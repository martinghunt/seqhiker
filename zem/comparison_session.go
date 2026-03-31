package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

var comparisonSessionMagic = []byte{'S', 'H', 'C', 'M', 'P', 0x01}

func isComparisonSessionFile(path string) (bool, error) {
	f, err := os.Open(path)
	if err != nil {
		return false, err
	}
	defer f.Close()
	header := make([]byte, len(comparisonSessionMagic))
	n, err := io.ReadFull(f, header)
	if err != nil {
		if err == io.EOF || err == io.ErrUnexpectedEOF {
			return false, nil
		}
		return false, err
	}
	return n == len(comparisonSessionMagic) && bytes.Equal(header, comparisonSessionMagic), nil
}

func (e *Engine) SaveComparisonSession(path string) error {
	e.mu.RLock()
	defer e.mu.RUnlock()

	if len(e.comparisonGenomeOrder) == 0 {
		return fmt.Errorf("no comparison genomes loaded")
	}

	var buf bytes.Buffer
	buf.Write(comparisonSessionMagic)
	writeU16(&buf, uint16(len(e.comparisonGenomeOrder)))
	for _, genomeID := range e.comparisonGenomeOrder {
		genome := e.comparisonGenomes[genomeID]
		if genome == nil {
			return fmt.Errorf("comparison genome %d missing", genomeID)
		}
		writeComparisonGenome(&buf, genome)
	}
	writeU16(&buf, uint16(len(e.comparisonPairOrder)))
	for _, pairID := range e.comparisonPairOrder {
		pair := e.comparisonPairs[pairID]
		if pair == nil {
			return fmt.Errorf("comparison pair %d missing", pairID)
		}
		writeComparisonPair(&buf, pair)
	}
	return os.WriteFile(path, buf.Bytes(), 0o644)
}

func (e *Engine) LoadComparisonSession(path string) error {
	f, err := os.Open(path)
	if err != nil {
		return err
	}
	defer f.Close()

	r := bufio.NewReader(f)
	header := make([]byte, len(comparisonSessionMagic))
	if _, err := io.ReadFull(r, header); err != nil {
		return err
	}
	if !bytes.Equal(header, comparisonSessionMagic) {
		return fmt.Errorf("not a seqhiker comparison session file")
	}

	genomeCount, err := readU16(r)
	if err != nil {
		return err
	}
	genomes := make([]*comparisonGenome, 0, int(genomeCount))
	order := make([]uint16, 0, int(genomeCount))
	var maxGenomeID uint16
	for i := 0; i < int(genomeCount); i++ {
		genome, err := readComparisonGenome(r)
		if err != nil {
			return err
		}
		genomes = append(genomes, genome)
		order = append(order, genome.ID)
		if genome.ID > maxGenomeID {
			maxGenomeID = genome.ID
		}
	}

	pairCount, err := readU16(r)
	if err != nil {
		return err
	}
	pairs := make([]*comparisonPair, 0, int(pairCount))
	pairOrder := make([]uint16, 0, int(pairCount))
	var maxPairID uint16
	seenGenomeIDs := make(map[uint16]bool, len(genomes))
	for _, genome := range genomes {
		seenGenomeIDs[genome.ID] = true
	}
	for i := 0; i < int(pairCount); i++ {
		pair, err := readComparisonPair(r)
		if err != nil {
			return err
		}
		if !seenGenomeIDs[pair.TopGenomeID] || !seenGenomeIDs[pair.BottomGenomeID] {
			return fmt.Errorf("comparison pair references unknown genome")
		}
		pairs = append(pairs, pair)
		pairOrder = append(pairOrder, pair.ID)
		if pair.ID > maxPairID {
			maxPairID = pair.ID
		}
	}

	e.mu.Lock()
	defer e.mu.Unlock()

	e.comparisonGenomes = make(map[uint16]*comparisonGenome, len(genomes))
	e.comparisonGenomeOrder = append(e.comparisonGenomeOrder[:0], order...)
	for _, genome := range genomes {
		e.comparisonGenomes[genome.ID] = genome
	}
	e.comparisonPairs = make(map[uint16]*comparisonPair, len(pairs))
	e.comparisonPairOrder = append(e.comparisonPairOrder[:0], pairOrder...)
	for _, pair := range pairs {
		e.comparisonPairs[pair.ID] = pair
	}
	e.nextComparisonGenomeID = maxGenomeID + 1
	if e.nextComparisonGenomeID == 0 {
		e.nextComparisonGenomeID = 1
	}
	e.nextComparisonPairID = maxPairID + 1
	if e.nextComparisonPairID == 0 {
		e.nextComparisonPairID = 1
	}
	return nil
}

func writeComparisonGenome(w io.Writer, genome *comparisonGenome) {
	writeU16(w, genome.ID)
	writeString(w, genome.Name)
	writeString(w, genome.Path)
	writeString(w, genome.Sequence)
	writeU32(w, uint32(genome.Length))
	writeU16(w, uint16(len(genome.Segments)))
	for _, segment := range genome.Segments {
		writeString(w, segment.Name)
		writeU32(w, uint32(segment.Start))
		writeU32(w, uint32(segment.End))
		writeU32(w, uint32(segment.FeatureCount))
	}
	writeU32(w, uint32(len(genome.Features)))
	for _, feature := range genome.Features {
		writeFeature(w, feature)
	}
}

func readComparisonGenome(r io.Reader) (*comparisonGenome, error) {
	id, err := readU16(r)
	if err != nil {
		return nil, err
	}
	name, err := readString(r)
	if err != nil {
		return nil, err
	}
	path, err := readString(r)
	if err != nil {
		return nil, err
	}
	sequence, err := readString(r)
	if err != nil {
		return nil, err
	}
	length, err := readU32(r)
	if err != nil {
		return nil, err
	}
	segmentCount, err := readU16(r)
	if err != nil {
		return nil, err
	}
	segments := make([]comparisonSegment, 0, int(segmentCount))
	for i := 0; i < int(segmentCount); i++ {
		segName, err := readString(r)
		if err != nil {
			return nil, err
		}
		start, err := readU32(r)
		if err != nil {
			return nil, err
		}
		end, err := readU32(r)
		if err != nil {
			return nil, err
		}
		featureCount, err := readU32(r)
		if err != nil {
			return nil, err
		}
		segments = append(segments, comparisonSegment{
			Name:         segName,
			Start:        int(start),
			End:          int(end),
			FeatureCount: int(featureCount),
		})
	}
	featureCount, err := readU32(r)
	if err != nil {
		return nil, err
	}
	features := make([]Feature, 0, int(featureCount))
	for i := 0; i < int(featureCount); i++ {
		feature, err := readFeature(r)
		if err != nil {
			return nil, err
		}
		features = append(features, feature)
	}
	return &comparisonGenome{
		ID:       id,
		Name:     name,
		Path:     path,
		Length:   int(length),
		Sequence: sequence,
		Segments: segments,
		Features: features,
	}, nil
}

func writeComparisonPair(w io.Writer, pair *comparisonPair) {
	writeU16(w, pair.ID)
	writeU16(w, pair.TopGenomeID)
	writeU16(w, pair.BottomGenomeID)
	writeU8(w, pair.Status)
	writeU32(w, uint32(len(pair.Blocks)))
	for _, block := range pair.Blocks {
		writeComparisonBlockDetail(w, block)
	}
}

func readComparisonPair(r io.Reader) (*comparisonPair, error) {
	id, err := readU16(r)
	if err != nil {
		return nil, err
	}
	topID, err := readU16(r)
	if err != nil {
		return nil, err
	}
	bottomID, err := readU16(r)
	if err != nil {
		return nil, err
	}
	status, err := readU8(r)
	if err != nil {
		return nil, err
	}
	blockCount, err := readU32(r)
	if err != nil {
		return nil, err
	}
	blocks := make([]comparisonBlockDetail, 0, int(blockCount))
	for i := 0; i < int(blockCount); i++ {
		block, err := readComparisonBlockDetail(r)
		if err != nil {
			return nil, err
		}
		blocks = append(blocks, block)
	}
	return &comparisonPair{
		ID:             id,
		TopGenomeID:    topID,
		BottomGenomeID: bottomID,
		Status:         status,
		Blocks:         blocks,
	}, nil
}

func writeComparisonBlockDetail(w io.Writer, block comparisonBlockDetail) {
	writeU32(w, block.Summary.QueryStart)
	writeU32(w, block.Summary.QueryEnd)
	writeU32(w, block.Summary.TargetStart)
	writeU32(w, block.Summary.TargetEnd)
	writeU16(w, block.Summary.PercentIdentX100)
	if block.Summary.SameStrand {
		writeU8(w, 1)
	} else {
		writeU8(w, 0)
	}
	writeU32(w, uint32(len(block.Variants)))
	for _, variant := range block.Variants {
		writeU8(w, variant.Kind)
		writeU32(w, variant.QueryPos)
		writeU32(w, variant.TargetPos)
		writeString(w, variant.RefBases)
		writeString(w, variant.AltBases)
	}
}

func readComparisonBlockDetail(r io.Reader) (comparisonBlockDetail, error) {
	qStart, err := readU32(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	qEnd, err := readU32(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	tStart, err := readU32(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	tEnd, err := readU32(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	pid, err := readU16(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	sameStrandByte, err := readU8(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	variantCount, err := readU32(r)
	if err != nil {
		return comparisonBlockDetail{}, err
	}
	variants := make([]comparisonVariant, 0, int(variantCount))
	for i := 0; i < int(variantCount); i++ {
		kind, err := readU8(r)
		if err != nil {
			return comparisonBlockDetail{}, err
		}
		qPos, err := readU32(r)
		if err != nil {
			return comparisonBlockDetail{}, err
		}
		tPos, err := readU32(r)
		if err != nil {
			return comparisonBlockDetail{}, err
		}
		refBases, err := readString(r)
		if err != nil {
			return comparisonBlockDetail{}, err
		}
		altBases, err := readString(r)
		if err != nil {
			return comparisonBlockDetail{}, err
		}
		variants = append(variants, comparisonVariant{
			Kind:      kind,
			QueryPos:  qPos,
			TargetPos: tPos,
			RefBases:  refBases,
			AltBases:  altBases,
		})
	}
	return comparisonBlockDetail{
		Summary: ComparisonBlock{
			QueryStart:       qStart,
			QueryEnd:         qEnd,
			TargetStart:      tStart,
			TargetEnd:        tEnd,
			PercentIdentX100: pid,
			SameStrand:       sameStrandByte != 0,
		},
		Variants: variants,
	}, nil
}

func writeFeature(w io.Writer, feature Feature) {
	writeString(w, feature.SeqName)
	writeString(w, feature.Source)
	writeString(w, feature.Type)
	writeU32(w, uint32(feature.Start))
	writeU32(w, uint32(feature.End))
	writeU8(w, feature.Strand)
	writeString(w, feature.Attributes)
}

func readFeature(r io.Reader) (Feature, error) {
	seqName, err := readString(r)
	if err != nil {
		return Feature{}, err
	}
	source, err := readString(r)
	if err != nil {
		return Feature{}, err
	}
	typ, err := readString(r)
	if err != nil {
		return Feature{}, err
	}
	start, err := readU32(r)
	if err != nil {
		return Feature{}, err
	}
	end, err := readU32(r)
	if err != nil {
		return Feature{}, err
	}
	strand, err := readU8(r)
	if err != nil {
		return Feature{}, err
	}
	attrs, err := readString(r)
	if err != nil {
		return Feature{}, err
	}
	return Feature{
		SeqName:    seqName,
		Source:     source,
		Type:       typ,
		Start:      int(start),
		End:        int(end),
		Strand:     strand,
		Attributes: attrs,
	}, nil
}

func writeU8(w io.Writer, value uint8) {
	_, _ = w.Write([]byte{value})
}

func writeU16(w io.Writer, value uint16) {
	_ = binary.Write(w, binary.LittleEndian, value)
}

func writeU32(w io.Writer, value uint32) {
	_ = binary.Write(w, binary.LittleEndian, value)
}

func writeString(w io.Writer, value string) {
	writeU32(w, uint32(len(value)))
	_, _ = io.WriteString(w, value)
}

func readU8(r io.Reader) (uint8, error) {
	var value [1]byte
	_, err := io.ReadFull(r, value[:])
	return value[0], err
}

func readU16(r io.Reader) (uint16, error) {
	var value uint16
	err := binary.Read(r, binary.LittleEndian, &value)
	return value, err
}

func readU32(r io.Reader) (uint32, error) {
	var value uint32
	err := binary.Read(r, binary.LittleEndian, &value)
	return value, err
}

func readString(r io.Reader) (string, error) {
	n, err := readU32(r)
	if err != nil {
		return "", err
	}
	if n == 0 {
		return "", nil
	}
	buf := make([]byte, int(n))
	if _, err := io.ReadFull(r, buf); err != nil {
		return "", err
	}
	return string(buf), nil
}
