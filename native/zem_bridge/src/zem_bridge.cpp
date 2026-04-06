#include "zem_bridge.h"

#include <algorithm>

#include "libzem.h"

#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

namespace {
constexpr uint16_t MSG_ERROR = 8;
constexpr uint16_t MSG_GET_VERSION = 19;
}

std::mutex ZemBridge::backend_mutex;
uint64_t ZemBridge::backend_handle = 0;
uint32_t ZemBridge::instance_count = 0;

void ZemBridge::_bind_methods() {
	ClassDB::bind_method(D_METHOD("is_ready"), &ZemBridge::is_ready);
	ClassDB::bind_method(D_METHOD("handle_request", "msg_type", "payload"), &ZemBridge::handle_request);
	ClassDB::bind_method(D_METHOD("get_backend_version"), &ZemBridge::get_backend_version);
}

bool ZemBridge::ensure_backend_locked() {
	if (backend_handle != 0) {
		return true;
	}
	backend_handle = ZemBackendCreate();
	return backend_handle != 0;
}

String ZemBridge::decode_wire_text(const PackedByteArray &p_payload, int32_t p_offset) {
	if (p_offset < 0 || p_offset >= p_payload.size()) {
		return String();
	}
	PackedByteArray bytes = p_payload.slice(p_offset, p_payload.size());
	return bytes.get_string_from_utf8();
}

String ZemBridge::decode_error_payload(const PackedByteArray &p_payload) {
	if (p_payload.size() < 2) {
		return String("Unknown backend error");
	}
	uint16_t len = p_payload.decode_u16(0);
	if (p_payload.size() < 2 + len) {
		return String("Malformed backend error");
	}
	return decode_wire_text(p_payload.slice(0, 2 + len), 2);
}

ZemBridge::ZemBridge() {
	std::lock_guard<std::mutex> lock(backend_mutex);
	instance_count += 1;
	ensure_backend_locked();
}

ZemBridge::~ZemBridge() {
	std::lock_guard<std::mutex> lock(backend_mutex);
	if (instance_count > 0) {
		instance_count -= 1;
	}
	if (instance_count == 0 && backend_handle != 0) {
		ZemBackendFree(backend_handle);
		backend_handle = 0;
	}
}

bool ZemBridge::is_ready() const {
	std::lock_guard<std::mutex> lock(backend_mutex);
	return backend_handle != 0;
}

Dictionary ZemBridge::handle_request(int64_t p_msg_type, const PackedByteArray &p_payload) {
	Dictionary result;

	std::lock_guard<std::mutex> lock(backend_mutex);
	if (!ensure_backend_locked()) {
		result["ok"] = false;
		result["error"] = "Unable to create native backend";
		return result;
	}

	uint8_t *payload_ptr = nullptr;
	if (p_payload.size() > 0) {
		payload_ptr = const_cast<uint8_t *>(p_payload.ptr());
	}

	ZemResponse response = ZemBackendHandleRequest(
			backend_handle,
			static_cast<uint16_t>(p_msg_type),
			payload_ptr,
			static_cast<uint32_t>(p_payload.size()));

	PackedByteArray response_payload;
	if (response.data != nullptr && response.len > 0) {
		response_payload.resize(static_cast<int32_t>(response.len));
		std::copy(response.data, response.data + response.len, response_payload.ptrw());
	}
	ZemResponseFree(response.data);

	if (response.message_type == MSG_ERROR) {
		result["ok"] = false;
		result["error"] = decode_error_payload(response_payload);
		return result;
	}

	result["ok"] = true;
	result["type"] = static_cast<int64_t>(response.message_type);
	result["payload"] = response_payload;
	return result;
}

String ZemBridge::get_backend_version() {
	PackedByteArray empty;
	Dictionary response = handle_request(MSG_GET_VERSION, empty);
	if (!bool(response.get("ok", false))) {
		return String();
	}
	PackedByteArray payload = response.get("payload", PackedByteArray());
	if (payload.size() < 2) {
		return String();
	}
	uint16_t len = payload.decode_u16(0);
	if (payload.size() < 2 + len) {
		return String();
	}
	return decode_wire_text(payload.slice(0, 2 + len), 2);
}
