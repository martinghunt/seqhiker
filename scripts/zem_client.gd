extends RefCounted
class_name ZemClient

const MSG_LOAD_GENOME := 1
const MSG_LOAD_BAM := 2
const MSG_GET_TILE := 3
const MSG_GET_COVERAGE_TILE := 4
const MSG_GET_ANNOTATIONS := 5
const MSG_GET_REFERENCE_SLICE := 6
const MSG_ACK := 7
const MSG_ERROR := 8
const MSG_GET_CHROMOSOMES := 10
const MSG_GET_GC_PLOT_TILE := 11
const NAME_KEYS := ["Name=", "gene=", "locus_tag=", "ID="]
const DISPLAY_NAME_KEYS := ["Name=", "gene=", "locus_tag="]
const REQUEST_TIMEOUT_MS := 1800
const LOAD_TIMEOUT_MS := 120000

var _tcp: StreamPeerTCP = StreamPeerTCP.new()
var _host: String = "127.0.0.1"
var _port: int = 9000
var _request_id: int = 1

func connect_to_server(host: String = "127.0.0.1", port: int = 9000, timeout_ms: int = 1200) -> bool:
	_host = host
	_port = port
	if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		return true
	var err: int = _tcp.connect_to_host(host, port)
	if err != OK:
		return false
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < timeout_ms:
		_tcp.poll()
		if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			return true
		if _tcp.get_status() == StreamPeerTCP.STATUS_ERROR:
			return false
		OS.delay_msec(10)
	return _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED

func disconnect_from_server() -> void:
	if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_tcp.disconnect_from_host()

func ensure_connected() -> bool:
	if _tcp.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		return true
	return connect_to_server(_host, _port)

func load_genome(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	return _send_request(MSG_LOAD_GENOME, payload, LOAD_TIMEOUT_MS)

func load_bam(path: String) -> Dictionary:
	var path_bytes := path.to_utf8_buffer()
	var payload := PackedByteArray()
	payload.resize(2 + path_bytes.size())
	payload.encode_u16(0, path_bytes.size())
	for i in range(path_bytes.size()):
		payload[2 + i] = path_bytes[i]
	return _send_request(MSG_LOAD_BAM, payload, LOAD_TIMEOUT_MS)

func get_chromosomes() -> Dictionary:
	var resp := _send_request(MSG_GET_CHROMOSOMES, PackedByteArray())
	if not resp.get("ok", false):
		return resp
	resp["chromosomes"] = _parse_chromosomes(resp["payload"])
	return resp

func get_tile(chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(7)
	payload.encode_u16(0, chr_id)
	payload[2] = zoom
	payload.encode_u32(3, tile_index)
	var resp := _send_request(MSG_GET_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["reads"] = _parse_tile_reads(resp["payload"])
	return resp

func get_coverage_tile(chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(7)
	payload.encode_u16(0, chr_id)
	payload[2] = zoom
	payload.encode_u32(3, tile_index)
	var resp := _send_request(MSG_GET_COVERAGE_TILE, payload)
	if not resp.get("ok", false):
		return resp
	resp["coverage"] = _parse_coverage_tile(resp["payload"])
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

func get_annotations(chr_id: int, start_bp: int, end_bp: int, max_records: int = 2000) -> Dictionary:
	var payload := PackedByteArray()
	payload.resize(12)
	payload.encode_u16(0, chr_id)
	payload.encode_u32(2, start_bp)
	payload.encode_u32(6, end_bp)
	payload.encode_u16(10, max_records)
	var resp := _send_request(MSG_GET_ANNOTATIONS, payload)
	if not resp.get("ok", false):
		return resp
	resp["features"] = _parse_annotations(resp["payload"])
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

func _send_request(msg_type: int, payload: PackedByteArray, timeout_ms: int = REQUEST_TIMEOUT_MS) -> Dictionary:
	if not ensure_connected():
		return {"ok": false, "error": "Unable to connect to %s:%d" % [_host, _port]}
	var req_id := _next_request_id()
	var frame := PackedByteArray()
	frame.resize(8 + payload.size())
	frame.encode_u32(0, payload.size())
	frame.encode_u16(4, msg_type)
	frame.encode_u16(6, req_id)
	for i in range(payload.size()):
		frame[8 + i] = payload[i]

	var put_err := _tcp.put_data(frame)
	if put_err != OK:
		return {"ok": false, "error": "Write failed"}

	var header_result := _read_exact(8, timeout_ms)
	if header_result["error"] != OK:
		return {"ok": false, "error": "Failed to read response header: %s" % _describe_stream_error(int(header_result["error"]))}
	var hdr: PackedByteArray = header_result["data"]
	var length := hdr.decode_u32(0)
	var res_type := hdr.decode_u16(4)
	var payload_result := _read_exact(length, timeout_ms)
	if payload_result["error"] != OK:
		return {"ok": false, "error": "Failed to read response payload: %s" % _describe_stream_error(int(payload_result["error"]))}
	var res_payload: PackedByteArray = payload_result["data"]

	if res_type == MSG_ERROR:
		return {"ok": false, "error": _decode_error_string(res_payload)}
	return {
		"ok": true,
		"type": res_type,
		"payload": res_payload
	}

func _read_exact(bytes: int, timeout_ms: int = REQUEST_TIMEOUT_MS) -> Dictionary:
	var out := PackedByteArray()
	out.resize(0)
	var started: int = Time.get_ticks_msec()
	while out.size() < bytes:
		_tcp.poll()
		if _tcp.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			return {"error": ERR_CONNECTION_ERROR, "data": out}
		if _tcp.get_available_bytes() > 0:
			var to_read: int = mini(bytes - out.size(), _tcp.get_available_bytes())
			var result := _tcp.get_data(to_read)
			if result[0] != OK:
				return {"error": result[0], "data": out}
			out.append_array(result[1])
			continue
		if Time.get_ticks_msec() - started > timeout_ms:
			return {"error": ERR_TIMEOUT, "data": out}
		OS.delay_msec(4)
	return {"error": OK, "data": out}

func _decode_error_string(payload: PackedByteArray) -> String:
	if payload.size() < 2:
		return "Unknown server error"
	var ln := payload.decode_u16(0)
	if payload.size() < 2 + ln:
		return "Malformed server error"
	return payload.slice(2, 2 + ln).get_string_from_utf8()

func _describe_stream_error(err: int) -> String:
	match err:
		OK:
			return "ok"
		ERR_TIMEOUT:
			return "timeout"
		ERR_CONNECTION_ERROR:
			return "connection closed"
		_:
			return error_string(err)

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
		var name := payload.slice(off, off + name_len).get_string_from_utf8()
		off += name_len
		out.append({"id": chr_id, "length": length, "name": name})
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
		if off + 26 > payload.size():
			break
		var start_bp := payload.decode_u32(off)
		var end_bp := payload.decode_u32(off + 4)
		var mapq := payload[off + 8]
		var reverse := payload[off + 9] == 1
		var flags := payload.decode_u16(off + 10)
		var mate_start_u := payload.decode_u32(off + 12)
		var mate_end_u := payload.decode_u32(off + 16)
		var fragment_len := int(payload.decode_u32(off + 20))
		var name_len := payload.decode_u16(off + 24)
		off += 26
		if off + name_len > payload.size():
			break
		var read_name := payload.slice(off, off + name_len).get_string_from_utf8()
		off += name_len
		if off + 2 > payload.size():
			break
		var cigar_len := payload.decode_u16(off)
		off += 2
		if off + cigar_len > payload.size():
			break
		var cigar := payload.slice(off, off + cigar_len).get_string_from_utf8()
		off += cigar_len
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
			"snps": snps,
			"snp_bases": snp_bases,
			"mate_start": -1 if mate_start_u == 0xFFFFFFFF else int(mate_start_u),
			"mate_end": -1 if mate_end_u == 0xFFFFFFFF else int(mate_end_u),
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
		var seq_name := payload.slice(off, off + seq_name_len).get_string_from_utf8()
		off += seq_name_len
		if off + 2 > payload.size():
			break
		var src_len := payload.decode_u16(off)
		off += 2
		if off + src_len > payload.size():
			break
		var source := payload.slice(off, off + src_len).get_string_from_utf8()
		off += src_len
		if off + 2 > payload.size():
			break
		var type_len := payload.decode_u16(off)
		off += 2
		if off + type_len > payload.size():
			break
		var feature_type := payload.slice(off, off + type_len).get_string_from_utf8()
		off += type_len
		if off + 2 > payload.size():
			break
		var attr_len := payload.decode_u16(off)
		off += 2
		if off + attr_len > payload.size():
			break
		var attrs := payload.slice(off, off + attr_len).get_string_from_utf8()
		off += attr_len
		var name := _extract_first_attr(attrs, DISPLAY_NAME_KEYS)
		var feature_id := _extract_first_attr(attrs, ["ID="])
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
			"id": feature_id
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
	var seq: String = payload.slice(12, 12 + seq_len).get_string_from_utf8()
	return {
		"slice_start": start_bp,
		"slice_end": end_bp,
		"sequence": seq
	}

func _extract_name(attrs: String, fallback: String) -> String:
	for key: String in NAME_KEYS:
		var pos: int = attrs.find(key)
		if pos >= 0:
			var start: int = pos + key.length()
			var end: int = attrs.find(";", start)
			if end == -1:
				end = attrs.length()
			return attrs.substr(start, end - start)
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
		return attrs.substr(start, end - start)
	return ""

func _next_request_id() -> int:
	_request_id = (_request_id + 1) & 0xFFFF
	if _request_id == 0:
		_request_id = 1
	return _request_id
