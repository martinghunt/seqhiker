package main

import (
	"encoding/binary"
	"fmt"
	"io"
)

const (
	MsgLoadGenome                   uint16 = 1
	MsgLoadBAM                      uint16 = 2
	MsgGetTile                      uint16 = 3
	MsgGetCoverageTile              uint16 = 4
	MsgGetAnnotations               uint16 = 5
	MsgGetReferenceSlice            uint16 = 6
	MsgAck                          uint16 = 7
	MsgError                        uint16 = 8
	MsgShutdown                     uint16 = 9
	MsgGetChromosomes               uint16 = 10
	MsgGetGCPlotTile                uint16 = 11
	MsgGetAnnotationCounts          uint16 = 12
	MsgGetLoadState                 uint16 = 13
	MsgInspectInput                 uint16 = 14
	MsgGetAnnotationTile            uint16 = 15
	MsgSearchDNAExact               uint16 = 16
	MsgGetStrandCoverageTile        uint16 = 17
	MsgDownloadGenome               uint16 = 18
	MsgGetVersion                   uint16 = 19
	MsgGenerateTestData             uint16 = 20
	MsgAddComparisonGenome          uint16 = 21
	MsgListComparisonGenomes        uint16 = 22
	MsgListComparisonPairs          uint16 = 23
	MsgGetComparisonBlocks          uint16 = 24
	MsgGetComparisonBlocksByGenomes uint16 = 25
	MsgGetComparisonAnnotations     uint16 = 26
	MsgSaveComparisonSession        uint16 = 27
	MsgLoadComparisonSession        uint16 = 28
	MsgResetComparisonState         uint16 = 29
	MsgGenerateComparisonTestData   uint16 = 30
	MsgGetComparisonReferenceSlice  uint16 = 31
	MsgGetComparisonBlockDetail     uint16 = 32
	MsgAddComparisonGenomeFiles     uint16 = 33
	MsgSearchComparisonDNAExact     uint16 = 34
	MsgGetStopCodonTile             uint16 = 35
	MsgLoadVariantFile              uint16 = 36
	MsgListVariantSources           uint16 = 37
	MsgGetVariantTile               uint16 = 38
	MsgGetVariantDetail             uint16 = 39
)

type FrameHeader struct {
	Length      uint32
	MessageType uint16
	RequestID   uint16
}

type ChromInfo struct {
	ID     uint16
	Name   string
	Length uint32
}

type AnnotationCountInfo struct {
	ID    uint16
	Count uint32
}

type VariantSourceInfo struct {
	ID          uint16
	Name        string
	Path        string
	SampleNames []string
}

func ReadFrameHeader(r io.Reader) (*FrameHeader, error) {
	var h FrameHeader
	err := binary.Read(r, binary.LittleEndian, &h)
	if err != nil {
		return nil, err
	}
	return &h, nil
}

func WriteFrame(w io.Writer, msgType uint16, requestID uint16, payload []byte) error {
	header := FrameHeader{
		Length:      uint32(len(payload)),
		MessageType: msgType,
		RequestID:   requestID,
	}

	if err := binary.Write(w, binary.LittleEndian, header); err != nil {
		return err
	}

	_, err := w.Write(payload)
	return err
}

func decodePathPayload(payload []byte) (string, error) {
	if len(payload) < 2 {
		return "", fmt.Errorf("payload too short for path")
	}
	pathLen := int(binary.LittleEndian.Uint16(payload[:2]))
	if len(payload) < 2+pathLen {
		return "", fmt.Errorf("invalid path payload length")
	}
	return string(payload[2 : 2+pathLen]), nil
}

func decodeDownloadGenomePayload(payload []byte) (string, string, uint32, error) {
	if len(payload) < 8 {
		return "", "", 0, fmt.Errorf("payload too short for download request")
	}
	accessionLen := int(binary.LittleEndian.Uint16(payload[0:2]))
	if len(payload) < 2+accessionLen+2+4 {
		return "", "", 0, fmt.Errorf("invalid download payload length")
	}
	off := 2
	accession := string(payload[off : off+accessionLen])
	off += accessionLen
	cacheDirLen := int(binary.LittleEndian.Uint16(payload[off : off+2]))
	off += 2
	if len(payload) < off+cacheDirLen+4 {
		return "", "", 0, fmt.Errorf("invalid download cache-dir payload length")
	}
	cacheDir := string(payload[off : off+cacheDirLen])
	off += cacheDirLen
	maxBytes := binary.LittleEndian.Uint32(payload[off : off+4])
	return accession, cacheDir, maxBytes, nil
}

func encodeChromosomes(chroms []ChromInfo) []byte {
	total := 2
	for _, c := range chroms {
		total += 8 + len(c.Name)
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(chroms)))
	off := 2
	for _, c := range chroms {
		binary.LittleEndian.PutUint16(buf[off:off+2], c.ID)
		binary.LittleEndian.PutUint32(buf[off+2:off+6], c.Length)
		binary.LittleEndian.PutUint16(buf[off+6:off+8], uint16(len(c.Name)))
		copy(buf[off+8:off+8+len(c.Name)], c.Name)
		off += 8 + len(c.Name)
	}
	return buf
}

func encodeAnnotationCounts(counts []AnnotationCountInfo) []byte {
	buf := make([]byte, 2+6*len(counts))
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(counts)))
	off := 2
	for _, c := range counts {
		binary.LittleEndian.PutUint16(buf[off:off+2], c.ID)
		binary.LittleEndian.PutUint32(buf[off+2:off+6], c.Count)
		off += 6
	}
	return buf
}

func ackPayload(msg string) []byte {
	buf := make([]byte, 2+len(msg))
	binary.LittleEndian.PutUint16(buf[:2], uint16(len(msg)))
	copy(buf[2:], msg)
	return buf
}

func encodeBAMLoaded(sourceID uint16, msg string) []byte {
	buf := make([]byte, 4+len(msg))
	binary.LittleEndian.PutUint16(buf[0:2], sourceID)
	binary.LittleEndian.PutUint16(buf[2:4], uint16(len(msg)))
	copy(buf[4:], msg)
	return buf
}

func encodeVariantSourceLoaded(sourceID uint16, sampleNames []string, msg string) []byte {
	total := 6 + len(msg)
	for _, sample := range sampleNames {
		total += 2 + len(sample)
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], sourceID)
	binary.LittleEndian.PutUint16(buf[2:4], uint16(len(sampleNames)))
	off := 4
	for _, sample := range sampleNames {
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(sample)))
		copy(buf[off+2:off+2+len(sample)], sample)
		off += 2 + len(sample)
	}
	binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(msg)))
	copy(buf[off+2:], msg)
	return buf
}

func encodeLoadState(hasSequence bool) []byte {
	if hasSequence {
		return []byte{1}
	}
	return []byte{0}
}

func encodeInputInfo(hasSequence bool, hasAnnotation bool, hasEmbeddedGFF3Sequence bool, isComparisonSession bool, hasVariants bool) []byte {
	var flags byte
	if hasSequence {
		flags |= 1
	}
	if hasAnnotation {
		flags |= 2
	}
	if hasEmbeddedGFF3Sequence {
		flags |= 8
	}
	if isComparisonSession {
		flags |= 4
	}
	if hasVariants {
		flags |= 16
	}
	return []byte{flags}
}

func encodeVariantSources(sources []VariantSourceInfo) []byte {
	total := 2
	for _, source := range sources {
		total += 8 + len(source.Name) + len(source.Path)
		for _, sample := range source.SampleNames {
			total += 2 + len(sample)
		}
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(sources)))
	off := 2
	for _, source := range sources {
		binary.LittleEndian.PutUint16(buf[off:off+2], source.ID)
		binary.LittleEndian.PutUint16(buf[off+2:off+4], uint16(len(source.Name)))
		binary.LittleEndian.PutUint16(buf[off+4:off+6], uint16(len(source.Path)))
		binary.LittleEndian.PutUint16(buf[off+6:off+8], uint16(len(source.SampleNames)))
		copy(buf[off+8:off+8+len(source.Name)], source.Name)
		off += 8 + len(source.Name)
		copy(buf[off:off+len(source.Path)], source.Path)
		off += len(source.Path)
		for _, sample := range source.SampleNames {
			binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(sample)))
			copy(buf[off+2:off+2+len(sample)], sample)
			off += 2 + len(sample)
		}
	}
	return buf
}

func encodeDNAExactHits(truncated bool, hits []DNAExactHit) []byte {
	buf := make([]byte, 3+9*len(hits))
	if truncated {
		buf[0] = 1
	}
	binary.LittleEndian.PutUint16(buf[1:3], uint16(len(hits)))
	off := 3
	for _, hit := range hits {
		binary.LittleEndian.PutUint32(buf[off:off+4], uint32(hit.Start))
		binary.LittleEndian.PutUint32(buf[off+4:off+8], uint32(hit.End))
		buf[off+8] = hit.Strand
		off += 9
	}
	return buf
}

func encodeStringList(values []string) []byte {
	total := 2
	for _, value := range values {
		total += 2 + len(value)
	}
	buf := make([]byte, total)
	binary.LittleEndian.PutUint16(buf[0:2], uint16(len(values)))
	off := 2
	for _, value := range values {
		binary.LittleEndian.PutUint16(buf[off:off+2], uint16(len(value)))
		copy(buf[off+2:off+2+len(value)], value)
		off += 2 + len(value)
	}
	return buf
}

func decodeStringListPayload(payload []byte) ([]string, error) {
	if len(payload) < 2 {
		return nil, fmt.Errorf("payload too short for string list")
	}
	count := int(binary.LittleEndian.Uint16(payload[0:2]))
	off := 2
	values := make([]string, 0, count)
	for i := 0; i < count; i++ {
		if len(payload) < off+2 {
			return nil, fmt.Errorf("invalid string list payload length")
		}
		n := int(binary.LittleEndian.Uint16(payload[off : off+2]))
		off += 2
		if len(payload) < off+n {
			return nil, fmt.Errorf("invalid string list entry length")
		}
		values = append(values, string(payload[off:off+n]))
		off += n
	}
	return values, nil
}
