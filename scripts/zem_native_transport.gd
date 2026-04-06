extends RefCounted
class_name ZemNativeTransport

const BACKEND_NOT_READY_ERROR := "Native zem backend bridge is not integrated yet on this branch."
const BRIDGE_EXTENSION_PATH := "res://seqhiker_zem_bridge.gdextension"

var _bridge: RefCounted = null
var _bridge_extension_loaded := false


func connect_to_server(_host: String = "127.0.0.1", _port: int = 9000, _timeout_ms: int = 1200) -> bool:
	return ensure_connected()


func disconnect_from_server() -> void:
	pass


func ensure_connected() -> bool:
	return _ensure_bridge()


func connection_info() -> Dictionary:
	return {"mode": "native"}


func spawn_peer_transport() -> RefCounted:
	return get_script().new()


func requires_server_process() -> bool:
	return false


func send_request(_msg_type: int, _payload: PackedByteArray, _timeout_ms: int = 1800) -> Dictionary:
	if not _ensure_bridge():
		return {"ok": false, "error": BACKEND_NOT_READY_ERROR}
	return _bridge.handle_request(_msg_type, _payload)


func _ensure_bridge() -> bool:
	if _bridge != null and _bridge.has_method("is_ready") and _bridge.is_ready():
		return true
	_try_load_bridge_extension()
	if not ClassDB.class_exists("ZemBridge"):
		return false
	var instance: Variant = ClassDB.instantiate("ZemBridge")
	if instance == null:
		return false
	_bridge = instance
	return _bridge.has_method("is_ready") and _bridge.is_ready()


func _try_load_bridge_extension() -> void:
	if _bridge_extension_loaded:
		return
	_bridge_extension_loaded = true
	if ResourceLoader.exists(BRIDGE_EXTENSION_PATH):
		load(BRIDGE_EXTENSION_PATH)
