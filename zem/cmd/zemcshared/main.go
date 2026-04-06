package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef struct {
	uint16_t message_type;
	uint8_t* data;
	uint32_t len;
} ZemResponse;
*/
import "C"

import (
	"encoding/binary"
	"sync"
	"unsafe"

	"seqhiker/zem"
)

var (
	backendMu     sync.Mutex
	nextBackendID uint64 = 1
	backends             = map[uint64]*zem.Backend{}
)

func main() {}

//export ZemBackendCreate
func ZemBackendCreate() C.uint64_t {
	backendMu.Lock()
	defer backendMu.Unlock()
	id := nextBackendID
	nextBackendID++
	backends[id] = zem.NewBackend()
	return C.uint64_t(id)
}

//export ZemBackendFree
func ZemBackendFree(handle C.uint64_t) {
	backendMu.Lock()
	defer backendMu.Unlock()
	delete(backends, uint64(handle))
}

//export ZemBackendHandleRequest
func ZemBackendHandleRequest(handle C.uint64_t, msgType C.uint16_t, data *C.uint8_t, length C.uint32_t) C.ZemResponse {
	backend := lookupBackend(uint64(handle))
	if backend == nil {
		return makeResponse(zem.MsgError, encodeErrorPayload("invalid backend handle"))
	}
	var payload []byte
	if data != nil && length > 0 {
		payload = C.GoBytes(unsafe.Pointer(data), C.int(length))
	}
	resp := backend.HandleRequest(uint16(msgType), payload)
	return makeResponse(resp.MessageType, resp.Payload)
}

//export ZemResponseFree
func ZemResponseFree(data *C.uint8_t) {
	if data != nil {
		C.free(unsafe.Pointer(data))
	}
}

func lookupBackend(handle uint64) *zem.Backend {
	backendMu.Lock()
	defer backendMu.Unlock()
	return backends[handle]
}

func makeResponse(msgType uint16, payload []byte) C.ZemResponse {
	resp := C.ZemResponse{message_type: C.uint16_t(msgType)}
	if len(payload) == 0 {
		return resp
	}
	resp.data = (*C.uint8_t)(C.CBytes(payload))
	resp.len = C.uint32_t(len(payload))
	return resp
}

func encodeErrorPayload(msg string) []byte {
	data := make([]byte, 2+len(msg))
	binary.LittleEndian.PutUint16(data[:2], uint16(len(msg)))
	copy(data[2:], []byte(msg))
	return data
}
