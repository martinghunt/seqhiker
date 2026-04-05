package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"path/filepath"
	"sort"
	"strings"
)

const (
	comparisonConcatGapBP                = 50
	maxComparisonGenomes                 = 8
	comparisonStatusPending        uint8 = 1
	comparisonStatusReady          uint8 = 2
	comparisonMinimizerK                 = 15
	comparisonMinimizerWindow            = 10
	comparisonMaxSeedHits                = 64
	comparisonMinAnchorCount             = 3
	comparisonMinBlockLen                = 100
	comparisonMinPercentIdentX100        = 5000
	comparisonMaxAnchorGap               = 20000
	comparisonMaxDiagonalDrift           = 6000
	comparisonDiagonalBinSize            = 512
	comparisonChainMergeGapMaxSpan       = 256
	comparisonChainMergeOverlapMaxSpan   = 32
	comparisonChainSplitGapMaxSpan       = 12000
	comparisonRefineGapMaxSpan           = 8192
	comparisonRefineBandPad              = 96
	comparisonAffineMatch                = 2
	comparisonAffineMismatch             = -3
	comparisonAffineGapOpen              = -5
	comparisonAffineGapExtend            = -1
)

type comparisonSegment struct {
	Name         string
	Start        int
	End          int
	FeatureCount int
}

type comparisonGenome struct {
	ID       uint16
	Name     string
	Path     string
	Length   int
	Sequence string
	Features []Feature
	Segments []comparisonSegment
}

type comparisonPair struct {
	ID             uint16
	TopGenomeID    uint16
	BottomGenomeID uint16
	Status         uint8
	Blocks         []ComparisonBlock
	DetailPath     string
	DetailIndex    map[string]comparisonDetailIndexEntry
}

type minimizerSeed struct {
	Hash uint64
	Pos  int
}

type comparisonAnchor struct {
	QPos   int
	TPos   int
	TTrans int
}

type comparisonChain struct {
	Anchors    []comparisonAnchor
	DiagMean   float64
	SameStrand bool
}

type comparisonBlockDetail struct {
	Summary  ComparisonBlock
	Ops      string
	Variants []comparisonVariant
}

type comparisonVariant struct {
	Kind      byte
	QueryPos  uint32
	TargetPos uint32
	RefBases  string
	AltBases  string
}

type comparisonRefinedChain struct {
	Summary       ComparisonBlock
	OrientedStart int
	OrientedEnd   int
	Anchors       []comparisonAnchor
}

func encodeSequenceSlice(start int, end int, slice string) []byte {
	buf := make([]byte, 12+len(slice))
	binary.LittleEndian.PutUint32(buf[0:4], uint32(start))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(end))
	binary.LittleEndian.PutUint32(buf[8:12], uint32(len(slice)))
	copy(buf[12:], slice)
	return buf
}

func loadGenomeSnapshotEntries(entries []string) (GenomeSnapshot, bool, error) {
	snapshot := GenomeSnapshot{
		Sequences:   make(map[string]string),
		Features:    make(map[string][]Feature),
		ChromLength: make(map[string]int),
	}
	hasSequenceInput := false

	for _, p := range entries {
		kind, err := detectInputKind(p)
		if err != nil {
			return GenomeSnapshot{}, false, err
		}
		switch kind {
		case inputKindFASTA:
			hasSequenceInput = true
			seqs, err := parseFASTA(p)
			if err != nil {
				return GenomeSnapshot{}, false, err
			}
			for chr, seq := range seqs {
				snapshot.Sequences[chr] = seq
				snapshot.ChromLength[chr] = len(seq)
			}
		case inputKindGFF3:
			gffSeqs, gffFeatures, err := parseGFF3(p)
			if err != nil {
				return GenomeSnapshot{}, false, err
			}
			if len(gffSeqs) > 0 {
				hasSequenceInput = true
				for chr, seq := range gffSeqs {
					snapshot.Sequences[chr] = seq
					snapshot.ChromLength[chr] = len(seq)
				}
			}
			mergeFeatures(snapshot.Features, gffFeatures)
			for chr, feats := range gffFeatures {
				if _, ok := snapshot.ChromLength[chr]; ok || len(feats) == 0 {
					continue
				}
				snapshot.ChromLength[chr] = maxFeatureEnd(feats)
			}
		case inputKindFlatFile:
			hasSequenceInput = true
			flatSeqs, flatFeatures, err := parseFlatFile(p)
			if err != nil {
				return GenomeSnapshot{}, false, err
			}
			for chr, seq := range flatSeqs {
				snapshot.Sequences[chr] = seq
				snapshot.ChromLength[chr] = len(seq)
			}
			mergeFeatures(snapshot.Features, flatFeatures)
		default:
			return GenomeSnapshot{}, false, fmt.Errorf("unsupported genome/annotation file: %s", p)
		}
	}

	return snapshot, hasSequenceInput, nil
}

func loadGenomeSnapshot(path string) (GenomeSnapshot, bool, error) {
	entries, err := gatherInputFiles(path)
	if err != nil {
		return GenomeSnapshot{}, false, err
	}
	return loadGenomeSnapshotEntries(entries)
}

func entriesAreEmbeddedGFF3(entries []string) (bool, error) {
	if len(entries) == 0 {
		return false, nil
	}
	for _, p := range entries {
		kind, err := detectInputKind(p)
		if err != nil {
			return false, err
		}
		if kind != inputKindGFF3 {
			return false, nil
		}
		hasEmbeddedSeq, err := gff3HasEmbeddedSequence(p)
		if err != nil {
			return false, err
		}
		if !hasEmbeddedSeq {
			return false, nil
		}
	}
	return true, nil
}

func (e *Engine) AddComparisonGenome(path string) (ComparisonGenomeInfo, error) {
	snapshot, hasSequenceInput, err := loadGenomeSnapshot(path)
	if err != nil {
		return ComparisonGenomeInfo{}, err
	}
	if !hasSequenceInput || len(snapshot.Sequences) == 0 {
		return ComparisonGenomeInfo{}, errors.New("comparison genome requires sequence-bearing input")
	}

	genome, err := buildComparisonGenome(path, snapshot)
	if err != nil {
		return ComparisonGenomeInfo{}, err
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if len(e.comparisonGenomeOrder) >= maxComparisonGenomes {
		return ComparisonGenomeInfo{}, fmt.Errorf("comparison view supports at most %d genomes", maxComparisonGenomes)
	}
	genome.ID = e.nextComparisonGenomeID
	e.nextComparisonGenomeID++
	if e.nextComparisonGenomeID == 0 {
		e.nextComparisonGenomeID = 1
	}
	e.comparisonGenomes[genome.ID] = genome
	e.comparisonGenomeOrder = append(e.comparisonGenomeOrder, genome.ID)
	e.rebuildComparisonPairsLocked()
	return genome.info(), nil
}

func (e *Engine) AddComparisonGenomeFiles(paths []string) (ComparisonGenomeInfo, error) {
	if len(paths) == 0 {
		return ComparisonGenomeInfo{}, errors.New("comparison genome requires at least one input path")
	}
	entries := make([]string, 0, len(paths))
	for _, path := range paths {
		if path == "" {
			continue
		}
		entries = append(entries, path)
	}
	if len(entries) == 0 {
		return ComparisonGenomeInfo{}, errors.New("comparison genome requires at least one input path")
	}
	snapshot, hasSequenceInput, err := loadGenomeSnapshotEntries(entries)
	if err != nil {
		return ComparisonGenomeInfo{}, err
	}
	if !hasSequenceInput || len(snapshot.Sequences) == 0 {
		return ComparisonGenomeInfo{}, errors.New("comparison genome requires sequence-bearing input")
	}
	genome, err := buildComparisonGenome(entries[0], snapshot)
	if err != nil {
		return ComparisonGenomeInfo{}, err
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if len(e.comparisonGenomeOrder) >= maxComparisonGenomes {
		return ComparisonGenomeInfo{}, fmt.Errorf("comparison view supports at most %d genomes", maxComparisonGenomes)
	}
	genome.ID = e.nextComparisonGenomeID
	e.nextComparisonGenomeID++
	if e.nextComparisonGenomeID == 0 {
		e.nextComparisonGenomeID = 1
	}
	e.comparisonGenomes[genome.ID] = genome
	e.comparisonGenomeOrder = append(e.comparisonGenomeOrder, genome.ID)
	e.rebuildComparisonPairsLocked()
	return genome.info(), nil
}

func (e *Engine) ListComparisonGenomes() []ComparisonGenomeInfo {
	e.mu.RLock()
	defer e.mu.RUnlock()

	out := make([]ComparisonGenomeInfo, 0, len(e.comparisonGenomeOrder))
	for _, genomeID := range e.comparisonGenomeOrder {
		if genome, ok := e.comparisonGenomes[genomeID]; ok && genome != nil {
			out = append(out, genome.info())
		}
	}
	return out
}

func (e *Engine) ListComparisonPairs() []ComparisonPairInfo {
	e.mu.Lock()
	defer e.mu.Unlock()

	out := make([]ComparisonPairInfo, 0, len(e.comparisonPairOrder))
	for _, pairID := range e.comparisonPairOrder {
		pair := e.comparisonPairs[pairID]
		if pair == nil {
			continue
		}
		if pair.Status != comparisonStatusReady {
			query := e.comparisonGenomes[pair.TopGenomeID]
			target := e.comparisonGenomes[pair.BottomGenomeID]
			pair.Blocks = buildComparisonBlocksForDisplay(query, target, pair.TopGenomeID, pair.BottomGenomeID)
			_ = e.ensureComparisonPairDetailCacheLocked(pair, query, target)
			pair.Status = comparisonStatusReady
		}
		out = append(out, ComparisonPairInfo{
			ID:             pair.ID,
			TopGenomeID:    pair.TopGenomeID,
			BottomGenomeID: pair.BottomGenomeID,
			BlockCount:     uint32(len(pair.Blocks)),
			Status:         pair.Status,
		})
	}
	return out
}

func (e *Engine) GetComparisonBlocks(pairID uint16) ([]ComparisonBlock, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	pair, ok := e.comparisonPairs[pairID]
	if !ok || pair == nil {
		return nil, fmt.Errorf("comparison pair %d not found", pairID)
	}
	if pair.Status != comparisonStatusReady {
		query := e.comparisonGenomes[pair.TopGenomeID]
		target := e.comparisonGenomes[pair.BottomGenomeID]
		pair.Blocks = buildComparisonBlocksForDisplay(query, target, pair.TopGenomeID, pair.BottomGenomeID)
		_ = e.ensureComparisonPairDetailCacheLocked(pair, query, target)
		pair.Status = comparisonStatusReady
	}
	out := make([]ComparisonBlock, 0, len(pair.Blocks))
	for _, block := range pair.Blocks {
		out = append(out, block)
	}
	return out, nil
}

func (e *Engine) GetComparisonBlocksByGenomes(queryGenomeID uint16, targetGenomeID uint16) ([]ComparisonBlock, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	blocks, storedQueryID, storedTargetID, err := e.getOrBuildComparisonPairLocked(queryGenomeID, targetGenomeID)
	if err != nil {
		return nil, err
	}
	out := make([]ComparisonBlock, 0, len(blocks))
	reverse := storedQueryID != queryGenomeID || storedTargetID != targetGenomeID
	for _, summary := range blocks {
		if reverse {
			summary = swappedComparisonBlock(summary)
		}
		out = append(out, summary)
	}
	return out, nil
}

func (e *Engine) GetComparisonAnnotations(genomeID uint16, start uint32, end uint32, maxRecords uint16, minFeatureLen uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	genome := e.comparisonGenomes[genomeID]
	if genome == nil {
		return nil, fmt.Errorf("comparison genome %d not found", genomeID)
	}
	if end < start {
		return nil, errors.New("end must be >= start")
	}
	maxRecs := int(maxRecords)
	if maxRecs <= 0 {
		maxRecs = 2000
	}
	minLen := int(minFeatureLen)
	if minLen < 1 {
		minLen = 1
	}
	features := queryFeatures(genome.Features, int(start), int(end), maxRecs, minLen)
	return encodeAnnotations(int(start), int(end), features), nil
}

func (e *Engine) GetComparisonReferenceSlice(genomeID uint16, start uint32, end uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	genome := e.comparisonGenomes[genomeID]
	if genome == nil {
		return nil, fmt.Errorf("comparison genome %d not found", genomeID)
	}
	s := int(start)
	eIdx := int(end)
	if eIdx < s {
		return nil, errors.New("end must be >= start")
	}
	if s < 0 {
		s = 0
	}
	if s > len(genome.Sequence) {
		s = len(genome.Sequence)
	}
	if eIdx > len(genome.Sequence) {
		eIdx = len(genome.Sequence)
	}
	return encodeSequenceSlice(s, eIdx, genome.Sequence[s:eIdx]), nil
}

func (e *Engine) GetComparisonBlockDetail(queryGenomeID uint16, targetGenomeID uint16, block ComparisonBlock) (ComparisonBlockDetail, error) {
	e.mu.Lock()
	query := e.comparisonGenomes[queryGenomeID]
	target := e.comparisonGenomes[targetGenomeID]
	var exactPair *comparisonPair
	var reversePair *comparisonPair
	for _, pair := range e.comparisonPairs {
		if pair == nil {
			continue
		}
		if pair.TopGenomeID == queryGenomeID && pair.BottomGenomeID == targetGenomeID {
			exactPair = pair
			break
		}
		if pair.TopGenomeID == targetGenomeID && pair.BottomGenomeID == queryGenomeID {
			reversePair = pair
		}
	}
	if query == nil || target == nil {
		e.mu.Unlock()
		return ComparisonBlockDetail{}, fmt.Errorf("comparison genomes %d/%d not loaded", queryGenomeID, targetGenomeID)
	}
	if exactPair != nil {
		_ = e.ensureComparisonPairDetailCacheLocked(exactPair, query, target)
	}
	if reversePair != nil {
		_ = e.ensureComparisonPairDetailCacheLocked(reversePair, target, query)
	}
	if exactPair != nil {
		if detail, ok, err := readComparisonDetailFromPairCache(exactPair, block); err == nil && ok {
			e.mu.Unlock()
			return detail, nil
		}
	}
	if reversePair != nil {
		if detail, ok, err := readComparisonDetailFromPairCache(reversePair, swappedComparisonBlock(block)); err == nil && ok {
			e.mu.Unlock()
			return swappedComparisonBlockDetail(detail), nil
		}
	}
	e.mu.Unlock()
	detail, ok := buildComparisonBlockDetail(query, target, block)
	if !ok {
		return ComparisonBlockDetail{}, fmt.Errorf("unable to refine comparison block")
	}
	e.mu.Lock()
	if exactPair != nil {
		_ = appendComparisonDetailToPairCache(exactPair, block, detail.info())
	} else if reversePair != nil {
		_ = appendComparisonDetailToPairCache(reversePair, swappedComparisonBlock(block), swappedComparisonBlockDetail(detail.info()))
	}
	e.mu.Unlock()
	return detail.info(), nil
}

func buildComparisonGenome(path string, snapshot GenomeSnapshot) (*comparisonGenome, error) {
	chrNames := make([]string, 0, len(snapshot.ChromLength))
	for chr := range snapshot.ChromLength {
		chrNames = append(chrNames, chr)
	}
	sort.Strings(chrNames)
	if len(chrNames) == 0 {
		return nil, errors.New("comparison genome has no chromosomes")
	}

	var seqBuilder strings.Builder
	segments := make([]comparisonSegment, 0, len(chrNames))
	features := make([]Feature, 0, 1024)
	offset := 0
	for i, chr := range chrNames {
		if i > 0 {
			seqBuilder.WriteString(strings.Repeat("N", comparisonConcatGapBP))
			offset += comparisonConcatGapBP
		}
		seq := snapshot.Sequences[chr]
		start := offset
		seqBuilder.WriteString(seq)
		offset += len(seq)
		chrFeatures := snapshot.Features[chr]
		segments = append(segments, comparisonSegment{
			Name:         chr,
			Start:        start,
			End:          offset,
			FeatureCount: len(chrFeatures),
		})
		for _, feat := range chrFeatures {
			adjusted := feat
			adjusted.SeqName = chr
			adjusted.Start += start
			adjusted.End += start
			features = append(features, adjusted)
		}
	}
	sort.Slice(features, func(i, j int) bool {
		if features[i].Start == features[j].Start {
			return features[i].End < features[j].End
		}
		return features[i].Start < features[j].Start
	})
	name := filepath.Base(path)
	if ext := filepath.Ext(name); ext != "" {
		name = strings.TrimSuffix(name, ext)
	}
	if name == "" {
		name = "genome"
	}
	return &comparisonGenome{
		Name:     name,
		Path:     path,
		Length:   seqBuilder.Len(),
		Sequence: seqBuilder.String(),
		Features: features,
		Segments: segments,
	}, nil
}

func (g *comparisonGenome) info() ComparisonGenomeInfo {
	segments := make([]ComparisonSegmentInfo, 0, len(g.Segments))
	for _, segment := range g.Segments {
		segments = append(segments, ComparisonSegmentInfo{
			Name:         segment.Name,
			Start:        uint32(segment.Start),
			End:          uint32(segment.End),
			FeatureCount: uint32(segment.FeatureCount),
		})
	}
	return ComparisonGenomeInfo{
		ID:           g.ID,
		Name:         g.Name,
		Path:         g.Path,
		Length:       uint32(g.Length),
		SegmentCount: uint16(len(g.Segments)),
		FeatureCount: uint32(len(g.Features)),
		Segments:     segments,
	}
}

func (e *Engine) rebuildComparisonPairsLocked() {
	e.comparisonPairs = make(map[uint16]*comparisonPair)
	e.comparisonPairOrder = e.comparisonPairOrder[:0]
	e.nextComparisonPairID = 1
	for i := 0; i+1 < len(e.comparisonGenomeOrder); i++ {
		pairID := e.nextComparisonPairID
		e.nextComparisonPairID++
		pair := &comparisonPair{
			ID:             pairID,
			TopGenomeID:    e.comparisonGenomeOrder[i],
			BottomGenomeID: e.comparisonGenomeOrder[i+1],
			Status:         comparisonStatusPending,
			Blocks:         nil,
		}
		e.comparisonPairs[pairID] = pair
		e.comparisonPairOrder = append(e.comparisonPairOrder, pairID)
	}
}

func (e *Engine) getOrBuildComparisonPairLocked(queryGenomeID uint16, targetGenomeID uint16) ([]ComparisonBlock, uint16, uint16, error) {
	if queryGenomeID == 0 || targetGenomeID == 0 || queryGenomeID == targetGenomeID {
		return nil, 0, 0, fmt.Errorf("invalid comparison genome pair %d/%d", queryGenomeID, targetGenomeID)
	}
	query := e.comparisonGenomes[queryGenomeID]
	target := e.comparisonGenomes[targetGenomeID]
	if query == nil || target == nil {
		return nil, 0, 0, fmt.Errorf("comparison genomes %d/%d not loaded", queryGenomeID, targetGenomeID)
	}
	canonicalQueryID, canonicalTargetID := comparisonCanonicalGenomeIDs(queryGenomeID, targetGenomeID)
	canonicalQuery := e.comparisonGenomes[canonicalQueryID]
	canonicalTarget := e.comparisonGenomes[canonicalTargetID]
	for _, pair := range e.comparisonPairs {
		if pair == nil {
			continue
		}
		if pair.TopGenomeID == queryGenomeID && pair.BottomGenomeID == targetGenomeID {
			if pair.Status != comparisonStatusReady {
				pair.Blocks = buildComparisonBlocksForDisplay(canonicalQuery, canonicalTarget, pair.TopGenomeID, pair.BottomGenomeID)
				_ = e.ensureComparisonPairDetailCacheLocked(pair, query, target)
				pair.Status = comparisonStatusReady
			}
			return pair.Blocks, queryGenomeID, targetGenomeID, nil
		}
		if pair.TopGenomeID == targetGenomeID && pair.BottomGenomeID == queryGenomeID {
			if pair.Status != comparisonStatusReady {
				pair.Blocks = buildComparisonBlocksForDisplay(canonicalQuery, canonicalTarget, pair.TopGenomeID, pair.BottomGenomeID)
				_ = e.ensureComparisonPairDetailCacheLocked(pair, target, query)
				pair.Status = comparisonStatusReady
			}
			return swapComparisonBlocks(pair.Blocks), queryGenomeID, targetGenomeID, nil
		}
	}
	blocks := buildComparisonBlocksForDisplay(canonicalQuery, canonicalTarget, queryGenomeID, targetGenomeID)
	return blocks, queryGenomeID, targetGenomeID, nil
}

func comparisonCanonicalGenomeIDs(a uint16, b uint16) (uint16, uint16) {
	if a < b {
		return a, b
	}
	return b, a
}

func buildComparisonBlocksForDisplay(canonicalQuery, canonicalTarget *comparisonGenome, displayQueryID uint16, displayTargetID uint16) []ComparisonBlock {
	blocks := buildComparisonBlocks(canonicalQuery, canonicalTarget)
	if canonicalQuery == nil || canonicalTarget == nil {
		return blocks
	}
	if canonicalQuery.ID == displayQueryID && canonicalTarget.ID == displayTargetID {
		return blocks
	}
	return swapComparisonBlocks(blocks)
}

func swapComparisonBlocks(blocks []ComparisonBlock) []ComparisonBlock {
	if len(blocks) == 0 {
		return nil
	}
	out := make([]ComparisonBlock, 0, len(blocks))
	for _, block := range blocks {
		out = append(out, swappedComparisonBlock(block))
	}
	return out
}

func swappedComparisonBlock(block ComparisonBlock) ComparisonBlock {
	return ComparisonBlock{
		QueryStart:       block.TargetStart,
		QueryEnd:         block.TargetEnd,
		TargetStart:      block.QueryStart,
		TargetEnd:        block.QueryEnd,
		PercentIdentX100: block.PercentIdentX100,
		SameStrand:       block.SameStrand,
	}
}

func buildComparisonBlockDetail(query, target *comparisonGenome, summary ComparisonBlock) (comparisonBlockDetail, bool) {
	block := comparisonBlockDetail{Summary: summary}
	if query == nil || target == nil {
		return comparisonBlockDetail{}, false
	}
	qStart := int(summary.QueryStart)
	qEnd := int(summary.QueryEnd)
	tStart := int(summary.TargetStart)
	tEnd := int(summary.TargetEnd)
	if qStart < 0 || tStart < 0 || qEnd > len(query.Sequence) || tEnd > len(target.Sequence) || qEnd <= qStart || tEnd <= tStart {
		return comparisonBlockDetail{}, false
	}
	qSpan := qEnd - qStart
	tSpan := tEnd - tStart
	if max(qSpan, tSpan) > comparisonRefineGapMaxSpan {
		return comparisonBlockDetail{}, false
	}
	querySeq := query.Sequence[qStart:qEnd]
	targetSeq := target.Sequence[tStart:tEnd]
	if !summary.SameStrand {
		targetSeq = reverseComplementString(targetSeq)
	}
	band := absInt(qSpan-tSpan) + comparisonRefineBandPad
	aln, ok := bandedAffineAlign(querySeq, targetSeq, band)
	if !ok {
		return comparisonBlockDetail{}, false
	}
	block.Summary.PercentIdentX100 = aln.percentIdentityX100()
	if int(block.Summary.PercentIdentX100) < comparisonMinPercentIdentX100 {
		return comparisonBlockDetail{}, false
	}
	block.Variants = aln.variantsForBlock(block.Summary)
	block.Ops = string(aln.Ops)
	return block, true
}

func buildComparisonBlockDetails(query, target *comparisonGenome) []comparisonBlockDetail {
	if query == nil || target == nil || len(query.Sequence) < comparisonMinimizerK || len(target.Sequence) < comparisonMinimizerK {
		return nil
	}

	querySeeds := extractMinimizers(query.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, false)
	targetForward := buildSeedIndex(extractMinimizers(target.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, false))
	targetReverse := buildSeedIndex(extractMinimizers(target.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, true))

	sameAnchors := make([]comparisonAnchor, 0, 1024)
	reverseAnchors := make([]comparisonAnchor, 0, 1024)
	for _, seed := range querySeeds {
		if positions, ok := targetForward[seed.Hash]; ok && len(positions) > 0 && len(positions) <= comparisonMaxSeedHits {
			for _, tPos := range positions {
				sameAnchors = append(sameAnchors, comparisonAnchor{QPos: seed.Pos, TPos: tPos, TTrans: tPos})
			}
		}
		if positions, ok := targetReverse[seed.Hash]; ok && len(positions) > 0 && len(positions) <= comparisonMaxSeedHits {
			for _, tPos := range positions {
				tTrans := target.Length - (tPos + comparisonMinimizerK)
				if tTrans < 0 {
					continue
				}
				reverseAnchors = append(reverseAnchors, comparisonAnchor{QPos: seed.Pos, TPos: tPos, TTrans: tTrans})
			}
		}
	}

	details := make([]comparisonBlockDetail, 0, 64)
	details = append(details, buildDetailsFromAnchors(query, target, sameAnchors, true)...)
	details = append(details, buildDetailsFromAnchors(query, target, reverseAnchors, false)...)
	sort.Slice(details, func(i, j int) bool {
		if details[i].Summary.QueryStart == details[j].Summary.QueryStart {
			if details[i].Summary.QueryEnd == details[j].Summary.QueryEnd {
				return details[i].Summary.TargetStart < details[j].Summary.TargetStart
			}
			return details[i].Summary.QueryEnd < details[j].Summary.QueryEnd
		}
		return details[i].Summary.QueryStart < details[j].Summary.QueryStart
	})
	return details
}

func buildComparisonBlocks(query, target *comparisonGenome) []ComparisonBlock {
	if query == nil || target == nil || len(query.Sequence) < comparisonMinimizerK || len(target.Sequence) < comparisonMinimizerK {
		return nil
	}

	querySeeds := extractMinimizers(query.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, false)
	targetForward := buildSeedIndex(extractMinimizers(target.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, false))
	targetReverse := buildSeedIndex(extractMinimizers(target.Sequence, comparisonMinimizerK, comparisonMinimizerWindow, true))

	sameAnchors := make([]comparisonAnchor, 0, 1024)
	reverseAnchors := make([]comparisonAnchor, 0, 1024)
	for _, seed := range querySeeds {
		if positions, ok := targetForward[seed.Hash]; ok && len(positions) > 0 && len(positions) <= comparisonMaxSeedHits {
			for _, tPos := range positions {
				sameAnchors = append(sameAnchors, comparisonAnchor{QPos: seed.Pos, TPos: tPos, TTrans: tPos})
			}
		}
		if positions, ok := targetReverse[seed.Hash]; ok && len(positions) > 0 && len(positions) <= comparisonMaxSeedHits {
			for _, tPos := range positions {
				tTrans := target.Length - (tPos + comparisonMinimizerK)
				if tTrans < 0 {
					continue
				}
				reverseAnchors = append(reverseAnchors, comparisonAnchor{QPos: seed.Pos, TPos: tPos, TTrans: tTrans})
			}
		}
	}

	chains := make([]comparisonRefinedChain, 0, 64)
	chains = append(chains, buildRefinedChainsFromAnchors(sameAnchors, true)...)
	chains = append(chains, buildRefinedChainsFromAnchors(reverseAnchors, false)...)
	sort.Slice(chains, func(i, j int) bool {
		if chains[i].Summary.QueryStart == chains[j].Summary.QueryStart {
			if chains[i].Summary.QueryEnd == chains[j].Summary.QueryEnd {
				return chains[i].Summary.TargetStart < chains[j].Summary.TargetStart
			}
			return chains[i].Summary.QueryEnd < chains[j].Summary.QueryEnd
		}
		return chains[i].Summary.QueryStart < chains[j].Summary.QueryStart
	})
	blocks := make([]ComparisonBlock, 0, len(chains))
	for _, chain := range chains {
		summary := chain.Summary
		if detail, ok := buildComparisonDetailFromRefinedChain(query, target, chain); ok {
			summary = detail.Summary
		} else if exactPID, ok := exactComparisonBlockPercentIdentity(query, target, summary); ok {
			summary.PercentIdentX100 = exactPID
		}
		if int(summary.PercentIdentX100) < comparisonMinPercentIdentX100 {
			continue
		}
		blocks = append(blocks, summary)
	}
	return blocks
}

func buildBlocksFromAnchors(anchors []comparisonAnchor, sameStrand bool) []ComparisonBlock {
	if len(anchors) == 0 {
		return nil
	}
	diagBuckets := make(map[int][]comparisonAnchor, 16)
	for _, anchor := range anchors {
		diag := anchor.TTrans - anchor.QPos
		bucket := diagBucket(diag)
		diagBuckets[bucket] = append(diagBuckets[bucket], anchor)
	}
	bucketKeys := make([]int, 0, len(diagBuckets))
	for key := range diagBuckets {
		bucketKeys = append(bucketKeys, key)
	}
	sort.Ints(bucketKeys)
	blocks := make([]ComparisonBlock, 0, len(anchors)/comparisonMinAnchorCount)
	for _, key := range bucketKeys {
		blocks = append(blocks, buildBlocksFromDiagonalBucket(diagBuckets[key], sameStrand)...)
	}
	return blocks
}

func buildDetailsFromAnchors(query, target *comparisonGenome, anchors []comparisonAnchor, sameStrand bool) []comparisonBlockDetail {
	refinedChains := buildRefinedChainsFromAnchors(anchors, sameStrand)
	out := make([]comparisonBlockDetail, 0, len(refinedChains))
	for _, chain := range refinedChains {
		detail, ok := buildComparisonDetailFromRefinedChain(query, target, chain)
		if !ok {
			continue
		}
		out = append(out, detail)
	}
	return out
}

func buildRefinedChainsFromAnchors(anchors []comparisonAnchor, sameStrand bool) []comparisonRefinedChain {
	if len(anchors) == 0 {
		return nil
	}
	sort.Slice(anchors, func(i, j int) bool {
		if anchors[i].QPos == anchors[j].QPos {
			if anchors[i].TTrans == anchors[j].TTrans {
				return anchors[i].TPos < anchors[j].TPos
			}
			return anchors[i].TTrans < anchors[j].TTrans
		}
		return anchors[i].QPos < anchors[j].QPos
	})

	chains := make([]comparisonChain, 0, 32)
	var current comparisonChain
	for _, anchor := range dedupComparisonAnchors(anchors) {
		if len(current.Anchors) == 0 {
			current = comparisonChain{Anchors: []comparisonAnchor{anchor}, DiagMean: float64(anchor.TTrans - anchor.QPos), SameStrand: sameStrand}
			continue
		}
		prev := current.Anchors[len(current.Anchors)-1]
		qGap := anchor.QPos - prev.QPos
		tGap := anchor.TTrans - prev.TTrans
		diag := float64(anchor.TTrans - anchor.QPos)
		if qGap > 0 && tGap > 0 && qGap <= comparisonMaxAnchorGap && tGap <= comparisonMaxAnchorGap && math.Abs(diag-current.DiagMean) <= comparisonMaxDiagonalDrift {
			current.Anchors = append(current.Anchors, anchor)
			n := float64(len(current.Anchors))
			current.DiagMean += (diag - current.DiagMean) / n
			continue
		}
		if isUsableComparisonChain(current) {
			chains = append(chains, current)
		}
		current = comparisonChain{Anchors: []comparisonAnchor{anchor}, DiagMean: float64(anchor.TTrans - anchor.QPos), SameStrand: sameStrand}
	}
	if isUsableComparisonChain(current) {
		chains = append(chains, current)
	}

	out := make([]comparisonRefinedChain, 0, len(chains))
	for _, chain := range chains {
		for _, subchain := range splitComparisonChainForRefinement(chain) {
			refined := comparisonChainToRefinedChain(subchain)
			if refined.Summary.QueryEnd > refined.Summary.QueryStart && refined.Summary.TargetEnd > refined.Summary.TargetStart {
				out = append(out, refined)
			}
		}
	}
	return mergeAdjacentRefinedChains(out)
}

func mergeAdjacentRefinedChains(chains []comparisonRefinedChain) []comparisonRefinedChain {
	if len(chains) <= 1 {
		return chains
	}
	sort.Slice(chains, func(i, j int) bool {
		if chains[i].Summary.QueryStart == chains[j].Summary.QueryStart {
			if chains[i].Summary.QueryEnd == chains[j].Summary.QueryEnd {
				if chains[i].OrientedStart == chains[j].OrientedStart {
					return chains[i].OrientedEnd < chains[j].OrientedEnd
				}
				return chains[i].OrientedStart < chains[j].OrientedStart
			}
			return chains[i].Summary.QueryEnd < chains[j].Summary.QueryEnd
		}
		return chains[i].Summary.QueryStart < chains[j].Summary.QueryStart
	})
	merged := make([]comparisonRefinedChain, 0, len(chains))
	current := chains[0]
	for i := 1; i < len(chains); i++ {
		next := chains[i]
		if canMergeAdjacentRefinedChains(current, next) {
			chain := comparisonChain{
				Anchors:    append(append([]comparisonAnchor(nil), current.Anchors...), next.Anchors...),
				SameStrand: current.Summary.SameStrand,
			}
			current = comparisonChainToRefinedChain(chain)
			continue
		}
		merged = append(merged, current)
		current = next
	}
	merged = append(merged, current)
	return merged
}

func canMergeAdjacentRefinedChains(a, b comparisonRefinedChain) bool {
	if a.Summary.SameStrand != b.Summary.SameStrand {
		return false
	}
	qGap := int(b.Summary.QueryStart) - int(a.Summary.QueryEnd)
	tGap := b.OrientedStart - a.OrientedEnd
	if qGap < -comparisonChainMergeOverlapMaxSpan || tGap < -comparisonChainMergeOverlapMaxSpan {
		return false
	}
	if max(qGap, tGap) > comparisonChainMergeGapMaxSpan {
		return false
	}
	diagA := a.OrientedStart - int(a.Summary.QueryStart)
	diagB := b.OrientedStart - int(b.Summary.QueryStart)
	if absInt(diagA-diagB) > comparisonMaxDiagonalDrift {
		return false
	}
	return true
}

func splitComparisonChainForRefinement(chain comparisonChain) []comparisonChain {
	if len(chain.Anchors) <= 1 {
		return []comparisonChain{chain}
	}
	out := make([]comparisonChain, 0, 4)
	current := comparisonChain{
		Anchors:    []comparisonAnchor{chain.Anchors[0]},
		DiagMean:   float64(chain.Anchors[0].TTrans - chain.Anchors[0].QPos),
		SameStrand: chain.SameStrand,
	}
	for i := 1; i < len(chain.Anchors); i++ {
		prev := current.Anchors[len(current.Anchors)-1]
		next := chain.Anchors[i]
		qGap := next.QPos - (prev.QPos + comparisonMinimizerK)
		tGap := next.TTrans - (prev.TTrans + comparisonMinimizerK)
		if max(qGap, tGap) > comparisonChainSplitGapMaxSpan && isUsableComparisonChain(current) {
			out = append(out, current)
			current = comparisonChain{
				Anchors:    []comparisonAnchor{next},
				DiagMean:   float64(next.TTrans - next.QPos),
				SameStrand: chain.SameStrand,
			}
			continue
		}
		current.Anchors = append(current.Anchors, next)
		n := float64(len(current.Anchors))
		diag := float64(next.TTrans - next.QPos)
		current.DiagMean += (diag - current.DiagMean) / n
	}
	if len(current.Anchors) > 0 && isUsableComparisonChain(current) {
		out = append(out, current)
	}
	if len(out) == 0 {
		return []comparisonChain{chain}
	}
	return out
}

func buildBlocksFromDiagonalBucket(anchors []comparisonAnchor, sameStrand bool) []ComparisonBlock {
	if len(anchors) == 0 {
		return nil
	}
	sort.Slice(anchors, func(i, j int) bool {
		if anchors[i].QPos == anchors[j].QPos {
			if anchors[i].TTrans == anchors[j].TTrans {
				return anchors[i].TPos < anchors[j].TPos
			}
			return anchors[i].TTrans < anchors[j].TTrans
		}
		return anchors[i].QPos < anchors[j].QPos
	})

	chains := make([]comparisonChain, 0, 32)
	var current comparisonChain
	for _, anchor := range dedupComparisonAnchors(anchors) {
		if len(current.Anchors) == 0 {
			current = comparisonChain{
				Anchors:    []comparisonAnchor{anchor},
				DiagMean:   float64(anchor.TTrans - anchor.QPos),
				SameStrand: sameStrand,
			}
			continue
		}
		prev := current.Anchors[len(current.Anchors)-1]
		qGap := anchor.QPos - prev.QPos
		tGap := anchor.TTrans - prev.TTrans
		diag := float64(anchor.TTrans - anchor.QPos)
		if qGap > 0 && tGap > 0 && qGap <= comparisonMaxAnchorGap && tGap <= comparisonMaxAnchorGap && math.Abs(diag-current.DiagMean) <= comparisonMaxDiagonalDrift {
			current.Anchors = append(current.Anchors, anchor)
			n := float64(len(current.Anchors))
			current.DiagMean += (diag - current.DiagMean) / n
			continue
		}
		if isUsableComparisonChain(current) {
			chains = append(chains, current)
		}
		current = comparisonChain{
			Anchors:    []comparisonAnchor{anchor},
			DiagMean:   float64(anchor.TTrans - anchor.QPos),
			SameStrand: sameStrand,
		}
	}
	if isUsableComparisonChain(current) {
		chains = append(chains, current)
	}

	blocks := make([]ComparisonBlock, 0, len(chains))
	for _, chain := range chains {
		block := comparisonChainToBlock(chain)
		if block.QueryEnd > block.QueryStart && block.TargetEnd > block.TargetStart {
			blocks = append(blocks, block)
		}
	}
	return blocks
}

func diagBucket(diag int) int {
	if comparisonDiagonalBinSize <= 0 {
		return diag
	}
	if diag >= 0 {
		return diag / comparisonDiagonalBinSize
	}
	return -(((-diag) + comparisonDiagonalBinSize - 1) / comparisonDiagonalBinSize)
}

func dedupComparisonAnchors(anchors []comparisonAnchor) []comparisonAnchor {
	if len(anchors) == 0 {
		return nil
	}
	out := make([]comparisonAnchor, 0, len(anchors))
	last := anchors[0]
	out = append(out, last)
	for i := 1; i < len(anchors); i++ {
		if anchors[i].QPos == last.QPos && anchors[i].TPos == last.TPos && anchors[i].TTrans == last.TTrans {
			continue
		}
		last = anchors[i]
		out = append(out, last)
	}
	return out
}

func isUsableComparisonChain(chain comparisonChain) bool {
	if len(chain.Anchors) < comparisonMinAnchorCount {
		return false
	}
	block := comparisonChainToBlock(chain)
	if int(block.QueryEnd-block.QueryStart) < comparisonMinBlockLen {
		return false
	}
	if int(block.TargetEnd-block.TargetStart) < comparisonMinBlockLen {
		return false
	}
	return true
}

func comparisonChainToBlock(chain comparisonChain) ComparisonBlock {
	return comparisonChainToRefinedChain(chain).Summary
}

func comparisonChainToRefinedChain(chain comparisonChain) comparisonRefinedChain {
	qStart := chain.Anchors[0].QPos
	qEnd := chain.Anchors[0].QPos + comparisonMinimizerK
	tStart := chain.Anchors[0].TPos
	tEnd := chain.Anchors[0].TPos + comparisonMinimizerK
	tOrientedStart := chain.Anchors[0].TTrans
	tOrientedEnd := chain.Anchors[0].TTrans + comparisonMinimizerK
	covered := 0
	covStart := -1
	covEnd := -1
	for _, anchor := range chain.Anchors {
		if anchor.QPos < qStart {
			qStart = anchor.QPos
		}
		if anchor.QPos+comparisonMinimizerK > qEnd {
			qEnd = anchor.QPos + comparisonMinimizerK
		}
		if anchor.TPos < tStart {
			tStart = anchor.TPos
		}
		if anchor.TPos+comparisonMinimizerK > tEnd {
			tEnd = anchor.TPos + comparisonMinimizerK
		}
		if anchor.TTrans < tOrientedStart {
			tOrientedStart = anchor.TTrans
		}
		if anchor.TTrans+comparisonMinimizerK > tOrientedEnd {
			tOrientedEnd = anchor.TTrans + comparisonMinimizerK
		}
		if covStart < 0 {
			covStart = anchor.QPos
			covEnd = anchor.QPos + comparisonMinimizerK
			continue
		}
		if anchor.QPos <= covEnd {
			if anchor.QPos+comparisonMinimizerK > covEnd {
				covEnd = anchor.QPos + comparisonMinimizerK
			}
			continue
		}
		covered += covEnd - covStart
		covStart = anchor.QPos
		covEnd = anchor.QPos + comparisonMinimizerK
	}
	if covStart >= 0 {
		covered += covEnd - covStart
	}
	span := max(qEnd-qStart, tEnd-tStart)
	pid := uint16(0)
	if span > 0 {
		pct := int(math.Round(10000 * float64(covered) / float64(span)))
		if pct < 0 {
			pct = 0
		}
		if pct > 10000 {
			pct = 10000
		}
		pid = uint16(pct)
	}
	return comparisonRefinedChain{
		Summary: ComparisonBlock{
			QueryStart:       uint32(qStart),
			QueryEnd:         uint32(qEnd),
			TargetStart:      uint32(tStart),
			TargetEnd:        uint32(tEnd),
			PercentIdentX100: pid,
			SameStrand:       chain.SameStrand,
		},
		OrientedStart: tOrientedStart,
		OrientedEnd:   tOrientedEnd,
		Anchors:       append([]comparisonAnchor(nil), chain.Anchors...),
	}
}

func refineComparisonBlock(query, target *comparisonGenome, block *comparisonBlockDetail) {
	if query == nil || target == nil || block == nil {
		return
	}
	refined, ok := buildComparisonBlockDetail(query, target, block.Summary)
	if !ok {
		return
	}
	*block = refined
}

func buildComparisonDetailFromRefinedChain(query, target *comparisonGenome, chain comparisonRefinedChain) (comparisonBlockDetail, bool) {
	if query == nil || target == nil || len(chain.Anchors) == 0 {
		return comparisonBlockDetail{}, false
	}
	var ops []byte
	coveredQ := chain.Anchors[0].QPos
	coveredT := chain.Anchors[0].TTrans
	for _, anchor := range chain.Anchors {
		if anchor.QPos > coveredQ || anchor.TTrans > coveredT {
			qGapStart := coveredQ
			qGapEnd := anchor.QPos
			tGapStart := coveredT
			tGapEnd := anchor.TTrans
			if qGapEnd < qGapStart || tGapEnd < tGapStart {
				return comparisonBlockDetail{}, false
			}
			if qGapEnd > qGapStart || tGapEnd > tGapStart {
				if max(qGapEnd-qGapStart, tGapEnd-tGapStart) > comparisonRefineGapMaxSpan {
					return comparisonBlockDetail{}, false
				}
				queryGap := query.Sequence[qGapStart:qGapEnd]
				targetGap, ok := orientedTargetSlice(target, chain.Summary.SameStrand, tGapStart, tGapEnd)
				if !ok {
					return comparisonBlockDetail{}, false
				}
				aln, ok := bandedAffineAlign(queryGap, targetGap, absInt((qGapEnd-qGapStart)-(tGapEnd-tGapStart))+comparisonRefineBandPad)
				if !ok {
					return comparisonBlockDetail{}, false
				}
				ops = append(ops, aln.Ops...)
			}
		}
		matchStartQ := max(anchor.QPos, coveredQ)
		matchStartT := max(anchor.TTrans, coveredT)
		matchLen := min(anchor.QPos+comparisonMinimizerK-matchStartQ, anchor.TTrans+comparisonMinimizerK-matchStartT)
		if matchLen > 0 {
			ops = appendRepeatedOp(ops, 'M', matchLen)
			coveredQ = matchStartQ + matchLen
			coveredT = matchStartT + matchLen
		}
	}
	if coveredQ != int(chain.Summary.QueryEnd) || coveredT != chain.OrientedEnd {
		return comparisonBlockDetail{}, false
	}
	detail := comparisonBlockDetail{
		Summary: chain.Summary,
		Ops:     string(ops),
	}
	aln := affineAlignment{Ops: ops}
	detail.Summary.PercentIdentX100 = aln.percentIdentityX100()
	if int(detail.Summary.PercentIdentX100) < comparisonMinPercentIdentX100 {
		return comparisonBlockDetail{}, false
	}
	detail.Variants = aln.variantsForBlock(detail.Summary)
	return detail, true
}

func exactComparisonBlockPercentIdentity(query, target *comparisonGenome, summary ComparisonBlock) (uint16, bool) {
	if query == nil || target == nil {
		return 0, false
	}
	qStart := int(summary.QueryStart)
	qEnd := int(summary.QueryEnd)
	tStart := int(summary.TargetStart)
	tEnd := int(summary.TargetEnd)
	if qStart < 0 || qEnd < qStart || qEnd > len(query.Sequence) {
		return 0, false
	}
	if tStart < 0 || tEnd < tStart || tEnd > len(target.Sequence) {
		return 0, false
	}
	qLen := qEnd - qStart
	tLen := tEnd - tStart
	if qLen != tLen {
		return 0, false
	}
	querySeq := query.Sequence[qStart:qEnd]
	targetSeq, ok := orientedTargetSlice(target, summary.SameStrand, tStart, tEnd)
	if !ok {
		return 0, false
	}
	if querySeq == targetSeq {
		return 10000, true
	}
	return 0, false
}

func orientedTargetSlice(target *comparisonGenome, sameStrand bool, start int, end int) (string, bool) {
	if target == nil || start < 0 || end < start || end > target.Length {
		return "", false
	}
	if sameStrand {
		return target.Sequence[start:end], true
	}
	actualStart := target.Length - end
	actualEnd := target.Length - start
	if actualStart < 0 || actualEnd < actualStart || actualEnd > len(target.Sequence) {
		return "", false
	}
	return reverseComplementString(target.Sequence[actualStart:actualEnd]), true
}

func appendRepeatedOp(dst []byte, op byte, n int) []byte {
	for i := 0; i < n; i++ {
		dst = append(dst, op)
	}
	return dst
}

type affineAlignment struct {
	Ops []byte
}

func (a affineAlignment) percentIdentityX100() uint16 {
	matches := 0
	aligned := 0
	for _, op := range a.Ops {
		switch op {
		case 'M':
			matches++
			aligned++
		case 'X', 'I', 'D':
			aligned++
		}
	}
	if aligned == 0 {
		return 0
	}
	pct := int(math.Round(10000 * float64(matches) / float64(aligned)))
	if pct < 0 {
		pct = 0
	}
	if pct > 10000 {
		pct = 10000
	}
	return uint16(pct)
}

func (a affineAlignment) variantsForBlock(summary ComparisonBlock) []comparisonVariant {
	if len(a.Ops) == 0 {
		return nil
	}
	var out []comparisonVariant
	qPos := int(summary.QueryStart)
	tPos := int(summary.TargetStart)
	if !summary.SameStrand {
		tPos = int(summary.TargetEnd) - 1
	}
	for i := 0; i < len(a.Ops); {
		op := a.Ops[i]
		j := i + 1
		for j < len(a.Ops) && a.Ops[j] == op {
			j++
		}
		runLen := j - i
		switch op {
		case 'M':
			qPos += runLen
			if summary.SameStrand {
				tPos += runLen
			} else {
				tPos -= runLen
			}
		case 'X':
			for k := 0; k < runLen; k++ {
				out = append(out, comparisonVariant{
					Kind:      'X',
					QueryPos:  uint32(qPos),
					TargetPos: uint32(tPos),
				})
				qPos++
				if summary.SameStrand {
					tPos++
				} else {
					tPos--
				}
			}
		case 'I':
			out = append(out, comparisonVariant{
				Kind:      'I',
				QueryPos:  uint32(qPos),
				TargetPos: uint32(tPos),
				AltBases:  strings.Repeat("N", runLen),
			})
			qPos += runLen
		case 'D':
			out = append(out, comparisonVariant{
				Kind:      'D',
				QueryPos:  uint32(qPos),
				TargetPos: uint32(tPos),
				RefBases:  strings.Repeat("N", runLen),
			})
			if summary.SameStrand {
				tPos += runLen
			} else {
				tPos -= runLen
			}
		}
		i = j
	}
	return out
}

func (d comparisonBlockDetail) info() ComparisonBlockDetail {
	variants := make([]ComparisonVariantInfo, 0, len(d.Variants))
	for _, v := range d.Variants {
		variants = append(variants, ComparisonVariantInfo{
			Kind:      v.Kind,
			QueryPos:  v.QueryPos,
			TargetPos: v.TargetPos,
			RefBases:  v.RefBases,
			AltBases:  v.AltBases,
		})
	}
	return ComparisonBlockDetail{
		Block:    d.Summary,
		Ops:      d.Ops,
		Variants: variants,
	}
}

func bandedAffineAlign(query, target string, band int) (affineAlignment, bool) {
	m := len(query)
	n := len(target)
	if m == 0 && n == 0 {
		return affineAlignment{}, true
	}
	const negInf = -1 << 30
	M := make([][]int, m+1)
	Ix := make([][]int, m+1)
	Iy := make([][]int, m+1)
	traceM := make([][]byte, m+1)
	traceIx := make([][]byte, m+1)
	traceIy := make([][]byte, m+1)
	valid := make([][]bool, m+1)
	for i := 0; i <= m; i++ {
		M[i] = make([]int, n+1)
		Ix[i] = make([]int, n+1)
		Iy[i] = make([]int, n+1)
		traceM[i] = make([]byte, n+1)
		traceIx[i] = make([]byte, n+1)
		traceIy[i] = make([]byte, n+1)
		valid[i] = make([]bool, n+1)
		for j := 0; j <= n; j++ {
			M[i][j] = negInf
			Ix[i][j] = negInf
			Iy[i][j] = negInf
		}
	}
	centerDelta := n - m
	inBand := func(i, j int) bool {
		return absInt((j-i)-centerDelta) <= band
	}
	for i := 0; i <= m; i++ {
		for j := 0; j <= n; j++ {
			if !inBand(i, j) {
				continue
			}
			valid[i][j] = true
		}
	}
	if !valid[m][n] {
		return affineAlignment{}, false
	}
	M[0][0] = 0
	for i := 1; i <= m; i++ {
		if !valid[i][0] {
			continue
		}
		if i == 1 {
			Ix[i][0] = comparisonAffineGapOpen + comparisonAffineGapExtend
			traceIx[i][0] = 'M'
		} else if Ix[i-1][0] > negInf {
			Ix[i][0] = Ix[i-1][0] + comparisonAffineGapExtend
			traceIx[i][0] = 'X'
		}
	}
	for j := 1; j <= n; j++ {
		if !valid[0][j] {
			continue
		}
		if j == 1 {
			Iy[0][j] = comparisonAffineGapOpen + comparisonAffineGapExtend
			traceIy[0][j] = 'M'
		} else if Iy[0][j-1] > negInf {
			Iy[0][j] = Iy[0][j-1] + comparisonAffineGapExtend
			traceIy[0][j] = 'Y'
		}
	}
	for i := 1; i <= m; i++ {
		for j := 1; j <= n; j++ {
			if !valid[i][j] {
				continue
			}
			bestM := M[i-1][j-1]
			traceM[i][j] = 'M'
			if Ix[i-1][j-1] > bestM {
				bestM = Ix[i-1][j-1]
				traceM[i][j] = 'X'
			}
			if Iy[i-1][j-1] > bestM {
				bestM = Iy[i-1][j-1]
				traceM[i][j] = 'Y'
			}
			if bestM > negInf {
				score := comparisonAffineMismatch
				if query[i-1] == target[j-1] {
					score = comparisonAffineMatch
				}
				M[i][j] = bestM + score
			}
			fromM := M[i-1][j]
			fromX := Ix[i-1][j]
			if fromM > negInf {
				fromM += comparisonAffineGapOpen + comparisonAffineGapExtend
			}
			if fromX > negInf {
				fromX += comparisonAffineGapExtend
			}
			if fromM >= fromX {
				Ix[i][j] = fromM
				traceIx[i][j] = 'M'
			} else {
				Ix[i][j] = fromX
				traceIx[i][j] = 'X'
			}
			fromM = M[i][j-1]
			fromY := Iy[i][j-1]
			if fromM > negInf {
				fromM += comparisonAffineGapOpen + comparisonAffineGapExtend
			}
			if fromY > negInf {
				fromY += comparisonAffineGapExtend
			}
			if fromM >= fromY {
				Iy[i][j] = fromM
				traceIy[i][j] = 'M'
			} else {
				Iy[i][j] = fromY
				traceIy[i][j] = 'Y'
			}
		}
	}
	state := byte('M')
	best := M[m][n]
	if Ix[m][n] > best {
		best = Ix[m][n]
		state = 'X'
	}
	if Iy[m][n] > best {
		best = Iy[m][n]
		state = 'Y'
	}
	if best <= negInf {
		return affineAlignment{}, false
	}
	ops := make([]byte, 0, m+n)
	i, j := m, n
	for i > 0 || j > 0 {
		switch state {
		case 'M':
			prev := traceM[i][j]
			if i <= 0 || j <= 0 {
				return affineAlignment{}, false
			}
			if query[i-1] == target[j-1] {
				ops = append(ops, 'M')
			} else {
				ops = append(ops, 'X')
			}
			i--
			j--
			state = prev
		case 'X':
			prev := traceIx[i][j]
			if i <= 0 {
				return affineAlignment{}, false
			}
			ops = append(ops, 'I')
			i--
			state = prev
		case 'Y':
			prev := traceIy[i][j]
			if j <= 0 {
				return affineAlignment{}, false
			}
			ops = append(ops, 'D')
			j--
			state = prev
		default:
			return affineAlignment{}, false
		}
	}
	for l, r := 0, len(ops)-1; l < r; l, r = l+1, r-1 {
		ops[l], ops[r] = ops[r], ops[l]
	}
	return affineAlignment{Ops: ops}, true
}

func buildSeedIndex(seeds []minimizerSeed) map[uint64][]int {
	index := make(map[uint64][]int, len(seeds))
	for _, seed := range seeds {
		index[seed.Hash] = append(index[seed.Hash], seed.Pos)
	}
	return index
}

func extractMinimizers(seq string, k int, window int, reverse bool) []minimizerSeed {
	if k <= 0 || window <= 0 || len(seq) < k {
		return nil
	}
	type queueEntry struct {
		hash    uint64
		pos     int
		ordinal int
	}
	mask := uint64(1<<(2*k)) - 1
	var forwardHash uint64
	var reverseHash uint64
	validRun := 0
	runOrdinal := 0
	deque := make([]queueEntry, 0, window)
	out := make([]minimizerSeed, 0, len(seq)/window+1)
	lastPos := -1
	lastHash := uint64(0)
	for i := 0; i < len(seq); i++ {
		base, ok := encodeDNA2Bit(seq[i])
		if !ok {
			validRun = 0
			runOrdinal = 0
			forwardHash = 0
			reverseHash = 0
			deque = deque[:0]
			continue
		}
		forwardHash = ((forwardHash << 2) | uint64(base)) & mask
		reverseHash = (reverseHash >> 2) | (uint64(base^3) << (2 * (k - 1)))
		validRun++
		if validRun < k {
			continue
		}
		hash := forwardHash
		if reverse {
			hash = reverseHash
		}
		pos := i - k + 1
		for len(deque) > 0 && deque[len(deque)-1].hash >= hash {
			deque = deque[:len(deque)-1]
		}
		deque = append(deque, queueEntry{hash: hash, pos: pos, ordinal: runOrdinal})
		for len(deque) > 0 && runOrdinal-deque[0].ordinal >= window {
			deque = deque[1:]
		}
		if runOrdinal >= window-1 && len(deque) > 0 {
			entry := deque[0]
			if entry.pos != lastPos || entry.hash != lastHash {
				out = append(out, minimizerSeed{Hash: entry.hash, Pos: entry.pos})
				lastPos = entry.pos
				lastHash = entry.hash
			}
		}
		runOrdinal++
	}
	return out
}

func encodeDNA2Bit(b byte) (uint8, bool) {
	switch b {
	case 'A', 'a':
		return 0, true
	case 'C', 'c':
		return 1, true
	case 'G', 'g':
		return 2, true
	case 'T', 't', 'U', 'u':
		return 3, true
	default:
		return 0, false
	}
}

func encodeComparisonGenomes(genomes []ComparisonGenomeInfo) []byte {
	total := 2
	for _, genome := range genomes {
		total += 16 + len(genome.Name) + len(genome.Path)
		for _, segment := range genome.Segments {
			total += 14 + len(segment.Name)
		}
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(genomes)))
	off := 2
	for _, genome := range genomes {
		binary.LittleEndian.PutUint16(buf[off:off+2], genome.ID)
		binary.LittleEndian.PutUint32(buf[off+2:off+6], genome.Length)
		binary.LittleEndian.PutUint16(buf[off+6:off+8], genome.SegmentCount)
		binary.LittleEndian.PutUint32(buf[off+8:off+12], genome.FeatureCount)
		binary.LittleEndian.PutUint16(buf[off+12:off+14], uint16(len(genome.Name)))
		copy(buf[off+14:off+14+len(genome.Name)], genome.Name)
		off += 14 + len(genome.Name)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(genome.Path)))
		copy(buf[off+2:off+2+len(genome.Path)], genome.Path)
		off += 2 + len(genome.Path)
		for _, segment := range genome.Segments {
			binary.LittleEndian.PutUint32(buf[off:off+4], segment.Start)
			binary.LittleEndian.PutUint32(buf[off+4:off+8], segment.End)
			binary.LittleEndian.PutUint32(buf[off+8:off+12], segment.FeatureCount)
			binary.LittleEndian.PutUint16(buf[off+12:off+14], uint16(len(segment.Name)))
			copy(buf[off+14:off+14+len(segment.Name)], segment.Name)
			off += 14 + len(segment.Name)
		}
	}
	return buf
}

func encodeComparisonPairs(pairs []ComparisonPairInfo) []byte {
	buf := make([]byte, 2+13*len(pairs))
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(pairs)))
	off := 2
	for _, pair := range pairs {
		binary.LittleEndian.PutUint16(buf[off:off+2], pair.ID)
		binary.LittleEndian.PutUint16(buf[off+2:off+4], pair.TopGenomeID)
		binary.LittleEndian.PutUint16(buf[off+4:off+6], pair.BottomGenomeID)
		binary.LittleEndian.PutUint32(buf[off+6:off+10], pair.BlockCount)
		buf[off+10] = pair.Status
		off += 13
	}
	return buf
}

func encodeComparisonBlocks(blocks []ComparisonBlock) []byte {
	buf := make([]byte, 2+19*len(blocks))
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(blocks)))
	off := 2
	for _, block := range blocks {
		binary.LittleEndian.PutUint32(buf[off:off+4], block.QueryStart)
		binary.LittleEndian.PutUint32(buf[off+4:off+8], block.QueryEnd)
		binary.LittleEndian.PutUint32(buf[off+8:off+12], block.TargetStart)
		binary.LittleEndian.PutUint32(buf[off+12:off+16], block.TargetEnd)
		binary.LittleEndian.PutUint16(buf[off+16:off+18], block.PercentIdentX100)
		if block.SameStrand {
			buf[off+18] = 1
		}
		off += 19
	}
	return buf
}

func encodeComparisonBlockDetail(detail ComparisonBlockDetail) []byte {
	total := 23 + len(detail.Ops) + 2
	for _, variant := range detail.Variants {
		total += 13 + len(variant.RefBases) + len(variant.AltBases)
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint32(buf[0:4], detail.Block.QueryStart)
	binary.LittleEndian.PutUint32(buf[4:8], detail.Block.QueryEnd)
	binary.LittleEndian.PutUint32(buf[8:12], detail.Block.TargetStart)
	binary.LittleEndian.PutUint32(buf[12:16], detail.Block.TargetEnd)
	binary.LittleEndian.PutUint16(buf[16:18], detail.Block.PercentIdentX100)
	if detail.Block.SameStrand {
		buf[18] = 1
	}
	binary.LittleEndian.PutUint32(buf[19:23], uint32(len(detail.Ops)))
	copy(buf[23:23+len(detail.Ops)], detail.Ops)
	off := 23 + len(detail.Ops)
	binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(detail.Variants)))
	off += 2
	for _, variant := range detail.Variants {
		buf[off] = variant.Kind
		binary.LittleEndian.PutUint32(buf[off+1:off+5], variant.QueryPos)
		binary.LittleEndian.PutUint32(buf[off+5:off+9], variant.TargetPos)
		binary.LittleEndian.PutUint16(buf[off+9:off+11], uint16(len(variant.RefBases)))
		binary.LittleEndian.PutUint16(buf[off+11:off+13], uint16(len(variant.AltBases)))
		off += 13
		copy(buf[off:off+len(variant.RefBases)], variant.RefBases)
		off += len(variant.RefBases)
		copy(buf[off:off+len(variant.AltBases)], variant.AltBases)
		off += len(variant.AltBases)
	}
	return buf
}
