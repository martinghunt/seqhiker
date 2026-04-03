extends RefCounted
class_name TileController

const ZemClientScript = preload("res://scripts/zem_client.gd")
const ReadLayoutHelperScript = preload("res://scripts/read_layout_helper.gd")
const READ_RENDER_MAX_BP_PER_PX := 128.0
const DETAILED_READ_MAX_BP_PER_PX := 48.0
const READ_VIEWPORT_SAMPLE_MIN_BP_PER_PX := 48.0
const MIN_VIEWPORT_READS_PER_TRACK := 12000
const MAX_VIEWPORT_READS_PER_TRACK := 24000
const DEFAULT_GC_WINDOW_BP := 200
const SEQ_VIEW_CONCAT := 0
const SEQ_VIEW_SINGLE := 1
const TILE_PRUNE_MARGIN := 2
const ANNOT_TILE_BASE_BP := 1024

var _compute_tile_zoom_cb: Callable
var _read_tile_cache: Dictionary = {}
var _coverage_tile_cache: Dictionary = {}
var _strand_coverage_tile_cache: Dictionary = {}
var _gc_tile_cache: Dictionary = {}
var _annotation_tile_cache: Dictionary = {}
var _stop_codon_tile_cache: Dictionary = {}
var _active_scope_key := ""
var _active_generation := -1
var _read_layout_helper := ReadLayoutHelperScript.new()
var _thread: Thread
var _mutex := Mutex.new()
var _semaphore := Semaphore.new()
var _stop_requested := false
var _pending_requests: Array[Dictionary] = []
var _result_queue: Array[Dictionary] = []

func configure(compute_tile_zoom_cb: Callable) -> void:
	_compute_tile_zoom_cb = compute_tile_zoom_cb

func reset() -> void:
	_mutex.lock()
	_active_generation = -1
	_pending_requests.clear()
	_result_queue.clear()
	_mutex.unlock()


func cancel_requests() -> void:
	_mutex.lock()
	_pending_requests.clear()
	_result_queue.clear()
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
	var req := request.duplicate(true)
	if bool(req.get("high_priority", false)):
		_pending_requests.push_front(req)
	else:
		_pending_requests.append(req)
	_mutex.unlock()
	_semaphore.post()

func poll_result() -> Dictionary:
	var result: Dictionary = {}
	_mutex.lock()
	if not _result_queue.is_empty():
		result = _result_queue.pop_front()
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
		if not _pending_requests.is_empty():
			request = _pending_requests.pop_front()
		_mutex.unlock()
		if request.is_empty():
			continue
		var result := _fetch_visible_tiles_sync(zem, request)
		_mutex.lock()
		_result_queue.append(result)
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
		_strand_coverage_tile_cache.clear()
		_gc_tile_cache.clear()
		_annotation_tile_cache.clear()
		_stop_codon_tile_cache.clear()
		_active_scope_key = scope_key
		_active_generation = generation
	var query_start := int(request.get("query_start", 0))
	var query_end := int(request.get("query_end", 0))
	var visible_start := int(request.get("visible_start", query_start))
	var visible_end := int(request.get("visible_end", query_end))
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
	var show_stop_codons := bool(request.get("show_stop_codons", false))
	var keep_read_keys := {}
	var keep_coverage_keys := {}
	var keep_strand_coverage_keys := {}
	var keep_gc_keys := {}
	var keep_annotation_keys := {}
	var keep_stop_codon_keys := {}

	var read_payload_by_track := {}
	var annotation_features: Array = []
	var stop_codon_tiles: Array = []
	var gc_plot_tiles: Array = []
	var depth_plot_tiles: Array = []
	var depth_plot_series: Array = []
	var ref_start := query_start
	var ref_sequence := ""
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
		if bool(request.get("need_reference", false)):
			var ref_resp: Dictionary = zem.get_reference_slice(current_chr_id, query_start, query_end)
			if not ref_resp.get("ok", false):
				return {"ok": false, "serial": int(request.get("serial", -1)), "error": "Reference query failed: %s" % ref_resp.get("error", "error")}
			ref_start = int(ref_resp.get("slice_start", query_start))
			ref_sequence = str(ref_resp.get("sequence", ""))
		if has_bam_loaded and (show_reads or show_depth_plot):
			for t_any in bam_tracks:
				var track: Dictionary = t_any as Dictionary
				var track_id := str(track.get("track_id", ""))
				if not bool(visible_track_ids.get(track_id, false)):
					continue
				var source_id := int(track.get("source_id", 0))
				var track_cov: Array[Dictionary] = []
				var track_reads: Array[Dictionary] = []
				var track_strand_cov: Array[Dictionary] = []
				if last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX:
					var tile_width := 1024 << zoom
					var tile_start := int(floor(float(query_start) / float(tile_width)))
					var tile_end := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width)))
					for t in range(tile_start, tile_end + 1):
						_mark_tile_range(keep_read_keys, source_id, current_chr_id, zoom, t)
						var tile_resp: Dictionary = _frame_get_read_tile(zem, source_id, current_chr_id, zoom, t)
						if not tile_resp.get("ok", false):
							return {"ok": false, "error": "Tile query failed: %s" % tile_resp.get("error", "error")}
						for r in tile_resp.get("reads", []):
							if typeof(r) != TYPE_DICTIONARY:
								continue
							var read: Dictionary = r
							if int(read.get("end", 0)) > query_start and int(read.get("start", 0)) < query_end:
								track_reads.append(read)
				if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX or show_depth_plot:
					var tile_width_cov := 1024 << zoom
					var tile_start_cov := int(floor(float(query_start) / float(tile_width_cov)))
					var tile_end_cov := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width_cov)))
					for t in range(tile_start_cov, tile_end_cov + 1):
						_mark_tile_range(keep_coverage_keys, source_id, current_chr_id, zoom, t)
						var cov_resp: Dictionary = _frame_get_coverage_tile(zem, source_id, current_chr_id, zoom, t)
						if not cov_resp.get("ok", false):
							return {"ok": false, "error": "Coverage query failed: %s" % cov_resp.get("error", "error")}
						var cov_tile = cov_resp.get("coverage", {})
						if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX:
							track_cov.append(cov_tile)
						if show_depth_plot:
							if not depth_series_by_track.has(track_id):
								depth_series_by_track[track_id] = []
							var depth_tiles_for_track: Array = depth_series_by_track[track_id]
							depth_tiles_for_track.append(_coverage_to_plot_tile(cov_tile))
							depth_series_by_track[track_id] = depth_tiles_for_track
				if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX and int(track.get("view_mode", 0)) == 1:
					var tile_width_strand := 1024 << zoom
					var tile_start_strand := int(floor(float(query_start) / float(tile_width_strand)))
					var tile_end_strand := int(floor(float(maxi(query_end - 1, query_start)) / float(tile_width_strand)))
					for t in range(tile_start_strand, tile_end_strand + 1):
						_mark_tile_range(keep_strand_coverage_keys, source_id, current_chr_id, zoom, t)
						var strand_resp: Dictionary = _frame_get_strand_coverage_tile(zem, source_id, current_chr_id, zoom, t)
						if not strand_resp.get("ok", false):
							return {"ok": false, "error": "Strand coverage query failed: %s" % strand_resp.get("error", "error")}
						track_strand_cov.append(strand_resp.get("coverage", {}))
				read_payload_by_track[track_id] = _prepare_track_payload(track, _build_prepared_reads(track, track_reads, seq_view_mode), track_cov, track_strand_cov, query_start, query_end, visible_start, visible_end, last_bp_per_px)
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
		if show_stop_codons:
			var stop_resp := _fetch_stop_codon_tiles_single(zem, current_chr_id, query_start, query_end, zoom, keep_stop_codon_keys)
			if not stop_resp.get("ok", false):
				return stop_resp
			stop_codon_tiles = stop_resp.get("tiles", [])
	else:
		if bool(request.get("need_reference", false)):
			ref_sequence = _build_concat_reference(zem, query_start, query_end, overlaps)
		if has_bam_loaded and (show_reads or show_depth_plot):
			for t_any in bam_tracks:
				var track: Dictionary = t_any as Dictionary
				var track_id := str(track.get("track_id", ""))
				if not bool(visible_track_ids.get(track_id, false)):
					continue
				var source_id := int(track.get("source_id", 0))
				var track_cov: Array[Dictionary] = []
				var track_reads: Array[Dictionary] = []
				var track_strand_cov: Array[Dictionary] = []
				if last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX:
					for ov_any in overlaps:
						var ov_reads: Dictionary = ov_any as Dictionary
						var chr_id_reads := int(ov_reads["id"])
						var offset_reads := int(ov_reads["offset"])
						var local_start_reads := int(ov_reads["local_start"])
						var local_end_reads := int(ov_reads["local_end"])
						var tile_width_reads := 1024 << zoom
						var tile_start_reads := int(floor(float(local_start_reads) / float(tile_width_reads)))
						var tile_end_reads := int(floor(float(maxi(local_end_reads - 1, local_start_reads)) / float(tile_width_reads)))
						for t in range(tile_start_reads, tile_end_reads + 1):
							_mark_tile_range(keep_read_keys, source_id, chr_id_reads, zoom, t)
							var tile_resp_concat: Dictionary = _frame_get_read_tile(zem, source_id, chr_id_reads, zoom, t)
							if not tile_resp_concat.get("ok", false):
								return {"ok": false, "error": "Tile query failed: %s" % tile_resp_concat.get("error", "error")}
							for r in tile_resp_concat.get("reads", []):
								if typeof(r) != TYPE_DICTIONARY:
									continue
								var shifted := _shift_read_coords(r, offset_reads)
								if int(shifted.get("end", 0)) > query_start and int(shifted.get("start", 0)) < query_end:
									track_reads.append(shifted)
				for ov_any in overlaps:
					var ov: Dictionary = ov_any as Dictionary
					var chr_id := int(ov["id"])
					var offset := int(ov["offset"])
					var local_start := int(ov["local_start"])
					var local_end := int(ov["local_end"])
					if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX or show_depth_plot:
						var tile_width_cov := 1024 << zoom
						var tile_start_cov := int(floor(float(local_start) / float(tile_width_cov)))
						var tile_end_cov := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width_cov)))
						for t in range(tile_start_cov, tile_end_cov + 1):
							_mark_tile_range(keep_coverage_keys, source_id, chr_id, zoom, t)
							var cov_resp = _frame_get_coverage_tile(zem, source_id, chr_id, zoom, t)
							if not cov_resp.get("ok", false):
								return {"ok": false, "error": "Coverage query failed: %s" % cov_resp.get("error", "error")}
							var shifted_cov := _shift_coverage_coords(cov_resp.get("coverage", {}), offset)
							if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX:
								track_cov.append(shifted_cov)
							if show_depth_plot:
								if not depth_series_by_track.has(track_id):
									depth_series_by_track[track_id] = []
								var depth_tiles_for_track: Array = depth_series_by_track[track_id]
								depth_tiles_for_track.append(_coverage_to_plot_tile(shifted_cov))
								depth_series_by_track[track_id] = depth_tiles_for_track
				if last_bp_per_px > DETAILED_READ_MAX_BP_PER_PX and int(track.get("view_mode", 0)) == 1:
					for ov_any in overlaps:
						var ov_strand: Dictionary = ov_any as Dictionary
						var chr_id_strand := int(ov_strand["id"])
						var offset_strand := int(ov_strand["offset"])
						var local_start_strand := int(ov_strand["local_start"])
						var local_end_strand := int(ov_strand["local_end"])
						var tile_width_strand := 1024 << zoom
						var tile_start_strand := int(floor(float(local_start_strand) / float(tile_width_strand)))
						var tile_end_strand := int(floor(float(maxi(local_end_strand - 1, local_start_strand)) / float(tile_width_strand)))
						for t in range(tile_start_strand, tile_end_strand + 1):
							_mark_tile_range(keep_strand_coverage_keys, source_id, chr_id_strand, zoom, t)
							var strand_resp: Dictionary = _frame_get_strand_coverage_tile(zem, source_id, chr_id_strand, zoom, t)
							if not strand_resp.get("ok", false):
								return {"ok": false, "error": "Strand coverage query failed: %s" % strand_resp.get("error", "error")}
							track_strand_cov.append(_shift_strand_coverage_coords(strand_resp.get("coverage", {}), offset_strand))
				read_payload_by_track[track_id] = _prepare_track_payload(track, _build_prepared_reads(track, track_reads, seq_view_mode), track_cov, track_strand_cov, query_start, query_end, visible_start, visible_end, last_bp_per_px)
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
		if show_stop_codons:
			for ov_any in overlaps:
				var ov_stop: Dictionary = ov_any as Dictionary
				var chr_id_stop := int(ov_stop["id"])
				var offset_stop := int(ov_stop["offset"])
				var local_start_stop := int(ov_stop["local_start"])
				var local_end_stop := int(ov_stop["local_end"])
				var tile_width_stop := 1024 << zoom
				var tile_start_stop := int(floor(float(local_start_stop) / float(tile_width_stop)))
				var tile_end_stop := int(floor(float(maxi(local_end_stop - 1, local_start_stop)) / float(tile_width_stop)))
				for t in range(tile_start_stop, tile_end_stop + 1):
					_mark_tile_range(keep_stop_codon_keys, 0, chr_id_stop, zoom, t)
					var stop_resp_concat := _frame_get_stop_codon_tile(zem, chr_id_stop, zoom, t)
					if not stop_resp_concat.get("ok", false):
						return {"ok": false, "error": "Stop codon tile query failed: %s" % stop_resp_concat.get("error", "error")}
					stop_codon_tiles.append(_shift_stop_codon_coords(stop_resp_concat.get("tile", {}), offset_stop))

	for track_any in bam_tracks:
		var track: Dictionary = track_any as Dictionary
		var track_id := str(track.get("track_id", ""))
		if show_depth_plot and depth_series_by_track.has(track_id):
			var depth_tiles: Array = _dedupe_plot_tiles(depth_series_by_track[track_id])
			for tile_any in depth_tiles:
				if typeof(tile_any) == TYPE_DICTIONARY:
					depth_plot_tiles.append(tile_any)
			depth_plot_series.append({
				"track_id": track_id,
				"label": str(track.get("label", track_id)),
				"tiles": depth_tiles
			})

	_prune_cache(_read_tile_cache, keep_read_keys)
	_prune_cache(_coverage_tile_cache, keep_coverage_keys)
	_prune_cache(_strand_coverage_tile_cache, keep_strand_coverage_keys)
	_prune_cache(_gc_tile_cache, keep_gc_keys)
	_prune_cache(_annotation_tile_cache, keep_annotation_keys)
	_prune_cache(_stop_codon_tile_cache, keep_stop_codon_keys)
	annotation_stats["features_out"] = annotation_features.size()
	annotation_stats["fetch_time_ms"] = float(Time.get_ticks_usec() - annotation_t0) / 1000.0

	return {
		"ok": true,
		"serial": int(request.get("serial", -1)),
		"request_kind": str(request.get("request_kind", "visible")),
		"read_payload_by_track": read_payload_by_track,
		"annotation_features": annotation_features,
		"stop_codon_tiles": stop_codon_tiles,
		"annotation_stats": annotation_stats,
		"gc_plot_tiles": gc_plot_tiles,
		"depth_plot_tiles": depth_plot_tiles,
		"depth_plot_series": depth_plot_series,
		"ref_start": ref_start,
		"ref_sequence": ref_sequence
	}

func _build_concat_reference(zem, query_start: int, query_end: int, overlaps: Array) -> String:
	var ln := maxi(0, query_end - query_start)
	if ln == 0:
		return ""
	var chars: PackedStringArray = []
	chars.resize(ln)
	for i in range(ln):
		chars[i] = " "
	for ov_any in overlaps:
		if typeof(ov_any) != TYPE_DICTIONARY:
			continue
		var ov: Dictionary = ov_any
		var chr_id := int(ov.get("id", -1))
		var local_start := int(ov.get("local_start", 0))
		var local_end := int(ov.get("local_end", 0))
		var global_start := int(ov.get("global_start", 0))
		var ref_resp: Dictionary = zem.get_reference_slice(chr_id, local_start, local_end)
		if not ref_resp.get("ok", false):
			continue
		var seq := str(ref_resp.get("sequence", ""))
		var dst := global_start - query_start
		var copy_len := mini(seq.length(), ln - dst)
		for i in range(copy_len):
			chars[dst + i] = seq.substr(i, 1)
	var built := ""
	for c in chars:
		built += c
	return built

func _prepare_track_payload(track: Dictionary, prepared_reads_in: Array[Dictionary], track_cov: Array[Dictionary], track_strand_cov: Array[Dictionary], payload_start: int, payload_end: int, visible_start: int, visible_end: int, bp_per_px: float) -> Dictionary:
	var view_mode := int(track.get("view_mode", 0))
	var fragment_log := bool(track.get("fragment_log", true))
	var max_rows := int(track.get("max_rows", 500))
	var prepared_reads: Array[Dictionary] = []
	for read in prepared_reads_in:
		var s := int(read.get("start", 0))
		var e := int(read.get("end", s))
		if e > payload_start and s < payload_end:
			prepared_reads.append(read)
	var strand_summary := {}
	var fragment_summary := {}
	if bp_per_px > DETAILED_READ_MAX_BP_PER_PX:
		if view_mode == 1:
			strand_summary = _build_strand_summary_from_tiles(track_strand_cov, payload_start, payload_end)
		elif view_mode == 3:
			fragment_summary = _build_fragment_summary(prepared_reads, payload_start, payload_end)
	var viewport_limit := _viewport_read_limit(visible_start, visible_end, bp_per_px)
	if bp_per_px >= READ_VIEWPORT_SAMPLE_MIN_BP_PER_PX and prepared_reads.size() > viewport_limit:
		prepared_reads = _sample_reads_for_viewport(prepared_reads, visible_start, visible_end, bp_per_px, viewport_limit)
	var layout := _read_layout_helper.build_layout(prepared_reads, view_mode, fragment_log, max_rows, payload_start, payload_end)
	return {
		"reads": prepared_reads,
		"coverage": track_cov,
		"strand_summary": strand_summary,
		"fragment_summary": fragment_summary,
		"laid_out_reads": layout.get("laid_out_reads", []),
		"read_row_count": int(layout.get("read_row_count", 0)),
		"strand_forward_rows": int(layout.get("strand_forward_rows", 0)),
		"strand_reverse_rows": int(layout.get("strand_reverse_rows", 0))
	}

func _build_strand_summary_from_tiles(strand_tiles: Array[Dictionary], view_start: int, view_end: int, bin_count: int = 256) -> Dictionary:
	var span := maxi(1, view_end - view_start)
	var bins := clampi(bin_count, 32, 512)
	var forward := PackedFloat32Array()
	var reverse := PackedFloat32Array()
	var counts := PackedInt32Array()
	forward.resize(bins)
	reverse.resize(bins)
	counts.resize(bins)
	for tile in strand_tiles:
		if tile.is_empty():
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", tile_start))
		if tile_end <= view_start or tile_start >= view_end:
			continue
		var tile_forward: PackedInt32Array = tile.get("forward", PackedInt32Array())
		var tile_reverse: PackedInt32Array = tile.get("reverse", PackedInt32Array())
		var tile_bins := mini(tile_forward.size(), tile_reverse.size())
		if tile_bins <= 0:
			continue
		var tile_span := maxf(1.0, float(tile_end - tile_start) / float(tile_bins))
		for i in range(tile_bins):
			var src_mid := float(tile_start) + (float(i) + 0.5) * tile_span
			var idx := clampi(int(floor((src_mid - float(view_start)) * float(bins) / float(span))), 0, bins - 1)
			forward[idx] += float(tile_forward[i])
			reverse[idx] += float(tile_reverse[i])
			counts[idx] += 1
	for i in range(bins):
		if counts[i] <= 1:
			continue
		forward[i] /= float(counts[i])
		reverse[i] /= float(counts[i])
	return {
		"start": view_start,
		"end": view_end,
		"forward": forward,
		"reverse": reverse
	}

func _build_fragment_summary(reads_in: Array[Dictionary], view_start: int, view_end: int, bin_count: int = 256) -> Dictionary:
	var span := maxi(1, view_end - view_start)
	var bins := clampi(bin_count, 32, 512)
	var buckets: Array = []
	buckets.resize(bins)
	for i in range(bins):
		buckets[i] = []
	for read in reads_in:
		var frag_len := int(read.get("fragment_len", 0))
		if frag_len <= 0:
			continue
		var midpoint := int(floor((float(int(read.get("start", 0))) + float(int(read.get("end", 0)))) * 0.5))
		var idx := clampi(int(floor(float((midpoint - view_start) * bins) / float(span))), 0, bins - 1)
		var bucket: Array = buckets[idx]
		bucket.append(frag_len)
		buckets[idx] = bucket
	var p25 := PackedFloat32Array()
	var p50 := PackedFloat32Array()
	var p75 := PackedFloat32Array()
	p25.resize(bins)
	p50.resize(bins)
	p75.resize(bins)
	for i in range(bins):
		var bucket: Array = buckets[i]
		if bucket.is_empty():
			p25[i] = -1.0
			p50[i] = -1.0
			p75[i] = -1.0
			continue
		bucket.sort()
		p25[i] = float(bucket[int(floor(float(bucket.size() - 1) * 0.25))])
		p50[i] = float(bucket[int(floor(float(bucket.size() - 1) * 0.50))])
		p75[i] = float(bucket[int(floor(float(bucket.size() - 1) * 0.75))])
	return {
		"start": view_start,
		"end": view_end,
		"p25": p25,
		"median": p50,
		"p75": p75
	}

func _build_prepared_reads(track: Dictionary, track_reads: Array[Dictionary], seq_view_mode: int) -> Array[Dictionary]:
	var min_mapq := int(track.get("min_mapq", 0))
	var hidden_flags := int(track.get("hidden_flags", 0))
	var hide_improper_pair := bool(track.get("hide_improper_pair", false))
	var hide_forward_strand := bool(track.get("hide_forward_strand", false))
	var hide_mate_forward_strand := bool(track.get("hide_mate_forward_strand", false))
	var concat_fragment_view := seq_view_mode == SEQ_VIEW_CONCAT and int(track.get("view_mode", 0)) == 3
	var prepared_reads: Array[Dictionary] = []
	for read_any in _dedupe_reads(track_reads):
		if typeof(read_any) != TYPE_DICTIONARY:
			continue
		var read: Dictionary = (read_any as Dictionary).duplicate(false)
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
		if concat_fragment_view and (int(read.get("flags", 0)) & 1) != 0:
			var mate_start := int(read.get("mate_start", -1))
			var mate_end := int(read.get("mate_end", -1))
			if mate_start < 0 or mate_end <= mate_start:
				var read_start := int(read.get("start", 0))
				var read_end := int(read.get("end", read_start))
				read["fragment_len"] = maxi(1, read_end - read_start)
		_read_layout_helper.attach_indel_markers(read)
		prepared_reads.append(read)
	return prepared_reads

func _sample_reads_for_viewport(reads_in: Array[Dictionary], view_start: int, view_end: int, bp_per_px: float, limit: int) -> Array[Dictionary]:
	if reads_in.size() <= limit or view_end <= view_start or limit <= 0:
		return reads_in
	var viewport_px := maxi(1, int(round(float(view_end - view_start) / maxf(bp_per_px, 0.001))))
	var bin_count := clampi(int(round(float(viewport_px) / 2.0)), 128, mini(1024, limit))
	if bin_count <= 0:
		bin_count = 1
	var span := maxi(1, view_end - view_start)
	var bucket_reads: Array = []
	var bucket_scores: Array = []
	bucket_reads.resize(bin_count)
	bucket_scores.resize(bin_count)
	for i in range(bin_count):
		bucket_reads[i] = []
		bucket_scores[i] = []
	var base_cap := int(floor(float(limit) / float(bin_count)))
	var extra_caps := limit % bin_count
	for read in reads_in:
		var midpoint := int(floor((float(int(read.get("start", 0))) + float(int(read.get("end", 0)))) * 0.5))
		var bin_index := int(floor(float((midpoint - view_start) * bin_count) / float(span)))
		bin_index = clampi(bin_index, 0, bin_count - 1)
		var cap_for_bin := base_cap
		if bin_index < extra_caps:
			cap_for_bin += 1
		if cap_for_bin <= 0:
			continue
		var reads_bucket: Array = bucket_reads[bin_index]
		var scores_bucket: Array = bucket_scores[bin_index]
		var score := _stable_read_hash(read)
		if reads_bucket.size() < cap_for_bin:
			reads_bucket.append(read)
			scores_bucket.append(score)
			bucket_reads[bin_index] = reads_bucket
			bucket_scores[bin_index] = scores_bucket
			continue
		var worst_index := 0
		var worst_score := int(scores_bucket[0])
		for i in range(1, scores_bucket.size()):
			var item_score := int(scores_bucket[i])
			if item_score > worst_score:
				worst_score = item_score
				worst_index = i
		if score < worst_score:
			reads_bucket[worst_index] = read
			scores_bucket[worst_index] = score
			bucket_reads[bin_index] = reads_bucket
			bucket_scores[bin_index] = scores_bucket
	var selected: Array[Dictionary] = []
	selected.resize(0)
	for i in range(bin_count):
		var reads_bucket: Array = bucket_reads[i]
		if reads_bucket.is_empty():
			continue
		for read_any in reads_bucket:
			selected.append(read_any)
	if selected.size() <= limit:
		_sort_reads_by_position(selected)
		return selected
	var trimmed: Array[Dictionary] = []
	for i in range(limit):
		trimmed.append(selected[i])
	_sort_reads_by_position(trimmed)
	return trimmed

func _viewport_read_limit(view_start: int, view_end: int, bp_per_px: float) -> int:
	var viewport_px := maxi(1, int(round(float(view_end - view_start) / maxf(bp_per_px, 0.001))))
	var target := viewport_px * 16
	return clampi(target, MIN_VIEWPORT_READS_PER_TRACK, MAX_VIEWPORT_READS_PER_TRACK)

func _stable_read_hash(read: Dictionary) -> int:
	var key := _read_dedupe_key(read)
	var h := 2166136261
	for i in range(key.length()):
		h = int((h ^ key.unicode_at(i)) * 16777619) & 0x7fffffff
	return h

func _sort_reads_by_position(reads: Array[Dictionary]) -> void:
	reads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("start", 0))
		var sb := int(b.get("start", 0))
		if sa == sb:
			var ea := int(a.get("end", sa))
			var eb := int(b.get("end", sb))
			if ea == eb:
				return str(a.get("name", "")) < str(b.get("name", ""))
			return ea < eb
		return sa < sb
	)

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

func _frame_get_strand_coverage_tile(zem, source_id: int, chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var key := _frame_tile_key(source_id, chr_id, zoom, tile_index, -1)
	if _strand_coverage_tile_cache.has(key):
		return _strand_coverage_tile_cache[key]
	var resp: Dictionary = zem.get_strand_coverage_tile(chr_id, zoom, tile_index, source_id)
	_strand_coverage_tile_cache[key] = resp
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

func _frame_get_stop_codon_tile(zem, chr_id: int, zoom: int, tile_index: int) -> Dictionary:
	var key := _frame_tile_key(0, chr_id, zoom, tile_index, -2)
	if _stop_codon_tile_cache.has(key):
		return _stop_codon_tile_cache[key]
	var resp: Dictionary = zem.get_stop_codon_tile(chr_id, zoom, tile_index)
	_stop_codon_tile_cache[key] = resp
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

func _fetch_stop_codon_tiles_single(zem, chr_id: int, start_bp: int, end_bp: int, zoom: int, keep_stop_codon_keys: Dictionary) -> Dictionary:
	if end_bp <= start_bp:
		return {"ok": true, "tiles": []}
	var tile_w := ANNOT_TILE_BASE_BP << zoom
	var tile_start := int(floor(float(start_bp) / float(tile_w)))
	var tile_end := int(floor(float(maxi(end_bp - 1, start_bp)) / float(tile_w)))
	if tile_end < tile_start:
		tile_end = tile_start
	var out: Array = []
	for t in range(tile_start, tile_end + 1):
		_mark_tile_range(keep_stop_codon_keys, 0, chr_id, zoom, t)
		var resp := _frame_get_stop_codon_tile(zem, chr_id, zoom, t)
		if not resp.get("ok", false):
			return {"ok": false, "error": "Stop codon tile query failed: %s" % resp.get("error", "error")}
		var tile: Dictionary = resp.get("tile", {})
		if not tile.is_empty():
			out.append(tile)
	return {"ok": true, "tiles": out}

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
	var shifted := read.duplicate(false)
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

func _shift_strand_coverage_coords(cov: Dictionary, offset: int) -> Dictionary:
	if cov.is_empty():
		return cov
	return {
		"start": int(cov.get("start", 0)) + offset,
		"end": int(cov.get("end", 0)) + offset,
		"forward": cov.get("forward", PackedInt32Array()),
		"reverse": cov.get("reverse", PackedInt32Array())
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

func _shift_stop_codon_coords(tile: Dictionary, offset: int) -> Dictionary:
	if tile.is_empty():
		return tile
	return {
		"start": int(tile.get("start", 0)) + offset,
		"end": int(tile.get("end", 0)) + offset,
		"bin_count": int(tile.get("bin_count", 0)),
		"frames": tile.get("frames", [])
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

func _dedupe_plot_tiles(tiles_in: Array) -> Array:
	var seen := {}
	var out: Array = []
	for tile_any in tiles_in:
		if typeof(tile_any) != TYPE_DICTIONARY:
			continue
		var tile: Dictionary = tile_any
		var key := "%d|%d" % [int(tile.get("start", 0)), int(tile.get("end", 0))]
		if seen.get(key, false):
			continue
		seen[key] = true
		out.append(tile)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	return out
