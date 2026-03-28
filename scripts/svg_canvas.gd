extends RefCounted
class_name SVGCanvas

var width := 0.0
var height := 0.0
var _elements: Array[String] = []
var _transform_origin := Vector2.ZERO
var _transform_scale := Vector2.ONE


func configure(view_width: float, view_height: float) -> void:
	width = maxf(1.0, view_width)
	height = maxf(1.0, view_height)


func draw_rect(rect: Rect2, color: Color, filled: bool, width_px: float = 1.0) -> void:
	var p0 := _transform_point(rect.position)
	var sx := _transform_scale.x
	var sy := _transform_scale.y
	var w := rect.size.x * sx
	var h := rect.size.y * sy
	if w < 0.0:
		p0.x += w
		w = -w
	if h < 0.0:
		p0.y += h
		h = -h
	var clipped := _clip_rect(Rect2(p0.x, p0.y, w, h))
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var fill_col := _svg_color(color) if filled else "none"
	var stroke_col := "none" if filled else _svg_color(color)
	var stroke_w := 0.0 if filled else maxf(0.1, width_px * maxf(absf(sx), absf(sy)))
	var fill_opacity := _svg_opacity(color) if filled else ""
	var stroke_opacity := "" if filled else _svg_opacity(color)
	_elements.append(
		"<rect x=\"%s\" y=\"%s\" width=\"%s\" height=\"%s\" fill=\"%s\"%s stroke=\"%s\"%s stroke-width=\"%s\" />" % [
			_fmt(clipped.position.x),
			_fmt(clipped.position.y),
			_fmt(clipped.size.x),
			_fmt(clipped.size.y),
			fill_col,
			fill_opacity,
			stroke_col,
			stroke_opacity,
			_fmt(stroke_w)
		]
	)


func draw_line(p0: Vector2, p1: Vector2, color: Color, width_px: float = 1.0) -> void:
	var a := _transform_point(p0)
	var b := _transform_point(p1)
	var clipped := _clip_line(a, b)
	if clipped.is_empty():
		return
	var stroke_w := maxf(0.1, width_px * maxf(absf(_transform_scale.x), absf(_transform_scale.y)))
	_elements.append(
		"<line x1=\"%s\" y1=\"%s\" x2=\"%s\" y2=\"%s\" stroke=\"%s\"%s stroke-width=\"%s\" stroke-linecap=\"round\" />" % [
			_fmt(clipped[0].x),
			_fmt(clipped[0].y),
			_fmt(clipped[1].x),
			_fmt(clipped[1].y),
			_svg_color(color),
			_svg_opacity(color),
			_fmt(stroke_w)
		]
	)


func draw_string(_font: Font, pos: Vector2, text: String, _align: int, _max_width: float, font_size: int, color: Color) -> void:
	var sx := _transform_scale.x
	var sy := _transform_scale.y
	var size_px := maxf(1.0, float(font_size))
	var family := "Arial, sans-serif"
	var x := pos.x
	var y := pos.y
	var transform_attr := ""
	if not is_equal_approx(sx, 1.0) or not is_equal_approx(sy, 1.0):
		x = 0.0
		y = 0.0
		transform_attr = " transform=\"matrix(%s 0 0 %s %s %s)\"" % [
			_fmt(sx),
			_fmt(sy),
			_fmt(_transform_origin.x + pos.x * sx),
			_fmt(_transform_origin.y + pos.y * sy)
		]
	else:
		var p := _transform_point(pos)
		x = p.x
		y = p.y
	_elements.append(
		"<text x=\"%s\" y=\"%s\" font-size=\"%s\" font-family=\"%s\" fill=\"%s\"%s%s>%s</text>" % [
			_fmt(x),
			_fmt(y),
			_fmt(size_px),
			family,
			_svg_color(color),
			_svg_opacity(color),
			transform_attr,
			_xml_escape(text)
		]
	)


func draw_set_transform(offset: Vector2, _rotation: float, scale: Vector2) -> void:
	_transform_origin = offset
	_transform_scale = scale


func save(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(to_svg())
	file.close()
	return true


func to_svg() -> String:
	return """<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" width="%s" height="%s" viewBox="0 0 %s %s">
%s
</svg>
""" % [_fmt(width), _fmt(height), _fmt(width), _fmt(height), "\n".join(_elements)]


func _transform_point(p: Vector2) -> Vector2:
	return Vector2(
		_transform_origin.x + p.x * _transform_scale.x,
		_transform_origin.y + p.y * _transform_scale.y
	)


func _svg_color(c: Color) -> String:
	return "#%02x%02x%02x" % [
		int(round(clampf(c.r, 0.0, 1.0) * 255.0)),
		int(round(clampf(c.g, 0.0, 1.0) * 255.0)),
		int(round(clampf(c.b, 0.0, 1.0) * 255.0))
	]


func _svg_opacity(c: Color) -> String:
	var a := clampf(c.a, 0.0, 1.0)
	if is_equal_approx(a, 1.0):
		return ""
	return " opacity=\"%s\"" % _fmt(a)


func _xml_escape(text: String) -> String:
	return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("\"", "&quot;")


func _clip_rect(rect: Rect2) -> Rect2:
	var x0 := clampf(rect.position.x, 0.0, width)
	var y0 := clampf(rect.position.y, 0.0, height)
	var x1 := clampf(rect.position.x + rect.size.x, 0.0, width)
	var y1 := clampf(rect.position.y + rect.size.y, 0.0, height)
	return Rect2(x0, y0, maxf(0.0, x1 - x0), maxf(0.0, y1 - y0))


func _clip_line(a: Vector2, b: Vector2) -> Array:
	var t0 := 0.0
	var t1 := 1.0
	var dx := b.x - a.x
	var dy := b.y - a.y
	var checks := [
		{"p": -dx, "q": a.x},
		{"p": dx, "q": width - a.x},
		{"p": -dy, "q": a.y},
		{"p": dy, "q": height - a.y}
	]
	for check_any in checks:
		var check: Dictionary = check_any
		var p := float(check.get("p", 0.0))
		var q := float(check.get("q", 0.0))
		if is_zero_approx(p):
			if q < 0.0:
				return []
			continue
		var r := q / p
		if p < 0.0:
			if r > t1:
				return []
			t0 = maxf(t0, r)
		else:
			if r < t0:
				return []
			t1 = minf(t1, r)
	if t1 < t0:
		return []
	return [
		Vector2(a.x + t0 * dx, a.y + t0 * dy),
		Vector2(a.x + t1 * dx, a.y + t1 * dy)
	]


func _fmt(v: float) -> String:
	return "%.3f" % v
