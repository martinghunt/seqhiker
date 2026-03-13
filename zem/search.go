package main

import (
	"encoding/binary"
	"errors"
	"fmt"
	"strings"
)

func (e *Engine) GetReferenceSlice(chrID uint16, start uint32, end uint32) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}

	seq := e.sequences[chr]
	if seq == "" {
		return nil, fmt.Errorf("no sequence loaded for chromosome %s", chr)
	}

	s := int(start)
	eIdx := int(end)
	if eIdx < s {
		return nil, errors.New("end must be >= start")
	}
	if s < 0 {
		s = 0
	}
	if s > len(seq) {
		s = len(seq)
	}
	if eIdx > len(seq) {
		eIdx = len(seq)
	}

	slice := seq[s:eIdx]
	buf := make([]byte, 12+len(slice))
	binary.LittleEndian.PutUint32(buf[0:4], uint32(s))
	binary.LittleEndian.PutUint32(buf[4:8], uint32(eIdx))
	binary.LittleEndian.PutUint32(buf[8:12], uint32(len(slice)))
	copy(buf[12:], slice)
	return buf, nil
}

func (e *Engine) SearchDNAExact(chrID uint16, pattern string, includeRevComp bool, maxHits uint16) ([]byte, error) {
	e.mu.RLock()
	defer e.mu.RUnlock()

	chr, ok := e.idToChr[chrID]
	if !ok {
		return nil, fmt.Errorf("unknown chromosome id %d", chrID)
	}
	seq := e.sequences[chr]
	if seq == "" {
		return nil, fmt.Errorf("no sequence loaded for chromosome %s", chr)
	}
	pattern = strings.ToUpper(strings.TrimSpace(pattern))
	if pattern == "" {
		return nil, errors.New("search pattern must not be empty")
	}
	limit := int(maxHits)
	if limit <= 0 {
		limit = 5000
	}
	hits := make([]DNAExactHit, 0, min(limit, 256))
	truncated := false
	appendHits := func(query string, strand byte) bool {
		offset := 0
		for {
			at := strings.Index(seq[offset:], query)
			if at < 0 {
				return false
			}
			at += offset
			hits = append(hits, DNAExactHit{
				Start:  at,
				End:    at + len(query),
				Strand: strand,
			})
			if len(hits) >= limit {
				return true
			}
			offset = at + 1
			if offset >= len(seq) {
				return false
			}
		}
	}
	if appendHits(pattern, '+') {
		truncated = true
		return encodeDNAExactHits(truncated, hits), nil
	}
	if includeRevComp {
		rcPattern, ok := reverseComplementDNA(pattern)
		if ok && rcPattern != pattern && appendHits(rcPattern, '-') {
			truncated = true
			return encodeDNAExactHits(truncated, hits), nil
		}
	}
	return encodeDNAExactHits(truncated, hits), nil
}

func reverseComplementDNA(seq string) (string, bool) {
	out := make([]byte, len(seq))
	for i := 0; i < len(seq); i++ {
		switch seq[i] {
		case 'A':
			out[len(seq)-1-i] = 'T'
		case 'T':
			out[len(seq)-1-i] = 'A'
		case 'C':
			out[len(seq)-1-i] = 'G'
		case 'G':
			out[len(seq)-1-i] = 'C'
		default:
			return "", false
		}
	}
	return string(out), true
}
