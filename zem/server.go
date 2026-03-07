package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"sync/atomic"
)

type serverState struct {
	listener net.Listener
	stopping atomic.Bool
}

func StartServer(addr string, engine *Engine) error {
	ln, err := net.Listen("tcp", addr)
	if err != nil {
		return err
	}
	defer ln.Close()
	state := &serverState{listener: ln}

	log.Println("Genome engine listening on", addr)

	for {
		conn, err := ln.Accept()
		if err != nil {
			if state.stopping.Load() {
				return nil
			}
			log.Println("Accept error:", err)
			continue
		}
		go handleConnection(conn, engine, state)
	}
}

func handleConnection(conn net.Conn, engine *Engine, state *serverState) {
	defer conn.Close()
	log.Println("Client connected:", conn.RemoteAddr())

	for {
		header, err := ReadFrameHeader(conn)
		if err != nil {
			if err != io.EOF {
				log.Println("Header read error:", err)
			}
			return
		}

		payload := make([]byte, header.Length)
		_, err = io.ReadFull(conn, payload)
		if err != nil {
			log.Println("Payload read error:", err)
			return
		}
		if header.MessageType == MsgShutdown {
			_ = WriteFrame(conn, MsgAck, header.RequestID, ackPayload("bye"))
			if !state.stopping.Swap(true) {
				_ = state.listener.Close()
			}
			return
		}

		responseType, response, err := dispatch(engine, header.MessageType, payload)
		if err != nil {
			sendError(conn, header.RequestID, err.Error())
			continue
		}

		err = WriteFrame(conn, responseType, header.RequestID, response)
		if err != nil {
			log.Println("Write error:", err)
			return
		}
	}
}

func dispatch(engine *Engine, msgType uint16, payload []byte) (uint16, []byte, error) {
	switch msgType {
	case MsgLoadGenome:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		if err := engine.LoadGenome(path); err != nil {
			return 0, nil, err
		}
		return MsgAck, ackPayload("genome loaded"), nil

	case MsgLoadBAM:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		if err := engine.LoadBAM(path); err != nil {
			return 0, nil, err
		}
		return MsgAck, ackPayload("bam loaded"), nil

	case MsgGetChromosomes:
		return MsgGetChromosomes, encodeChromosomes(engine.ListChromosomes()), nil
	case MsgGetAnnotationCounts:
		return MsgGetAnnotationCounts, encodeAnnotationCounts(engine.ListAnnotationCounts()), nil

	case MsgGetTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid tile payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[:2])
		zoom := payload[2]
		tileIndex := binary.LittleEndian.Uint32(payload[3:7])
		resp, err := engine.GetTile(chrID, zoom, tileIndex)
		return MsgGetTile, resp, err

	case MsgGetCoverageTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid coverage tile payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[:2])
		zoom := payload[2]
		tileIndex := binary.LittleEndian.Uint32(payload[3:7])
		resp, err := engine.GetCoverageTile(chrID, zoom, tileIndex)
		return MsgGetCoverageTile, resp, err

	case MsgGetGCPlotTile:
		if len(payload) < 11 {
			return 0, nil, fmt.Errorf("invalid gc plot tile payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[:2])
		zoom := payload[2]
		tileIndex := binary.LittleEndian.Uint32(payload[3:7])
		windowLen := binary.LittleEndian.Uint32(payload[7:11])
		resp, err := engine.GetGCPlotTile(chrID, zoom, tileIndex, windowLen)
		return MsgGetGCPlotTile, resp, err

	case MsgGetAnnotations:
		if len(payload) < 16 {
			return 0, nil, fmt.Errorf("invalid annotation payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		start := binary.LittleEndian.Uint32(payload[2:6])
		end := binary.LittleEndian.Uint32(payload[6:10])
		maxRecs := binary.LittleEndian.Uint16(payload[10:12])
		minLen := binary.LittleEndian.Uint32(payload[12:16])
		resp, err := engine.GetAnnotations(chrID, start, end, maxRecs, minLen)
		return MsgGetAnnotations, resp, err

	case MsgGetReferenceSlice:
		if len(payload) < 10 {
			return 0, nil, fmt.Errorf("invalid reference payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		start := binary.LittleEndian.Uint32(payload[2:6])
		end := binary.LittleEndian.Uint32(payload[6:10])
		resp, err := engine.GetReferenceSlice(chrID, start, end)
		return MsgGetReferenceSlice, resp, err

	default:
		return 0, nil, fmt.Errorf("unknown message type %d", msgType)
	}
}

func sendError(conn net.Conn, requestID uint16, msg string) {
	data := make([]byte, 2+len(msg))
	binary.LittleEndian.PutUint16(data[:2], uint16(len(msg)))
	copy(data[2:], []byte(msg))
	if err := WriteFrame(conn, MsgError, requestID, data); err != nil {
		log.Println("Error write failed:", err)
	}
}
