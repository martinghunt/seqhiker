package main

import (
	"container/list"
	"encoding/binary"
	"errors"
	"fmt"
	"math"
	"sort"
	"strings"
	"sync"

	"github.com/biogo/hts/sam"
)

const baseTileSize = 1024
const (
	readTileCacheKind      uint8 = 1
	covTileCacheKind       uint8 = 2
	plotTileCacheKind      uint8 = 3
	annotTileCacheKind     uint8 = 4
	strandCovTileCacheKind uint8 = 5
	stopCodonTileCacheKind uint8 = 6
	variantTileCacheKind   uint8 = 7
	maxScannedTileReads          = 2000000
	snpDetailMaxZoom       uint8 = 5
	plotTileBins                 = 256
	stopCodonTileBins            = 512
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
	Start         int
	End           int
	Name          string
	MapQ          uint8
	Flags         uint16
	Cigar         string
	SoftClipLeft  string
	SoftClipRight string
	SNPs          []uint32
	SNPBases      []byte
	Reverse       bool
	MateStart     int
	MateEnd       int
	MateRawStart  int
	MateRawEnd    int
	MateRefID     int
	FragLen       int
	MateSameRef   bool
}

type DNAExactHit struct {
	Start  int
	End    int
	Strand byte
}

type GenomeSnapshot struct {
	Sequences   map[string]string
	Features    map[string][]Feature
	ChromLength map[string]int
}

type ComparisonGenomeInfo struct {
	ID           uint16
	Name         string
	Path         string
	Length       uint32
	SegmentCount uint16
	FeatureCount uint32
	Segments     []ComparisonSegmentInfo
}

type ComparisonSegmentInfo struct {
	Name         string
	Start        uint32
	End          uint32
	FeatureCount uint32
}

type ComparisonPairInfo struct {
	ID             uint16
	TopGenomeID    uint16
	BottomGenomeID uint16
	BlockCount     uint32
	Status         uint8
}

type ComparisonBlock struct {
	QueryStart       uint32
	QueryEnd         uint32
	TargetStart      uint32
	TargetEnd        uint32
	PercentIdentX100 uint16
	SameStrand       bool
}

type ComparisonBlockDetail struct {
	Block    ComparisonBlock
	Ops      string
	Variants []ComparisonVariantInfo
}

type ComparisonVariantInfo struct {
	Kind      byte
	QueryPos  uint32
	TargetPos uint32
	RefBases  string
	AltBases  string
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
	variantSources   map[uint16]*variantSource
	variantOrder     []uint16
	nextVariantID    uint16
	globalGeneration uint64
	maxTileRecs      uint32
	maxReadZoom      uint8

	tileCacheMaxBytes int64
	tileCacheBytes    int64
	tileCache         map[tileCacheKey]*list.Element
	tileLRU           *list.List
	prefetchRadius    int
	prefetchSem       chan struct{}

	comparisonGenomes      map[uint16]*comparisonGenome
	comparisonGenomeOrder  []uint16
	nextComparisonGenomeID uint16
	comparisonPairs        map[uint16]*comparisonPair
	comparisonPairOrder    []uint16
	nextComparisonPairID   uint16
	comparisonCacheDir     string
}

func NewEngine() *Engine {
	return &Engine{
		chrToID:                make(map[string]uint16),
		idToChr:                make(map[uint16]string),
		chrLength:              make(map[string]int),
		sequences:              make(map[string]string),
		features:               make(map[string][]Feature),
		gcPrefix:               make(map[string][]uint32),
		atgcPrefix:             make(map[string][]uint32),
		bamSources:             make(map[uint16]*bamSource),
		bamOrder:               make([]uint16, 0, 4),
		nextBAMSourceID:        1,
		variantSources:         make(map[uint16]*variantSource),
		variantOrder:           make([]uint16, 0, 4),
		nextVariantID:          1,
		globalGeneration:       1,
		maxTileRecs:            5000,
		maxReadZoom:            7,
		tileCacheMaxBytes:      512 << 20, // 512 MiB cap keeps backend well under 2 GiB.
		tileCache:              make(map[tileCacheKey]*list.Element),
		tileLRU:                list.New(),
		prefetchRadius:         1,
		prefetchSem:            make(chan struct{}, 4),
		comparisonGenomes:      make(map[uint16]*comparisonGenome),
		comparisonGenomeOrder:  make([]uint16, 0, 4),
		nextComparisonGenomeID: 1,
		comparisonPairs:        make(map[uint16]*comparisonPair),
		comparisonPairOrder:    make([]uint16, 0, 4),
		nextComparisonPairID:   1,
		comparisonCacheDir:     defaultComparisonCacheDir(),
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
	return e.loadGenomeEntries(entries)
}

func (e *Engine) LoadGenomeFiles(paths []string) error {
	if len(paths) == 0 {
		return errors.New("load genome requires at least one input path")
	}
	entries := make([]string, 0, len(paths))
	for _, path := range paths {
		if path == "" {
			continue
		}
		entries = append(entries, path)
	}
	if len(entries) == 0 {
		return errors.New("load genome requires at least one input path")
	}
	return e.loadGenomeEntries(entries)
}

func (e *Engine) loadGenomeEntries(entries []string) error {
	snapshot, hasSequenceInput, err := loadGenomeSnapshotEntries(entries)
	if err != nil {
		return err
	}
	embeddedGFFOnly, err := entriesAreEmbeddedGFF3(entries)
	if err != nil {
		return err
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	if len(e.sequences) > 0 && hasSequenceInput && len(snapshot.Sequences) > 0 && embeddedGFFOnly {
		if !sameSequenceSet(e.sequences, snapshot.Sequences) {
			return errors.New("embedded GFF3 sequence does not match loaded reference")
		}
		hasSequenceInput = false
	}

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
		e.resetVariantStateLocked()

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
	e.globalGeneration++
	e.resetTileCacheLocked()

	return nil
}

func sameSequenceSet(current map[string]string, incoming map[string]string) bool {
	if len(current) != len(incoming) {
		return false
	}
	for chr, seq := range current {
		if incoming[chr] != seq {
			return false
		}
	}
	return true
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

func (e *Engine) InspectInput(path string) (bool, bool, bool, bool, bool, error) {
	entries, err := gatherInputFiles(path)
	if err != nil {
		kind, kindErr := detectInputKind(path)
		if kindErr == nil && kind == inputKindComparisonSession {
			return false, false, false, true, false, nil
		}
		return false, false, false, false, false, err
	}
	hasSequence := false
	hasAnnotation := false
	hasEmbeddedGFF3Sequence := false
	hasVariants := false
	for _, p := range entries {
		kind, err := detectInputKind(p)
		if err != nil {
			return false, false, false, false, false, err
		}
		switch kind {
		case inputKindFASTA, inputKindFlatFile:
			hasSequence = true
		case inputKindGFF3:
			hasAnnotation = true
			hasEmbeddedSeq, err := gff3HasEmbeddedSequence(p)
			if err != nil {
				return false, false, false, false, false, err
			}
			if hasEmbeddedSeq {
				hasSequence = true
				hasEmbeddedGFF3Sequence = true
			}
		case inputKindVCF:
			hasVariants = true
		case inputKindComparisonSession:
			return false, false, false, true, false, nil
		default:
			return false, false, false, false, false, fmt.Errorf("unsupported genome/annotation file: %s", p)
		}
	}
	return hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, false, hasVariants, nil
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

func recordDedupKey(rec *sam.Record) string {
	if rec == nil {
		return ""
	}
	refID := -1
	if rec.Ref != nil {
		refID = rec.Ref.ID()
	}
	return fmt.Sprintf(
		"%s|%d|%d|%d|%d|%d|%s|%d",
		rec.Name,
		refID,
		rec.Start(),
		rec.End(),
		rec.Flags,
		rec.MapQ,
		rec.Cigar.String(),
		rec.MatePos,
	)
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

func (e *Engine) resetVariantStateLocked() {
	e.variantSources = make(map[uint16]*variantSource)
	e.variantOrder = e.variantOrder[:0]
	e.nextVariantID = 1
	e.globalGeneration++
	e.resetTileCacheLocked()
}

func encodeAlignmentTile(start, end int, alns []Alignment) []byte {
	payloadLen := 13
	for _, aln := range alns {
		nameLen := min(len(aln.Name), 0xFFFF)
		cigarLen := min(len(aln.Cigar), 0xFFFF)
		leftSoftLen := min(len(aln.SoftClipLeft), 0xFFFF)
		rightSoftLen := min(len(aln.SoftClipRight), 0xFFFF)
		snpCount := min(min(len(aln.SNPs), len(aln.SNPBases)), 0xFFFF)
		// Fixed per-record bytes:
		// 38 header + 2 cigar_len + 2 left_soft_len + 2 right_soft_len + 2 snp_count + variable fields.
		payloadLen += 46 + nameLen + cigarLen + leftSoftLen + rightSoftLen + 5*snpCount
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
		mateRawStart := uint32(0xFFFFFFFF)
		mateRawEnd := uint32(0xFFFFFFFF)
		mateRefID := uint32(0xFFFFFFFF)
		if aln.MateSameRef && aln.MateStart >= 0 && aln.MateEnd > aln.MateStart {
			mateStart = uint32(aln.MateStart)
			mateEnd = uint32(aln.MateEnd)
		}
		if aln.MateRawStart >= 0 && aln.MateRawEnd > aln.MateRawStart {
			mateRawStart = uint32(aln.MateRawStart)
			mateRawEnd = uint32(aln.MateRawEnd)
		}
		if aln.MateRefID >= 0 {
			mateRefID = uint32(aln.MateRefID)
		}
		binary.LittleEndian.PutUint32(buf[off+12:off+16], mateStart)
		binary.LittleEndian.PutUint32(buf[off+16:off+20], mateEnd)
		binary.LittleEndian.PutUint32(buf[off+20:off+24], uint32(max(0, aln.FragLen)))
		binary.LittleEndian.PutUint32(buf[off+24:off+28], mateRawStart)
		binary.LittleEndian.PutUint32(buf[off+28:off+32], mateRawEnd)
		binary.LittleEndian.PutUint32(buf[off+32:off+36], mateRefID)
		nameLen := min(len(aln.Name), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off+36:off+38], uint16(nameLen))
		copy(buf[off+38:off+38+nameLen], aln.Name[:nameLen])
		off += 38 + nameLen
		cigarLen := min(len(aln.Cigar), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(cigarLen))
		copy(buf[off+2:off+2+cigarLen], aln.Cigar[:cigarLen])
		off += 2 + cigarLen
		leftSoftLen := min(len(aln.SoftClipLeft), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(leftSoftLen))
		copy(buf[off+2:off+2+leftSoftLen], aln.SoftClipLeft[:leftSoftLen])
		off += 2 + leftSoftLen
		rightSoftLen := min(len(aln.SoftClipRight), 0xFFFF)
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(rightSoftLen))
		copy(buf[off+2:off+2+rightSoftLen], aln.SoftClipRight[:rightSoftLen])
		off += 2 + rightSoftLen
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

func encodeStrandCoverageTile(start, end int, forwardBins, reverseBins []uint16) []byte {
	n := min(len(forwardBins), len(reverseBins))
	buf := make([]byte, 13+4*n)
	buf[0] = 4
	binary.LittleEndian.PutUint32(buf[1:5], uint32(start))
	binary.LittleEndian.PutUint32(buf[5:9], uint32(end))
	binary.LittleEndian.PutUint32(buf[9:13], uint32(n))
	off := 13
	for i := 0; i < n; i++ {
		binary.LittleEndian.PutUint16(buf[off:off+2], forwardBins[i])
		off += 2
	}
	for i := 0; i < n; i++ {
		binary.LittleEndian.PutUint16(buf[off:off+2], reverseBins[i])
		off += 2
	}
	return buf
}

func avgDepthBinValue(sum uint64, binW int) uint16 {
	if binW <= 0 {
		binW = 1
	}
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
	return uint16(avgDepth)
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
