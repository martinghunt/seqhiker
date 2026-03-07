extends Control
class_name GenomeView

signal viewport_changed(start_bp: int, end_bp: int, bp_per_px: float)
signal feature_clicked(feature: Dictionary)
signal read_clicked(read: Dictionary)
signal track_settings_requested(track_id: String)
signal track_order_changed(order: PackedStringArray)
signal track_visibility_changed(track_id: String, visible: bool)
signal region_selected(start_bp: int, end_bp: int)

const AA_ROW_H := 26.0
const AA_ROW_GAP := 3.0
const DEFAULT_PLOT_H := 100.0
const MIN_PLOT_H := 50.0
const MAX_PLOT_H := 360.0
const GENOME_H := 86.0
const TRACK_LEFT_PAD := 64.0
const TRACK_RIGHT_PAD := 28.0
const TOP_PAD := 16.0
const PANEL_GAP := 14.0
const BOTTOM_PAD := 12.0
const READ_ROW_H := 8.0
const READ_ROW_GAP := 4.0
const SNP_MARK_MAX_BP_PER_PX := 1.5
const NUC_TEXT_MAX_BASES := 3000
const FEATURE_MIN_DRAW_PX := 3.0
const FEATURE_DETAIL_MAX_BP_PER_PX := 1.25
const FEATURE_LABEL_MIN_CHARS := 10
const TRACK_ID_READS := "reads"
const TRACK_ID_AA := "aa"
const TRACK_ID_GC_PLOT := "gc_plot"
const TRACK_ID_DEPTH_PLOT := "depth_plot"
const TRACK_ID_GENOME := "genome"
const PLOT_Y_UNIT := 0
const PLOT_Y_AUTOSCALE := 1
const PLOT_Y_FIXED := 2
const READ_VIEW_STACK := 0
const READ_VIEW_STRAND := 1
const READ_VIEW_PAIRED := 2
const READ_VIEW_FRAGMENT := 3
const STRAND_SPLIT_LINE_WIDTH := 2.5
const READ_RENDER_MAX_BP_PER_PX := 128.0
const COMPLEMENT_MAP := {
	"A": "T",
	"T": "A",
	"U": "A",
	"C": "G",
	"G": "C",
	"R": "Y",
	"Y": "R",
	"S": "S",
	"W": "W",
	"K": "M",
	"M": "K",
	"B": "V",
	"V": "B",
	"D": "H",
	"H": "D",
	"N": "N"
}
const CODON_TO_AA := {
	"TTT": "F", "TTC": "F", "TTA": "L", "TTG": "L",
	"CTT": "L", "CTC": "L", "CTA": "L", "CTG": "L",
	"ATT": "I", "ATC": "I", "ATA": "I", "ATG": "M",
	"GTT": "V", "GTC": "V", "GTA": "V", "GTG": "V",
	"TCT": "S", "TCC": "S", "TCA": "S", "TCG": "S",
	"CCT": "P", "CCC": "P", "CCA": "P", "CCG": "P",
	"ACT": "T", "ACC": "T", "ACA": "T", "ACG": "T",
	"GCT": "A", "GCC": "A", "GCA": "A", "GCG": "A",
	"TAT": "Y", "TAC": "Y", "TAA": "*", "TAG": "*",
	"CAT": "H", "CAC": "H", "CAA": "Q", "CAG": "Q",
	"AAT": "N", "AAC": "N", "AAA": "K", "AAG": "K",
	"GAT": "D", "GAC": "D", "GAA": "E", "GAG": "E",
	"TGT": "C", "TGC": "C", "TGA": "*", "TGG": "W",
	"CGT": "R", "CGC": "R", "CGA": "R", "CGG": "R",
	"AGT": "S", "AGC": "S", "AGA": "R", "AGG": "R",
	"GGT": "G", "GGC": "G", "GGA": "G", "GGG": "G"
}

var chromosome_length := 50000
var view_start_bp := 0.0
var bp_per_px := 8.0
var min_bp_per_px := 0.02
var max_bp_per_px := 10000.0

var reads: Array[Dictionary] = []
var coverage_tiles: Array[Dictionary] = []
var gc_plot_tiles: Array[Dictionary] = []
var depth_plot_tiles: Array[Dictionary] = []
var features: Array[Dictionary] = []
var loaded_files: PackedStringArray = PackedStringArray()
var reference_start_bp := 0
var reference_sequence := ""
var concat_segments: Array[Dictionary] = []

var palette: Dictionary = {
	"bg": Color("f7efe4"),
	"panel": Color("fff7eb"),
	"grid": Color("d4c6b4"),
	"text": Color("2b2520"),
	"aa_alt_bg": Color("ececec"),
	"genome": Color("3f5a7a"),
	"read": Color("0f8b8d"),
	"gc_plot": Color("2aa198"),
	"depth_plot": Color("345995"),
	"snp": Color("d7263d"),
	"snp_text": Color("ffffff"),
	"aa_forward": Color("8a4fff"),
	"aa_reverse": Color("f39237"),
	"feature": Color("c53211")
}

var _pan_tween: Tween
var _zoom_tween: Tween
var _zoom_from_bp_per_px := 8.0
var _zoom_to_bp_per_px := 8.0
var _zoom_from_start_bp := 0.0
var _zoom_to_start_bp := 0.0
var _feature_hitboxes: Array[Dictionary] = []
var _read_hitboxes: Array[Dictionary] = []
var _trackpad_pan_sensitivity := 1.0
var _trackpad_pinch_sensitivity := 1.0
var _reads_scrollbar: VScrollBar
var _laid_out_reads: Array[Dictionary] = []
var _read_row_count := 0
var _strand_forward_rows := 0
var _strand_reverse_rows := 0
var _strand_split_lock_y := -1.0
var _read_view_mode := READ_VIEW_STACK
var _fragment_log_scale := false
var _read_row_h := READ_ROW_H
var _annotation_max_on_screen := 4400
var _show_full_length_regions := false
var _colorize_nucleotides := true
var _gc_plot_y_mode := PLOT_Y_UNIT
var _gc_plot_y_min := 0.0
var _gc_plot_y_max := 1.0
var _depth_plot_y_mode := PLOT_Y_UNIT
var _depth_plot_y_min := 0.0
var _depth_plot_y_max := 1.0
var _gc_plot_h := DEFAULT_PLOT_H
var _depth_plot_h := DEFAULT_PLOT_H
var _track_order: PackedStringArray = PackedStringArray([TRACK_ID_READS, TRACK_ID_DEPTH_PLOT, TRACK_ID_GC_PLOT, TRACK_ID_AA, TRACK_ID_GENOME])
var _track_visible := {
	TRACK_ID_READS: false,
	TRACK_ID_AA: true,
	TRACK_ID_GC_PLOT: false,
	TRACK_ID_DEPTH_PLOT: false,
	TRACK_ID_GENOME: true
}
var _track_close_hitboxes: Array[Dictionary] = []
var _track_grab_hitboxes: Array[Dictionary] = []
var _track_settings_hitboxes: Array[Dictionary] = []
var _track_drag_active := false
var _track_drag_track_id := ""
var _track_drag_target_index := -1
var _region_select_dragging := false
var _region_select_has_selection := false
var _region_select_start_edge := 0
var _region_select_end_edge := 0
var _annotation_debug_stats := {
	"seen": 0,
	"drawn": 0,
	"labels": 0,
	"hitboxes": 0,
	"draw_ms": 0.0
}

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2.ZERO
	_reads_scrollbar = VScrollBar.new()
	_reads_scrollbar.visible = false
	_reads_scrollbar.step = 1.0
	_reads_scrollbar.value_changed.connect(_on_reads_scroll_changed)
	add_child(_reads_scrollbar)
	_layout_read_scrollbar()
	_emit_viewport_changed()

func set_chromosome(_chr_name: String, length_bp: int) -> void:
	chromosome_length = max(length_bp, 1)
	view_start_bp = 0.0
	reference_start_bp = 0
	reference_sequence = ""
	_strand_split_lock_y = -1.0
	queue_redraw()
	_emit_viewport_changed()

func set_reads(next_reads: Array[Dictionary]) -> void:
	reads.clear()
	for read_any in next_reads:
		var read: Dictionary = (read_any as Dictionary).duplicate(true)
		_attach_indel_markers(read)
		reads.append(read)
	_layout_reads()
	_layout_read_scrollbar()
	queue_redraw()

func set_coverage_tiles(next_tiles: Array[Dictionary]) -> void:
	coverage_tiles = next_tiles
	queue_redraw()

func set_gc_plot_tiles(next_tiles: Array[Dictionary]) -> void:
	gc_plot_tiles = next_tiles
	queue_redraw()

func set_depth_plot_tiles(next_tiles: Array[Dictionary]) -> void:
	depth_plot_tiles = next_tiles
	queue_redraw()

func set_features(next_features: Array[Dictionary]) -> void:
	features = next_features
	queue_redraw()

func set_reference_slice(start_bp: int, sequence: String) -> void:
	reference_start_bp = start_bp
	reference_sequence = sequence
	queue_redraw()

func needs_reference_data(show_aa_track: bool, show_genome_track: bool) -> bool:
	if show_genome_track and _can_draw_nucleotide_letters():
		return true
	if show_aa_track and _can_draw_aa_letters_without_reference():
		return true
	return false

func set_concat_segments(segments: Array) -> void:
	concat_segments.clear()
	for seg in segments:
		if typeof(seg) == TYPE_DICTIONARY:
			concat_segments.append(seg)
	queue_redraw()

func clear_all_data() -> void:
	reads.clear()
	_laid_out_reads.clear()
	_read_row_count = 0
	_strand_split_lock_y = -1.0
	coverage_tiles.clear()
	gc_plot_tiles.clear()
	depth_plot_tiles.clear()
	features.clear()
	concat_segments.clear()
	loaded_files = PackedStringArray()
	reference_start_bp = 0
	reference_sequence = ""
	view_start_bp = 0.0
	queue_redraw()
	_emit_viewport_changed()

func set_palette(next_palette: Dictionary) -> void:
	palette = next_palette
	queue_redraw()

func set_trackpad_pan_sensitivity(value: float) -> void:
	_trackpad_pan_sensitivity = clampf(value, 0.5, 20.0)

func set_trackpad_pinch_sensitivity(value: float) -> void:
	_trackpad_pinch_sensitivity = clampf(value, 0.5, 20.0)

func set_read_view_mode(mode: int) -> void:
	_read_view_mode = clampi(mode, READ_VIEW_STACK, READ_VIEW_FRAGMENT)
	_strand_split_lock_y = -1.0
	if _reads_scrollbar != null:
		_reads_scrollbar.value = 0.0
	_layout_reads()
	_layout_read_scrollbar()
	if _read_view_mode == READ_VIEW_STRAND and _reads_scrollbar != null and _reads_scrollbar.visible:
		_reads_scrollbar.value = _reads_scrollbar.max_value * 0.5
	queue_redraw()

func set_fragment_log_scale(enabled: bool) -> void:
	_fragment_log_scale = enabled
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_layout_reads()
		_layout_read_scrollbar()
		queue_redraw()

func set_read_thickness(value: float) -> void:
	_read_row_h = clampf(value, 2.0, 24.0)
	_layout_reads()
	_layout_read_scrollbar()
	queue_redraw()

func set_show_full_length_regions(enabled: bool) -> void:
	_show_full_length_regions = enabled
	queue_redraw()

func set_annotation_max_on_screen(max_count: int) -> void:
	_annotation_max_on_screen = clampi(max_count, 200, 50000)
	queue_redraw()

func set_colorize_nucleotides(enabled: bool) -> void:
	_colorize_nucleotides = enabled
	queue_redraw()

func set_gc_plot_y_scale(mode: int, min_v: float, max_v: float) -> void:
	_gc_plot_y_mode = clampi(mode, PLOT_Y_UNIT, PLOT_Y_FIXED)
	_gc_plot_y_min = min_v
	_gc_plot_y_max = max_v
	if _gc_plot_y_max <= _gc_plot_y_min:
		_gc_plot_y_max = _gc_plot_y_min + 1.0
	queue_redraw()

func set_depth_plot_y_scale(mode: int, min_v: float, max_v: float) -> void:
	_depth_plot_y_mode = clampi(mode, PLOT_Y_UNIT, PLOT_Y_FIXED)
	_depth_plot_y_min = min_v
	_depth_plot_y_max = max_v
	if _depth_plot_y_max <= _depth_plot_y_min:
		_depth_plot_y_max = _depth_plot_y_min + 1.0
	queue_redraw()

func set_gc_plot_height(height_px: float) -> void:
	_gc_plot_h = clampf(height_px, MIN_PLOT_H, MAX_PLOT_H)
	_layout_read_scrollbar()
	queue_redraw()

func set_depth_plot_height(height_px: float) -> void:
	_depth_plot_h = clampf(height_px, MIN_PLOT_H, MAX_PLOT_H)
	_layout_read_scrollbar()
	queue_redraw()

func center_strand_scroll() -> void:
	if _read_view_mode != READ_VIEW_STRAND or _reads_scrollbar == null:
		return
	var read_area := _track_rect(TRACK_ID_READS)
	var content_top := read_area.position.y + 30.0
	var content_bottom := read_area.position.y + read_area.size.y - 4.0
	_strand_split_lock_y = (content_top + content_bottom) * 0.5
	_layout_read_scrollbar()
	if _reads_scrollbar.visible:
		_reads_scrollbar.value = _reads_scrollbar.max_value * 0.5
	queue_redraw()

func get_track_order() -> PackedStringArray:
	return _track_order.duplicate()

func is_track_visible(track_id: String) -> bool:
	return bool(_track_visible.get(track_id, true))

func set_track_visible(track_id: String, show_track: bool) -> void:
	if not _track_visible.has(track_id):
		return
	var next_visible := show_track
	if bool(_track_visible.get(track_id, true)) == next_visible:
		return
	_track_visible[track_id] = next_visible
	if _track_drag_active and _track_drag_track_id == track_id and not next_visible:
		_track_drag_active = false
		_track_drag_track_id = ""
		_track_drag_target_index = -1
	_layout_read_scrollbar()
	queue_redraw()
	emit_signal("track_visibility_changed", track_id, next_visible)

func set_track_order(order: PackedStringArray) -> void:
	var prev := _track_order
	var valid := PackedStringArray([TRACK_ID_READS, TRACK_ID_AA, TRACK_ID_GC_PLOT, TRACK_ID_DEPTH_PLOT, TRACK_ID_GENOME])
	var seen: Dictionary = {}
	var next := PackedStringArray()
	for id_any in order:
		var id := str(id_any)
		if not valid.has(id):
			continue
		if seen.get(id, false):
			continue
		seen[id] = true
		next.append(id)
	for id in valid:
		if not seen.get(id, false):
			next.append(id)
	_track_order = next
	_layout_read_scrollbar()
	queue_redraw()
	if prev != _track_order:
		emit_signal("track_order_changed", _track_order.duplicate())

func is_zoom_animating() -> bool:
	return _zoom_tween != null and _zoom_tween.is_running()

func pan_by_fraction(fraction: float, duration: float = 0.35) -> void:
	var plot_w := _plot_width()
	if plot_w <= 0:
		return
	var span := plot_w * bp_per_px
	var target := _clamp_start(view_start_bp + span * fraction)
	_pan_to(target, duration)

func zoom_by(factor: float, duration: float = 0.22) -> void:
	zoom_by_at_x(factor, TRACK_LEFT_PAD + _plot_width() * 0.5, duration)

func zoom_by_at_x(factor: float, anchor_x: float, duration: float = 0.22) -> void:
	var plot_w := _plot_width()
	if factor <= 0.0 || plot_w <= 0:
		return
	var old: float = bp_per_px
	var next: float = clampf(old * factor, min_bp_per_px, max_bp_per_px)
	if is_equal_approx(next, old):
		return
	var anchor_px := clampf(anchor_x - TRACK_LEFT_PAD, 0.0, plot_w)
	var anchor_bp: float = view_start_bp + old * anchor_px
	var target_start: float = _clamp_start(anchor_bp - next * anchor_px)
	_animate_zoom(view_start_bp, target_start, old, next, duration)

func load_files(paths: PackedStringArray) -> void:
	for p in paths:
		if not loaded_files.has(p):
			loaded_files.append(p)
	queue_redraw()

func _pan_to(target_start: float, duration: float) -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_CUBIC)
	_pan_tween.set_ease(Tween.EASE_OUT)
	_pan_tween.tween_method(_set_view_start_animated, view_start_bp, target_start, duration)

func _set_view_start_animated(next_start: float) -> void:
	view_start_bp = _clamp_start(next_start)
	queue_redraw()
	_emit_viewport_changed()

func _animate_zoom(from_start: float, to_start: float, from_bp_per_px: float, to_bp_per_px: float, duration: float) -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_zoom_from_start_bp = from_start
	_zoom_to_start_bp = to_start
	_zoom_from_bp_per_px = from_bp_per_px
	_zoom_to_bp_per_px = to_bp_per_px
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_set_zoom_progress, 0.0, 1.0, duration)
	_zoom_tween.finished.connect(_on_zoom_finished, CONNECT_ONE_SHOT)

func _set_zoom_progress(t: float) -> void:
	bp_per_px = lerpf(_zoom_from_bp_per_px, _zoom_to_bp_per_px, t)
	view_start_bp = _clamp_start(lerpf(_zoom_from_start_bp, _zoom_to_start_bp, t))
	queue_redraw()
	_emit_viewport_changed()

func _on_zoom_finished() -> void:
	_emit_viewport_changed()

func _clamp_start(next_start: float) -> float:
	var plot_w := _plot_width()
	if plot_w <= 0:
		return maxf(0.0, next_start)
	var max_start := maxf(0.0, float(chromosome_length) - plot_w * bp_per_px)
	return clampf(next_start, 0.0, max_start)

func _emit_viewport_changed() -> void:
	var end_bp := int(minf(float(chromosome_length), view_start_bp + _plot_width() * bp_per_px))
	emit_signal("viewport_changed", int(view_start_bp), end_bp, bp_per_px)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		view_start_bp = _clamp_start(view_start_bp)
		_layout_read_scrollbar()
		queue_redraw()
		_emit_viewport_changed()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["panel"], true)
	_track_close_hitboxes.clear()
	_track_grab_hitboxes.clear()
	_track_settings_hitboxes.clear()
	_read_hitboxes.clear()
	_feature_hitboxes.clear()
	var track_rects := _track_layout_rects()
	for track_id in _track_order:
		if not track_rects.has(track_id):
			continue
		var area: Rect2 = track_rects[track_id]
		match track_id:
			TRACK_ID_READS:
				_draw_read_tracks(area)
			TRACK_ID_AA:
				_draw_aa_tracks(area)
			TRACK_ID_GC_PLOT:
				_draw_plot_track(area, gc_plot_tiles, _gc_plot_y_mode, _gc_plot_y_min, _gc_plot_y_max, palette.get("gc_plot", palette["read"]))
			TRACK_ID_DEPTH_PLOT:
				_draw_plot_track(area, depth_plot_tiles, _depth_plot_y_mode, _depth_plot_y_min, _depth_plot_y_max, palette.get("depth_plot", palette["read"]))
			TRACK_ID_GENOME:
				_draw_genome_track(area)
		_draw_track_header(track_id, area)
	_draw_region_selection(track_rects)
	if _track_drag_active and _track_drag_target_index >= 0 and _track_drag_target_index < _track_order.size():
		var target_id := _track_order[_track_drag_target_index]
		if track_rects.has(target_id):
			var target_rect: Rect2 = track_rects[target_id]
			var y := target_rect.position.y - 2.0
			draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), Color(0.05, 0.05, 0.05, 0.9), 2.0)
	_draw_file_status()

func _draw_region_selection(track_rects: Dictionary) -> void:
	if not _region_select_has_selection and not _region_select_dragging:
		return
	var view_rect := _tracks_view_rect(track_rects)
	if view_rect.size.y <= 0.0:
		return
	var bp0 := mini(_region_select_start_edge, _region_select_end_edge)
	var bp1 := maxi(_region_select_start_edge, _region_select_end_edge)
	var x0 := clampf(_bp_to_screen_edge(bp0), TRACK_LEFT_PAD, size.x - TRACK_RIGHT_PAD)
	var x1 := clampf(_bp_to_screen_edge(bp1), TRACK_LEFT_PAD, size.x - TRACK_RIGHT_PAD)
	var w := maxf(1.0, x1 - x0)
	var rect := Rect2(x0, view_rect.position.y, w, view_rect.size.y)
	var fill: Color = palette.get("genome", Color(0.25, 0.45, 0.75))
	fill.a = 0.28
	draw_rect(rect, fill, true)
	var border: Color = palette["text"]
	border.a = 0.55
	draw_rect(rect, border, false, 1.0)

func _draw_track_header(track_id: String, area: Rect2) -> void:
	var gx := 4.0
	var gy := area.position.y + 4.0
	var close_rect := Rect2(gx, gy, 14.0, 14.0)
	var grab_rect := Rect2(gx, gy + 18.0, 14.0, 14.0)
	var settings_rect := Rect2(gx, gy + 36.0, 14.0, 14.0)
	draw_rect(close_rect, Color(1, 1, 1, 0.35), true)
	draw_rect(close_rect, palette["grid"], false, 1.0)
	draw_line(close_rect.position + Vector2(3.0, 3.0), close_rect.position + Vector2(close_rect.size.x - 3.0, close_rect.size.y - 3.0), palette["text"], 1.0)
	draw_line(close_rect.position + Vector2(close_rect.size.x - 3.0, 3.0), close_rect.position + Vector2(3.0, close_rect.size.y - 3.0), palette["text"], 1.0)
	draw_rect(grab_rect, Color(1, 1, 1, 0.35), true)
	draw_rect(grab_rect, palette["grid"], false, 1.0)
	for i in range(3):
		var ly := grab_rect.position.y + 4.0 + i * 4.0
		draw_line(Vector2(grab_rect.position.x + 3.0, ly), Vector2(grab_rect.position.x + grab_rect.size.x - 3.0, ly), palette["text"], 1.0)
	draw_rect(settings_rect, Color(1, 1, 1, 0.35), true)
	draw_rect(settings_rect, palette["grid"], false, 1.0)
	draw_string(get_theme_default_font(), Vector2(settings_rect.position.x + 3.0, settings_rect.position.y + 11.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, palette["text"])
	_track_close_hitboxes.append({"rect": close_rect, "track_id": track_id})
	_track_grab_hitboxes.append({"rect": grab_rect, "track_id": track_id})
	_track_settings_hitboxes.append({"rect": settings_rect, "track_id": track_id})

func _track_label_for_id(track_id: String) -> String:
	match track_id:
		TRACK_ID_READS:
			return "Reads"
		TRACK_ID_AA:
			return "AA / Annotation"
		TRACK_ID_GC_PLOT:
			return "GC Plot"
		TRACK_ID_DEPTH_PLOT:
			return "Depth Plot"
		TRACK_ID_GENOME:
			return "Genome"
		_:
			return track_id

func _track_index_for_y(y: float) -> int:
	var rects := _track_layout_rects()
	for i in range(_track_order.size()):
		var track_id := _track_order[i]
		if not rects.has(track_id):
			continue
		var r: Rect2 = rects[track_id]
		if y < r.position.y + r.size.y * 0.5:
			return i
	return max(0, _track_order.size() - 1)

func _draw_read_tracks(area: Rect2) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	var depth_only := bp_per_px > READ_RENDER_MAX_BP_PER_PX
	_draw_coverage_tiles(area, depth_only)
	if depth_only:
		return

	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var scroll_sign := -1.0 if _read_view_mode == READ_VIEW_STRAND else 1.0
	var scroll_px := scroll_sign * _reads_scrollbar.value * (_read_row_h + READ_ROW_GAP)
	var strand_split_y := 0.0
	if _read_view_mode == READ_VIEW_STRAND:
		var step_px := _read_row_h + READ_ROW_GAP
		var split_gap := _strand_split_gap_px()
		var forward_extent := 0.0
		var reverse_extent := 0.0
		if _strand_forward_rows > 0:
			forward_extent = _read_row_h + float(_strand_forward_rows - 1) * step_px + split_gap * 0.5
		if _strand_reverse_rows > 0:
			reverse_extent = _read_row_h + float(_strand_reverse_rows - 1) * step_px + split_gap * 0.5
		var split_at_forward_top := content_top + forward_extent
		var split_at_reverse_bottom := content_bottom - reverse_extent
		if split_at_forward_top <= split_at_reverse_bottom:
			strand_split_y = (split_at_forward_top + split_at_reverse_bottom) * 0.5
		else:
			var range_px := split_at_forward_top - split_at_reverse_bottom
			var off_px := clampf(_reads_scrollbar.value, 0.0, range_px)
			strand_split_y = split_at_forward_top - off_px
		_strand_split_lock_y = strand_split_y
		draw_line(Vector2(0.0, strand_split_y), Vector2(size.x, strand_split_y), Color(0, 0, 0, 0.9), STRAND_SPLIT_LINE_WIDTH)
	var drawn_pairs: Dictionary = {}
	var draw_snp_text := _can_draw_read_snp_letters()
	var snp_font := get_theme_default_font()
	var snp_font_size := clampi(int(floor(_read_row_h - 1.0)), 8, 14)
	for read in _laid_out_reads:
		var read_start: int = read["start"]
		var read_end: int = read["end"]
		if read_end < int(view_start_bp) || read_start > int(_viewport_end_bp()):
			continue
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			var pair_key := _pair_render_key(read)
			if not pair_key.is_empty():
				if drawn_pairs.has(pair_key):
					continue
				drawn_pairs[pair_key] = true
		var y := _read_y_for_area(read, content_top, content_bottom, scroll_px, strand_split_y)
		if y + _read_row_h < content_top or y > area.position.y + area.size.y - 4.0:
			continue
		var x0 := TRACK_LEFT_PAD + _bp_to_x(read_start)
		var x1 := TRACK_LEFT_PAD + _bp_to_x(read_end)
		var rect := Rect2(Vector2(x0, y), Vector2(maxf(2.0, x1 - x0), _read_row_h))
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			_draw_pair_connector(read, y)
			_draw_mate_block(read, y)
		draw_rect(rect, palette["read"], true)
		_read_hitboxes.append({
			"rect": rect,
			"read": read
		})
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			var mate_rect := _mate_rect_for_read(read, y)
			if mate_rect.size.x > 0.0 and mate_rect.size.y > 0.0:
				_read_hitboxes.append({
					"rect": mate_rect,
					"read": read
				})
		if bp_per_px <= SNP_MARK_MAX_BP_PER_PX:
			var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
			var snp_bases: PackedByteArray = read.get("snp_bases", PackedByteArray())
			for i in range(snps.size()):
				var snp_bp := int(snps[i])
				if snp_bp < int(view_start_bp) or snp_bp > int(_viewport_end_bp()):
					continue
				var sx := _bp_to_screen_center(float(snp_bp))
				if sx < TRACK_LEFT_PAD or sx > size.x - TRACK_RIGHT_PAD:
					continue
				var snp_w := maxf(1.0, 1.0 / bp_per_px)
				var base_text := ""
				if draw_snp_text and i < snp_bases.size():
					var b := char(int(snp_bases[i]))
					base_text = "N" if b.is_empty() else b
					var base_w := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x + 2.0
					snp_w = maxf(snp_w, base_w)
				draw_rect(Rect2(sx - snp_w * 0.5, y, snp_w, _read_row_h), palette.get("snp", Color(0.86, 0.14, 0.14)), true)
				if draw_snp_text and not base_text.is_empty():
					var tw := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x
					var tx := sx - tw * 0.5
					var ty := y + (_read_row_h + float(snp_font_size)) * 0.5 - 1.0
					draw_string(snp_font, Vector2(tx, ty), base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size, palette.get("snp_text", Color.WHITE))
			_draw_indel_markers(read, y)

func _read_y_for_area(read: Dictionary, content_top: float, content_bottom: float, scroll_px: float, strand_split_y: float) -> float:
	if _read_view_mode == READ_VIEW_FRAGMENT:
		var norm := clampf(float(read.get("frag_norm", 0.0)), 0.0, 1.0)
		var span := maxf(1.0, content_bottom - content_top - _read_row_h)
		return content_bottom - _read_row_h - norm * span
	var row: int = int(read.get("row", 0))
	if _read_view_mode == READ_VIEW_STRAND:
		var split_gap := _strand_split_gap_px()
		if bool(read.get("reverse", false)):
			return strand_split_y + split_gap * 0.5 + row * (_read_row_h + READ_ROW_GAP)
		return strand_split_y - split_gap * 0.5 - _read_row_h - row * (_read_row_h + READ_ROW_GAP)
	return content_bottom - _read_row_h - row * (_read_row_h + READ_ROW_GAP) + scroll_px

func _draw_pair_connector(read: Dictionary, y: float) -> void:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return
	var read_center := float(read.get("start", 0) + read.get("end", 0)) * 0.5
	var mate_center := float(mate_start + mate_end) * 0.5
	var x0 := TRACK_LEFT_PAD + _bp_to_x(read_center)
	var x1 := TRACK_LEFT_PAD + _bp_to_x(mate_center)
	var yc := y + _read_row_h * 0.5
	draw_line(Vector2(x0, yc), Vector2(x1, yc), Color(0.24, 0.24, 0.24, 0.9), 1.0)

func _can_draw_read_snp_letters() -> bool:
	if _read_row_h < 10.0:
		return false
	var font := get_theme_default_font()
	var font_size := clampi(int(floor(_read_row_h - 1.0)), 8, 14)
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	return pixels_per_bp >= char_px + 1.0

func _draw_indel_markers(read: Dictionary, y: float) -> void:
	var mid_y := y + _read_row_h * 0.5
	var half_h := maxf(1.0, _read_row_h * 0.5)
	var trim_h := maxf(0.0, (_read_row_h - half_h) * 0.5)
	var del_starts: PackedInt32Array = read.get("del_starts", PackedInt32Array())
	var del_ends: PackedInt32Array = read.get("del_ends", PackedInt32Array())
	var del_count := mini(del_starts.size(), del_ends.size())
	for i in range(del_count):
		var ds := int(del_starts[i])
		var de := int(del_ends[i])
		if de <= ds:
			continue
		if de < int(view_start_bp) or ds > int(_viewport_end_bp()):
			continue
		var dx0 := TRACK_LEFT_PAD + _bp_to_x(float(ds))
		var dx1 := TRACK_LEFT_PAD + _bp_to_x(float(de))
		# Thin the read body around deletions so the deletion marker is easier to see.
		if trim_h > 0.0 and dx1 > dx0:
			draw_rect(Rect2(dx0, y, dx1 - dx0, trim_h), palette["bg"], true)
			draw_rect(Rect2(dx0, y + _read_row_h - trim_h, dx1 - dx0, trim_h), palette["bg"], true)
		draw_line(Vector2(dx0, mid_y), Vector2(dx1, mid_y), Color(0.08, 0.08, 0.08, 0.95), 1.0)
	var ins_positions: PackedInt32Array = read.get("ins_positions", PackedInt32Array())
	for pos in ins_positions:
		var ip := int(pos)
		if ip < int(view_start_bp) or ip > int(_viewport_end_bp()):
			continue
		var ix := TRACK_LEFT_PAD + _bp_to_x(float(ip))
		var y0 := y + 1.0
		var y1 := y + _read_row_h - 1.0
		var cap_w := maxf(4.0, _read_row_h * 0.7)
		var cap_line_w := maxf(1.0, _read_row_h * 0.15)
		var stem_line_w := maxf(1.0, _read_row_h * 0.3)
		var col := Color(0.05, 0.05, 0.05, 0.98)
		draw_line(Vector2(ix, y0), Vector2(ix, y1), col, stem_line_w)
		draw_line(Vector2(ix - cap_w * 0.5, y0), Vector2(ix + cap_w * 0.5, y0), col, cap_line_w)
		draw_line(Vector2(ix - cap_w * 0.5, y1), Vector2(ix + cap_w * 0.5, y1), col, cap_line_w)

func _attach_indel_markers(read: Dictionary) -> void:
	var cigar := str(read.get("cigar", ""))
	if cigar.is_empty():
		return
	var ref_pos := int(read.get("start", 0))
	var num := 0
	var del_starts := PackedInt32Array()
	var del_ends := PackedInt32Array()
	var ins_positions := PackedInt32Array()
	for i in range(cigar.length()):
		var ch := cigar.substr(i, 1)
		if ch >= "0" and ch <= "9":
			num = num * 10 + int(ch.to_int())
			continue
		var ln := num
		num = 0
		if ln <= 0:
			continue
		match ch:
			"M", "=", "X":
				ref_pos += ln
			"D", "N":
				del_starts.append(ref_pos)
				del_ends.append(ref_pos + ln)
				ref_pos += ln
			"I":
				ins_positions.append(ref_pos)
			"S", "H", "P":
				pass
			_:
				pass
	read["del_starts"] = del_starts
	read["del_ends"] = del_ends
	read["ins_positions"] = ins_positions

func _draw_mate_block(read: Dictionary, y: float) -> void:
	var mate_rect := _mate_rect_for_read(read, y)
	if mate_rect.size.x <= 0.0 or mate_rect.size.y <= 0.0:
		return
	var mate_color: Color = palette["read"]
	draw_rect(mate_rect, mate_color, true)

func _mate_rect_for_read(read: Dictionary, y: float) -> Rect2:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return Rect2()
	if mate_end < int(view_start_bp) or mate_start > int(_viewport_end_bp()):
		return Rect2()
	var mx0 := TRACK_LEFT_PAD + _bp_to_x(mate_start)
	var mx1 := TRACK_LEFT_PAD + _bp_to_x(mate_end)
	return Rect2(Vector2(mx0, y), Vector2(maxf(2.0, mx1 - mx0), _read_row_h))

func _pair_render_key(read: Dictionary) -> String:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return ""
	var a0 := int(read.get("start", 0))
	var a1 := int(read.get("end", a0 + 1))
	var b0 := mate_start
	var b1 := mate_end
	if b0 < a0 or (b0 == a0 and b1 < a1):
		var t0 := a0
		var t1 := a1
		a0 = b0
		a1 = b1
		b0 = t0
		b1 = t1
	return "%s|%d|%d|%d|%d" % [str(read.get("name", "")), a0, a1, b0, b1]

func _draw_coverage_tiles(area: Rect2, show_y_ticks: bool = false) -> void:
	if coverage_tiles.is_empty():
		return

	var visible_start := int(view_start_bp)
	var visible_end := int(_viewport_end_bp())
	var vis_tiles_raw: Array[Dictionary] = []
	for tile in coverage_tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		if bins.is_empty():
			continue
		vis_tiles_raw.append(tile)
	if vis_tiles_raw.is_empty():
		return
	var span_counts := {}
	for tile in vis_tiles_raw:
		var span := maxi(1, int(tile.get("end", 0)) - int(tile.get("start", 0)))
		span_counts[span] = int(span_counts.get(span, 0)) + 1
	var dominant_span := 0
	var dominant_count := -1
	for k_any in span_counts.keys():
		var k := int(k_any)
		var c := int(span_counts[k])
		if c > dominant_count:
			dominant_count = c
			dominant_span = k
	var dominant_tiles: Array[Dictionary] = []
	var fallback_tiles: Array[Dictionary] = []
	for tile in vis_tiles_raw:
		var t_start := int(tile.get("start", 0))
		var t_end := int(tile.get("end", 0))
		var span := maxi(1, t_end - t_start)
		if span == dominant_span:
			dominant_tiles.append(tile)
		else:
			fallback_tiles.append(tile)
	dominant_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	fallback_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := absi(int(a.get("end", 0)) - int(a.get("start", 0)) - dominant_span)
		var sb := absi(int(b.get("end", 0)) - int(b.get("start", 0)) - dominant_span)
		if sa == sb:
			return int(a.get("start", 0)) < int(b.get("start", 0))
		return sa < sb
	)
	var coverage_intervals: Array[Dictionary] = []
	for tile in dominant_tiles:
		var s := maxi(visible_start, int(tile.get("start", 0)))
		var e := mini(visible_end, int(tile.get("end", 0)))
		if e <= s:
			continue
		coverage_intervals.append({"start": s, "end": e})
	coverage_intervals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	var merged: Array[Dictionary] = []
	for iv in coverage_intervals:
		if merged.is_empty():
			merged.append(iv)
			continue
		var last := merged[merged.size() - 1]
		var ls := int(last.get("start", 0))
		var le := int(last.get("end", ls))
		var s := int(iv.get("start", 0))
		var e := int(iv.get("end", s))
		if s <= le:
			last["end"] = maxi(le, e)
			merged[merged.size() - 1] = last
		else:
			merged.append(iv)
	var vis_tiles: Array[Dictionary] = dominant_tiles.duplicate()
	for tile in fallback_tiles:
		var s := maxi(visible_start, int(tile.get("start", 0)))
		var e := mini(visible_end, int(tile.get("end", 0)))
		if e <= s:
			continue
		var covered := 0
		for iv in merged:
			var is0 := int(iv.get("start", 0))
			var ie0 := int(iv.get("end", is0))
			var os := maxi(s, is0)
			var oe := mini(e, ie0)
			if oe > os:
				covered += oe - os
		if covered < (e - s):
			vis_tiles.append(tile)
	var seen_keys := {}
	var unique_tiles: Array[Dictionary] = []
	for tile in vis_tiles:
		var key := "%d|%d" % [int(tile.get("start", 0)), int(tile.get("end", 0))]
		if seen_keys.get(key, false):
			continue
		seen_keys[key] = true
		unique_tiles.append(tile)
	unique_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	var max_depth := 0
	for tile in unique_tiles:
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		for d in bins:
			if d > max_depth:
				max_depth = d
	if max_depth <= 0:
		return

	var cov_color: Color = palette["read"]
	cov_color.a = 0.45
	var chart_top := area.position.y + 30.0
	var chart_bottom := area.position.y + area.size.y - 10.0
	var chart_height := maxf(1.0, chart_bottom - chart_top)
	if show_y_ticks:
		var axis_col: Color = palette["grid"]
		var text_col: Color = _axis_text_color()
		var font := get_theme_default_font()
		var font_size := 11
		var tick_x := TRACK_LEFT_PAD - 8.0
		var label_x := 8.0
		draw_line(Vector2(tick_x, chart_top), Vector2(tick_x, chart_bottom), axis_col, 1.0)
		var tick_vals: Array[int] = [0, int(round(float(max_depth) * 0.5)), max_depth]
		var tick_ys: Array[float] = [chart_bottom, (chart_top + chart_bottom) * 0.5, chart_top]
		for i in range(3):
			var ty: float = tick_ys[i]
			draw_line(Vector2(tick_x, ty), Vector2(tick_x + 5.0, ty), axis_col, 1.0)
			var label := str(tick_vals[i])
			draw_string(font, Vector2(label_x, ty + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

	for tile in unique_tiles:
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
		for i in range(bins.size()):
			var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
			var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
			if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
				continue
			var x0 := TRACK_LEFT_PAD + _bp_to_x(float(bin_start_bp))
			var x1 := TRACK_LEFT_PAD + _bp_to_x(float(bin_end_bp))
			var w := maxf(1.0, x1 - x0)
			var h := chart_height * (float(bins[i]) / float(max_depth))
			if h <= 0.0:
				continue
			if not show_y_ticks:
				draw_rect(Rect2(x0, chart_bottom - h, w, h), cov_color, true)

	if show_y_ticks:
		var line_col: Color = palette["read"]
		line_col.a = 0.9
		var prev := Vector2.ZERO
		var have_prev := false
		var prev_end_bp := -1
		for tile in unique_tiles:
			var tile_start := int(tile.get("start", 0))
			var tile_end := int(tile.get("end", 0))
			var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
			var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
			for i in range(bins.size()):
				var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
				var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
				if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
					continue
				var cx_bp := 0.5 * float(bin_start_bp + bin_end_bp)
				var x := TRACK_LEFT_PAD + _bp_to_x(cx_bp)
				var norm := float(bins[i]) / float(max_depth)
				var y := chart_bottom - clampf(norm, 0.0, 1.0) * chart_height
				var p := Vector2(x, y)
				var contiguous := have_prev and bin_start_bp <= prev_end_bp + maxi(1, int(ceil(bin_span * 1.25)))
				var monotonic := not have_prev or p.x >= prev.x
				if have_prev and contiguous and monotonic:
					draw_line(prev, p, line_col, 1.5)
				elif have_prev:
					have_prev = false
				prev = p
				have_prev = true
				prev_end_bp = bin_end_bp

func _draw_plot_track(area: Rect2, tiles: Array[Dictionary], y_mode: int, y_min_fixed: float, y_max_fixed: float, line_color: Color) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	if tiles.is_empty():
		return
	var visible_start := int(view_start_bp)
	var visible_end := int(_viewport_end_bp())
	var top := area.position.y + 10.0
	var bottom := area.position.y + area.size.y - 8.0
	var h := maxf(1.0, bottom - top)
	var y_min := 0.0
	var y_max := 1.0
	if y_mode == PLOT_Y_FIXED:
		y_min = y_min_fixed
		y_max = y_max_fixed
	elif y_mode == PLOT_Y_AUTOSCALE:
		var found := false
		var auto_min := 0.0
		var auto_max := 0.0
		for tile in tiles:
			if typeof(tile) != TYPE_DICTIONARY:
				continue
			var tile_start := int(tile.get("start", 0))
			var tile_end := int(tile.get("end", 0))
			if tile_end <= visible_start or tile_start >= visible_end:
				continue
			var vals_auto: PackedFloat32Array = tile.get("values", PackedFloat32Array())
			for v_raw in vals_auto:
				var v := float(v_raw)
				if v < 0.0 or is_nan(v):
					continue
				if not found:
					auto_min = v
					auto_max = v
					found = true
				else:
					auto_min = minf(auto_min, v)
					auto_max = maxf(auto_max, v)
		if found:
			if is_equal_approx(auto_min, auto_max):
				auto_min -= 0.05
				auto_max += 0.05
			y_min = auto_min
			y_max = auto_max
	if y_max <= y_min:
		y_max = y_min + 1.0
	var y_span := y_max - y_min
	_draw_plot_scale(area, top, bottom, y_min, y_max)
	for tile in tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var vals: PackedFloat32Array = tile.get("values", PackedFloat32Array())
		if vals.is_empty():
			continue
		var prev := Vector2.ZERO
		var have_prev := false
		var count := vals.size()
		for i in range(count):
			var v := float(vals[i])
			if v < 0.0 or is_nan(v):
				have_prev = false
				continue
			var bp := float(tile_start) + (float(i) + 0.5) * float(tile_end - tile_start) / float(count)
			if bp < visible_start or bp > visible_end:
				continue
			var x := _bp_to_screen_center(bp)
			var norm := (v - y_min) / y_span
			var y := bottom - clampf(norm, 0.0, 1.0) * h
			var p := Vector2(x, y)
			if have_prev:
				draw_line(prev, p, line_color, 1.5)
			prev = p
			have_prev = true

func _draw_plot_scale(area: Rect2, top: float, bottom: float, y_min: float, y_max: float) -> void:
	var tick_x := TRACK_LEFT_PAD - 6.0
	var label_x := 8.0
	var text_col: Color = _axis_text_color()
	var font := get_theme_default_font()
	var font_size := 11
	var guide_col: Color = palette["grid"]
	guide_col.a *= 0.45
	draw_line(Vector2(TRACK_LEFT_PAD, top), Vector2(area.position.x + area.size.x - TRACK_RIGHT_PAD, top), guide_col, 1.0)
	draw_line(Vector2(TRACK_LEFT_PAD, bottom), Vector2(area.position.x + area.size.x - TRACK_RIGHT_PAD, bottom), guide_col, 1.0)
	draw_line(Vector2(tick_x, top), Vector2(tick_x + 5.0, top), palette["grid"], 1.0)
	draw_line(Vector2(tick_x, bottom), Vector2(tick_x + 5.0, bottom), palette["grid"], 1.0)
	var top_label := _format_plot_value(y_max)
	var bottom_label := _format_plot_value(y_min)
	draw_string(font, Vector2(label_x, top + 10.0), top_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
	draw_string(font, Vector2(label_x, bottom), bottom_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)

func _format_plot_value(v: float) -> String:
	if absf(v) >= 10.0:
		return "%.1f" % v
	if absf(v) >= 1.0:
		return "%.2f" % v
	return "%.3f" % v

func _draw_aa_tracks(area: Rect2) -> void:
	var t0 := Time.get_ticks_usec()
	var seen := 0
	var drawn := 0
	var labels := 0
	var culled_density := 0
	var area_start := area.position.y
	var show_aa_letters := _can_draw_aa_letters()
	var show_feature_detail := bp_per_px <= FEATURE_DETAIL_MAX_BP_PER_PX
	var max_ann := clampi(_annotation_max_on_screen, 200, 50000)
	var draw_cap := maxi(200, int(round(float(max_ann) * 0.5)))
	if bp_per_px >= 10.0:
		draw_cap = maxi(120, int(round(float(max_ann) * 0.18)))
	elif bp_per_px >= 5.0:
		draw_cap = maxi(220, int(round(float(max_ann) * 0.33)))
	elif bp_per_px >= 2.0:
		draw_cap = maxi(320, int(round(float(max_ann) * 0.64)))
	else:
		draw_cap = max_ann
	var use_density_bins := bp_per_px >= 2.0
	var density_bins := {}
	var frame_label_boxes: Array = []
	frame_label_boxes.resize(6)
	for i in range(6):
		frame_label_boxes[i] = []
	_feature_hitboxes.clear()
	for i in range(6):
		var y := area_start + i * (AA_ROW_H + AA_ROW_GAP)
		var track_rect := Rect2(0.0, y, area.size.x, AA_ROW_H)
		var bg_col: Color = palette["bg"]
		if i == 1 or i == 4:
			bg_col = palette.get("aa_alt_bg", bg_col)
		draw_rect(track_rect, bg_col, true)
		_draw_grid(track_rect)
	var split_y := area_start + 3.0 * (AA_ROW_H + AA_ROW_GAP) - AA_ROW_GAP * 0.5
	draw_line(Vector2(0.0, split_y), Vector2(size.x, split_y), Color(0.15, 0.15, 0.15, 0.45), 1.0)

	for feature in features:
		seen += 1
		if _is_hidden_full_length_region(feature):
			continue
		var frame := _feature_to_frame(feature)
		if frame < 0 || frame > 5:
			continue
		var f_start: int = feature["start"]
		var f_end: int = feature["end"]
		if f_end < int(view_start_bp) || f_start > int(_viewport_end_bp()):
			continue
		var fy := area_start + frame * (AA_ROW_H + AA_ROW_GAP) + 4.0
		var fx0 := TRACK_LEFT_PAD + _bp_to_x(f_start)
		var fx1 := TRACK_LEFT_PAD + _bp_to_x(f_end)
		var feature_w := fx1 - fx0
		if feature_w < FEATURE_MIN_DRAW_PX:
			continue
		if drawn >= draw_cap:
			culled_density += 1
			continue
		if use_density_bins:
			var bin_x := int(floor((fx0 - TRACK_LEFT_PAD) / 2.0))
			var dkey := "%d|%d" % [frame, bin_x]
			if density_bins.get(dkey, false):
				culled_density += 1
				continue
			density_bins[dkey] = true
		var rect := Rect2(Vector2(fx0, fy), Vector2(feature_w, AA_ROW_H - 8.0))
		var feature_col: Color = (palette["feature"] as Color).lerp(Color.WHITE, 0.45)
		feature_col.a = 0.4
		draw_rect(rect, feature_col, true)
		drawn += 1
		var click_rect := rect.grow(3.0) if show_feature_detail else rect
		_feature_hitboxes.append({
			"rect": click_rect,
			"feature": feature
		})
		if not show_aa_letters:
			var label_w := rect.size.x - 8.0
			var label := _feature_annotation_label(feature, label_w)
			if not label.is_empty():
				var font := get_theme_default_font()
				var font_size := 12
				var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var draw_w := minf(label_w, text_w)
				var label_rect := Rect2(Vector2(rect.position.x + 4.0, rect.position.y + 2.0), Vector2(draw_w, AA_ROW_H - 8.0))
				if not _intersects_any(label_rect, frame_label_boxes[frame]):
					draw_string(font, Vector2(rect.position.x + 4.0, rect.position.y + 14.0), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, font_size, _axis_text_color())
					frame_label_boxes[frame].append(label_rect)
					labels += 1

	if show_aa_letters:
		_draw_aa_translation_letters(area_start)
	_annotation_debug_stats = {
		"seen": seen,
		"drawn": drawn,
		"labels": labels,
		"hitboxes": _feature_hitboxes.size(),
		"culled_density": culled_density,
		"draw_ms": float(Time.get_ticks_usec() - t0) / 1000.0
	}

func annotation_debug_stats() -> Dictionary:
	return _annotation_debug_stats.duplicate()

func _can_draw_aa_letters() -> bool:
	if reference_sequence.is_empty():
		return false
	return _can_draw_aa_letters_without_reference()

func _can_draw_aa_letters_without_reference() -> bool:
	if _zoom_tween != null and _zoom_tween.is_running():
		return false
	var font := get_theme_default_font()
	var nuc_font_size := 14
	var nuc_char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, nuc_font_size).x
	if nuc_char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	var min_nuc_px := maxf(4.0, nuc_char_px * 0.45)
	if pixels_per_bp < min_nuc_px:
		return false
	var aa_font_size := 12
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x
	if aa_char_px <= 0.0:
		return false
	var min_aa_codon_px := maxf(4.0, aa_char_px * 0.55)
	return 3.0 * pixels_per_bp >= min_aa_codon_px

func _can_draw_nucleotide_letters() -> bool:
	var font := get_theme_default_font()
	var font_size := 14
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	return pixels_per_bp >= maxf(4.0, char_px * 0.45)

func _draw_aa_translation_letters(area_start: float) -> void:
	if not _can_draw_aa_letters():
		return
	var font := get_theme_default_font()
	var aa_font_size := 12
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x

	var seq_len := reference_sequence.length()
	if seq_len < 3:
		return
	var ref_start := reference_start_bp
	var ref_end := reference_start_bp + seq_len
	var vis_start := maxi(ref_start, int(floor(view_start_bp)))
	var vis_end := mini(ref_end, int(ceil(_viewport_end_bp())))
	if vis_end - vis_start < 3:
		return
	for frame in range(3):
		var first_bp := vis_start + posmod(frame - posmod(vis_start, 3), 3)
		var last_bp := vis_end - 3
		if last_bp < first_bp:
			continue
		var codon_count := int(floor(float(last_bp - first_bp) / 3.0)) + 1
		var max_by_pixels := maxi(1, int(floor(_plot_width() / maxf(1.0, aa_char_px + 1.0))) + 1)
		var sample_count := mini(codon_count, max_by_pixels)
		for n in range(sample_count):
			var codon_index := n
			if sample_count > 1 and codon_count > 1:
				codon_index = int(round(float(n) * float(codon_count - 1) / float(sample_count - 1)))
			var bp := first_bp + codon_index * 3
			var i0 := bp - ref_start
			var i1 := i0 + 1
			var i2 := i0 + 2
			if i0 < 0 or i2 >= seq_len:
				continue
			var b0 := reference_sequence.substr(i0, 1).to_upper()
			var b1 := reference_sequence.substr(i1, 1).to_upper()
			var b2 := reference_sequence.substr(i2, 1).to_upper()
			if b0 == " " or b1 == " " or b2 == " ":
				continue

			var codon := b0 + b1 + b2
			var aa_fwd := _translate_codon(codon)
			if not aa_fwd.is_empty():
				var x := TRACK_LEFT_PAD + _bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var y := area_start + frame * (AA_ROW_H + AA_ROW_GAP) + 17.0
				draw_string(font, Vector2(x, y), aa_fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, palette["text"])

			var rev_codon := _complement_base(b2) + _complement_base(b1) + _complement_base(b0)
			var aa_rev := _translate_codon(rev_codon)
			if not aa_rev.is_empty():
				var rx := TRACK_LEFT_PAD + _bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var ry := area_start + (3 + frame) * (AA_ROW_H + AA_ROW_GAP) + 17.0
				draw_string(font, Vector2(rx, ry), aa_rev, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, palette["text"])

func _is_hidden_full_length_region(feature: Dictionary) -> bool:
	if _show_full_length_regions:
		return false
	var feature_type := str(feature.get("type", "")).to_lower()
	if feature_type != "region":
		return false
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", 0))
	return start_bp <= 0 and end_bp >= chromosome_length

func _draw_genome_track(area: Rect2) -> void:
	var y := area.position.y
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	var line_y := y + 36.0
	if concat_segments.is_empty():
		var axis_left := TRACK_LEFT_PAD
		var axis_right := size.x - TRACK_RIGHT_PAD
		var vis_start := maxf(0.0, view_start_bp)
		var vis_end := minf(_viewport_end_bp(), float(chromosome_length))
		if vis_end > vis_start:
			var x0 := clampf(axis_left + _bp_to_x(vis_start), axis_left, axis_right)
			var x1 := clampf(axis_left + _bp_to_x(vis_end), axis_left, axis_right)
			if x1 > x0:
				draw_line(Vector2(x0, line_y), Vector2(x1, line_y), palette["genome"], 3.0)
		_draw_ticks(y, line_y)
	else:
		_draw_concat_genome_axis(y, line_y)
	_draw_nucleotide_letters(y, line_y)

func _draw_concat_genome_axis(top_y: float, line_y: float) -> void:
	var axis_left := TRACK_LEFT_PAD
	var axis_right := size.x - TRACK_RIGHT_PAD
	var view_start := view_start_bp
	var visible_end := _viewport_end_bp()
	for seg in concat_segments:
		var seg_start := float(seg.get("start", 0))
		var seg_end := float(seg.get("end", 0))
		if seg_end <= view_start or seg_start >= visible_end:
			continue
		var x0 := axis_left + _bp_to_x(seg_start)
		var x1 := axis_left + _bp_to_x(seg_end)
		x0 = clampf(x0, axis_left, axis_right)
		x1 = clampf(x1, axis_left, axis_right)
		if x1 <= x0:
			continue
		draw_line(Vector2(x0, line_y), Vector2(x1, line_y), palette["genome"], 3.0)
		if seg_start >= view_start and seg_start <= visible_end:
			draw_line(Vector2(x0, line_y - 7.0), Vector2(x0, line_y + 7.0), Color.BLACK, 1.0)
		if seg_end >= view_start and seg_end <= visible_end:
			draw_line(Vector2(x1, line_y - 7.0), Vector2(x1, line_y + 7.0), Color.BLACK, 1.0)
		var chr_label := str(seg.get("name", "chr"))
		var label_x := x0 + 4.0
		var label_w := maxf(0.0, x1 - x0 - 8.0)
		if label_w > 12.0:
			draw_string(get_theme_default_font(), Vector2(label_x, top_y + 16.0), chr_label, HORIZONTAL_ALIGNMENT_LEFT, label_w, 12, _axis_text_color())

	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var font := get_theme_default_font()
	var font_size := 11
	var max_tick_labels := 8
	var tick_step := _axis_tick_step(span)
	var segment_tick_labels: Array = []
	for seg in concat_segments:
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", 0))
		var seg_len := maxi(0, seg_end - seg_start)
		if seg_len <= 0:
			continue
		var vis_start := maxi(seg_start, int(floor(view_start_bp)))
		var vis_end := mini(seg_end, int(ceil(visible_end)))
		if vis_end <= vis_start:
			continue
		var local_vis_start := maxi(0, vis_start - seg_start)
		var local_vis_end := mini(seg_len, vis_end - seg_start)
		var first_local_tick := int(floor(float(local_vis_start) / float(tick_step)) * tick_step)
		var local_tick := first_local_tick
		var ticks_for_segment: Array = []
		while local_tick <= local_vis_end:
			if local_tick >= 0 and local_tick <= seg_len:
				var global_tick := seg_start + local_tick
				var x := _bp_to_screen_center(float(global_tick))
				draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), palette["grid"], 1.0)
				ticks_for_segment.append({
					"x": x,
					"label": _format_axis_bp(local_tick, tick_step)
				})
			local_tick += tick_step
		segment_tick_labels.append(ticks_for_segment)

	for i in range(segment_tick_labels.size() - 1):
		var left_ticks: Array = segment_tick_labels[i]
		var right_ticks: Array = segment_tick_labels[i + 1]
		if left_ticks.is_empty() or right_ticks.is_empty():
			continue
		var left_last: Dictionary = left_ticks[left_ticks.size() - 1]
		var right_first: Dictionary = right_ticks[0]
		var left_x := float(left_last.get("x", 0.0))
		var right_x := float(right_first.get("x", 0.0))
		var left_label := str(left_last.get("label", ""))
		var right_label := str(right_first.get("label", ""))
		var left_w := font.get_string_size(left_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var right_w := font.get_string_size(right_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var left_start := left_x - left_w * 0.5
		var right_start := right_x - right_w * 0.5
		if left_start + left_w > right_start:
			left_ticks.remove_at(left_ticks.size() - 1)

	var flat_labels: Array = []
	for ticks_for_segment in segment_tick_labels:
		for tick_info in ticks_for_segment:
			flat_labels.append(tick_info)
	flat_labels.sort_custom(func(a, b): return float(a.get("x", 0.0)) < float(b.get("x", 0.0)))

	if flat_labels.size() > max_tick_labels:
		var selected: Array = []
		for i in range(max_tick_labels):
			var idx := int(round(float(i) * float(flat_labels.size() - 1) / float(max_tick_labels - 1)))
			if selected.is_empty() or idx != int(selected[selected.size() - 1]):
				selected.append(idx)
		var filtered: Array = []
		for idx in selected:
			filtered.append(flat_labels[int(idx)])
		flat_labels = filtered

	for tick_info in flat_labels:
		var label := str(tick_info.get("label", ""))
		var x := float(tick_info.get("x", 0.0))
		var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x - label_w * 0.5, top_y + 54.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _axis_text_color())

func _bp_in_concat_segment(bp: int) -> bool:
	for seg in concat_segments:
		var s := int(seg.get("start", 0))
		var e := int(seg.get("end", 0))
		if bp >= s and bp < e:
			return true
	return false

func _draw_ticks(top_y: float, line_y: float) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var tick_step := float(_axis_tick_step(span))
	var first_tick := int(floor(view_start_bp / tick_step) * tick_step)
	var tick := first_tick
	while tick < int(view_start_bp + span):
		if tick >= 0 and tick <= chromosome_length:
			var x := _bp_to_screen_center(float(tick))
			draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), palette["grid"], 1.0)
			var label := _format_axis_bp(tick, int(tick_step))
			var font := get_theme_default_font()
			var font_size := 11
			var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(x - label_w * 0.5, top_y + 54), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _axis_text_color())
		tick += int(tick_step)

func _draw_grid(area: Rect2) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var step: float = maxf(1.0, _nice_tick(span / 6.0))
	var first: float = floor(view_start_bp / step) * step
	var grid: float = first
	while grid < view_start_bp + span:
		if grid >= 0.0:
			var x := _bp_to_screen_center(grid)
			draw_line(Vector2(x, area.position.y), Vector2(x, area.position.y + area.size.y), palette["grid"], 1.0)
		grid += step

func _draw_file_status() -> void:
	if loaded_files.is_empty():
		draw_string(get_theme_default_font(), Vector2(16, size.y - 10), "Drop genome/BAM/annotation files anywhere to load", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, palette["text"])
	else:
		draw_string(get_theme_default_font(), Vector2(16, size.y - 10), "Loaded files: %d" % loaded_files.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, palette["text"])

func _draw_nucleotide_letters(_top_y: float, line_y: float) -> void:
	if reference_sequence.is_empty():
		return
	if not _can_draw_nucleotide_letters():
		return
	var font := get_theme_default_font()
	var font_size := 14

	var base_count: int = reference_sequence.length()
	if base_count <= 0:
		return
	var vis_start_bp := int(floor(view_start_bp))
	var vis_end_bp := int(ceil(_viewport_end_bp()))
	var ref_start_bp := reference_start_bp
	var ref_end_bp := reference_start_bp + base_count
	if vis_end_bp < ref_start_bp or vis_start_bp > ref_end_bp:
		return
	var i_start := maxi(0, vis_start_bp - ref_start_bp)
	var i_end := mini(base_count - 1, vis_end_bp - ref_start_bp)
	if i_end < i_start:
		return
	if i_end - i_start + 1 > NUC_TEXT_MAX_BASES:
		i_end = i_start + NUC_TEXT_MAX_BASES - 1
	var fwd_y := line_y - 12.0
	var rev_y := line_y + 30.0
	var base_colors := {
		"A": Color("2b9348"),
		"C": Color("1d4ed8"),
		"G": Color("a16207"),
		"T": Color("b91c1c"),
		"N": palette["text"]
	}
	for i in range(i_start, i_end + 1):
		var bp := reference_start_bp + i
		var fwd := reference_sequence.substr(i, 1).to_upper()
		if fwd == " ":
			continue
		var rev := _complement_base(fwd)
		var color: Color = palette["text"]
		if _colorize_nucleotides:
			color = base_colors.get(fwd, palette["text"])
		var x := _bp_to_screen_center(float(bp))
		var fwd_w := font.get_string_size(fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var rev_w := font.get_string_size(rev, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(x - fwd_w * 0.5, fwd_y), fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(font, Vector2(x - rev_w * 0.5, rev_y), rev, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _complement_base(base: String) -> String:
	return COMPLEMENT_MAP.get(base, "N")

func _translate_codon(codon: String) -> String:
	if codon.length() != 3:
		return ""
	return str(CODON_TO_AA.get(codon, "X"))

func _feature_annotation_label(feature: Dictionary, max_width: float) -> String:
	if max_width <= 0.0:
		return ""
	var font := get_theme_default_font()
	var font_size := 12
	var label_name := str(feature.get("name", "")).strip_edges()
	var id := str(feature.get("id", "")).strip_edges()
	if label_name.is_empty():
		label_name = str(feature.get("type", "")).strip_edges()
	if label_name.is_empty() and id.is_empty():
		return ""
	if id.is_empty() or id == label_name:
		return _truncate_label_to_width(label_name, max_width, FEATURE_LABEL_MIN_CHARS, font, font_size)
	var combined := "%s / %s" % [label_name, id]
	var combined_w := font.get_string_size(combined, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if combined_w <= max_width:
		return combined
	return _truncate_label_to_width(label_name, max_width, FEATURE_LABEL_MIN_CHARS, font, font_size)

func _truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
	if text.is_empty() or max_width <= 0.0:
		return ""
	var full_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if full_w <= max_width:
		return text
	var ellipsis := "..."
	var n := text.length()
	var min_n := mini(maxi(1, min_chars), n)
	var min_candidate := text.substr(0, min_n) + ellipsis
	var min_w := font.get_string_size(min_candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if min_w > max_width:
		return ""
	var lo := min_n
	var hi := n
	var best := min_n
	while lo <= hi:
		var mid := lo + ((hi - lo) >> 1)
		var candidate := text.substr(0, mid) + ellipsis
		var w := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w <= max_width:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return text.substr(0, best) + ellipsis

func _intersects_any(rect: Rect2, existing: Array) -> bool:
	for r_any in existing:
		var r: Rect2 = r_any
		if r.intersects(rect):
			return true
	return false

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		var read_rect := _track_rect(TRACK_ID_READS)
		var aa_rect := _track_rect(TRACK_ID_AA)
		var in_reads := read_rect.has_point(mouse_pos)
		var in_aa := aa_rect.has_point(mouse_pos)
		for hit in _track_close_hitboxes:
			var close_rect: Rect2 = hit["rect"]
			if close_rect.has_point(mouse_pos):
				set_track_visible(str(hit["track_id"]), false)
				accept_event()
				return
		for hit in _track_settings_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				emit_signal("track_settings_requested", str(hit["track_id"]))
				accept_event()
				return
		for hit in _track_grab_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				_track_drag_active = true
				_track_drag_track_id = str(hit["track_id"])
				_track_drag_target_index = _track_order.find(_track_drag_track_id)
				accept_event()
				return
		if in_reads:
			for i in range(_read_hitboxes.size() - 1, -1, -1):
				var read_hit: Dictionary = _read_hitboxes[i]
				var read_rect_hit: Rect2 = read_hit["rect"]
				if read_rect_hit.has_point(mouse_pos):
					emit_signal("read_clicked", read_hit["read"])
					accept_event()
					return
		if in_aa:
			for hit in _feature_hitboxes:
				var rect: Rect2 = hit["rect"]
				if rect.has_point(mouse_pos):
					emit_signal("feature_clicked", hit["feature"])
					accept_event()
					return
		if not in_reads:
			for i in range(_read_hitboxes.size() - 1, -1, -1):
				var read_hit_any: Dictionary = _read_hitboxes[i]
				var read_rect_any: Rect2 = read_hit_any["rect"]
				if read_rect_any.has_point(mouse_pos):
					emit_signal("read_clicked", read_hit_any["read"])
					accept_event()
					return
		if not in_aa:
			for hit_any in _feature_hitboxes:
				var feat_rect_any: Rect2 = hit_any["rect"]
				if feat_rect_any.has_point(mouse_pos):
					emit_signal("feature_clicked", hit_any["feature"])
					accept_event()
					return
		if _can_start_region_selection(mouse_pos):
			var edge := _x_to_bp_edge(mouse_pos.x)
			_region_select_dragging = true
			_region_select_has_selection = true
			_region_select_start_edge = edge
			_region_select_end_edge = edge
			queue_redraw()
			accept_event()
			return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _track_drag_active:
			var from_idx := _track_order.find(_track_drag_track_id)
			var to_idx := clampi(_track_drag_target_index, 0, _track_order.size() - 1)
			if from_idx >= 0 and to_idx >= 0 and from_idx != to_idx:
				var next := _track_order.duplicate()
				next.remove_at(from_idx)
				if to_idx > from_idx:
					to_idx -= 1
				next.insert(to_idx, _track_drag_track_id)
				set_track_order(next)
			_track_drag_active = false
			_track_drag_track_id = ""
			_track_drag_target_index = -1
			queue_redraw()
			accept_event()
			return
		if _region_select_dragging:
			_region_select_dragging = false
			var bp0 := mini(_region_select_start_edge, _region_select_end_edge)
			var bp1 := maxi(_region_select_start_edge, _region_select_end_edge)
			if bp1 <= bp0:
				_region_select_has_selection = false
			else:
				emit_signal("region_selected", bp0, bp1)
			queue_redraw()
			accept_event()
			return
	elif event is InputEventMouseMotion and _track_drag_active:
		_track_drag_target_index = _track_index_for_y(event.position.y)
		queue_redraw()
		accept_event()
		return
	elif event is InputEventMouseMotion and _region_select_dragging:
		_region_select_end_edge = _x_to_bp_edge(event.position.x)
		queue_redraw()
		accept_event()
		return
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if absf(pan_event.delta.x) > 0.0:
			_pan_by_pixels(pan_event.delta.x * _trackpad_pan_sensitivity * 3.0)
			accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify_event := event as InputEventMagnifyGesture
		if magnify_event.factor > 0.0:
			# factor > 1 usually means zoom in; invert for bp/px scaling.
			var scaled_factor := pow(magnify_event.factor, _trackpad_pinch_sensitivity)
			scaled_factor = maxf(0.05, scaled_factor)
			var local_mouse := get_local_mouse_position()
			zoom_by_at_x(1.0 / scaled_factor, local_mouse.x, 0.12)
			accept_event()

func _pan_by_pixels(delta_x: float) -> void:
	if _plot_width() <= 0:
		return
	view_start_bp = _clamp_start(view_start_bp + delta_x * bp_per_px)
	queue_redraw()
	_emit_viewport_changed()

func auto_scroll_bp(delta_bp: float) -> bool:
	if _plot_width() <= 0:
		return true
	if is_zero_approx(delta_bp):
		return false
	var prev_start := view_start_bp
	var next_start := _clamp_start(view_start_bp + delta_bp)
	var moved := absf(next_start - prev_start) > 1e-9
	var reached_boundary := not moved
	view_start_bp = next_start
	queue_redraw()
	_emit_viewport_changed()
	return reached_boundary

func get_visible_span_bp() -> float:
	return _plot_width() * bp_per_px

func _plot_width() -> float:
	return maxf(1.0, size.x - TRACK_LEFT_PAD - TRACK_RIGHT_PAD)

func _viewport_end_bp() -> float:
	return view_start_bp + _plot_width() * bp_per_px

func _bp_to_x(bp: float) -> float:
	return (bp - view_start_bp) / bp_per_px

func _bp_to_screen_edge(bp: float) -> float:
	return TRACK_LEFT_PAD + _bp_to_x(bp)

func _bp_to_screen_center(bp: float) -> float:
	return TRACK_LEFT_PAD + _bp_to_x(bp + 0.5)

func _x_to_bp(x: float) -> float:
	var px := clampf(x - TRACK_LEFT_PAD, 0.0, _plot_width())
	return view_start_bp + px * bp_per_px

func _x_to_bp_edge(x: float) -> int:
	return int(round(_x_to_bp(x)))

func _nice_tick(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var exponent: float = floor(log(raw) / log(10.0))
	var base: float = pow(10.0, exponent)
	var scaled: float = raw / base
	if scaled <= 1.0:
		return base
	if scaled <= 2.0:
		return 2.0 * base
	if scaled <= 5.0:
		return 5.0 * base
	return 10.0 * base

func _format_bp(value: int) -> String:
	if value >= 1000000:
		return "%.1f Mb" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1f kb" % (float(value) / 1000.0)
	return "%d" % value

func _format_axis_bp(value: int, step: int) -> String:
	if step < 1000:
		return str(value)
	if step < 1000000:
		var kb := float(value) / 1000.0
		if step < 10000:
			return "%.2f kb" % kb
		if step < 100000:
			return "%.1f kb" % kb
		return "%.0f kb" % kb
	var mb := float(value) / 1000000.0
	if step < 10000000:
		return "%.2f Mb" % mb
	if step < 100000000:
		return "%.1f Mb" % mb
	return "%.0f Mb" % mb

func _axis_text_color() -> Color:
	return palette["text"]

func _axis_tick_step(span: float) -> int:
	if span <= 0.0:
		return 1
	var step6 := int(maxf(1.0, _nice_tick(span / 6.0)))
	var step8 := int(maxf(1.0, _nice_tick(span / 8.0)))
	var count6 := span / float(step6)
	var count8 := span / float(step8)
	var score6 := absf(count6 - 7.0)
	var score8 := absf(count8 - 7.0)
	if count6 < 6.0 or count6 > 8.0:
		score6 += 10.0
	if count8 < 6.0 or count8 > 8.0:
		score8 += 10.0
	if score8 < score6:
		return step8
	return step6

func _feature_to_frame(feature: Dictionary) -> int:
	var strand: String = str(feature.get("strand", "+"))
	var start: int = int(feature.get("start", 0))
	var end: int = int(feature.get("end", 0))
	if strand == "-":
		var reverse_phase := ((2 - ((end - 1) % 3)) + 3) % 3
		return 3 + reverse_phase
	return ((start % 3) + 3) % 3

func _generate_mock_data() -> void:
	reads.clear()
	features.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for i in range(420):
		var start := rng.randi_range(0, chromosome_length - 180)
		reads.append({
			"start": start,
			"end": start + rng.randi_range(40, 180)
		})
	var names := ["dnaA", "recA", "rpoB", "gyrA", "atpD", "hemE", "murC", "ftsZ", "lpxC", "nadK"]
	for i in range(75):
		var s := rng.randi_range(0, chromosome_length - 600)
		var e := s + rng.randi_range(120, 1600)
		features.append({
			"start": s,
			"end": min(e, chromosome_length),
			"strand": "+" if rng.randf() > 0.45 else "-",
			"name": names[i % names.size()]
		})

func _genome_area() -> Rect2:
	return _track_rect(TRACK_ID_GENOME)

func _annotation_area(_area_unused: Rect2) -> Rect2:
	return _track_rect(TRACK_ID_AA)

func _read_area(_ann_area_unused: Rect2) -> Rect2:
	return _track_rect(TRACK_ID_READS)

func _track_layout_rects() -> Dictionary:
	var out := {}
	if _track_order.is_empty():
		return out
	var fixed_sum := 0.0
	var flex_count := 0
	for track_id in _track_order:
		if not is_track_visible(track_id):
			continue
		var h := _track_fixed_height(track_id)
		if h >= 0.0:
			fixed_sum += h
		else:
			flex_count += 1
	var visible_track_count := 0
	for track_id in _track_order:
		if is_track_visible(track_id):
			visible_track_count += 1
	var gap_total := PANEL_GAP * maxf(0.0, float(visible_track_count - 1))
	var available := maxf(0.0, size.y - TOP_PAD - BOTTOM_PAD - gap_total - fixed_sum)
	var flex_h := 0.0
	if flex_count > 0:
		flex_h = available / float(flex_count)
	var used_h := fixed_sum + gap_total + flex_h * float(flex_count)
	var y := maxf(TOP_PAD, size.y - BOTTOM_PAD - used_h)
	for track_id in _track_order:
		if not is_track_visible(track_id):
			continue
		var h := _track_fixed_height(track_id)
		if h < 0.0:
			h = maxf(24.0, flex_h)
		out[track_id] = Rect2(0.0, y, size.x, maxf(24.0, h))
		y += h + PANEL_GAP
	return out

func _track_fixed_height(track_id: String) -> float:
	match track_id:
		TRACK_ID_AA:
			return 6.0 * (AA_ROW_H + AA_ROW_GAP)
		TRACK_ID_GC_PLOT:
			return _gc_plot_h
		TRACK_ID_DEPTH_PLOT:
			return _depth_plot_h
		TRACK_ID_GENOME:
			return GENOME_H
		_:
			return -1.0

func _track_rect(track_id: String) -> Rect2:
	var rects := _track_layout_rects()
	if rects.has(track_id):
		return rects[track_id]
	return Rect2(0.0, 0.0, size.x, 0.0)

func minimum_required_height(reads_min_height: float = 24.0) -> float:
	if _track_order.is_empty():
		return TOP_PAD + BOTTOM_PAD
	var fixed_sum := 0.0
	var flex_sum := 0.0
	var visible_track_count := 0
	for track_id in _track_order:
		if not is_track_visible(track_id):
			continue
		visible_track_count += 1
		var h := _track_fixed_height(track_id)
		if h >= 0.0:
			fixed_sum += h
		elif track_id == TRACK_ID_READS:
			flex_sum += maxf(24.0, reads_min_height)
		else:
			flex_sum += 24.0
	var gap_total := PANEL_GAP * maxf(0.0, float(visible_track_count - 1))
	return TOP_PAD + BOTTOM_PAD + gap_total + fixed_sum + flex_sum

func _can_start_region_selection(mouse_pos: Vector2) -> bool:
	if mouse_pos.x < TRACK_LEFT_PAD or mouse_pos.x > size.x - TRACK_RIGHT_PAD:
		return false
	var aa_rect := _track_rect(TRACK_ID_AA)
	if aa_rect.has_point(mouse_pos):
		return true
	var genome_rect := _track_rect(TRACK_ID_GENOME)
	return genome_rect.has_point(mouse_pos)

func _tracks_view_rect(track_rects: Dictionary) -> Rect2:
	var min_y := INF
	var max_y := -INF
	for rect_any in track_rects.values():
		var r: Rect2 = rect_any
		if r.size.y <= 0.0:
			continue
		min_y = minf(min_y, r.position.y)
		max_y = maxf(max_y, r.position.y + r.size.y)
	if min_y == INF or max_y <= min_y:
		return Rect2(0.0, TOP_PAD, size.x, maxf(0.0, size.y - TOP_PAD - BOTTOM_PAD))
	return Rect2(0.0, min_y, size.x, max_y - min_y)

func _layout_reads() -> void:
	_laid_out_reads.clear()
	_strand_forward_rows = 0
	_strand_reverse_rows = 0
	if reads.is_empty():
		_read_row_count = 0
		return

	if _read_view_mode == READ_VIEW_FRAGMENT:
		_layout_fragment_reads()
		return

	if _read_view_mode == READ_VIEW_STRAND:
		var forward_reads: Array = []
		var reverse_reads: Array = []
		for read in reads:
			if bool(read.get("reverse", false)):
				reverse_reads.append(read)
			else:
				forward_reads.append(read)
		_strand_forward_rows = _pack_reads_into_rows(forward_reads, false)
		_strand_reverse_rows = _pack_reads_into_rows(reverse_reads, false)
		_read_row_count = maxi(_strand_forward_rows, _strand_reverse_rows)
		return

	var use_pair_span := _read_view_mode == READ_VIEW_PAIRED
	_read_row_count = _pack_reads_into_rows(reads, use_pair_span)

func _layout_fragment_reads() -> void:
	var max_frag := 1.0
	for read in reads:
		var f := float(maxi(1, int(read.get("fragment_len", 0))))
		if f > max_frag:
			max_frag = f
	for read in reads:
		var laid_out: Dictionary = (read as Dictionary).duplicate(true)
		var f := float(maxi(1, int(laid_out.get("fragment_len", 0))))
		var norm := 0.0
		if _fragment_log_scale:
			norm = log(f + 1.0) / log(max_frag + 1.0)
		else:
			norm = f / max_frag
		laid_out["frag_norm"] = clampf(norm, 0.0, 1.0)
		_laid_out_reads.append(laid_out)
	_read_row_count = 0

func _pack_reads_into_rows(source_reads: Array, use_pair_span: bool) -> int:
	if source_reads.is_empty():
		return 0
	var sorted_reads: Array = source_reads.duplicate(true)
	sorted_reads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := _layout_span_start(a, use_pair_span)
		var sb := _layout_span_start(b, use_pair_span)
		if sa == sb:
			return _layout_span_end(a, use_pair_span) < _layout_span_end(b, use_pair_span)
		return sa < sb
	)
	var row_ends: Array[int] = []
	for read_any in sorted_reads:
		var read: Dictionary = read_any
		var s := _layout_span_start(read, use_pair_span)
		var e := _layout_span_end(read, use_pair_span)
		var chosen := -1
		for i in range(row_ends.size()):
			if s >= row_ends[i]:
				chosen = i
				break
		if chosen == -1:
			chosen = row_ends.size()
			row_ends.append(e)
		else:
			row_ends[chosen] = e
		var laid_out := read.duplicate(true)
		laid_out["row"] = chosen
		_laid_out_reads.append(laid_out)
	return row_ends.size()

func _layout_span_start(read: Dictionary, use_pair_span: bool) -> int:
	var s := int(read.get("start", 0))
	if not use_pair_span or not _should_use_mate_span_for_packing(read):
		return s
	var mate_start := int(read.get("mate_start", -1))
	if mate_start >= 0:
		return mini(s, mate_start)
	return s

func _layout_span_end(read: Dictionary, use_pair_span: bool) -> int:
	var s := int(read.get("start", 0))
	var e := int(read.get("end", s + 1))
	if not use_pair_span or not _should_use_mate_span_for_packing(read):
		return e
	var mate_end := int(read.get("mate_end", -1))
	if mate_end > 0:
		return maxi(e, mate_end)
	return e

func _should_use_mate_span_for_packing(read: Dictionary) -> bool:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return false
	var view_start := int(view_start_bp)
	var view_end := int(_viewport_end_bp())
	var view_span := maxi(1, view_end - view_start)
	# Keep packing tight: include mate span only when mate is close enough to current view.
	var max_distance := view_span * 2
	var read_start := int(read.get("start", 0))
	var read_end := int(read.get("end", read_start + 1))
	var read_center := int((read_start + read_end) / 2.0)
	var mate_center := int((mate_start + mate_end) / 2.0)
	return absi(mate_center - read_center) <= max_distance

func _layout_read_scrollbar() -> void:
	if _reads_scrollbar == null:
		return
	var read_area := _track_rect(TRACK_ID_READS)
	if read_area.size.y <= 0.0:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var sb_x := size.x - 16.0
	_reads_scrollbar.position = Vector2(sb_x, read_area.position.y + 2.0)
	_reads_scrollbar.size = Vector2(12.0, maxf(12.0, read_area.size.y - 4.0))
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var content_h := maxf(1.0, read_area.size.y - 34.0)
	var visible_rows := maxf(1.0, floor(content_h / (_read_row_h + READ_ROW_GAP)))
	var max_rows := maxi(_read_row_count, 0)
	if _read_view_mode == READ_VIEW_STRAND:
		var step_px := _read_row_h + READ_ROW_GAP
		var split_gap := _strand_split_gap_px()
		var content_top := read_area.position.y + 30.0
		var content_bottom := read_area.position.y + read_area.size.y - 4.0
		var forward_extent := 0.0
		var reverse_extent := 0.0
		if _strand_forward_rows > 0:
			forward_extent = _read_row_h + float(_strand_forward_rows - 1) * step_px + split_gap * 0.5
		if _strand_reverse_rows > 0:
			reverse_extent = _read_row_h + float(_strand_reverse_rows - 1) * step_px + split_gap * 0.5
		var split_at_forward_top := content_top + forward_extent
		var split_at_reverse_bottom := content_bottom - reverse_extent
		var range_px := maxf(0.0, split_at_forward_top - split_at_reverse_bottom)
		_reads_scrollbar.visible = range_px > 0.0
		_reads_scrollbar.max_value = range_px
		_reads_scrollbar.page = maxf(1.0, minf(range_px, 64.0))
		_reads_scrollbar.step = 1.0
		var next_val := clampf(_reads_scrollbar.value, 0.0, range_px)
		if _strand_split_lock_y >= content_top and _strand_split_lock_y <= content_bottom and split_at_forward_top > split_at_reverse_bottom:
			next_val = clampf(split_at_forward_top - _strand_split_lock_y, 0.0, range_px)
		_reads_scrollbar.value = next_val
		return
	var max_offset := maxf(0.0, float(max_rows) - visible_rows)
	_reads_scrollbar.visible = max_offset > 0.0
	_reads_scrollbar.max_value = max_offset
	_reads_scrollbar.page = 1.0
	_reads_scrollbar.step = 1.0
	_reads_scrollbar.value = clampf(_reads_scrollbar.value, 0.0, max_offset)

func _on_reads_scroll_changed(_value: float) -> void:
	queue_redraw()

func _strand_split_gap_px() -> float:
	return 12.0
