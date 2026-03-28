package main

import (
	"os"
	"path/filepath"
	"slices"
	"testing"
)

func TestDetectInputKindByName(t *testing.T) {
	cases := []struct {
		name string
		want inputKind
	}{
		{"ref.fa", inputKindFASTA},
		{"ref.fasta.gz", inputKindFASTA},
		{"ann.gff3", inputKindGFF3},
		{"ann.gff.xz", inputKindGFF3},
		{"record.gbk", inputKindFlatFile},
		{"record.genbank.zst", inputKindFlatFile},
		{"notes.txt", inputKindUnknown},
	}
	for _, tc := range cases {
		if got := detectInputKindByName(tc.name); got != tc.want {
			t.Fatalf("detectInputKindByName(%q) = %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestDetectInputKindByContent(t *testing.T) {
	dir := t.TempDir()
	tests := []struct {
		name    string
		content string
		want    inputKind
	}{
		{"ref.txt", ">chr1\nACGT\n", inputKindFASTA},
		{"ann.txt", "chr1\tsrc\tgene\t1\t4\t.\t+\t.\tID=g1\n", inputKindGFF3},
		{"ann.txt", "##gff-version 3\nchr1\tsrc\tgene\t1\t4\t.\t+\t.\tID=g1\n", inputKindGFF3},
		{"flat.txt", "LOCUS       NC_000001\n", inputKindFlatFile},
		{"record.txt", "ID   SC10H5 standard; DNA; PRO; 4870 BP.\n", inputKindFlatFile},
		{"unknown.txt", "hello world\n", inputKindUnknown},
	}
	for _, tc := range tests {
		path := filepath.Join(dir, tc.name)
		if err := os.WriteFile(path, []byte(tc.content), 0o644); err != nil {
			t.Fatal(err)
		}
		got, err := detectInputKindByContent(path)
		if err != nil {
			t.Fatalf("detectInputKindByContent(%q) returned error: %v", tc.name, err)
		}
		if got != tc.want {
			t.Fatalf("detectInputKindByContent(%q) = %v, want %v", tc.name, got, tc.want)
		}
	}
}

func TestDetectInputKindPrefersContentOverMisleadingExtension(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "stupid.gbk")
	if err := os.WriteFile(path, []byte(">chr1\nACGT\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	got, err := detectInputKind(path)
	if err != nil {
		t.Fatalf("detectInputKind returned error: %v", err)
	}
	if got != inputKindFASTA {
		t.Fatalf("detectInputKind(%q) = %v, want %v", path, got, inputKindFASTA)
	}
}

func TestGatherInputFilesFiltersAndSorts(t *testing.T) {
	dir := t.TempDir()
	paths := map[string]string{
		"b.gff3":      "##gff-version 3\n",
		"a.fa":        ">chr1\nACGT\n",
		"c.txt":       "ignore me\n",
		"misnamed.gbk": ">chr2\nTGCA\n",
	}
	for name, content := range paths {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(content), 0o644); err != nil {
			t.Fatal(err)
		}
	}

	got, err := gatherInputFiles(dir)
	if err != nil {
		t.Fatalf("gatherInputFiles returned error: %v", err)
	}
	want := []string{
		filepath.Join(dir, "a.fa"),
		filepath.Join(dir, "b.gff3"),
		filepath.Join(dir, "misnamed.gbk"),
	}
	if !slices.Equal(got, want) {
		t.Fatalf("gatherInputFiles = %v, want %v", got, want)
	}
}

func TestParseFASTAUppercasesAndKeepsAmbiguousBases(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "ref.fa")
	content := ">chr1 description\nacgtnry-* 123\n>chr2\nNNnn\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	seqs, err := parseFASTA(path)
	if err != nil {
		t.Fatalf("parseFASTA returned error: %v", err)
	}
	if got := seqs["chr1"]; got != "ACGTNRY-*" {
		t.Fatalf("chr1 sequence = %q, want %q", got, "ACGTNRY-*")
	}
	if got := seqs["chr2"]; got != "NNNN" {
		t.Fatalf("chr2 sequence = %q, want %q", got, "NNNN")
	}
}

func TestParseFlatFileParsesSequenceAndQualifiers(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "record.gbk")
	content := "" +
		"LOCUS       NC_000001\n" +
		"FEATURES             Location/Qualifiers\n" +
		"     gene            2..8\n" +
		"                     /gene=\"foo\"\n" +
		"                     /note=\"bar baz\"\n" +
		"     CDS             complement(2..8)\n" +
		"                     /product=\"Thing\"\n" +
		"ORIGIN\n" +
		"        1 acgtacgt\n" +
		"//\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	seqs, feats, err := parseFlatFile(path)
	if err != nil {
		t.Fatalf("parseFlatFile returned error: %v", err)
	}
	if got := seqs["NC_000001"]; got != "ACGTACGT" {
		t.Fatalf("sequence = %q, want %q", got, "ACGTACGT")
	}
	chrFeats := feats["NC_000001"]
	if len(chrFeats) != 2 {
		t.Fatalf("expected 2 features, got %d", len(chrFeats))
	}
	if chrFeats[0].Type != "gene" || chrFeats[0].Start != 1 || chrFeats[0].End != 8 || chrFeats[0].Strand != '+' {
		t.Fatalf("unexpected gene feature: %+v", chrFeats[0])
	}
	if chrFeats[0].Attributes != "gene=foo;note=bar baz" {
		t.Fatalf("unexpected gene attributes: %q", chrFeats[0].Attributes)
	}
	if chrFeats[1].Type != "CDS" || chrFeats[1].Strand != '-' {
		t.Fatalf("unexpected cds feature: %+v", chrFeats[1])
	}
	if chrFeats[1].Attributes != "product=Thing" {
		t.Fatalf("unexpected cds attributes: %q", chrFeats[1].Attributes)
	}
}

func TestParseFlatFileParsesEMBLSequenceAndQualifiers(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "record.embl")
	content := "" +
		"ID   SC10H5 standard; DNA; PRO; 12 BP.\n" +
		"FH   Key             Location/Qualifiers\n" +
		"FH\n" +
		"FT   gene            2..8\n" +
		"FT                   /gene=\"foo\"\n" +
		"FT                   /note=\"bar baz\"\n" +
		"FT   CDS             complement(2..8)\n" +
		"FT                   /product=\"Thing\"\n" +
		"SQ   Sequence 12 BP; 3 A; 3 C; 3 G; 3 T; 0 other;\n" +
		"     acgtacgtacgt 12\n" +
		"//\n"
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		t.Fatal(err)
	}

	seqs, feats, err := parseFlatFile(path)
	if err != nil {
		t.Fatalf("parseFlatFile returned error: %v", err)
	}
	if got := seqs["SC10H5"]; got != "ACGTACGTACGT" {
		t.Fatalf("sequence = %q, want %q", got, "ACGTACGTACGT")
	}
	chrFeats := feats["SC10H5"]
	if len(chrFeats) != 2 {
		t.Fatalf("expected 2 features, got %d", len(chrFeats))
	}
	if chrFeats[0].Type != "gene" || chrFeats[0].Start != 1 || chrFeats[0].End != 8 || chrFeats[0].Strand != '+' {
		t.Fatalf("unexpected gene feature: %+v", chrFeats[0])
	}
	if chrFeats[0].Attributes != "gene=foo;note=bar baz" {
		t.Fatalf("unexpected gene attributes: %q", chrFeats[0].Attributes)
	}
	if chrFeats[1].Type != "CDS" || chrFeats[1].Strand != '-' {
		t.Fatalf("unexpected cds feature: %+v", chrFeats[1])
	}
	if chrFeats[1].Attributes != "product=Thing" {
		t.Fatalf("unexpected cds attributes: %q", chrFeats[1].Attributes)
	}
}

func TestParseFlatFileQualifierStripsQuotes(t *testing.T) {
	got, ok := parseFlatFileQualifier("                     /product=\"DNA-binding protein\"")
	if !ok {
		t.Fatal("expected qualifier to parse")
	}
	if got != "product=DNA-binding protein" {
		t.Fatalf("qualifier = %q", got)
	}
}

func TestParseFeatureLineFormats(t *testing.T) {
	ftType, ftLoc, ok := parseFeatureLine("FT   CDS             complement(123..456)")
	if !ok || ftType != "CDS" || ftLoc != "complement(123..456)" {
		t.Fatalf("unexpected EMBL feature parse: type=%q loc=%q ok=%v", ftType, ftLoc, ok)
	}

	gbType, gbLoc, ok := parseFeatureLine("     gene            123..456")
	if !ok || gbType != "gene" || gbLoc != "123..456" {
		t.Fatalf("unexpected GenBank feature parse: type=%q loc=%q ok=%v", gbType, gbLoc, ok)
	}
}

func TestParseLocationHandlesComplexLocations(t *testing.T) {
	start, end := parseLocation("join(complement(<5..10),20..>30)")
	if start != 4 || end != 30 {
		t.Fatalf("parseLocation returned (%d, %d), want (4, 30)", start, end)
	}
}
