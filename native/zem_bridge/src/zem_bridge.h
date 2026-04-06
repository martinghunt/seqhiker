#ifndef SEQHIKER_ZEM_BRIDGE_H
#define SEQHIKER_ZEM_BRIDGE_H

#include <cstdint>
#include <mutex>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/string.hpp>

class ZemBridge : public godot::RefCounted {
	GDCLASS(ZemBridge, godot::RefCounted)

	static std::mutex backend_mutex;
	static uint64_t backend_handle;
	static uint32_t instance_count;

	static void _bind_methods();
	static bool ensure_backend_locked();
	static godot::String decode_wire_text(const godot::PackedByteArray &p_payload, int32_t p_offset);
	static godot::String decode_error_payload(const godot::PackedByteArray &p_payload);

public:
	ZemBridge();
	~ZemBridge();

	bool is_ready() const;
	godot::Dictionary handle_request(int64_t p_msg_type, const godot::PackedByteArray &p_payload);
	godot::String get_backend_version();
};

#endif
