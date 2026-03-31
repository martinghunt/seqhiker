extends RefCounted
class_name ComparisonController

var host: Node = null
var zem: RefCounted = null
var themes_lib: RefCounted = null
var comparison_view: Control = null

var _comparison_genomes: Array[Dictionary] = []
var _comparison_pair_cache := {}
var _comparison_detail_cache := {}
var _comparison_reference_cache := {}
var _comparison_block_cap_label: Label
var _comparison_block_cap_spin: SpinBox
var _min_block_len_label: Label
var _min_block_len_spin: SpinBox
var _max_block_len_label: Label
var _max_block_len_spin: SpinBox
var _min_identity_label: Label
var _min_identity_spin: SpinBox
var _max_identity_label: Label
var _max_identity_spin: SpinBox
var _generate_test_genomes_button: Button


func configure(next_host: Node, next_zem: RefCounted, next_themes_lib: RefCounted, next_view: Control) -> void:
	host = next_host
	zem = next_zem
	themes_lib = next_themes_lib
	comparison_view = next_view


func setup() -> void:
	if comparison_view == null:
		return
	comparison_view.visible = false
	if comparison_view.has_signal("genome_order_changed") and not comparison_view.genome_order_changed.is_connected(_on_comparison_genome_order_changed):
		comparison_view.genome_order_changed.connect(_on_comparison_genome_order_changed)
	if comparison_view.has_signal("comparison_match_selected") and not comparison_view.comparison_match_selected.is_connected(_on_comparison_match_selected):
		comparison_view.comparison_match_selected.connect(_on_comparison_match_selected)
	if comparison_view.has_signal("comparison_match_cleared") and not comparison_view.comparison_match_cleared.is_connected(_on_comparison_match_cleared):
		comparison_view.comparison_match_cleared.connect(_on_comparison_match_cleared)
	if comparison_view.has_signal("detail_requested") and not comparison_view.detail_requested.is_connected(_on_detail_requested):
		comparison_view.detail_requested.connect(_on_detail_requested)

func has_genomes() -> bool:
	return not _comparison_genomes.is_empty()


func setup_settings(view_box: VBoxContainer) -> void:
	if view_box == null:
		return
	_comparison_block_cap_label = Label.new()
	_comparison_block_cap_label.text = "Max Comparison Blocks On Screen"
	_comparison_block_cap_spin = SpinBox.new()
	_comparison_block_cap_spin.min_value = 10
	_comparison_block_cap_spin.max_value = 5000
	_comparison_block_cap_spin.step = 10
	_comparison_block_cap_spin.value = 500
	_comparison_block_cap_spin.value_changed.connect(_on_comparison_block_cap_changed)

	_min_block_len_label = Label.new()
	_min_block_len_label.text = "Minimum Match Length (bp)"
	_min_block_len_spin = SpinBox.new()
	_min_block_len_spin.min_value = 0
	_min_block_len_spin.max_value = 25000000
	_min_block_len_spin.step = 1
	_min_block_len_spin.value = 0
	_min_block_len_spin.value_changed.connect(_on_comparison_filters_changed)

	_max_block_len_label = Label.new()
	_max_block_len_label.text = "Maximum Match Length (bp, 0 = no max)"
	_max_block_len_spin = SpinBox.new()
	_max_block_len_spin.min_value = 0
	_max_block_len_spin.max_value = 25000000
	_max_block_len_spin.step = 1
	_max_block_len_spin.value = 0
	_max_block_len_spin.value_changed.connect(_on_comparison_filters_changed)

	_min_identity_label = Label.new()
	_min_identity_label.text = "Minimum % Identity"
	_min_identity_spin = SpinBox.new()
	_min_identity_spin.min_value = 0.0
	_min_identity_spin.max_value = 100.0
	_min_identity_spin.step = 0.1
	_min_identity_spin.value = 0.0
	_min_identity_spin.value_changed.connect(_on_comparison_filters_changed)

	_max_identity_label = Label.new()
	_max_identity_label.text = "Maximum % Identity"
	_max_identity_spin = SpinBox.new()
	_max_identity_spin.min_value = 0.0
	_max_identity_spin.max_value = 100.0
	_max_identity_spin.step = 0.1
	_max_identity_spin.value = 100.0
	_max_identity_spin.value_changed.connect(_on_comparison_filters_changed)

	_generate_test_genomes_button = Button.new()
	_generate_test_genomes_button.text = "Use comparison test genomes"
	_generate_test_genomes_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_test_genomes_button.pressed.connect(func() -> void:
		host._start_generate_comparison_test_data()
	)

	view_box.add_child(_comparison_block_cap_label)
	view_box.add_child(_comparison_block_cap_spin)
	view_box.add_child(_min_block_len_label)
	view_box.add_child(_min_block_len_spin)
	view_box.add_child(_max_block_len_label)
	view_box.add_child(_max_block_len_spin)
	view_box.add_child(_min_identity_label)
	view_box.add_child(_min_identity_spin)
	view_box.add_child(_max_identity_label)
	view_box.add_child(_max_identity_spin)
	view_box.add_child(_generate_test_genomes_button)
	refresh_settings(int(host._app_mode))
	_on_comparison_block_cap_changed(_comparison_block_cap_spin.value)
	_on_comparison_filters_changed(0.0)


func refresh_settings(app_mode: int) -> void:
	var visible: bool = app_mode == host.APP_MODE_COMPARISON
	if _comparison_block_cap_label != null:
		_comparison_block_cap_label.visible = visible
	if _comparison_block_cap_spin != null:
		_comparison_block_cap_spin.visible = visible
	for node in [_min_block_len_label, _min_block_len_spin, _max_block_len_label, _max_block_len_spin, _min_identity_label, _min_identity_spin, _max_identity_label, _max_identity_spin]:
		if node != null:
			node.visible = visible
	if _generate_test_genomes_button != null:
		_generate_test_genomes_button.visible = visible

func set_generate_test_genomes_enabled(enabled: bool) -> void:
	if _generate_test_genomes_button != null:
		_generate_test_genomes_button.disabled = not enabled


func ensure_seed_genome_loaded(loaded_file_paths: PackedStringArray) -> void:
	if not _comparison_genomes.is_empty():
		return
	if loaded_file_paths.is_empty():
		return
	for path_any in loaded_file_paths:
		var path := str(path_any)
		if path.is_empty():
			continue
		var inspect: Dictionary = host._inspect_dropped_files(PackedStringArray([path]))
		if bool(inspect.get("has_sequence", false)):
			add_genome(path)
			break


func refresh_view(theme_name: String) -> void:
	if comparison_view == null:
		return
	var palette: Dictionary = themes_lib.palette(theme_name)
	if comparison_view.has_method("set_theme_colors"):
		comparison_view.set_theme_colors({
			"text": palette.get("text", Color.BLACK),
			"text_muted": palette.get("text_muted", Color("666666")),
			"border": palette.get("border", Color("aaaaaa")),
			"panel_alt": palette.get("panel_alt", Color("efefef")),
			"genome": palette.get("genome", Color("3f5a7a")),
			"map_contig": palette.get("map_contig", Color("ffffff")),
			"map_contig_alt": palette.get("map_contig_alt", Color("efefef")),
			"map_view_fill": palette.get("map_view_fill", Color("3f5a7a")),
			"map_view_outline": palette.get("map_view_outline", palette.get("text", Color.BLACK)),
			"feature": palette.get("feature", Color("dce8f7")),
			"feature_text": palette.get("feature_text", Color("1e3557")),
			"same_strand": palette.get("comparison_same_strand", Color("cb4934")),
			"opp_strand": palette.get("comparison_opp_strand", Color("2c7fb8")),
			"selection_outline": palette.get("text", Color.BLACK),
			"snp": palette.get("snp", Color("f59e0b"))
		})
	if comparison_view.has_method("set_genomes"):
		comparison_view.set_genomes(_comparison_genomes)
	var order := PackedInt32Array()
	if comparison_view.has_method("get_order"):
		order = comparison_view.get_order()
	if order.is_empty():
		for genome in _comparison_genomes:
			order.append(int(genome.get("id", -1)))
	for i in range(order.size() - 1):
		_ensure_pair_blocks(int(order[i]), int(order[i + 1]))


func reset_view_to_full_genomes() -> void:
	if comparison_view != null and comparison_view.has_method("reset_view_to_full_genomes"):
		comparison_view.reset_view_to_full_genomes()


func add_genome(path: String) -> bool:
	var resp: Dictionary = zem.add_comparison_genome(path)
	return _apply_added_comparison_genome_response(resp)

func add_genome_files(paths: PackedStringArray) -> bool:
	var resp: Dictionary = zem.add_comparison_genome_files(paths)
	return _apply_added_comparison_genome_response(resp)

func _apply_added_comparison_genome_response(resp: Dictionary) -> bool:
	if not bool(resp.get("ok", false)):
		host._set_status("Comparison load failed: %s" % str(resp.get("error", "error")), true)
		return false
	var added_genome: Dictionary = resp.get("genome", {})
	var added_id := int(added_genome.get("id", -1))
	var genome: Dictionary = added_genome
	var genomes_resp: Dictionary = zem.list_comparison_genomes()
	if bool(genomes_resp.get("ok", false)):
		for genome_any in genomes_resp.get("genomes", []):
			var listed: Dictionary = genome_any
			if int(listed.get("id", -1)) == added_id:
				genome = listed
				break
	var feature_resp: Dictionary = zem.get_comparison_annotations(int(genome.get("id", -1)), 0, int(genome.get("length", 0)), 50000, 1)
	genome["features"] = feature_resp.get("features", []) if bool(feature_resp.get("ok", false)) else []
	var found := false
	for i in range(_comparison_genomes.size()):
		if int(_comparison_genomes[i].get("id", -1)) == int(genome.get("id", -1)):
			_comparison_genomes[i] = genome
			found = true
			break
	if not found:
		_comparison_genomes.append(genome)
	return true

func save_session(path: String) -> bool:
	var resp: Dictionary = zem.save_comparison_session(path)
	if not bool(resp.get("ok", false)):
		host._set_status("Comparison save failed: %s" % str(resp.get("error", "error")), true)
		return false
	host._set_status("Saved comparison session: %s" % path)
	return true

func load_session(path: String) -> bool:
	var resp: Dictionary = zem.load_comparison_session(path)
	if not bool(resp.get("ok", false)):
		host._set_status("Comparison load failed: %s" % str(resp.get("error", "error")), true)
		return false
	_comparison_pair_cache.clear()
	_comparison_detail_cache.clear()
	_comparison_reference_cache.clear()
	_comparison_genomes.clear()
	if comparison_view != null and comparison_view.has_method("clear_view"):
		comparison_view.clear_view()
	var genomes_resp: Dictionary = zem.list_comparison_genomes()
	if not bool(genomes_resp.get("ok", false)):
		host._set_status("Comparison load failed: could not list genomes", true)
		return false
	for genome_any in genomes_resp.get("genomes", []):
		var genome: Dictionary = genome_any
		var feature_resp: Dictionary = zem.get_comparison_annotations(int(genome.get("id", -1)), 0, int(genome.get("length", 0)), 50000, 1)
		genome["features"] = feature_resp.get("features", []) if bool(feature_resp.get("ok", false)) else []
		_comparison_genomes.append(genome)
	refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
	reset_view_to_full_genomes()
	host._set_status("Loaded comparison session: %s" % path)
	return true

func clear_state() -> bool:
	var resp: Dictionary = zem.reset_comparison_state()
	if not bool(resp.get("ok", false)):
		host._set_status("Comparison reset failed: %s" % str(resp.get("error", "error")), true)
		return false
	_comparison_pair_cache.clear()
	_comparison_detail_cache.clear()
	_comparison_reference_cache.clear()
	_comparison_genomes.clear()
	if comparison_view != null and comparison_view.has_method("clear_view"):
		comparison_view.clear_view()
	return true

func load_generated_genomes(paths: PackedStringArray) -> bool:
	if not clear_state():
		return false
	for path_any in paths:
		if not add_genome(str(path_any)):
			return false
	refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
	reset_view_to_full_genomes()
	return true


func handle_files_dropped(files: PackedStringArray) -> void:
	var drop_info: Dictionary = host._inspect_dropped_files(files)
	if bool(drop_info.get("ok", false)) and bool(drop_info.get("has_sequence", false)) and int(drop_info.get("sequence_root_count", 0)) == 1 and files.size() > 1:
		if add_genome_files(files):
			refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
			if _comparison_genomes.size() == 1:
				reset_view_to_full_genomes()
		return
	var added_any := false
	for file_any in files:
		var path := str(file_any)
		if path.is_empty():
			continue
		var inspect: Dictionary = host._inspect_dropped_files(PackedStringArray([path]))
		if not bool(inspect.get("has_sequence", false)):
			continue
		if add_genome(path):
			added_any = true
	refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
	if added_any and _comparison_genomes.size() == 1:
		reset_view_to_full_genomes()


func _ensure_pair_blocks(query_genome_id: int, target_genome_id: int) -> void:
	if comparison_view != null and comparison_view.has_method("pair_cached") and comparison_view.pair_cached(query_genome_id, target_genome_id):
		return
	var key := "%d:%d" % [mini(query_genome_id, target_genome_id), maxi(query_genome_id, target_genome_id)]
	if _comparison_pair_cache.has(key):
		var cached: Dictionary = _comparison_pair_cache[key]
		var cached_blocks: Array = cached.get("blocks", [])
		if not cached_blocks.is_empty():
			comparison_view.set_pair_blocks(int(cached.get("query_id", query_genome_id)), int(cached.get("target_id", target_genome_id)), cached_blocks)
			return
		_comparison_pair_cache.erase(key)
	var resp: Dictionary = zem.get_comparison_blocks_by_genomes(query_genome_id, target_genome_id)
	if not bool(resp.get("ok", false)):
		host._set_status("Comparison query failed: %s" % str(resp.get("error", "error")), true)
		return
	var blocks: Array = resp.get("blocks", [])
	if blocks.is_empty():
		var pairs_resp: Dictionary = zem.list_comparison_pairs()
		if bool(pairs_resp.get("ok", false)):
			for pair_any in pairs_resp.get("pairs", []):
				var pair: Dictionary = pair_any
				var top_id := int(pair.get("top_genome_id", -1))
				var bottom_id := int(pair.get("bottom_genome_id", -1))
				if (top_id == query_genome_id and bottom_id == target_genome_id) or (top_id == target_genome_id and bottom_id == query_genome_id):
					var pair_blocks_resp: Dictionary = zem.get_comparison_blocks(int(pair.get("id", -1)))
					if bool(pair_blocks_resp.get("ok", false)):
						blocks = pair_blocks_resp.get("blocks", [])
					break
	var payload := {
		"query_id": query_genome_id,
		"target_id": target_genome_id,
		"blocks": blocks
	}
	if not blocks.is_empty():
		_comparison_pair_cache[key] = payload
	if comparison_view != null:
		comparison_view.set_pair_blocks(query_genome_id, target_genome_id, blocks)


func _on_comparison_genome_order_changed(order: PackedInt32Array) -> void:
	for i in range(order.size() - 1):
		_ensure_pair_blocks(int(order[i]), int(order[i + 1]))


func _on_comparison_block_cap_changed(value: float) -> void:
	if comparison_view != null and comparison_view.has_method("set_max_draw_blocks_per_pair"):
		comparison_view.set_max_draw_blocks_per_pair(int(value))

func _on_comparison_filters_changed(_value: float) -> void:
	if comparison_view == null or not comparison_view.has_method("set_block_filters"):
		return
	comparison_view.set_block_filters(
		int(_min_block_len_spin.value) if _min_block_len_spin != null else 0,
		int(_max_block_len_spin.value) if _max_block_len_spin != null else 0,
		float(_min_identity_spin.value) if _min_identity_spin != null else 0.0,
		float(_max_identity_spin.value) if _max_identity_spin != null else 100.0
	)


func _on_comparison_match_selected(match: Dictionary, was_double_click: bool) -> void:
	if host != null and host.has_method("_on_comparison_match_selected"):
		host._on_comparison_match_selected(match, was_double_click)


func _on_comparison_match_cleared() -> void:
	if host != null and host.has_method("_on_comparison_match_cleared"):
		host._on_comparison_match_cleared()


func _on_detail_requested(request: Dictionary) -> void:
	if comparison_view == null:
		return
	for genome_any in request.get("genomes", []):
		var genome_req: Dictionary = genome_any
		var genome_id := int(genome_req.get("genome_id", -1))
		if genome_id < 0:
			continue
		var start_bp := int(genome_req.get("start_bp", 0))
		var end_bp := int(genome_req.get("end_bp", 0))
		var slice_data: Dictionary = _reference_slice_for_window(genome_id, start_bp, end_bp)
		if slice_data.is_empty():
			continue
		comparison_view.set_reference_slice(genome_id, slice_data)
	for block_any in request.get("blocks", []):
		var block_req: Dictionary = block_any
		var query_genome_id := int(block_req.get("query_genome_id", -1))
		var target_genome_id := int(block_req.get("target_genome_id", -1))
		var block: Dictionary = block_req.get("block", {})
		if query_genome_id < 0 or target_genome_id < 0 or block.is_empty():
			continue
		var cache_key := "%d:%d:%d:%d:%d:%d:%d" % [
			query_genome_id,
			target_genome_id,
			int(block.get("query_start", 0)),
			int(block.get("query_end", 0)),
			int(block.get("target_start", 0)),
			int(block.get("target_end", 0)),
			1 if bool(block.get("same_strand", true)) else 0
		]
		var detail: Dictionary = _comparison_detail_cache.get(cache_key, {})
		if detail.is_empty():
			var detail_resp: Dictionary = zem.get_comparison_block_detail(query_genome_id, target_genome_id, block)
			if not bool(detail_resp.get("ok", false)):
				continue
			detail = detail_resp.get("detail", {})
			_comparison_detail_cache[cache_key] = detail
		comparison_view.set_block_detail(query_genome_id, target_genome_id, block, detail)


func _reference_slice_for_window(genome_id: int, start_bp: int, end_bp: int) -> Dictionary:
	var cached: Dictionary = _comparison_reference_cache.get(genome_id, {})
	if not cached.is_empty():
		var cached_start := int(cached.get("slice_start", 0))
		var cached_end := int(cached.get("slice_end", cached_start + str(cached.get("sequence", "")).length()))
		if start_bp >= cached_start and end_bp <= cached_end:
			return cached
	var genome_len := 0
	for genome in _comparison_genomes:
		if int(genome.get("id", -1)) == genome_id:
			genome_len = int(genome.get("length", 0))
			break
	if genome_len <= 0:
		return {}
	var span := maxi(1, end_bp - start_bp)
	var pad := maxi(200, span)
	var fetch_start := maxi(0, start_bp - pad)
	var fetch_end := mini(genome_len, end_bp + pad)
	var slice_resp: Dictionary = zem.get_comparison_reference_slice(genome_id, fetch_start, fetch_end)
	if not bool(slice_resp.get("ok", false)):
		return {}
	var slice_data: Dictionary = slice_resp.get("slice", {})
	_comparison_reference_cache[genome_id] = slice_data
	return slice_data
