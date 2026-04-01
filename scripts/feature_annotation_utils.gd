extends RefCounted
class_name FeatureAnnotationUtils


static func text_baseline_for_center(center_y: float, font: Font, font_size: int) -> float:
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return center_y + (ascent - descent) * 0.5


static func text_center_y(font: Font, font_size: int, baseline_y: float) -> float:
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return baseline_y + (descent - ascent) * 0.5


static func feature_key(feature: Dictionary) -> String:
	if feature.is_empty():
		return ""
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", start_bp))
	var seq_name := str(feature.get("seq_name", ""))
	var feat_name := str(feature.get("name", ""))
	var ftype := str(feature.get("type", ""))
	return "%s|%d|%d|%s|%s" % [seq_name, start_bp, end_bp, feat_name, ftype]


static func truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
	if text.is_empty() or max_width <= 0.0:
		return ""
	var full_w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if full_w <= max_width:
		return text
	var ellipsis := "..."
	var n := text.length()
	var min_n := mini(maxi(1, min_chars), n)
	var min_candidate := text.substr(0, min_n) + ellipsis
	var min_w := font.get_string_size(min_candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if min_w > max_width:
		return ""
	var lo := min_n
	var hi := n
	var best := min_n
	while lo <= hi:
		var mid := lo + ((hi - lo) >> 1)
		var candidate := text.substr(0, mid) + ellipsis
		var w := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if w <= max_width:
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return text.substr(0, best) + ellipsis


static func feature_annotation_label(feature: Dictionary, max_width: float, font: Font, font_size: int, min_chars: int) -> String:
	if max_width <= 0.0:
		return ""
	var label_name := str(feature.get("name", "")).strip_edges()
	var feature_id := str(feature.get("id", "")).strip_edges()
	if label_name.is_empty():
		label_name = str(feature.get("type", "")).strip_edges()
	if label_name.is_empty() and feature_id.is_empty():
		return ""
	if feature_id.is_empty() or feature_id == label_name:
		return truncate_label_to_width(label_name, max_width, min_chars, font, font_size)
	var combined := "%s / %s" % [label_name, feature_id]
	var combined_w := font.get_string_size(combined, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if combined_w <= max_width:
		return combined
	return truncate_label_to_width(label_name, max_width, min_chars, font, font_size)


static func intersects_any(rect: Rect2, existing: Array) -> bool:
	for r_any in existing:
		var r: Rect2 = r_any
		if r.intersects(rect):
			return true
	return false


static func feature_to_collapsed_genome_row(feature: Dictionary, default_row: int = 1) -> int:
	var strand := str(feature.get("strand", "")).strip_edges()
	if strand == "+":
		return 0
	if strand == "-":
		return 2
	return default_row
