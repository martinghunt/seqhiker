extends RefCounted
class_name SessionLoader

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func on_files_dropped(files: PackedStringArray) -> void:
	_load_paths(files)


func load_server_paths(files: PackedStringArray) -> Dictionary:
	return _load_paths(files)

func apply_already_loaded_genome(files: PackedStringArray) -> void:
	host._reset_loaded_state()
	record_loaded_files(files, true)
	host.genome_view.load_files(files)
	refresh_sequence_loaded_state()
	refresh_chromosomes(true)
	host._refresh_visible_data()


func _load_paths(files: PackedStringArray) -> Dictionary:
	if not ensure_server_connected():
		return {"ok": false, "error": str(host._last_status_message)}
	var drop_info: Dictionary = inspect_dropped_files(files)
	if not drop_info.get("ok", false):
		var err_msg := str(drop_info.get("error", "Unable to inspect dropped files."))
		host._set_status(err_msg, true)
		return {"ok": false, "error": err_msg}
	var dropped_sequence := bool(drop_info.get("has_sequence", false))
	if int(drop_info.get("sequence_root_count", 0)) > 1:
		var err_msg := "Drop only one sequence-bearing genome source at a time."
		host._set_status(err_msg, true)
		return {"ok": false, "error": err_msg}
	if dropped_sequence:
		var embedded_only := int(drop_info.get("embedded_gff_sequence_root_count", 0)) == int(drop_info.get("sequence_root_count", 0))
		if not (host._has_sequence_loaded and embedded_only):
			host._reset_loaded_state()
	else:
		host._view_slots.clear()
	if not load_dropped_files(files):
		return {"ok": false, "error": str(host._last_status_message)}
	record_loaded_files(files, dropped_sequence)
	host.genome_view.load_files(files)
	refresh_sequence_loaded_state()
	refresh_chromosomes(dropped_sequence)
	host._refresh_visible_data()
	if host._annotation_cache_controller.detailed_read_strips_enabled(host._last_bp_per_px):
		host._annotation_cache_controller.update_detailed_read_strips(host._last_start, host._last_end, host._last_bp_per_px)
	return {"ok": true}


func ensure_server_connected() -> bool:
	if host._zem.ensure_connected():
		refresh_sequence_loaded_state()
		host._set_status("Connected")
		return true
	var host_ip: String = "127.0.0.1"
	var port: int = host.ZEM_DEFAULT_PORT
	if host._local_zem_manager.connect_with_local_fallback(host_ip, port):
		refresh_sequence_loaded_state()
		host._set_status("Connected %s:%d" % [host_ip, port])
		return true
	var msg: String = "Disconnected"
	var last_error: String = host._local_zem_manager.last_error()
	if not last_error.is_empty():
		msg = last_error
	host._set_status(msg, true)
	return false


func refresh_sequence_loaded_state() -> void:
	var resp: Dictionary = host._zem.get_load_state()
	if resp.get("ok", false):
		host._has_sequence_loaded = bool(resp.get("has_sequence", false))


func inspect_dropped_files(files: PackedStringArray) -> Dictionary:
	var sequence_root_count := 0
	var embedded_gff_sequence_root_count := 0
	for path in files:
		if path.get_extension().to_lower() == "bam":
			continue
		var resp: Dictionary = host._zem.inspect_input(path)
		if not resp.get("ok", false):
			return {"ok": false, "error": "Inspect input failed: %s" % resp.get("error", "error")}
		if bool(resp.get("has_sequence", false)):
			sequence_root_count += 1
			if bool(resp.get("has_embedded_gff3_sequence", false)):
				embedded_gff_sequence_root_count += 1
	return {
		"ok": true,
		"has_sequence": sequence_root_count > 0,
		"sequence_root_count": sequence_root_count,
		"embedded_gff_sequence_root_count": embedded_gff_sequence_root_count
	}


func load_dropped_files(files: PackedStringArray) -> bool:
	var genome_targets: Array[String] = []
	var bam_targets: Array[String] = []
	for path in files:
		var ext: String = path.get_extension().to_lower()
		if ext == "bam":
			bam_targets.append(path)
		elif genome_targets.find(path) < 0:
			genome_targets.append(path)
	var pending: Array[String] = genome_targets.duplicate()
	while not pending.is_empty():
		var deferred: Array[String] = []
		var progress := false
		for target in pending:
			var resp: Dictionary = host._zem.load_genome(target)
			if resp.get("ok", false):
				progress = true
				continue
			var err_msg := str(resp.get("error", "error"))
			if err_msg.contains("no reference sequence loaded"):
				deferred.append(target)
				continue
			host._set_status("Load genome failed: %s" % err_msg, true)
			return false
		if deferred.is_empty():
			break
		if not progress:
			host._set_status("Load genome failed: no reference sequence loaded; load a sequence file first.", true)
			return false
		pending = deferred

	host.genome_view.set_read_loading_message("Loading BAMs...")
	for bam_path in bam_targets:
		var source_id: int = host._existing_bam_source_id(bam_path)
		if source_id <= 0:
			var cutoff_bp: int = host._bam_cov_precompute_cutoff_bp
			if cutoff_bp > 0:
				host.genome_view.set_read_loading_message("Loading %s and precomputing depth..." % bam_path.get_file())
			else:
				host.genome_view.set_read_loading_message("Loading %s..." % bam_path.get_file())
			var bam_resp: Dictionary = host._zem.load_bam(bam_path, cutoff_bp)
			if not bam_resp.get("ok", false):
				host.genome_view.set_read_loading_message("")
				host._set_status("Load BAM failed: %s" % bam_resp.get("error", "error"), true)
				return false
			source_id = int(bam_resp.get("source_id", 0))
		host._bam_track_serial += 1
		var label: String = bam_path.get_file()
		var track_id: String = "reads:%d" % host._bam_track_serial
		host._bam_tracks.append({
			"source_id": source_id,
			"path": bam_path,
			"label": label,
			"track_id": track_id,
			"view_mode": 0,
			"fragment_log": true,
			"thickness": host.DEFAULT_READ_THICKNESS,
			"max_rows": host.DEFAULT_READ_MAX_ROWS,
			"min_mapq": host.DEFAULT_READ_MIN_MAPQ,
			"hidden_flags": host.DEFAULT_READ_HIDDEN_FLAGS,
			"hide_improper_pair": false,
			"hide_forward_strand": false,
			"hide_mate_forward_strand": false,
			"auto_expand_snp_text": true,
			"color_by_mate_contig": false
		})
		host._has_bam_loaded = true
		host.center_strand_scroll_pending = true
		host._sync_bam_read_tracks()
		host.genome_view.set_track_visible(track_id, true)
	host.genome_view.set_read_loading_message("")
	return true


func refresh_chromosomes(reset_viewport: bool = true) -> void:
	var resp: Dictionary = host._zem.get_chromosomes()
	if not resp.get("ok", false):
		host._set_status("Chrom query failed: %s" % resp.get("error", "error"), true)
		return
	var chroms_any: Array = resp.get("chromosomes", [])
	var chroms: Array[Dictionary] = []
	for c in chroms_any:
		if typeof(c) == TYPE_DICTIONARY:
			chroms.append(c)
	if chroms.is_empty():
		host._set_status("No chromosomes loaded", true)
		return
	host._chromosomes = chroms
	var counts_resp: Dictionary = host._zem.get_annotation_counts()
	if counts_resp.get("ok", false):
		host._annotation_counts_by_chr = counts_resp.get("counts", {})
	else:
		host._annotation_counts_by_chr = {}
		host._set_status("Annotation preload disabled: counts unavailable (restart zem)", true)
	rebuild_concat_segments()
	refresh_sequence_options()
	if host._go_controller != null:
		host._go_controller.refresh_context()
	apply_sequence_view(reset_viewport)


func rebuild_concat_segments() -> void:
	host._concat_segments.clear()
	var pos := 0
	for i in range(host._chromosomes.size()):
		var c: Dictionary = host._chromosomes[i]
		var seg_len: int = int(c.get("length", 0))
		var seg: Dictionary = {
			"id": int(c.get("id", -1)),
			"name": str(c.get("name", "chr")),
			"length": seg_len,
			"start": pos,
			"end": pos + seg_len
		}
		host._concat_segments.append(seg)
		pos += seg_len
		if i < host._chromosomes.size() - 1:
			pos += host._concat_gap_bp


func refresh_sequence_options() -> void:
	host._seq_option.clear()
	for c in host._chromosomes:
		host._seq_option.add_item(str(c.get("name", "chr")), int(c.get("id", -1)))
	if host._selected_seq_id < 0 and not host._selected_seq_name.is_empty():
		for c in host._chromosomes:
			if str(c.get("name", "")) == host._selected_seq_name:
				host._selected_seq_id = int(c.get("id", -1))
				break
	if host._selected_seq_id < 0 and host._chromosomes.size() > 0:
		host._selected_seq_id = int(host._chromosomes[0].get("id", -1))
	var found := false
	for i in range(host._seq_option.item_count):
		if host._seq_option.get_item_id(i) == host._selected_seq_id:
			host._seq_option.select(i)
			host._selected_seq_name = host._seq_option.get_item_text(i)
			found = true
			break
	if not found and host._seq_option.item_count > 0:
		host._seq_option.select(0)
		host._selected_seq_id = int(host._seq_option.get_item_id(0))
		host._selected_seq_name = host._seq_option.get_item_text(0)


func apply_sequence_view(reset_viewport: bool) -> void:
	if host._seq_view_mode == host.SEQ_VIEW_SINGLE:
		var selected: Dictionary = {}
		for c in host._chromosomes:
			if int(c.get("id", -1)) == host._selected_seq_id:
				selected = c
				break
		if selected.is_empty() and host._chromosomes.size() > 0:
			selected = host._chromosomes[0]
			host._selected_seq_id = int(selected.get("id", -1))
		host._current_chr_id = int(selected.get("id", -1))
		host._current_chr_name = str(selected.get("name", "chr"))
		host._selected_seq_name = host._current_chr_name
		host._current_chr_len = int(selected.get("length", 0))
		host._set_status("Loaded %s (%d bp)" % [host._current_chr_name, host._current_chr_len])
	else:
		host._current_chr_id = -2
		var total := 0
		if host._concat_segments.size() > 0:
			total = int(host._concat_segments[host._concat_segments.size() - 1].get("end", 0))
		host._current_chr_name = "concat"
		host._current_chr_len = total
		host._set_status("Loaded concat (%d seqs, %d bp)" % [host._concat_segments.size(), host._current_chr_len])
	if reset_viewport:
		host.genome_view.set_chromosome(host._current_chr_name, host._current_chr_len)
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT:
		host.genome_view.set_concat_segments(host._concat_segments)
	else:
		host.genome_view.set_concat_segments([])
	host._invalidate_cache()


func record_loaded_files(files: PackedStringArray, replace_existing: bool) -> void:
	if replace_existing:
		host._loaded_file_paths = PackedStringArray()
	for path in files:
		if not host._loaded_file_paths.has(path):
			host._loaded_file_paths.append(path)
	host._update_loaded_files_debug_label()


func reset_loaded_state() -> void:
	host._loaded_file_paths = PackedStringArray()
	host._update_loaded_files_debug_label()
	host._view_slots.clear()
	host._current_chr_id = -1
	host._current_chr_name = ""
	host._current_chr_len = 0
	host._cache_start = -1
	host._cache_end = -1
	host._invalidate_cache()
