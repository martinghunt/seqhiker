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
	comparisonConcatGapBP            = 50
	maxComparisonGenomes             = 8
	comparisonStatusPending    uint8 = 1
	comparisonStatusReady      uint8 = 2
	comparisonMinimizerK             = 15
	comparisonMinimizerWindow        = 10
	comparisonMaxSeedHits            = 64
	comparisonMinAnchorCount         = 3
	comparisonMinBlockLen            = 100
	comparisonMaxAnchorGap           = 20000
	comparisonMaxDiagonalDrift       = 2500
	comparisonDiagonalBinSize        = 512
	comparisonRefineMaxSpan          = 16384
	comparisonRefineBandPad          = 96
	comparisonAffineMatch            = 2
	comparisonAffineMismatch         = -3
	comparisonAffineGapOpen          = -5
	comparisonAffineGapExtend        = -1
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
	Blocks         []comparisonBlockDetail
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

func encodeSequenceSlice(start int, end int, slice string) []byte {
	buf := make([]byte, 12+len(slice))
	binary.LittleEndian.PutUint32(buf[0:4], uint32(start))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(end))
	binary.LittleEndian.PutUint32(buf[8:12], uint32(len(slice)))
	copy(buf[12:], slice)
	return buf
}

func loadGenomeSnapshot(path string) (GenomeSnapshot, bool, error) {
	entries, err := gatherInputFiles(path)
	if err != nil {
		return GenomeSnapshot{}, false, err
	}

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
	e.mu.RLock()
	defer e.mu.RUnlock()

	out := make([]ComparisonPairInfo, 0, len(e.comparisonPairOrder))
	for _, pairID := range e.comparisonPairOrder {
		pair := e.comparisonPairs[pairID]
		if pair == nil {
			continue
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
	e.mu.RLock()
	defer e.mu.RUnlock()

	pair, ok := e.comparisonPairs[pairID]
	if !ok || pair == nil {
		return nil, fmt.Errorf("comparison pair %d not found", pairID)
	}
	out := make([]ComparisonBlock, 0, len(pair.Blocks))
	for _, block := range pair.Blocks {
		out = append(out, block.Summary)
	}
	return out, nil
}

func (e *Engine) GetComparisonBlocksByGenomes(queryGenomeID uint16, targetGenomeID uint16) ([]ComparisonBlock, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	details, storedQueryID, storedTargetID, err := e.getOrBuildComparisonPairLocked(queryGenomeID, targetGenomeID)
	if err != nil {
		return nil, err
	}
	out := make([]ComparisonBlock, 0, len(details))
	reverse := storedQueryID != queryGenomeID || storedTargetID != targetGenomeID
	for _, detail := range details {
		summary := detail.Summary
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
	e.mu.RLock()
	query := e.comparisonGenomes[queryGenomeID]
	target := e.comparisonGenomes[targetGenomeID]
	e.mu.RUnlock()
	if query == nil || target == nil {
		return ComparisonBlockDetail{}, fmt.Errorf("comparison genomes %d/%d not loaded", queryGenomeID, targetGenomeID)
	}
	detail, ok := buildComparisonBlockDetail(query, target, block)
	if !ok {
		return ComparisonBlockDetail{}, fmt.Errorf("unable to refine comparison block")
	}
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
		details, storedQueryID, storedTargetID, err := e.getOrBuildComparisonPairLocked(pair.TopGenomeID, pair.BottomGenomeID)
		if err == nil && storedQueryID == pair.TopGenomeID && storedTargetID == pair.BottomGenomeID {
			pair.Blocks = details
			pair.Status = comparisonStatusReady
		}
		e.comparisonPairs[pairID] = pair
		e.comparisonPairOrder = append(e.comparisonPairOrder, pairID)
	}
}

func (e *Engine) getOrBuildComparisonPairLocked(queryGenomeID uint16, targetGenomeID uint16) ([]comparisonBlockDetail, uint16, uint16, error) {
	if queryGenomeID == 0 || targetGenomeID == 0 || queryGenomeID == targetGenomeID {
		return nil, 0, 0, fmt.Errorf("invalid comparison genome pair %d/%d", queryGenomeID, targetGenomeID)
	}
	query := e.comparisonGenomes[queryGenomeID]
	target := e.comparisonGenomes[targetGenomeID]
	if query == nil || target == nil {
		return nil, 0, 0, fmt.Errorf("comparison genomes %d/%d not loaded", queryGenomeID, targetGenomeID)
	}
	for _, pair := range e.comparisonPairs {
		if pair == nil {
			continue
		}
		if pair.TopGenomeID == queryGenomeID && pair.BottomGenomeID == targetGenomeID {
			if pair.Status != comparisonStatusReady {
				pair.Blocks = buildComparisonBlocks(query, target)
				pair.Status = comparisonStatusReady
			}
			return pair.Blocks, pair.TopGenomeID, pair.BottomGenomeID, nil
		}
		if pair.TopGenomeID == targetGenomeID && pair.BottomGenomeID == queryGenomeID {
			if pair.Status != comparisonStatusReady {
				pair.Blocks = buildComparisonBlocks(target, query)
				pair.Status = comparisonStatusReady
			}
			return pair.Blocks, pair.TopGenomeID, pair.BottomGenomeID, nil
		}
	}
	details := buildComparisonBlocks(query, target)
	return details, queryGenomeID, targetGenomeID, nil
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
	if max(qSpan, tSpan) > comparisonRefineMaxSpan {
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
	block.Variants = aln.variantsForBlock(block.Summary)
	block.Ops = string(aln.Ops)
	return block, true
}

func buildComparisonBlocks(query, target *comparisonGenome) []comparisonBlockDetail {
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
				sameAnchors = append(sameAnchors, comparisonAnchor{
					QPos:   seed.Pos,
					TPos:   tPos,
					TTrans: tPos,
				})
			}
		}
		if positions, ok := targetReverse[seed.Hash]; ok && len(positions) > 0 && len(positions) <= comparisonMaxSeedHits {
			for _, tPos := range positions {
				tTrans := target.Length - (tPos + comparisonMinimizerK)
				if tTrans < 0 {
					continue
				}
				reverseAnchors = append(reverseAnchors, comparisonAnchor{
					QPos:   seed.Pos,
					TPos:   tPos,
					TTrans: tTrans,
				})
			}
		}
	}

	blocks := make([]comparisonBlockDetail, 0, 64)
	blocks = append(blocks, buildBlocksFromAnchors(sameAnchors, true)...)
	blocks = append(blocks, buildBlocksFromAnchors(reverseAnchors, false)...)
	sort.Slice(blocks, func(i, j int) bool {
		if blocks[i].Summary.QueryStart == blocks[j].Summary.QueryStart {
			if blocks[i].Summary.QueryEnd == blocks[j].Summary.QueryEnd {
				return blocks[i].Summary.TargetStart < blocks[j].Summary.TargetStart
			}
			return blocks[i].Summary.QueryEnd < blocks[j].Summary.QueryEnd
		}
		return blocks[i].Summary.QueryStart < blocks[j].Summary.QueryStart
	})
	for i := range blocks {
		refineComparisonBlock(query, target, &blocks[i])
	}
	return blocks
}

func buildBlocksFromAnchors(anchors []comparisonAnchor, sameStrand bool) []comparisonBlockDetail {
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
	blocks := make([]comparisonBlockDetail, 0, len(anchors)/comparisonMinAnchorCount)
	for _, key := range bucketKeys {
		blocks = append(blocks, buildBlocksFromDiagonalBucket(diagBuckets[key], sameStrand)...)
	}
	return blocks
}

func buildBlocksFromDiagonalBucket(anchors []comparisonAnchor, sameStrand bool) []comparisonBlockDetail {
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

	blocks := make([]comparisonBlockDetail, 0, len(chains))
	for _, chain := range chains {
		block := comparisonChainToBlock(chain)
		if block.QueryEnd > block.QueryStart && block.TargetEnd > block.TargetStart {
			blocks = append(blocks, comparisonBlockDetail{Summary: block})
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
	qStart := chain.Anchors[0].QPos
	qEnd := chain.Anchors[0].QPos + comparisonMinimizerK
	tStart := chain.Anchors[0].TPos
	tEnd := chain.Anchors[0].TPos + comparisonMinimizerK
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
	return ComparisonBlock{
		QueryStart:       uint32(qStart),
		QueryEnd:         uint32(qEnd),
		TargetStart:      uint32(tStart),
		TargetEnd:        uint32(tEnd),
		PercentIdentX100: pid,
		SameStrand:       chain.SameStrand,
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
