package main

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"os"
)

var comparisonSessionMagicV1 = []byte{'S', 'H', 'C', 'M', 'P', 0x01}
var comparisonSessionMagicV2 = []byte{'S', 'H', 'C', 'M', 'P', 0x02}
var comparisonSessionMagic = []byte{'S', 'H', 'C', 'M', 'P', 0x03}

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
	return n == len(comparisonSessionMagic) && (bytes.Equal(header, comparisonSessionMagic) || bytes.Equal(header, comparisonSessionMagicV2) || bytes.Equal(header, comparisonSessionMagicV1)), nil
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
	sessionVersion := 0
	switch {
	case bytes.Equal(header, comparisonSessionMagic):
		sessionVersion = 3
	case bytes.Equal(header, comparisonSessionMagicV2):
		sessionVersion = 2
	case bytes.Equal(header, comparisonSessionMagicV1):
		sessionVersion = 1
	default:
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
		genome, err := readComparisonGenome(r, sessionVersion)
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
		pair, err := readComparisonPair(r, sessionVersion)
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
	serialGenome := genome
	if comparisonGenomeNeedsRawMaterial(genome) {
		clone := *genome
		clone.Segments = append([]comparisonSegment(nil), genome.Segments...)
		populateRawComparisonSegments(&clone)
		serialGenome = &clone
	}
	writeU16(w, serialGenome.ID)
	writeString(w, serialGenome.Name)
	writeString(w, serialGenome.Path)
	writeString(w, serialGenome.Sequence)
	writeU32(w, uint32(serialGenome.Length))
	writeU16(w, uint16(len(serialGenome.Segments)))
	for _, segment := range serialGenome.Segments {
		writeString(w, segment.Name)
		writeU32(w, uint32(segment.Start))
		writeU32(w, uint32(segment.End))
		writeU32(w, uint32(segment.FeatureCount))
	}
	writeU32(w, uint32(len(serialGenome.Features)))
	for _, feature := range serialGenome.Features {
		writeFeature(w, feature)
	}
	writeU16(w, uint16(len(serialGenome.Segments)))
	for _, segment := range serialGenome.Segments {
		writeString(w, segment.RawSequence)
		if segment.Reversed {
			writeU8(w, 1)
		} else {
			writeU8(w, 0)
		}
		writeU32(w, uint32(len(segment.RawFeatures)))
		for _, feature := range segment.RawFeatures {
			writeFeature(w, feature)
		}
	}
}

func comparisonGenomeNeedsRawMaterial(genome *comparisonGenome) bool {
	if genome == nil {
		return false
	}
	for _, segment := range genome.Segments {
		if segment.RawSequence == "" && segment.End > segment.Start {
			return true
		}
	}
	return false
}

func readComparisonGenome(r io.Reader, sessionVersion int) (*comparisonGenome, error) {
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
	genome := &comparisonGenome{
		ID:       id,
		Name:     name,
		Path:     path,
		Length:   int(length),
		Sequence: sequence,
		Segments: segments,
		Features: features,
	}
	if sessionVersion >= 2 {
		rawSegmentCount, err := readU16(r)
		if err != nil {
			return nil, err
		}
		if int(rawSegmentCount) != len(genome.Segments) {
			return nil, fmt.Errorf("comparison session raw segment count mismatch")
		}
		for i := range genome.Segments {
			rawSeq, err := readString(r)
			if err != nil {
				return nil, err
			}
			reversed, err := readU8(r)
			if err != nil {
				return nil, err
			}
			rawFeatureCount, err := readU32(r)
			if err != nil {
				return nil, err
			}
			rawFeatures := make([]Feature, 0, int(rawFeatureCount))
			for j := 0; j < int(rawFeatureCount); j++ {
				feature, err := readFeature(r)
				if err != nil {
					return nil, err
				}
				rawFeatures = append(rawFeatures, feature)
			}
			genome.Segments[i].RawSequence = rawSeq
			genome.Segments[i].RawFeatures = rawFeatures
			genome.Segments[i].Reversed = reversed != 0
		}
	} else {
		populateRawComparisonSegments(genome)
	}
	genome.rebuildDerived()
	return genome, nil
}

func populateRawComparisonSegments(genome *comparisonGenome) {
	if genome == nil {
		return
	}
	for i := range genome.Segments {
		segment := &genome.Segments[i]
		if segment.Start >= 0 && segment.End <= len(genome.Sequence) && segment.End >= segment.Start {
			segment.RawSequence = genome.Sequence[segment.Start:segment.End]
			if segment.Reversed {
				segment.RawSequence = reverseComplementString(segment.RawSequence)
			}
		}
		segment.RawFeatures = segment.RawFeatures[:0]
		for _, feature := range genome.Features {
			if feature.Start < segment.Start || feature.End > segment.End {
				continue
			}
			rawFeature := feature
			rawFeature.Start -= segment.Start
			rawFeature.End -= segment.Start
			rawFeature.SeqName = segment.Name
			if segment.Reversed {
				rawFeature = reverseFeatureForLength(rawFeature, len(segment.RawSequence))
				rawFeature.SeqName = segment.Name
			}
			segment.RawFeatures = append(segment.RawFeatures, rawFeature)
		}
	}
}

func writeComparisonPair(w io.Writer, pair *comparisonPair) {
	writeU16(w, pair.ID)
	writeU16(w, pair.TopGenomeID)
	writeU16(w, pair.BottomGenomeID)
	writeU8(w, pair.Status)
	writeU32(w, uint32(len(pair.CanonicalBlocks)))
	for _, block := range pair.CanonicalBlocks {
		writeComparisonCanonicalBlock(w, block)
	}
}

func readComparisonPair(r io.Reader, sessionVersion int) (*comparisonPair, error) {
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
	canonicalBlocks := make([]comparisonCanonicalBlock, 0, int(blockCount))
	if sessionVersion >= 3 {
		for i := 0; i < int(blockCount); i++ {
			block, err := readComparisonCanonicalBlock(r)
			if err != nil {
				return nil, err
			}
			canonicalBlocks = append(canonicalBlocks, block)
		}
	} else {
		for i := 0; i < int(blockCount); i++ {
			if _, err := readComparisonBlock(r); err != nil {
				return nil, err
			}
		}
		status = comparisonStatusPending
	}
	return &comparisonPair{
		ID:              id,
		TopGenomeID:     topID,
		BottomGenomeID:  bottomID,
		Status:          status,
		CanonicalBlocks: canonicalBlocks,
	}, nil
}

func writeComparisonCanonicalBlock(w io.Writer, block comparisonCanonicalBlock) {
	writeU16(w, uint16(block.QuerySegment))
	writeU32(w, uint32(block.QueryStart))
	writeU32(w, uint32(block.QueryEnd))
	writeU16(w, uint16(block.TargetSegment))
	writeU32(w, uint32(block.TargetStart))
	writeU32(w, uint32(block.TargetEnd))
	writeU16(w, block.PercentIdentX100)
	if block.SameStrand {
		writeU8(w, 1)
	} else {
		writeU8(w, 0)
	}
}

func readComparisonCanonicalBlock(r io.Reader) (comparisonCanonicalBlock, error) {
	querySegment, err := readU16(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	queryStart, err := readU32(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	queryEnd, err := readU32(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	targetSegment, err := readU16(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	targetStart, err := readU32(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	targetEnd, err := readU32(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	pid, err := readU16(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	sameStrandByte, err := readU8(r)
	if err != nil {
		return comparisonCanonicalBlock{}, err
	}
	return comparisonCanonicalBlock{
		QuerySegment:     int(querySegment),
		QueryStart:       int(queryStart),
		QueryEnd:         int(queryEnd),
		TargetSegment:    int(targetSegment),
		TargetStart:      int(targetStart),
		TargetEnd:        int(targetEnd),
		PercentIdentX100: pid,
		SameStrand:       sameStrandByte != 0,
	}, nil
}

func writeComparisonBlock(w io.Writer, block ComparisonBlock) {
	writeU32(w, block.QueryStart)
	writeU32(w, block.QueryEnd)
	writeU32(w, block.TargetStart)
	writeU32(w, block.TargetEnd)
	writeU16(w, block.PercentIdentX100)
	if block.SameStrand {
		writeU8(w, 1)
	} else {
		writeU8(w, 0)
	}
}

func readComparisonBlock(r io.Reader) (ComparisonBlock, error) {
	qStart, err := readU32(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	qEnd, err := readU32(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	tStart, err := readU32(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	tEnd, err := readU32(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	pid, err := readU16(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	sameStrandByte, err := readU8(r)
	if err != nil {
		return ComparisonBlock{}, err
	}
	return ComparisonBlock{
		QueryStart:       qStart,
		QueryEnd:         qEnd,
		TargetStart:      tStart,
		TargetEnd:        tEnd,
		PercentIdentX100: pid,
		SameStrand:       sameStrandByte != 0,
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
