extends Control
class_name ThemePreview

const PREVIEW_MONO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")

var _palette := {
	"bg": Color("e8edf2"),
	"panel": Color("f6f9fc"),
	"panel_alt": Color("edf2f6"),
	"border": Color("b6c3cf"),
	"scrollbar_outline": Color("7a8794"),
	"text": Color("1f2933"),
	"text_muted": Color("4d5a67"),
	"text_inverse": Color("ffffff"),
	"button_bg": Color("dde6ee"),
	"button_hover": Color("d4dee8"),
	"button_pressed": Color("c9d5e2"),
	"field_bg": Color("f9fbfd"),
	"field_border": Color("a9bac9"),
	"field_focus": Color("2d7dd2"),
	"accent": Color("345995"),
	"status_error": Color("8b1f1f"),
	"map_contig": Color("e8edf2"),
	"map_contig_alt": Color("dde3ea"),
	"map_view_fill": Color("345995"),
	"map_view_outline": Color("1f2933"),
	"genome": Color("345995"),
	"read": Color("2d7dd2"),
	"insertion_marker": Color("1f2933"),
	"gc_plot": Color("2d7dd2"),
	"depth_plot": Color("345995"),
	"depth_plot_series": [
		Color("345995"),
		Color("2d7dd2"),
		Color("6f93c7"),
		Color("8fb2da"),
		Color("4d78b0"),
		Color("1f3654")
	],
	"feature": Color("c6d6ec"),
	"feature_accent": Color("6f93c7"),
	"feature_text": Color("1f3654"),
	"snp": Color("d7263d"),
	"snp_text": Color("ffffff"),
	"comparison_same_strand": Color("cb5a4a"),
	"comparison_opp_strand": Color("4d78b0"),
	"comparison_selected_fill": Color("ffd84d"),
	"comparison_match_line": Color("1f2933"),
	"comparison_snp": Color("7a00ff"),
	"vcf_gt_ref_fill": Color("1f2933"),
	"vcf_gt_ref_text": Color("f6f9fc"),
	"vcf_gt_het_fill": Color("2d7dd2"),
	"vcf_gt_het_text": Color("ffffff"),
	"vcf_gt_hom_alt_fill": Color("d7263d"),
	"vcf_gt_hom_alt_text": Color("ffffff")
}
var _theme_name := "Theme Preview"
var _role_regions := {}
var _flash_role_key := ""
var _flash_time_left := 0.0
var _scroll_y := 0.0
var _scroll_max := 0.0
var _scroll_content_height := 0.0
var _scroll_drag_active := false
var _scroll_drag_offset := 0.0
const FLASH_DURATION := 1.0
const NARROW_LAYOUT_WIDTH := 860.0
const PREVIEW_SECTION_GAP := 22.0
const HEADER_BOX_GAP := 12.0
const HEADER_TITLE_H := 42.0
const HEADER_CONTROLS_H := 64.0
const PLOT_SECTION_H := 120.0
const ANNOT_SECTION_H := 156.0
const GENOME_SECTION_H := 132.0
const MAP_SECTION_H := 124.0
const READS_SECTION_H := 172.0
const VCF_SECTION_H := 136.0
const COMPARISON_SECTION_H := 224.0
const DEPTH_SERIES_SECTION_H := 220.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)


func set_palette(next_palette: Dictionary, theme_name: String = "") -> void:
	_palette = next_palette.duplicate(true)
	if not theme_name.is_empty():
		_theme_name = theme_name
	queue_redraw()


func flash_role(role_key: String) -> void:
	_flash_role_key = role_key
	_flash_time_left = FLASH_DURATION
	queue_redraw()


func _process(delta: float) -> void:
	if _flash_time_left <= 0.0:
		return
	_flash_time_left = maxf(0.0, _flash_time_left - delta)
	queue_redraw()


func _draw() -> void:
	_role_regions.clear()
	draw_rect(Rect2(Vector2.ZERO, size), _palette.get("bg", Color.WHITE), true)
	_register_role_rect("bg", Rect2(Vector2.ZERO, size))
	var viewport_rect := _preview_viewport_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return
	var use_single_column := viewport_rect.size.x < NARROW_LAYOUT_WIDTH
	var content_h := _content_height(use_single_column)
	_scroll_content_height = content_h
	_scroll_max = maxf(0.0, content_h - viewport_rect.size.y)
	_scroll_y = clampf(_scroll_y, 0.0, _scroll_max)
	var content_rect := Rect2(
		viewport_rect.position.x,
		viewport_rect.position.y - _scroll_y,
		viewport_rect.size.x - (_single_column_scrollbar_width() if _scroll_max > 0.0 else 0.0),
		content_h
	)
	if use_single_column:
		_draw_single_column(content_rect)
	else:
		var header_w := _header_box_width(content_rect.size.x)
		var title_rect := Rect2(content_rect.position.x, content_rect.position.y, header_w, HEADER_TITLE_H)
		_draw_header_title(title_rect)
		var col_gap := 18.0
		var left_w: float = floor((content_rect.size.x - col_gap) * 0.54)
		var right_w := maxf(0.0, content_rect.size.x - left_w - col_gap)
		var controls_rect := Rect2(content_rect.position.x, title_rect.end.y + HEADER_BOX_GAP, left_w, HEADER_CONTROLS_H)
		_draw_header_controls(controls_rect)
		var left_top := controls_rect.end.y + PREVIEW_SECTION_GAP
		var right_top := controls_rect.position.y
		var left_rect := Rect2(Vector2(content_rect.position.x, left_top), Vector2(left_w, maxf(0.0, content_rect.end.y - left_top)))
		var right_rect := Rect2(Vector2(content_rect.position.x + left_w + col_gap, right_top), Vector2(right_w, maxf(0.0, content_rect.end.y - right_top)))
		_draw_browser_column(left_rect)
		_draw_data_column(right_rect)
	if _scroll_max > 0.0:
		_draw_preview_scrollbar(viewport_rect)
	_draw_flash_overlay()


func _gui_input(event: InputEvent) -> void:
	if _scroll_max <= 0.0:
		_scroll_drag_active = false
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed:
				var scrollbar := _preview_scrollbar_rect()
				if not scrollbar.track.has_area():
					return
				if scrollbar.grabber.has_point(mouse_event.position):
					_scroll_drag_active = true
					_scroll_drag_offset = mouse_event.position.y - scrollbar.grabber.position.y
					accept_event()
				elif scrollbar.track.has_point(mouse_event.position):
					_scroll_y = _scroll_from_grabber_top(mouse_event.position.y - scrollbar.grabber.size.y * 0.5)
					queue_redraw()
					accept_event()
			else:
				_scroll_drag_active = false
			return
		if not mouse_event.pressed:
			return
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_y = clampf(_scroll_y - 48.0, 0.0, _scroll_max)
			queue_redraw()
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_y = clampf(_scroll_y + 48.0, 0.0, _scroll_max)
			queue_redraw()
			accept_event()
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		_scroll_y = clampf(_scroll_y + pan_event.delta.y * 2.2, 0.0, _scroll_max)
		queue_redraw()
		accept_event()
	elif event is InputEventMouseMotion and _scroll_drag_active:
		var motion_event := event as InputEventMouseMotion
		_scroll_y = _scroll_from_grabber_top(motion_event.position.y - _scroll_drag_offset)
		queue_redraw()
		accept_event()


func _draw_header_title(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 12)
	_register_role_rect("panel", rect)
	_register_role_rect("border", rect)
	var font := get_theme_default_font()
	var title_size := maxi(18, get_theme_default_font_size() + 4)
	var title_y := rect.position.y + 16.0 + _text_ascent(font, title_size)
	var title_pos := Vector2(rect.position.x + 18.0, title_y)
	draw_string(font, title_pos, _theme_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, _palette.get("text", Color.BLACK))
	_register_text_rect("text", font, title_pos, _theme_name, title_size)
	var status_size := maxi(11, get_theme_default_font_size() - 1)
	var title_width := font.get_string_size(_theme_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size).x
	var status_pos := Vector2(title_pos.x + title_width + 28.0, title_y)
	draw_string(font, status_pos, "Error message", HORIZONTAL_ALIGNMENT_LEFT, -1.0, status_size, _palette.get("status_error", Color("8b1f1f")))
	_register_text_rect("status_error", font, status_pos, "Error message", status_size)


func _draw_header_controls(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 12)
	_register_role_rect("panel", rect)
	_register_role_rect("border", rect)
	var font := get_theme_default_font()
	var button_text_size := maxi(12, get_theme_default_font_size())
	var scrollbar_rect := Rect2(rect.end.x - 28.0, rect.position.y + 12.0, 12.0, rect.size.y - 24.0)
	_draw_panel_scrollbar_sample(scrollbar_rect)
	var normal_label := "Normal"
	var hover_label := "Hover"
	var pressed_label := "Pressed"
	var button_w := maxf(
		80.0,
		maxf(
			font.get_string_size(normal_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button_text_size).x,
			maxf(
				font.get_string_size(hover_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button_text_size).x,
				font.get_string_size(pressed_label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, button_text_size).x
			)
		) + 28.0
	)
	var button_gap := 8.0
	var button_row_x := rect.position.x + 18.0
	var pressed_rect := Rect2(button_row_x + (button_w + button_gap) * 2.0, rect.position.y + 12.0, button_w, 32.0)
	var hover_rect := Rect2(pressed_rect.position.x - button_gap - button_w, rect.position.y + 12.0, button_w, 32.0)
	var normal_rect := Rect2(hover_rect.position.x - button_gap - button_w, rect.position.y + 12.0, button_w, 32.0)
	_draw_button(normal_rect, _palette.get("button_bg", Color.GRAY), normal_label)
	_draw_button(hover_rect, _palette.get("button_hover", _palette.get("button_bg", Color.GRAY)), hover_label)
	_draw_button(pressed_rect, _palette.get("button_pressed", _palette.get("button_hover", Color.GRAY)), pressed_label)
	var control_row_y := rect.position.y + 44.0
	var checkbox_rect := Rect2(button_row_x, control_row_y, 22.0, 22.0)
	_draw_checkbox_sample(checkbox_rect, true)
	var toggle_rect := Rect2(checkbox_rect.end.x + 12.0, control_row_y, 40.0, 22.0)
	_draw_toggle_sample(toggle_rect, true)
	var slider_rect := Rect2(toggle_rect.end.x + 14.0, control_row_y + 3.0, 78.0, 16.0)
	_draw_slider_sample(slider_rect)
	_register_role_rect("button_bg", normal_rect)
	_register_role_rect("button_hover", hover_rect)
	_register_role_rect("button_pressed", pressed_rect)
	_register_role_rect("field_bg", checkbox_rect)
	_register_role_rect("field_border", checkbox_rect)
	_register_role_rect("field_bg", toggle_rect)
	_register_role_rect("field_bg", slider_rect)
	_register_role_rect("field_border", toggle_rect)
	_register_role_rect("field_border", slider_rect)
	_register_role_rect("field_focus", slider_rect.grow(4.0))
	_register_role_rect("accent", checkbox_rect)
	_register_role_rect("text_inverse", checkbox_rect)
	_register_role_rect("accent", toggle_rect)
	_register_role_rect("accent", slider_rect)


func _draw_browser_column(rect: Rect2) -> void:
	var gap := PREVIEW_SECTION_GAP
	var plot_h := maxf(PLOT_SECTION_H, floor(rect.size.y * 0.20))
	var annot_h := maxf(ANNOT_SECTION_H, floor(rect.size.y * 0.27))
	var genome_h := maxf(GENOME_SECTION_H, floor(rect.size.y * 0.19))
	var map_h := maxf(MAP_SECTION_H, rect.size.y - plot_h - annot_h - genome_h - gap * 3.0)
	var y := rect.position.y
	_draw_plot_section(Rect2(rect.position.x, y, rect.size.x, plot_h))
	y += plot_h + gap
	_draw_annotation_section(Rect2(rect.position.x, y, rect.size.x, annot_h))
	y += annot_h + gap
	_draw_genome_section(Rect2(rect.position.x, y, rect.size.x, genome_h))
	y += genome_h + gap
	_draw_map_section(Rect2(rect.position.x, y, rect.size.x, map_h))


func _draw_data_column(rect: Rect2) -> void:
	var gap := PREVIEW_SECTION_GAP
	var reads_h := maxf(READS_SECTION_H, floor(rect.size.y * 0.28))
	var depth_series_h := maxf(DEPTH_SERIES_SECTION_H, floor(rect.size.y * 0.20))
	var vcf_h := maxf(VCF_SECTION_H, floor(rect.size.y * 0.18))
	var comparison_h := maxf(COMPARISON_SECTION_H, rect.size.y - reads_h - depth_series_h - vcf_h - gap * 3.0)
	var y := rect.position.y
	_draw_reads_section(Rect2(rect.position.x, y, rect.size.x, reads_h))
	y += reads_h + gap
	_draw_depth_plot_series_section(Rect2(rect.position.x, y, rect.size.x, depth_series_h))
	y += depth_series_h + gap
	_draw_vcf_section(Rect2(rect.position.x, y, rect.size.x, vcf_h))
	y += vcf_h + gap
	_draw_comparison_section(Rect2(rect.position.x, y, rect.size.x, comparison_h))


func _draw_single_column(rect: Rect2) -> void:
	var y := rect.position.y
	var header_w := _header_box_width(rect.size.x)
	var title_rect := Rect2(rect.position.x, y, header_w, HEADER_TITLE_H)
	_draw_header_title(title_rect)
	y = title_rect.end.y + HEADER_BOX_GAP
	var controls_rect := Rect2(rect.position.x, y, rect.size.x, HEADER_CONTROLS_H)
	_draw_header_controls(controls_rect)
	y = controls_rect.end.y + PREVIEW_SECTION_GAP
	var full_w := rect.size.x
	var plot_h := PLOT_SECTION_H
	var annot_h := ANNOT_SECTION_H
	var genome_h := GENOME_SECTION_H
	var map_h := MAP_SECTION_H
	var reads_h := READS_SECTION_H
	var vcf_h := VCF_SECTION_H
	var comparison_h := COMPARISON_SECTION_H
	var depth_series_h := DEPTH_SERIES_SECTION_H
	_draw_plot_section(Rect2(rect.position.x, y, full_w, plot_h))
	y += plot_h + PREVIEW_SECTION_GAP
	_draw_annotation_section(Rect2(rect.position.x, y, full_w, annot_h))
	y += annot_h + PREVIEW_SECTION_GAP
	_draw_genome_section(Rect2(rect.position.x, y, full_w, genome_h))
	y += genome_h + PREVIEW_SECTION_GAP
	_draw_map_section(Rect2(rect.position.x, y, full_w, map_h))
	y += map_h + PREVIEW_SECTION_GAP
	_draw_reads_section(Rect2(rect.position.x, y, full_w, reads_h))
	y += reads_h + PREVIEW_SECTION_GAP
	_draw_depth_plot_series_section(Rect2(rect.position.x, y, full_w, depth_series_h))
	y += depth_series_h + PREVIEW_SECTION_GAP
	_draw_vcf_section(Rect2(rect.position.x, y, full_w, vcf_h))
	y += vcf_h + PREVIEW_SECTION_GAP
	_draw_comparison_section(Rect2(rect.position.x, y, full_w, comparison_h))


func _single_column_content_height() -> float:
	return HEADER_TITLE_H + HEADER_BOX_GAP + HEADER_CONTROLS_H + PREVIEW_SECTION_GAP + PLOT_SECTION_H + ANNOT_SECTION_H + GENOME_SECTION_H + MAP_SECTION_H + READS_SECTION_H + DEPTH_SERIES_SECTION_H + VCF_SECTION_H + COMPARISON_SECTION_H + PREVIEW_SECTION_GAP * 7.0


func _two_column_content_height() -> float:
	var left_h := PLOT_SECTION_H + ANNOT_SECTION_H + GENOME_SECTION_H + MAP_SECTION_H + PREVIEW_SECTION_GAP * 3.0
	var right_h := READS_SECTION_H + DEPTH_SERIES_SECTION_H + VCF_SECTION_H + COMPARISON_SECTION_H + PREVIEW_SECTION_GAP * 3.0
	return maxf(
		HEADER_TITLE_H + HEADER_BOX_GAP + HEADER_CONTROLS_H + PREVIEW_SECTION_GAP + left_h,
		HEADER_TITLE_H + HEADER_BOX_GAP + right_h
	)


func _content_height(use_single_column: bool) -> float:
	return _single_column_content_height() if use_single_column else _two_column_content_height()


func _single_column_scrollbar_width() -> float:
	return 16.0


func _header_box_width(available_w: float) -> float:
	return minf(available_w, maxf(320.0, floor(available_w * 0.5)))


func _draw_preview_scrollbar(_body_rect: Rect2) -> void:
	var scrollbar: Dictionary = _preview_scrollbar_rect()
	var track: Rect2 = scrollbar.track
	draw_rect(track, _palette.get("panel_alt", Color("efefef")), true)
	_draw_rect_outline(track, _palette.get("border", Color.BLACK), 1.0)
	var grabber: Rect2 = scrollbar.grabber
	draw_rect(grabber, _palette.get("button_bg", Color.WHITE), true)
	_draw_rect_outline(grabber, _palette.get("scrollbar_outline", _palette.get("border", Color.BLACK)), 1.5)


func _preview_viewport_rect() -> Rect2:
	var outer_pad := 24.0
	return Rect2(outer_pad, outer_pad, maxf(0.0, size.x - outer_pad * 2.0), maxf(0.0, size.y - outer_pad * 2.0))


func _preview_scrollbar_rect() -> Dictionary:
	var viewport_rect := _preview_viewport_rect()
	var track := Rect2(viewport_rect.end.x - 12.0, viewport_rect.position.y, 8.0, viewport_rect.size.y)
	var visible_ratio := clampf(viewport_rect.size.y / maxf(_scroll_content_height, 1.0), 0.12, 1.0)
	var grabber_h := maxf(36.0, track.size.y * visible_ratio)
	var progress := _scroll_y / maxf(_scroll_max, 1.0)
	var grabber_y := track.position.y + (track.size.y - grabber_h) * progress
	var grabber := Rect2(track.position.x + 1.0, grabber_y, track.size.x - 2.0, grabber_h)
	return {"track": track, "grabber": grabber}


func _scroll_from_grabber_top(grabber_y: float) -> float:
	var scrollbar := _preview_scrollbar_rect()
	var track: Rect2 = scrollbar.track
	var grabber: Rect2 = scrollbar.grabber
	var top := clampf(grabber_y, track.position.y, track.end.y - grabber.size.y)
	var denom := maxf(track.size.y - grabber.size.y, 1.0)
	var progress := (top - track.position.y) / denom
	return clampf(progress * _scroll_max, 0.0, _scroll_max)


func _draw_plot_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(rect, "Plots")
	var plot_rect := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(plot_rect, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel_alt", plot_rect)
	_register_role_rect("border", plot_rect)
	var mid_y := plot_rect.position.y + plot_rect.size.y * 0.5
	var gc_points := PackedVector2Array([
		Vector2(plot_rect.position.x + 6.0, mid_y + 8.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.20, mid_y - 10.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.42, mid_y + 4.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.64, mid_y - 16.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.82, mid_y + 2.0),
		Vector2(plot_rect.end.x - 6.0, mid_y - 8.0)
	])
	draw_polyline(gc_points, _palette.get("gc_plot", _palette.get("read", Color.CYAN)), 3.0)
	var depth_points := PackedVector2Array([
		Vector2(plot_rect.position.x + 6.0, mid_y + 24.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.22, mid_y + 8.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.40, mid_y + 22.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.62, mid_y - 6.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.80, mid_y + 18.0),
		Vector2(plot_rect.end.x - 6.0, mid_y - 2.0)
	])
	draw_polyline(depth_points, _palette.get("depth_plot", Color.BLUE), 3.0)
	_register_role_rect("gc_plot", _polyline_bounds(gc_points, 4.0))
	_register_role_rect("depth_plot", _polyline_bounds(depth_points, 4.0))
	var caption_font := get_theme_default_font()
	var caption_size := maxi(11, get_theme_default_font_size() - 1)
	var caption_pos := Vector2(plot_rect.position.x + 4.0, plot_rect.end.y - 8.0)
	draw_string(caption_font, caption_pos, "GC and depth overview", HORIZONTAL_ALIGNMENT_LEFT, -1.0, caption_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text_muted", caption_font, caption_pos, "GC and depth overview", caption_size)


func _draw_annotation_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(rect, "AA / Annotation")
	var card := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(card, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel_alt", card)
	_register_role_rect("border", card)
	var row_gap: float = 4.0
	var caption_h: float = 18.0
	var rows_area := Rect2(card.position.x + 8.0, card.position.y + 10.0, card.size.x - 16.0, card.size.y - 20.0 - caption_h)
	var row_h: float = floor((rows_area.size.y - row_gap * 2.0) / 3.0)
	var row_rects: Array[Rect2] = []
	for i in range(3):
		var row_y: float = rows_area.position.y + i * (row_h + row_gap)
		var row_rect := Rect2(rows_area.position.x, row_y, rows_area.size.x, row_h)
		var row_color: Color = _palette.get("bg", Color.WHITE)
		if i == 1:
			row_color = _palette.get("track_alt_bg", row_color)
			_register_role_rect("track_alt_bg", row_rect)
		else:
			_register_role_rect("bg", row_rect)
		draw_rect(row_rect, row_color, true)
		_draw_rect_outline(row_rect, _palette.get("border", Color.BLACK), 1.0)
		row_rects.append(row_rect)
	var feature_a := Rect2(row_rects[0].position.x + 16.0, row_rects[0].position.y + 4.0, row_rects[0].size.x * 0.5, row_rects[0].size.y - 8.0)
	var feature_b := Rect2(row_rects[1].position.x + row_rects[1].size.x * 0.26, row_rects[1].position.y + 4.0, row_rects[1].size.x * 0.44, row_rects[1].size.y - 8.0)
	draw_rect(feature_a, _palette.get("feature", Color("dce8f7")), true)
	_draw_rect_outline(feature_a, _palette.get("feature_accent", _palette.get("border", Color.BLACK)), 2.0)
	draw_rect(feature_b, _palette.get("feature", Color("dce8f7")), true)
	_draw_rect_outline(feature_b, _palette.get("feature_accent", _palette.get("border", Color.BLACK)), 2.0)
	var stop_color: Color = _palette.get("stop_codon", _palette.get("text", Color.BLACK))
	var stop_markers := [
		Rect2(row_rects[0].position.x + row_rects[0].size.x * 0.80, row_rects[0].position.y + 3.0, 4.0, row_rects[0].size.y - 6.0),
		Rect2(row_rects[1].position.x + row_rects[1].size.x * 0.12, row_rects[1].position.y + 3.0, 4.0, row_rects[1].size.y - 6.0),
		Rect2(row_rects[2].position.x + row_rects[2].size.x * 0.58, row_rects[2].position.y + 3.0, 4.0, row_rects[2].size.y - 6.0)
	]
	for marker_any in stop_markers:
		var marker: Rect2 = marker_any
		draw_rect(marker, stop_color, true)
		_register_role_rect("stop_codon", marker)
	_register_role_rect("feature", feature_a)
	_register_role_rect("feature", feature_b)
	_register_role_rect("feature_accent", feature_a)
	_register_role_rect("feature_accent", feature_b)
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var feature_a_text_size := font.get_string_size("geneX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size)
	var feature_b_text_size := font.get_string_size("CDS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size)
	var feature_a_pos := Vector2(feature_a.position.x + 10.0, feature_a.position.y + (feature_a.size.y - feature_a_text_size.y) * 0.5 + _text_ascent(font, body_size))
	var feature_b_pos := Vector2(feature_b.position.x + 10.0, feature_b.position.y + (feature_b.size.y - feature_b_text_size.y) * 0.5 + _text_ascent(font, body_size))
	var feature_caption_pos := Vector2(card.position.x + 12.0, card.end.y - 8.0)
	draw_string(font, feature_a_pos, "geneX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("feature_text", _palette.get("text", Color.BLACK)))
	draw_string(font, feature_b_pos, "CDS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("feature_text", _palette.get("text", Color.BLACK)))
	draw_string(font, feature_caption_pos, "Three AA rows with alternating middle row", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("feature_text", font, feature_a_pos, "geneX", body_size)
	_register_text_rect("feature_text", font, feature_b_pos, "CDS", body_size)
	_register_text_rect("text_muted", font, feature_caption_pos, "Three AA rows with alternating middle row", body_size)


func _draw_genome_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(rect, "Genome")
	var strip := Rect2(rect.position.x + 18.0, rect.position.y + 44.0, rect.size.x - 36.0, rect.size.y - 62.0)
	_draw_rounded_box(strip, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel_alt", strip)
	_register_role_rect("border", strip)
	var grid_col: Color = _palette.get("grid", _palette.get("border", Color.BLACK))
	grid_col.a = minf(grid_col.a, 0.55)
	var grid_y0 := strip.position.y + 10.0
	var grid_y1 := strip.end.y - 10.0
	for frac_any in [0.12, 0.26, 0.40, 0.54, 0.68, 0.82]:
		var frac: float = float(frac_any)
		var x: float = strip.position.x + 10.0 + (strip.size.x - 20.0) * frac
		draw_line(Vector2(x, grid_y0), Vector2(x, grid_y1), grid_col, 2.0)
		_register_role_rect("grid", Rect2(x - 1.0, grid_y0, 2.0, grid_y1 - grid_y0))
	var genome_bar := Rect2(strip.position.x + 10.0, strip.position.y + strip.size.y * 0.45, strip.size.x - 20.0, 16.0)
	draw_rect(genome_bar, _palette.get("genome", Color.BLUE), true)
	_draw_rect_outline(genome_bar, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect("genome", genome_bar)
	var select_fill: Color = _palette.get("region_select_fill", _palette.get("genome", Color.BLUE))
	select_fill.a = minf(maxf(select_fill.a, 0.28), 0.45)
	var selection_rect := Rect2(strip.end.x - 34.0, strip.position.y + 18.0, 18.0, strip.size.y - 36.0)
	draw_rect(selection_rect, select_fill, true)
	_draw_rect_outline(selection_rect, _palette.get("region_select_outline", _palette.get("border", Color.BLACK)), 2.0)
	_register_role_rect("region_select_fill", selection_rect)
	_register_role_rect("region_select_outline", selection_rect)
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var genome_title_pos := Vector2(strip.position.x + 6.0, strip.position.y + 6.0 + _text_ascent(font, body_size))
	var genome_caption_pos := Vector2(strip.position.x + 6.0, strip.end.y - 8.0)
	var mono_font_size := maxi(12, get_theme_default_font_size())
	var mono_font := PREVIEW_MONO_FONT if PREVIEW_MONO_FONT != null else font
	var title_width := font.get_string_size("chr1: 10,000 - 20,000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size).x
	var mono_pos := Vector2(genome_title_pos.x + title_width + 18.0, genome_title_pos.y - 2.0)
	draw_string(font, genome_title_pos, "chr1: 10,000 - 20,000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	var base_colors: Dictionary = _palette.get("pileup_logo_bases", {})
	var ambiguous_color: Color = _palette.get("ambiguous_base", _palette.get("text", Color.BLACK))
	var mono_x := mono_pos.x
	for base in ["A", "C", "G", "T", "N"]:
		var letter := str(base)
		var letter_color: Color = base_colors.get(letter, ambiguous_color)
		var letter_pos := Vector2(mono_x, mono_pos.y)
		draw_string(mono_font, letter_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size, letter_color)
		if letter == "N":
			_register_role_rect("ambiguous_base", Rect2(letter_pos.x, letter_pos.y - _text_ascent(mono_font, mono_font_size), mono_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size).x, mono_font.get_height(mono_font_size)))
		else:
			var role_key := "pileup_base_%s" % letter.to_lower()
			_register_role_rect(role_key, Rect2(letter_pos.x, letter_pos.y - _text_ascent(mono_font, mono_font_size), mono_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size).x, mono_font.get_height(mono_font_size)))
		mono_x += mono_font.get_string_size(letter + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size).x
	draw_string(font, genome_caption_pos, "Genome axis / sequence track", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text", font, genome_title_pos, "chr1: 10,000 - 20,000", body_size)
	_register_text_rect("text_muted", font, genome_caption_pos, "Genome axis / sequence track", body_size)


func _draw_map_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel_alt", Color("efefef")), 14)
	_draw_section_title(rect, "Map")
	var strip := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(strip, _palette.get("panel", Color.WHITE), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel", strip)
	_register_role_rect("border", strip)
	var contig_h := 12.0
	var gap := 14.0
	var contig_w := (strip.size.x - 24.0 - gap) * 0.5
	var contig_y := strip.position.y + strip.size.y * 0.46
	var contig_a := Rect2(strip.position.x + 8.0, contig_y, contig_w, contig_h)
	var contig_b := Rect2(contig_a.end.x + gap, contig_y, contig_w, contig_h)
	draw_rect(contig_a, _palette.get("map_contig", _palette.get("genome", Color.BLUE)), true)
	draw_rect(contig_b, _palette.get("map_contig_alt", _palette.get("map_contig", _palette.get("genome", Color.BLUE))), true)
	_register_role_rect("map_contig", contig_a)
	_register_role_rect("map_contig_alt", contig_b)
	_draw_rect_outline(contig_a, _palette.get("border", Color.BLACK), 1.0)
	_draw_rect_outline(contig_b, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect("border", contig_a)
	_register_role_rect("border", contig_b)
	var fill: Color = _palette.get("map_view_fill", _palette.get("accent", Color("345995")))
	fill.a = minf(fill.a, 0.35)
	if fill.a <= 0.0:
		fill.a = 0.35
	var viewport := Rect2(contig_a.position.x + contig_a.size.x * 0.56, contig_a.position.y - 4.0, contig_a.size.x * 0.26, contig_h + 8.0)
	draw_rect(viewport, fill, true)
	_draw_rect_outline(viewport, _palette.get("map_view_outline", _palette.get("border", Color.BLACK)), 2.0)
	_register_role_rect("map_view_fill", viewport)
	_register_role_rect("map_view_outline", viewport)
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var contig_a_pos := Vector2(contig_a.position.x, contig_a.position.y - 8.0)
	var contig_b_pos := Vector2(contig_b.position.x, contig_b.position.y - 8.0)
	var map_caption_pos := Vector2(strip.position.x + 6.0, strip.end.y - 8.0)
	draw_string(font, contig_a_pos, "contigA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	draw_string(font, contig_b_pos, "contigB", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	draw_string(font, map_caption_pos, "Two contigs with translucent viewport grabber", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text", font, contig_a_pos, "contigA", body_size)
	_register_text_rect("text", font, contig_b_pos, "contigB", body_size)
	_register_text_rect("text_muted", font, map_caption_pos, "Two contigs with translucent viewport grabber", body_size)


func _draw_reads_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(rect, "Reads")
	var band := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(band, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel_alt", band)
	_register_role_rect("border", band)
	var caption_h := 18.0
	var logo_area_h := 42.0
	var reads_top := band.position.y + 10.0
	var rows := 2
	var read_rects: Array[Rect2] = []
	for i in range(rows):
		var y := reads_top + float(i) * 18.0
		var read_rect := Rect2(band.position.x + 8.0 + float(i % 2) * 16.0, y, band.size.x * (0.58 + 0.08 * float(i % 2)), 14.0)
		_draw_rounded_box(read_rect, _palette.get("read", Color.CYAN), _palette.get("border", Color.BLACK), 5, 1)
		_register_role_rect("read", read_rect)
		_register_role_rect("border", read_rect)
		read_rects.append(read_rect)
	if read_rects.size() >= 2:
		var snp_rect := Rect2(read_rects[1].position.x + read_rects[1].size.x * 0.55, read_rects[1].position.y - 2.0, 12.0, 18.0)
		draw_rect(snp_rect, _palette.get("snp", Color.RED), true)
		_draw_rect_outline(snp_rect, _palette.get("border", Color.BLACK), 1.0)
		_register_role_rect("snp", snp_rect)
		_register_role_rect("snp_text", snp_rect)
		_register_role_rect("border", snp_rect)
		var snp_font := get_theme_default_font()
		var snp_font_size := maxi(11, get_theme_default_font_size() - 1)
		var snp_text := "A"
		var snp_text_size := snp_font.get_string_size(snp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, snp_font_size)
		var snp_text_pos := Vector2(
			snp_rect.position.x + (snp_rect.size.x - snp_text_size.x) * 0.5,
			snp_rect.position.y + (snp_rect.size.y - snp_text_size.y) * 0.5 + _text_ascent(snp_font, snp_font_size)
		)
		draw_string(snp_font, snp_text_pos, snp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, snp_font_size, _palette.get("snp_text", _palette.get("text_inverse", Color.WHITE)))
		_register_text_rect("snp_text", snp_font, snp_text_pos, snp_text, snp_font_size)
		var insert_read := read_rects[1]
		var insert_x := insert_read.position.x + insert_read.size.x * 0.80
		var insert_y0 := insert_read.position.y - 2.0
		var insert_y1 := insert_read.end.y + 2.0
		var insert_color: Color = _palette.get("insertion_marker", _palette.get("text", Color.BLACK))
		draw_line(Vector2(insert_x, insert_y0), Vector2(insert_x, insert_y1), insert_color, 3.0)
		draw_line(Vector2(insert_x - 4.5, insert_y0), Vector2(insert_x + 4.5, insert_y0), insert_color, 3.0)
		draw_line(Vector2(insert_x - 4.5, insert_y1), Vector2(insert_x + 4.5, insert_y1), insert_color, 3.0)
		_register_role_rect("insertion_marker", Rect2(insert_x - 5.5, insert_y0 - 1.5, 11.0, insert_y1 - insert_y0 + 3.0))
	var logo_top := maxf(
		read_rects[read_rects.size() - 1].end.y + 14.0 if not read_rects.is_empty() else reads_top + 34.0,
		band.end.y - caption_h - logo_area_h - 4.0
	)
	var logo_col_w := 20.0
	var logo_gap := 10.0
	var logo_x := band.position.x + 10.0
	var base_colors: Dictionary = _palette.get("pileup_logo_bases", {})
	var ambiguous_color: Color = _palette.get("ambiguous_base", _palette.get("text", Color.BLACK))
	var logo_font := PREVIEW_MONO_FONT if PREVIEW_MONO_FONT != null else get_theme_default_font()
	var logo_font_size := maxi(10, get_theme_default_font_size() - 2)
	for col in [
		[["A", 14.0], ["C", 11.0], ["G", 8.0]],
		[["T", 18.0], ["A", 8.0], ["N", 6.0]],
		[["D", 22.0], ["A", 6.0], ["C", 5.0]]
	]:
		var y_cursor := logo_top + 30.0
		for seg_any in col:
			var seg: Array = seg_any
			var base := str(seg[0])
			var h := float(seg[1])
			y_cursor -= h
			var seg_rect := Rect2(logo_x, y_cursor, logo_col_w, h)
			var text_color: Color = base_colors.get(base, ambiguous_color)
			var seg_rect_col := text_color
			seg_rect_col.a = 0.18
			draw_rect(seg_rect, seg_rect_col, true)
			if h > 0.0:
				var tw := logo_font.get_string_size(base, HORIZONTAL_ALIGNMENT_LEFT, -1.0, logo_font_size).x
				var tx := logo_x + (logo_col_w - tw) * 0.5
				var base_ascent := maxf(1.0, logo_font.get_ascent(logo_font_size))
				var base_descent := maxf(0.0, logo_font.get_descent(logo_font_size))
				var base_font_h := maxf(1.0, base_ascent + base_descent)
				var y_scale := (h / base_font_h) * 1.25
				var seg_mid_y := seg_rect.position.y + seg_rect.size.y * 0.5
				var local_baseline_y := base_ascent - base_font_h * 0.5
				draw_set_transform(Vector2(tx, seg_mid_y), 0.0, Vector2(1.0, y_scale))
				draw_string(logo_font, Vector2(0.0, local_baseline_y), base, HORIZONTAL_ALIGNMENT_LEFT, -1.0, logo_font_size, text_color)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if base == "D":
				_register_role_rect("pileup_base_d", seg_rect)
			elif base == "N":
				_register_role_rect("ambiguous_base", seg_rect)
			else:
				_register_role_rect("pileup_base_%s" % base.to_lower(), seg_rect)
		logo_x += logo_col_w + logo_gap
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var reads_caption_pos := Vector2(band.position.x + 6.0, band.end.y - 8.0)
	draw_string(font, reads_caption_pos, "Reads with SNP, insertion and pileup logos", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text_muted", font, reads_caption_pos, "Reads with SNP, insertion and pileup logos", body_size)


func _draw_vcf_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel_alt", Color("efefef")), 14)
	_register_role_rect("panel_alt", rect)
	_register_role_rect("border", rect)
	_draw_section_title(rect, "VCF")
	var row_x := rect.position.x + 18.0
	var row_w := rect.size.x - 36.0
	var row_h := 28.0
	var row_gap := 8.0
	var row_top := rect.position.y + 42.0
	var row_bg := Rect2(row_x, row_top, row_w, row_h)
	var row_alt := Rect2(row_x, row_top + row_h + row_gap, row_w, row_h)
	_draw_rounded_box(row_bg, _palette.get("bg", Color.WHITE), _palette.get("border", Color.BLACK), 6, 1)
	_draw_rounded_box(row_alt, _palette.get("track_alt_bg", _palette.get("panel_alt", Color("efefef"))), _palette.get("border", Color.BLACK), 6, 1)
	_register_role_rect("bg", row_bg)
	_register_role_rect("track_alt_bg", row_alt)
	_register_role_rect("border", row_bg)
	_register_role_rect("border", row_alt)
	var font := get_theme_default_font()
	var body_size := maxi(11, get_theme_default_font_size() - 1)
	var label_ascent := _text_ascent(font, body_size)
	var label_a_pos := Vector2(row_bg.position.x + 10.0, row_bg.position.y + row_bg.size.y * 0.5 + label_ascent * 0.5 - 1.0)
	var label_b_pos := Vector2(row_alt.position.x + 10.0, row_alt.position.y + row_alt.size.y * 0.5 + label_ascent * 0.5 - 1.0)
	draw_string(font, label_a_pos, "Sample A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	draw_string(font, label_b_pos, "Sample B", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	_register_text_rect("text", font, label_a_pos, "Sample A", body_size)
	_register_text_rect("text", font, label_b_pos, "Sample B", body_size)
	var chip_y := row_bg.position.y
	var chip_ref := Rect2(row_bg.position.x + 92.0, chip_y, 64.0, 28.0)
	var chip_het := Rect2(row_bg.position.x + 166.0, chip_y, 64.0, 28.0)
	var chip_alt := Rect2(row_bg.position.x + 240.0, chip_y, 64.0, 28.0)
	_draw_chip(chip_ref, _palette.get("vcf_gt_ref_fill", Color.BLACK), _palette.get("vcf_gt_ref_text", Color.WHITE), "0/0")
	_draw_chip(chip_het, _palette.get("vcf_gt_het_fill", Color.GRAY), _palette.get("vcf_gt_het_text", Color.WHITE), "0/1")
	_draw_chip(chip_alt, _palette.get("vcf_gt_hom_alt_fill", Color.RED), _palette.get("vcf_gt_hom_alt_text", Color.WHITE), "1/1")
	_register_role_rect("vcf_gt_ref_fill", chip_ref)
	_register_role_rect("vcf_gt_het_fill", chip_het)
	_register_role_rect("vcf_gt_hom_alt_fill", chip_alt)
	_register_text_rect("vcf_gt_ref_text", font, Vector2(chip_ref.position.x + 12.0, chip_ref.position.y + 7.0 + _text_ascent(font, body_size)), "0/0", body_size)
	_register_text_rect("vcf_gt_het_text", font, Vector2(chip_het.position.x + 12.0, chip_het.position.y + 7.0 + _text_ascent(font, body_size)), "0/1", body_size)
	_register_text_rect("vcf_gt_hom_alt_text", font, Vector2(chip_alt.position.x + 12.0, chip_alt.position.y + 7.0 + _text_ascent(font, body_size)), "1/1", body_size)
	var vcf_caption_pos := Vector2(rect.position.x + 18.0, row_alt.end.y + 18.0)
	draw_string(font, vcf_caption_pos, "VCF rows use Background / Track alt bg", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text_muted", font, vcf_caption_pos, "VCF rows use Background / Track alt bg", body_size)


func _draw_comparison_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(rect, "Comparison")
	var band := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(band, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel_alt", band)
	_register_role_rect("border", band)
	var footer_h := 40.0
	var content_top := band.position.y + 10.0
	var content_bottom := band.end.y - footer_h - 10.0
	var genome_h := 12.0
	var lane_gap := 14.0
	var lane_h := maxf(0.0, content_bottom - content_top - genome_h * 2.0 - lane_gap * 2.0)
	var top_genome := Rect2(band.position.x + 8.0, content_top, band.size.x - 16.0, genome_h)
	var middle_y := top_genome.end.y + lane_gap
	var bottom_genome := Rect2(band.position.x + 8.0, middle_y + lane_h + lane_gap, band.size.x - 16.0, genome_h)
	draw_rect(top_genome, _palette.get("genome", Color.BLUE), true)
	draw_rect(bottom_genome, _palette.get("genome", Color.BLUE), true)
	_register_role_rect("genome", top_genome)
	_register_role_rect("genome", bottom_genome)
	_draw_rect_outline(top_genome, _palette.get("border", Color.BLACK), 1.0)
	_draw_rect_outline(bottom_genome, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect("border", top_genome)
	_register_role_rect("border", bottom_genome)
	var same := Rect2(band.position.x + 18.0, middle_y, band.size.x * 0.30, lane_h)
	var opp := Rect2(band.position.x + band.size.x * 0.43, middle_y, band.size.x * 0.22, lane_h)
	var selected := Rect2(band.position.x + band.size.x * 0.72, middle_y, band.size.x * 0.16, lane_h)
	draw_rect(same, _palette.get("comparison_same_strand", Color("cb5a4a")), true)
	draw_rect(selected, _palette.get("comparison_selected_fill", Color("ffd84d")), true)
	_register_role_rect("comparison_same_strand", same)
	_register_role_rect("comparison_selected_fill", selected)
	_draw_rect_outline(same, _palette.get("border", Color.BLACK), 1.0)
	_draw_rect_outline(selected, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect("border", same)
	_register_role_rect("border", selected)
	_draw_reverse_match(opp, _palette.get("comparison_opp_strand", Color("4d78b0")))
	_register_role_rect("comparison_opp_strand", opp)
	var same_line_x0 := same.position.x + same.size.x * 0.28
	var same_line_x1 := same.position.x + same.size.x * 0.72
	var match_line_color: Color = _palette.get("comparison_match_line", _palette.get("text", Color.BLACK))
	draw_line(Vector2(same_line_x0, same.position.y + 2.0), Vector2(same_line_x0, same.end.y - 2.0), match_line_color, 2.0)
	draw_line(Vector2(same_line_x1, same.position.y + 2.0), Vector2(same_line_x1, same.end.y - 2.0), match_line_color, 2.0)
	_register_role_rect("comparison_match_line", Rect2(same_line_x0 - 2.0, same.position.y + 2.0, 4.0, same.size.y - 4.0))
	_register_role_rect("comparison_match_line", Rect2(same_line_x1 - 2.0, same.position.y + 2.0, 4.0, same.size.y - 4.0))
	_draw_vertical_wavy_line(Vector2(same.position.x + same.size.x * 0.5, same.position.y + 4.0), Vector2(same.position.x + same.size.x * 0.5, same.end.y - 4.0), _palette.get("comparison_snp", Color.MAGENTA), 2.0, 5.0)
	_register_role_rect("comparison_snp", Rect2(same.position.x + same.size.x * 0.5 - 6.0, same.position.y + 4.0, 12.0, same.size.y - 8.0))
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var footer_y := band.end.y - footer_h + 4.0 + _text_ascent(font, body_size)
	var footer_pos_1 := Vector2(band.position.x + 8.0, footer_y)
	var footer_pos_2 := Vector2(band.position.x + 8.0, footer_y + body_size + 4.0)
	draw_string(font, footer_pos_1, "Top/bottom genomes with", HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 16.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	draw_string(font, footer_pos_2, "forward, reverse and selected matches", HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 16.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text_muted", font, footer_pos_1, "Top/bottom genomes with", body_size, band.size.x - 16.0)
	_register_text_rect("text_muted", font, footer_pos_2, "forward, reverse and selected matches", body_size, band.size.x - 16.0)


func _draw_depth_plot_series_section(rect: Rect2) -> void:
	_draw_panel(rect, _palette.get("panel_alt", Color("efefef")), 14)
	_draw_section_title(rect, "Depth plot colours")
	var plot_rect := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(plot_rect, _palette.get("panel", Color.WHITE), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect("panel", plot_rect)
	_register_role_rect("border", plot_rect)
	var series_colors_any: Variant = _palette.get("depth_plot_series", [])
	var series_colors: Array = []
	if series_colors_any is Array:
		series_colors = series_colors_any
	var fallback_color: Color = _palette.get("depth_plot", _palette.get("read", Color.BLUE))
	var font := get_theme_default_font()
	var body_size := maxi(11, get_theme_default_font_size() - 1)
	var line_gap := 8.0
	var line_h := maxf(12.0, (plot_rect.size.y - line_gap * 5.0 - 12.0) / 6.0)
	var line_w := plot_rect.size.x - 26.0
	var line_x := plot_rect.position.x + 12.0
	var line_y := plot_rect.position.y + 8.0
	for i in range(6):
		var color: Color = fallback_color
		if i < series_colors.size() and series_colors[i] is Color:
			color = series_colors[i]
		var top_y := line_y + float(i) * (line_h + line_gap)
		var points := PackedVector2Array([
			Vector2(line_x, top_y + line_h * 0.80),
			Vector2(line_x + line_w * 0.18, top_y + line_h * 0.35),
			Vector2(line_x + line_w * 0.38, top_y + line_h * 0.62),
			Vector2(line_x + line_w * 0.60, top_y + line_h * 0.18),
			Vector2(line_x + line_w * 0.82, top_y + line_h * 0.48),
			Vector2(line_x + line_w, top_y + line_h * 0.28)
		])
		draw_polyline(points, color, 3.0)
		_register_role_rect("depth_plot_series_%d" % i, _polyline_bounds(points, 4.0))
	var caption_pos := Vector2(plot_rect.position.x + 4.0, plot_rect.end.y - 4.0)
	draw_string(font, caption_pos, "One colour per BAM track, cycled across tracks", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect("text_muted", font, caption_pos, "One colour per BAM track, cycled across tracks", body_size)


func _draw_section_title(rect: Rect2, title: String) -> void:
	var font := get_theme_default_font()
	var title_size := maxi(13, get_theme_default_font_size() + 1)
	var title_pos := Vector2(rect.position.x + 18.0, rect.position.y + 14.0 + _text_ascent(font, title_size))
	draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, _palette.get("text", Color.BLACK))
	_register_text_rect("text", font, title_pos, title, title_size)


func _draw_panel(rect: Rect2, fill: Color, radius: int) -> void:
	_draw_rounded_box(rect, fill, _palette.get("border", Color.BLACK), radius, 1)


func _draw_rounded_box(rect: Rect2, fill: Color, border: Color, radius: int, border_width: int = 1) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, rect)


func _draw_button(rect: Rect2, fill: Color, text: String) -> void:
	draw_rect(rect, fill, true)
	_draw_rect_outline(rect, _palette.get("border", Color.BLACK), 1.0)
	var font := get_theme_default_font()
	var body_size := maxi(12, get_theme_default_font_size())
	var text_pos := Vector2(rect.position.x + 14.0, rect.position.y + 9.0 + _text_ascent(font, body_size))
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 28.0, body_size, _palette.get("text", Color.BLACK))
	_register_text_rect("text", font, text_pos, text, body_size, rect.size.x - 28.0)


func _draw_checkbox_sample(rect: Rect2, checked: bool) -> void:
	var fill: Color = _palette.get("field_bg", Color.WHITE)
	if checked:
		fill = _palette.get("accent", Color.BLUE)
	draw_rect(rect, fill, true)
	_draw_rect_outline(rect, _palette.get("field_border", Color.BLACK), 1.0)
	if checked:
		var check_color: Color = _palette.get("text_inverse", Color.WHITE)
		draw_line(rect.position + Vector2(4.0, rect.size.y * 0.55), rect.position + Vector2(rect.size.x * 0.42, rect.size.y - 5.0), check_color, 2.0)
		draw_line(rect.position + Vector2(rect.size.x * 0.42, rect.size.y - 5.0), rect.position + Vector2(rect.size.x - 4.0, 5.0), check_color, 2.0)


func _draw_chip(rect: Rect2, fill: Color, text_color: Color, text: String) -> void:
	draw_rect(rect, fill, true)
	_draw_rect_outline(rect, _palette.get("border", Color.BLACK), 1.0)
	var font := get_theme_default_font()
	var body_size := maxi(11, get_theme_default_font_size())
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size)
	var text_pos := Vector2(
		rect.position.x + 12.0,
		rect.position.y + (rect.size.y - text_size.y) * 0.5 + _text_ascent(font, body_size)
	)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, text_color)


func _draw_toggle_sample(rect: Rect2, enabled: bool) -> void:
	draw_rect(rect, _palette.get("button_hover", Color("dddddd")), true)
	_draw_rect_outline(rect, _palette.get("border", Color.BLACK), 1.0)
	var knob_r := rect.size.y * 0.34
	var knob_x := rect.end.x - knob_r - 3.5 if enabled else rect.position.x + knob_r + 3.5
	var knob_color: Color = _palette.get("accent", Color.BLUE) if enabled else _palette.get("button_bg", Color.WHITE)
	draw_circle(Vector2(knob_x, rect.position.y + rect.size.y * 0.5), knob_r, knob_color)
	_draw_rect_outline(Rect2(rect.position, rect.size), _palette.get("border", Color.BLACK), 1.0)


func _draw_slider_sample(rect: Rect2) -> void:
	var track := Rect2(rect.position.x, rect.position.y + rect.size.y * 0.40, rect.size.x, 5.0)
	draw_rect(track, _palette.get("button_hover", Color("dddddd")), true)
	_draw_rect_outline(track, _palette.get("border", Color.BLACK), 1.0)
	var active := Rect2(track.position.x, track.position.y, track.size.x * 0.58, track.size.y)
	draw_rect(active, _palette.get("accent", Color.BLUE), true)
	var knob_center := Vector2(active.end.x, rect.position.y + rect.size.y * 0.5)
	draw_circle(knob_center, 7.0, _palette.get("accent", Color.BLUE))


func _draw_panel_scrollbar_sample(track: Rect2) -> void:
	draw_rect(track, _palette.get("panel_alt", Color("efefef")), true)
	_register_role_rect("panel_alt", track)
	var grabber_h := maxf(22.0, track.size.y * 0.42)
	var grabber_y := track.position.y + track.size.y * 0.28
	var grabber := Rect2(track.position.x + 1.0, grabber_y, track.size.x - 2.0, grabber_h)
	draw_rect(grabber, _palette.get("button_bg", Color.WHITE), true)
	_register_role_rect("button_bg", grabber)
	_register_role_rect("scrollbar_outline", grabber)
	_draw_rect_outline(grabber, _palette.get("scrollbar_outline", _palette.get("border", Color.BLACK)), 1.5)


func _draw_rect_outline(rect: Rect2, color: Color, width: float) -> void:
	draw_rect(rect, color, false, width)


func _register_text_rect(role_key: String, font: Font, baseline_pos: Vector2, text: String, font_size: int, width: float = -1.0) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var ascent := _text_ascent(font, font_size)
	_register_role_rect(role_key, Rect2(Vector2(baseline_pos.x, baseline_pos.y - ascent), text_size))


func _polyline_bounds(points: PackedVector2Array, pad: float = 0.0) -> Rect2:
	if points.is_empty():
		return Rect2()
	var min_x := points[0].x
	var min_y := points[0].y
	var max_x := points[0].x
	var max_y := points[0].y
	for point in points:
		min_x = minf(min_x, point.x)
		min_y = minf(min_y, point.y)
		max_x = maxf(max_x, point.x)
		max_y = maxf(max_y, point.y)
	return Rect2(Vector2(min_x, min_y), Vector2(max_x - min_x, max_y - min_y)).grow(pad)


func _register_role_rect(role_key: String, rect: Rect2) -> void:
	if not _role_regions.has(role_key):
		_role_regions[role_key] = []
	(_role_regions[role_key] as Array).append(rect)


func _draw_flash_overlay() -> void:
	if _flash_time_left <= 0.0 or _flash_role_key.is_empty():
		return
	var rects_any: Variant = _role_regions.get(_flash_role_key, [])
	if not (rects_any is Array):
		return
	var phase := 1.0 - (_flash_time_left / FLASH_DURATION)
	var blink := 0.5 + 0.5 * sin(phase * TAU * 3.0)
	var flash_color: Color = _palette.get("accent", Color.YELLOW)
	flash_color.a = 0.18 + 0.22 * blink
	var outline_color: Color = _palette.get("text", Color.BLACK)
	outline_color.a = 0.55 + 0.45 * blink
	for rect_any in rects_any:
		if not (rect_any is Rect2):
			continue
		var rect: Rect2 = rect_any
		if _flash_role_key == "border" or _flash_role_key == "scrollbar_outline":
			draw_rect(rect.grow(2.0), outline_color, false, 3.0)
			continue
		draw_rect(rect, flash_color, true)
		draw_rect(rect.grow(2.0), outline_color, false, 2.0)


func _draw_twisted_connector(start: Vector2, end: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	var steps := 5
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var y := lerpf(start.y, end.y, t)
		var x := start.x + sin(t * TAU * 1.5) * 6.0
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, 2.0)


func _draw_wavy_line(start: Vector2, end: Vector2, color: Color, width: float, amplitude: float) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(start.x, end.x, t)
		var y := lerpf(start.y, end.y, t) + sin(t * TAU * 2.0) * amplitude
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, width)


func _draw_vertical_wavy_line(start: Vector2, end: Vector2, color: Color, width: float, amplitude: float) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(start.x, end.x, t) + sin(t * TAU * 2.0) * amplitude
		var y := lerpf(start.y, end.y, t)
		pts.append(Vector2(x, y))
	draw_polyline(pts, color, width)


func _draw_reverse_match(rect: Rect2, color: Color) -> void:
	var mid_y := rect.position.y + rect.size.y * 0.5
	var top_tri := PackedVector2Array([
		Vector2(rect.position.x, rect.position.y),
		Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x + rect.size.x * 0.5, mid_y)
	])
	var bottom_tri := PackedVector2Array([
		Vector2(rect.position.x, rect.end.y),
		Vector2(rect.end.x, rect.end.y),
		Vector2(rect.position.x + rect.size.x * 0.5, mid_y)
	])
	draw_colored_polygon(top_tri, color)
	draw_colored_polygon(bottom_tri, color)
	draw_polyline(top_tri, _palette.get("border", Color.BLACK), 1.0)
	draw_polyline(bottom_tri, _palette.get("border", Color.BLACK), 1.0)


func _text_ascent(font: Font, font_size: int) -> float:
	if font == null:
		return float(font_size)
	return font.get_ascent(font_size)
