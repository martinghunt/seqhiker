extends Control
class_name GenomeView
const MAGRATHEA_FONT := preload("res://fonts/magrathea.ttf")
const ANONYMOUS_PRO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")
const COURIER_NEW_FONT := preload("res://fonts/Courier-New/couriernew.ttf")
const DEJAVU_SANS_FONT_PATH := "res://fonts/Dejavu-sans/DejaVuSans.ttf"
const TRACK_ROW_SCENE := preload("res://scenes/Track.tscn")
const ReadLayoutHelperScript = preload("res://scripts/read_layout_helper.gd")
const ReadTrackRendererScript = preload("res://scripts/read_track_renderer.gd")
const AnnotationRendererScript = preload("res://scripts/annotation_renderer.gd")
const MotionReadLayerScript = preload("res://scripts/motion_read_layer.gd")
const DETAILED_READ_MAX_BP_PER_PX := 48.0

signal viewport_changed(start_bp: int, end_bp: int, bp_per_px: float)
signal feature_clicked(feature: Dictionary)
signal feature_activated(feature: Dictionary)
signal read_clicked(read: Dictionary)
signal read_activated(read: Dictionary)
signal track_settings_requested(track_id: String)
signal track_order_changed(order: PackedStringArray)
signal track_visibility_changed(track_id: String, visible: bool)
signal region_selected(start_bp: int, end_bp: int)
signal region_selection_changed(active: bool, start_bp: int, end_bp: int)
signal map_jump_requested(bp_center: float)

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
const BOTTOM_PAD := 0.0
const READ_ROW_H := 8.0
const READ_ROW_GAP := 4.0
const SNP_MARK_MAX_BP_PER_PX := 8.0
const NUC_TEXT_MAX_BASES := 3000
const FEATURE_MIN_DRAW_PX := 3.0
const FEATURE_DETAIL_MAX_BP_PER_PX := 1.25
const FEATURE_LABEL_MIN_CHARS := 6
const TRACK_ID_READS := "reads"
const READ_TRACK_PREFIX := "reads:"
const TRACK_ID_AA := "aa"
const TRACK_ID_GC_PLOT := "gc_plot"
const TRACK_ID_DEPTH_PLOT := "depth_plot"
const TRACK_ID_GENOME := "genome"
const TRACK_ID_MAP := "map"
const PLOT_Y_UNIT := 0
const PLOT_Y_AUTOSCALE := 1
const PLOT_Y_FIXED := 2
const READ_VIEW_STACK := 0
const READ_VIEW_STRAND := 1
const READ_VIEW_PAIRED := 2
const READ_VIEW_FRAGMENT := 3
const STRAND_SPLIT_LINE_WIDTH := 2.5
const READ_SCROLLBAR_MIN_GRABBER_SIZE := 36
const READ_RENDER_MAX_BP_PER_PX := 128.0
const MAX_VISIBLE_BP := 10000000.0
const MAP_TRACK_H := 72.0
const MAP_VIEW_MIN_PX := 5.0
const MAP_SEQUENCE_H := AA_ROW_H - 6.0
const MAP_VIEW_EXTRA_H := 6.0
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
var chromosome_name := ""
var view_start_bp := 0.0
var bp_per_px := 8.0
var min_bp_per_px := 0.02
var max_bp_per_px := 10000.0

var reads: Array[Dictionary] = []
var coverage_tiles: Array[Dictionary] = []
var _strand_summary: Dictionary = {}
var _fragment_summary: Dictionary = {}
var _was_summary_only := false
var gc_plot_tiles: Array[Dictionary] = []
var depth_plot_tiles: Array[Dictionary] = []
var depth_plot_series: Array[Dictionary] = []
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
	"feature": Color("dce8f7"),
	"feature_text": Color("1e3557")
}

var _pan_tween: Tween
var _zoom_tween: Tween
var _motion_read_layer: Control = null
var _motion_read_layer_active := false
var _motion_read_layer_start_bp := 0.0
var _motion_read_layer_end_bp := 0.0
var _motion_read_layer_bp_per_px := 1.0
var _zoom_from_bp_per_px := 8.0
var _zoom_to_bp_per_px := 8.0
var _zoom_from_start_bp := 0.0
var _zoom_to_start_bp := 0.0
var _feature_hitboxes: Array[Dictionary] = []
var _read_hitboxes: Array[Dictionary] = []
var _selected_feature_key := ""
var _selected_read_index := -1
var _selected_read_track_id := ""
var _selected_read_pair_name := ""
var _selected_read_flags := 0
var _selected_read_pair_a_start := -1
var _selected_read_pair_a_end := -1
var _selected_read_pair_b_start := -1
var _selected_read_pair_b_end := -1
var _trackpad_pan_sensitivity := 1.0
var _trackpad_pinch_sensitivity := 1.0
var _vertical_swipe_zoom_enabled := true
var _mouse_wheel_zoom_sensitivity := 1.0
var _invert_mouse_wheel_zoom := false
var _mouse_wheel_pan_sensitivity := 1.0
var _pan_zoom_animation_speed := 1.0
var _reads_scrollbar: VScrollBar
var _laid_out_reads: Array[Dictionary] = []
var _read_layout_helper := ReadLayoutHelperScript.new()
var _read_renderer: RefCounted
var _annotation_renderer: RefCounted
var _read_row_count := 0
var _strand_forward_rows := 0
var _strand_reverse_rows := 0
var _strand_split_lock_y := -1.0
var _last_layout_bp_per_px := -1.0
var _read_view_mode := READ_VIEW_STACK
var _fragment_log_scale := false
var _read_row_h := READ_ROW_H
var _auto_expand_snp_text := false
var _color_by_mate_contig := false
var _read_row_limit := 0
var _annotation_max_on_screen := 4400
var _show_full_length_regions := false
var _colorize_nucleotides := true
var _gc_plot_y_mode := PLOT_Y_UNIT
var _gc_plot_y_min := 0.0
var _gc_plot_y_max := 1.0
var _depth_plot_y_mode := PLOT_Y_UNIT
var _depth_plot_y_min := 0.0
var _depth_plot_y_max := 1.0
var _axis_coords_with_commas := false
var _gc_plot_h := DEFAULT_PLOT_H
var _depth_plot_h := DEFAULT_PLOT_H
var _track_order: PackedStringArray = PackedStringArray([TRACK_ID_READS, TRACK_ID_DEPTH_PLOT, TRACK_ID_GC_PLOT, TRACK_ID_AA, TRACK_ID_GENOME, TRACK_ID_MAP])
var _track_visible := {
	TRACK_ID_READS: false,
	TRACK_ID_AA: true,
	TRACK_ID_GC_PLOT: false,
	TRACK_ID_DEPTH_PLOT: false,
	TRACK_ID_GENOME: true,
	TRACK_ID_MAP: true
}
var _track_rows := {}
var _track_drag_active := false
var _track_drag_track_id := ""
var _track_drag_target_index := -1
var _region_select_dragging := false
var _region_select_has_selection := false
var _region_select_start_edge := 0
var _region_select_end_edge := 0
var _font_size_small := 11
var _font_size_medium := 13
var _font_size_large := 14
var _sequence_letter_font_name := "Anonymous Pro"
var _dejavu_sans_font: FontFile = null
var annotation_debug_stats_state := {
	"seen": 0,
	"drawn": 0,
	"labels": 0,
	"hitboxes": 0,
	"draw_ms": 0.0
}
var _read_track_states := {}
var _active_read_track_id := TRACK_ID_READS
var _dragging_scrollbar: VScrollBar = null
var _read_loading_message := ""
var _map_drag_active := false
var _map_drag_bp_offset := 0.0

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2.ZERO
	_reads_scrollbar = VScrollBar.new()
	_reads_scrollbar.visible = false
	_reads_scrollbar.step = 0.1
	_reads_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	_reads_scrollbar.add_theme_constant_override("grabber_min_size", READ_SCROLLBAR_MIN_GRABBER_SIZE)
	_reads_scrollbar.value_changed.connect(_on_reads_scroll_changed_for_track.bind(TRACK_ID_READS))
	_reads_scrollbar.gui_input.connect(_on_read_scrollbar_gui_input.bind(_reads_scrollbar))
	add_child(_reads_scrollbar)
	_read_renderer = ReadTrackRendererScript.new()
	_read_renderer.configure(self)
	_annotation_renderer = AnnotationRendererScript.new()
	_annotation_renderer.configure(self)
	_motion_read_layer = MotionReadLayerScript.new()
	_motion_read_layer.configure(self)
	_motion_read_layer.visible = false
	add_child(_motion_read_layer)
	_sync_track_rows()
	_read_track_states[TRACK_ID_READS] = {
		"reads": reads,
		"coverage_tiles": coverage_tiles,
		"strand_summary": _strand_summary,
		"fragment_summary": _fragment_summary,
		"laid_out_reads": _laid_out_reads,
		"read_row_count": _read_row_count,
		"strand_forward_rows": _strand_forward_rows,
		"strand_reverse_rows": _strand_reverse_rows,
		"strand_split_lock_y": _strand_split_lock_y,
		"was_summary_only": _was_summary_only,
		"read_view_mode": _read_view_mode,
		"fragment_log_scale": _fragment_log_scale,
		"read_row_h": _read_row_h,
		"auto_expand_snp_text": _auto_expand_snp_text,
		"color_by_mate_contig": _color_by_mate_contig,
		"read_row_limit": _read_row_limit,
		"scrollbar": _reads_scrollbar
	}
	_layout_track_rows()
	_layout_read_scrollbar()
	_emit_viewport_changed()

func set_chromosome(_chr_name: String, length_bp: int) -> void:
	chromosome_name = _chr_name
	chromosome_length = max(length_bp, 1)
	view_start_bp = 0.0
	reference_start_bp = 0
	reference_sequence = ""
	_strand_split_lock_y = -1.0
	queue_redraw()
	_emit_viewport_changed()

func set_reads(next_reads: Array[Dictionary]) -> void:
	_activate_read_track(TRACK_ID_READS)
	reads.clear()
	for read_any in next_reads:
		var read: Dictionary = (read_any as Dictionary).duplicate(true)
		_read_layout_helper.attach_indel_markers(read)
		reads.append(read)
	_layout_reads()
	_layout_read_scrollbar()
	_persist_active_read_track()
	queue_redraw()

func set_coverage_tiles(next_tiles: Array[Dictionary]) -> void:
	_activate_read_track(TRACK_ID_READS)
	coverage_tiles = next_tiles
	_persist_active_read_track()
	queue_redraw()

func sync_read_tracks(track_ids: PackedStringArray) -> void:
	var wanted := {}
	for id_any in track_ids:
		var track_id := str(id_any)
		if not _is_read_track(track_id):
			continue
		wanted[track_id] = true
		_ensure_read_track_state(track_id)
	for id_any in _read_track_states.keys():
		var existing_id := str(id_any)
		if existing_id == TRACK_ID_READS:
			continue
		if wanted.get(existing_id, false):
			continue
		var state: Dictionary = _read_track_states[existing_id]
		var sb: VScrollBar = state.get("scrollbar", null)
		if sb != null and is_instance_valid(sb):
			sb.queue_free()
		_read_track_states.erase(existing_id)
		_track_visible.erase(existing_id)
	_sync_track_rows()
	if not _read_track_states.has(TRACK_ID_READS):
		_read_track_states[TRACK_ID_READS] = {
			"reads": [],
			"coverage_tiles": [],
			"strand_summary": {},
			"fragment_summary": {},
			"laid_out_reads": [],
			"read_row_count": 0,
			"strand_forward_rows": 0,
			"strand_reverse_rows": 0,
			"strand_split_lock_y": -1.0,
			"was_summary_only": false,
			"read_view_mode": READ_VIEW_STACK,
			"fragment_log_scale": false,
			"read_row_h": READ_ROW_H,
			"color_by_mate_contig": false,
			"read_row_limit": 0,
			"scrollbar": _reads_scrollbar
		}
	_sync_track_rows()
	queue_redraw()

func _sync_track_rows() -> void:
	var wanted := {}
	for id_any in _track_order:
		var track_id := str(id_any)
		wanted[track_id] = true
		if _track_rows.has(track_id):
			continue
		var row: HBoxContainer = TRACK_ROW_SCENE.instantiate()
		row.name = "TrackRow_%s" % track_id.replace(":", "_")
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var buttons := row.get_node("Buttons") as VBoxContainer
		buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var close_button := row.get_node("Buttons/CloseButton") as Button
		var grab_button := row.get_node("Buttons/GrabButton") as Button
		var settings_button := row.get_node("Buttons/SettingsButton") as Button
		var track_view := row.get_node("TrackView") as Control
		track_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		close_button.focus_mode = Control.FOCUS_NONE
		grab_button.focus_mode = Control.FOCUS_NONE
		settings_button.focus_mode = Control.FOCUS_NONE
		grab_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
		close_button.pressed.connect(_on_track_close_pressed.bind(track_id))
		grab_button.button_down.connect(_on_track_grab_button_down.bind(track_id))
		settings_button.pressed.connect(_on_track_settings_pressed.bind(track_id))
		add_child(row)
		_track_rows[track_id] = row
	for id_any in _track_rows.keys():
		var existing_id := str(id_any)
		if wanted.get(existing_id, false):
			continue
		var existing := _track_rows[existing_id] as Control
		if existing != null and is_instance_valid(existing):
			existing.queue_free()
		_track_rows.erase(existing_id)
	_layout_track_rows()

func _layout_track_rows() -> void:
	var rects := _track_layout_rects()
	for id_any in _track_rows.keys():
		var track_id := str(id_any)
		var row := _track_rows[track_id] as Control
		if row == null or not is_instance_valid(row):
			continue
		if rects.has(track_id) and is_track_visible(track_id):
			var rect: Rect2 = rects[track_id]
			row.position = rect.position
			row.size = rect.size
			row.visible = true
		else:
			row.visible = false

func _on_track_close_pressed(track_id: String) -> void:
	set_track_visible(track_id, false)

func _on_track_grab_button_down(track_id: String) -> void:
	if not is_track_visible(track_id):
		return
	_track_drag_active = true
	_track_drag_track_id = track_id
	_track_drag_target_index = _track_order.find(track_id)
	queue_redraw()

func _on_track_settings_pressed(track_id: String) -> void:
	emit_signal("track_settings_requested", track_id)

func _finish_track_drag() -> void:
	if not _track_drag_active:
		return
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

func set_read_track_data(track_id: String, next_reads: Array[Dictionary], next_cov_tiles: Array[Dictionary]) -> void:
	_ensure_read_track_state(track_id)
	_activate_read_track(track_id)
	reads.clear()
	for read_any in next_reads:
		var read: Dictionary = (read_any as Dictionary).duplicate(true)
		_read_layout_helper.attach_indel_markers(read)
		reads.append(read)
	coverage_tiles = next_cov_tiles
	_strand_summary = {}
	_fragment_summary = {}
	_layout_reads()
	_layout_read_scrollbar()
	_persist_active_read_track()
	queue_redraw()

func set_read_track_payload(track_id: String, payload: Dictionary, view_mode: int, fragment_log: bool, row_h: float, row_limit: int, auto_expand_snp_text: bool = false, color_by_mate_contig: bool = false) -> void:
	_ensure_read_track_state(track_id)
	_activate_read_track(track_id)
	var selected_read_key := ""
	if track_id == _selected_read_track_id and _selected_read_index >= 0 and _selected_read_index < _laid_out_reads.size():
		selected_read_key = _read_key(_laid_out_reads[_selected_read_index])
	var prev_view_mode := _read_view_mode
	var next_view_mode := clampi(view_mode, READ_VIEW_STACK, READ_VIEW_FRAGMENT)
	var preferred_rows := {}
	if prev_view_mode == next_view_mode and absf(_last_layout_bp_per_px - bp_per_px) < 0.000001:
		preferred_rows = _read_layout_helper.preferred_row_map(_laid_out_reads, _read_view_mode, int(view_start_bp), int(_viewport_end_bp()))
	var current_summary_only := bp_per_px > DETAILED_READ_MAX_BP_PER_PX and bp_per_px <= READ_RENDER_MAX_BP_PER_PX
	var should_center_paired_from_summary := _was_summary_only and not current_summary_only and next_view_mode == READ_VIEW_PAIRED
	var should_center_strand := prev_view_mode != READ_VIEW_STRAND and next_view_mode == READ_VIEW_STRAND
	var should_bottom_align_stack_like := prev_view_mode != next_view_mode and (next_view_mode == READ_VIEW_STACK or next_view_mode == READ_VIEW_PAIRED)
	_read_view_mode = next_view_mode
	_fragment_log_scale = fragment_log
	_read_row_h = clampf(row_h, 2.0, 24.0)
	_auto_expand_snp_text = auto_expand_snp_text
	_color_by_mate_contig = color_by_mate_contig
	_read_row_limit = maxi(0, row_limit)
	reads = _as_dict_array(payload.get("reads", []))
	coverage_tiles = _as_dict_array(payload.get("coverage", []))
	_strand_summary = payload.get("strand_summary", {})
	_fragment_summary = payload.get("fragment_summary", {})
	_laid_out_reads = _as_dict_array(payload.get("laid_out_reads", []))
	_read_row_count = int(payload.get("read_row_count", 0))
	_strand_forward_rows = int(payload.get("strand_forward_rows", 0))
	_strand_reverse_rows = int(payload.get("strand_reverse_rows", 0))
	if not reads.is_empty() and _read_view_mode != READ_VIEW_FRAGMENT and not preferred_rows.is_empty():
		var stable_layout := _read_layout_helper.build_layout(
			reads,
			_read_view_mode,
			_fragment_log_scale,
			_read_row_limit,
			int(view_start_bp),
			int(_viewport_end_bp()),
			preferred_rows
		)
		_laid_out_reads = stable_layout.get("laid_out_reads", [])
		_read_row_count = int(stable_layout.get("read_row_count", 0))
		_strand_forward_rows = int(stable_layout.get("strand_forward_rows", 0))
		_strand_reverse_rows = int(stable_layout.get("strand_reverse_rows", 0))
	if not reads.is_empty() and (_laid_out_reads.is_empty() or (_read_view_mode != READ_VIEW_FRAGMENT and _read_row_count <= 0)):
		_layout_reads()
	_layout_read_scrollbar()
	if should_center_paired_from_summary and _reads_scrollbar != null and _reads_scrollbar.visible:
		var max_offset := maxf(0.0, _reads_scrollbar.max_value - _reads_scrollbar.page)
		_reads_scrollbar.value = max_offset * 0.5
	elif should_bottom_align_stack_like and _reads_scrollbar != null and _reads_scrollbar.visible:
		var max_offset_stack := maxf(0.0, _reads_scrollbar.max_value - _reads_scrollbar.page)
		_reads_scrollbar.value = max_offset_stack
	if should_center_strand:
		center_strand_scroll()
	if not selected_read_key.is_empty() and track_id == _selected_read_track_id:
		var rebound_index := -1
		for i in range(_laid_out_reads.size()):
			if _read_key(_laid_out_reads[i]) == selected_read_key:
				rebound_index = i
				break
		_selected_read_index = rebound_index
		if rebound_index < 0:
			_selected_read_track_id = ""
			_selected_read_pair_name = ""
			_selected_read_flags = 0
			_selected_read_pair_a_start = -1
			_selected_read_pair_a_end = -1
			_selected_read_pair_b_start = -1
			_selected_read_pair_b_end = -1
	_was_summary_only = current_summary_only
	_last_layout_bp_per_px = bp_per_px
	_persist_active_read_track()
	queue_redraw()

func set_read_track_settings(track_id: String, view_mode: int, fragment_log: bool, row_h: float, row_limit: int, auto_expand_snp_text: bool = false, color_by_mate_contig: bool = false) -> void:
	_ensure_read_track_state(track_id)
	_activate_read_track(track_id)
	var prev_view_mode := _read_view_mode
	_read_view_mode = clampi(view_mode, READ_VIEW_STACK, READ_VIEW_FRAGMENT)
	_fragment_log_scale = fragment_log
	_read_row_h = clampf(row_h, 2.0, 24.0)
	_auto_expand_snp_text = auto_expand_snp_text
	_color_by_mate_contig = color_by_mate_contig
	_read_row_limit = maxi(0, row_limit)
	_layout_reads()
	_layout_read_scrollbar()
	if prev_view_mode != READ_VIEW_STRAND and _read_view_mode == READ_VIEW_STRAND:
		center_strand_scroll()
	elif prev_view_mode != _read_view_mode and (_read_view_mode == READ_VIEW_STACK or _read_view_mode == READ_VIEW_PAIRED) and _reads_scrollbar != null and _reads_scrollbar.visible:
		var max_offset := maxf(0.0, _reads_scrollbar.max_value - _reads_scrollbar.page)
		_reads_scrollbar.value = max_offset
	_persist_active_read_track()
	queue_redraw()

func center_strand_scroll_for_track(track_id: String) -> void:
	_ensure_read_track_state(track_id)
	_activate_read_track(track_id)
	center_strand_scroll()
	_persist_active_read_track()
	queue_redraw()

func set_gc_plot_tiles(next_tiles: Array[Dictionary]) -> void:
	gc_plot_tiles = next_tiles
	queue_redraw()

func set_depth_plot_tiles(next_tiles: Array[Dictionary]) -> void:
	depth_plot_tiles = next_tiles
	queue_redraw()

func set_depth_plot_series(next_series: Array[Dictionary]) -> void:
	depth_plot_series = next_series
	queue_redraw()

func set_read_loading_message(message: String) -> void:
	_read_loading_message = message
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
	for id_any in _read_track_states.keys():
		var id := str(id_any)
		var state: Dictionary = _read_track_states[id]
		var sb: VScrollBar = state.get("scrollbar", null)
		if sb != null and is_instance_valid(sb) and sb != _reads_scrollbar:
			sb.queue_free()
	_read_track_states.clear()
	reads.clear()
	_laid_out_reads.clear()
	_read_row_count = 0
	_strand_split_lock_y = -1.0
	coverage_tiles.clear()
	gc_plot_tiles.clear()
	depth_plot_tiles.clear()
	depth_plot_series.clear()
	features.clear()
	concat_segments.clear()
	loaded_files = PackedStringArray()
	reference_start_bp = 0
	reference_sequence = ""
	view_start_bp = 0.0
	_active_read_track_id = TRACK_ID_READS
	_read_track_states[TRACK_ID_READS] = {
		"reads": reads,
		"coverage_tiles": coverage_tiles,
		"strand_summary": _strand_summary,
		"fragment_summary": _fragment_summary,
		"laid_out_reads": _laid_out_reads,
		"read_row_count": _read_row_count,
		"strand_forward_rows": _strand_forward_rows,
		"strand_reverse_rows": _strand_reverse_rows,
		"strand_split_lock_y": _strand_split_lock_y,
			"read_view_mode": _read_view_mode,
			"fragment_log_scale": _fragment_log_scale,
			"read_row_h": _read_row_h,
			"read_row_limit": _read_row_limit,
			"scrollbar": _reads_scrollbar
		}
	queue_redraw()
	_emit_viewport_changed()

func set_palette(next_palette: Dictionary) -> void:
	palette = next_palette
	queue_redraw()

func set_trackpad_pan_sensitivity(value: float) -> void:
	_trackpad_pan_sensitivity = clampf(value, 0.5, 20.0)

func set_trackpad_pinch_sensitivity(value: float) -> void:
	_trackpad_pinch_sensitivity = clampf(value, 0.5, 20.0)

func set_vertical_swipe_zoom_enabled(enabled: bool) -> void:
	_vertical_swipe_zoom_enabled = enabled

func set_mouse_wheel_zoom_sensitivity(value: float) -> void:
	_mouse_wheel_zoom_sensitivity = clampf(value, 0.1, 10.0)

func set_invert_mouse_wheel_zoom(enabled: bool) -> void:
	_invert_mouse_wheel_zoom = enabled

func set_mouse_wheel_pan_sensitivity(value: float) -> void:
	_mouse_wheel_pan_sensitivity = clampf(value, 0.5, 20.0)

func set_pan_zoom_animation_speed(speed: float) -> void:
	_pan_zoom_animation_speed = clampf(speed, 1.0, 3.0)

func set_base_font_size(base_size: int) -> void:
	_font_size_medium = clampi(base_size, 9, 24)
	_font_size_small = maxi(8, _font_size_medium - 2)
	_font_size_large = _font_size_medium + 1
	queue_redraw()


func set_sequence_letter_font_name(font_name: String) -> void:
	_sequence_letter_font_name = font_name
	queue_redraw()


func sequence_letter_font() -> Font:
	match _sequence_letter_font_name:
		"Noto Sans":
			return ThemeDB.fallback_font
		"DejaVu Sans":
			return _load_dejavu_sans_font()
		"Courier New":
			return COURIER_NEW_FONT
		_:
			return ANONYMOUS_PRO_FONT


func _load_dejavu_sans_font() -> Font:
	if _dejavu_sans_font != null:
		return _dejavu_sans_font
	var font := FontFile.new()
	var err := font.load_dynamic_font(DEJAVU_SANS_FONT_PATH)
	if err != OK:
		return ThemeDB.fallback_font
	_dejavu_sans_font = font
	return _dejavu_sans_font

func set_read_view_mode(mode: int) -> void:
	_activate_read_track(TRACK_ID_READS)
	var prev_view_mode := _read_view_mode
	_read_view_mode = clampi(mode, READ_VIEW_STACK, READ_VIEW_FRAGMENT)
	_strand_split_lock_y = -1.0
	if _reads_scrollbar != null:
		_reads_scrollbar.value = 0.0
	_layout_reads()
	_layout_read_scrollbar()
	_persist_active_read_track()
	if prev_view_mode != READ_VIEW_STRAND and _read_view_mode == READ_VIEW_STRAND:
		center_strand_scroll()
	elif prev_view_mode != _read_view_mode and (_read_view_mode == READ_VIEW_STACK or _read_view_mode == READ_VIEW_PAIRED) and _reads_scrollbar != null and _reads_scrollbar.visible:
		var max_offset := maxf(0.0, _reads_scrollbar.max_value - _reads_scrollbar.page)
		_reads_scrollbar.value = max_offset
	queue_redraw()

func set_fragment_log_scale(enabled: bool) -> void:
	_activate_read_track(TRACK_ID_READS)
	_fragment_log_scale = enabled
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_layout_reads()
		_layout_read_scrollbar()
		_persist_active_read_track()
		queue_redraw()

func set_read_thickness(value: float) -> void:
	_activate_read_track(TRACK_ID_READS)
	_read_row_h = clampf(value, 2.0, 24.0)
	_layout_reads()
	_layout_read_scrollbar()
	_persist_active_read_track()
	queue_redraw()

func current_read_row_h() -> float:
	return _effective_read_row_h()

func current_read_row_step() -> float:
	return current_read_row_h() + READ_ROW_GAP

func can_draw_read_snp_letters_for_row_h(row_h: float) -> bool:
	if row_h < 10.0:
		return false
	var font := sequence_letter_font()
	var font_size := _read_text_font_size_for_row_h(row_h)
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	return pixels_per_bp >= char_px + 1.0

func _read_text_font_size_for_row_h(row_h: float) -> int:
	var row_cap := clampi(int(floor(row_h - 1.0)), 8, _font_size_large)
	return mini(_font_size_medium, row_cap)

func _snp_text_target_read_row_h() -> float:
	return clampf(maxf(10.0, float(_font_size_medium) + 3.0), 2.0, 24.0)

func _effective_read_row_h() -> float:
	if not _auto_expand_snp_text:
		return _read_row_h
	if _read_view_mode == READ_VIEW_FRAGMENT:
		return _read_row_h
	if bp_per_px > SNP_MARK_MAX_BP_PER_PX:
		return _read_row_h
	var expanded := maxf(_read_row_h, _snp_text_target_read_row_h())
	if can_draw_read_snp_letters_for_row_h(expanded):
		return expanded
	return _read_row_h

func set_show_full_length_regions(enabled: bool) -> void:
	_show_full_length_regions = enabled
	queue_redraw()

func set_annotation_max_on_screen(max_count: int) -> void:
	_annotation_max_on_screen = clampi(max_count, 200, 50000)
	queue_redraw()

func set_colorize_nucleotides(enabled: bool) -> void:
	_colorize_nucleotides = enabled
	queue_redraw()

func set_axis_coords_with_commas(enabled: bool) -> void:
	_axis_coords_with_commas = enabled
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
		var max_offset := maxf(0.0, _reads_scrollbar.max_value - _reads_scrollbar.page)
		_reads_scrollbar.value = max_offset * 0.5
		_update_strand_split_lock_from_scrollbar(TRACK_ID_READS)
	_persist_active_read_track()
	queue_redraw()

func get_track_order() -> PackedStringArray:
	return _track_order.duplicate()

func is_track_visible(track_id: String) -> bool:
	return bool(_track_visible.get(track_id, true))

func set_track_visible(track_id: String, show_track: bool) -> void:
	if not _track_visible.has(track_id):
		if _is_read_track(track_id):
			_ensure_read_track_state(track_id)
		else:
			return
	if not _track_visible.has(track_id):
		return
	var next_visible := show_track
	if bool(_track_visible.get(track_id, true)) == next_visible:
		return
	_track_visible[track_id] = next_visible
	if _is_read_track(track_id):
		var state: Dictionary = _read_track_states.get(track_id, {})
		var sb: VScrollBar = state.get("scrollbar", null)
		if sb != null and is_instance_valid(sb) and not next_visible:
			sb.visible = false
	if _track_drag_active and _track_drag_track_id == track_id and not next_visible:
		_track_drag_active = false
		_track_drag_track_id = ""
		_track_drag_target_index = -1
	_layout_track_rows()
	_layout_all_read_scrollbars()
	queue_redraw()
	emit_signal("track_visibility_changed", track_id, next_visible)

func set_track_order(order: PackedStringArray) -> void:
	var prev := _track_order
	var valid := PackedStringArray([TRACK_ID_AA, TRACK_ID_GC_PLOT, TRACK_ID_DEPTH_PLOT, TRACK_ID_GENOME, TRACK_ID_MAP])
	var seen: Dictionary = {}
	var next := PackedStringArray()
	for id_any in order:
		var id := str(id_any)
		if not valid.has(id) and not _is_read_track(id):
			continue
		if seen.get(id, false):
			continue
		if _is_read_track(id):
			_ensure_read_track_state(id)
		seen[id] = true
		next.append(id)
	for id in valid:
		if not seen.get(id, false):
			next.append(id)
	_track_order = next
	_sync_track_rows()
	_layout_track_rows()
	_layout_all_read_scrollbars()
	queue_redraw()
	if prev != _track_order:
		emit_signal("track_order_changed", _track_order.duplicate())

func is_zoom_animating() -> bool:
	return _zoom_tween != null and _zoom_tween.is_running()


func is_pan_animating() -> bool:
	return _pan_tween != null and _pan_tween.is_running()

func get_view_state() -> Dictionary:
	return {
		"start_bp": view_start_bp,
		"bp_per_px": bp_per_px,
		"end_bp": _viewport_end_bp()
	}

func set_view_state(start_bp: float, bp_per_px_value: float) -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_end_motion_read_layer()
	bp_per_px = clampf(bp_per_px_value, min_bp_per_px, _max_allowed_bp_per_px())
	view_start_bp = _clamp_start(start_bp)
	_layout_all_read_scrollbars()
	queue_redraw()
	_emit_viewport_changed()

func jump_to_start() -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_end_motion_read_layer()
	view_start_bp = 0.0
	_layout_all_read_scrollbars()
	queue_redraw()
	_emit_viewport_changed()

func jump_to_end() -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_end_motion_read_layer()
	view_start_bp = _clamp_start(float(chromosome_length))
	_layout_all_read_scrollbars()
	queue_redraw()
	_emit_viewport_changed()

func pan_by_fraction(fraction: float, duration: float = 0.35) -> void:
	var plot_w := _plot_width()
	if plot_w <= 0:
		return
	var span := plot_w * bp_per_px
	var target := _clamp_start(view_start_bp + span * fraction)
	_pan_to(target, duration, false)

func pan_to_start(target_start: float, duration: float = 0.35) -> void:
	_pan_to(_clamp_start(target_start), duration, false)


func pan_to_start_linear(target_start: float, duration: float) -> void:
	_pan_to(_clamp_start(target_start), duration, true)


func begin_motion_read_layer_for_range(render_start: float, render_end: float) -> void:
	_end_motion_read_layer()
	_activate_motion_read_layer(render_start, render_end)


func end_motion_read_layer() -> void:
	_end_motion_read_layer()


func motion_read_layer_covers(start_bp: float, end_bp: float) -> bool:
	if not is_motion_read_layer_active():
		return false
	return start_bp >= _motion_read_layer_start_bp and end_bp <= _motion_read_layer_end_bp


func motion_read_layer_has_autoplay_margin(view_start: float, view_end: float, direction: float, margin_bp: float) -> bool:
	if not is_motion_read_layer_active():
		return false
	if direction >= 0.0:
		return view_start >= _motion_read_layer_start_bp and view_end <= (_motion_read_layer_end_bp - margin_bp)
	return view_end <= _motion_read_layer_end_bp and view_start >= (_motion_read_layer_start_bp + margin_bp)

func zoom_by(factor: float, duration: float = 0.22) -> void:
	zoom_by_at_x(factor, TRACK_LEFT_PAD + _plot_width() * 0.5, duration)

func zoom_by_at_x(factor: float, anchor_x: float, duration: float = 0.22) -> void:
	var plot_w := _plot_width()
	if factor <= 0.0 || plot_w <= 0:
		return
	var old: float = bp_per_px
	var next: float = clampf(old * factor, min_bp_per_px, _max_allowed_bp_per_px())
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

func _pan_to(target_start: float, duration: float, linear: bool) -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	_end_motion_read_layer()
	var actual_duration := _effective_animation_duration(duration)
	if actual_duration <= 0.0:
		view_start_bp = _clamp_start(target_start)
		queue_redraw()
		_emit_viewport_changed()
		return
	var current_start := view_start_bp
	var plot_span := _plot_width() * bp_per_px
	var target_end := minf(float(chromosome_length), target_start + plot_span)
	_activate_motion_read_layer(minf(current_start, target_start), maxf(_viewport_end_bp(), target_end))
	_pan_tween = create_tween()
	if linear:
		_pan_tween.set_trans(Tween.TRANS_LINEAR)
		_pan_tween.set_ease(Tween.EASE_IN_OUT)
	else:
		_pan_tween.set_trans(Tween.TRANS_CUBIC)
		_pan_tween.set_ease(Tween.EASE_OUT)
	_pan_tween.tween_method(_set_view_start_animated, view_start_bp, target_start, actual_duration)
	_pan_tween.finished.connect(_on_pan_finished, CONNECT_ONE_SHOT)

func _set_view_start_animated(next_start: float) -> void:
	view_start_bp = _clamp_start(next_start)
	_update_motion_read_layer_offset()
	queue_redraw()

func _animate_zoom(from_start: float, to_start: float, from_bp_per_px: float, to_bp_per_px: float, duration: float) -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_end_motion_read_layer()
	var actual_duration := _effective_animation_duration(duration)
	if actual_duration <= 0.0:
		bp_per_px = clampf(to_bp_per_px, min_bp_per_px, _max_allowed_bp_per_px())
		view_start_bp = _clamp_start(to_start)
		_layout_all_read_scrollbars()
		queue_redraw()
		_emit_viewport_changed()
		return
	_zoom_from_start_bp = from_start
	_zoom_to_start_bp = to_start
	_zoom_from_bp_per_px = from_bp_per_px
	_zoom_to_bp_per_px = to_bp_per_px
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_set_zoom_progress, 0.0, 1.0, actual_duration)
	_zoom_tween.finished.connect(_on_zoom_finished, CONNECT_ONE_SHOT)

func _set_zoom_progress(t: float) -> void:
	bp_per_px = clampf(lerpf(_zoom_from_bp_per_px, _zoom_to_bp_per_px, t), min_bp_per_px, _max_allowed_bp_per_px())
	view_start_bp = _clamp_start(lerpf(_zoom_from_start_bp, _zoom_to_start_bp, t))
	_layout_all_read_scrollbars()
	queue_redraw()
	_emit_viewport_changed()

func _on_zoom_finished() -> void:
	_emit_viewport_changed()


func _on_pan_finished() -> void:
	_end_motion_read_layer()
	_emit_viewport_changed()


func _effective_animation_duration(base_duration: float) -> float:
	if base_duration <= 0.0:
		return 0.0
	if _pan_zoom_animation_speed >= 3.0:
		return 0.0
	return base_duration / clampf(_pan_zoom_animation_speed, 1.0, 2.0)

func _max_allowed_bp_per_px() -> float:
	var plot_w := _plot_width()
	if plot_w <= 0.0:
		return max_bp_per_px
	return minf(max_bp_per_px, MAX_VISIBLE_BP / plot_w)

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
		bp_per_px = clampf(bp_per_px, min_bp_per_px, _max_allowed_bp_per_px())
		view_start_bp = _clamp_start(view_start_bp)
		_layout_track_rows()
		_layout_all_read_scrollbars()
		queue_redraw()
		_emit_viewport_changed()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["panel"], true)
	_layout_track_rows()
	_read_hitboxes.clear()
	_feature_hitboxes.clear()
	var track_rects := _track_layout_rects()
	var previous_track_id := _active_read_track_id
	for track_id in _track_order:
		if not track_rects.has(track_id):
			continue
		var area: Rect2 = track_rects[track_id]
		if _is_read_track(track_id):
			_activate_read_track(track_id)
			_draw_read_tracks(area)
		else:
				match track_id:
					TRACK_ID_AA:
						_draw_aa_tracks(area)
					TRACK_ID_GC_PLOT:
						_draw_plot_track(area, gc_plot_tiles, _gc_plot_y_mode, _gc_plot_y_min, _gc_plot_y_max, palette.get("gc_plot", palette["read"]))
					TRACK_ID_DEPTH_PLOT:
						if not depth_plot_series.is_empty():
							_draw_plot_track_multi(area, depth_plot_series, _depth_plot_y_mode, _depth_plot_y_min, _depth_plot_y_max)
						else:
							_draw_plot_track(area, depth_plot_tiles, _depth_plot_y_mode, _depth_plot_y_min, _depth_plot_y_max, palette.get("depth_plot", palette["read"]))
					TRACK_ID_GENOME:
						_draw_genome_track(area)
					TRACK_ID_MAP:
						_draw_map_track(area)
	if not previous_track_id.is_empty() and _read_track_states.has(previous_track_id):
		_activate_read_track(previous_track_id)
	_draw_region_selection(track_rects)
	if _track_drag_active and _track_drag_target_index >= 0 and _track_drag_target_index < _track_order.size():
		var target_id := _track_order[_track_drag_target_index]
		if track_rects.has(target_id):
			var target_rect: Rect2 = track_rects[target_id]
			var y := target_rect.position.y - 2.0
			draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), Color(0.05, 0.05, 0.05, 0.9), 2.0)
	_draw_file_status()

func _input(event: InputEvent) -> void:
	if not _track_drag_active:
		return
	if event is InputEventMouseMotion:
		_track_drag_target_index = _track_index_for_y(get_local_mouse_position().y)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_track_drag()

func _draw_region_selection(track_rects: Dictionary) -> void:
	if not _region_select_has_selection and not _region_select_dragging:
		return
	var bp0 := mini(_region_select_start_edge, _region_select_end_edge)
	var bp1 := maxi(_region_select_start_edge, _region_select_end_edge)
	if bp1 <= bp0:
		return
	var x0 := clampf(_bp_to_screen_edge(bp0), TRACK_LEFT_PAD, size.x - TRACK_RIGHT_PAD)
	var x1 := clampf(_bp_to_screen_edge(bp1), TRACK_LEFT_PAD, size.x - TRACK_RIGHT_PAD)
	var w := maxf(1.0, x1 - x0)
	var fill: Color = palette.get("region_select_fill", palette.get("genome", Color(0.25, 0.45, 0.75)))
	fill.a = 0.28
	var border: Color = palette.get("region_select_outline", palette["text"])
	border.a = 0.55
	var selection_spans := _region_selection_spans(track_rects)
	for span_any in selection_spans:
		var span: Rect2 = span_any
		if span.size.y <= 0.0:
			continue
		var rect := Rect2(x0, span.position.y, w, span.size.y)
		draw_rect(rect, fill, true)
		draw_rect(rect, border, false, 1.0)

func _track_label_for_id(track_id: String) -> String:
	if _is_read_track(track_id):
		return "Reads"
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
		TRACK_ID_MAP:
			return "Map"
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
	_read_renderer.draw_read_tracks(area)
	if is_motion_read_layer_active() and _read_view_mode == READ_VIEW_STRAND:
		var content_top := area.position.y + 30.0
		var content_bottom := area.position.y + area.size.y - 4.0
		var strand_split_y := _strand_split_y_for_area(area, _reads_scrollbar.value)
		if strand_split_y >= content_top and strand_split_y <= content_bottom:
			draw_line(Vector2(0.0, strand_split_y), Vector2(size.x, strand_split_y), Color(0, 0, 0, 0.9), STRAND_SPLIT_LINE_WIDTH)


func is_motion_read_layer_active() -> bool:
	return _motion_read_layer_active and _motion_read_layer != null and _motion_read_layer.visible


func _has_visible_read_tracks() -> bool:
	for track_id_any in _track_order:
		var track_id := str(track_id_any)
		if _is_read_track(track_id) and is_track_visible(track_id):
			return true
	return false


func _activate_motion_read_layer(render_start: float, render_end: float) -> void:
	if _motion_read_layer == null:
		return
	if not _has_visible_read_tracks():
		return
	if bp_per_px > DETAILED_READ_MAX_BP_PER_PX:
		return
	render_start = clampf(render_start, 0.0, float(chromosome_length))
	render_end = clampf(render_end, render_start, float(chromosome_length))
	var content_width_px := TRACK_LEFT_PAD + ((render_end - render_start) / bp_per_px) + TRACK_RIGHT_PAD
	_motion_read_layer_start_bp = render_start
	_motion_read_layer_end_bp = render_end
	_motion_read_layer_bp_per_px = bp_per_px
	_motion_read_layer.activate(render_start, render_end, bp_per_px, content_width_px)
	_motion_read_layer_active = true
	_update_motion_read_layer_offset()


func _update_motion_read_layer_offset() -> void:
	if not is_motion_read_layer_active():
		return
	var offset_px := maxf(0.0, (view_start_bp - _motion_read_layer_start_bp) / _motion_read_layer_bp_per_px)
	_motion_read_layer.set_offset_px(offset_px)


func _end_motion_read_layer() -> void:
	_motion_read_layer_active = false
	if _motion_read_layer != null:
		_motion_read_layer.deactivate()

func _read_y_for_area(read: Dictionary, content_top: float, content_bottom: float, scroll_px: float, strand_split_y: float) -> float:
	return _read_renderer.read_y_for_area(read, content_top, content_bottom, scroll_px, strand_split_y)

func _draw_pair_connector(read: Dictionary, y: float) -> void:
	_read_renderer.draw_pair_connector(read, y, palette["read"])

func _can_draw_read_snp_letters() -> bool:
	return _read_renderer.can_draw_read_snp_letters()

func _read_text_font_size() -> int:
	return _read_renderer.read_text_font_size()

func _draw_indel_markers(read: Dictionary, y: float) -> void:
	_read_renderer.draw_indel_markers(read, y)

func _draw_mate_block(read: Dictionary, y: float) -> void:
	_read_renderer.draw_mate_block(read, y, palette["read"])

func _mate_rect_for_read(read: Dictionary, y: float) -> Rect2:
	return _read_renderer.mate_rect_for_read(read, y)

func _build_mate_lookup() -> Dictionary:
	return _read_renderer.build_mate_lookup()

func _mate_lookup_key(pair_key: String, start_bp: int, end_bp: int) -> String:
	return _read_renderer.mate_lookup_key(pair_key, start_bp, end_bp)

func _mate_hitbox_payload(read: Dictionary, current_index: int, mate_lookup: Dictionary = {}) -> Dictionary:
	return _read_renderer.mate_hitbox_payload(read, current_index, mate_lookup)

func _pair_render_key(read: Dictionary) -> String:
	return _read_renderer.pair_render_key(read)

func _draw_coverage_tiles(area: Rect2, show_y_ticks: bool = false) -> void:
	_read_renderer.draw_coverage_tiles(area, show_y_ticks)

func _draw_strand_summary(area: Rect2) -> void:
	_read_renderer.draw_strand_summary(area)

func _draw_stack_summary(area: Rect2) -> void:
	_read_renderer.draw_stack_summary(area)

func _draw_fragment_summary(area: Rect2) -> void:
	_read_renderer.draw_fragment_summary(area)

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
	var prev := Vector2.ZERO
	var have_prev := false
	var prev_tile_end := 0
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
		if have_prev and tile_start > prev_tile_end:
			have_prev = false
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
		prev_tile_end = tile_end

func _draw_plot_track_multi(area: Rect2, series: Array[Dictionary], y_mode: int, y_min_fixed: float, y_max_fixed: float) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	if series.is_empty():
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
		for series_any in series:
			if typeof(series_any) != TYPE_DICTIONARY:
				continue
			var tiles: Array = series_any.get("tiles", [])
			for tile_any in tiles:
				if typeof(tile_any) != TYPE_DICTIONARY:
					continue
				var tile: Dictionary = tile_any
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
	for series_any in series:
		if typeof(series_any) != TYPE_DICTIONARY:
			continue
		var series_dict: Dictionary = series_any
		var line_color: Color = series_dict.get("color", palette.get("depth_plot", palette["read"]))
		var tiles_any: Array = series_dict.get("tiles", [])
		var prev := Vector2.ZERO
		var have_prev := false
		var prev_tile_end := 0
		for tile_any in tiles_any:
			if typeof(tile_any) != TYPE_DICTIONARY:
				continue
			var tile: Dictionary = tile_any
			var tile_start := int(tile.get("start", 0))
			var tile_end := int(tile.get("end", 0))
			if tile_end <= visible_start or tile_start >= visible_end:
				continue
			var vals: PackedFloat32Array = tile.get("values", PackedFloat32Array())
			if vals.is_empty():
				continue
			if have_prev and tile_start > prev_tile_end:
				have_prev = false
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
			prev_tile_end = tile_end

func _draw_plot_scale(area: Rect2, top: float, bottom: float, y_min: float, y_max: float) -> void:
	var tick_x := TRACK_LEFT_PAD - 6.0
	var label_x := 26.0
	var text_col: Color = _axis_text_color()
	var font := get_theme_default_font()
	var font_size := _font_size_small
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
	_annotation_renderer.draw_aa_tracks(area)

func _draw_genome_feature_tracks(area: Rect2, line_y: float) -> void:
	_annotation_renderer.draw_genome_feature_tracks(area, line_y)

func _text_center_y(font: Font, font_size: int, baseline_y: float) -> float:
	return _annotation_renderer.text_center_y(font, font_size, baseline_y)

func _text_baseline_for_center(center_y: float, font: Font, font_size: int) -> float:
	return _annotation_renderer.text_baseline_for_center(center_y, font, font_size)

func _aa_frame_row_center_y(area_start: float, frame: int) -> float:
	return _annotation_renderer.aa_frame_row_center_y(area_start, frame)

func _genome_feature_row_center_y(area: Rect2, line_y: float, row: int) -> float:
	return _annotation_renderer.genome_feature_row_center_y(area, line_y, row)

func annotation_debug_stats() -> Dictionary:
	return _annotation_renderer.annotation_debug_stats()

func set_selected_feature(feature: Dictionary, toggle: bool = false) -> void:
	var next_key := _feature_key(feature)
	if next_key.is_empty():
		return
	if toggle and next_key == _selected_feature_key:
		_selected_feature_key = ""
	else:
		_selected_feature_key = next_key
	queue_redraw()

func set_selected_feature_key(key: String) -> void:
	_selected_feature_key = key
	queue_redraw()

func clear_selected_feature() -> void:
	if _selected_feature_key.is_empty():
		return
	_selected_feature_key = ""
	queue_redraw()

func _feature_key(feature: Dictionary) -> String:
	if feature.is_empty():
		return ""
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", start_bp))
	var seq_name := str(feature.get("seq_name", ""))
	var feat_name := str(feature.get("name", ""))
	var ftype := str(feature.get("type", ""))
	return "%s|%d|%d|%s|%s" % [seq_name, start_bp, end_bp, feat_name, ftype]

func set_selected_read(read: Dictionary, read_index: int, track_id: String, toggle: bool = false) -> void:
	if read_index < 0:
		return
	if toggle and track_id == _selected_read_track_id and read_index == _selected_read_index:
		clear_selected_read()
		return
	_selected_read_index = read_index
	_selected_read_track_id = track_id
	_selected_read_pair_name = str(read.get("name", ""))
	_selected_read_flags = int(read.get("flags", 0))
	var a_start := int(read.get("start", 0))
	var a_end := int(read.get("end", a_start))
	var b_start := int(read.get("mate_start", -1))
	var b_end := int(read.get("mate_end", -1))
	if b_start >= 0 and b_end > b_start:
		_selected_read_pair_a_start = a_start
		_selected_read_pair_a_end = a_end
		_selected_read_pair_b_start = b_start
		_selected_read_pair_b_end = b_end
	else:
		_selected_read_pair_a_start = a_start
		_selected_read_pair_a_end = a_end
		_selected_read_pair_b_start = -1
		_selected_read_pair_b_end = -1
	queue_redraw()

func clear_selected_read() -> void:
	_selected_read_index = -1
	_selected_read_track_id = ""
	_selected_read_pair_name = ""
	_selected_read_flags = 0
	_selected_read_pair_a_start = -1
	_selected_read_pair_a_end = -1
	_selected_read_pair_b_start = -1
	_selected_read_pair_b_end = -1
	queue_redraw()

func _read_key(read: Dictionary) -> String:
	if read.is_empty():
		return ""
	var read_name := str(read.get("name", ""))
	var start_bp := int(read.get("start", 0))
	var end_bp := int(read.get("end", start_bp))
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	var reverse := int(read.get("reverse", false))
	var flags := int(read.get("flags", 0))
	return "%s|%d|%d|%d|%d|%d|%d" % [read_name, start_bp, end_bp, mate_start, mate_end, reverse, flags]

func _can_draw_aa_letters() -> bool:
	if reference_sequence.is_empty():
		return false
	return _can_draw_aa_letters_without_reference()

func _can_draw_aa_letters_without_reference() -> bool:
	if _zoom_tween != null and _zoom_tween.is_running():
		return false
	var font := sequence_letter_font()
	var nuc_font_size := _font_size_large
	var nuc_char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, nuc_font_size).x
	if nuc_char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	var min_nuc_px := maxf(4.0, nuc_char_px * 0.45)
	if pixels_per_bp < min_nuc_px:
		return false
	var aa_font_size := _font_size_medium
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x
	if aa_char_px <= 0.0:
		return false
	var min_aa_codon_px := maxf(4.0, aa_char_px * 0.55)
	return 3.0 * pixels_per_bp >= min_aa_codon_px

func _can_draw_nucleotide_letters() -> bool:
	var font := sequence_letter_font()
	var font_size := _font_size_large
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	return pixels_per_bp >= maxf(4.0, char_px * 0.45)

func _draw_aa_translation_letters(area_start: float) -> void:
	_annotation_renderer.draw_aa_translation_letters(area_start)

func _is_hidden_full_length_region(feature: Dictionary) -> bool:
	return _annotation_renderer.is_hidden_full_length_region(feature)

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
	_draw_genome_feature_tracks(area, line_y)
	_draw_nucleotide_letters(y, line_y)

func _draw_map_track(area: Rect2) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	var axis_left := TRACK_LEFT_PAD
	var axis_right := area.position.x + area.size.x - TRACK_RIGHT_PAD
	if axis_right <= axis_left:
		return
	var total_len: int = max(chromosome_length, 1)
	var has_loaded_genome := not loaded_files.is_empty()
	var viewport_rect := Rect2()
	if has_loaded_genome:
		viewport_rect = _map_view_rect(area, total_len)
	var seq_center_y := viewport_rect.get_center().y
	if not has_loaded_genome:
		seq_center_y = area.position.y + area.size.y * 0.5
	var seq_top := seq_center_y - MAP_SEQUENCE_H * 0.5
	var seq_font := get_theme_default_font()
	var seq_font_size := _font_size_small
	var base_seq_color: Color = palette.get("map_contig", palette["bg"])
	var alt_seq_color: Color = palette.get("map_contig_alt", palette.get("aa_alt_bg", base_seq_color))
	if concat_segments.is_empty():
		var seq_rect := Rect2(axis_left, seq_top, axis_right - axis_left, MAP_SEQUENCE_H)
		draw_rect(seq_rect, base_seq_color, true)
		draw_rect(seq_rect, palette["text"], false, 1.0)
		var seq_name := chromosome_name.strip_edges()
		if has_loaded_genome and not seq_name.is_empty():
			var label := _truncate_label_to_width(seq_name, seq_rect.size.x - 10.0, 4, seq_font, seq_font_size)
			if not label.is_empty():
				var label_y := _text_baseline_for_center(seq_rect.get_center().y, seq_font, seq_font_size)
				draw_string(seq_font, Vector2(seq_rect.position.x + 5.0, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, seq_rect.size.x - 10.0, seq_font_size, palette["text"])
	else:
		for i in range(concat_segments.size()):
			var seg: Dictionary = concat_segments[i]
			var seg_start := float(seg.get("start", 0))
			var seg_end := float(seg.get("end", 0))
			if seg_end <= seg_start:
				continue
			var x0 := _map_bp_to_x(seg_start, area, total_len)
			var x1 := _map_bp_to_x(seg_end, area, total_len)
			if x1 <= x0:
				continue
			var seq_rect := Rect2(x0, seq_top, x1 - x0, MAP_SEQUENCE_H)
			var seq_color: Color = base_seq_color if (i % 2) == 0 else alt_seq_color
			draw_rect(seq_rect, seq_color, true)
			draw_rect(seq_rect, palette["text"], false, 1.0)
			if not has_loaded_genome:
				continue
			var seq_name := str(seg.get("name", "")).strip_edges()
			if seq_name.is_empty():
				continue
			var label := _truncate_label_to_width(seq_name, seq_rect.size.x - 10.0, 4, seq_font, seq_font_size)
			if label.is_empty():
				continue
			var label_y := _text_baseline_for_center(seq_rect.get_center().y, seq_font, seq_font_size)
			draw_string(seq_font, Vector2(seq_rect.position.x + 5.0, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, seq_rect.size.x - 10.0, seq_font_size, palette["text"])
	if has_loaded_genome:
		var fill: Color = palette.get("map_view_fill", palette.get("genome", Color(0.25, 0.45, 0.75)))
		fill.a = 0.5
		draw_rect(viewport_rect, fill, true)
		draw_rect(viewport_rect, palette.get("map_view_outline", palette["text"]), false, 1.5)

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
			draw_string(get_theme_default_font(), Vector2(label_x, top_y + 10.0), chr_label, HORIZONTAL_ALIGNMENT_LEFT, label_w, _font_size_medium, _axis_text_color())

	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var font := get_theme_default_font()
	var font_size := _font_size_small
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
		draw_string(font, Vector2(x - label_w * 0.5, top_y + 49.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _axis_text_color())

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
			var font_size := _font_size_small
			var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(x - label_w * 0.5, top_y + 49), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _axis_text_color())
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
	if not loaded_files.is_empty():
		return
	var genome_area := _track_rect(TRACK_ID_GENOME)
	if genome_area.size.x <= 0.0 or genome_area.size.y <= 0.0:
		return
	var font := get_theme_default_font()
	var msg := "Drop genome/BAM/annotation files anywhere to load"
	var text_w := font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size_medium).x
	var x := genome_area.position.x + (genome_area.size.x - text_w) * 0.5
	var y := genome_area.position.y + genome_area.size.y * 0.5 + _font_size_medium * 0.35
	draw_string(font, Vector2(x, y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size_medium, palette["text"])

func _draw_nucleotide_letters(_top_y: float, line_y: float) -> void:
	if reference_sequence.is_empty():
		return
	if not _can_draw_nucleotide_letters():
		return
	var font := sequence_letter_font()
	var font_size := _font_size_large

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
	var fwd_center_y := _text_center_y(font, font_size, line_y - 12.0)
	var rev_center_y := _text_center_y(font, font_size, line_y + 38.0)
	var fwd_y := _text_baseline_for_center(fwd_center_y, font, font_size)
	var rev_y := _text_baseline_for_center(rev_center_y, font, font_size)
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
	return _annotation_renderer.feature_annotation_label(feature, max_width)

func _truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
	return _annotation_renderer.truncate_label_to_width(text, max_width, min_chars, font, font_size)

func _intersects_any(rect: Rect2, existing: Array) -> bool:
	return _annotation_renderer.intersects_any(rect, existing)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and _map_drag_active:
		var motion := event as InputEventMouseMotion
		var map_rect := _map_track_rect()
		if map_rect.size.x > 0.0 and map_rect.size.y > 0.0:
			var total_len: int = max(chromosome_length, 1)
			var anchor_bp := _map_x_to_bp(motion.position.x, map_rect, total_len)
			var desired_start := _clamp_start(anchor_bp - _map_drag_bp_offset)
			view_start_bp = desired_start
			queue_redraw()
			_emit_viewport_changed()
			accept_event()
			return
	elif event is InputEventMouseButton and event.pressed and (
		event.button_index == MOUSE_BUTTON_WHEEL_UP
		or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		or event.button_index == MOUSE_BUTTON_WHEEL_LEFT
		or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	):
		var wheel_event := event as InputEventMouseButton
		var is_horizontal_wheel := wheel_event.button_index == MOUSE_BUTTON_WHEEL_LEFT or wheel_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
		var shift_held := wheel_event.shift_pressed or Input.is_key_pressed(KEY_SHIFT)
		if is_horizontal_wheel or shift_held:
			var pan_sign := 0.0
			if wheel_event.button_index == MOUSE_BUTTON_WHEEL_LEFT:
				pan_sign = -1.0
			elif wheel_event.button_index == MOUSE_BUTTON_WHEEL_RIGHT:
				pan_sign = 1.0
			else:
				pan_sign = -1.0 if wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			var pan_fraction := 0.12 * _mouse_wheel_pan_sensitivity
			var pan_bp := get_visible_span_bp() * pan_fraction
			_pan_by_pixels(pan_sign * pan_bp / maxf(bp_per_px, 0.000001))
			accept_event()
			return
		var zoom_in := wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP
		if _invert_mouse_wheel_zoom:
			zoom_in = not zoom_in
		var wheel_factor := 0.88 if zoom_in else 1.14
		var scaled_factor := pow(wheel_factor, _mouse_wheel_zoom_sensitivity)
		var local_mouse := wheel_event.position
		zoom_by_at_x(scaled_factor, local_mouse.x, 0.12)
		accept_event()
		return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mb := event as InputEventMouseButton
		var mouse_pos: Vector2 = mb.position
		var map_rect := _map_track_rect()
		if map_rect.size.x > 0.0 and map_rect.size.y > 0.0 and map_rect.has_point(mouse_pos):
			var total_len: int = max(chromosome_length, 1)
			var viewport_rect := _map_view_rect(map_rect, total_len)
			if viewport_rect.has_point(mouse_pos):
				_map_drag_active = true
				_map_drag_bp_offset = _map_x_to_bp(mouse_pos.x, map_rect, total_len) - view_start_bp
			else:
				_map_drag_active = false
				_jump_map_view_to(_map_x_to_bp(mouse_pos.x, map_rect, total_len))
			accept_event()
			return
		var read_rect := _any_read_track_rect_at_point(mouse_pos)
		var aa_rect := _track_rect(TRACK_ID_AA)
		var in_reads := read_rect.size.x > 0.0 and read_rect.has_point(mouse_pos)
		var in_aa := aa_rect.has_point(mouse_pos)
		var hit_feature := false
		var hit_read := false
		if in_reads:
			for i in range(_read_hitboxes.size() - 1, -1, -1):
				var read_hit: Dictionary = _read_hitboxes[i]
				var read_rect_hit: Rect2 = read_hit["rect"]
				if read_rect_hit.has_point(mouse_pos):
					clear_selected_feature()
					set_selected_read(read_hit["read"], int(read_hit.get("read_index", -1)), str(read_hit.get("track_id", "")), false)
					hit_read = true
					emit_signal("read_clicked", read_hit["read"])
					if mb.double_click:
						emit_signal("read_activated", read_hit["read"])
					accept_event()
					return
			clear_selected_read()
			accept_event()
			return
		if in_aa:
			for hit in _feature_hitboxes:
				var rect: Rect2 = hit["rect"]
				if rect.has_point(mouse_pos):
					clear_selected_read()
					set_selected_feature(hit["feature"], false)
					hit_feature = true
					emit_signal("feature_clicked", hit["feature"])
					if mb.double_click:
						emit_signal("feature_activated", hit["feature"])
					accept_event()
					return
		if not in_reads:
			for i in range(_read_hitboxes.size() - 1, -1, -1):
				var read_hit_any: Dictionary = _read_hitboxes[i]
				var read_rect_any: Rect2 = read_hit_any["rect"]
				if read_rect_any.has_point(mouse_pos):
					clear_selected_feature()
					set_selected_read(read_hit_any["read"], int(read_hit_any.get("read_index", -1)), str(read_hit_any.get("track_id", "")), false)
					hit_read = true
					emit_signal("read_clicked", read_hit_any["read"])
					if mb.double_click:
						emit_signal("read_activated", read_hit_any["read"])
					accept_event()
					return
		if not in_aa:
			for hit_any in _feature_hitboxes:
				var feat_rect_any: Rect2 = hit_any["rect"]
				if feat_rect_any.has_point(mouse_pos):
					clear_selected_read()
					set_selected_feature(hit_any["feature"], false)
					hit_feature = true
					emit_signal("feature_clicked", hit_any["feature"])
					if mb.double_click:
						emit_signal("feature_activated", hit_any["feature"])
					accept_event()
					return
			if _can_start_region_selection(mouse_pos):
				clear_selected_read()
				clear_selected_feature()
				var edge := _x_to_bp_edge(mouse_pos.x)
				_region_select_dragging = true
				_region_select_has_selection = false
				_region_select_start_edge = edge
				_region_select_end_edge = edge
				queue_redraw()
				accept_event()
				return
		if not hit_feature and not hit_read:
			clear_selected_read()
		if not hit_feature:
			clear_selected_feature()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _map_drag_active:
			_map_drag_active = false
			accept_event()
			return
		if _region_select_dragging:
			_finish_region_selection_drag()
			queue_redraw()
			accept_event()
			return
	elif event is InputEventMouseMotion and _region_select_dragging:
		var motion := event as InputEventMouseMotion
		if (motion.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
			_finish_region_selection_drag()
			queue_redraw()
			accept_event()
			return
		_region_select_end_edge = _x_to_bp_edge(event.position.x)
		var bp0 := mini(_region_select_start_edge, _region_select_end_edge)
		var bp1 := maxi(_region_select_start_edge, _region_select_end_edge)
		if bp1 > bp0:
			var end_inclusive := bp1 - 1
			_region_select_has_selection = true
			emit_signal("region_selection_changed", true, bp0, end_inclusive)
		else:
			_region_select_has_selection = false
			emit_signal("region_selection_changed", false, 0, 0)
		queue_redraw()
		accept_event()
		return
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if _vertical_swipe_zoom_enabled and absf(pan_event.delta.y) > absf(pan_event.delta.x) and absf(pan_event.delta.y) > 0.0:
			var zoom_in := pan_event.delta.y < 0.0
			if _invert_mouse_wheel_zoom:
				zoom_in = not zoom_in
			var gesture_factor := 0.88 if zoom_in else 1.14
			var scaled_factor := pow(gesture_factor, absf(pan_event.delta.y) * _mouse_wheel_zoom_sensitivity)
			zoom_by_at_x(scaled_factor, pan_event.position.x, 0.12)
			accept_event()
		elif absf(pan_event.delta.x) > 0.0:
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

func _finish_region_selection_drag() -> void:
	_region_select_dragging = false
	var bp0 := mini(_region_select_start_edge, _region_select_end_edge)
	var bp1 := maxi(_region_select_start_edge, _region_select_end_edge)
	if bp1 > bp0:
		_region_select_has_selection = true
		_region_select_start_edge = bp0
		_region_select_end_edge = bp1
		var end_inclusive := bp1 - 1
		emit_signal("region_selected", bp0, end_inclusive)
		emit_signal("region_selection_changed", true, bp0, end_inclusive)
	else:
		_region_select_has_selection = false
		emit_signal("region_selection_changed", false, 0, 0)

func set_region_selection(start_bp: int, end_bp: int) -> void:
	_region_select_dragging = false
	var bp0 := mini(start_bp, end_bp)
	var bp1 := maxi(start_bp, end_bp)
	# Internal selection stores [start_edge, end_edge) while emitted/visible is inclusive.
	_region_select_start_edge = bp0
	_region_select_end_edge = bp1 + 1
	_region_select_has_selection = true
	emit_signal("region_selection_changed", true, bp0, bp1)
	queue_redraw()

func clear_region_selection() -> void:
	_region_select_dragging = false
	_region_select_has_selection = false
	emit_signal("region_selection_changed", false, 0, 0)
	queue_redraw()

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
	_update_motion_read_layer_offset()
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
		return _format_int_with_commas(value) if _axis_coords_with_commas else str(value)
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

func _format_int_with_commas(value: int) -> String:
	var neg := value < 0
	var digits := str(absi(value))
	var out := ""
	var n := digits.length()
	for i in range(n):
		if i > 0 and ((n - i) % 3 == 0):
			out += ","
		out += digits.substr(i, 1)
	return ("-" + out) if neg else out

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
	return _annotation_renderer.feature_to_frame(feature)

func _feature_uses_frame(feature: Dictionary) -> bool:
	return _annotation_renderer.feature_uses_frame(feature)

func _feature_shows_in_aa_track(feature: Dictionary) -> bool:
	return _annotation_renderer.feature_shows_in_aa_track(feature)

func _feature_to_genome_row(feature: Dictionary) -> int:
	return _annotation_renderer.feature_to_genome_row(feature)

func _map_bp_to_x(bp: float, area: Rect2, total_len: int) -> float:
	var axis_left := TRACK_LEFT_PAD
	var axis_right := area.position.x + area.size.x - TRACK_RIGHT_PAD
	var usable_w := maxf(1.0, axis_right - axis_left)
	var norm := clampf(bp / float(max(total_len, 1)), 0.0, 1.0)
	return axis_left + norm * usable_w

func _map_x_to_bp(x: float, area: Rect2, total_len: int) -> float:
	var axis_left := TRACK_LEFT_PAD
	var axis_right := area.position.x + area.size.x - TRACK_RIGHT_PAD
	var usable_w := maxf(1.0, axis_right - axis_left)
	var norm := clampf((x - axis_left) / usable_w, 0.0, 1.0)
	return norm * float(max(total_len, 1))

func _map_view_rect(area: Rect2, total_len: int) -> Rect2:
	var visible_span := minf(get_visible_span_bp(), float(max(total_len, 1)))
	var x0 := _map_bp_to_x(view_start_bp, area, total_len)
	var x1 := _map_bp_to_x(view_start_bp + visible_span, area, total_len)
	var axis_left := TRACK_LEFT_PAD
	var axis_right := area.position.x + area.size.x - TRACK_RIGHT_PAD
	var usable_w := maxf(1.0, axis_right - axis_left)
	var w := minf(usable_w, maxf(MAP_VIEW_MIN_PX, x1 - x0))
	if x0 + w > axis_right:
		x0 = axis_right - w
	x0 = clampf(x0, axis_left, axis_right - w)
	var rect_h := MAP_SEQUENCE_H + MAP_VIEW_EXTRA_H
	var rect_y := area.position.y + (area.size.y - rect_h) * 0.5
	return Rect2(x0, rect_y, w, rect_h)

func _map_track_rect() -> Rect2:
	return _track_rect(TRACK_ID_MAP)

func _jump_map_view_to(bp_center: float) -> void:
	emit_signal("map_jump_requested", bp_center)

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

func _is_read_track(track_id: String) -> bool:
	return track_id == TRACK_ID_READS or track_id.begins_with(READ_TRACK_PREFIX)

func _any_read_track_rect_at_point(mouse_pos: Vector2) -> Rect2:
	for track_id in _track_order:
		var id := str(track_id)
		if not _is_read_track(id):
			continue
		if not is_track_visible(id):
			continue
		var rect := _track_rect(id)
		if rect.has_point(mouse_pos):
			return rect
	return Rect2()

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
		TRACK_ID_MAP:
			return MAP_TRACK_H
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
		elif _is_read_track(str(track_id)):
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

func _region_selection_spans(track_rects: Dictionary) -> Array[Rect2]:
	var spans: Array[Rect2] = []
	var current_start := INF
	var current_end := -INF
	for track_id_any in _track_order:
		var track_id := str(track_id_any)
		if track_id == TRACK_ID_MAP:
			if current_start != INF and current_end > current_start:
				spans.append(Rect2(0.0, current_start, size.x, current_end - current_start))
			current_start = INF
			current_end = -INF
			continue
		if not track_rects.has(track_id):
			continue
		var r: Rect2 = track_rects[track_id]
		if r.size.y <= 0.0:
			continue
		if current_start == INF:
			current_start = r.position.y
			current_end = r.position.y + r.size.y
		else:
			current_end = r.position.y + r.size.y
	if current_start != INF and current_end > current_start:
		spans.append(Rect2(0.0, current_start, size.x, current_end - current_start))
	if spans.is_empty():
		var fallback := _tracks_view_rect(track_rects)
		if fallback.size.y > 0.0:
			spans.append(fallback)
	return spans

func _layout_reads() -> void:
	var preferred_rows := {}
	if absf(_last_layout_bp_per_px - bp_per_px) < 0.000001:
		preferred_rows = _read_layout_helper.preferred_row_map(_laid_out_reads, _read_view_mode, int(view_start_bp), int(_viewport_end_bp()))
	var layout := _read_layout_helper.build_layout(
		reads,
		_read_view_mode,
		_fragment_log_scale,
		_read_row_limit,
		int(view_start_bp),
		int(_viewport_end_bp()),
		preferred_rows
	)
	_laid_out_reads = layout.get("laid_out_reads", [])
	_read_row_count = int(layout.get("read_row_count", 0))
	_strand_forward_rows = int(layout.get("strand_forward_rows", 0))
	_strand_reverse_rows = int(layout.get("strand_reverse_rows", 0))
	_last_layout_bp_per_px = bp_per_px

func _ensure_read_track_state(track_id: String) -> void:
	if not _is_read_track(track_id):
		return
	if _read_track_states.has(track_id):
		return
	var sb := VScrollBar.new()
	sb.visible = false
	sb.step = 0.1
	sb.mouse_filter = Control.MOUSE_FILTER_STOP
	sb.add_theme_constant_override("grabber_min_size", READ_SCROLLBAR_MIN_GRABBER_SIZE)
	sb.value_changed.connect(_on_reads_scroll_changed_for_track.bind(track_id))
	sb.gui_input.connect(_on_read_scrollbar_gui_input.bind(sb))
	add_child(sb)
	_read_track_states[track_id] = {
		"reads": [],
			"coverage_tiles": [],
			"strand_summary": {},
			"fragment_summary": {},
			"laid_out_reads": [],
		"read_row_count": 0,
		"strand_forward_rows": 0,
		"strand_reverse_rows": 0,
		"strand_split_lock_y": -1.0,
		"was_summary_only": false,
		"read_view_mode": READ_VIEW_STACK,
		"fragment_log_scale": true,
		"read_row_h": READ_ROW_H,
		"auto_expand_snp_text": false,
		"color_by_mate_contig": false,
		"read_row_limit": 0,
		"scrollbar": sb
	}
	if not _track_visible.has(track_id):
		_track_visible[track_id] = true
	_sync_track_rows()

func _activate_read_track(track_id: String) -> void:
	_ensure_read_track_state(track_id)
	var state: Dictionary = _read_track_states.get(track_id, {})
	if state.is_empty():
		return
	_active_read_track_id = track_id
	reads = _as_dict_array(state.get("reads", []))
	coverage_tiles = _as_dict_array(state.get("coverage_tiles", []))
	_strand_summary = state.get("strand_summary", {})
	_fragment_summary = state.get("fragment_summary", {})
	_laid_out_reads = _as_dict_array(state.get("laid_out_reads", []))
	_read_row_count = int(state.get("read_row_count", 0))
	_strand_forward_rows = int(state.get("strand_forward_rows", 0))
	_strand_reverse_rows = int(state.get("strand_reverse_rows", 0))
	_strand_split_lock_y = float(state.get("strand_split_lock_y", -1.0))
	_was_summary_only = bool(state.get("was_summary_only", false))
	_read_view_mode = int(state.get("read_view_mode", READ_VIEW_STACK))
	_fragment_log_scale = bool(state.get("fragment_log_scale", true))
	_read_row_h = float(state.get("read_row_h", READ_ROW_H))
	_auto_expand_snp_text = bool(state.get("auto_expand_snp_text", false))
	_color_by_mate_contig = bool(state.get("color_by_mate_contig", false))
	_read_row_limit = int(state.get("read_row_limit", 0))
	_reads_scrollbar = state.get("scrollbar", _reads_scrollbar)

func _as_dict_array(value: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if typeof(value) != TYPE_ARRAY:
		return out
	for item in value:
		if typeof(item) == TYPE_DICTIONARY:
			out.append(item)
	return out

func _persist_active_read_track() -> void:
	if _active_read_track_id.is_empty():
		return
	if not _read_track_states.has(_active_read_track_id):
		return
	_read_track_states[_active_read_track_id] = {
		"reads": reads,
		"coverage_tiles": coverage_tiles,
		"strand_summary": _strand_summary,
		"fragment_summary": _fragment_summary,
		"laid_out_reads": _laid_out_reads,
		"read_row_count": _read_row_count,
		"strand_forward_rows": _strand_forward_rows,
		"strand_reverse_rows": _strand_reverse_rows,
		"strand_split_lock_y": _strand_split_lock_y,
		"read_view_mode": _read_view_mode,
		"fragment_log_scale": _fragment_log_scale,
		"read_row_h": _read_row_h,
		"auto_expand_snp_text": _auto_expand_snp_text,
		"color_by_mate_contig": _color_by_mate_contig,
		"read_row_limit": _read_row_limit,
		"scrollbar": _reads_scrollbar
	}

func _layout_all_read_scrollbars() -> void:
	var previous_track_id := _active_read_track_id
	for track_id_any in _read_track_states.keys():
		var track_id := str(track_id_any)
		_activate_read_track(track_id)
		_layout_read_scrollbar()
		_persist_active_read_track()
	if not previous_track_id.is_empty() and _read_track_states.has(previous_track_id):
		_activate_read_track(previous_track_id)
		return
	if not _read_track_states.is_empty():
		_activate_read_track(str(_read_track_states.keys()[0]))

func _layout_read_scrollbar() -> void:
	if _reads_scrollbar == null:
		return
	var target_track_id := _active_read_track_id
	if target_track_id.is_empty():
		target_track_id = TRACK_ID_READS
	var read_area := _track_rect(target_track_id)
	if read_area.size.y <= 0.0:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var sb_w := float(get_theme_constant("scroll_size", "VScrollBar"))
	if sb_w <= 0.0:
		sb_w = 12.0
	_reads_scrollbar.size = Vector2(sb_w, maxf(12.0, read_area.size.y - 4.0))
	var sb_x := size.x - _reads_scrollbar.size.x
	_reads_scrollbar.position = Vector2(sb_x, read_area.position.y + 2.0)
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var row_h := current_read_row_h()
	var row_step := row_h + READ_ROW_GAP
	var content_h := maxf(1.0, read_area.size.y - 34.0)
	var visible_rows := maxf(1.0, floor(content_h / row_step))
	var max_rows := maxi(_read_row_count, 0)
	if _read_view_mode == READ_VIEW_STRAND:
		var step_px := row_step
		var split_gap := _strand_split_gap_px()
		var content_top := read_area.position.y + 30.0
		var content_bottom := read_area.position.y + read_area.size.y - 4.0
		var forward_extent := 0.0
		var reverse_extent := 0.0
		if _strand_forward_rows > 0:
			forward_extent = row_h + float(_strand_forward_rows - 1) * step_px + split_gap * 0.5
		if _strand_reverse_rows > 0:
			reverse_extent = row_h + float(_strand_reverse_rows - 1) * step_px + split_gap * 0.5
		var split_at_forward_top := content_top + forward_extent
		var split_at_reverse_bottom := content_bottom - reverse_extent
		var range_px := maxf(0.0, split_at_forward_top - split_at_reverse_bottom)
		_reads_scrollbar.visible = range_px > 0.0
		# Godot scrollbar effective drag range is (max_value - page).
		# Configure values so effective range equals our logical range_px.
		var strand_page := maxf(1.0, minf(range_px, content_h * 0.5))
		_reads_scrollbar.page = strand_page
		_reads_scrollbar.max_value = range_px + strand_page
		_reads_scrollbar.step = 0.1
		var next_val := clampf(_reads_scrollbar.value, 0.0, range_px)
		# Preserve split-line lock whenever strand layout is refreshed, but never
		# while the user drags this scrollbar thumb directly.
		if _dragging_scrollbar != _reads_scrollbar and _strand_split_lock_y >= content_top and _strand_split_lock_y <= content_bottom and split_at_forward_top > split_at_reverse_bottom:
			next_val = clampf(split_at_forward_top - _strand_split_lock_y, 0.0, range_px)
		if absf(next_val - _reads_scrollbar.value) > 0.001:
			_reads_scrollbar.value = next_val
		return
	var max_offset := maxf(0.0, float(max_rows) - visible_rows)
	var was_visible := _reads_scrollbar.visible
	var prev_page := _reads_scrollbar.page
	var prev_max_value := _reads_scrollbar.max_value
	var prev_offset_max := maxf(0.0, prev_max_value - prev_page)
	var was_at_bottom := was_visible and absf(_reads_scrollbar.value - prev_offset_max) <= 0.001
	_reads_scrollbar.visible = max_offset > 0.0
	# Godot scrollbar effective drag range is (max_value - page).
	# Configure values so effective range equals our logical max_offset.
	var stack_page := maxf(1.0, visible_rows)
	_reads_scrollbar.page = stack_page
	_reads_scrollbar.max_value = max_offset + stack_page
	_reads_scrollbar.step = 0.1
	var clamped_stack := _reads_scrollbar.value
	if _reads_scrollbar.visible and (not was_visible or was_at_bottom):
		clamped_stack = max_offset
	else:
		clamped_stack = clampf(clamped_stack, 0.0, max_offset)
	if absf(clamped_stack - _reads_scrollbar.value) > 0.001:
		_reads_scrollbar.value = clamped_stack

func _on_reads_scroll_changed_for_track(_value: float, track_id: String) -> void:
	if _read_view_mode == READ_VIEW_STRAND:
		_update_strand_split_lock_from_scrollbar(track_id)
	if _active_read_track_id == track_id:
		_persist_active_read_track()
	queue_redraw()

func _on_read_scrollbar_gui_input(event: InputEvent, sb: VScrollBar) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging_scrollbar = sb
		elif _dragging_scrollbar == sb:
			_dragging_scrollbar = null

func _strand_split_gap_px() -> float:
	return 12.0

func _strand_split_y_for_area(area: Rect2, scroll_value: float) -> float:
	var row_h := current_read_row_h()
	var row_step := current_read_row_step()
	var step_px := row_step
	var split_gap := _strand_split_gap_px()
	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var forward_extent := 0.0
	var reverse_extent := 0.0
	if _strand_forward_rows > 0:
		forward_extent = row_h + float(_strand_forward_rows - 1) * step_px + split_gap * 0.5
	if _strand_reverse_rows > 0:
		reverse_extent = row_h + float(_strand_reverse_rows - 1) * step_px + split_gap * 0.5
	var split_at_forward_top := content_top + forward_extent
	var split_at_reverse_bottom := content_bottom - reverse_extent
	if split_at_forward_top <= split_at_reverse_bottom:
		return (split_at_forward_top + split_at_reverse_bottom) * 0.5
	var range_px := maxf(0.0, split_at_forward_top - split_at_reverse_bottom)
	var off_px := clampf(scroll_value, 0.0, range_px)
	return split_at_forward_top - off_px

func _update_strand_split_lock_from_scrollbar(track_id: String) -> void:
	if _read_view_mode != READ_VIEW_STRAND:
		return
	var state: Dictionary = _read_track_states.get(track_id, {})
	var sb: VScrollBar = state.get("scrollbar", null)
	if sb == null or not is_instance_valid(sb):
		sb = _reads_scrollbar
	if sb == null or not is_instance_valid(sb):
		return
	var read_area := _track_rect(track_id)
	if read_area.size.y <= 0.0:
		return
	_strand_split_lock_y = _strand_split_y_for_area(read_area, sb.value)
