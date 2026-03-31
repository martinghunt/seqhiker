package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestAddComparisonGenomeBuildsConcatenatedGenome(t *testing.T) {
	tmpDir := t.TempDir()
	fastaPath := filepath.Join(tmpDir, "ref.fa")
	gffPath := filepath.Join(tmpDir, "ref.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chrB\nAACCGG\n>chrA\nTTAA\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(gffPath, []byte("##gff-version 3\nchrA\tt\tgene\t2\t4\t.\t+\t.\tID=a1\nchrB\tt\tgene\t1\t2\t.\t-\t.\tID=b1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	info, err := e.AddComparisonGenome(tmpDir)
	if err != nil {
		t.Fatalf("AddComparisonGenome returned error: %v", err)
	}
	if info.SegmentCount != 2 {
		t.Fatalf("unexpected segment count: got %d want 2", info.SegmentCount)
	}
	if info.FeatureCount != 2 {
		t.Fatalf("unexpected feature count: got %d want 2", info.FeatureCount)
	}

	e.mu.RLock()
	defer e.mu.RUnlock()
	genome := e.comparisonGenomes[info.ID]
	if genome == nil {
		t.Fatal("comparison genome missing from engine state")
	}
	wantSeq := "TTAA" + strings.Repeat("N", comparisonConcatGapBP) + "AACCGG"
	if genome.Sequence != wantSeq {
		t.Fatalf("unexpected concatenated sequence: got %q want %q", genome.Sequence, wantSeq)
	}
	if len(genome.Features) != 2 {
		t.Fatalf("unexpected feature count in genome: got %d want 2", len(genome.Features))
	}
	if genome.Features[0].Start != 1 || genome.Features[0].End != 4 {
		t.Fatalf("unexpected chrA feature coords: got %d-%d want 1-4", genome.Features[0].Start, genome.Features[0].End)
	}
	chrBStart := 4 + comparisonConcatGapBP
	if genome.Features[1].Start != chrBStart || genome.Features[1].End != chrBStart+2 {
		t.Fatalf("unexpected chrB feature coords: got %d-%d want %d-%d", genome.Features[1].Start, genome.Features[1].End, chrBStart, chrBStart+2)
	}
}

func TestComparisonPairsFollowGenomeOrder(t *testing.T) {
	e := NewEngine()
	for i := 0; i < 3; i++ {
		tmpDir := t.TempDir()
		fastaPath := filepath.Join(tmpDir, "ref.fa")
		if err := os.WriteFile(fastaPath, []byte(">chr1\nACGT\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		if _, err := e.AddComparisonGenome(fastaPath); err != nil {
			t.Fatalf("AddComparisonGenome returned error: %v", err)
		}
	}

	pairs := e.ListComparisonPairs()
	if len(pairs) != 2 {
		t.Fatalf("unexpected pair count: got %d want 2", len(pairs))
	}
	if pairs[0].TopGenomeID == pairs[0].BottomGenomeID {
		t.Fatal("pair references the same genome on both sides")
	}
	if pairs[0].BottomGenomeID != pairs[1].TopGenomeID {
		t.Fatalf("pairs do not follow neighboring order: %+v", pairs)
	}
	if pairs[0].Status != comparisonStatusReady || pairs[1].Status != comparisonStatusReady {
		t.Fatalf("unexpected pair status values: %+v", pairs)
	}
}

func TestComparisonBuildsForwardBlocks(t *testing.T) {
	core := uniqueishDNA(400)
	top := &comparisonGenome{
		ID:       1,
		Name:     "top",
		Length:   400,
		Sequence: core,
	}
	bottom := &comparisonGenome{
		ID:       2,
		Name:     "bottom",
		Length:   440,
		Sequence: strings.Repeat("N", 40) + core,
	}
	blocks := buildComparisonBlocks(top, bottom)
	if len(blocks) == 0 {
		t.Fatal("expected at least one forward comparison block")
	}
	found := false
	for _, block := range blocks {
		if !block.Summary.SameStrand {
			continue
		}
		if int(block.Summary.QueryEnd-block.Summary.QueryStart) < 300 {
			continue
		}
		if int(block.Summary.TargetStart) > 60 {
			continue
		}
		if int(block.Summary.TargetEnd) < 340 {
			continue
		}
		found = true
		break
	}
	if !found {
		t.Fatalf("no suitable forward block found: %+v", blocks)
	}
}

func TestComparisonBuildsReverseBlocks(t *testing.T) {
	topSeq := uniqueishDNA(320)
	bottomSeq := reverseComplementString(topSeq)
	top := &comparisonGenome{
		ID:       1,
		Name:     "top",
		Length:   len(topSeq),
		Sequence: topSeq,
	}
	bottom := &comparisonGenome{
		ID:       2,
		Name:     "bottom",
		Length:   len(bottomSeq),
		Sequence: bottomSeq,
	}
	blocks := buildComparisonBlocks(top, bottom)
	if len(blocks) == 0 {
		t.Fatal("expected at least one reverse comparison block")
	}
	found := false
	for _, block := range blocks {
		if block.Summary.SameStrand {
			continue
		}
		if int(block.Summary.QueryEnd-block.Summary.QueryStart) >= 200 {
			found = true
			break
		}
	}
	if !found {
		t.Fatalf("no reverse block found: %+v", blocks)
	}
}

func TestComparisonRefinementCapturesSNPAndIndel(t *testing.T) {
	query := &comparisonGenome{
		ID:       1,
		Name:     "q",
		Length:   len("AACCGGTT"),
		Sequence: "AACCGGTT",
	}
	target := &comparisonGenome{
		ID:       2,
		Name:     "t",
		Length:   len("AATCAGGTT"),
		Sequence: "AATCAGGTT",
	}
	block := comparisonBlockDetail{
		Summary: ComparisonBlock{
			QueryStart:  0,
			QueryEnd:    uint32(len(query.Sequence)),
			TargetStart: 0,
			TargetEnd:   uint32(len(target.Sequence)),
			SameStrand:  true,
		},
	}
	refineComparisonBlock(query, target, &block)
	if block.Summary.PercentIdentX100 == 0 {
		t.Fatal("expected refined percent identity to be set")
	}
	if len(block.Variants) < 2 {
		t.Fatalf("expected SNP and indel variants, got %+v", block.Variants)
	}
	foundSNP := false
	foundIns := false
	for _, v := range block.Variants {
		if v.Kind == 'X' {
			foundSNP = true
		}
		if v.Kind == 'D' || v.Kind == 'I' {
			foundIns = true
		}
	}
	if !foundSNP || !foundIns {
		t.Fatalf("missing SNP/indel in variants: %+v", block.Variants)
	}
}

func TestComparisonRefinementCapturesReverseOrientationVariants(t *testing.T) {
	querySeq := "AACCGGTT"
	targetSeq := reverseComplementString("AATCAGGTT")
	query := &comparisonGenome{ID: 1, Name: "q", Length: len(querySeq), Sequence: querySeq}
	target := &comparisonGenome{ID: 2, Name: "t", Length: len(targetSeq), Sequence: targetSeq}
	block := comparisonBlockDetail{
		Summary: ComparisonBlock{
			QueryStart:  0,
			QueryEnd:    uint32(len(querySeq)),
			TargetStart: 0,
			TargetEnd:   uint32(len(targetSeq)),
			SameStrand:  false,
		},
	}
	refineComparisonBlock(query, target, &block)
	if block.Summary.PercentIdentX100 == 0 {
		t.Fatal("expected reverse refined percent identity to be set")
	}
	if len(block.Variants) == 0 {
		t.Fatal("expected reverse-orientation variants")
	}
}

func TestComparisonRepeatsProduceMultipleBlocks(t *testing.T) {
	anchors := []comparisonAnchor{
		{QPos: 0, TPos: 0, TTrans: 0},
		{QPos: 80, TPos: 80, TTrans: 80},
		{QPos: 160, TPos: 160, TTrans: 160},
		{QPos: 240, TPos: 240, TTrans: 240},
		{QPos: 0, TPos: 900, TTrans: 900},
		{QPos: 80, TPos: 980, TTrans: 980},
		{QPos: 160, TPos: 1060, TTrans: 1060},
		{QPos: 240, TPos: 1140, TTrans: 1140},
	}
	blocks := buildBlocksFromAnchors(anchors, true)
	if len(blocks) < 2 {
		t.Fatalf("expected multiple blocks for repeated target, got %+v", blocks)
	}
	foundFirst := false
	foundSecond := false
	for _, block := range blocks {
		if !block.Summary.SameStrand {
			continue
		}
		if int(block.Summary.QueryEnd-block.Summary.QueryStart) < 250 {
			continue
		}
		if int(block.Summary.TargetStart) < 50 {
			foundFirst = true
		}
		if int(block.Summary.TargetStart) > 700 {
			foundSecond = true
		}
	}
	if !foundFirst || !foundSecond {
		t.Fatalf("expected blocks for both repeat copies, got %+v", blocks)
	}
}

func TestComparisonHighlyRepetitiveSeedsAreFiltered(t *testing.T) {
	querySeq := strings.Repeat("A", 800)
	targetSeq := strings.Repeat("A", 1200)
	query := &comparisonGenome{
		ID:       1,
		Name:     "q",
		Length:   len(querySeq),
		Sequence: querySeq,
	}
	target := &comparisonGenome{
		ID:       2,
		Name:     "t",
		Length:   len(targetSeq),
		Sequence: targetSeq,
	}
	blocks := buildComparisonBlocks(query, target)
	if len(blocks) != 0 {
		t.Fatalf("expected repetitive seeds to be filtered out, got %+v", blocks)
	}
}

func TestComparisonSessionRoundTrip(t *testing.T) {
	query := &comparisonGenome{
		ID:       1,
		Name:     "q",
		Path:     "/tmp/q.fa",
		Length:   len("AACCGGTT"),
		Sequence: "AACCGGTT",
		Segments: []comparisonSegment{{Name: "chr1", Start: 0, End: 8, FeatureCount: 1}},
		Features: []Feature{{SeqName: "chr1", Source: "src", Type: "gene", Start: 1, End: 7, Strand: '+', Attributes: "ID=g1"}},
	}
	target := &comparisonGenome{
		ID:       2,
		Name:     "t",
		Path:     "/tmp/t.fa",
		Length:   len("AATCAGGTT"),
		Sequence: "AATCAGGTT",
		Segments: []comparisonSegment{{Name: "chr1", Start: 0, End: 9, FeatureCount: 1}},
		Features: []Feature{{SeqName: "chr1", Source: "src", Type: "gene", Start: 2, End: 8, Strand: '-', Attributes: "ID=g2"}},
	}
	block := comparisonBlockDetail{
		Summary: ComparisonBlock{
			QueryStart:       0,
			QueryEnd:         8,
			TargetStart:      0,
			TargetEnd:        9,
			PercentIdentX100: 7777,
			SameStrand:       true,
		},
		Variants: []comparisonVariant{
			{Kind: 'X', QueryPos: 2, TargetPos: 2},
			{Kind: 'I', QueryPos: 4, TargetPos: 4, AltBases: "NN"},
		},
	}

	e := NewEngine()
	e.comparisonGenomes[1] = query
	e.comparisonGenomes[2] = target
	e.comparisonGenomeOrder = []uint16{1, 2}
	e.comparisonPairs[1] = &comparisonPair{
		ID:             1,
		TopGenomeID:    1,
		BottomGenomeID: 2,
		Status:         comparisonStatusReady,
		Blocks:         []comparisonBlockDetail{block},
	}
	e.comparisonPairOrder = []uint16{1}
	e.nextComparisonGenomeID = 3
	e.nextComparisonPairID = 2

	path := filepath.Join(t.TempDir(), "saved.seqhikercmp")
	if err := e.SaveComparisonSession(path); err != nil {
		t.Fatalf("SaveComparisonSession returned error: %v", err)
	}

	ok, err := isComparisonSessionFile(path)
	if err != nil {
		t.Fatalf("isComparisonSessionFile returned error: %v", err)
	}
	if !ok {
		t.Fatal("expected saved file to be detected as a comparison session")
	}

	loaded := NewEngine()
	if err := loaded.LoadComparisonSession(path); err != nil {
		t.Fatalf("LoadComparisonSession returned error: %v", err)
	}

	genomes := loaded.ListComparisonGenomes()
	if len(genomes) != 2 {
		t.Fatalf("unexpected genome count after load: got %d want 2", len(genomes))
	}
	pairs := loaded.ListComparisonPairs()
	if len(pairs) != 1 {
		t.Fatalf("unexpected pair count after load: got %d want 1", len(pairs))
	}
	blocks, err := loaded.GetComparisonBlocks(1)
	if err != nil {
		t.Fatalf("GetComparisonBlocks returned error: %v", err)
	}
	if len(blocks) != 1 {
		t.Fatalf("unexpected block count after load: got %d want 1", len(blocks))
	}
	if blocks[0].PercentIdentX100 != 7777 {
		t.Fatalf("unexpected percent identity after load: got %d want 7777", blocks[0].PercentIdentX100)
	}

	loaded.mu.RLock()
	defer loaded.mu.RUnlock()
	if len(loaded.comparisonGenomes[1].Features) != 1 {
		t.Fatalf("expected features to round-trip, got %+v", loaded.comparisonGenomes[1].Features)
	}
	if len(loaded.comparisonPairs[1].Blocks[0].Variants) != 2 {
		t.Fatalf("expected variants to round-trip, got %+v", loaded.comparisonPairs[1].Blocks[0].Variants)
	}
}

func TestGenerateComparisonTestData(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	if len(paths) != 3 {
		t.Fatalf("unexpected generated genome count: got %d want 3", len(paths))
	}
	for _, path := range paths {
		info, err := e.AddComparisonGenome(path)
		if err != nil {
			t.Fatalf("AddComparisonGenome(%q) returned error: %v", path, err)
		}
		if info.SegmentCount != 3 {
			t.Fatalf("expected generated comparison genome to contain 3 contigs: %+v", info)
		}
		if info.FeatureCount == 0 {
			t.Fatalf("expected generated comparison genome to contain features: %+v", info)
		}
	}
	pairs := e.ListComparisonPairs()
	if len(pairs) != 2 {
		t.Fatalf("unexpected comparison pair count after generated load: got %d want 2", len(pairs))
	}
	foundMultiple := false
	foundReverse := false
	for _, pair := range pairs {
		blocks, err := e.GetComparisonBlocks(pair.ID)
		if err != nil {
			t.Fatalf("GetComparisonBlocks(%d) returned error: %v", pair.ID, err)
		}
		if len(blocks) >= 3 {
			foundMultiple = true
		}
		for _, block := range blocks {
			if !block.SameStrand {
				foundReverse = true
				break
			}
		}
	}
	if !foundMultiple {
		t.Fatalf("expected generated comparison test data to yield multiple blocks across a pair, got %+v", pairs)
	}
	if !foundReverse {
		t.Fatalf("expected generated comparison test data to yield at least one reverse-strand block")
	}
}

func uniqueishDNA(n int) string {
	bases := [4]byte{'A', 'C', 'G', 'T'}
	out := make([]byte, n)
	state := uint32(17)
	for i := 0; i < n; i++ {
		state = state*1664525 + 1013904223
		out[i] = bases[(state>>24)&3]
	}
	return string(out)
}
