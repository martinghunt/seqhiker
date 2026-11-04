package main

import (
	"context"
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"path/filepath"
	"sort"
	"strings"

	"github.com/martinghunt/faqt/align"
)

const (
	comparisonConcatGapBP                = 50
	maxComparisonGenomes                 = 8
	comparisonStatusPending        uint8 = 1
	comparisonStatusReady          uint8 = 2
	comparisonRedundantOverlapX100       = 9000
	comparisonMaxDetailOps               = 200000
)

type comparisonSegment struct {
	Name         string
	Start        int
	End          int
	FeatureCount int
	RawSequence  string
	RawFeatures  []Feature
	Reversed     bool
}

type comparisonGenome struct {
	Prepared *align.Genome
	ID       uint16
	Name     string
	Path     string
	Length   int
	Sequence string
	Features []Feature
	Segments []comparisonSegment
}

type comparisonPair struct {
	ID              uint16
	TopGenomeID     uint16
	BottomGenomeID  uint16
	Status          uint8
	CanonicalBlocks []comparisonCanonicalBlock
	DetailPath      string
	DetailIndex     map[string]comparisonDetailIndexEntry
}

type comparisonCanonicalBlock struct {
	Ops              []align.Op
	QuerySegment     int
	QueryStart       int
	QueryEnd         int
	TargetSegment    int
	TargetStart      int
	TargetEnd        int
	PercentIdentX100 uint16
	SameStrand       bool
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
			_ = e.ensureComparisonPairBlocksLocked(pair)
		}
		out = append(out, ComparisonPairInfo{
			ID:             pair.ID,
			TopGenomeID:    pair.TopGenomeID,
			BottomGenomeID: pair.BottomGenomeID,
			BlockCount:     uint32(len(pair.CanonicalBlocks)),
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
		if err := e.ensureComparisonPairBlocksLocked(pair); err != nil {
			return nil, err
		}
	}
	query := e.comparisonGenomes[pair.TopGenomeID]
	target := e.comparisonGenomes[pair.BottomGenomeID]
	return displayComparisonBlocks(query, target, pair.CanonicalBlocks), nil
}

func (e *Engine) GetComparisonBlocksByGenomes(queryGenomeID uint16, targetGenomeID uint16) ([]ComparisonBlock, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	blocks, _, _, err := e.getOrBuildComparisonPairLocked(queryGenomeID, targetGenomeID)
	if err != nil {
		return nil, err
	}
	return blocks, nil
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

func buildComparisonGenome(path string, snapshot GenomeSnapshot) (*comparisonGenome, error) {
	chrNames := make([]string, 0, len(snapshot.ChromLength))
	for chr := range snapshot.ChromLength {
		chrNames = append(chrNames, chr)
	}
	sort.Strings(chrNames)
	if len(chrNames) == 0 {
		return nil, errors.New("comparison genome has no chromosomes")
	}

	segments := make([]comparisonSegment, 0, len(chrNames))
	for _, chr := range chrNames {
		chrFeatures := cloneFeatures(snapshot.Features[chr])
		segments = append(segments, comparisonSegment{
			Name:        chr,
			RawSequence: snapshot.Sequences[chr],
			RawFeatures: chrFeatures,
			Reversed:    false,
		})
	}
	name := filepath.Base(path)
	if ext := filepath.Ext(name); ext != "" {
		name = strings.TrimSuffix(name, ext)
	}
	if name == "" {
		name = "genome"
	}
	genome := &comparisonGenome{
		Name:     name,
		Path:     path,
		Segments: segments,
	}
	genome.rebuildDerived()
	return genome, nil
}

func (g *comparisonGenome) rebuildDerived() {
	g.Prepared = nil
	var seqBuilder strings.Builder
	features := make([]Feature, 0, 1024)
	offset := 0
	for i := range g.Segments {
		segment := &g.Segments[i]
		if i > 0 {
			seqBuilder.WriteString(strings.Repeat("N", comparisonConcatGapBP))
			offset += comparisonConcatGapBP
		}
		seq := segment.RawSequence
		if segment.Reversed {
			seq = reverseComplementString(seq)
		}
		segment.Start = offset
		seqBuilder.WriteString(seq)
		offset += len(seq)
		segment.End = offset
		segment.FeatureCount = len(segment.RawFeatures)
		for _, rawFeature := range segment.RawFeatures {
			adjusted := rawFeature
			if segment.Reversed {
				adjusted = reverseFeatureForLength(adjusted, len(segment.RawSequence))
			}
			adjusted.SeqName = segment.Name
			adjusted.Start += segment.Start
			adjusted.End += segment.Start
			features = append(features, adjusted)
		}
	}
	sort.Slice(features, func(i, j int) bool {
		if features[i].Start == features[j].Start {
			return features[i].End < features[j].End
		}
		return features[i].Start < features[j].Start
	})
	g.Sequence = seqBuilder.String()
	g.Length = len(g.Sequence)
	g.Features = features
}

func (g *comparisonGenome) info() ComparisonGenomeInfo {
	segments := make([]ComparisonSegmentInfo, 0, len(g.Segments))
	for _, segment := range g.Segments {
		segments = append(segments, ComparisonSegmentInfo{
			Name:         segment.Name,
			Start:        uint32(segment.Start),
			End:          uint32(segment.End),
			FeatureCount: uint32(segment.FeatureCount),
			Reversed:     segment.Reversed,
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
			ID:              pairID,
			TopGenomeID:     e.comparisonGenomeOrder[i],
			BottomGenomeID:  e.comparisonGenomeOrder[i+1],
			Status:          comparisonStatusPending,
			CanonicalBlocks: nil,
		}
		e.comparisonPairs[pairID] = pair
		e.comparisonPairOrder = append(e.comparisonPairOrder, pairID)
	}
}

func (e *Engine) ensureComparisonPairBlocksLocked(pair *comparisonPair) error {
	if pair == nil {
		return nil
	}
	if pair.Status == comparisonStatusReady {
		return nil
	}
	query := e.comparisonGenomes[pair.TopGenomeID]
	target := e.comparisonGenomes[pair.BottomGenomeID]
	if query == nil || target == nil {
		return fmt.Errorf("comparison genomes %d/%d not loaded", pair.TopGenomeID, pair.BottomGenomeID)
	}
	progress := e.beginComparisonProgress(query, target)
	defer progress.finish()
	blocks, err := alignCanonicalComparisonBlocks(context.Background(), query, target, progress, comparisonAlignOptions())
	if err != nil {
		return err
	}
	pair.CanonicalBlocks = blocks
	pair.DetailPath = ""
	pair.DetailIndex = nil
	pair.Status = comparisonStatusReady
	return nil
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
	for _, pair := range e.comparisonPairs {
		if pair == nil {
			continue
		}
		if pair.TopGenomeID == queryGenomeID && pair.BottomGenomeID == targetGenomeID {
			if err := e.ensureComparisonPairBlocksLocked(pair); err != nil {
				return nil, 0, 0, err
			}
			return displayComparisonBlocks(query, target, pair.CanonicalBlocks), queryGenomeID, targetGenomeID, nil
		}
		if pair.TopGenomeID == targetGenomeID && pair.BottomGenomeID == queryGenomeID {
			if err := e.ensureComparisonPairBlocksLocked(pair); err != nil {
				return nil, 0, 0, err
			}
			storedTop := e.comparisonGenomes[pair.TopGenomeID]
			storedBottom := e.comparisonGenomes[pair.BottomGenomeID]
			return swapComparisonBlocks(displayComparisonBlocks(storedTop, storedBottom, pair.CanonicalBlocks)), queryGenomeID, targetGenomeID, nil
		}
	}
	progress := e.beginComparisonProgress(query, target)
	defer progress.finish()
	canonicalBlocks, err := alignCanonicalComparisonBlocks(context.Background(), query, target, progress, comparisonAlignOptions())
	if err != nil {
		return nil, 0, 0, err
	}
	return displayComparisonBlocks(query, target, canonicalBlocks), queryGenomeID, targetGenomeID, nil
}

type comparisonProgressTracker struct {
	engine    *Engine
	key       string
	total     uint64
	completed uint64
}

func comparisonProgressKey(a, b uint16) string {
	if a > b {
		a, b = b, a
	}
	return fmt.Sprintf("%d:%d", a, b)
}

func (e *Engine) beginComparisonProgress(query, target *comparisonGenome) *comparisonProgressTracker {
	if e == nil || query == nil || target == nil {
		return nil
	}
	totalTargetLen := uint64(comparisonRawSegmentsLength(target))
	var total uint64
	for _, segment := range query.Segments {
		total += uint64(len(segment.RawSequence)) * totalTargetLen
	}
	if total == 0 {
		total = 1
	}
	tracker := &comparisonProgressTracker{
		engine: e,
		key:    comparisonProgressKey(query.ID, target.ID),
		total:  total,
	}
	tracker.update("Preparing comparison", 0)
	return tracker
}

func (t *comparisonProgressTracker) update(message string, additionalCompleted uint64) {
	if t == nil || t.engine == nil {
		return
	}
	completed := t.completed + additionalCompleted
	if completed > t.total {
		completed = t.total
	}
	progressX100 := uint32(0)
	if t.total > 0 {
		progressX100 = uint32(completed * 10000 / t.total)
	}
	t.engine.comparisonProgressMu.Lock()
	t.engine.comparisonProgress[t.key] = ComparisonProgressInfo{
		Active:       true,
		ProgressX100: progressX100,
		Message:      message,
	}
	t.engine.comparisonProgressMu.Unlock()
}

func (t *comparisonProgressTracker) addCompleted(units uint64) {
	if t == nil {
		return
	}
	t.completed += units
	if t.completed > t.total {
		t.completed = t.total
	}
}

func (t *comparisonProgressTracker) complete(message string, units uint64) {
	if t == nil {
		return
	}
	t.update(message, units)
	t.addCompleted(units)
}

func (t *comparisonProgressTracker) updateCurrent(message string, currentUnits uint64, currentFraction float64) {
	if t == nil {
		return
	}
	if currentFraction < 0 {
		currentFraction = 0
	}
	if currentFraction > 1 {
		currentFraction = 1
	}
	additionalCompleted := uint64(float64(currentUnits) * currentFraction)
	if currentFraction >= 1 || additionalCompleted > currentUnits {
		additionalCompleted = currentUnits
	}
	t.update(message, additionalCompleted)
}

func (t *comparisonProgressTracker) finish() {
	if t == nil || t.engine == nil {
		return
	}
	t.engine.comparisonProgressMu.Lock()
	delete(t.engine.comparisonProgress, t.key)
	t.engine.comparisonProgressMu.Unlock()
}

func comparisonRawSegmentsLength(genome *comparisonGenome) int {
	if genome == nil {
		return 0
	}
	total := 0
	for _, segment := range genome.Segments {
		total += len(segment.RawSequence)
	}
	return total
}

func (e *Engine) clearComparisonProgress() {
	if e == nil {
		return
	}
	e.comparisonProgressMu.Lock()
	e.comparisonProgress = make(map[string]ComparisonProgressInfo)
	e.comparisonProgressMu.Unlock()
}

func (e *Engine) GetComparisonProgress(queryGenomeID uint16, targetGenomeID uint16) ComparisonProgressInfo {
	if e == nil {
		return ComparisonProgressInfo{}
	}
	key := comparisonProgressKey(queryGenomeID, targetGenomeID)
	e.comparisonProgressMu.RLock()
	progress := e.comparisonProgress[key]
	e.comparisonProgressMu.RUnlock()
	return progress
}

func comparisonCanonicalBlockIsTrivialSelfOverlap(query, target *comparisonGenome, block comparisonCanonicalBlock) bool {
	if !comparisonGenomesAreSameSource(query, target) || !block.SameStrand || block.QuerySegment != block.TargetSegment {
		return false
	}
	qLen := block.QueryEnd - block.QueryStart
	tLen := block.TargetEnd - block.TargetStart
	if qLen <= 0 || tLen <= 0 {
		return true
	}
	overlap := intervalOverlapInt(block.QueryStart, block.QueryEnd, block.TargetStart, block.TargetEnd)
	if overlap <= 0 {
		return false
	}
	return overlap*10000 >= min(qLen, tLen)*comparisonRedundantOverlapX100
}

func comparisonGenomesAreSameSource(query, target *comparisonGenome) bool {
	if query == nil || target == nil {
		return false
	}
	if query == target {
		return true
	}
	if query.Path != "" || target.Path != "" {
		return query.Path != "" && filepath.Clean(query.Path) == filepath.Clean(target.Path)
	}
	return false
}

func displayComparisonBlocks(query, target *comparisonGenome, canonicalBlocks []comparisonCanonicalBlock) []ComparisonBlock {
	if query == nil || target == nil || len(canonicalBlocks) == 0 {
		return nil
	}
	query, target = comparisonSegmentsForDisplay(query), comparisonSegmentsForDisplay(target)
	out := make([]ComparisonBlock, 0, len(canonicalBlocks))
	for _, block := range canonicalBlocks {
		displayBlock, ok := displayComparisonBlock(query, target, block)
		if !ok {
			continue
		}
		out = append(out, displayBlock)
	}
	sort.Slice(out, func(i, j int) bool { return comparisonBlockLess(out[i], out[j]) })
	return out
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

func displayComparisonBlock(query, target *comparisonGenome, block comparisonCanonicalBlock) (ComparisonBlock, bool) {
	if query == nil || target == nil {
		return ComparisonBlock{}, false
	}
	if block.QuerySegment < 0 || block.QuerySegment >= len(query.Segments) || block.TargetSegment < 0 || block.TargetSegment >= len(target.Segments) {
		return ComparisonBlock{}, false
	}
	querySegment := query.Segments[block.QuerySegment]
	targetSegment := target.Segments[block.TargetSegment]
	queryStart, queryEnd, ok := displayComparisonInterval(querySegment, block.QueryStart, block.QueryEnd)
	if !ok {
		return ComparisonBlock{}, false
	}
	targetStart, targetEnd, ok := displayComparisonInterval(targetSegment, block.TargetStart, block.TargetEnd)
	if !ok {
		return ComparisonBlock{}, false
	}
	sameStrand := block.SameStrand
	if querySegment.Reversed != targetSegment.Reversed {
		sameStrand = !sameStrand
	}
	return ComparisonBlock{
		QueryStart:       uint32(queryStart),
		QueryEnd:         uint32(queryEnd),
		TargetStart:      uint32(targetStart),
		TargetEnd:        uint32(targetEnd),
		PercentIdentX100: block.PercentIdentX100,
		SameStrand:       sameStrand,
	}, true
}

func displayComparisonInterval(segment comparisonSegment, start, end int) (int, int, bool) {
	segmentLen := len(segment.RawSequence)
	if segmentLen <= 0 {
		segmentLen = segment.End - segment.Start
	}
	if start < 0 || end < start || end > segmentLen {
		return 0, 0, false
	}
	if segment.Reversed {
		return segment.Start + (segmentLen - end), segment.Start + (segmentLen - start), true
	}
	return segment.Start + start, segment.Start + end, true
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

func intervalOverlapInt(aStart, aEnd, bStart, bEnd int) int {
	start := max(aStart, bStart)
	end := min(aEnd, bEnd)
	if end <= start {
		return 0
	}
	return end - start
}

func comparisonBlockLess(a, b ComparisonBlock) bool {
	if a.QueryStart == b.QueryStart {
		if a.QueryEnd == b.QueryEnd {
			return a.TargetStart < b.TargetStart
		}
		return a.QueryEnd < b.QueryEnd
	}
	return a.QueryStart < b.QueryStart
}

func canonicalComparisonBlockLess(a, b comparisonCanonicalBlock) bool {
	if a.QuerySegment == b.QuerySegment {
		if a.QueryStart == b.QueryStart {
			if a.TargetSegment == b.TargetSegment {
				if a.TargetStart == b.TargetStart {
					if a.QueryEnd == b.QueryEnd {
						return a.TargetEnd < b.TargetEnd
					}
					return a.QueryEnd < b.QueryEnd
				}
				return a.TargetStart < b.TargetStart
			}
			return a.TargetSegment < b.TargetSegment
		}
		return a.QueryStart < b.QueryStart
	}
	return a.QuerySegment < b.QuerySegment
}

func comparisonPercentIdentityX100(matches, aligned int) uint16 {
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

type comparisonAlignmentOps struct {
	Ops []byte
}

func (a comparisonAlignmentOps) variantsForBlock(summary ComparisonBlock) []comparisonVariant {
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

func encodeComparisonGenomes(genomes []ComparisonGenomeInfo) []byte {
	if len(genomes) > 0xFFFF {
		genomes = genomes[:0xFFFF]
	}
	total := 2
	for _, genome := range genomes {
		name := wireString16(genome.Name)
		path := wireString16(genome.Path)
		total += 16 + len(name) + len(path)
		segments := genome.Segments
		if len(segments) > 0xFFFF {
			segments = segments[:0xFFFF]
		}
		for _, segment := range segments {
			segmentName := wireString16(segment.Name)
			total += 15 + len(segmentName)
		}
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(genomes)))
	off := 2
	for _, genome := range genomes {
		name := wireString16(genome.Name)
		path := wireString16(genome.Path)
		segments := genome.Segments
		if len(segments) > 0xFFFF {
			segments = segments[:0xFFFF]
		}
		binary.LittleEndian.PutUint16(buf[off:off+2], genome.ID)
		binary.LittleEndian.PutUint32(buf[off+2:off+6], genome.Length)
		binary.LittleEndian.PutUint16(buf[off+6:off+8], uint16(len(segments)))
		binary.LittleEndian.PutUint32(buf[off+8:off+12], genome.FeatureCount)
		binary.LittleEndian.PutUint16(buf[off+12:off+14], uint16(len(name)))
		copy(buf[off+14:off+14+len(name)], name)
		off += 14 + len(name)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(path)))
		copy(buf[off+2:off+2+len(path)], path)
		off += 2 + len(path)
		for _, segment := range segments {
			segmentName := wireString16(segment.Name)
			binary.LittleEndian.PutUint32(buf[off:off+4], segment.Start)
			binary.LittleEndian.PutUint32(buf[off+4:off+8], segment.End)
			binary.LittleEndian.PutUint32(buf[off+8:off+12], segment.FeatureCount)
			buf[off+12] = 0
			if segment.Reversed {
				buf[off+12] = 1
			}
			binary.LittleEndian.PutUint16(buf[off+13:off+15], uint16(len(segmentName)))
			copy(buf[off+15:off+15+len(segmentName)], segmentName)
			off += 15 + len(segmentName)
		}
	}
	return buf
}

func encodeComparisonPairs(pairs []ComparisonPairInfo) []byte {
	if len(pairs) > 0xFFFF {
		pairs = pairs[:0xFFFF]
	}
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
	if len(blocks) > 0xFFFF {
		blocks = blocks[:0xFFFF]
	}
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

func encodeComparisonProgress(progress ComparisonProgressInfo) []byte {
	message := wireString16(progress.Message)
	if len(message) > 0xFFFF {
		message = message[:0xFFFF]
	}
	buf := make([]byte, 7+len(message))
	if progress.Active {
		buf[0] = 1
	}
	if progress.ProgressX100 > 10000 {
		progress.ProgressX100 = 10000
	}
	binary.LittleEndian.PutUint32(buf[1:5], progress.ProgressX100)
	binary.LittleEndian.PutUint16(buf[5:7], uint16(len(message)))
	copy(buf[7:], message)
	return buf
}

func encodeComparisonBlockDetail(detail ComparisonBlockDetail) []byte {
	if len(detail.Variants) > 0xFFFF {
		detail.Variants = detail.Variants[:0xFFFF]
	}
	total := 23 + len(detail.Ops) + 2
	for _, variant := range detail.Variants {
		refBases := wireString16(variant.RefBases)
		altBases := wireString16(variant.AltBases)
		total += 13 + len(refBases) + len(altBases)
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
		refBases := wireString16(variant.RefBases)
		altBases := wireString16(variant.AltBases)
		buf[off] = variant.Kind
		binary.LittleEndian.PutUint32(buf[off+1:off+5], variant.QueryPos)
		binary.LittleEndian.PutUint32(buf[off+5:off+9], variant.TargetPos)
		binary.LittleEndian.PutUint16(buf[off+9:off+11], uint16(len(refBases)))
		binary.LittleEndian.PutUint16(buf[off+11:off+13], uint16(len(altBases)))
		off += 13
		copy(buf[off:off+len(refBases)], refBases)
		off += len(refBases)
		copy(buf[off:off+len(altBases)], altBases)
		off += len(altBases)
	}
	return buf
}
