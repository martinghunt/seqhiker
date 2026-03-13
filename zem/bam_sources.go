package main

import (
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"strings"

	"github.com/biogo/hts/bam"
	"github.com/biogo/hts/sam"
)

type bamSource struct {
	ID           uint16
	Path         string
	IndexPath    string
	Generation   uint64
	Index        *bam.Index
	Refs         map[string]*sam.Reference
	RefByChrID   map[uint16]*sam.Reference
	RefNameToID  map[string]uint16
	CovPrefixFwd map[uint16][]uint64
	CovPrefixRev map[uint16][]uint64
	CovReady     bool
}

func (e *Engine) LoadBAM(path string, precomputeCutoffBP int) (uint16, error) {
	bamFile, err := os.Open(path)
	if err != nil {
		return 0, err
	}
	defer bamFile.Close()

	reader, err := bam.NewReader(bamFile, 0)
	if err != nil {
		return 0, err
	}
	defer reader.Close()

	idxPath, err := resolveBAMIndexPath(path)
	if err != nil {
		return 0, err
	}

	idxFile, err := os.Open(idxPath)
	if err != nil {
		return 0, err
	}
	defer idxFile.Close()

	idx, err := bam.ReadIndex(idxFile)
	if err != nil {
		return 0, fmt.Errorf("failed to read BAM index %s: %w", idxPath, err)
	}

	refs := make(map[string]*sam.Reference)
	totalRefLen := 0
	headerRefs := reader.Header().Refs()
	for _, ref := range headerRefs {
		if ref == nil {
			continue
		}
		refs[ref.Name()] = ref
		totalRefLen += max(0, ref.Len())
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	refByChrID := make(map[uint16]*sam.Reference, len(refs))
	refNameToID := make(map[string]uint16, len(refs))
	for _, ref := range headerRefs {
		if ref == nil {
			continue
		}
		chrID := e.resolveBAMRefChromIDLocked(ref.Name(), ref.Len())
		refByChrID[chrID] = ref
		refNameToID[ref.Name()] = chrID
	}
	sourceID := e.nextBAMSourceID
	e.nextBAMSourceID++
	if e.nextBAMSourceID == 0 {
		e.nextBAMSourceID = 1
	}
	shouldPrecomputeCov := precomputeCutoffBP > 0 && totalRefLen > 0 && totalRefLen <= precomputeCutoffBP
	e.bamSources[sourceID] = &bamSource{
		ID:           sourceID,
		Path:         path,
		IndexPath:    idxPath,
		Generation:   e.globalGeneration + 1,
		Index:        idx,
		Refs:         refs,
		RefByChrID:   refByChrID,
		RefNameToID:  refNameToID,
		CovPrefixFwd: map[uint16][]uint64{},
		CovPrefixRev: map[uint16][]uint64{},
		CovReady:     !shouldPrecomputeCov,
	}
	e.bamOrder = append(e.bamOrder, sourceID)
	e.globalGeneration++
	e.resetTileCacheLocked()

	if shouldPrecomputeCov {
		go e.precomputeCoverageForSource(sourceID, path, headerRefs)
	}

	return sourceID, nil
}

func (e *Engine) ensureChromosomeLocked(name string, length int) uint16 {
	if id, ok := e.chrToID[name]; ok {
		if e.chrLength[name] < length {
			e.chrLength[name] = length
		}
		return id
	}
	id := uint16(len(e.chromOrder))
	e.chromOrder = append(e.chromOrder, name)
	e.chrToID[name] = id
	e.idToChr[id] = name
	e.chrLength[name] = length
	return id
}

func (e *Engine) resolveBAMRefChromIDLocked(name string, length int) uint16 {
	if id, ok := e.chrToID[name]; ok {
		if e.chrLength[name] < length {
			e.chrLength[name] = length
		}
		return id
	}
	normalized := normalizeChromAlias(name)
	for _, chr := range e.chromOrder {
		if e.chrLength[chr] != length {
			continue
		}
		if normalizeChromAlias(chr) != normalized {
			continue
		}
		return e.chrToID[chr]
	}
	return e.ensureChromosomeLocked(name, length)
}

func normalizeChromAlias(name string) string {
	dot := strings.LastIndex(name, ".")
	if dot <= 0 || dot >= len(name)-1 {
		return name
	}
	suffix := name[dot+1:]
	for _, r := range suffix {
		if r < '0' || r > '9' {
			return name
		}
	}
	return name[:dot]
}

func resolveBAMIndexPath(bamPath string) (string, error) {
	candidates := []string{
		bamPath + ".bai",
		strings.TrimSuffix(bamPath, filepath.Ext(bamPath)) + ".bai",
	}
	for _, p := range candidates {
		if _, err := os.Stat(p); err == nil {
			return p, nil
		}
	}
	return "", fmt.Errorf("BAM index not found; expected %s or %s", candidates[0], candidates[1])
}

func (e *Engine) precomputeCoverageForSource(sourceID uint16, bamPath string, refs []*sam.Reference) {
	covPrefixByName, err := buildCoveragePrefixSums(bamPath, refs)
	if err != nil {
		log.Printf("coverage precompute failed for source %d: %v", sourceID, err)
		e.mu.Lock()
		if src, ok := e.bamSources[sourceID]; ok {
			src.CovReady = true
		}
		e.mu.Unlock()
		return
	}

	e.mu.Lock()
	defer e.mu.Unlock()
	src, ok := e.bamSources[sourceID]
	if !ok {
		return
	}
	for chrName, prefix := range covPrefixByName {
		if chrID, ok := src.RefNameToID[chrName]; ok {
			src.CovPrefixFwd[chrID] = prefix.Forward
			src.CovPrefixRev[chrID] = prefix.Reverse
		}
	}
	src.CovReady = true
}

type strandCoveragePrefix struct {
	Forward []uint64
	Reverse []uint64
}

func buildCoveragePrefixSums(bamPath string, refs []*sam.Reference) (map[string]strandCoveragePrefix, error) {
	if len(refs) == 0 {
		return map[string]strandCoveragePrefix{}, nil
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

	diffFwdByRefID := make(map[int][]int32, len(refs))
	diffRevByRefID := make(map[int][]int32, len(refs))
	refNameByID := make(map[int]string, len(refs))
	for _, ref := range refs {
		if ref == nil {
			continue
		}
		rid := ref.ID()
		if rid < 0 {
			continue
		}
		diffFwdByRefID[rid] = make([]int32, ref.Len()+1)
		diffRevByRefID[rid] = make([]int32, ref.Len()+1)
		refNameByID[rid] = ref.Name()
	}

	for {
		rec, err := reader.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		if rec == nil || rec.Ref == nil {
			continue
		}
		rid := rec.Ref.ID()
		diffMap := diffFwdByRefID
		if rec.Flags&sam.Reverse != 0 {
			diffMap = diffRevByRefID
		}
		diff := diffMap[rid]
		if len(diff) == 0 {
			continue
		}
		s := rec.Start()
		e := rec.End()
		if s < 0 {
			s = 0
		}
		if e < s {
			e = s
		}
		if e > len(diff)-1 {
			e = len(diff) - 1
		}
		if s >= e {
			continue
		}
		diff[s]++
		diff[e]--
	}

	out := make(map[string]strandCoveragePrefix, len(diffFwdByRefID))
	for rid := range diffFwdByRefID {
		name := refNameByID[rid]
		diffFwd := diffFwdByRefID[rid]
		diffRev := diffRevByRefID[rid]
		if name == "" || len(diffFwd) == 0 || len(diffRev) == 0 {
			continue
		}
		prefixFwd := make([]uint64, len(diffFwd))
		prefixRev := make([]uint64, len(diffRev))
		var depthFwd int64
		var depthRev int64
		for i := 0; i < len(diffFwd)-1; i++ {
			depthFwd += int64(diffFwd[i])
			if depthFwd < 0 {
				depthFwd = 0
			}
			prefixFwd[i+1] = prefixFwd[i] + uint64(depthFwd)
			depthRev += int64(diffRev[i])
			if depthRev < 0 {
				depthRev = 0
			}
			prefixRev[i+1] = prefixRev[i] + uint64(depthRev)
		}
		out[name] = strandCoveragePrefix{Forward: prefixFwd, Reverse: prefixRev}
	}
	return out, nil
}
