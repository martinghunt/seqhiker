extends Control
class_name ComparisonGenomeRow

const MapStripRendererScript = preload("res://scripts/map_strip_renderer.gd")
const FeatureAnnotationUtilsScript = preload("res://scripts/feature_annotation_utils.gd")
const ANONYMOUS_PRO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")
const COURIER_NEW_FONT := preload("res://fonts/Courier-New/couriernew.ttf")
const DEJAVU_SANS_FONT_PATH := "res://fonts/Dejavu-sans/DejaVuSans.ttf"

signal drag_started(genome_id: int)
signal offset_changed(genome_id: int, value: float)
signal pan_step_requested(genome_id: int, fraction: float)
signal feature_clicked(genome_id: int, feature: Dictionary, was_double_click: bool)
signal axis_center_requested(genome_id: int, click_x_in_parent: float)
signal axis_contig_context_requested(genome_id: int, segment: Dictionary)

const ROW_H := 96.0
const FEATURE_H := 14.0
const FEATURE_ROW_GAP := 3.0
const PAN_STEP_FRAC := 0.75
const DETAIL_TEXT_MAX_BASES := 2000
const MIN_VIEW_SPAN_BP := 50.0

@onready var drag_button: Button = $RootHBox/LeftBox/ButtonsRow/DragButton
@onready var name_label: Label = $RootHBox/LeftBox/NameLabel
@onready var pan_left_button: Button = $RootHBox/LeftBox/ButtonsRow/PanLeftButton
@onready var pan_right_button: Button = $RootHBox/LeftBox/ButtonsRow/PanRightButton
@onready var root_hbox: HBoxContainer = $RootHBox
@onready var left_box: VBoxContainer = $RootHBox/LeftBox
@onready var buttons_row: HBoxContainer = $RootHBox/LeftBox/ButtonsRow
@onready var right_box: VBoxContainer = $RootHBox/RightBox
@onready var axis_wrap: Control = $RootHBox/RightBox/AxisWrap
@onready var axis_bar: HScrollBar = $RootHBox/RightBox/AxisWrap/AxisBar
@onready var axis_input: Control = $RootHBox/RightBox/AxisWrap/AxisInput
@onready var bottom_spacer: Control = $RootHBox/RightBox/BottomSpacer

var _genome_id := -1
var _genome: Dictionary = {}
var _offset := 0.0
var _view_span_bp := 10000.0
var _syncing := false
var _scene_ready := false
var _map_drag_active := false
var _map_drag_bp_offset := 0.0
var _reference_start_bp := 0
var _reference_sequence := ""
var _colorize_nucleotides := true
var _sequence_letter_font_name := "Anonymous Pro"
var _dejavu_sans_font: FontFile = null
var _feature_hitboxes: Array[Dictionary] = []
var _selected_feature_key := ""
var _region_select_dragging := false
var _region_select_has_selection := false
var _region_select_start_edge := 0.0
var _region_select_end_edge := 0.0
var _theme_colors := ThemesLib.new().comparison_theme_colors_from_palette(ThemesLib.THEMES["Slate"])

func _ready() -> void:
	_scene_ready = true
	custom_minimum_size.y = ROW_H
	_apply_axis_track_overrides()
	mouse_filter = Control.MOUSE_FILTER_PASS
	root_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	axis_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_button.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_button.button_down.connect(func() -> void:
		emit_signal("drag_started", _genome_id)
	)
	pan_left_button.pressed.connect(func() -> void:
		emit_signal("pan_step_requested", _genome_id, -PAN_STEP_FRAC)
	)
	pan_right_button.pressed.connect(func() -> void:
		emit_signal("pan_step_requested", _genome_id, PAN_STEP_FRAC)
	)
	axis_bar.value_changed.connect(_on_axis_value_changed)
	axis_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	axis_input.mouse_filter = Control.MOUSE_FILTER_STOP
	axis_input.gui_input.connect(_on_axis_gui_input)
	_apply_axis_range()
	queue_redraw()

func set_theme_colors(next_colors: Dictionary) -> void:
	for key in next_colors.keys():
		_theme_colors[str(key)] = next_colors[key]
	queue_redraw()

func configure_row(genome: Dictionary, offset: float, view_span_bp: float) -> void:
	_genome = genome.duplicate(true)
	_genome_id = int(_genome.get("id", -1))
	_view_span_bp = maxf(MIN_VIEW_SPAN_BP, view_span_bp)
	_offset = maxf(0.0, offset)
	_refresh_if_ready()

func set_view_span_bp(next_span: float) -> void:
	_view_span_bp = maxf(MIN_VIEW_SPAN_BP, next_span)
	_refresh_if_ready()

func set_view_offset(next_offset: float) -> void:
	_offset = maxf(0.0, next_offset)
	_refresh_if_ready()

func set_reference_slice(slice_start: int, sequence: String) -> void:
	_reference_start_bp = maxi(0, slice_start)
	_reference_sequence = sequence
	if _scene_ready:
		queue_redraw()

func set_colorize_nucleotides(enabled: bool) -> void:
	_colorize_nucleotides = enabled
	if _scene_ready:
		queue_redraw()

func set_sequence_letter_font_name(font_name: String) -> void:
	_sequence_letter_font_name = font_name
	if _scene_ready:
		queue_redraw()

func clear_reference_slice() -> void:
	_reference_start_bp = 0
	_reference_sequence = ""
	if _scene_ready:
		queue_redraw()

func get_genome_id() -> int:
	return _genome_id

func get_view_offset() -> float:
	return _offset

func get_axis_rect_in_parent() -> Rect2:
	if axis_bar == null:
		return Rect2(position, Vector2.ZERO)
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return Rect2(position, axis_bar.size)
	return Rect2(axis_bar.global_position - parent_ctrl.global_position, axis_bar.size)

func is_drag_handle_point_in_parent(point_parent: Vector2) -> bool:
	if drag_button == null:
		return false
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return false
	var drag_rect := Rect2(drag_button.global_position - parent_ctrl.global_position, drag_button.size)
	return drag_rect.has_point(point_parent)


func get_match_band_top_in_parent() -> float:
	if axis_bar == null:
		return position.y
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	var upper_center := _forward_feature_center_y(axis_rect)
	return position.y + upper_center - FEATURE_H * 0.5


func get_match_band_bottom_in_parent() -> float:
	if axis_bar == null:
		return position.y + size.y
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	var lower_center := _reverse_feature_center_y(axis_rect)
	return position.y + lower_center + FEATURE_H * 0.5

func get_detail_anchor_y_in_parent() -> float:
	if axis_bar == null:
		return position.y
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	return position.y + _nucleotide_center_y(axis_rect)


func get_bp_center_x_in_parent(bp: float) -> float:
	if axis_bar == null:
		return position.x
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	return position.x + _bp_center_x(bp, axis_rect)


func get_bp_edge_x_in_parent(bp: float) -> float:
	if axis_bar == null:
		return position.x
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	return position.x + (axis_rect.position.x + ((bp - _offset) / _view_span_bp) * axis_rect.size.x)

func get_bp_edge_at_x_in_parent(x_parent: float) -> float:
	var axis_rect := get_axis_rect_in_parent()
	if axis_rect.size.x <= 0.0:
		return _offset
	var frac := clampf((x_parent - axis_rect.position.x) / axis_rect.size.x, 0.0, 1.0)
	return _offset + frac * _view_span_bp

func hit_test_feature_in_parent(point_parent: Vector2) -> Dictionary:
	var local_point := point_parent - position
	for i in range(_feature_hitboxes.size() - 1, -1, -1):
		var hit: Dictionary = _feature_hitboxes[i]
		var rect: Rect2 = hit.get("rect", Rect2())
		if rect.has_point(local_point):
			return {
				"genome_id": _genome_id,
				"feature": hit.get("feature", {})
			}
	return {}

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _scene_ready:
		_apply_axis_range()
		queue_redraw()

func _refresh_if_ready() -> void:
	if not _scene_ready:
		return
	_apply_axis_range()
	name_label.text = "%s%s" % [str(_genome.get("name", "Genome %d" % _genome_id)), _orientation_suffix()]
	queue_redraw()

func _orientation_suffix() -> String:
	var segments: Array = _genome.get("segments", [])
	if segments.is_empty():
		return ""
	var reversed_count := 0
	for seg_any in segments:
		var seg: Dictionary = seg_any
		if bool(seg.get("reversed", false)):
			reversed_count += 1
	if reversed_count <= 0:
		return ""
	if reversed_count >= segments.size():
		return " [RC]"
	return " [%d RC]" % reversed_count

func _apply_axis_range() -> void:
	if axis_bar == null:
		return
	var genome_len := float(_genome.get("length", 0))
	var max_offset := maxf(0.0, genome_len - _view_span_bp)
	_syncing = true
	axis_bar.min_value = 0.0
	axis_bar.max_value = maxf(genome_len, 0.0)
	axis_bar.step = maxf(1.0, floor(_view_span_bp / 500.0))
	axis_bar.page = minf(_view_span_bp, genome_len)
	axis_bar.value = clampf(_offset, 0.0, max_offset)
	_syncing = false

func _draw() -> void:
	_draw_to(self)

func export_to(target) -> void:
	target.draw_set_transform(position, 0.0, Vector2.ONE)
	_draw_to(target)
	target.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_to(target) -> void:
	_draw_rect_on(target, Rect2(0.0, 0.0, size.x, ROW_H), _theme_colors["panel_alt"], true)
	_draw_rect_on(target, Rect2(0.0, 0.0, size.x, ROW_H), _theme_colors["border"], false, 1.0)
	if axis_bar == null:
		return
	if target == self:
		_feature_hitboxes.clear()
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	_draw_contig_segments(axis_rect, target)
	_draw_row_features(axis_rect, target)
	_draw_reference_letters(axis_rect, target)
	_draw_axis_ticks(axis_rect, target)
	_draw_region_selection(axis_rect, target)

func _draw_contig_segments(axis_rect: Rect2, target = self) -> void:
	var segments: Array = _genome.get("segments", [])
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	var genome_len := maxf(1.0, float(_genome.get("length", 0)))
	var strip_segments: Array = segments
	if strip_segments.is_empty():
		strip_segments = [{"name": str(_genome.get("name", "Genome %d" % _genome_id)), "start": 0, "end": genome_len}]
	MapStripRendererScript.draw_strip(
		target,
		axis_rect,
		genome_len,
		strip_segments,
		_theme_colors,
		font,
		font_size,
		Callable(self, "_draw_rect_local"),
		Callable(self, "_draw_string_local"),
		Callable(FeatureAnnotationUtilsScript, "truncate_label_to_width"),
		Callable(FeatureAnnotationUtilsScript, "text_baseline_for_center"),
		true,
		_offset,
		_view_span_bp,
		6.0,
		4.0
	)

func _draw_row_features(axis_rect: Rect2, target = self) -> void:
	var features: Array = _genome.get("features", [])
	var view_end := _offset + _view_span_bp
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var label_boxes := [[], [], []]
	var label_draws := []
	for feat_any in features:
		var feat: Dictionary = feat_any
		if _is_hidden_full_length_region(feat, int(_genome.get("length", 0))):
			continue
		var feat_start := float(feat.get("start", 0))
		var feat_end := float(feat.get("end", 0))
		if feat_end <= _offset or feat_start >= view_end:
			continue
		var row := _feature_to_genome_row(feat)
		var x0 := axis_rect.position.x + (maxf(feat_start, _offset) - _offset) / _view_span_bp * axis_rect.size.x
		var x1 := axis_rect.position.x + (minf(feat_end, view_end) - _offset) / _view_span_bp * axis_rect.size.x
		var center_y := _feature_center_y(axis_rect, row)
		var rect := Rect2(x0, center_y - FEATURE_H * 0.5, maxf(1.5, x1 - x0), FEATURE_H)
		_draw_rect_on(target, rect, _theme_colors["feature"], true)
		if FeatureAnnotationUtilsScript.feature_key(feat) == _selected_feature_key:
			_draw_rect_on(target, rect, _theme_colors["selection_outline"], false, 1.0)
		if target == self:
			_feature_hitboxes.append({
				"rect": rect,
				"feature": feat
			})
		var label_x_min := maxf(rect.position.x + 4.0, axis_rect.position.x + 2.0)
		var label_x_max := minf(rect.position.x + rect.size.x - 4.0, axis_rect.position.x + axis_rect.size.x - 2.0)
		var label_w := maxf(0.0, label_x_max - label_x_min)
		var label := FeatureAnnotationUtilsScript.feature_annotation_label(feat, label_w, font, font_size, 6)
		if label.is_empty():
			continue
		var draw_w := minf(label_w, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var baseline := FeatureAnnotationUtilsScript.text_baseline_for_center(center_y, font, font_size)
		var label_rect := Rect2(label_x_min, rect.position.y + 1.0, draw_w, rect.size.y - 2.0)
		if FeatureAnnotationUtilsScript.intersects_any(label_rect, label_boxes[row]):
			continue
		label_boxes[row].append(label_rect)
		label_draws.append({
			"x": label_x_min,
			"baseline": baseline,
			"label": label,
			"width": label_w
		})
	for draw_any in label_draws:
		var draw_data: Dictionary = draw_any
		_draw_string_on(
			target,
			font,
			Vector2(float(draw_data.get("x", 0.0)), float(draw_data.get("baseline", 0.0))),
			str(draw_data.get("label", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			float(draw_data.get("width", -1.0)),
			font_size,
			_theme_colors["feature_text"]
		)

func _draw_axis_ticks(axis_rect: Rect2, target = self) -> void:
	var genome_len := int(_genome.get("length", 0))
	if genome_len <= 0:
		return
	var offset := int(round(_offset))
	var view_end := mini(genome_len, int(round(_offset + _view_span_bp)))
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	var span := maxi(1, view_end - offset)
	var tick_step := _axis_tick_step(float(span))
	var axis_line_y := _axis_line_y(axis_rect)
	var baseline := _axis_label_baseline_y(axis_rect, font, font_size)
	_draw_line_on(
		target,
		Vector2(axis_rect.position.x, axis_line_y),
		Vector2(axis_rect.position.x + axis_rect.size.x, axis_line_y),
		_theme_colors["text_muted"],
		1.0
	)
	var segments: Array = _genome.get("segments", [])
	if segments.is_empty():
		var first_tick := int(floor(float(offset) / float(tick_step)) * tick_step)
		var tick := first_tick
		while tick <= view_end:
			if tick >= offset and tick <= genome_len:
				var x := _bp_center_x(float(tick), axis_rect)
				_draw_line_on(target, Vector2(x, axis_line_y - 3.0), Vector2(x, axis_line_y + 2.0), _theme_colors["text_muted"], 1.0)
				var label := _format_bp_label(tick + 1)
				var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				_draw_string_on(target, font, Vector2(x - label_w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
			tick += tick_step
		return
	for segment_any in segments:
		var segment: Dictionary = segment_any
		var seg_start := int(segment.get("start", 0))
		var seg_end := int(segment.get("end", 0))
		if seg_end <= offset or seg_start >= view_end:
			continue
		if seg_start >= offset and seg_start <= view_end:
			var start_x := _bp_center_x(float(seg_start), axis_rect)
			_draw_line_on(target, Vector2(start_x, axis_line_y - 3.0), Vector2(start_x, axis_line_y + 2.0), _theme_colors["text_muted"], 1.0)
			var start_label := _format_bp_label(1)
			var start_label_w := font.get_string_size(start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			_draw_string_on(target, font, Vector2(start_x - start_label_w * 0.5, baseline), start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
		var local_start := maxi(0, offset - seg_start)
		var local_end := mini(seg_end - seg_start, view_end - seg_start)
		var first_local_tick := int(floor(float(local_start) / float(tick_step)) * tick_step)
		var local_tick := first_local_tick
		while local_tick <= local_end:
			if local_tick >= local_start and local_tick < seg_end-seg_start:
				if local_tick == 0:
					local_tick += tick_step
					continue
				var tick_bp := seg_start + local_tick
				var x := _bp_center_x(float(tick_bp), axis_rect)
				_draw_line_on(target, Vector2(x, axis_line_y - 3.0), Vector2(x, axis_line_y + 2.0), _theme_colors["text_muted"], 1.0)
				var label := _format_bp_label(local_tick + 1)
				var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				_draw_string_on(target, font, Vector2(x - label_w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
			local_tick += tick_step

func _on_axis_value_changed(value: float) -> void:
	if _syncing:
		return
	_offset = value
	queue_redraw()
	emit_signal("offset_changed", _genome_id, value)


func _on_axis_gui_input(event: InputEvent) -> void:
	var genome_len := float(_genome.get("length", 0))
	if genome_len <= 0.0 or axis_input.size.x <= 0.0:
		return
	var strip_rect := Rect2(Vector2.ZERO, axis_input.size)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var segment := MapStripRendererScript.segment_at_x(mb.position.x, strip_rect, genome_len, _genome.get("segments", []))
			if not segment.is_empty():
				emit_signal("axis_contig_context_requested", _genome_id, segment)
				accept_event()
				return
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var viewport_rect := MapStripRendererScript.viewport_rect(strip_rect, genome_len, _offset, _view_span_bp, 6.0, 4.0)
			if viewport_rect.has_point(mb.position):
				_map_drag_active = true
				_map_drag_bp_offset = MapStripRendererScript.clicked_bp(mb.position.x, strip_rect, genome_len) - _offset
			else:
				_map_drag_active = false
				var bp_center := MapStripRendererScript.clicked_bp(mb.position.x, strip_rect, genome_len)
				_set_offset_from_map(MapStripRendererScript.centered_offset_for_bp(bp_center, genome_len, _view_span_bp))
			accept_event()
			return
		_map_drag_active = false
		accept_event()
		return
	if event is InputEventMouseMotion and _map_drag_active:
		var motion := event as InputEventMouseMotion
		var anchor_bp := MapStripRendererScript.clicked_bp(motion.position.x, strip_rect, genome_len)
		_set_offset_from_map(clampf(anchor_bp - _map_drag_bp_offset, 0.0, maxf(0.0, genome_len - _view_span_bp)))
		accept_event()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
			return
		for i in range(_feature_hitboxes.size() - 1, -1, -1):
			var hit: Dictionary = _feature_hitboxes[i]
			var rect: Rect2 = hit.get("rect", Rect2())
			if not rect.has_point(mb.position):
				continue
			var feature: Dictionary = hit.get("feature", {})
			set_selected_feature(feature, false)
			emit_signal("feature_clicked", _genome_id, feature, mb.double_click)
			accept_event()
			return
		if mb.double_click and _is_in_axis_label_band(mb.position):
			clear_selected_feature()
			emit_signal("axis_center_requested", _genome_id, position.x + mb.position.x)
			accept_event()
			return


func _set_offset_from_map(next_offset: float) -> void:
	_syncing = true
	axis_bar.value = next_offset
	_syncing = false
	_offset = next_offset
	queue_redraw()
	emit_signal("offset_changed", _genome_id, next_offset)

func _draw_reference_letters(axis_rect: Rect2, target = self) -> void:
	if _reference_sequence.is_empty():
		return
	if not _can_draw_nucleotide_letters(axis_rect):
		return
	var base_count := _reference_sequence.length()
	if base_count <= 0:
		return
	var view_start_bp := int(floor(_offset))
	var view_end_bp := int(ceil(_offset + _view_span_bp))
	var ref_end_bp := _reference_start_bp + base_count
	if view_end_bp < _reference_start_bp or view_start_bp > ref_end_bp:
		return
	var i_start := maxi(0, view_start_bp - _reference_start_bp)
	var i_end := mini(base_count - 1, view_end_bp - _reference_start_bp)
	if i_end < i_start:
		return
	if i_end - i_start + 1 > DETAIL_TEXT_MAX_BASES:
		i_end = i_start + DETAIL_TEXT_MAX_BASES - 1
	var font := sequence_letter_font()
	var font_size := maxi(11, get_theme_default_font_size())
	var fwd_center_y := _nucleotide_center_y(axis_rect)
	var fwd_baseline := FeatureAnnotationUtilsScript.text_baseline_for_center(fwd_center_y, font, font_size)
	var base_colors: Dictionary = _theme_colors.get("pileup_logo_bases", {})
	var ambiguous_color: Color = _theme_colors.get("ambiguous_base", _theme_colors["text"])
	for i in range(i_start, i_end + 1):
		var bp := _reference_start_bp + i
		if not _bp_in_segment(bp):
			continue
		var base := _reference_sequence.substr(i, 1).to_upper()
		if base.is_empty():
			continue
		var x := _bp_center_x(float(bp), axis_rect)
		if x < axis_rect.position.x - 8.0 or x > axis_rect.position.x + axis_rect.size.x + 8.0:
			continue
		var color: Color = _theme_colors["text"]
		if _colorize_nucleotides:
			color = base_colors.get(base, ambiguous_color)
		var text_w := font.get_string_size(base, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		_draw_string_on(target, font, Vector2(x - text_w * 0.5, fwd_baseline), base, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _can_draw_nucleotide_letters(axis_rect: Rect2) -> bool:
	if axis_rect.size.x <= 0.0 or _view_span_bp <= 0.0:
		return false
	var font := sequence_letter_font()
	var font_size := maxi(11, get_theme_default_font_size())
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := axis_rect.size.x / _view_span_bp
	return pixels_per_bp >= maxf(4.0, char_px * 0.45)

func _bp_center_x(bp: float, axis_rect: Rect2) -> float:
	return axis_rect.position.x + ((bp - _offset + 0.5) / _view_span_bp) * axis_rect.size.x

func _is_in_axis_label_band(local_pos: Vector2) -> bool:
	if axis_bar == null:
		return false
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	var top := _axis_line_y(axis_rect) - 6.0
	var bottom := _axis_label_baseline_y(axis_rect, get_theme_default_font(), maxi(10, get_theme_default_font_size() - 2)) + 4.0
	return local_pos.x >= axis_rect.position.x and local_pos.x <= axis_rect.position.x + axis_rect.size.x and local_pos.y >= top and local_pos.y <= bottom

func _bp_in_segment(bp: int) -> bool:
	var segments: Array = _genome.get("segments", [])
	if segments.is_empty():
		return true
	for segment_any in segments:
		var segment: Dictionary = segment_any
		var seg_start := int(segment.get("start", 0))
		var seg_end := int(segment.get("end", 0))
		if bp >= seg_start and bp < seg_end:
			return true
	return false

func set_region_selection(start_bp: float, end_bp: float, dragging: bool = false) -> void:
	_region_select_has_selection = true
	_region_select_dragging = dragging
	_region_select_start_edge = start_bp
	_region_select_end_edge = end_bp
	queue_redraw()

func clear_region_selection() -> void:
	if not _region_select_has_selection and not _region_select_dragging:
		return
	_region_select_dragging = false
	_region_select_has_selection = false
	_region_select_start_edge = 0.0
	_region_select_end_edge = 0.0
	queue_redraw()

func set_selected_feature(feature: Dictionary, toggle: bool = false) -> void:
	var next_key := FeatureAnnotationUtilsScript.feature_key(feature)
	if next_key.is_empty():
		return
	if toggle and next_key == _selected_feature_key:
		_selected_feature_key = ""
	else:
		_selected_feature_key = next_key
	queue_redraw()

func clear_selected_feature() -> void:
	if _selected_feature_key.is_empty():
		return
	_selected_feature_key = ""
	queue_redraw()

func set_selected_feature_key(key: String) -> void:
	_selected_feature_key = key
	queue_redraw()

func _feature_to_genome_row(feature: Dictionary) -> int:
	return FeatureAnnotationUtilsScript.feature_to_collapsed_genome_row(feature, 0)

func _feature_center_y(row_rect: Rect2, row: int) -> float:
	if row == 2:
		return _reverse_feature_center_y(row_rect)
	return _forward_feature_center_y(row_rect)

func _forward_feature_center_y(row_rect: Rect2) -> float:
	return row_rect.position.y - FEATURE_ROW_GAP - FEATURE_H * 0.5

func _nucleotide_center_y(row_rect: Rect2) -> float:
	return row_rect.position.y + row_rect.size.y + 10.0

func _axis_line_y(row_rect: Rect2) -> float:
	return _nucleotide_center_y(row_rect) + 12.0

func _axis_label_baseline_y(row_rect: Rect2, font: Font, font_size: int) -> float:
	return _axis_line_y(row_rect) + 2.0 + font.get_ascent(font_size)

func _reverse_feature_center_y(row_rect: Rect2) -> float:
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	return _axis_label_baseline_y(row_rect, font, font_size) + 6.0 + FEATURE_H * 0.5

func _is_hidden_full_length_region(feature: Dictionary, genome_len: int) -> bool:
	var feature_type := str(feature.get("type", "")).to_lower()
	if feature_type != "region" and feature_type != "source":
		return false
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", 0))
	return start_bp <= 0 and end_bp >= genome_len

func _format_bp_label(bp: int) -> String:
	var n := maxi(0, bp)
	var text := str(n)
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3, 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out

func _axis_tick_step(span: float) -> int:
	var step: float = maxf(1.0, _nice_tick(span / 6.0))
	return maxi(1, int(step))

func _apply_axis_track_overrides() -> void:
	if axis_bar == null:
		return
	axis_bar.modulate = Color(1, 1, 1, 0.0)
	var clear_track := StyleBoxFlat.new()
	clear_track.bg_color = Color(0, 0, 0, 0)
	clear_track.border_color = Color(0, 0, 0, 0)
	clear_track.set_border_width_all(0)
	clear_track.content_margin_left = 2
	clear_track.content_margin_right = 2
	clear_track.content_margin_top = 2
	clear_track.content_margin_bottom = 2
	axis_bar.add_theme_stylebox_override("scroll", clear_track)
	axis_bar.add_theme_stylebox_override("scroll_focus", clear_track.duplicate())
	var clear_grabber := StyleBoxFlat.new()
	clear_grabber.bg_color = Color(0, 0, 0, 0)
	clear_grabber.border_color = Color(0, 0, 0, 0)
	clear_grabber.set_border_width_all(0)
	clear_grabber.set_corner_radius_all(4)
	axis_bar.add_theme_stylebox_override("grabber", clear_grabber)
	axis_bar.add_theme_stylebox_override("grabber_highlight", clear_grabber.duplicate())
	axis_bar.add_theme_stylebox_override("grabber_pressed", clear_grabber.duplicate())

func _draw_region_selection(axis_rect: Rect2, target = self) -> void:
	if not _region_select_has_selection:
		return
	var x0 := get_bp_edge_x_in_parent(_region_select_start_edge) - position.x
	var x1 := get_bp_edge_x_in_parent(_region_select_end_edge) - position.x
	var left := clampf(minf(x0, x1), axis_rect.position.x, axis_rect.position.x + axis_rect.size.x)
	var right := clampf(maxf(x0, x1), axis_rect.position.x, axis_rect.position.x + axis_rect.size.x)
	if right <= left:
		right = minf(axis_rect.position.x + axis_rect.size.x, left + 1.0)
	var rect := Rect2(left, 0.0, right - left, ROW_H)
	var fill: Color = _theme_colors["region_select_fill"]
	fill.a = 0.28
	var border: Color = _theme_colors.get("region_select_outline", _theme_colors.get("text", Color.BLACK))
	border.a = 0.55
	_draw_rect_on(target, rect, fill, true)
	_draw_rect_on(target, rect, border, false, 1.0)


func _draw_rect_on(target, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	if target == self:
		if filled:
			draw_rect(rect, color, true)
		else:
			draw_rect(rect, color, false, width)
	else:
		if filled:
			target.draw_rect(rect, color, true)
		else:
			target.draw_rect(rect, color, false, width)

func _draw_line_on(target, p0: Vector2, p1: Vector2, color: Color, width: float = 1.0) -> void:
	if target == self:
		draw_line(p0, p1, color, width)
	else:
		target.draw_line(p0, p1, color, width)

func _draw_string_on(target, font: Font, pos: Vector2, text: String, align: int, max_width: float, font_size: int, color: Color) -> void:
	if target == self:
		draw_string(font, pos, text, align, max_width, font_size, color)
	else:
		target.draw_string(font, pos, text, align, max_width, font_size, color)

func _draw_rect_local(target, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	_draw_rect_on(target, rect, color, filled, width)

func _draw_string_local(target, font: Font, pos: Vector2, text: String, align: int, max_width: float, font_size: int, color: Color) -> void:
	_draw_string_on(target, font, pos, text, align, max_width, font_size, color)

func _nice_tick(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var exp10: float = floor(log(raw) / log(10.0))
	var magnitude: float = pow(10.0, exp10)
	var norm: float = raw / magnitude
	if norm <= 1.0:
		return magnitude
	if norm <= 2.0:
		return 2.0 * magnitude
	if norm <= 5.0:
		return 5.0 * magnitude
	return 10.0 * magnitude

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
