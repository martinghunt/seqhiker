extends Control
class_name ComparisonGenomeRow

const MapStripRendererScript = preload("res://scripts/map_strip_renderer.gd")

signal drag_started(genome_id: int)
signal offset_changed(genome_id: int, value: float)
signal pan_step_requested(genome_id: int, fraction: float)

const ROW_H := 82.0
const FEATURE_H := 14.0
const FEATURE_ROW_GAP := 3.0
const PAN_STEP_FRAC := 0.75

@onready var drag_button: Button = $RootHBox/LeftBox/ButtonsRow/DragButton
@onready var name_label: Label = $RootHBox/LeftBox/NameLabel
@onready var pan_left_button: Button = $RootHBox/LeftBox/ButtonsRow/PanLeftButton
@onready var pan_right_button: Button = $RootHBox/LeftBox/ButtonsRow/PanRightButton
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
var _theme_colors := {
	"text": Color.BLACK,
	"text_muted": Color("666666"),
	"border": Color("aaaaaa"),
	"panel_alt": Color("efefef"),
	"genome": Color("3f5a7a"),
	"map_contig": Color("ffffff"),
	"map_contig_alt": Color("efefef"),
	"map_view_fill": Color("3f5a7a"),
	"map_view_outline": Color.BLACK,
	"feature": Color("dce8f7"),
	"feature_text": Color("1e3557")
}

func _ready() -> void:
	_scene_ready = true
	custom_minimum_size.y = ROW_H
	_apply_axis_track_overrides()
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
	_view_span_bp = maxf(100.0, view_span_bp)
	_offset = maxf(0.0, offset)
	_refresh_if_ready()

func set_view_span_bp(next_span: float) -> void:
	_view_span_bp = maxf(100.0, next_span)
	_refresh_if_ready()

func set_view_offset(next_offset: float) -> void:
	_offset = maxf(0.0, next_offset)
	_refresh_if_ready()

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


func get_match_band_top_in_parent() -> float:
	if axis_bar == null:
		return position.y
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	var upper_center := minf(_genome_feature_row_center_y(axis_rect, 0), _genome_feature_row_center_y(axis_rect, 1))
	return position.y + upper_center - FEATURE_H * 0.5


func get_match_band_bottom_in_parent() -> float:
	if axis_bar == null:
		return position.y + size.y
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	var lower_center := _genome_feature_row_center_y(axis_rect, 2)
	return position.y + lower_center + FEATURE_H * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _scene_ready:
		_apply_axis_range()
		queue_redraw()

func _refresh_if_ready() -> void:
	if not _scene_ready:
		return
	_apply_axis_range()
	name_label.text = str(_genome.get("name", "Genome %d" % _genome_id))
	queue_redraw()

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
	draw_rect(Rect2(0.0, 0.0, size.x, ROW_H), _theme_colors["panel_alt"], true)
	draw_rect(Rect2(0.0, 0.0, size.x, ROW_H), _theme_colors["border"], false, 1.0)
	if axis_bar == null:
		return
	var axis_rect := Rect2(axis_bar.global_position - global_position, axis_bar.size)
	_draw_contig_segments(axis_rect)
	_draw_row_features(axis_rect)
	_draw_axis_ticks(axis_rect)

func _draw_contig_segments(axis_rect: Rect2) -> void:
	var segments: Array = _genome.get("segments", [])
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	var genome_len := maxf(1.0, float(_genome.get("length", 0)))
	var strip_segments: Array = segments
	if strip_segments.is_empty():
		strip_segments = [{"name": str(_genome.get("name", "Genome %d" % _genome_id)), "start": 0, "end": genome_len}]
	MapStripRendererScript.draw_strip(
		self,
		axis_rect,
		genome_len,
		strip_segments,
		_theme_colors,
		font,
		font_size,
		Callable(self, "_draw_rect_local"),
		Callable(self, "_draw_string_local"),
		Callable(self, "_truncate_label_to_width"),
		Callable(self, "_text_baseline_for_center"),
		true,
		_offset,
		_view_span_bp,
		6.0,
		4.0
	)

func _draw_row_features(axis_rect: Rect2) -> void:
	var features: Array = _genome.get("features", [])
	var view_end := _offset + _view_span_bp
	var font := get_theme_default_font()
	var font_size := get_theme_default_font_size()
	var label_boxes := [[], [], []]
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
		var center_y := _genome_feature_row_center_y(axis_rect, row)
		var rect := Rect2(x0, center_y - FEATURE_H * 0.5, maxf(1.5, x1 - x0), FEATURE_H)
		draw_rect(rect, _theme_colors["feature"], true)
		var label_x_min := maxf(rect.position.x + 4.0, axis_rect.position.x + 2.0)
		var label_x_max := minf(rect.position.x + rect.size.x - 4.0, axis_rect.position.x + axis_rect.size.x - 2.0)
		var label_w := maxf(0.0, label_x_max - label_x_min)
		var label := _feature_annotation_label(feat, label_w, font, font_size)
		if label.is_empty():
			continue
		var draw_w := minf(label_w, font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		var label_rect := Rect2(label_x_min, rect.position.y + 1.0, draw_w, rect.size.y - 2.0)
		if _intersects_any(label_rect, label_boxes[row]):
			continue
		label_boxes[row].append(label_rect)
		draw_string(font, Vector2(label_x_min, _text_baseline_for_center(center_y, font, font_size)), label, HORIZONTAL_ALIGNMENT_LEFT, label_w, font_size, _theme_colors["feature_text"])

func _draw_axis_ticks(axis_rect: Rect2) -> void:
	var genome_len := int(_genome.get("length", 0))
	if genome_len <= 0:
		return
	var offset := int(round(_offset))
	var view_end := mini(genome_len, int(round(_offset + _view_span_bp)))
	var font := get_theme_default_font()
	var font_size := maxi(10, get_theme_default_font_size() - 2)
	var span := maxi(1, view_end - offset)
	var tick_step := _axis_tick_step(float(span))
	var baseline := axis_rect.position.y + axis_rect.size.y + font_size + 1.0
	var segments: Array = _genome.get("segments", [])
	if segments.is_empty():
		var first_tick := int(floor(float(offset) / float(tick_step)) * tick_step)
		var tick := first_tick
		while tick <= view_end:
			if tick >= offset and tick <= genome_len:
				var x := axis_rect.position.x + (float(tick - offset) / _view_span_bp) * axis_rect.size.x
				draw_line(Vector2(x, axis_rect.position.y + axis_rect.size.y - 3.0), Vector2(x, axis_rect.position.y + axis_rect.size.y + 2.0), _theme_colors["text_muted"], 1.0)
				var label := _format_bp_label(tick + 1)
				var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				draw_string(font, Vector2(x - label_w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
			tick += tick_step
		return
	for segment_any in segments:
		var segment: Dictionary = segment_any
		var seg_start := int(segment.get("start", 0))
		var seg_end := int(segment.get("end", 0))
		if seg_end <= offset or seg_start >= view_end:
			continue
		if seg_start >= offset and seg_start <= view_end:
			var start_x := axis_rect.position.x + (float(seg_start - offset) / _view_span_bp) * axis_rect.size.x
			draw_line(Vector2(start_x, axis_rect.position.y + axis_rect.size.y - 3.0), Vector2(start_x, axis_rect.position.y + axis_rect.size.y + 2.0), _theme_colors["text_muted"], 1.0)
			var start_label := _format_bp_label(1)
			var start_label_w := font.get_string_size(start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(start_x - start_label_w * 0.5, baseline), start_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
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
				var x := axis_rect.position.x + (float(tick_bp - offset) / _view_span_bp) * axis_rect.size.x
				draw_line(Vector2(x, axis_rect.position.y + axis_rect.size.y - 3.0), Vector2(x, axis_rect.position.y + axis_rect.size.y + 2.0), _theme_colors["text_muted"], 1.0)
				var label := _format_bp_label(local_tick + 1)
				var label_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				draw_string(font, Vector2(x - label_w * 0.5, baseline), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors["text_muted"])
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


func _set_offset_from_map(next_offset: float) -> void:
	_syncing = true
	axis_bar.value = next_offset
	_syncing = false
	_offset = next_offset
	queue_redraw()
	emit_signal("offset_changed", _genome_id, next_offset)

func _feature_to_genome_row(feature: Dictionary) -> int:
	var strand := str(feature.get("strand", "")).strip_edges()
	if strand == "+":
		return 0
	if strand == "-":
		return 2
	return 1

func _genome_feature_row_center_y(row_rect: Rect2, row: int) -> float:
	match row:
		0:
			return row_rect.position.y - FEATURE_H * 0.55 - FEATURE_ROW_GAP
		1:
			return row_rect.position.y - FEATURE_H * 1.45 - FEATURE_ROW_GAP - 3.0
		_:
			if bottom_spacer != null:
				return bottom_spacer.position.y + bottom_spacer.size.y - FEATURE_H * 0.5 - 3.0
			return row_rect.position.y + row_rect.size.y + FEATURE_H * 0.5 + 14.0

func _is_hidden_full_length_region(feature: Dictionary, genome_len: int) -> bool:
	var feature_type := str(feature.get("type", "")).to_lower()
	if feature_type != "region" and feature_type != "source":
		return false
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", 0))
	return start_bp <= 0 and end_bp >= genome_len

func _feature_annotation_label(feature: Dictionary, max_width: float, font: Font, font_size: int) -> String:
	if max_width <= 0.0:
		return ""
	var label_name := str(feature.get("name", "")).strip_edges()
	var feature_id := str(feature.get("id", "")).strip_edges()
	if label_name.is_empty():
		label_name = str(feature.get("type", "")).strip_edges()
	if label_name.is_empty() and feature_id.is_empty():
		return ""
	if feature_id.is_empty() or feature_id == label_name:
		return _truncate_label_to_width(label_name, max_width, 6, font, font_size)
	var combined := "%s / %s" % [label_name, feature_id]
	if font.get_string_size(combined, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return combined
	return _truncate_label_to_width(label_name, max_width, 6, font, font_size)

func _truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
	if text.is_empty() or max_width <= 0.0:
		return ""
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
		return text
	var ellipsis := "..."
	var n := text.length()
	var min_n := mini(maxi(1, min_chars), n)
	if font.get_string_size(text.substr(0, min_n) + ellipsis, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_width:
		return ""
	var lo := min_n
	var hi := n
	var best := min_n
	while lo <= hi:
		var mid := lo + ((hi - lo) >> 1)
		var candidate := text.substr(0, mid) + ellipsis
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= max_width:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return text.substr(0, best) + ellipsis

func _intersects_any(rect: Rect2, existing: Array) -> bool:
	for rect_any in existing:
		var other: Rect2 = rect_any
		if other.intersects(rect):
			return true
	return false

func _text_baseline_for_center(center_y: float, font: Font, font_size: int) -> float:
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return center_y + (ascent - descent) * 0.5

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


func _draw_rect_local(_target, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	if filled:
		draw_rect(rect, color, true)
	else:
		draw_rect(rect, color, false, width)


func _draw_string_local(_target, font: Font, pos: Vector2, text: String, align: int, max_width: float, font_size: int, color: Color) -> void:
	draw_string(font, pos, text, align, max_width, font_size, color)

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
