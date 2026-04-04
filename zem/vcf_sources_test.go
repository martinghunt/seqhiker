package main

import (
	"encoding/binary"
	"math"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"
)

func TestInspectInputVCFReportsVariants(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "calls.vcf")
	content := "##fileformat=VCFv4.2\n" +
		"#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\ts1\ts2\n" +
		"chr1\t3\t.\tA\tG\t42\tPASS\t.\tGT\t0/1\t1/1\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isSession, hasVariants, err := e.InspectInput(path)
	if err != nil {
		t.Fatalf("InspectInput returned error: %v", err)
	}
	if hasSequence || hasAnnotation || hasEmbeddedGFF3Sequence || isSession {
		t.Fatalf("unexpected inspect flags: seq=%v ann=%v emb=%v session=%v", hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isSession)
	}
	if !hasVariants {
		t.Fatal("expected VCF to report variants")
	}
}

func TestLoadVariantFileVCFTracksSamplesAndTiles(t *testing.T) {
	dir := t.TempDir()
	genomePath := filepath.Join(dir, "ref.fa")
	if err := os.WriteFile(genomePath, []byte(">chr1\n"+strings.Repeat("A", 40000)+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	vcfPath := filepath.Join(dir, "sample.vcf")
	content := "##fileformat=VCFv4.2\n" +
		"##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n" +
		"#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tsample_a\tsample_b\tsample_c\n" +
		"chr1\t5\tdemo1\tA\tG\t60\tPASS\tTYPE=SNP\tGT\t0/1\t1/1\t0/0\n" +
		"chr1\t10\tdemo2\tC\tT\t50\tPASS\tTYPE=SNP\tGT\t0/0\t0/1\t1/1\n"
	if err := os.WriteFile(vcfPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(genomePath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	source, err := e.LoadVariantFile(vcfPath)
	if err != nil {
		t.Fatalf("LoadVariantFile returned error: %v", err)
	}
	if !slices.Equal(source.SampleNames, []string{"sample_a", "sample_b", "sample_c"}) {
		t.Fatalf("unexpected sample names: %v", source.SampleNames)
	}
	chroms := e.ListChromosomes()
	chr1ID := chroms[0].ID
	tileIndex := uint32(0) // Covers chr1:0-32768 at zoom 5.
	payload, err := e.GetVariantTile(source.ID, chr1ID, 5, tileIndex)
	if err != nil {
		t.Fatalf("GetVariantTile returned error: %v", err)
	}
	start, end, records := decodeVariantTileForTest(t, payload)
	if start != 0 || end != 32768 {
		t.Fatalf("unexpected tile bounds: %d-%d", start, end)
	}
	if len(records) == 0 {
		t.Fatal("expected at least one VCF variant in tile")
	}
	if records[0].SampleCount != 3 {
		t.Fatalf("unexpected sample count: %d", records[0].SampleCount)
	}
	if records[0].Ref == "" || records[0].AltSummary == "" {
		t.Fatalf("expected record alleles, got %+v", records[0])
	}
	if len(records[0].SampleClasses) != 3 || len(records[0].SampleTexts) != 3 {
		t.Fatalf("expected genotype summaries for 3 samples, got classes=%v texts=%v", records[0].SampleClasses, records[0].SampleTexts)
	}
	if records[0].SampleClasses[0] != variantGTHet || records[0].SampleClasses[1] != variantGTHomAlt || records[0].SampleClasses[2] != variantGTRef {
		t.Fatalf("unexpected genotype classes: %v", records[0].SampleClasses)
	}
}

func TestGetVariantDetailVCF(t *testing.T) {
	dir := t.TempDir()
	genomePath := filepath.Join(dir, "ref.fa")
	if err := os.WriteFile(genomePath, []byte(">chr1\n"+strings.Repeat("A", 40000)+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	vcfPath := filepath.Join(dir, "sample.vcf")
	content := "##fileformat=VCFv4.2\n" +
		"##FORMAT=<ID=GT,Number=1,Type=String,Description=\"Genotype\">\n" +
		"##FORMAT=<ID=DP,Number=1,Type=Integer,Description=\"Read Depth\">\n" +
		"#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\tsample_a\tsample_b\n" +
		"chr1\t5\tdemo1\tA\tG\t60\tPASS\tTYPE=SNP\tGT:DP\t0/1:12\t1/1:18\n"
	if err := os.WriteFile(vcfPath, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(genomePath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	source, err := e.LoadVariantFile(vcfPath)
	if err != nil {
		t.Fatalf("LoadVariantFile returned error: %v", err)
	}
	chroms := e.ListChromosomes()
	if len(chroms) != 1 {
		t.Fatalf("unexpected chromosome count: %d", len(chroms))
	}
	payload, err := e.GetVariantDetail(source.ID, chroms[0].ID, 4, "A", "G")
	if err != nil {
		t.Fatalf("GetVariantDetail returned error: %v", err)
	}
	detail := decodeVariantDetailForTest(t, payload)
	if detail["chrom"] != "chr1" {
		t.Fatalf("unexpected chrom: %v", detail["chrom"])
	}
	if detail["ref"] != "A" || detail["alt_summary"] != "G" {
		t.Fatalf("unexpected alleles: ref=%v alt=%v", detail["ref"], detail["alt_summary"])
	}
	samples, _ := detail["samples"].([]map[string]any)
	if len(samples) != 2 {
		t.Fatalf("unexpected sample count: %d", len(samples))
	}
}

type decodedVariantRecord struct {
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

func decodeVariantTileForTest(t *testing.T, payload []byte) (int, int, []decodedVariantRecord) {
	t.Helper()
	if len(payload) < 13 {
		t.Fatalf("variant tile payload too short: %d", len(payload))
	}
	start := int(binary.LittleEndian.Uint32(payload[1:5]))
	end := int(binary.LittleEndian.Uint32(payload[5:9]))
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	off := 13
	records := make([]decodedVariantRecord, 0, count)
	for i := 0; i < count; i++ {
		if off+27 > len(payload) {
			t.Fatalf("record header truncated at %d", off)
		}
		record := decodedVariantRecord{
			Start:       binary.LittleEndian.Uint32(payload[off : off+4]),
			End:         binary.LittleEndian.Uint32(payload[off+4 : off+8]),
			Kind:        payload[off+8],
			SampleCount: binary.LittleEndian.Uint16(payload[off+9 : off+11]),
			Qual:        math.Float32frombits(binary.LittleEndian.Uint32(payload[off+11 : off+15])),
		}
		classLen := int(binary.LittleEndian.Uint16(payload[off+15 : off+17]))
		textBlobLen := int(binary.LittleEndian.Uint16(payload[off+17 : off+19]))
		idLen := int(binary.LittleEndian.Uint16(payload[off+19 : off+21]))
		refLen := int(binary.LittleEndian.Uint16(payload[off+21 : off+23]))
		altLen := int(binary.LittleEndian.Uint16(payload[off+23 : off+25]))
		filterLen := int(binary.LittleEndian.Uint16(payload[off+25 : off+27]))
		off += 27
		if off+classLen+textBlobLen+idLen+refLen+altLen+filterLen > len(payload) {
			t.Fatalf("record payload truncated at %d", off)
		}
		record.SampleClasses = append([]byte(nil), payload[off:off+classLen]...)
		off += classLen
		textEnd := off + textBlobLen
		record.SampleTexts = make([]string, 0, record.SampleCount)
		for i := 0; i < int(record.SampleCount); i++ {
			if off+2 > textEnd {
				t.Fatalf("record sample text header truncated at %d", off)
			}
			textLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
			off += 2
			if off+textLen > textEnd {
				t.Fatalf("record sample text truncated at %d", off)
			}
			record.SampleTexts = append(record.SampleTexts, string(payload[off:off+textLen]))
			off += textLen
		}
		off = textEnd
		record.ID = string(payload[off : off+idLen])
		off += idLen
		record.Ref = string(payload[off : off+refLen])
		off += refLen
		record.AltSummary = string(payload[off : off+altLen])
		off += altLen
		record.Filter = string(payload[off : off+filterLen])
		off += filterLen
		records = append(records, record)
	}
	return start, end, records
}

func decodeVariantDetailForTest(t *testing.T, payload []byte) map[string]any {
	t.Helper()
	if len(payload) < 29 {
		t.Fatalf("variant detail payload too short: %d", len(payload))
	}
	sourceID := int(binary.LittleEndian.Uint16(payload[0:2]))
	start := int(binary.LittleEndian.Uint32(payload[2:6]))
	end := int(binary.LittleEndian.Uint32(payload[6:10]))
	kind := int(payload[10])
	qual := math.Float32frombits(binary.LittleEndian.Uint32(payload[11:15]))
	formatCount := int(binary.LittleEndian.Uint16(payload[15:17]))
	sampleCount := int(binary.LittleEndian.Uint16(payload[17:19]))
	sourceNameLen := int(binary.LittleEndian.Uint16(payload[19:21]))
	sourcePathLen := int(binary.LittleEndian.Uint16(payload[21:23]))
	chromLen := int(binary.LittleEndian.Uint16(payload[23:25]))
	idLen := int(binary.LittleEndian.Uint16(payload[25:27]))
	refLen := int(binary.LittleEndian.Uint16(payload[27:29]))
	off := 29
	var variableTexts []string
	for i := 0; i < 3; i++ {
		if off+2 > len(payload) {
			t.Fatalf("variant detail payload truncated reading text len at %d", off)
		}
		textLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+textLen > len(payload) {
			t.Fatalf("variant detail payload truncated reading text at %d", off)
		}
		variableTexts = append(variableTexts, string(payload[off:off+textLen]))
		off += textLen
	}
	if off+sourceNameLen+sourcePathLen+chromLen+idLen+refLen > len(payload) {
		t.Fatalf("variant detail payload truncated reading fixed strings at %d", off)
	}
	sourceName := string(payload[off : off+sourceNameLen])
	off += sourceNameLen
	sourcePath := string(payload[off : off+sourcePathLen])
	off += sourcePathLen
	chrom := string(payload[off : off+chromLen])
	off += chromLen
	recID := string(payload[off : off+idLen])
	off += idLen
	ref := string(payload[off : off+refLen])
	off += refLen
	formatKeys := make([]string, 0, formatCount)
	for i := 0; i < formatCount; i++ {
		if off+2 > len(payload) {
			t.Fatalf("variant detail payload truncated reading format len at %d", off)
		}
		keyLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+keyLen > len(payload) {
			t.Fatalf("variant detail payload truncated reading format key at %d", off)
		}
		formatKeys = append(formatKeys, string(payload[off:off+keyLen]))
		off += keyLen
	}
	samples := make([]map[string]any, 0, sampleCount)
	for i := 0; i < sampleCount; i++ {
		if off+5 > len(payload) {
			t.Fatalf("variant detail payload truncated reading sample header at %d", off)
		}
		hasAlt := payload[off] != 0
		off++
		nameLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		valueLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+nameLen+valueLen > len(payload) {
			t.Fatalf("variant detail payload truncated reading sample at %d", off)
		}
		name := string(payload[off : off+nameLen])
		off += nameLen
		value := string(payload[off : off+valueLen])
		off += valueLen
		samples = append(samples, map[string]any{
			"name":    name,
			"value":   value,
			"has_alt": hasAlt,
		})
	}
	return map[string]any{
		"source_id":   sourceID,
		"start":       start,
		"end":         end,
		"kind":        kind,
		"qual":        qual,
		"source_name": sourceName,
		"source_path": sourcePath,
		"chrom":       chrom,
		"id":          recID,
		"ref":         ref,
		"alt_summary": variableTexts[0],
		"filter":      variableTexts[1],
		"info":        variableTexts[2],
		"format_keys": formatKeys,
		"samples":     samples,
	}
}
