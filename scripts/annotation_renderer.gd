extends RefCounted
class_name AnnotationRenderer

const FeatureAnnotationUtilsScript = preload("res://scripts/feature_annotation_utils.gd")

var view: GenomeView = null


func configure(next_view: GenomeView) -> void:
	view = next_view


func _draw_rect_on(target, rect: Rect2, color: Color, filled: bool, width: float = 1.0) -> void:
	if target == null or target == view:
		if filled:
			view.draw_rect(rect, color, true)
		else:
			view.draw_rect(rect, color, false, width)
	else:
		target.draw_rect(rect, color, filled, width)


func _draw_line_on(target, p0: Vector2, p1: Vector2, color: Color, width: float = 1.0) -> void:
	if target == null or target == view:
		view.draw_line(p0, p1, color, width)
	else:
		target.draw_line(p0, p1, color, width)


func _draw_string_on(target, font: Font, pos: Vector2, text: String, align: int, max_width: float, font_size: int, color: Color) -> void:
	if target == null or target == view:
		view.draw_string(font, pos, text, align, max_width, font_size, color)
	else:
		target.draw_string(font, pos, text, align, max_width, font_size, color)


func draw_quadratic_bezier(target, p0: Vector2, p1: Vector2, p2: Vector2, color: Color, width: float, segments: int = 12) -> void:
	var prev := p0
	for i in range(1, segments + 1):
		var t := float(i) / float(segments)
		var u := 1.0 - t
		var point := u * u * p0 + 2.0 * u * t * p1 + t * t * p2
		_draw_line_on(target, prev, point, color, width)
		prev = point


func draw_exon_connector_curve(target, from_point: Vector2, to_point: Vector2, color: Color, width: float) -> void:
	var dx := maxf(0.0, to_point.x - from_point.x)
	var curve_lift := minf(10.0, maxf(4.0, dx * 0.12))
	var control := Vector2(0.5 * (from_point.x + to_point.x), minf(from_point.y, to_point.y) - curve_lift)
	draw_quadratic_bezier(target, from_point, control, to_point, color, width)


func draw_aa_tracks(area: Rect2, target = null) -> void:
	var t0 := Time.get_ticks_usec()
	var seen := 0
	var drawn := 0
	var labels := 0
	var culled_density := 0
	var area_start := area.position.y
	var show_aa_letters := view._can_draw_aa_letters()
	var show_feature_detail := view.bp_per_px <= view.FEATURE_DETAIL_MAX_BP_PER_PX
	var aa_feature_height := view.AA_ROW_H - 2.0
	var visible_start_bp := int(floor(view.view_start_bp - view.TRACK_LEFT_PAD * view.bp_per_px))
	var visible_end_bp := int(ceil(view.view_start_bp + view.size.x * view.bp_per_px))
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
		_draw_rect_on(target, track_rect, bg_col, true)
		view._draw_grid(track_rect, target)
	var split_y := area_start + 3.0 * (view.AA_ROW_H + view.AA_ROW_GAP) - view.AA_ROW_GAP * 0.5
	_draw_line_on(target, Vector2(0.0, split_y), Vector2(view.size.x, split_y), Color(0.15, 0.15, 0.15, 0.45), 1.0)

	for feature in view.features:
		seen += 1
		if is_hidden_full_length_region(feature):
			continue
		var cds_parts_any: Variant = feature.get("cds_parts", [])
		if cds_parts_any is Array and (cds_parts_any as Array).size() > 1:
			var cds_parts: Array = cds_parts_any
			var part_rects: Array[Rect2] = []
			var part_hitboxes: Array[Rect2] = []
			var selected_border_rects: Array[Rect2] = []
			for part_any in cds_parts:
				if typeof(part_any) != TYPE_DICTIONARY:
					continue
				var part: Dictionary = part_any
				var frame_part := feature_to_frame(part)
				if frame_part < 0 or frame_part > 5:
					continue
				var p_start: int = part["start"]
				var p_end: int = part["end"]
				var row_center_y_part := aa_frame_row_center_y(area_start, frame_part)
				var fy_part := row_center_y_part - aa_feature_height * 0.5
				var fx0_part := view.TRACK_LEFT_PAD + view._bp_to_x(p_start)
				var fx1_part := view.TRACK_LEFT_PAD + view._bp_to_x(p_end)
				var feature_w_part := fx1_part - fx0_part
				if feature_w_part < view.FEATURE_MIN_DRAW_PX:
					continue
				var rect_part := Rect2(Vector2(fx0_part, fy_part), Vector2(feature_w_part, aa_feature_height))
				var feature_col_part: Color = view.palette["feature"]
				feature_col_part.a = 1.0
				_draw_rect_on(target, rect_part, feature_col_part, true)
				var key_part := view._feature_key(feature)
				if not view._selected_feature_key.is_empty() and key_part == view._selected_feature_key:
					selected_border_rects.append(rect_part.grow(1.5))
				part_rects.append(rect_part)
				part_hitboxes.append(rect_part.grow(3.0) if show_feature_detail else rect_part)
				drawn += 1
				if not show_aa_letters:
					var label_x_min_part := maxf(rect_part.position.x + 4.0, view.TRACK_LEFT_PAD + 2.0)
					var label_x_max_part := minf(rect_part.position.x + rect_part.size.x - 4.0, view.size.x - view.TRACK_RIGHT_PAD - 2.0)
					var label_w_part := maxf(0.0, label_x_max_part - label_x_min_part)
					var label_part := feature_annotation_label(part, label_w_part)
					if not label_part.is_empty():
						var font_part := view.get_theme_default_font()
						var font_size_part := view._font_size_small
						var text_w_part := font_part.get_string_size(label_part, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_part).x
						var draw_w_part := minf(label_w_part, text_w_part)
						var label_rect_part := Rect2(Vector2(label_x_min_part, rect_part.position.y + 2.0), Vector2(draw_w_part, view.AA_ROW_H - 8.0))
						var frame_part_boxes: Array = frame_label_boxes[frame_part]
						if not intersects_any(label_rect_part, frame_part_boxes):
							var ann_text_col_part: Color = view.palette.get("feature_text", view._axis_text_color())
							var label_center_y_part := rect_part.position.y + rect_part.size.y * 0.5
							pending_labels.append({
								"pos": Vector2(label_x_min_part, text_baseline_for_center(label_center_y_part, font_part, font_size_part)),
								"text": label_part,
								"max_w": label_w_part,
								"font_size": font_size_part,
								"color": ann_text_col_part
							})
							frame_part_boxes.append(label_rect_part)
							frame_label_boxes[frame_part] = frame_part_boxes
							labels += 1
			if part_rects.size() >= 2:
				var connector_col: Color = view.palette["feature"]
				connector_col.a = 0.95
				var selected_connector_col: Color = view.palette.get("feature_text", view._axis_text_color())
				var draw_selected_connector := not view._selected_feature_key.is_empty() and view._feature_key(feature) == view._selected_feature_key
				var selected_connector_segments: Array[Dictionary] = []
				for i in range(part_rects.size() - 1):
					var left_rect: Rect2 = part_rects[i]
					var right_rect: Rect2 = part_rects[i + 1]
					var from_point := Vector2(left_rect.end.x, left_rect.position.y + left_rect.size.y * 0.5)
					var to_point := Vector2(right_rect.position.x, right_rect.position.y + right_rect.size.y * 0.5)
					draw_exon_connector_curve(target, from_point, to_point, connector_col, 8.0)
					if draw_selected_connector:
						selected_connector_segments.append({
							"from": from_point,
							"to": to_point
						})
				if draw_selected_connector:
					for seg_any in selected_connector_segments:
						var seg: Dictionary = seg_any
						draw_exon_connector_curve(
							target,
							seg.get("from", Vector2.ZERO),
							seg.get("to", Vector2.ZERO),
							selected_connector_col,
							2.0
						)
			if not selected_border_rects.is_empty():
				var border_col_part: Color = view.palette.get("feature_text", view._axis_text_color())
				for border_rect in selected_border_rects:
					_draw_rect_on(target, border_rect, border_col_part, false, 2.0)
			for hitbox in part_hitboxes:
				view._feature_hitboxes.append({
					"rect": hitbox,
					"feature": feature
				})
			continue
		var frame := feature_to_frame(feature)
		if frame < 0 or frame > 5:
			continue
		var f_start: int = feature["start"]
		var f_end: int = feature["end"]
		if f_end < visible_start_bp or f_start > visible_end_bp:
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
		_draw_rect_on(target, rect, feature_col, true)
		var key := view._feature_key(feature)
		if not view._selected_feature_key.is_empty() and key == view._selected_feature_key:
			var border_col: Color = view.palette.get("feature_text", view._axis_text_color())
			_draw_rect_on(target, rect.grow(1.5), border_col, false, 2.0)
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
		draw_aa_translation_letters(area_start, target)
	var label_font := view.get_theme_default_font()
	for entry in pending_labels:
		_draw_string_on(
			target,
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


func draw_genome_feature_tracks(area: Rect2, line_y: float, target = null) -> void:
	var show_feature_labels := not view._can_draw_nucleotide_letters()
	var row_height := view.AA_ROW_H - 2.0
	var exon_row_height := row_height
	var visible_start_bp := int(floor(view.view_start_bp - view.TRACK_LEFT_PAD * view.bp_per_px))
	var visible_end_bp := int(ceil(view.view_start_bp + view.size.x * view.bp_per_px))
	var row_label_boxes: Array = [[], [], []]
	var pending_labels: Array[Dictionary] = []
	var text_col: Color = view.palette.get("feature_text", view._axis_text_color())
	for feature in view.features:
		if is_hidden_full_length_region(feature):
			continue
		var cds_parts_any: Variant = feature.get("cds_parts", [])
		if cds_parts_any is Array and (cds_parts_any as Array).size() > 1:
			var row_multi := feature_to_genome_row(feature)
			if row_multi < 0 or row_multi > 2:
				continue
			var f_start_multi := int(feature.get("start", 0))
			var f_end_multi := int(feature.get("end", f_start_multi))
			if f_end_multi < visible_start_bp or f_start_multi > visible_end_bp:
				continue
			var fx0_multi := view.TRACK_LEFT_PAD + view._bp_to_x(f_start_multi)
			var fx1_multi := view.TRACK_LEFT_PAD + view._bp_to_x(f_end_multi)
			var feature_w_multi := fx1_multi - fx0_multi
			if feature_w_multi < view.FEATURE_MIN_DRAW_PX:
				continue
			var row_center_y_multi := genome_feature_row_center_y(area, line_y, row_multi)
			var gene_rect := Rect2(
				Vector2(fx0_multi, row_center_y_multi - row_height * 0.5),
				Vector2(feature_w_multi, row_height)
			)
			var cds_parts: Array = cds_parts_any
			var exon_rects: Array[Rect2] = []
			var exon_col: Color = view.palette["feature"]
			exon_col.a = 0.95
			for part_any in cds_parts:
				if typeof(part_any) != TYPE_DICTIONARY:
					continue
				var part: Dictionary = part_any
				var p_start_multi := int(part.get("start", 0))
				var p_end_multi := int(part.get("end", p_start_multi))
				var px0_multi := view.TRACK_LEFT_PAD + view._bp_to_x(p_start_multi)
				var px1_multi := view.TRACK_LEFT_PAD + view._bp_to_x(p_end_multi)
				var part_w_multi := px1_multi - px0_multi
				if part_w_multi < view.FEATURE_MIN_DRAW_PX:
					continue
				var exon_rect := Rect2(
					Vector2(px0_multi, row_center_y_multi - exon_row_height * 0.5),
					Vector2(part_w_multi, exon_row_height)
				)
				exon_rects.append(exon_rect)
			if exon_rects.size() >= 2:
				var intron_col: Color = view.palette["feature"]
				intron_col.a = 0.95
				var intron_h := maxf(3.0, exon_row_height * 0.35)
				for i in range(exon_rects.size() - 1):
					var left_rect_multi: Rect2 = exon_rects[i]
					var right_rect_multi: Rect2 = exon_rects[i + 1]
					var intron_x0 := left_rect_multi.end.x
					var intron_x1 := right_rect_multi.position.x
					if intron_x1 > intron_x0:
						var intron_rect := Rect2(
							Vector2(intron_x0, row_center_y_multi - intron_h * 0.5),
							Vector2(intron_x1 - intron_x0, intron_h)
						)
						_draw_rect_on(target, intron_rect, intron_col, true)
			for exon_rect in exon_rects:
				_draw_rect_on(target, exon_rect, exon_col, true)
			var key_multi := view._feature_key(feature)
			if not view._selected_feature_key.is_empty() and key_multi == view._selected_feature_key:
				_draw_rect_on(target, gene_rect.grow(1.5), text_col, false, 2.0)
			view._feature_hitboxes.append({
				"rect": gene_rect.grow(3.0),
				"feature": feature
			})
			if show_feature_labels:
				var label_x_min_multi := maxf(gene_rect.position.x + 4.0, view.TRACK_LEFT_PAD + 2.0)
				var label_x_max_multi := minf(gene_rect.position.x + gene_rect.size.x - 4.0, view.size.x - view.TRACK_RIGHT_PAD - 2.0)
				var label_w_multi := maxf(0.0, label_x_max_multi - label_x_min_multi)
				var label_multi := feature_annotation_label(feature, label_w_multi)
				if not label_multi.is_empty():
					var font_multi := view.get_theme_default_font()
					var font_size_multi := view._font_size_small
					var text_w_multi := font_multi.get_string_size(label_multi, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_multi).x
					var draw_w_multi := minf(label_w_multi, text_w_multi)
					var label_rect_multi := Rect2(Vector2(label_x_min_multi, gene_rect.position.y + 2.0), Vector2(draw_w_multi, row_height - 4.0))
					if not intersects_any(label_rect_multi, row_label_boxes[row_multi]):
						pending_labels.append({
							"pos": Vector2(label_x_min_multi, text_baseline_for_center(row_center_y_multi, font_multi, font_size_multi)),
							"text": label_multi,
							"max_w": label_w_multi,
							"font_size": font_size_multi,
							"color": text_col
						})
						row_label_boxes[row_multi].append(label_rect_multi)
			continue
		if feature_shows_in_aa_track(feature):
			continue
		var row := feature_to_genome_row(feature)
		if row < 0 or row > 2:
			continue
		var f_start := int(feature.get("start", 0))
		var f_end := int(feature.get("end", f_start))
		if f_end < visible_start_bp or f_start > visible_end_bp:
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
		_draw_rect_on(target, rect, feature_col, true)
		var key := view._feature_key(feature)
		if not view._selected_feature_key.is_empty() and key == view._selected_feature_key:
			_draw_rect_on(target, rect.grow(1.5), text_col, false, 2.0)
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
		_draw_string_on(
			target,
			label_font,
			entry.get("pos", Vector2.ZERO),
			str(entry.get("text", "")),
			HORIZONTAL_ALIGNMENT_LEFT,
			float(entry.get("max_w", -1.0)),
			int(entry.get("font_size", view._font_size_small)),
			entry.get("color", text_col)
		)


func text_center_y(font: Font, font_size: int, baseline_y: float) -> float:
	return FeatureAnnotationUtilsScript.text_center_y(font, font_size, baseline_y)


func text_baseline_for_center(center_y: float, font: Font, font_size: int) -> float:
	return FeatureAnnotationUtilsScript.text_baseline_for_center(center_y, font, font_size)


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


func draw_aa_translation_letters(area_start: float, target = null) -> void:
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
				_draw_string_on(target, font, Vector2(x, y), aa_fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, view.palette["text"])

			var rev_codon := view._complement_base(b2) + view._complement_base(b1) + view._complement_base(b0)
			var aa_rev := view._translate_codon(rev_codon)
			if not aa_rev.is_empty():
				var rx := view.TRACK_LEFT_PAD + view._bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var rev_center_y := aa_frame_row_center_y(area_start, 3 + frame)
				var ry := text_baseline_for_center(rev_center_y, font, aa_font_size)
				_draw_string_on(target, font, Vector2(rx, ry), aa_rev, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, view.palette["text"])


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
	return FeatureAnnotationUtilsScript.feature_annotation_label(
		feature,
		max_width,
		view.get_theme_default_font(),
		view._font_size_small,
		view.FEATURE_LABEL_MIN_CHARS
	)


func truncate_label_to_width(text: String, max_width: float, min_chars: int, font: Font, font_size: int) -> String:
	return FeatureAnnotationUtilsScript.truncate_label_to_width(text, max_width, min_chars, font, font_size)


func intersects_any(rect: Rect2, existing: Array) -> bool:
	return FeatureAnnotationUtilsScript.intersects_any(rect, existing)


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
	return FeatureAnnotationUtilsScript.feature_to_collapsed_genome_row(feature, 1)
