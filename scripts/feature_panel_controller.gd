extends RefCounted
class_name FeaturePanelController

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func on_feature_clicked(feature: Dictionary) -> void:
	host._prepare_context_panel(host.CONTEXT_PANEL_FEATURE, "Feature Details", true)
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_name_label.visible = true
	host.feature_name_label.text = "Name: %s" % str(feature.get("name", "-"))
	host.feature_type_label.text = "Type: %s" % str(feature.get("type", "-"))
	host.feature_range_label.text = "Range: %d - %d" % [int(feature.get("start", 0)), int(feature.get("end", 0))]
	host.feature_strand_label.text = "Strand: %s" % str(feature.get("strand", "."))
	var feature_id := str(feature.get("id", "")).strip_edges()
	if feature_id.is_empty():
		host.feature_source_label.text = "Source: %s" % str(feature.get("source", "-"))
	else:
		host.feature_source_label.text = "Source: %s | ID=%s" % [str(feature.get("source", "-")), feature_id]
	var seq_text := "Sequence: %s" % str(feature.get("seq_name", host._current_chr_name))
	var paired_cds: Dictionary = feature.get("paired_cds", {})
	if not paired_cds.is_empty():
		var cds_id := str(paired_cds.get("id", "")).strip_edges()
		var cds_source := str(paired_cds.get("source", "-"))
		var cds_name := str(paired_cds.get("name", "-"))
		seq_text += "\n\nCDS\nName: %s\nRange: %d - %d\nStrand: %s\nSource: %s" % [
			cds_name,
			int(paired_cds.get("start", 0)),
			int(paired_cds.get("end", 0)),
			str(paired_cds.get("strand", ".")),
			cds_source
		]
		if not cds_id.is_empty():
			seq_text += "\nID: %s" % cds_id
	host.feature_seq_label.text = seq_text
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)


func on_feature_selected(feature: Dictionary) -> void:
	if not host._feature_panel_open:
		return
	on_feature_clicked(feature)


func on_read_clicked(read: Dictionary) -> void:
	host._prepare_context_panel(host.CONTEXT_PANEL_FEATURE, "Feature Details", true)
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.feature_name_label.visible = true
	var read_name := str(read.get("name", ""))
	if read_name.is_empty():
		read_name = "(unnamed)"
	var start_bp := int(read.get("start", 0))
	var end_bp := int(read.get("end", start_bp))
	var read_len := maxi(0, end_bp - start_bp)
	var cigar := str(read.get("cigar", ""))
	if cigar.is_empty() and bool(read.get("is_mate_hit", false)):
		cigar = "(mate CIGAR unavailable)"
	elif cigar.is_empty():
		cigar = "-"
	var mapq := int(read.get("mapq", 0))
	var flags := int(read.get("flags", 0))
	var strand := "-" if bool(read.get("reverse", false)) else "+"
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	var mate_raw_start := int(read.get("mate_raw_start", -1))
	var mate_raw_end := int(read.get("mate_raw_end", -1))
	var mate_ref_id := int(read.get("mate_ref_id", -1))
	var mate_text := "Mate: unavailable"
	var read_range_text := _format_read_range(start_bp, end_bp)
	if mate_start >= 0 and mate_end > mate_start:
		mate_text = "Mate: %s" % _format_read_range(mate_start, mate_end)
	elif mate_ref_id >= 0 and mate_raw_start >= 0 and mate_raw_end > mate_raw_start:
		var mate_chr_name := _chrom_name_for_id(mate_ref_id)
		if mate_chr_name.is_empty():
			mate_chr_name = "chr%d" % mate_ref_id
		mate_text = "Mate: %s:%d - %d" % [mate_chr_name, mate_raw_start, mate_raw_end]
	var frag_len := int(read.get("fragment_len", 0))
	host.feature_name_label.text = "Read: %s" % read_name
	host.feature_type_label.text = "Range: %s (%d bp)" % [read_range_text, read_len]
	host.feature_range_label.text = "CIGAR: %s" % cigar
	host.feature_strand_label.text = "Strand: %s | MAPQ: %d | Flags: %d" % [strand, mapq, flags]
	host.feature_source_label.text = "%s | Fragment: %d bp" % [mate_text, frag_len]
	host.feature_seq_label.text = "Flags:\n%s" % format_read_flags(flags)
	if mate_start >= 0 and mate_end > mate_start:
		_show_mate_jump_button(mate_start, mate_end, -1)
	elif mate_ref_id >= 0 and mate_raw_start >= 0 and mate_raw_end > mate_raw_start:
		_show_mate_jump_button(mate_raw_start, mate_raw_end, mate_ref_id)
	else:
		_hide_mate_jump_button()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)

func _chrom_name_for_id(chr_id: int) -> String:
	for c_any in host._chromosomes:
		var c: Dictionary = c_any
		if int(c.get("id", -1)) == chr_id:
			return str(c.get("name", ""))
	return ""


func _concat_segment_for_bp(bp: int) -> Dictionary:
	for seg_any in host._concat_segments:
		var seg: Dictionary = seg_any
		var start_bp := int(seg.get("start", 0))
		var end_bp := int(seg.get("end", start_bp))
		if bp >= start_bp and bp < end_bp:
			return seg
	return {}


func _format_read_range(start_bp: int, end_bp: int) -> String:
	if host._seq_view_mode != host.SEQ_VIEW_CONCAT:
		return "%d - %d" % [start_bp, end_bp]
	if end_bp <= start_bp:
		var point_seg := _concat_segment_for_bp(start_bp)
		if point_seg.is_empty():
			return "%d - %d" % [start_bp, end_bp]
		var point_name := str(point_seg.get("name", ""))
		var point_local := start_bp - int(point_seg.get("start", 0))
		return "%s:%d" % [point_name, point_local]
	var start_seg := _concat_segment_for_bp(start_bp)
	var end_seg := _concat_segment_for_bp(end_bp - 1)
	if start_seg.is_empty() or end_seg.is_empty():
		return "%d - %d" % [start_bp, end_bp]
	var start_name := str(start_seg.get("name", ""))
	var start_local := start_bp - int(start_seg.get("start", 0))
	var end_local := end_bp - int(end_seg.get("start", 0))
	if start_name == str(end_seg.get("name", "")):
		return "%s:%d - %d" % [start_name, start_local, end_local]
	return "%s:%d - %s:%d" % [start_name, start_local, str(end_seg.get("name", "")), end_local]


func _ensure_mate_jump_button() -> void:
	if host._read_mate_jump_button != null:
		return
	host._read_mate_jump_button = Button.new()
	host._read_mate_jump_button.text = "Jump to mate"
	host._read_mate_jump_button.size_flags_horizontal = Control.SIZE_FILL
	host.feature_content.add_child(host._read_mate_jump_button)
	host._read_mate_jump_button.pressed.connect(func() -> void:
		jump_to_mate(host.read_mate_jump_start, host.read_mate_jump_end, host.read_mate_jump_ref_id)
	)


func _show_mate_jump_button(start_bp: int, end_bp: int, ref_id: int) -> void:
	_ensure_mate_jump_button()
	host._read_mate_jump_button.visible = true
	host.read_mate_jump_start = start_bp
	host.read_mate_jump_end = end_bp
	host.read_mate_jump_ref_id = ref_id


func _hide_mate_jump_button() -> void:
	if host._read_mate_jump_button != null:
		host._read_mate_jump_button.visible = false
	host.read_mate_jump_ref_id = -1


func on_read_selected(read: Dictionary) -> void:
	if not host._feature_panel_open:
		return
	on_read_clicked(read)


func jump_to_mate(start_bp: int, end_bp: int, mate_ref_id: int = -1) -> void:
	if start_bp < 0 or end_bp <= start_bp:
		return
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT:
		var target_start_bp := start_bp
		var target_end_bp := end_bp
		if mate_ref_id >= 0:
			var seg := _concat_segment_for_chr_id(mate_ref_id)
			if seg.is_empty():
				return
			target_start_bp = int(seg.get("start", 0)) + start_bp
			target_end_bp = int(seg.get("start", 0)) + end_bp
		_jump_to_range(target_start_bp, target_end_bp)
		return
	if mate_ref_id >= 0 and mate_ref_id != host._selected_seq_id:
		if host._seq_view_mode != host.SEQ_VIEW_SINGLE:
			host._seq_view_option.select(host.SEQ_VIEW_SINGLE)
			host._on_seq_view_selected(host.SEQ_VIEW_SINGLE)
		for i in range(host._seq_option.item_count):
			if int(host._seq_option.get_item_id(i)) == mate_ref_id:
				host._seq_option.select(i)
				host._on_seq_selected(i)
				break
	_jump_to_range(start_bp, end_bp)


func _jump_to_range(start_bp: int, end_bp: int) -> void:
	if host._current_chr_len <= 0:
		return
	var width_px := maxf(1.0, host.genome_view.size.x)
	var current_bp_per_px := clampf(host._last_bp_per_px, host.genome_view.min_bp_per_px, host.genome_view.max_bp_per_px)
	var view_span_bp := int(ceil(current_bp_per_px * width_px))
	var center_bp := 0.5 * float(start_bp + end_bp)
	var target_start := maxi(0, int(floor(center_bp - 0.5 * float(view_span_bp))))
	host.genome_view.set_view_state(float(target_start), current_bp_per_px)
	host.genome_view.clear_region_selection()
	host._invalidate_viewport_cache()
	host._schedule_fetch()


func _concat_segment_for_chr_id(chr_id: int) -> Dictionary:
	for seg_any in host._concat_segments:
		var seg: Dictionary = seg_any
		if int(seg.get("id", -1)) == chr_id:
			return seg
	return {}


func format_read_flags(flags: int) -> String:
	var lines: Array[String] = []
	for entry_any in host.SAM_FLAG_LABELS:
		var entry: Dictionary = entry_any
		var bit := int(entry.get("bit", 0))
		var marker := "✓" if (flags & bit) != 0 else "✗"
		lines.append("%s %s (%d)" % [marker, str(entry.get("label", "")), bit])
	return "\n".join(lines)


func close_feature_panel() -> void:
	host._maybe_save_genome_track_settings()
	host._context_panel_mode = host.CONTEXT_PANEL_NONE
	host._feature_panel_open = false
	host._track_settings_open = false
	host._active_track_settings_id = ""
	host._hide_context_subpanels()
	host._slide_feature_panel(false, true)
