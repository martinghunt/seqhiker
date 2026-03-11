package main

import (
	"os"
	"path/filepath"
	"testing"
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
