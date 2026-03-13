package main

import (
	"encoding/binary"
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
