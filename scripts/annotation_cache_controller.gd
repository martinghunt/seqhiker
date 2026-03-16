extends RefCounted
class_name AnnotationCacheController

var host: Node = null
var _strip_segments: Array[Dictionary] = []
var _strip_zoom := -1
var _strip_scope_key := ""
var _strip_generation := -1
var _strip_left_pending := false
var _strip_right_pending := false
var _strip_pending_requests: Dictionary = {}

const NORMAL_LEFT_SPAN_MULT := 1.0
const NORMAL_RIGHT_SPAN_MULT := 1.0
const AUTOPLAY_RIGHT_SPAN_MULT := 2.0


func configure(next_host: Node) -> void:
	host = next_host


func annotation_pixel_budget() -> int:
	return host.ANNOT_MAX_ON_SCREEN_MAX


func annotation_min_feature_len_bp() -> int:
	var min_px := 3.0
	var raw := int(ceil(min_px * host._last_bp_per_px))
	return maxi(raw, 1)


func detailed_read_strips_enabled(bp_per_px: float) -> bool:
	if host == null or host._current_chr_len <= 0:
		return false
	if not host._has_bam_loaded or not host._any_visible_read_track():
		return false
	return bp_per_px <= host.genome_view.DETAILED_READ_MAX_BP_PER_PX


func schedule_fetch() -> void:
	if host._fetch_timer == null:
		return
	if host._fetch_in_progress:
		host._fetch_pending = true
		return
	if host._fetch_timer.is_stopped():
		host._fetch_timer.start()


func on_fetch_timer_timeout() -> void:
	host._fetch_in_progress = true
	host._fetch_pending = false
	refresh_visible_data()


func refresh_visible_data() -> void:
	if host._current_chr_len <= 0:
		host._finish_sync_fetch_attempt()
		return
	if host._debug_enabled:
		host._reset_debug_annotation_counters()
	var show_reads: bool = host._any_visible_read_track()
	var fetch_reads_in_window := show_reads and not detailed_read_strips_enabled(host._last_bp_per_px)
	var show_aa: bool = bool(host.genome_view.is_track_visible(host.TRACK_AA))
	var show_gc_plot: bool = bool(host.genome_view.is_track_visible(host.TRACK_GC_PLOT))
	var show_depth_plot: bool = bool(host.genome_view.is_track_visible(host.TRACK_DEPTH_PLOT))
	var show_genome: bool = bool(host.genome_view.is_track_visible(host.TRACK_GENOME))
	var need_annotations: bool = show_aa or show_genome
	var need_reference: bool = host.genome_view.needs_reference_data(show_aa, show_genome)
	var span: int = maxi(1, host._last_end - host._last_start)
	var left_span_mult := NORMAL_LEFT_SPAN_MULT
	var right_span_mult := AUTOPLAY_RIGHT_SPAN_MULT if host._auto_play_enabled else NORMAL_RIGHT_SPAN_MULT
	var query_start := maxi(0, int(floor(float(host._last_start) - float(span) * left_span_mult)))
	var query_end := mini(host._current_chr_len, int(ceil(float(host._last_end) + float(span) * right_span_mult)))
	var overlaps: Array[Dictionary] = []
	var visible_track_ids := {}
	for t_any in host._bam_tracks:
		var track_vis: Dictionary = t_any
		var track_vis_id := str(track_vis.get("track_id", ""))
		visible_track_ids[track_vis_id] = host.genome_view.is_track_visible(track_vis_id)
	if host._seq_view_mode != host.SEQ_VIEW_SINGLE:
		overlaps = host._segments_overlapping(query_start, query_end)
	elif not need_reference:
		host.genome_view.set_reference_slice(query_start, "")
	host.tile_fetch_serial += 1
	var serial: int = int(host.tile_fetch_serial)
	host.pending_tile_apply = {
		"serial": serial,
		"query_start": query_start,
		"query_end": query_end,
		"need_reference": need_reference,
		"ref_start": query_start,
		"ref_sequence": "",
		"zoom": host._compute_tile_zoom(host._last_bp_per_px),
		"mode": 0 if (host._has_bam_loaded and host._any_visible_read_track() and host._last_bp_per_px <= host.READ_RENDER_MAX_BP_PER_PX) else 1,
		"scope_key": host._scope_cache_key(),
		"fetch_reads": fetch_reads_in_window
	}
	host._tile_controller.request_tiles({
		"serial": serial,
		"request_kind": "visible",
		"high_priority": true,
		"host": "127.0.0.1",
		"port": host.ZEM_DEFAULT_PORT,
		"generation": host._tile_cache_generation,
		"scope_key": host._scope_cache_key(),
		"need_reference": need_reference,
		"visible_start": host._last_start,
		"visible_end": host._last_end,
		"query_start": query_start,
		"query_end": query_end,
		"last_bp_per_px": host._last_bp_per_px,
		"show_reads": fetch_reads_in_window,
		"show_annotations": need_annotations,
		"show_gc_plot": show_gc_plot,
		"show_depth_plot": show_depth_plot,
		"has_bam_loaded": host._has_bam_loaded,
		"seq_view_mode": host._seq_view_mode,
		"current_chr_id": host._current_chr_id,
		"bam_tracks": host._bam_tracks,
		"overlaps": overlaps,
		"visible_track_ids": visible_track_ids,
		"gc_window_bp": host._gc_window_bp,
		"annotation_cap_total": annotation_pixel_budget(),
		"annotation_min_len_bp": annotation_min_feature_len_bp()
	})


func update_detailed_read_strips(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	if not detailed_read_strips_enabled(bp_per_px):
		_reset_read_strips()
		return
	_ensure_read_strip_scope(bp_per_px)
	var covered := _strip_covered_range()
	if covered.x <= start_bp and covered.y >= end_bp:
		_apply_read_strip_viewport(start_bp, end_bp)
	_request_missing_read_strips(start_bp, end_bp, bp_per_px)


func prefetch_detailed_read_target(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	if not detailed_read_strips_enabled(bp_per_px):
		return
	_ensure_read_strip_scope(bp_per_px)
	_request_missing_read_strips(start_bp, end_bp, bp_per_px)


func detailed_read_target_ready(start_bp: int, end_bp: int, bp_per_px: float) -> bool:
	if not detailed_read_strips_enabled(bp_per_px):
		return true
	_ensure_read_strip_scope(bp_per_px)
	var covered := _strip_covered_range()
	return covered.x <= start_bp and covered.y >= end_bp


func apply_detailed_read_span(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	if not detailed_read_strips_enabled(bp_per_px):
		return
	_ensure_read_strip_scope(bp_per_px)
	var covered := _strip_covered_range()
	if covered.x <= start_bp and covered.y >= end_bp:
		_apply_read_strip_viewport(start_bp, end_bp)


func _ensure_read_strip_scope(bp_per_px: float) -> void:
	var zoom: int = int(host._compute_tile_zoom(bp_per_px))
	var scope_key: String = str(host._scope_cache_key())
	if zoom != _strip_zoom or scope_key != _strip_scope_key or host._tile_cache_generation != _strip_generation:
		_reset_read_strips()
		_strip_zoom = zoom
		_strip_scope_key = scope_key
		_strip_generation = host._tile_cache_generation


func drain_tile_fetch_result() -> void:
	if host._tile_controller == null:
		return
	var tile_resp: Dictionary = host._tile_controller.poll_result()
	if tile_resp.is_empty():
		return
	var serial := int(tile_resp.get("serial", -1))
	if _strip_pending_requests.has(serial):
		_handle_read_strip_result(serial, tile_resp)
		return
	var kind := str(tile_resp.get("request_kind", ""))
	if kind == "read_strip":
		_handle_read_strip_result(serial, tile_resp)
		return
	if not tile_resp.get("ok", false):
		host._set_status(str(tile_resp.get("error", "Tile fetch failed")), true)
		host._fetch_in_progress = false
		if host._fetch_pending:
			host._fetch_timer.start()
		return
	if serial != int(host.pending_tile_apply.get("serial", -2)):
		host._fetch_in_progress = false
		if host._fetch_pending:
			host._fetch_timer.start()
		return
	_apply_visible_tile_result(tile_resp)
	host._fetch_in_progress = false
	if host._fetch_pending:
		host._fetch_timer.start()


func _handle_read_strip_result(serial: int, tile_resp: Dictionary) -> void:
	var req: Dictionary = _strip_pending_requests.get(serial, {})
	if req.is_empty():
		return
	_strip_pending_requests.erase(serial)
	var side := str(req.get("side", ""))
	if side == "left":
		_strip_left_pending = false
	else:
		_strip_right_pending = false
	if not tile_resp.get("ok", false):
		return
	if int(req.get("zoom", -1)) != _strip_zoom:
		return
	if str(req.get("scope_key", "")) != _strip_scope_key:
		return
	if int(req.get("generation", -1)) != _strip_generation:
		return
	_store_read_strip_segment(req, tile_resp)
	if detailed_read_strips_enabled(host._last_bp_per_px):
		_apply_read_strip_viewport(host._last_start, host._last_end)
		_request_missing_read_strips(host._last_start, host._last_end, host._last_bp_per_px)


func _request_missing_read_strips(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	var span := maxi(1, end_bp - start_bp)
	var pan_dir := _recent_pan_direction()
	var want_start := maxi(0, start_bp - span)
	var want_end := mini(host._current_chr_len, end_bp + span)
	if pan_dir > 0:
		want_end = mini(host._current_chr_len, end_bp + span * 2)
	elif pan_dir < 0:
		want_start = maxi(0, start_bp - span * 2)
	var covered := _strip_covered_range()
	if covered.x < 0 or covered.y <= covered.x:
		_request_read_strip(want_start, want_end, bp_per_px, "right")
		return
	if covered.x > want_start:
		_request_read_strip(want_start, covered.x, bp_per_px, "left")
	if covered.y < want_end:
		_request_read_strip(covered.y, want_end, bp_per_px, "right")


func _request_read_strip(start_bp: int, end_bp: int, bp_per_px: float, side: String) -> void:
	start_bp = maxi(0, start_bp)
	end_bp = mini(host._current_chr_len, end_bp)
	if end_bp <= start_bp:
		return
	if side == "left" and _strip_left_pending:
		return
	if side == "right" and _strip_right_pending:
		return
	var overlaps: Array[Dictionary] = []
	if host._seq_view_mode != host.SEQ_VIEW_SINGLE:
		overlaps = host._segments_overlapping(start_bp, end_bp)
	var visible_track_ids := {}
	for t_any in host._bam_tracks:
		var track_vis: Dictionary = t_any
		var track_vis_id := str(track_vis.get("track_id", ""))
		visible_track_ids[track_vis_id] = host.genome_view.is_track_visible(track_vis_id)
	host.tile_fetch_serial += 1
	var serial: int = int(host.tile_fetch_serial)
	var req := {
		"serial": serial,
		"side": side,
		"start_bp": start_bp,
		"end_bp": end_bp,
		"zoom": _strip_zoom,
		"scope_key": _strip_scope_key,
		"generation": _strip_generation
	}
	_strip_pending_requests[serial] = req
	if side == "left":
		_strip_left_pending = true
	else:
		_strip_right_pending = true
	host._tile_controller.request_tiles({
		"serial": serial,
		"request_kind": "read_strip",
		"high_priority": true,
		"host": "127.0.0.1",
		"port": host.ZEM_DEFAULT_PORT,
		"generation": host._tile_cache_generation,
		"scope_key": host._scope_cache_key(),
		"need_reference": false,
		"visible_start": start_bp,
		"visible_end": end_bp,
		"query_start": start_bp,
		"query_end": end_bp,
		"last_bp_per_px": bp_per_px,
		"show_reads": true,
		"show_annotations": false,
		"show_gc_plot": false,
		"show_depth_plot": false,
		"has_bam_loaded": host._has_bam_loaded,
		"seq_view_mode": host._seq_view_mode,
		"current_chr_id": host._current_chr_id,
		"bam_tracks": host._bam_tracks,
		"overlaps": overlaps,
		"visible_track_ids": visible_track_ids,
		"gc_window_bp": host._gc_window_bp,
		"annotation_cap_total": 0,
		"annotation_min_len_bp": 1
	})


func _store_read_strip_segment(req: Dictionary, tile_resp: Dictionary) -> void:
	var segment := {
		"start_bp": int(req.get("start_bp", 0)),
		"end_bp": int(req.get("end_bp", 0)),
		"read_payload_by_track": (tile_resp.get("read_payload_by_track", {}) as Dictionary).duplicate(true)
	}
	_strip_segments.append(segment)
	_strip_segments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start_bp", 0)) < int(b.get("start_bp", 0))
	)
	var merged: Array[Dictionary] = []
	for seg_any in _strip_segments:
		var seg: Dictionary = seg_any
		if merged.is_empty():
			merged.append(seg)
			continue
		var prev: Dictionary = merged[merged.size() - 1]
		if int(seg.get("start_bp", 0)) >= int(prev.get("start_bp", 0)) and int(seg.get("end_bp", 0)) <= int(prev.get("end_bp", 0)):
			continue
		if int(seg.get("start_bp", 0)) <= int(prev.get("start_bp", 0)) and int(seg.get("end_bp", 0)) >= int(prev.get("end_bp", 0)):
			merged[merged.size() - 1] = seg
			continue
		merged.append(seg)
	_strip_segments = merged
	_prune_read_strips()


func _prune_read_strips() -> void:
	if _strip_segments.is_empty():
		return
	var span := maxi(1, host._last_end - host._last_start)
	var keep_start := maxi(0, host._last_start - span * 4)
	var keep_end := mini(host._current_chr_len, host._last_end + span * 4)
	var kept: Array[Dictionary] = []
	for seg_any in _strip_segments:
		var seg: Dictionary = seg_any
		if int(seg.get("end_bp", 0)) <= keep_start or int(seg.get("start_bp", 0)) >= keep_end:
			continue
		kept.append(seg)
	_strip_segments = kept


func _strip_covered_range() -> Vector2i:
	if _strip_segments.is_empty():
		return Vector2i(-1, -1)
	var left := int(_strip_segments[0].get("start_bp", -1))
	var right := int(_strip_segments[0].get("end_bp", -1))
	for seg_any in _strip_segments:
		var seg: Dictionary = seg_any
		left = mini(left, int(seg.get("start_bp", left)))
		right = maxi(right, int(seg.get("end_bp", right)))
	return Vector2i(left, right)


func _apply_read_strip_viewport(start_bp: int, end_bp: int) -> void:
	for t_any in host._bam_tracks:
		var track: Dictionary = t_any
		var track_id := str(track.get("track_id", ""))
		var reads_out: Array[Dictionary] = []
		var coverage_out: Array[Dictionary] = []
		var strand_summary := {}
		var fragment_summary := {}
		for seg_any in _strip_segments:
			var seg: Dictionary = seg_any
			if int(seg.get("end_bp", 0)) <= start_bp or int(seg.get("start_bp", 0)) >= end_bp:
				continue
			var read_payload_by_track: Dictionary = seg.get("read_payload_by_track", {})
			var payload: Dictionary = read_payload_by_track.get(track_id, {})
			for read_any in payload.get("reads", []):
				if typeof(read_any) != TYPE_DICTIONARY:
					continue
				var read: Dictionary = read_any
				if int(read.get("end", 0)) > start_bp and int(read.get("start", 0)) < end_bp:
					reads_out.append(read)
			for cov_any in payload.get("coverage", []):
				if typeof(cov_any) == TYPE_DICTIONARY:
					coverage_out.append(cov_any)
			if strand_summary.is_empty() and typeof(payload.get("strand_summary", {})) == TYPE_DICTIONARY:
				strand_summary = payload.get("strand_summary", {})
			if fragment_summary.is_empty() and typeof(payload.get("fragment_summary", {})) == TYPE_DICTIONARY:
				fragment_summary = payload.get("fragment_summary", {})
		host.genome_view.set_read_track_payload(
			track_id,
			{
				"reads": _dedupe_reads(reads_out),
				"coverage": coverage_out,
				"strand_summary": strand_summary,
				"fragment_summary": fragment_summary
			},
			int(track.get("view_mode", 0)),
			bool(track.get("fragment_log", true)),
			float(track.get("thickness", host.DEFAULT_READ_THICKNESS)),
			int(track.get("max_rows", host.DEFAULT_READ_MAX_ROWS)),
			bool(track.get("auto_expand_snp_text", true)),
			bool(track.get("color_by_mate_contig", false))
		)


func _dedupe_reads(reads_in: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var seen := {}
	for read_any in reads_in:
		var read: Dictionary = read_any
		var key := "%s|%d|%d|%d" % [
			str(read.get("name", "")),
			int(read.get("start", 0)),
			int(read.get("end", 0)),
			int(read.get("flags", 0))
		]
		if seen.get(key, false):
			continue
		seen[key] = true
		out.append(read)
	return out


func _apply_visible_tile_result(tile_resp: Dictionary) -> void:
	var read_payload_by_track = tile_resp.get("read_payload_by_track", {})
	var annotation_features_raw: Array = tile_resp.get("annotation_features", [])
	var annotation_stats: Dictionary = tile_resp.get("annotation_stats", {})
	var all_gc_plot_tiles: Array = tile_resp.get("gc_plot_tiles", [])
	var all_depth_plot_tiles: Array = tile_resp.get("depth_plot_tiles", [])
	var all_depth_plot_series: Array = tile_resp.get("depth_plot_series", [])
	var result_ref_start := int(tile_resp.get("ref_start", int(host.pending_tile_apply.get("ref_start", -1))))
	var result_ref_sequence := str(tile_resp.get("ref_sequence", host.pending_tile_apply.get("ref_sequence", "")))
	host.genome_view.set_reference_slice(result_ref_start, result_ref_sequence)
	var annotation_features: Array[Dictionary] = []
	for feat_any in annotation_features_raw:
		if typeof(feat_any) == TYPE_DICTIONARY:
			annotation_features.append(feat_any)
	annotation_features = host._collapse_gene_cds_features(annotation_features)
	host.genome_view.set_features(annotation_features)
	host._apply_pending_annotation_highlight(annotation_features)
	var gc_plot_tiles_typed: Array[Dictionary] = []
	for tile_any in all_gc_plot_tiles:
		if typeof(tile_any) == TYPE_DICTIONARY:
			gc_plot_tiles_typed.append(tile_any)
	var depth_plot_tiles_typed: Array[Dictionary] = []
	for tile_any in all_depth_plot_tiles:
		if typeof(tile_any) == TYPE_DICTIONARY:
			depth_plot_tiles_typed.append(tile_any)
	var depth_plot_series_typed: Array[Dictionary] = []
	for series_any in all_depth_plot_series:
		if typeof(series_any) == TYPE_DICTIONARY:
			depth_plot_series_typed.append(series_any)
	if bool(host.pending_tile_apply.get("fetch_reads", true)):
		for t_any in host._bam_tracks:
			var track: Dictionary = t_any
			var track_id := str(track.get("track_id", ""))
			var payload: Dictionary = read_payload_by_track.get(track_id, {"reads": [], "coverage": []})
			host.genome_view.set_read_track_payload(
				track_id,
				payload,
				int(track.get("view_mode", 0)),
				bool(track.get("fragment_log", true)),
				float(track.get("thickness", host.DEFAULT_READ_THICKNESS)),
				int(track.get("max_rows", host.DEFAULT_READ_MAX_ROWS)),
				bool(track.get("auto_expand_snp_text", true)),
				bool(track.get("color_by_mate_contig", false))
			)
			if host.center_strand_scroll_pending and int(track.get("view_mode", 0)) == 1 and (payload.get("reads", []) as Array).size() > 0:
				host.genome_view.center_strand_scroll_for_track(track_id)
				host.center_strand_scroll_pending = false
	host.genome_view.set_gc_plot_tiles(gc_plot_tiles_typed)
	host.genome_view.set_depth_plot_tiles(depth_plot_tiles_typed)
	for i in range(depth_plot_series_typed.size()):
		var series: Dictionary = depth_plot_series_typed[i]
		series["color"] = host._depth_plot_color_for_track(str(series.get("track_id", "")))
		depth_plot_series_typed[i] = series
	host.genome_view.set_depth_plot_series(depth_plot_series_typed)
	host._cache_start = int(host.pending_tile_apply.get("query_start", -1))
	host._cache_end = int(host.pending_tile_apply.get("query_end", -1))
	host._cache_zoom = host._compute_tile_zoom(host._last_bp_per_px)
	host._cache_mode = 0 if (host._has_bam_loaded and host._any_visible_read_track() and host._last_bp_per_px <= host.READ_RENDER_MAX_BP_PER_PX) else 1
	host._cache_need_reference = bool(host.pending_tile_apply.get("need_reference", false))
	host._cache_scope_key = host._scope_cache_key()
	host._dbg_ann_tile_requests = int(annotation_stats.get("tile_requests", 0))
	host._dbg_ann_tile_cache_hits = int(annotation_stats.get("tile_cache_hits", 0))
	host._dbg_ann_tile_queries = int(annotation_stats.get("tile_queries", 0))
	host._dbg_ann_features_examined = int(annotation_stats.get("features_examined", 0))
	host._dbg_ann_features_out = int(annotation_stats.get("features_out", 0))
	host._dbg_ann_fetch_time_ms = float(annotation_stats.get("fetch_time_ms", 0.0))
	if host._debug_enabled:
		host._update_debug_stats_label()


func _recent_pan_direction() -> int:
	if host._last_start > host._prev_view_start:
		return 1
	if host._last_start < host._prev_view_start:
		return -1
	return 0


func _reset_read_strips() -> void:
	_strip_segments.clear()
	_strip_zoom = -1
	_strip_scope_key = ""
	_strip_generation = -1
	_strip_left_pending = false
	_strip_right_pending = false
	_strip_pending_requests.clear()
