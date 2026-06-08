extends "res://tests/godot/test_case.gd"

const AnnotationCacheControllerScript = preload("res://scripts/annotation_cache_controller.gd")

var host: FakeHost
var controller: RefCounted


class FakeTimer:
	extends RefCounted

	var start_count := 0
	var stop_count := 0

	func start() -> void:
		start_count += 1

	func stop() -> void:
		stop_count += 1

	func is_stopped() -> bool:
		return true


class FakeTileController:
	extends RefCounted

	var requests: Array[Dictionary] = []
	var results: Array[Dictionary] = []
	var cancel_count := 0

	func request_tiles(request: Dictionary) -> void:
		requests.append(request.duplicate(true))

	func poll_result() -> Dictionary:
		if results.is_empty():
			return {}
		return results.pop_front()

	func cancel_requests() -> void:
		cancel_count += 1


class FakeGenomeView:
	extends RefCounted

	const DETAILED_READ_MAX_BP_PER_PX := 4.0

	var visible_tracks := {"bam1": true}
	var read_payloads: Dictionary = {}
	var reference_slices: Array[Dictionary] = []
	var features: Array[Dictionary] = []

	func is_track_visible(track_id: String) -> bool:
		return bool(visible_tracks.get(track_id, false))

	func is_motion_read_layer_active() -> bool:
		return false

	func needs_reference_data(_show_aa: bool, _show_genome: bool) -> bool:
		return false

	func needs_stop_codon_overview(_show_aa: bool) -> bool:
		return false

	func set_reference_slice(start_bp: int, sequence: String) -> void:
		reference_slices.append({"start": start_bp, "sequence": sequence})

	func set_features(next_features: Array[Dictionary]) -> void:
		features = next_features

	func set_stop_codon_tiles(_tiles: Array[Dictionary]) -> void:
		pass

	func set_variant_tiles(_tiles: Array[Dictionary]) -> void:
		pass

	func set_read_track_payload(track_id: String, payload: Dictionary, _view_mode: int, _fragment_log: bool, _thickness: float, _max_rows: int, _auto_expand_snp_text: bool, _show_soft_clips: bool, _show_pileup_logo: bool, _color_by_mate_contig: bool) -> void:
		read_payloads[track_id] = payload.duplicate(true)

	func set_gc_plot_tiles(_tiles: Array[Dictionary]) -> void:
		pass

	func set_depth_plot_tiles(_tiles: Array[Dictionary]) -> void:
		pass

	func set_depth_plot_series(_series: Array[Dictionary]) -> void:
		pass

	func center_strand_scroll_for_track(_track_id: String) -> void:
		pass


class FakeHost:
	extends Node

	const ANNOT_MAX_ON_SCREEN_MAX := 50000
	const DEFAULT_READ_THICKNESS := 8.0
	const DEFAULT_READ_MAX_ROWS := 500
	const READ_RENDER_MAX_BP_PER_PX := 128.0
	const SEQ_VIEW_SINGLE := 1
	const ZEM_DEFAULT_PORT := 9000
	const TRACK_AA := "aa"
	const TRACK_GC_PLOT := "gc_plot"
	const TRACK_DEPTH_PLOT := "depth_plot"
	const TRACK_GENOME := "genome"
	const TRACK_VCF := "vcf"

	var genome_view := FakeGenomeView.new()
	var _tile_controller := FakeTileController.new()
	var _fetch_timer := FakeTimer.new()
	var _current_chr_len := 1000
	var _has_bam_loaded := true
	var _last_bp_per_px := 1.0
	var _last_start := 100
	var _last_end := 200
	var _prev_view_start := 100
	var _fetch_in_progress := false
	var _fetch_pending := false
	var _tile_cache_generation := 0
	var _seq_view_mode := SEQ_VIEW_SINGLE
	var _current_chr_id := 1
	var _gc_window_bp := 200
	var _bam_tracks: Array[Dictionary] = [
		{"track_id": "bam1", "view_mode": 0, "fragment_log": true, "thickness": 8.0, "max_rows": 500}
	]
	var _variant_sources: Array[Dictionary] = []
	var tile_fetch_serial := 0
	var status_messages: Array[Dictionary] = []
	var _cache_start := -1
	var _cache_end := -1
	var _cache_zoom := -1
	var _cache_mode := -1
	var _cache_need_reference := false
	var _cache_scope_key := ""
	var _debug_enabled := false
	var _dbg_ann_tile_requests := 0
	var _dbg_ann_tile_cache_hits := 0
	var _dbg_ann_tile_queries := 0
	var _dbg_ann_features_examined := 0
	var _dbg_ann_features_out := 0
	var _dbg_ann_fetch_time_ms := 0.0
	var center_strand_scroll_pending := false

	func _any_visible_read_track() -> bool:
		return true

	func _compute_tile_zoom(_bp_per_px: float) -> int:
		return 1

	func _scope_cache_key() -> String:
		return "scope"

	func _segments_overlapping(_start_bp: int, _end_bp: int) -> Array[Dictionary]:
		return []

	func _set_status(message: String, is_error: bool = false) -> void:
		status_messages.append({"message": message, "is_error": is_error})

	func _collapse_gene_cds_features(features_in: Array[Dictionary]) -> Array[Dictionary]:
		return features_in

	func _apply_pending_annotation_highlight(_features: Array[Dictionary]) -> void:
		pass

	func _depth_plot_color_for_track(_track_id: String) -> Color:
		return Color.WHITE

	func _update_debug_stats_label() -> void:
		pass

	func _finish_sync_fetch_attempt() -> void:
		pass

	func _reset_debug_annotation_counters() -> void:
		pass


func setup() -> void:
	host = FakeHost.new()
	controller = AnnotationCacheControllerScript.new()
	controller.configure(host)


func teardown() -> void:
	host.free()
	host = null
	controller = null


func _strip_segments(items: Array) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item_any in items:
		var item: Dictionary = item_any
		out.append(item)
	return out


func test_detailed_read_target_requires_continuous_strip_coverage() -> void:
	controller._strip_segments = _strip_segments([
		{"start_bp": 0, "end_bp": 150},
		{"start_bp": 180, "end_bp": 300}
	])
	assert_false(controller.detailed_read_target_ready(100, 200, 1.0), "Disjoint cached strips must not be treated as complete coverage.")
	controller._strip_segments = _strip_segments([
		{"start_bp": 0, "end_bp": 150},
		{"start_bp": 150, "end_bp": 300}
	])
	assert_true(controller.detailed_read_target_ready(100, 200, 1.0), "Adjacent cached strips should cover the requested region.")


func test_missing_read_strip_request_fills_internal_gap() -> void:
	controller._strip_zoom = 1
	controller._strip_scope_key = "scope"
	controller._strip_generation = 0
	controller._strip_segments = _strip_segments([
		{"start_bp": 0, "end_bp": 150},
		{"start_bp": 180, "end_bp": 300}
	])

	controller._request_missing_read_strips(100, 200, 1.0)

	assert_eq(host._tile_controller.requests.size(), 1, "Expected one request for the internal gap.")
	if host._tile_controller.requests.is_empty():
		return
	var request: Dictionary = host._tile_controller.requests[0]
	assert_eq(int(request.get("query_start", -1)), 150)
	assert_eq(int(request.get("query_end", -1)), 180)
	assert_eq(str(request.get("request_kind", "")), "read_strip")


func test_stale_visible_error_is_ignored() -> void:
	controller._visible_pending_requests[2] = {"serial": 2, "query_start": 0, "query_end": 100}
	controller._latest_visible_serial = 3
	host._fetch_in_progress = true
	host._tile_controller.results.append({"serial": 2, "ok": false, "error": "old failure"})

	controller.drain_tile_fetch_result()

	assert_eq(host.status_messages.size(), 0, "Stale visible errors should not be shown.")
	assert_false(host._fetch_in_progress)


func test_current_visible_error_is_reported() -> void:
	controller._visible_pending_requests[3] = {"serial": 3, "query_start": 0, "query_end": 100}
	controller._latest_visible_serial = 3
	host._fetch_in_progress = true
	host._tile_controller.results.append({"serial": 3, "ok": false, "error": "current failure"})

	controller.drain_tile_fetch_result()

	assert_eq(host.status_messages.size(), 1)
	if host.status_messages.is_empty():
		return
	assert_eq(str(host.status_messages[0].get("message", "")), "current failure")
	assert_true(bool(host.status_messages[0].get("is_error", false)))
