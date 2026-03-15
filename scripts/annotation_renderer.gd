extends RefCounted
class_name AnnotationRenderer

var view: GenomeView = null


func configure(next_view: GenomeView) -> void:
	view = next_view


func draw_aa_tracks(area: Rect2) -> void:
	var t0 := Time.get_ticks_usec()
	var seen := 0
	var drawn := 0
	var labels := 0
	var culled_density := 0
	var area_start := area.position.y
	var show_aa_letters := view._can_draw_aa_letters()
	var show_feature_detail := view.bp_per_px <= view.FEATURE_DETAIL_MAX_BP_PER_PX
	var aa_feature_height := view.AA_ROW_H - 6.0
	var frame_label_boxes: Array = []
	var pending_labels: Array[Dictionary] = []
	frame_label_boxes.resize(6)
	for i in range(6):
		frame_label_boxes[i] = []
	view._feature_hitboxes.clear()
	for i in range(6):
		var y := area_start + i * (view.AA_ROW_H + view.AA_ROW_GAP)
		var track_rect := Rect2(0.0, y, area.size.x, view.AA_ROW_H)
		var bg_col: Color = view.palette["bg"]
		if i == 1 or i == 4:
			bg_col = view.palette.get("aa_alt_bg", bg_col)
		view.draw_rect(track_rect, bg_col, true)
		view._draw_grid(track_rect)
	var split_y := area_start + 3.0 * (view.AA_ROW_H + view.AA_ROW_GAP) - view.AA_ROW_GAP * 0.5
	view.draw_line(Vector2(0.0, split_y), Vector2(view.size.x, split_y), Color(0.15, 0.15, 0.15, 0.45), 1.0)

	for feature in view.features:
		seen += 1
		if is_hidden_full_length_region(feature):
			continue
		var frame := feature_to_frame(feature)
		if frame < 0 or frame > 5:
			continue
		var f_start: int = feature["start"]
		var f_end: int = feature["end"]
		if f_end < int(view.view_start_bp) or f_start > int(view._viewport_end_bp()):
			continue
		var row_center_y := aa_frame_row_center_y(area_start, frame)
		var fy := row_center_y - aa_feature_height * 0.5
		var fx0 := view.TRACK_LEFT_PAD + view._bp_to_x(f_start)
		var fx1 := view.TRACK_LEFT_PAD + view._bp_to_x(f_end)
		var feature_w := fx1 - fx0
		if feature_w < view.FEATURE_MIN_DRAW_PX:
			continue
		var rect := Rect2(Vector2(fx0, fy), Vector2(feature_w, aa_feature_height))
		var feature_col: Color = view.palette["feature"]
		feature_col.a = 1.0
		view.draw_rect(rect, feature_col, true)
		var key := view._feature_key(feature)
		if not view._selected_feature_key.is_empty() and key == view._selected_feature_key:
			var border_col: Color = view.palette.get("feature_text", view._axis_text_color())
			view.draw_rect(rect.grow(1.5), border_col, false, 2.0)
		drawn += 1
		var click_rect := rect.grow(3.0) if show_feature_detail else rect
		view._feature_hitboxes.append({
			"rect": click_rect,
			"feature": feature
		})
		if not show_aa_letters:
			var label_x_min := maxf(rect.position.x + 4.0, view.TRACK_LEFT_PAD + 2.0)
			var label_x_max := minf(rect.position.x + rect.size.x - 4.0, view.size.x - view.TRACK_RIGHT_PAD - 2.0)
			var label_w := maxf(0.0, label_x_max - label_x_min)
			var label := feature_annotation_label(feature, label_w)
			if not label.is_empty():
				var font := view.get_theme_default_font()
				var font_size := view._font_size_small
				var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
				var draw_w := minf(label_w, text_w)
				var label_rect := Rect2(Vector2(label_x_min, rect.position.y + 2.0), Vector2(draw_w, view.AA_ROW_H - 8.0))
				if not intersects_any(label_rect, frame_label_boxes[frame]):
					var ann_text_col: Color = view.palette.get("feature_text", view._axis_text_color())
					var label_center_y := rect.position.y + rect.size.y * 0.5
					pending_labels.append({
						"pos": Vector2(label_x_min, text_baseline_for_center(label_center_y, font, font_size)),
						"text": label,
						"max_w": label_w,
						"font_size": font_size,
						"color": ann_text_col
					})
					frame_label_boxes[frame].append(label_rect)
					labels += 1

	if show_aa_letters:
		draw_aa_translation_letters(area_start)
	var label_font := view.get_theme_default_font()
	for entry in pending_labels:
		view.draw_string(
			label_font,
			entry.get("pos", Vector2.ZERO),
			str(entry.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			float(entry.get("max_w", -1.0)),
			int(entry.get("font_size", view._font_size_small)),
			entry.get("color", view._axis_text_color())
		)
	view.annotation_debug_stats_state = {
		"seen": seen,
		"drawn": drawn,
		"labels": labels,
		"hitboxes": view._feature_hitboxes.size(),
		"culled_density": culled_density,
		"draw_ms": float(Time.get_ticks_usec() - t0) / 1000.0
	}


func draw_genome_feature_tracks(area: Rect2, line_y: float) -> void:
	var show_feature_labels := not view._can_draw_nucleotide_letters()
	var row_height := view.AA_ROW_H - 6.0
	var row_label_boxes: Array = [[], [], []]
	var pending_labels: Array[Dictionary] = []
	var text_col: Color = view.palette.get("feature_text", view._axis_text_color())
	for feature in view.features:
		if is_hidden_full_length_region(feature):
			continue
		if feature_shows_in_aa_track(feature):
			continue
		var row := feature_to_genome_row(feature)
		if row < 0 or row > 2:
			continue
		var f_start := int(feature.get("start", 0))
		var f_end := int(feature.get("end", f_start))
		if f_end < int(view.view_start_bp) or f_start > int(view._viewport_end_bp()):
			continue
		var fx0 := view.TRACK_LEFT_PAD + view._bp_to_x(f_start)
		var fx1 := view.TRACK_LEFT_PAD + view._bp_to_x(f_end)
		var feature_w := fx1 - fx0
		if feature_w < view.FEATURE_MIN_DRAW_PX:
			continue
		var row_center_y := genome_feature_row_center_y(area, line_y, row)
		var rect := Rect2(Vector2(fx0, row_center_y - row_height * 0.5), Vector2(feature_w, row_height))
		var feature_col: Color = view.palette["feature"]
		feature_col.a = 0.9
		view.draw_rect(rect, feature_col, true)
		var key := view._feature_key(feature)
		if not view._selected_feature_key.is_empty() and key == view._selected_feature_key:
			view.draw_rect(rect.grow(1.5), text_col, false, 2.0)
		view._feature_hitboxes.append({
			"rect": rect.grow(3.0),
			"feature": feature
		})
		if not show_feature_labels:
			continue
		var label_x_min := maxf(rect.position.x + 4.0, view.TRACK_LEFT_PAD + 2.0)
		var label_x_max := minf(rect.position.x + rect.size.x - 4.0, view.size.x - view.TRACK_RIGHT_PAD - 2.0)
		var label_w := maxf(0.0, label_x_max - label_x_min)
		var label := feature_annotation_label(feature, label_w)
		if label.is_empty():
			continue
		var font := view.get_theme_default_font()
		var font_size := view._font_size_small
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var draw_w := minf(label_w, text_w)
		var label_rect := Rect2(Vector2(label_x_min, rect.position.y + 2.0), Vector2(draw_w, row_height - 4.0))
		if intersects_any(label_rect, row_label_boxes[row]):
			continue
		var label_center_y := rect.position.y + rect.size.y * 0.5
		pending_labels.append({
			"pos": Vector2(label_x_min, text_baseline_for_center(label_center_y, font, font_size)),
			"text": label,
			"max_w": label_w,
			"font_size": font_size,
			"color": text_col
		})
		row_label_boxes[row].append(label_rect)
	var label_font := view.get_theme_default_font()
	for entry in pending_labels:
		view.draw_string(
			label_font,
			entry.get("pos", Vector2.ZERO),
			str(entry.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			float(entry.get("max_w", -1.0)),
			int(entry.get("font_size", view._font_size_small)),
			entry.get("color", text_col)
		)


func text_center_y(font: Font, font_size: int, baseline_y: float) -> float:
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return baseline_y + (descent - ascent) * 0.5


func text_baseline_for_center(center_y: float, font: Font, font_size: int) -> float:
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	return center_y + (ascent - descent) * 0.5


func aa_frame_row_center_y(area_start: float, frame: int) -> float:
	return area_start + frame * (view.AA_ROW_H + view.AA_ROW_GAP) + view.AA_ROW_H * 0.5


func genome_feature_row_center_y(area: Rect2, line_y: float, row: int) -> float:
	var font := view.get_theme_default_font()
	match row:
		0:
			return text_center_y(font, view._font_size_large, line_y - 12.0)
		1:
			return area.position.y + area.size.y * 0.5
		2:
			return text_center_y(font, view._font_size_large, line_y + 38.0)
		_:
			return area.position.y + area.size.y * 0.5


func annotation_debug_stats() -> Dictionary:
	return view.annotation_debug_stats_state.duplicate()


func draw_aa_translation_letters(area_start: float) -> void:
	if not view._can_draw_aa_letters():
		return
	var font := view.sequence_letter_font()
	var aa_font_size := view._font_size_medium
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x

	var seq_len := view.reference_sequence.length()
	if seq_len < 3:
		return
	var ref_start := view.reference_start_bp
	var ref_end := view.reference_start_bp + seq_len
	var vis_start := maxi(ref_start, int(floor(view.view_start_bp)))
	var vis_end := mini(ref_end, int(ceil(view._viewport_end_bp())))
	if vis_end - vis_start < 3:
		return
	for frame in range(3):
		var first_bp := vis_start + posmod(frame - posmod(vis_start, 3), 3)
		var last_bp := vis_end - 3
		if last_bp < first_bp:
			continue
		var codon_count := int(floor(float(last_bp - first_bp) / 3.0)) + 1
		var max_by_pixels := maxi(1, int(floor(view._plot_width() / maxf(1.0, aa_char_px + 1.0))) + 1)
		var sample_count := mini(codon_count, max_by_pixels)
		for n in range(sample_count):
			var codon_index := n
			if sample_count > 1 and codon_count > 1:
				codon_index = int(round(float(n) * float(codon_count - 1) / float(sample_count - 1)))
			var bp := first_bp + codon_index * 3
			var i0 := bp - ref_start
			var i1 := i0 + 1
			var i2 := i0 + 2
			if i0 < 0 or i2 >= seq_len:
				continue
			var b0 := view.reference_sequence.substr(i0, 1).to_upper()
			var b1 := view.reference_sequence.substr(i1, 1).to_upper()
			var b2 := view.reference_sequence.substr(i2, 1).to_upper()
			if b0 == " " or b1 == " " or b2 == " ":
				continue

			var codon := b0 + b1 + b2
			var aa_fwd := view._translate_codon(codon)
			if not aa_fwd.is_empty():
				var x := view.TRACK_LEFT_PAD + view._bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var center_y := aa_frame_row_center_y(area_start, frame)
				var y := text_baseline_for_center(center_y, font, aa_font_size)
				view.draw_string(font, Vector2(x, y), aa_fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, view.palette["text"])

			var rev_codon := view._complement_base(b2) + view._complement_base(b1) + view._complement_base(b0)
			var aa_rev := view._translate_codon(rev_codon)
			if not aa_rev.is_empty():
				var rx := view.TRACK_LEFT_PAD + view._bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var rev_center_y := aa_frame_row_center_y(area_start, 3 + frame)
				var ry := text_baseline_for_center(rev_center_y, font, aa_font_size)
				view.draw_string(font, Vector2(rx, ry), aa_rev, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, view.palette["text"])


func is_hidden_full_length_region(feature: Dictionary) -> bool:
	if view._show_full_length_regions:
		return false
	var feature_type := str(feature.get("type", "")).to_lower()
	if feature_type != "region" and feature_type != "source":
		return false
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", 0))
	return start_bp <= 0 and end_bp >= view.chromosome_length


func feature_annotation_label(feature: Dictionary, max_width: float) -> String:
	if max_width <= 0.0:
		return ""
	var font := view.get_theme_default_font()
	var font_size := view._font_size_small
	var label_name := str(feature.get("name", "")).strip_edges()
	var id := str(feature.get("id", "")).strip_edges()
	if label_name.is_empty():
		label_name = str(feature.get("type", "")).strip_edges()
	if label_name.is_empty() and id.is_empty():
		return ""
	if id.is_empty() or id == label_name:
		return truncate_label_to_width(label_name, max_width, view.FEATURE_LABEL_MIN_CHARS, font, font_size)
	var combined := "%s / %s" % [label_name, id]
	var combined_w := font.get_string_size(combined, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	if combined_w <= max_width:
		return combined
	return truncate_label_to_width(label_name, max_width, view.FEATURE_LABEL_MIN_CHARS, font, font_size)


func truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
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


func intersects_any(rect: Rect2, existing: Array) -> bool:
	for r_any in existing:
		var r: Rect2 = r_any
		if r.intersects(rect):
			return true
	return false


func feature_to_frame(feature: Dictionary) -> int:
	if not feature_shows_in_aa_track(feature):
		return -1
	var strand: String = str(feature.get("strand", "+"))
	var start: int = int(feature.get("start", 0))
	var end: int = int(feature.get("end", 0))
	if strand == "-":
		var reverse_phase := ((2 - ((end - 1) % 3)) + 3) % 3
		return 3 + reverse_phase
	return ((start % 3) + 3) % 3


func feature_uses_frame(feature: Dictionary) -> bool:
	var feature_type := str(feature.get("type", "")).to_lower()
	return feature_type == "cds" or feature_type == "gene"


func feature_shows_in_aa_track(feature: Dictionary) -> bool:
	return feature_uses_frame(feature) and view.is_track_visible(view.TRACK_ID_AA)


func feature_to_genome_row(feature: Dictionary) -> int:
	var strand := str(feature.get("strand", "")).strip_edges()
	if strand == "+":
		return 0
	if strand == "-":
		return 2
	return 1
