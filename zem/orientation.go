package main

import (
	"encoding/binary"
	"fmt"
	"strconv"
	"strings"
)

const (
	moveActionLeft  byte = 1
	moveActionRight byte = 2
	moveActionStart byte = 3
	moveActionEnd   byte = 4
)

type cigarOp struct {
	Len int
	Op  byte
}

func clampWindowToLength(start, end, chromLen int) (int, int) {
	if start < 0 {
		start = 0
	}
	if start > chromLen {
		start = chromLen
	}
	if end < start {
		end = start
	}
	if end > chromLen {
		end = chromLen
	}
	return start, end
}

func rawWindowForOrientation(start, end, chromLen int, reversed bool) (int, int) {
	start, end = clampWindowToLength(start, end, chromLen)
	if !reversed {
		return start, end
	}
	return chromLen - end, chromLen - start
}

func reverseIntervalForLength(start, end, chromLen int) (int, int) {
	return chromLen - end, chromLen - start
}

func reversePointForLength(pos, chromLen int) int {
	return chromLen - 1 - pos
}

func complementIUPACBase(b byte) byte {
	switch b {
	case 'A', 'a':
		return 'T'
	case 'C', 'c':
		return 'G'
	case 'G', 'g':
		return 'C'
	case 'T', 't', 'U', 'u':
		return 'A'
	case 'R', 'r':
		return 'Y'
	case 'Y', 'y':
		return 'R'
	case 'S', 's':
		return 'S'
	case 'W', 'w':
		return 'W'
	case 'K', 'k':
		return 'M'
	case 'M', 'm':
		return 'K'
	case 'B', 'b':
		return 'V'
	case 'D', 'd':
		return 'H'
	case 'H', 'h':
		return 'D'
	case 'V', 'v':
		return 'B'
	case 'N', 'n':
		return 'N'
	default:
		return 0
	}
}

func isSimpleDNASequence(seq string) bool {
	if seq == "" {
		return true
	}
	for i := 0; i < len(seq); i++ {
		if complementIUPACBase(seq[i]) == 0 {
			return false
		}
	}
	return true
}

func reverseComplementFlexible(seq string) string {
	if !isSimpleDNASequence(seq) {
		return seq
	}
	out := make([]byte, len(seq))
	for i := 0; i < len(seq); i++ {
		out[len(seq)-1-i] = complementIUPACBase(seq[i])
	}
	return string(out)
}

func reverseComplementAltSummary(summary string) string {
	if summary == "" {
		return ""
	}
	parts := strings.Split(summary, ",")
	for i := range parts {
		parts[i] = reverseComplementFlexible(parts[i])
	}
	return strings.Join(parts, ",")
}

func reverseComplementSampleText(text string) string {
	if text == "" || text == "." {
		return text
	}
	parts := strings.Split(text, "/")
	for i := range parts {
		parts[i] = reverseComplementFlexible(strings.TrimSpace(parts[i]))
	}
	return strings.Join(parts, "/")
}

func transformVariantRecordForLength(record variantRecord, chromLen int) variantRecord {
	out := record
	out.Start = uint32(chromLen - int(record.End))
	out.End = uint32(chromLen - int(record.Start))
	out.Ref = reverseComplementFlexible(record.Ref)
	out.AltSummary = reverseComplementAltSummary(record.AltSummary)
	if len(record.SampleTexts) > 0 {
		out.SampleTexts = make([]string, len(record.SampleTexts))
		for i, text := range record.SampleTexts {
			out.SampleTexts[i] = reverseComplementSampleText(text)
		}
	}
	return out
}

func transformVariantDetailForLength(detail variantDetail, chromLen int) variantDetail {
	out := detail
	out.Start = uint32(chromLen - int(detail.End))
	out.End = uint32(chromLen - int(detail.Start))
	out.Ref = reverseComplementFlexible(detail.Ref)
	out.AltSummary = reverseComplementAltSummary(detail.AltSummary)
	return out
}

func parseCigarString(cigar string) ([]cigarOp, bool) {
	if cigar == "" {
		return nil, true
	}
	ops := make([]cigarOp, 0, 8)
	num := 0
	haveNum := false
	for i := 0; i < len(cigar); i++ {
		ch := cigar[i]
		if ch >= '0' && ch <= '9' {
			num = num*10 + int(ch-'0')
			haveNum = true
			continue
		}
		if !haveNum {
			return nil, false
		}
		ops = append(ops, cigarOp{Len: num, Op: ch})
		num = 0
		haveNum = false
	}
	if haveNum {
		return nil, false
	}
	return ops, true
}

func reverseCigarString(cigar string) string {
	ops, ok := parseCigarString(cigar)
	if !ok {
		return cigar
	}
	if len(ops) == 0 {
		return ""
	}
	var b strings.Builder
	for i := len(ops) - 1; i >= 0; i-- {
		b.WriteString(strconv.Itoa(ops[i].Len))
		b.WriteByte(ops[i].Op)
	}
	return b.String()
}

func reverseUint16s(values []uint16) {
	for i, j := 0, len(values)-1; i < j; i, j = i+1, j-1 {
		values[i], values[j] = values[j], values[i]
	}
}

func decodeAlignmentTilePayload(payload []byte) (int, int, []Alignment, error) {
	if len(payload) < 13 || payload[0] != 2 {
		return 0, 0, nil, fmt.Errorf("invalid alignment payload header")
	}
	start := int(binary.LittleEndian.Uint32(payload[1:5]))
	end := int(binary.LittleEndian.Uint32(payload[5:9]))
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	alns := make([]Alignment, 0, count)
	off := 13
	for i := 0; i < count; i++ {
		if off+38 > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment payload too short")
		}
		aln := Alignment{
			Start:   int(binary.LittleEndian.Uint32(payload[off : off+4])),
			End:     int(binary.LittleEndian.Uint32(payload[off+4 : off+8])),
			MapQ:    payload[off+8],
			Reverse: payload[off+9] != 0,
			Flags:   binary.LittleEndian.Uint16(payload[off+10 : off+12]),
			FragLen: int(binary.LittleEndian.Uint32(payload[off+20 : off+24])),
		}
		mateStartRaw := binary.LittleEndian.Uint32(payload[off+12 : off+16])
		mateEndRaw := binary.LittleEndian.Uint32(payload[off+16 : off+20])
		mateRawStartRaw := binary.LittleEndian.Uint32(payload[off+24 : off+28])
		mateRawEndRaw := binary.LittleEndian.Uint32(payload[off+28 : off+32])
		mateRefIDRaw := binary.LittleEndian.Uint32(payload[off+32 : off+36])
		nameLen := int(binary.LittleEndian.Uint16(payload[off+36 : off+38]))
		off += 38
		if off+nameLen > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment name overflow")
		}
		aln.Name = string(payload[off : off+nameLen])
		off += nameLen
		if off+2 > len(payload) {
			return 0, 0, nil, fmt.Errorf("missing cigar length")
		}
		cigarLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+cigarLen > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment cigar overflow")
		}
		aln.Cigar = string(payload[off : off+cigarLen])
		off += cigarLen
		if off+2 > len(payload) {
			return 0, 0, nil, fmt.Errorf("missing left soft-clip length")
		}
		leftSoftLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+leftSoftLen > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment left soft-clip overflow")
		}
		aln.SoftClipLeft = string(payload[off : off+leftSoftLen])
		off += leftSoftLen
		if off+2 > len(payload) {
			return 0, 0, nil, fmt.Errorf("missing right soft-clip length")
		}
		rightSoftLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+rightSoftLen > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment right soft-clip overflow")
		}
		aln.SoftClipRight = string(payload[off : off+rightSoftLen])
		off += rightSoftLen
		if off+2 > len(payload) {
			return 0, 0, nil, fmt.Errorf("missing snp count")
		}
		snpCount := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+5*snpCount > len(payload) {
			return 0, 0, nil, fmt.Errorf("alignment snp overflow")
		}
		if snpCount > 0 {
			aln.SNPs = make([]uint32, snpCount)
			aln.SNPBases = make([]byte, snpCount)
			for j := 0; j < snpCount; j++ {
				aln.SNPs[j] = binary.LittleEndian.Uint32(payload[off : off+4])
				off += 4
				aln.SNPBases[j] = payload[off]
				off++
			}
		}
		aln.MateStart = -1
		aln.MateEnd = -1
		aln.MateRawStart = -1
		aln.MateRawEnd = -1
		aln.MateRefID = -1
		if mateStartRaw != 0xFFFFFFFF && mateEndRaw != 0xFFFFFFFF {
			aln.MateStart = int(mateStartRaw)
			aln.MateEnd = int(mateEndRaw)
			aln.MateSameRef = true
		}
		if mateRawStartRaw != 0xFFFFFFFF && mateRawEndRaw != 0xFFFFFFFF {
			aln.MateRawStart = int(mateRawStartRaw)
			aln.MateRawEnd = int(mateRawEndRaw)
		}
		if mateRefIDRaw != 0xFFFFFFFF {
			aln.MateRefID = int(mateRefIDRaw)
		}
		alns = append(alns, aln)
	}
	return start, end, alns, nil
}

func decodeCoverageTilePayload(payload []byte) (int, int, []uint16, error) {
	if len(payload) < 13 || payload[0] != 1 {
		return 0, 0, nil, fmt.Errorf("invalid coverage payload header")
	}
	start := int(binary.LittleEndian.Uint32(payload[1:5]))
	end := int(binary.LittleEndian.Uint32(payload[5:9]))
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	if len(payload) < 13+2*count {
		return 0, 0, nil, fmt.Errorf("coverage payload too short")
	}
	bins := make([]uint16, count)
	off := 13
	for i := 0; i < count; i++ {
		bins[i] = binary.LittleEndian.Uint16(payload[off : off+2])
		off += 2
	}
	return start, end, bins, nil
}

func decodeStrandCoverageTilePayload(payload []byte) (int, int, []uint16, []uint16, error) {
	if len(payload) < 13 || payload[0] != 4 {
		return 0, 0, nil, nil, fmt.Errorf("invalid strand coverage payload header")
	}
	start := int(binary.LittleEndian.Uint32(payload[1:5]))
	end := int(binary.LittleEndian.Uint32(payload[5:9]))
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	if len(payload) < 13+4*count {
		return 0, 0, nil, nil, fmt.Errorf("strand coverage payload too short")
	}
	forward := make([]uint16, count)
	reverse := make([]uint16, count)
	off := 13
	for i := 0; i < count; i++ {
		forward[i] = binary.LittleEndian.Uint16(payload[off : off+2])
		off += 2
	}
	for i := 0; i < count; i++ {
		reverse[i] = binary.LittleEndian.Uint16(payload[off : off+2])
		off += 2
	}
	return start, end, forward, reverse, nil
}

func transformSNPsForLength(snps []uint32, bases []byte, chromLen int) ([]uint32, []byte) {
	if len(snps) == 0 || len(bases) == 0 {
		return nil, nil
	}
	count := len(snps)
	if len(bases) < count {
		count = len(bases)
	}
	outPos := make([]uint32, 0, count)
	outBases := make([]byte, 0, count)
	for i := count - 1; i >= 0; i-- {
		outPos = append(outPos, uint32(reversePointForLength(int(snps[i]), chromLen)))
		base := complementIUPACBase(bases[i])
		if base == 0 {
			base = 'N'
		}
		outBases = append(outBases, base)
	}
	return outPos, outBases
}

func (e *Engine) transformAlignmentForChromLocked(chr string, aln Alignment) Alignment {
	chromLen := e.rawChrLength[chr]
	out := aln
	out.Start, out.End = reverseIntervalForLength(aln.Start, aln.End, chromLen)
	out.Reverse = !aln.Reverse
	out.Cigar = reverseCigarString(aln.Cigar)
	out.SoftClipLeft = reverseComplementFlexible(aln.SoftClipRight)
	out.SoftClipRight = reverseComplementFlexible(aln.SoftClipLeft)
	out.SNPs, out.SNPBases = transformSNPsForLength(aln.SNPs, aln.SNPBases, chromLen)
	out.Flags = e.transformAlignmentFlagsLocked(chr, aln)
	if aln.MateStart >= 0 && aln.MateEnd > aln.MateStart {
		out.MateStart, out.MateEnd = reverseIntervalForLength(aln.MateStart, aln.MateEnd, chromLen)
	}
	if aln.MateRawStart >= 0 && aln.MateRawEnd > aln.MateRawStart {
		mateLen := chromLen
		mateReversed := e.chrReverse[chr]
		if aln.MateRefID >= 0 {
			if mateChr, ok := e.idToChr[uint16(aln.MateRefID)]; ok {
				mateLen = e.rawChrLength[mateChr]
				mateReversed = e.chrReverse[mateChr]
			} else {
				mateReversed = false
			}
		}
		if mateReversed {
			out.MateRawStart, out.MateRawEnd = reverseIntervalForLength(aln.MateRawStart, aln.MateRawEnd, mateLen)
		}
	}
	return out
}

func (e *Engine) transformAlignmentFlagsLocked(chr string, aln Alignment) uint16 {
	flags := aln.Flags
	flags ^= 0x10
	mateReversed := false
	if aln.MateRefID >= 0 {
		if mateChr, ok := e.idToChr[uint16(aln.MateRefID)]; ok {
			mateReversed = e.chrReverse[mateChr]
		}
	} else if aln.MateStart >= 0 || aln.MateRawStart >= 0 {
		mateReversed = e.chrReverse[chr]
	}
	if mateReversed {
		flags ^= 0x20
	}
	return flags
}

func (e *Engine) SetChromosomeOrientation(chrID uint16, reversed bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return fmt.Errorf("unknown chromosome id %d", chrID)
	}
	e.ensureBrowserRawMaterialLocked(chr)
	if e.chrReverse[chr] == reversed {
		return nil
	}
	e.chrReverse[chr] = reversed
	e.rebuildBrowserChromosomeLocked(chr)
	e.invalidateOrientationDependentStateLocked()
	return nil
}

func (e *Engine) SetAllChromosomeOrientations(reversed bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	changed := false
	for _, chr := range e.chromOrder {
		e.ensureBrowserRawMaterialLocked(chr)
		if e.chrReverse[chr] == reversed {
			continue
		}
		e.chrReverse[chr] = reversed
		e.rebuildBrowserChromosomeLocked(chr)
		changed = true
	}
	if changed {
		e.invalidateOrientationDependentStateLocked()
	}
	return nil
}

func (e *Engine) SetComparisonGenomeOrientation(genomeID uint16, reversed bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	genome := e.comparisonGenomes[genomeID]
	if genome == nil {
		return fmt.Errorf("comparison genome %d not found", genomeID)
	}
	changed := false
	for i := range genome.Segments {
		if genome.Segments[i].Reversed == reversed {
			continue
		}
		genome.Segments[i].Reversed = reversed
		changed = true
	}
	if changed {
		genome.rebuildDerived()
	}
	return nil
}

func (e *Engine) SetComparisonSegmentOrientation(genomeID uint16, segmentStart uint32, reversed bool) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	genome := e.comparisonGenomes[genomeID]
	if genome == nil {
		return fmt.Errorf("comparison genome %d not found", genomeID)
	}
	for i := range genome.Segments {
		if uint32(genome.Segments[i].Start) != segmentStart {
			continue
		}
		if genome.Segments[i].Reversed == reversed {
			return nil
		}
		genome.Segments[i].Reversed = reversed
		genome.rebuildDerived()
		return nil
	}
	return fmt.Errorf("comparison segment starting at %d not found", segmentStart)
}

func moveIndex(items int, from int, moveAction byte) (int, bool, error) {
	if items <= 0 || from < 0 || from >= items {
		return from, false, fmt.Errorf("index %d out of range", from)
	}
	to := from
	switch moveAction {
	case moveActionLeft:
		to = max(0, from-1)
	case moveActionRight:
		to = min(items-1, from+1)
	case moveActionStart:
		to = 0
	case moveActionEnd:
		to = items - 1
	default:
		return from, false, fmt.Errorf("unknown move action %d", moveAction)
	}
	return to, to != from, nil
}

func (e *Engine) MoveChromosome(chrID uint16, moveAction byte) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return fmt.Errorf("unknown chromosome id %d", chrID)
	}
	from := -1
	for i, name := range e.chromOrder {
		if name == chr {
			from = i
			break
		}
	}
	to, changed, err := moveIndex(len(e.chromOrder), from, moveAction)
	if err != nil || !changed {
		return err
	}
	item := e.chromOrder[from]
	copy(e.chromOrder[from:], e.chromOrder[from+1:])
	e.chromOrder = e.chromOrder[:len(e.chromOrder)-1]
	if to >= len(e.chromOrder) {
		e.chromOrder = append(e.chromOrder, item)
	} else {
		e.chromOrder = append(e.chromOrder, "")
		copy(e.chromOrder[to+1:], e.chromOrder[to:])
		e.chromOrder[to] = item
	}
	return nil
}

func (e *Engine) MoveComparisonSegment(genomeID uint16, segmentStart uint32, moveAction byte) error {
	e.mu.Lock()
	defer e.mu.Unlock()

	genome := e.comparisonGenomes[genomeID]
	if genome == nil {
		return fmt.Errorf("comparison genome %d not found", genomeID)
	}
	from := -1
	for i := range genome.Segments {
		if uint32(genome.Segments[i].Start) == segmentStart {
			from = i
			break
		}
	}
	to, changed, err := moveIndex(len(genome.Segments), from, moveAction)
	if err != nil || !changed {
		return err
	}
	item := genome.Segments[from]
	genome.Segments = append(genome.Segments[:from], genome.Segments[from+1:]...)
	if to >= len(genome.Segments) {
		genome.Segments = append(genome.Segments, item)
	} else {
		genome.Segments = append(genome.Segments[:to], append([]comparisonSegment{item}, genome.Segments[to:]...)...)
	}
	genome.rebuildDerived()
	e.rebuildComparisonPairsLocked()
	return nil
}
