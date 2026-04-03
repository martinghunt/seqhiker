extends RefCounted
class_name MapStripRenderer


static func bp_to_x(bp: float, strip_rect: Rect2, total_len: float) -> float:
	var usable_w := maxf(1.0, strip_rect.size.x)
	var norm := clampf(bp / maxf(1.0, total_len), 0.0, 1.0)
	return strip_rect.position.x + norm * usable_w


static func viewport_rect(strip_rect: Rect2, total_len: float, view_start: float, visible_span: float, min_px: float = 6.0, extra_h: float = 4.0) -> Rect2:
	var bounded_total := maxf(1.0, total_len)
	var bounded_span := minf(maxf(0.0, visible_span), bounded_total)
	var x0 := bp_to_x(view_start, strip_rect, bounded_total)
	var x1 := bp_to_x(view_start + bounded_span, strip_rect, bounded_total)
	var w := minf(strip_rect.size.x, maxf(min_px, x1 - x0))
	if x0 + w > strip_rect.position.x + strip_rect.size.x:
		x0 = strip_rect.position.x + strip_rect.size.x - w
	x0 = clampf(x0, strip_rect.position.x, strip_rect.position.x + strip_rect.size.x - w)
	var rect_y := strip_rect.position.y - extra_h * 0.5
	return Rect2(x0, rect_y, w, strip_rect.size.y + extra_h)


static func clicked_bp(local_x: float, strip_rect: Rect2, total_len: float) -> float:
	var usable_w := maxf(1.0, strip_rect.size.x)
	var norm := clampf((local_x - strip_rect.position.x) / usable_w, 0.0, 1.0)
	return norm * maxf(1.0, total_len)


static func centered_offset_for_bp(bp_center: float, total_len: float, visible_span: float) -> float:
	var bounded_total := maxf(1.0, total_len)
	var bounded_span := minf(maxf(0.0, visible_span), bounded_total)
	var max_offset := maxf(0.0, bounded_total - bounded_span)
	return clampf(bp_center - bounded_span * 0.5, 0.0, max_offset)


static func draw_strip(target, strip_rect: Rect2, total_len: float, segments: Array, palette: Dictionary, font: Font, font_size: int, draw_rect_fn: Callable, draw_string_fn: Callable, truncate_label_fn: Callable, text_baseline_fn: Callable, show_labels: bool = true, view_start: float = -1.0, visible_span: float = -1.0, min_view_px: float = 6.0, view_extra_h: float = 4.0) -> void:
	if strip_rect.size.x <= 0.0 or strip_rect.size.y <= 0.0:
		return
	var bounded_total := maxf(1.0, total_len)
	var base_seq_color: Color = palette.get("map_contig", palette.get("bg", Color.WHITE))
	var alt_seq_color: Color = palette.get("map_contig_alt", palette.get("aa_alt_bg", base_seq_color))
	if base_seq_color.is_equal_approx(alt_seq_color):
		alt_seq_color = base_seq_color.darkened(0.08) if base_seq_color.get_luminance() > 0.5 else base_seq_color.lightened(0.12)
	if segments.is_empty():
		draw_rect_fn.call(target, strip_rect, base_seq_color, true, 1.0)
		draw_rect_fn.call(target, strip_rect, palette.get("text", Color.BLACK), false, 1.0)
	else:
		for i in range(segments.size()):
			var seg: Dictionary = segments[i]
			var seg_start := float(seg.get("start", 0))
			var seg_end := float(seg.get("end", 0))
			if seg_end <= seg_start:
				continue
			var x0 := bp_to_x(seg_start, strip_rect, bounded_total)
			var x1 := bp_to_x(seg_end, strip_rect, bounded_total)
			if x1 <= x0:
				continue
			var seq_rect := Rect2(x0, strip_rect.position.y, x1 - x0, strip_rect.size.y)
			var seq_color: Color = base_seq_color if (i % 2) == 0 else alt_seq_color
			draw_rect_fn.call(target, seq_rect, seq_color, true, 1.0)
			draw_rect_fn.call(target, seq_rect, palette.get("text", Color.BLACK), false, 1.0)
			if i > 0:
				draw_rect_fn.call(target, Rect2(x0 - 1.0, strip_rect.position.y, 2.0, strip_rect.size.y), palette.get("text", Color.BLACK), true, 1.0)
			if not show_labels:
				continue
			var seg_name := str(seg.get("name", "")).strip_edges()
			if seg_name.is_empty():
				continue
			var label := str(truncate_label_fn.call(seg_name, seq_rect.size.x - 10.0, 4, font, font_size))
			if label.is_empty():
				continue
			var label_y := float(text_baseline_fn.call(seq_rect.get_center().y, font, font_size))
			draw_string_fn.call(target, font, Vector2(seq_rect.position.x + 5.0, label_y), label, HORIZONTAL_ALIGNMENT_LEFT, seq_rect.size.x - 10.0, font_size, palette.get("text", Color.BLACK))
	if view_start < 0.0 or visible_span <= 0.0 or visible_span >= bounded_total - 0.5:
		return
	var view_rect := viewport_rect(strip_rect, bounded_total, view_start, visible_span, min_view_px, view_extra_h)
	var fill: Color = palette.get("map_view_fill", palette.get("genome", Color(0.25, 0.45, 0.75)))
	fill.a = 0.5
	draw_rect_fn.call(target, view_rect, fill, true, 1.0)
	draw_rect_fn.call(target, view_rect, palette.get("map_view_outline", palette.get("text", Color.BLACK)), false, 1.5)
