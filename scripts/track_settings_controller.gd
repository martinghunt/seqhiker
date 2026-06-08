extends RefCounted
class_name TrackSettingsController

const SoundControllerScript = preload("res://scripts/sound_controller.gd")

var host: Node = null


func configure(next_host: Node) -> void:
	host = next_host


func setup(feature_content: VBoxContainer, read_panel_scene: PackedScene) -> void:
	if host == null:
		return
	host._track_settings_box = VBoxContainer.new()
	host._track_settings_box.visible = false
	feature_content.add_child(host._track_settings_box)
	host._read_track_settings_panel = read_panel_scene.instantiate() as VBoxContainer
	if host._read_track_settings_panel == null:
		return
	host._read_track_settings_panel.visible = false
	host._track_settings_box.add_child(host._read_track_settings_panel)
	_setup_read_track_settings_panel()


func show_track_settings(track_id: String) -> void:
	if host == null or host._track_settings_box == null:
		return
	if host._track_settings_open and host._active_track_settings_id == track_id and host._feature_panel_open:
		host._play_ui_sound(SoundControllerScript.SOUND_BLIP)
		host._close_feature_panel()
		return
	if host._track_settings_open and host._active_track_settings_id == host.TRACK_GENOME and track_id != host.TRACK_GENOME:
		host._save_config()
	host._play_ui_sound(SoundControllerScript.SOUND_BLIP)
	host._prepare_context_panel(host.CONTEXT_PANEL_TRACK_SETTINGS, "%s track settings" % host._track_label_for_id(track_id), false)
	host.feature_name_label.visible = true
	host.feature_name_label.text = ""
	_clear_track_settings_box()
	host._track_settings_box.visible = true
	host._track_settings_open = true
	host._active_track_settings_id = track_id
	if track_id.begins_with("reads:"):
		_populate_read_track_settings(track_id)
	elif track_id == host.TRACK_AA:
		_populate_annotation_track_settings()
	elif track_id == host.TRACK_VCF:
		if host._variant_controller != null:
			host._variant_controller.populate_track_settings(track_id, host._track_settings_box)
	elif track_id == host.TRACK_GENOME:
		_populate_genome_track_settings()
	elif track_id == host.TRACK_GC_PLOT:
		_populate_gc_plot_track_settings()
	elif track_id == host.TRACK_DEPTH_PLOT:
		_populate_depth_plot_track_settings()
	else:
		var info := Label.new()
		info.text = "No track-specific settings yet."
		host._track_settings_box.add_child(info)
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)


func _setup_read_track_settings_panel() -> void:
	var read_view_option := host._read_track_settings_panel.get_node("ReadViewOption") as OptionButton
	if read_view_option != null and read_view_option.item_count == 0:
		read_view_option.add_item("Stack", 0)
		read_view_option.add_item("Strand Stack", 1)
		read_view_option.add_item("Paired", 2)
		read_view_option.add_item("Fragment Size", 3)
	_connect_read_setting_signal(read_view_option, "item_selected", Callable(host, "_on_active_read_track_view_selected"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("FragmentLogScale") as CheckButton, "toggled", Callable(host, "_on_active_read_track_fragment_log_toggled"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("ReadThicknessSpin") as SpinBox, "value_changed", Callable(host, "_on_active_read_track_thickness_changed"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("AutoExpandSNPText") as CheckButton, "toggled", Callable(host, "_on_active_read_track_auto_expand_snp_toggled"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("ShowSoftClips") as CheckButton, "toggled", Callable(host, "_on_active_read_track_show_soft_clips_toggled"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("ShowPileupLogo") as CheckButton, "toggled", Callable(host, "_on_active_read_track_show_pileup_logo_toggled"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("MateContigColor") as CheckButton, "toggled", Callable(host, "_on_active_read_track_mate_contig_color_toggled"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("MaxRowsSpin") as SpinBox, "value_changed", Callable(host, "_on_active_read_track_max_rows_changed"))
	_connect_read_setting_signal(host._read_track_settings_panel.get_node("MapQSpin") as SpinBox, "value_changed", Callable(host, "_on_active_read_track_min_mapq_changed"))


func _connect_read_setting_signal(control: Object, signal_name: String, target: Callable) -> void:
	if control == null:
		return
	var sig: Signal = control.get(signal_name)
	if not sig.is_connected(target):
		sig.connect(target)


func _clear_track_settings_box() -> void:
	for child in host._track_settings_box.get_children():
		if child == host._read_track_settings_panel:
			child.visible = false
			_clear_read_dynamic_options()
			continue
		child.queue_free()


func _clear_read_dynamic_options() -> void:
	if host._read_track_settings_panel == null:
		return
	var dynamic_options := host._read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
	if dynamic_options == null:
		return
	for dynamic_child in dynamic_options.get_children():
		dynamic_child.queue_free()


func _populate_read_track_settings(track_id: String) -> void:
	var track_meta: Dictionary = host._bam_track_for_id(track_id)
	var bam_name := str(track_meta.get("label", track_meta.get("path", "BAM")))
	var bam_label := host._read_track_settings_panel.get_node("BAMLabel") as Label
	var view_option := host._read_track_settings_panel.get_node("ReadViewOption") as OptionButton
	var frag_cb := host._read_track_settings_panel.get_node("FragmentLogScale") as CheckButton
	var thickness_spin := host._read_track_settings_panel.get_node("ReadThicknessSpin") as SpinBox
	var auto_expand_snp_cb := host._read_track_settings_panel.get_node("AutoExpandSNPText") as CheckButton
	var show_soft_clips_cb := host._read_track_settings_panel.get_node("ShowSoftClips") as CheckButton
	var show_pileup_logo_cb := host._read_track_settings_panel.get_node("ShowPileupLogo") as CheckButton
	var mate_contig_color_cb := host._read_track_settings_panel.get_node("MateContigColor") as CheckButton
	var max_rows_spin := host._read_track_settings_panel.get_node("MaxRowsSpin") as SpinBox
	var mapq_spin := host._read_track_settings_panel.get_node("MapQSpin") as SpinBox
	var dynamic_options := host._read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
	host._read_track_settings_panel.visible = true
	if bam_label != null:
		bam_label.text = "BAM: %s" % bam_name
	if view_option != null:
		view_option.select(int(track_meta.get("view_mode", 0)))
	if frag_cb != null:
		frag_cb.button_pressed = bool(track_meta.get("fragment_log", true))
		frag_cb.visible = view_option != null and view_option.selected == 3
	if thickness_spin != null:
		thickness_spin.value = float(track_meta.get("thickness", host.DEFAULT_READ_THICKNESS))
	if auto_expand_snp_cb != null:
		auto_expand_snp_cb.button_pressed = bool(track_meta.get("auto_expand_snp_text", true))
	if show_soft_clips_cb != null:
		show_soft_clips_cb.button_pressed = bool(track_meta.get("show_soft_clips", false))
	if show_pileup_logo_cb != null:
		show_pileup_logo_cb.button_pressed = bool(track_meta.get("show_pileup_logo", false))
	if mate_contig_color_cb != null:
		mate_contig_color_cb.button_pressed = bool(track_meta.get("color_by_mate_contig", false))
	if max_rows_spin != null:
		max_rows_spin.value = float(int(track_meta.get("max_rows", host.DEFAULT_READ_MAX_ROWS)))
	if mapq_spin != null:
		mapq_spin.value = float(int(track_meta.get("min_mapq", host.DEFAULT_READ_MIN_MAPQ)))
	if dynamic_options == null:
		return
	for child in dynamic_options.get_children():
		child.queue_free()
	_add_read_filter_options(track_id, track_meta, dynamic_options)


func _add_read_filter_options(track_id: String, track_meta: Dictionary, dynamic_options: VBoxContainer) -> void:
	var hidden_flags := int(track_meta.get("hidden_flags", host.DEFAULT_READ_HIDDEN_FLAGS))
	for entry_any in host.READ_FILTER_FLAG_LABELS:
		var entry: Dictionary = entry_any
		var flag_bit := int(entry.get("bit", 0))
		var flag_cb := CheckBox.new()
		flag_cb.text = "Hide %s" % str(entry.get("label", ""))
		flag_cb.button_pressed = (hidden_flags & flag_bit) != 0
		flag_cb.toggled.connect(func(enabled: bool) -> void:
			host._play_toggle_sound(enabled)
			_set_read_track_hidden_flag(track_id, flag_bit, enabled)
			host._on_read_track_filter_changed()
		)
		dynamic_options.add_child(flag_cb)
		if flag_bit == 2:
			_add_read_filter_bool_option(dynamic_options, track_id, "hide_improper_pair", "Hide improper pair", bool(track_meta.get("hide_improper_pair", false)))
		elif flag_bit == 8:
			_add_read_filter_bool_option(dynamic_options, track_id, "hide_mate_forward_strand", "Hide mate forward strand", bool(track_meta.get("hide_mate_forward_strand", false)))
		elif flag_bit == 16:
			_add_read_filter_bool_option(dynamic_options, track_id, "hide_forward_strand", "Hide forward strand", bool(track_meta.get("hide_forward_strand", false)))


func _add_read_filter_bool_option(dynamic_options: VBoxContainer, track_id: String, key: String, label: String, current_value: bool) -> void:
	var cb := CheckBox.new()
	cb.text = label
	cb.button_pressed = current_value
	cb.toggled.connect(func(enabled: bool) -> void:
		host._play_toggle_sound(enabled)
		_set_read_track_value(track_id, key, enabled)
		host._on_read_track_filter_changed()
	)
	dynamic_options.add_child(cb)


func _set_read_track_hidden_flag(track_id: String, flag_bit: int, enabled: bool) -> void:
	for i in range(host._bam_tracks.size()):
		var track: Dictionary = host._bam_tracks[i]
		if str(track.get("track_id", "")) != track_id:
			continue
		var next_hidden := int(track.get("hidden_flags", 0))
		if enabled:
			next_hidden |= flag_bit
		else:
			next_hidden &= ~flag_bit
		track["hidden_flags"] = next_hidden
		host._bam_tracks[i] = track
		return


func _set_read_track_value(track_id: String, key: String, value: Variant) -> void:
	for i in range(host._bam_tracks.size()):
		var track: Dictionary = host._bam_tracks[i]
		if str(track.get("track_id", "")) != track_id:
			continue
		track[key] = value
		host._bam_tracks[i] = track
		return


func _populate_annotation_track_settings() -> void:
	var region_cb := CheckButton.new()
	region_cb.text = "Show full-length region annotations"
	region_cb.button_pressed = host._show_full_length_regions
	region_cb.toggled.connect(host._on_show_full_region_toggled)
	var stop_cb := CheckButton.new()
	stop_cb.text = "Show stop codons"
	stop_cb.button_pressed = host._show_stop_codons
	stop_cb.toggled.connect(host._on_show_stop_codons_toggled)
	var max_ann_label := Label.new()
	max_ann_label.text = "Max annotations on screen"
	var max_ann_spin := SpinBox.new()
	max_ann_spin.min_value = host.ANNOT_MAX_ON_SCREEN_MIN
	max_ann_spin.max_value = host.ANNOT_MAX_ON_SCREEN_MAX
	max_ann_spin.step = 100
	max_ann_spin.value = host._annotation_max_on_screen
	max_ann_spin.value_changed.connect(host._on_annotation_max_on_screen_changed)
	host._track_settings_box.add_child(region_cb)
	host._track_settings_box.add_child(stop_cb)
	host._track_settings_box.add_child(max_ann_label)
	host._track_settings_box.add_child(max_ann_spin)


func _populate_genome_track_settings() -> void:
	var seq_view_label := Label.new()
	seq_view_label.text = "Sequence View"
	var seq_view_option := OptionButton.new()
	seq_view_option.add_item("Concatenate", host.SEQ_VIEW_CONCAT)
	seq_view_option.add_item("Single Sequence", host.SEQ_VIEW_SINGLE)
	seq_view_option.select(host._seq_view_mode)
	host._track_settings_box.add_child(seq_view_label)
	host._track_settings_box.add_child(seq_view_option)
	var seq_label := Label.new()
	seq_label.text = "Sequence"
	var seq_option := OptionButton.new()
	for i in range(host._seq_option.item_count):
		seq_option.add_item(host._seq_option.get_item_text(i), host._seq_option.get_item_id(i))
	if host._selected_seq_id >= 0:
		for i in range(seq_option.item_count):
			if seq_option.get_item_id(i) == host._selected_seq_id:
				seq_option.select(i)
				break
	seq_option.visible = host._seq_view_mode == host.SEQ_VIEW_SINGLE
	seq_label.visible = seq_option.visible
	host._track_settings_box.add_child(seq_label)
	host._track_settings_box.add_child(seq_option)
	var gap_label := Label.new()
	gap_label.text = "Concat Gap (bp)"
	var gap_spin := SpinBox.new()
	gap_spin.min_value = 0
	gap_spin.max_value = 10000
	gap_spin.step = 10
	gap_spin.value = host._concat_gap_bp
	host._track_settings_box.add_child(gap_label)
	host._track_settings_box.add_child(gap_spin)
	var coord_commas_cb := CheckButton.new()
	coord_commas_cb.text = "Use commas in axis coordinates"
	coord_commas_cb.button_pressed = host._axis_coords_with_commas
	coord_commas_cb.toggled.connect(host._on_axis_coords_commas_toggled)
	host._track_settings_box.add_child(coord_commas_cb)
	seq_view_option.item_selected.connect(func(index: int) -> void:
		host._on_seq_view_selected(index)
		var single: bool = index == host.SEQ_VIEW_SINGLE
		seq_option.visible = single
		seq_label.visible = single
	)
	seq_option.item_selected.connect(func(index: int) -> void:
		if index < 0 or index >= seq_option.item_count:
			return
		var target_id := int(seq_option.get_item_id(index))
		for j in range(host._seq_option.item_count):
			if host._seq_option.get_item_id(j) == target_id:
				host._seq_option.select(j)
				break
		host._on_seq_selected(host._seq_option.selected)
	)
	gap_spin.value_changed.connect(host._on_concat_gap_changed)


func _populate_gc_plot_track_settings() -> void:
	var win_label := Label.new()
	win_label.text = "GC Window (bp)"
	var win_spin := SpinBox.new()
	win_spin.min_value = 1
	win_spin.max_value = 1000000
	win_spin.step = 1
	win_spin.value = host._gc_window_bp
	win_spin.value_changed.connect(func(value: float) -> void:
		host._gc_window_bp = clampi(int(value), 1, 1000000)
		host._invalidate_cache()
		host._schedule_fetch()
	)
	var height_label := Label.new()
	height_label.text = "Track Height (px)"
	var height_spin := SpinBox.new()
	height_spin.min_value = host.MIN_PLOT_HEIGHT
	height_spin.max_value = host.MAX_PLOT_HEIGHT
	height_spin.step = 1
	height_spin.value = host._gc_plot_height
	height_spin.value_changed.connect(func(value: float) -> void:
		host._gc_plot_height = value
		host._apply_gc_plot_height()
	)
	host._track_settings_box.add_child(win_label)
	host._track_settings_box.add_child(win_spin)
	host._track_settings_box.add_child(height_label)
	host._track_settings_box.add_child(height_spin)


func _populate_depth_plot_track_settings() -> void:
	if not host._has_bam_loaded:
		var no_bam := Label.new()
		no_bam.text = "Load BAM to enable depth plot."
		host._track_settings_box.add_child(no_bam)
	var height_label := Label.new()
	height_label.text = "Track Height (px)"
	var height_spin := SpinBox.new()
	height_spin.min_value = host.MIN_PLOT_HEIGHT
	height_spin.max_value = host.MAX_PLOT_HEIGHT
	height_spin.step = 1
	height_spin.value = host._depth_plot_height
	height_spin.value_changed.connect(func(value: float) -> void:
		host._depth_plot_height = value
		host._apply_depth_plot_height()
	)
	host._track_settings_box.add_child(height_label)
	host._track_settings_box.add_child(height_spin)
	var legend_title := Label.new()
	legend_title.text = "Depth Lines"
	host._track_settings_box.add_child(legend_title)
	if host._bam_tracks.is_empty():
		var legend_empty := Label.new()
		legend_empty.text = "None"
		host._track_settings_box.add_child(legend_empty)
		return
	for i in range(host._bam_tracks.size()):
		var track: Dictionary = host._bam_tracks[i]
		var track_id := str(track.get("track_id", ""))
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = host._depth_plot_color_for_track(track_id)
		var name_label := Label.new()
		name_label.text = "BAM %d: %s" % [i + 1, str(track.get("label", track_id))]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(swatch)
		row.add_child(name_label)
		host._track_settings_box.add_child(row)
