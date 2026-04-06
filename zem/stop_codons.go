package zem

import "fmt"

func (e *Engine) GetStopCodonTile(chrID uint16, zoom uint8, tileIndex uint32) ([]byte, error) {
	e.mu.Lock()
	defer e.mu.Unlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	key := tileCacheKey{
		Generation: e.globalGeneration,
		Kind:       stopCodonTileCacheKind,
		ChrID:      chrID,
		Zoom:       zoom,
		TileIndex:  tileIndex,
	}
	if payload, ok := e.getCachedTileLocked(key); ok {
		return payload, nil
	}
	window := tileWindow(zoom, tileIndex)
	seq := e.sequences[chr]
	if window.start < 0 {
		window.start = 0
	}
	if window.start > len(seq) {
		window.start = len(seq)
	}
	if window.end > len(seq) {
		window.end = len(seq)
	}
	if window.end < window.start {
		window.end = window.start
	}
	payload := encodeStopCodonTile(window.start, window.end, buildStopCodonBins(seq, window.start, window.end, stopCodonTileBins))
	e.putCachedTileLocked(key, payload)
	return payload, nil
}

func buildStopCodonBins(seq string, start, end, binCount int) [6][]byte {
	var frames [6][]byte
	for i := range frames {
		frames[i] = make([]byte, max(binCount, 0))
	}
	if len(seq) < 3 || end-start < 3 || binCount <= 0 {
		return frames
	}
	seqLen := len(seq)
	if start < 0 {
		start = 0
	}
	if end > seqLen {
		end = seqLen
	}
	if end <= start {
		return frames
	}
	span := max(1, end-start)
	mark := func(frame, centerBP int) {
		if centerBP < start || centerBP >= end {
			return
		}
		bin := ((centerBP - start) * binCount) / span
		if bin < 0 {
			bin = 0
		}
		if bin >= binCount {
			bin = binCount - 1
		}
		frames[frame][bin] = 1
	}
	for frame := 0; frame < 3; frame++ {
		firstBP := start + posMod(frame-posMod(start, 3), 3)
		lastBP := end - 3
		if lastBP < firstBP {
			continue
		}
		for bp := firstBP; bp <= lastBP; bp += 3 {
			b0 := normalizeDNAByte(seq[bp])
			b1 := normalizeDNAByte(seq[bp+1])
			b2 := normalizeDNAByte(seq[bp+2])
			if isStopCodonBytes(b0, b1, b2) {
				mark(frame, bp+1)
			}
			if isStopCodonBytes(complementBaseByte(b2), complementBaseByte(b1), complementBaseByte(b0)) {
				mark(3+frame, bp+1)
			}
		}
	}
	return frames
}

func encodeStopCodonTile(start, end int, frames [6][]byte) []byte {
	binCount := 0
	if len(frames[0]) > 0 {
		binCount = len(frames[0])
	}
	total := 13 + 6*binCount
	buf := make([]byte, total)
	buf[0] = 5
	putU32(buf[1:5], uint32(start))
	putU32(buf[5:9], uint32(end))
	putU32(buf[9:13], uint32(binCount))
	off := 13
	for frame := 0; frame < 6; frame++ {
		copy(buf[off:off+binCount], frames[frame])
		off += binCount
	}
	return buf
}

func posMod(x, m int) int {
	r := x % m
	if r < 0 {
		r += m
	}
	return r
}

func normalizeDNAByte(b byte) byte {
	switch b {
	case 'a', 'A':
		return 'A'
	case 'c', 'C':
		return 'C'
	case 'g', 'G':
		return 'G'
	case 't', 'T', 'u', 'U':
		return 'T'
	default:
		return 'N'
	}
}

func complementBaseByte(b byte) byte {
	switch b {
	case 'A':
		return 'T'
	case 'C':
		return 'G'
	case 'G':
		return 'C'
	case 'T':
		return 'A'
	default:
		return 'N'
	}
}

func isStopCodonBytes(b0, b1, b2 byte) bool {
	return b0 == 'T' && b1 == 'A' && (b2 == 'A' || b2 == 'G') || b0 == 'T' && b1 == 'G' && b2 == 'A'
}

func putU32(dst []byte, v uint32) {
	dst[0] = byte(v)
	dst[1] = byte(v >> 8)
	dst[2] = byte(v >> 16)
	dst[3] = byte(v >> 24)
}
