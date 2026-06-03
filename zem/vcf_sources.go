package main

import (
	"bufio"
	"encoding/binary"
	"fmt"
	"io"
	"math"
	"path/filepath"
	"sort"
	"strings"

	"github.com/brentp/vcfgo"
	"github.com/shenwei356/xopen"
)

const (
	variantKindUnknown byte = iota
	variantKindSNP
	variantKindMNP
	variantKindInsertion
	variantKindDeletion
	variantKindComplex
	variantKindSymbolic
)

const (
	variantGTMissing byte = iota
	variantGTRef
	variantGTHet
	variantGTHomAlt
)

type variantSource struct {
	ID            uint16
	Path          string
	Name          string
	Generation    uint64
	SampleNames   []string
	VariantsByChr map[uint16][]variantRecord
}

type variantRecord struct {
	Start         uint32
	End           uint32
	Kind          byte
	SampleCount   uint16
	SampleClasses []byte
	SampleTexts   []string
	Qual          float32
	ID            string
	Ref           string
	AltSummary    string
	Filter        string
}

type variantDetail struct {
	SourceID     uint16
	SourceName   string
	SourcePath   string
	Chrom        string
	Start        uint32
	End          uint32
	Kind         byte
	ID           string
	Ref          string
	AltSummary   string
	Qual         float32
	Filter       string
	Info         string
	FormatKeys   []string
	SampleNames  []string
	SampleValues []string
	SampleHasAlt []byte
}

func (e *Engine) LoadVariantFile(path string) (*variantSource, error) {
	kind, err := detectInputKind(path)
	if err != nil {
		return nil, err
	}
	if kind != inputKindVCF {
		return nil, fmt.Errorf("unsupported variant file: %s", path)
	}

	e.mu.Lock()
	if len(e.sequences) == 0 {
		e.mu.Unlock()
		return nil, fmt.Errorf("no reference sequence loaded; load FASTA/EMBL/GenBank first")
	}
	e.mu.Unlock()

	source, err := e.loadVCFSource(path)
	if err != nil {
		return nil, err
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	source.ID = e.nextVariantID
	e.nextVariantID++
	if e.nextVariantID == 0 {
		e.nextVariantID = 1
	}
	source.Generation = e.globalGeneration + 1
	e.variantSources[source.ID] = source
	e.variantOrder = append(e.variantOrder, source.ID)
	e.globalGeneration++
	e.resetTileCacheLocked()
	return source, nil
}

func (e *Engine) ListVariantSources() []VariantSourceInfo {
	e.mu.RLock()
	defer e.mu.RUnlock()

	out := make([]VariantSourceInfo, 0, len(e.variantOrder))
	for _, id := range e.variantOrder {
		src := e.variantSources[id]
		if src == nil {
			continue
		}
		out = append(out, VariantSourceInfo{
			ID:          src.ID,
			Name:        src.Name,
			Path:        src.Path,
			SampleNames: append([]string(nil), src.SampleNames...),
		})
	}
	return out
}

func (e *Engine) GetVariantTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	e.mu.Lock()
	src, err := e.resolveVariantSourceLocked(sourceID)
	if err != nil {
		e.mu.Unlock()
		return nil, err
	}
	chrName, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	window := tileWindow(zoom, tileIndex)
	key := tileCacheKey{
		Generation: src.Generation,
		SourceID:   src.ID,
		Kind:       variantTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}
	records := src.VariantsByChr[chrID]
	generation := src.Generation
	selectedSourceID := src.ID
	chromLen := e.rawChrLength[chrName]
	if chromLen <= 0 {
		chromLen = e.chrLength[chrName]
	}
	reversed := e.chrReverse[chrName]
	e.mu.Unlock()

	orientedStart, orientedEnd := clampWindowToLength(window.start, window.end, chromLen)
	rawStart, rawEnd := rawWindowForOrientation(window.start, window.end, chromLen, reversed)
	filtered := variantRecordsInWindow(records, rawStart, rawEnd)
	if reversed {
		transformed := make([]variantRecord, 0, len(filtered))
		for i := len(filtered) - 1; i >= 0; i-- {
			transformed = append(transformed, transformVariantRecordForLength(filtered[i], chromLen))
		}
		filtered = transformed
	}
	payload := encodeVariantTile(orientedStart, orientedEnd, filtered)

	e.mu.Lock()
	if src2, ok := e.variantSources[selectedSourceID]; ok && src2.Generation == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()
	return payload, nil
}

func (e *Engine) GetVariantDetail(sourceID uint16, chrID uint16, start uint32, ref, altSummary string) ([]byte, error) {
	e.mu.RLock()
	src, err := e.resolveVariantSourceLockedRead(sourceID)
	if err != nil {
		e.mu.RUnlock()
		return nil, err
	}
	chrName := e.idToChr[chrID]
	chromLen := e.rawChrLength[chrName]
	if chromLen <= 0 {
		chromLen = e.chrLength[chrName]
	}
	reversed := e.chrReverse[chrName]
	e.mu.RUnlock()
	if chrName == "" {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	rawStart := start
	rawRef := ref
	rawAltSummary := altSummary
	if reversed {
		rawRef = reverseComplementFlexible(ref)
		rawAltSummary = reverseComplementAltSummary(altSummary)
		rawEnd := int(start) + len(ref)
		rawStart = uint32(chromLen - rawEnd)
	}
	detail, err := loadVariantDetailFromPath(src.Path, chrName, rawStart, rawRef, rawAltSummary)
	if err != nil {
		return nil, err
	}
	detail.SourceID = src.ID
	detail.SourceName = src.Name
	detail.SourcePath = src.Path
	if reversed {
		detail = transformVariantDetailForLength(detail, chromLen)
	}
	return encodeVariantDetail(detail), nil
}

func (e *Engine) resolveVariantSourceLocked(sourceID uint16) (*variantSource, error) {
	if len(e.variantOrder) == 0 {
		return nil, fmt.Errorf("variant file not loaded")
	}
	if sourceID == 0 {
		sourceID = e.variantOrder[0]
	}
	src := e.variantSources[sourceID]
	if src == nil {
		return nil, fmt.Errorf("variant source %d not loaded", sourceID)
	}
	return src, nil
}

func (e *Engine) resolveVariantSourceLockedRead(sourceID uint16) (*variantSource, error) {
	if len(e.variantOrder) == 0 {
		return nil, fmt.Errorf("variant file not loaded")
	}
	if sourceID == 0 {
		sourceID = e.variantOrder[0]
	}
	src := e.variantSources[sourceID]
	if src == nil {
		return nil, fmt.Errorf("variant source %d not loaded", sourceID)
	}
	return src, nil
}

func (e *Engine) loadVCFSource(path string) (*variantSource, error) {
	reader, closer, err := openVariantReader(path)
	if err != nil {
		return nil, err
	}
	defer closer.Close()
	source := &variantSource{
		Path:          path,
		Name:          filepath.Base(path),
		SampleNames:   append([]string(nil), reader.Header.SampleNames...),
		VariantsByChr: map[uint16][]variantRecord{},
	}
	if len(source.SampleNames) > 0xFFFF {
		source.SampleNames = source.SampleNames[:0xFFFF]
	}
	sampleCount := uint16(len(source.SampleNames))
	for {
		variant := reader.Read()
		if variant == nil {
			break
		}
		if err := parseVariantSamplesTolerant(variant); err != nil {
			return nil, err
		}
		chrID, ok := e.resolveExistingChromIDForVariants(variant.Chrom())
		if !ok {
			return nil, fmt.Errorf("VCF references do not match loaded genome: %s", variant.Chrom())
		}
		sampleClasses, sampleTexts := variantSampleSummaries(variant.Samples, variant.Ref(), variant.Alt())
		record := variantRecord{
			Start:         variant.Start(),
			End:           variant.End(),
			Kind:          classifyVariant(variant.Ref(), variant.Alt()),
			SampleCount:   sampleCount,
			SampleClasses: sampleClasses,
			SampleTexts:   sampleTexts,
			Qual:          variant.Quality,
			ID:            variant.Id(),
			Ref:           variant.Ref(),
			AltSummary:    strings.Join(variant.Alt(), ","),
			Filter:        variant.Filter,
		}
		source.VariantsByChr[chrID] = append(source.VariantsByChr[chrID], record)
	}
	if err := reader.Error(); err != nil {
		return nil, err
	}
	sortVariantRecords(source.VariantsByChr)
	return source, nil
}

func (e *Engine) resolveExistingChromIDForVariants(name string) (uint16, bool) {
	e.mu.RLock()
	defer e.mu.RUnlock()
	_, matchedID, matchCount := e.resolveExistingChromMatchLocked(name, 0, false)
	return matchedID, matchCount == 1
}

func sortVariantRecords(byChr map[uint16][]variantRecord) {
	for chrID, records := range byChr {
		sort.Slice(records, func(i, j int) bool {
			if records[i].Start == records[j].Start {
				return records[i].End < records[j].End
			}
			return records[i].Start < records[j].Start
		})
		byChr[chrID] = records
	}
}

func variantRecordsInWindow(records []variantRecord, start, end int) []variantRecord {
	if len(records) == 0 {
		return nil
	}
	first := sort.Search(len(records), func(i int) bool {
		return int(records[i].End) > start
	})
	if first >= len(records) {
		return nil
	}
	last := sort.Search(len(records), func(i int) bool {
		return int(records[i].Start) >= end
	})
	if last <= first {
		return nil
	}
	return records[first:last]
}

func classifyVariant(ref string, alts []string) byte {
	if ref == "" || len(alts) == 0 {
		return variantKindUnknown
	}
	if isSymbolicAlt(alts) {
		return variantKindSymbolic
	}
	if len(alts) == 1 {
		alt := alts[0]
		switch {
		case len(ref) == 1 && len(alt) == 1:
			return variantKindSNP
		case len(ref) == len(alt):
			return variantKindMNP
		case len(ref) < len(alt) && strings.HasPrefix(alt, ref):
			return variantKindInsertion
		case len(ref) > len(alt) && strings.HasPrefix(ref, alt):
			return variantKindDeletion
		default:
			return variantKindComplex
		}
	}
	return variantKindComplex
}

func isSymbolicAlt(alts []string) bool {
	for _, alt := range alts {
		if strings.HasPrefix(alt, "<") || strings.Contains(alt, "[") || strings.Contains(alt, "]") {
			return true
		}
	}
	return false
}

func extractVCFSampleNamesFromHeader(headerText []byte) []string {
	scanner := bufio.NewScanner(strings.NewReader(string(headerText)))
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "#CHROM\t") {
			continue
		}
		fields := strings.Split(line, "\t")
		if len(fields) <= 9 {
			return nil
		}
		return append([]string(nil), fields[9:]...)
	}
	return nil
}

func encodeVariantTile(start, end int, records []variantRecord) []byte {
	payloadLen := 13
	for _, record := range records {
		sampleClasses, _, _, textBlobLen := wireVariantRecordSamples16(record)
		id := wireString16(record.ID)
		ref := wireString16(record.Ref)
		altSummary := wireString16(record.AltSummary)
		filter := wireString16(record.Filter)
		payloadLen += 27 + len(sampleClasses) + textBlobLen + len(id) + len(ref) + len(altSummary) + len(filter)
	}
	buf := make([]byte, payloadLen)
	buf[0] = 1
	binary.LittleEndian.PutUint32(buf[1:5], uint32(start))
	binary.LittleEndian.PutUint32(buf[5:9], uint32(end))
	binary.LittleEndian.PutUint32(buf[9:13], uint32(len(records)))
	off := 13
	for _, record := range records {
		sampleClasses, sampleTexts, sampleCount, textBlobLen := wireVariantRecordSamples16(record)
		id := wireString16(record.ID)
		ref := wireString16(record.Ref)
		altSummary := wireString16(record.AltSummary)
		filter := wireString16(record.Filter)
		binary.LittleEndian.PutUint32(buf[off:off+4], record.Start)
		binary.LittleEndian.PutUint32(buf[off+4:off+8], record.End)
		buf[off+8] = record.Kind
		binary.LittleEndian.PutUint16(buf[off+9:off+11], sampleCount)
		binary.LittleEndian.PutUint32(buf[off+11:off+15], math.Float32bits(record.Qual))
		binary.LittleEndian.PutUint16(buf[off+15:off+17], uint16(len(sampleClasses)))
		binary.LittleEndian.PutUint16(buf[off+17:off+19], uint16(textBlobLen))
		binary.LittleEndian.PutUint16(buf[off+19:off+21], uint16(len(id)))
		binary.LittleEndian.PutUint16(buf[off+21:off+23], uint16(len(ref)))
		binary.LittleEndian.PutUint16(buf[off+23:off+25], uint16(len(altSummary)))
		binary.LittleEndian.PutUint16(buf[off+25:off+27], uint16(len(filter)))
		copy(buf[off+27:off+27+len(sampleClasses)], sampleClasses)
		off += 27 + len(sampleClasses)
		for _, text := range sampleTexts {
			binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(text)))
			off += 2
			copy(buf[off:off+len(text)], text)
			off += len(text)
		}
		copy(buf[off:off+len(id)], id)
		off += len(id)
		copy(buf[off:off+len(ref)], ref)
		off += len(ref)
		copy(buf[off:off+len(altSummary)], altSummary)
		off += len(altSummary)
		copy(buf[off:off+len(filter)], filter)
		off += len(filter)
	}
	return buf
}

func wireVariantRecordSamples16(record variantRecord) ([]byte, []string, uint16, int) {
	count := min(int(record.SampleCount), len(record.SampleClasses), len(record.SampleTexts), 0xFFFF)
	classes := wireBytes16(record.SampleClasses)
	if len(classes) < count {
		count = len(classes)
	}
	texts := make([]string, 0, count)
	textBlobLen := 0
	for i := 0; i < count; i++ {
		if textBlobLen+2 > 0xFFFF {
			break
		}
		remaining := 0xFFFF - textBlobLen - 2
		text := record.SampleTexts[i]
		if len(text) > remaining {
			text = text[:remaining]
		}
		texts = append(texts, text)
		textBlobLen += 2 + len(text)
	}
	classes = classes[:len(texts)]
	return classes, texts, uint16(len(texts)), textBlobLen
}

func encodeVariantDetail(detail variantDetail) []byte {
	sourceName := wireString16(detail.SourceName)
	sourcePath := wireString16(detail.SourcePath)
	chrom := wireString16(detail.Chrom)
	id := wireString16(detail.ID)
	ref := wireString16(detail.Ref)
	altSummary := wireString16(detail.AltSummary)
	filter := wireString16(detail.Filter)
	info := wireString16(detail.Info)
	formatKeys := wireStringList16(detail.FormatKeys)
	sampleCount := min(len(detail.SampleNames), len(detail.SampleValues), len(detail.SampleHasAlt), 0xFFFF)
	sampleNames := make([]string, sampleCount)
	sampleValues := make([]string, sampleCount)
	for i := 0; i < sampleCount; i++ {
		sampleNames[i] = wireString16(detail.SampleNames[i])
		sampleValues[i] = wireString16(detail.SampleValues[i])
	}
	payloadLen := 35 +
		len(sourceName) +
		len(sourcePath) +
		len(chrom) +
		len(id) +
		len(ref) +
		len(altSummary) +
		len(filter) +
		len(info)
	for _, key := range formatKeys {
		payloadLen += 2 + len(key)
	}
	for i := range sampleNames {
		payloadLen += 5 + len(sampleNames[i]) + len(sampleValues[i])
	}
	buf := make([]byte, payloadLen)
	binary.LittleEndian.PutUint16(buf[0:2], detail.SourceID)
	binary.LittleEndian.PutUint32(buf[2:6], detail.Start)
	binary.LittleEndian.PutUint32(buf[6:10], detail.End)
	buf[10] = detail.Kind
	binary.LittleEndian.PutUint32(buf[11:15], math.Float32bits(detail.Qual))
	binary.LittleEndian.PutUint16(buf[15:17], uint16(len(formatKeys)))
	binary.LittleEndian.PutUint16(buf[17:19], uint16(len(sampleNames)))
	binary.LittleEndian.PutUint16(buf[19:21], uint16(len(sourceName)))
	binary.LittleEndian.PutUint16(buf[21:23], uint16(len(sourcePath)))
	binary.LittleEndian.PutUint16(buf[23:25], uint16(len(chrom)))
	binary.LittleEndian.PutUint16(buf[25:27], uint16(len(id)))
	binary.LittleEndian.PutUint16(buf[27:29], uint16(len(ref)))
	off := 29
	for _, value := range []string{altSummary, filter, info} {
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(value)))
		off += 2
		copy(buf[off:off+len(value)], value)
		off += len(value)
	}
	for _, value := range []string{sourceName, sourcePath, chrom, id, ref} {
		copy(buf[off:off+len(value)], value)
		off += len(value)
	}
	for _, key := range formatKeys {
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(key)))
		off += 2
		copy(buf[off:off+len(key)], key)
		off += len(key)
	}
	for i := range sampleNames {
		sampleName := sampleNames[i]
		sampleValue := sampleValues[i]
		buf[off] = detail.SampleHasAlt[i]
		off++
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(sampleName)))
		off += 2
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(sampleValue)))
		off += 2
		copy(buf[off:off+len(sampleName)], sampleName)
		off += len(sampleName)
		copy(buf[off:off+len(sampleValue)], sampleValue)
		off += len(sampleValue)
	}
	return buf
}

func openVariantReader(path string) (*vcfgo.Reader, io.Closer, error) {
	kind, err := detectInputKind(path)
	if err != nil {
		return nil, nil, err
	}
	if kind == inputKindVCF {
		f, err := xopen.Ropen(path)
		if err != nil {
			return nil, nil, err
		}
		reader, err := vcfgo.NewReader(f, true)
		if err != nil {
			f.Close()
			return nil, nil, err
		}
		return reader, f, nil
	}
	return nil, nil, fmt.Errorf("variant detail only supports VCF right now")
}

func parseVariantSamplesTolerant(variant *vcfgo.Variant) error {
	if variant == nil || variant.Header == nil {
		return nil
	}
	err := variant.Header.ParseSamples(variant)
	if err == nil || isIgnorableVCFSampleParseError(err) {
		return nil
	}
	return err
}

func isIgnorableVCFSampleParseError(err error) bool {
	if err == nil {
		return false
	}
	msg := err.Error()
	return strings.Contains(msg, "setSampleGQ: GQ reported as float") ||
		strings.Contains(msg, "rounding to int")
}

func sampleHasAlt(sample *vcfgo.SampleGenotype) bool {
	gt := sampleGTAlleles(sample)
	for _, allele := range gt {
		if allele > 0 {
			return true
		}
	}
	return false
}

func variantSampleSummaries(samples []*vcfgo.SampleGenotype, ref string, alts []string) ([]byte, []string) {
	if len(samples) == 0 {
		return nil, nil
	}
	classes := make([]byte, len(samples))
	texts := make([]string, len(samples))
	for i, sample := range samples {
		class, text := sampleGenotypeSummary(sample, ref, alts)
		classes[i] = class
		texts[i] = text
	}
	return classes, texts
}

func sampleGenotypeSummary(sample *vcfgo.SampleGenotype, ref string, alts []string) (byte, string) {
	gt := sampleGTAlleles(sample)
	if len(gt) == 0 {
		return variantGTMissing, ""
	}
	alleleTexts := make([]string, 0, len(gt))
	for _, allele := range gt {
		text, ok := variantAlleleText(allele, ref, alts)
		if !ok {
			return variantGTMissing, ""
		}
		alleleTexts = append(alleleTexts, text)
	}
	allSame := true
	for i := 1; i < len(gt); i++ {
		if gt[i] != gt[0] {
			allSame = false
			break
		}
	}
	if allSame {
		if gt[0] == 0 {
			return variantGTRef, alleleTexts[0]
		}
		return variantGTHomAlt, alleleTexts[0]
	}
	return variantGTHet, strings.Join(alleleTexts, "/")
}

func variantAlleleText(allele int, ref string, alts []string) (string, bool) {
	switch {
	case allele < 0:
		return "", false
	case allele == 0:
		return ref, true
	case allele <= len(alts):
		return alts[allele-1], true
	default:
		return "", false
	}
}

func sampleGTAlleles(sample *vcfgo.SampleGenotype) []int {
	if sample == nil {
		return nil
	}
	if len(sample.GT) > 0 {
		out := make([]int, 0, len(sample.GT))
		for _, gt := range sample.GT {
			if gt < 0 {
				return nil
			}
			out = append(out, gt)
		}
		return out
	}
	var gtText string
	if sample.Fields != nil {
		gtText = strings.TrimSpace(sample.Fields["GT"])
	}
	if gtText == "" {
		return nil
	}
	gtText = strings.ReplaceAll(strings.TrimSpace(gtText), "|", "/")
	out := make([]int, 0, 2)
	for _, part := range strings.Split(gtText, "/") {
		part = strings.TrimSpace(part)
		if part == "." || part == "" {
			return nil
		}
		value := 0
		for _, ch := range part {
			if ch < '0' || ch > '9' {
				return nil
			}
			value = value*10 + int(ch-'0')
		}
		out = append(out, value)
	}
	return out
}

func loadVariantDetailFromPath(path, chrom string, start uint32, ref, altSummary string) (variantDetail, error) {
	reader, closer, err := openVariantReader(path)
	if err != nil {
		return variantDetail{}, err
	}
	defer closer.Close()
	for {
		variant := reader.Read()
		if variant == nil {
			break
		}
		if variant.Chrom() != chrom || variant.Start() != start || variant.Ref() != ref || strings.Join(variant.Alt(), ",") != altSummary {
			continue
		}
		if err := parseVariantSamplesTolerant(variant); err != nil {
			return variantDetail{}, err
		}
		sampleNames := append([]string(nil), reader.Header.SampleNames...)
		sampleValues := make([]string, len(sampleNames))
		sampleHasAltFlags := make([]byte, len(sampleNames))
		for i, sample := range variant.Samples {
			if sample == nil {
				sampleValues[i] = "."
			} else {
				sampleValues[i] = formatSampleFields(variant.Format, sample.Fields)
				if sampleHasAlt(sample) {
					sampleHasAltFlags[i] = 1
				}
			}
		}
		return variantDetail{
			Chrom:        chrom,
			Start:        variant.Start(),
			End:          variant.End(),
			Kind:         classifyVariant(variant.Ref(), variant.Alt()),
			ID:           variant.Id(),
			Ref:          variant.Ref(),
			AltSummary:   strings.Join(variant.Alt(), ","),
			Qual:         variant.Quality,
			Filter:       variant.Filter,
			Info:         formatVariantInfoString(variant),
			FormatKeys:   append([]string(nil), variant.Format...),
			SampleNames:  sampleNames,
			SampleValues: sampleValues,
			SampleHasAlt: sampleHasAltFlags,
		}, nil
	}
	if err := reader.Error(); err != nil {
		return variantDetail{}, err
	}
	return variantDetail{}, fmt.Errorf("variant detail not found")
}

func formatVariantInfoString(variant *vcfgo.Variant) string {
	if variant == nil || variant.Info_ == nil {
		return "."
	}
	return fmt.Sprintf("%v", variant.Info())
}

func formatSampleFields(formatKeys []string, fields map[string]string) string {
	if len(formatKeys) == 0 || len(fields) == 0 {
		return "."
	}
	parts := make([]string, 0, len(formatKeys))
	for _, key := range formatKeys {
		parts = append(parts, fmt.Sprintf("%s=%s", key, fields[key]))
	}
	return strings.Join(parts, "  ")
}
