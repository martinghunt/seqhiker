extends RefCounted
class_name FeaturePanelController

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func on_feature_clicked(feature: Dictionary) -> void:
	host._track_settings_open = false
	host._active_track_settings_id = ""
	host.feature_title_label.text = "Feature Details"
	host._set_feature_labels_visible(true)
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_name_label.visible = true
	if host._track_settings_box != null:
		host._track_settings_box.visible = false
	if host._search_controller != null:
		host._search_controller.hide_panel()
	if host._read_mate_jump_button != null:
		host._read_mate_jump_button.visible = false
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
	host._track_settings_open = false
	host._active_track_settings_id = ""
	host.feature_title_label.text = "Feature Details"
	host._set_feature_labels_visible(true)
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	host.feature_name_label.visible = true
	if host._track_settings_box != null:
		host._track_settings_box.visible = false
	if host._search_controller != null:
		host._search_controller.hide_panel()
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
	var mate_text := "Mate: unavailable"
	if mate_start >= 0 and mate_end > mate_start:
		mate_text = "Mate: %d - %d" % [mate_start, mate_end]
	var frag_len := int(read.get("fragment_len", 0))
	host.feature_name_label.text = "Read: %s" % read_name
	host.feature_type_label.text = "Range: %d - %d (%d bp)" % [start_bp, end_bp, read_len]
	host.feature_range_label.text = "CIGAR: %s" % cigar
	host.feature_strand_label.text = "Strand: %s | MAPQ: %d | Flags: %d" % [strand, mapq, flags]
	host.feature_source_label.text = "%s | Fragment: %d bp" % [mate_text, frag_len]
	host.feature_seq_label.text = "Flags:\n%s" % format_read_flags(flags)
	if mate_start >= 0 and mate_end > mate_start:
		if host._read_mate_jump_button == null:
			host._read_mate_jump_button = Button.new()
			host._read_mate_jump_button.text = "Jump to mate"
			host._read_mate_jump_button.size_flags_horizontal = Control.SIZE_FILL
			host.feature_content.add_child(host._read_mate_jump_button)
			host._read_mate_jump_button.pressed.connect(func() -> void:
				jump_to_mate(host.read_mate_jump_start, host.read_mate_jump_end)
			)
		host._read_mate_jump_button.visible = true
		host.read_mate_jump_start = mate_start
		host.read_mate_jump_end = mate_end
	elif host._read_mate_jump_button != null:
		host._read_mate_jump_button.visible = false
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)


func on_read_selected(read: Dictionary) -> void:
	if not host._feature_panel_open:
		return
	on_read_clicked(read)


func jump_to_mate(start_bp: int, end_bp: int) -> void:
	if host._current_chr_len <= 0:
		return
	if start_bp < 0 or end_bp <= start_bp:
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
	host._feature_panel_open = false
	host._track_settings_open = false
	host._active_track_settings_id = ""
	if host._track_settings_box != null:
		host._track_settings_box.visible = false
	if host._search_controller != null:
		host._search_controller.hide_panel()
	if host._go_panel != null:
		host._go_panel.visible = false
	host._slide_feature_panel(false, true)
