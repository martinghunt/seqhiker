package main

import (
	"errors"
	"fmt"
	"sort"
)

func (e *Engine) GetAnnotations(chrID uint16, start uint32, end uint32, maxRecords uint16, minFeatureLen uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	if end < start {
		return nil, errors.New("end must be >= start")
	}

	maxRecs := int(maxRecords)
	if maxRecs <= 0 {
		maxRecs = 2000
	}
	minLen := int(minFeatureLen)
	if minLen < 1 {
		minLen = 1
	}

	features := queryFeatures(e.features[chr], int(start), int(end), maxRecs, minLen)
	return encodeAnnotations(int(start), int(end), features), nil
}

func (e *Engine) GetAnnotationTile(chrID uint16, zoom uint8, tileIndex uint32, maxRecords uint16, minFeatureLen uint32) ([]byte, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	maxRecs := int(maxRecords)
	if maxRecs <= 0 {
		maxRecs = 2000
	}
	minLen := int(minFeatureLen)
	if minLen < 1 {
		minLen = 1
	}
	minLenForKey := min(minLen, 0xFFFF)
	key := tileCacheKey{
		Generation: e.globalGeneration,
		Kind:       annotTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
		Param:      (uint32(maxRecords) << 16) | uint32(minLenForKey),
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		return payload, nil
	}
	window := tileWindow(zoom, tileIndex)
	features := queryFeatures(e.features[chr], window.start, window.end, maxRecs, minLen)
	payload := encodeAnnotations(window.start, window.end, features)
	e.putCachedTileLocked(key, payload)
	return payload, nil
}

func queryFeatures(features []Feature, start, end, limit, minLen int) []Feature {
	if len(features) == 0 {
		return nil
	}
	if minLen < 1 {
		minLen = 1
	}
	idx := sort.Search(len(features), func(i int) bool {
		return features[i].End > start
	})
	out := make([]Feature, 0, min(limit, 256))
	for i := idx; i < len(features); i++ {
		feat := features[i]
		if feat.Start >= end {
			break
		}
		if feat.End <= start {
			continue
		}
		if feat.End-feat.Start < minLen {
			continue
		}
		out = append(out, feat)
		if len(out) >= limit {
			break
		}
	}
	return out
}
