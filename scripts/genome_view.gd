extends Control
class_name GenomeView

signal viewport_changed(start_bp: int, end_bp: int, bp_per_px: float)
signal feature_clicked(feature: Dictionary)

const AA_ROW_H := 26.0
const AA_ROW_GAP := 5.0
const GENOME_H := 86.0
const TRACK_LEFT_PAD := 64.0
const TRACK_RIGHT_PAD := 28.0
const TOP_PAD := 16.0
const PANEL_GAP := 14.0
const BOTTOM_PAD := 12.0
const READ_ROW_H := 8.0
const READ_ROW_GAP := 4.0
const SNP_MARK_MAX_BP_PER_PX := 1.5
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

var palette: Dictionary = {
	"bg": Color("f7efe4"),
	"panel": Color("fff7eb"),
	"grid": Color("d4c6b4"),
	"text": Color("2b2520"),
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
var _trackpad_pan_sensitivity := 1.0
var _trackpad_pinch_sensitivity := 1.0
var _reads_scrollbar: VScrollBar
var _laid_out_reads: Array[Dictionary] = []
var _read_row_count := 0

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

func clear_all_data() -> void:
	reads.clear()
	_laid_out_reads.clear()
	_read_row_count = 0
	coverage_tiles.clear()
	features.clear()
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

func _set_zoom_progress(t: float) -> void:
	bp_per_px = lerpf(_zoom_from_bp_per_px, _zoom_to_bp_per_px, t)
	view_start_bp = _clamp_start(lerpf(_zoom_from_start_bp, _zoom_to_start_bp, t))
	queue_redraw()
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
	var genome_area := _genome_area()
	var anno_area := _annotation_area(genome_area)
	var read_area := _read_area(anno_area)
	_draw_read_tracks(read_area)
	_draw_aa_tracks(anno_area)
	_draw_genome_track(genome_area)
	_draw_file_status()

func _draw_read_tracks(area: Rect2) -> void:
	if area.size.y <= 24.0:
		return
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	draw_string(get_theme_default_font(), Vector2(14, area.position.y + 20), "Reads", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, palette["text"])
	_draw_coverage_tiles(area)

	var content_top := area.position.y + 30.0
	var content_bottom := area.position.y + area.size.y - 4.0
	var scroll_px := _reads_scrollbar.value * (READ_ROW_H + READ_ROW_GAP)
	for read in _laid_out_reads:
		var read_start: int = read["start"]
		var read_end: int = read["end"]
		if read_end < int(view_start_bp) || read_start > int(_viewport_end_bp()):
			continue
		var row: int = int(read.get("row", 0))
		var y := content_bottom - READ_ROW_H - row * (READ_ROW_H + READ_ROW_GAP) + scroll_px
		if y + READ_ROW_H < content_top or y > area.position.y + area.size.y - 4.0:
			continue
		var x0 := TRACK_LEFT_PAD + _bp_to_x(read_start)
		var x1 := TRACK_LEFT_PAD + _bp_to_x(read_end)
		var rect := Rect2(Vector2(x0, y), Vector2(maxf(2.0, x1 - x0), READ_ROW_H))
		draw_rect(rect, palette["read"], true)
		if bp_per_px <= SNP_MARK_MAX_BP_PER_PX:
			var snps: PackedInt32Array = read.get("snps", PackedInt32Array())
			for snp_bp in snps:
				if snp_bp < int(view_start_bp) or snp_bp > int(_viewport_end_bp()):
					continue
				var sx := TRACK_LEFT_PAD + _bp_to_x(float(snp_bp))
				if sx < TRACK_LEFT_PAD or sx > size.x - TRACK_RIGHT_PAD:
					continue
				var snp_w := maxf(1.0, 1.0 / bp_per_px)
				draw_rect(Rect2(sx - snp_w * 0.5, y, snp_w, READ_ROW_H), Color(0.86, 0.14, 0.14), true)

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
	_feature_hitboxes.clear()
	var labels := ["F1", "F2", "F3", "R1", "R2", "R3"]
	for i in range(6):
		var y := area_start + i * (AA_ROW_H + AA_ROW_GAP)
		var track_rect := Rect2(0.0, y, area.size.x, AA_ROW_H)
		draw_rect(track_rect, palette["bg"], true)
		_draw_grid(track_rect)
		draw_string(get_theme_default_font(), Vector2(14, y + 17), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, palette["text"])
		var aa_col: Color = palette["aa_forward"] if i < 3 else palette["aa_reverse"]
		draw_rect(Rect2(52, y + 7, 6, 12), aa_col, true)

	for feature in features:
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
		draw_rect(rect, palette["feature"], true)
		_feature_hitboxes.append({
			"rect": rect,
			"feature": feature
		})
		if rect.size.x > 60:
			draw_string(get_theme_default_font(), Vector2(rect.position.x + 4, rect.position.y + 14), str(feature["name"]), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 8, 12, Color.WHITE)

func _draw_genome_track(area: Rect2) -> void:
	var y := area.position.y
	draw_rect(area, palette["bg"], true)
	_draw_grid(area)
	draw_string(get_theme_default_font(), Vector2(14, y + 20), "Genome", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, palette["text"])
	var line_y := y + 36.0
	draw_line(Vector2(TRACK_LEFT_PAD, line_y), Vector2(size.x - 12.0, line_y), palette["genome"], 3.0)
	_draw_ticks(y, line_y)
	_draw_nucleotide_letters(y, line_y)

func _draw_ticks(top_y: float, line_y: float) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var tick_step := _nice_tick(span / 8.0)
	var first_tick := int(floor(view_start_bp / tick_step) * tick_step)
	var tick := first_tick
	while tick < int(view_start_bp + span):
		if tick >= 0:
			var x := TRACK_LEFT_PAD + _bp_to_x(float(tick))
			draw_line(Vector2(x, line_y - 8), Vector2(x, line_y + 8), palette["grid"], 1.0)
			draw_string(get_theme_default_font(), Vector2(x + 2, top_y + 54), _format_bp(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, palette["text"])
		tick += int(tick_step)

func _draw_grid(area: Rect2) -> void:
	var span := _plot_width() * bp_per_px
	if span <= 0:
		return
	var step := _nice_tick(span / 6.0)
	var first := int(floor(view_start_bp / step) * step)
	var grid := first
	while grid < int(view_start_bp + span):
		if grid >= 0:
			var x := TRACK_LEFT_PAD + _bp_to_x(float(grid))
			draw_line(Vector2(x, area.position.y), Vector2(x, area.position.y + area.size.y), palette["grid"], 1.0)
		grid += int(step)

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
	var fwd_y := line_y - 12.0
	var rev_y := line_y + 30.0
	var base_colors := {
		"A": Color("2b9348"),
		"C": Color("1d4ed8"),
		"G": Color("a16207"),
		"T": Color("b91c1c"),
		"N": palette["text"]
	}
	for i in range(base_count):
		var bp := reference_start_bp + i
		if bp < int(view_start_bp) || bp > int(_viewport_end_bp()):
			continue
		var fwd := reference_sequence.substr(i, 1).to_upper()
		var rev := _complement_base(fwd)
		var color: Color = base_colors.get(fwd, palette["text"])
		var x := TRACK_LEFT_PAD + _bp_to_x(float(bp)) + 1.0
		draw_string(font, Vector2(x, fwd_y), fwd, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
		draw_string(font, Vector2(x, rev_y), rev, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _complement_base(base: String) -> String:
	return COMPLEMENT_MAP.get(base, "N")

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos: Vector2 = event.position
		for hit in _feature_hitboxes:
			var rect: Rect2 = hit["rect"]
			if rect.has_point(mouse_pos):
				emit_signal("feature_clicked", hit["feature"])
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
	return Rect2(0.0, size.y - BOTTOM_PAD - GENOME_H, size.x, GENOME_H)

func _annotation_area(genome_area: Rect2) -> Rect2:
	var h := 6.0 * (AA_ROW_H + AA_ROW_GAP)
	var y := genome_area.position.y - PANEL_GAP - h
	return Rect2(0.0, y, size.x, h)

func _read_area(annotation_area: Rect2) -> Rect2:
	var h := annotation_area.position.y - PANEL_GAP - TOP_PAD
	return Rect2(0.0, TOP_PAD, size.x, maxf(24.0, h))

func _layout_reads() -> void:
	_laid_out_reads.clear()
	if reads.is_empty():
		_read_row_count = 0
		return

	var sorted_reads: Array = reads.duplicate(true)
	sorted_reads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("start", 0)) == int(b.get("start", 0)):
			return int(a.get("end", 0)) < int(b.get("end", 0))
		return int(a.get("start", 0)) < int(b.get("start", 0))
	)

	var row_ends: Array[int] = []
	for read_any in sorted_reads:
		var read: Dictionary = read_any
		var s := int(read.get("start", 0))
		var e := int(read.get("end", s + 1))
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
	_read_row_count = row_ends.size()

func _layout_read_scrollbar() -> void:
	if _reads_scrollbar == null:
		return
	var read_area := _read_area(_annotation_area(_genome_area()))
	var sb_x := size.x - 16.0
	_reads_scrollbar.position = Vector2(sb_x, read_area.position.y + 2.0)
	_reads_scrollbar.size = Vector2(12.0, maxf(12.0, read_area.size.y - 4.0))
	var visible_rows := maxf(1.0, floor((read_area.size.y - 34.0) / (READ_ROW_H + READ_ROW_GAP)))
	var max_rows := maxi(_read_row_count, 0)
	_reads_scrollbar.visible = float(max_rows) > visible_rows
	_reads_scrollbar.max_value = float(max_rows)
	_reads_scrollbar.page = visible_rows
	_reads_scrollbar.value = clampf(_reads_scrollbar.value, 0.0, maxf(0.0, float(max_rows) - visible_rows))

func _on_reads_scroll_changed(_value: float) -> void:
	queue_redraw()
