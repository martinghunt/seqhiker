package zem

// Backend is the stateful in-process entrypoint for future native/library
// integrations. It wraps one Engine instance and preserves the current
// message-type + binary-payload protocol surface.
type Backend struct {
	engine *Engine
}

type BackendResponse struct {
	MessageType uint16
	Payload     []byte
}

func NewBackend() *Backend {
	return &Backend{engine: NewEngine()}
}

func NewBackendWithEngine(engine *Engine) *Backend {
	if engine == nil {
		engine = NewEngine()
	}
	return &Backend{engine: engine}
}

func (b *Backend) Engine() *Engine {
	if b == nil {
		return nil
	}
	return b.engine
}

func (b *Backend) HandleMessage(msgType uint16, payload []byte) (uint16, []byte, error) {
	if b == nil || b.engine == nil {
		return 0, nil, ErrNilBackend
	}
	return HandleMessage(b.engine, msgType, payload)
}

func (b *Backend) HandleRequest(msgType uint16, payload []byte) BackendResponse {
	responseType, responsePayload, err := b.HandleMessage(msgType, payload)
	if err != nil {
		return BackendResponse{
			MessageType: MsgError,
			Payload:     errorPayload(err.Error()),
		}
	}
	return BackendResponse{
		MessageType: responseType,
		Payload:     responsePayload,
	}
}
