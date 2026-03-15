extends RefCounted
class_name AnnotationCacheController

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func annotation_pixel_budget() -> int:
	return host.ANNOT_MAX_ON_SCREEN_MAX


func annotation_min_feature_len_bp() -> int:
	var min_px := 3.0
	var raw := int(ceil(min_px * host._last_bp_per_px))
	return maxi(raw, 1)


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
	var show_aa: bool = bool(host.genome_view.is_track_visible(host.TRACK_AA))
	var show_gc_plot: bool = bool(host.genome_view.is_track_visible(host.TRACK_GC_PLOT))
	var show_depth_plot: bool = bool(host.genome_view.is_track_visible(host.TRACK_DEPTH_PLOT))
	var show_genome: bool = bool(host.genome_view.is_track_visible(host.TRACK_GENOME))
	var need_annotations: bool = show_aa or show_genome
	var need_reference: bool = host.genome_view.needs_reference_data(show_aa, show_genome)
	var span: int = maxi(1, host._last_end - host._last_start)
	var left_span_mult := 1.0
	var right_span_mult := 2.0 if host._auto_play_enabled else 1.0
	var query_start: int = maxi(0, int(floor(float(host._last_start) - float(span) * left_span_mult)))
	var query_end: int = mini(host._current_chr_len, int(ceil(float(host._last_end) + float(span) * right_span_mult)))
	var ref_start := query_start
	var ref_sequence := ""
	var overlaps: Array[Dictionary] = []
	var visible_track_ids := {}
	for t_any in host._bam_tracks:
		var track_vis: Dictionary = t_any
		var track_vis_id := str(track_vis.get("track_id", ""))
		visible_track_ids[track_vis_id] = host.genome_view.is_track_visible(track_vis_id)

	if host._seq_view_mode != host.SEQ_VIEW_SINGLE:
		overlaps = host._segments_overlapping(query_start, query_end)
	else:
		if not need_reference:
			host.genome_view.set_reference_slice(ref_start, "")
	host.tile_fetch_serial += 1
	host.pending_tile_apply = {
		"serial": host.tile_fetch_serial,
		"query_start": query_start,
		"query_end": query_end,
		"need_reference": need_reference,
		"ref_start": ref_start,
		"ref_sequence": ref_sequence
	}
	host._tile_controller.request_tiles({
		"serial": host.tile_fetch_serial,
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
		"show_reads": show_reads,
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


func drain_tile_fetch_result() -> void:
	if host._tile_controller == null:
		return
	var tile_resp: Dictionary = host._tile_controller.poll_result()
	if tile_resp.is_empty():
		return
	if not tile_resp.get("ok", false):
		host._set_status(str(tile_resp.get("error", "Tile fetch failed")), true)
		host._fetch_in_progress = false
		if host._fetch_pending:
			host._fetch_timer.start()
		return
	var serial := int(tile_resp.get("serial", -1))
	if serial != int(host.pending_tile_apply.get("serial", -2)):
		host._fetch_in_progress = false
		if host._fetch_pending:
			host._fetch_timer.start()
		return
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
	host._fetch_in_progress = false
	if host._fetch_pending:
		host._fetch_timer.start()
