extends RefCounted
class_name SearchController

const SEARCH_MODE_ANNOTATION := 0
const SEARCH_MODE_DNA_EXACT := 1
const SEARCH_SCOPE_CURRENT := 0
const SEARCH_SCOPE_ALL := 1
const SEARCH_DNA_MIN_LEN_DEFAULT := 12
const SEARCH_MAX_HITS := 5000
const SearchPanelScene = preload("res://scenes/SearchPanel.tscn")

var _callbacks: Dictionary = {}
var _search_box: VBoxContainer
var _scope_label: Label
var _search_mode_option: OptionButton
var _search_scope_option: OptionButton
var _search_query_edit: LineEdit
var _search_min_len_spin: SpinBox
var _search_revcomp_cb: CheckBox
var _search_case_sensitive_cb: CheckBox
var _search_results_list: ItemList
var _search_status_label: Label
var _search_hits: Array[Dictionary] = []
var _search_running := false

func setup(feature_content: VBoxContainer, callbacks: Dictionary) -> void:
	_callbacks = callbacks.duplicate()
	var panel := SearchPanelScene.instantiate()
	_search_box = panel as VBoxContainer
	if _search_box == null:
		return
	feature_content.add_child(_search_box)

	var mode_label := _search_box.get_node("ModeLabel") as Label
	_search_mode_option = _search_box.get_node("ModeOption") as OptionButton
	_scope_label = _search_box.get_node("ScopeLabel") as Label
	_search_scope_option = _search_box.get_node("ScopeOption") as OptionButton
	_search_query_edit = _search_box.get_node("QueryEdit") as LineEdit
	var min_len_label := _search_box.get_node("MinLenLabel") as Label
	_search_min_len_spin = _search_box.get_node("MinLenSpin") as SpinBox
	_search_revcomp_cb = _search_box.get_node("RevCompCheck") as CheckBox
	_search_case_sensitive_cb = _search_box.get_node("CaseSensitiveCheck") as CheckBox
	var run_button := _search_box.get_node("RunButton") as Button
	_search_status_label = _search_box.get_node("StatusLabel") as Label
	_search_results_list = _search_box.get_node("ResultsList") as ItemList

	if mode_label != null:
		mode_label.text = "Mode"
	if _search_mode_option != null:
		_search_mode_option.add_item("Annotation text", SEARCH_MODE_ANNOTATION)
		_search_mode_option.add_item("DNA exact", SEARCH_MODE_DNA_EXACT)
		_search_mode_option.select(0)
		_search_mode_option.item_selected.connect(_on_search_mode_changed)
	if _search_query_edit != null:
		_search_query_edit.placeholder_text = "Name, ID, type, source..."
		_search_query_edit.text_submitted.connect(func(_text: String) -> void:
			_run_search()
		)
	if min_len_label != null:
		min_len_label.text = "DNA min length"
		min_len_label.visible = false
	if _search_min_len_spin != null:
		_search_min_len_spin.min_value = 4
		_search_min_len_spin.max_value = 1000
		_search_min_len_spin.step = 1
		_search_min_len_spin.value = SEARCH_DNA_MIN_LEN_DEFAULT
		_search_min_len_spin.visible = false
	if _search_mode_option != null:
		_search_mode_option.set_meta("min_len_label", min_len_label)
	if _search_revcomp_cb != null:
		_search_revcomp_cb.visible = false
	if _search_case_sensitive_cb != null:
		_search_case_sensitive_cb.visible = true
	if run_button != null:
		run_button.pressed.connect(func() -> void:
			_run_search()
		)
	if _search_status_label != null:
		_search_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_search_status_label.text = "Ready."
	if _search_results_list != null:
		_search_results_list.item_selected.connect(_on_search_result_selected)
		_search_results_list.item_activated.connect(_on_search_result_selected)
	refresh_context()

func is_visible() -> bool:
	return _search_box != null and _search_box.visible

func show_panel() -> void:
	if _search_box != null:
		refresh_context()
		_search_box.visible = true

func hide_panel() -> void:
	if _search_box != null:
		_search_box.visible = false

func focus_query() -> void:
	if _search_query_edit != null:
		_search_query_edit.grab_focus()

func refresh_context() -> void:
	_refresh_scope_options()

func apply_theme(palette: Dictionary) -> void:
	if _search_results_list != null:
		var item_keys := [
			"font_color",
			"font_selected_color",
			"font_hovered_color",
			"font_hovered_selected_color",
			"font_disabled_color",
			"font_outline_color",
			"selection_fill",
			"selection_rect"
		]
		for key_any in item_keys:
			_search_results_list.remove_theme_color_override(str(key_any))
		_search_results_list.remove_theme_stylebox_override("panel")
		_search_results_list.remove_theme_stylebox_override("focus")
	if _search_status_label != null:
		_search_status_label.add_theme_color_override("font_color", palette["text"])
	if _search_query_edit != null:
		_search_query_edit.add_theme_color_override("font_color", palette["text"])
		_search_query_edit.add_theme_color_override("font_placeholder_color", palette.get("grid", palette["text"]))

func _on_search_mode_changed(index: int) -> void:
	if _search_mode_option == null:
		return
	var mode := int(_search_mode_option.get_item_id(index))
	var show_dna := mode == SEARCH_MODE_DNA_EXACT
	var min_len_label: Label = _search_mode_option.get_meta("min_len_label", null)
	if min_len_label != null:
		min_len_label.visible = show_dna
	if _search_min_len_spin != null:
		_search_min_len_spin.visible = show_dna
	if _search_revcomp_cb != null:
		_search_revcomp_cb.visible = show_dna
	if _search_case_sensitive_cb != null:
		_search_case_sensitive_cb.visible = not show_dna
	if _search_query_edit != null:
		_search_query_edit.placeholder_text = "ATGC..." if show_dna else "Name, ID, type, source..."

func _run_search() -> void:
	if _search_running:
		return
	if _search_query_edit == null or _search_status_label == null or _search_results_list == null:
		return
	var q := _search_query_edit.text.strip_edges()
	if q.is_empty():
		_search_status_label.text = "Enter a query."
		return
	var zem = _call0("get_zem")
	if zem == null:
		_search_status_label.text = "Not connected."
		return
	_refresh_scope_options()
	_search_running = true
	_search_hits.clear()
	_search_results_list.clear()
	var mode := int(_search_mode_option.get_selected_id())
	var is_comparison := _is_comparison_mode()
	var truncated := false
	var ok := true
	var case_sensitive := _search_case_sensitive_cb != null and _search_case_sensitive_cb.button_pressed
	if mode == SEARCH_MODE_DNA_EXACT:
		var clean := q.to_upper().replace(" ", "").replace("\n", "").replace("\t", "")
		var min_len := maxi(1, int(_search_min_len_spin.value))
		if clean.length() < min_len:
			_search_status_label.text = "DNA query too short (min %d)." % min_len
			_search_running = false
			return
		_search_status_label.text = "Searching DNA..."
		var include_revcomp := _search_revcomp_cb != null and _search_revcomp_cb.button_pressed
		var dna_res: Dictionary = {}
		if is_comparison:
			dna_res = await _search_comparison_dna_exact(clean, include_revcomp)
		else:
			dna_res = await _search_dna_exact(clean, _search_chr_ids_for_scope(_single_scope_value()), include_revcomp)
		ok = bool(dna_res.get("ok", false))
		truncated = bool(dna_res.get("truncated", false))
	else:
		_search_status_label.text = "Searching annotations..."
		var ann_res: Dictionary = {}
		if is_comparison:
			ann_res = await _search_comparison_annotations_text(q, case_sensitive)
		else:
			ann_res = await _search_annotations_text(q, _search_chr_ids_for_scope(_single_scope_value()), case_sensitive)
		ok = bool(ann_res.get("ok", false))
		truncated = bool(ann_res.get("truncated", false))
	if not ok:
		_search_running = false
		return
	_populate_search_results()
	var msg := "%d hit(s)" % _search_hits.size()
	if truncated:
		msg += " (truncated at %d)" % SEARCH_MAX_HITS
	_search_status_label.text = msg
	_search_running = false

func _search_chr_ids_for_scope(scope: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var chromosomes: Array[Dictionary] = _call0("get_chromosomes")
	if scope == SEARCH_SCOPE_ALL:
		for c in chromosomes:
			out.append(int(c.get("id", -1)))
		return out
	var selected_seq_id := int(_call0("get_selected_seq_id"))
	if selected_seq_id >= 0:
		out.append(selected_seq_id)
	return out

func _single_scope_value() -> int:
	if _search_scope_option == null:
		return SEARCH_SCOPE_CURRENT
	var idx := _search_scope_option.selected
	if idx < 0:
		return SEARCH_SCOPE_CURRENT
	var meta = _search_scope_option.get_item_metadata(idx)
	if typeof(meta) == TYPE_DICTIONARY:
		return int((meta as Dictionary).get("single_scope", SEARCH_SCOPE_CURRENT))
	return SEARCH_SCOPE_CURRENT

func _comparison_selected_genome_id() -> int:
	if _search_scope_option == null:
		return -1
	var idx := _search_scope_option.selected
	if idx < 0:
		return -1
	var meta = _search_scope_option.get_item_metadata(idx)
	if typeof(meta) != TYPE_DICTIONARY:
		return -1
	var data: Dictionary = meta
	if bool(data.get("all_genomes", false)):
		return -1
	return int(data.get("genome_id", -1))

func _comparison_genomes_for_scope() -> Array[Dictionary]:
	var genomes: Array[Dictionary] = _call0("get_comparison_genomes")
	var selected_genome_id := _comparison_selected_genome_id()
	if selected_genome_id < 0:
		return genomes
	var out: Array[Dictionary] = []
	for genome_any in genomes:
		var genome: Dictionary = genome_any
		if int(genome.get("id", -1)) == selected_genome_id:
			out.append(genome)
			break
	return out

func _search_annotations_text(query: String, chr_filter: PackedInt32Array, case_sensitive: bool) -> Dictionary:
	var zem = _call0("get_zem")
	var chromosomes: Array[Dictionary] = _call0("get_chromosomes")
	var truncated := false
	var needle := query if case_sensitive else query.to_lower()
	for c in chromosomes:
		var chr_id := int(c.get("id", -1))
		if chr_filter.find(chr_id) < 0:
			continue
		var chr_name := str(c.get("name", "chr"))
		var resp: Dictionary = zem.get_annotations(chr_id, 0, 0x7fffffff, 65535, 1)
		if not resp.get("ok", false):
			_search_status_label.text = "Annotation search failed: %s" % resp.get("error", "error")
			return {"ok": false, "truncated": false}
		for f_any in resp.get("features", []):
			var f: Dictionary = f_any
			var blob := "%s %s %s %s %s" % [
				str(f.get("name", "")),
				str(f.get("id", "")),
				str(f.get("type", "")),
				str(f.get("source", "")),
				str(f.get("seq_name", chr_name))
			]
			var haystack := blob if case_sensitive else blob.to_lower()
			if haystack.find(needle) < 0:
				continue
			_search_hits.append({
				"kind": "annotation",
				"chr_id": chr_id,
				"chr_name": chr_name,
				"start": int(f.get("start", 0)),
				"end": int(f.get("end", int(f.get("start", 0)) + 1)),
				"label": str(f.get("name", str(f.get("type", "feature"))))
			})
			if _search_hits.size() >= SEARCH_MAX_HITS:
				truncated = true
				return {"ok": true, "truncated": truncated}
		await (Engine.get_main_loop() as SceneTree).process_frame
	return {"ok": true, "truncated": truncated}

func _search_comparison_annotations_text(query: String, case_sensitive: bool) -> Dictionary:
	var zem = _call0("get_zem")
	var truncated := false
	var needle := query if case_sensitive else query.to_lower()
	var genomes := _comparison_genomes_for_scope()
	if genomes.is_empty():
		_search_status_label.text = "No comparison genomes loaded."
		return {"ok": false, "truncated": false}
	for genome_any in genomes:
		var genome: Dictionary = genome_any
		var genome_id := int(genome.get("id", -1))
		var genome_name := str(genome.get("name", "genome"))
		var genome_len := int(genome.get("length", 0))
		var resp: Dictionary = zem.get_comparison_annotations(genome_id, 0, genome_len, 65535, 1)
		if not resp.get("ok", false):
			_search_status_label.text = "Annotation search failed: %s" % resp.get("error", "error")
			return {"ok": false, "truncated": false}
		for f_any in resp.get("features", []):
			var f: Dictionary = f_any
			var chr_name := str(f.get("seq_name", genome_name))
			var blob := "%s %s %s %s %s %s" % [
				str(f.get("name", "")),
				str(f.get("id", "")),
				str(f.get("type", "")),
				str(f.get("source", "")),
				chr_name,
				genome_name
			]
			var haystack := blob if case_sensitive else blob.to_lower()
			if haystack.find(needle) < 0:
				continue
			var start_bp := int(f.get("start", 0))
			var end_bp := int(f.get("end", start_bp + 1))
			var local_range := _comparison_contig_range_for_interval(genome, start_bp, end_bp)
			_search_hits.append({
				"context": "comparison",
				"kind": "annotation",
				"genome_id": genome_id,
				"genome_name": genome_name,
				"seq_name": str(f.get("seq_name", chr_name)),
				"name": str(f.get("name", str(f.get("type", "feature")))),
				"id": str(f.get("id", "")),
				"type": str(f.get("type", "")),
				"source": str(f.get("source", "")),
				"strand": str(f.get("strand", ".")),
				"chr_name": str(local_range.get("contig_name", chr_name)),
				"start": start_bp,
				"end": end_bp,
				"display_start": int(local_range.get("start", start_bp)) + 1,
				"display_end": int(local_range.get("end", end_bp)),
				"label": str(f.get("name", str(f.get("type", "feature"))))
			})
			if _search_hits.size() >= SEARCH_MAX_HITS:
				truncated = true
				return {"ok": true, "truncated": truncated}
		await (Engine.get_main_loop() as SceneTree).process_frame
	return {"ok": true, "truncated": truncated}

func _search_dna_exact(pattern: String, chr_filter: PackedInt32Array, include_revcomp: bool) -> Dictionary:
	var zem = _call0("get_zem")
	var chromosomes: Array[Dictionary] = _call0("get_chromosomes")
	var truncated := false
	for c in chromosomes:
		var chr_id := int(c.get("id", -1))
		if chr_filter.find(chr_id) < 0:
			continue
		var chr_name := str(c.get("name", "chr"))
		var remaining_hits := maxi(1, SEARCH_MAX_HITS - _search_hits.size())
		var resp: Dictionary = zem.search_dna_exact(chr_id, pattern, include_revcomp, remaining_hits)
		if not resp.get("ok", false):
			_search_status_label.text = "DNA search failed: %s" % resp.get("error", "error")
			return {"ok": false, "truncated": false}
		for hit_any in resp.get("hits", []):
			var hit: Dictionary = hit_any
			_search_hits.append({
				"kind": "dna",
				"chr_id": chr_id,
				"chr_name": chr_name,
				"start": int(hit.get("start", 0)),
				"end": int(hit.get("end", 0)),
				"label": pattern,
				"strand": str(hit.get("strand", "+"))
			})
			if _search_hits.size() >= SEARCH_MAX_HITS:
				return {"ok": true, "truncated": true}
		if bool(resp.get("truncated", false)):
			truncated = true
			return {"ok": true, "truncated": truncated}
		await (Engine.get_main_loop() as SceneTree).process_frame
	return {"ok": true, "truncated": truncated}

func _search_comparison_dna_exact(pattern: String, include_revcomp: bool) -> Dictionary:
	var zem = _call0("get_zem")
	var truncated := false
	var genomes := _comparison_genomes_for_scope()
	if genomes.is_empty():
		_search_status_label.text = "No comparison genomes loaded."
		return {"ok": false, "truncated": false}
	for genome_any in genomes:
		var genome: Dictionary = genome_any
		var genome_id := int(genome.get("id", -1))
		var genome_name := str(genome.get("name", "genome"))
		var remaining_hits := maxi(1, SEARCH_MAX_HITS - _search_hits.size())
		var resp: Dictionary = zem.search_comparison_dna_exact(genome_id, pattern, include_revcomp, remaining_hits)
		if not resp.get("ok", false):
			_search_status_label.text = "DNA search failed: %s" % resp.get("error", "error")
			return {"ok": false, "truncated": false}
		for hit_any in resp.get("hits", []):
			var hit: Dictionary = hit_any
			var start_bp := int(hit.get("start", 0))
			var end_bp := int(hit.get("end", 0))
			var local_range := _comparison_contig_range_for_interval(genome, start_bp, end_bp)
			_search_hits.append({
				"context": "comparison",
				"kind": "dna",
				"genome_id": genome_id,
				"genome_name": genome_name,
				"chr_name": str(local_range.get("contig_name", genome_name)),
				"start": start_bp,
				"end": end_bp,
				"display_start": int(local_range.get("start", start_bp)) + 1,
				"display_end": int(local_range.get("end", end_bp)),
				"label": pattern,
				"strand": str(hit.get("strand", "+"))
			})
			if _search_hits.size() >= SEARCH_MAX_HITS:
				return {"ok": true, "truncated": true}
		if bool(resp.get("truncated", false)):
			truncated = true
			return {"ok": true, "truncated": truncated}
		await (Engine.get_main_loop() as SceneTree).process_frame
	return {"ok": true, "truncated": truncated}

func _revcomp_dna(seq: String) -> String:
	var s := seq.to_upper()
	var chars: Array[String] = []
	chars.resize(s.length())
	for i in range(s.length()):
		var c := s.substr(i, 1)
		match c:
			"A":
				chars[s.length() - 1 - i] = "T"
			"T":
				chars[s.length() - 1 - i] = "A"
			"C":
				chars[s.length() - 1 - i] = "G"
			"G":
				chars[s.length() - 1 - i] = "C"
			_:
				return ""
	return "".join(chars)

func _populate_search_results() -> void:
	_search_results_list.clear()
	for hit in _search_hits:
		var strand_tag := ""
		if hit.has("strand"):
			strand_tag = " (%s)" % str(hit.get("strand", ""))
		var text := ""
		if str(hit.get("context", "")) == "comparison":
			text = "%s / %s:%d-%d  %s" % [
				str(hit.get("genome_name", "genome")),
				str(hit.get("chr_name", "contig")),
				int(hit.get("display_start", int(hit.get("start", 0)) + 1)),
				int(hit.get("display_end", int(hit.get("end", 0)))),
				"%s%s" % [str(hit.get("label", "match")), strand_tag]
			]
		else:
			text = "%s:%d-%d  %s" % [
				str(hit.get("chr_name", "chr")),
				int(hit.get("start", 0)) + 1,
				int(hit.get("end", 0)),
				"%s%s" % [str(hit.get("label", "match")), strand_tag]
			]
		_search_results_list.add_item(text)

func _on_search_result_selected(index: int) -> void:
	if index < 0 or index >= _search_hits.size():
		return
	var callback: Callable = _callbacks.get("on_hit_selected", Callable())
	if callback.is_valid():
		callback.call(_search_hits[index])

func _call0(name: String):
	var callback: Callable = _callbacks.get(name, Callable())
	if callback.is_valid():
		return callback.call()
	return null

func _is_comparison_mode() -> bool:
	var callback: Callable = _callbacks.get("get_app_mode", Callable())
	if callback.is_valid():
		return int(callback.call()) == 1
	return false

func _refresh_scope_options() -> void:
	if _search_scope_option == null:
		return
	var previous_single_scope := _single_scope_value()
	var previous_comparison_genome_id := _comparison_selected_genome_id()
	_search_scope_option.clear()
	if _is_comparison_mode():
		if _scope_label != null:
			_scope_label.text = "Genome"
		_search_scope_option.add_item("All genomes")
		_search_scope_option.set_item_metadata(0, {"all_genomes": true, "genome_id": -1})
		var select_idx := 0
		var genomes: Array[Dictionary] = _call0("get_comparison_genomes")
		for genome_any in genomes:
			var genome: Dictionary = genome_any
			var idx := _search_scope_option.item_count
			_search_scope_option.add_item(str(genome.get("name", "genome")))
			_search_scope_option.set_item_metadata(idx, {"genome_id": int(genome.get("id", -1))})
			if int(genome.get("id", -1)) == previous_comparison_genome_id:
				select_idx = idx
		_search_scope_option.select(select_idx)
	else:
		if _scope_label != null:
			_scope_label.text = "Scope"
		_search_scope_option.add_item("Current sequence")
		_search_scope_option.set_item_metadata(0, {"single_scope": SEARCH_SCOPE_CURRENT})
		_search_scope_option.add_item("All sequences")
		_search_scope_option.set_item_metadata(1, {"single_scope": SEARCH_SCOPE_ALL})
		_search_scope_option.select(clampi(previous_single_scope, SEARCH_SCOPE_CURRENT, SEARCH_SCOPE_ALL))

func _comparison_contig_range_for_interval(genome: Dictionary, start_bp: int, end_bp: int) -> Dictionary:
	var segments: Array = genome.get("segments", [])
	var best: Dictionary = {}
	var best_overlap := -1
	var midpoint := int(floor(0.5 * float(start_bp + end_bp)))
	for seg_any in segments:
		var seg: Dictionary = seg_any
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", seg_start))
		var overlap: int = min(end_bp, seg_end) - max(start_bp, seg_start)
		if overlap > best_overlap:
			best_overlap = overlap
			best = seg
		elif overlap == best_overlap and best_overlap <= 0 and midpoint >= seg_start and midpoint < seg_end:
			best = seg
	if best.is_empty():
		return {"contig_name": str(genome.get("name", "genome")), "start": start_bp, "end": end_bp}
	var contig_start := int(best.get("start", 0))
	var contig_end := int(best.get("end", contig_start))
	return {
		"contig_name": str(best.get("name", genome.get("name", "genome"))),
		"start": clampi(start_bp - contig_start, 0, maxi(0, contig_end - contig_start)),
		"end": clampi(end_bp - contig_start, 0, maxi(0, contig_end - contig_start))
	}
