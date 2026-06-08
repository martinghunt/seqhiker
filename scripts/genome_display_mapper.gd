extends RefCounted
class_name GenomeDisplayMapper

var chromosome_length := 1
var leading_pad_bp := 0.0
var trailing_pad_bp := 0.0
var gap_overrides: Array[Dictionary] = []
var total_bp := 1.0


func reset(length_bp: int) -> void:
	chromosome_length = maxi(length_bp, 1)
	leading_pad_bp = 0.0
	trailing_pad_bp = 0.0
	gap_overrides.clear()
	total_bp = float(chromosome_length)


func recompute(length_bp: int, soft_clip_tracks: Array[Dictionary], concat_segments: Array[Dictionary]) -> void:
	reset(length_bp)
	if soft_clip_tracks.is_empty():
		return
	if concat_segments.is_empty():
		_recompute_linear_padding(soft_clip_tracks)
		return
	_recompute_concat_padding(soft_clip_tracks, concat_segments)


func display_total_length_bp() -> float:
	return maxf(total_bp, float(chromosome_length))


func display_bp_for_genome_bp(bp: float) -> float:
	var out := clampf(bp, 0.0, float(chromosome_length)) + leading_pad_bp
	for gap_any in gap_overrides:
		var gap: Dictionary = gap_any
		var next_start := float(gap.get("next_start", 0.0))
		if bp >= next_start:
			out += float(gap.get("extra_bp", 0.0))
	return out


func genome_bp_for_display_bp(display_bp: float) -> float:
	var remaining := clampf(display_bp, 0.0, display_total_length_bp()) - leading_pad_bp
	if remaining <= 0.0:
		return 0.0
	for gap_any in gap_overrides:
		var gap: Dictionary = gap_any
		var next_start := float(gap.get("next_start", 0.0))
		var extra_bp := float(gap.get("extra_bp", 0.0))
		if remaining < next_start:
			return clampf(remaining, 0.0, float(chromosome_length))
		remaining -= extra_bp
		if remaining < next_start:
			return clampf(next_start, 0.0, float(chromosome_length))
	return clampf(remaining, 0.0, float(chromosome_length))


func display_start_bp_for_view(view_start_bp: float, bp_per_px: float, plot_width_px: float) -> float:
	if bp_per_px <= 0.0:
		return 0.0
	var raw := display_bp_for_genome_bp(view_start_bp)
	if view_start_bp <= 0.0001:
		raw -= leading_pad_bp
	var max_display_start := maxf(0.0, display_total_length_bp() - maxf(1.0, plot_width_px) * bp_per_px)
	return clampf(raw, 0.0, max_display_start)


func clamp_view_start(next_start_bp: float, bp_per_px: float, plot_width_px: float) -> float:
	if plot_width_px <= 0.0:
		return maxf(0.0, next_start_bp)
	var max_display_start := maxf(0.0, display_total_length_bp() - plot_width_px * bp_per_px)
	var next_display := display_bp_for_genome_bp(clampf(next_start_bp, 0.0, float(chromosome_length)))
	return genome_bp_for_display_bp(clampf(next_display, 0.0, max_display_start))


func _recompute_linear_padding(soft_clip_tracks: Array[Dictionary]) -> void:
	for entry_any in soft_clip_tracks:
		var entry: Dictionary = entry_any
		for read_any in entry.get("reads", []):
			var read: Dictionary = read_any
			var read_start := int(read.get("start", 0))
			var read_end := int(read.get("end", read_start))
			if read_start <= 0:
				leading_pad_bp = maxf(leading_pad_bp, _soft_clip_len(read, "soft_clip_left"))
			if read_end >= chromosome_length:
				trailing_pad_bp = maxf(trailing_pad_bp, _soft_clip_len(read, "soft_clip_right"))
	total_bp = float(chromosome_length) + leading_pad_bp + trailing_pad_bp


func _recompute_concat_padding(soft_clip_tracks: Array[Dictionary], concat_segments: Array[Dictionary]) -> void:
	var left_overhangs: Dictionary = {}
	var right_overhangs: Dictionary = {}
	for seg_any in concat_segments:
		var seg: Dictionary = seg_any
		var seg_id := int(seg.get("id", -1))
		left_overhangs[seg_id] = 0.0
		right_overhangs[seg_id] = 0.0
	for entry_any in soft_clip_tracks:
		var entry: Dictionary = entry_any
		for read_any in entry.get("reads", []):
			var read: Dictionary = read_any
			var read_start := int(read.get("start", 0))
			var read_end := int(read.get("end", read_start))
			var left_clip := _soft_clip_len(read, "soft_clip_left")
			var right_clip := _soft_clip_len(read, "soft_clip_right")
			for seg_any in concat_segments:
				var seg: Dictionary = seg_any
				var seg_id := int(seg.get("id", -1))
				var seg_start := int(seg.get("start", 0))
				var seg_end := int(seg.get("end", seg_start))
				if left_clip > 0.0 and read_start <= seg_start:
					left_overhangs[seg_id] = maxf(float(left_overhangs.get(seg_id, 0.0)), left_clip)
				if right_clip > 0.0 and read_end >= seg_end:
					right_overhangs[seg_id] = maxf(float(right_overhangs.get(seg_id, 0.0)), right_clip)
	for i in range(concat_segments.size()):
		var seg: Dictionary = concat_segments[i]
		var seg_id := int(seg.get("id", -1))
		if i == 0:
			leading_pad_bp = float(left_overhangs.get(seg_id, 0.0))
		if i == concat_segments.size() - 1:
			trailing_pad_bp = float(right_overhangs.get(seg_id, 0.0))
			continue
		var next_seg: Dictionary = concat_segments[i + 1]
		var next_id := int(next_seg.get("id", -1))
		var seg_end := float(seg.get("end", 0))
		var next_start := float(next_seg.get("start", seg_end))
		var genome_gap := maxf(0.0, next_start - seg_end)
		var needed_gap := float(right_overhangs.get(seg_id, 0.0)) + float(left_overhangs.get(next_id, 0.0))
		var extra_gap := maxf(0.0, needed_gap - genome_gap)
		if extra_gap > 0.0:
			gap_overrides.append({"next_start": next_start, "extra_bp": extra_gap})
	total_bp = float(chromosome_length) + leading_pad_bp + trailing_pad_bp
	for gap_any in gap_overrides:
		total_bp += float((gap_any as Dictionary).get("extra_bp", 0.0))


func _soft_clip_len(read: Dictionary, key: String) -> float:
	return float(str(read.get(key, "")).length())
