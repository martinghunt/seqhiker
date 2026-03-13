extends RefCounted
class_name TileController

const ZemClientScript = preload("res://scripts/zem_client.gd")
const ReadLayoutHelperScript = preload("res://scripts/read_layout_helper.gd")
const READ_RENDER_MAX_BP_PER_PX := 128.0
const DEFAULT_GC_WINDOW_BP := 200
const SEQ_VIEW_CONCAT := 0
const SEQ_VIEW_SINGLE := 1
const TILE_PRUNE_MARGIN := 2
const ANNOT_TILE_BASE_BP := 1024

var _compute_tile_zoom_cb: Callable
var _read_tile_cache: Dictionary = {}
var _coverage_tile_cache: Dictionary = {}
var _gc_tile_cache: Dictionary = {}
var _annotation_tile_cache: Dictionary = {}
var _active_scope_key := ""
var _active_generation := -1
var _read_layout_helper := ReadLayoutHelperScript.new()
var _thread: Thread
var _mutex := Mutex.new()
var _semaphore := Semaphore.new()
var _stop_requested := false
var _pending_request: Dictionary = {}
var _result_pending := false
var _latest_result: Dictionary = {}

func configure(compute_tile_zoom_cb: Callable) -> void:
	_compute_tile_zoom_cb = compute_tile_zoom_cb

func reset() -> void:
	_mutex.lock()
	_active_generation = -1
	_pending_request = {}
	_latest_result = {}
	_result_pending = false
	_mutex.unlock()

func shutdown() -> void:
	if _thread == null:
		return
	_mutex.lock()
	_stop_requested = true
	_mutex.unlock()
	_semaphore.post()
	_thread.wait_to_finish()
	_thread = null

func request_tiles(request: Dictionary) -> void:
	if _thread == null:
		_thread = Thread.new()
		_thread.start(Callable(self, "_worker_main"))
	_mutex.lock()
	_pending_request = request.duplicate(true)
	_mutex.unlock()
	_semaphore.post()

func poll_result() -> Dictionary:
	var result: Dictionary = {}
	_mutex.lock()
	if _result_pending:
		result = _latest_result
		_result_pending = false
	_mutex.unlock()
	return result

func _worker_main() -> void:
	var zem = ZemClientScript.new()
	while true:
		_semaphore.wait()
		var request: Dictionary = {}
		_mutex.lock()
		if _stop_requested:
			_mutex.unlock()
			break
		request = _pending_request.duplicate(true)
		_mutex.unlock()
		if request.is_empty():
			continue
		var result := _fetch_visible_tiles_sync(zem, request)
		_mutex.lock()
		if int(request.get("serial", -1)) == int(_pending_request.get("serial", -2)):
			_latest_result = result
			_result_pending = true
		_mutex.unlock()
	zem.disconnect_from_server()

func _fetch_visible_tiles_sync(zem, request: Dictionary) -> Dictionary:
	var host := str(request.get("host", "127.0.0.1"))
	var port := int(request.get("port", 9000))
	if not zem.connect_to_server(host, port, 250):
		return {
			"ok": false,
			"serial": int(request.get("serial", -1)),
			"error": "Unable to connect to %s:%d" % [host, port]
		}
	var scope_key := str(request.get("scope_key", ""))
	var generation := int(request.get("generation", -1))
	if scope_key != _active_scope_key or generation != _active_generation:
		_read_tile_cache.clear()
		_coverage_tile_cache.clear()
		_gc_tile_cache.clear()
		_annotation_tile_cache.clear()
		_active_scope_key = scope_key
		_active_generation = generation
	var query_start := int(request.get("query_start", 0))
	var query_end := int(request.get("query_end", 0))
	var last_bp_per_px := float(request.get("last_bp_per_px", 1.0))
	var zoom := _compute_tile_zoom(last_bp_per_px)
	var show_reads := bool(request.get("show_reads", false))
	var show_annotations := bool(request.get("show_annotations", false))
	var show_gc_plot := bool(request.get("show_gc_plot", false))
	var show_depth_plot := bool(request.get("show_depth_plot", false))
	var has_bam_loaded := bool(request.get("has_bam_loaded", false))
	var seq_view_mode := int(request.get("seq_view_mode", SEQ_VIEW_SINGLE))
	var current_chr_id := int(request.get("current_chr_id", -1))
	var bam_tracks: Array = request.get("bam_tracks", [])
	var overlaps: Array = request.get("overlaps", [])
	var visible_track_ids = request.get("visible_track_ids", {})
	var gc_window_bp := int(request.get("gc_window_bp", DEFAULT_GC_WINDOW_BP))
	var annotation_cap_total := int(request.get("annotation_cap_total", 0))
	var annotation_min_len_bp := int(request.get("annotation_min_len_bp", 1))
	var keep_read_keys := {}
	var keep_coverage_keys := {}
	var keep_gc_keys := {}
	var keep_annotation_keys := {}

	var read_payload_by_track := {}
	var annotation_features: Array = []
	var gc_plot_tiles: Array = []
	var depth_plot_tiles: Array = []
	var depth_plot_series: Array = []
	var depth_series_by_track := {}
	var annotation_stats := {
		"tile_requests": 0,
		"tile_cache_hits": 0,
		"tile_queries": 0,
		"features_examined": 0,
		"features_out": 0,
		"fetch_time_ms": 0.0
	}
	var annotation_t0 := Time.get_ticks_usec()

	if seq_view_mode == SEQ_VIEW_SINGLE:
		if has_bam_loaded and show_reads:
			for t_any in bam_tracks:
				var track: Dictionary = t_any as Dictionary
				var track_id := str(track.get("track_id", ""))
				if not bool(visible_track_ids.get(track_id, false)):
					continue
				var source_id := int(track.get("source_id", 0))
				var track_reads: Array[Dictionary] = []
				var track_cov: Array[Dictionary] = []
				if last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX:
					var tile_width := 1024 << zoom
					var tile_start := int(floor(float(query_start) / float(tile_width)))
					var tile_end := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width)))
					for t in range(tile_start, tile_end + 1):
						_mark_tile_range(keep_read_keys, source_id, current_chr_id, zoom, t)
						var tile_resp: Dictionary = _frame_get_read_tile(zem, source_id, current_chr_id, zoom, t)
						if not tile_resp.get("ok", false):
							return {"ok": false, "error": "Tile query failed: %s" % tile_resp.get("error", "error")}
						track_reads.append_array(tile_resp.get("reads", []))
				if last_bp_per_px > READ_RENDER_MAX_BP_PER_PX or show_depth_plot:
					var tile_width_cov := 1024 << zoom
					var tile_start_cov := int(floor(float(query_start) / float(tile_width_cov)))
					var tile_end_cov := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width_cov)))
					for t in range(tile_start_cov, tile_end_cov + 1):
						_mark_tile_range(keep_coverage_keys, source_id, current_chr_id, zoom, t)
						var cov_resp: Dictionary = _frame_get_coverage_tile(zem, source_id, current_chr_id, zoom, t)
						if not cov_resp.get("ok", false):
							return {"ok": false, "error": "Coverage query failed: %s" % cov_resp.get("error", "error")}
						var cov_tile = cov_resp.get("coverage", {})
						if last_bp_per_px > READ_RENDER_MAX_BP_PER_PX:
							track_cov.append(cov_tile)
							if show_depth_plot:
								if not depth_series_by_track.has(track_id):
									depth_series_by_track[track_id] = []
								var depth_tiles_for_track: Array = depth_series_by_track[track_id]
								depth_tiles_for_track.append(_coverage_to_plot_tile(cov_tile))
								depth_series_by_track[track_id] = depth_tiles_for_track
					read_payload_by_track[track_id] = _prepare_track_payload(track, track_reads, track_cov, query_start, query_end)
		if show_gc_plot:
			var tile_width_plot := 1024 << zoom
			var tile_start_plot := int(floor(float(query_start) / float(tile_width_plot)))
			var tile_end_plot := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width_plot)))
			for t in range(tile_start_plot, tile_end_plot + 1):
				_mark_tile_range(keep_gc_keys, 0, current_chr_id, zoom, t, gc_window_bp)
				var plot_resp = _frame_get_gc_plot_tile(zem, current_chr_id, zoom, t, gc_window_bp)
				if not plot_resp.get("ok", false):
					return {"ok": false, "error": "GC plot query failed: %s" % plot_resp.get("error", "error")}
				gc_plot_tiles.append(plot_resp.get("plot", {}))
		if show_annotations:
			var ann_resp := _fetch_annotation_features_single(
				zem,
				current_chr_id,
				query_start,
				query_end,
				zoom,
				annotation_cap_total,
				annotation_min_len_bp,
				keep_annotation_keys,
				annotation_stats
			)
			if not ann_resp.get("ok", false):
				return ann_resp
			annotation_features = ann_resp.get("features", [])
	else:
		if has_bam_loaded and show_reads:
			for t_any in bam_tracks:
				var track: Dictionary = t_any as Dictionary
				var track_id := str(track.get("track_id", ""))
				if not bool(visible_track_ids.get(track_id, false)):
					continue
				var source_id := int(track.get("source_id", 0))
				var track_reads: Array[Dictionary] = []
				var track_cov: Array[Dictionary] = []
				for ov_any in overlaps:
					var ov: Dictionary = ov_any as Dictionary
					var chr_id := int(ov["id"])
					var offset := int(ov["offset"])
					var local_start := int(ov["local_start"])
					var local_end := int(ov["local_end"])
					if last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX:
						var tile_width := 1024 << zoom
						var tile_start := int(floor(float(local_start) / float(tile_width)))
						var tile_end := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width)))
						for t in range(tile_start, tile_end + 1):
							_mark_tile_range(keep_read_keys, source_id, chr_id, zoom, t)
							var tile_resp: Dictionary = _frame_get_read_tile(zem, source_id, chr_id, zoom, t)
							if not tile_resp.get("ok", false):
								return {"ok": false, "error": "Tile query failed: %s" % tile_resp.get("error", "error")}
							for r in tile_resp.get("reads", []):
								var shifted := _shift_read_coords(r, offset)
								if int(shifted.get("end", 0)) > query_start and int(shifted.get("start", 0)) < query_end:
									track_reads.append(shifted)
					if last_bp_per_px > READ_RENDER_MAX_BP_PER_PX or show_depth_plot:
						var tile_width_cov := 1024 << zoom
						var tile_start_cov := int(floor(float(local_start) / float(tile_width_cov)))
						var tile_end_cov := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width_cov)))
						for t in range(tile_start_cov, tile_end_cov + 1):
							_mark_tile_range(keep_coverage_keys, source_id, chr_id, zoom, t)
							var cov_resp = _frame_get_coverage_tile(zem, source_id, chr_id, zoom, t)
							if not cov_resp.get("ok", false):
								return {"ok": false, "error": "Coverage query failed: %s" % cov_resp.get("error", "error")}
							var shifted_cov := _shift_coverage_coords(cov_resp.get("coverage", {}), offset)
							if last_bp_per_px > READ_RENDER_MAX_BP_PER_PX:
								track_cov.append(shifted_cov)
							if show_depth_plot:
								if not depth_series_by_track.has(track_id):
									depth_series_by_track[track_id] = []
								var depth_tiles_for_track: Array = depth_series_by_track[track_id]
								depth_tiles_for_track.append(_coverage_to_plot_tile(shifted_cov))
								depth_series_by_track[track_id] = depth_tiles_for_track
				read_payload_by_track[track_id] = _prepare_track_payload(track, track_reads, track_cov, query_start, query_end)
		if show_gc_plot:
			for ov_any in overlaps:
				var ov: Dictionary = ov_any as Dictionary
				var chr_id := int(ov["id"])
				var offset := int(ov["offset"])
				var local_start := int(ov["local_start"])
				var local_end := int(ov["local_end"])
				var tile_width_plot := 1024 << zoom
				var tile_start_plot := int(floor(float(local_start) / float(tile_width_plot)))
				var tile_end_plot := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width_plot)))
				for t in range(tile_start_plot, tile_end_plot + 1):
					_mark_tile_range(keep_gc_keys, 0, chr_id, zoom, t, gc_window_bp)
					var plot_resp = _frame_get_gc_plot_tile(zem, chr_id, zoom, t, gc_window_bp)
					if not plot_resp.get("ok", false):
						return {"ok": false, "error": "GC plot query failed: %s" % plot_resp.get("error", "error")}
					gc_plot_tiles.append(_shift_plot_coords(plot_resp.get("plot", {}), offset, gc_window_bp))
		if show_annotations:
			var shifted_features: Array = []
			for ov_any in overlaps:
				var ov: Dictionary = ov_any as Dictionary
				var chr_id := int(ov["id"])
				var offset := int(ov["offset"])
				var local_start := int(ov["local_start"])
				var local_end := int(ov["local_end"])
				var ann_resp := _fetch_annotation_features_single(
					zem,
					chr_id,
					local_start,
					local_end,
					zoom,
					annotation_cap_total,
					annotation_min_len_bp,
					keep_annotation_keys,
					annotation_stats
				)
				if not ann_resp.get("ok", false):
					return ann_resp
				for feat_any in ann_resp.get("features", []):
					shifted_features.append(_shift_feature_coords(feat_any as Dictionary, offset))
			annotation_features = _collapse_annotation_features(shifted_features, query_start, query_end, annotation_cap_total)

	for track_any in bam_tracks:
		var track: Dictionary = track_any as Dictionary
		var track_id := str(track.get("track_id", ""))
		if show_depth_plot and depth_series_by_track.has(track_id):
			var depth_tiles: Array = []
			for tile_any in depth_series_by_track[track_id]:
				if typeof(tile_any) == TYPE_DICTIONARY:
					depth_tiles.append(tile_any)
					depth_plot_tiles.append(tile_any)
			depth_plot_series.append({
				"track_id": track_id,
				"label": str(track.get("label", track_id)),
				"tiles": depth_tiles
			})

	_prune_cache(_read_tile_cache, keep_read_keys)
	_prune_cache(_coverage_tile_cache, keep_coverage_keys)
	_prune_cache(_gc_tile_cache, keep_gc_keys)
	_prune_cache(_annotation_tile_cache, keep_annotation_keys)
	annotation_stats["features_out"] = annotation_features.size()
	annotation_stats["fetch_time_ms"] = float(Time.get_ticks_usec() - annotation_t0) / 1000.0

	return {
		"ok": true,
		"serial": int(request.get("serial", -1)),
		"read_payload_by_track": read_payload_by_track,
		"annotation_features": annotation_features,
		"annotation_stats": annotation_stats,
		"gc_plot_tiles": gc_plot_tiles,
		"depth_plot_tiles": depth_plot_tiles,
		"depth_plot_series": depth_plot_series
	}

func _prepare_track_payload(track: Dictionary, track_reads: Array[Dictionary], track_cov: Array[Dictionary], view_start: int, view_end: int) -> Dictionary:
	var view_mode := int(track.get("view_mode", 0))
	var fragment_log := bool(track.get("fragment_log", true))
	var max_rows := int(track.get("max_rows", 500))
	var min_mapq := int(track.get("min_mapq", 0))
	var hidden_flags := int(track.get("hidden_flags", 0))
	var hide_improper_pair := bool(track.get("hide_improper_pair", false))
	var hide_forward_strand := bool(track.get("hide_forward_strand", false))
	var hide_mate_forward_strand := bool(track.get("hide_mate_forward_strand", false))
	var prepared_reads: Array[Dictionary] = []
	for read_any in _dedupe_reads(track_reads):
		if typeof(read_any) != TYPE_DICTIONARY:
			continue
		var read: Dictionary = (read_any as Dictionary).duplicate(true)
		if int(read.get("mapq", 0)) < min_mapq:
			continue
		if (int(read.get("flags", 0)) & hidden_flags) != 0:
			continue
		if hide_improper_pair and (int(read.get("flags", 0)) & 2) == 0:
			continue
		if hide_forward_strand and (int(read.get("flags", 0)) & 16) == 0:
			continue
		if hide_mate_forward_strand and (int(read.get("flags", 0)) & 32) == 0:
			continue
		_read_layout_helper.attach_indel_markers(read)
		prepared_reads.append(read)
	var layout := _read_layout_helper.build_layout(prepared_reads, view_mode, fragment_log, max_rows, view_start, view_end)
	return {
		"reads": prepared_reads,
		"coverage": track_cov,
		"laid_out_reads": layout.get("laid_out_reads", []),
		"read_row_count": int(layout.get("read_row_count", 0)),
		"strand_forward_rows": int(layout.get("strand_forward_rows", 0)),
		"strand_reverse_rows": int(layout.get("strand_reverse_rows", 0))
	}

func _dedupe_reads(reads_in: Array[Dictionary]) -> Array[Dictionary]:
	var by_key: Dictionary = {}
	for read_any in reads_in:
		if typeof(read_any) != TYPE_DICTIONARY:
			continue
		var read: Dictionary = read_any
		var key := _read_dedupe_key(read)
		if key.is_empty():
			continue
		if not by_key.has(key):
			by_key[key] = read
			continue
		var existing: Dictionary = by_key[key]
		if _read_quality_score(read) > _read_quality_score(existing):
			by_key[key] = read
	var out: Array[Dictionary] = []
	for k in by_key.keys():
		out.append(by_key[k])
	return out

func _read_dedupe_key(read: Dictionary) -> String:
	var name := str(read.get("name", ""))
	var start_bp := int(read.get("start", 0))
	var end_bp := int(read.get("end", start_bp))
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	var reverse := int(read.get("reverse", false))
	var flags := int(read.get("flags", 0))
	if name.is_empty() and start_bp == 0 and end_bp == 0:
		return ""
	return "%s|%d|%d|%d|%d|%d|%d" % [name, start_bp, end_bp, mate_start, mate_end, reverse, flags]

func _read_quality_score(read: Dictionary) -> int:
	var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
	var mapq := int(read.get("mapq", 0))
	return snps.size() * 1000 + mapq

func _compute_tile_zoom(bp_per_px: float) -> int:
	if _compute_tile_zoom_cb.is_valid():
		return int(_compute_tile_zoom_cb.call(bp_per_px))
	var z := int(round(log(max(bp_per_px, 0.001)) / log(2.0)))
	return clampi(z, 0, 16)

func _frame_tile_key(source_id: int, chr_id: int, zoom: int, tile_index: int, param: int = 0) -> String:
	return "%d|%d|%d|%d|%d" % [source_id, chr_id, zoom, tile_index, param]

func _mark_tile_range(keep: Dictionary, source_id: int, chr_id: int, zoom: int, tile_index: int, param: int = 0) -> void:
	for t in range(tile_index - TILE_PRUNE_MARGIN, tile_index + TILE_PRUNE_MARGIN + 1):
		if t < 0:
			continue
		keep[_frame_tile_key(source_id, chr_id, zoom, t, param)] = true

func _prune_cache(cache: Dictionary, keep: Dictionary) -> void:
	var drop_keys: Array[String] = []
	for key_any in cache.keys():
		var key := str(key_any)
		if keep.get(key, false):
			continue
		drop_keys.append(key)
	for key in drop_keys:
		cache.erase(key)

func _frame_get_read_tile(zem, source_id: int, chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var key := _frame_tile_key(source_id, chr_id, zoom, tile_index)
	if _read_tile_cache.has(key):
		return _read_tile_cache[key]
	var resp: Dictionary = zem.get_tile(chr_id, zoom, tile_index, source_id)
	_read_tile_cache[key] = resp
	return resp

func _frame_get_coverage_tile(zem, source_id: int, chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var key := _frame_tile_key(source_id, chr_id, zoom, tile_index)
	if _coverage_tile_cache.has(key):
		return _coverage_tile_cache[key]
	var resp: Dictionary = zem.get_coverage_tile(chr_id, zoom, tile_index, source_id)
	_coverage_tile_cache[key] = resp
	return resp

func _frame_get_gc_plot_tile(zem, chr_id: int, zoom: int, tile_index: int, window_len_bp: int) -> Dictionary:
	var key := _frame_tile_key(0, chr_id, zoom, tile_index, window_len_bp)
	if _gc_tile_cache.has(key):
		return _gc_tile_cache[key]
	var resp: Dictionary = zem.get_gc_plot_tile(chr_id, zoom, tile_index, window_len_bp)
	_gc_tile_cache[key] = resp
	return resp

func _frame_get_annotation_tile(zem, chr_id: int, zoom: int, tile_index: int, cap_per_tile: int, min_len_bp: int, annotation_stats: Dictionary) -> Dictionary:
	var param := _annotation_cache_param(cap_per_tile, min_len_bp)
	var key := _frame_tile_key(0, chr_id, zoom, tile_index, param)
	annotation_stats["tile_requests"] = int(annotation_stats.get("tile_requests", 0)) + 1
	if _annotation_tile_cache.has(key):
		annotation_stats["tile_cache_hits"] = int(annotation_stats.get("tile_cache_hits", 0)) + 1
		return _annotation_tile_cache[key]
	var resp: Dictionary = zem.get_annotation_tile(chr_id, zoom, tile_index, cap_per_tile, min_len_bp)
	_annotation_tile_cache[key] = resp
	if resp.get("ok", false):
		annotation_stats["tile_queries"] = int(annotation_stats.get("tile_queries", 0)) + 1
	return resp

func _fetch_annotation_features_single(zem, chr_id: int, start_bp: int, end_bp: int, zoom: int, cap_total: int, min_len_bp: int, keep_annotation_keys: Dictionary, annotation_stats: Dictionary) -> Dictionary:
	if end_bp <= start_bp:
		return {"ok": true, "features": []}
	var tile_w := ANNOT_TILE_BASE_BP << zoom
	var tile_start := int(floor(float(start_bp) / float(tile_w)))
	var tile_end := int(floor(float(maxi(end_bp - 1, start_bp)) / float(tile_w)))
	if tile_end < tile_start:
		tile_end = tile_start
	var tile_count := tile_end - tile_start + 1
	var cap_per_tile := clampi(int(ceil(float(maxi(cap_total, 1)) / float(maxi(tile_count, 1)) * 1.5)), 128, maxi(cap_total, 128))
	var out: Array = []
	for t in range(tile_start, tile_end + 1):
		var param := _annotation_cache_param(cap_per_tile, min_len_bp)
		_mark_tile_range(keep_annotation_keys, 0, chr_id, zoom, t, param)
		var resp := _frame_get_annotation_tile(zem, chr_id, zoom, t, cap_per_tile, min_len_bp, annotation_stats)
		if not resp.get("ok", false):
			return {"ok": false, "error": "Annotation tile query failed: %s" % resp.get("error", "error")}
		var cached: Array = resp.get("features", [])
		annotation_stats["features_examined"] = int(annotation_stats.get("features_examined", 0)) + cached.size()
		for feat_any in cached:
			if typeof(feat_any) == TYPE_DICTIONARY:
				out.append(feat_any)
	return {"ok": true, "features": _collapse_annotation_features(out, start_bp, end_bp, cap_total)}

func _annotation_cache_param(cap_per_tile: int, min_len_bp: int) -> int:
	return ((cap_per_tile & 0xFFFF) << 16) | (min_len_bp & 0xFFFF)

func _collapse_annotation_features(features_in: Array, start_bp: int, end_bp: int, cap_total: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for feat_any in features_in:
		if typeof(feat_any) != TYPE_DICTIONARY:
			continue
		var feat: Dictionary = feat_any
		var feat_start := int(feat.get("start", 0))
		var feat_end := int(feat.get("end", feat_start))
		if feat_end <= start_bp or feat_start >= end_bp:
			continue
		var key_f := _feature_dedupe_key(feat)
		if seen.get(key_f, false):
			continue
		seen[key_f] = true
		out.append(feat)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("start", 0))
		var sb := int(b.get("start", 0))
		if sa == sb:
			return int(a.get("end", sa)) < int(b.get("end", sb))
		return sa < sb
	)
	if out.size() > cap_total:
		out = _annotation_select_spread(out, start_bp, end_bp, cap_total)
	return out

func _annotation_select_spread(features_in: Array, start_bp: int, end_bp: int, cap_total: int) -> Array:
	if cap_total <= 0 or features_in.is_empty() or end_bp <= start_bp:
		return []
	var span := maxi(1, end_bp - start_bp)
	var bin_w := maxi(1, int(ceil(float(span) / float(cap_total))))
	var seen_bins := {}
	var primary: Array = []
	var overflow: Array = []
	for feat_any in features_in:
		var feat: Dictionary = feat_any
		var s := int(feat.get("start", 0))
		var anchor := clampi(s, start_bp, end_bp - 1)
		var bin_idx := int(floor(float(anchor - start_bp) / float(bin_w)))
		var bkey := str(bin_idx)
		if not seen_bins.get(bkey, false):
			seen_bins[bkey] = true
			primary.append(feat)
		else:
			overflow.append(feat)
	if primary.size() >= cap_total:
		primary.resize(cap_total)
		return primary
	for feat_any in overflow:
		primary.append(feat_any)
		if primary.size() >= cap_total:
			break
	return primary

func _feature_dedupe_key(feature: Dictionary) -> String:
	return "%d|%d|%s|%s|%s|%s" % [
		int(feature.get("start", 0)),
		int(feature.get("end", 0)),
		str(feature.get("strand", ".")),
		str(feature.get("type", "")),
		str(feature.get("name", "")),
		str(feature.get("source", ""))
	]

func _shift_read_coords(read: Dictionary, offset: int) -> Dictionary:
	var shifted := read.duplicate(true)
	shifted["start"] = int(shifted.get("start", 0)) + offset
	shifted["end"] = int(shifted.get("end", 0)) + offset
	if int(shifted.get("mate_start", -1)) >= 0:
		shifted["mate_start"] = int(shifted.get("mate_start", -1)) + offset
	if int(shifted.get("mate_end", -1)) >= 0:
		shifted["mate_end"] = int(shifted.get("mate_end", -1)) + offset
	var shifted_snps := PackedInt32Array()
	var snps: PackedInt32Array = shifted.get("snps", PackedInt32Array())
	for s in snps:
		shifted_snps.append(int(s) + offset)
	shifted["snps"] = shifted_snps
	return shifted

func _shift_coverage_coords(cov: Dictionary, offset: int) -> Dictionary:
	if cov.is_empty():
		return cov
	return {
		"start": int(cov.get("start", 0)) + offset,
		"end": int(cov.get("end", 0)) + offset,
		"bins": cov.get("bins", PackedInt32Array())
	}

func _shift_plot_coords(plot: Dictionary, offset: int, gc_window_bp: int) -> Dictionary:
	if plot.is_empty():
		return plot
	return {
		"start": int(plot.get("start", 0)) + offset,
		"end": int(plot.get("end", 0)) + offset,
		"window": int(plot.get("window", gc_window_bp)),
		"values": plot.get("values", PackedFloat32Array())
	}

func _shift_feature_coords(feature: Dictionary, offset: int) -> Dictionary:
	var shifted := feature.duplicate(true)
	shifted["start"] = int(shifted.get("start", 0)) + offset
	shifted["end"] = int(shifted.get("end", 0)) + offset
	return shifted

func _coverage_to_plot_tile(cov: Dictionary) -> Dictionary:
	if cov.is_empty():
		return {}
	var bins: PackedInt32Array = cov.get("bins", PackedInt32Array())
	var values := PackedFloat32Array()
	values.resize(bins.size())
	for i in range(bins.size()):
		values[i] = float(bins[i])
	return {
		"start": int(cov.get("start", 0)),
		"end": int(cov.get("end", 0)),
		"window": 1,
		"values": values
	}
