extends RefCounted
class_name ReadTrackRenderer

var view: GenomeView = null


func configure(next_view: GenomeView) -> void:
	view = next_view


func _viewport_start_bp_at(render_start_bp: float, render_bp_per_px: float) -> float:
	if render_bp_per_px > 0.0:
		return render_start_bp
	return view.view_start_bp


func _viewport_end_bp_at(render_start_bp: float, render_bp_per_px: float, render_width_px: float = -1.0) -> float:
	var start_bp := _viewport_start_bp_at(render_start_bp, render_bp_per_px)
	var bp_per_px_value := render_bp_per_px if render_bp_per_px > 0.0 else view.bp_per_px
	var width_px := render_width_px
	if width_px <= 0.0:
		width_px = maxf(1.0, view.size.x - view.TRACK_LEFT_PAD - view.TRACK_RIGHT_PAD)
	return start_bp + width_px * bp_per_px_value


func _bp_to_x_at(bp: float, render_start_bp: float, render_bp_per_px: float) -> float:
	var start_bp := _viewport_start_bp_at(render_start_bp, render_bp_per_px)
	var bp_per_px_value := render_bp_per_px if render_bp_per_px > 0.0 else view.bp_per_px
	return (bp - start_bp) / bp_per_px_value


func _bp_to_screen_center_at(bp: float, render_start_bp: float, render_bp_per_px: float) -> float:
	return view.TRACK_LEFT_PAD + _bp_to_x_at(bp + 0.5, render_start_bp, render_bp_per_px)

func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt(dr * dr + dg * dg + db * db)


func _distinct_mate_palette() -> Array[Color]:
	var read_col: Color = view.palette["read"]
	var monochrome_base := read_col.s < 0.08
	var candidates: Array[Color] = [
		view.palette.get("aa_reverse", read_col.darkened(0.35)),
		view.palette.get("aa_forward", read_col.lightened(0.35)),
		view.palette.get("depth_plot", read_col.darkened(0.20)),
		view.palette.get("accent", read_col.lightened(0.20)),
		view.palette.get("gc_plot", read_col)
	]
	var out: Array[Color] = []
	for cand in candidates:
		if _color_distance(cand, read_col) < 0.18:
			continue
		var distinct := true
		for existing in out:
			if _color_distance(cand, existing) < 0.12:
				distinct = false
				break
		if distinct:
			out.append(cand)
	while out.size() < 5:
		var idx := out.size()
		var derived: Color
		if monochrome_base:
			var step := 0.10 + 0.06 * float(idx)
			if idx % 2 == 0:
				derived = read_col.lightened(step)
			else:
				derived = read_col.darkened(step)
			derived.s = 0.0
		else:
			derived = read_col
			derived.h = fposmod(read_col.h + 0.16 * float(idx + 1), 1.0)
			derived.s = min(1.0, max(read_col.s, 0.55))
			derived.v = min(1.0, max(read_col.v, 0.75))
		out.append(derived)
	return out

func _origin_contig_id(read: Dictionary) -> int:
	if not view.concat_segments.is_empty():
		var start_bp := int(read.get("start", 0))
		var end_bp := int(read.get("end", start_bp))
		var mid_bp := int(floor(0.5 * float(start_bp + end_bp)))
		return _segment_id_for_bp(mid_bp)
	return 0


func _mate_contig_colors(reads_in: Array[Dictionary]) -> Dictionary:
	if not view._color_by_mate_contig:
		return {}
	var inferred_ids := _inferred_mate_contig_ids(reads_in)
	var counts_by_origin := {}
	for read in reads_in:
		var origin_ref_id := _origin_contig_id(read)
		if origin_ref_id < 0:
			continue
		var mate_ref_id := _effective_mate_contig_id(read, inferred_ids)
		if mate_ref_id < 0:
			continue
		if not counts_by_origin.has(origin_ref_id):
			counts_by_origin[origin_ref_id] = {}
		var counts: Dictionary = counts_by_origin[origin_ref_id]
		counts[mate_ref_id] = int(counts.get(mate_ref_id, 0)) + 1
		counts_by_origin[origin_ref_id] = counts
	if counts_by_origin.is_empty():
		return {}
	var palette_colors := _distinct_mate_palette()
	var out := {}
	for origin_any in counts_by_origin.keys():
		var origin_ref_id := int(origin_any)
		var counts: Dictionary = counts_by_origin[origin_any]
		var ids: Array[int] = []
		for id_any in counts.keys():
			ids.append(int(id_any))
		ids.sort_custom(func(a: int, b: int) -> bool:
			var ca := int(counts.get(a, 0))
			var cb := int(counts.get(b, 0))
			if ca == cb:
				return a < b
			return ca > cb
		)
		var submap := {}
		for i in range(mini(5, ids.size())):
			submap[ids[i]] = palette_colors[i]
		if ids.size() > 5:
			submap["_other"] = view.palette.get("feature_text", view.palette.get("text_muted", view.palette["read"]))
		out[origin_ref_id] = submap
	return out

func _effective_mate_contig_id(read: Dictionary, inferred_ids: Dictionary) -> int:
	var mate_ref_id := int(read.get("mate_ref_id", -1))
	if mate_ref_id >= 0:
		return mate_ref_id
	var key := "%s|%d|%d" % [str(read.get("name", "")), int(read.get("start", 0)), int(read.get("end", 0))]
	return int(inferred_ids.get(key, -1))

func _segment_id_for_bp(bp: int) -> int:
	for seg_any in view.concat_segments:
		var seg: Dictionary = seg_any
		var start_bp := int(seg.get("start", 0))
		var end_bp := int(seg.get("end", start_bp))
		if bp >= start_bp and bp < end_bp:
			return int(seg.get("id", -1))
	return -1

func _inferred_mate_contig_ids(reads_in: Array[Dictionary]) -> Dictionary:
	if view.concat_segments.is_empty():
		return {}
	var groups := {}
	for read in reads_in:
		var name := str(read.get("name", ""))
		if name.is_empty():
			continue
		var start_bp := int(read.get("start", 0))
		var end_bp := int(read.get("end", start_bp))
		var mid_bp := int(floor(0.5 * float(start_bp + end_bp)))
		var ref_id := _segment_id_for_bp(mid_bp)
		if ref_id < 0:
			continue
		if not groups.has(name):
			groups[name] = []
		var arr: Array = groups[name]
		arr.append({
			"key": "%s|%d|%d" % [name, start_bp, end_bp],
			"ref_id": ref_id
		})
		groups[name] = arr
	var out := {}
	for name_any in groups.keys():
		var entries: Array = groups[name_any]
		if entries.size() < 2:
			continue
		for i in range(entries.size()):
			var current: Dictionary = entries[i]
			for j in range(entries.size()):
				if i == j:
					continue
				var other: Dictionary = entries[j]
				var other_ref_id := int(other.get("ref_id", -1))
				if other_ref_id < 0 or other_ref_id == int(current.get("ref_id", -1)):
					continue
				out[str(current.get("key", ""))] = other_ref_id
				break
	return out

func _read_color(read: Dictionary, mate_contig_colors: Dictionary, inferred_ids: Dictionary) -> Color:
	var col: Color = view.palette["read"]
	if not view._color_by_mate_contig:
		return col
	var origin_ref_id := _origin_contig_id(read)
	if origin_ref_id < 0 or not mate_contig_colors.has(origin_ref_id):
		return col
	var mate_ref_id := _effective_mate_contig_id(read, inferred_ids)
	if mate_ref_id < 0:
		return col
	var submap: Dictionary = mate_contig_colors[origin_ref_id]
	if submap.has(mate_ref_id):
		return submap[mate_ref_id]
	if submap.has("_other"):
		return submap["_other"]
	return col


func draw_read_tracks(area: Rect2) -> void:
	if area.size.y <= 24.0:
		return
	var track_id := view._active_read_track_id
	view.draw_rect(area, view.palette["bg"], true)
	view._draw_grid(area)
	if not view._read_loading_message.is_empty():
		var font := view.get_theme_default_font()
		var fs := view._font_size_medium
		var text_col: Color = view._axis_text_color()
		var tw := font.get_string_size(view._read_loading_message, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tx := area.position.x + (area.size.x - tw) * 0.5
		var ty := area.position.y + area.size.y * 0.5 + float(fs) * 0.35
		view.draw_string(font, Vector2(tx, ty), view._read_loading_message, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_col)
		return
	var depth_only := view.bp_per_px > view.READ_RENDER_MAX_BP_PER_PX
	var summary_only := view.bp_per_px > view.DETAILED_READ_MAX_BP_PER_PX
	if depth_only:
		draw_coverage_tiles(area, true)
		return
	if summary_only:
		match view._read_view_mode:
			view.READ_VIEW_STRAND:
				draw_strand_summary(area)
			view.READ_VIEW_FRAGMENT:
				draw_fragment_summary(area)
			_:
				draw_stack_summary(area)
		return
	draw_coverage_tiles(area, false)
	if view.is_motion_read_layer_active():
		return

	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var row_h := view.current_read_row_h()
	var row_step := view.current_read_row_step()
	var scroll_px := 0.0
	if view._read_view_mode == view.READ_VIEW_FRAGMENT:
		scroll_px = view._reads_scrollbar.value * row_step
	elif view._read_view_mode == view.READ_VIEW_STRAND:
		scroll_px = -view._reads_scrollbar.value * row_step
	else:
		var max_offset := maxf(0.0, view._reads_scrollbar.max_value - view._reads_scrollbar.page)
		var effective_offset := maxf(0.0, max_offset - view._reads_scrollbar.value)
		scroll_px = effective_offset * row_step
	var strand_split_y := 0.0
	if view._read_view_mode == view.READ_VIEW_STRAND:
		strand_split_y = view._strand_split_y_for_area(area, view._reads_scrollbar.value)
		if strand_split_y >= content_top and strand_split_y <= content_bottom:
			view.draw_line(Vector2(0.0, strand_split_y), Vector2(view.size.x, strand_split_y), Color(0, 0, 0, 0.9), view.STRAND_SPLIT_LINE_WIDTH)
	var drawn_pairs: Dictionary = {}
	var mate_lookup := {}
	if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
		mate_lookup = build_mate_lookup()
	var inferred_ids := _inferred_mate_contig_ids(view._laid_out_reads)
	var mate_contig_colors := _mate_contig_colors(view._laid_out_reads)
	var pan_animating := view._pan_tween != null and view._pan_tween.is_running()
	var draw_snp_text := can_draw_read_snp_letters() and not pan_animating
	var snp_font := view.sequence_letter_font()
	var snp_font_size := maxi(8, read_text_font_size() - 1)
	var visible_end_bp := int(view._viewport_end_bp())
	var can_break_by_start := view._read_view_mode != view.READ_VIEW_STRAND
	for i in range(view._laid_out_reads.size()):
		var read: Dictionary = view._laid_out_reads[i]
		var read_start: int = read["start"]
		var read_end: int = read["end"]
		if can_break_by_start and read_start > visible_end_bp:
			break
		if read_end < int(view.view_start_bp) or read_start > int(view._viewport_end_bp()):
			continue
		if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
			var pair_key := pair_render_key(read)
			if not pair_key.is_empty():
				if drawn_pairs.has(pair_key):
					continue
				drawn_pairs[pair_key] = true
		var y := read_y_for_area(read, content_top, content_bottom, scroll_px, strand_split_y)
		if y + row_h < content_top or y > area.position.y + area.size.y - 4.0:
			continue
		var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(read_start)
		var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(read_end)
		var rect := Rect2(Vector2(x0, y), Vector2(maxf(2.0, x1 - x0), row_h))
		var read_color := _read_color(read, mate_contig_colors, inferred_ids)
		if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
			draw_pair_connector(read, y, read_color)
			draw_mate_block(read, y, read_color)
		view.draw_rect(rect, read_color, true)
		var draw_selected := false
		if track_id == view._selected_read_track_id and i == view._selected_read_index:
			draw_selected = true
		elif track_id == view._selected_read_track_id and not view._selected_read_pair_name.is_empty():
			var rname := str(read.get("name", ""))
			if rname == view._selected_read_pair_name:
				if (view._selected_read_flags & 1) != 0:
					draw_selected = true
				elif read_start == view._selected_read_pair_a_start and read_end == view._selected_read_pair_a_end:
					draw_selected = true
				elif read_start == view._selected_read_pair_b_start and read_end == view._selected_read_pair_b_end:
					draw_selected = true
		if draw_selected:
			var border_col: Color = view.palette.get("text", view._axis_text_color())
			view.draw_rect(rect.grow(1.5), border_col, false, 2.0)
		view._read_hitboxes.append({
			"rect": rect,
			"read": read,
			"read_index": i,
			"track_id": track_id
		})
		if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
			var mate_rect := mate_rect_for_read(read, y)
			if mate_rect.size.x > 0.0 and mate_rect.size.y > 0.0:
				if draw_selected:
					var mate_border: Color = view.palette.get("text", view._axis_text_color())
					view.draw_rect(mate_rect.grow(1.5), mate_border, false, 2.0)
				var mate_hit := mate_hitbox_payload(read, i, mate_lookup)
				view._read_hitboxes.append({
					"rect": mate_rect,
					"read": mate_hit.get("read", read),
					"read_index": int(mate_hit.get("read_index", i)),
					"track_id": track_id
				})
		if view.bp_per_px <= view.SNP_MARK_MAX_BP_PER_PX:
			var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
			var snp_bases: PackedByteArray = read.get("snp_bases", PackedByteArray())
			for j in range(snps.size()):
				var snp_bp := int(snps[j])
				if snp_bp < int(view.view_start_bp) or snp_bp > int(view._viewport_end_bp()):
					continue
				var sx := view._bp_to_screen_center(float(snp_bp))
				if sx < view.TRACK_LEFT_PAD or sx > view.size.x - view.TRACK_RIGHT_PAD:
					continue
				var snp_w := maxf(1.0, 1.0 / view.bp_per_px)
				var base_text := ""
				if draw_snp_text and j < snp_bases.size():
					var b := char(int(snp_bases[j]))
					base_text = "N" if b.is_empty() else b
					var base_w := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x + 2.0
					snp_w = maxf(snp_w, base_w)
				view.draw_rect(Rect2(sx - snp_w * 0.5, y, snp_w, row_h), view.palette.get("snp", Color(0.86, 0.14, 0.14)), true)
				if draw_snp_text and not base_text.is_empty():
					var tw := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x
					var tx := sx - tw * 0.5
					var ty := view._text_baseline_for_center(y + row_h * 0.5, snp_font, snp_font_size)
					view.draw_string(snp_font, Vector2(tx, ty), base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size, view.palette.get("snp_text", Color.WHITE))
			if not pan_animating:
				draw_indel_markers(read, y)


func draw_detailed_reads_to(target: CanvasItem, area: Rect2, render_start_bp: float, render_bp_per_px: float, render_end_bp: float, track_id: String) -> void:
	if area.size.y <= 24.0:
		return
	var visible_start := int(_viewport_start_bp_at(render_start_bp, render_bp_per_px))
	var visible_end_bp := int(render_end_bp)
	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var row_h := view.current_read_row_h()
	var row_step := view.current_read_row_step()
	var scroll_px := 0.0
	if view._read_view_mode == view.READ_VIEW_FRAGMENT:
		scroll_px = view._reads_scrollbar.value * row_step
	elif view._read_view_mode == view.READ_VIEW_STRAND:
		scroll_px = -view._reads_scrollbar.value * row_step
	else:
		var max_offset := maxf(0.0, view._reads_scrollbar.max_value - view._reads_scrollbar.page)
		var effective_offset := maxf(0.0, max_offset - view._reads_scrollbar.value)
		scroll_px = effective_offset * row_step
	var strand_split_y := 0.0
	if view._read_view_mode == view.READ_VIEW_STRAND:
		strand_split_y = view._strand_split_y_for_area(area, view._reads_scrollbar.value)
		if strand_split_y >= content_top and strand_split_y <= content_bottom:
			target.draw_line(Vector2(0.0, strand_split_y), Vector2(view.size.x, strand_split_y), Color(0, 0, 0, 0.9), view.STRAND_SPLIT_LINE_WIDTH)
	var drawn_pairs: Dictionary = {}
	var inferred_ids := _inferred_mate_contig_ids(view._laid_out_reads)
	var mate_contig_colors := _mate_contig_colors(view._laid_out_reads)
	var snp_font := view.sequence_letter_font()
	var snp_font_size := read_text_font_size()
	var draw_snp_text := view.can_draw_read_snp_letters_for_row_h(view.current_read_row_h())
	var can_break_by_start := view._read_view_mode != view.READ_VIEW_STRAND
	var render_screen_right := view.TRACK_LEFT_PAD + maxf(0.0, (render_end_bp - render_start_bp) / render_bp_per_px)
	for i in range(view._laid_out_reads.size()):
		var read: Dictionary = view._laid_out_reads[i]
		var read_start: int = read["start"]
		var read_end: int = read["end"]
		if can_break_by_start and read_start > visible_end_bp:
			break
		if read_end < visible_start or read_start > visible_end_bp:
			continue
		if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
			var pair_key := pair_render_key(read)
			if not pair_key.is_empty():
				if drawn_pairs.has(pair_key):
					continue
				drawn_pairs[pair_key] = true
		var y := read_y_for_area(read, content_top, content_bottom, scroll_px, strand_split_y)
		if y + row_h < content_top or y > area.position.y + area.size.y - 4.0:
			continue
		var x0 := view.TRACK_LEFT_PAD + _bp_to_x_at(read_start, render_start_bp, render_bp_per_px)
		var x1 := view.TRACK_LEFT_PAD + _bp_to_x_at(read_end, render_start_bp, render_bp_per_px)
		var rect := Rect2(Vector2(x0, y), Vector2(maxf(2.0, x1 - x0), row_h))
		var read_color := _read_color(read, mate_contig_colors, inferred_ids)
		if view._read_view_mode == view.READ_VIEW_PAIRED or view._read_view_mode == view.READ_VIEW_FRAGMENT:
			_draw_pair_connector_to(target, read, y, read_color, render_start_bp, render_bp_per_px)
			_draw_mate_block_to(target, read, y, read_color, render_start_bp, render_bp_per_px, render_end_bp)
		target.draw_rect(rect, read_color, true)
		var draw_selected := false
		if track_id == view._selected_read_track_id and i == view._selected_read_index:
			draw_selected = true
		elif track_id == view._selected_read_track_id and not view._selected_read_pair_name.is_empty():
			var rname := str(read.get("name", ""))
			if rname == view._selected_read_pair_name:
				if (view._selected_read_flags & 1) != 0:
					draw_selected = true
				elif read_start == view._selected_read_pair_a_start and read_end == view._selected_read_pair_a_end:
					draw_selected = true
				elif read_start == view._selected_read_pair_b_start and read_end == view._selected_read_pair_b_end:
					draw_selected = true
		if draw_selected:
			var border_col: Color = view.palette.get("text", view._axis_text_color())
			target.draw_rect(rect.grow(1.5), border_col, false, 2.0)
		if view.bp_per_px <= view.SNP_MARK_MAX_BP_PER_PX:
			var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
			var snp_bases: PackedByteArray = read.get("snp_bases", PackedByteArray())
			for j in range(snps.size()):
				var snp_bp := int(snps[j])
				if snp_bp < visible_start or snp_bp > visible_end_bp:
					continue
				var sx := _bp_to_screen_center_at(float(snp_bp), render_start_bp, render_bp_per_px)
				if sx < view.TRACK_LEFT_PAD or sx > render_screen_right:
					continue
				var snp_w := maxf(1.0, 1.0 / render_bp_per_px)
				var base_text := ""
				if draw_snp_text and j < snp_bases.size():
					var b := char(int(snp_bases[j]))
					base_text = "N" if b.is_empty() else b
					var base_w := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x + 1.0
					snp_w = maxf(snp_w, base_w)
				target.draw_rect(Rect2(sx - snp_w * 0.5, y, snp_w, row_h), view.palette.get("snp", Color(0.86, 0.14, 0.14)), true)
				if not base_text.is_empty():
					var tw := snp_font.get_string_size(base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size).x
					var tx := sx - tw * 0.5
					var ty := view._text_baseline_for_center(y + row_h * 0.5, snp_font, snp_font_size)
					target.draw_string(snp_font, Vector2(tx, ty), base_text, HORIZONTAL_ALIGNMENT_LEFT, -1, snp_font_size, view.palette.get("snp_text", Color.WHITE))
			_draw_indel_markers_to(target, read, y, render_start_bp, render_bp_per_px, render_end_bp)


func read_y_for_area(read: Dictionary, content_top: float, content_bottom: float, scroll_px: float, strand_split_y: float) -> float:
	var row_h := view.current_read_row_h()
	var row_step := view.current_read_row_step()
	if view._read_view_mode == view.READ_VIEW_FRAGMENT:
		var norm := clampf(float(read.get("frag_norm", 0.0)), 0.0, 1.0)
		var span := maxf(1.0, content_bottom - content_top - row_h)
		return content_bottom - row_h - norm * span
	var row: int = int(read.get("row", 0))
	if view._read_view_mode == view.READ_VIEW_STRAND:
		var split_gap := view._strand_split_gap_px()
		if bool(read.get("reverse", false)):
			return strand_split_y + split_gap * 0.5 + row * row_step
		return strand_split_y - split_gap * 0.5 - row_h - row * row_step
	return content_bottom - row_h - row * row_step + scroll_px


func draw_pair_connector(read: Dictionary, y: float, line_color: Color) -> void:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return
	var read_center := float(read.get("start", 0) + read.get("end", 0)) * 0.5
	var mate_center := float(mate_start + mate_end) * 0.5
	var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(read_center)
	var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(mate_center)
	var yc := y + view.current_read_row_h() * 0.5
	var draw_col := line_color
	draw_col.a = maxf(draw_col.a, 0.9)
	view.draw_line(Vector2(x0, yc), Vector2(x1, yc), draw_col, 1.0)


func _draw_pair_connector_to(target: CanvasItem, read: Dictionary, y: float, line_color: Color, render_start_bp: float, render_bp_per_px: float) -> void:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return
	var read_center := float(read.get("start", 0) + read.get("end", 0)) * 0.5
	var mate_center := float(mate_start + mate_end) * 0.5
	var x0 := view.TRACK_LEFT_PAD + _bp_to_x_at(read_center, render_start_bp, render_bp_per_px)
	var x1 := view.TRACK_LEFT_PAD + _bp_to_x_at(mate_center, render_start_bp, render_bp_per_px)
	var yc := y + view.current_read_row_h() * 0.5
	var draw_col := line_color
	draw_col.a = maxf(draw_col.a, 0.9)
	target.draw_line(Vector2(x0, yc), Vector2(x1, yc), draw_col, 1.0)


func can_draw_read_snp_letters() -> bool:
	return view.can_draw_read_snp_letters_for_row_h(view.current_read_row_h())


func read_text_font_size() -> int:
	return view._read_text_font_size_for_row_h(view.current_read_row_h())


func draw_indel_markers(read: Dictionary, y: float) -> void:
	var row_h := view.current_read_row_h()
	var mid_y := y + row_h * 0.5
	var half_h := maxf(1.0, row_h * 0.5)
	var trim_h := maxf(0.0, (row_h - half_h) * 0.5)
	var del_starts: PackedInt32Array = read.get("del_starts", PackedInt32Array())
	var del_ends: PackedInt32Array = read.get("del_ends", PackedInt32Array())
	var del_count := mini(del_starts.size(), del_ends.size())
	for i in range(del_count):
		var ds := int(del_starts[i])
		var de := int(del_ends[i])
		if de <= ds:
			continue
		if de < int(view.view_start_bp) or ds > int(view._viewport_end_bp()):
			continue
		var dx0 := view.TRACK_LEFT_PAD + view._bp_to_x(float(ds))
		var dx1 := view.TRACK_LEFT_PAD + view._bp_to_x(float(de))
		if trim_h > 0.0 and dx1 > dx0:
			view.draw_rect(Rect2(dx0, y, dx1 - dx0, trim_h), view.palette["bg"], true)
			view.draw_rect(Rect2(dx0, y + row_h - trim_h, dx1 - dx0, trim_h), view.palette["bg"], true)
		view.draw_line(Vector2(dx0, mid_y), Vector2(dx1, mid_y), Color(0.08, 0.08, 0.08, 0.95), 1.0)
	var ins_positions: PackedInt32Array = read.get("ins_positions", PackedInt32Array())
	for pos in ins_positions:
		var ip := int(pos)
		if ip < int(view.view_start_bp) or ip > int(view._viewport_end_bp()):
			continue
		var ix := view.TRACK_LEFT_PAD + view._bp_to_x(float(ip))
		var y0 := y + 1.0
		var y1 := y + row_h - 1.0
		var cap_w := maxf(4.0, row_h * 0.7)
		var cap_line_w := maxf(1.0, row_h * 0.15)
		var stem_line_w := maxf(1.0, row_h * 0.3)
		var col := Color(0.05, 0.05, 0.05, 0.98)
		view.draw_line(Vector2(ix, y0), Vector2(ix, y1), col, stem_line_w)
		view.draw_line(Vector2(ix - cap_w * 0.5, y0), Vector2(ix + cap_w * 0.5, y0), col, cap_line_w)
		view.draw_line(Vector2(ix - cap_w * 0.5, y1), Vector2(ix + cap_w * 0.5, y1), col, cap_line_w)


func _draw_indel_markers_to(target: CanvasItem, read: Dictionary, y: float, render_start_bp: float, render_bp_per_px: float, render_end_bp: float = -1.0) -> void:
	var row_h := view.current_read_row_h()
	var mid_y := y + row_h * 0.5
	var half_h := maxf(1.0, row_h * 0.5)
	var trim_h := maxf(0.0, (row_h - half_h) * 0.5)
	var visible_start := int(_viewport_start_bp_at(render_start_bp, render_bp_per_px))
	var visible_end := int(render_end_bp if render_end_bp > 0.0 else _viewport_end_bp_at(render_start_bp, render_bp_per_px))
	var del_starts: PackedInt32Array = read.get("del_starts", PackedInt32Array())
	var del_ends: PackedInt32Array = read.get("del_ends", PackedInt32Array())
	var del_count := mini(del_starts.size(), del_ends.size())
	for i in range(del_count):
		var ds := int(del_starts[i])
		var de := int(del_ends[i])
		if de <= ds:
			continue
		if de < visible_start or ds > visible_end:
			continue
		var dx0 := view.TRACK_LEFT_PAD + _bp_to_x_at(float(ds), render_start_bp, render_bp_per_px)
		var dx1 := view.TRACK_LEFT_PAD + _bp_to_x_at(float(de), render_start_bp, render_bp_per_px)
		if trim_h > 0.0 and dx1 > dx0:
			target.draw_rect(Rect2(dx0, y, dx1 - dx0, trim_h), view.palette["bg"], true)
			target.draw_rect(Rect2(dx0, y + row_h - trim_h, dx1 - dx0, trim_h), view.palette["bg"], true)
		target.draw_line(Vector2(dx0, mid_y), Vector2(dx1, mid_y), Color(0.08, 0.08, 0.08, 0.95), 1.0)
	var ins_positions: PackedInt32Array = read.get("ins_positions", PackedInt32Array())
	for pos in ins_positions:
		var ip := int(pos)
		if ip < visible_start or ip > visible_end:
			continue
		var ix := view.TRACK_LEFT_PAD + _bp_to_x_at(float(ip), render_start_bp, render_bp_per_px)
		var y0 := y + 1.0
		var y1 := y + row_h - 1.0
		var cap_w := maxf(4.0, row_h * 0.7)
		var cap_line_w := maxf(1.0, row_h * 0.15)
		var stem_line_w := maxf(1.0, row_h * 0.3)
		var col := Color(0.05, 0.05, 0.05, 0.98)
		target.draw_line(Vector2(ix, y0), Vector2(ix, y1), col, stem_line_w)
		target.draw_line(Vector2(ix - cap_w * 0.5, y0), Vector2(ix + cap_w * 0.5, y0), col, cap_line_w)
		target.draw_line(Vector2(ix - cap_w * 0.5, y1), Vector2(ix + cap_w * 0.5, y1), col, cap_line_w)


func draw_mate_block(read: Dictionary, y: float, block_color: Color) -> void:
	var mate_rect := mate_rect_for_read(read, y)
	if mate_rect.size.x <= 0.0 or mate_rect.size.y <= 0.0:
		return
	view.draw_rect(mate_rect, block_color, true)


func _draw_mate_block_to(target: CanvasItem, read: Dictionary, y: float, block_color: Color, render_start_bp: float, render_bp_per_px: float, render_end_bp: float = -1.0) -> void:
	var mate_rect := _mate_rect_for_read_at(read, y, render_start_bp, render_bp_per_px, render_end_bp)
	if mate_rect.size.x <= 0.0 or mate_rect.size.y <= 0.0:
		return
	target.draw_rect(mate_rect, block_color, true)


func mate_rect_for_read(read: Dictionary, y: float) -> Rect2:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return Rect2()
	if mate_end < int(view.view_start_bp) or mate_start > int(view._viewport_end_bp()):
		return Rect2()
	var mx0 := view.TRACK_LEFT_PAD + view._bp_to_x(mate_start)
	var mx1 := view.TRACK_LEFT_PAD + view._bp_to_x(mate_end)
	return Rect2(Vector2(mx0, y), Vector2(maxf(2.0, mx1 - mx0), view.current_read_row_h()))


func _mate_rect_for_read_at(read: Dictionary, y: float, render_start_bp: float, render_bp_per_px: float, render_end_bp: float = -1.0) -> Rect2:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	var visible_start := int(_viewport_start_bp_at(render_start_bp, render_bp_per_px))
	var visible_end := int(render_end_bp if render_end_bp > 0.0 else _viewport_end_bp_at(render_start_bp, render_bp_per_px))
	if mate_start < 0 or mate_end <= mate_start:
		return Rect2()
	if mate_end < visible_start or mate_start > visible_end:
		return Rect2()
	var mx0 := view.TRACK_LEFT_PAD + _bp_to_x_at(float(mate_start), render_start_bp, render_bp_per_px)
	var mx1 := view.TRACK_LEFT_PAD + _bp_to_x_at(float(mate_end), render_start_bp, render_bp_per_px)
	return Rect2(Vector2(mx0, y), Vector2(maxf(2.0, mx1 - mx0), view.current_read_row_h()))


func build_mate_lookup() -> Dictionary:
	var out := {}
	for i in range(view._laid_out_reads.size()):
		var candidate: Dictionary = view._laid_out_reads[i]
		var pair_key := pair_render_key(candidate)
		if pair_key.is_empty():
			continue
		var key := mate_lookup_key(
			pair_key,
			int(candidate.get("start", 0)),
			int(candidate.get("end", 0))
		)
		out[key] = {
			"read": candidate,
			"read_index": i
		}
	return out


func mate_lookup_key(pair_key: String, start_bp: int, end_bp: int) -> String:
	return "%s|%d|%d" % [pair_key, start_bp, end_bp]


func mate_hitbox_payload(read: Dictionary, current_index: int, mate_lookup: Dictionary = {}) -> Dictionary:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	var pair_key := pair_render_key(read)
	if not pair_key.is_empty():
		var lookup_key := mate_lookup_key(pair_key, mate_start, mate_end)
		if mate_lookup.has(lookup_key):
			var hit: Dictionary = mate_lookup[lookup_key]
			if int(hit.get("read_index", -1)) != current_index:
				return hit
	var mate_read := read.duplicate(true)
	var read_start := int(read.get("start", 0))
	var read_end := int(read.get("end", read_start))
	mate_read["start"] = mate_start
	mate_read["end"] = mate_end
	mate_read["mate_start"] = read_start
	mate_read["mate_end"] = read_end
	mate_read["reverse"] = (int(read.get("flags", 0)) & 32) != 0
	mate_read["cigar"] = ""
	mate_read["snps"] = PackedInt32Array()
	mate_read["snp_bases"] = PackedByteArray()
	mate_read["is_mate_hit"] = true
	return {
		"read": mate_read,
		"read_index": current_index
	}


func pair_render_key(read: Dictionary) -> String:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return ""
	var a0 := int(read.get("start", 0))
	var a1 := int(read.get("end", a0 + 1))
	var b0 := mate_start
	var b1 := mate_end
	if b0 < a0 or (b0 == a0 and b1 < a1):
		var t0 := a0
		var t1 := a1
		a0 = b0
		a1 = b1
		b0 = t0
		b1 = t1
	return "%s|%d|%d|%d|%d" % [str(read.get("name", "")), a0, a1, b0, b1]


func draw_coverage_tiles(area: Rect2, show_y_ticks: bool = false) -> void:
	if view.coverage_tiles.is_empty():
		return
	var visible_start := int(view.view_start_bp)
	var visible_end := int(view._viewport_end_bp())
	var vis_tiles_raw: Array[Dictionary] = []
	for tile in view.coverage_tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		if bins.is_empty():
			continue
		vis_tiles_raw.append(tile)
	if vis_tiles_raw.is_empty():
		return
	var vis_tiles: Array[Dictionary] = vis_tiles_raw
	var seen_keys := {}
	var unique_tiles: Array[Dictionary] = []
	for tile in vis_tiles:
		var key := "%d|%d" % [int(tile.get("start", 0)), int(tile.get("end", 0))]
		if seen_keys.get(key, false):
			continue
		seen_keys[key] = true
		unique_tiles.append(tile)
	unique_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	var max_depth := 0
	for tile in unique_tiles:
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		for d in bins:
			if d > max_depth:
				max_depth = d
	if max_depth <= 0:
		return
	var cov_color: Color = view.palette["read"]
	cov_color.a = 0.45
	var chart_top := area.position.y + 30.0
	var chart_bottom := area.position.y + area.size.y - 10.0
	var chart_height := maxf(1.0, chart_bottom - chart_top)
	if show_y_ticks:
		var axis_col: Color = view.palette["grid"]
		var text_col: Color = view._axis_text_color()
		var font := view.get_theme_default_font()
		var font_size := view._font_size_small
		var tick_x := view.TRACK_LEFT_PAD - 8.0
		var label_x := 26.0
		view.draw_line(Vector2(tick_x, chart_top), Vector2(tick_x, chart_bottom), axis_col, 1.0)
		var tick_vals: Array[int] = [0, int(round(float(max_depth) * 0.5)), max_depth]
		var tick_ys: Array[float] = [chart_bottom, (chart_top + chart_bottom) * 0.5, chart_top]
		for i in range(3):
			var ty: float = tick_ys[i]
			view.draw_line(Vector2(tick_x, ty), Vector2(tick_x + 5.0, ty), axis_col, 1.0)
			var label := str(tick_vals[i])
			view.draw_string(font, Vector2(label_x, ty + 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_col)
	for tile in unique_tiles:
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
		for i in range(bins.size()):
			var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
			var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
			if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
				continue
			var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_start_bp))
			var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_end_bp))
			var w := maxf(1.0, x1 - x0)
			var h := chart_height * (float(bins[i]) / float(max_depth))
			if h <= 0.0:
				continue
			if not show_y_ticks:
				view.draw_rect(Rect2(x0, chart_bottom - h, w, h), cov_color, true)
	if show_y_ticks:
		var line_col: Color = view.palette["read"]
		line_col.a = 0.9
		var prev := Vector2.ZERO
		var have_prev := false
		var prev_end_bp := -1
		for tile in unique_tiles:
			var tile_start := int(tile.get("start", 0))
			var tile_end := int(tile.get("end", 0))
			var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
			var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
			for i in range(bins.size()):
				var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
				var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
				if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
					continue
				var cx_bp := 0.5 * float(bin_start_bp + bin_end_bp)
				var x := view.TRACK_LEFT_PAD + view._bp_to_x(cx_bp)
				var norm := float(bins[i]) / float(max_depth)
				var y := chart_bottom - clampf(norm, 0.0, 1.0) * chart_height
				var p := Vector2(x, y)
				var contiguous := have_prev and bin_start_bp <= prev_end_bp + maxi(1, int(ceil(bin_span * 1.25)))
				var monotonic := not have_prev or p.x >= prev.x
				if have_prev and contiguous and monotonic:
					view.draw_line(prev, p, line_col, 1.5)
				elif have_prev:
					have_prev = false
				prev = p
				have_prev = true
				prev_end_bp = bin_end_bp


func draw_strand_summary(area: Rect2) -> void:
	view.draw_rect(area, view.palette["bg"], true)
	view._draw_grid(area)
	if view._strand_summary.is_empty():
		return
	var forward: PackedFloat32Array = view._strand_summary.get("forward", PackedFloat32Array())
	var reverse: PackedFloat32Array = view._strand_summary.get("reverse", PackedFloat32Array())
	if forward.is_empty() or reverse.is_empty():
		return
	var start_bp := int(view._strand_summary.get("start", int(view.view_start_bp)))
	var end_bp := int(view._strand_summary.get("end", int(view._viewport_end_bp())))
	var bins := mini(forward.size(), reverse.size())
	if bins <= 0:
		return
	var top := area.position.y + 12.0
	var bottom := area.position.y + area.size.y - 10.0
	var mid := (top + bottom) * 0.5
	var half_h := maxf(1.0, (bottom - top) * 0.5 - 4.0)
	view.draw_line(Vector2(view.TRACK_LEFT_PAD, mid), Vector2(area.position.x + area.size.x - view.TRACK_RIGHT_PAD, mid), view.palette["grid"], 1.0)
	var max_v := 1.0
	for i in range(bins):
		max_v = maxf(max_v, maxf(forward[i], reverse[i]))
	var bin_span := maxf(1.0, float(end_bp - start_bp) / float(bins))
	var fwd_col: Color = view.palette["read"]
	fwd_col.a = 0.65
	var rev_col: Color = view.palette["read"].darkened(0.25)
	rev_col.a = 0.65
	for i in range(bins):
		var bin_start_bp := start_bp + int(floor(float(i) * bin_span))
		var bin_end_bp := start_bp + int(ceil(float(i + 1) * bin_span))
		var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_start_bp))
		var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_end_bp))
		var w := maxf(1.0, x1 - x0)
		var fh := half_h * (forward[i] / max_v)
		var rh := half_h * (reverse[i] / max_v)
		if fh > 0.0:
			view.draw_rect(Rect2(x0, mid - fh, w, fh), fwd_col, true)
		if rh > 0.0:
			view.draw_rect(Rect2(x0, mid, w, rh), rev_col, true)


func draw_stack_summary(area: Rect2) -> void:
	view.draw_rect(area, view.palette["bg"], true)
	view._draw_grid(area)
	if view.coverage_tiles.is_empty():
		return
	var visible_start := int(view.view_start_bp)
	var visible_end := int(view._viewport_end_bp())
	var vis_tiles_raw: Array[Dictionary] = []
	for tile in view.coverage_tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		if bins.is_empty():
			continue
		vis_tiles_raw.append(tile)
	if vis_tiles_raw.is_empty():
		return
	var seen_keys := {}
	var unique_tiles: Array[Dictionary] = []
	for tile in vis_tiles_raw:
		var key := "%d|%d" % [int(tile.get("start", 0)), int(tile.get("end", 0))]
		if seen_keys.get(key, false):
			continue
		seen_keys[key] = true
		unique_tiles.append(tile)
	unique_tiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)
	var max_depth := 1
	for tile in unique_tiles:
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		for d in bins:
			max_depth = maxi(max_depth, int(d))
	var top := area.position.y + 12.0
	var bottom := area.position.y + area.size.y - 10.0
	var h := maxf(1.0, bottom - top)
	var bar_col: Color = view.palette["read"]
	bar_col.a = 0.65
	for tile in unique_tiles:
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
		for i in range(bins.size()):
			var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
			var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
			if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
				continue
			var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_start_bp))
			var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_end_bp))
			var w := maxf(1.0, x1 - x0)
			var bar_h := h * (float(bins[i]) / float(max_depth))
			if bar_h <= 0.0:
				continue
			view.draw_rect(Rect2(x0, bottom - bar_h, w, bar_h), bar_col, true)


func draw_fragment_summary(area: Rect2) -> void:
	view.draw_rect(area, view.palette["bg"], true)
	view._draw_grid(area)
	if view._fragment_summary.is_empty():
		return
	var p25: PackedFloat32Array = view._fragment_summary.get("p25", PackedFloat32Array())
	var median: PackedFloat32Array = view._fragment_summary.get("median", PackedFloat32Array())
	var p75: PackedFloat32Array = view._fragment_summary.get("p75", PackedFloat32Array())
	if p25.is_empty() or median.is_empty() or p75.is_empty():
		return
	var start_bp := int(view._fragment_summary.get("start", int(view.view_start_bp)))
	var end_bp := int(view._fragment_summary.get("end", int(view._viewport_end_bp())))
	var visible_start := int(view.view_start_bp)
	var visible_end := int(view._viewport_end_bp())
	var bins := mini(p25.size(), mini(median.size(), p75.size()))
	if bins <= 0:
		return
	var top := area.position.y + 10.0
	var bottom := area.position.y + area.size.y - 8.0
	var h := maxf(1.0, bottom - top)
	var min_v := INF
	var max_v := -INF
	var bin_span := maxf(1.0, float(end_bp - start_bp) / float(bins))
	for i in range(bins):
		var bin_start_bp := start_bp + int(floor(float(i) * bin_span))
		var bin_end_bp := start_bp + int(ceil(float(i + 1) * bin_span))
		if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
			continue
		if p75[i] >= 0.0:
			min_v = minf(min_v, p25[i] if p25[i] >= 0.0 else p75[i])
			max_v = maxf(max_v, p75[i])
	if min_v == INF or max_v <= min_v:
		min_v = 0.0
		max_v = maxf(1.0, max_v)
	var scale_min := min_v
	var scale_max := max_v
	if view._fragment_log_scale:
		scale_min = log(scale_min + 1.0)
		scale_max = log(scale_max + 1.0)
	if scale_max <= scale_min:
		scale_max = scale_min + 1.0
	var band_col: Color = view.palette["read"]
	band_col.a = 0.25
	var line_col: Color = view.palette["read"]
	line_col.a = 0.95
	var prev_median := Vector2.ZERO
	var have_prev_median := false
	for i in range(bins):
		var bin_start_bp := start_bp + int(floor(float(i) * bin_span))
		var bin_end_bp := start_bp + int(ceil(float(i + 1) * bin_span))
		if bin_end_bp <= visible_start or bin_start_bp >= visible_end or median[i] < 0.0:
			have_prev_median = false
			continue
		var x0 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_start_bp))
		var x1 := view.TRACK_LEFT_PAD + view._bp_to_x(float(bin_end_bp))
		var w := maxf(1.0, x1 - x0)
		var v25 := p25[i]
		var v50 := median[i]
		var v75 := p75[i]
		if view._fragment_log_scale:
			v25 = log(v25 + 1.0) if v25 >= 0.0 else -1.0
			v50 = log(v50 + 1.0)
			v75 = log(v75 + 1.0) if v75 >= 0.0 else -1.0
		var y25 := bottom - clampf((v25 - scale_min) / (scale_max - scale_min), 0.0, 1.0) * h if v25 >= 0.0 else bottom
		var y50 := bottom - clampf((v50 - scale_min) / (scale_max - scale_min), 0.0, 1.0) * h
		var y75 := bottom - clampf((v75 - scale_min) / (scale_max - scale_min), 0.0, 1.0) * h if v75 >= 0.0 else y50
		view.draw_rect(Rect2(x0, minf(y25, y75), w, absf(y75 - y25)), band_col, true)
		var cx := x0 + w * 0.5
		var p := Vector2(cx, y50)
		if have_prev_median:
			view.draw_line(prev_median, p, line_col, 1.5)
		prev_median = p
		have_prev_median = true
