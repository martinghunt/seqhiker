extends "res://tests/godot/test_case.gd"

const ZemClientScript = preload("res://scripts/zem_client.gd")

var client: RefCounted


func setup() -> void:
	client = ZemClientScript.new()


func teardown() -> void:
	client = null


func test_encode_string_payload_prefixes_utf8_length() -> void:
	var payload: PackedByteArray = client._encode_string_payload("abc")

	assert_eq(payload.size(), 5)
	assert_eq(int(payload.decode_u16(0)), 3)
	assert_eq(payload.slice(2, payload.size()).get_string_from_utf8(), "abc")


func test_encode_tile_payload_uses_source_less_tile_layout() -> void:
	var payload: PackedByteArray = client._encode_tile_payload(12, 3, 456)

	assert_eq(payload.size(), 7)
	assert_eq(int(payload.decode_u16(0)), 12)
	assert_eq(int(payload[2]), 3)
	assert_eq(int(payload.decode_u32(3)), 456)


func test_encode_source_tile_payload_prefixes_source_id() -> void:
	var payload: PackedByteArray = client._encode_source_tile_payload(7, 12, 3, 456)

	assert_eq(payload.size(), 9)
	assert_eq(int(payload.decode_u16(0)), 7)
	assert_eq(int(payload.decode_u16(2)), 12)
	assert_eq(int(payload[4]), 3)
	assert_eq(int(payload.decode_u32(5)), 456)


func test_encode_dna_search_payload_uppercases_pattern_and_clamps_hits() -> void:
	var payload: PackedByteArray = client._encode_dna_search_payload(4, "acgt", true, 70000)

	assert_eq(payload.size(), 11)
	assert_eq(int(payload.decode_u16(0)), 4)
	assert_eq(int(payload.decode_u16(2)), 65535)
	assert_eq(int(payload[4]), 1)
	assert_eq(int(payload.decode_u16(5)), 4)
	assert_eq(payload.slice(7, payload.size()).get_string_from_utf8(), "ACGT")
