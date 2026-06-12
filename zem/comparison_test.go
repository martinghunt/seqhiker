package main

import (
	"encoding/binary"
	"fmt"
	"os"
	"path/filepath"
	"slices"
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

func TestComparisonProgressTrackerReportsAndClears(t *testing.T) {
	e := NewEngine()
	query := &comparisonGenome{
		ID: 7,
		Segments: []comparisonSegment{
			{Name: "q1", RawSequence: "AAAA"},
			{Name: "q2", RawSequence: "CCCC"},
		},
	}
	target := &comparisonGenome{
		ID:       3,
		Segments: []comparisonSegment{{Name: "t1", RawSequence: "GGGGGG"}},
	}

	tracker := e.beginComparisonProgress(query, target)
	if tracker == nil {
		t.Fatal("expected progress tracker")
	}
	progress := e.GetComparisonProgress(query.ID, target.ID)
	if !progress.Active || progress.ProgressX100 != 0 || progress.Message != "Preparing comparison" {
		t.Fatalf("unexpected initial progress: %+v", progress)
	}

	tracker.updateCurrent("Finding seed matches", 24, 0.25)
	progress = e.GetComparisonProgress(query.ID, target.ID)
	if !progress.Active || progress.ProgressX100 != 1250 || progress.Message != "Finding seed matches" {
		t.Fatalf("unexpected within-pair progress: %+v", progress)
	}

	tracker.complete("Comparing q1 vs t1", 24)
	progress = e.GetComparisonProgress(target.ID, query.ID)
	if !progress.Active || progress.ProgressX100 != 5000 || progress.Message != "Comparing q1 vs t1" {
		t.Fatalf("unexpected halfway progress: %+v", progress)
	}

	tracker.finish()
	if progress = e.GetComparisonProgress(query.ID, target.ID); progress.Active || progress.ProgressX100 != 0 || progress.Message != "" {
		t.Fatalf("expected finished progress to be cleared, got %+v", progress)
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

func TestBuildComparisonBlocksFromSketchesMatchesDirectBlocks(t *testing.T) {
	tests := []struct {
		name      string
		querySeq  string
		targetSeq string
	}{
		{
			name:      "forward",
			querySeq:  uniqueishDNA(1200),
			targetSeq: strings.Repeat("N", 37) + uniqueishDNA(1200) + strings.Repeat("N", 23),
		},
		{
			name:      "reverse",
			querySeq:  uniqueishDNA(1200),
			targetSeq: strings.Repeat("N", 29) + reverseComplementString(uniqueishDNA(1200)) + strings.Repeat("N", 31),
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			query := &comparisonGenome{
				ID:       1,
				Name:     "q",
				Length:   len(tt.querySeq),
				Sequence: tt.querySeq,
			}
			target := &comparisonGenome{
				ID:       2,
				Name:     "t",
				Length:   len(tt.targetSeq),
				Sequence: tt.targetSeq,
			}
			direct := buildComparisonBlocks(query, target)
			if len(direct) == 0 {
				t.Fatal("expected direct comparison blocks")
			}

			querySegmented := &comparisonGenome{
				ID:   query.ID,
				Name: query.Name,
				Segments: []comparisonSegment{{
					Name:        "q1",
					RawSequence: tt.querySeq,
				}},
			}
			querySegmented.rebuildDerived()
			targetSegmented := &comparisonGenome{
				ID:   target.ID,
				Name: target.Name,
				Segments: []comparisonSegment{{
					Name:        "t1",
					RawSequence: tt.targetSeq,
				}},
			}
			targetSegmented.rebuildDerived()
			querySketches := buildComparisonSegmentSketches(querySegmented, false)
			targetSketches := buildComparisonSegmentSketches(targetSegmented, true)
			cached := buildComparisonBlocksFromSketches(querySketches[0], targetSketches[0])

			if !slices.Equal(direct, cached) {
				t.Fatalf("cached sketch blocks differ from direct blocks:\ndirect=%+v\ncached=%+v", direct, cached)
			}
		})
	}
}

func TestComparisonBlocksUseRefinedIdentityForDivergentBlock(t *testing.T) {
	querySeq := uniqueishDNA(1800)
	mutated := []byte(querySeq)
	for _, idx := range []int{211, 503, 947, 1319, 1591} {
		switch mutated[idx] {
		case 'A':
			mutated[idx] = 'C'
		case 'C':
			mutated[idx] = 'G'
		case 'G':
			mutated[idx] = 'T'
		default:
			mutated[idx] = 'A'
		}
	}
	targetSeq := string(mutated[:700]) + "ACGTAC" + string(mutated[700:])
	query := &comparisonGenome{ID: 1, Name: "q", Length: len(querySeq), Sequence: querySeq}
	target := &comparisonGenome{ID: 2, Name: "t", Length: len(targetSeq), Sequence: targetSeq}

	blocks := buildComparisonBlocks(query, target)
	if len(blocks) == 0 {
		t.Fatal("expected comparison blocks")
	}
	var best ComparisonBlock
	for _, block := range blocks {
		if int(block.QueryEnd-block.QueryStart) > int(best.QueryEnd-best.QueryStart) {
			best = block
		}
	}
	if best.PercentIdentX100 == 10000 {
		t.Fatalf("expected divergent block identity below 100%%, got %+v", best)
	}
	if best.PercentIdentX100 < 9900 {
		t.Fatalf("expected high refined identity for small edits, got %+v", best)
	}
	detail, ok := buildComparisonBlockDetail(query, target, best)
	if !ok {
		t.Fatalf("expected block detail for %+v", best)
	}
	if absInt(int(detail.Summary.PercentIdentX100)-int(best.PercentIdentX100)) > 10 {
		t.Fatalf("block identity differs from detail: block=%d detail=%d", best.PercentIdentX100, detail.Summary.PercentIdentX100)
	}
}

func TestCanonicalSelfComparisonKeepsRepeatMatches(t *testing.T) {
	repeat := comparisonDeterministicTestDNA(520)
	left := uniqueishDNA(650)
	middle := comparisonDeterministicTestDNA(760)
	right := uniqueishDNA(690)
	seq := left + repeat + middle + repeat + right
	genome := &comparisonGenome{
		ID:   1,
		Name: "self",
		Segments: []comparisonSegment{{
			Name:        "chr1",
			RawSequence: seq,
		}},
	}
	genome.rebuildDerived()

	blocks := buildCanonicalComparisonBlocks(genome, genome)
	if len(blocks) < 2 {
		t.Fatalf("expected exact self block plus repeat blocks, got %+v", blocks)
	}
	foundExact := false
	foundRepeat := false
	for _, block := range blocks {
		if block.QuerySegment == 0 && block.TargetSegment == 0 && block.QueryStart == 0 && block.TargetStart == 0 &&
			block.QueryEnd == len(seq) && block.TargetEnd == len(seq) && block.PercentIdentX100 == 10000 {
			foundExact = true
			continue
		}
		if block.QuerySegment != 0 || block.TargetSegment != 0 || !block.SameStrand || block.PercentIdentX100 != 10000 {
			continue
		}
		if block.QueryStart == block.TargetStart && block.QueryEnd == block.TargetEnd {
			t.Fatalf("unexpected exact diagonal subblock survived alongside full self block: %+v", block)
		}
		if block.QueryEnd-block.QueryStart >= 300 && block.TargetEnd-block.TargetStart >= 300 {
			foundRepeat = true
		}
	}
	if !foundExact {
		t.Fatalf("missing full exact self block: %+v", blocks)
	}
	if !foundRepeat {
		t.Fatalf("missing off-diagonal repeat block: %+v", blocks)
	}
}

func TestCanonicalSelfComparisonDropsTrivialOverlappingSelfBlocks(t *testing.T) {
	unit := comparisonDeterministicTestDNA(560)
	core := uniqueishDNA(60000)
	seq := uniqueishDNA(1200) + unit + unit + core + comparisonDeterministicTestDNA(1200)
	genome := &comparisonGenome{
		ID:   1,
		Name: "self",
		Segments: []comparisonSegment{{
			Name:        "chr1",
			RawSequence: seq,
		}},
	}
	genome.rebuildDerived()

	artifactQueryStart := 1200 + len(unit)
	artifactQueryEnd := artifactQueryStart + len(core)
	artifact := comparisonCanonicalBlock{
		QuerySegment:     0,
		QueryStart:       artifactQueryStart,
		QueryEnd:         artifactQueryEnd,
		TargetSegment:    0,
		TargetStart:      1200,
		TargetEnd:        artifactQueryEnd,
		PercentIdentX100: 9972,
		SameStrand:       true,
	}
	if !comparisonCanonicalBlockIsTrivialSelfOverlap(genome, genome, artifact) {
		t.Fatalf("expected shifted same-locus self overlap to be treated as trivial: %+v", artifact)
	}
	nonOverlappingRepeat := comparisonCanonicalBlock{
		QuerySegment:     0,
		QueryStart:       1200,
		QueryEnd:         1760,
		TargetSegment:    0,
		TargetStart:      1760,
		TargetEnd:        2320,
		PercentIdentX100: 10000,
		SameStrand:       true,
	}
	if comparisonCanonicalBlockIsTrivialSelfOverlap(genome, genome, nonOverlappingRepeat) {
		t.Fatalf("non-overlapping repeat should remain visible: %+v", nonOverlappingRepeat)
	}

	blocks := buildCanonicalComparisonBlocks(genome, genome)
	if len(blocks) == 0 {
		t.Fatal("expected self-comparison blocks")
	}
	for _, block := range blocks {
		if block.QuerySegment != 0 || block.TargetSegment != 0 || !block.SameStrand {
			continue
		}
		if block.QueryStart == 0 && block.TargetStart == 0 && block.QueryEnd == len(seq) && block.TargetEnd == len(seq) {
			continue
		}
		qLen := block.QueryEnd - block.QueryStart
		tLen := block.TargetEnd - block.TargetStart
		overlap := intervalOverlapInt(block.QueryStart, block.QueryEnd, block.TargetStart, block.TargetEnd)
		if overlap*10000 >= min(qLen, tLen)*comparisonRedundantOverlapX100 {
			t.Fatalf("unexpected trivial overlapping self block: %+v", block)
		}
	}
}

func BenchmarkBuildCanonicalComparisonBlocksMultiSegment(b *testing.B) {
	makeSegment := func(i int) string {
		seq := comparisonDeterministicTestDNA(4200 + i*137)
		return seq[i*137:]
	}
	mutate := func(seq string) string {
		out := []byte(seq)
		for i := 811; i < len(out); i += 997 {
			switch out[i] {
			case 'A':
				out[i] = 'C'
			case 'C':
				out[i] = 'G'
			case 'G':
				out[i] = 'T'
			default:
				out[i] = 'A'
			}
		}
		return string(out)
	}
	query := &comparisonGenome{
		ID:   1,
		Name: "q",
	}
	target := &comparisonGenome{
		ID:   2,
		Name: "t",
	}
	for i := 0; i < 4; i++ {
		seq := makeSegment(i)
		query.Segments = append(query.Segments, comparisonSegment{
			Name:        fmt.Sprintf("q%d", i+1),
			RawSequence: seq,
		})
		target.Segments = append(target.Segments, comparisonSegment{
			Name:        fmt.Sprintf("t%d", i+1),
			RawSequence: mutate(seq),
		})
	}
	query.rebuildDerived()
	target.rebuildDerived()
	if blocks := buildCanonicalComparisonBlocks(query, target); len(blocks) == 0 {
		b.Fatal("expected comparison blocks")
	}

	b.ReportAllocs()
	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		if blocks := buildCanonicalComparisonBlocks(query, target); len(blocks) == 0 {
			b.Fatal("expected comparison blocks")
		}
	}
}

func TestBandedAffineAlignHandlesLongNarrowBand(t *testing.T) {
	query := comparisonDeterministicTestDNA(2500)
	target := query[:1200] + "ACGTAC" + query[1200:]
	aln, ok := bandedAffineAlign(query, target, absInt(len(query)-len(target))+comparisonRefineBandPad)
	if !ok {
		t.Fatal("expected long narrow-band alignment to succeed")
	}
	if len(aln.Ops) != len(target) {
		t.Fatalf("unexpected ops length: got %d want %d", len(aln.Ops), len(target))
	}
	if !strings.Contains(string(aln.Ops), "DDDDDD") {
		t.Fatalf("expected inserted target bases to be represented in ops, got %q", aln.Ops)
	}
	if got := aln.percentIdentityX100(); got < 9900 {
		t.Fatalf("unexpectedly low identity: got %d", got)
	}
}

func BenchmarkBandedAffineAlignNarrowBand(b *testing.B) {
	query := comparisonDeterministicTestDNA(4096)
	target := query[:2048] + "ACGTACGT" + query[2048:]
	band := absInt(len(query)-len(target)) + comparisonRefineBandPad
	b.ReportAllocs()
	for i := 0; i < b.N; i++ {
		if _, ok := bandedAffineAlign(query, target, band); !ok {
			b.Fatal("expected alignment")
		}
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

func TestComparisonDetailTrimsTerminalGapOverhangs(t *testing.T) {
	core := uniqueishDNA(1200)
	extra := "AACCGGTTAACCGGTTAACCGGTT"
	tests := []struct {
		name       string
		querySeq   string
		targetSeq  string
		wantQStart uint32
		wantQEnd   uint32
		wantTStart uint32
		wantTEnd   uint32
	}{
		{
			name:       "target leading overhang",
			querySeq:   core,
			targetSeq:  extra + core,
			wantQEnd:   uint32(len(core)),
			wantTStart: uint32(len(extra)),
			wantTEnd:   uint32(len(extra) + len(core)),
		},
		{
			name:      "target trailing overhang",
			querySeq:  core,
			targetSeq: core + extra,
			wantQEnd:  uint32(len(core)),
			wantTEnd:  uint32(len(core)),
		},
		{
			name:       "query leading overhang",
			querySeq:   extra + core,
			targetSeq:  core,
			wantQStart: uint32(len(extra)),
			wantQEnd:   uint32(len(extra) + len(core)),
			wantTEnd:   uint32(len(core)),
		},
		{
			name:      "query trailing overhang",
			querySeq:  core + extra,
			targetSeq: core,
			wantQEnd:  uint32(len(core)),
			wantTEnd:  uint32(len(core)),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			query := &comparisonGenome{ID: 1, Name: "q", Length: len(tt.querySeq), Sequence: tt.querySeq}
			target := &comparisonGenome{ID: 2, Name: "t", Length: len(tt.targetSeq), Sequence: tt.targetSeq}
			detail, ok := buildComparisonBlockDetail(query, target, ComparisonBlock{
				QueryStart:  0,
				QueryEnd:    uint32(len(tt.querySeq)),
				TargetStart: 0,
				TargetEnd:   uint32(len(tt.targetSeq)),
				SameStrand:  true,
			})
			if !ok {
				t.Fatal("expected detail")
			}
			if detail.Summary.QueryStart != tt.wantQStart || detail.Summary.QueryEnd != tt.wantQEnd ||
				detail.Summary.TargetStart != tt.wantTStart || detail.Summary.TargetEnd != tt.wantTEnd {
				t.Fatalf("unexpected trimmed summary: got %+v", detail.Summary)
			}
			if detail.Summary.PercentIdentX100 != 10000 {
				t.Fatalf("expected exact identity after trimming terminal gaps, got %+v", detail.Summary)
			}
			if detail.Ops != strings.Repeat("M", len(core)) {
				t.Fatalf("unexpected ops after trimming: len=%d ops=%q", len(detail.Ops), detail.Ops)
			}
		})
	}
}

func TestComparisonRefinedChainTrimsAnchorOverhangs(t *testing.T) {
	core := uniqueishDNA(360)
	tests := []struct {
		name         string
		queryPrefix  string
		targetPrefix string
		queryTail    string
		targetTail   string
	}{
		{name: "query leading tail", queryPrefix: "A"},
		{name: "target leading tail", targetPrefix: "T"},
		{name: "query trailing tail", queryTail: "A"},
		{name: "target trailing tail", targetTail: "T"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			querySeq := tt.queryPrefix + core + tt.queryTail
			targetSeq := tt.targetPrefix + core + tt.targetTail
			query := &comparisonGenome{ID: 1, Name: "q", Length: len(querySeq), Sequence: querySeq}
			target := &comparisonGenome{ID: 2, Name: "t", Length: len(targetSeq), Sequence: targetSeq}
			lastAnchor := len(core) - comparisonMinimizerK
			queryAnchorOffset := len(tt.queryPrefix)
			targetAnchorOffset := len(tt.targetPrefix)
			chain := comparisonRefinedChain{
				Summary: ComparisonBlock{
					QueryStart:  0,
					QueryEnd:    uint32(len(querySeq)),
					TargetStart: 0,
					TargetEnd:   uint32(len(targetSeq)),
					SameStrand:  true,
				},
				OrientedStart: 0,
				OrientedEnd:   len(targetSeq),
				Anchors: []comparisonAnchor{
					{QPos: queryAnchorOffset, TPos: targetAnchorOffset, TTrans: targetAnchorOffset},
					{QPos: queryAnchorOffset + 80, TPos: targetAnchorOffset + 80, TTrans: targetAnchorOffset + 80},
					{QPos: queryAnchorOffset + 160, TPos: targetAnchorOffset + 160, TTrans: targetAnchorOffset + 160},
					{QPos: queryAnchorOffset + 240, TPos: targetAnchorOffset + 240, TTrans: targetAnchorOffset + 240},
					{QPos: queryAnchorOffset + lastAnchor, TPos: targetAnchorOffset + lastAnchor, TTrans: targetAnchorOffset + lastAnchor},
				},
			}
			if _, ok := comparisonRefinedChainAlignmentCells(chain, false); !ok {
				t.Fatal("expected anchor overhang to be refinement-feasible")
			}
			summary, ok := buildComparisonSummaryFromRefinedChain(query, target, chain)
			if !ok {
				t.Fatal("expected anchor overhang to be trimmed from refined summary")
			}
			if summary.QueryStart != uint32(queryAnchorOffset) || summary.QueryEnd != uint32(queryAnchorOffset+len(core)) ||
				summary.TargetStart != uint32(targetAnchorOffset) || summary.TargetEnd != uint32(targetAnchorOffset+len(core)) {
				t.Fatalf("unexpected trimmed summary: got %+v", summary)
			}
			if summary.PercentIdentX100 != 10000 {
				t.Fatalf("expected exact identity after trimming anchor overhang, got %+v", summary)
			}
		})
	}
}

func TestComparisonDetailTrimsReverseTerminalGapOverhangs(t *testing.T) {
	core := uniqueishDNA(1200)
	extra := "AACCGGTTAACCGGTTAACCGGTT"
	tests := []struct {
		name       string
		targetSeq  string
		wantTStart uint32
		wantTEnd   uint32
	}{
		{
			name:      "target high-coordinate overhang",
			targetSeq: reverseComplementString(core) + extra,
			wantTEnd:  uint32(len(core)),
		},
		{
			name:       "target low-coordinate overhang",
			targetSeq:  extra + reverseComplementString(core),
			wantTStart: uint32(len(extra)),
			wantTEnd:   uint32(len(extra) + len(core)),
		},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			query := &comparisonGenome{ID: 1, Name: "q", Length: len(core), Sequence: core}
			target := &comparisonGenome{ID: 2, Name: "t", Length: len(tt.targetSeq), Sequence: tt.targetSeq}
			detail, ok := buildComparisonBlockDetail(query, target, ComparisonBlock{
				QueryStart:  0,
				QueryEnd:    uint32(len(core)),
				TargetStart: 0,
				TargetEnd:   uint32(len(tt.targetSeq)),
				SameStrand:  false,
			})
			if !ok {
				t.Fatal("expected detail")
			}
			if detail.Summary.QueryStart != 0 || detail.Summary.QueryEnd != uint32(len(core)) ||
				detail.Summary.TargetStart != tt.wantTStart || detail.Summary.TargetEnd != tt.wantTEnd {
				t.Fatalf("unexpected trimmed reverse summary: got %+v", detail.Summary)
			}
			if detail.Summary.PercentIdentX100 != 10000 {
				t.Fatalf("expected exact reverse identity after trimming terminal gaps, got %+v", detail.Summary)
			}
			if detail.Ops != strings.Repeat("M", len(core)) {
				t.Fatalf("unexpected reverse ops after trimming: len=%d ops=%q", len(detail.Ops), detail.Ops)
			}
		})
	}
}

func TestExactLargeComparisonDetailOmitsHugeOps(t *testing.T) {
	seq := comparisonDeterministicTestDNA(comparisonMaxDetailOps + 1)
	query := &comparisonGenome{ID: 1, Name: "q", Length: len(seq), Sequence: seq}
	target := &comparisonGenome{ID: 2, Name: "t", Length: len(seq), Sequence: seq}
	detail, ok := buildComparisonBlockDetail(query, target, ComparisonBlock{
		QueryStart:  0,
		QueryEnd:    uint32(len(seq)),
		TargetStart: 0,
		TargetEnd:   uint32(len(seq)),
		SameStrand:  true,
	})
	if !ok {
		t.Fatal("expected exact large detail request to succeed")
	}
	if detail.Summary.PercentIdentX100 != 10000 {
		t.Fatalf("unexpected identity for exact large detail: %+v", detail.Summary)
	}
	if detail.Ops != "" {
		t.Fatalf("expected huge exact detail to omit ops, got length %d", len(detail.Ops))
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

func TestComparisonRefinesLargeNarrowBandedAnchorGap(t *testing.T) {
	prefix := uniqueishDNA(95)
	suffix := uniqueishDNA(95)
	queryGap := strings.Repeat("A", comparisonRefineGapMaxSpan+808)
	targetGap := strings.Repeat("A", comparisonRefineGapMaxSpan+658)
	querySeq := prefix + queryGap + suffix
	targetSeq := prefix + targetGap + suffix
	query := &comparisonGenome{Length: len(querySeq), Sequence: querySeq}
	target := &comparisonGenome{Length: len(targetSeq), Sequence: targetSeq}
	rightQuery := len(prefix) + len(queryGap)
	rightTarget := len(prefix) + len(targetGap)
	chain := comparisonRefinedChain{
		Summary: ComparisonBlock{
			QueryStart:  0,
			QueryEnd:    uint32(len(querySeq)),
			TargetStart: 0,
			TargetEnd:   uint32(len(targetSeq)),
			SameStrand:  true,
		},
		OrientedStart: 0,
		OrientedEnd:   len(targetSeq),
		Anchors: []comparisonAnchor{
			{QPos: 0, TPos: 0, TTrans: 0},
			{QPos: 80, TPos: 80, TTrans: 80},
			{QPos: rightQuery, TPos: rightTarget, TTrans: rightTarget},
			{QPos: rightQuery + 80, TPos: rightTarget + 80, TTrans: rightTarget + 80},
		},
	}

	if max(len(queryGap), len(targetGap)) <= comparisonRefineGapMaxSpan {
		t.Fatal("test gap must exceed the span-only refinement limit")
	}
	if cells, ok := comparisonRefinedChainAlignmentCells(chain, false); !ok || cells > comparisonRefineGapCellBudget {
		t.Fatalf("expected narrow large gap to be within the cell budget, ok=%v cells=%d", ok, cells)
	}
	summary, ok := buildComparisonSummaryFromRefinedChain(query, target, chain)
	if !ok {
		t.Fatal("expected large narrow-banded gap to refine")
	}
	if summary.QueryStart != 0 || int(summary.QueryEnd) != len(querySeq) || summary.TargetStart != 0 || int(summary.TargetEnd) != len(targetSeq) {
		t.Fatalf("unexpected refined summary: %+v", summary)
	}
	if summary.PercentIdentX100 < 9800 {
		t.Fatalf("expected high identity across narrow large gap, got %.2f", float64(summary.PercentIdentX100)/100)
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

func TestBuildSeedIndexStoresSampledRepetitivePositions(t *testing.T) {
	const repeatHash = uint64(42)
	seeds := make([]minimizerSeed, 0, 1003)
	allRepeatPositions := make([]int, 1000)
	for i := range allRepeatPositions {
		pos := i * 7
		allRepeatPositions[i] = pos
		seeds = append(seeds, minimizerSeed{Hash: repeatHash, Pos: pos})
	}
	seeds = append(seeds,
		minimizerSeed{Hash: 7, Pos: 11},
		minimizerSeed{Hash: 7, Pos: 23},
		minimizerSeed{Hash: 7, Pos: 37},
	)

	index := buildSeedIndex(seeds)
	wantRepeatPositions := sampleComparisonSeedPositions(allRepeatPositions)
	gotRepeatPositions := index[repeatHash].slice()
	if !slices.Equal(gotRepeatPositions, wantRepeatPositions) {
		t.Fatalf("sampled repeat positions differ:\ngot  %v\nwant %v", gotRepeatPositions, wantRepeatPositions)
	}
	if len(gotRepeatPositions) != comparisonMaxSeedHits {
		t.Fatalf("repeat hash stored %d positions, want %d", len(gotRepeatPositions), comparisonMaxSeedHits)
	}
	gotNonRepetitivePositions := index[7].slice()
	if want := []int{11, 23, 37}; !slices.Equal(gotNonRepetitivePositions, want) {
		t.Fatalf("non-repetitive positions changed: got %v want %v", gotNonRepetitivePositions, want)
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

func TestEncodeComparisonGenomesTruncatesLongNamesAndUsesWrittenSegmentCount(t *testing.T) {
	longName := strings.Repeat("A", 0xFFFF+25)
	payload := encodeComparisonGenomes([]ComparisonGenomeInfo{{
		ID:           1,
		Name:         longName,
		Path:         longName,
		Length:       10,
		SegmentCount: 99,
		FeatureCount: 1,
		Segments: []ComparisonSegmentInfo{{
			Name: longName,
			End:  10,
		}},
	}})
	if got := int(binary.LittleEndian.Uint16(payload[0:2])); got != 1 {
		t.Fatalf("genome count = %d, want 1", got)
	}
	off := 2
	if got := int(binary.LittleEndian.Uint16(payload[off+6 : off+8])); got != 1 {
		t.Fatalf("segment count = %d, want written segment count 1", got)
	}
	nameLen := int(binary.LittleEndian.Uint16(payload[off+12 : off+14]))
	if nameLen != 0xFFFF {
		t.Fatalf("name length = %d, want %d", nameLen, 0xFFFF)
	}
	off += 14 + nameLen
	pathLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
	if pathLen != 0xFFFF {
		t.Fatalf("path length = %d, want %d", pathLen, 0xFFFF)
	}
	off += 2 + pathLen
	segmentNameLen := int(binary.LittleEndian.Uint16(payload[off+13 : off+15]))
	if segmentNameLen != 0xFFFF {
		t.Fatalf("segment name length = %d, want %d", segmentNameLen, 0xFFFF)
	}
}

func TestEncodeComparisonBlockDetailTruncatesVariantStringsAndKeepsRecordsAligned(t *testing.T) {
	longBases := strings.Repeat("G", 0xFFFF+25)
	payload := encodeComparisonBlockDetail(ComparisonBlockDetail{
		Block: ComparisonBlock{
			QueryEnd:         1,
			TargetEnd:        1,
			PercentIdentX100: 9000,
			SameStrand:       true,
		},
		Ops: "M",
		Variants: []ComparisonVariantInfo{
			{
				Kind:      variantKindComplex,
				RefBases:  longBases,
				AltBases:  longBases,
				QueryPos:  1,
				TargetPos: 1,
			},
			{
				Kind:      variantKindSNP,
				RefBases:  "C",
				AltBases:  "T",
				QueryPos:  2,
				TargetPos: 2,
			},
		},
	})
	opsLen := int(binary.LittleEndian.Uint32(payload[19:23]))
	off := 23 + opsLen
	variantCount := int(binary.LittleEndian.Uint16(payload[off : off+2]))
	if variantCount != 2 {
		t.Fatalf("variant count = %d, want 2", variantCount)
	}
	off += 2
	refLen := int(binary.LittleEndian.Uint16(payload[off+9 : off+11]))
	altLen := int(binary.LittleEndian.Uint16(payload[off+11 : off+13]))
	if refLen != 0xFFFF || altLen != 0xFFFF {
		t.Fatalf("first variant lengths = %d/%d, want %d/%d", refLen, altLen, 0xFFFF, 0xFFFF)
	}
	off += 13 + refLen + altLen
	if payload[off] != variantKindSNP {
		t.Fatalf("second variant kind = %d, want %d", payload[off], variantKindSNP)
	}
	secondRefLen := int(binary.LittleEndian.Uint16(payload[off+9 : off+11]))
	secondAltLen := int(binary.LittleEndian.Uint16(payload[off+11 : off+13]))
	off += 13
	secondRef := string(payload[off : off+secondRefLen])
	off += secondRefLen
	secondAlt := string(payload[off : off+secondAltLen])
	if secondRef != "C" || secondAlt != "T" {
		t.Fatalf("second variant did not stay aligned: ref=%q alt=%q", secondRef, secondAlt)
	}
}

func TestCloneComparisonGenomeForDetailSnapshotsMutableSlices(t *testing.T) {
	original := &comparisonGenome{
		Name:     "original",
		Sequence: "ACGT",
		Features: []Feature{{
			Type: "gene",
		}},
		Segments: []comparisonSegment{{
			Name: "chr1",
			RawFeatures: []Feature{{
				Type: "raw_gene",
			}},
		}},
	}
	clone := cloneComparisonGenomeForDetail(original)
	original.Sequence = "TTTT"
	original.Features[0].Type = "changed"
	original.Segments[0].Name = "changed"
	original.Segments[0].RawFeatures[0].Type = "changed"

	if clone.Sequence != "ACGT" {
		t.Fatalf("clone sequence changed: %q", clone.Sequence)
	}
	if clone.Features[0].Type != "gene" {
		t.Fatalf("clone features changed: %+v", clone.Features)
	}
	if clone.Segments[0].Name != "chr1" {
		t.Fatalf("clone segment changed: %+v", clone.Segments[0])
	}
	if clone.Segments[0].RawFeatures[0].Type != "raw_gene" {
		t.Fatalf("clone raw features changed: %+v", clone.Segments[0].RawFeatures)
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

func TestMoveComparisonSegmentRebuildsCoordinatesAndAnnotations(t *testing.T) {
	e := NewEngine()
	genome := &comparisonGenome{
		ID:   1,
		Name: "g1",
		Segments: []comparisonSegment{
			{
				Name:        "chr1",
				RawSequence: strings.Repeat("A", 120),
				RawFeatures: []Feature{{SeqName: "chr1", Start: 10, End: 20, Type: "gene"}},
			},
			{
				Name:        "chr2",
				RawSequence: strings.Repeat("C", 80),
				RawFeatures: []Feature{{SeqName: "chr2", Start: 5, End: 15, Type: "gene"}},
			},
			{
				Name:        "chr3",
				RawSequence: strings.Repeat("G", 60),
				RawFeatures: []Feature{{SeqName: "chr3", Start: 1, End: 6, Type: "gene"}},
			},
		},
	}
	genome.rebuildDerived()
	e.comparisonGenomes[genome.ID] = genome
	e.comparisonGenomeOrder = []uint16{genome.ID}

	if err := e.MoveComparisonSegment(genome.ID, uint32(genome.Segments[0].Start), moveActionEnd); err != nil {
		t.Fatalf("MoveComparisonSegment returned error: %v", err)
	}

	genomes := e.ListComparisonGenomes()
	if len(genomes) != 1 {
		t.Fatalf("expected 1 genome, got %d", len(genomes))
	}
	segments := genomes[0].Segments
	gotOrder := []string{segments[0].Name, segments[1].Name, segments[2].Name}
	wantOrder := []string{"chr2", "chr3", "chr1"}
	if !slices.Equal(gotOrder, wantOrder) {
		t.Fatalf("unexpected segment order: got %v want %v", gotOrder, wantOrder)
	}
	wantChr1Start := uint32(80 + comparisonConcatGapBP + 60 + comparisonConcatGapBP)
	if segments[2].Start != wantChr1Start {
		t.Fatalf("unexpected moved chr1 start: got %d want %d", segments[2].Start, wantChr1Start)
	}
	annPayload, err := e.GetComparisonAnnotations(genome.ID, 0, uint32(genomes[0].Length), 100, 1)
	if err != nil {
		t.Fatalf("GetComparisonAnnotations returned error: %v", err)
	}
	_, _, feats := decodeAnnotationsForTest(t, annPayload)
	foundChr1 := false
	for _, feat := range feats {
		if feat.SeqName != "chr1" {
			continue
		}
		foundChr1 = true
		if feat.Start != int(wantChr1Start)+10 || feat.End != int(wantChr1Start)+20 {
			t.Fatalf("unexpected moved chr1 feature coordinates: %+v", feat)
		}
	}
	if !foundChr1 {
		t.Fatal("expected moved chr1 feature to be present")
	}
}
