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

	case MsgLoadGenomeFiles:
		paths, err := decodeStringListPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		if err := engine.LoadGenomeFiles(paths); err != nil {
			return 0, nil, err
		}
		return MsgAck, ackPayload("genome loaded"), nil

	case MsgResetBrowserState:
		engine.ResetBrowserState()
		return MsgAck, ackPayload("browser state reset"), nil

	case MsgSetChromosomeOrientation:
		if len(payload) < 3 {
			return 0, nil, fmt.Errorf("invalid chromosome orientation payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		reversed := payload[2] != 0
		if err := engine.SetChromosomeOrientation(chrID, reversed); err != nil {
			return 0, nil, err
		}
		return MsgGetChromosomes, encodeChromosomes(engine.ListChromosomes()), nil

	case MsgSetAllChromosomeOrientations:
		if len(payload) < 1 {
			return 0, nil, fmt.Errorf("invalid all-chromosome orientation payload")
		}
		reversed := payload[0] != 0
		if err := engine.SetAllChromosomeOrientations(reversed); err != nil {
			return 0, nil, err
		}
		return MsgGetChromosomes, encodeChromosomes(engine.ListChromosomes()), nil

	case MsgSetComparisonSegmentOrientation:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid comparison segment orientation payload")
		}
		genomeID := binary.LittleEndian.Uint16(payload[0:2])
		segmentStart := binary.LittleEndian.Uint32(payload[2:6])
		reversed := payload[6] != 0
		if err := engine.SetComparisonSegmentOrientation(genomeID, segmentStart, reversed); err != nil {
			return 0, nil, err
		}
		return MsgListComparisonGenomes, encodeComparisonGenomes(engine.ListComparisonGenomes()), nil

	case MsgSetComparisonGenomeOrientation:
		if len(payload) < 3 {
			return 0, nil, fmt.Errorf("invalid comparison genome orientation payload")
		}
		genomeID := binary.LittleEndian.Uint16(payload[0:2])
		reversed := payload[2] != 0
		if err := engine.SetComparisonGenomeOrientation(genomeID, reversed); err != nil {
			return 0, nil, err
		}
		return MsgListComparisonGenomes, encodeComparisonGenomes(engine.ListComparisonGenomes()), nil

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
		hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isComparisonSession, hasVariants, err := engine.InspectInput(path)
		if err != nil {
			return 0, nil, err
		}
		return MsgInspectInput, encodeInputInfo(hasSequence, hasAnnotation, hasEmbeddedGFF3Sequence, isComparisonSession, hasVariants), nil

	case MsgLoadVariantFile:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		source, err := engine.LoadVariantFile(path)
		if err != nil {
			return 0, nil, err
		}
		return MsgLoadVariantFile, encodeVariantSourceLoaded(source.ID, source.SampleNames, "variants loaded"), nil

	case MsgListVariantSources:
		return MsgListVariantSources, encodeVariantSources(engine.ListVariantSources()), nil

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

	case MsgGetStopCodonTile:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid stop codon tile payload")
		}
		chrID := binary.LittleEndian.Uint16(payload[0:2])
		zoom := payload[2]
		tileIndex := binary.LittleEndian.Uint32(payload[3:7])
		resp, err := engine.GetStopCodonTile(chrID, zoom, tileIndex)
		return MsgGetStopCodonTile, resp, err

	case MsgGetVariantTile:
		if len(payload) < 9 {
			return 0, nil, fmt.Errorf("invalid variant tile payload")
		}
		sourceID := binary.LittleEndian.Uint16(payload[0:2])
		chrID := binary.LittleEndian.Uint16(payload[2:4])
		zoom := payload[4]
		tileIndex := binary.LittleEndian.Uint32(payload[5:9])
		resp, err := engine.GetVariantTile(sourceID, chrID, zoom, tileIndex)
		return MsgGetVariantTile, resp, err

	case MsgGetVariantDetail:
		if len(payload) < 12 {
			return 0, nil, fmt.Errorf("invalid variant detail payload")
		}
		sourceID := binary.LittleEndian.Uint16(payload[0:2])
		chrID := binary.LittleEndian.Uint16(payload[2:4])
		start := binary.LittleEndian.Uint32(payload[4:8])
		refLen := int(binary.LittleEndian.Uint16(payload[8:10]))
		altLen := int(binary.LittleEndian.Uint16(payload[10:12]))
		if len(payload) < 12+refLen+altLen {
			return 0, nil, fmt.Errorf("invalid variant detail payload length")
		}
		ref := string(payload[12 : 12+refLen])
		altSummary := string(payload[12+refLen : 12+refLen+altLen])
		resp, err := engine.GetVariantDetail(sourceID, chrID, start, ref, altSummary)
		return MsgGetVariantDetail, resp, err

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

	case MsgSearchComparisonDNAExact:
		if len(payload) < 7 {
			return 0, nil, fmt.Errorf("invalid comparison dna search payload")
		}
		genomeID := binary.LittleEndian.Uint16(payload[0:2])
		maxHits := binary.LittleEndian.Uint16(payload[2:4])
		includeRevComp := payload[4] != 0
		patternLen := int(binary.LittleEndian.Uint16(payload[5:7]))
		if len(payload) < 7+patternLen {
			return 0, nil, fmt.Errorf("invalid comparison dna search payload length")
		}
		pattern := string(payload[7 : 7+patternLen])
		resp, err := engine.SearchComparisonDNAExact(genomeID, pattern, includeRevComp, maxHits)
		return MsgSearchComparisonDNAExact, resp, err

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

	case MsgSaveComparisonSession:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		if err := engine.SaveComparisonSession(path); err != nil {
			return 0, nil, err
		}
		return MsgAck, ackPayload("comparison session saved"), nil

	case MsgLoadComparisonSession:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		if err := engine.LoadComparisonSession(path); err != nil {
			return 0, nil, err
		}
		return MsgAck, ackPayload("comparison session loaded"), nil

	case MsgResetComparisonState:
		engine.ResetComparisonState()
		return MsgAck, ackPayload("comparison state reset"), nil

	case MsgGenerateComparisonTestData:
		rootDir, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		files, err := engine.GenerateComparisonTestData(rootDir)
		if err != nil {
			return 0, nil, err
		}
		return MsgGenerateComparisonTestData, encodeStringList(files), nil

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
			kind, kindErr := detectInputKind(path)
			if kindErr != nil {
				return 0, nil, kindErr
			}
			if kind == inputKindVCF {
				continue
			}
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

	case MsgAddComparisonGenome:
		path, err := decodePathPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		genome, err := engine.AddComparisonGenome(path)
		if err != nil {
			return 0, nil, err
		}
		return MsgAddComparisonGenome, encodeComparisonGenomes([]ComparisonGenomeInfo{genome}), nil

	case MsgAddComparisonGenomeFiles:
		paths, err := decodeStringListPayload(payload)
		if err != nil {
			return 0, nil, err
		}
		genome, err := engine.AddComparisonGenomeFiles(paths)
		if err != nil {
			return 0, nil, err
		}
		return MsgAddComparisonGenome, encodeComparisonGenomes([]ComparisonGenomeInfo{genome}), nil

	case MsgListComparisonGenomes:
		return MsgListComparisonGenomes, encodeComparisonGenomes(engine.ListComparisonGenomes()), nil

	case MsgListComparisonPairs:
		return MsgListComparisonPairs, encodeComparisonPairs(engine.ListComparisonPairs()), nil

	case MsgGetComparisonBlocks:
		if len(payload) < 2 {
			return 0, nil, fmt.Errorf("invalid comparison block payload")
		}
		pairID := binary.LittleEndian.Uint16(payload[0:2])
		blocks, err := engine.GetComparisonBlocks(pairID)
		if err != nil {
			return 0, nil, err
		}
		return MsgGetComparisonBlocks, encodeComparisonBlocks(blocks), nil

	case MsgGetComparisonBlocksByGenomes:
		if len(payload) < 4 {
			return 0, nil, fmt.Errorf("invalid comparison block-by-genomes payload")
		}
		queryGenomeID := binary.LittleEndian.Uint16(payload[0:2])
		targetGenomeID := binary.LittleEndian.Uint16(payload[2:4])
		blocks, err := engine.GetComparisonBlocksByGenomes(queryGenomeID, targetGenomeID)
		if err != nil {
			return 0, nil, err
		}
		return MsgGetComparisonBlocksByGenomes, encodeComparisonBlocks(blocks), nil

	case MsgGetComparisonAnnotations:
		if len(payload) < 16 {
			return 0, nil, fmt.Errorf("invalid comparison annotation payload")
		}
		genomeID := binary.LittleEndian.Uint16(payload[0:2])
		start := binary.LittleEndian.Uint32(payload[2:6])
		end := binary.LittleEndian.Uint32(payload[6:10])
		maxRecs := binary.LittleEndian.Uint16(payload[10:12])
		minLen := binary.LittleEndian.Uint32(payload[12:16])
		resp, err := engine.GetComparisonAnnotations(genomeID, start, end, maxRecs, minLen)
		return MsgGetComparisonAnnotations, resp, err

	case MsgGetComparisonReferenceSlice:
		if len(payload) < 10 {
			return 0, nil, fmt.Errorf("invalid comparison reference slice payload")
		}
		genomeID := binary.LittleEndian.Uint16(payload[0:2])
		start := binary.LittleEndian.Uint32(payload[2:6])
		end := binary.LittleEndian.Uint32(payload[6:10])
		resp, err := engine.GetComparisonReferenceSlice(genomeID, start, end)
		return MsgGetComparisonReferenceSlice, resp, err

	case MsgGetComparisonBlockDetail:
		if len(payload) < 21 {
			return 0, nil, fmt.Errorf("invalid comparison block detail payload")
		}
		queryGenomeID := binary.LittleEndian.Uint16(payload[0:2])
		targetGenomeID := binary.LittleEndian.Uint16(payload[2:4])
		block := ComparisonBlock{
			QueryStart:       binary.LittleEndian.Uint32(payload[4:8]),
			QueryEnd:         binary.LittleEndian.Uint32(payload[8:12]),
			TargetStart:      binary.LittleEndian.Uint32(payload[12:16]),
			TargetEnd:        binary.LittleEndian.Uint32(payload[16:20]),
			SameStrand:       payload[20] != 0,
			PercentIdentX100: 0,
		}
		detail, err := engine.GetComparisonBlockDetail(queryGenomeID, targetGenomeID, block)
		if err != nil {
			return 0, nil, err
		}
		return MsgGetComparisonBlockDetail, encodeComparisonBlockDetail(detail), nil

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
