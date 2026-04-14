extends RefCounted
class_name GoController

const GoPanelScene = preload("res://scenes/GoPanel.tscn")

const APP_MODE_BROWSER := 0
const APP_MODE_COMPARISON := 1

var _callbacks: Dictionary = {}
var _go_panel: VBoxContainer
var _go_genome_label: Label
var _go_genome_option: OptionButton
var _go_chr_label: Label
var _go_chr_option: OptionButton
var _go_start_edit: LineEdit
var _go_end_edit: LineEdit
var _go_status_label: Label


func setup(feature_content: VBoxContainer, callbacks: Dictionary) -> void:
	_callbacks = callbacks.duplicate()
	var panel := GoPanelScene.instantiate()
	_go_panel = panel as VBoxContainer
	if _go_panel == null:
		return
	feature_content.add_child(_go_panel)
	_go_panel.visible = false
	_go_genome_label = Label.new()
	_go_genome_label.text = "Genome"
	_go_genome_label.visible = false
	_go_genome_option = OptionButton.new()
	_go_genome_option.visible = false
	_go_panel.add_child(_go_genome_label)
	_go_panel.move_child(_go_genome_label, 0)
	_go_panel.add_child(_go_genome_option)
	_go_panel.move_child(_go_genome_option, 1)
	_go_chr_label = _go_panel.get_node("ChromosomeLabel") as Label
	_go_chr_option = _go_panel.get_node("ChromosomeOption") as OptionButton
	_go_start_edit = _go_panel.get_node("StartEdit") as LineEdit
	_go_end_edit = _go_panel.get_node("EndEdit") as LineEdit
	_go_status_label = _go_panel.get_node("StatusLabel") as Label
	var go_action_button := _go_panel.get_node("GoButton") as Button
	if go_action_button != null:
		go_action_button.pressed.connect(_apply_go_request)
	if _go_start_edit != null:
		_go_start_edit.text_submitted.connect(func(_text: String) -> void:
			_apply_go_request()
		)
	if _go_end_edit != null:
		_go_end_edit.text_submitted.connect(func(_text: String) -> void:
			_apply_go_request()
		)
	if _go_genome_option != null:
		_go_genome_option.item_selected.connect(func(_index: int) -> void:
			if _app_mode() == APP_MODE_COMPARISON:
				_refresh_comparison_contigs()
		)


func is_visible() -> bool:
	return _go_panel != null and _go_panel.visible


func show_panel() -> void:
	if _go_panel == null:
		return
	_go_panel.visible = true
	refresh_context()
	clear_status()


func hide_panel() -> void:
	if _go_panel != null:
		_go_panel.visible = false


func focus_start() -> void:
	if _go_start_edit != null:
		_go_start_edit.grab_focus()


func refresh_context() -> void:
	if _go_chr_option == null:
		return
	_go_chr_option.clear()
	if _app_mode() == APP_MODE_COMPARISON:
		_show_comparison_controls()
		_refresh_comparison_contigs()
		return
	_show_browser_controls()
	_refresh_browser_chromosomes()


func clear_status() -> void:
	if _go_status_label != null:
		_go_status_label.text = ""


func set_status(message: String, is_error: bool = false) -> void:
	if _go_status_label != null:
		_go_status_label.text = message
	if is_error:
		_call1("report_error_status", message)


func _show_comparison_controls() -> void:
	if _go_genome_label != null:
		_go_genome_label.visible = true
	if _go_genome_option != null:
		_go_genome_option.visible = true
		_go_genome_option.clear()
	if _go_chr_label != null:
		_go_chr_label.text = "Chromosome"
	for genome_any in _comparison_genomes():
		var genome: Dictionary = genome_any
		if _go_genome_option != null:
			_go_genome_option.add_item(str(genome.get("name", "genome")), int(genome.get("id", -1)))
	if _go_genome_option != null and _go_genome_option.item_count > 0:
		_go_genome_option.select(0)


func _show_browser_controls() -> void:
	if _go_genome_label != null:
		_go_genome_label.visible = false
	if _go_genome_option != null:
		_go_genome_option.visible = false
	if _go_chr_label != null:
		_go_chr_label.text = "Chromosome"


func _refresh_browser_chromosomes() -> void:
	var chromosomes := _chromosomes()
	for chr_any in chromosomes:
		var chromosome: Dictionary = chr_any
		_go_chr_option.add_item(_display_sequence_name(chromosome), int(chromosome.get("id", -1)))
	var target_id := int(_call0("get_browser_target_chr_id"))
	if target_id < 0 and not chromosomes.is_empty():
		target_id = int(chromosomes[0].get("id", -1))
	for i in range(_go_chr_option.item_count):
		if int(_go_chr_option.get_item_id(i)) == target_id:
			_go_chr_option.select(i)
			return
	if _go_chr_option.item_count > 0:
		_go_chr_option.select(0)


func _refresh_comparison_contigs() -> void:
	if _go_chr_option == null:
		return
	_go_chr_option.clear()
	var genome_id := int(_go_genome_option.get_selected_id()) if _go_genome_option != null and _go_genome_option.item_count > 0 else -1
	if genome_id < 0:
		return
	for genome_any in _comparison_genomes():
		var genome: Dictionary = genome_any
		if int(genome.get("id", -1)) != genome_id:
			continue
		for seg_any in genome.get("segments", []):
			var seg: Dictionary = seg_any
			_go_chr_option.add_item(_display_sequence_name(seg), int(seg.get("start", 0)))
			var idx := _go_chr_option.item_count - 1
			_go_chr_option.set_item_metadata(idx, seg)
		break
	if _go_chr_option.item_count > 0:
		_go_chr_option.select(0)


func _display_sequence_name(item: Dictionary) -> String:
	var name := str(item.get("name", "chr"))
	if bool(item.get("reversed", false)):
		return "%s [RC]" % name
	return name


func _apply_go_request() -> void:
	if _go_chr_option == null or _go_start_edit == null:
		return
	clear_status()
	if _app_mode() == APP_MODE_COMPARISON:
		_apply_comparison_go_request()
		return
	_apply_browser_go_request()


func _apply_comparison_go_request() -> void:
	var genomes := _comparison_genomes()
	if genomes.is_empty():
		set_status("No comparison genomes loaded.", true)
		return
	var genome_id := int(_go_genome_option.get_selected_id()) if _go_genome_option != null else -1
	var genome_name := ""
	var segment: Dictionary = {}
	for genome_any in genomes:
		var genome: Dictionary = genome_any
		if int(genome.get("id", -1)) != genome_id:
			continue
		genome_name = str(genome.get("name", "genome"))
		var seg_idx := _go_chr_option.selected if _go_chr_option != null else -1
		if seg_idx >= 0:
			var seg_meta = _go_chr_option.get_item_metadata(seg_idx)
			if typeof(seg_meta) == TYPE_DICTIONARY:
				segment = seg_meta
		break
	if segment.is_empty():
		set_status("Genome length unavailable.", true)
		return
	var seg_start := int(segment.get("start", 0))
	var seg_end := int(segment.get("end", seg_start))
	var seg_len := maxi(0, seg_end - seg_start)
	var seg_name := str(segment.get("name", "chr"))
	var start_display := _parse_bp(_go_start_edit.text)
	if start_display < 1:
		set_status("Enter a valid start position.", true)
		return
	var end_display := _parse_bp(_go_end_edit.text) if _go_end_edit != null else -1
	if start_display > seg_len:
		set_status("Start position beyond chromosome length.", true)
		return
	if end_display >= 0 and end_display < start_display:
		var swap := start_display
		start_display = end_display
		end_display = swap
	if end_display > seg_len:
		end_display = seg_len
	_call4("on_comparison_go_request", genome_id, segment, start_display, end_display)
	if end_display >= 0:
		set_status("%s / %s:%d-%d" % [genome_name, seg_name, start_display, end_display])
	else:
		set_status("%s / %s:%d" % [genome_name, seg_name, start_display])
	_call0("request_close_panel")


func _apply_browser_go_request() -> void:
	var chromosomes := _chromosomes()
	if chromosomes.is_empty():
		set_status("No chromosomes loaded.", true)
		return
	var chr_id := int(_go_chr_option.get_selected_id())
	var chr_len := 0
	var chr_name := ""
	for chr_any in chromosomes:
		var chromosome: Dictionary = chr_any
		if int(chromosome.get("id", -1)) == chr_id:
			chr_len = int(chromosome.get("length", 0))
			chr_name = str(chromosome.get("name", "chr"))
			break
	if chr_len <= 0:
		set_status("Chromosome length unavailable.", true)
		return
	var start_display := _parse_bp(_go_start_edit.text)
	if start_display < 1:
		set_status("Enter a valid start position.", true)
		return
	var end_display := _parse_bp(_go_end_edit.text) if _go_end_edit != null else -1
	if start_display > chr_len:
		set_status("Start position beyond chromosome length.", true)
		return
	if end_display >= 0 and end_display < start_display:
		var swap := start_display
		start_display = end_display
		end_display = swap
	if end_display > chr_len:
		end_display = chr_len
	_call3("on_browser_go_request", chr_id, start_display, end_display)
	if end_display >= 0:
		set_status("%s:%d-%d" % [chr_name, start_display, end_display])
	else:
		set_status("%s:%d" % [chr_name, start_display])
	_call0("request_close_panel")


func _parse_bp(text: String) -> int:
	var clean := text.strip_edges().replace(",", "").replace(" ", "")
	if clean.is_empty():
		return -1
	if not clean.is_valid_int():
		return -1
	var value := int(clean)
	if value < 1:
		return -1
	return value


func _app_mode() -> int:
	return int(_call0("get_app_mode"))


func _chromosomes() -> Array[Dictionary]:
	return _call0("get_chromosomes")


func _comparison_genomes() -> Array[Dictionary]:
	return _call0("get_comparison_genomes")


func _call0(name: String):
	var cb: Variant = _callbacks.get(name, Callable())
	if cb is Callable and (cb as Callable).is_valid():
		return (cb as Callable).call()
	return null


func _call1(name: String, a0):
	var cb: Variant = _callbacks.get(name, Callable())
	if cb is Callable and (cb as Callable).is_valid():
		return (cb as Callable).call(a0)
	return null


func _call3(name: String, a0, a1, a2):
	var cb: Variant = _callbacks.get(name, Callable())
	if cb is Callable and (cb as Callable).is_valid():
		return (cb as Callable).call(a0, a1, a2)
	return null


func _call4(name: String, a0, a1, a2, a3):
	var cb: Variant = _callbacks.get(name, Callable())
	if cb is Callable and (cb as Callable).is_valid():
		return (cb as Callable).call(a0, a1, a2, a3)
	return null
