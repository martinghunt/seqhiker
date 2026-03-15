package main

import (
	"encoding/binary"
	"fmt"
	"io"
	"log"
	"net"
	"path/filepath"
	"strings"
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
		path, cutoff, err := decodeLoadBAMPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		sourceID, err := engine.LoadBAM(path, cutoff)
		if err != nil {
			return 0, nil, err
		}
		return MsgLoadBAM, encodeBAMLoaded(sourceID, "bam loaded"), nil

	case MsgGetChromosomes:
		return MsgGetChromosomes, encodeChromosomes(engine.ListChromosomes()), nil
	case MsgGetAnnotationCounts:
		return MsgGetAnnotationCounts, encodeAnnotationCounts(engine.ListAnnotationCounts()), nil
	case MsgGetLoadState:
		return MsgGetLoadState, encodeLoadState(engine.HasSequenceLoaded()), nil
	case MsgInspectInput:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		hasSequence, hasAnnotation, err := engine.InspectInput(path)
		if err != nil {
			return 0, nil, err
		}
		return MsgInspectInput, encodeInputInfo(hasSequence, hasAnnotation), nil

	case MsgGetTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid tile payload")
		}
		sourceID := uint16(0)
		off := 0
		if len(payload) >= 9 {
			sourceID = binary.LittleEndian.Uint16(payload[0:2])
			off = 2
		}
		chrID := binary.LittleEndian.Uint16(payload[off : off+2])
		zoom := payload[off+2]
		tileIndex := binary.LittleEndian.Uint32(payload[off+3 : off+7])
		resp, err := engine.GetTile(sourceID, chrID, zoom, tileIndex)
		return MsgGetTile, resp, err

	case MsgGetCoverageTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid coverage tile payload")
		}
		sourceID := uint16(0)
		off := 0
		if len(payload) >= 9 {
			sourceID = binary.LittleEndian.Uint16(payload[0:2])
			off = 2
		}
		chrID := binary.LittleEndian.Uint16(payload[off : off+2])
		zoom := payload[off+2]
		tileIndex := binary.LittleEndian.Uint32(payload[off+3 : off+7])
		resp, err := engine.GetCoverageTile(sourceID, chrID, zoom, tileIndex)
		return MsgGetCoverageTile, resp, err

	case MsgGetStrandCoverageTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid strand coverage tile payload")
		}
		sourceID := uint16(0)
		off := 0
		if len(payload) >= 9 {
			sourceID = binary.LittleEndian.Uint16(payload[0:2])
			off = 2
		}
		chrID := binary.LittleEndian.Uint16(payload[off : off+2])
		zoom := payload[off+2]
		tileIndex := binary.LittleEndian.Uint32(payload[off+3 : off+7])
		resp, err := engine.GetStrandCoverageTile(sourceID, chrID, zoom, tileIndex)
		return MsgGetStrandCoverageTile, resp, err

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

	case MsgGetAnnotationTile:
		if len(payload) < 13 {
			return 0, nil, fmt.Errorf("invalid annotation tile payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		zoom := payload[2]
		tileIndex := binary.LittleEndian.Uint32(payload[3:7])
		maxRecs := binary.LittleEndian.Uint16(payload[7:9])
		minLen := binary.LittleEndian.Uint32(payload[9:13])
		resp, err := engine.GetAnnotationTile(chrID, zoom, tileIndex, maxRecs, minLen)
		return MsgGetAnnotationTile, resp, err

	case MsgGetReferenceSlice:
		if len(payload) < 10 {
			return 0, nil, fmt.Errorf("invalid reference payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		start := binary.LittleEndian.Uint32(payload[2:6])
		end := binary.LittleEndian.Uint32(payload[6:10])
		resp, err := engine.GetReferenceSlice(chrID, start, end)
		return MsgGetReferenceSlice, resp, err

	case MsgSearchDNAExact:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid dna search payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		maxHits := binary.LittleEndian.Uint16(payload[2:4])
		includeRevComp := payload[4] != 0
		patternLen := int(binary.LittleEndian.Uint16(payload[5:7]))
		if len(payload) < 7+patternLen {
			return 0, nil, fmt.Errorf("invalid dna search payload length")
		}
		pattern := string(payload[7 : 7+patternLen])
		resp, err := engine.SearchDNAExact(chrID, pattern, includeRevComp, maxHits)
		return MsgSearchDNAExact, resp, err

	case MsgDownloadGenome:
		accession, cacheDir, maxBytes, err := decodeDownloadGenomePayload(payload)
		if err != nil {
			return 0, nil, err
		}
		files, err := engine.DownloadGenome(accession, cacheDir, int64(maxBytes))
		if err != nil {
			return 0, nil, err
		}
		if len(files) == 0 {
			return 0, nil, fmt.Errorf("download returned no files")
		}
		for _, path := range files {
			if err := engine.LoadGenome(path); err != nil {
				return 0, nil, err
			}
		}
		return MsgDownloadGenome, encodeStringList(files), nil

	case MsgGetVersion:
		return MsgGetVersion, ackPayload(ZemVersion), nil

	case MsgGenerateTestData:
		rootDir, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		files, err := engine.GenerateTestData(rootDir)
		if err != nil {
			return 0, nil, err
		}
		for _, path := range files {
			ext := strings.ToLower(filepath.Ext(path))
			if ext == ".bam" {
				if _, err := engine.LoadBAM(path, 0); err != nil {
					return 0, nil, err
				}
				continue
			}
			if err := engine.LoadGenome(path); err != nil {
				return 0, nil, err
			}
		}
		return MsgGenerateTestData, encodeStringList(files), nil

	default:
		return 0, nil, fmt.Errorf("unknown message type %d", msgType)
	}
}

func decodeLoadBAMPayload(payload []byte) (string, int, error) {
	if len(payload) >= 7 && payload[0] == 0xFF {
		cutoff := int(binary.LittleEndian.Uint32(payload[1:5]))
		pathLen := int(binary.LittleEndian.Uint16(payload[5:7]))
		if len(payload) < 7+pathLen {
			return "", 0, fmt.Errorf("invalid load-bam payload length")
		}
		return string(payload[7 : 7+pathLen]), cutoff, nil
	}
	path, err := decodePathPayload(payload)
	return path, 0, err
}

func sendError(conn net.Conn, requestID uint16, msg string) {
	data := make([]byte, 2+len(msg))
	binary.LittleEndian.PutUint16(data[:2], uint16(len(msg)))
	copy(data[2:], []byte(msg))
	if err := WriteFrame(conn, MsgError, requestID, data); err != nil {
		log.Println("Error write failed:", err)
	}
}
