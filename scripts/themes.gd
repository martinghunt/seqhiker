extends RefCounted
class_name ThemesLib

const THEMES := {
	"Light": {
		"bg": Color("ffffff"),
		"panel": Color("ffffff"),
		"panel_alt": Color("f5f5f5"),
		"grid": Color("d0d0d0"),
		"border": Color("d0d0d0"),
		"text": Color("111111"),
		"text_muted": Color("4a4a4a"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("efefef"),
		"button_hover": Color("e5e5e5"),
		"button_pressed": Color("dadada"),
		"field_bg": Color("ffffff"),
		"field_border": Color("c8c8c8"),
		"field_focus": Color("5b8def"),
		"accent": Color("3f5a7a"),
		"status_error": Color("8b0000"),
		"aa_alt_bg": Color("efefef"),
		"genome": Color("3f5a7a"),
		"read": Color("0f8b8d"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("345995"),
		"snp": Color("b11f47"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("8a4fff"),
		"aa_reverse": Color("f39237"),
		"feature": Color("dce8f7"),
		"feature_text": Color("1e3557")
	},
	"Forest": {
		"bg": Color("eaf4e5"),
		"panel": Color("f6fff0"),
		"panel_alt": Color("eef8e9"),
		"grid": Color("b8d1ad"),
		"border": Color("b8d1ad"),
		"text": Color("20301f"),
		"text_muted": Color("41513f"),
		"text_inverse": Color("ffffff"),
		"button_bg": Color("dcebd5"),
		"button_hover": Color("d3e4ca"),
		"button_pressed": Color("c8dbbe"),
		"field_bg": Color("f8fff4"),
		"field_border": Color("abc7a0"),
		"field_focus": Color("588157"),
		"accent": Color("386641"),
		"status_error": Color("8b1f1f"),
		"aa_alt_bg": Color("dfe8d8"),
		"genome": Color("386641"),
		"read": Color("6a994e"),
		"gc_plot": Color("2a9d8f"),
		"depth_plot": Color("386641"),
		"snp": Color("7a143a"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("588157"),
		"aa_reverse": Color("bc4749"),
		"feature": Color("c8dfc0"),
		"feature_text": Color("1f3a24")
	},
	"Slate": {
		"bg": Color("e8edf2"),
		"panel": Color("f6f9fc"),
		"panel_alt": Color("edf2f6"),
		"grid": Color("b6c3cf"),
		"border": Color("b6c3cf"),
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
		"aa_alt_bg": Color("dde3ea"),
		"genome": Color("345995"),
		"read": Color("2d7dd2"),
		"gc_plot": Color("2d7dd2"),
		"depth_plot": Color("345995"),
		"snp": Color("d7263d"),
		"snp_text": Color("ffffff"),
		"aa_forward": Color("5c6784"),
		"aa_reverse": Color("f4a259"),
		"feature": Color("c6d6ec"),
		"feature_text": Color("1f3654")
	},
	"Dark": {
		"bg": Color("1a1d22"),
		"panel": Color("21262d"),
		"panel_alt": Color("2a3038"),
		"grid": Color("3a434f"),
		"border": Color("3a434f"),
		"text": Color("e6edf3"),
		"text_muted": Color("aab6c2"),
		"text_inverse": Color("111111"),
		"button_bg": Color("2f3742"),
		"button_hover": Color("374150"),
		"button_pressed": Color("2a3240"),
		"field_bg": Color("1f252d"),
		"field_border": Color("455061"),
		"field_focus": Color("58a6ff"),
		"accent": Color("58a6ff"),
		"status_error": Color("ff7b72"),
		"aa_alt_bg": Color("2c333d"),
		"genome": Color("7aa2f7"),
		"read": Color("4fb6c2"),
		"gc_plot": Color("58a6ff"),
		"depth_plot": Color("7aa2f7"),
		"snp": Color("ff7b72"),
		"snp_text": Color("111111"),
		"aa_forward": Color("b392f0"),
		"aa_reverse": Color("ffb86b"),
		"feature": Color("2e466e"),
		"feature_text": Color("eaf2ff")
	},
	"Solarized Light": {
		"bg": Color("fdf6e3"),
		"panel": Color("fdf6e3"),
		"panel_alt": Color("eee8d5"),
		"grid": Color("93a1a1"),
		"border": Color("93a1a1"),
		"text": Color("657b83"),
		"text_muted": Color("93a1a1"),
		"text_inverse": Color("fdf6e3"),
		"button_bg": Color("eee8d5"),
		"button_hover": Color("e4dcc8"),
		"button_pressed": Color("d9d1bc"),
		"field_bg": Color("fdf6e3"),
		"field_border": Color("93a1a1"),
		"field_focus": Color("268bd2"),
		"accent": Color("268bd2"),
		"status_error": Color("dc322f"),
		"aa_alt_bg": Color("eee8d5"),
		"genome": Color("268bd2"),
		"read": Color("2aa198"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("268bd2"),
		"snp": Color("d33682"),
		"snp_text": Color("fdf6e3"),
		"aa_forward": Color("6c71c4"),
		"aa_reverse": Color("cb4b16"),
		"feature": Color("dcecf6"),
		"feature_text": Color("1f5d85")
	},
	"Solarized Dark": {
		"bg": Color("002b36"),
		"panel": Color("002b36"),
		"panel_alt": Color("073642"),
		"grid": Color("586e75"),
		"border": Color("586e75"),
		"text": Color("839496"),
		"text_muted": Color("657b83"),
		"text_inverse": Color("002b36"),
		"button_bg": Color("073642"),
		"button_hover": Color("0d414d"),
		"button_pressed": Color("114853"),
		"field_bg": Color("073642"),
		"field_border": Color("586e75"),
		"field_focus": Color("268bd2"),
		"accent": Color("268bd2"),
		"status_error": Color("dc322f"),
		"aa_alt_bg": Color("073642"),
		"genome": Color("268bd2"),
		"read": Color("2aa198"),
		"gc_plot": Color("2aa198"),
		"depth_plot": Color("268bd2"),
		"snp": Color("d33682"),
		"snp_text": Color("fdf6e3"),
		"aa_forward": Color("6c71c4"),
		"aa_reverse": Color("cb4b16"),
		"feature": Color("12455f"),
		"feature_text": Color("dceef8")
	}
}

func theme_names() -> PackedStringArray:
	var names := PackedStringArray()
	for key in THEMES.keys():
		names.append(str(key))
	names.sort()
	return names

func has_theme(theme_name: String) -> bool:
	return THEMES.has(_resolve_theme_name(theme_name))

func palette(theme_name: String) -> Dictionary:
	var resolved := _resolve_theme_name(theme_name)
	if not THEMES.has(resolved):
		resolved = "Light"
	return (THEMES[resolved] as Dictionary).duplicate(true)

func genome_palette(theme_name: String) -> Dictionary:
	var p := palette(theme_name)
	return {
		"bg": p["bg"],
		"panel": p["panel"],
		"grid": p["grid"],
		"text": p["text"],
		"aa_alt_bg": p["aa_alt_bg"],
		"genome": p["genome"],
		"read": p["read"],
		"gc_plot": p["gc_plot"],
		"depth_plot": p["depth_plot"],
		"snp": p["snp"],
		"snp_text": p["snp_text"],
		"aa_forward": p["aa_forward"],
		"aa_reverse": p["aa_reverse"],
		"feature": p["feature"],
		"feature_text": p["feature_text"]
	}

func make_theme(theme_name: String, font_size: int) -> Theme:
	var p := palette(theme_name)
	var t := Theme.new()
	var fs := maxi(8, font_size)
	t.default_font_size = fs

	_set_font_colors(t, p)
	_set_panel_styles(t, p)
	_set_button_styles(t, p)
	_set_field_styles(t, p)
	_set_item_list_styles(t, p)
	_set_popup_menu_styles(t, p)
	_set_checkbox_styles(t, p)
	_set_check_button_styles(t, p)
	_set_slider_styles(t, p)
	_set_option_button_icons(t, p)
	return t

func _set_font_colors(theme: Theme, p: Dictionary) -> void:
	var text: Color = p["text"]
	var text_muted: Color = p["text_muted"]
	theme.set_color("font_color", "Label", text)
	theme.set_color("font_color", "RichTextLabel", text)
	theme.set_color("default_color", "RichTextLabel", text)
	theme.set_color("font_color", "Button", text)
	theme.set_color("font_hover_color", "Button", text)
	theme.set_color("font_pressed_color", "Button", text)
	theme.set_color("font_focus_color", "Button", text)
	theme.set_color("font_disabled_color", "Button", text_muted)
	theme.set_color("font_color", "CheckBox", text)
	theme.set_color("font_hover_color", "CheckBox", text)
	theme.set_color("font_pressed_color", "CheckBox", text)
	theme.set_color("font_hover_pressed_color", "CheckBox", text)
	theme.set_color("font_focus_color", "CheckBox", text)
	theme.set_color("font_disabled_color", "CheckBox", text_muted)
	theme.set_color("font_color", "CheckButton", text)
	theme.set_color("font_hover_color", "CheckButton", text)
	theme.set_color("font_pressed_color", "CheckButton", text)
	theme.set_color("font_hover_pressed_color", "CheckButton", text)
	theme.set_color("font_focus_color", "CheckButton", text)
	theme.set_color("font_disabled_color", "CheckButton", text_muted)
	theme.set_color("font_color", "LineEdit", text)
	theme.set_color("caret_color", "LineEdit", text)
	theme.set_color("selection_color", "LineEdit", text)
	theme.set_color("font_color", "OptionButton", text)
	theme.set_color("font_color", "ItemList", text)
	theme.set_color("font_color", "PopupMenu", text)
	theme.set_color("font_disabled_color", "PopupMenu", text_muted)
	theme.set_color("font_hover_color", "PopupMenu", text)
	theme.set_color("font_separator_color", "PopupMenu", text_muted)
	theme.set_color("font_accelerator_color", "PopupMenu", text_muted)

func _set_panel_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["panel"]
	panel.border_color = p["border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(10)
	theme.set_stylebox("panel", "Panel", panel)
	theme.set_stylebox("panel", "PanelContainer", panel)

	var bg_panel := StyleBoxFlat.new()
	bg_panel.bg_color = p["bg"]
	bg_panel.border_color = p["border"]
	bg_panel.set_border_width_all(1)
	theme.set_stylebox("panel", "Window", bg_panel)

func _set_button_styles(theme: Theme, p: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = p["button_bg"]
	normal.border_color = p["border"]
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("normal", "OptionButton", normal)

	var hover := normal.duplicate()
	hover.bg_color = p["button_hover"]
	theme.set_stylebox("hover", "Button", hover)
	theme.set_stylebox("hover", "OptionButton", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = p["button_pressed"]
	theme.set_stylebox("pressed", "Button", pressed)
	theme.set_stylebox("pressed", "OptionButton", pressed)

	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(2)
	theme.set_stylebox("focus", "Button", focus)
	theme.set_stylebox("focus", "OptionButton", focus)

func _set_field_styles(theme: Theme, p: Dictionary) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = p["field_bg"]
	normal.border_color = p["field_border"]
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 6
	normal.content_margin_right = 6
	normal.content_margin_top = 4
	normal.content_margin_bottom = 4
	theme.set_stylebox("normal", "LineEdit", normal)
	theme.set_stylebox("read_only", "LineEdit", normal)

	var focus := normal.duplicate()
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "LineEdit", focus)

func _set_item_list_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["button_bg"]
	panel.border_color = p["border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	theme.set_stylebox("panel", "ItemList", panel)

	var focus := panel.duplicate()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(2)
	theme.set_stylebox("focus", "ItemList", focus)

	var selected_bg: Color = p["button_pressed"]
	var selected_border: Color = p["border"]
	var cursor := StyleBoxFlat.new()
	cursor.bg_color = selected_bg
	cursor.border_color = selected_border
	cursor.set_border_width_all(1)
	cursor.set_corner_radius_all(4)
	theme.set_stylebox("cursor", "ItemList", cursor)
	theme.set_stylebox("cursor_unfocused", "ItemList", cursor.duplicate())

	theme.set_color("font_selected_color", "ItemList", p["text"])
	theme.set_color("font_hovered_color", "ItemList", p["text"])
	theme.set_color("font_hovered_selected_color", "ItemList", p["text"])
	theme.set_color("font_disabled_color", "ItemList", p["text_muted"])
	theme.set_color("font_outline_color", "ItemList", Color(0, 0, 0, 0))
	theme.set_color("selection_fill", "ItemList", selected_bg)
	theme.set_color("selection_rect", "ItemList", selected_border)

func _set_popup_menu_styles(theme: Theme, p: Dictionary) -> void:
	var panel := StyleBoxFlat.new()
	panel.bg_color = p["field_bg"]
	panel.border_color = p["field_border"]
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(6)
	theme.set_stylebox("panel", "PopupMenu", panel)

	var hover := StyleBoxFlat.new()
	hover.bg_color = p["button_hover"]
	hover.border_color = p["button_hover"]
	hover.set_border_width_all(0)
	hover.set_corner_radius_all(4)
	theme.set_stylebox("hover", "PopupMenu", hover)

func _set_option_button_icons(theme: Theme, p: Dictionary) -> void:
	var arrow := _make_arrow_icon(10, 7, p["text"])
	theme.set_icon("arrow", "OptionButton", arrow)
	theme.set_constant("arrow_margin", "OptionButton", 8)
	theme.set_color("modulate_arrow", "OptionButton", p["text"])

func _set_checkbox_styles(theme: Theme, p: Dictionary) -> void:
	var unchecked := _make_checkbox_texture(16, p["field_bg"], p["field_border"])
	var checked := _make_check_texture(16, p["accent"], p["text_inverse"], p["accent"])
	theme.set_icon("unchecked", "CheckBox", unchecked)
	theme.set_icon("checked", "CheckBox", checked)
	theme.set_icon("unchecked_disabled", "CheckBox", unchecked)
	theme.set_icon("checked_disabled", "CheckBox", checked)
	theme.set_constant("h_separation", "CheckBox", 6)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	theme.set_stylebox("normal", "CheckBox", normal)

	var hover := normal.duplicate()
	hover.bg_color = (p["button_hover"] as Color)
	hover.bg_color.a *= 0.35
	theme.set_stylebox("hover", "CheckBox", hover)

	var pressed := normal.duplicate()
	pressed.bg_color = (p["button_pressed"] as Color)
	pressed.bg_color.a *= 0.45
	theme.set_stylebox("pressed", "CheckBox", pressed)

	var focus := normal.duplicate()
	focus.border_color = p["field_focus"]
	focus.set_border_width_all(1)
	theme.set_stylebox("focus", "CheckBox", focus)

func _set_check_button_styles(theme: Theme, p: Dictionary) -> void:
	var toggle_w := 40
	var toggle_h := 22
	var off_icon := _make_toggle_icon(toggle_w, toggle_h, p["panel_alt"], p["field_border"], p["button_bg"], false)
	var on_icon := _make_toggle_icon(toggle_w, toggle_h, p["panel_alt"], p["field_border"], p["accent"], true)
	theme.set_icon("off", "CheckButton", off_icon)
	theme.set_icon("off_disabled", "CheckButton", off_icon)
	theme.set_icon("on", "CheckButton", on_icon)
	theme.set_icon("on_disabled", "CheckButton", on_icon)
	theme.set_icon("unchecked", "CheckButton", off_icon)
	theme.set_icon("unchecked_disabled", "CheckButton", off_icon)
	theme.set_icon("checked", "CheckButton", on_icon)
	theme.set_icon("checked_disabled", "CheckButton", on_icon)
	theme.set_constant("h_separation", "CheckButton", 8)
	theme.set_constant("icon_max_width", "CheckButton", toggle_w)

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(0, 0, 0, 0)
	normal.set_border_width_all(0)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 2
	normal.content_margin_right = 2
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	theme.set_stylebox("normal", "CheckButton", normal)

	var hover := normal.duplicate()
	theme.set_stylebox("hover", "CheckButton", hover)

	var pressed := normal.duplicate()
	theme.set_stylebox("pressed", "CheckButton", pressed)
	theme.set_stylebox("hover_pressed", "CheckButton", pressed.duplicate())

	var disabled := normal.duplicate()
	theme.set_stylebox("disabled", "CheckButton", disabled)
	theme.set_stylebox("disabled_mirrored", "CheckButton", disabled.duplicate())

	var focus := normal.duplicate()
	theme.set_stylebox("focus", "CheckButton", focus)

func _set_slider_styles(theme: Theme, p: Dictionary) -> void:
	var grabber_size := 18
	var grabber := _make_pill_icon(grabber_size, grabber_size, p["accent"])
	theme.set_icon("grabber", "Slider", grabber)
	theme.set_icon("grabber_highlight", "Slider", _make_pill_icon(grabber_size, grabber_size, p["field_focus"]))
	theme.set_icon("grabber_disabled", "Slider", grabber)

	var track := StyleBoxFlat.new()
	track.bg_color = p["panel_alt"]
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	theme.set_stylebox("slider", "HSlider", track)
	theme.set_stylebox("grabber_area", "HSlider", track)
	theme.set_stylebox("grabber_area_highlight", "HSlider", track)
	theme.set_stylebox("slider", "VSlider", track)
	theme.set_stylebox("grabber_area", "VSlider", track)
	theme.set_stylebox("grabber_area_highlight", "VSlider", track)

	theme.set_constant("grabber_size", "HSlider", grabber_size)
	theme.set_constant("grabber_size", "VSlider", grabber_size)

	var sb_scroll := StyleBoxFlat.new()
	sb_scroll.bg_color = p["panel_alt"]
	sb_scroll.set_corner_radius_all(5)
	sb_scroll.content_margin_left = 2
	sb_scroll.content_margin_right = 2
	sb_scroll.content_margin_top = 2
	sb_scroll.content_margin_bottom = 2

	var sb_grabber := StyleBoxFlat.new()
	sb_grabber.bg_color = p["button_bg"]
	sb_grabber.border_color = p["field_border"]
	sb_grabber.set_border_width_all(1)
	sb_grabber.set_corner_radius_all(5)

	var sb_grabber_h := sb_grabber.duplicate()
	sb_grabber_h.bg_color = p["button_hover"]

	var sb_grabber_p := sb_grabber.duplicate()
	sb_grabber_p.bg_color = p["button_pressed"]

	theme.set_stylebox("scroll", "VScrollBar", sb_scroll)
	theme.set_stylebox("scroll_focus", "VScrollBar", sb_scroll)
	theme.set_stylebox("grabber", "VScrollBar", sb_grabber)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb_grabber_h)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb_grabber_p)
	theme.set_constant("scroll_size", "VScrollBar", 12)
	theme.set_constant("min_grab_thickness", "VScrollBar", 36)

	theme.set_stylebox("scroll", "HScrollBar", sb_scroll)
	theme.set_stylebox("scroll_focus", "HScrollBar", sb_scroll)
	theme.set_stylebox("grabber", "HScrollBar", sb_grabber)
	theme.set_stylebox("grabber_highlight", "HScrollBar", sb_grabber_h)
	theme.set_stylebox("grabber_pressed", "HScrollBar", sb_grabber_p)
	theme.set_constant("scroll_size", "HScrollBar", 12)
	theme.set_constant("min_grab_thickness", "HScrollBar", 36)

func _resolve_theme_name(theme_name: String) -> String:
	if THEMES.has(theme_name):
		return theme_name
	return theme_name

func _make_flat_texture(color: Color, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func _make_checkbox_texture(size: int, fill: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(size):
		for x in range(size):
			var is_border := x == 0 or y == 0 or x == size - 1 or y == size - 1
			img.set_pixel(x, y, border if is_border else fill)
	return ImageTexture.create_from_image(img)

func _make_pill_icon(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in range(height):
		for x in range(width):
			var rx := (x + 0.5 - 0.5 * width) / (0.5 * width)
			var ry := (y + 0.5 - 0.5 * height) / (0.5 * height)
			if rx * rx + ry * ry <= 1.0:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)

func _make_toggle_icon(width: int, height: int, fill: Color, _border: Color, knob: Color, on: bool) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cy := int(floor(float(height) * 0.5))
	var knob_radius := maxi(6, int(floor(float(height) * 0.38)))
	var track_margin := knob_radius + 1
	var track_h := 8
	var track_y0 := cy - int(floor(float(track_h) * 0.5))
	var track_y1 := track_y0 + track_h - 1
	for y in range(track_y0, track_y1 + 1):
		for x in range(track_margin, width - track_margin):
			if y >= 0 and y < height and x >= 0 and x < width:
				img.set_pixel(x, y, fill)
	var knob_cx := width - knob_radius - 2 if on else knob_radius + 1
	var knob_cy := cy
	for y in range(height):
		for x in range(width):
			var dx := x - knob_cx
			var dy := y - knob_cy
			if dx * dx + dy * dy <= knob_radius * knob_radius:
				img.set_pixel(x, y, knob)
	return ImageTexture.create_from_image(img)

func _make_check_texture(size: int, bg: Color, mark: Color, border: Color) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			var is_border := x == 0 or y == 0 or x == size - 1 or y == size - 1
			img.set_pixel(x, y, border if is_border else bg)
	var inset := 3
	for i in range(inset, size - inset):
		img.set_pixel(i, i, mark)
		img.set_pixel(i, size - 1 - i, mark)
	return ImageTexture.create_from_image(img)

func _make_arrow_icon(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var mid := int(floor(float(width) * 0.5))
	for y in range(height):
		var half := int(floor(float(y) * float(mid) / float(maxi(1, height - 1))))
		var x0 := mid - half
		var x1 := mid + half
		for x in range(x0, x1 + 1):
			if x >= 0 and x < width:
				img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
