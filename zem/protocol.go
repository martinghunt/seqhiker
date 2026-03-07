package main

import (
	"encoding/binary"
	"fmt"
	"io"
)

const (
	MsgLoadGenome        uint16 = 1
	MsgLoadBAM           uint16 = 2
	MsgGetTile           uint16 = 3
	MsgGetCoverageTile   uint16 = 4
	MsgGetAnnotations    uint16 = 5
	MsgGetReferenceSlice uint16 = 6
	MsgAck               uint16 = 7
	MsgError             uint16 = 8
	MsgShutdown          uint16 = 9
	MsgGetChromosomes    uint16 = 10
	MsgGetGCPlotTile     uint16 = 11
	MsgGetAnnotationCounts uint16 = 12
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
