package main

import (
	"bytes"
	"encoding/binary"
	"errors"
	"io"
	"net"
	"strings"
	"testing"
	"time"
)

type shortPayloadWriter struct {
	bytes.Buffer
	maxPayloadWrite int
	writeCount      int
}

func (w *shortPayloadWriter) Write(p []byte) (int, error) {
	w.writeCount++
	if w.writeCount == 1 || len(p) <= w.maxPayloadWrite {
		return w.Buffer.Write(p)
	}
	return w.Buffer.Write(p[:w.maxPayloadWrite])
}

func TestWriteFrameCompletesShortPayloadWrites(t *testing.T) {
	payload := []byte("abcdefghijklmnopqrstuvwxyz")
	writer := &shortPayloadWriter{maxPayloadWrite: 5}
	if err := WriteFrame(writer, MsgAck, 42, payload); err != nil {
		t.Fatalf("WriteFrame returned error: %v", err)
	}

	var expected bytes.Buffer
	if err := binary.Write(&expected, binary.LittleEndian, FrameHeader{
		Length:      uint32(len(payload)),
		MessageType: MsgAck,
		RequestID:   42,
	}); err != nil {
		t.Fatal(err)
	}
	expected.Write(payload)
	if !bytes.Equal(writer.Bytes(), expected.Bytes()) {
		t.Fatalf("unexpected frame bytes after short writes")
	}
}

type zeroPayloadWriter struct {
	bytes.Buffer
	writeCount int
}

func (w *zeroPayloadWriter) Write(p []byte) (int, error) {
	w.writeCount++
	if w.writeCount == 1 {
		return w.Buffer.Write(p)
	}
	return 0, nil
}

func TestWriteFrameRejectsZeroLengthPayloadWrite(t *testing.T) {
	err := WriteFrame(&zeroPayloadWriter{}, MsgAck, 1, []byte("payload"))
	if !errors.Is(err, io.ErrShortWrite) {
		t.Fatalf("WriteFrame error = %v, want io.ErrShortWrite", err)
	}
}

func TestHandleConnectionRejectsOversizedInboundFrame(t *testing.T) {
	serverConn, clientConn := net.Pipe()
	defer clientConn.Close()
	deadline := time.Now().Add(2 * time.Second)
	if err := clientConn.SetDeadline(deadline); err != nil {
		t.Fatal(err)
	}
	if err := serverConn.SetDeadline(deadline); err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		handleConnection(serverConn, NewEngine(), &serverState{})
		close(done)
	}()

	err := binary.Write(clientConn, binary.LittleEndian, FrameHeader{
		Length:      maxIncomingFramePayloadBytes + 1,
		MessageType: MsgGetVersion,
		RequestID:   77,
	})
	if err != nil {
		t.Fatalf("write oversized header: %v", err)
	}

	header, err := ReadFrameHeader(clientConn)
	if err != nil {
		t.Fatalf("read error response header: %v", err)
	}
	if header.MessageType != MsgError || header.RequestID != 77 {
		t.Fatalf("unexpected response header: %+v", header)
	}
	payload := make([]byte, header.Length)
	if _, err := io.ReadFull(clientConn, payload); err != nil {
		t.Fatalf("read error payload: %v", err)
	}
	if len(payload) < 2 {
		t.Fatalf("error payload too short: %d", len(payload))
	}
	msgLen := int(binary.LittleEndian.Uint16(payload[:2]))
	if len(payload) != 2+msgLen {
		t.Fatalf("error payload length mismatch: payload=%d msgLen=%d", len(payload), msgLen)
	}
	if !strings.Contains(string(payload[2:]), "payload too large") {
		t.Fatalf("unexpected error payload: %q", string(payload[2:]))
	}

	select {
	case <-done:
	case <-time.After(2 * time.Second):
		t.Fatal("server did not close oversized connection")
	}
}

func TestDecodeTileRequestPayload(t *testing.T) {
	legacy := make([]byte, 7)
	binary.LittleEndian.PutUint16(legacy[0:2], 3)
	legacy[2] = 4
	binary.LittleEndian.PutUint32(legacy[3:7], 5)
	req, err := decodeTileRequestPayload(legacy, "tile")
	if err != nil {
		t.Fatalf("decode legacy tile request: %v", err)
	}
	if req.sourceID != 0 || req.chrID != 3 || req.zoom != 4 || req.tileIndex != 5 {
		t.Fatalf("unexpected legacy tile request: %+v", req)
	}

	withSource := make([]byte, 9)
	binary.LittleEndian.PutUint16(withSource[0:2], 7)
	binary.LittleEndian.PutUint16(withSource[2:4], 8)
	withSource[4] = 9
	binary.LittleEndian.PutUint32(withSource[5:9], 10)
	req, err = decodeTileRequestPayload(withSource, "tile")
	if err != nil {
		t.Fatalf("decode source tile request: %v", err)
	}
	if req.sourceID != 7 || req.chrID != 8 || req.zoom != 9 || req.tileIndex != 10 {
		t.Fatalf("unexpected source tile request: %+v", req)
	}

	if _, err := decodeTileRequestPayload(make([]byte, 8), "tile"); err == nil {
		t.Fatal("expected malformed 8-byte tile payload to be rejected")
	}
}
