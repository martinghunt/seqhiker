package zem

import (
	"encoding/binary"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"testing"

	"github.com/biogo/hts/sam"
)

func TestParseGFF3EmbeddedFASTA(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "embedded.gff")
	content := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTACGT\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	seqs, feats, err := parseGFF3(path)
	if err != nil {
		t.Fatalf("parseGFF3 returned error: %v", err)
	}
	if got := seqs["chr1"]; got != "ACGTACGT" {
		t.Fatalf("embedded sequence mismatch: got %q", got)
	}
	chrFeats := feats["chr1"]
	if len(chrFeats) != 1 {
		t.Fatalf("expected 1 feature, got %d", len(chrFeats))
	}
	if chrFeats[0].Start != 1 || chrFeats[0].End != 5 {
		t.Fatalf("unexpected feature coordinates: %+v", chrFeats[0])
	}
}

func TestInspectInputEmbeddedGFF3ReportsSequenceAndAnnotation(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "embedded.gff3")
	content := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTACGT\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isSession, hasVariants, err := e.InspectInput(path)
	if err != nil {
		t.Fatalf("InspectInput returned error: %v", err)
	}
	if !hasSequence {
		t.Fatal("expected embedded GFF3 to report sequence")
	}
	if !hasAnnotation {
		t.Fatal("expected embedded GFF3 to report annotation")
	}
	if !hasEmbeddedGFF3Sequence {
		t.Fatal("expected embedded GFF3 to report embedded sequence")
	}
	if isSession {
		t.Fatal("embedded GFF3 must not report comparison session")
	}
	if hasVariants {
		t.Fatal("embedded GFF3 must not report variants")
	}
}

func TestInspectInputEmbeddedGFF3WithLongLineReportsSequenceAndAnnotation(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "embedded.gff3")
	longAttr := strings.Repeat("A", 200000)
	content := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test;Note=" + longAttr + "\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTACGT\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isSession, hasVariants, err := e.InspectInput(path)
	if err != nil {
		t.Fatalf("InspectInput returned error: %v", err)
	}
	if !hasSequence || !hasAnnotation || !hasEmbeddedGFF3Sequence {
		t.Fatalf("unexpected inspect flags: seq=%v ann=%v emb=%v", hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence)
	}
	if isSession || hasVariants {
		t.Fatalf("unexpected inspect flags: session=%v variants=%v", isSession, hasVariants)
	}
}

func TestLoadEmbeddedGFF3MergesAnnotationsIntoMatchingGenome(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	gffPath := filepath.Join(dir, "embedded.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGTACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gff := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTACGT\n"
	if err := os.WriteFile(gffPath, []byte(gff), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome FASTA returned error: %v", err)
	}
	if err := e.LoadGenome(gffPath); err != nil {
		t.Fatalf("LoadGenome embedded GFF3 returned error: %v", err)
	}
	if got := e.sequences["chr1"]; got != "ACGTACGT" {
		t.Fatalf("sequence changed after embedded GFF3 merge: got %q", got)
	}
	if got := len(e.features["chr1"]); got != 1 {
		t.Fatalf("expected 1 merged feature, got %d", got)
	}
}

func TestLoadEmbeddedGFF3RejectsMismatchedLoadedGenome(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	gffPath := filepath.Join(dir, "embedded.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGTACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gff := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTTCGT\n"
	if err := os.WriteFile(gffPath, []byte(gff), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome FASTA returned error: %v", err)
	}
	err := e.LoadGenome(gffPath)
	if err == nil {
		t.Fatal("expected mismatched embedded GFF3 to be rejected")
	}
	if !strings.Contains(err.Error(), "does not match loaded reference") {
		t.Fatalf("unexpected mismatch error: %v", err)
	}
}

func TestLoadAnnotationRejectsMismatchedLoadedGenome(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	gffPath := filepath.Join(dir, "ann.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGTACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gff := "##gff-version 3\n" +
		"other_chr\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n"
	if err := os.WriteFile(gffPath, []byte(gff), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome FASTA returned error: %v", err)
	}
	err := e.LoadGenome(gffPath)
	if err == nil {
		t.Fatal("expected mismatched annotation to be rejected")
	}
	if !strings.Contains(err.Error(), "annotation file does not match loaded genome") {
		t.Fatalf("unexpected mismatch error: %v", err)
	}
}

func TestLoadBAMRejectsMismatchedLoadedGenome(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	if err := os.WriteFile(fastaPath, []byte(">wrong_chr\n"+strings.Repeat("A", 512)+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome FASTA returned error: %v", err)
	}
	_, err := e.LoadBAM(filepath.Join("testdata", "test_reads.bam"), 0)
	if err == nil {
		t.Fatal("expected mismatched BAM to be rejected")
	}
	if !strings.Contains(err.Error(), "BAM references do not match loaded genome") {
		t.Fatalf("unexpected BAM mismatch error: %v", err)
	}
}

func TestLoadGenomeFilesCombinesSequenceAndAnnotation(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	gffPath := filepath.Join(dir, "ann.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nAACCGGTT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(gffPath, []byte("##gff-version 3\nchr1\tsrc\tgene\t2\t7\t.\t+\t.\tID=g1;Name=gene1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenomeFiles([]string{fastaPath, gffPath}); err != nil {
		t.Fatalf("LoadGenomeFiles returned error: %v", err)
	}
	if got := e.sequences["chr1"]; got != "AACCGGTT" {
		t.Fatalf("sequence mismatch: got %q", got)
	}
	if got := len(e.features["chr1"]); got != 1 {
		t.Fatalf("expected 1 merged feature, got %d", got)
	}
	if got := e.features["chr1"][0]; got.Start != 1 || got.End != 7 {
		t.Fatalf("unexpected feature coordinates: %+v", got)
	}
}

func TestLoadGenomeFilesMergesMatchingEmbeddedGFF3(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	gffPath := filepath.Join(dir, "embedded.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGTACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gff := "##gff-version 3\n" +
		"chr1\tsrc\tgene\t2\t5\t.\t+\t.\tID=gene1;Name=test\n" +
		"##FASTA\n" +
		">chr1\n" +
		"ACGTACGT\n"
	if err := os.WriteFile(gffPath, []byte(gff), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome FASTA returned error: %v", err)
	}
	if err := e.LoadGenomeFiles([]string{gffPath}); err != nil {
		t.Fatalf("LoadGenomeFiles embedded GFF3 returned error: %v", err)
	}
	if got := e.sequences["chr1"]; got != "ACGTACGT" {
		t.Fatalf("sequence changed after embedded GFF3 merge: got %q", got)
	}
	if got := len(e.features["chr1"]); got != 1 {
		t.Fatalf("expected 1 merged feature, got %d", got)
	}
}

func TestResetBrowserStateClearsLoadedGenome(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nACGTACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	if !e.HasSequenceLoaded() {
		t.Fatal("expected sequence to be loaded")
	}

	e.ResetBrowserState()
	if e.HasSequenceLoaded() {
		t.Fatal("expected sequence to be cleared")
	}
	if got := len(e.ListChromosomes()); got != 0 {
		t.Fatalf("expected no chromosomes after reset, got %d", got)
	}
}

func TestSearchDNAExact(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = "ACGTACGT"
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"

	payload, err := e.SearchDNAExact(1, "ACG", true, 10)
	if err != nil {
		t.Fatalf("SearchDNAExact returned error: %v", err)
	}
	truncated, hits := decodeDNAHitsForTest(payload)
	if truncated {
		t.Fatal("expected non-truncated hit set")
	}
	if len(hits) != 4 {
		t.Fatalf("expected 4 hits, got %d", len(hits))
	}
	if hits[0].Start != 0 || hits[0].End != 3 || hits[0].Strand != '+' {
		t.Fatalf("unexpected first hit: %+v", hits[0])
	}
	if hits[2].Start != 1 || hits[2].End != 4 || hits[2].Strand != '-' {
		t.Fatalf("unexpected reverse-complement hit: %+v", hits[2])
	}
}

func TestGetReferenceSlice(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = "ACGTACGT"
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"

	payload, err := e.GetReferenceSlice(1, 2, 6)
	if err != nil {
		t.Fatalf("GetReferenceSlice returned error: %v", err)
	}
	start, end, seq := decodeReferenceSliceForTest(t, payload)
	if start != 2 || end != 6 || seq != "GTAC" {
		t.Fatalf("unexpected slice: start=%d end=%d seq=%q", start, end, seq)
	}
}

func TestGetReferenceSliceClampsEnd(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = "ACGTACGT"
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"

	payload, err := e.GetReferenceSlice(1, 6, 99)
	if err != nil {
		t.Fatalf("GetReferenceSlice returned error: %v", err)
	}
	start, end, seq := decodeReferenceSliceForTest(t, payload)
	if start != 6 || end != 8 || seq != "GT" {
		t.Fatalf("unexpected clamped slice: start=%d end=%d seq=%q", start, end, seq)
	}
}

func TestGetReferenceSliceRejectsInvertedRange(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = "ACGTACGT"
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"

	if _, err := e.GetReferenceSlice(1, 7, 6); err == nil {
		t.Fatal("expected inverted range to return an error")
	}
}

func TestLoadGenomeEMBL(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "record.embl")
	content := "" +
		"ID   SC10H5 standard; DNA; PRO; 12 BP.\n" +
		"FH   Key             Location/Qualifiers\n" +
		"FH\n" +
		"FT   source          1..12\n" +
		"FT                   /organism=\"Testus exampleii\"\n" +
		"FT   gene            2..8\n" +
		"FT                   /gene=\"foo\"\n" +
		"SQ   Sequence 12 BP; 3 A; 3 C; 3 G; 3 T; 0 other;\n" +
		"     acgtacgtacgt 12\n" +
		"//\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(path); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}

	if got := e.sequences["SC10H5"]; got != "ACGTACGTACGT" {
		t.Fatalf("loaded sequence = %q, want %q", got, "ACGTACGTACGT")
	}
	if got := e.chrLength["SC10H5"]; got != 12 {
		t.Fatalf("chrLength = %d, want 12", got)
	}
	feats := e.features["SC10H5"]
	if len(feats) != 2 {
		t.Fatalf("expected 2 features, got %d", len(feats))
	}
	if feats[0].Type != "source" || feats[0].Start != 0 || feats[0].End != 12 {
		t.Fatalf("unexpected source feature: %+v", feats[0])
	}
	if feats[1].Type != "gene" || feats[1].Attributes != "gene=foo" {
		t.Fatalf("unexpected gene feature: %+v", feats[1])
	}
}

func TestGetAnnotationsFiltersByOverlapLengthAndLimit(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = "ACGTACGTACGTACGT"
	e.chrLength["chr1"] = 16
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"
	e.features["chr1"] = []Feature{
		{SeqName: "chr1", Source: "src", Type: "gene", Start: 0, End: 3, Strand: '+', Attributes: "ID=short"},
		{SeqName: "chr1", Source: "src", Type: "gene", Start: 2, End: 8, Strand: '+', Attributes: "ID=mid"},
		{SeqName: "chr1", Source: "src", Type: "CDS", Start: 7, End: 12, Strand: '-', Attributes: "ID=late"},
		{SeqName: "chr1", Source: "src", Type: "misc_feature", Start: 12, End: 16, Strand: '.', Attributes: "ID=tail"},
	}

	payload, err := e.GetAnnotations(1, 3, 13, 2, 5)
	if err != nil {
		t.Fatalf("GetAnnotations returned error: %v", err)
	}
	start, end, feats := decodeAnnotationsForTest(t, payload)
	if start != 3 || end != 13 {
		t.Fatalf("unexpected annotation window: %d..%d", start, end)
	}
	if len(feats) != 2 {
		t.Fatalf("expected 2 features after limit/filtering, got %d", len(feats))
	}
	if feats[0].Attributes != "ID=mid" || feats[1].Attributes != "ID=late" {
		t.Fatalf("unexpected filtered features: %+v", feats)
	}
}

func TestGetAnnotationTileUsesTileWindow(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = strings.Repeat("A", 5000)
	e.chrLength["chr1"] = 5000
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"
	e.features["chr1"] = []Feature{
		{SeqName: "chr1", Source: "src", Type: "gene", Start: 10, End: 20, Strand: '+', Attributes: "ID=early"},
		{SeqName: "chr1", Source: "src", Type: "gene", Start: 1100, End: 1200, Strand: '+', Attributes: "ID=tile1"},
		{SeqName: "chr1", Source: "src", Type: "gene", Start: 2500, End: 2600, Strand: '-', Attributes: "ID=tile2"},
	}

	payload, err := e.GetAnnotationTile(1, 0, 1, 10, 1)
	if err != nil {
		t.Fatalf("GetAnnotationTile returned error: %v", err)
	}
	start, end, feats := decodeAnnotationsForTest(t, payload)
	if start != 1024 || end != 2048 {
		t.Fatalf("unexpected tile window: %d..%d", start, end)
	}
	if len(feats) != 1 || feats[0].Attributes != "ID=tile1" {
		t.Fatalf("unexpected tile features: %+v", feats)
	}
}

func TestGetStopCodonTileUsesTileWindow(t *testing.T) {
	e := NewEngine()
	e.sequences["chr1"] = strings.Repeat("CAA", 340) + "TAA" + strings.Repeat("CAA", 340)
	e.chrLength["chr1"] = len(e.sequences["chr1"])
	e.chrToID["chr1"] = 1
	e.idToChr[1] = "chr1"

	payload, err := e.GetStopCodonTile(1, 0, 0)
	if err != nil {
		t.Fatalf("GetStopCodonTile returned error: %v", err)
	}
	start, end, binCount, frames := decodeStopCodonTileForTest(t, payload)
	if start != 0 || end != 1024 {
		t.Fatalf("unexpected stop-codon tile window: %d..%d", start, end)
	}
	if binCount != stopCodonTileBins {
		t.Fatalf("unexpected stop-codon tile bin count: %d", binCount)
	}
	if len(frames) != 6 {
		t.Fatalf("expected 6 frames, got %d", len(frames))
	}
	found := false
	for frame := 0; frame < len(frames) && !found; frame++ {
		for _, v := range frames[frame] {
			if v != 0 {
				found = true
				break
			}
		}
	}
	if !found {
		t.Fatal("expected stop codon occupancy in tile")
	}
}

func TestAnnotationOnlyLoadInvalidatesAnnotationTileCache(t *testing.T) {
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	if err := os.WriteFile(fastaPath, []byte(">chr1\n"+strings.Repeat("A", 3000)+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	gff1Path := filepath.Join(dir, "ann1.gff3")
	gff1 := "" +
		"##gff-version 3\n" +
		"chr1\tsrc\tgene\t1101\t1200\t.\t+\t.\tID=gene1\n"
	if err := os.WriteFile(gff1Path, []byte(gff1), 0o644); err != nil {
		t.Fatal(err)
	}
	gff2Path := filepath.Join(dir, "ann2.gff3")
	gff2 := "" +
		"##gff-version 3\n" +
		"chr1\tsrc\tgene\t1101\t1200\t.\t+\t.\tID=gene2\n"
	if err := os.WriteFile(gff2Path, []byte(gff2), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	if err := e.LoadGenome(fastaPath); err != nil {
		t.Fatalf("LoadGenome fasta returned error: %v", err)
	}
	if err := e.LoadGenome(gff1Path); err != nil {
		t.Fatalf("LoadGenome gff1 returned error: %v", err)
	}

	chrID := e.chrToID["chr1"]
	payload, err := e.GetAnnotationTile(chrID, 0, 1, 10, 1)
	if err != nil {
		t.Fatalf("GetAnnotationTile before merge returned error: %v", err)
	}
	_, _, feats := decodeAnnotationsForTest(t, payload)
	if len(feats) != 1 || feats[0].Attributes != "ID=gene1" {
		t.Fatalf("unexpected features before merge: %+v", feats)
	}

	if err := e.LoadGenome(gff2Path); err != nil {
		t.Fatalf("LoadGenome gff2 returned error: %v", err)
	}
	payload, err = e.GetAnnotationTile(chrID, 0, 1, 10, 1)
	if err != nil {
		t.Fatalf("GetAnnotationTile after merge returned error: %v", err)
	}
	_, _, feats = decodeAnnotationsForTest(t, payload)
	if len(feats) != 2 {
		t.Fatalf("expected 2 features after merge, got %d", len(feats))
	}
	attrs := []string{feats[0].Attributes, feats[1].Attributes}
	slices.Sort(attrs)
	if !slices.Equal(attrs, []string{"ID=gene1", "ID=gene2"}) {
		t.Fatalf("unexpected merged attributes: %v", attrs)
	}
}

func TestResolveBAMRefChromIDLockedMatchesVersionedAliasByLength(t *testing.T) {
	e := NewEngine()
	wantID := e.ensureChromosomeLocked("NC_000962", 4411532)

	gotID := e.resolveBAMRefChromIDLocked("NC_000962.3", 4411532)
	if gotID != wantID {
		t.Fatalf("resolveBAMRefChromIDLocked returned id %d, want %d", gotID, wantID)
	}
	if len(e.chromOrder) != 1 {
		t.Fatalf("expected alias match to reuse chromosome, got %d chromosomes", len(e.chromOrder))
	}

	newID := e.resolveBAMRefChromIDLocked("NC_000962.4", 4411533)
	if newID == wantID {
		t.Fatal("expected differing length to create a distinct chromosome id")
	}
	if len(e.chromOrder) != 2 {
		t.Fatalf("expected second chromosome after length mismatch, got %d", len(e.chromOrder))
	}
}

func TestEncodeCoverageTilesFromStrandPrefixes(t *testing.T) {
	forward := make([]uint64, 257)
	reverse := make([]uint64, 257)
	depthsFwd := []uint64{3, 1, 0}
	depthsRev := []uint64{2, 0, 4}
	for i := 0; i < len(depthsFwd); i++ {
		forward[i+1] = forward[i] + depthsFwd[i]
		reverse[i+1] = reverse[i] + depthsRev[i]
	}
	for i := len(depthsFwd); i < 256; i++ {
		forward[i+1] = forward[i]
		reverse[i+1] = reverse[i]
	}

	totalPayload, err := encodeCoverageTileFromStrandPrefixes(0, 256, forward, reverse, 256)
	if err != nil {
		t.Fatalf("encodeCoverageTileFromStrandPrefixes returned error: %v", err)
	}
	totalBins := decodeCoverageBinsForTest(t, totalPayload)
	if totalBins[0] != 5 || totalBins[1] != 1 || totalBins[2] != 4 {
		t.Fatalf("unexpected total bins: got [%d %d %d], want [5 1 4]", totalBins[0], totalBins[1], totalBins[2])
	}

	strandPayload, err := encodeStrandCoverageTileFromStrandPrefixes(0, 256, forward, reverse, 256)
	if err != nil {
		t.Fatalf("encodeStrandCoverageTileFromStrandPrefixes returned error: %v", err)
	}
	fwdBins, revBins := decodeStrandCoverageBinsForTest(t, strandPayload)
	if fwdBins[0] != 3 || fwdBins[1] != 1 || fwdBins[2] != 0 {
		t.Fatalf("unexpected forward bins: got [%d %d %d], want [3 1 0]", fwdBins[0], fwdBins[1], fwdBins[2])
	}
	if revBins[0] != 2 || revBins[1] != 0 || revBins[2] != 4 {
		t.Fatalf("unexpected reverse bins: got [%d %d %d], want [2 0 4]", revBins[0], revBins[1], revBins[2])
	}
}

func TestLoadBAMFixtureReadTileIncludesProperPair(t *testing.T) {
	e := NewEngine()
	refPath := filepath.Join("testdata", "test_reads.ref.fa")
	bamPath := filepath.Join("testdata", "test_reads.bam")
	if err := e.LoadGenome(refPath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	sourceID, err := e.LoadBAM(bamPath, 0)
	if err != nil {
		t.Fatalf("LoadBAM returned error: %v", err)
	}

	chrID := e.chrToID["chrTest"]
	payload, err := e.GetTile(sourceID, chrID, 1, 0)
	if err != nil {
		t.Fatalf("GetTile returned error: %v", err)
	}
	alns := decodeAlignmentTileForTest(t, payload)
	if len(alns) != 4 {
		t.Fatalf("expected 4 alignments in first tile, got %d", len(alns))
	}

	var pairAlns []Alignment
	for _, aln := range alns {
		if aln.Name == "pair1" {
			pairAlns = append(pairAlns, aln)
		}
	}
	if len(pairAlns) != 2 {
		t.Fatalf("expected 2 pair1 alignments, got %d", len(pairAlns))
	}

	flags := []uint16{pairAlns[0].Flags, pairAlns[1].Flags}
	slices.Sort(flags)
	if !slices.Equal(flags, []uint16{99, 147}) {
		t.Fatalf("unexpected pair flags: %v", flags)
	}

	for _, aln := range pairAlns {
		if aln.MapQ != 60 {
			t.Fatalf("unexpected pair MapQ: %+v", aln)
		}
		if aln.MateStart != 200 && aln.MateStart != 420 {
			t.Fatalf("unexpected mate start: %+v", aln)
		}
		if aln.MateEnd != 325 && aln.MateEnd != 545 {
			t.Fatalf("unexpected mate end: %+v", aln)
		}
		if aln.FragLen != 345 {
			t.Fatalf("unexpected fragment length: %+v", aln)
		}
	}
}

func TestMateFieldsForRecordHidesUnmappedMate(t *testing.T) {
	ref, err := sam.NewReference("chr1", "", "", 1000, nil, nil)
	if err != nil {
		t.Fatalf("NewReference returned error: %v", err)
	}
	rec := &sam.Record{
		Name:  "read1",
		Ref:   ref,
		Cigar: sam.Cigar{sam.NewCigarOp(sam.CigarMatch, 50)},
		Seq:   sam.NewSeq([]byte(strings.Repeat("A", 50))),
	}
	rec.Flags = sam.Paired | sam.MateUnmapped
	rec.MatePos = 123
	rec.MateRef = ref

	mateStart, mateEnd, mateRawStart, mateRawEnd, mateRefID := mateFieldsForRecord(rec)
	if mateStart != -1 || mateEnd != -1 || mateRawStart != -1 || mateRawEnd != -1 || mateRefID != -1 {
		t.Fatalf("expected unmapped mate fields to be hidden, got start=%d end=%d rawStart=%d rawEnd=%d refID=%d", mateStart, mateEnd, mateRawStart, mateRawEnd, mateRefID)
	}
}

func TestMateFieldsForRecordKeepsMappedCrossContigMate(t *testing.T) {
	ref, err := sam.NewReference("chr1", "", "", 1000, nil, nil)
	if err != nil {
		t.Fatalf("NewReference returned error: %v", err)
	}
	mateRef, err := sam.NewReference("chr2", "", "", 1000, nil, nil)
	if err != nil {
		t.Fatalf("NewReference returned error: %v", err)
	}
	rec := &sam.Record{
		Name:  "read1",
		Ref:   ref,
		Cigar: sam.Cigar{sam.NewCigarOp(sam.CigarMatch, 50)},
		Seq:   sam.NewSeq([]byte(strings.Repeat("A", 50))),
	}
	rec.Flags = sam.Paired
	rec.MatePos = 123
	rec.MateRef = mateRef

	mateStart, mateEnd, mateRawStart, mateRawEnd, mateRefID := mateFieldsForRecord(rec)
	if mateStart != 123 || mateEnd != 173 || mateRawStart != 123 || mateRawEnd != 173 {
		t.Fatalf("unexpected mapped mate coordinates: start=%d end=%d rawStart=%d rawEnd=%d", mateStart, mateEnd, mateRawStart, mateRawEnd)
	}
	if mateRefID != mateRef.ID() {
		t.Fatalf("unexpected mate ref id: got %d want %d", mateRefID, mateRef.ID())
	}
}

func TestLoadBAMFixtureCoverageTiles(t *testing.T) {
	e := NewEngine()
	refPath := filepath.Join("testdata", "test_reads.ref.fa")
	bamPath := filepath.Join("testdata", "test_reads.bam")
	if err := e.LoadGenome(refPath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	sourceID, err := e.LoadBAM(bamPath, 100000)
	if err != nil {
		t.Fatalf("LoadBAM returned error: %v", err)
	}

	chrID := e.chrToID["chrTest"]
	covPayload, err := e.GetCoverageTile(sourceID, chrID, 1, 0)
	if err != nil {
		t.Fatalf("GetCoverageTile returned error: %v", err)
	}
	covBins := decodeCoverageBinsForTest(t, covPayload)
	if covBins[25] == 0 {
		t.Fatalf("expected coverage near pair1 first mate, bin 25 was zero")
	}
	if covBins[112] == 0 {
		t.Fatalf("expected coverage near single_fwd, bin 112 was zero")
	}

	strandPayload, err := e.GetStrandCoverageTile(sourceID, chrID, 1, 0)
	if err != nil {
		t.Fatalf("GetStrandCoverageTile returned error: %v", err)
	}
	forwardBins, reverseBins := decodeStrandCoverageBinsForTest(t, strandPayload)
	if forwardBins[25] == 0 || reverseBins[25] != 0 {
		t.Fatalf("unexpected strand coverage around first mate: fwd=%d rev=%d", forwardBins[25], reverseBins[25])
	}
	if reverseBins[52] == 0 || forwardBins[52] != 0 {
		t.Fatalf("unexpected strand coverage around second mate: fwd=%d rev=%d", forwardBins[52], reverseBins[52])
	}
}

func TestLoadBAMFixtureReadBoundariesAreExact(t *testing.T) {
	e := NewEngine()
	refPath := filepath.Join("testdata", "test_reads.ref.fa")
	bamPath := filepath.Join("testdata", "test_reads.bam")
	if err := e.LoadGenome(refPath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	sourceID, err := e.LoadBAM(bamPath, 0)
	if err != nil {
		t.Fatalf("LoadBAM returned error: %v", err)
	}

	chrID := e.chrToID["chrTest"]
	src := e.bamSources[sourceID]
	ref := src.RefByChrID[chrID]
	payload, err := loadIndexedTilePayload(src.Path, src.Index, ref, 0, 3000, readTileCacheKind, 100, true, e.sequences["chrTest"], 0)
	if err != nil {
		t.Fatalf("loadIndexedTilePayload returned error: %v", err)
	}
	alns := decodeAlignmentTileForTest(t, payload)
	if len(alns) != 5 {
		t.Fatalf("expected 5 alignments, got %d", len(alns))
	}

	got := make(map[string][]Alignment)
	for _, aln := range alns {
		got[aln.Name] = append(got[aln.Name], aln)
	}

	pair := got["pair1"]
	if len(pair) != 2 {
		t.Fatalf("expected 2 pair1 alignments, got %d", len(pair))
	}
	slices.SortFunc(pair, func(a, b Alignment) int { return a.Start - b.Start })
	if pair[0].Start != 200 || pair[0].End != 325 || pair[0].Cigar != "125M" || pair[0].Reverse {
		t.Fatalf("unexpected first pair alignment: %+v", pair[0])
	}
	if pair[1].Start != 420 || pair[1].End != 545 || pair[1].Cigar != "125M" || !pair[1].Reverse {
		t.Fatalf("unexpected second pair alignment: %+v", pair[1])
	}

	singleFwd := got["single_fwd"]
	if len(singleFwd) != 1 || singleFwd[0].Start != 900 || singleFwd[0].End != 1040 || singleFwd[0].Cigar != "140M" {
		t.Fatalf("unexpected single_fwd alignment: %+v", singleFwd)
	}

	singleRev := got["single_rev"]
	if len(singleRev) != 1 || singleRev[0].Start != 1500 || singleRev[0].End != 1635 || singleRev[0].Cigar != "135M" || !singleRev[0].Reverse {
		t.Fatalf("unexpected single_rev alignment: %+v", singleRev)
	}

	indel := got["indel_like"]
	if len(indel) != 1 || indel[0].Start != 2200 || indel[0].End != 2350 || indel[0].Cigar != "70M1I38M1D41M" {
		t.Fatalf("unexpected indel_like alignment: %+v", indel)
	}
}

func TestLoadBAMFixtureCoverageBoundariesAreExact(t *testing.T) {
	e := NewEngine()
	refPath := filepath.Join("testdata", "test_reads.ref.fa")
	bamPath := filepath.Join("testdata", "test_reads.bam")
	if err := e.LoadGenome(refPath); err != nil {
		t.Fatalf("LoadGenome returned error: %v", err)
	}
	sourceID, err := e.LoadBAM(bamPath, 0)
	if err != nil {
		t.Fatalf("LoadBAM returned error: %v", err)
	}

	chrID := e.chrToID["chrTest"]
	src := e.bamSources[sourceID]
	ref := src.RefByChrID[chrID]

	forwardWindowStart := 100
	forwardWindowEnd := 356 // 256 bp window; one bin per base.
	covPayload, err := loadIndexedTilePayload(src.Path, src.Index, ref, forwardWindowStart, forwardWindowEnd, covTileCacheKind, 0, false, "", 256)
	if err != nil {
		t.Fatalf("forward-window coverage payload error: %v", err)
	}
	covBins := decodeCoverageBinsForTest(t, covPayload)
	if covBins[99] != 0 || covBins[100] != 1 || covBins[224] != 1 || covBins[225] != 0 {
		t.Fatalf("unexpected forward coverage edges around pair1 start/end: bins[99..100]=[%d %d] bins[224..225]=[%d %d]", covBins[99], covBins[100], covBins[224], covBins[225])
	}

	strandPayload, err := loadIndexedTilePayload(src.Path, src.Index, ref, forwardWindowStart, forwardWindowEnd, strandCovTileCacheKind, 0, false, "", 256)
	if err != nil {
		t.Fatalf("forward-window strand coverage payload error: %v", err)
	}
	fwdBins, revBins := decodeStrandCoverageBinsForTest(t, strandPayload)
	if fwdBins[100] != 1 || revBins[100] != 0 || fwdBins[225] != 0 || revBins[225] != 0 {
		t.Fatalf("unexpected strand coverage around first mate edge: fwd[100]=%d rev[100]=%d fwd[225]=%d rev[225]=%d", fwdBins[100], revBins[100], fwdBins[225], revBins[225])
	}

	reverseWindowStart := 400
	reverseWindowEnd := 656 // 256 bp window; one bin per base.
	reverseStrandPayload, err := loadIndexedTilePayload(src.Path, src.Index, ref, reverseWindowStart, reverseWindowEnd, strandCovTileCacheKind, 0, false, "", 256)
	if err != nil {
		t.Fatalf("reverse-window strand coverage payload error: %v", err)
	}
	fwdBins, revBins = decodeStrandCoverageBinsForTest(t, reverseStrandPayload)
	if fwdBins[20] != 0 || revBins[20] != 1 || fwdBins[144] != 0 || revBins[144] != 1 || revBins[145] != 0 {
		t.Fatalf("unexpected strand coverage around second mate edges: fwd[20]=%d rev[20]=%d fwd[144]=%d rev[144]=%d rev[145]=%d", fwdBins[20], revBins[20], fwdBins[144], revBins[144], revBins[145])
	}
}

func TestCoverageTailTilesUseProportionalBinCount(t *testing.T) {
	tailBins := coverageTileBinCount(1024, 2048, 0, 1536)
	if tailBins != 128 {
		t.Fatalf("unexpected tail coverage bin count: got %d, want 128", tailBins)
	}

	forwardPrefix := make([]uint64, 1537)
	reversePrefix := make([]uint64, 1537)
	for i := 1024; i < 1536; i++ {
		forwardPrefix[i+1] = forwardPrefix[i] + 1
		reversePrefix[i+1] = reversePrefix[i]
	}

	covPayload, err := encodeCoverageTileFromStrandPrefixes(1024, 2048, forwardPrefix, reversePrefix, tailBins)
	if err != nil {
		t.Fatalf("encodeCoverageTileFromStrandPrefixes returned error: %v", err)
	}
	covBins := decodeCoverageBinsForTest(t, covPayload)
	if len(covBins) != 128 {
		t.Fatalf("unexpected tail coverage bin length: got %d, want 128", len(covBins))
	}

	strandPayload, err := encodeStrandCoverageTileFromStrandPrefixes(1024, 2048, forwardPrefix, reversePrefix, tailBins)
	if err != nil {
		t.Fatalf("encodeStrandCoverageTileFromStrandPrefixes returned error: %v", err)
	}
	forwardBins, reverseBins := decodeStrandCoverageBinsForTest(t, strandPayload)
	if len(forwardBins) != 128 || len(reverseBins) != 128 {
		t.Fatalf("unexpected tail strand coverage bin lengths: got %d/%d, want 128/128", len(forwardBins), len(reverseBins))
	}
}

func TestDispatchGetVersion(t *testing.T) {
	msgType, payload, err := HandleMessage(NewEngine(), MsgGetVersion, nil)
	if err != nil {
		t.Fatalf("HandleMessage returned error: %v", err)
	}
	if msgType != MsgGetVersion {
		t.Fatalf("unexpected message type: got %d, want %d", msgType, MsgGetVersion)
	}
	if got := decodeWireAckForTest(t, payload); got != ZemVersion {
		t.Fatalf("unexpected version payload: got %q, want %q", got, ZemVersion)
	}
}

func TestBackendHandleMessageGetVersion(t *testing.T) {
	backend := NewBackend()
	msgType, payload, err := backend.HandleMessage(MsgGetVersion, nil)
	if err != nil {
		t.Fatalf("Backend.HandleMessage returned error: %v", err)
	}
	if msgType != MsgGetVersion {
		t.Fatalf("unexpected message type: got %d, want %d", msgType, MsgGetVersion)
	}
	if got := decodeWireAckForTest(t, payload); got != ZemVersion {
		t.Fatalf("unexpected version payload: got %q, want %q", got, ZemVersion)
	}
}

func TestGenerateTestData(t *testing.T) {
	e := NewEngine()
	root := t.TempDir()
	files, err := e.GenerateTestData(root)
	if err != nil {
		t.Fatalf("GenerateTestData returned error: %v", err)
	}
	if len(files) != 5 {
		t.Fatalf("unexpected generated file count: got %d, want %d", len(files), 5)
	}
	for _, path := range files {
		if _, err := os.Stat(path); err != nil {
			t.Fatalf("generated file missing: %s (%v)", path, err)
		}
	}
	if _, err := os.Stat(files[2] + ".bai"); err != nil {
		t.Fatalf("generated single-end BAM index missing: %v", err)
	}
	if _, err := os.Stat(files[3] + ".bai"); err != nil {
		t.Fatalf("generated paired-end BAM index missing: %v", err)
	}
	if got := filepath.Ext(files[4]); got != ".vcf" {
		t.Fatalf("expected VCF as 5th generated file, got %q", files[4])
	}
	if err := e.LoadGenome(files[0]); err != nil {
		t.Fatalf("loading generated FASTA failed: %v", err)
	}
	if err := e.LoadGenome(files[1]); err != nil {
		t.Fatalf("loading generated GFF failed: %v", err)
	}
	if _, err := e.LoadBAM(files[2], 0); err != nil {
		t.Fatalf("loading generated single-end BAM failed: %v", err)
	}
	if _, err := e.LoadBAM(files[3], 0); err != nil {
		t.Fatalf("loading generated paired-end BAM failed: %v", err)
	}
	variantSource, err := e.LoadVariantFile(files[4])
	if err != nil {
		t.Fatalf("loading generated VCF failed: %v", err)
	}
	if !slices.Equal(variantSource.SampleNames, []string{"sample_a", "sample_b"}) {
		t.Fatalf("unexpected generated VCF samples: %v", variantSource.SampleNames)
	}
	seenKinds := map[byte]bool{}
	for _, records := range variantSource.VariantsByChr {
		for _, record := range records {
			seenKinds[record.Kind] = true
		}
	}
	for _, kind := range []byte{variantKindSNP, variantKindInsertion, variantKindDeletion, variantKindComplex} {
		if !seenKinds[kind] {
			t.Fatalf("generated VCF missing variant kind %d", kind)
		}
	}
	chroms := e.ListChromosomes()
	if len(chroms) != 9 {
		t.Fatalf("unexpected chromosome count after generated test data load: got %d, want 9", len(chroms))
	}
}

func TestGenerateTestDataIncludesSoftClipBoundaryReads(t *testing.T) {
	e := NewEngine()
	root := t.TempDir()
	files, err := e.GenerateTestData(root)
	if err != nil {
		t.Fatalf("GenerateTestData returned error: %v", err)
	}
	if err := e.LoadGenome(files[0]); err != nil {
		t.Fatalf("loading generated FASTA failed: %v", err)
	}
	sourceID, err := e.LoadBAM(files[2], 0)
	if err != nil {
		t.Fatalf("loading generated single-end BAM failed: %v", err)
	}

	ctgAID := e.chrToID["ctgA"]
	ctgBID := e.chrToID["ctgB"]
	src := e.bamSources[sourceID]

	ctgARef := src.RefByChrID[ctgAID]
	payload, err := loadIndexedTilePayload(src.Path, src.Index, ctgARef, 0, testContigLen, readTileCacheKind, 20000, true, e.sequences["ctgA"], 0)
	if err != nil {
		t.Fatalf("loadIndexedTilePayload ctgA returned error: %v", err)
	}
	alnsA := decodeAlignmentTileForTest(t, payload)
	foundAStart := false
	foundAEnd := false
	for _, aln := range alnsA {
		switch aln.Name {
		case "ctgA_softclip_start_overhang":
			foundAStart = true
			if aln.Start != 0 || aln.SoftClipLeft != "TGCATGCATGCATGCATGCATGCA" || aln.SoftClipRight != "" {
				t.Fatalf("unexpected ctgA start overhang alignment: %+v", aln)
			}
		case "ctgA_softclip_end_overhang":
			foundAEnd = true
			if aln.Start != testContigLen-testReadLen || aln.SoftClipLeft != "" || aln.SoftClipRight != "CAGTCAGTCAGTCAGTCAGTCAGTCAGT" {
				t.Fatalf("unexpected ctgA end overhang alignment: %+v", aln)
			}
		}
	}
	if !foundAStart || !foundAEnd {
		t.Fatalf("missing expected ctgA soft-clip boundary reads: start=%v end=%v", foundAStart, foundAEnd)
	}

	ctgBRef := src.RefByChrID[ctgBID]
	payload, err = loadIndexedTilePayload(src.Path, src.Index, ctgBRef, 0, testContigLen, readTileCacheKind, 20000, true, e.sequences["ctgB"], 0)
	if err != nil {
		t.Fatalf("loadIndexedTilePayload ctgB returned error: %v", err)
	}
	alnsB := decodeAlignmentTileForTest(t, payload)
	foundBStart := false
	for _, aln := range alnsB {
		if aln.Name != "ctgB_softclip_start_overhang" {
			continue
		}
		foundBStart = true
		if aln.Start != 0 || aln.SoftClipLeft != "TGCATGCATGCATGCATGCATG" || aln.SoftClipRight != "" {
			t.Fatalf("unexpected ctgB start overhang alignment: %+v", aln)
		}
	}
	if !foundBStart {
		t.Fatal("missing expected ctgB soft-clip start overhang read")
	}
}

func TestGenerateTestDataVCFSNPMaskPresent(t *testing.T) {
	e := NewEngine()
	root := t.TempDir()
	files, err := e.GenerateTestData(root)
	if err != nil {
		t.Fatalf("GenerateTestData returned error: %v", err)
	}
	if err := e.LoadGenome(files[0]); err != nil {
		t.Fatalf("loading generated FASTA failed: %v", err)
	}
	source, err := e.LoadVariantFile(files[4])
	if err != nil {
		t.Fatalf("loading generated VCF failed: %v", err)
	}
	ctgAID := uint16(0)
	foundChr := false
	for _, chr := range e.ListChromosomes() {
		if chr.Name == "ctgA" {
			ctgAID = chr.ID
			foundChr = true
			break
		}
	}
	if !foundChr {
		t.Fatal("ctgA chromosome id missing")
	}
	payload, err := e.GetVariantTile(source.ID, ctgAID, 5, 0)
	if err != nil {
		t.Fatalf("GetVariantTile returned error: %v", err)
	}
	_, _, records := decodeVariantTileForTest(t, payload)
	found := false
	for _, record := range records {
		if record.ID != "demo_snp_1" {
			continue
		}
		found = true
		if record.Kind != variantKindSNP {
			t.Fatalf("demo_snp_1 kind = %d, want %d", record.Kind, variantKindSNP)
		}
		if len(record.SampleClasses) != 2 {
			t.Fatalf("demo_snp_1 sample classes len = %d, want 2", len(record.SampleClasses))
		}
		if record.SampleClasses[0] != variantGTHet || record.SampleClasses[1] != variantGTHomAlt {
			t.Fatalf("demo_snp_1 sample classes = %v, want [%d %d]", record.SampleClasses, variantGTHet, variantGTHomAlt)
		}
		if len(record.SampleTexts) != 2 || record.SampleTexts[0] == "" || record.SampleTexts[1] == "" {
			t.Fatalf("demo_snp_1 sample texts unexpectedly empty: %v", record.SampleTexts)
		}
	}
	if !found {
		t.Fatal("demo_snp_1 not found in ctgA tile")
	}
}

func decodeDNAHitsForTest(payload []byte) (bool, []DNAExactHit) {
	if len(payload) < 3 {
		return false, nil
	}
	truncated := payload[0] != 0
	count := int(binary.LittleEndian.Uint16(payload[1:3]))
	hits := make([]DNAExactHit, 0, count)
	off := 3
	for i := 0; i < count && off+9 <= len(payload); i++ {
		hits = append(hits, DNAExactHit{
			Start:  int(binary.LittleEndian.Uint32(payload[off : off+4])),
			End:    int(binary.LittleEndian.Uint32(payload[off+4 : off+8])),
			Strand: payload[off+8],
		})
		off += 9
	}
	return truncated, hits
}

func decodeReferenceSliceForTest(t *testing.T, payload []byte) (int, int, string) {
	t.Helper()
	if len(payload) < 12 {
		t.Fatalf("reference slice payload too short")
	}
	start := int(binary.LittleEndian.Uint32(payload[0:4]))
	end := int(binary.LittleEndian.Uint32(payload[4:8]))
	n := int(binary.LittleEndian.Uint32(payload[8:12]))
	if len(payload) < 12+n {
		t.Fatalf("reference slice payload truncated")
	}
	return start, end, string(payload[12 : 12+n])
}

func decodeAnnotationsForTest(t *testing.T, payload []byte) (int, int, []Feature) {
	t.Helper()
	if len(payload) < 12 {
		t.Fatalf("annotation payload too short")
	}
	start := int(binary.LittleEndian.Uint32(payload[0:4]))
	end := int(binary.LittleEndian.Uint32(payload[4:8]))
	count := int(binary.LittleEndian.Uint32(payload[8:12]))
	off := 12
	feats := make([]Feature, 0, count)
	for i := 0; i < count; i++ {
		if off+12 > len(payload) {
			t.Fatalf("annotation payload truncated")
		}
		feat := Feature{
			Start:  int(binary.LittleEndian.Uint32(payload[off : off+4])),
			End:    int(binary.LittleEndian.Uint32(payload[off+4 : off+8])),
			Strand: payload[off+8],
		}
		seqNameLen := int(binary.LittleEndian.Uint16(payload[off+10 : off+12]))
		off += 12
		if off+seqNameLen > len(payload) {
			t.Fatalf("annotation seqname overflow")
		}
		feat.SeqName = string(payload[off : off+seqNameLen])
		off += seqNameLen
		if off+2 > len(payload) {
			t.Fatalf("annotation source length missing")
		}
		sourceLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+sourceLen > len(payload) {
			t.Fatalf("annotation source overflow")
		}
		feat.Source = string(payload[off : off+sourceLen])
		off += sourceLen
		if off+2 > len(payload) {
			t.Fatalf("annotation type length missing")
		}
		typeLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+typeLen > len(payload) {
			t.Fatalf("annotation type overflow")
		}
		feat.Type = string(payload[off : off+typeLen])
		off += typeLen
		if off+2 > len(payload) {
			t.Fatalf("annotation attr length missing")
		}
		attrLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+attrLen > len(payload) {
			t.Fatalf("annotation attr overflow")
		}
		feat.Attributes = string(payload[off : off+attrLen])
		off += attrLen
		feats = append(feats, feat)
	}
	return start, end, feats
}

func decodeStopCodonTileForTest(t *testing.T, payload []byte) (int, int, int, [6][]byte) {
	t.Helper()
	var frames [6][]byte
	if len(payload) < 13 {
		t.Fatalf("stop codon tile payload too short")
	}
	if payload[0] != 5 {
		t.Fatalf("unexpected stop codon tile type: %d", payload[0])
	}
	start := int(binary.LittleEndian.Uint32(payload[1:5]))
	end := int(binary.LittleEndian.Uint32(payload[5:9]))
	binCount := int(binary.LittleEndian.Uint32(payload[9:13]))
	off := 13
	for frame := 0; frame < 6; frame++ {
		if off+binCount > len(payload) {
			t.Fatalf("stop codon tile payload truncated")
		}
		frames[frame] = append([]byte(nil), payload[off:off+binCount]...)
		off += binCount
	}
	return start, end, binCount, frames
}

func decodeAlignmentTileForTest(t *testing.T, payload []byte) []Alignment {
	t.Helper()
	if len(payload) < 13 || payload[0] != 2 {
		t.Fatalf("invalid alignment payload header")
	}
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	alns := make([]Alignment, 0, count)
	off := 13
	for i := 0; i < count; i++ {
		if off+38 > len(payload) {
			t.Fatalf("alignment payload too short")
		}
		start := int(binary.LittleEndian.Uint32(payload[off : off+4]))
		end := int(binary.LittleEndian.Uint32(payload[off+4 : off+8]))
		mapQ := payload[off+8]
		reverse := payload[off+9] != 0
		flags := binary.LittleEndian.Uint16(payload[off+10 : off+12])
		mateStartRaw := binary.LittleEndian.Uint32(payload[off+12 : off+16])
		mateEndRaw := binary.LittleEndian.Uint32(payload[off+16 : off+20])
		fragLen := int(binary.LittleEndian.Uint32(payload[off+20 : off+24]))
		mateRawStartRaw := binary.LittleEndian.Uint32(payload[off+24 : off+28])
		mateRawEndRaw := binary.LittleEndian.Uint32(payload[off+28 : off+32])
		mateRefIDRaw := binary.LittleEndian.Uint32(payload[off+32 : off+36])
		nameLen := int(binary.LittleEndian.Uint16(payload[off+36 : off+38]))
		off += 38
		if off+nameLen > len(payload) {
			t.Fatalf("alignment name overflow")
		}
		name := string(payload[off : off+nameLen])
		off += nameLen
		if off+2 > len(payload) {
			t.Fatalf("missing cigar length")
		}
		cigarLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+cigarLen > len(payload) {
			t.Fatalf("alignment cigar overflow")
		}
		cigar := string(payload[off : off+cigarLen])
		off += cigarLen
		if off+2 > len(payload) {
			t.Fatalf("missing left soft-clip length")
		}
		leftSoftLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+leftSoftLen > len(payload) {
			t.Fatalf("alignment left soft-clip overflow")
		}
		leftSoft := string(payload[off : off+leftSoftLen])
		off += leftSoftLen
		if off+2 > len(payload) {
			t.Fatalf("missing right soft-clip length")
		}
		rightSoftLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if off+rightSoftLen > len(payload) {
			t.Fatalf("alignment right soft-clip overflow")
		}
		rightSoft := string(payload[off : off+rightSoftLen])
		off += rightSoftLen
		if off+2 > len(payload) {
			t.Fatalf("missing snp count")
		}
		snpCount := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2 + 5*snpCount
		if off > len(payload) {
			t.Fatalf("alignment snp overflow")
		}
		mateStart := -1
		mateEnd := -1
		mateRawStart := -1
		mateRawEnd := -1
		mateRefID := -1
		if mateStartRaw != 0xFFFFFFFF && mateEndRaw != 0xFFFFFFFF {
			mateStart = int(mateStartRaw)
			mateEnd = int(mateEndRaw)
		}
		if mateRawStartRaw != 0xFFFFFFFF && mateRawEndRaw != 0xFFFFFFFF {
			mateRawStart = int(mateRawStartRaw)
			mateRawEnd = int(mateRawEndRaw)
		}
		if mateRefIDRaw != 0xFFFFFFFF {
			mateRefID = int(mateRefIDRaw)
		}
		alns = append(alns, Alignment{
			Start:         start,
			End:           end,
			Name:          name,
			MapQ:          mapQ,
			Flags:         flags,
			Cigar:         cigar,
			Reverse:       reverse,
			MateStart:     mateStart,
			MateEnd:       mateEnd,
			MateRawStart:  mateRawStart,
			MateRawEnd:    mateRawEnd,
			MateRefID:     mateRefID,
			FragLen:       fragLen,
			SoftClipLeft:  leftSoft,
			SoftClipRight: rightSoft,
		})
	}
	return alns
}

func decodeCoverageBinsForTest(t *testing.T, payload []byte) []uint16 {
	t.Helper()
	if len(payload) < 13 || payload[0] != 1 {
		t.Fatalf("invalid coverage payload header")
	}
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	if len(payload) < 13+2*count {
		t.Fatalf("coverage payload too short")
	}
	bins := make([]uint16, count)
	off := 13
	for i := 0; i < count; i++ {
		bins[i] = binary.LittleEndian.Uint16(payload[off : off+2])
		off += 2
	}
	return bins
}

func decodeWireAckForTest(t *testing.T, payload []byte) string {
	t.Helper()
	if len(payload) < 2 {
		t.Fatalf("ack payload too short")
	}
	n := int(binary.LittleEndian.Uint16(payload[0:2]))
	if len(payload) < 2+n {
		t.Fatalf("ack payload truncated")
	}
	return string(payload[2 : 2+n])
}

func decodeStrandCoverageBinsForTest(t *testing.T, payload []byte) ([]uint16, []uint16) {
	t.Helper()
	if len(payload) < 13 || payload[0] != 4 {
		t.Fatalf("invalid strand coverage payload header")
	}
	count := int(binary.LittleEndian.Uint32(payload[9:13]))
	if len(payload) < 13+4*count {
		t.Fatalf("strand coverage payload too short")
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
	return forward, reverse
}
