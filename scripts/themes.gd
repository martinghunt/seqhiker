extends Node

const PALLETES := {
	"Light": {
		"bg": Color(0.95, 0.95, 0.95),
		"panel": Color(0.84, 0.84, 0.84),
		"text_dark": Color(0, 0, 0),
		"text": Color(0.12, 0.12, 0.12),
		"text_light": Color(0.25, 0.25, 0.25),
		"text_lighter": Color(0.4, 0.4, 0.4),
		"border": Color(0.7, 0.7, 0.7),
		"button_bg": Color(0.8, 0.8, 0.8),
	},
	"Dark": {
		"bg": Color(0.12, 0.12, 0.12),
		"panel": Color(0.16, 0.16, 0.16),
		"text_dark": Color(1, 1, 1),
		"text": Color(0.88, 0.88, 0.88),
		"text_light": Color(0.75, 0.75, 0.75),
		"text_lighter": Color(0.6, 0.6, 0.6),
		"border": Color(0.3, 0.3, 0.3),
		"button_bg": Color(0.2, 0.2, 0.2),
	},
}


func make_flat_texture(color: Color, size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex := ImageTexture.create_from_image(img)
	return tex

# Generates a rounded pill ImageTexture for the grabber
func make_pill_icon(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	for y in range(height):
		for x in range(width):
			# Normalized coordinates from center
			var rx = (x + 0.5 - 0.5 * width) / (0.5 * width)
			var ry = (y + 0.5 - 0.5 * height) / (0.5 * height)
			# Circle / pill shape
			if rx*rx + ry*ry <= 1.0:
				img.set_pixel(x, y, color)
			else:
				img.set_pixel(x, y, Color(0,0,0,0))
	
	var tex := ImageTexture.create_from_image(img)
	return tex

func make_tick_texture(width: int, height: int, color: Color) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	
	for y in range(height):
		for x in range(width):
			img.set_pixel(x, y, color)
	
	return ImageTexture.create_from_image(img)


# Apply pill-shaped slider theme
func set_theme_slider(theme: Theme, palette: Dictionary, grabber_size: int = 32):
	# 1. Create grabber icon
	var pill_icon = make_pill_icon(grabber_size, grabber_size, palette.text)
	theme.set_icon("grabber", "Slider", pill_icon)
	var pill_icon_light = make_pill_icon(grabber_size, grabber_size, palette.text_dark)
	theme.set_icon("grabber_highlight", "Slider", pill_icon_light)
	theme.set_icon("grabber_disabled", "Slider", pill_icon)
	
	# 2. Grabber area for hover/pressed
	var grabber_area := StyleBoxFlat.new()
	grabber_area.bg_color = palette.text
	grabber_area.set_corner_radius_all(int(0.5 * grabber_size))
	grabber_area.content_margin_left = 2
	grabber_area.content_margin_right = 2
	grabber_area.content_margin_top = 2
	grabber_area.content_margin_bottom = 2
	theme.set_stylebox("grabber_area", "Slider", grabber_area)
	
	var grabber_hover := StyleBoxFlat.new()
	grabber_hover.bg_color = palette.text_dark
	grabber_hover.set_corner_radius_all(int(0.5 * grabber_size))
	grabber_hover.content_margin_left = 2
	grabber_hover.content_margin_right = 2
	grabber_hover.content_margin_top = 2
	grabber_hover.content_margin_bottom = 2
	theme.set_stylebox("grabber_area_highlight", "Slider", grabber_hover)
	
	#var grabber_pressed := StyleBoxFlat.new()
	#grabber_pressed.bg_color = grabber_color.darkened(0.2)
	#grabber_pressed.set_corner_radius_all(int(0.5 * grabber_size))
	#grabber_pressed.content_margin_left = 2
	#grabber_pressed.content_margin_right = 2
	#grabber_pressed.content_margin_top = 2
	#grabber_pressed.content_margin_bottom = 2
	#theme.set_stylebox("grabber_area_pressed", "Slider", grabber_pressed)
	
	# 3. Track
	var track := StyleBoxFlat.new()
	track.bg_color = palette.panel
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	theme.set_stylebox("background", "Slider", track)
	
	# 4. Grabber size constant
	theme.set_constant("grabber_size", "Slider", grabber_size)


func make_theme(theme_name: String, font_size: int) -> Theme:
	var t := Theme.new()
	t.set_font_size("font_size", "Label", font_size)
	t.set_font_size("font_size", "Button", font_size)
	t.set_font_size("font_size", "LineEdit", font_size)

	var palette = PALLETES[theme_name]
	t.set_color("font_color", "Label", palette.text)
	t.set_color("font_color", "Button", palette.text)
	t.set_color("font_color_disabled", "Button", Color(0.5, 0.5, 0.5))

	var panel := StyleBoxFlat.new()
	panel.bg_color = palette.bg
	panel.border_color = palette.border
	panel.set_border_width_all(1)

	t.set_stylebox("panel", "Panel", panel)
	t.set_color("font_color", "Label", palette.text)
	
	var button := StyleBoxFlat.new()
	button.bg_color = palette.button_bg
	button.set_corner_radius_all(8)
	t.set_stylebox("normal", "Button", button)

	set_theme_slider(t, palette, 20)
	var tick_tex = make_tick_texture(2, 5, palette.text_light)
	t.set_icon("tick", "Slider", tick_tex)

	return t


#var themes = {
#	"light": make_theme(LIGHT),
#	"dark": make_theme(DARK),
#}
