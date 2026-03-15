package main

import (
	"container/list"
	"fmt"
	"math"
	"os"
	"sort"

	"github.com/biogo/hts/bam"
	"github.com/biogo/hts/sam"
)

type windowRange struct {
	start int
	end   int
}

func (e *Engine) GetTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	window := tileWindow(zoom, tileIndex)
	if zoom > e.maxReadZoom {
		return encodeAlignmentTile(window.start, window.end, nil), nil
	}
	return e.getIndexedTile(sourceID, chrID, zoom, tileIndex, readTileCacheKind, true)
}

func (e *Engine) GetCoverageTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	return e.getIndexedTile(sourceID, chrID, zoom, tileIndex, covTileCacheKind, false)
}

func (e *Engine) GetStrandCoverageTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	return e.getIndexedTile(sourceID, chrID, zoom, tileIndex, strandCovTileCacheKind, false)
}

func (e *Engine) GetGCPlotTile(chrID uint16, zoom uint8, tileIndex uint32, windowLen uint32) ([]byte, error) {
	e.mu.Lock()
	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	chrLen := e.chrLength[chr]
	if chrLen <= 0 {
		e.mu.Unlock()
		return encodeGCPlotTile(0, 0, int(windowLen), nil), nil
	}
	window := tileWindow(zoom, tileIndex)
	if window.start < 0 {
		window.start = 0
	}
	if window.start > chrLen {
		window.start = chrLen
	}
	if window.end > chrLen {
		window.end = chrLen
	}
	if window.end < window.start {
		window.end = window.start
	}
	if windowLen == 0 {
		windowLen = 200
	}
	if windowLen > 1_000_000 {
		windowLen = 1_000_000
	}
	key := tileCacheKey{
		Generation: e.globalGeneration,
		SourceID:   0,
		Kind:       plotTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      windowLen,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}
	gc := e.gcPrefix[chr]
	atgc := e.atgcPrefix[chr]
	generation := e.globalGeneration
	e.mu.Unlock()

	values := computeGCPlotValues(gc, atgc, window.start, window.end, int(windowLen), plotTileBins)
	payload := encodeGCPlotTile(window.start, window.end, int(windowLen), values)

	e.mu.Lock()
	if e.globalGeneration == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()
	return payload, nil
}

func (e *Engine) getIndexedTile(sourceID uint16, chrID uint16, zoom uint8, tileIndex uint32, kind uint8, prefetch bool) ([]byte, error) {
	e.mu.Lock()
	src, err := e.resolveBAMSourceLocked(sourceID)
	if err != nil {
		e.mu.Unlock()
		return nil, err
	}

	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	ref := src.RefByChrID[chrID]
	if ref == nil {
		e.mu.Unlock()
		return nil, fmt.Errorf("chromosome %s is missing from BAM header", chr)
	}

	key := tileCacheKey{
		Generation: src.Generation,
		SourceID:   src.ID,
		Kind:       kind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      0,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}

	bamPath := src.Path
	bamIdx := src.Index
	covPrefixFwd := src.CovPrefixFwd[chrID]
	covPrefixRev := src.CovPrefixRev[chrID]
	maxTileRecs := e.maxTileRecs
	if kind == readTileCacheKind && zoom >= 6 {
		maxTileRecs *= 2
	}
	window := tileWindow(zoom, tileIndex)
	binCount := coverageTileBinCount(window.start, window.end, 0, ref.Len())
	generation := src.Generation
	prefetchRadius := e.prefetchRadius
	refSeq := e.sequences[chr]
	selectedSourceID := src.ID
	e.mu.Unlock()

	includeSNPs := kind == readTileCacheKind && zoom <= snpDetailMaxZoom
	var payload []byte
	if (kind == covTileCacheKind || kind == strandCovTileCacheKind) && (len(covPrefixFwd) > 0 || len(covPrefixRev) > 0) {
		if kind == strandCovTileCacheKind {
			payload, err = encodeStrandCoverageTileFromStrandPrefixes(window.start, window.end, covPrefixFwd, covPrefixRev, binCount)
		} else {
			payload, err = encodeCoverageTileFromStrandPrefixes(window.start, window.end, covPrefixFwd, covPrefixRev, binCount)
		}
	} else {
		payload, err = loadIndexedTilePayload(bamPath, bamIdx, ref, window.start, window.end, kind, maxTileRecs, includeSNPs, refSeq, binCount)
	}
	if err != nil {
		return nil, err
	}

	e.mu.Lock()
	if src2, ok := e.bamSources[selectedSourceID]; ok && src2.Generation == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()

	if prefetch && prefetchRadius > 0 {
		go e.prefetchAdjacentReadTiles(selectedSourceID, generation, chrID, zoom, tileIndex, prefetchRadius)
	}

	return payload, nil
}

func coverageTileBinCount(windowStart, windowEnd, minPos, maxPos int) int {
	nominalSpan := max(0, windowEnd-windowStart)
	actualStart := max(windowStart, minPos)
	actualEnd := min(windowEnd, maxPos)
	actualSpan := max(0, actualEnd-actualStart)
	if nominalSpan <= 0 || actualSpan <= 0 {
		return 0
	}
	if actualSpan >= nominalSpan {
		return plotTileBins
	}
	return max(1, int(math.Round(float64(plotTileBins)*float64(actualSpan)/float64(nominalSpan))))
}

func encodeCoverageTileFromStrandPrefixes(start, end int, forwardPrefix, reversePrefix []uint64, binCount int) ([]byte, error) {
	if start < 0 {
		start = 0
	}
	if end < start {
		end = start
	}
	maxPos := max(len(forwardPrefix), len(reversePrefix)) - 1
	if start > maxPos {
		start = maxPos
	}
	if end > maxPos {
		end = maxPos
	}
	if binCount <= 0 {
		return encodeCoverageTile(start, end, nil), nil
	}
	bins := make([]uint16, binCount)
	span := max(1, end-start)
	for b := range bins {
		bStart := start + (b*span)/len(bins)
		bEnd := start + ((b+1)*span)/len(bins)
		if bEnd <= bStart {
			bEnd = bStart + 1
		}
		if bStart < 0 {
			bStart = 0
		}
		if bEnd > maxPos {
			bEnd = maxPos
		}
		binW := bEnd - bStart
		if binW <= 0 {
			binW = 1
		}
		sum := prefixDelta(forwardPrefix, bStart, bEnd) + prefixDelta(reversePrefix, bStart, bEnd)
		avgDepth := int(math.Round(float64(sum) / float64(binW)))
		if avgDepth == 0 && sum > 0 {
			avgDepth = 1
		}
		if avgDepth < 0 {
			avgDepth = 0
		}
		if avgDepth > int(^uint16(0)) {
			avgDepth = int(^uint16(0))
		}
		bins[b] = uint16(avgDepth)
	}
	return encodeCoverageTile(start, end, bins), nil
}

func encodeStrandCoverageTileFromStrandPrefixes(start, end int, forwardPrefix, reversePrefix []uint64, binCount int) ([]byte, error) {
	if start < 0 {
		start = 0
	}
	if end < start {
		end = start
	}
	maxPos := max(len(forwardPrefix), len(reversePrefix)) - 1
	if start > maxPos {
		start = maxPos
	}
	if end > maxPos {
		end = maxPos
	}
	if binCount <= 0 {
		return encodeStrandCoverageTile(start, end, nil, nil), nil
	}
	forwardBins := make([]uint16, binCount)
	reverseBins := make([]uint16, binCount)
	span := max(1, end-start)
	for b := range forwardBins {
		bStart := start + (b*span)/len(forwardBins)
		bEnd := start + ((b+1)*span)/len(forwardBins)
		if bEnd <= bStart {
			bEnd = bStart + 1
		}
		if bStart < 0 {
			bStart = 0
		}
		if bEnd > maxPos {
			bEnd = maxPos
		}
		binW := bEnd - bStart
		if binW <= 0 {
			binW = 1
		}
		fwdSum := prefixDelta(forwardPrefix, bStart, bEnd)
		revSum := prefixDelta(reversePrefix, bStart, bEnd)
		forwardBins[b] = avgDepthBinValue(fwdSum, binW)
		reverseBins[b] = avgDepthBinValue(revSum, binW)
	}
	return encodeStrandCoverageTile(start, end, forwardBins, reverseBins), nil
}

func prefixDelta(prefix []uint64, start, end int) uint64 {
	if len(prefix) == 0 {
		return 0
	}
	maxPos := len(prefix) - 1
	if start < 0 {
		start = 0
	}
	if end < start {
		end = start
	}
	if start > maxPos {
		start = maxPos
	}
	if end > maxPos {
		end = maxPos
	}
	return prefix[end] - prefix[start]
}

func loadIndexedTilePayload(bamPath string, bamIdx *bam.Index, ref *sam.Reference, start, end int, kind uint8, maxTileRecs uint32, includeSNPs bool, refSeq string, binCount int) ([]byte, error) {
	if start < 0 {
		start = 0
	}
	refLen := ref.Len()
	if start > refLen {
		start = refLen
	}
	if end < start {
		end = start
	}
	if end > refLen {
		end = refLen
	}

	file, err := os.Open(bamPath)
	if err != nil {
		return nil, err
	}
	defer file.Close()

	reader, err := bam.NewReader(file, 0)
	if err != nil {
		return nil, err
	}
	defer reader.Close()

	chunks, err := bamIdx.Chunks(ref, start, end)
	if err != nil {
		return nil, err
	}
	if len(chunks) == 0 {
		if kind == covTileCacheKind {
			return encodeCoverageTile(start, end, make([]uint16, max(0, binCount))), nil
		}
		if kind == strandCovTileCacheKind {
			zeros := make([]uint16, max(0, binCount))
			return encodeStrandCoverageTile(start, end, zeros, zeros), nil
		}
		return encodeAlignmentTile(start, end, nil), nil
	}

	it, err := bam.NewIterator(reader, chunks)
	if err != nil {
		return nil, err
	}
	defer it.Close()

	switch kind {
	case covTileCacheKind:
		if binCount <= 0 {
			return encodeCoverageTile(start, end, nil), nil
		}
		bins := make([]uint16, binCount)
		sumDepthBp := make([]uint64, len(bins))
		span := max(1, end-start)
		seen := make(map[string]struct{})
		for it.Next() {
			rec := it.Record()
			if rec == nil || rec.Ref == nil || rec.Ref.ID() != ref.ID() {
				continue
			}
			key := recordDedupKey(rec)
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			s := max(rec.Start(), start)
			e := min(rec.End(), end)
			if e <= s {
				continue
			}
			binStart := ((s - start) * len(bins)) / span
			binEnd := ((e - 1 - start) * len(bins)) / span
			if binStart < 0 {
				binStart = 0
			}
			if binEnd >= len(bins) {
				binEnd = len(bins) - 1
			}
			for b := binStart; b <= binEnd; b++ {
				bStart := start + (b*span)/len(bins)
				bEnd := start + ((b+1)*span)/len(bins)
				if bEnd <= bStart {
					bEnd = bStart + 1
				}
				ovStart := max(s, bStart)
				ovEnd := min(e, bEnd)
				if ovEnd > ovStart {
					sumDepthBp[b] += uint64(ovEnd - ovStart)
				}
			}
		}
		if err := it.Error(); err != nil {
			return nil, err
		}
		for b := range bins {
			bStart := start + (b*span)/len(bins)
			bEnd := start + ((b+1)*span)/len(bins)
			if bEnd <= bStart {
				bEnd = bStart + 1
			}
			binW := bEnd - bStart
			bins[b] = avgDepthBinValue(sumDepthBp[b], binW)
		}
		return encodeCoverageTile(start, end, bins), nil

	case strandCovTileCacheKind:
		if binCount <= 0 {
			return encodeStrandCoverageTile(start, end, nil, nil), nil
		}
		forwardBins := make([]uint16, binCount)
		reverseBins := make([]uint16, binCount)
		sumDepthBpFwd := make([]uint64, len(forwardBins))
		sumDepthBpRev := make([]uint64, len(reverseBins))
		span := max(1, end-start)
		seen := make(map[string]struct{})
		for it.Next() {
			rec := it.Record()
			if rec == nil || rec.Ref == nil || rec.Ref.ID() != ref.ID() {
				continue
			}
			key := recordDedupKey(rec)
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			s := max(rec.Start(), start)
			e := min(rec.End(), end)
			if e <= s {
				continue
			}
			binStart := ((s - start) * len(forwardBins)) / span
			binEnd := ((e - 1 - start) * len(forwardBins)) / span
			if binStart < 0 {
				binStart = 0
			}
			if binEnd >= len(forwardBins) {
				binEnd = len(forwardBins) - 1
			}
			targetSums := sumDepthBpFwd
			if rec.Flags&sam.Reverse != 0 {
				targetSums = sumDepthBpRev
			}
			for b := binStart; b <= binEnd; b++ {
				bStart := start + (b*span)/len(forwardBins)
				bEnd := start + ((b+1)*span)/len(forwardBins)
				if bEnd <= bStart {
					bEnd = bStart + 1
				}
				ovStart := max(s, bStart)
				ovEnd := min(e, bEnd)
				if ovEnd > ovStart {
					targetSums[b] += uint64(ovEnd - ovStart)
				}
			}
		}
		if err := it.Error(); err != nil {
			return nil, err
		}
		for b := range forwardBins {
			bStart := start + (b*span)/len(forwardBins)
			bEnd := start + ((b+1)*span)/len(forwardBins)
			if bEnd <= bStart {
				bEnd = bStart + 1
			}
			binW := bEnd - bStart
			forwardBins[b] = avgDepthBinValue(sumDepthBpFwd[b], binW)
			reverseBins[b] = avgDepthBinValue(sumDepthBpRev[b], binW)
		}
		return encodeStrandCoverageTile(start, end, forwardBins, reverseBins), nil

	case readTileCacheKind:
		alignments, err := collectWindowAlignments(it, ref, start, end, maxTileRecs, includeSNPs, refSeq)
		if err != nil {
			return nil, err
		}
		return encodeAlignmentTile(start, end, alignments), nil

	default:
		return nil, fmt.Errorf("unknown tile kind %d", kind)
	}
}

func collectWindowAlignments(it *bam.Iterator, ref *sam.Reference, start, end int, maxTileRecs uint32, includeSNPs bool, refSeq string) ([]Alignment, error) {
	if maxTileRecs == 0 || end <= start {
		return nil, nil
	}

	limit := int(maxTileRecs)
	binCount := min(256, limit)
	if binCount <= 0 {
		binCount = 1
	}
	binCaps := make([]int, binCount)
	baseCap := limit / binCount
	rem := limit % binCount
	for i := range binCount {
		binCaps[i] = baseCap
		if i < rem {
			binCaps[i]++
		}
		if binCaps[i] <= 0 {
			binCaps[i] = 1
		}
	}
	bins := make([][]Alignment, binCount)
	binCounts := make([]int, binCount)
	filledBins := 0
	span := max(1, end-start)
	scanned := 0
	seen := make(map[string]struct{})
	for it.Next() {
		scanned++
		if scanned > maxScannedTileReads {
			break
		}
		rec := it.Record()
		if rec == nil || rec.Ref == nil || rec.Ref.ID() != ref.ID() {
			continue
		}
		key := recordDedupKey(rec)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		if rec.End() <= start || rec.Start() >= end {
			continue
		}
		s := max(rec.Start(), start)
		e := min(rec.End(), end)
		if e <= s {
			continue
		}
		pos := s + (e-s-1)/2
		b := ((pos - start) * binCount) / span
		if b < 0 {
			b = 0
		}
		if b >= binCount {
			b = binCount - 1
		}
		capForBin := binCaps[b]
		if binCounts[b] >= capForBin {
			continue
		}
		snps := recordSNPPositions(rec, start, end, includeSNPs, refSeq)
		mateRefID := -1
		if rec.MateRef != nil && (rec.Ref == nil || rec.MateRef.ID() != rec.Ref.ID()) {
			mateRefID = rec.MateRef.ID()
		}
		bins[b] = append(bins[b], Alignment{
			Start:        rec.Start(),
			End:          rec.End(),
			Name:         rec.Name,
			MapQ:         rec.MapQ,
			Flags:        uint16(rec.Flags),
			Cigar:        rec.Cigar.String(),
			SNPs:         snps,
			SNPBases:     snpBasesFromPositions(rec, snps),
			Reverse:      rec.Flags&sam.Reverse != 0,
			MateStart:    rec.MatePos,
			MateEnd:      estimateMateEnd(rec),
			MateRawStart: rec.MatePos,
			MateRawEnd:   estimateMateEnd(rec),
			MateRefID:    mateRefID,
			FragLen:      absInt(rec.TempLen),
			MateSameRef:  isLikelySameRefMate(rec),
		})
		binCounts[b]++
		if binCounts[b] == capForBin {
			filledBins++
			if filledBins >= binCount {
				break
			}
		}
	}
	if err := it.Error(); err != nil {
		return nil, err
	}

	alignments := make([]Alignment, 0, limit)
	for _, bucket := range bins {
		alignments = append(alignments, bucket...)
	}
	sort.Slice(alignments, func(i, j int) bool {
		if alignments[i].Start == alignments[j].Start {
			return alignments[i].End < alignments[j].End
		}
		return alignments[i].Start < alignments[j].Start
	})
	if len(alignments) > limit {
		alignments = alignments[:limit]
	}
	return alignments, nil
}

func (e *Engine) prefetchAdjacentReadTiles(sourceID uint16, generation uint64, chrID uint16, zoom uint8, tileIndex uint32, radius int) {
	select {
	case e.prefetchSem <- struct{}{}:
	default:
		return
	}
	defer func() { <-e.prefetchSem }()

	for offset := 1; offset <= radius; offset++ {
		step := uint32(offset)
		if tileIndex >= step {
			_, _ = e.prefetchReadTile(sourceID, generation, chrID, zoom, tileIndex-step)
		}
		_, _ = e.prefetchReadTile(sourceID, generation, chrID, zoom, tileIndex+step)
	}
}

func (e *Engine) prefetchReadTile(sourceID uint16, generation uint64, chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	e.mu.Lock()
	src, ok := e.bamSources[sourceID]
	if !ok || src.Generation != generation || src.Index == nil {
		e.mu.Unlock()
		return nil, nil
	}
	if zoom > e.maxReadZoom {
		e.mu.Unlock()
		return encodeAlignmentTile(tileWindow(zoom, tileIndex).start, tileWindow(zoom, tileIndex).end, nil), nil
	}
	chr, ok := e.idToChr[chrID]
	if !ok {
		e.mu.Unlock()
		return nil, nil
	}
	ref := src.Refs[chr]
	if ref == nil {
		e.mu.Unlock()
		return nil, nil
	}
	key := tileCacheKey{
		Generation: generation,
		SourceID:   sourceID,
		Kind:       readTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      0,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		e.mu.Unlock()
		return payload, nil
	}
	bamPath := src.Path
	bamIdx := src.Index
	maxTileRecs := e.maxTileRecs
	window := tileWindow(zoom, tileIndex)
	refSeq := e.sequences[chr]
	e.mu.Unlock()

	includeSNPs := zoom <= snpDetailMaxZoom
	payload, err := loadIndexedTilePayload(bamPath, bamIdx, ref, window.start, window.end, readTileCacheKind, maxTileRecs, includeSNPs, refSeq, 0)
	if err != nil {
		return nil, err
	}

	e.mu.Lock()
	if src2, ok := e.bamSources[sourceID]; ok && src2.Generation == generation {
		e.putCachedTileLocked(key, payload)
	}
	e.mu.Unlock()
	return payload, nil
}

func (e *Engine) getCachedTileLocked(key tileCacheKey) ([]byte, bool) {
	elem, ok := e.tileCache[key]
	if !ok {
		return nil, false
	}
	entry := elem.Value.(*tileCacheEntry)
	e.tileLRU.MoveToFront(elem)
	payload := make([]byte, len(entry.Payload))
	copy(payload, entry.Payload)
	return payload, true
}

func (e *Engine) putCachedTileLocked(key tileCacheKey, payload []byte) {
	payloadCopy := make([]byte, len(payload))
	copy(payloadCopy, payload)
	size := int64(len(payloadCopy) + 128)

	if existing, ok := e.tileCache[key]; ok {
		entry := existing.Value.(*tileCacheEntry)
		e.tileCacheBytes -= entry.Size
		entry.Payload = payloadCopy
		entry.Size = size
		e.tileCacheBytes += entry.Size
		e.tileLRU.MoveToFront(existing)
	} else {
		entry := &tileCacheEntry{Key: key, Payload: payloadCopy, Size: size}
		elem := e.tileLRU.PushFront(entry)
		e.tileCache[key] = elem
		e.tileCacheBytes += size
	}

	for e.tileCacheBytes > e.tileCacheMaxBytes {
		last := e.tileLRU.Back()
		if last == nil {
			break
		}
		entry := last.Value.(*tileCacheEntry)
		delete(e.tileCache, entry.Key)
		e.tileCacheBytes -= entry.Size
		e.tileLRU.Remove(last)
	}
}

func (e *Engine) resetTileCacheLocked() {
	e.tileCache = make(map[tileCacheKey]*list.Element)
	e.tileLRU.Init()
	e.tileCacheBytes = 0
}

func tileWindow(zoom uint8, tileIndex uint32) windowRange {
	tileWidth := baseTileSize << zoom
	start := int(tileIndex) * tileWidth
	end := start + tileWidth
	return windowRange{start: start, end: end}
}
