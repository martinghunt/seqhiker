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

func TestAddComparisonGenomeFilesCombinesSequenceAndAnnotation(t *testing.T) {
	tmpDir := t.TempDir()
	fastaPath := filepath.Join(tmpDir, "ref.fa")
	gffPath := filepath.Join(tmpDir, "ref.gff3")
	if err := os.WriteFile(fastaPath, []byte(">chr1\nAACCGGTT\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(gffPath, []byte("##gff-version 3\nchr1\tt\tgene\t2\t7\t.\t+\t.\tID=g1;Name=gene1\n"), 0o644); err != nil {
		t.Fatal(err)
	}

	e := NewEngine()
	info, err := e.AddComparisonGenomeFiles([]string{fastaPath, gffPath})
	if err != nil {
		t.Fatalf("AddComparisonGenomeFiles returned error: %v", err)
	}
	if info.FeatureCount != 1 {
		t.Fatalf("unexpected feature count: got %d want 1", info.FeatureCount)
	}

	e.mu.RLock()
	defer e.mu.RUnlock()
	genome := e.comparisonGenomes[info.ID]
	if genome == nil {
		t.Fatal("comparison genome missing from engine state")
	}
	if len(genome.Features) != 1 {
		t.Fatalf("unexpected feature count in genome: got %d want 1", len(genome.Features))
	}
	if genome.Features[0].Start != 1 || genome.Features[0].End != 7 {
		t.Fatalf("unexpected feature coords: got %d-%d want 1-7", genome.Features[0].Start, genome.Features[0].End)
	}
}

func TestSetComparisonGenomeOrientationRebuildsSequenceAndBlocks(t *testing.T) {
	e := NewEngine()
	seq := uniqueishDNA(320)

	makeGenome := func(dir string, name string) string {
		path := filepath.Join(dir, name)
		if err := os.WriteFile(path, []byte(">chr1\n"+seq+"\n"), 0o644); err != nil {
			t.Fatal(err)
		}
		return path
	}

	pathA := makeGenome(t.TempDir(), "a.fa")
	pathB := makeGenome(t.TempDir(), "b.fa")
	infoA, err := e.AddComparisonGenome(pathA)
	if err != nil {
		t.Fatalf("AddComparisonGenome(a) returned error: %v", err)
	}
	infoB, err := e.AddComparisonGenome(pathB)
	if err != nil {
		t.Fatalf("AddComparisonGenome(b) returned error: %v", err)
	}

	blocksBefore, err := e.GetComparisonBlocksByGenomes(infoA.ID, infoB.ID)
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(before) returned error: %v", err)
	}
	foundForward := false
	for _, block := range blocksBefore {
		if block.SameStrand {
			foundForward = true
			break
		}
	}
	if !foundForward {
		t.Fatalf("expected forward blocks before orientation change, got %+v", blocksBefore)
	}

	if err := e.SetComparisonGenomeOrientation(infoA.ID, true); err != nil {
		t.Fatalf("SetComparisonGenomeOrientation returned error: %v", err)
	}
	genomes := e.ListComparisonGenomes()
	if len(genomes) < 1 || len(genomes[0].Segments) != 1 || !genomes[0].Segments[0].Reversed {
		t.Fatalf("expected reversed comparison segment metadata, got %+v", genomes)
	}
	slicePayload, err := e.GetComparisonReferenceSlice(infoA.ID, 0, 20)
	if err != nil {
		t.Fatalf("GetComparisonReferenceSlice returned error: %v", err)
	}
	start, end, got := decodeReferenceSliceForTest(t, slicePayload)
	want := reverseComplementString(seq)[:20]
	if start != 0 || end != 20 || got != want {
		t.Fatalf("unexpected reversed comparison slice: start=%d end=%d got=%q want=%q", start, end, got, want)
	}

	blocksAfter, err := e.GetComparisonBlocksByGenomes(infoA.ID, infoB.ID)
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(after) returned error: %v", err)
	}
	foundReverse := false
	for _, block := range blocksAfter {
		if !block.SameStrand {
			foundReverse = true
			break
		}
	}
	if !foundReverse {
		t.Fatalf("expected reverse-strand blocks after orientation change, got %+v", blocksAfter)
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
		if !block.SameStrand {
			continue
		}
		if int(block.QueryEnd-block.QueryStart) < 300 {
			continue
		}
		if int(block.TargetStart) > 60 {
			continue
		}
		if int(block.TargetEnd) < 340 {
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
		if block.SameStrand {
			continue
		}
		if int(block.QueryEnd-block.QueryStart) >= 200 {
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

func TestComparisonBlockDetailHandlesLongBlockByStitchingAnchors(t *testing.T) {
	querySeq := uniqueishDNA(10000)
	targetSeq := querySeq[:3200] + "ACGTACGTACGTACGT" + querySeq[3200:7600] + "TTGGAACC" + querySeq[7600:]
	query := &comparisonGenome{ID: 1, Name: "q", Length: len(querySeq), Sequence: querySeq}
	target := &comparisonGenome{ID: 2, Name: "t", Length: len(targetSeq), Sequence: targetSeq}
	detail, ok := buildComparisonBlockDetail(query, target, ComparisonBlock{
		QueryStart:  0,
		QueryEnd:    uint32(len(querySeq)),
		TargetStart: 0,
		TargetEnd:   uint32(len(targetSeq)),
		SameStrand:  true,
	})
	if !ok {
		t.Fatal("expected long block detail to be built by stitched anchors")
	}
	if len(detail.Ops) == 0 {
		t.Fatal("expected long block detail ops")
	}
	if detail.Summary.QueryStart != 0 || detail.Summary.QueryEnd != uint32(len(querySeq)) {
		t.Fatalf("unexpected query span: %+v", detail.Summary)
	}
	if detail.Summary.TargetStart != 0 || detail.Summary.TargetEnd != uint32(len(targetSeq)) {
		t.Fatalf("unexpected target span: %+v", detail.Summary)
	}
	if detail.Summary.PercentIdentX100 < 9000 {
		t.Fatalf("expected high-identity stitched detail, got %+v", detail.Summary)
	}
}

func TestComparisonDetailHandlesOneSidedAnchorGap(t *testing.T) {
	query := &comparisonGenome{ID: 1, Name: "q", Length: 80, Sequence: uniqueishDNA(80)}
	target := &comparisonGenome{ID: 2, Name: "t", Length: 80, Sequence: query.Sequence}
	chain := comparisonRefinedChain{
		Summary: ComparisonBlock{
			QueryStart:  0,
			QueryEnd:    55,
			TargetStart: 0,
			TargetEnd:   54,
			SameStrand:  true,
		},
		OrientedStart: 0,
		OrientedEnd:   54,
		Anchors: []comparisonAnchor{
			{QPos: 0, TPos: 0, TTrans: 0},
			{QPos: 20, TPos: 20, TTrans: 20},
			{QPos: 40, TPos: 39, TTrans: 39},
		},
	}
	detail, ok := buildComparisonDetailFromRefinedChainWithMode(query, target, chain, true)
	if !ok {
		t.Fatal("expected permissive chain detail to handle one-sided anchor gap")
	}
	if len(detail.Ops) == 0 {
		t.Fatal("expected ops for one-sided anchor gap detail")
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
		if !block.SameStrand {
			continue
		}
		if int(block.QueryEnd-block.QueryStart) < 250 {
			continue
		}
		if int(block.TargetStart) < 50 {
			foundFirst = true
		}
		if int(block.TargetStart) > 700 {
			foundSecond = true
		}
	}
	if !foundFirst || !foundSecond {
		t.Fatalf("expected blocks for both repeat copies, got %+v", blocks)
	}
}

func TestComparisonLargeUnanchoredGapSplitsBlocks(t *testing.T) {
	anchors := []comparisonAnchor{
		{QPos: 0, TPos: 0, TTrans: 0},
		{QPos: 80, TPos: 80, TTrans: 80},
		{QPos: 160, TPos: 160, TTrans: 160},
		{QPos: 14000, TPos: 14000, TTrans: 14000},
		{QPos: 14080, TPos: 14080, TTrans: 14080},
		{QPos: 14160, TPos: 14160, TTrans: 14160},
	}
	chains := buildRefinedChainsFromAnchors(nil, nil, anchors, true)
	if len(chains) != 2 {
		t.Fatalf("expected large unanchored gap to split into 2 chains, got %+v", chains)
	}
	if int(chains[0].Summary.QueryEnd) >= 1000 || int(chains[1].Summary.QueryStart) <= 1000 {
		t.Fatalf("unexpected split positions: %+v", chains)
	}
}

func TestComparisonGapAboveRefineLimitSplitsBlocks(t *testing.T) {
	anchors := []comparisonAnchor{
		{QPos: 0, TPos: 0, TTrans: 0},
		{QPos: 80, TPos: 80, TTrans: 80},
		{QPos: 160, TPos: 160, TTrans: 160},
		{QPos: 8400, TPos: 8400, TTrans: 8400},
		{QPos: 8480, TPos: 8480, TTrans: 8480},
		{QPos: 8560, TPos: 8560, TTrans: 8560},
	}
	chains := buildRefinedChainsFromAnchors(nil, nil, anchors, true)
	if len(chains) != 2 {
		t.Fatalf("expected gap above refine limit to split into 2 chains, got %+v", chains)
	}
}

func TestComparisonLargeGapImbalanceSplitsBlocks(t *testing.T) {
	anchors := []comparisonAnchor{
		{QPos: 0, TPos: 0, TTrans: 0},
		{QPos: 80, TPos: 80, TTrans: 80},
		{QPos: 160, TPos: 160, TTrans: 160},
		{QPos: 1800, TPos: 240, TTrans: 240},
		{QPos: 1880, TPos: 320, TTrans: 320},
		{QPos: 1960, TPos: 400, TTrans: 400},
	}
	chains := buildRefinedChainsFromAnchors(nil, nil, anchors, true)
	if len(chains) != 2 {
		t.Fatalf("expected large internal gap imbalance to split into 2 chains, got %+v", chains)
	}
}

func TestComparisonSmallGapChainsMerge(t *testing.T) {
	chains := []comparisonRefinedChain{
		{
			Summary: ComparisonBlock{
				QueryStart: 500, QueryEnd: 675,
				TargetStart: 3500, TargetEnd: 3675,
				SameStrand: true,
			},
			OrientedStart: 3500,
			OrientedEnd:   3675,
			Anchors: []comparisonAnchor{
				{QPos: 500, TPos: 3500, TTrans: 3500},
				{QPos: 580, TPos: 3580, TTrans: 3580},
				{QPos: 660, TPos: 3660, TTrans: 3660},
			},
		},
		{
			Summary: ComparisonBlock{
				QueryStart: 687, QueryEnd: 862,
				TargetStart: 3687, TargetEnd: 3862,
				SameStrand: true,
			},
			OrientedStart: 3687,
			OrientedEnd:   3862,
			Anchors: []comparisonAnchor{
				{QPos: 687, TPos: 3687, TTrans: 3687},
				{QPos: 767, TPos: 3767, TTrans: 3767},
				{QPos: 847, TPos: 3847, TTrans: 3847},
			},
		},
	}
	merged := mergeAdjacentRefinedChains(nil, nil, chains)
	if len(merged) != 1 {
		t.Fatalf("expected nearby chains to merge into 1 block, got %+v", merged)
	}
	if merged[0].Summary.QueryStart != 500 || merged[0].Summary.QueryEnd < 862 {
		t.Fatalf("unexpected merged block span: %+v", merged[0].Summary)
	}
}

func TestComparisonLargeInternalIndelPreventsChainMerge(t *testing.T) {
	chains := []comparisonRefinedChain{
		{
			Summary: ComparisonBlock{
				QueryStart: 500, QueryEnd: 675,
				TargetStart: 3500, TargetEnd: 3675,
				SameStrand: true,
			},
			OrientedStart: 3500,
			OrientedEnd:   3675,
			Anchors: []comparisonAnchor{
				{QPos: 500, TPos: 3500, TTrans: 3500},
				{QPos: 580, TPos: 3580, TTrans: 3580},
				{QPos: 660, TPos: 3660, TTrans: 3660},
			},
		},
		{
			Summary: ComparisonBlock{
				QueryStart: 687, QueryEnd: 862,
				TargetStart: 3855, TargetEnd: 4030,
				SameStrand: true,
			},
			OrientedStart: 3855,
			OrientedEnd:   4030,
			Anchors: []comparisonAnchor{
				{QPos: 687, TPos: 3855, TTrans: 3855},
				{QPos: 767, TPos: 3935, TTrans: 3935},
				{QPos: 847, TPos: 4015, TTrans: 4015},
			},
		},
	}
	merged := mergeAdjacentRefinedChains(nil, nil, chains)
	if len(merged) != 2 {
		t.Fatalf("expected large internal indel to keep chains separate, got %+v", merged)
	}
}

func TestGeneratedComparisonDataDoesNotBridgeLargeInternalInsertion(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	ids := make([]uint16, 0, len(paths))
	for _, path := range paths {
		info, err := e.AddComparisonGenome(path)
		if err != nil {
			t.Fatalf("AddComparisonGenome(%q) returned error: %v", path, err)
		}
		ids = append(ids, info.ID)
	}
	if len(ids) != 3 {
		t.Fatalf("expected 3 genomes, got %d", len(ids))
	}
	blocks, err := e.GetComparisonBlocksByGenomes(ids[0], ids[2])
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes returned error: %v", err)
	}
	for _, block := range blocks {
		if int(block.QueryStart) == 4906 && int(block.QueryEnd) == 10121 && int(block.TargetStart) == 1506 && int(block.TargetEnd) == 5121 {
			t.Fatalf("unexpected bridged beta/uniq1 block still present: %+v", block)
		}
	}
}

func TestComparisonSmallOverlapChainsMerge(t *testing.T) {
	chains := []comparisonRefinedChain{
		{
			Summary: ComparisonBlock{
				QueryStart: 500, QueryEnd: 675,
				TargetStart: 3500, TargetEnd: 3675,
				SameStrand: true,
			},
			OrientedStart: 3500,
			OrientedEnd:   3675,
			Anchors: []comparisonAnchor{
				{QPos: 500, TPos: 3500, TTrans: 3500},
				{QPos: 580, TPos: 3580, TTrans: 3580},
				{QPos: 660, TPos: 3660, TTrans: 3660},
			},
		},
		{
			Summary: ComparisonBlock{
				QueryStart: 671, QueryEnd: 846,
				TargetStart: 3671, TargetEnd: 3846,
				SameStrand: true,
			},
			OrientedStart: 3671,
			OrientedEnd:   3846,
			Anchors: []comparisonAnchor{
				{QPos: 671, TPos: 3671, TTrans: 3671},
				{QPos: 751, TPos: 3751, TTrans: 3751},
				{QPos: 831, TPos: 3831, TTrans: 3831},
			},
		},
	}
	merged := mergeAdjacentRefinedChains(nil, nil, chains)
	if len(merged) != 1 {
		t.Fatalf("expected overlapping chains to merge into 1 block, got %+v", merged)
	}
	if merged[0].Summary.QueryStart != 500 || merged[0].Summary.QueryEnd < 846 {
		t.Fatalf("unexpected merged block span: %+v", merged[0].Summary)
	}
}

func TestComparisonChainsDoNotMergeAcrossSegmentBoundaries(t *testing.T) {
	query := &comparisonGenome{
		Segments: []comparisonSegment{
			{Start: 0, End: 675},
			{Start: 680, End: 1200},
		},
	}
	target := &comparisonGenome{
		Segments: []comparisonSegment{
			{Start: 0, End: 3675},
			{Start: 3680, End: 4200},
		},
	}
	chains := []comparisonRefinedChain{
		{
			Summary: ComparisonBlock{
				QueryStart: 500, QueryEnd: 675,
				TargetStart: 3500, TargetEnd: 3675,
				SameStrand: true,
			},
			OrientedStart: 3500,
			OrientedEnd:   3675,
			Anchors: []comparisonAnchor{
				{QPos: 500, TPos: 3500, TTrans: 3500},
				{QPos: 580, TPos: 3580, TTrans: 3580},
				{QPos: 660, TPos: 3660, TTrans: 3660},
			},
		},
		{
			Summary: ComparisonBlock{
				QueryStart: 687, QueryEnd: 862,
				TargetStart: 3687, TargetEnd: 3862,
				SameStrand: true,
			},
			OrientedStart: 3687,
			OrientedEnd:   3862,
			Anchors: []comparisonAnchor{
				{QPos: 687, TPos: 3687, TTrans: 3687},
				{QPos: 767, TPos: 3767, TTrans: 3767},
				{QPos: 847, TPos: 3847, TTrans: 3847},
			},
		},
	}
	merged := mergeAdjacentRefinedChains(query, target, chains)
	if len(merged) != 2 {
		t.Fatalf("expected segment boundary to prevent merge, got %+v", merged)
	}
}

func TestComparisonTargetSegmentChecksUseDisplayCoordinates(t *testing.T) {
	target := &comparisonGenome{
		Segments: []comparisonSegment{
			{Start: 0, End: 100},
			{Start: 150, End: 250},
		},
	}
	if !comparisonAnchorInSameSegment(target, comparisonAnchor{TPos: 10, TTrans: 180}, comparisonAnchor{TPos: 80, TTrans: 20}, false) {
		t.Fatal("expected target segment comparison to use display coordinates")
	}
	chain := comparisonRefinedChain{
		Summary: ComparisonBlock{
			QueryStart: 10, QueryEnd: 80,
			TargetStart: 10, TargetEnd: 80,
			SameStrand: false,
		},
		OrientedStart: 20,
		OrientedEnd:   180,
	}
	if !comparisonChainWithinSingleSegments(nil, target, chain) {
		t.Fatal("expected target chain boundary checks to use display coordinates")
	}
}

func TestComparisonReverseOrientationStaysWithinReversedSegment(t *testing.T) {
	makeDNA := func(seed uint32, n int) string {
		bases := [4]byte{'A', 'C', 'G', 'T'}
		out := make([]byte, n)
		state := seed
		for i := 0; i < n; i++ {
			state = state*1664525 + 1013904223
			out[i] = bases[(state>>24)&3]
		}
		return string(out)
	}
	segA := makeDNA(17, 320)
	segB := makeDNA(12345, 320)
	makeGenome := func(id uint16, reverseFirst bool) *comparisonGenome {
		genome := &comparisonGenome{
			ID:   id,
			Name: "g",
			Segments: []comparisonSegment{
				{Name: "a", RawSequence: segA, Reversed: reverseFirst},
				{Name: "b", RawSequence: segB},
			},
		}
		genome.rebuildDerived()
		return genome
	}

	query := makeGenome(1, false)
	target := makeGenome(2, true)
	segBStart := target.Segments[1].Start
	blocks := buildComparisonBlocks(query, target)
	if len(blocks) == 0 {
		t.Fatal("expected comparison blocks for mixed-orientation genome")
	}

	bestReverseLen := 0
	bestSecondForwardLen := 0
	for _, block := range blocks {
		span := int(block.QueryEnd - block.QueryStart)
		if !block.SameStrand && int(block.QueryStart) < segBStart && int(block.TargetStart) < segBStart {
			if span > bestReverseLen {
				bestReverseLen = span
			}
		}
		if block.SameStrand && int(block.QueryStart) >= segBStart && int(block.TargetStart) >= segBStart {
			if span > bestSecondForwardLen {
				bestSecondForwardLen = span
			}
		}
		if !block.SameStrand && (int(block.QueryStart) >= segBStart || int(block.TargetStart) >= segBStart) && span >= 200 {
			t.Fatalf("unexpected large reverse block outside reversed first segment: %+v", block)
		}
	}
	if bestReverseLen < 200 {
		t.Fatalf("expected large reverse block in first segment, got %d from %+v", bestReverseLen, blocks)
	}
	if bestSecondForwardLen < 200 {
		t.Fatalf("expected large forward block in second segment, got %d from %+v", bestSecondForwardLen, blocks)
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

func TestComparisonDropsVeryLowIdentityBlockDetail(t *testing.T) {
	query := &comparisonGenome{ID: 1, Name: "q", Length: len("AAAAAAAAAAAAAAAA"), Sequence: "AAAAAAAAAAAAAAAA"}
	target := &comparisonGenome{ID: 2, Name: "t", Length: len("TTTTTTTTTTTTTTTT"), Sequence: "TTTTTTTTTTTTTTTT"}
	block := ComparisonBlock{
		QueryStart: 0, QueryEnd: 16,
		TargetStart: 0, TargetEnd: 16,
		SameStrand: true,
	}
	if _, ok := buildComparisonBlockDetail(query, target, block); ok {
		t.Fatal("expected sub-50% identity block detail to be rejected")
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
	block := ComparisonBlock{
		QueryStart:       0,
		QueryEnd:         8,
		TargetStart:      0,
		TargetEnd:        9,
		PercentIdentX100: 7777,
		SameStrand:       true,
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
		CanonicalBlocks: []comparisonCanonicalBlock{{
			QuerySegment:     0,
			QueryStart:       int(block.QueryStart),
			QueryEnd:         int(block.QueryEnd),
			TargetSegment:    0,
			TargetStart:      int(block.TargetStart),
			TargetEnd:        int(block.TargetEnd),
			PercentIdentX100: block.PercentIdentX100,
			SameStrand:       block.SameStrand,
		}},
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
	if loaded.comparisonPairs[1].CanonicalBlocks[0].PercentIdentX100 != 7777 {
		t.Fatalf("expected canonical block summary to round-trip, got %+v", loaded.comparisonPairs[1].CanonicalBlocks[0])
	}
}

func TestComparisonBlocksAreSymmetricAcrossDirection(t *testing.T) {
	e := NewEngine()
	alpha := &comparisonGenome{ID: 1, Name: "a", Length: len("AAAACCCCGGGGTTTTAAAACCCC"), Sequence: "AAAACCCCGGGGTTTTAAAACCCC"}
	beta := &comparisonGenome{ID: 2, Name: "b", Length: len("AAAACCCCGGGGTTTTAAAAGCCC"), Sequence: "AAAACCCCGGGGTTTTAAAAGCCC"}
	e.comparisonGenomes[1] = alpha
	e.comparisonGenomes[2] = beta
	e.comparisonGenomeOrder = []uint16{1, 2, 1}
	e.rebuildComparisonPairsLocked()

	forward, _, _, err := e.getOrBuildComparisonPairLocked(1, 2)
	if err != nil {
		t.Fatalf("forward getOrBuildComparisonPairLocked returned error: %v", err)
	}
	reverse, _, _, err := e.getOrBuildComparisonPairLocked(2, 1)
	if err != nil {
		t.Fatalf("reverse getOrBuildComparisonPairLocked returned error: %v", err)
	}
	if len(forward) != len(reverse) {
		t.Fatalf("expected same block count forward/reverse, got %d vs %d", len(forward), len(reverse))
	}
	for i := range forward {
		if reverse[i] != swappedComparisonBlock(forward[i]) {
			t.Fatalf("reverse block %d not symmetric: forward=%+v reverse=%+v", i, forward[i], reverse[i])
		}
	}
}

func TestComparisonSessionPreservesSegmentOrientation(t *testing.T) {
	e := NewEngine()
	dir := t.TempDir()
	fastaPath := filepath.Join(dir, "ref.fa")
	seq := uniqueishDNA(320)
	if err := os.WriteFile(fastaPath, []byte(">chr1\n"+seq+"\n"), 0o644); err != nil {
		t.Fatal(err)
	}
	info, err := e.AddComparisonGenome(fastaPath)
	if err != nil {
		t.Fatalf("AddComparisonGenome returned error: %v", err)
	}
	if err := e.SetComparisonGenomeOrientation(info.ID, true); err != nil {
		t.Fatalf("SetComparisonGenomeOrientation returned error: %v", err)
	}

	path := filepath.Join(dir, "oriented.seqhikercmp")
	if err := e.SaveComparisonSession(path); err != nil {
		t.Fatalf("SaveComparisonSession returned error: %v", err)
	}

	loaded := NewEngine()
	if err := loaded.LoadComparisonSession(path); err != nil {
		t.Fatalf("LoadComparisonSession returned error: %v", err)
	}
	genomes := loaded.ListComparisonGenomes()
	if len(genomes) != 1 || len(genomes[0].Segments) != 1 || !genomes[0].Segments[0].Reversed {
		t.Fatalf("expected reversed segment after reload, got %+v", genomes)
	}
	slicePayload, err := loaded.GetComparisonReferenceSlice(genomes[0].ID, 0, 16)
	if err != nil {
		t.Fatalf("GetComparisonReferenceSlice returned error: %v", err)
	}
	_, _, got := decodeReferenceSliceForTest(t, slicePayload)
	want := reverseComplementString(seq)[:16]
	if got != want {
		t.Fatalf("unexpected reloaded oriented slice: got %q want %q", got, want)
	}
}

func TestComparisonIdenticalGenomesYieldPerfectIdentityBlock(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	if len(paths) == 0 {
		t.Fatal("expected generated comparison test data paths")
	}
	info1, err := e.AddComparisonGenome(paths[0])
	if err != nil {
		t.Fatalf("AddComparisonGenome(first) returned error: %v", err)
	}
	info2, err := e.AddComparisonGenome(paths[0])
	if err != nil {
		t.Fatalf("AddComparisonGenome(second) returned error: %v", err)
	}
	blocks, err := e.GetComparisonBlocksByGenomes(info1.ID, info2.ID)
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes returned error: %v", err)
	}
	if len(blocks) == 0 {
		t.Fatal("expected at least one block for identical loaded genomes")
	}
	foundPerfect := false
	for _, block := range blocks {
		if block.PercentIdentX100 == 10000 {
			foundPerfect = true
			break
		}
	}
	if !foundPerfect {
		t.Fatalf("expected a 100%% identity block for identical genomes, got %+v", blocks)
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

func TestGeneratedComparisonDataGetBlocksByGenomes(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	for _, path := range paths {
		if _, err := e.AddComparisonGenome(path); err != nil {
			t.Fatalf("AddComparisonGenome(%q) returned error: %v", path, err)
		}
	}
	pairs := e.ListComparisonPairs()
	if len(pairs) == 0 {
		t.Fatal("expected generated test data to create comparison pairs")
	}
	for _, pair := range pairs {
		blocksByPair, err := e.GetComparisonBlocks(pair.ID)
		if err != nil {
			t.Fatalf("GetComparisonBlocks(%d) returned error: %v", pair.ID, err)
		}
		blocksByGenomes, err := e.GetComparisonBlocksByGenomes(pair.TopGenomeID, pair.BottomGenomeID)
		if err != nil {
			t.Fatalf("GetComparisonBlocksByGenomes(%d,%d) returned error: %v", pair.TopGenomeID, pair.BottomGenomeID, err)
		}
		if len(blocksByPair) == 0 {
			t.Fatalf("expected pair %d to have blocks by pair id", pair.ID)
		}
		if len(blocksByGenomes) == 0 {
			t.Fatalf("expected pair %d genomes %d/%d to have blocks by genomes", pair.ID, pair.TopGenomeID, pair.BottomGenomeID)
		}
	}
}

func TestGetComparisonBlocksByGenomesWorksForReorderedNonAdjacentGenomes(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	ids := make([]uint16, 0, len(paths))
	for _, path := range paths {
		info, err := e.AddComparisonGenome(path)
		if err != nil {
			t.Fatalf("AddComparisonGenome(%q) returned error: %v", path, err)
		}
		ids = append(ids, info.ID)
	}
	if len(ids) != 3 {
		t.Fatalf("expected 3 genomes, got %d", len(ids))
	}
	blocks, err := e.GetComparisonBlocksByGenomes(ids[0], ids[2])
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(non-adjacent) returned error: %v", err)
	}
	if len(blocks) == 0 {
		t.Fatal("expected non-adjacent genome query to return blocks")
	}
}

func TestComparisonMonomerDimerBlocksDoNotDependOnLoadOrder(t *testing.T) {
	dir := t.TempDir()
	monomerSeq := comparisonDeterministicTestDNA(6707)
	dimerSeq := monomerSeq + monomerSeq
	monomerPath := filepath.Join(dir, "monomer.fa")
	dimerPath := filepath.Join(dir, "dimer.fa")
	if err := os.WriteFile(monomerPath, []byte(">monomer\n"+monomerSeq+"\n"), 0o644); err != nil {
		t.Fatalf("WriteFile(monomer) returned error: %v", err)
	}
	if err := os.WriteFile(dimerPath, []byte(">dimer\n"+dimerSeq+"\n"), 0o644); err != nil {
		t.Fatalf("WriteFile(dimer) returned error: %v", err)
	}

	e := NewEngine()
	monomerInfo, err := e.AddComparisonGenome(monomerPath)
	if err != nil {
		t.Fatalf("AddComparisonGenome(monomer) returned error: %v", err)
	}
	dimerInfo, err := e.AddComparisonGenome(dimerPath)
	if err != nil {
		t.Fatalf("AddComparisonGenome(dimer) returned error: %v", err)
	}
	blocks, err := e.GetComparisonBlocksByGenomes(monomerInfo.ID, dimerInfo.ID)
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(monomer,dimer) returned error: %v", err)
	}
	if len(blocks) == 0 {
		t.Fatal("expected monomer->dimer comparison to yield blocks")
	}

	e = NewEngine()
	dimerInfo, err = e.AddComparisonGenome(dimerPath)
	if err != nil {
		t.Fatalf("AddComparisonGenome(dimer first) returned error: %v", err)
	}
	monomerInfo, err = e.AddComparisonGenome(monomerPath)
	if err != nil {
		t.Fatalf("AddComparisonGenome(monomer second) returned error: %v", err)
	}
	blocks, err = e.GetComparisonBlocksByGenomes(dimerInfo.ID, monomerInfo.ID)
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(dimer,monomer) returned error: %v", err)
	}
	if len(blocks) == 0 {
		t.Fatal("expected dimer->monomer comparison to yield blocks")
	}
}

func comparisonDeterministicTestDNA(length int) string {
	var b strings.Builder
	b.Grow(length)
	state := uint32(1)
	bases := [4]byte{'A', 'C', 'G', 'T'}
	for b.Len() < length {
		state = state*1664525 + 1013904223
		b.WriteByte(bases[(state>>30)&3])
		if b.Len()%97 == 0 {
			b.WriteString("GATTACAGGCT")
		}
	}
	seq := b.String()
	return seq[:length]
}

func TestComparisonGeneratedReverseChrB2SegmentSummary(t *testing.T) {
	e := NewEngine()
	paths, err := e.GenerateComparisonTestData(t.TempDir())
	if err != nil {
		t.Fatalf("GenerateComparisonTestData returned error: %v", err)
	}
	ids := make([]uint16, 0, len(paths))
	for _, path := range paths {
		info, err := e.AddComparisonGenome(path)
		if err != nil {
			t.Fatalf("AddComparisonGenome(%q) returned error: %v", path, err)
		}
		ids = append(ids, info.ID)
	}
	if len(ids) < 2 {
		t.Fatalf("expected at least two genomes, got %d", len(ids))
	}
	genomes := e.ListComparisonGenomes()
	segmentsByID := make(map[uint16][]ComparisonSegmentInfo, len(genomes))
	var betaID uint16
	var chrB2Start uint32
	for _, genome := range genomes {
		segmentsByID[genome.ID] = genome.Segments
		if genome.Name != "cmp_beta" {
			continue
		}
		betaID = genome.ID
		for _, segment := range genome.Segments {
			if segment.Name == "chrB2" {
				chrB2Start = segment.Start
				break
			}
		}
	}
	if betaID == 0 {
		t.Fatalf("could not resolve cmp_beta genome: %+v", genomes)
	}
	type pairSummary struct {
		count     int
		maxSpan   int
		totalSpan int
	}
	segmentNameAt := func(genomeID uint16, start uint32) string {
		for _, segment := range segmentsByID[genomeID] {
			if start >= segment.Start && start < segment.End {
				return segment.Name
			}
		}
		return "?"
	}
	summarize := func(blocks []ComparisonBlock) map[string]pairSummary {
		summary := map[string]pairSummary{}
		for _, block := range blocks {
			qName := segmentNameAt(ids[0], block.QueryStart)
			tName := segmentNameAt(ids[1], block.TargetStart)
			key := qName + " -> " + tName + " strand=" + map[bool]string{true: "+", false: "-"}[block.SameStrand]
			item := summary[key]
			item.count++
			span := max(int(block.QueryEnd-block.QueryStart), int(block.TargetEnd-block.TargetStart))
			item.totalSpan += span
			if span > item.maxSpan {
				item.maxSpan = span
			}
			summary[key] = item
		}
		return summary
	}
	beforeBlocks, err := e.GetComparisonBlocksByGenomes(ids[0], ids[1])
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes(before) returned error: %v", err)
	}
	beforeSummary := summarize(beforeBlocks)
	if err := e.SetComparisonSegmentOrientation(betaID, chrB2Start, true); err != nil {
		t.Fatalf("SetComparisonSegmentOrientation returned error: %v", err)
	}
	blocks, err := e.GetComparisonBlocksByGenomes(ids[0], ids[1])
	if err != nil {
		t.Fatalf("GetComparisonBlocksByGenomes returned error: %v", err)
	}
	afterSummary := summarize(blocks)
	if beforeSummary["chrA2 -> chrB2 strand=+"].totalSpan < 3000 {
		t.Fatalf("expected substantial forward chrA2 -> chrB2 coverage before reverse, got %+v", beforeSummary)
	}
	if afterSummary["chrA2 -> chrB2 strand=-"].totalSpan != beforeSummary["chrA2 -> chrB2 strand=+"].totalSpan {
		t.Fatalf("expected chrA2 -> chrB2 total span to be preserved across reverse, before=%+v after=%+v", beforeSummary, afterSummary)
	}
	if beforeSummary["chrA3 -> chrB3 strand=+"] != afterSummary["chrA3 -> chrB3 strand=+"] {
		t.Fatalf("expected unrelated chrA3 -> chrB3 blocks to remain unchanged, before=%+v after=%+v", beforeSummary["chrA3 -> chrB3 strand=+"], afterSummary["chrA3 -> chrB3 strand=+"])
	}
	if beforeSummary["chrA1 -> chrB1 strand=+"] != afterSummary["chrA1 -> chrB1 strand=+"] {
		t.Fatalf("expected chrA1 -> chrB1 forward blocks to remain unchanged, before=%+v after=%+v", beforeSummary["chrA1 -> chrB1 strand=+"], afterSummary["chrA1 -> chrB1 strand=+"])
	}
	if beforeSummary["chrA1 -> chrB1 strand=-"] != afterSummary["chrA1 -> chrB1 strand=-"] {
		t.Fatalf("expected chrA1 -> chrB1 reverse blocks to remain unchanged, before=%+v after=%+v", beforeSummary["chrA1 -> chrB1 strand=-"], afterSummary["chrA1 -> chrB1 strand=-"])
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
