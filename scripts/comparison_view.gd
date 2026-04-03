extends Control
class_name ComparisonView

const SVGCanvasScript = preload("res://scripts/svg_canvas.gd")
const MAGRATHEA_FONT := preload("res://fonts/magrathea.ttf")

signal genome_order_changed(order: PackedInt32Array)
signal viewport_changed(visible_span_bp: int)
signal comparison_match_selected(match: Dictionary, was_double_click: bool)
signal comparison_match_cleared()
signal comparison_feature_selected(feature: Dictionary, was_double_click: bool)
signal comparison_region_selected(selection: Dictionary)
signal comparison_region_cleared()
signal detail_requested(request: Dictionary)
signal ui_sound_requested(sound_id: String)

const ROW_SCENE = preload("res://scenes/ComparisonGenomeRow.tscn")
const ROW_H := 96.0
const TOP_PAD := 6.0
const BOTTOM_PAD := 2.0
const MIN_MATCH_BAND_H := 40.0
const DETAIL_MATCH_BAND_H := 18.0
const MATCH_PAD_Y := 2.0
const LOCK_BTN_SIZE := Vector2(30.0, 30.0)
const LOCK_BTN_X := 18.0
const MIN_VIEW_SPAN_BP := 50.0
const DEFAULT_VIEW_SPAN_BP := 10000.0
const DETAIL_MAX_BLOCKS_PER_PAIR := 24
const REGION_SELECT_DRAG_THRESHOLD_PX := 6.0

var _genomes_by_id := {}
var _order := PackedInt32Array()
var _offsets := {}
var _pair_blocks := {}
var _detail_blocks := {}
var _reference_slices := {}
var _detail_request_pending := false
var _colorize_nucleotides := true
var _sequence_letter_font_name := "Anonymous Pro"
var _rows := {}
var _lock_buttons := {}
var _pair_locks := {}
var _drawn_match_hitboxes := []
var _selected_match_key := ""
var _hovered_match_key := ""
var _selected_feature_key := ""
var _pending_click_serial := 0
var _pending_click_payload: Dictionary = {}
var _drag_active := false
var _drag_genome_id := -1
var _drag_target_index := -1
var _region_select_pending := false
var _region_select_pending_genome_id := -1
var _region_select_pending_edge := 0.0
var _region_select_pending_start_point := Vector2.ZERO
var _region_select_dragging := false
var _region_select_has_selection := false
var _region_select_genome_id := -1
var _region_select_start_edge := 0.0
var _region_select_end_edge := 0.0
var _view_span_bp := DEFAULT_VIEW_SPAN_BP
var _syncing_offsets := false
var _max_draw_blocks_per_pair := 500
var _min_block_len_bp := 0
var _max_block_len_bp := 0
var _min_percent_identity := 0.0
var _max_percent_identity := 100.0
var _post_layout_refresh_pending := false
var _pan_tween: Tween = null
var _zoom_tween: Tween = null
var _trackpad_pan_sensitivity := 1.0
var _trackpad_pinch_sensitivity := 1.0
var _vertical_swipe_zoom_enabled := true
var _mouse_wheel_zoom_sensitivity := 1.0
var _invert_mouse_wheel_zoom := false
var _mouse_wheel_pan_sensitivity := 1.0
var _loading_message := ""
var _last_ui_sound_ms := {}
var _theme_colors := {
	"text": Color.BLACK,
	"text_muted": Color("666666"),
	"border": Color("aaaaaa"),
	"panel_alt": Color("efefef"),
	"genome": Color("3f5a7a"),
	"feature": Color("dce8f7"),
	"feature_text": Color("1e3557"),
	"same_strand": Color("cb4934"),
	"opp_strand": Color("2c7fb8"),
	"selected_fill": Color("ffd84d"),
	"selection_outline": Color.BLACK,
	"snp": Color("f59e0b")
}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = false
	mouse_exited.connect(_on_mouse_exited)


func clear_view() -> void:
	for row_any in _rows.values():
		var row = row_any
		if is_instance_valid(row):
			row.queue_free()
	for btn_any in _lock_buttons.values():
		var btn: Button = btn_any
		if is_instance_valid(btn):
			btn.queue_free()
	_rows.clear()
	_lock_buttons.clear()
	_genomes_by_id.clear()
	_order = PackedInt32Array()
	_offsets.clear()
	_pair_blocks.clear()
	_detail_blocks.clear()
	_reference_slices.clear()
	_detail_request_pending = false
	_pair_locks.clear()
	_drawn_match_hitboxes.clear()
	_selected_match_key = ""
	_hovered_match_key = ""
	_selected_feature_key = ""
	_region_select_dragging = false
	_region_select_has_selection = false
	_region_select_genome_id = -1
	_region_select_start_edge = 0.0
	_region_select_end_edge = 0.0
	_pending_click_serial = 0
	_pending_click_payload.clear()
	_drag_active = false
	_drag_genome_id = -1
	_drag_target_index = -1
	_region_select_pending = false
	_region_select_pending_genome_id = -1
	_region_select_pending_edge = 0.0
	_region_select_pending_start_point = Vector2.ZERO
	_view_span_bp = DEFAULT_VIEW_SPAN_BP
	_loading_message = ""
	_post_layout_refresh_pending = false
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	_emit_viewport_changed()
	queue_redraw()

func export_current_view_svg(path: String) -> bool:
	var svg = SVGCanvasScript.new()
	svg.configure(size.x, size.y)
	_draw_to(svg)
	return svg.save(path)


func set_theme_colors(next_colors: Dictionary) -> void:
	for key in next_colors.keys():
		_theme_colors[str(key)] = next_colors[key]
	for row_any in _rows.values():
		var row = row_any
		row.set_theme_colors(_theme_colors)
		row.set_colorize_nucleotides(_colorize_nucleotides)
	for btn_any in _lock_buttons.values():
		var btn: Button = btn_any
		btn.queue_redraw()
	queue_redraw()


func set_loading_message(message: String) -> void:
	_loading_message = message
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


func set_zoom_span_bp(next_span: float) -> void:
	var longest := _longest_genome_len()
	var max_span := maxf(MIN_VIEW_SPAN_BP, longest)
	_view_span_bp = clampf(next_span, MIN_VIEW_SPAN_BP, max_span)
	for genome_id in _order:
		var row = _rows.get(int(genome_id))
		if row == null:
			continue
		var genome_len := float(_genomes_by_id.get(int(genome_id), {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		var next_offset := clampf(float(_offsets.get(int(genome_id), 0.0)), 0.0, max_offset)
		_offsets[int(genome_id)] = next_offset
		row.set_view_span_bp(_view_span_bp)
		row.set_view_offset(next_offset)
		var slice_data: Dictionary = _reference_slices.get(int(genome_id), {})
		if not slice_data.is_empty():
			row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
	_schedule_detail_request()
	_emit_viewport_changed()
	queue_redraw()


func reset_view_to_full_genomes() -> void:
	var longest := _longest_genome_len()
	if longest <= 0.0:
		return
	_view_span_bp = maxf(MIN_VIEW_SPAN_BP, longest)
	for genome_id in _order:
		_offsets[int(genome_id)] = 0.0
		var row = _rows.get(int(genome_id))
		if row == null:
			continue
		row.set_view_span_bp(_view_span_bp)
		row.set_view_offset(0.0)
		row.clear_reference_slice()
	_reference_slices.clear()
	_schedule_detail_request()
	_emit_viewport_changed()
	queue_redraw()


func zoom_by(factor: float) -> void:
	if factor <= 0.0:
		return
	var anchor_x := _default_anchor_x()
	_animate_zoom_to_span(_view_span_bp * factor, anchor_x)


func zoom_by_at_x(factor: float, anchor_x: float, duration: float = 0.12) -> void:
	if factor <= 0.0:
		return
	_animate_zoom_to_span(_view_span_bp * factor, anchor_x, duration)


func pan_all_by_fraction(fraction: float) -> void:
	if absf(fraction) < 0.000001:
		return
	var targets := {}
	for genome_id in _order:
		var genome_len := float(_genomes_by_id.get(int(genome_id), {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		var next_offset := clampf(float(_offsets.get(int(genome_id), 0.0)) + _view_span_bp * fraction, 0.0, max_offset)
		targets[int(genome_id)] = next_offset
	_animate_offsets_to(targets)


func move_all_to_boundary(at_end: bool) -> void:
	var targets := {}
	for genome_id in _order:
		var genome_len := float(_genomes_by_id.get(int(genome_id), {}).get("length", 0))
		var next_offset := maxf(0.0, genome_len - _view_span_bp) if at_end else 0.0
		targets[int(genome_id)] = next_offset
	_animate_offsets_to(targets)

func select_feature(genome_id: int, feature: Dictionary) -> void:
	_select_feature_in_rows(genome_id, feature)

func clear_selected_feature() -> void:
	_selected_feature_key = ""
	for row_any in _rows.values():
		var row = row_any
		if row != null and row.has_method("clear_selected_feature"):
			row.clear_selected_feature()

func focus_genome_range(genome_id: int, start_bp: int, end_bp: int) -> void:
	if not _genomes_by_id.has(genome_id):
		return
	var genome_len := float(_genomes_by_id.get(genome_id, {}).get("length", 0))
	if genome_len <= 0.0:
		return
	var center_bp := 0.5 * float(start_bp + maxi(start_bp + 1, end_bp))
	var max_offset := maxf(0.0, genome_len - _view_span_bp)
	var next_offset := clampf(center_bp - _view_span_bp * 0.5, 0.0, max_offset)
	_animate_offsets_to(_targets_with_locked_propagation({genome_id: next_offset}))

func focus_genome_range_with_zoom(genome_id: int, start_bp: int, end_bp: int) -> void:
	if not _genomes_by_id.has(genome_id):
		return
	var span_bp := maxi(1, end_bp - start_bp)
	set_zoom_span_bp(float(span_bp))
	focus_genome_range(genome_id, start_bp, end_bp)

func _select_feature_in_rows(genome_id: int, feature: Dictionary) -> void:
	_selected_feature_key = _feature_key(feature)
	for row_id_any in _rows.keys():
		var row_id := int(row_id_any)
		var row = _rows.get(row_id)
		if row == null:
			continue
		if row_id == genome_id:
			row.set_selected_feature_key(_selected_feature_key)
		else:
			row.clear_selected_feature()

func _feature_key(feature: Dictionary) -> String:
	if feature.is_empty():
		return ""
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", start_bp))
	var seq_name := str(feature.get("seq_name", ""))
	var feat_name := str(feature.get("name", ""))
	var ftype := str(feature.get("type", ""))
	return "%s|%d|%d|%s|%s" % [seq_name, start_bp, end_bp, feat_name, ftype]


func set_max_draw_blocks_per_pair(value: int) -> void:
	_max_draw_blocks_per_pair = maxi(1, value)
	queue_redraw()


func set_block_filters(min_block_len_bp: int, max_block_len_bp: int, min_percent_identity: float, max_percent_identity: float) -> void:
	_min_block_len_bp = maxi(0, min_block_len_bp)
	_max_block_len_bp = maxi(0, max_block_len_bp)
	_min_percent_identity = clampf(min_percent_identity, 0.0, 100.0)
	_max_percent_identity = clampf(max_percent_identity, 0.0, 100.0)
	if _max_percent_identity < _min_percent_identity:
		_max_percent_identity = _min_percent_identity
	queue_redraw()


func set_genomes(genomes: Array) -> void:
	var had_no_genomes := _order.is_empty()
	var next_by_id := {}
	var next_order := PackedInt32Array()
	for genome_any in genomes:
		var genome: Dictionary = genome_any
		var genome_id := int(genome.get("id", -1))
		if genome_id < 0:
			continue
		next_by_id[genome_id] = genome.duplicate(true)
		if not _offsets.has(genome_id):
			_offsets[genome_id] = 0.0
	if not _order.is_empty():
		for genome_id in _order:
			if next_by_id.has(int(genome_id)):
				next_order.append(int(genome_id))
	for genome_id_any in next_by_id.keys():
		var genome_id := int(genome_id_any)
		if next_order.has(genome_id):
			continue
		next_order.append(genome_id)
	_genomes_by_id = next_by_id
	var valid_offsets := {}
	for genome_id in next_order:
		valid_offsets[int(genome_id)] = _offsets.get(int(genome_id), 0.0)
	_offsets = valid_offsets
	_order = next_order
	_sync_row_instances()
	if had_no_genomes and not _order.is_empty():
		reset_view_to_full_genomes()
	_layout_rows_and_locks()
	_schedule_post_layout_refresh()
	_schedule_detail_request()
	emit_signal("genome_order_changed", _order)
	_emit_viewport_changed()
	queue_redraw()


func set_pair_blocks(query_genome_id: int, target_genome_id: int, blocks: Array) -> void:
	var key := _pair_key(query_genome_id, target_genome_id)
	_pair_blocks[key] = {
		"query_id": query_genome_id,
		"target_id": target_genome_id,
		"blocks": blocks.duplicate(true)
	}
	_schedule_detail_request()
	queue_redraw()

func set_colorize_nucleotides(enabled: bool) -> void:
	_colorize_nucleotides = enabled
	for row_any in _rows.values():
		var row = row_any
		row.set_colorize_nucleotides(enabled)
	queue_redraw()

func set_sequence_letter_font_name(font_name: String) -> void:
	_sequence_letter_font_name = font_name
	for row_any in _rows.values():
		var row = row_any
		if row != null and row.has_method("set_sequence_letter_font_name"):
			row.set_sequence_letter_font_name(font_name)
	queue_redraw()

func set_reference_slice(genome_id: int, slice_data: Dictionary) -> void:
	_reference_slices[genome_id] = slice_data.duplicate(true)
	var row = _rows.get(genome_id)
	if row != null:
		row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))

func set_block_detail(query_genome_id: int, target_genome_id: int, block: Dictionary, detail: Dictionary) -> void:
	_detail_blocks[_detail_block_key(query_genome_id, target_genome_id, block)] = detail.duplicate(true)
	queue_redraw()


func pair_cached(query_genome_id: int, target_genome_id: int) -> bool:
	var payload: Dictionary = _pair_blocks.get(_pair_key(query_genome_id, target_genome_id), {})
	if payload.is_empty():
		return false
	return not (payload.get("blocks", []) as Array).is_empty()


func get_order() -> PackedInt32Array:
	return _order

func get_visible_span_bp() -> int:
	return int(round(_view_span_bp))

func get_view_slot_state() -> Dictionary:
	var offsets: Dictionary = {}
	for genome_id_any in _order:
		var genome_id := int(genome_id_any)
		offsets[genome_id] = float(_offsets.get(genome_id, 0.0))
	return {
		"order": _order,
		"view_span_bp": _view_span_bp,
		"offsets": offsets
	}

func apply_view_slot_state(state: Dictionary) -> void:
	if state.is_empty():
		return
	var order_any: Variant = state.get("order", PackedInt32Array())
	var saved_order := PackedInt32Array()
	if order_any is PackedInt32Array:
		saved_order = order_any
	elif order_any is Array:
		for genome_id_any in order_any:
			saved_order.append(int(genome_id_any))
	var next_order := PackedInt32Array()
	for genome_id in saved_order:
		if _genomes_by_id.has(int(genome_id)) and not next_order.has(int(genome_id)):
			next_order.append(int(genome_id))
	for genome_id_any in _genomes_by_id.keys():
		var genome_id := int(genome_id_any)
		if not next_order.has(genome_id):
			next_order.append(genome_id)
	_order = next_order
	var offsets_any: Variant = state.get("offsets", {})
	var offsets_dict: Dictionary = offsets_any if typeof(offsets_any) == TYPE_DICTIONARY else {}
	var next_span := float(state.get("view_span_bp", _view_span_bp))
	var longest := _longest_genome_len()
	_view_span_bp = clampf(next_span, MIN_VIEW_SPAN_BP, maxf(MIN_VIEW_SPAN_BP, longest))
	for genome_id_any in _order:
		var genome_id := int(genome_id_any)
		var genome_len := float(_genomes_by_id.get(genome_id, {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		_offsets[genome_id] = clampf(float(offsets_dict.get(genome_id, 0.0)), 0.0, max_offset)
	_sync_row_instances()
	_layout_rows_and_locks()
	_schedule_post_layout_refresh()
	_schedule_detail_request()
	_emit_viewport_changed()
	queue_redraw()

func _emit_viewport_changed() -> void:
	emit_signal("viewport_changed", int(round(_view_span_bp)))


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout_rows_and_locks()
		_schedule_post_layout_refresh()
		queue_redraw()


func _input(event: InputEvent) -> void:
	if visible and not _event_over_overlay_panel(event) and event is InputEventMouseButton:
		var mb_feature := event as InputEventMouseButton
		if mb_feature.button_index == MOUSE_BUTTON_LEFT and mb_feature.pressed:
			var local_feature_point := _local_input_point(mb_feature.position)
			var feature_hit := _hit_test_feature(local_feature_point)
			if not feature_hit.is_empty():
				_on_row_feature_clicked(int(feature_hit.get("genome_id", -1)), feature_hit.get("feature", {}), mb_feature.double_click)
				accept_event()
				return
	if not visible:
		return
	if _event_over_overlay_panel(event):
		return
	if event is InputEventMouseButton and event.pressed and (
		event.button_index == MOUSE_BUTTON_WHEEL_UP
		or event.button_index == MOUSE_BUTTON_WHEEL_DOWN
		or event.button_index == MOUSE_BUTTON_WHEEL_LEFT
		or event.button_index == MOUSE_BUTTON_WHEEL_RIGHT
	):
		var wheel_event := event as InputEventMouseButton
		var local_wheel_point := _local_input_point(wheel_event.position)
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
			pan_all_by_fraction(pan_sign * 0.12 * _mouse_wheel_pan_sensitivity)
			_emit_ui_sound_throttled("pan_left" if pan_sign < 0.0 else "pan_right", 130)
			accept_event()
			return
		var zoom_in := wheel_event.button_index == MOUSE_BUTTON_WHEEL_UP
		if _invert_mouse_wheel_zoom:
			zoom_in = not zoom_in
		var wheel_factor := 0.88 if zoom_in else 1.14
		var scaled_factor := pow(wheel_factor, _mouse_wheel_zoom_sensitivity)
		zoom_by_at_x(scaled_factor, local_wheel_point.x, 0.12)
		_emit_ui_sound_throttled("zoom_in" if zoom_in else "zoom_out", 130)
		accept_event()
		return
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		var local_pan_point := _local_input_point(pan_event.position)
		if _vertical_swipe_zoom_enabled and absf(pan_event.delta.y) > absf(pan_event.delta.x) and absf(pan_event.delta.y) > 0.0:
			var zoom_in := pan_event.delta.y < 0.0
			if _invert_mouse_wheel_zoom:
				zoom_in = not zoom_in
			var gesture_factor := 0.88 if zoom_in else 1.14
			var scaled_factor := pow(gesture_factor, absf(pan_event.delta.y) * _mouse_wheel_zoom_sensitivity)
			zoom_by_at_x(scaled_factor, local_pan_point.x, 0.12)
			_emit_ui_sound_throttled("zoom_in" if zoom_in else "zoom_out", 130)
			accept_event()
			return
		elif absf(pan_event.delta.x) > 0.0:
			_pan_all_by_pixels(pan_event.delta.x * _trackpad_pan_sensitivity * 3.0, false)
			_emit_ui_sound_throttled("pan_left" if pan_event.delta.x < 0.0 else "pan_right", 130)
			accept_event()
			return
	elif event is InputEventMagnifyGesture:
		var magnify_event := event as InputEventMagnifyGesture
		if magnify_event.factor > 0.0:
			var scaled_factor := pow(magnify_event.factor, _trackpad_pinch_sensitivity)
			scaled_factor = maxf(0.05, scaled_factor)
			var local_magnify_point := _local_input_point(get_viewport().get_mouse_position())
			zoom_by_at_x(1.0 / scaled_factor, local_magnify_point.x, 0.12)
			_emit_ui_sound_throttled("zoom_in" if magnify_event.factor > 1.0 else "zoom_out", 130)
			accept_event()
			return
	if event is InputEventMouseMotion:
		if _region_select_pending:
			var local_motion_pending := _local_input_point((event as InputEventMouseMotion).position)
			if local_motion_pending.distance_to(_region_select_pending_start_point) >= REGION_SELECT_DRAG_THRESHOLD_PX:
				_start_region_selection(_region_select_pending_genome_id, _region_select_pending_edge)
				_update_region_selection_drag(local_motion_pending)
			accept_event()
			return
		if _region_select_dragging:
			var local_motion := _local_input_point((event as InputEventMouseMotion).position)
			_update_region_selection_drag(local_motion)
			accept_event()
			return
		if not _drag_active:
			return
		_drag_target_index = _row_index_for_y(get_local_mouse_position().y)
		queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _region_select_pending:
			_cancel_pending_region_selection()
			accept_event()
			return
		if _region_select_dragging:
			var local_release := _local_input_point((event as InputEventMouseButton).position)
			_finish_region_selection_drag(local_release)
			accept_event()
			return
	if not _drag_active:
		return
	_finish_row_drag(_drag_target_index)


func _emit_ui_sound_throttled(sound_id: String, min_interval_ms: int) -> void:
	var now_ms := Time.get_ticks_msec()
	var last_ms := int(_last_ui_sound_ms.get(sound_id, -1000000))
	if now_ms - last_ms < min_interval_ms:
		return
	_last_ui_sound_ms[sound_id] = now_ms
	emit_signal("ui_sound_requested", sound_id)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if _event_over_overlay_panel(event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		var mb := event as InputEventMouseButton
		_cancel_pending_region_selection()
		var feature_hit := _hit_test_feature(mb.position)
		if not feature_hit.is_empty():
			_on_row_feature_clicked(int(feature_hit.get("genome_id", -1)), feature_hit.get("feature", {}), true)
			accept_event()
			return
		var hit := _hit_test_match(mb.position)
		if hit.is_empty():
			return
		var payload: Dictionary = hit.get("payload", {})
		_selected_match_key = _match_key_for_payload(payload)
		_cancel_pending_click_dispatch()
		queue_redraw()
		emit_signal("comparison_match_selected", payload, true)
		_focus_match_left(payload)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mb := event as InputEventMouseButton
		var feature_hit := _hit_test_feature(mb.position)
		if not feature_hit.is_empty():
			_on_row_feature_clicked(int(feature_hit.get("genome_id", -1)), feature_hit.get("feature", {}), false)
			accept_event()
			return
		var hit := _hit_test_match(mb.position)
		if hit.is_empty():
			if not _selected_match_key.is_empty():
				_selected_match_key = ""
				_cancel_pending_click_dispatch()
				queue_redraw()
				emit_signal("comparison_match_cleared")
			var row_hit := _row_hit_for_point(mb.position)
			if row_hit.is_empty():
				_clear_region_selection(true)
				return
			_begin_pending_region_selection(int(row_hit.get("genome_id", -1)), float(row_hit.get("bp", 0.0)), mb.position)
			accept_event()
			return
		var payload: Dictionary = hit.get("payload", {})
		_selected_match_key = _match_key_for_payload(payload)
		queue_redraw()
		_schedule_single_click_dispatch(payload)
		accept_event()
	elif event is InputEventMouseMotion:
		if _drag_active or _region_select_pending or _region_select_dragging:
			return
		var motion := event as InputEventMouseMotion
		var hover_hit := _hit_test_match(motion.position)
		var next_hover_key := ""
		if not hover_hit.is_empty():
			next_hover_key = _match_key_for_payload(hover_hit.get("payload", {}))
		if next_hover_key != _hovered_match_key:
			_hovered_match_key = next_hover_key
			queue_redraw()

func _hit_test_feature(point_parent: Vector2) -> Dictionary:
	for genome_id_any in _order:
		var genome_id := int(genome_id_any)
		var row = _rows.get(genome_id)
		if row == null or not row.has_method("hit_test_feature_in_parent"):
			continue
		var hit: Dictionary = row.hit_test_feature_in_parent(point_parent)
		if not hit.is_empty():
			return hit
	return {}


func _on_mouse_exited() -> void:
	if _hovered_match_key.is_empty():
		return
	_hovered_match_key = ""
	queue_redraw()


func _event_over_overlay_panel(event: InputEvent) -> bool:
	var parent_ctrl := get_parent() as Control
	if parent_ctrl == null:
		return false
	for panel_name in ["SettingsPanel", "FeaturePanel"]:
		var panel := parent_ctrl.get_node_or_null(panel_name) as Control
		if panel == null or not panel.visible:
			continue
		var point := Vector2.ZERO
		var has_point := true
		if event is InputEventMouseButton:
			point = (event as InputEventMouseButton).position
		elif event is InputEventPanGesture:
			point = (event as InputEventPanGesture).position
		elif event is InputEventMouseMotion:
			point = (event as InputEventMouseMotion).position
		elif event is InputEventMagnifyGesture:
			point = get_viewport().get_mouse_position()
		else:
			has_point = false
		if has_point and panel.get_global_rect().has_point(point):
			return true
	return false


func _draw() -> void:
	_draw_to(self)

func _draw_to(target) -> void:
	if target == self:
		_drawn_match_hitboxes.clear()
	else:
		_draw_rect_on(target, Rect2(Vector2.ZERO, size), _theme_colors.get("panel_alt", Color.WHITE), true)
	for idx in range(_order.size() - 1):
		var top_id := int(_order[idx])
		var bottom_id := int(_order[idx + 1])
		var top_row = _rows.get(top_id)
		var bottom_row = _rows.get(bottom_id)
		if top_row == null or bottom_row == null:
			continue
		var top_axis: Rect2 = top_row.get_axis_rect_in_parent()
		var bottom_axis: Rect2 = bottom_row.get_axis_rect_in_parent()
		var x_min := maxf(top_axis.position.x, bottom_axis.position.x)
		var x_max := minf(top_axis.position.x + top_axis.size.x, bottom_axis.position.x + bottom_axis.size.x)
		if x_max <= x_min:
			continue
		var top_y: float = top_row.get_match_band_bottom_in_parent() + MATCH_PAD_Y
		var bottom_y: float = bottom_row.get_match_band_top_in_parent() - MATCH_PAD_Y
		var detail_top_y: float = top_row.get_detail_anchor_y_in_parent()
		var detail_bottom_y: float = bottom_row.get_detail_anchor_y_in_parent()
		if bottom_y <= top_y:
			continue
		var visible_blocks: Array = _display_blocks_for_pair(top_id, bottom_id)
		var selected_blocks: Array = []
		for block_any in visible_blocks:
			var block: Dictionary = block_any
			if _match_key_for_display_block(block, top_id, bottom_id) == _selected_match_key:
				selected_blocks.append(block)
				continue
			_draw_pair_block(target, block, top_id, bottom_id, top_row, bottom_row, top_axis, bottom_axis, top_y, bottom_y, detail_top_y, detail_bottom_y, x_min, x_max)
		for selected_block_any in selected_blocks:
			var selected_block: Dictionary = selected_block_any
			_draw_pair_block(target, selected_block, top_id, bottom_id, top_row, bottom_row, top_axis, bottom_axis, top_y, bottom_y, detail_top_y, detail_bottom_y, x_min, x_max)
	for genome_id_any in _order:
		var row = _rows.get(int(genome_id_any))
		if row != null and row.has_method("export_to"):
			row.export_to(target)
	if target == self:
		_draw_empty_state_prompt()
		_draw_drag_indicator()
		_draw_loading_overlay()


func _draw_pair_block(target, block: Dictionary, top_id: int, bottom_id: int, top_row, bottom_row, top_axis: Rect2, bottom_axis: Rect2, top_y: float, bottom_y: float, detail_top_y: float, detail_bottom_y: float, x_min: float, x_max: float) -> void:
	if _detail_mode_active() and _has_block_detail(top_id, bottom_id, block):
		var detail: Dictionary = _detail_blocks.get(_detail_block_key(top_id, bottom_id, block), {})
		var display_block := _aligned_block_from_detail(block, detail)
		var detail_fill := _block_color(display_block, top_id, bottom_id)
		if bool(display_block.get("same_strand", true)):
			var detail_poly := _project_block_polygon_for_rows(display_block, top_row, bottom_row, top_y, bottom_y, 0.5)
			if not detail_poly.is_empty():
				detail_poly = _clip_polygon_x(detail_poly, x_min, x_max)
				if detail_poly.size() >= 3 and _polygon_area_abs(detail_poly) > 0.25:
					_draw_colored_polygon_on(target, detail_poly, detail_fill)
					var detail_closed := detail_poly.duplicate()
					detail_closed.append(detail_closed[0])
					_draw_polyline_on(target, detail_closed, detail_fill.darkened(0.18), 1.0)
					if target == self:
						_register_match_hitbox(display_block, top_id, bottom_id, detail_poly)
					if _match_is_emphasized(_match_key_for_display_block(display_block, top_id, bottom_id)):
						_draw_polyline_on(target, detail_closed, _theme_colors["selection_outline"], 2.0)
		else:
			_draw_reverse_block(target, display_block, top_id, bottom_id, float(_offsets.get(top_id, 0.0)), float(_offsets.get(bottom_id, 0.0)), top_axis, bottom_axis, top_y, bottom_y, x_min, x_max, detail_fill, 0.5)
		_draw_detail_block(target, block, top_id, bottom_id, top_axis, bottom_axis, detail_top_y, detail_bottom_y)
		return
	var fill := _block_color(block, top_id, bottom_id)
	if bool(block.get("same_strand", true)):
		var poly := _project_block_polygon_for_rows(block, top_row, bottom_row, top_y, bottom_y)
		if poly.is_empty():
			return
		poly = _clip_polygon_x(poly, x_min, x_max)
		if poly.size() < 3 or _polygon_area_abs(poly) <= 0.25:
			return
		_draw_colored_polygon_on(target, poly, fill)
		poly.append(poly[0])
		_draw_polyline_on(target, poly, fill.darkened(0.18), 1.0)
		if target == self:
			_register_match_hitbox(block, top_id, bottom_id, poly.slice(0, poly.size() - 1))
		if _match_is_emphasized(_match_key_for_display_block(block, top_id, bottom_id)):
			_draw_polyline_on(target, poly, _theme_colors["selection_outline"], 2.0)
	else:
		_draw_reverse_block(target, block, top_id, bottom_id, float(_offsets.get(top_id, 0.0)), float(_offsets.get(bottom_id, 0.0)), top_axis, bottom_axis, top_y, bottom_y, x_min, x_max, fill)


func _sync_row_instances() -> void:
	var keep := {}
	for genome_id in _order:
		var genome: Dictionary = _genomes_by_id.get(int(genome_id), {})
		var row = _rows.get(int(genome_id))
		if row == null:
			row = ROW_SCENE.instantiate()
		if not row.drag_started.is_connected(_on_row_drag_started):
			row.drag_started.connect(_on_row_drag_started)
		if not row.offset_changed.is_connected(_on_row_offset_changed):
			row.offset_changed.connect(_on_row_offset_changed)
		if not row.pan_step_requested.is_connected(_on_row_pan_step_requested):
			row.pan_step_requested.connect(_on_row_pan_step_requested)
		if not row.feature_clicked.is_connected(_on_row_feature_clicked):
			row.feature_clicked.connect(_on_row_feature_clicked)
		if not row.axis_center_requested.is_connected(_on_row_axis_center_requested):
			row.axis_center_requested.connect(_on_row_axis_center_requested)
		if row.get_parent() != self:
			add_child(row)
		row.visible = true
		row.set_theme_colors(_theme_colors)
		row.set_colorize_nucleotides(_colorize_nucleotides)
		if row.has_method("set_sequence_letter_font_name"):
			row.set_sequence_letter_font_name(_sequence_letter_font_name)
		row.configure_row(genome, float(_offsets.get(int(genome_id), 0.0)), _view_span_bp)
		var slice_data: Dictionary = _reference_slices.get(int(genome_id), {})
		if not slice_data.is_empty():
			row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
		_rows[int(genome_id)] = row
		keep[int(genome_id)] = true
	for genome_id_any in _rows.keys():
		var genome_id := int(genome_id_any)
		if keep.has(genome_id):
			continue
		var row = _rows[genome_id]
		row.queue_free()
		_rows.erase(genome_id)
	_cleanup_lock_buttons()


func _layout_rows_and_locks() -> void:
	if _order.is_empty():
		return
	var match_band_h := _match_band_height()
	for i in range(_order.size()):
		var genome_id := int(_order[i])
		var row = _rows.get(genome_id)
		if row == null:
			continue
		row.position = Vector2(0.0, TOP_PAD + i * (ROW_H + match_band_h))
		row.size = Vector2(size.x, ROW_H)
		row.set_view_span_bp(_view_span_bp)
		row.set_view_offset(float(_offsets.get(genome_id, 0.0)))
	_update_lock_buttons(match_band_h)


func _schedule_post_layout_refresh() -> void:
	if _post_layout_refresh_pending:
		return
	_post_layout_refresh_pending = true
	call_deferred("_apply_post_layout_refresh")


func _apply_post_layout_refresh() -> void:
	_post_layout_refresh_pending = false
	for genome_id in _order:
		var row = _rows.get(int(genome_id))
		if row == null:
			continue
		row.set_view_span_bp(_view_span_bp)
		row.set_view_offset(float(_offsets.get(int(genome_id), 0.0)))
		var slice_data: Dictionary = _reference_slices.get(int(genome_id), {})
		if not slice_data.is_empty():
			row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
	_schedule_detail_request()
	queue_redraw()


func _animate_offsets_to(targets: Dictionary, duration: float = 0.22) -> void:
	if targets.is_empty():
		return
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	if _pan_tween != null:
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_SINE)
	_pan_tween.set_ease(Tween.EASE_OUT)
	for genome_id_any in targets.keys():
		var genome_id := int(genome_id_any)
		var start_offset := float(_offsets.get(genome_id, 0.0))
		var end_offset := float(targets[genome_id_any])
		_pan_tween.parallel().tween_method(func(v: float) -> void:
			_set_row_offset_animated(genome_id, v)
		, start_offset, end_offset, duration)
	_pan_tween.finished.connect(func() -> void:
		_pan_tween = null
	)


func _set_row_offset_animated(genome_id: int, value: float) -> void:
	_offsets[genome_id] = value
	var row = _rows.get(genome_id)
	if row != null:
		row.set_view_offset(value)
		var slice_data: Dictionary = _reference_slices.get(genome_id, {})
		if not slice_data.is_empty():
			row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
	_schedule_detail_request()
	queue_redraw()


func _register_match_hitbox(block: Dictionary, top_genome_id: int, bottom_genome_id: int, poly: PackedVector2Array) -> void:
	var bounds := _polygon_bounds(poly)
	var payload := _payload_for_block(block, top_genome_id, bottom_genome_id)
	_drawn_match_hitboxes.append({
		"bounds": bounds,
		"poly": poly,
		"payload": payload
	})


func _hit_test_match(point: Vector2) -> Dictionary:
	for i in range(_drawn_match_hitboxes.size() - 1, -1, -1):
		var hit: Dictionary = _drawn_match_hitboxes[i]
		var bounds: Rect2 = hit.get("bounds", Rect2())
		if not bounds.has_point(point):
			continue
		var poly: PackedVector2Array = hit.get("poly", PackedVector2Array())
		if Geometry2D.is_point_in_polygon(point, poly):
			return hit
	return {}


func _polygon_bounds(poly: PackedVector2Array) -> Rect2:
	if poly.is_empty():
		return Rect2()
	var min_x := poly[0].x
	var max_x := poly[0].x
	var min_y := poly[0].y
	var max_y := poly[0].y
	for point in poly:
		min_x = minf(min_x, point.x)
		max_x = maxf(max_x, point.x)
		min_y = minf(min_y, point.y)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y))


func _segment_match_for_interval(genome: Dictionary, start_bp: int, end_bp: int) -> Dictionary:
	var segments: Array = genome.get("segments", [])
	if segments.is_empty():
		return {}
	var interval_start := mini(start_bp, end_bp)
	var interval_end := maxi(start_bp, end_bp)
	var best_seg: Dictionary = {}
	var best_overlap := -1
	for seg_any in segments:
		var seg: Dictionary = seg_any
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", 0))
		var overlap_start := maxi(interval_start, seg_start)
		var overlap_end := mini(interval_end, seg_end)
		var overlap := overlap_end - overlap_start
		if overlap > best_overlap:
			best_overlap = overlap
			best_seg = seg
		elif best_overlap < 0 and start_bp >= seg_start and start_bp < seg_end:
			best_seg = seg
	# Fallback to the first segment spanning the start or midpoint if there was no positive overlap.
	if best_seg.is_empty():
		var probe_points := [start_bp, int(floor((float(interval_start) + float(interval_end)) * 0.5))]
		for probe in probe_points:
			for seg_any in segments:
				var seg: Dictionary = seg_any
				var seg_start := int(seg.get("start", 0))
				var seg_end := int(seg.get("end", 0))
				if probe >= seg_start and probe < seg_end:
					best_seg = seg
					break
			if not best_seg.is_empty():
				break
	if best_seg.is_empty():
		return {}
	var best_start := int(best_seg.get("start", 0))
	var best_end := int(best_seg.get("end", 0))
	var local_start := clampi(interval_start - best_start, 0, maxi(0, best_end-best_start))
	var local_end := clampi(interval_end - best_start, 0, maxi(0, best_end-best_start))
	return {
		"name": str(best_seg.get("name", "")),
		"local_start": local_start,
		"local_end": local_end
	}

func _payload_for_block(block: Dictionary, top_genome_id: int, bottom_genome_id: int) -> Dictionary:
	var top_match := _segment_match_for_interval(_genomes_by_id.get(top_genome_id, {}), int(block.get("query_start", 0)), int(block.get("query_end", 0)))
	var bottom_match := _segment_match_for_interval(_genomes_by_id.get(bottom_genome_id, {}), int(block.get("target_start", 0)), int(block.get("target_end", 0)))
	return {
		"top_genome_id": top_genome_id,
		"bottom_genome_id": bottom_genome_id,
		"query_start": int(block.get("query_start", 0)),
		"query_end": int(block.get("query_end", 0)),
		"target_start": int(block.get("target_start", 0)),
		"target_end": int(block.get("target_end", 0)),
		"percent_identity": float(block.get("percent_identity", 0.0)),
		"percent_identity_x100": int(block.get("percent_identity_x100", 0)),
		"same_strand": bool(block.get("same_strand", true)),
		"top_name": str(_genomes_by_id.get(top_genome_id, {}).get("name", "Genome %d" % top_genome_id)),
		"bottom_name": str(_genomes_by_id.get(bottom_genome_id, {}).get("name", "Genome %d" % bottom_genome_id)),
		"top_contig": str(top_match.get("name", "")),
		"bottom_contig": str(bottom_match.get("name", "")),
		"top_local_start": int(top_match.get("local_start", int(block.get("query_start", 0)))),
		"top_local_end": int(top_match.get("local_end", int(block.get("query_end", 0)))),
		"bottom_local_start": int(bottom_match.get("local_start", int(block.get("target_start", 0)))),
		"bottom_local_end": int(bottom_match.get("local_end", int(block.get("target_end", 0))))
	}


func _schedule_detail_request() -> void:
	if _detail_request_pending:
		return
	_detail_request_pending = true
	call_deferred("_emit_detail_request_if_needed")


func _emit_detail_request_if_needed() -> void:
	_detail_request_pending = false
	if not visible:
		return
	if not _detail_mode_active():
		for row_any in _rows.values():
			var row = row_any
			row.clear_reference_slice()
		return
	var genomes: Array[Dictionary] = []
	var blocks: Array[Dictionary] = []
	for genome_id in _order:
		var genome: Dictionary = _genomes_by_id.get(int(genome_id), {})
		if genome.is_empty():
			continue
		var genome_len := int(genome.get("length", 0))
		var start_bp := clampi(int(floor(float(_offsets.get(int(genome_id), 0.0)))), 0, genome_len)
		var end_bp := clampi(int(ceil(float(_offsets.get(int(genome_id), 0.0)) + _view_span_bp)), 0, genome_len)
		genomes.append({"genome_id": int(genome_id), "start_bp": start_bp, "end_bp": end_bp})
	for idx in range(_order.size() - 1):
		var top_id := int(_order[idx])
		var bottom_id := int(_order[idx + 1])
		var visible_blocks: Array = _display_blocks_for_pair(top_id, bottom_id)
		for i in range(mini(DETAIL_MAX_BLOCKS_PER_PAIR, visible_blocks.size())):
			blocks.append({
				"query_genome_id": top_id,
				"target_genome_id": bottom_id,
				"block": visible_blocks[i].duplicate(true)
			})
	emit_signal("detail_requested", {"genomes": genomes, "blocks": blocks})


func _detail_mode_active() -> bool:
	if _order.is_empty():
		return false
	var row = _rows.get(int(_order[0]))
	if row == null:
		return false
	var axis_rect: Rect2 = row.get_axis_rect_in_parent()
	if axis_rect.size.x <= 0.0 or _view_span_bp <= 0.0:
		return false
	var font := get_theme_default_font()
	var font_size := maxi(11, get_theme_default_font_size())
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if char_px <= 0.0:
		return false
	var pixels_per_bp := axis_rect.size.x / _view_span_bp
	return pixels_per_bp >= maxf(4.0, char_px * 0.45)


func _detail_block_key(query_genome_id: int, target_genome_id: int, block: Dictionary) -> String:
	return "%d:%d:%d:%d:%d:%d:%d" % [
		query_genome_id,
		target_genome_id,
		int(block.get("query_start", 0)),
		int(block.get("query_end", 0)),
		int(block.get("target_start", 0)),
		int(block.get("target_end", 0)),
		1 if bool(block.get("same_strand", true)) else 0
	]


func _has_block_detail(query_genome_id: int, target_genome_id: int, block: Dictionary) -> bool:
	return _detail_blocks.has(_detail_block_key(query_genome_id, target_genome_id, block))


func _aligned_block_from_detail(block: Dictionary, detail: Dictionary) -> Dictionary:
	if detail.is_empty():
		return block
	var ops := str(detail.get("ops", ""))
	if ops.is_empty():
		return block
	var same := bool(detail.get("same_strand", true))
	var query_start := int(detail.get("query_start", block.get("query_start", 0)))
	var target_start := int(detail.get("target_start", block.get("target_start", 0)))
	var target_end := int(detail.get("target_end", block.get("target_end", 0)))
	var q_pos := query_start
	var t_pos := target_start if same else target_end - 1
	for i in range(ops.length()):
		var op := ops.substr(i, 1)
		match op:
			"M", "X":
				q_pos += 1
				t_pos += 1 if same else -1
			"I":
				q_pos += 1
			"D":
				t_pos += 1 if same else -1
	var out := block.duplicate(true)
	out["query_start"] = query_start
	out["query_end"] = q_pos
	if same:
		out["target_start"] = target_start
		out["target_end"] = t_pos
	else:
		out["target_start"] = t_pos + 1
		out["target_end"] = target_end
	return out


func _draw_detail_block(target, block: Dictionary, top_genome_id: int, bottom_genome_id: int, top_axis: Rect2, bottom_axis: Rect2, top_y: float, bottom_y: float) -> void:
	var detail: Dictionary = _detail_blocks.get(_detail_block_key(top_genome_id, bottom_genome_id, block), {})
	if detail.is_empty():
		return
	var ops := str(detail.get("ops", ""))
	if ops.is_empty():
		return
	var top_row = _rows.get(top_genome_id)
	var bottom_row = _rows.get(bottom_genome_id)
	if top_row == null or bottom_row == null:
		return
	var q_pos := int(detail.get("query_start", 0))
	var t_pos := int(detail.get("target_start", 0))
	var same := bool(detail.get("same_strand", true))
	if not same:
		t_pos = int(detail.get("target_end", 0)) - 1
	var match_color: Color = _theme_colors["selection_outline"]
	match_color.a = 1.0
	var snp_color: Color = _theme_colors.get("snp", Color("f59e0b"))
	var line_width := 1.0
	var x_tolerance := 8.0
	var bp_px := minf(_pixels_per_bp(top_axis), _pixels_per_bp(bottom_axis))
	for i in range(ops.length()):
		var op := ops.substr(i, 1)
		match op:
			"M", "X":
				var qx := float(top_row.get_bp_center_x_in_parent(float(q_pos)))
				var tx := float(bottom_row.get_bp_center_x_in_parent(float(t_pos)))
				if _x_within_axis(qx, top_axis, x_tolerance) and _x_within_axis(tx, bottom_axis, x_tolerance):
					var start_pt := Vector2(qx, top_y)
					var end_pt := Vector2(tx, bottom_y)
					if op == "X":
						_draw_snp_connector(target, start_pt, end_pt, snp_color, bp_px)
					else:
						_draw_line_on(target, start_pt, end_pt, match_color, line_width)
				q_pos += 1
				t_pos += 1 if same else -1
			"I":
				q_pos += 1
			"D":
				t_pos += 1 if same else -1

func _draw_snp_connector(target, start_pt: Vector2, end_pt: Vector2, color: Color, bp_px: float) -> void:
	var delta := end_pt - start_pt
	var length := delta.length()
	if length <= 0.000001:
		if target == self:
			draw_circle(start_pt, 1.5, color)
		return
	var tangent := delta / length
	var normal := Vector2(-tangent.y, tangent.x)
	var amp := maxf(0.5, bp_px * 0.1)
	var poly := PackedVector2Array([start_pt])
	var wavelength_px := 20.0
	var segment_count := maxi(6, int(ceil(length / 2.0)))
	for i in range(1, segment_count):
		var frac := float(i) / float(segment_count)
		var dist := length * frac
		var phase := dist / wavelength_px * PI * 2.0
		poly.append(start_pt + delta * frac + normal * sin(phase) * amp)
	poly.append(end_pt)
	_draw_polyline_on(target, poly, color, 2.0)


func _focus_match_left(payload: Dictionary) -> void:
	var left_frac := 0.06
	var query_start := float(payload.get("query_start", 0))
	var target_start := float(payload.get("target_start", 0))
	var direct_targets := {}
	var top_id := int(payload.get("top_genome_id", -1))
	var bottom_id := int(payload.get("bottom_genome_id", -1))
	for pair_any in [
		[top_id, query_start],
		[bottom_id, target_start]
	]:
		var genome_id := int(pair_any[0])
		if genome_id < 0:
			continue
		var start_bp := float(pair_any[1])
		var genome_len := float(_genomes_by_id.get(genome_id, {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		var next_offset := clampf(start_bp - _view_span_bp * left_frac, 0.0, max_offset)
		direct_targets[genome_id] = next_offset
	_animate_offsets_to(_targets_with_locked_propagation(direct_targets))

func focus_match_payload(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	_selected_match_key = _match_key_for_payload(payload)
	queue_redraw()
	_focus_match_left(payload)

func clear_region_selection() -> void:
	_clear_region_selection()


func _targets_with_locked_propagation(direct_targets: Dictionary) -> Dictionary:
	if direct_targets.is_empty():
		return {}
	var targets := {}
	var queue: Array = []
	for genome_id_any in direct_targets.keys():
		var genome_id := int(genome_id_any)
		var target_offset := float(direct_targets[genome_id_any])
		targets[genome_id] = target_offset
		queue.append({
			"genome_id": genome_id,
			"delta": target_offset - float(_offsets.get(genome_id, target_offset))
		})
	while not queue.is_empty():
		var item: Dictionary = queue.pop_front()
		var current_id := int(item.get("genome_id", -1))
		var delta := float(item.get("delta", 0.0))
		var idx := _order.find(current_id)
		if idx < 0:
			continue
		for neighbor_idx in [idx - 1, idx + 1]:
			if neighbor_idx < 0 or neighbor_idx >= _order.size():
				continue
			var neighbor_id := int(_order[neighbor_idx])
			if not bool(_pair_locks.get(_pair_key(current_id, neighbor_id), false)):
				continue
			if targets.has(neighbor_id) or direct_targets.has(neighbor_id):
				continue
			var genome_len := float(_genomes_by_id.get(neighbor_id, {}).get("length", 0))
			var max_offset := maxf(0.0, genome_len - _view_span_bp)
			var next_offset := clampf(float(_offsets.get(neighbor_id, 0.0)) + delta, 0.0, max_offset)
			targets[neighbor_id] = next_offset
			queue.append({
				"genome_id": neighbor_id,
				"delta": next_offset - float(_offsets.get(neighbor_id, next_offset))
			})
	return targets


func _match_key_for_display_block(block: Dictionary, top_genome_id: int, bottom_genome_id: int) -> String:
	return "%d:%d:%d:%d:%d:%d" % [
		top_genome_id,
		bottom_genome_id,
		int(block.get("query_start", 0)),
		int(block.get("query_end", 0)),
		int(block.get("target_start", 0)),
		int(block.get("target_end", 0))
	]


func _match_key_for_payload(payload: Dictionary) -> String:
	return "%d:%d:%d:%d:%d:%d" % [
		int(payload.get("top_genome_id", -1)),
		int(payload.get("bottom_genome_id", -1)),
		int(payload.get("query_start", 0)),
		int(payload.get("query_end", 0)),
		int(payload.get("target_start", 0)),
		int(payload.get("target_end", 0))
	]


func _default_anchor_x() -> float:
	if _order.is_empty():
		return size.x * 0.5
	var row = _rows.get(int(_order[0]))
	if row == null:
		return size.x * 0.5
	var axis_rect: Rect2 = row.get_axis_rect_in_parent()
	return axis_rect.position.x + axis_rect.size.x * 0.5


func _schedule_single_click_dispatch(payload: Dictionary) -> void:
	_pending_click_serial += 1
	var serial := _pending_click_serial
	_pending_click_payload = payload.duplicate(true)
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func() -> void:
		if serial != _pending_click_serial:
			return
		var delayed_payload := _pending_click_payload.duplicate(true)
		_pending_click_payload.clear()
		emit_signal("comparison_match_selected", delayed_payload, false)
	)


func _cancel_pending_click_dispatch() -> void:
	_pending_click_serial += 1
	_pending_click_payload.clear()


func _local_input_point(global_point: Vector2) -> Vector2:
	return get_global_transform_with_canvas().affine_inverse() * global_point


func _pan_all_by_pixels(delta_x: float, animated: bool = true) -> void:
	var axis_width := 0.0
	if not _order.is_empty():
		var row = _rows.get(int(_order[0]))
		if row != null:
			var axis_rect: Rect2 = row.get_axis_rect_in_parent()
			axis_width = axis_rect.size.x
	if axis_width <= 0.0:
		return
	var fraction := (delta_x * 3.0) / axis_width
	if animated:
		pan_all_by_fraction(fraction)
		return
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	for genome_id in _order:
		var genome_len := float(_genomes_by_id.get(int(genome_id), {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		var next_offset := clampf(float(_offsets.get(int(genome_id), 0.0)) + _view_span_bp * fraction, 0.0, max_offset)
		_offsets[int(genome_id)] = next_offset
		var row2 = _rows.get(int(genome_id))
		if row2 != null:
			row2.set_view_offset(next_offset)
			var slice_data: Dictionary = _reference_slices.get(int(genome_id), {})
			if not slice_data.is_empty():
				row2.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
	_schedule_detail_request()
	queue_redraw()


func _animate_zoom_to_span(next_span: float, anchor_x: float, duration: float = 0.22) -> void:
	var longest := _longest_genome_len()
	var target_span := clampf(next_span, MIN_VIEW_SPAN_BP, maxf(MIN_VIEW_SPAN_BP, longest))
	if absf(target_span - _view_span_bp) < 0.000001:
		return
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null
	if _zoom_tween != null:
		_zoom_tween.kill()
	var anchors := {}
	for genome_id in _order:
		var row = _rows.get(int(genome_id))
		var anchor_frac := 0.5
		if row != null:
			var axis_rect: Rect2 = row.get_axis_rect_in_parent()
			if axis_rect.size.x > 0.0:
				anchor_frac = clampf((anchor_x - axis_rect.position.x) / axis_rect.size.x, 0.0, 1.0)
		var current_offset := float(_offsets.get(int(genome_id), 0.0))
		anchors[int(genome_id)] = current_offset + _view_span_bp * anchor_frac
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_SINE)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(func(span_value: float) -> void:
		_set_zoom_span_animated(span_value, anchors, anchor_x)
	, _view_span_bp, target_span, duration)
	_zoom_tween.finished.connect(func() -> void:
		_zoom_tween = null
	)


func _set_zoom_span_animated(span_value: float, anchors: Dictionary, anchor_x: float) -> void:
	var longest := _longest_genome_len()
	_view_span_bp = clampf(span_value, MIN_VIEW_SPAN_BP, maxf(MIN_VIEW_SPAN_BP, longest))
	for genome_id in _order:
		var genome_len := float(_genomes_by_id.get(int(genome_id), {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		var row = _rows.get(int(genome_id))
		var anchor_frac := 0.5
		if row != null:
			var axis_rect: Rect2 = row.get_axis_rect_in_parent()
			if axis_rect.size.x > 0.0:
				anchor_frac = clampf((anchor_x - axis_rect.position.x) / axis_rect.size.x, 0.0, 1.0)
		var anchor_bp := float(anchors.get(int(genome_id), _view_span_bp * 0.5))
		var next_offset := clampf(anchor_bp - _view_span_bp * anchor_frac, 0.0, max_offset)
		_offsets[int(genome_id)] = next_offset
		if row != null:
			row.set_view_span_bp(_view_span_bp)
			row.set_view_offset(next_offset)
			var slice_data: Dictionary = _reference_slices.get(int(genome_id), {})
			if not slice_data.is_empty():
				row.set_reference_slice(int(slice_data.get("slice_start", 0)), str(slice_data.get("sequence", "")))
	_schedule_detail_request()
	_emit_viewport_changed()
	queue_redraw()


func _cleanup_lock_buttons() -> void:
	var needed := {}
	for i in range(_order.size() - 1):
		needed[_pair_key(int(_order[i]), int(_order[i + 1]))] = true
	for key_any in _lock_buttons.keys():
		var key := str(key_any)
		if needed.has(key):
			continue
		var btn: Button = _lock_buttons[key]
		btn.queue_free()
		_lock_buttons.erase(key)


func _update_lock_buttons(match_band_h: float) -> void:
	_cleanup_lock_buttons()
	for i in range(_order.size() - 1):
		var top_id := int(_order[i])
		var bottom_id := int(_order[i + 1])
		var key := _pair_key(top_id, bottom_id)
		var btn: Button = _lock_buttons.get(key)
		if btn == null:
			btn = Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			btn.add_theme_font_override("font", MAGRATHEA_FONT)
			btn.tooltip_text = "Lock/unlock sequences"
			btn.pressed.connect(func() -> void:
				_on_lock_button_pressed(key)
			)
			add_child(btn)
			_lock_buttons[key] = btn
		btn.text = "P" if bool(_pair_locks.get(key, false)) else "Q"
		btn.size = LOCK_BTN_SIZE
		btn.position = Vector2(LOCK_BTN_X, TOP_PAD + i * (ROW_H + match_band_h) + ROW_H + 0.5 * (match_band_h - LOCK_BTN_SIZE.y))
		btn.visible = true


func _display_blocks_for_pair(top_genome_id: int, bottom_genome_id: int) -> Array:
	var ordered_blocks := _blocks_for_pair_in_display_order(top_genome_id, bottom_genome_id)
	return _visible_blocks_for_pair(ordered_blocks, top_genome_id, bottom_genome_id)

func _blocks_for_pair_in_display_order(top_genome_id: int, bottom_genome_id: int) -> Array:
	var payload: Dictionary = _pair_blocks.get(_pair_key(top_genome_id, bottom_genome_id), {})
	if payload.is_empty():
		return []
	var stored_query_id := int(payload.get("query_id", top_genome_id))
	var stored_target_id := int(payload.get("target_id", bottom_genome_id))
	var blocks: Array = payload.get("blocks", [])
	if stored_query_id == top_genome_id and stored_target_id == bottom_genome_id:
		return blocks.duplicate(true)
	var swapped := []
	for block_any in blocks:
		var block: Dictionary = block_any
		swapped.append({
			"query_start": int(block.get("target_start", 0)),
			"query_end": int(block.get("target_end", 0)),
			"target_start": int(block.get("query_start", 0)),
			"target_end": int(block.get("query_end", 0)),
			"percent_identity_x100": int(block.get("percent_identity_x100", 0)),
			"percent_identity": float(block.get("percent_identity", 0.0)),
			"same_strand": bool(block.get("same_strand", true))
		})
	return swapped


func _visible_blocks_for_pair(blocks: Array, top_genome_id: int, bottom_genome_id: int) -> Array:
	var top_offset := float(_offsets.get(top_genome_id, 0.0))
	var bottom_offset := float(_offsets.get(bottom_genome_id, 0.0))
	var top_end := top_offset + _view_span_bp
	var bottom_end := bottom_offset + _view_span_bp
	var tolerance := _view_span_bp * 0.25
	var top_vis_start := top_offset - tolerance
	var top_vis_end := top_end + tolerance
	var bottom_vis_start := bottom_offset - tolerance
	var bottom_vis_end := bottom_end + tolerance
	var visible_blocks := []
	for block_any in blocks:
		var block: Dictionary = block_any
		var q0 := float(block.get("query_start", 0))
		var q1 := float(block.get("query_end", 0))
		var t0 := float(block.get("target_start", 0))
		var t1 := float(block.get("target_end", 0))
		var span_len := maxi(int(absf(q1 - q0)), int(absf(t1 - t0)))
		var pct := float(block.get("percent_identity", 0.0))
		if span_len < _min_block_len_bp:
			continue
		if _max_block_len_bp > 0 and span_len > _max_block_len_bp:
			continue
		if pct < _min_percent_identity or pct > _max_percent_identity:
			continue
		var top_intersects := q1 > top_vis_start and q0 < top_vis_end
		var bottom_intersects := t1 > bottom_vis_start and t0 < bottom_vis_end
		if not top_intersects and not bottom_intersects:
			continue
		visible_blocks.append(block)
	visible_blocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_span := maxi(int(absf(float(a.get("query_end", 0)) - float(a.get("query_start", 0)))), int(absf(float(a.get("target_end", 0)) - float(a.get("target_start", 0)))))
		var b_span := maxi(int(absf(float(b.get("query_end", 0)) - float(b.get("query_start", 0)))), int(absf(float(b.get("target_end", 0)) - float(b.get("target_start", 0)))))
		if a_span == b_span:
			return float(a.get("percent_identity", 0.0)) > float(b.get("percent_identity", 0.0))
		return a_span > b_span
	)
	if visible_blocks.size() > _max_draw_blocks_per_pair:
		visible_blocks.resize(_max_draw_blocks_per_pair)
	return visible_blocks


func _project_block_polygon(block: Dictionary, top_offset: float, bottom_offset: float, top_axis: Rect2, bottom_axis: Rect2, top_y: float, bottom_y: float) -> PackedVector2Array:
	var q0 := _bp_edge_x(float(block.get("query_start", 0)), top_offset, top_axis)
	var q1 := _bp_edge_x(float(block.get("query_end", 0)), top_offset, top_axis)
	var t0 := _bp_edge_x(float(block.get("target_start", 0)), bottom_offset, bottom_axis)
	var t1 := _bp_edge_x(float(block.get("target_end", 0)), bottom_offset, bottom_axis)
	var poly := PackedVector2Array()
	poly.append(Vector2(q0, top_y))
	poly.append(Vector2(q1, top_y))
	if bool(block.get("same_strand", true)):
		poly.append(Vector2(t1, bottom_y))
		poly.append(Vector2(t0, bottom_y))
	else:
		poly.append(Vector2(t0, bottom_y))
		poly.append(Vector2(t1, bottom_y))
	return poly


func _project_block_polygon_for_rows(block: Dictionary, top_row, bottom_row, top_y: float, bottom_y: float, edge_inset_px: float = 0.0) -> PackedVector2Array:
	if top_row == null or bottom_row == null:
		return PackedVector2Array()
	var q0 := float(top_row.get_bp_edge_x_in_parent(float(block.get("query_start", 0))))
	var q1 := float(top_row.get_bp_edge_x_in_parent(float(block.get("query_end", 0))))
	var t0 := float(bottom_row.get_bp_edge_x_in_parent(float(block.get("target_start", 0))))
	var t1 := float(bottom_row.get_bp_edge_x_in_parent(float(block.get("target_end", 0))))
	if edge_inset_px > 0.0:
		if q1 - q0 > edge_inset_px * 2.0:
			q0 += edge_inset_px
			q1 -= edge_inset_px
		if t1 - t0 > edge_inset_px * 2.0:
			t0 += edge_inset_px
			t1 -= edge_inset_px
	var poly := PackedVector2Array()
	poly.append(Vector2(q0, top_y))
	poly.append(Vector2(q1, top_y))
	if bool(block.get("same_strand", true)):
		poly.append(Vector2(t1, bottom_y))
		poly.append(Vector2(t0, bottom_y))
	else:
		poly.append(Vector2(t0, bottom_y))
		poly.append(Vector2(t1, bottom_y))
	return poly


func _draw_reverse_block(target, block: Dictionary, top_genome_id: int, bottom_genome_id: int, top_offset: float, bottom_offset: float, top_axis: Rect2, bottom_axis: Rect2, top_y: float, bottom_y: float, x_min: float, x_max: float, fill: Color, edge_inset_px: float = 0.0) -> void:
	var q0 := _bp_edge_x(float(block.get("query_start", 0)), top_offset, top_axis)
	var q1 := _bp_edge_x(float(block.get("query_end", 0)), top_offset, top_axis)
	var t0 := _bp_edge_x(float(block.get("target_start", 0)), bottom_offset, bottom_axis)
	var t1 := _bp_edge_x(float(block.get("target_end", 0)), bottom_offset, bottom_axis)
	if edge_inset_px > 0.0:
		if q1 - q0 > edge_inset_px * 2.0:
			q0 += edge_inset_px
			q1 -= edge_inset_px
		if t1 - t0 > edge_inset_px * 2.0:
			t0 += edge_inset_px
			t1 -= edge_inset_px
	var cross := _line_intersection(Vector2(q0, top_y), Vector2(t1, bottom_y), Vector2(q1, top_y), Vector2(t0, bottom_y))
	var top_tri := PackedVector2Array([Vector2(q0, top_y), Vector2(q1, top_y), cross])
	var bottom_tri := PackedVector2Array([Vector2(t0, bottom_y), Vector2(t1, bottom_y), cross])
	top_tri = _clip_polygon_x(top_tri, x_min, x_max)
	bottom_tri = _clip_polygon_x(bottom_tri, x_min, x_max)
	if top_tri.size() >= 3 and _polygon_area_abs(top_tri) > 0.25:
		_draw_colored_polygon_on(target, top_tri, fill)
		if target == self:
			_register_match_hitbox(block, top_genome_id, bottom_genome_id, top_tri)
		top_tri.append(top_tri[0])
		_draw_polyline_on(target, top_tri, fill.darkened(0.18), 1.0)
		if _match_is_emphasized(_match_key_for_display_block(block, top_genome_id, bottom_genome_id)):
			_draw_polyline_on(target, top_tri, _theme_colors["selection_outline"], 2.0)
	if bottom_tri.size() >= 3 and _polygon_area_abs(bottom_tri) > 0.25:
		_draw_colored_polygon_on(target, bottom_tri, fill)
		if target == self:
			_register_match_hitbox(block, top_genome_id, bottom_genome_id, bottom_tri)
		bottom_tri.append(bottom_tri[0])
		_draw_polyline_on(target, bottom_tri, fill.darkened(0.18), 1.0)
		if _match_is_emphasized(_match_key_for_display_block(block, top_genome_id, bottom_genome_id)):
			_draw_polyline_on(target, bottom_tri, _theme_colors["selection_outline"], 2.0)


func _match_is_emphasized(match_key: String) -> bool:
	return match_key == _selected_match_key or match_key == _hovered_match_key


func _line_intersection(a0: Vector2, a1: Vector2, b0: Vector2, b1: Vector2) -> Vector2:
	var r := a1 - a0
	var s := b1 - b0
	var denom := r.x * s.y - r.y * s.x
	if absf(denom) < 0.000001:
		return (a0 + a1 + b0 + b1) * 0.25
	var diff := b0 - a0
	var t := (diff.x * s.y - diff.y * s.x) / denom
	return a0 + r * t


func _block_color(block: Dictionary, top_genome_id: int = -1, bottom_genome_id: int = -1) -> Color:
	if top_genome_id >= 0 and bottom_genome_id >= 0:
		if _match_key_for_display_block(block, top_genome_id, bottom_genome_id) == _selected_match_key:
			var selected_fill: Color = _theme_colors.get("selected_fill", Color("ffd84d"))
			selected_fill.a = 0.78
			return selected_fill
	var base: Color = _theme_colors["same_strand"] if bool(block.get("same_strand", true)) else _theme_colors["opp_strand"]
	var pct := clampf(float(block.get("percent_identity", 0.0)), 0.0, 100.0) / 100.0
	base.a = lerpf(0.18, 0.82, pct)
	return base


func _bp_edge_x(bp: float, offset: float, axis_rect: Rect2) -> float:
	return axis_rect.position.x + ((bp - offset) / _view_span_bp) * axis_rect.size.x


func _bp_center_x(bp: float, offset: float, axis_rect: Rect2) -> float:
	return axis_rect.position.x + ((bp - offset + 0.5) / _view_span_bp) * axis_rect.size.x


func _pixels_per_bp(axis_rect: Rect2) -> float:
	if _view_span_bp <= 0.0:
		return 0.0
	return axis_rect.size.x / _view_span_bp


func _x_within_axis(x: float, axis_rect: Rect2, tolerance: float = 0.0) -> bool:
	return x >= axis_rect.position.x - tolerance and x <= axis_rect.position.x + axis_rect.size.x + tolerance


func _clip_polygon_x(poly: PackedVector2Array, x_min: float, x_max: float) -> PackedVector2Array:
	var clipped := _clip_polygon_against_vertical(poly, x_min, true)
	if clipped.size() < 3:
		return PackedVector2Array()
	return _clip_polygon_against_vertical(clipped, x_max, false)


func _clip_polygon_against_vertical(poly: PackedVector2Array, boundary_x: float, keep_greater_equal: bool) -> PackedVector2Array:
	var out := PackedVector2Array()
	if poly.is_empty():
		return out
	var prev := poly[poly.size() - 1]
	var prev_inside := prev.x >= boundary_x if keep_greater_equal else prev.x <= boundary_x
	for point in poly:
		var inside := point.x >= boundary_x if keep_greater_equal else point.x <= boundary_x
		if inside != prev_inside and absf(point.x - prev.x) > 0.000001:
			var t := (boundary_x - prev.x) / (point.x - prev.x)
			out.append(Vector2(boundary_x, prev.y + (point.y - prev.y) * t))
		if inside:
			out.append(point)
		prev = point
		prev_inside = inside
	return out


func _polygon_area_abs(poly: PackedVector2Array) -> float:
	if poly.size() < 3:
		return 0.0
	var sum := 0.0
	for i in range(poly.size()):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


func _on_row_drag_started(genome_id: int) -> void:
	_clear_region_selection()
	_drag_active = true
	_drag_genome_id = genome_id
	_drag_target_index = _order.find(genome_id)
	queue_redraw()

func _on_row_feature_clicked(genome_id: int, feature: Dictionary, was_double_click: bool) -> void:
	_clear_region_selection()
	_select_feature_in_rows(genome_id, feature)
	emit_signal("comparison_feature_selected", feature, was_double_click)


func _on_row_offset_changed(genome_id: int, value: float) -> void:
	if _pan_tween != null:
		_pan_tween.kill()
		_pan_tween = null
	if _zoom_tween != null:
		_zoom_tween.kill()
		_zoom_tween = null
	if _syncing_offsets:
		return
	var previous := float(_offsets.get(genome_id, value))
	_offsets[genome_id] = value
	if absf(value - previous) > 0.000001:
		_propagate_locked_offsets(genome_id, value - previous)
	_schedule_detail_request()
	queue_redraw()


func _on_row_pan_step_requested(genome_id: int, fraction: float) -> void:
	if absf(fraction) < 0.000001:
		return
	var delta := _view_span_bp * fraction
	var targets := {}
	var queue := [genome_id]
	var seen := {genome_id: true}
	while not queue.is_empty():
		var current_id := int(queue.pop_front())
		var genome_len := float(_genomes_by_id.get(current_id, {}).get("length", 0))
		var max_offset := maxf(0.0, genome_len - _view_span_bp)
		targets[current_id] = clampf(float(_offsets.get(current_id, 0.0)) + delta, 0.0, max_offset)
		var idx := _order.find(current_id)
		if idx < 0:
			continue
		for neighbor_idx in [idx - 1, idx + 1]:
			if neighbor_idx < 0 or neighbor_idx >= _order.size():
				continue
			var neighbor_id := int(_order[neighbor_idx])
			if seen.has(neighbor_id):
				continue
			if not bool(_pair_locks.get(_pair_key(current_id, neighbor_id), false)):
				continue
			seen[neighbor_id] = true
			queue.append(neighbor_id)
	_animate_offsets_to(targets)


func _on_row_axis_center_requested(genome_id: int, click_x_in_parent: float) -> void:
	_clear_region_selection()
	var row = _rows.get(genome_id)
	if row == null or not _genomes_by_id.has(genome_id):
		return
	var genome_len := float(_genomes_by_id.get(genome_id, {}).get("length", 0))
	if genome_len <= 0.0:
		return
	var max_offset := maxf(0.0, genome_len - _view_span_bp)
	var axis_rect: Rect2 = row.get_axis_rect_in_parent()
	if axis_rect.size.x <= 0.0:
		return
	var frac := clampf((click_x_in_parent - axis_rect.position.x) / axis_rect.size.x, 0.0, 1.0)
	var clicked_bp: float = float(_offsets.get(genome_id, 0.0)) + frac * _view_span_bp
	var next_offset := clampf(clicked_bp - _view_span_bp * 0.5, 0.0, max_offset)
	_animate_offsets_to(_targets_with_locked_propagation({genome_id: next_offset}))


func _on_lock_button_pressed(key: String) -> void:
	_pair_locks[key] = not bool(_pair_locks.get(key, false))
	emit_signal("ui_sound_requested", "toggle_on" if bool(_pair_locks.get(key, false)) else "toggle_off")
	var btn: Button = _lock_buttons.get(key)
	if btn != null:
		btn.text = "P" if bool(_pair_locks.get(key, false)) else "Q"


func _propagate_locked_offsets(source_genome_id: int, delta: float) -> void:
	if absf(delta) < 0.000001:
		return
	_syncing_offsets = true
	var queue := [source_genome_id]
	var seen := {source_genome_id: true}
	while not queue.is_empty():
		var genome_id := int(queue.pop_front())
		var idx := _order.find(genome_id)
		if idx < 0:
			continue
		for neighbor_idx in [idx - 1, idx + 1]:
			if neighbor_idx < 0 or neighbor_idx >= _order.size():
				continue
			var neighbor_id := int(_order[neighbor_idx])
			if seen.has(neighbor_id):
				continue
			if not bool(_pair_locks.get(_pair_key(genome_id, neighbor_id), false)):
				continue
			seen[neighbor_id] = true
			queue.append(neighbor_id)
			var genome_len := float(_genomes_by_id.get(neighbor_id, {}).get("length", 0))
			var max_offset := maxf(0.0, genome_len - _view_span_bp)
			var next_offset := clampf(float(_offsets.get(neighbor_id, 0.0)) + delta, 0.0, max_offset)
			_offsets[neighbor_id] = next_offset
			var row = _rows.get(neighbor_id)
			if row != null:
				row.set_view_offset(next_offset)
	_syncing_offsets = false


func _row_index_for_y(y: float) -> int:
	if _order.is_empty():
		return -1
	var best_idx := 0
	var best_dist := INF
	for i in range(_order.size()):
		var row = _rows.get(int(_order[i]))
		if row == null:
			continue
		var center_y: float = row.position.y + ROW_H * 0.5
		var dist := absf(y - center_y)
		if dist < best_dist:
			best_dist = dist
			best_idx = i
	return best_idx


func _finish_row_drag(target_index: int) -> void:
	if not _drag_active:
		return
	var from_index := _order.find(_drag_genome_id)
	if from_index >= 0 and target_index >= 0 and target_index < _order.size() and target_index != from_index:
		var moved := int(_order[from_index])
		_order.remove_at(from_index)
		_order.insert(target_index, moved)
		_layout_rows_and_locks()
		emit_signal("genome_order_changed", _order)
	_drag_active = false
	_drag_genome_id = -1
	_drag_target_index = -1
	queue_redraw()


func _draw_drag_indicator() -> void:
	if not _drag_active or _drag_target_index < 0 or _drag_target_index >= _order.size():
		return
	var row = _rows.get(int(_order[_drag_target_index]))
	if row == null:
		return
	var y: float = row.position.y - 3.0
	draw_line(Vector2(0.0, y), Vector2(size.x, y), _theme_colors["border"], 4.0)


func _draw_empty_state_prompt() -> void:
	if not _loading_message.is_empty():
		return
	var message := ""
	if _order.is_empty():
		message = "Drag genome files one-by-one to compare"
	elif _order.size() == 1:
		message = "Drag another genome to compare"
	else:
		return
	var font := get_theme_default_font()
	var font_size := maxi(18, get_theme_default_font_size() + 2)
	var text_size := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := Vector2((size.x - text_size.x) * 0.5, (size.y + font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5)
	draw_string(font, pos, message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors.get("text", Color.BLACK))


func _draw_loading_overlay() -> void:
	if _loading_message.is_empty():
		return
	var overlay_color: Color = _theme_colors.get("panel_alt", Color(0.95, 0.95, 0.95, 1.0))
	overlay_color.a = 0.82
	draw_rect(Rect2(Vector2.ZERO, size), overlay_color, true)
	var font := get_theme_default_font()
	var font_size := maxi(16, get_theme_default_font_size() + 2)
	var text_w := font.get_string_size(_loading_message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var text_h := font.get_height(font_size)
	var pad_x := 18.0
	var pad_y := 12.0
	var box := Rect2(
		Vector2((size.x - text_w) * 0.5 - pad_x, (size.y - text_h) * 0.5 - pad_y),
		Vector2(text_w + pad_x * 2.0, text_h + pad_y * 2.0)
	)
	draw_rect(box, _theme_colors.get("panel_alt", Color.WHITE), true)
	draw_rect(box, _theme_colors.get("border", Color.BLACK), false, 1.0)
	var baseline := box.position.y + pad_y + font.get_ascent(font_size)
	draw_string(font, Vector2(box.position.x + pad_x, baseline), _loading_message, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _theme_colors.get("text", Color.BLACK))

func _draw_rect_on(target, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	if target == self:
		draw_rect(rect, color, filled, width)
	else:
		target.draw_rect(rect, color, filled, width)

func _draw_line_on(target, p0: Vector2, p1: Vector2, color: Color, width: float = 1.0) -> void:
	if target == self:
		draw_line(p0, p1, color, width)
	else:
		target.draw_line(p0, p1, color, width)

func _draw_polyline_on(target, points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	if target == self:
		draw_polyline(points, color, width)
	else:
		target.draw_polyline(points, color, width)

func _draw_colored_polygon_on(target, points: PackedVector2Array, color: Color) -> void:
	if target == self:
		draw_colored_polygon(points, color)
	else:
		target.draw_colored_polygon(points, color)


func _match_band_height() -> float:
	if _order.size() <= 1:
		return MIN_MATCH_BAND_H
	var free_h := maxf(0.0, size.y - TOP_PAD - BOTTOM_PAD - ROW_H * float(_order.size()))
	return maxf(MIN_MATCH_BAND_H, free_h / float(_order.size() - 1))


func _longest_genome_len() -> float:
	var longest := 0.0
	for genome_any in _genomes_by_id.values():
		var genome: Dictionary = genome_any
		longest = maxf(longest, float(genome.get("length", 0)))
	return longest


func _pair_key(a: int, b: int) -> String:
	return "%d:%d" % [mini(a, b), maxi(a, b)]

func _row_hit_for_point(point_parent: Vector2) -> Dictionary:
	for genome_id_any in _order:
		var genome_id := int(genome_id_any)
		var row = _rows.get(genome_id)
		if row == null:
			continue
		var axis_rect: Rect2 = row.get_axis_rect_in_parent()
		var row_rect := Rect2(Vector2(axis_rect.position.x, row.position.y), Vector2(axis_rect.size.x, ROW_H))
		if not row_rect.has_point(point_parent):
			continue
		return {
			"genome_id": genome_id,
			"bp": float(row.get_bp_edge_at_x_in_parent(point_parent.x))
		}
	return {}

func _start_region_selection(genome_id: int, edge_bp: float) -> void:
	_cancel_pending_region_selection()
	_drag_active = false
	_drag_genome_id = -1
	_drag_target_index = -1
	_region_select_dragging = true
	_region_select_has_selection = true
	_region_select_genome_id = genome_id
	_region_select_start_edge = edge_bp
	_region_select_end_edge = edge_bp
	_update_region_selection_rows()

func _begin_pending_region_selection(genome_id: int, edge_bp: float, start_point: Vector2) -> void:
	_region_select_pending = true
	_region_select_pending_genome_id = genome_id
	_region_select_pending_edge = edge_bp
	_region_select_pending_start_point = start_point

func _cancel_pending_region_selection() -> void:
	_region_select_pending = false
	_region_select_pending_genome_id = -1
	_region_select_pending_edge = 0.0
	_region_select_pending_start_point = Vector2.ZERO

func _update_region_selection_drag(point_parent: Vector2) -> void:
	if not _region_select_dragging:
		return
	var row = _rows.get(_region_select_genome_id)
	if row == null:
		return
	_region_select_end_edge = float(row.get_bp_edge_at_x_in_parent(point_parent.x))
	_update_region_selection_rows()

func _finish_region_selection_drag(point_parent: Vector2) -> void:
	if not _region_select_dragging:
		return
	_update_region_selection_drag(point_parent)
	_region_select_dragging = false
	_update_region_selection_rows()
	var selection := _selection_payload()
	if selection.is_empty():
		_clear_region_selection(true)
		return
	emit_signal("comparison_region_selected", selection)

func _update_region_selection_rows() -> void:
	for genome_id_any in _rows.keys():
		var genome_id := int(genome_id_any)
		var row = _rows.get(genome_id)
		if row == null:
			continue
		if _region_select_has_selection and genome_id == _region_select_genome_id:
			row.set_region_selection(_region_select_start_edge, _region_select_end_edge, _region_select_dragging)
		else:
			row.clear_region_selection()

func _clear_region_selection(emit_cleared: bool = false) -> void:
	var had_selection := _region_select_has_selection or _region_select_dragging
	_cancel_pending_region_selection()
	_region_select_dragging = false
	_region_select_has_selection = false
	_region_select_genome_id = -1
	_region_select_start_edge = 0.0
	_region_select_end_edge = 0.0
	_update_region_selection_rows()
	if had_selection and emit_cleared:
		emit_signal("comparison_region_cleared")

func _selection_payload() -> Dictionary:
	if not _region_select_has_selection or _region_select_genome_id < 0:
		return {}
	var start_bp := int(floor(minf(_region_select_start_edge, _region_select_end_edge)))
	var end_bp := int(ceil(maxf(_region_select_start_edge, _region_select_end_edge)))
	if end_bp <= start_bp:
		end_bp = start_bp + 1
	var genome: Dictionary = _genomes_by_id.get(_region_select_genome_id, {})
	if genome.is_empty():
		return {}
	var selected_match: Dictionary = _segment_match_for_interval(genome, start_bp, end_bp)
	var idx := _order.find(_region_select_genome_id)
	var matches_above: Array = []
	var matches_below: Array = []
	if idx > 0:
		var above_id := int(_order[idx - 1])
		matches_above = _overlapping_match_payloads_for_pair(above_id, _region_select_genome_id, start_bp, end_bp, false)
	if idx >= 0 and idx < _order.size() - 1:
		var below_id := int(_order[idx + 1])
		matches_below = _overlapping_match_payloads_for_pair(_region_select_genome_id, below_id, start_bp, end_bp, true)
	return {
		"genome_id": _region_select_genome_id,
		"genome_name": str(genome.get("name", "Genome %d" % _region_select_genome_id)),
		"contig": str(selected_match.get("name", "")),
		"start_bp": start_bp,
		"end_bp": end_bp,
		"local_start": int(selected_match.get("local_start", start_bp)),
		"local_end": int(selected_match.get("local_end", end_bp)),
		"matches_above": matches_above,
		"matches_below": matches_below
	}

func _overlapping_match_payloads_for_pair(top_genome_id: int, bottom_genome_id: int, start_bp: int, end_bp: int, selected_is_top: bool) -> Array:
	var payload: Dictionary = _pair_blocks.get(_pair_key(top_genome_id, bottom_genome_id), {})
	if payload.is_empty():
		return []
	var blocks := _blocks_for_pair_in_display_order(top_genome_id, bottom_genome_id)
	var out := []
	for block_any in blocks:
		var block: Dictionary = block_any
		var block_start := int(block.get("query_start", 0)) if selected_is_top else int(block.get("target_start", 0))
		var block_end := int(block.get("query_end", 0)) if selected_is_top else int(block.get("target_end", 0))
		if block_end <= start_bp or block_start >= end_bp:
			continue
		out.append(_payload_for_block(block, top_genome_id, bottom_genome_id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_start := int(a.get("query_start", 0)) if selected_is_top else int(a.get("target_start", 0))
		var b_start := int(b.get("query_start", 0)) if selected_is_top else int(b.get("target_start", 0))
		if a_start == b_start:
			return float(a.get("percent_identity", 0.0)) > float(b.get("percent_identity", 0.0))
		return a_start < b_start
	)
	return out
