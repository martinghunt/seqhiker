extends Control
class_name ThemePreview

const PREVIEW_MONO_FONT := preload("res://fonts/Anonymous-Pro/Anonymous_Pro.ttf")
const FLASH_DURATION := 1.0
const NARROW_LAYOUT_WIDTH := 860.0
const HEADER_BOX_GAP := 18.0
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
var _flash_role_key := ""
var _flash_time_left := 0.0
var _sections: Dictionary = {}

@onready var _flow: HFlowContainer = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow
@onready var _scroll: ScrollContainer = $PreviewMargin/PreviewScroll
@onready var _flash_overlay: Control = $FlashOverlay
@onready var _header_theme_name: Label = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderTitleSection/Padding/Row/ThemeNameLabel
@onready var _header_status: Label = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderTitleSection/Padding/Row/StatusLabel
@onready var _normal_button: Button = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ButtonsRow/NormalButton
@onready var _hover_button: Button = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ButtonsRow/HoverButton
@onready var _pressed_button: Button = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ButtonsRow/PressedButton
@onready var _check_sample: CheckBox = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ControlsRow/CheckSample
@onready var _toggle_sample: CheckButton = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ControlsRow/ToggleSample
@onready var _slider_sample: HSlider = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ControlsRow/SliderSample
@onready var _scroll_sample: VScrollBar = $PreviewMargin/PreviewScroll/PreviewPadding/SectionsFlow/HeaderControlsSection/Padding/Layout/ScrollSample


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_process(true)
	_collect_sections()
	_sync_header_preview_nodes()
	_update_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		call_deferred("_update_layout")
		queue_redraw()


func set_palette(next_palette: Dictionary, theme_name: String = "") -> void:
	_palette = next_palette.duplicate(true)
	if not theme_name.is_empty():
		_theme_name = theme_name
	_sync_header_preview_nodes()
	queue_redraw()
	_redraw_sections()


func flash_role(role_key: String) -> void:
	_flash_role_key = role_key
	_flash_time_left = FLASH_DURATION
	_redraw_sections()


func _process(delta: float) -> void:
	if _flash_time_left <= 0.0:
		return
	_flash_time_left = maxf(0.0, _flash_time_left - delta)
	_redraw_sections()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _palette.get("bg", Color.WHITE), true)


func draw_preview_section(canvas: Control, section_key: String, rect: Rect2, role_regions: Dictionary) -> void:
	match section_key:
		"bg_overlay":
			_draw_background_flash_overlay(canvas, rect)
		"header_title":
			_draw_header_title(canvas, rect, role_regions)
		"header_controls":
			_draw_header_controls(canvas, rect, role_regions)
		"plot":
			_draw_plot_section(canvas, rect, role_regions)
		"annotation":
			_draw_annotation_section(canvas, rect, role_regions)
		"genome":
			_draw_genome_section(canvas, rect, role_regions)
		"map":
			_draw_map_section(canvas, rect, role_regions)
		"reads":
			_draw_reads_section(canvas, rect, role_regions)
		"vcf":
			_draw_vcf_section(canvas, rect, role_regions)
		"comparison":
			_draw_comparison_section(canvas, rect, role_regions)
		"depth_series":
			_draw_depth_plot_series_section(canvas, rect, role_regions)


func draw_flash_overlay_on(canvas: Control, role_regions: Dictionary) -> void:
	if _flash_time_left <= 0.0 or _flash_role_key.is_empty():
		return
	var rects_any: Variant = role_regions.get(_flash_role_key, [])
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
			canvas.draw_rect(rect.grow(2.0), outline_color, false, 3.0)
			continue
		canvas.draw_rect(rect, flash_color, true)
		canvas.draw_rect(rect.grow(2.0), outline_color, false, 2.0)


func _collect_sections() -> void:
	_sections.clear()
	if _flow == null:
		return
	for child in _flow.get_children():
		if child is Control:
			_sections[String(child.name)] = child


func _redraw_sections() -> void:
	for child_any in _sections.values():
		var child := child_any as Control
		if child != null:
			child.queue_redraw()
	if _flash_overlay != null:
		_flash_overlay.queue_redraw()


func _update_layout() -> void:
	if _flow == null:
		return
	var available_w := maxf(0.0, _flow.size.x)
	if _scroll != null:
		available_w = minf(available_w, _scroll.size.x)
		var v_scrollbar := _scroll.get_v_scroll_bar()
		if v_scrollbar != null and v_scrollbar.visible:
			available_w -= v_scrollbar.size.x
	if available_w <= 0.0:
		return
	var use_single_column := available_w < NARROW_LAYOUT_WIDTH
	if use_single_column:
		_set_section_size("HeaderTitleSection", available_w, HEADER_TITLE_H)
		_set_section_size("HeaderControlsSection", available_w, HEADER_CONTROLS_H)
		_set_section_size("PlotSection", available_w, PLOT_SECTION_H)
		_set_section_size("ReadsSection", available_w, READS_SECTION_H)
		_set_section_size("AnnotationSection", available_w, ANNOT_SECTION_H)
		_set_section_size("DepthSeriesSection", available_w, DEPTH_SERIES_SECTION_H)
		_set_section_size("GenomeSection", available_w, GENOME_SECTION_H)
		_set_section_size("VcfSection", available_w, VCF_SECTION_H)
		_set_section_size("MapSection", available_w, MAP_SECTION_H)
		_set_section_size("ComparisonSection", available_w, COMPARISON_SECTION_H)
		return
	var column_w: float = floor((available_w - HEADER_BOX_GAP) * 0.5)
	_set_section_size("HeaderTitleSection", column_w, HEADER_TITLE_H)
	_set_section_size("HeaderControlsSection", column_w, HEADER_CONTROLS_H)
	_set_section_size("PlotSection", column_w, PLOT_SECTION_H)
	_set_section_size("ReadsSection", column_w, READS_SECTION_H)
	_set_section_size("AnnotationSection", column_w, ANNOT_SECTION_H)
	_set_section_size("DepthSeriesSection", column_w, DEPTH_SERIES_SECTION_H)
	_set_section_size("GenomeSection", column_w, GENOME_SECTION_H)
	_set_section_size("VcfSection", column_w, VCF_SECTION_H)
	_set_section_size("MapSection", column_w, MAP_SECTION_H)
	_set_section_size("ComparisonSection", column_w, COMPARISON_SECTION_H)


func _set_section_size(node_name: String, width: float, height: float) -> void:
	var section := _sections.get(node_name, null) as Control
	if section == null:
		return
	section.custom_minimum_size = Vector2(width, height)


func _draw_header_title(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 12)
	_register_role_rect(role_regions, "panel", rect)
	_register_role_rect(role_regions, "border", rect)
	if _header_theme_name != null:
		_register_role_rect(role_regions, "text", _local_rect_in_section(canvas, _header_theme_name))
	if _header_status != null:
		_register_role_rect(role_regions, "status_error", _local_rect_in_section(canvas, _header_status))


func _draw_header_controls(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 12)
	_register_role_rect(role_regions, "panel", rect)
	_register_role_rect(role_regions, "border", rect)
	if _normal_button != null:
		_register_role_rect(role_regions, "button_bg", _local_rect_in_section(canvas, _normal_button))
	if _hover_button != null:
		_register_role_rect(role_regions, "button_hover", _local_rect_in_section(canvas, _hover_button))
	if _pressed_button != null:
		_register_role_rect(role_regions, "button_pressed", _local_rect_in_section(canvas, _pressed_button))
	if _check_sample != null:
		var check_rect := _local_rect_in_section(canvas, _check_sample)
		_register_role_rect(role_regions, "field_bg", check_rect)
		_register_role_rect(role_regions, "field_border", check_rect)
		_register_role_rect(role_regions, "accent", check_rect)
		_register_role_rect(role_regions, "text_inverse", check_rect)
	if _toggle_sample != null:
		var toggle_rect := _local_rect_in_section(canvas, _toggle_sample)
		_register_role_rect(role_regions, "field_bg", toggle_rect)
		_register_role_rect(role_regions, "field_border", toggle_rect)
		_register_role_rect(role_regions, "accent", toggle_rect)
	if _slider_sample != null:
		var slider_rect := _local_rect_in_section(canvas, _slider_sample)
		_register_role_rect(role_regions, "field_bg", slider_rect)
		_register_role_rect(role_regions, "field_border", slider_rect)
		_register_role_rect(role_regions, "field_focus", slider_rect.grow(4.0))
		_register_role_rect(role_regions, "accent", slider_rect)
	if _scroll_sample != null:
		var scroll_rect := _local_rect_in_section(canvas, _scroll_sample)
		_register_role_rect(role_regions, "panel_alt", scroll_rect)
		_register_role_rect(role_regions, "button_bg", scroll_rect)
		_register_role_rect(role_regions, "scrollbar_outline", scroll_rect)


func _draw_plot_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(canvas, rect, "Plots", role_regions)
	var plot_rect := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, plot_rect, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel_alt", plot_rect)
	_register_role_rect(role_regions, "border", plot_rect)
	var mid_y := plot_rect.position.y + plot_rect.size.y * 0.5
	var gc_points := PackedVector2Array([
		Vector2(plot_rect.position.x + 6.0, mid_y + 8.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.20, mid_y - 10.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.42, mid_y + 4.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.64, mid_y - 16.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.82, mid_y + 2.0),
		Vector2(plot_rect.end.x - 6.0, mid_y - 8.0)
	])
	canvas.draw_polyline(gc_points, _palette.get("gc_plot", _palette.get("read", Color.CYAN)), 3.0)
	var depth_points := PackedVector2Array([
		Vector2(plot_rect.position.x + 6.0, mid_y + 24.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.22, mid_y + 8.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.40, mid_y + 22.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.62, mid_y - 6.0),
		Vector2(plot_rect.position.x + plot_rect.size.x * 0.80, mid_y + 18.0),
		Vector2(plot_rect.end.x - 6.0, mid_y - 2.0)
	])
	canvas.draw_polyline(depth_points, _palette.get("depth_plot", Color.BLUE), 3.0)
	_register_role_rect(role_regions, "gc_plot", _polyline_bounds(gc_points, 4.0))
	_register_role_rect(role_regions, "depth_plot", _polyline_bounds(depth_points, 4.0))
	var caption_font := _default_font(canvas)
	var caption_size := maxi(11, _default_font_size(canvas) - 1)
	var caption_pos := Vector2(plot_rect.position.x + 4.0, plot_rect.end.y - 8.0)
	canvas.draw_string(caption_font, caption_pos, "GC and depth overview", HORIZONTAL_ALIGNMENT_LEFT, -1.0, caption_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", caption_font, caption_pos, "GC and depth overview", caption_size)


func _draw_annotation_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(canvas, rect, "AA / Annotation", role_regions)
	var card := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, card, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel_alt", card)
	_register_role_rect(role_regions, "border", card)
	var rows_area := Rect2(card.position.x + 8.0, card.position.y + 10.0, card.size.x - 16.0, card.size.y - 38.0)
	var row_gap := 4.0
	var row_h: float = floor((rows_area.size.y - row_gap * 2.0) / 3.0)
	var row_rects: Array[Rect2] = []
	for i in range(3):
		var row_rect := Rect2(rows_area.position.x, rows_area.position.y + i * (row_h + row_gap), rows_area.size.x, row_h)
		var row_color: Color = _palette.get("bg", Color.WHITE)
		if i == 1:
			row_color = _palette.get("track_alt_bg", row_color)
			_register_role_rect(role_regions, "track_alt_bg", row_rect)
		else:
			_register_role_rect(role_regions, "bg", row_rect)
		canvas.draw_rect(row_rect, row_color, true)
		_draw_rect_outline(canvas, row_rect, _palette.get("border", Color.BLACK), 1.0)
		row_rects.append(row_rect)
	var feature_a := Rect2(row_rects[0].position.x + 16.0, row_rects[0].position.y + 4.0, row_rects[0].size.x * 0.5, row_rects[0].size.y - 8.0)
	var feature_b := Rect2(row_rects[1].position.x + row_rects[1].size.x * 0.26, row_rects[1].position.y + 4.0, row_rects[1].size.x * 0.44, row_rects[1].size.y - 8.0)
	canvas.draw_rect(feature_a, _palette.get("feature", Color("dce8f7")), true)
	canvas.draw_rect(feature_b, _palette.get("feature", Color("dce8f7")), true)
	_draw_rect_outline(canvas, feature_a, _palette.get("feature_accent", _palette.get("border", Color.BLACK)), 2.0)
	_draw_rect_outline(canvas, feature_b, _palette.get("feature_accent", _palette.get("border", Color.BLACK)), 2.0)
	_register_role_rect(role_regions, "feature", feature_a)
	_register_role_rect(role_regions, "feature", feature_b)
	_register_role_rect(role_regions, "feature_accent", feature_a)
	_register_role_rect(role_regions, "feature_accent", feature_b)
	var stop_color: Color = _palette.get("stop_codon", _palette.get("text", Color.BLACK))
	for marker in [
		Rect2(row_rects[0].position.x + row_rects[0].size.x * 0.80, row_rects[0].position.y + 3.0, 4.0, row_rects[0].size.y - 6.0),
		Rect2(row_rects[1].position.x + row_rects[1].size.x * 0.12, row_rects[1].position.y + 3.0, 4.0, row_rects[1].size.y - 6.0),
		Rect2(row_rects[2].position.x + row_rects[2].size.x * 0.58, row_rects[2].position.y + 3.0, 4.0, row_rects[2].size.y - 6.0)
	]:
		canvas.draw_rect(marker, stop_color, true)
		_register_role_rect(role_regions, "stop_codon", marker)
	var font := _default_font(canvas)
	var body_size := maxi(12, _default_font_size(canvas))
	var feature_a_text_size := font.get_string_size("geneX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size)
	var feature_b_text_size := font.get_string_size("CDS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size)
	var feature_a_pos := Vector2(feature_a.position.x + 10.0, feature_a.position.y + (feature_a.size.y - feature_a_text_size.y) * 0.5 + _text_ascent(font, body_size))
	var feature_b_pos := Vector2(feature_b.position.x + 10.0, feature_b.position.y + (feature_b.size.y - feature_b_text_size.y) * 0.5 + _text_ascent(font, body_size))
	var feature_caption_pos := Vector2(card.position.x + 12.0, card.end.y - 8.0)
	canvas.draw_string(font, feature_a_pos, "geneX", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("feature_text", _palette.get("text", Color.BLACK)))
	canvas.draw_string(font, feature_b_pos, "CDS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("feature_text", _palette.get("text", Color.BLACK)))
	canvas.draw_string(font, feature_caption_pos, "Three AA rows with alternating middle row", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "feature_text", font, feature_a_pos, "geneX", body_size)
	_register_text_rect(role_regions, "feature_text", font, feature_b_pos, "CDS", body_size)
	_register_text_rect(role_regions, "text_muted", font, feature_caption_pos, "Three AA rows with alternating middle row", body_size)


func _draw_genome_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(canvas, rect, "Genome", role_regions)
	var strip := Rect2(rect.position.x + 18.0, rect.position.y + 44.0, rect.size.x - 36.0, rect.size.y - 62.0)
	_draw_rounded_box(canvas, strip, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel_alt", strip)
	_register_role_rect(role_regions, "border", strip)
	var grid_col: Color = _palette.get("grid", _palette.get("border", Color.BLACK))
	grid_col.a = minf(grid_col.a, 0.55)
	var grid_y0 := strip.position.y + 10.0
	var grid_y1 := strip.end.y - 10.0
	for frac_any in [0.12, 0.26, 0.40, 0.54, 0.68, 0.82]:
		var frac: float = float(frac_any)
		var x: float = strip.position.x + 10.0 + (strip.size.x - 20.0) * frac
		canvas.draw_line(Vector2(x, grid_y0), Vector2(x, grid_y1), grid_col, 2.0)
		_register_role_rect(role_regions, "grid", Rect2(x - 1.0, grid_y0, 2.0, grid_y1 - grid_y0))
	var genome_bar := Rect2(strip.position.x + 10.0, strip.position.y + strip.size.y * 0.45, strip.size.x - 20.0, 16.0)
	canvas.draw_rect(genome_bar, _palette.get("genome", Color.BLUE), true)
	_draw_rect_outline(canvas, genome_bar, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect(role_regions, "genome", genome_bar)
	var selection_rect := Rect2(strip.end.x - 34.0, strip.position.y + 18.0, 18.0, strip.size.y - 36.0)
	var select_fill: Color = _palette.get("region_select_fill", _palette.get("genome", Color.BLUE))
	select_fill.a = 0.35
	canvas.draw_rect(selection_rect, select_fill, true)
	_draw_rect_outline(canvas, selection_rect, _palette.get("region_select_outline", _palette.get("border", Color.BLACK)), 2.0)
	_register_role_rect(role_regions, "region_select_fill", selection_rect)
	_register_role_rect(role_regions, "region_select_outline", selection_rect)
	var font := _default_font(canvas)
	var body_size := maxi(12, _default_font_size(canvas))
	var genome_title_pos := Vector2(strip.position.x + 6.0, strip.position.y + 6.0 + _text_ascent(font, body_size))
	var genome_caption_pos := Vector2(strip.position.x + 6.0, strip.end.y - 8.0)
	var mono_font_size := maxi(12, _default_font_size(canvas))
	var mono_font := PREVIEW_MONO_FONT if PREVIEW_MONO_FONT != null else font
	var title_width := font.get_string_size("chr1: 10,000 - 20,000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size).x
	var mono_pos := Vector2(genome_title_pos.x + title_width + 18.0, genome_title_pos.y - 2.0)
	canvas.draw_string(font, genome_title_pos, "chr1: 10,000 - 20,000", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	_register_text_rect(role_regions, "text", font, genome_title_pos, "chr1: 10,000 - 20,000", body_size)
	var base_colors: Dictionary = _palette.get("pileup_logo_bases", {})
	var ambiguous_color: Color = _palette.get("ambiguous_base", _palette.get("text", Color.BLACK))
	var mono_x := mono_pos.x
	for base in ["A", "C", "G", "T", "N"]:
		var letter := str(base)
		var letter_color: Color = base_colors.get(letter, ambiguous_color)
		var letter_pos := Vector2(mono_x, mono_pos.y)
		canvas.draw_string(mono_font, letter_pos, letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size, letter_color)
		var letter_rect := Rect2(letter_pos.x, letter_pos.y - _text_ascent(mono_font, mono_font_size), mono_font.get_string_size(letter, HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size).x, mono_font.get_height(mono_font_size))
		if letter == "N":
			_register_role_rect(role_regions, "ambiguous_base", letter_rect)
		else:
			_register_role_rect(role_regions, "pileup_base_%s" % letter.to_lower(), letter_rect)
		mono_x += mono_font.get_string_size(letter + " ", HORIZONTAL_ALIGNMENT_LEFT, -1.0, mono_font_size).x
	canvas.draw_string(font, genome_caption_pos, "Genome axis / sequence track", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", font, genome_caption_pos, "Genome axis / sequence track", body_size)


func _draw_map_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel_alt", Color("efefef")), 14)
	_draw_section_title(canvas, rect, "Map", role_regions)
	var strip := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, strip, _palette.get("panel", Color.WHITE), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel", strip)
	_register_role_rect(role_regions, "border", strip)
	var contig_h := 12.0
	var gap := 14.0
	var contig_w := (strip.size.x - 24.0 - gap) * 0.5
	var contig_y := strip.position.y + strip.size.y * 0.46
	var contig_a := Rect2(strip.position.x + 8.0, contig_y, contig_w, contig_h)
	var contig_b := Rect2(contig_a.end.x + gap, contig_y, contig_w, contig_h)
	canvas.draw_rect(contig_a, _palette.get("map_contig", _palette.get("genome", Color.BLUE)), true)
	canvas.draw_rect(contig_b, _palette.get("map_contig_alt", _palette.get("map_contig", _palette.get("genome", Color.BLUE))), true)
	_register_role_rect(role_regions, "map_contig", contig_a)
	_register_role_rect(role_regions, "map_contig_alt", contig_b)
	var fill: Color = _palette.get("map_view_fill", _palette.get("accent", Color("345995")))
	fill.a = 0.35
	var viewport := Rect2(contig_a.position.x + contig_a.size.x * 0.56, contig_a.position.y - 4.0, contig_a.size.x * 0.26, contig_h + 8.0)
	canvas.draw_rect(viewport, fill, true)
	_draw_rect_outline(canvas, viewport, _palette.get("map_view_outline", _palette.get("border", Color.BLACK)), 2.0)
	_register_role_rect(role_regions, "map_view_fill", viewport)
	_register_role_rect(role_regions, "map_view_outline", viewport)
	var font := _default_font(canvas)
	var body_size := maxi(12, _default_font_size(canvas))
	var contig_a_pos := Vector2(contig_a.position.x, contig_a.position.y - 8.0)
	var contig_b_pos := Vector2(contig_b.position.x, contig_b.position.y - 8.0)
	var map_caption_pos := Vector2(strip.position.x + 6.0, strip.end.y - 8.0)
	canvas.draw_string(font, contig_a_pos, "contigA", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	canvas.draw_string(font, contig_b_pos, "contigB", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	canvas.draw_string(font, map_caption_pos, "Two contigs with translucent viewport grabber", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text", font, contig_a_pos, "contigA", body_size)
	_register_text_rect(role_regions, "text", font, contig_b_pos, "contigB", body_size)
	_register_text_rect(role_regions, "text_muted", font, map_caption_pos, "Two contigs with translucent viewport grabber", body_size)


func _draw_reads_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(canvas, rect, "Reads", role_regions)
	var band := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, band, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel_alt", band)
	_register_role_rect(role_regions, "border", band)
	var read_a := Rect2(band.position.x + 8.0, band.position.y + 12.0, band.size.x * 0.58, 14.0)
	var read_b := Rect2(band.position.x + 24.0, band.position.y + 30.0, band.size.x * 0.64, 14.0)
	_draw_rounded_box(canvas, read_a, _palette.get("read", Color.CYAN), _palette.get("border", Color.BLACK), 5, 1)
	_draw_rounded_box(canvas, read_b, _palette.get("read", Color.CYAN), _palette.get("border", Color.BLACK), 5, 1)
	_register_role_rect(role_regions, "read", read_a)
	_register_role_rect(role_regions, "read", read_b)
	var snp_rect := Rect2(read_b.position.x + read_b.size.x * 0.55, read_b.position.y - 2.0, 12.0, 18.0)
	canvas.draw_rect(snp_rect, _palette.get("snp", Color.RED), true)
	_draw_rect_outline(canvas, snp_rect, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect(role_regions, "snp", snp_rect)
	_register_role_rect(role_regions, "snp_text", snp_rect)
	var snp_font := _default_font(canvas)
	var snp_font_size := maxi(11, _default_font_size(canvas) - 1)
	var snp_text := "A"
	var snp_text_size := snp_font.get_string_size(snp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, snp_font_size)
	var snp_text_pos := Vector2(
		snp_rect.position.x + (snp_rect.size.x - snp_text_size.x) * 0.5,
		snp_rect.position.y + (snp_rect.size.y - snp_text_size.y) * 0.5 + _text_ascent(snp_font, snp_font_size)
	)
	canvas.draw_string(snp_font, snp_text_pos, snp_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, snp_font_size, _palette.get("snp_text", _palette.get("text_inverse", Color.WHITE)))
	_register_text_rect(role_regions, "snp_text", snp_font, snp_text_pos, snp_text, snp_font_size)
	var insert_x := read_b.position.x + read_b.size.x * 0.80
	var insert_y0 := read_b.position.y - 2.0
	var insert_y1 := read_b.end.y + 2.0
	var insert_color: Color = _palette.get("insertion_marker", _palette.get("text", Color.BLACK))
	canvas.draw_line(Vector2(insert_x, insert_y0), Vector2(insert_x, insert_y1), insert_color, 3.0)
	canvas.draw_line(Vector2(insert_x - 4.5, insert_y0), Vector2(insert_x + 4.5, insert_y0), insert_color, 3.0)
	canvas.draw_line(Vector2(insert_x - 4.5, insert_y1), Vector2(insert_x + 4.5, insert_y1), insert_color, 3.0)
	_register_role_rect(role_regions, "insertion_marker", Rect2(insert_x - 5.5, insert_y0 - 1.5, 11.0, insert_y1 - insert_y0 + 3.0))
	var caption_h := 18.0
	var logo_area_h := 42.0
	var logo_top := maxf(read_b.end.y + 14.0, band.end.y - caption_h - logo_area_h - 4.0)
	var logo_col_w := 20.0
	var logo_gap := 10.0
	var logo_x := band.position.x + 10.0
	var base_colors: Dictionary = _palette.get("pileup_logo_bases", {})
	var ambiguous_color: Color = _palette.get("ambiguous_base", _palette.get("text", Color.BLACK))
	var logo_font := PREVIEW_MONO_FONT if PREVIEW_MONO_FONT != null else _default_font(canvas)
	var logo_font_size := maxi(10, _default_font_size(canvas) - 2)
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
			canvas.draw_rect(seg_rect, seg_rect_col, true)
			if h > 0.0:
				var tw := logo_font.get_string_size(base, HORIZONTAL_ALIGNMENT_LEFT, -1.0, logo_font_size).x
				var tx := logo_x + (logo_col_w - tw) * 0.5
				var base_ascent := maxf(1.0, logo_font.get_ascent(logo_font_size))
				var base_descent := maxf(0.0, logo_font.get_descent(logo_font_size))
				var base_font_h := maxf(1.0, base_ascent + base_descent)
				var y_scale := (h / base_font_h) * 1.25
				var seg_mid_y := seg_rect.position.y + seg_rect.size.y * 0.5
				var local_baseline_y := base_ascent - base_font_h * 0.5
				canvas.draw_set_transform(Vector2(tx, seg_mid_y), 0.0, Vector2(1.0, y_scale))
				canvas.draw_string(logo_font, Vector2(0.0, local_baseline_y), base, HORIZONTAL_ALIGNMENT_LEFT, -1.0, logo_font_size, text_color)
				canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if base == "D":
				_register_role_rect(role_regions, "pileup_base_d", seg_rect)
			elif base == "N":
				_register_role_rect(role_regions, "ambiguous_base", seg_rect)
			else:
				_register_role_rect(role_regions, "pileup_base_%s" % base.to_lower(), seg_rect)
		logo_x += logo_col_w + logo_gap
	var font := _default_font(canvas)
	var body_size := maxi(12, _default_font_size(canvas))
	var reads_caption_pos := Vector2(band.position.x + 6.0, band.end.y - 8.0)
	canvas.draw_string(font, reads_caption_pos, "Reads with SNP, insertion and pileup logos", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", font, reads_caption_pos, "Reads with SNP, insertion and pileup logos", body_size)


func _draw_vcf_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel_alt", Color("efefef")), 14)
	_register_role_rect(role_regions, "panel_alt", rect)
	_register_role_rect(role_regions, "border", rect)
	_draw_section_title(canvas, rect, "VCF", role_regions)
	var row_x := rect.position.x + 18.0
	var row_w := rect.size.x - 36.0
	var row_h := 28.0
	var row_gap := 8.0
	var row_top := rect.position.y + 42.0
	var row_bg := Rect2(row_x, row_top, row_w, row_h)
	var row_alt := Rect2(row_x, row_top + row_h + row_gap, row_w, row_h)
	_draw_rounded_box(canvas, row_bg, _palette.get("bg", Color.WHITE), _palette.get("border", Color.BLACK), 6, 1)
	_draw_rounded_box(canvas, row_alt, _palette.get("track_alt_bg", _palette.get("panel_alt", Color("efefef"))), _palette.get("border", Color.BLACK), 6, 1)
	_register_role_rect(role_regions, "bg", row_bg)
	_register_role_rect(role_regions, "track_alt_bg", row_alt)
	_register_role_rect(role_regions, "border", row_bg)
	_register_role_rect(role_regions, "border", row_alt)
	var font := _default_font(canvas)
	var body_size := maxi(11, _default_font_size(canvas) - 1)
	var label_ascent := _text_ascent(font, body_size)
	var label_a_pos := Vector2(row_bg.position.x + 10.0, row_bg.position.y + row_bg.size.y * 0.5 + label_ascent * 0.5 - 1.0)
	var label_b_pos := Vector2(row_alt.position.x + 10.0, row_alt.position.y + row_alt.size.y * 0.5 + label_ascent * 0.5 - 1.0)
	canvas.draw_string(font, label_a_pos, "Sample A", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	canvas.draw_string(font, label_b_pos, "Sample B", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text", Color.BLACK))
	_register_text_rect(role_regions, "text", font, label_a_pos, "Sample A", body_size)
	_register_text_rect(role_regions, "text", font, label_b_pos, "Sample B", body_size)
	var chip_ref := Rect2(row_bg.position.x + 92.0, row_bg.position.y, 64.0, 28.0)
	var chip_het := Rect2(row_bg.position.x + 166.0, row_bg.position.y, 64.0, 28.0)
	var chip_alt := Rect2(row_bg.position.x + 240.0, row_bg.position.y, 64.0, 28.0)
	_draw_chip(canvas, chip_ref, _palette.get("vcf_gt_ref_fill", Color.BLACK), _palette.get("vcf_gt_ref_text", Color.WHITE), "0/0")
	_draw_chip(canvas, chip_het, _palette.get("vcf_gt_het_fill", Color.GRAY), _palette.get("vcf_gt_het_text", Color.WHITE), "0/1")
	_draw_chip(canvas, chip_alt, _palette.get("vcf_gt_hom_alt_fill", Color.RED), _palette.get("vcf_gt_hom_alt_text", Color.WHITE), "1/1")
	_register_role_rect(role_regions, "vcf_gt_ref_fill", chip_ref)
	_register_role_rect(role_regions, "vcf_gt_het_fill", chip_het)
	_register_role_rect(role_regions, "vcf_gt_hom_alt_fill", chip_alt)
	_register_text_rect(role_regions, "vcf_gt_ref_text", font, Vector2(chip_ref.position.x + 12.0, chip_ref.position.y + 7.0 + _text_ascent(font, body_size)), "0/0", body_size)
	_register_text_rect(role_regions, "vcf_gt_het_text", font, Vector2(chip_het.position.x + 12.0, chip_het.position.y + 7.0 + _text_ascent(font, body_size)), "0/1", body_size)
	_register_text_rect(role_regions, "vcf_gt_hom_alt_text", font, Vector2(chip_alt.position.x + 12.0, chip_alt.position.y + 7.0 + _text_ascent(font, body_size)), "1/1", body_size)
	var vcf_caption_pos := Vector2(rect.position.x + 18.0, row_alt.end.y + 18.0)
	canvas.draw_string(font, vcf_caption_pos, "VCF rows use Background / Track alt bg", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", font, vcf_caption_pos, "VCF rows use Background / Track alt bg", body_size)


func _draw_comparison_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel", Color.WHITE), 14)
	_draw_section_title(canvas, rect, "Comparison", role_regions)
	var band := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, band, _palette.get("panel_alt", Color("efefef")), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel_alt", band)
	_register_role_rect(role_regions, "border", band)
	var top_genome := Rect2(band.position.x + 8.0, band.position.y + 10.0, band.size.x - 16.0, 12.0)
	var bottom_genome := Rect2(band.position.x + 8.0, band.end.y - 62.0, band.size.x - 16.0, 12.0)
	canvas.draw_rect(top_genome, _palette.get("genome", Color.BLUE), true)
	canvas.draw_rect(bottom_genome, _palette.get("genome", Color.BLUE), true)
	_register_role_rect(role_regions, "genome", top_genome)
	_register_role_rect(role_regions, "genome", bottom_genome)
	_draw_rect_outline(canvas, top_genome, _palette.get("border", Color.BLACK), 1.0)
	_draw_rect_outline(canvas, bottom_genome, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect(role_regions, "border", top_genome)
	_register_role_rect(role_regions, "border", bottom_genome)
	var lane_y := top_genome.end.y + 14.0
	var lane_h := maxf(20.0, bottom_genome.position.y - lane_y - 14.0)
	var same := Rect2(band.position.x + 18.0, lane_y, band.size.x * 0.30, lane_h)
	var opp := Rect2(band.position.x + band.size.x * 0.43, lane_y, band.size.x * 0.22, lane_h)
	var selected := Rect2(band.position.x + band.size.x * 0.72, lane_y, band.size.x * 0.16, lane_h)
	canvas.draw_rect(same, _palette.get("comparison_same_strand", Color("cb5a4a")), true)
	canvas.draw_rect(selected, _palette.get("comparison_selected_fill", Color("ffd84d")), true)
	_register_role_rect(role_regions, "comparison_same_strand", same)
	_register_role_rect(role_regions, "comparison_selected_fill", selected)
	_draw_rect_outline(canvas, same, _palette.get("border", Color.BLACK), 1.0)
	_draw_rect_outline(canvas, selected, _palette.get("border", Color.BLACK), 1.0)
	_register_role_rect(role_regions, "border", same)
	_register_role_rect(role_regions, "border", selected)
	_draw_reverse_match(canvas, opp, _palette.get("comparison_opp_strand", Color("4d78b0")))
	_register_role_rect(role_regions, "comparison_opp_strand", opp)
	var match_line_color: Color = _palette.get("comparison_match_line", _palette.get("text", Color.BLACK))
	var same_line_x0 := same.position.x + same.size.x * 0.28
	var same_line_x1 := same.position.x + same.size.x * 0.72
	canvas.draw_line(Vector2(same_line_x0, same.position.y + 2.0), Vector2(same_line_x0, same.end.y - 2.0), match_line_color, 2.0)
	canvas.draw_line(Vector2(same_line_x1, same.position.y + 2.0), Vector2(same_line_x1, same.end.y - 2.0), match_line_color, 2.0)
	_register_role_rect(role_regions, "comparison_match_line", Rect2(same_line_x0 - 2.0, same.position.y + 2.0, 4.0, same.size.y - 4.0))
	_register_role_rect(role_regions, "comparison_match_line", Rect2(same_line_x1 - 2.0, same.position.y + 2.0, 4.0, same.size.y - 4.0))
	_draw_vertical_wavy_line(canvas, Vector2(same.position.x + same.size.x * 0.5, same.position.y + 4.0), Vector2(same.position.x + same.size.x * 0.5, same.end.y - 4.0), _palette.get("comparison_snp", Color.MAGENTA), 2.0, 5.0)
	_register_role_rect(role_regions, "comparison_snp", Rect2(same.position.x + same.size.x * 0.5 - 6.0, same.position.y + 4.0, 12.0, same.size.y - 8.0))
	var font := _default_font(canvas)
	var body_size := maxi(12, _default_font_size(canvas))
	var footer_y := band.end.y - 36.0 + 4.0 + _text_ascent(font, body_size)
	var footer_pos_1 := Vector2(band.position.x + 8.0, footer_y)
	var footer_pos_2 := Vector2(band.position.x + 8.0, footer_y + body_size + 4.0)
	canvas.draw_string(font, footer_pos_1, "Top/bottom genomes with", HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 16.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	canvas.draw_string(font, footer_pos_2, "forward, reverse and selected matches", HORIZONTAL_ALIGNMENT_LEFT, band.size.x - 16.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", font, footer_pos_1, "Top/bottom genomes with", body_size, band.size.x - 16.0)
	_register_text_rect(role_regions, "text_muted", font, footer_pos_2, "forward, reverse and selected matches", body_size, band.size.x - 16.0)


func _draw_depth_plot_series_section(canvas: Control, rect: Rect2, role_regions: Dictionary) -> void:
	_draw_panel(canvas, rect, _palette.get("panel_alt", Color("efefef")), 14)
	_draw_section_title(canvas, rect, "Depth plot colours", role_regions)
	var plot_rect := Rect2(rect.position.x + 18.0, rect.position.y + 42.0, rect.size.x - 36.0, rect.size.y - 60.0)
	_draw_rounded_box(canvas, plot_rect, _palette.get("panel", Color.WHITE), _palette.get("border", Color.BLACK), 8, 1)
	_register_role_rect(role_regions, "panel", plot_rect)
	_register_role_rect(role_regions, "border", plot_rect)
	var series_colors_any: Variant = _palette.get("depth_plot_series", [])
	var series_colors: Array = series_colors_any if series_colors_any is Array else []
	var fallback_color: Color = _palette.get("depth_plot", _palette.get("read", Color.BLUE))
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
		canvas.draw_polyline(points, color, 3.0)
		_register_role_rect(role_regions, "depth_plot_series_%d" % i, _polyline_bounds(points, 4.0))
	var font := _default_font(canvas)
	var body_size := maxi(11, _default_font_size(canvas) - 1)
	var caption_pos := Vector2(plot_rect.position.x + 4.0, plot_rect.end.y - 4.0)
	canvas.draw_string(font, caption_pos, "One colour per BAM track, cycled across tracks", HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, _palette.get("text_muted", _palette.get("text", Color.BLACK)))
	_register_text_rect(role_regions, "text_muted", font, caption_pos, "One colour per BAM track, cycled across tracks", body_size)


func _draw_section_title(canvas: Control, rect: Rect2, title: String, role_regions: Dictionary) -> void:
	var font := _default_font(canvas)
	var title_size := maxi(13, _default_font_size(canvas) + 1)
	var title_pos := Vector2(rect.position.x + 18.0, rect.position.y + 14.0 + _text_ascent(font, title_size))
	canvas.draw_string(font, title_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, title_size, _palette.get("text", Color.BLACK))
	_register_text_rect(role_regions, "text", font, title_pos, title, title_size)


func _draw_panel(canvas: Control, rect: Rect2, fill: Color, radius: int) -> void:
	_draw_rounded_box(canvas, rect, fill, _palette.get("border", Color.BLACK), radius, 1)


func _draw_rounded_box(canvas: Control, rect: Rect2, fill: Color, border: Color, radius: int, border_width: int = 1) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	canvas.draw_style_box(sb, rect)


func _draw_chip(canvas: Control, rect: Rect2, fill: Color, text_color: Color, text: String) -> void:
	canvas.draw_rect(rect, fill, true)
	_draw_rect_outline(canvas, rect, _palette.get("border", Color.BLACK), 1.0)
	var font := _default_font(canvas)
	var body_size := maxi(11, _default_font_size(canvas))
	var text_pos := Vector2(rect.position.x + 12.0, rect.position.y + 7.0 + _text_ascent(font, body_size))
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, body_size, text_color)


func _draw_rect_outline(canvas: Control, rect: Rect2, color: Color, width: float) -> void:
	canvas.draw_rect(rect, color, false, width)


func _draw_vertical_wavy_line(canvas: Control, start: Vector2, end: Vector2, color: Color, width: float, amplitude: float) -> void:
	var pts := PackedVector2Array()
	var steps := 18
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var x := lerpf(start.x, end.x, t) + sin(t * TAU * 2.0) * amplitude
		var y := lerpf(start.y, end.y, t)
		pts.append(Vector2(x, y))
	canvas.draw_polyline(pts, color, width)


func _draw_reverse_match(canvas: Control, rect: Rect2, color: Color) -> void:
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
	canvas.draw_colored_polygon(top_tri, color)
	canvas.draw_colored_polygon(bottom_tri, color)
	canvas.draw_polyline(top_tri, _palette.get("border", Color.BLACK), 1.0)
	canvas.draw_polyline(bottom_tri, _palette.get("border", Color.BLACK), 1.0)


func _register_text_rect(role_regions: Dictionary, role_key: String, font: Font, baseline_pos: Vector2, text: String, font_size: int, width: float = -1.0) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, font_size)
	var ascent := _text_ascent(font, font_size)
	_register_role_rect(role_regions, role_key, Rect2(Vector2(baseline_pos.x, baseline_pos.y - ascent), text_size))


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


func _register_role_rect(role_regions: Dictionary, role_key: String, rect: Rect2) -> void:
	if not role_regions.has(role_key):
		role_regions[role_key] = []
	(role_regions[role_key] as Array).append(rect)


func _text_ascent(font: Font, font_size: int) -> float:
	if font == null:
		return float(font_size)
	return font.get_ascent(font_size)


func _default_font(canvas: Control) -> Font:
	var font := canvas.get_theme_default_font()
	if font != null:
		return font
	return ThemeDB.fallback_font


func _default_font_size(canvas: Control) -> int:
	return maxi(12, canvas.get_theme_default_font_size())


func _draw_background_flash_overlay(canvas: Control, rect: Rect2) -> void:
	if _flash_role_key != "bg" or _flash_time_left <= 0.0:
		return
	var phase := 1.0 - (_flash_time_left / FLASH_DURATION)
	var blink := 0.5 + 0.5 * sin(phase * TAU * 3.0)
	var flash_color: Color = _palette.get("accent", Color.YELLOW)
	flash_color.a = 0.18 + 0.22 * blink
	var outline_color: Color = _palette.get("text", Color.BLACK)
	outline_color.a = 0.55 + 0.45 * blink
	canvas.draw_rect(rect, flash_color, true)
	canvas.draw_rect(rect.grow(-1.0), outline_color, false, 2.0)


func _sync_header_preview_nodes() -> void:
	if _header_theme_name != null:
		_header_theme_name.text = _theme_name
		_header_theme_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header_theme_name.add_theme_color_override("font_color", _palette.get("text", Color.BLACK))
	if _header_status != null:
		_header_status.text = "Error message"
		_header_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header_status.add_theme_color_override("font_color", _palette.get("status_error", Color("8b1f1f")))
	for button in [_normal_button, _hover_button, _pressed_button]:
		if button != null:
			button.mouse_filter = Control.MOUSE_FILTER_IGNORE
			button.focus_mode = Control.FOCUS_NONE
	if _check_sample != null:
		_check_sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_check_sample.focus_mode = Control.FOCUS_NONE
	if _toggle_sample != null:
		_toggle_sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_toggle_sample.focus_mode = Control.FOCUS_NONE
	if _slider_sample != null:
		_slider_sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slider_sample.focus_mode = Control.FOCUS_NONE
	if _scroll_sample != null:
		_scroll_sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scroll_sample.focus_mode = Control.FOCUS_NONE
	if _hover_button != null:
		var hover_style := _hover_button.get_theme_stylebox("hover")
		if hover_style != null:
			_hover_button.add_theme_stylebox_override("normal", hover_style)
	if _pressed_button != null:
		var pressed_style := _pressed_button.get_theme_stylebox("pressed")
		if pressed_style != null:
			_pressed_button.add_theme_stylebox_override("normal", pressed_style)


func _local_rect_in_section(section: Control, child: Control) -> Rect2:
	var offset := child.global_position - section.global_position
	return Rect2(offset, child.size)
