package main

import (
	"bufio"
	"crypto/sha256"
	"encoding/binary"
	"encoding/hex"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

var comparisonDetailCacheMagic = [8]byte{'Z', 'C', 'M', 'P', 'D', 'T', 'L', '1'}

const comparisonDetailCacheVersion = 2

type comparisonDetailIndexEntry struct {
	Offset int64
}

func defaultComparisonCacheDir() string {
	if root, err := os.UserCacheDir(); err == nil && root != "" {
		return filepath.Join(root, "seqhiker", "comparison")
	}
	return filepath.Join(os.TempDir(), "seqhiker-comparison")
}

func comparisonBlockKey(block ComparisonBlock) string {
	same := 0
	if block.SameStrand {
		same = 1
	}
	return fmt.Sprintf("%d:%d:%d:%d:%d", block.QueryStart, block.QueryEnd, block.TargetStart, block.TargetEnd, same)
}

func comparisonDetailCachePath(cacheDir string, query, target *comparisonGenome) string {
	h := sha256.New()
	io.WriteString(h, ZemVersion)
	h.Write([]byte{0})
	io.WriteString(h, fmt.Sprintf("%d:%d:%d:%d:%d:%d:%d:%d:%d\n",
		comparisonDetailCacheVersion,
		comparisonMinimizerK,
		comparisonMinimizerWindow,
		comparisonMaxSeedHits,
		comparisonMaxAnchorGap,
		comparisonMaxDiagonalDrift,
		comparisonChainMergeGapMaxSpan,
		comparisonChainMergeOverlapMaxSpan,
		comparisonRefineGapMaxSpan,
	))
	h.Write([]byte{0})
	io.WriteString(h, query.Name)
	h.Write([]byte{0})
	io.WriteString(h, query.Sequence)
	h.Write([]byte{0xff})
	io.WriteString(h, target.Name)
	h.Write([]byte{0})
	io.WriteString(h, target.Sequence)
	return filepath.Join(cacheDir, hex.EncodeToString(h.Sum(nil))+".zcmpdtl")
}

func (e *Engine) ensureComparisonPairDetailCacheLocked(pair *comparisonPair, query, target *comparisonGenome) error {
	if pair == nil || query == nil || target == nil {
		return nil
	}
	if len(pair.Blocks) == 0 {
		pair.DetailPath = ""
		pair.DetailIndex = nil
		return nil
	}
	cachePath := comparisonDetailCachePath(e.comparisonCacheDir, query, target)
	if idx, err := loadComparisonDetailIndex(cachePath); err == nil {
		pair.DetailPath = cachePath
		pair.DetailIndex = idx
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(cachePath), 0o755); err != nil {
		return err
	}
	pair.DetailPath = cachePath
	if _, err := os.Stat(cachePath); os.IsNotExist(err) {
		details := buildComparisonBlockDetails(query, target)
		idx, err := writeComparisonDetailCache(cachePath, details)
		if err != nil {
			return err
		}
		pair.DetailIndex = idx
		return nil
	}
	if idx, err := loadComparisonDetailIndex(cachePath); err == nil {
		pair.DetailIndex = idx
		return nil
	}
	pair.DetailIndex = map[string]comparisonDetailIndexEntry{}
	return nil
}

func writeComparisonDetailCache(path string, details []comparisonBlockDetail) (map[string]comparisonDetailIndexEntry, error) {
	tmpPath := path + ".tmp"
	f, err := os.Create(tmpPath)
	if err != nil {
		return nil, err
	}
	w := bufio.NewWriter(f)
	if _, err := w.Write(comparisonDetailCacheMagic[:]); err != nil {
		f.Close()
		_ = os.Remove(tmpPath)
		return nil, err
	}
	index := make(map[string]comparisonDetailIndexEntry, len(details))
	offset := int64(len(comparisonDetailCacheMagic))
	for _, detail := range details {
		index[comparisonBlockKey(detail.Summary)] = comparisonDetailIndexEntry{Offset: offset}
		n, err := writeComparisonDetailRecord(w, detail.info())
		if err != nil {
			f.Close()
			_ = os.Remove(tmpPath)
			return nil, err
		}
		offset += int64(n)
	}
	if err := w.Flush(); err != nil {
		f.Close()
		_ = os.Remove(tmpPath)
		return nil, err
	}
	if err := f.Close(); err != nil {
		_ = os.Remove(tmpPath)
		return nil, err
	}
	if err := os.Rename(tmpPath, path); err != nil {
		_ = os.Remove(tmpPath)
		return nil, err
	}
	return index, nil
}

func loadComparisonDetailIndex(path string) (map[string]comparisonDetailIndexEntry, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var magic [8]byte
	if _, err := io.ReadFull(f, magic[:]); err != nil {
		return nil, err
	}
	if magic != comparisonDetailCacheMagic {
		return nil, fmt.Errorf("not a comparison detail cache")
	}
	index := map[string]comparisonDetailIndexEntry{}
	offset := int64(len(magic))
	for {
		detail, n, err := readComparisonDetailRecordAt(f, offset)
		if err == io.EOF {
			break
		}
		if err != nil {
			return nil, err
		}
		index[comparisonBlockKey(detail.Block)] = comparisonDetailIndexEntry{Offset: offset}
		offset += int64(n)
	}
	return index, nil
}

func readComparisonDetailFromPairCache(pair *comparisonPair, block ComparisonBlock) (ComparisonBlockDetail, bool, error) {
	if pair == nil || pair.DetailPath == "" || len(pair.DetailIndex) == 0 {
		return ComparisonBlockDetail{}, false, nil
	}
	entry, ok := pair.DetailIndex[comparisonBlockKey(block)]
	if !ok {
		return ComparisonBlockDetail{}, false, nil
	}
	f, err := os.Open(pair.DetailPath)
	if err != nil {
		return ComparisonBlockDetail{}, false, err
	}
	defer f.Close()
	detail, _, err := readComparisonDetailRecordAt(f, entry.Offset)
	if err != nil {
		return ComparisonBlockDetail{}, false, err
	}
	return detail, true, nil
}

func appendComparisonDetailToPairCache(pair *comparisonPair, block ComparisonBlock, detail ComparisonBlockDetail) error {
	if pair == nil {
		return nil
	}
	if pair.DetailIndex == nil {
		pair.DetailIndex = map[string]comparisonDetailIndexEntry{}
	}
	if pair.DetailPath == "" {
		return fmt.Errorf("comparison detail cache path not set")
	}
	if _, ok := pair.DetailIndex[comparisonBlockKey(block)]; ok {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(pair.DetailPath), 0o755); err != nil {
		return err
	}
	var offset int64
	if info, err := os.Stat(pair.DetailPath); err == nil {
		offset = info.Size()
	} else if os.IsNotExist(err) {
		f, err := os.Create(pair.DetailPath)
		if err != nil {
			return err
		}
		if _, err := f.Write(comparisonDetailCacheMagic[:]); err != nil {
			f.Close()
			return err
		}
		if err := f.Close(); err != nil {
			return err
		}
		offset = int64(len(comparisonDetailCacheMagic))
	} else {
		return err
	}
	f, err := os.OpenFile(pair.DetailPath, os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		return err
	}
	defer f.Close()
	w := bufio.NewWriter(f)
	n, err := writeComparisonDetailRecord(w, detail)
	if err != nil {
		return err
	}
	if err := w.Flush(); err != nil {
		return err
	}
	pair.DetailIndex[comparisonBlockKey(block)] = comparisonDetailIndexEntry{Offset: offset}
	_ = n
	return nil
}

func writeComparisonDetailRecord(w io.Writer, detail ComparisonBlockDetail) (int, error) {
	buf := make([]byte, 0, 23+4+len(detail.Ops))
	tmp := make([]byte, 4)
	binary.LittleEndian.PutUint32(tmp, detail.Block.QueryStart)
	buf = append(buf, tmp...)
	binary.LittleEndian.PutUint32(tmp, detail.Block.QueryEnd)
	buf = append(buf, tmp...)
	binary.LittleEndian.PutUint32(tmp, detail.Block.TargetStart)
	buf = append(buf, tmp...)
	binary.LittleEndian.PutUint32(tmp, detail.Block.TargetEnd)
	buf = append(buf, tmp...)
	tmp2 := make([]byte, 2)
	binary.LittleEndian.PutUint16(tmp2, detail.Block.PercentIdentX100)
	buf = append(buf, tmp2...)
	if detail.Block.SameStrand {
		buf = append(buf, 1)
	} else {
		buf = append(buf, 0)
	}
	binary.LittleEndian.PutUint32(tmp, uint32(len(detail.Ops)))
	buf = append(buf, tmp...)
	buf = append(buf, []byte(detail.Ops)...)
	n, err := w.Write(buf)
	return n, err
}

func readComparisonDetailRecordAt(r io.ReaderAt, offset int64) (ComparisonBlockDetail, int, error) {
	header := make([]byte, 23)
	n, err := r.ReadAt(header, offset)
	if err != nil {
		if err == io.EOF && n == 0 {
			return ComparisonBlockDetail{}, 0, io.EOF
		}
		return ComparisonBlockDetail{}, 0, err
	}
	if n != len(header) {
		return ComparisonBlockDetail{}, 0, io.ErrUnexpectedEOF
	}
	block := ComparisonBlock{
		QueryStart:       binary.LittleEndian.Uint32(header[0:4]),
		QueryEnd:         binary.LittleEndian.Uint32(header[4:8]),
		TargetStart:      binary.LittleEndian.Uint32(header[8:12]),
		TargetEnd:        binary.LittleEndian.Uint32(header[12:16]),
		PercentIdentX100: binary.LittleEndian.Uint16(header[16:18]),
		SameStrand:       header[18] != 0,
	}
	opsLen := int(binary.LittleEndian.Uint32(header[19:23]))
	opsBytes := make([]byte, opsLen)
	if opsLen > 0 {
		if _, err := r.ReadAt(opsBytes, offset+int64(len(header))); err != nil {
			return ComparisonBlockDetail{}, 0, err
		}
	}
	variants := affineAlignment{Ops: opsBytes}.variantsForBlock(block)
	return ComparisonBlockDetail{
		Block:    block,
		Ops:      string(opsBytes),
		Variants: variantsToInfo(variants),
	}, len(header) + opsLen, nil
}

func variantsToInfo(vars []comparisonVariant) []ComparisonVariantInfo {
	out := make([]ComparisonVariantInfo, 0, len(vars))
	for _, v := range vars {
		out = append(out, ComparisonVariantInfo{
			Kind:      v.Kind,
			QueryPos:  v.QueryPos,
			TargetPos: v.TargetPos,
			RefBases:  v.RefBases,
			AltBases:  v.AltBases,
		})
	}
	return out
}

func swappedComparisonBlockDetail(detail ComparisonBlockDetail) ComparisonBlockDetail {
	ops := []byte(detail.Ops)
	for i, op := range ops {
		switch op {
		case 'I':
			ops[i] = 'D'
		case 'D':
			ops[i] = 'I'
		}
	}
	variants := make([]ComparisonVariantInfo, 0, len(detail.Variants))
	for _, v := range detail.Variants {
		kind := v.Kind
		switch kind {
		case 'I':
			kind = 'D'
		case 'D':
			kind = 'I'
		}
		variants = append(variants, ComparisonVariantInfo{
			Kind:      kind,
			QueryPos:  v.TargetPos,
			TargetPos: v.QueryPos,
			RefBases:  v.AltBases,
			AltBases:  v.RefBases,
		})
	}
	return ComparisonBlockDetail{
		Block:    swappedComparisonBlock(detail.Block),
		Ops:      string(ops),
		Variants: variants,
	}
}
