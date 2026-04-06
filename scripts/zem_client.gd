extends RefCounted
class_name ZemClient

const ZemNativeTransportScript = preload("res://scripts/zem_native_transport.gd")

const MSG_LOAD_GENOME := 1
const MSG_LOAD_BAM := 2
const MSG_GET_TILE := 3
const MSG_GET_COVERAGE_TILE := 4
const MSG_GET_ANNOTATIONS := 5
const MSG_GET_REFERENCE_SLICE := 6
const MSG_ACK := 7
const MSG_ERROR := 8
const MSG_SHUTDOWN := 9
const MSG_GET_CHROMOSOMES := 10
const MSG_GET_GC_PLOT_TILE := 11
const MSG_GET_ANNOTATION_COUNTS := 12
const MSG_GET_LOAD_STATE := 13
const MSG_INSPECT_INPUT := 14
const MSG_GET_ANNOTATION_TILE := 15
const MSG_SEARCH_DNA_EXACT := 16
const MSG_GET_STRAND_COVERAGE_TILE := 17
const MSG_DOWNLOAD_GENOME := 18
const MSG_GET_VERSION := 19
const MSG_GENERATE_TEST_DATA := 20
const MSG_ADD_COMPARISON_GENOME := 21
const MSG_LIST_COMPARISON_GENOMES := 22
const MSG_LIST_COMPARISON_PAIRS := 23
const MSG_GET_COMPARISON_BLOCKS := 24
const MSG_GET_COMPARISON_BLOCKS_BY_GENOMES := 25
const MSG_GET_COMPARISON_ANNOTATIONS := 26
const MSG_SAVE_COMPARISON_SESSION := 27
const MSG_LOAD_COMPARISON_SESSION := 28
const MSG_RESET_COMPARISON_STATE := 29
const MSG_GENERATE_COMPARISON_TEST_DATA := 30
const MSG_GET_COMPARISON_REFERENCE_SLICE := 31
const MSG_GET_COMPARISON_BLOCK_DETAIL := 32
const MSG_ADD_COMPARISON_GENOME_FILES := 33
const MSG_SEARCH_COMPARISON_DNA_EXACT := 34
const MSG_GET_STOP_CODON_TILE := 35
const MSG_LOAD_VARIANT_FILE := 36
const MSG_LIST_VARIANT_SOURCES := 37
const MSG_GET_VARIANT_TILE := 38
const MSG_GET_VARIANT_DETAIL := 39
const MSG_LOAD_GENOME_FILES := 40
const MSG_RESET_BROWSER_STATE := 41
const NAME_KEYS := ["Name=", "gene=", "locus_tag=", "ID="]
const DISPLAY_NAME_KEYS := ["Name=", "gene=", "locus_tag="]
const REQUEST_TIMEOUT_MS := 1800
const LOAD_TIMEOUT_MS := 120000

var _transport: RefCounted = ZemNativeTransportScript.new()

func connect_to_server(host: String = "127.0.0.1", port: int = 9000, timeout_ms: int = 1200) -> bool:
	return _transport.connect_to_server(host, port, timeout_ms)

func disconnect_from_server() -> void:
	_transport.disconnect_from_server()

func ensure_connected() -> bool:
	return _transport.ensure_connected()

func set_transport(transport: RefCounted) -> void:
	if transport == null:
		return
	_transport = transport

func spawn_peer_client() -> RefCounted:
	var client: RefCounted = get_script().new()
	if _transport != null and _transport.has_method("spawn_peer_transport"):
		client.set_transport(_transport.spawn_peer_transport())
	return client

func requires_server_process() -> bool:
	if _transport != null and _transport.has_method("requires_server_process"):
		return bool(_transport.requires_server_process())
	return true

func load_genome(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	return _send_request(MSG_LOAD_GENOME, payload, LOAD_TIMEOUT_MS)

func load_genome_files(paths: PackedStringArray) -> Dictionary:
	var payload := _encode_string_list(paths)
	return _send_request(MSG_LOAD_GENOME_FILES, payload, LOAD_TIMEOUT_MS)

func add_comparison_genome_files(paths: PackedStringArray) -> Dictionary:
	var payload := _encode_string_list(paths)
	var resp := _send_request(MSG_ADD_COMPARISON_GENOME_FILES, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	var genomes := _parse_comparison_genomes(resp.get("payload", PackedByteArray()))
	resp["genome"] = genomes[0] if not genomes.is_empty() else {}
	return resp

func load_bam(path: String, precompute_cutoff_bp: int = 0) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var cutoff := maxi(0, precompute_cutoff_bp)
	var payload := PackedByteArray()
	payload.resize(7 + path_bytes.size())
	payload[0] = 0xFF
	payload.encode_u32(1, cutoff)
	payload.encode_u16(5, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[7 + i] = path_bytes[i]
	var resp := _send_request(MSG_LOAD_BAM, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		# Backward-compat fallback for older servers expecting the legacy payload.
		payload = PackedByteArray()
		payload.resize(2 + path_bytes.size())
		payload.encode_u16(0, path_bytes.size())
		for i in range(path_bytes.size()):
			payload[2 + i] = path_bytes[i]
		resp = _send_request(MSG_LOAD_BAM, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	var p: PackedByteArray = resp.get("payload", PackedByteArray())
	if p.size() >= 4:
		resp["source_id"] = int(p.decode_u16(0))
		resp["message"] = _decode_wire_text(p.slice(4, p.size()))
	else:
		resp["source_id"] = 0
	return resp

func get_chromosomes() -> Dictionary:
	var resp := _send_request(MSG_GET_CHROMOSOMES, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["chromosomes"] = _parse_chromosomes(resp["payload"])
	return resp

func get_annotation_counts() -> Dictionary:
	var resp := _send_request(MSG_GET_ANNOTATION_COUNTS, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["counts"] = _parse_annotation_counts(resp["payload"])
	return resp

func get_load_state() -> Dictionary:
	var resp := _send_request(MSG_GET_LOAD_STATE, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	var payload: PackedByteArray = resp.get("payload", PackedByteArray())
	resp["has_sequence"] = payload.size() > 0 and payload[0] != 0
	return resp

func inspect_input(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	var resp := _send_request(MSG_INSPECT_INPUT, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	var raw: PackedByteArray = resp.get("payload", PackedByteArray())
	var flags := raw[0] if raw.size() > 0 else 0
	resp["has_sequence"] = (flags & 1) != 0
	resp["has_annotation"] = (flags & 2) != 0
	resp["is_comparison_session"] = (flags & 4) != 0
	resp["has_embedded_gff3_sequence"] = (flags & 8) != 0
	resp["has_variants"] = (flags & 16) != 0
	return resp

func _encode_string_list(values: PackedStringArray) -> PackedByteArray:
	var total := 2
	var encoded := []
	for value_any in values:
		var value := str(value_any)
		var bytes := value.to_utf8_buffer()
		encoded.append(bytes)
		total += 2 + bytes.size()
	var payload := PackedByteArray()
	payload.resize(total)
	payload.encode_u16(0, values.size())
	var off := 2
	for bytes_any in encoded:
		var bytes: PackedByteArray = bytes_any
		payload.encode_u16(off, bytes.size())
		off += 2
		for i in range(bytes.size()):
			payload[off + i] = bytes[i]
		off += bytes.size()
	return payload

func get_tile(chr_id: int, zoom: int, tile_index: int, source_id: int = 0) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(9)
	payload.encode_u16(0, source_id)
	payload.encode_u16(2, chr_id)
	payload[4] = zoom
	payload.encode_u32(5, tile_index)
	var resp := _send_request(MSG_GET_TILE, payload)
	if not resp.get("ok", false):
		# Backward-compat fallback for older zem servers that still expect
		# the legacy 7-byte tile payload (no source_id prefix).
		var legacy_payload := PackedByteArray()
		legacy_payload.resize(7)
		legacy_payload.encode_u16(0, chr_id)
		legacy_payload[2] = zoom
		legacy_payload.encode_u32(3, tile_index)
		resp = _send_request(MSG_GET_TILE, legacy_payload)
	if not resp.get("ok", false):
		return resp
	resp["reads"] = _parse_tile_reads(resp["payload"])
	return resp

func get_coverage_tile(chr_id: int, zoom: int, tile_index: int, source_id: int = 0) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(9)
	payload.encode_u16(0, source_id)
	payload.encode_u16(2, chr_id)
	payload[4] = zoom
	payload.encode_u32(5, tile_index)
	var resp := _send_request(MSG_GET_COVERAGE_TILE, payload)
	if not resp.get("ok", false):
		# Backward-compat fallback for older zem servers that still expect
		# the legacy 7-byte coverage payload (no source_id prefix).
		var legacy_payload := PackedByteArray()
		legacy_payload.resize(7)
		legacy_payload.encode_u16(0, chr_id)
		legacy_payload[2] = zoom
		legacy_payload.encode_u32(3, tile_index)
		resp = _send_request(MSG_GET_COVERAGE_TILE, legacy_payload)
	if not resp.get("ok", false):
		return resp
	resp["coverage"] = _parse_coverage_tile(resp["payload"])
	return resp

func get_strand_coverage_tile(chr_id: int, zoom: int, tile_index: int, source_id: int = 0) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(9)
	payload.encode_u16(0, source_id)
	payload.encode_u16(2, chr_id)
	payload[4] = zoom
	payload.encode_u32(5, tile_index)
	var resp := _send_request(MSG_GET_STRAND_COVERAGE_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["coverage"] = _parse_strand_coverage_tile(resp["payload"])
	return resp

func get_gc_plot_tile(chr_id: int, zoom: int, tile_index: int, window_len_bp: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(11)
	payload.encode_u16(0, chr_id)
	payload[2] = zoom
	payload.encode_u32(3, tile_index)
	payload.encode_u32(7, max(window_len_bp, 1))
	var resp := _send_request(MSG_GET_GC_PLOT_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["plot"] = _parse_gc_plot_tile(resp["payload"])
	return resp

func get_annotations(chr_id: int, start_bp: int, end_bp: int, max_records: int = 2000, min_feature_len_bp: int = 1) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(16)
	payload.encode_u16(0, chr_id)
	payload.encode_u32(2, start_bp)
	payload.encode_u32(6, end_bp)
	payload.encode_u16(10, max_records)
	payload.encode_u32(12, max(min_feature_len_bp, 1))
	var resp := _send_request(MSG_GET_ANNOTATIONS, payload)
	if not resp.get("ok", false):
		return resp
	resp["features"] = _parse_annotations(resp["payload"])
	return resp

func get_annotation_tile(chr_id: int, zoom: int, tile_index: int, max_records: int = 2000, min_feature_len_bp: int = 1) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(13)
	payload.encode_u16(0, chr_id)
	payload[2] = zoom
	payload.encode_u32(3, tile_index)
	payload.encode_u16(7, max(1, min(max_records, 65535)))
	payload.encode_u32(9, max(min_feature_len_bp, 1))
	var resp := _send_request(MSG_GET_ANNOTATION_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["features"] = _parse_annotations(resp["payload"])
	return resp

func get_stop_codon_tile(chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(7)
	payload.encode_u16(0, chr_id)
	payload[2] = zoom
	payload.encode_u32(3, tile_index)
	var resp := _send_request(MSG_GET_STOP_CODON_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["tile"] = _parse_stop_codon_tile(resp["payload"])
	return resp

func load_variant_file(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	var resp := _send_request(MSG_LOAD_VARIANT_FILE, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	var payload_bytes: PackedByteArray = resp.get("payload", PackedByteArray())
	if payload_bytes.size() >= 4:
		resp.merge(_parse_variant_source_loaded(payload_bytes), true)
	return resp

func list_variant_sources() -> Dictionary:
	var resp := _send_request(MSG_LIST_VARIANT_SOURCES, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["sources"] = _parse_variant_sources(resp.get("payload", PackedByteArray()))
	return resp

func get_variant_tile(source_id: int, chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(9)
	payload.encode_u16(0, source_id)
	payload.encode_u16(2, chr_id)
	payload[4] = zoom
	payload.encode_u32(5, tile_index)
	var resp := _send_request(MSG_GET_VARIANT_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["tile"] = _parse_variant_tile(resp.get("payload", PackedByteArray()))
	return resp

func get_variant_detail(source_id: int, chr_id: int, start_bp: int, ref: String, alt_summary: String) -> Dictionary:
	var ref_bytes := ref.to_utf8_buffer()
	var alt_bytes := alt_summary.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(12 + ref_bytes.size() + alt_bytes.size())
	payload.encode_u16(0, source_id)
	payload.encode_u16(2, chr_id)
	payload.encode_u32(4, start_bp)
	payload.encode_u16(8, ref_bytes.size())
	payload.encode_u16(10, alt_bytes.size())
	for i in range(ref_bytes.size()):
		payload[12 + i] = ref_bytes[i]
	for i in range(alt_bytes.size()):
		payload[12 + ref_bytes.size() + i] = alt_bytes[i]
	var resp := _send_request(MSG_GET_VARIANT_DETAIL, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["detail"] = _parse_variant_detail(resp.get("payload", PackedByteArray()))
	return resp

func get_reference_slice(chr_id: int, start_bp: int, end_bp: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(10)
	payload.encode_u16(0, chr_id)
	payload.encode_u32(2, start_bp)
	payload.encode_u32(6, end_bp)
	var resp := _send_request(MSG_GET_REFERENCE_SLICE, payload)
	if not resp.get("ok", false):
		return resp
	resp.merge(_parse_reference_slice(resp["payload"]), true)
	return resp

func search_dna_exact(chr_id: int, pattern: String, include_revcomp: bool, max_hits: int = 5000) -> Dictionary:
	var pattern_bytes := pattern.to_upper().to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(7 + pattern_bytes.size())
	payload.encode_u16(0, chr_id)
	payload.encode_u16(2, max(1, min(max_hits, 65535)))
	payload[4] = 1 if include_revcomp else 0
	payload.encode_u16(5, pattern_bytes.size())
	for i in range(pattern_bytes.size()):
		payload[7 + i] = pattern_bytes[i]
	var resp := _send_request(MSG_SEARCH_DNA_EXACT, payload)
	if not resp.get("ok", false):
		return resp
	resp.merge(_parse_dna_exact_hits(resp["payload"]), true)
	return resp

func search_comparison_dna_exact(genome_id: int, pattern: String, include_revcomp: bool, max_hits: int = 5000) -> Dictionary:
	var pattern_bytes := pattern.to_upper().to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(7 + pattern_bytes.size())
	payload.encode_u16(0, genome_id)
	payload.encode_u16(2, max(1, min(max_hits, 65535)))
	payload[4] = 1 if include_revcomp else 0
	payload.encode_u16(5, pattern_bytes.size())
	for i in range(pattern_bytes.size()):
		payload[7 + i] = pattern_bytes[i]
	var resp := _send_request(MSG_SEARCH_COMPARISON_DNA_EXACT, payload)
	if not resp.get("ok", false):
		return resp
	resp.merge(_parse_dna_exact_hits(resp["payload"]), true)
	return resp

func download_genome(accession: String, cache_dir: String = "", max_cache_bytes: int = 0) -> Dictionary:
	var accession_bytes := accession.strip_edges().to_utf8_buffer()
	var cache_dir_bytes := cache_dir.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(8 + accession_bytes.size() + cache_dir_bytes.size())
	payload.encode_u16(0, accession_bytes.size())
	for i in range(accession_bytes.size()):
		payload[2 + i] = accession_bytes[i]
	var off := 2 + accession_bytes.size()
	payload.encode_u16(off, cache_dir_bytes.size())
	off += 2
	for i in range(cache_dir_bytes.size()):
		payload[off + i] = cache_dir_bytes[i]
	off += cache_dir_bytes.size()
	payload.encode_u32(off, maxi(0, max_cache_bytes))
	var resp := _send_request(MSG_DOWNLOAD_GENOME, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["files"] = _parse_string_list(resp.get("payload", PackedByteArray()))
	return resp

func get_server_version() -> Dictionary:
	var resp := _send_request(MSG_GET_VERSION, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["version"] = _decode_ack_message(resp.get("payload", PackedByteArray()))
	return resp

func generate_test_data(root_dir: String) -> Dictionary:
	var root_bytes := root_dir.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + root_bytes.size())
	payload.encode_u16(0, root_bytes.size())
	for i in range(root_bytes.size()):
		payload[2 + i] = root_bytes[i]
	var resp := _send_request(MSG_GENERATE_TEST_DATA, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["files"] = _parse_string_list(resp.get("payload", PackedByteArray()))
	return resp

func add_comparison_genome(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	var resp := _send_request(MSG_ADD_COMPARISON_GENOME, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	var genomes := _parse_comparison_genomes(resp.get("payload", PackedByteArray()))
	resp["genome"] = genomes[0] if not genomes.is_empty() else {}
	return resp

func list_comparison_genomes() -> Dictionary:
	var resp := _send_request(MSG_LIST_COMPARISON_GENOMES, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["genomes"] = _parse_comparison_genomes(resp.get("payload", PackedByteArray()))
	return resp

func list_comparison_pairs() -> Dictionary:
	var resp := _send_request(MSG_LIST_COMPARISON_PAIRS, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["pairs"] = _parse_comparison_pairs(resp.get("payload", PackedByteArray()))
	return resp

func get_comparison_blocks(pair_id: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(2)
	payload.encode_u16(0, pair_id)
	var resp := _send_request(MSG_GET_COMPARISON_BLOCKS, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["blocks"] = _parse_comparison_blocks(resp.get("payload", PackedByteArray()))
	return resp

func get_comparison_blocks_by_genomes(query_genome_id: int, target_genome_id: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(4)
	payload.encode_u16(0, query_genome_id)
	payload.encode_u16(2, target_genome_id)
	var resp := _send_request(MSG_GET_COMPARISON_BLOCKS_BY_GENOMES, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["blocks"] = _parse_comparison_blocks(resp.get("payload", PackedByteArray()))
	return resp

func get_comparison_annotations(genome_id: int, start_bp: int, end_bp: int, max_records: int = 2000, min_feature_len_bp: int = 1) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(16)
	payload.encode_u16(0, genome_id)
	payload.encode_u32(2, start_bp)
	payload.encode_u32(6, end_bp)
	payload.encode_u16(10, max_records)
	payload.encode_u32(12, max(min_feature_len_bp, 1))
	var resp := _send_request(MSG_GET_COMPARISON_ANNOTATIONS, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["features"] = _parse_annotations(resp.get("payload", PackedByteArray()))
	return resp

func get_comparison_reference_slice(genome_id: int, start_bp: int, end_bp: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(10)
	payload.encode_u16(0, genome_id)
	payload.encode_u32(2, start_bp)
	payload.encode_u32(6, end_bp)
	var resp := _send_request(MSG_GET_COMPARISON_REFERENCE_SLICE, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["slice"] = _parse_reference_slice(resp.get("payload", PackedByteArray()))
	return resp

func get_comparison_block_detail(query_genome_id: int, target_genome_id: int, block: Dictionary) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(21)
	payload.encode_u16(0, query_genome_id)
	payload.encode_u16(2, target_genome_id)
	payload.encode_u32(4, int(block.get("query_start", 0)))
	payload.encode_u32(8, int(block.get("query_end", 0)))
	payload.encode_u32(12, int(block.get("target_start", 0)))
	payload.encode_u32(16, int(block.get("target_end", 0)))
	payload[20] = 1 if bool(block.get("same_strand", true)) else 0
	var resp := _send_request(MSG_GET_COMPARISON_BLOCK_DETAIL, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["detail"] = _parse_comparison_block_detail(resp.get("payload", PackedByteArray()))
	return resp

func save_comparison_session(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	return _send_request(MSG_SAVE_COMPARISON_SESSION, payload, LOAD_TIMEOUT_MS)

func load_comparison_session(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	return _send_request(MSG_LOAD_COMPARISON_SESSION, payload, LOAD_TIMEOUT_MS)

func reset_comparison_state() -> Dictionary:
	return _send_request(MSG_RESET_COMPARISON_STATE, PackedByteArray(), LOAD_TIMEOUT_MS)

func reset_browser_state() -> Dictionary:
	return _send_request(MSG_RESET_BROWSER_STATE, PackedByteArray(), LOAD_TIMEOUT_MS)

func generate_comparison_test_data(root_dir: String) -> Dictionary:
	var root_bytes := root_dir.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + root_bytes.size())
	payload.encode_u16(0, root_bytes.size())
	for i in range(root_bytes.size()):
		payload[2 + i] = root_bytes[i]
	var resp := _send_request(MSG_GENERATE_COMPARISON_TEST_DATA, payload, LOAD_TIMEOUT_MS)
	if not resp.get("ok", false):
		return resp
	resp["files"] = _parse_string_list(resp.get("payload", PackedByteArray()))
	return resp

func connection_info() -> Dictionary:
	return _transport.connection_info()

func shutdown_server(timeout_ms: int = 600) -> Dictionary:
	return _send_request(MSG_SHUTDOWN, PackedByteArray(), timeout_ms)

func _send_request(msg_type: int, payload: PackedByteArray, timeout_ms: int = REQUEST_TIMEOUT_MS) -> Dictionary:
	return _transport.send_request(msg_type, payload, timeout_ms)

func _decode_ack_message(payload: PackedByteArray) -> String:
	if payload.size() < 2:
		return ""
	var ln := payload.decode_u16(0)
	if payload.size() < 2 + ln:
		return ""
	return _decode_wire_text(payload.slice(2, 2 + ln))

func _parse_chromosomes(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 8 > payload.size():
			break
		var chr_id := payload.decode_u16(off)
		var length := payload.decode_u32(off + 2)
		var name_len := payload.decode_u16(off + 6)
		off += 8
		if off + name_len > payload.size():
			break
		var name := _decode_wire_text(payload.slice(off, off + name_len))
		off += name_len
		out.append({"id": chr_id, "length": length, "name": name})
	return out

func _parse_string_list(payload: PackedByteArray) -> PackedStringArray:
	var out := PackedStringArray()
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 2 > payload.size():
			break
		var item_len := payload.decode_u16(off)
		off += 2
		if off + item_len > payload.size():
			break
		out.append(_decode_wire_text(payload.slice(off, off + item_len)))
		off += item_len
	return out

func _parse_annotation_counts(payload: PackedByteArray) -> Dictionary:
	var out := {}
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 6 > payload.size():
			break
		var chr_id := payload.decode_u16(off)
		var n := payload.decode_u32(off + 2)
		out[chr_id] = int(n)
		off += 6
	return out

func _parse_comparison_genomes(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 14 > payload.size():
			break
		var genome_id := payload.decode_u16(off)
		var length_bp := payload.decode_u32(off + 2)
		var segment_count := payload.decode_u16(off + 6)
		var feature_count := payload.decode_u32(off + 8)
		var name_len := payload.decode_u16(off + 12)
		off += 14
		if off + name_len + 2 > payload.size():
			break
		var name := _decode_wire_text(payload.slice(off, off + name_len))
		off += name_len
		var path_len := payload.decode_u16(off)
		off += 2
		if off + path_len > payload.size():
			break
		var path := _decode_wire_text(payload.slice(off, off + path_len))
		off += path_len
		var segments: Array[Dictionary] = []
		for _seg_i in range(segment_count):
			if off + 14 > payload.size():
				break
			var seg_start := payload.decode_u32(off)
			var seg_end := payload.decode_u32(off + 4)
			var seg_feature_count := payload.decode_u32(off + 8)
			var seg_name_len := payload.decode_u16(off + 12)
			off += 14
			if off + seg_name_len > payload.size():
				break
			var seg_name := _decode_wire_text(payload.slice(off, off + seg_name_len))
			off += seg_name_len
			segments.append({
				"name": seg_name,
				"start": int(seg_start),
				"end": int(seg_end),
				"feature_count": int(seg_feature_count)
			})
		out.append({
			"id": int(genome_id),
			"name": name,
			"path": path,
			"length": int(length_bp),
			"segment_count": int(segment_count),
			"feature_count": int(feature_count),
			"segments": segments,
			"features": []
		})
	return out

func _parse_comparison_pairs(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 13 > payload.size():
			break
		out.append({
			"id": int(payload.decode_u16(off)),
			"top_genome_id": int(payload.decode_u16(off + 2)),
			"bottom_genome_id": int(payload.decode_u16(off + 4)),
			"block_count": int(payload.decode_u32(off + 6)),
			"status": int(payload[off + 10])
		})
		off += 13
	return out

func _parse_comparison_blocks(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 2:
		return out
	var count := payload.decode_u16(0)
	var off := 2
	for _i in range(count):
		if off + 19 > payload.size():
			break
		var pct_x100 := int(payload.decode_u16(off + 16))
		out.append({
			"query_start": int(payload.decode_u32(off)),
			"query_end": int(payload.decode_u32(off + 4)),
			"target_start": int(payload.decode_u32(off + 8)),
			"target_end": int(payload.decode_u32(off + 12)),
			"percent_identity_x100": pct_x100,
			"percent_identity": float(pct_x100) / 100.0,
			"same_strand": payload[off + 18] != 0
		})
		off += 19
	return out

func _parse_comparison_block_detail(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 25:
		return {}
	var op_len := int(payload.decode_u32(19))
	if payload.size() < 23 + op_len + 2:
		return {}
	var ops := _decode_wire_text(payload.slice(23, 23 + op_len))
	var off := 23 + op_len
	var variant_count := int(payload.decode_u16(off))
	off += 2
	var variants: Array[Dictionary] = []
	for _i in range(variant_count):
		if off + 13 > payload.size():
			break
		var kind := char(payload[off])
		var query_pos := int(payload.decode_u32(off + 1))
		var target_pos := int(payload.decode_u32(off + 5))
		var ref_len := int(payload.decode_u16(off + 9))
		var alt_len := int(payload.decode_u16(off + 11))
		off += 13
		if off + ref_len + alt_len > payload.size():
			break
		var ref_bases := _decode_wire_text(payload.slice(off, off + ref_len))
		off += ref_len
		var alt_bases := _decode_wire_text(payload.slice(off, off + alt_len))
		off += alt_len
		variants.append({
			"kind": kind,
			"query_pos": query_pos,
			"target_pos": target_pos,
			"ref_bases": ref_bases,
			"alt_bases": alt_bases
		})
	return {
		"query_start": int(payload.decode_u32(0)),
		"query_end": int(payload.decode_u32(4)),
		"target_start": int(payload.decode_u32(8)),
		"target_end": int(payload.decode_u32(12)),
		"percent_identity_x100": int(payload.decode_u16(16)),
		"percent_identity": float(payload.decode_u16(16)) / 100.0,
		"same_strand": payload[18] != 0,
		"ops": ops,
		"variants": variants
	}

func _parse_variant_source_loaded(payload: PackedByteArray) -> Dictionary:
	var out := {
		"source_id": 0,
		"sample_names": PackedStringArray(),
		"message": ""
	}
	if payload.size() < 4:
		return out
	var source_id := int(payload.decode_u16(0))
	var sample_count := int(payload.decode_u16(2))
	var off := 4
	var sample_names := PackedStringArray()
	for _i in range(sample_count):
		if off + 2 > payload.size():
			break
		var sample_len := int(payload.decode_u16(off))
		off += 2
		if off + sample_len > payload.size():
			break
		sample_names.append(_decode_wire_text(payload.slice(off, off + sample_len)))
		off += sample_len
	if off + 2 <= payload.size():
		var msg_len := int(payload.decode_u16(off))
		off += 2
		if off + msg_len <= payload.size():
			out["message"] = _decode_wire_text(payload.slice(off, off + msg_len))
	out["source_id"] = source_id
	out["sample_names"] = sample_names
	return out

func _parse_variant_sources(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 2:
		return out
	var count := int(payload.decode_u16(0))
	var off := 2
	for _i in range(count):
		if off + 8 > payload.size():
			break
		var source_id := int(payload.decode_u16(off))
		var name_len := int(payload.decode_u16(off + 2))
		var path_len := int(payload.decode_u16(off + 4))
		var sample_count := int(payload.decode_u16(off + 6))
		off += 8
		if off + name_len + path_len > payload.size():
			break
		var name := _decode_wire_text(payload.slice(off, off + name_len))
		off += name_len
		var path := _decode_wire_text(payload.slice(off, off + path_len))
		off += path_len
		var sample_names := PackedStringArray()
		for _j in range(sample_count):
			if off + 2 > payload.size():
				break
			var sample_len := int(payload.decode_u16(off))
			off += 2
			if off + sample_len > payload.size():
				break
			sample_names.append(_decode_wire_text(payload.slice(off, off + sample_len)))
			off += sample_len
		out.append({
			"id": source_id,
			"name": name,
			"path": path,
			"sample_names": sample_names
		})
	return out

func _parse_variant_tile(payload: PackedByteArray) -> Dictionary:
	var out := {
		"start": 0,
		"end": 0,
		"variants": []
	}
	if payload.size() < 13:
		return out
	var tile_type := int(payload[0])
	if tile_type != 1:
		return out
	var tile_start := int(payload.decode_u32(1))
	var tile_end := int(payload.decode_u32(5))
	var count := int(payload.decode_u32(9))
	var off := 13
	var variants: Array[Dictionary] = []
	for _i in range(count):
		if off + 27 > payload.size():
			break
		var start_bp := int(payload.decode_u32(off))
		var end_bp := int(payload.decode_u32(off + 4))
		var kind := int(payload[off + 8])
		var sample_count := int(payload.decode_u16(off + 9))
		var qual := payload.decode_float(off + 11)
		var class_len := int(payload.decode_u16(off + 15))
		var text_blob_len := int(payload.decode_u16(off + 17))
		var id_len := int(payload.decode_u16(off + 19))
		var ref_len := int(payload.decode_u16(off + 21))
		var alt_len := int(payload.decode_u16(off + 23))
		var filter_len := int(payload.decode_u16(off + 25))
		off += 27
		if off + class_len + text_blob_len + id_len + ref_len + alt_len + filter_len > payload.size():
			break
		var sample_classes := PackedByteArray()
		if class_len > 0:
			sample_classes = payload.slice(off, off + class_len)
		off += class_len
		var sample_texts := PackedStringArray()
		var text_end := off + text_blob_len
		for _j in range(sample_count):
			if off + 2 > text_end:
				break
			var text_len := int(payload.decode_u16(off))
			off += 2
			if off + text_len > text_end:
				break
			sample_texts.append(_decode_wire_text(payload.slice(off, off + text_len)))
			off += text_len
		off = text_end
		var rec_id := _decode_wire_text(payload.slice(off, off + id_len))
		off += id_len
		var ref := _decode_wire_text(payload.slice(off, off + ref_len))
		off += ref_len
		var alt_summary := _decode_wire_text(payload.slice(off, off + alt_len))
		off += alt_len
		var filter := _decode_wire_text(payload.slice(off, off + filter_len))
		off += filter_len
		variants.append({
			"start": start_bp,
			"end": end_bp,
			"kind": kind,
			"sample_count": sample_count,
			"sample_classes": sample_classes,
			"sample_texts": sample_texts,
			"qual": qual,
			"id": rec_id,
			"ref": ref,
			"alt_summary": alt_summary,
			"filter": filter
		})
	out["start"] = tile_start
	out["end"] = tile_end
	out["variants"] = variants
	return out

func _parse_variant_detail(payload: PackedByteArray) -> Dictionary:
	var out := {}
	if payload.size() < 29:
		return out
	var source_id := int(payload.decode_u16(0))
	var start_bp := int(payload.decode_u32(2))
	var end_bp := int(payload.decode_u32(6))
	var kind := int(payload[10])
	var qual := payload.decode_float(11)
	var format_count := int(payload.decode_u16(15))
	var sample_count := int(payload.decode_u16(17))
	var source_name_len := int(payload.decode_u16(19))
	var source_path_len := int(payload.decode_u16(21))
	var chrom_len := int(payload.decode_u16(23))
	var id_len := int(payload.decode_u16(25))
	var ref_len := int(payload.decode_u16(27))
	var off := 29
	var variable_texts: Array[String] = []
	for _i in range(3):
		if off + 2 > payload.size():
			return out
		var text_len := int(payload.decode_u16(off))
		off += 2
		if off + text_len > payload.size():
			return out
		variable_texts.append(_decode_wire_text(payload.slice(off, off + text_len)))
		off += text_len
	if off + source_name_len + source_path_len + chrom_len + id_len + ref_len > payload.size():
		return out
	var source_name := _decode_wire_text(payload.slice(off, off + source_name_len))
	off += source_name_len
	var source_path := _decode_wire_text(payload.slice(off, off + source_path_len))
	off += source_path_len
	var chrom := _decode_wire_text(payload.slice(off, off + chrom_len))
	off += chrom_len
	var rec_id := _decode_wire_text(payload.slice(off, off + id_len))
	off += id_len
	var ref := _decode_wire_text(payload.slice(off, off + ref_len))
	off += ref_len
	var format_keys := PackedStringArray()
	for _j in range(format_count):
		if off + 2 > payload.size():
			return out
		var key_len := int(payload.decode_u16(off))
		off += 2
		if off + key_len > payload.size():
			return out
		format_keys.append(_decode_wire_text(payload.slice(off, off + key_len)))
		off += key_len
	var samples: Array[Dictionary] = []
	for _k in range(sample_count):
		if off + 5 > payload.size():
			return out
		var has_alt := payload[off] != 0
		off += 1
		var name_len := int(payload.decode_u16(off))
		off += 2
		var value_len := int(payload.decode_u16(off))
		off += 2
		if off + name_len + value_len > payload.size():
			return out
		var sample_name := _decode_wire_text(payload.slice(off, off + name_len))
		off += name_len
		var sample_value := _decode_wire_text(payload.slice(off, off + value_len))
		off += value_len
		samples.append({
			"name": sample_name,
			"value": sample_value,
			"has_alt": has_alt
		})
	out["source_id"] = source_id
	out["source_name"] = source_name
	out["source_path"] = source_path
	out["chrom"] = chrom
	out["start"] = start_bp
	out["end"] = end_bp
	out["kind"] = kind
	out["id"] = rec_id
	out["ref"] = ref
	out["alt_summary"] = variable_texts[0] if variable_texts.size() > 0 else ""
	out["filter"] = variable_texts[1] if variable_texts.size() > 1 else ""
	out["info"] = variable_texts[2] if variable_texts.size() > 2 else ""
	out["qual"] = qual
	out["format_keys"] = format_keys
	out["samples"] = samples
	return out

func _parse_tile_reads(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 13:
		return out
	var tile_type := payload[0]
	if tile_type != 2:
		return out
	var count := payload.decode_u32(9)
	var off := 13
	for i in range(count):
		if off + 38 > payload.size():
			break
		var start_bp := payload.decode_u32(off)
		var end_bp := payload.decode_u32(off + 4)
		var mapq := payload[off + 8]
		var reverse := payload[off + 9] == 1
		var flags := payload.decode_u16(off + 10)
		var mate_start_u := payload.decode_u32(off + 12)
		var mate_end_u := payload.decode_u32(off + 16)
		var fragment_len := int(payload.decode_u32(off + 20))
		var mate_raw_start_u := payload.decode_u32(off + 24)
		var mate_raw_end_u := payload.decode_u32(off + 28)
		var mate_ref_id_u := payload.decode_u32(off + 32)
		var name_len := payload.decode_u16(off + 36)
		off += 38
		if off + name_len > payload.size():
			break
		var read_name := _decode_wire_text(payload.slice(off, off + name_len))
		off += name_len
		if off + 2 > payload.size():
			break
		var cigar_len := payload.decode_u16(off)
		off += 2
		if off + cigar_len > payload.size():
			break
		var cigar := _decode_wire_text(payload.slice(off, off + cigar_len))
		off += cigar_len
		if off + 2 > payload.size():
			break
		var soft_left_len := payload.decode_u16(off)
		off += 2
		if off + soft_left_len > payload.size():
			break
		var soft_clip_left := _decode_wire_text(payload.slice(off, off + soft_left_len))
		off += soft_left_len
		if off + 2 > payload.size():
			break
		var soft_right_len := payload.decode_u16(off)
		off += 2
		if off + soft_right_len > payload.size():
			break
		var soft_clip_right := _decode_wire_text(payload.slice(off, off + soft_right_len))
		off += soft_right_len
		var snps := PackedInt32Array()
		var snp_bases := PackedByteArray()
		if off + 2 <= payload.size():
			var snp_count := int(payload.decode_u16(off))
			off += 2
			for _s in range(snp_count):
				if off + 5 > payload.size():
					break
				snps.append(int(payload.decode_u32(off)))
				off += 4
				snp_bases.append(payload[off])
				off += 1
		else:
			snps = PackedInt32Array()
			snp_bases = PackedByteArray()
		out.append({
			"start": int(start_bp),
			"end": int(end_bp),
			"mapq": int(mapq),
			"reverse": reverse,
			"flags": int(flags),
			"name": read_name,
			"cigar": cigar,
			"soft_clip_left": soft_clip_left,
			"soft_clip_right": soft_clip_right,
			"snps": snps,
			"snp_bases": snp_bases,
			"mate_start": -1 if mate_start_u == 0xFFFFFFFF else int(mate_start_u),
			"mate_end": -1 if mate_end_u == 0xFFFFFFFF else int(mate_end_u),
			"mate_raw_start": -1 if mate_raw_start_u == 0xFFFFFFFF else int(mate_raw_start_u),
			"mate_raw_end": -1 if mate_raw_end_u == 0xFFFFFFFF else int(mate_raw_end_u),
			"mate_ref_id": -1 if mate_ref_id_u == 0xFFFFFFFF else int(mate_ref_id_u),
			"fragment_len": fragment_len,
			"row": i % 12
		})
	return out

func _parse_coverage_tile(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 13:
		return {"start": 0, "end": 0, "bins": PackedInt32Array()}
	var tile_type := payload[0]
	if tile_type != 1:
		return {"start": 0, "end": 0, "bins": PackedInt32Array()}
	var start_bp := int(payload.decode_u32(1))
	var end_bp := int(payload.decode_u32(5))
	var bin_count := int(payload.decode_u32(9))
	var bins := PackedInt32Array()
	var off := 13
	for _i in range(bin_count):
		if off + 2 > payload.size():
			break
		bins.append(int(payload.decode_u16(off)))
		off += 2
	return {
		"start": start_bp,
		"end": end_bp,
		"bins": bins
	}

func _parse_strand_coverage_tile(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 13:
		return {"start": 0, "end": 0, "forward": PackedInt32Array(), "reverse": PackedInt32Array()}
	var tile_type := payload[0]
	if tile_type != 4:
		return {"start": 0, "end": 0, "forward": PackedInt32Array(), "reverse": PackedInt32Array()}
	var start_bp := int(payload.decode_u32(1))
	var end_bp := int(payload.decode_u32(5))
	var bin_count := int(payload.decode_u32(9))
	var forward := PackedInt32Array()
	var reverse := PackedInt32Array()
	var off := 13
	for _i in range(bin_count):
		if off + 2 > payload.size():
			break
		forward.append(int(payload.decode_u16(off)))
		off += 2
	for _i in range(bin_count):
		if off + 2 > payload.size():
			break
		reverse.append(int(payload.decode_u16(off)))
		off += 2
	return {
		"start": start_bp,
		"end": end_bp,
		"forward": forward,
		"reverse": reverse
	}

func _parse_gc_plot_tile(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 17:
		return {"start": 0, "end": 0, "window": 0, "values": PackedFloat32Array()}
	var tile_type := payload[0]
	if tile_type != 3:
		return {"start": 0, "end": 0, "window": 0, "values": PackedFloat32Array()}
	var start_bp := int(payload.decode_u32(1))
	var end_bp := int(payload.decode_u32(5))
	var window_bp := int(payload.decode_u32(9))
	var count := int(payload.decode_u32(13))
	var values := PackedFloat32Array()
	var off := 17
	for _i in range(count):
		if off + 4 > payload.size():
			break
		values.append(payload.decode_float(off))
		off += 4
	return {
		"start": start_bp,
		"end": end_bp,
		"window": window_bp,
		"values": values
	}

func _parse_stop_codon_tile(payload: PackedByteArray) -> Dictionary:
	var empty_frames: Array = []
	for _i in range(6):
		empty_frames.append(PackedByteArray())
	if payload.size() < 13:
		return {"start": 0, "end": 0, "bin_count": 0, "frames": empty_frames}
	if payload[0] != 5:
		return {"start": 0, "end": 0, "bin_count": 0, "frames": empty_frames}
	var start_bp := int(payload.decode_u32(1))
	var end_bp := int(payload.decode_u32(5))
	var bin_count := int(payload.decode_u32(9))
	var off := 13
	var frames: Array = []
	for _frame in range(6):
		var bins := PackedByteArray()
		if off + bin_count <= payload.size():
			bins = payload.slice(off, off + bin_count)
		frames.append(bins)
		off += bin_count
	return {
		"start": start_bp,
		"end": end_bp,
		"bin_count": bin_count,
		"frames": frames
	}

func _parse_annotations(payload: PackedByteArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if payload.size() < 12:
		return out
	var count := payload.decode_u32(8)
	var off := 12
	for _i in range(count):
		if off + 12 > payload.size():
			break
		var start_bp := int(payload.decode_u32(off))
		var end_bp := int(payload.decode_u32(off + 4))
		var strand := char(payload[off + 8])
		var seq_name_len := payload.decode_u16(off + 10)
		off += 12
		if off + seq_name_len > payload.size():
			break
		var seq_name := _decode_wire_text(payload.slice(off, off + seq_name_len))
		off += seq_name_len
		if off + 2 > payload.size():
			break
		var src_len := payload.decode_u16(off)
		off += 2
		if off + src_len > payload.size():
			break
		var source := _decode_wire_text(payload.slice(off, off + src_len))
		off += src_len
		if off + 2 > payload.size():
			break
		var type_len := payload.decode_u16(off)
		off += 2
		if off + type_len > payload.size():
			break
		var feature_type := _decode_wire_text(payload.slice(off, off + type_len))
		off += type_len
		if off + 2 > payload.size():
			break
		var attr_len := payload.decode_u16(off)
		off += 2
		if off + attr_len > payload.size():
			break
		var attrs := _decode_wire_text(payload.slice(off, off + attr_len))
		off += attr_len
		var name := _extract_first_attr(attrs, DISPLAY_NAME_KEYS)
		var feature_id := _extract_first_attr(attrs, ["ID="])
		var parent_id := _extract_first_attr(attrs, ["Parent="])
		if name.is_empty():
			name = _extract_name(attrs, feature_type)
		out.append({
			"start": start_bp,
			"end": end_bp,
			"strand": strand,
			"seq_name": seq_name,
			"source": source,
			"type": feature_type,
			"name": name,
			"id": feature_id,
			"parent": parent_id
		})
	return out

func _parse_reference_slice(payload: PackedByteArray) -> Dictionary:
	if payload.size() < 12:
		return {"slice_start": 0, "slice_end": 0, "sequence": ""}
	var start_bp: int = int(payload.decode_u32(0))
	var end_bp: int = int(payload.decode_u32(4))
	var seq_len: int = int(payload.decode_u32(8))
	if payload.size() < 12 + seq_len:
		seq_len = max(0, payload.size() - 12)
	var seq: String = _decode_wire_text(payload.slice(12, 12 + seq_len))
	return {
		"slice_start": start_bp,
		"slice_end": end_bp,
		"sequence": seq
	}

func _parse_dna_exact_hits(payload: PackedByteArray) -> Dictionary:
	var hits: Array[Dictionary] = []
	if payload.size() < 3:
		return {"hits": hits, "truncated": false}
	var truncated := payload[0] != 0
	var count := int(payload.decode_u16(1))
	var off := 3
	for _i in range(count):
		if off + 9 > payload.size():
			break
		hits.append({
			"start": int(payload.decode_u32(off)),
			"end": int(payload.decode_u32(off + 4)),
			"strand": String.chr(payload[off + 8])
		})
		off += 9
	return {
		"hits": hits,
		"truncated": truncated
	}

func _decode_wire_text(bytes: PackedByteArray) -> String:
	# Protocol text fields are expected ASCII; decode permissively to avoid UTF-8 warning floods.
	return bytes.get_string_from_ascii()

func _extract_name(attrs: String, fallback: String) -> String:
	for key: String in NAME_KEYS:
		var pos: int = attrs.find(key)
		if pos >= 0:
			var start: int = pos + key.length()
			var end: int = attrs.find(";", start)
			if end == -1:
				end = attrs.length()
			return _trim_attr_value(attrs.substr(start, end - start))
	return fallback

func _extract_first_attr(attrs: String, keys: Array) -> String:
	for key in keys:
		var pos: int = attrs.find(key)
		if pos < 0:
			continue
		var start: int = pos + key.length()
		var end: int = attrs.find(";", start)
		if end == -1:
			end = attrs.length()
		return _trim_attr_value(attrs.substr(start, end - start))
	return ""

func _trim_attr_value(value: String) -> String:
	var out := value.strip_edges()
	if out.length() >= 2 and out.begins_with("\"") and out.ends_with("\""):
		out = out.substr(1, out.length() - 2)
	return out
