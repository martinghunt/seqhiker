extends Control
class_name GenomeView

signal viewport_changed(start_bp: int, end_bp: int, bp_per_px: float)
signal feature_clicked(feature: Dictionary)
signal read_clicked(read: Dictionary)
signal track_settings_requested(track_id: String)
signal track_order_changed(order: PackedStringArray)

const AA_ROW_H := 26.0
const AA_ROW_GAP := 3.0
const GENOME_H := 86.0
const TRACK_LEFT_PAD := 64.0
const TRACK_RIGHT_PAD := 28.0
const TOP_PAD := 16.0
const PANEL_GAP := 14.0
const BOTTOM_PAD := 12.0
const READ_ROW_H := 8.0
const READ_ROW_GAP := 4.0
const SNP_MARK_MAX_BP_PER_PX := 1.5
const NUC_TEXT_MAX_BASES := 3000
const TRACK_ID_READS := "reads"
const TRACK_ID_AA := "aa"
const TRACK_ID_GENOME := "genome"
const READ_VIEW_STACK := 0
const READ_VIEW_STRAND := 1
const READ_VIEW_PAIRED := 2
const READ_VIEW_FRAGMENT := 3
const STRAND_SPLIT_GAP := 8.0
const STRAND_SPLIT_LINE_WIDTH := 2.5
const COMPLEMENT_MAP := {
	"A": "T",
	"T": "A",
	"U": "A",
	"C": "G",
	"G": "C",
	"R": "Y",
	"Y": "R",
	"S": "S",
	"W": "W",
	"K": "M",
	"M": "K",
	"B": "V",
	"V": "B",
	"D": "H",
	"H": "D",
	"N": "N"
}
const CODON_TO_AA := {
	"TTT": "F", "TTC": "F", "TTA": "L", "TTG": "L",
	"CTT": "L", "CTC": "L", "CTA": "L", "CTG": "L",
	"ATT": "I", "ATC": "I", "ATA": "I", "ATG": "M",
	"GTT": "V", "GTC": "V", "GTA": "V", "GTG": "V",
	"TCT": "S", "TCC": "S", "TCA": "S", "TCG": "S",
	"CCT": "P", "CCC": "P", "CCA": "P", "CCG": "P",
	"ACT": "T", "ACC": "T", "ACA": "T", "ACG": "T",
	"GCT": "A", "GCC": "A", "GCA": "A", "GCG": "A",
	"TAT": "Y", "TAC": "Y", "TAA": "*", "TAG": "*",
	"CAT": "H", "CAC": "H", "CAA": "Q", "CAG": "Q",
	"AAT": "N", "AAC": "N", "AAA": "K", "AAG": "K",
	"GAT": "D", "GAC": "D", "GAA": "E", "GAG": "E",
	"TGT": "C", "TGC": "C", "TGA": "*", "TGG": "W",
	"CGT": "R", "CGC": "R", "CGA": "R", "CGG": "R",
	"AGT": "S", "AGC": "S", "AGA": "R", "AGG": "R",
	"GGT": "G", "GGC": "G", "GGA": "G", "GGG": "G"
}

var chromosome_length := 50000
var view_start_bp := 0.0
var bp_per_px := 8.0
var min_bp_per_px := 0.02
var max_bp_per_px := 120.0

var reads: Array[Dictionary] = []
var coverage_tiles: Array[Dictionary] = []
var features: Array[Dictionary] = []
var loaded_files: PackedStringArray = PackedStringArray()
var reference_start_bp := 0
var reference_sequence := ""
var concat_segments: Array[Dictionary] = []

var palette: Dictionary = {
	"bg": Color("f7efe4"),
	"panel": Color("fff7eb"),
	"grid": Color("d4c6b4"),
	"text": Color("2b2520"),
	"aa_alt_bg": Color("ececec"),
	"genome": Color("3f5a7a"),
	"read": Color("0f8b8d"),
	"aa_forward": Color("8a4fff"),
	"aa_reverse": Color("f39237"),
	"feature": Color("c53211")
}

var _pan_tween: Tween
var _zoom_tween: Tween
var _zoom_from_bp_per_px := 8.0
var _zoom_to_bp_per_px := 8.0
var _zoom_from_start_bp := 0.0
var _zoom_to_start_bp := 0.0
var _feature_hitboxes: Array[Dictionary] = []
var _read_hitboxes: Array[Dictionary] = []
var _trackpad_pan_sensitivity := 1.0
var _trackpad_pinch_sensitivity := 1.0
var _reads_scrollbar: VScrollBar
var _laid_out_reads: Array[Dictionary] = []
var _read_row_count := 0
var _strand_forward_rows := 0
var _strand_reverse_rows := 0
var _read_view_mode := READ_VIEW_STACK
var _fragment_log_scale := false
var _read_row_h := READ_ROW_H
var _show_full_length_regions := false
var _track_order: PackedStringArray = PackedStringArray([TRACK_ID_READS, TRACK_ID_AA, TRACK_ID_GENOME])
var _track_grab_hitboxes: Array[Dictionary] = []
var _track_settings_hitboxes: Array[Dictionary] = []
var _track_drag_active := false
var _track_drag_track_id := ""
var _track_drag_target_index := -1

func _ready() -> void:
	clip_contents = true
	custom_minimum_size = Vector2(900, 560)
	_reads_scrollbar = VScrollBar.new()
	_reads_scrollbar.visible = false
	_reads_scrollbar.step = 1.0
	_reads_scrollbar.value_changed.connect(_on_reads_scroll_changed)
	add_child(_reads_scrollbar)
	_layout_read_scrollbar()
	_emit_viewport_changed()

func set_chromosome(chr_name: String, length_bp: int) -> void:
	chromosome_length = max(length_bp, 1)
	view_start_bp = 0.0
	reference_start_bp = 0
	reference_sequence = ""
	queue_redraw()
	_emit_viewport_changed()

func set_reads(next_reads: Array[Dictionary]) -> void:
	reads = next_reads
	_layout_reads()
	_layout_read_scrollbar()
	queue_redraw()

func set_coverage_tiles(next_tiles: Array[Dictionary]) -> void:
	coverage_tiles = next_tiles
	queue_redraw()

func set_features(next_features: Array[Dictionary]) -> void:
	features = next_features
	queue_redraw()

func set_reference_slice(start_bp: int, sequence: String) -> void:
	reference_start_bp = start_bp
	reference_sequence = sequence
	queue_redraw()

func set_concat_segments(segments: Array) -> void:
	concat_segments.clear()
	for seg in segments:
		if typeof(seg) == TYPE_DICTIONARY:
			concat_segments.append(seg)
	queue_redraw()

func clear_all_data() -> void:
	reads.clear()
	_laid_out_reads.clear()
	_read_row_count = 0
	coverage_tiles.clear()
	features.clear()
	concat_segments.clear()
	loaded_files = PackedStringArray()
	reference_start_bp = 0
	reference_sequence = ""
	view_start_bp = 0.0
	queue_redraw()
	_emit_viewport_changed()

func set_palette(next_palette: Dictionary) -> void:
	palette = next_palette
	queue_redraw()

func set_trackpad_pan_sensitivity(value: float) -> void:
	_trackpad_pan_sensitivity = clampf(value, 0.5, 20.0)

func set_trackpad_pinch_sensitivity(value: float) -> void:
	_trackpad_pinch_sensitivity = clampf(value, 0.5, 20.0)

func set_read_view_mode(mode: int) -> void:
	_read_view_mode = clampi(mode, READ_VIEW_STACK, READ_VIEW_FRAGMENT)
	if _reads_scrollbar != null:
		_reads_scrollbar.value = 0.0
	_layout_reads()
	_layout_read_scrollbar()
	if _read_view_mode == READ_VIEW_STRAND and _reads_scrollbar != null and _reads_scrollbar.visible:
		_reads_scrollbar.value = _reads_scrollbar.max_value * 0.5
	queue_redraw()

func set_fragment_log_scale(enabled: bool) -> void:
	_fragment_log_scale = enabled
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_layout_reads()
		_layout_read_scrollbar()
		queue_redraw()

func set_read_thickness(value: float) -> void:
	_read_row_h = clampf(value, 2.0, 24.0)
	_layout_reads()
	_layout_read_scrollbar()
	queue_redraw()

func set_show_full_length_regions(enabled: bool) -> void:
	_show_full_length_regions = enabled
	queue_redraw()

func get_track_order() -> PackedStringArray:
	return _track_order.duplicate()

func set_track_order(order: PackedStringArray) -> void:
	var prev := _track_order
	var valid := PackedStringArray([TRACK_ID_READS, TRACK_ID_AA, TRACK_ID_GENOME])
	var seen: Dictionary = {}
	var next := PackedStringArray()
	for id_any in order:
		var id := str(id_any)
		if not valid.has(id):
			continue
		if seen.get(id, false):
			continue
		seen[id] = true
		next.append(id)
	for id in valid:
		if not seen.get(id, false):
			next.append(id)
	_track_order = next
	_layout_read_scrollbar()
	queue_redraw()
	if prev != _track_order:
		emit_signal("track_order_changed", _track_order.duplicate())

func is_zoom_animating() -> bool:
	return _zoom_tween != null and _zoom_tween.is_running()

func pan_by_fraction(fraction: float, duration: float = 0.35) -> void:
	var plot_w := _plot_width()
	if plot_w <= 0:
		return
	var span := plot_w * bp_per_px
	var target := _clamp_start(view_start_bp + span * fraction)
	_pan_to(target, duration)

func zoom_by(factor: float, duration: float = 0.22) -> void:
	zoom_by_at_x(factor, TRACK_LEFT_PAD + _plot_width() * 0.5, duration)

func zoom_by_at_x(factor: float, anchor_x: float, duration: float = 0.22) -> void:
	var plot_w := _plot_width()
	if factor <= 0.0 || plot_w <= 0:
		return
	var old: float = bp_per_px
	var next: float = clampf(old * factor, min_bp_per_px, max_bp_per_px)
	if is_equal_approx(next, old):
		return
	var anchor_px := clampf(anchor_x - TRACK_LEFT_PAD, 0.0, plot_w)
	var anchor_bp: float = view_start_bp + old * anchor_px
	var target_start: float = _clamp_start(anchor_bp - next * anchor_px)
	_animate_zoom(view_start_bp, target_start, old, next, duration)

func load_files(paths: PackedStringArray) -> void:
	for p in paths:
		if not loaded_files.has(p):
			loaded_files.append(p)
	queue_redraw()

func _pan_to(target_start: float, duration: float) -> void:
	if _pan_tween and _pan_tween.is_running():
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.set_trans(Tween.TRANS_CUBIC)
	_pan_tween.set_ease(Tween.EASE_OUT)
	_pan_tween.tween_method(_set_view_start_animated, view_start_bp, target_start, duration)

func _set_view_start_animated(next_start: float) -> void:
	view_start_bp = _clamp_start(next_start)
	queue_redraw()
	_emit_viewport_changed()

func _animate_zoom(from_start: float, to_start: float, from_bp_per_px: float, to_bp_per_px: float, duration: float) -> void:
	if _zoom_tween and _zoom_tween.is_running():
		_zoom_tween.kill()
	_zoom_from_start_bp = from_start
	_zoom_to_start_bp = to_start
	_zoom_from_bp_per_px = from_bp_per_px
	_zoom_to_bp_per_px = to_bp_per_px
	_zoom_tween = create_tween()
	_zoom_tween.set_trans(Tween.TRANS_CUBIC)
	_zoom_tween.set_ease(Tween.EASE_OUT)
	_zoom_tween.tween_method(_set_zoom_progress, 0.0, 1.0, duration)
	_zoom_tween.finished.connect(_on_zoom_finished, CONNECT_ONE_SHOT)

func _set_zoom_progress(t: float) -> void:
	bp_per_px = lerpf(_zoom_from_bp_per_px, _zoom_to_bp_per_px, t)
	view_start_bp = _clamp_start(lerpf(_zoom_from_start_bp, _zoom_to_start_bp, t))
	queue_redraw()
	_emit_viewport_changed()

func _on_zoom_finished() -> void:
	_emit_viewport_changed()

func _clamp_start(next_start: float) -> float:
	var plot_w := _plot_width()
	if plot_w <= 0:
		return maxf(0.0, next_start)
	var max_start := maxf(0.0, float(chromosome_length) - plot_w * bp_per_px)
	return clampf(next_start, 0.0, max_start)

func _emit_viewport_changed() -> void:
	var end_bp := int(minf(float(chromosome_length), view_start_bp + _plot_width() * bp_per_px))
	emit_signal("viewport_changed", int(view_start_bp), end_bp, bp_per_px)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		view_start_bp = _clamp_start(view_start_bp)
		_layout_read_scrollbar()
		queue_redraw()
		_emit_viewport_changed()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["panel"], true)
	_track_grab_hitboxes.clear()
	_track_settings_hitboxes.clear()
	_read_hitboxes.clear()
	var track_rects := _track_layout_rects()
	for track_id in _track_order:
		if not track_rects.has(track_id):
			continue
		var area: Rect2 = track_rects[track_id]
		match track_id:
			TRACK_ID_READS:
				_draw_read_tracks(area)
			TRACK_ID_AA:
				_draw_aa_tracks(area)
			TRACK_ID_GENOME:
				_draw_genome_track(area)
		_draw_track_header(track_id, area)
	if _track_drag_active and _track_drag_target_index >= 0 and _track_drag_target_index < _track_order.size():
		var target_id := _track_order[_track_drag_target_index]
		if track_rects.has(target_id):
			var target_rect: Rect2 = track_rects[target_id]
			var y := target_rect.position.y - 2.0
			draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), Color(0.05, 0.05, 0.05, 0.9), 2.0)
	_draw_file_status()

func _draw_track_header(track_id: String, area: Rect2) -> void:
	var gx := 4.0
	var gy := area.position.y + 4.0
	var grab_rect := Rect2(gx, gy, 14.0, 14.0)
	var settings_rect := Rect2(gx, gy + 18.0, 14.0, 14.0)
	draw_rect(grab_rect, Color(1, 1, 1, 0.35), true)
	draw_rect(grab_rect, palette["grid"], false, 1.0)
	for i in range(3):
		var ly := grab_rect.position.y + 4.0 + i * 4.0
		draw_line(Vector2(grab_rect.position.x + 3.0, ly), Vector2(grab_rect.position.x + grab_rect.size.x - 3.0, ly), palette["text"], 1.0)
	draw_rect(settings_rect, Color(1, 1, 1, 0.35), true)
	draw_rect(settings_rect, palette["grid"], false, 1.0)
	draw_string(get_theme_default_font(), Vector2(settings_rect.position.x + 3.0, settings_rect.position.y + 11.0), "S", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, palette["text"])
	_track_grab_hitboxes.append({"rect": grab_rect, "track_id": track_id})
	_track_settings_hitboxes.append({"rect": settings_rect, "track_id": track_id})

func _track_label_for_id(track_id: String) -> String:
	match track_id:
		TRACK_ID_READS:
			return "Reads"
		TRACK_ID_AA:
			return "AA / Annotation"
		TRACK_ID_GENOME:
			return "Genome"
		_:
			return track_id

func _track_index_for_y(y: float) -> int:
	var rects := _track_layout_rects()
	for i in range(_track_order.size()):
		var track_id := _track_order[i]
		if not rects.has(track_id):
			continue
		var r: Rect2 = rects[track_id]
		if y < r.position.y + r.size.y * 0.5:
			return i
	return max(0, _track_order.size() - 1)

func _draw_read_tracks(area: Rect2) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	_draw_coverage_tiles(area)

	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var scroll_sign := -1.0 if _read_view_mode == READ_VIEW_STRAND else 1.0
	var scroll_px := scroll_sign * _reads_scrollbar.value * (_read_row_h + READ_ROW_GAP)
	var strand_split_y := 0.0
	if _read_view_mode == READ_VIEW_STRAND:
		var step_px := _read_row_h + READ_ROW_GAP
		var forward_extent := 0.0
		var reverse_extent := 0.0
		if _strand_forward_rows > 0:
			forward_extent = _read_row_h + float(_strand_forward_rows - 1) * step_px + STRAND_SPLIT_GAP * 0.5
		if _strand_reverse_rows > 0:
			reverse_extent = _read_row_h + float(_strand_reverse_rows - 1) * step_px + STRAND_SPLIT_GAP * 0.5
		var split_at_forward_top := content_top + forward_extent
		var split_at_reverse_bottom := content_bottom - reverse_extent
		if split_at_forward_top <= split_at_reverse_bottom:
			strand_split_y = (split_at_forward_top + split_at_reverse_bottom) * 0.5
		else:
			var range_px := split_at_forward_top - split_at_reverse_bottom
			var off_px := clampf(_reads_scrollbar.value, 0.0, range_px)
			strand_split_y = split_at_forward_top - off_px
		draw_line(Vector2(TRACK_LEFT_PAD, strand_split_y), Vector2(size.x - TRACK_RIGHT_PAD, strand_split_y), Color(0, 0, 0, 0.9), STRAND_SPLIT_LINE_WIDTH)
	var drawn_pairs: Dictionary = {}
	for read in _laid_out_reads:
		var read_start: int = read["start"]
		var read_end: int = read["end"]
		if read_end < int(view_start_bp) || read_start > int(_viewport_end_bp()):
			continue
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			var pair_key := _pair_render_key(read)
			if not pair_key.is_empty():
				if drawn_pairs.has(pair_key):
					continue
				drawn_pairs[pair_key] = true
		var y := _read_y_for_area(read, content_top, content_bottom, scroll_px, strand_split_y)
		if y + _read_row_h < content_top or y > area.position.y + area.size.y - 4.0:
			continue
		var x0 := TRACK_LEFT_PAD + _bp_to_x(read_start)
		var x1 := TRACK_LEFT_PAD + _bp_to_x(read_end)
		var rect := Rect2(Vector2(x0, y), Vector2(maxf(2.0, x1 - x0), _read_row_h))
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			_draw_pair_connector(read, y)
			_draw_mate_block(read, y)
		draw_rect(rect, palette["read"], true)
		_read_hitboxes.append({
			"rect": rect,
			"read": read
		})
		if _read_view_mode == READ_VIEW_PAIRED or _read_view_mode == READ_VIEW_FRAGMENT:
			var mate_rect := _mate_rect_for_read(read, y)
			if mate_rect.size.x > 0.0 and mate_rect.size.y > 0.0:
				_read_hitboxes.append({
					"rect": mate_rect,
					"read": read
				})
		if bp_per_px <= SNP_MARK_MAX_BP_PER_PX:
			var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
			for snp_bp in snps:
				if snp_bp < int(view_start_bp) or snp_bp > int(_viewport_end_bp()):
					continue
				var sx := TRACK_LEFT_PAD + _bp_to_x(float(snp_bp))
				if sx < TRACK_LEFT_PAD or sx > size.x - TRACK_RIGHT_PAD:
					continue
				var snp_w := maxf(1.0, 1.0 / bp_per_px)
				draw_rect(Rect2(sx - snp_w * 0.5, y, snp_w, _read_row_h), Color(0.86, 0.14, 0.14), true)

func _read_y_for_area(read: Dictionary, content_top: float, content_bottom: float, scroll_px: float, strand_split_y: float) -> float:
	if _read_view_mode == READ_VIEW_FRAGMENT:
		var norm := clampf(float(read.get("frag_norm", 0.0)), 0.0, 1.0)
		var span := maxf(1.0, content_bottom - content_top - _read_row_h)
		return content_bottom - _read_row_h - norm * span
	var row: int = int(read.get("row", 0))
	if _read_view_mode == READ_VIEW_STRAND:
		if bool(read.get("reverse", false)):
			return strand_split_y + STRAND_SPLIT_GAP * 0.5 + row * (_read_row_h + READ_ROW_GAP)
		return strand_split_y - STRAND_SPLIT_GAP * 0.5 - _read_row_h - row * (_read_row_h + READ_ROW_GAP)
	return content_bottom - _read_row_h - row * (_read_row_h + READ_ROW_GAP) + scroll_px

func _draw_pair_connector(read: Dictionary, y: float) -> void:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return
	var read_center := float(read.get("start", 0) + read.get("end", 0)) * 0.5
	var mate_center := float(mate_start + mate_end) * 0.5
	var x0 := TRACK_LEFT_PAD + _bp_to_x(read_center)
	var x1 := TRACK_LEFT_PAD + _bp_to_x(mate_center)
	var yc := y + _read_row_h * 0.5
	draw_line(Vector2(x0, yc), Vector2(x1, yc), Color(0.24, 0.24, 0.24, 0.9), 1.0)

func _draw_mate_block(read: Dictionary, y: float) -> void:
	var mate_rect := _mate_rect_for_read(read, y)
	if mate_rect.size.x <= 0.0 or mate_rect.size.y <= 0.0:
		return
	var mate_color: Color = palette["read"]
	draw_rect(mate_rect, mate_color, true)

func _mate_rect_for_read(read: Dictionary, y: float) -> Rect2:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return Rect2()
	if mate_end < int(view_start_bp) or mate_start > int(_viewport_end_bp()):
		return Rect2()
	var mx0 := TRACK_LEFT_PAD + _bp_to_x(mate_start)
	var mx1 := TRACK_LEFT_PAD + _bp_to_x(mate_end)
	return Rect2(Vector2(mx0, y), Vector2(maxf(2.0, mx1 - mx0), _read_row_h))

func _pair_render_key(read: Dictionary) -> String:
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

func _draw_coverage_tiles(area: Rect2) -> void:
	if coverage_tiles.is_empty():
		return

	var visible_start := int(view_start_bp)
	var visible_end := int(_viewport_end_bp())
	var max_depth := 0
	for tile in coverage_tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		for d in bins:
			if d > max_depth:
				max_depth = d
	if max_depth <= 0:
		return

	var cov_color: Color = palette["read"]
	cov_color.a = 0.45
	var chart_top := area.position.y + 30.0
	var chart_bottom := area.position.y + area.size.y - 10.0
	var chart_height := maxf(1.0, chart_bottom - chart_top)

	for tile in coverage_tiles:
		if typeof(tile) != TYPE_DICTIONARY:
			continue
		var tile_start := int(tile.get("start", 0))
		var tile_end := int(tile.get("end", 0))
		if tile_end <= visible_start or tile_start >= visible_end:
			continue
		var bins: PackedInt32Array = tile.get("bins", PackedInt32Array())
		if bins.is_empty():
			continue
		var bin_span := maxf(1.0, float(tile_end - tile_start) / float(bins.size()))
		for i in range(bins.size()):
			var bin_start_bp := tile_start + int(floor(float(i) * bin_span))
			var bin_end_bp := tile_start + int(ceil(float(i + 1) * bin_span))
			if bin_end_bp <= visible_start or bin_start_bp >= visible_end:
				continue
			var x0 := TRACK_LEFT_PAD + _bp_to_x(float(bin_start_bp))
			var x1 := TRACK_LEFT_PAD + _bp_to_x(float(bin_end_bp))
			var w := maxf(1.0, x1 - x0)
			var h := chart_height * (float(bins[i]) / float(max_depth))
			if h <= 0.0:
				continue
			draw_rect(Rect2(x0, chart_bottom - h, w, h), cov_color, true)

func _draw_aa_tracks(area: Rect2) -> void:
	var area_start := area.position.y
	var show_aa_letters := _can_draw_aa_letters()
	_feature_hitboxes.clear()
	for i in range(6):
		var y := area_start + i * (AA_ROW_H + AA_ROW_GAP)
		var track_rect := Rect2(0.0, y, area.size.x, AA_ROW_H)
		var bg_col: Color = palette["bg"]
		if i == 1 or i == 4:
			bg_col = palette.get("aa_alt_bg", bg_col)
		draw_rect(track_rect, bg_col, true)
		_draw_grid(track_rect)
	var split_y := area_start + 3.0 * (AA_ROW_H + AA_ROW_GAP) - AA_ROW_GAP * 0.5
	draw_line(Vector2(0.0, split_y), Vector2(size.x, split_y), Color(0.15, 0.15, 0.15, 0.45), 1.0)

	for feature in features:
		if _is_hidden_full_length_region(feature):
			continue
		var frame := _feature_to_frame(feature)
		if frame < 0 || frame > 5:
			continue
		var f_start: int = feature["start"]
		var f_end: int = feature["end"]
		if f_end < int(view_start_bp) || f_start > int(_viewport_end_bp()):
			continue
		var fy := area_start + frame * (AA_ROW_H + AA_ROW_GAP) + 4.0
		var fx0 := TRACK_LEFT_PAD + _bp_to_x(f_start)
		var fx1 := TRACK_LEFT_PAD + _bp_to_x(f_end)
		var rect := Rect2(Vector2(fx0, fy), Vector2(maxf(2.0, fx1 - fx0), AA_ROW_H - 8.0))
		var feature_col: Color = (palette["feature"] as Color).lerp(Color.WHITE, 0.45)
		feature_col.a = 0.6
		draw_rect(rect, feature_col, true)
		_feature_hitboxes.append({
			"rect": rect,
			"feature": feature
		})
		if rect.size.x > 60 and not show_aa_letters:
			draw_string(get_theme_default_font(), Vector2(rect.position.x + 4, rect.position.y + 14), str(feature["name"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 12, Color.WHITE)

	if show_aa_letters:
		_draw_aa_translation_letters(area_start)

func _can_draw_aa_letters() -> bool:
	if reference_sequence.is_empty():
		return false
	if _zoom_tween != null and _zoom_tween.is_running():
		return false
	var font := get_theme_default_font()
	var nuc_font_size := 14
	var nuc_char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, nuc_font_size).x
	if nuc_char_px <= 0.0:
		return false
	var pixels_per_bp := 1.0 / bp_per_px
	if pixels_per_bp < nuc_char_px + 1.0:
		return false
	var aa_font_size := 12
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x
	if aa_char_px <= 0.0:
		return false
	return 3.0 * pixels_per_bp >= aa_char_px + 1.0

func _draw_aa_translation_letters(area_start: float) -> void:
	if not _can_draw_aa_letters():
		return
	var font := get_theme_default_font()
	var aa_font_size := 12
	var aa_char_px := font.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size).x

	var seq_len := reference_sequence.length()
	if seq_len < 3:
		return
	var ref_start := reference_start_bp
	var ref_end := reference_start_bp + seq_len
	var vis_start := maxi(ref_start, int(floor(view_start_bp)))
	var vis_end := mini(ref_end, int(ceil(_viewport_end_bp())))
	if vis_end - vis_start < 3:
		return
	for frame in range(3):
		var first_bp := vis_start + posmod(frame - posmod(vis_start, 3), 3)
		var last_bp := vis_end - 3
		if last_bp < first_bp:
			continue
		var codon_count := int((last_bp - first_bp) / 3) + 1
		var max_by_pixels := maxi(1, int(floor(_plot_width() / maxf(1.0, aa_char_px + 1.0))) + 1)
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
			var b0 := reference_sequence.substr(i0, 1).to_upper()
			var b1 := reference_sequence.substr(i1, 1).to_upper()
			var b2 := reference_sequence.substr(i2, 1).to_upper()
			if b0 == " " or b1 == " " or b2 == " ":
				continue

			var codon := b0 + b1 + b2
			var aa_fwd := _translate_codon(codon)
			if not aa_fwd.is_empty():
				var x := TRACK_LEFT_PAD + _bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var y := area_start + frame * (AA_ROW_H + AA_ROW_GAP) + 17.0
				draw_string(font, Vector2(x, y), aa_fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, palette["text"])

			var rev_codon := _complement_base(b2) + _complement_base(b1) + _complement_base(b0)
			var aa_rev := _translate_codon(rev_codon)
			if not aa_rev.is_empty():
				var rx := TRACK_LEFT_PAD + _bp_to_x(float(bp) + 1.5) - aa_char_px * 0.5
				var ry := area_start + (3 + frame) * (AA_ROW_H + AA_ROW_GAP) + 17.0
				draw_string(font, Vector2(rx, ry), aa_rev, HORIZONTAL_ALIGNMENT_LEFT, -1, aa_font_size, palette["text"])

func _is_hidden_full_length_region(feature: Dictionary) -> bool:
	if _show_full_length_regions:
		return false
	var feature_type := str(feature.get("type", "")).to_lower()
	if feature_type != "region":
		return false
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", 0))
	return start_bp <= 0 and end_bp >= chromosome_length

func _draw_genome_track(area: Rect2) -> void:
	var y := area.position.y
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	var line_y := y + 36.0
	if concat_segments.is_empty():
		var axis_left := TRACK_LEFT_PAD
		var axis_right := size.x - TRACK_RIGHT_PAD
		var vis_start := maxf(0.0, view_start_bp)
		var vis_end := minf(_viewport_end_bp(), float(chromosome_length))
		if vis_end > vis_start:
			var x0 := clampf(axis_left + _bp_to_x(vis_start), axis_left, axis_right)
			var x1 := clampf(axis_left + _bp_to_x(vis_end), axis_left, axis_right)
			if x1 > x0:
				draw_line(Vector2(x0, line_y), Vector2(x1, line_y), palette["genome"], 3.0)
		_draw_ticks(y, line_y)
	else:
		_draw_concat_genome_axis(y, line_y)
	_draw_nucleotide_letters(y, line_y)

func _draw_concat_genome_axis(top_y: float, line_y: float) -> void:
	var axis_left := TRACK_LEFT_PAD
	var axis_right := size.x - TRACK_RIGHT_PAD
	var view_start := view_start_bp
	var visible_end := _viewport_end_bp()
	for seg in concat_segments:
		var seg_start := float(seg.get("start", 0))
		var seg_end := float(seg.get("end", 0))
		if seg_end <= view_start or seg_start >= visible_end:
			continue
		var x0 := axis_left + _bp_to_x(seg_start)
		var x1 := axis_left + _bp_to_x(seg_end)
		x0 = clampf(x0, axis_left, axis_right)
		x1 = clampf(x1, axis_left, axis_right)
		if x1 <= x0:
			continue
		draw_line(Vector2(x0, line_y), Vector2(x1, line_y), palette["genome"], 3.0)
		if seg_start >= view_start and seg_start <= visible_end:
			draw_line(Vector2(x0, line_y - 7.0), Vector2(x0, line_y + 7.0), Color.BLACK, 1.0)
		if seg_end >= view_start and seg_end <= visible_end:
			draw_line(Vector2(x1, line_y - 7.0), Vector2(x1, line_y + 7.0), Color.BLACK, 1.0)
		var name := str(seg.get("name", "chr"))
		var label_x := x0 + 4.0
		var label_w := maxf(0.0, x1 - x0 - 8.0)
		if label_w > 12.0:
			draw_string(get_theme_default_font(), Vector2(label_x, top_y + 16.0), name, HORIZONTAL_ALIGNMENT_LEFT, label_w, 12, palette["text"])

	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var view_end := _viewport_end_bp()
	var font := get_theme_default_font()
	var font_size := 11
	var max_tick_labels := 8
	var tick_step := _axis_tick_step(span)
	var segment_tick_labels: Array = []
	for seg in concat_segments:
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", 0))
		var seg_len := maxi(0, seg_end - seg_start)
		if seg_len <= 0:
			continue
		var vis_start := maxi(seg_start, int(floor(view_start_bp)))
		var vis_end := mini(seg_end, int(ceil(visible_end)))
		if vis_end <= vis_start:
			continue
		var local_vis_start := maxi(0, vis_start - seg_start)
		var local_vis_end := mini(seg_len, vis_end - seg_start)
		var first_local_tick := int(floor(float(local_vis_start) / float(tick_step)) * tick_step)
		var local_tick := first_local_tick
		var ticks_for_segment: Array = []
		while local_tick <= local_vis_end:
			if local_tick >= 0 and local_tick <= seg_len:
				var global_tick := seg_start + local_tick
				var x := TRACK_LEFT_PAD + _bp_to_x(float(global_tick))
				draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), palette["grid"], 1.0)
				ticks_for_segment.append({
					"x": x,
					"label": _format_axis_bp(local_tick, tick_step)
				})
			local_tick += tick_step
		segment_tick_labels.append(ticks_for_segment)

	for i in range(segment_tick_labels.size() - 1):
		var left_ticks: Array = segment_tick_labels[i]
		var right_ticks: Array = segment_tick_labels[i + 1]
		if left_ticks.is_empty() or right_ticks.is_empty():
			continue
		var left_last: Dictionary = left_ticks[left_ticks.size() - 1]
		var right_first: Dictionary = right_ticks[0]
		var left_x := float(left_last.get("x", 0.0)) + 2.0
		var right_x := float(right_first.get("x", 0.0)) + 2.0
		var left_label := str(left_last.get("label", ""))
		var left_w := font.get_string_size(left_label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if left_x + left_w > right_x:
			left_ticks.remove_at(left_ticks.size() - 1)

	var flat_labels: Array = []
	for ticks_for_segment in segment_tick_labels:
		for tick_info in ticks_for_segment:
			flat_labels.append(tick_info)
	flat_labels.sort_custom(func(a, b): return float(a.get("x", 0.0)) < float(b.get("x", 0.0)))

	if flat_labels.size() > max_tick_labels:
		var selected: Array = []
		for i in range(max_tick_labels):
			var idx := int(round(float(i) * float(flat_labels.size() - 1) / float(max_tick_labels - 1)))
			if selected.is_empty() or idx != int(selected[selected.size() - 1]):
				selected.append(idx)
		var filtered: Array = []
		for idx in selected:
			filtered.append(flat_labels[int(idx)])
		flat_labels = filtered

	for tick_info in flat_labels:
		var label := str(tick_info.get("label", ""))
		var x := float(tick_info.get("x", 0.0))
		draw_string(font, Vector2(x + 2.0, top_y + 54.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, palette["text"])

func _bp_in_concat_segment(bp: int) -> bool:
	for seg in concat_segments:
		var s := int(seg.get("start", 0))
		var e := int(seg.get("end", 0))
		if bp >= s and bp < e:
			return true
	return false

func _draw_ticks(top_y: float, line_y: float) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var tick_step := float(_axis_tick_step(span))
	var first_tick := int(floor(view_start_bp / tick_step) * tick_step)
	var tick := first_tick
	while tick < int(view_start_bp + span):
		if tick >= 0 and tick <= chromosome_length:
			var x := TRACK_LEFT_PAD + _bp_to_x(float(tick))
			draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), palette["grid"], 1.0)
			draw_string(get_theme_default_font(), Vector2(x + 2, top_y + 54), _format_axis_bp(tick, int(tick_step)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, palette["text"])
		tick += int(tick_step)

func _draw_grid(area: Rect2) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var step: float = maxf(1.0, _nice_tick(span / 6.0))
	var first: float = floor(view_start_bp / step) * step
	var grid: float = first
	while grid < view_start_bp + span:
		if grid >= 0.0:
			var x := TRACK_LEFT_PAD + _bp_to_x(grid)
			draw_line(Vector2(x, area.position.y), Vector2(x, area.position.y + area.size.y), palette["grid"], 1.0)
		grid += step

func _draw_file_status() -> void:
	if loaded_files.is_empty():
		draw_string(get_theme_default_font(), Vector2(16, size.y - 10), "Drop genome/BAM/annotation files anywhere to load", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, palette["text"])
	else:
		draw_string(get_theme_default_font(), Vector2(16, size.y - 10), "Loaded files: %d" % loaded_files.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, palette["text"])

func _draw_nucleotide_letters(top_y: float, line_y: float) -> void:
	if reference_sequence.is_empty():
		return
	var font := get_theme_default_font()
	var font_size := 14
	var char_px := font.get_string_size("A", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var pixels_per_bp := 1.0 / bp_per_px
	if pixels_per_bp < char_px + 1.0:
		return

	var base_count: int = reference_sequence.length()
	if base_count <= 0:
		return
	var vis_start_bp := int(floor(view_start_bp))
	var vis_end_bp := int(ceil(_viewport_end_bp()))
	var ref_start_bp := reference_start_bp
	var ref_end_bp := reference_start_bp + base_count
	if vis_end_bp < ref_start_bp or vis_start_bp > ref_end_bp:
		return
	var i_start := maxi(0, vis_start_bp - ref_start_bp)
	var i_end := mini(base_count - 1, vis_end_bp - ref_start_bp)
	if i_end < i_start:
		return
	if i_end - i_start + 1 > NUC_TEXT_MAX_BASES:
		i_end = i_start + NUC_TEXT_MAX_BASES - 1
	var fwd_y := line_y - 12.0
	var rev_y := line_y + 30.0
	var base_colors := {
		"A": Color("2b9348"),
		"C": Color("1d4ed8"),
		"G": Color("a16207"),
		"T": Color("b91c1c"),
		"N": palette["text"]
	}
	for i in range(i_start, i_end + 1):
		var bp := reference_start_bp + i
		var fwd := reference_sequence.substr(i, 1).to_upper()
		if fwd == " ":
			continue
		var rev := _complement_base(fwd)
		var color: Color = base_colors.get(fwd, palette["text"])
		var x := TRACK_LEFT_PAD + _bp_to_x(float(bp)) + 1.0
		draw_string(font, Vector2(x, fwd_y), fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(font, Vector2(x, rev_y), rev, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _complement_base(base: String) -> String:
	return COMPLEMENT_MAP.get(base, "N")

func _translate_codon(codon: String) -> String:
	if codon.length() != 3:
		return ""
	return str(CODON_TO_AA.get(codon, "X"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		for hit in _track_settings_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				emit_signal("track_settings_requested", str(hit["track_id"]))
				accept_event()
				return
		for hit in _track_grab_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				_track_drag_active = true
				_track_drag_track_id = str(hit["track_id"])
				_track_drag_target_index = _track_order.find(_track_drag_track_id)
				accept_event()
				return
		for hit in _feature_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				emit_signal("feature_clicked", hit["feature"])
				accept_event()
				return
		for i in range(_read_hitboxes.size() - 1, -1, -1):
			var read_hit: Dictionary = _read_hitboxes[i]
			var read_rect: Rect2 = read_hit["rect"]
			if read_rect.has_point(mouse_pos):
				emit_signal("read_clicked", read_hit["read"])
				accept_event()
				return
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		if _track_drag_active:
			var from_idx := _track_order.find(_track_drag_track_id)
			var to_idx := clampi(_track_drag_target_index, 0, _track_order.size() - 1)
			if from_idx >= 0 and to_idx >= 0 and from_idx != to_idx:
				var next := _track_order.duplicate()
				next.remove_at(from_idx)
				if to_idx > from_idx:
					to_idx -= 1
				next.insert(to_idx, _track_drag_track_id)
				set_track_order(next)
			_track_drag_active = false
			_track_drag_track_id = ""
			_track_drag_target_index = -1
			queue_redraw()
			accept_event()
			return
	elif event is InputEventMouseMotion and _track_drag_active:
		_track_drag_target_index = _track_index_for_y(event.position.y)
		queue_redraw()
		accept_event()
		return
	elif event is InputEventPanGesture:
		var pan_event := event as InputEventPanGesture
		if absf(pan_event.delta.x) > 0.0:
			_pan_by_pixels(pan_event.delta.x * _trackpad_pan_sensitivity * 3.0)
			accept_event()
	elif event is InputEventMagnifyGesture:
		var magnify_event := event as InputEventMagnifyGesture
		if magnify_event.factor > 0.0:
			# factor > 1 usually means zoom in; invert for bp/px scaling.
			var scaled_factor := pow(magnify_event.factor, _trackpad_pinch_sensitivity)
			scaled_factor = maxf(0.05, scaled_factor)
			var local_mouse := get_local_mouse_position()
			zoom_by_at_x(1.0 / scaled_factor, local_mouse.x, 0.12)
			accept_event()

func _pan_by_pixels(delta_x: float) -> void:
	if _plot_width() <= 0:
		return
	view_start_bp = _clamp_start(view_start_bp + delta_x * bp_per_px)
	queue_redraw()
	_emit_viewport_changed()

func auto_scroll_bp(delta_bp: float) -> bool:
	if _plot_width() <= 0:
		return true
	if is_zero_approx(delta_bp):
		return false
	var prev_start := view_start_bp
	var next_start := _clamp_start(view_start_bp + delta_bp)
	var moved := absf(next_start - prev_start) > 1e-9
	var reached_boundary := not moved
	view_start_bp = next_start
	queue_redraw()
	_emit_viewport_changed()
	return reached_boundary

func get_visible_span_bp() -> float:
	return _plot_width() * bp_per_px

func _plot_width() -> float:
	return maxf(1.0, size.x - TRACK_LEFT_PAD - TRACK_RIGHT_PAD)

func _viewport_end_bp() -> float:
	return view_start_bp + _plot_width() * bp_per_px

func _bp_to_x(bp: float) -> float:
	return (bp - view_start_bp) / bp_per_px

func _nice_tick(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var exp: float = floor(log(raw) / log(10.0))
	var base: float = pow(10.0, exp)
	var scaled: float = raw / base
	if scaled <= 1.0:
		return base
	if scaled <= 2.0:
		return 2.0 * base
	if scaled <= 5.0:
		return 5.0 * base
	return 10.0 * base

func _format_bp(value: int) -> String:
	if value >= 1000000:
		return "%.1f Mb" % (float(value) / 1000000.0)
	if value >= 1000:
		return "%.1f kb" % (float(value) / 1000.0)
	return "%d" % value

func _format_axis_bp(value: int, step: int) -> String:
	if step < 1000:
		return str(value)
	if step < 1000000:
		var kb := float(value) / 1000.0
		if step < 10000:
			return "%.2f kb" % kb
		if step < 100000:
			return "%.1f kb" % kb
		return "%.0f kb" % kb
	var mb := float(value) / 1000000.0
	if step < 10000000:
		return "%.2f Mb" % mb
	if step < 100000000:
		return "%.1f Mb" % mb
	return "%.0f Mb" % mb

func _axis_tick_step(span: float) -> int:
	if span <= 0.0:
		return 1
	var step6 := int(maxf(1.0, _nice_tick(span / 6.0)))
	var step8 := int(maxf(1.0, _nice_tick(span / 8.0)))
	var count6 := span / float(step6)
	var count8 := span / float(step8)
	var score6 := absf(count6 - 7.0)
	var score8 := absf(count8 - 7.0)
	if count6 < 6.0 or count6 > 8.0:
		score6 += 10.0
	if count8 < 6.0 or count8 > 8.0:
		score8 += 10.0
	if score8 < score6:
		return step8
	return step6

func _feature_to_frame(feature: Dictionary) -> int:
	var strand: String = str(feature.get("strand", "+"))
	var start: int = int(feature.get("start", 0))
	var end: int = int(feature.get("end", 0))
	if strand == "-":
		var reverse_phase := ((2 - ((end - 1) % 3)) + 3) % 3
		return 3 + reverse_phase
	return ((start % 3) + 3) % 3

func _generate_mock_data() -> void:
	reads.clear()
	features.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for i in range(420):
		var start := rng.randi_range(0, chromosome_length - 180)
		reads.append({
			"start": start,
			"end": start + rng.randi_range(40, 180)
		})
	var names := ["dnaA", "recA", "rpoB", "gyrA", "atpD", "hemE", "murC", "ftsZ", "lpxC", "nadK"]
	for i in range(75):
		var s := rng.randi_range(0, chromosome_length - 600)
		var e := s + rng.randi_range(120, 1600)
		features.append({
			"start": s,
			"end": min(e, chromosome_length),
			"strand": "+" if rng.randf() > 0.45 else "-",
			"name": names[i % names.size()]
		})

func _genome_area() -> Rect2:
	return _track_rect(TRACK_ID_GENOME)

func _annotation_area(genome_area: Rect2) -> Rect2:
	return _track_rect(TRACK_ID_AA)

func _read_area(annotation_area: Rect2) -> Rect2:
	return _track_rect(TRACK_ID_READS)

func _track_layout_rects() -> Dictionary:
	var out := {}
	if _track_order.is_empty():
		return out
	var fixed_sum := 0.0
	var flex_count := 0
	for track_id in _track_order:
		var h := _track_fixed_height(track_id)
		if h >= 0.0:
			fixed_sum += h
		else:
			flex_count += 1
	var gap_total := PANEL_GAP * maxf(0.0, float(_track_order.size() - 1))
	var available := maxf(0.0, size.y - TOP_PAD - BOTTOM_PAD - gap_total - fixed_sum)
	var flex_h := 0.0
	if flex_count > 0:
		flex_h = available / float(flex_count)
	var y := TOP_PAD
	for track_id in _track_order:
		var h := _track_fixed_height(track_id)
		if h < 0.0:
			h = maxf(24.0, flex_h)
		out[track_id] = Rect2(0.0, y, size.x, maxf(24.0, h))
		y += h + PANEL_GAP
	return out

func _track_fixed_height(track_id: String) -> float:
	match track_id:
		TRACK_ID_AA:
			return 6.0 * (AA_ROW_H + AA_ROW_GAP)
		TRACK_ID_GENOME:
			return GENOME_H
		_:
			return -1.0

func _track_rect(track_id: String) -> Rect2:
	var rects := _track_layout_rects()
	if rects.has(track_id):
		return rects[track_id]
	return Rect2(0.0, 0.0, size.x, 0.0)

func _layout_reads() -> void:
	_laid_out_reads.clear()
	_strand_forward_rows = 0
	_strand_reverse_rows = 0
	if reads.is_empty():
		_read_row_count = 0
		return

	if _read_view_mode == READ_VIEW_FRAGMENT:
		_layout_fragment_reads()
		return

	if _read_view_mode == READ_VIEW_STRAND:
		var forward_reads: Array = []
		var reverse_reads: Array = []
		for read in reads:
			if bool(read.get("reverse", false)):
				reverse_reads.append(read)
			else:
				forward_reads.append(read)
		_strand_forward_rows = _pack_reads_into_rows(forward_reads, false)
		_strand_reverse_rows = _pack_reads_into_rows(reverse_reads, false)
		_read_row_count = maxi(_strand_forward_rows, _strand_reverse_rows)
		return

	var use_pair_span := _read_view_mode == READ_VIEW_PAIRED
	_read_row_count = _pack_reads_into_rows(reads, use_pair_span)

func _layout_fragment_reads() -> void:
	var max_frag := 1.0
	for read in reads:
		var f := float(maxi(1, int(read.get("fragment_len", 0))))
		if f > max_frag:
			max_frag = f
	for read in reads:
		var laid_out: Dictionary = (read as Dictionary).duplicate(true)
		var f := float(maxi(1, int(laid_out.get("fragment_len", 0))))
		var norm := 0.0
		if _fragment_log_scale:
			norm = log(f + 1.0) / log(max_frag + 1.0)
		else:
			norm = f / max_frag
		laid_out["frag_norm"] = clampf(norm, 0.0, 1.0)
		_laid_out_reads.append(laid_out)
	_read_row_count = 0

func _pack_reads_into_rows(source_reads: Array, use_pair_span: bool) -> int:
	if source_reads.is_empty():
		return 0
	var sorted_reads: Array = source_reads.duplicate(true)
	sorted_reads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := _layout_span_start(a, use_pair_span)
		var sb := _layout_span_start(b, use_pair_span)
		if sa == sb:
			return _layout_span_end(a, use_pair_span) < _layout_span_end(b, use_pair_span)
		return sa < sb
	)
	var row_ends: Array[int] = []
	for read_any in sorted_reads:
		var read: Dictionary = read_any
		var s := _layout_span_start(read, use_pair_span)
		var e := _layout_span_end(read, use_pair_span)
		var chosen := -1
		for i in range(row_ends.size()):
			if s >= row_ends[i]:
				chosen = i
				break
		if chosen == -1:
			chosen = row_ends.size()
			row_ends.append(e)
		else:
			row_ends[chosen] = e
		var laid_out := read.duplicate(true)
		laid_out["row"] = chosen
		_laid_out_reads.append(laid_out)
	return row_ends.size()

func _layout_span_start(read: Dictionary, use_pair_span: bool) -> int:
	var s := int(read.get("start", 0))
	if not use_pair_span or not _should_use_mate_span_for_packing(read):
		return s
	var mate_start := int(read.get("mate_start", -1))
	if mate_start >= 0:
		return mini(s, mate_start)
	return s

func _layout_span_end(read: Dictionary, use_pair_span: bool) -> int:
	var s := int(read.get("start", 0))
	var e := int(read.get("end", s + 1))
	if not use_pair_span or not _should_use_mate_span_for_packing(read):
		return e
	var mate_end := int(read.get("mate_end", -1))
	if mate_end > 0:
		return maxi(e, mate_end)
	return e

func _should_use_mate_span_for_packing(read: Dictionary) -> bool:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return false
	var view_start := int(view_start_bp)
	var view_end := int(_viewport_end_bp())
	var view_span := maxi(1, view_end - view_start)
	# Keep packing tight: include mate span only when mate is close enough to current view.
	var max_distance := view_span * 2
	var read_start := int(read.get("start", 0))
	var read_end := int(read.get("end", read_start + 1))
	var read_center := int((read_start + read_end) / 2.0)
	var mate_center := int((mate_start + mate_end) / 2.0)
	return absi(mate_center - read_center) <= max_distance

func _layout_read_scrollbar() -> void:
	if _reads_scrollbar == null:
		return
	var read_area := _track_rect(TRACK_ID_READS)
	if read_area.size.y <= 0.0:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var sb_x := size.x - 16.0
	_reads_scrollbar.position = Vector2(sb_x, read_area.position.y + 2.0)
	_reads_scrollbar.size = Vector2(12.0, maxf(12.0, read_area.size.y - 4.0))
	if _read_view_mode == READ_VIEW_FRAGMENT:
		_reads_scrollbar.visible = false
		_reads_scrollbar.value = 0.0
		return
	var content_h := maxf(1.0, read_area.size.y - 34.0)
	var visible_rows := maxf(1.0, floor(content_h / (_read_row_h + READ_ROW_GAP)))
	var max_rows := maxi(_read_row_count, 0)
	if _read_view_mode == READ_VIEW_STRAND:
		var step_px := _read_row_h + READ_ROW_GAP
		var content_top := read_area.position.y + 30.0
		var content_bottom := read_area.position.y + read_area.size.y - 4.0
		var forward_extent := 0.0
		var reverse_extent := 0.0
		if _strand_forward_rows > 0:
			forward_extent = _read_row_h + float(_strand_forward_rows - 1) * step_px
		if _strand_reverse_rows > 0:
			reverse_extent = _read_row_h + float(_strand_reverse_rows - 1) * step_px
		var split_at_forward_top := content_top + forward_extent
		var split_at_reverse_bottom := content_bottom - reverse_extent
		var range_px := maxf(0.0, split_at_forward_top - split_at_reverse_bottom)
		_reads_scrollbar.visible = range_px > 0.0
		_reads_scrollbar.max_value = range_px
		_reads_scrollbar.page = maxf(1.0, minf(range_px, 64.0))
		_reads_scrollbar.step = 1.0
		_reads_scrollbar.value = clampf(_reads_scrollbar.value, 0.0, range_px)
		return
	var max_offset := maxf(0.0, float(max_rows) - visible_rows)
	_reads_scrollbar.visible = max_offset > 0.0
	_reads_scrollbar.max_value = max_offset
	_reads_scrollbar.page = 1.0
	_reads_scrollbar.step = 1.0
	_reads_scrollbar.value = clampf(_reads_scrollbar.value, 0.0, max_offset)

func _on_reads_scroll_changed(_value: float) -> void:
	queue_redraw()
