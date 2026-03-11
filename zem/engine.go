package main

import (
	"bufio"
	"container/list"
	"encoding/binary"
	"errors"
	"fmt"
	"io"
	"log"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"sort"
	"strconv"
	"strings"
	"sync"
	"unicode"

	"github.com/biogo/hts/bam"
	"github.com/biogo/hts/sam"
	"github.com/shenwei356/xopen"
)

const baseTileSize = 1024
const (
	readTileCacheKind   uint8 = 1
	covTileCacheKind    uint8 = 2
	plotTileCacheKind   uint8 = 3
	maxScannedTileReads       = 2000000
	snpDetailMaxZoom    uint8 = 5
	plotTileBins              = 256
)

var digitsRegexp = regexp.MustCompile(`\d+`)

type inputKind uint8

const (
	inputKindUnknown inputKind = iota
	inputKindFASTA
	inputKindGFF3
	inputKindFlatFile
)

type Feature struct {
	SeqName    string
	Source     string
	Type       string
	Start      int
	End        int
	Strand     byte
	Attributes string
}

type Alignment struct {
	Start       int
	End         int
	Name        string
	MapQ        uint8
	Flags       uint16
	Cigar       string
	SNPs        []uint32
	SNPBases    []byte
	Reverse     bool
	MateStart   int
	MateEnd     int
	FragLen     int
	MateSameRef bool
}

type GenomeSnapshot struct {
	Sequences   map[string]string
	Features    map[string][]Feature
	ChromLength map[string]int
}

type tileCacheKey struct {
	Generation uint64
	SourceID   uint16
	Kind       uint8
	ChrID      uint16
	Zoom       uint8
	TileIndex  uint32
	Param      uint32
}

type bamSource struct {
	ID         uint16
	Path       string
	IndexPath  string
	Generation uint64
	Index      *bam.Index
	Refs       map[string]*sam.Reference
	CovPrefix  map[uint16][]uint64
	CovReady   bool
}

type tileCacheEntry struct {
	Key     tileCacheKey
	Payload []byte
	Size    int64
}

type Engine struct {
	mu sync.RWMutex

	chromOrder []string
	chrToID    map[string]uint16
	idToChr    map[uint16]string
	chrLength  map[string]int
	sequences  map[string]string
	features   map[string][]Feature
	gcPrefix   map[string][]uint32
	atgcPrefix map[string][]uint32

	bamSources       map[uint16]*bamSource
	bamOrder         []uint16
	nextBAMSourceID  uint16
	globalGeneration uint64
	maxTileRecs      uint32
	maxReadZoom      uint8

	tileCacheMaxBytes int64
	tileCacheBytes    int64
	tileCache         map[tileCacheKey]*list.Element
	tileLRU           *list.List
	prefetchRadius    int
	prefetchSem       chan struct{}
}

func NewEngine() *Engine {
	return &Engine{
		chrToID:           make(map[string]uint16),
		idToChr:           make(map[uint16]string),
		chrLength:         make(map[string]int),
		sequences:         make(map[string]string),
		features:          make(map[string][]Feature),
		gcPrefix:          make(map[string][]uint32),
		atgcPrefix:        make(map[string][]uint32),
		bamSources:        make(map[uint16]*bamSource),
		bamOrder:          make([]uint16, 0, 4),
		nextBAMSourceID:   1,
		globalGeneration:  1,
		maxTileRecs:       5000,
		maxReadZoom:       7,
		tileCacheMaxBytes: 512 << 20, // 512 MiB cap keeps backend well under 2 GiB.
		tileCache:         make(map[tileCacheKey]*list.Element),
		tileLRU:           list.New(),
		prefetchRadius:    1,
		prefetchSem:       make(chan struct{}, 4),
	}
}

func (e *Engine) SetTileCacheMaxBytes(maxBytes int64) {
	if maxBytes <= 0 {
		return
	}
	e.mu.Lock()
	defer e.mu.Unlock()
	e.tileCacheMaxBytes = maxBytes
	for e.tileCacheBytes > e.tileCacheMaxBytes {
		last := e.tileLRU.Back()
		if last == nil {
			break
		}
		entry := last.Value.(*tileCacheEntry)
		delete(e.tileCache, entry.Key)
		e.tileCacheBytes -= entry.Size
		e.tileLRU.Remove(last)
	}
}

func (e *Engine) LoadGenome(path string) error {
	entries, err := gatherInputFiles(path)
	if err != nil {
		return err
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
			return err
		}
		switch kind {
		case inputKindFASTA:
			hasSequenceInput = true
			seqs, err := parseFASTA(p)
			if err != nil {
				return err
			}
			for chr, seq := range seqs {
				snapshot.Sequences[chr] = seq
				snapshot.ChromLength[chr] = len(seq)
			}
		case inputKindGFF3:
			gffFeatures, err := parseGFF3(p)
			if err != nil {
				return err
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
				return err
			}
			for chr, seq := range flatSeqs {
				snapshot.Sequences[chr] = seq
				snapshot.ChromLength[chr] = len(seq)
			}
			mergeFeatures(snapshot.Features, flatFeatures)
		default:
			return fmt.Errorf("unsupported genome/annotation file: %s", p)
		}
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if hasSequenceInput || len(snapshot.Sequences) > 0 {
		// Sequence-bearing loads define a new primary genome context.
		e.sequences = make(map[string]string, len(snapshot.Sequences))
		e.features = make(map[string][]Feature, len(snapshot.Features))
		e.chrLength = make(map[string]int, len(snapshot.ChromLength))
		e.gcPrefix = make(map[string][]uint32, len(snapshot.Sequences))
		e.atgcPrefix = make(map[string][]uint32, len(snapshot.Sequences))
		e.chrToID = make(map[string]uint16)
		e.idToChr = make(map[uint16]string)
		e.chromOrder = e.chromOrder[:0]
		e.resetBAMStateLocked()

		for chr, seq := range snapshot.Sequences {
			e.sequences[chr] = seq
			gc, atgc := buildGCPrefix(seq)
			e.gcPrefix[chr] = gc
			e.atgcPrefix[chr] = atgc
		}
		for chr, feats := range snapshot.Features {
			sort.Slice(feats, func(i, j int) bool {
				if feats[i].Start == feats[j].Start {
					return feats[i].End < feats[j].End
				}
				return feats[i].Start < feats[j].Start
			})
			e.features[chr] = feats
		}

		chrNames := make([]string, 0, len(snapshot.ChromLength))
		for chr, ln := range snapshot.ChromLength {
			e.chrLength[chr] = ln
			chrNames = append(chrNames, chr)
		}
		sort.Strings(chrNames)
		for _, chr := range chrNames {
			e.ensureChromosomeLocked(chr, e.chrLength[chr])
		}
		return nil
	}

	if len(e.sequences) == 0 {
		return errors.New("no reference sequence loaded; load FASTA/EMBL/GenBank first")
	}

	// Annotation-only loads merge into the current genome context.
	for chr, feats := range snapshot.Features {
		e.features[chr] = append(e.features[chr], feats...)
		sort.Slice(e.features[chr], func(i, j int) bool {
			if e.features[chr][i].Start == e.features[chr][j].Start {
				return e.features[chr][i].End < e.features[chr][j].End
			}
			return e.features[chr][i].Start < e.features[chr][j].Start
		})
		featureMax := maxFeatureEnd(e.features[chr])
		if e.chrLength[chr] < featureMax {
			e.chrLength[chr] = featureMax
		}
		e.ensureChromosomeLocked(chr, e.chrLength[chr])
	}

	return nil
}

func (e *Engine) LoadBAM(path string, precomputeCutoffBP int) (uint16, error) {
	bamFile, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer bamFile.Close()

	reader, err := bam.NewReader(bamFile, 0)
	if err != nil {
		return 0, err
	}
	defer reader.Close()

	idxPath, err := resolveBAMIndexPath(path)
	if err != nil {
		return 0, err
	}

	idxFile, err := os.Open(idxPath)
	if err != nil {
		return 0, err
	}
	defer idxFile.Close()

	idx, err := bam.ReadIndex(idxFile)
	if err != nil {
		return 0, fmt.Errorf("failed to read BAM index %s: %w", idxPath, err)
	}

	refs := make(map[string]*sam.Reference)
	localLengths := make(map[string]int)
	totalRefLen := 0
	headerRefs := reader.Header().Refs()
	for _, ref := range headerRefs {
		if ref == nil {
			continue
		}
		refs[ref.Name()] = ref
		localLengths[ref.Name()] = ref.Len()
		totalRefLen += max(0, ref.Len())
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	for chr, ln := range localLengths {
		if e.chrLength[chr] < ln {
			e.chrLength[chr] = ln
		}
		e.ensureChromosomeLocked(chr, e.chrLength[chr])
	}
	sourceID := e.nextBAMSourceID
	e.nextBAMSourceID++
	if e.nextBAMSourceID == 0 {
		e.nextBAMSourceID = 1
	}
	shouldPrecomputeCov := precomputeCutoffBP > 0 && totalRefLen > 0 && totalRefLen <= precomputeCutoffBP
	e.bamSources[sourceID] = &bamSource{
		ID:         sourceID,
		Path:       path,
		IndexPath:  idxPath,
		Generation: e.globalGeneration + 1,
		Index:      idx,
		Refs:       refs,
		CovPrefix:  map[uint16][]uint64{},
		CovReady:   !shouldPrecomputeCov,
	}
	e.bamOrder = append(e.bamOrder, sourceID)
	e.globalGeneration++
	e.resetTileCacheLocked()

	if shouldPrecomputeCov {
		go e.precomputeCoverageForSource(sourceID, path, headerRefs)
	}

	return sourceID, nil
}

func (e *Engine) GetTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	window := tileWindow(zoom, tileIndex)
	if zoom > e.maxReadZoom {
		return encodeAlignmentTile(window.start, window.end, nil), nil
	}
	return e.getIndexedTile(sourceID, chrID, zoom, tileIndex, readTileCacheKind, true)
}

func (e *Engine) GetCoverageTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	return e.getIndexedTile(sourceID, chrID, zoom, tileIndex, covTileCacheKind, false)
}

func (e *Engine) GetGCPlotTile(chrID uint16, zoom uint8, tileIndex uint32, windowLen uint32) ([]byte, error) {
	e.mu.Lock()
	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	chrLen := e.chrLength[chr]
	if chrLen <= 0 {
		e.mu.Unlock()
		return encodeGCPlotTile(0, 0, int(windowLen), nil), nil
	}
	window := tileWindow(zoom, tileIndex)
	if window.start < 0 {
		window.start = 0
	}
	if window.start > chrLen {
		window.start = chrLen
	}
	if window.end > chrLen {
		window.end = chrLen
	}
	if window.end < window.start {
		window.end = window.start
	}
	if windowLen == 0 {
		windowLen = 200
	}
	if windowLen > 1_000_000 {
		windowLen = 1_000_000
	}
	key := tileCacheKey{
		Generation: e.globalGeneration,
		SourceID:   0,
		Kind:       plotTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      windowLen,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}
	gc := e.gcPrefix[chr]
	atgc := e.atgcPrefix[chr]
	generation := e.globalGeneration
	e.mu.Unlock()

	values := computeGCPlotValues(gc, atgc, window.start, window.end, int(windowLen), plotTileBins)
	payload := encodeGCPlotTile(window.start, window.end, int(windowLen), values)

	e.mu.Lock()
	if e.globalGeneration == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()
	return payload, nil
}

func (e *Engine) GetAnnotations(chrID uint16, start uint32, end uint32, maxRecords uint16, minFeatureLen uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
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

	features := queryFeatures(e.features[chr], int(start), int(end), maxRecs, minLen)
	return encodeAnnotations(int(start), int(end), features), nil
}

func (e *Engine) GetReferenceSlice(chrID uint16, start uint32, end uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}

	seq := e.sequences[chr]
	if seq == "" {
		return nil, fmt.Errorf("no sequence loaded for chromosome %s", chr)
	}

	s := int(start)
	eIdx := int(end)
	if eIdx < s {
		return nil, errors.New("end must be >= start")
	}
	if s < 0 {
		s = 0
	}
	if s > len(seq) {
		s = len(seq)
	}
	if eIdx > len(seq) {
		eIdx = len(seq)
	}

	slice := seq[s:eIdx]
	buf := make([]byte, 12+len(slice))
	binary.LittleEndian.PutUint32(buf[0:4], uint32(s))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(eIdx))
	binary.LittleEndian.PutUint32(buf[8:12], uint32(len(slice)))
	copy(buf[12:], slice)
	return buf, nil
}

func (e *Engine) ListChromosomes() []ChromInfo {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chroms := make([]ChromInfo, 0, len(e.chromOrder))
	for _, chr := range e.chromOrder {
		chroms = append(chroms, ChromInfo{
			ID:     e.chrToID[chr],
			Name:   chr,
			Length: uint32(e.chrLength[chr]),
		})
	}
	return chroms
}

func (e *Engine) ListAnnotationCounts() []AnnotationCountInfo {
	e.mu.RLock()
	defer e.mu.RUnlock()

	out := make([]AnnotationCountInfo, 0, len(e.chromOrder))
	for _, chr := range e.chromOrder {
		id := e.chrToID[chr]
		out = append(out, AnnotationCountInfo{
			ID:    id,
			Count: uint32(len(e.features[chr])),
		})
	}
	return out
}

func (e *Engine) HasSequenceLoaded() bool {
	e.mu.RLock()
	defer e.mu.RUnlock()
	return len(e.sequences) > 0
}

func (e *Engine) InspectInput(path string) (bool, bool, error) {
	entries, err := gatherInputFiles(path)
	if err != nil {
		return false, false, err
	}
	hasSequence := false
	hasAnnotation := false
	for _, p := range entries {
		kind, err := detectInputKind(p)
		if err != nil {
			return false, false, err
		}
		switch kind {
		case inputKindFASTA, inputKindFlatFile:
			hasSequence = true
		case inputKindGFF3:
			hasAnnotation = true
		default:
			return false, false, fmt.Errorf("unsupported genome/annotation file: %s", p)
		}
	}
	return hasSequence, hasAnnotation, nil
}

func (e *Engine) ensureChromosomeLocked(name string, length int) uint16 {
	if id, ok := e.chrToID[name]; ok {
		if e.chrLength[name] < length {
			e.chrLength[name] = length
		}
		return id
	}
	id := uint16(len(e.chromOrder))
	e.chromOrder = append(e.chromOrder, name)
	e.chrToID[name] = id
	e.idToChr[id] = name
	e.chrLength[name] = length
	return id
}

func resolveBAMIndexPath(bamPath string) (string, error) {
	candidates := []string{
		bamPath + ".bai",
		strings.TrimSuffix(bamPath, filepath.Ext(bamPath)) + ".bai",
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("BAM index not found; expected %s or %s", candidates[0], candidates[1])
}

func (e *Engine) getIndexedTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32, kind uint8, prefetch bool) ([]byte, error) {
	e.mu.Lock()
	src, err := e.resolveBAMSourceLocked(sourceID)
	if err != nil {
		e.mu.Unlock()
		return nil, err
	}

	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	ref := src.Refs[chr]
	if ref == nil {
		e.mu.Unlock()
		return nil, fmt.Errorf("chromosome %s is missing from BAM header", chr)
	}

	key := tileCacheKey{
		Generation: src.Generation,
		SourceID:   src.ID,
		Kind:       kind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      0,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}

	bamPath := src.Path
	bamIdx := src.Index
	covPrefix := src.CovPrefix[chrID]
	maxTileRecs := e.maxTileRecs
	if kind == readTileCacheKind && zoom >= 6 {
		maxTileRecs *= 2
	}
	window := tileWindow(zoom, tileIndex)
	generation := src.Generation
	prefetchRadius := e.prefetchRadius
	refSeq := e.sequences[chr]
	selectedSourceID := src.ID
	e.mu.Unlock()

	includeSNPs := kind == readTileCacheKind && zoom <= snpDetailMaxZoom
	var payload []byte
	if kind == covTileCacheKind && len(covPrefix) > 0 {
		payload, err = encodeCoverageTileFromPrefix(window.start, window.end, covPrefix)
	} else {
		payload, err = loadIndexedTilePayload(bamPath, bamIdx, ref, window.start, window.end, kind, maxTileRecs, includeSNPs, refSeq)
	}
	if err != nil {
		return nil, err
	}

	e.mu.Lock()
	if src2, ok := e.bamSources[selectedSourceID]; ok && src2.Generation == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()

	if prefetch && prefetchRadius > 0 {
		go e.prefetchAdjacentReadTiles(selectedSourceID, generation, chrID, zoom, tileIndex, prefetchRadius)
	}

	return payload, nil
}

func (e *Engine) precomputeCoverageForSource(sourceID uint16, bamPath string, refs []*sam.Reference) {
	covPrefixByName, err := buildCoveragePrefixSums(bamPath, refs)
	if err != nil {
		log.Printf("coverage precompute failed for source %d: %v", sourceID, err)
		e.mu.Lock()
		if src, ok := e.bamSources[sourceID]; ok {
			src.CovReady = true
		}
		e.mu.Unlock()
		return
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	src, ok := e.bamSources[sourceID]
	if !ok {
		return
	}
	for chrName, prefix := range covPrefixByName {
		if chrID, ok := e.chrToID[chrName]; ok {
			src.CovPrefix[chrID] = prefix
		}
	}
	src.CovReady = true
}

func buildCoveragePrefixSums(bamPath string, refs []*sam.Reference) (map[string][]uint64, error) {
	if len(refs) == 0 {
		return map[string][]uint64{}, nil
	}
	file, err := os.Open(bamPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader, err := bam.NewReader(file, 0)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	diffByRefID := make(map[int][]int32, len(refs))
	refNameByID := make(map[int]string, len(refs))
	for _, ref := range refs {
		if ref == nil {
			continue
		}
		rid := ref.ID()
		if rid < 0 {
			continue
		}
		diffByRefID[rid] = make([]int32, ref.Len()+1)
		refNameByID[rid] = ref.Name()
	}

	for {
		rec, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if rec == nil || rec.Ref == nil {
			continue
		}
		rid := rec.Ref.ID()
		diff := diffByRefID[rid]
		if len(diff) == 0 {
			continue
		}
		s := rec.Start()
		e := rec.End()
		if s < 0 {
			s = 0
		}
		if e < s {
			e = s
		}
		if e > len(diff)-1 {
			e = len(diff) - 1
		}
		if s >= e {
			continue
		}
		diff[s]++
		diff[e]--
	}

	out := make(map[string][]uint64, len(diffByRefID))
	for rid, diff := range diffByRefID {
		name := refNameByID[rid]
		if name == "" || len(diff) == 0 {
			continue
		}
		prefix := make([]uint64, len(diff))
		var depth int64
		for i := 0; i < len(diff)-1; i++ {
			depth += int64(diff[i])
			if depth < 0 {
				depth = 0
			}
			prefix[i+1] = prefix[i] + uint64(depth)
		}
		out[name] = prefix
	}
	return out, nil
}

func encodeCoverageTileFromPrefix(start, end int, depthPrefix []uint64) ([]byte, error) {
	if start < 0 {
		start = 0
	}
	if end < start {
		end = start
	}
	maxPos := len(depthPrefix) - 1
	if start > maxPos {
		start = maxPos
	}
	if end > maxPos {
		end = maxPos
	}
	bins := make([]uint16, 256)
	span := max(1, end-start)
	for b := range bins {
		bStart := start + (b*span)/len(bins)
		bEnd := start + ((b+1)*span)/len(bins)
		if bEnd <= bStart {
			bEnd = bStart + 1
		}
		if bStart < 0 {
			bStart = 0
		}
		if bEnd > maxPos {
			bEnd = maxPos
		}
		binW := bEnd - bStart
		if binW <= 0 {
			binW = 1
		}
		sum := depthPrefix[bEnd] - depthPrefix[bStart]
		avgDepth := int(math.Round(float64(sum) / float64(binW)))
		if avgDepth == 0 && sum > 0 {
			avgDepth = 1
		}
		if avgDepth < 0 {
			avgDepth = 0
		}
		if avgDepth > int(^uint16(0)) {
			avgDepth = int(^uint16(0))
		}
		bins[b] = uint16(avgDepth)
	}
	return encodeCoverageTile(start, end, bins), nil
}

func loadIndexedTilePayload(bamPath string, bamIdx *bam.Index, ref *sam.Reference, start, end int, kind uint8, maxTileRecs uint32, includeSNPs bool, refSeq string) ([]byte, error) {
	if start < 0 {
		start = 0
	}
	refLen := ref.Len()
	if start > refLen {
		start = refLen
	}
	if end < start {
		end = start
	}
	if end > refLen {
		end = refLen
	}

	file, err := os.Open(bamPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader, err := bam.NewReader(file, 0)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	chunks, err := bamIdx.Chunks(ref, start, end)
	if err != nil {
		return nil, err
	}
	if len(chunks) == 0 {
		if kind == covTileCacheKind {
			return encodeCoverageTile(start, end, make([]uint16, 256)), nil
		}
		return encodeAlignmentTile(start, end, nil), nil
	}

	it, err := bam.NewIterator(reader, chunks)
	if err != nil {
		return nil, err
	}
	defer it.Close()

	switch kind {
	case covTileCacheKind:
		bins := make([]uint16, 256)
		sumDepthBp := make([]uint64, len(bins))
		span := max(1, end-start)
		for it.Next() {
			rec := it.Record()
			if rec == nil || rec.Ref == nil || rec.Ref.ID() != ref.ID() {
				continue
			}
			s := max(rec.Start(), start)
			e := min(rec.End(), end)
			if e <= s {
				continue
			}
			binStart := ((s - start) * len(bins)) / span
			binEnd := ((e - 1 - start) * len(bins)) / span
			if binStart < 0 {
				binStart = 0
			}
			if binEnd >= len(bins) {
				binEnd = len(bins) - 1
			}
			for b := binStart; b <= binEnd; b++ {
				bStart := start + (b*span)/len(bins)
				bEnd := start + ((b+1)*span)/len(bins)
				if bEnd <= bStart {
					bEnd = bStart + 1
				}
				ovStart := max(s, bStart)
				ovEnd := min(e, bEnd)
				if ovEnd > ovStart {
					sumDepthBp[b] += uint64(ovEnd - ovStart)
				}
			}
		}
		if err := it.Error(); err != nil {
			return nil, err
		}
		for b := range bins {
			bStart := start + (b*span)/len(bins)
			bEnd := start + ((b+1)*span)/len(bins)
			if bEnd <= bStart {
				bEnd = bStart + 1
			}
			binW := bEnd - bStart
			if binW <= 0 {
				binW = 1
			}
			avgDepth := int(math.Round(float64(sumDepthBp[b]) / float64(binW)))
			if avgDepth == 0 && sumDepthBp[b] > 0 {
				// Preserve sparse coverage visibility at coarse zooms.
				avgDepth = 1
			}
			if avgDepth < 0 {
				avgDepth = 0
			}
			if avgDepth > int(^uint16(0)) {
				avgDepth = int(^uint16(0))
			}
			bins[b] = uint16(avgDepth)
		}
		return encodeCoverageTile(start, end, bins), nil

	case readTileCacheKind:
		alignments, err := collectWindowAlignments(it, ref, start, end, maxTileRecs, includeSNPs, refSeq)
		if err != nil {
			return nil, err
		}
		return encodeAlignmentTile(start, end, alignments), nil

	default:
		return nil, fmt.Errorf("unknown tile kind %d", kind)
	}
}

func collectWindowAlignments(it *bam.Iterator, ref *sam.Reference, start, end int, maxTileRecs uint32, includeSNPs bool, refSeq string) ([]Alignment, error) {
	if maxTileRecs == 0 || end <= start {
		return nil, nil
	}

	limit := int(maxTileRecs)
	binCount := min(256, limit)
	if binCount <= 0 {
		binCount = 1
	}
	binCaps := make([]int, binCount)
	baseCap := limit / binCount
	rem := limit % binCount
	for i := range binCount {
		binCaps[i] = baseCap
		if i < rem {
			binCaps[i]++
		}
		if binCaps[i] <= 0 {
			binCaps[i] = 1
		}
	}
	bins := make([][]Alignment, binCount)
	binCounts := make([]int, binCount)
	filledBins := 0
	span := max(1, end-start)
	scanned := 0
	for it.Next() {
		scanned++
		if scanned > maxScannedTileReads {
			break
		}
		rec := it.Record()
		if rec == nil || rec.Ref == nil || rec.Ref.ID() != ref.ID() {
			continue
		}
		if rec.End() <= start || rec.Start() >= end {
			continue
		}
		s := max(rec.Start(), start)
		e := min(rec.End(), end)
		if e <= s {
			continue
		}
		// Assign by overlap midpoint (not read start) to avoid apparent tile holes.
		pos := s + (e-s-1)/2
		b := ((pos - start) * binCount) / span
		if b < 0 {
			b = 0
		}
		if b >= binCount {
			b = binCount - 1
		}
		capForBin := binCaps[b]
		if binCounts[b] >= capForBin {
			continue
		}
		snps := recordSNPPositions(rec, start, end, includeSNPs, refSeq)
		bins[b] = append(bins[b], Alignment{
			Start:       rec.Start(),
			End:         rec.End(),
			Name:        rec.Name,
			MapQ:        rec.MapQ,
			Flags:       uint16(rec.Flags),
			Cigar:       rec.Cigar.String(),
			SNPs:        snps,
			SNPBases:    snpBasesFromPositions(rec, snps),
			Reverse:     rec.Flags&sam.Reverse != 0,
			MateStart:   rec.MatePos,
			MateEnd:     estimateMateEnd(rec),
			FragLen:     absInt(rec.TempLen),
			MateSameRef: isLikelySameRefMate(rec),
		})
		binCounts[b]++
		if binCounts[b] == capForBin {
			filledBins++
			if filledBins >= binCount {
				break
			}
		}
	}
	if err := it.Error(); err != nil {
		return nil, err
	}

	alignments := make([]Alignment, 0, limit)
	for _, bucket := range bins {
		alignments = append(alignments, bucket...)
	}
	sort.Slice(alignments, func(i, j int) bool {
		if alignments[i].Start == alignments[j].Start {
			return alignments[i].End < alignments[j].End
		}
		return alignments[i].Start < alignments[j].Start
	})
	if len(alignments) > limit {
		alignments = alignments[:limit]
	}
	return alignments, nil
}

func recordSNPPositions(rec *sam.Record, windowStart, windowEnd int, includeSNPs bool, refSeq string) []uint32 {
	if !includeSNPs || rec == nil {
		return nil
	}
	defer func() {
		if recover() != nil {
			// Guard against malformed records causing panics in low-level base access.
		}
	}()
	aux, ok := rec.Tag([]byte("MD"))
	out := make([]uint32, 0, 4)
	if ok {
		raw, ok := aux.Value().(string)
		if ok && raw != "" {
			md := strings.TrimRight(raw, "\x00")
			pos := rec.Start()
			for i := 0; i < len(md); {
				ch := md[i]
				if ch >= '0' && ch <= '9' {
					n := 0
					for i < len(md) && md[i] >= '0' && md[i] <= '9' {
						n = n*10 + int(md[i]-'0')
						i++
					}
					pos += n
					continue
				}
				if ch == '^' {
					i++
					for i < len(md) && ((md[i] >= 'A' && md[i] <= 'Z') || (md[i] >= 'a' && md[i] <= 'z')) {
						pos++
						i++
					}
					continue
				}
				if (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') {
					if pos >= windowStart && pos < windowEnd {
						out = append(out, uint32(pos))
					}
					pos++
					i++
					continue
				}
				i++
			}
		}
	}
	if len(out) > 0 {
		return out
	}
	return snpPositionsFromCigar(rec, windowStart, windowEnd, refSeq)
}

func snpPositionsFromCigar(rec *sam.Record, windowStart, windowEnd int, refSeq string) []uint32 {
	out := make([]uint32, 0, 2)
	queryPos := 0
	refPos := rec.Start()
	maxQueryBases := min(rec.Seq.Length, len(rec.Seq.Seq)*2)
	if maxQueryBases < 0 {
		maxQueryBases = 0
	}
	for _, co := range rec.Cigar {
		op := co.Type()
		ln := co.Len()
		if ln <= 0 {
			continue
		}
		if op == sam.CigarMismatch {
			for i := 0; i < ln; i++ {
				p := refPos + i
				if p >= windowStart && p < windowEnd {
					out = append(out, uint32(p))
				}
			}
			queryPos += ln
			refPos += ln
			continue
		}
		if op == sam.CigarEqual {
			queryPos += ln
			refPos += ln
			continue
		}
		if op == sam.CigarMatch {
			if refSeq != "" {
				for i := 0; i < ln; i++ {
					p := refPos + i
					q := queryPos + i
					if p < windowStart || p >= windowEnd {
						continue
					}
					if p < 0 || p >= len(refSeq) || q < 0 || q >= maxQueryBases {
						continue
					}
					rb := normalizeBase(refSeq[p])
					qb := normalizeBase(rec.Seq.At(q))
					if rb == 0 || qb == 0 {
						continue
					}
					if rb != qb {
						out = append(out, uint32(p))
					}
				}
			}
			queryPos += ln
			refPos += ln
			continue
		}
		if op == sam.CigarInsertion || op == sam.CigarSoftClipped {
			queryPos += ln
			continue
		}
		if op == sam.CigarDeletion || op == sam.CigarSkipped {
			refPos += ln
			continue
		}
		if op == sam.CigarHardClipped || op == sam.CigarPadded {
			continue
		}
		cons := op.Consumes()
		if cons.Query > 0 {
			queryPos += ln * cons.Query
		}
		if cons.Reference > 0 {
			refPos += ln * cons.Reference
		}
	}
	return out
}

func normalizeBase(b byte) byte {
	switch b {
	case 'a', 'A':
		return 'A'
	case 'c', 'C':
		return 'C'
	case 'g', 'G':
		return 'G'
	case 't', 'T', 'u', 'U':
		return 'T'
	case 'n', 'N':
		return 'N'
	default:
		return 0
	}
}

func snpBasesFromPositions(rec *sam.Record, snps []uint32) []byte {
	if rec == nil || len(snps) == 0 {
		return nil
	}
	out := make([]byte, len(snps))
	for i, p := range snps {
		b, ok := readBaseAtRefPos(rec, int(p))
		if !ok || b == 0 {
			out[i] = 'N'
			continue
		}
		out[i] = b
	}
	return out
}

func readBaseAtRefPos(rec *sam.Record, targetRefPos int) (byte, bool) {
	if rec == nil {
		return 0, false
	}
	queryPos := 0
	refPos := rec.Start()
	maxQueryBases := min(rec.Seq.Length, len(rec.Seq.Seq)*2)
	if maxQueryBases < 0 {
		maxQueryBases = 0
	}
	for _, co := range rec.Cigar {
		op := co.Type()
		ln := co.Len()
		if ln <= 0 {
			continue
		}
		switch op {
		case sam.CigarMismatch, sam.CigarEqual, sam.CigarMatch:
			if targetRefPos >= refPos && targetRefPos < refPos+ln {
				q := queryPos + (targetRefPos - refPos)
				if q < 0 || q >= maxQueryBases {
					return 0, false
				}
				return normalizeBase(rec.Seq.At(q)), true
			}
			queryPos += ln
			refPos += ln
		case sam.CigarInsertion, sam.CigarSoftClipped:
			queryPos += ln
		case sam.CigarDeletion, sam.CigarSkipped:
			if targetRefPos >= refPos && targetRefPos < refPos+ln {
				return 0, false
			}
			refPos += ln
		case sam.CigarHardClipped, sam.CigarPadded:
			// no-op
		default:
			cons := op.Consumes()
			if cons.Query > 0 {
				queryPos += ln * cons.Query
			}
			if cons.Reference > 0 {
				if targetRefPos >= refPos && targetRefPos < refPos+ln*cons.Reference {
					return 0, false
				}
				refPos += ln * cons.Reference
			}
		}
	}
	return 0, false
}

func estimateMateEnd(rec *sam.Record) int {
	if rec == nil {
		return -1
	}
	if rec.MatePos < 0 {
		return -1
	}
	span := referenceSpan(rec)
	if span <= 0 {
		span = 1
	}
	return rec.MatePos + span
}

func referenceSpan(rec *sam.Record) int {
	if rec == nil {
		return 0
	}
	span := 0
	for _, co := range rec.Cigar {
		cons := co.Type().Consumes().Reference
		if cons > 0 {
			span += co.Len() * cons
		}
	}
	if span <= 0 {
		return max(1, rec.Len())
	}
	return span
}

func absInt(v int) int {
	if v < 0 {
		return -v
	}
	return v
}

func isLikelySameRefMate(rec *sam.Record) bool {
	if rec == nil || rec.Ref == nil {
		return false
	}
	if rec.Flags&sam.Paired == 0 || rec.Flags&sam.MateUnmapped != 0 || rec.MatePos < 0 {
		return false
	}
	// In many BAMs MateRef may be omitted while MatePos is still valid and
	// implies same-reference pairing.
	if rec.MateRef == nil {
		return true
	}
	return rec.MateRef.ID() == rec.Ref.ID()
}

func (e *Engine) prefetchAdjacentReadTiles(sourceID uint16, generation uint64, chrID uint16, zoom uint8, tileIndex uint32, radius int) {
	select {
	case e.prefetchSem <- struct{}{}:
	default:
		return
	}
	defer func() { <-e.prefetchSem }()

	for offset := 1; offset <= radius; offset++ {
		step := uint32(offset)
		if tileIndex >= step {
			_, _ = e.prefetchReadTile(sourceID, generation, chrID, zoom, tileIndex-step)
		}
		_, _ = e.prefetchReadTile(sourceID, generation, chrID, zoom, tileIndex+step)
	}
}

func (e *Engine) prefetchReadTile(sourceID uint16, generation uint64, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	e.mu.Lock()
	src, ok := e.bamSources[sourceID]
	if !ok || src.Generation != generation || src.Index == nil {
		e.mu.Unlock()
		return nil, nil
	}
	if zoom > e.maxReadZoom {
		e.mu.Unlock()
		return encodeAlignmentTile(tileWindow(zoom, tileIndex).start, tileWindow(zoom, tileIndex).end, nil), nil
	}
	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, nil
	}
	ref := src.Refs[chr]
	if ref == nil {
		e.mu.Unlock()
		return nil, nil
	}
	key := tileCacheKey{
		Generation: generation,
		SourceID:   sourceID,
		Kind:       readTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      0,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}
	bamPath := src.Path
	bamIdx := src.Index
	maxTileRecs := e.maxTileRecs
	window := tileWindow(zoom, tileIndex)
	refSeq := e.sequences[chr]
	e.mu.Unlock()

	includeSNPs := zoom <= snpDetailMaxZoom
	payload, err := loadIndexedTilePayload(bamPath, bamIdx, ref, window.start, window.end, readTileCacheKind, maxTileRecs, includeSNPs, refSeq)
	if err != nil {
		return nil, err
	}

	e.mu.Lock()
	if src2, ok := e.bamSources[sourceID]; ok && src2.Generation == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()
	return payload, nil
}

func (e *Engine) getCachedTileLocked(key tileCacheKey) ([]byte, bool) {
	elem, ok := e.tileCache[key]
	if !ok {
		return nil, false
	}
	e.tileLRU.MoveToFront(elem)
	entry := elem.Value.(*tileCacheEntry)
	payload := make([]byte, len(entry.Payload))
	copy(payload, entry.Payload)
	return payload, true
}

func (e *Engine) putCachedTileLocked(key tileCacheKey, payload []byte) {
	payloadCopy := make([]byte, len(payload))
	copy(payloadCopy, payload)
	size := int64(len(payloadCopy) + 128)

	if existing, ok := e.tileCache[key]; ok {
		entry := existing.Value.(*tileCacheEntry)
		e.tileCacheBytes -= entry.Size
		entry.Payload = payloadCopy
		entry.Size = size
		e.tileCacheBytes += entry.Size
		e.tileLRU.MoveToFront(existing)
	} else {
		entry := &tileCacheEntry{Key: key, Payload: payloadCopy, Size: size}
		elem := e.tileLRU.PushFront(entry)
		e.tileCache[key] = elem
		e.tileCacheBytes += size
	}

	for e.tileCacheBytes > e.tileCacheMaxBytes {
		last := e.tileLRU.Back()
		if last == nil {
			break
		}
		entry := last.Value.(*tileCacheEntry)
		delete(e.tileCache, entry.Key)
		e.tileCacheBytes -= entry.Size
		e.tileLRU.Remove(last)
	}
}

func (e *Engine) resetTileCacheLocked() {
	e.tileCache = make(map[tileCacheKey]*list.Element)
	e.tileLRU.Init()
	e.tileCacheBytes = 0
}

func (e *Engine) resolveBAMSourceLocked(sourceID uint16) (*bamSource, error) {
	if len(e.bamOrder) == 0 {
		return nil, errors.New("BAM not loaded")
	}
	if sourceID == 0 {
		sourceID = e.bamOrder[0]
	}
	src, ok := e.bamSources[sourceID]
	if !ok || src == nil || src.Index == nil {
		return nil, fmt.Errorf("BAM source %d not loaded", sourceID)
	}
	return src, nil
}

func (e *Engine) resetBAMStateLocked() {
	e.bamSources = make(map[uint16]*bamSource)
	e.bamOrder = e.bamOrder[:0]
	e.nextBAMSourceID = 1
	e.globalGeneration++
	e.resetTileCacheLocked()
}

type windowRange struct {
	start int
	end   int
}

func tileWindow(zoom uint8, tileIndex uint32) windowRange {
	tileWidth := baseTileSize << zoom
	start := int(tileIndex) * tileWidth
	end := start + tileWidth
	return windowRange{start: start, end: end}
}

func queryFeatures(features []Feature, start, end, limit, minLen int) []Feature {
	if len(features) == 0 {
		return nil
	}
	if minLen < 1 {
		minLen = 1
	}
	idx := sort.Search(len(features), func(i int) bool {
		return features[i].End > start
	})
	out := make([]Feature, 0, min(limit, 256))
	for i := idx; i < len(features); i++ {
		feat := features[i]
		if feat.Start >= end {
			break
		}
		if feat.End <= start {
			continue
		}
		if feat.End-feat.Start < minLen {
			continue
		}
		out = append(out, feat)
		if len(out) >= limit {
			break
		}
	}
	return out
}

func encodeAlignmentTile(start, end int, alns []Alignment) []byte {
	payloadLen := 13
	for _, aln := range alns {
		nameLen := min(len(aln.Name), 0xFFFF)
		cigarLen := min(len(aln.Cigar), 0xFFFF)
		snpCount := min(min(len(aln.SNPs), len(aln.SNPBases)), 0xFFFF)
		// Fixed per-record bytes:
		// 26 header + 2 cigar_len + 2 snp_count + variable fields.
		payloadLen += 30 + nameLen + cigarLen + 5*snpCount
	}

	buf := make([]byte, payloadLen)
	buf[0] = 2
	binary.LittleEndian.PutUint32(buf[1:5], uint32(start))
	binary.LittleEndian.PutUint32(buf[5:9], uint32(end))
	binary.LittleEndian.PutUint32(buf[9:13], uint32(len(alns)))
	off := 13
	for _, aln := range alns {
		binary.LittleEndian.PutUint32(buf[off:off+4], uint32(aln.Start))
		binary.LittleEndian.PutUint32(buf[off+4:off+8], uint32(aln.End))
		buf[off+8] = aln.MapQ
		if aln.Reverse {
			buf[off+9] = 1
		} else {
			buf[off+9] = 0
		}
		binary.LittleEndian.PutUint16(buf[off+10:off+12], aln.Flags)
		mateStart := uint32(0xFFFFFFFF)
		mateEnd := uint32(0xFFFFFFFF)
		if aln.MateSameRef && aln.MateStart >= 0 && aln.MateEnd > aln.MateStart {
			mateStart = uint32(aln.MateStart)
			mateEnd = uint32(aln.MateEnd)
		}
		binary.LittleEndian.PutUint32(buf[off+12:off+16], mateStart)
		binary.LittleEndian.PutUint32(buf[off+16:off+20], mateEnd)
		binary.LittleEndian.PutUint32(buf[off+20:off+24], uint32(max(0, aln.FragLen)))
		nameLen := min(len(aln.Name), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off+24:off+26], uint16(nameLen))
		copy(buf[off+26:off+26+nameLen], aln.Name[:nameLen])
		off += 26 + nameLen
		cigarLen := min(len(aln.Cigar), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(cigarLen))
		copy(buf[off+2:off+2+cigarLen], aln.Cigar[:cigarLen])
		off += 2 + cigarLen
		snpCount := min(min(len(aln.SNPs), len(aln.SNPBases)), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(snpCount))
		off += 2
		for i := 0; i < snpCount; i++ {
			binary.LittleEndian.PutUint32(buf[off:off+4], aln.SNPs[i])
			off += 4
			base := aln.SNPBases[i]
			if normalizeBase(base) == 0 {
				base = 'N'
			}
			buf[off] = base
			off++
		}
	}
	return buf
}

func encodeCoverageTile(start, end int, bins []uint16) []byte {
	buf := make([]byte, 13+2*len(bins))
	buf[0] = 1
	binary.LittleEndian.PutUint32(buf[1:5], uint32(start))
	binary.LittleEndian.PutUint32(buf[5:9], uint32(end))
	binary.LittleEndian.PutUint32(buf[9:13], uint32(len(bins)))
	off := 13
	for _, d := range bins {
		binary.LittleEndian.PutUint16(buf[off:off+2], d)
		off += 2
	}
	return buf
}

func encodeGCPlotTile(start, end, windowLen int, values []float32) []byte {
	if values == nil {
		values = make([]float32, 0)
	}
	buf := make([]byte, 17+4*len(values))
	buf[0] = 3
	binary.LittleEndian.PutUint32(buf[1:5], uint32(start))
	binary.LittleEndian.PutUint32(buf[5:9], uint32(end))
	binary.LittleEndian.PutUint32(buf[9:13], uint32(windowLen))
	binary.LittleEndian.PutUint32(buf[13:17], uint32(len(values)))
	off := 17
	for _, v := range values {
		binary.LittleEndian.PutUint32(buf[off:off+4], math.Float32bits(v))
		off += 4
	}
	return buf
}

func computeGCPlotValues(gcPrefix []uint32, atgcPrefix []uint32, tileStart, tileEnd, windowLen, bins int) []float32 {
	if bins <= 0 {
		bins = plotTileBins
	}
	out := make([]float32, bins)
	if tileEnd <= tileStart || len(gcPrefix) == 0 || len(atgcPrefix) == 0 {
		for i := range out {
			out[i] = -1.0
		}
		return out
	}
	seqLen := min(len(gcPrefix), len(atgcPrefix)) - 1
	if seqLen <= 0 {
		for i := range out {
			out[i] = -1.0
		}
		return out
	}
	if windowLen <= 0 {
		windowLen = 1
	}
	tileSpan := tileEnd - tileStart
	for i := range bins {
		center := tileStart + int((float64(i)+0.5)*float64(tileSpan)/float64(bins))
		w0 := center - windowLen/2
		w1 := w0 + windowLen
		if w0 < 0 {
			w0 = 0
		}
		if w1 > seqLen {
			w1 = seqLen
		}
		if w1 <= w0 {
			out[i] = -1.0
			continue
		}
		atgc := int(atgcPrefix[w1] - atgcPrefix[w0])
		if atgc <= 0 {
			out[i] = -1.0
			continue
		}
		gc := int(gcPrefix[w1] - gcPrefix[w0])
		out[i] = float32(float64(gc) / float64(atgc))
	}
	return out
}

func buildGCPrefix(seq string) ([]uint32, []uint32) {
	gc := make([]uint32, len(seq)+1)
	atgc := make([]uint32, len(seq)+1)
	for i := 0; i < len(seq); i++ {
		gc[i+1] = gc[i]
		atgc[i+1] = atgc[i]
		switch seq[i] {
		case 'G', 'g', 'C', 'c':
			gc[i+1]++
			atgc[i+1]++
		case 'A', 'a', 'T', 't', 'U', 'u':
			atgc[i+1]++
		}
	}
	return gc, atgc
}

func encodeAnnotations(start, end int, feats []Feature) []byte {
	payloadLen := 12
	for _, f := range feats {
		payloadLen += 18 + len(f.SeqName) + len(f.Source) + len(f.Type) + len(f.Attributes)
	}
	buf := make([]byte, payloadLen)
	binary.LittleEndian.PutUint32(buf[0:4], uint32(start))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(end))
	binary.LittleEndian.PutUint32(buf[8:12], uint32(len(feats)))
	off := 12
	for _, f := range feats {
		binary.LittleEndian.PutUint32(buf[off:off+4], uint32(f.Start))
		binary.LittleEndian.PutUint32(buf[off+4:off+8], uint32(f.End))
		buf[off+8] = f.Strand
		buf[off+9] = 0
		binary.LittleEndian.PutUint16(buf[off+10:off+12], uint16(len(f.SeqName)))
		copy(buf[off+12:off+12+len(f.SeqName)], f.SeqName)
		off += 12 + len(f.SeqName)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(f.Source)))
		copy(buf[off+2:off+2+len(f.Source)], f.Source)
		off += 2 + len(f.Source)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(f.Type)))
		copy(buf[off+2:off+2+len(f.Type)], f.Type)
		off += 2 + len(f.Type)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(f.Attributes)))
		copy(buf[off+2:off+2+len(f.Attributes)], f.Attributes)
		off += 2 + len(f.Attributes)
	}
	return buf
}

func gatherInputFiles(path string) ([]string, error) {
	st, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if !st.IsDir() {
		return []string{path}, nil
	}

	var files []string
	err = filepath.WalkDir(path, func(p string, d os.DirEntry, walkErr error) error {
		if walkErr != nil {
			return walkErr
		}
		if d.IsDir() {
			return nil
		}
		kind := detectInputKindByName(d.Name())
		if kind == inputKindUnknown {
			var detectErr error
			kind, detectErr = detectInputKind(p)
			if detectErr != nil {
				return detectErr
			}
		}
		if kind != inputKindUnknown {
			files = append(files, p)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	if len(files) == 0 {
		return nil, errors.New("no supported genome files found")
	}
	slices.Sort(files)
	return files, nil
}

func detectInputKind(path string) (inputKind, error) {
	if kind := detectInputKindByName(path); kind != inputKindUnknown {
		return kind, nil
	}
	return detectInputKindByContent(path)
}

func detectInputKindByName(name string) inputKind {
	base := strings.ToLower(filepath.Base(name))
	for _, suffix := range []string{".gz", ".bgz", ".bz2", ".xz", ".zst", ".zstd"} {
		if strings.HasSuffix(base, suffix) {
			base = strings.TrimSuffix(base, suffix)
			break
		}
	}
	switch filepath.Ext(base) {
	case ".fa", ".fasta", ".fna", ".ffn", ".frn", ".faa":
		return inputKindFASTA
	case ".gff", ".gff3":
		return inputKindGFF3
	case ".embl", ".gb", ".gbk", ".genbank":
		return inputKindFlatFile
	default:
		return inputKindUnknown
	}
}

func detectInputKindByContent(path string) (inputKind, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return inputKindUnknown, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		line = strings.TrimPrefix(line, "\uFEFF")
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, ">") {
			return inputKindFASTA, nil
		}
		if strings.HasPrefix(line, "##gff-version") || looksLikeGFF3Data(line) {
			return inputKindGFF3, nil
		}
		if strings.HasPrefix(line, "LOCUS ") || strings.HasPrefix(line, "ID   ") {
			return inputKindFlatFile, nil
		}
		// First non-empty line was not identifiable.
		return inputKindUnknown, nil
	}
	if err := scanner.Err(); err != nil {
		return inputKindUnknown, err
	}
	return inputKindUnknown, nil
}

func looksLikeGFF3Data(line string) bool {
	if strings.HasPrefix(line, "#") {
		return false
	}
	// GFF3 data rows have 9 tab-separated columns.
	return strings.Count(line, "\t") >= 8
}

func parseFASTA(path string) (map[string]string, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	seqs := make(map[string]string)
	var current string
	var b strings.Builder

	flush := func() {
		if current == "" {
			return
		}
		seqs[current] = strings.ToUpper(b.String())
		b.Reset()
	}

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		if strings.HasPrefix(line, ">") {
			flush()
			hdr := strings.TrimSpace(line[1:])
			fields := strings.Fields(hdr)
			if len(fields) == 0 {
				return nil, fmt.Errorf("invalid FASTA header in %s", path)
			}
			current = fields[0]
			continue
		}
		if current == "" {
			return nil, fmt.Errorf("FASTA sequence before header in %s", path)
		}
		for _, r := range line {
			if unicode.IsLetter(r) || r == '*' || r == '-' {
				b.WriteRune(unicode.ToUpper(r))
			}
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	flush()

	if len(seqs) == 0 {
		return nil, fmt.Errorf("no sequences found in %s", path)
	}
	return seqs, nil
}

func parseGFF3(path string) (map[string][]Feature, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()

	scanner := bufio.NewScanner(f)
	out := make(map[string][]Feature)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		cols := strings.Split(line, "\t")
		if len(cols) < 9 {
			continue
		}
		start, err := strconv.Atoi(cols[3])
		if err != nil {
			continue
		}
		end, err := strconv.Atoi(cols[4])
		if err != nil {
			continue
		}
		strand := byte('.')
		if cols[6] != "" {
			strand = cols[6][0]
		}
		feat := Feature{
			SeqName:    cols[0],
			Source:     cols[1],
			Type:       cols[2],
			Start:      start - 1,
			End:        end,
			Strand:     strand,
			Attributes: cols[8],
		}
		out[feat.SeqName] = append(out[feat.SeqName], feat)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}
	return out, nil
}

func parseFlatFile(path string) (map[string]string, map[string][]Feature, error) {
	f, err := xopen.Ropen(path)
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()

	seqs := make(map[string]string)
	feats := make(map[string][]Feature)

	scanner := bufio.NewScanner(f)
	var recName string
	var seqBuilder strings.Builder
	var inFeatures bool
	var inSeq bool
	var pending *Feature

	flushPending := func() {
		if pending == nil || recName == "" {
			return
		}
		feats[recName] = append(feats[recName], *pending)
		pending = nil
	}
	flushRecord := func() {
		flushPending()
		if recName != "" {
			if seqBuilder.Len() > 0 {
				seqs[recName] = strings.ToUpper(seqBuilder.String())
			}
		}
		recName = ""
		seqBuilder.Reset()
		inFeatures = false
		inSeq = false
		pending = nil
	}

	for scanner.Scan() {
		line := scanner.Text()
		trim := strings.TrimSpace(line)

		if strings.HasPrefix(line, "LOCUS") {
			flushRecord()
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				recName = fields[1]
			}
			continue
		}
		if strings.HasPrefix(line, "ID") && len(line) > 2 && unicode.IsSpace(rune(line[2])) {
			flushRecord()
			rest := strings.TrimSpace(line[2:])
			fields := strings.Fields(rest)
			if len(fields) > 0 {
				recName = strings.TrimSuffix(fields[0], ";")
			}
			continue
		}
		if strings.HasPrefix(trim, "FEATURES") || strings.HasPrefix(line, "FH") {
			inFeatures = true
			inSeq = false
			continue
		}
		if strings.HasPrefix(trim, "ORIGIN") || strings.HasPrefix(line, "SQ") {
			flushPending()
			inFeatures = false
			inSeq = true
			continue
		}
		if trim == "//" {
			flushRecord()
			continue
		}

		if inSeq {
			for _, r := range line {
				if unicode.IsLetter(r) {
					seqBuilder.WriteRune(unicode.ToUpper(r))
				}
			}
			continue
		}

		if !inFeatures || recName == "" {
			continue
		}

		if strings.Contains(line, "/") && strings.Contains(strings.TrimSpace(line), "=") {
			if pending != nil {
				q := strings.TrimSpace(line)
				if pending.Attributes == "" {
					pending.Attributes = q
				} else {
					pending.Attributes += ";" + q
				}
			}
			continue
		}

		featureType, location, ok := parseFeatureLine(line)
		if !ok {
			continue
		}
		flushPending()
		start, end := parseLocation(location)
		if end <= start {
			continue
		}
		strand := byte('+')
		if strings.Contains(location, "complement") {
			strand = '-'
		}
		pending = &Feature{
			SeqName: recName,
			Source:  "flatfile",
			Type:    featureType,
			Start:   start,
			End:     end,
			Strand:  strand,
		}
	}
	if err := scanner.Err(); err != nil {
		return nil, nil, err
	}
	flushRecord()

	return seqs, feats, nil
}

func parseFeatureLine(line string) (featureType, location string, ok bool) {
	if strings.HasPrefix(line, "FT") {
		rest := ""
		if len(line) > 2 {
			rest = strings.TrimSpace(line[2:])
		}
		fields := strings.Fields(rest)
		if len(fields) < 2 {
			return "", "", false
		}
		return fields[0], strings.Join(fields[1:], " "), true
	}
	if len(line) >= 21 && strings.HasPrefix(line, "     ") {
		key := strings.TrimSpace(line[:21])
		if key == "" || strings.HasPrefix(strings.TrimSpace(line), "/") {
			return "", "", false
		}
		loc := strings.TrimSpace(line[21:])
		if loc == "" {
			return "", "", false
		}
		return key, loc, true
	}
	return "", "", false
}

func parseLocation(location string) (int, int) {
	nums := digitsRegexp.FindAllString(location, -1)
	if len(nums) == 0 {
		return 0, 0
	}
	minVal := int(^uint(0) >> 1)
	maxVal := 0
	for _, n := range nums {
		v, err := strconv.Atoi(n)
		if err != nil {
			continue
		}
		if v < minVal {
			minVal = v
		}
		if v > maxVal {
			maxVal = v
		}
	}
	if minVal == int(^uint(0)>>1) {
		return 0, 0
	}
	if minVal > 0 {
		minVal--
	}
	return minVal, maxVal
}

func mergeFeatures(dst map[string][]Feature, src map[string][]Feature) {
	for chr, feats := range src {
		dst[chr] = append(dst[chr], feats...)
	}
}

func maxFeatureEnd(features []Feature) int {
	maxEnd := 0
	for _, f := range features {
		if f.End > maxEnd {
			maxEnd = f.End
		}
	}
	return maxEnd
}
