extends RefCounted
class_name FeaturePanelController

const VariantUtilsScript = preload("res://scripts/variant_utils.gd")

var host: Node = null
var _selected_matches_panel: VBoxContainer = null
var _variant_detail_label: RichTextLabel = null
var _selected_matches_summary: Label = null
var _selected_matches_above_label: Label = null
var _selected_matches_above_list: ItemList = null
var _selected_matches_below_label: Label = null
var _selected_matches_below_list: ItemList = null
var _selected_matches_above_payloads: Array[Dictionary] = []
var _selected_matches_below_payloads: Array[Dictionary] = []


func configure(next_host: Node) -> void:
	host = next_host
	_ensure_variant_detail_label()
	_ensure_selected_matches_panel()


func _ensure_variant_detail_label() -> void:
	if host == null or host.feature_content == null or _variant_detail_label != null:
		return
	_variant_detail_label = RichTextLabel.new()
	_variant_detail_label.visible = false
	_variant_detail_label.fit_content = true
	_variant_detail_label.scroll_active = false
	_variant_detail_label.selection_enabled = true
	_variant_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_variant_detail_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host.feature_content.add_child(_variant_detail_label)
	host.feature_content.move_child(_variant_detail_label, 0)

func _ensure_selected_matches_panel() -> void:
	if host == null or host.feature_content == null or _selected_matches_panel != null:
		return
	_selected_matches_panel = VBoxContainer.new()
	_selected_matches_panel.visible = false
	_selected_matches_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_selected_matches_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_matches_panel.add_theme_constant_override("separation", 8)
	host.feature_content.add_child(_selected_matches_panel)

	_selected_matches_summary = Label.new()
	_selected_matches_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_selected_matches_panel.add_child(_selected_matches_summary)

	_selected_matches_above_label = Label.new()
	_selected_matches_panel.add_child(_selected_matches_above_label)

	_selected_matches_above_list = ItemList.new()
	_selected_matches_above_list.custom_minimum_size = Vector2(0, 140)
	_selected_matches_above_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_matches_above_list.select_mode = ItemList.SELECT_SINGLE
	_selected_matches_above_list.allow_reselect = true
	_selected_matches_above_list.focus_mode = Control.FOCUS_ALL
	_selected_matches_above_list.item_selected.connect(_on_selected_matches_above_item_selected)
	_selected_matches_above_list.item_clicked.connect(_on_selected_matches_above_item_clicked)
	_selected_matches_panel.add_child(_selected_matches_above_list)

	_selected_matches_below_label = Label.new()
	_selected_matches_panel.add_child(_selected_matches_below_label)

	_selected_matches_below_list = ItemList.new()
	_selected_matches_below_list.custom_minimum_size = Vector2(0, 140)
	_selected_matches_below_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_selected_matches_below_list.select_mode = ItemList.SELECT_SINGLE
	_selected_matches_below_list.allow_reselect = true
	_selected_matches_below_list.focus_mode = Control.FOCUS_ALL
	_selected_matches_below_list.item_selected.connect(_on_selected_matches_below_item_selected)
	_selected_matches_below_list.item_clicked.connect(_on_selected_matches_below_item_clicked)
	_selected_matches_panel.add_child(_selected_matches_below_list)


func on_feature_clicked(feature: Dictionary) -> void:
	host._prepare_context_panel(host.CONTEXT_PANEL_FEATURE, "Feature Details", true)
	if _variant_detail_label != null:
		_variant_detail_label.visible = false
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_name_label.visible = true
	host.feature_type_label.visible = true
	host.feature_range_label.visible = true
	host.feature_strand_label.visible = true
	host.feature_source_label.visible = true
	host.feature_seq_label.visible = true
	host.feature_name_label.text = "Name: %s" % str(feature.get("name", "-"))
	host.feature_type_label.text = "Type: %s" % str(feature.get("type", "-"))
	host.feature_range_label.text = "Range: %d - %d" % [
		_display_range_start_bp(int(feature.get("start", 0))),
		_display_range_end_bp(int(feature.get("end", 0)))
	]
	host.feature_strand_label.text = "Strand: %s" % str(feature.get("strand", "."))
	var feature_id := str(feature.get("id", "")).strip_edges()
	if feature_id.is_empty():
		host.feature_source_label.text = "Source: %s" % str(feature.get("source", "-"))
	else:
		host.feature_source_label.text = "Source: %s | ID=%s" % [str(feature.get("source", "-")), feature_id]
	var seq_text := "Sequence: %s" % str(feature.get("seq_name", host._current_chr_name))
	var cds_parts_any: Variant = feature.get("cds_parts", [])
	if cds_parts_any is Array and (cds_parts_any as Array).size() > 1:
		var cds_parts: Array = cds_parts_any
		seq_text += "\n\nExons / CDS Parts"
		for i in range(cds_parts.size()):
			var part_any: Variant = cds_parts[i]
			if typeof(part_any) != TYPE_DICTIONARY:
				continue
			var part: Dictionary = part_any
			var part_id := str(part.get("id", "")).strip_edges()
			var part_name := str(part.get("name", "-"))
			var part_source := str(part.get("source", "-"))
			seq_text += "\n\nPart %d\nName: %s\nRange: %d - %d\nStrand: %s\nSource: %s" % [
				i + 1,
				part_name,
				_display_range_start_bp(int(part.get("start", 0))),
				_display_range_end_bp(int(part.get("end", 0))),
				str(part.get("strand", ".")),
				part_source
			]
			if not part_id.is_empty():
				seq_text += "\nID: %s" % part_id
	var paired_cds: Dictionary = feature.get("paired_cds", {})
	if not paired_cds.is_empty():
		var cds_id := str(paired_cds.get("id", "")).strip_edges()
		var cds_source := str(paired_cds.get("source", "-"))
		var cds_name := str(paired_cds.get("name", "-"))
		seq_text += "\n\nCDS\nName: %s\nRange: %d - %d\nStrand: %s\nSource: %s" % [
			cds_name,
			_display_range_start_bp(int(paired_cds.get("start", 0))),
			_display_range_end_bp(int(paired_cds.get("end", 0))),
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
	if _variant_detail_label != null:
		_variant_detail_label.visible = false
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
		mate_text = "Mate: %s:%d - %d" % [
			mate_chr_name,
			_display_range_start_bp(mate_raw_start),
			_display_range_end_bp(mate_raw_end)
		]
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

func on_variant_clicked(variant: Dictionary, detail: Dictionary) -> void:
	host._prepare_context_panel(host.CONTEXT_PANEL_FEATURE, "Variant Details", true)
	_ensure_variant_detail_label()
	if _variant_detail_label != null:
		_variant_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_name_label.visible = false
	host.feature_type_label.visible = false
	host.feature_range_label.visible = false
	host.feature_strand_label.visible = false
	host.feature_source_label.visible = false
	host.feature_seq_label.visible = false
	var source_name := str(detail.get("source_name", variant.get("source_name", "-")))
	var sample_name := str(variant.get("sample_name", "-"))
	var chrom := str(detail.get("chrom", host._current_chr_name))
	var start_bp := int(detail.get("start", variant.get("source_start", variant.get("start", 0))))
	var ref := str(detail.get("ref", variant.get("ref", "")))
	var alt_summary := str(detail.get("alt_summary", variant.get("alt_summary", "")))
	var rec_id := str(detail.get("id", variant.get("id", ".")))
	var kind_label := _variant_type_detail_label(int(detail.get("kind", variant.get("kind", 0))), ref, alt_summary)
	var seq_text := "Sample: %s\nFile: %s\nType: %s\n\nCHROM: %s\nPOS: %d\nID: %s\nREF: %s\nALT: %s\nQUAL: %s\nFILTER: %s\nINFO: %s" % [
		sample_name,
		source_name,
		kind_label,
		chrom,
		_display_range_start_bp(start_bp),
		rec_id,
		ref,
		alt_summary,
		str(detail.get("qual", variant.get("qual", 0.0))),
		str(detail.get("filter", variant.get("filter", "."))),
		str(detail.get("info", "."))
	]
	var samples: Array = detail.get("samples", [])
	if not samples.is_empty():
		var selected_sample: Dictionary = {}
		for sample_any in samples:
			if typeof(sample_any) != TYPE_DICTIONARY:
				continue
			var sample: Dictionary = sample_any
			if str(sample.get("name", "")) == sample_name:
				selected_sample = sample
				break
		if not selected_sample.is_empty():
			seq_text += "\n\nGenotype fields"
			var sample_value := str(selected_sample.get("value", ".")).strip_edges()
			if sample_value.is_empty() or sample_value == ".":
				seq_text += "\nNo information"
			else:
				var parts := sample_value.split("  ", false)
				var wrote_any := false
				for part_any in parts:
					var part := str(part_any).strip_edges()
					if part.is_empty():
						continue
					var eq_idx := part.find("=")
					if eq_idx > 0:
						var key := part.substr(0, eq_idx).strip_edges()
						var value := part.substr(eq_idx + 1).strip_edges()
						seq_text += "\n%s: %s" % [key, value]
					else:
						seq_text += "\n%s" % part
					wrote_any = true
				if not wrote_any:
					seq_text += "\nNo information"
		else:
			seq_text += "\n\nGenotype fields\nNo information"
	if _variant_detail_label != null:
		_variant_detail_label.text = seq_text
		_variant_detail_label.visible = true
	_hide_mate_jump_button()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)

func _variant_kind_label(kind: int) -> String:
	match kind:
		1:
			return "SNP"
		2:
			return "MNP"
		3:
			return "Insertion"
		4:
			return "Deletion"
		5:
			return "Complex"
		6:
			return "Symbolic"
		_:
			return "Variant"


func _variant_type_detail_label(kind: int, ref: String, alt_summary: String) -> String:
	kind = VariantUtilsScript.display_kind(kind, ref, alt_summary)
	var label := _variant_kind_label(kind)
	if alt_summary.contains(","):
		return label
	match kind:
		3:
			var inserted_bp := maxi(0, alt_summary.length() - ref.length())
			if inserted_bp > 0:
				return "%s (%dbp)" % [label, inserted_bp]
		4:
			var deleted_bp := maxi(0, ref.length() - alt_summary.length())
			if deleted_bp > 0:
				return "%s (%dbp)" % [label, deleted_bp]
	return label

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
		return "%d - %d" % [_display_range_start_bp(start_bp), _display_range_end_bp(end_bp)]
	if end_bp <= start_bp:
		var point_seg := _concat_segment_for_bp(start_bp)
		if point_seg.is_empty():
			return "%d - %d" % [_display_range_start_bp(start_bp), _display_range_end_bp(end_bp)]
		var point_name := str(point_seg.get("name", ""))
		var point_local := start_bp - int(point_seg.get("start", 0))
		return "%s:%d" % [point_name, _display_point_bp(point_local)]
	var start_seg := _concat_segment_for_bp(start_bp)
	var end_seg := _concat_segment_for_bp(end_bp - 1)
	if start_seg.is_empty() or end_seg.is_empty():
		return "%d - %d" % [_display_range_start_bp(start_bp), _display_range_end_bp(end_bp)]
	var start_name := str(start_seg.get("name", ""))
	var start_local := start_bp - int(start_seg.get("start", 0))
	var end_local := end_bp - int(end_seg.get("start", 0))
	if start_name == str(end_seg.get("name", "")):
		return "%s:%d - %d" % [start_name, _display_range_start_bp(start_local), _display_range_end_bp(end_local)]
	return "%s:%d - %s:%d" % [
		start_name,
		_display_range_start_bp(start_local),
		str(end_seg.get("name", "")),
		_display_range_end_bp(end_local)
	]


func _display_point_bp(bp: int) -> int:
	return bp + 1


func _display_range_start_bp(start_bp: int) -> int:
	return start_bp + 1


func _display_range_end_bp(end_bp: int) -> int:
	return end_bp


func _ensure_mate_jump_button() -> void:
	if host.read_mate_jump_button != null:
		return
	host.read_mate_jump_button = Button.new()
	host.read_mate_jump_button.text = "Jump to mate"
	host.read_mate_jump_button.size_flags_horizontal = Control.SIZE_FILL
	host.feature_content.add_child(host.read_mate_jump_button)
	host.read_mate_jump_button.pressed.connect(func() -> void:
		jump_to_mate(host.read_mate_jump_start, host.read_mate_jump_end, host.read_mate_jump_ref_id)
	)


func _show_mate_jump_button(start_bp: int, end_bp: int, ref_id: int) -> void:
	_ensure_mate_jump_button()
	host.read_mate_jump_button.visible = true
	host.read_mate_jump_start = start_bp
	host.read_mate_jump_end = end_bp
	host.read_mate_jump_ref_id = ref_id


func _hide_mate_jump_button() -> void:
	if host.read_mate_jump_button != null:
		host.read_mate_jump_button.visible = false
	host.read_mate_jump_ref_id = -1


func on_read_selected(read: Dictionary) -> void:
	if not host._feature_panel_open:
		return
	on_read_clicked(read)


func on_comparison_match_clicked(match: Dictionary) -> void:
	host._prepare_context_panel(host.CONTEXT_PANEL_FEATURE, "Comparison Match", true)
	if _variant_detail_label != null:
		_variant_detail_label.visible = false
	host.feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	host.feature_name_label.visible = true
	var top_name := str(match.get("top_name", "Top genome"))
	var bottom_name := str(match.get("bottom_name", "Bottom genome"))
	var top_contig := str(match.get("top_contig", "")).strip_edges()
	var bottom_contig := str(match.get("bottom_contig", "")).strip_edges()
	host.feature_name_label.text = "Pair: %s vs %s" % [top_name, bottom_name]
	host.feature_type_label.text = "Orientation: %s" % ("same strand" if bool(match.get("same_strand", true)) else "opposite strand")
	var top_label := top_name if top_contig.is_empty() else "%s / %s" % [top_name, top_contig]
	var bottom_label := bottom_name if bottom_contig.is_empty() else "%s / %s" % [bottom_name, bottom_contig]
	host.feature_range_label.text = "%s: %d - %d\n%s: %d - %d" % [
		top_label,
		_display_range_start_bp(int(match.get("top_local_start", match.get("query_start", 0)))),
		_display_range_end_bp(int(match.get("top_local_end", match.get("query_end", 0)))),
		bottom_label,
		_display_range_start_bp(int(match.get("bottom_local_start", match.get("target_start", 0)))),
		_display_range_end_bp(int(match.get("bottom_local_end", match.get("target_end", 0))))
	]
	host.feature_source_label.text = "Genome coords: %s: %d - %d\n%s: %d - %d" % [
		top_name,
		_display_range_start_bp(int(match.get("query_start", 0))),
		_display_range_end_bp(int(match.get("query_end", 0))),
		bottom_name,
		_display_range_start_bp(int(match.get("target_start", 0))),
		_display_range_end_bp(int(match.get("target_end", 0)))
	]
	host.feature_strand_label.text = "Identity: %.2f%%" % float(match.get("percent_identity", 0.0))
	var top_len := maxi(0, int(match.get("query_end", 0)) - int(match.get("query_start", 0)))
	var bottom_len := maxi(0, int(match.get("target_end", 0)) - int(match.get("target_start", 0)))
	host.feature_seq_label.text = "Span: %d bp / %d bp\nDouble-click a match to align both genomes near the left edge." % [top_len, bottom_len]
	_hide_mate_jump_button()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)

func show_selected_matches(selection: Dictionary) -> void:
	_ensure_selected_matches_panel()
	if _selected_matches_panel == null:
		return
	host._prepare_context_panel(host.CONTEXT_PANEL_SELECTED_MATCHES, "selected matches", false)
	var genome_name := str(selection.get("genome_name", "Genome"))
	var contig := str(selection.get("contig", "")).strip_edges()
	var range_label := "%d - %d" % [
		_display_range_start_bp(int(selection.get("local_start", selection.get("start_bp", 0)))),
		_display_range_end_bp(int(selection.get("local_end", selection.get("end_bp", 0))))
	]
	if contig.is_empty():
		_selected_matches_summary.text = "%s: %s" % [genome_name, range_label]
	else:
		_selected_matches_summary.text = "%s / %s: %s" % [genome_name, contig, range_label]
	_selected_matches_above_payloads = []
	_selected_matches_below_payloads = []
	_populate_selected_matches_list(_selected_matches_above_label, _selected_matches_above_list, "Matches To Genome Above", selection.get("matches_above", []), _selected_matches_above_payloads, false)
	_populate_selected_matches_list(_selected_matches_below_label, _selected_matches_below_list, "Matches To Genome Below", selection.get("matches_below", []), _selected_matches_below_payloads, true)
	_selected_matches_panel.visible = true
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)

func hide_subpanels() -> void:
	if _variant_detail_label != null:
		_variant_detail_label.visible = false
	if _selected_matches_panel != null:
		_selected_matches_panel.visible = false

func _populate_selected_matches_list(label: Label, item_list: ItemList, title: String, matches_any: Variant, dest: Array[Dictionary], selected_is_top: bool) -> void:
	item_list.clear()
	dest.clear()
	var matches: Array = matches_any if matches_any is Array else []
	if matches.is_empty():
		label.visible = false
		item_list.visible = false
		return
	label.text = "%s (%d)" % [title, matches.size()]
	label.visible = true
	item_list.visible = true
	for match_any in matches:
		if typeof(match_any) != TYPE_DICTIONARY:
			continue
		var match: Dictionary = match_any
		dest.append(match)
		var other_label := str(match.get("bottom_name", "")) if selected_is_top else str(match.get("top_name", ""))
		var other_contig := str(match.get("bottom_contig", "")) if selected_is_top else str(match.get("top_contig", ""))
		var range_start := int(match.get("bottom_local_start", 0)) if selected_is_top else int(match.get("top_local_start", 0))
		var range_end := int(match.get("bottom_local_end", 0)) if selected_is_top else int(match.get("top_local_end", 0))
		var line := "%s%s  %d - %d  %.2f%%" % [
			other_label,
			(" / %s" % other_contig) if not other_contig.is_empty() else "",
			_display_range_start_bp(range_start),
			_display_range_end_bp(range_end),
			float(match.get("percent_identity", 0.0))
		]
		item_list.add_item(line)

func _on_selected_matches_above_item_selected(index: int) -> void:
	if index < 0 or index >= _selected_matches_above_payloads.size():
		return
	if host != null and host.has_method("_on_selected_comparison_region_match"):
		host._on_selected_comparison_region_match(_selected_matches_above_payloads[index])

func _on_selected_matches_below_item_selected(index: int) -> void:
	if index < 0 or index >= _selected_matches_below_payloads.size():
		return
	if host != null and host.has_method("_on_selected_comparison_region_match"):
		host._on_selected_comparison_region_match(_selected_matches_below_payloads[index])

func _on_selected_matches_above_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_selected_matches_above_item_selected(index)

func _on_selected_matches_below_item_clicked(index: int, _at_position: Vector2, _mouse_button_index: int) -> void:
	_on_selected_matches_below_item_selected(index)


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
	var current_bp_per_px := clampf(host._last_bp_per_px, host.genome_view.min_bp_per_px, host.genome_view.max_bp_per_px)
	host._navigate_to_centered_range(start_bp, end_bp, current_bp_per_px)
	host.genome_view.clear_region_selection()


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
