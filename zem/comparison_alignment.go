package main

import (
	"context"
	"fmt"
	"slices"
	"sort"

	"github.com/martinghunt/faqt/align"
	"github.com/martinghunt/faqt/seqio"
)

// This is an application policy, shared by comparison and cache invalidation.
// Repeat-rich genomes exceed faqt's default raw-anchor budget. Limits still
// return errors rather than silently dropping placements.
func comparisonAlignOptions() align.Options {
	o := align.DefaultOptions()
	o.EndExtension = align.EndExtensionAdaptive
	// Collapse paths describing the same placement; repeat copies remain.
	o.Redundancy = align.RedundancyNear
	o.MaxAnchors = 20000000
	return o
}

func prepareComparisonGenome(ctx context.Context, g *comparisonGenome) (*align.Genome, error) {
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	if g == nil {
		return nil, fmt.Errorf("comparison genome is missing")
	}
	if g.Prepared != nil {
		return g.Prepared, nil
	}
	records := make([]seqio.SeqRecord, 0, len(g.Segments))
	if len(g.Segments) == 0 {
		records = append(records, seqio.SeqRecord{Name: g.Name, Seq: []byte(g.Sequence)})
	} else {
		for _, segment := range g.Segments {
			sequence := segment.RawSequence
			if sequence == "" && segment.End > segment.Start && segment.Start >= 0 && segment.End <= len(g.Sequence) {
				sequence = g.Sequence[segment.Start:segment.End]
				if segment.Reversed {
					sequence = reverseComplementString(sequence)
				}
			}
			records = append(records, seqio.SeqRecord{Name: segment.Name, Seq: []byte(sequence)})
		}
	}
	prepared, err := align.Prepare(records, align.SketchOptions{})
	if err != nil {
		return nil, fmt.Errorf("prepare %s: %w", g.Name, err)
	}
	if err := ctx.Err(); err != nil {
		return nil, err
	}
	g.Prepared = prepared
	return prepared, nil
}

func alignCanonicalComparisonBlocks(ctx context.Context, query, target *comparisonGenome, progress *comparisonProgressTracker, opts align.Options) ([]comparisonCanonicalBlock, error) {
	a, err := prepareComparisonGenome(ctx, query)
	if err != nil {
		return nil, err
	}
	b, err := prepareComparisonGenome(ctx, target)
	if err != nil {
		return nil, err
	}
	opts.Progress = func(p align.Progress) {
		if progress != nil && p.Total > 0 {
			progress.updateCurrent("Comparing sequences", progress.total, float64(p.Completed)/float64(p.Total))
		}
	}
	matches, err := align.Compare(ctx, a, b, opts)
	if err != nil {
		return nil, fmt.Errorf("compare %s vs %s: %w", query.Name, target.Name, err)
	}
	blocks := make([]comparisonCanonicalBlock, 0, len(matches))
	for _, m := range matches {
		block := comparisonCanonicalBlock{
			QuerySegment: m.AContig, QueryStart: m.A.Start, QueryEnd: m.A.End,
			TargetSegment: m.BContig, TargetStart: m.B.Start, TargetEnd: m.B.End,
			PercentIdentX100: comparisonPercentIdentityX100(m.Matches, m.Columns),
			SameStrand:       !m.Reverse, Ops: m.Ops,
		}
		// Keep the main diagonal and distinct self-repeat copies. Suppress the
		// same near-diagonal self artefacts as the existing display policy.
		if comparisonCanonicalBlockIsTrivialSelfOverlap(query, target, block) &&
			!(block.QueryStart == block.TargetStart && block.QueryEnd == block.TargetEnd) {
			continue
		}
		blocks = append(blocks, block)
	}
	sort.SliceStable(blocks, func(i, j int) bool { return canonicalComparisonBlockLess(blocks[i], blocks[j]) })
	return blocks, nil
}

func comparisonSegmentsForDisplay(g *comparisonGenome) *comparisonGenome {
	if len(g.Segments) != 0 {
		return g
	}
	copy := *g
	copy.Segments = []comparisonSegment{{Name: g.Name, RawSequence: g.Sequence, End: len(g.Sequence)}}
	return &copy
}

func detailForCanonicalComparisonBlock(query, target *comparisonGenome, canonical comparisonCanonicalBlock) (comparisonBlockDetail, bool) {
	query, target = comparisonSegmentsForDisplay(query), comparisonSegmentsForDisplay(target)
	summary, ok := displayComparisonBlock(query, target, canonical)
	if !ok {
		return comparisonBlockDetail{}, false
	}
	detail := comparisonBlockDetail{Summary: summary}
	columns := 0
	for _, op := range canonical.Ops {
		columns += op.Length
	}
	// Keep large paths compressed in memory/session files. The existing wire
	// protocol sends per-column operations, so omit those above its UI budget.
	if columns > comparisonMaxDetailOps {
		return detail, true
	}
	ops := make([]byte, 0, columns)
	for _, op := range canonical.Ops {
		code := op.Code
		if code == '=' {
			code = 'M'
		}
		for i := 0; i < op.Length; i++ {
			ops = append(ops, code)
		}
	}
	if query.Segments[canonical.QuerySegment].Reversed {
		slices.Reverse(ops)
	}
	detail.Ops = string(ops)
	detail.Variants = comparisonAlignmentOps{Ops: ops}.variantsForBlock(summary)
	return detail, true
}

func (e *Engine) GetComparisonBlockDetail(queryID, targetID uint16, block ComparisonBlock) (ComparisonBlockDetail, error) {
	e.mu.Lock()
	defer e.mu.Unlock()
	query, target := e.comparisonGenomes[queryID], e.comparisonGenomes[targetID]
	if query == nil || target == nil || queryID == targetID {
		return ComparisonBlockDetail{}, fmt.Errorf("invalid comparison genomes %d/%d", queryID, targetID)
	}
	for _, pair := range e.comparisonPairs {
		if pair == nil {
			continue
		}
		swapped := pair.TopGenomeID == targetID && pair.BottomGenomeID == queryID
		if !swapped && !(pair.TopGenomeID == queryID && pair.BottomGenomeID == targetID) {
			continue
		}
		if err := e.ensureComparisonPairBlocksLocked(pair); err != nil {
			return ComparisonBlockDetail{}, err
		}
		q, t := e.comparisonGenomes[pair.TopGenomeID], e.comparisonGenomes[pair.BottomGenomeID]
		requested := block
		if swapped {
			requested = swappedComparisonBlock(block)
		}
		// Disk caching is optional. A cache failure must not replace the
		// computed alignment with a different path or lose usable detail.
		_ = e.ensureComparisonPairDetailCacheLocked(pair, q, t)
		if detail, ok, err := readComparisonDetailFromPairCache(pair, requested); err == nil && ok {
			if swapped {
				detail = swappedComparisonBlockDetail(detail)
			}
			return detail, nil
		}
		for _, canonical := range pair.CanonicalBlocks {
			summary, ok := displayComparisonBlock(q, t, canonical)
			if !ok || summary != requested {
				continue
			}
			detail, ok := detailForCanonicalComparisonBlock(q, t, canonical)
			if !ok {
				break
			}
			info := detail.info()
			_ = appendComparisonDetailToPairCache(pair, requested, info)
			if swapped {
				info = swappedComparisonBlockDetail(info)
			}
			return info, nil
		}
		return ComparisonBlockDetail{}, fmt.Errorf("comparison block is no longer available")
	}
	// Non-adjacent comparisons have no persistent pair entry.
	blocks, err := alignCanonicalComparisonBlocks(context.Background(), query, target, nil, comparisonAlignOptions())
	if err != nil {
		return ComparisonBlockDetail{}, err
	}
	for _, canonical := range blocks {
		detail, ok := detailForCanonicalComparisonBlock(query, target, canonical)
		if ok && detail.Summary == block {
			return detail.info(), nil
		}
	}
	return ComparisonBlockDetail{}, fmt.Errorf("comparison block is no longer available")
}
