package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"math/rand"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/martinghunt/faqt/align"
)

// Convenience wrappers keep application-level tests focused on block behaviour;
// the production adapter always propagates alignment errors explicitly.
func buildCanonicalComparisonBlocks(query, target *comparisonGenome) []comparisonCanonicalBlock {
	blocks, err := alignCanonicalComparisonBlocks(context.Background(), query, target, nil, comparisonAlignOptions())
	if err != nil {
		panic(err)
	}
	return blocks
}

func comparisonTestDNA(seed int64, n int) string {
	r := rand.New(rand.NewSource(seed))
	b := make([]byte, n)
	for i := range b {
		b[i] = "ACGT"[r.Intn(4)]
	}
	return string(b)
}

func comparisonTestEngine(t *testing.T, q, target string, reverseQ, reverseT bool) *Engine {
	t.Helper()
	e := NewEngine()
	e.comparisonCacheDir = t.TempDir()
	for i, sequence := range []string{q, target} {
		g := &comparisonGenome{ID: uint16(i + 1), Name: fmt.Sprintf("genome%d", i), Segments: []comparisonSegment{
			{Name: "decoy", RawSequence: comparisonTestDNA(int64(i+90), 137+i*31)},
			{Name: "main", RawSequence: sequence, Reversed: []bool{reverseQ, reverseT}[i]},
		}}
		g.rebuildDerived()
		e.comparisonGenomes[g.ID] = g
		e.comparisonGenomeOrder = append(e.comparisonGenomeOrder, g.ID)
	}
	e.rebuildComparisonPairsLocked()
	return e
}

func replayComparisonDetail(t *testing.T, q, target *comparisonGenome, detail ComparisonBlockDetail) {
	t.Helper()
	b := detail.Block
	qPos, tPos := int(b.QueryStart), int(b.TargetStart)
	step := 1
	if !b.SameStrand {
		tPos = int(b.TargetEnd) - 1
		step = -1
	}
	matches := 0
	for _, op := range []byte(detail.Ops) {
		if op == 'M' || op == 'X' {
			if qPos >= int(b.QueryEnd) || tPos < int(b.TargetStart) || tPos >= int(b.TargetEnd) {
				t.Fatalf("operation exceeds block: %+v", b)
			}
			base := target.Sequence[tPos]
			if step < 0 {
				base = complementIUPACBase(base)
			}
			equal := q.Sequence[qPos] == base && base != 'N'
			if equal != (op == 'M') {
				t.Fatalf("%c disagrees with DNA at %d/%d", op, qPos, tPos)
			}
			if equal {
				matches++
			}
		}
		switch op {
		case 'M', 'X':
			qPos++
			tPos += step
		case 'I':
			qPos++
		case 'D':
			tPos += step
		default:
			t.Fatalf("unknown operation %q", op)
		}
	}
	wantT := int(b.TargetEnd)
	if step < 0 {
		wantT = int(b.TargetStart) - 1
	}
	if qPos != int(b.QueryEnd) || tPos != wantT {
		t.Fatalf("path consumption disagrees with block: %d/%d, %+v", qPos, tPos, b)
	}
	if comparisonPercentIdentityX100(matches, len(detail.Ops)) != b.PercentIdentX100 {
		t.Fatal("summary and path identity differ")
	}
	wantVariants := variantsToInfo(comparisonAlignmentOps{Ops: []byte(detail.Ops)}.variantsForBlock(b))
	if !reflect.DeepEqual(wantVariants, detail.Variants) {
		t.Fatal("variant coordinates do not follow alignment operations")
	}
}

func TestComparisonPathTransformsAndSession(t *testing.T) {
	query := comparisonTestDNA(12, 1400)
	mutated := []byte(query)
	mutated[303] = "ACGT"[(strings.IndexByte("ACGT", mutated[303])+1)%4]
	target := string(mutated[:700]) + "ACGTAC" + string(mutated[700:])
	for _, reverseMatch := range []bool{false, true} {
		for _, reverseQ := range []bool{false, true} {
			for _, reverseT := range []bool{false, true} {
				t.Run(fmt.Sprintf("match_%v/query_%v/target_%v", reverseMatch, reverseQ, reverseT), func(t *testing.T) {
					seq := target
					if reverseMatch {
						seq = reverseComplementString(seq)
					}
					e := comparisonTestEngine(t, query, seq, reverseQ, reverseT)
					blocks, err := e.GetComparisonBlocks(1)
					if err != nil || len(blocks) == 0 {
						t.Fatalf("blocks: %v, %v", blocks, err)
					}
					var best ComparisonBlock
					for _, b := range blocks {
						if b.QueryEnd-b.QueryStart > best.QueryEnd-best.QueryStart {
							best = b
						}
					}
					if best.QueryEnd-best.QueryStart < 1300 {
						t.Fatalf("missing edited full-length match: %+v", best)
					}
					detail, err := e.GetComparisonBlockDetail(1, 2, best)
					if err != nil || !strings.Contains(detail.Ops, "X") || !strings.Contains(detail.Ops, "D") {
						t.Fatalf("missing SNP/indel path: %v, %v", detail, err)
					}
					replayComparisonDetail(t, e.comparisonGenomes[1], e.comparisonGenomes[2], detail)
					// Exercise the on-disk path on the second request.
					cached, err := e.GetComparisonBlockDetail(1, 2, best)
					if err != nil || !reflect.DeepEqual(cached, detail) {
						t.Fatal("cached detail changed", err)
					}
					swapped, err := e.GetComparisonBlockDetail(2, 1, swappedComparisonBlock(best))
					if err != nil {
						t.Fatal(err)
					}
					replayComparisonDetail(t, e.comparisonGenomes[2], e.comparisonGenomes[1], swapped)
					path := filepath.Join(t.TempDir(), "paths.seqhikercmp")
					if err := e.SaveComparisonSession(path); err != nil {
						t.Fatal(err)
					}
					loaded := NewEngine()
					loaded.comparisonCacheDir = t.TempDir()
					if err := loaded.LoadComparisonSession(path); err != nil {
						t.Fatal(err)
					}
					restored, err := loaded.GetComparisonBlockDetail(1, 2, best)
					if err != nil || !reflect.DeepEqual(restored, detail) {
						t.Fatal("session lost the computed path", err)
					}
					// Reversing and moving a contig must preserve its path and
					// remap its offsets rather than crossing the spacer.
					if err := loaded.SetComparisonSegmentOrientation(1, uint32(loaded.comparisonGenomes[1].Segments[1].Start), !reverseQ); err != nil {
						t.Fatal(err)
					}
					if err := loaded.MoveComparisonSegment(1, uint32(loaded.comparisonGenomes[1].Segments[1].Start), moveActionStart); err != nil {
						t.Fatal(err)
					}
					moved, err := loaded.GetComparisonBlocksByGenomes(1, 2)
					if err != nil {
						t.Fatal(err)
					}
					for _, b := range moved {
						d, err := loaded.GetComparisonBlockDetail(1, 2, b)
						if err != nil {
							t.Fatal(err)
						}
						replayComparisonDetail(t, loaded.comparisonGenomes[1], loaded.comparisonGenomes[2], d)
					}
				})
			}
		}
	}
}

func TestComparisonAlignmentErrorsAreNotEmptyResults(t *testing.T) {
	q := &comparisonGenome{Name: "q", Sequence: comparisonTestDNA(1, 400)}
	target := &comparisonGenome{Name: "t", Sequence: q.Sequence}
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	blocks, err := alignCanonicalComparisonBlocks(ctx, q, target, nil, comparisonAlignOptions())
	if !errors.Is(err, context.Canceled) || blocks != nil {
		t.Fatalf("cancellation: %v, %v", blocks, err)
	}
	opts := comparisonAlignOptions()
	opts.MaxAnchors = 1
	blocks, err = alignCanonicalComparisonBlocks(context.Background(), q, target, nil, opts)
	var limit *align.LimitError
	if !errors.As(err, &limit) || blocks != nil {
		t.Fatalf("resource error: %v, %v", blocks, err)
	}
	e := comparisonTestEngine(t, "INVALID!", target.Sequence, false, false)
	if _, err := e.GetComparisonBlocks(1); err == nil || e.comparisonPairs[1].Status != comparisonStatusPending || len(e.comparisonPairs[1].CanonicalBlocks) != 0 {
		t.Fatal("failed comparison marked ready")
	}
	if e.GetComparisonProgress(1, 2).Active {
		t.Fatal("failed comparison left progress active")
	}
}

// Preserve the intent of the pre-existing short-prefix regression: an isolated
// hit before a large unseeded gap cannot hide a substantial later exact run.
func TestComparisonShortPrefixDoesNotHideValidRun(t *testing.T) {
	query := comparisonTestDNA(28, 17000)
	for _, reverse := range []bool{false, true} {
		target := query[:35] + comparisonTestDNA(60, 14458) + query[14000:]
		if reverse {
			target = reverseComplementString(target)
		}
		e := comparisonTestEngine(t, query, target, false, false)
		blocks, err := e.GetComparisonBlocks(1)
		if err != nil {
			t.Fatal(err)
		}
		found := false
		for _, block := range blocks {
			if block.QueryStart <= uint32(e.comparisonGenomes[1].Segments[1].Start+14000) && block.QueryEnd >= uint32(e.comparisonGenomes[1].Segments[1].Start+16980) && block.SameStrand != reverse {
				found = true
			}
		}
		if !found {
			t.Fatalf("later exact run lost, reverse=%v", reverse)
		}
	}
}

func TestComparisonV4SessionRecomputesLegacyBlocks(t *testing.T) {
	e := comparisonTestEngine(t, comparisonTestDNA(42, 800), comparisonTestDNA(42, 800), false, false)
	var b bytes.Buffer
	b.Write(comparisonSessionMagicV4)
	writeU16(&b, 2)
	writeComparisonGenome(&b, e.comparisonGenomes[1])
	writeComparisonGenome(&b, e.comparisonGenomes[2])
	writeU16(&b, 1)
	writeU16(&b, 1)
	writeU16(&b, 1)
	writeU16(&b, 2)
	writeU8(&b, comparisonStatusReady)
	writeU32(&b, 0) // Legacy empty result must not hide newly recoverable matches.
	path := filepath.Join(t.TempDir(), "legacy.seqhikercmp")
	if err := os.WriteFile(path, b.Bytes(), 0600); err != nil {
		t.Fatal(err)
	}
	loaded := NewEngine()
	if err := loaded.LoadComparisonSession(path); err != nil {
		t.Fatal(err)
	}
	if loaded.comparisonPairs[1].Status != comparisonStatusPending {
		t.Fatal("legacy alignment was not invalidated")
	}
	if blocks, err := loaded.GetComparisonBlocks(1); err != nil || len(blocks) == 0 {
		t.Fatal("legacy session did not recompute", err)
	}
}

func TestComparisonSessionRejectsInvalidPaths(t *testing.T) {
	for _, ops := range [][]align.Op{
		{{Code: '?', Length: 100}},
		{{Code: '=', Length: 0}},
		{{Code: '=', Length: 101}},
		{{Code: '=', Length: 99}},
	} {
		var b bytes.Buffer
		writeU32(&b, uint32(len(ops)))
		for _, op := range ops {
			writeU8(&b, op.Code)
			writeU32(&b, uint32(op.Length))
		}
		block := comparisonCanonicalBlock{QueryEnd: 100, TargetEnd: 100}
		if err := readComparisonCanonicalOps(&b, &block); err == nil {
			t.Fatalf("accepted invalid path: %+v", ops)
		}
	}
}

func TestComparisonLargePathsRemainCompressed(t *testing.T) {
	n := comparisonMaxDetailOps + 1
	query := &comparisonGenome{Sequence: strings.Repeat("A", n), Length: n}
	target := &comparisonGenome{Sequence: query.Sequence, Length: n}
	canonical := comparisonCanonicalBlock{QueryEnd: n, TargetEnd: n, SameStrand: true, PercentIdentX100: 10000, Ops: []align.Op{{Code: '=', Length: n}}}
	detail, ok := detailForCanonicalComparisonBlock(query, target, canonical)
	if !ok || detail.Ops != "" || len(canonical.Ops) != 1 || detail.Summary.QueryEnd != uint32(n) {
		t.Fatal("large path was expanded or lost")
	}
}

func TestComparisonIsolatedSeedsDoNotBecomeBlocks(t *testing.T) {
	q := comparisonTestDNA(1, 800)
	target := comparisonTestDNA(2, 800)
	for _, start := range []int{0, 300, 600} {
		target = target[:start] + q[start:start+15] + target[start+15:]
	}
	if blocks := buildComparisonBlocks(&comparisonGenome{Sequence: q}, &comparisonGenome{Sequence: target}); len(blocks) != 0 {
		t.Fatalf("isolated seeds became full matches: %+v", blocks)
	}
}

func TestComparisonRealData(t *testing.T) {
	dir := os.Getenv("SEQHIKER_COMPARISON_DATA")
	if dir == "" {
		t.Skip("set SEQHIKER_COMPARISON_DATA to the private FASTA directory")
	}
	for _, pair := range []struct{ name, a, b string }{
		{"original", "31585_6#49.fasta", "barcode10_ICESp23_spliced.fasta"},
		{"repeats", "repeats.CP026802.1.fa", "repeats.CP151312.1.fa"},
	} {
		t.Run(pair.name, func(t *testing.T) {
			e := NewEngine()
			e.comparisonCacheDir = t.TempDir()
			a, err := e.AddComparisonGenome(filepath.Join(dir, pair.a))
			if err != nil {
				t.Fatal(err)
			}
			b, err := e.AddComparisonGenome(filepath.Join(dir, pair.b))
			if err != nil {
				t.Fatal(err)
			}
			start := time.Now()
			blocks, err := e.GetComparisonBlocksByGenomes(a.ID, b.ID)
			if err != nil || len(blocks) == 0 {
				t.Fatalf("comparison failed: %v", err)
			}
			t.Logf("%d blocks, comparison %s", len(blocks), time.Since(start))
			if pair.name == "repeats" && len(blocks) <= 1024 {
				t.Fatal("repeat placements appear truncated")
			}
			found := pair.name != "original"
			for _, canonical := range e.comparisonPairs[1].CanonicalBlocks {
				g := e.comparisonGenomes[a.ID]
				if strings.Contains(g.Segments[canonical.QuerySegment].Name, "31585_6_49.4") && !canonical.SameStrand && canonical.QueryStart <= 66800 && canonical.QueryEnd >= 69700 && canonical.PercentIdentX100 >= 9500 {
					found = true
				}
				detail, ok := detailForCanonicalComparisonBlock(g, e.comparisonGenomes[b.ID], canonical)
				if !ok {
					t.Fatal("invalid contig mapping")
				}
				if detail.Ops != "" {
					replayComparisonDetail(t, g, e.comparisonGenomes[b.ID], detail.info())
				}
			}
			if !found {
				t.Fatal("motivating missing match not recovered")
			}
		})
	}
}

func buildComparisonBlocks(query, target *comparisonGenome) []ComparisonBlock {
	return displayComparisonBlocks(query, target, buildCanonicalComparisonBlocks(query, target))
}

func TestComparisonUsesAdaptiveExtension(t *testing.T) {
	if comparisonAlignOptions().EndExtension != align.EndExtensionAdaptive {
		t.Fatal("expected adaptive end extension")
	}
}

func buildComparisonBlockDetail(query, target *comparisonGenome, summary ComparisonBlock) (comparisonBlockDetail, bool) {
	for _, block := range buildCanonicalComparisonBlocks(query, target) {
		detail, ok := detailForCanonicalComparisonBlock(query, target, block)
		if ok && detail.Summary == summary {
			return detail, true
		}
	}
	return comparisonBlockDetail{}, false
}
