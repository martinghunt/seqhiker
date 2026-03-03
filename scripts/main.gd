extends Control

const ThemePaletteScript = preload("res://scripts/theme_palette.gd")
const ZemClientScript = preload("res://scripts/zem_client.gd")
const CONFIG_PATH := "user://seqhiker_settings.cfg"
const READ_DETAIL_MAX_ZOOM := 7
const DEFAULT_CONCAT_GAP_BP := 50
const DEFAULT_READ_THICKNESS := 8.0
const SEQ_VIEW_CONCAT := 0
const SEQ_VIEW_SINGLE := 1

@onready var background: ColorRect = $Background
@onready var genome_view: Control = $Root/ContentMargin/GenomeView
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_toggle_button: Button = $Root/TopBar/SettingsToggleButton
@onready var pan_left_button: Button = $Root/TopBar/PanLeftButton
@onready var pan_right_button: Button = $Root/TopBar/PanRightButton
@onready var zoom_out_button: Button = $Root/TopBar/ZoomOutButton
@onready var zoom_in_button: Button = $Root/TopBar/ZoomInButton
@onready var play_button: Button = $Root/TopBar/PlayButton
@onready var play_left_button: Button = $Root/TopBar/PlayLeftButton
@onready var stop_button: Button = $Root/TopBar/StopButton
@onready var viewport_label: Label = $Root/TopBar/ViewportLabel
@onready var server_status_label: Label = $Root/TopBar/ServerStatusLabel
@onready var feature_panel: PanelContainer = $FeaturePanel
@onready var feature_close_button: Button = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureCloseButton
@onready var feature_name_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureNameLabel
@onready var feature_type_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureTypeLabel
@onready var feature_range_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureRangeLabel
@onready var feature_strand_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureStrandLabel
@onready var feature_source_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureSourceLabel
@onready var feature_seq_label: Label = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureSeqLabel
@onready var ui_scale_slider: HSlider = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/UIScaleSlider
@onready var ui_scale_value: Label = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/UIScaleValue
@onready var trackpad_pan_slider: HSlider = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPanSlider
@onready var trackpad_pan_value: Label = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPanValue
@onready var trackpad_pinch_slider: HSlider = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPinchSlider
@onready var trackpad_pinch_value: Label = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPinchValue
@onready var play_speed_slider: HSlider = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PlaySpeedSlider
@onready var play_speed_value: Label = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PlaySpeedValue
@onready var theme_option: OptionButton = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ThemeOption
@onready var settings_content: VBoxContainer = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent
@onready var file_list: ItemList = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/FileList
@onready var host_edit: LineEdit = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/HostEdit
@onready var port_edit: LineEdit = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PortEdit
@onready var connect_button: Button = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ConnectButton
@onready var status_message_label: Label = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/StatusMessageLabel
@onready var close_settings_button: Button = $SettingsPanel/SettingsMargin/SettingsLayout/SettingsHeader/CloseSettingsButton

var _settings_open := false
var _settings_tween: Tween
var _feature_panel_open := false
var _feature_tween: Tween
var _fetch_timer: Timer
var _fetch_in_progress := false
var _fetch_pending := false

var _zem: RefCounted
var _current_chr_id := -1
var _current_chr_name := ""
var _current_chr_len := 0
var _last_start := 0
var _last_end := 0
var _last_bp_per_px := 8.0
var _has_bam_loaded := false
var _has_fasta_loaded := false
var _cache_start := -1
var _cache_end := -1
var _cache_zoom := -1
var _cache_mode := -1
var _cache_scope_key := ""
var _theme_text_color: Color = Color.BLACK
var _auto_play_enabled := false
var _auto_play_direction := 1.0
var _read_view_label: Label
var _read_view_option: OptionButton
var _fragment_log_checkbox: CheckBox
var _read_thickness_label: Label
var _read_thickness_spin: SpinBox
var _show_full_region_checkbox: CheckBox
var _seq_view_label: Label
var _seq_view_option: OptionButton
var _seq_option_label: Label
var _seq_option: OptionButton
var _concat_gap_label: Label
var _concat_gap_spin: SpinBox
var _seq_view_mode := SEQ_VIEW_CONCAT
var _selected_seq_id := -1
var _selected_seq_name := ""
var _concat_gap_bp := DEFAULT_CONCAT_GAP_BP
var _read_thickness := DEFAULT_READ_THICKNESS
var _show_full_length_regions := false
var _chromosomes: Array[Dictionary] = []
var _concat_segments: Array[Dictionary] = []

func _ready() -> void:
	_zem = ZemClientScript.new()
	_disable_button_focus()
	_setup_theme_selector()
	_setup_read_view_controls()
	_setup_sequence_controls()
	_connect_ui()
	_load_or_init_config()
	_apply_theme(theme_option.get_item_text(theme_option.selected))
	_on_trackpad_pan_changed(trackpad_pan_slider.value)
	_on_trackpad_pinch_changed(trackpad_pinch_slider.value)
	_on_play_speed_changed(play_speed_slider.value)
	_setup_fetch_timer()
	call_deferred("_initialize_settings_panel")
	if get_window().has_signal("files_dropped"):
		get_window().files_dropped.connect(_on_files_dropped)

func _initialize_settings_panel() -> void:
	settings_toggle_button.text = "Settings"
	_set_status("Disconnected")
	_slide_settings(false, false)
	_slide_feature_panel(false, false)

func _setup_fetch_timer() -> void:
	_fetch_timer = Timer.new()
	_fetch_timer.one_shot = true
	_fetch_timer.wait_time = 0.08
	_fetch_timer.timeout.connect(_on_fetch_timer_timeout)
	add_child(_fetch_timer)

func _setup_theme_selector() -> void:
	theme_option.clear()
	for theme_name in ThemePaletteScript.THEMES.keys():
		theme_option.add_item(theme_name)
	for i in range(theme_option.item_count):
		if theme_option.get_item_text(i) == "Dawn":
			theme_option.select(i)
			break

func _connect_ui() -> void:
	settings_toggle_button.pressed.connect(_toggle_settings)
	close_settings_button.pressed.connect(_close_settings)
	connect_button.pressed.connect(_connect_server)
	pan_left_button.pressed.connect(func() -> void: genome_view.pan_by_fraction(-0.35))
	pan_right_button.pressed.connect(func() -> void: genome_view.pan_by_fraction(0.35))
	zoom_in_button.pressed.connect(func() -> void: genome_view.zoom_by(0.78))
	zoom_out_button.pressed.connect(func() -> void: genome_view.zoom_by(1.28))
	play_button.pressed.connect(_start_auto_play)
	play_left_button.pressed.connect(_start_auto_play_left)
	stop_button.pressed.connect(_stop_auto_play)
	genome_view.viewport_changed.connect(_on_viewport_changed)
	genome_view.feature_clicked.connect(_on_feature_clicked)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	trackpad_pan_slider.value_changed.connect(_on_trackpad_pan_changed)
	trackpad_pinch_slider.value_changed.connect(_on_trackpad_pinch_changed)
	play_speed_slider.value_changed.connect(_on_play_speed_changed)
	theme_option.item_selected.connect(_on_theme_selected)
	feature_close_button.pressed.connect(_close_feature_panel)
	_read_view_option.item_selected.connect(_on_read_view_selected)
	_fragment_log_checkbox.toggled.connect(_on_fragment_log_toggled)
	_read_thickness_spin.value_changed.connect(_on_read_thickness_changed)
	_show_full_region_checkbox.toggled.connect(_on_show_full_region_toggled)
	_seq_view_option.item_selected.connect(_on_seq_view_selected)
	_seq_option.item_selected.connect(_on_seq_selected)
	_concat_gap_spin.value_changed.connect(_on_concat_gap_changed)

func _disable_button_focus() -> void:
	var buttons := [
		settings_toggle_button,
		pan_left_button,
		pan_right_button,
		zoom_out_button,
		zoom_in_button,
		play_button,
		play_left_button,
		stop_button,
		connect_button,
		close_settings_button,
		feature_close_button
	]
	for b in buttons:
		b.focus_mode = Control.FOCUS_NONE

func _connect_server() -> void:
	var host := host_edit.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(port_edit.text)
	if port <= 0:
		port = 9000
	var ok: bool = _zem.connect_to_server(host, port)
	if ok:
		_set_status("Connected %s:%d" % [host, port])
		_refresh_chromosomes()
	else:
		_set_status("Connection failed", true)

func _on_viewport_changed(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	_last_start = start_bp
	_last_end = end_bp
	_last_bp_per_px = bp_per_px
	viewport_label.text = "%s:%d - %d bp  |  %.2f bp/px" % [_current_chr_name, start_bp, end_bp, bp_per_px]
	if genome_view.is_zoom_animating():
		return
	if _current_chr_len > 0:
		var zoom := _compute_tile_zoom(bp_per_px)
		var mode := 0 if (_has_bam_loaded and zoom <= READ_DETAIL_MAX_ZOOM) else 1
		var needs_fetch := not _is_viewport_cached(start_bp, end_bp, zoom, mode, _scope_cache_key())
		if _auto_play_enabled and _is_near_cache_right_edge(start_bp, end_bp):
			needs_fetch = true
		if needs_fetch:
			_schedule_fetch()

func _toggle_settings() -> void:
	_settings_open = not _settings_open
	settings_toggle_button.text = "Close" if _settings_open else "Settings"
	_slide_settings(_settings_open, true)
	if not _settings_open:
		_save_config()

func _close_settings() -> void:
	_settings_open = false
	settings_toggle_button.text = "Settings"
	_slide_settings(false, true)
	_save_config()

func _slide_settings(open: bool, animated: bool) -> void:
	if _settings_tween and _settings_tween.is_running():
		_settings_tween.kill()
	var panel_w := maxf(settings_panel.size.x, settings_panel.custom_minimum_size.x)
	var target_x := 0.0 if open else -panel_w
	if animated:
		_settings_tween = create_tween()
		_settings_tween.set_trans(Tween.TRANS_CUBIC)
		_settings_tween.set_ease(Tween.EASE_OUT)
		_settings_tween.tween_property(settings_panel, "position:x", target_x, 0.24)
	else:
		settings_panel.position.x = target_x

func _slide_feature_panel(open: bool, animated: bool) -> void:
	if _feature_tween and _feature_tween.is_running():
		_feature_tween.kill()
	var panel_w := maxf(feature_panel.size.x, feature_panel.custom_minimum_size.x)
	var target_left := -panel_w if open else 0.0
	var target_right := 0.0 if open else panel_w
	if animated:
		_feature_tween = create_tween()
		_feature_tween.set_trans(Tween.TRANS_CUBIC)
		_feature_tween.set_ease(Tween.EASE_OUT)
		_feature_tween.parallel().tween_property(feature_panel, "offset_left", target_left, 0.24)
		_feature_tween.parallel().tween_property(feature_panel, "offset_right", target_right, 0.24)
	else:
		feature_panel.offset_left = target_left
		feature_panel.offset_right = target_right

func _on_ui_scale_changed(value: float) -> void:
	get_window().content_scale_factor = value
	ui_scale_value.text = "%.2fx" % value

func _on_trackpad_pan_changed(value: float) -> void:
	trackpad_pan_value.text = "%.2fx" % value
	genome_view.set_trackpad_pan_sensitivity(value)

func _on_trackpad_pinch_changed(value: float) -> void:
	trackpad_pinch_value.text = "%.2fx" % value
	genome_view.set_trackpad_pinch_sensitivity(value)

func _on_play_speed_changed(value: float) -> void:
	play_speed_value.text = "%.2f widths/s" % value

func _start_auto_play() -> void:
	if _current_chr_len <= 0:
		_set_status("Cannot play: no chromosome loaded.", true)
		return
	_auto_play_enabled = true
	_auto_play_direction = 1.0

func _start_auto_play_left() -> void:
	if _current_chr_len <= 0:
		_set_status("Cannot play: no chromosome loaded.", true)
		return
	_auto_play_enabled = true
	_auto_play_direction = -1.0

func _stop_auto_play() -> void:
	_auto_play_enabled = false

func _on_theme_selected(index: int) -> void:
	_apply_theme(theme_option.get_item_text(index))

func _setup_read_view_controls() -> void:
	_read_view_label = Label.new()
	_read_view_label.text = "Read View"
	_read_view_option = OptionButton.new()
	_read_view_option.add_item("Stack", 0)
	_read_view_option.add_item("Strand Stack", 1)
	_read_view_option.add_item("Paired", 2)
	_read_view_option.add_item("Fragment Size", 3)
	_read_view_option.select(0)
	_fragment_log_checkbox = CheckBox.new()
	_fragment_log_checkbox.text = "Log fragment Y scale"
	_fragment_log_checkbox.button_pressed = false
	_fragment_log_checkbox.visible = false
	_read_thickness_label = Label.new()
	_read_thickness_label.text = "Read Thickness"
	_read_thickness_spin = SpinBox.new()
	_read_thickness_spin.min_value = 2
	_read_thickness_spin.max_value = 24
	_read_thickness_spin.step = 1
	_read_thickness_spin.value = _read_thickness
	_show_full_region_checkbox = CheckBox.new()
	_show_full_region_checkbox.text = "Show full-length region annotations"
	_show_full_region_checkbox.button_pressed = _show_full_length_regions
	settings_content.add_child(_read_view_label)
	settings_content.add_child(_read_view_option)
	settings_content.add_child(_fragment_log_checkbox)
	settings_content.add_child(_read_thickness_label)
	settings_content.add_child(_read_thickness_spin)
	settings_content.add_child(_show_full_region_checkbox)
	genome_view.set_read_view_mode(0)
	genome_view.set_fragment_log_scale(false)
	genome_view.set_read_thickness(_read_thickness)
	genome_view.set_show_full_length_regions(_show_full_length_regions)

func _setup_sequence_controls() -> void:
	_seq_view_label = Label.new()
	_seq_view_label.text = "Sequence View"
	_seq_view_option = OptionButton.new()
	_seq_view_option.add_item("Concatenate", SEQ_VIEW_CONCAT)
	_seq_view_option.add_item("Single Sequence", SEQ_VIEW_SINGLE)
	_seq_view_option.select(SEQ_VIEW_CONCAT)
	_seq_option_label = Label.new()
	_seq_option_label.text = "Sequence"
	_seq_option = OptionButton.new()
	_seq_option.visible = false
	_seq_option_label.visible = false
	_concat_gap_label = Label.new()
	_concat_gap_label.text = "Concat Gap (bp)"
	_concat_gap_spin = SpinBox.new()
	_concat_gap_spin.min_value = 0
	_concat_gap_spin.max_value = 10000
	_concat_gap_spin.step = 10
	_concat_gap_spin.value = _concat_gap_bp
	settings_content.add_child(_seq_view_label)
	settings_content.add_child(_seq_view_option)
	settings_content.add_child(_seq_option_label)
	settings_content.add_child(_seq_option)
	settings_content.add_child(_concat_gap_label)
	settings_content.add_child(_concat_gap_spin)

func _on_read_view_selected(index: int) -> void:
	genome_view.set_read_view_mode(index)
	_fragment_log_checkbox.visible = index == 3

func _on_fragment_log_toggled(enabled: bool) -> void:
	genome_view.set_fragment_log_scale(enabled)

func _on_read_thickness_changed(value: float) -> void:
	_read_thickness = clampf(value, 2.0, 24.0)
	genome_view.set_read_thickness(_read_thickness)

func _on_show_full_region_toggled(enabled: bool) -> void:
	_show_full_length_regions = enabled
	genome_view.set_show_full_length_regions(enabled)

func _on_seq_view_selected(index: int) -> void:
	_seq_view_mode = index
	var single := index == SEQ_VIEW_SINGLE
	_seq_option.visible = single
	_seq_option_label.visible = single
	_invalidate_cache()
	_apply_sequence_view(true)
	_schedule_fetch()

func _on_seq_selected(index: int) -> void:
	if index < 0 or index >= _seq_option.item_count:
		return
	_selected_seq_id = int(_seq_option.get_item_id(index))
	_selected_seq_name = _seq_option.get_item_text(index)
	_invalidate_cache()
	_apply_sequence_view(true)
	_schedule_fetch()

func _on_concat_gap_changed(value: float) -> void:
	_concat_gap_bp = maxi(0, int(value))
	_rebuild_concat_segments()
	if _seq_view_mode == SEQ_VIEW_CONCAT:
		_apply_sequence_view(true)
		_schedule_fetch()

func _apply_theme(theme_name: String) -> void:
	if not ThemePaletteScript.THEMES.has(theme_name):
		return
	var palette: Dictionary = ThemePaletteScript.THEMES[theme_name]
	_theme_text_color = palette["text"]
	background.color = palette["bg"]
	genome_view.set_palette(palette)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = palette["panel"]
	panel_style.border_width_left = 1
	panel_style.border_width_right = 1
	panel_style.border_width_top = 1
	panel_style.border_width_bottom = 1
	panel_style.border_color = palette["grid"]
	settings_panel.add_theme_stylebox_override("panel", panel_style)
	feature_panel.add_theme_stylebox_override("panel", panel_style)
	server_status_label.add_theme_color_override("font_color", palette["text"])
	viewport_label.add_theme_color_override("font_color", palette["text"])
	status_message_label.add_theme_color_override("font_color", palette["text"])
	feature_name_label.add_theme_color_override("font_color", palette["text"])
	feature_type_label.add_theme_color_override("font_color", palette["text"])
	feature_range_label.add_theme_color_override("font_color", palette["text"])
	feature_strand_label.add_theme_color_override("font_color", palette["text"])
	feature_source_label.add_theme_color_override("font_color", palette["text"])
	feature_seq_label.add_theme_color_override("font_color", palette["text"])
	_apply_text_theme_recursive($SettingsPanel/SettingsMargin/SettingsLayout, palette["text"])

func _on_files_dropped(files: PackedStringArray) -> void:
	var dropped_fasta := _has_fasta(files)
	var dropped_gff3 := _has_gff3(files)
	if dropped_gff3 and not (_has_fasta_loaded or dropped_fasta):
		_set_status("Refusing GFF3 load: drop a FASTA first.", true)
		return
	if dropped_fasta:
		_reset_loaded_state()
	for f in files:
		if not _file_list_has(f):
			file_list.add_item(f)
	genome_view.load_files(files)
	if not _ensure_server_connected():
		return
	if not _load_dropped_files(files):
		return
	if dropped_fasta:
		_has_fasta_loaded = true
	_refresh_chromosomes()
	_refresh_visible_data()

func _ensure_server_connected() -> bool:
	if _zem.ensure_connected():
		_set_status("Connected")
		return true
	_set_status("Disconnected", true)
	return false

func _load_dropped_files(files: PackedStringArray) -> bool:
	var genome_targets: Dictionary = {}
	var bam_targets: Dictionary = {}
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext == "bam":
			bam_targets[path] = true
		else:
			genome_targets[path] = true

	for target in genome_targets.keys():
		var resp: Dictionary = _zem.load_genome(target)
		if not resp.get("ok", false):
			_set_status("Load genome failed: %s" % resp.get("error", "error"), true)
			return false

	for bam_path in bam_targets.keys():
		var bam_resp: Dictionary = _zem.load_bam(bam_path)
		if not bam_resp.get("ok", false):
			_set_status("Load BAM failed: %s" % bam_resp.get("error", "error"), true)
			return false
		_has_bam_loaded = true
	return true

func _refresh_chromosomes() -> void:
	var resp: Dictionary = _zem.get_chromosomes()
	if not resp.get("ok", false):
		_set_status("Chrom query failed: %s" % resp.get("error", "error"), true)
		return
	var chroms: Array[Dictionary] = resp.get("chromosomes", [])
	if chroms.is_empty():
		_set_status("No chromosomes loaded", true)
		return
	_chromosomes = chroms
	_rebuild_concat_segments()
	_refresh_sequence_options()
	_apply_sequence_view(true)

func _rebuild_concat_segments() -> void:
	_concat_segments.clear()
	var pos := 0
	for i in range(_chromosomes.size()):
		var c: Dictionary = _chromosomes[i]
		var seg_len := int(c.get("length", 0))
		var seg := {
			"id": int(c.get("id", -1)),
			"name": str(c.get("name", "chr")),
			"length": seg_len,
			"start": pos,
			"end": pos + seg_len
		}
		_concat_segments.append(seg)
		pos += seg_len
		if i < _chromosomes.size() - 1:
			pos += _concat_gap_bp

func _refresh_sequence_options() -> void:
	_seq_option.clear()
	for c in _chromosomes:
		_seq_option.add_item(str(c.get("name", "chr")), int(c.get("id", -1)))
	if _selected_seq_id < 0 and not _selected_seq_name.is_empty():
		for c in _chromosomes:
			if str(c.get("name", "")) == _selected_seq_name:
				_selected_seq_id = int(c.get("id", -1))
				break
	if _selected_seq_id < 0 and _chromosomes.size() > 0:
		_selected_seq_id = int(_chromosomes[0].get("id", -1))
	var found := false
	for i in range(_seq_option.item_count):
		if _seq_option.get_item_id(i) == _selected_seq_id:
			_seq_option.select(i)
			_selected_seq_name = _seq_option.get_item_text(i)
			found = true
			break
	if not found and _seq_option.item_count > 0:
		_seq_option.select(0)
		_selected_seq_id = int(_seq_option.get_item_id(0))
		_selected_seq_name = _seq_option.get_item_text(0)

func _apply_sequence_view(reset_viewport: bool) -> void:
	if _seq_view_mode == SEQ_VIEW_SINGLE:
		var selected: Dictionary = {}
		for c in _chromosomes:
			if int(c.get("id", -1)) == _selected_seq_id:
				selected = c
				break
		if selected.is_empty() and _chromosomes.size() > 0:
			selected = _chromosomes[0]
			_selected_seq_id = int(selected.get("id", -1))
		_current_chr_id = int(selected.get("id", -1))
		_current_chr_name = str(selected.get("name", "chr"))
		_selected_seq_name = _current_chr_name
		_current_chr_len = int(selected.get("length", 0))
		_set_status("Loaded %s (%d bp)" % [_current_chr_name, _current_chr_len])
	else:
		_current_chr_id = -2
		var total := 0
		if _concat_segments.size() > 0:
			total = int(_concat_segments[_concat_segments.size() - 1].get("end", 0))
		_current_chr_name = "concat"
		_current_chr_len = total
		_set_status("Loaded concat (%d seqs, %d bp)" % [_concat_segments.size(), _current_chr_len])
	if reset_viewport:
		genome_view.set_chromosome(_current_chr_name, _current_chr_len)
	if _seq_view_mode == SEQ_VIEW_CONCAT:
		genome_view.set_concat_segments(_concat_segments)
	else:
		genome_view.set_concat_segments([])
	_invalidate_cache()

func _scope_cache_key() -> String:
	if _seq_view_mode == SEQ_VIEW_SINGLE:
		return "single:%d" % _current_chr_id
	return "concat:%d:%d" % [_concat_segments.size(), _concat_gap_bp]

func _invalidate_cache() -> void:
	_cache_start = -1
	_cache_end = -1
	_cache_zoom = -1
	_cache_mode = -1
	_cache_scope_key = ""

func _refresh_visible_data() -> void:
	if _current_chr_len <= 0:
		return
	var span: int = maxi(1, _last_end - _last_start)
	var right_span_mult := 3 if _auto_play_enabled else 1
	var query_start: int = maxi(0, _last_start - span)
	var query_end: int = mini(_current_chr_len, _last_end + span * right_span_mult)
	var ann_margin: int = maxi(64, int(span * 0.2))
	var ann_query_start: int = maxi(0, _last_start - ann_margin)
	var ann_query_end: int = mini(_current_chr_len, _last_end + ann_margin)
	var all_reads: Array[Dictionary] = []
	var all_coverage_tiles: Array[Dictionary] = []
	var features: Array[Dictionary] = []
	var ref_start := query_start
	var ref_sequence := ""

	if _seq_view_mode == SEQ_VIEW_SINGLE:
		if _has_bam_loaded:
			var zoom := _compute_tile_zoom(_last_bp_per_px)
			var tile_width := 1024 << zoom
			var tile_start := int(floor(float(query_start) / float(tile_width)))
			var tile_end := int(floor(float(query_end) / float(tile_width)))
			if zoom <= READ_DETAIL_MAX_ZOOM:
				for t in range(tile_start, tile_end + 1):
					var tile_resp: Dictionary = _zem.get_tile(_current_chr_id, zoom, t)
					if not tile_resp.get("ok", false):
						_set_status("Tile query failed: %s" % tile_resp.get("error", "error"), true)
						return
					all_reads.append_array(tile_resp.get("reads", []))
			else:
				for t in range(tile_start, tile_end + 1):
					var cov_resp: Dictionary = _zem.get_coverage_tile(_current_chr_id, zoom, t)
					if not cov_resp.get("ok", false):
						_set_status("Coverage query failed: %s" % cov_resp.get("error", "error"), true)
						return
					all_coverage_tiles.append(cov_resp.get("coverage", {}))

		var ann_resp: Dictionary = _zem.get_annotations(_current_chr_id, ann_query_start, ann_query_end, 2500)
		if not ann_resp.get("ok", false):
			_set_status("Annotation query failed: %s" % ann_resp.get("error", "error"), true)
			return
		features = ann_resp.get("features", [])

		var ref_resp: Dictionary = _zem.get_reference_slice(_current_chr_id, query_start, query_end)
		if not ref_resp.get("ok", false):
			_set_status("Reference query failed: %s" % ref_resp.get("error", "error"), true)
			return
		ref_start = int(ref_resp.get("slice_start", query_start))
		ref_sequence = str(ref_resp.get("sequence", ""))
	else:
		var overlaps := _segments_overlapping(query_start, query_end)
		var ann_overlaps := _segments_overlapping(ann_query_start, ann_query_end)
		var zoom := _compute_tile_zoom(_last_bp_per_px)
		for ov in overlaps:
			var chr_id := int(ov["id"])
			var offset := int(ov["offset"])
			var local_start := int(ov["local_start"])
			var local_end := int(ov["local_end"])
			if _has_bam_loaded:
				var tile_width := 1024 << zoom
				var tile_start := int(floor(float(local_start) / float(tile_width)))
				var tile_end := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width)))
				if zoom <= READ_DETAIL_MAX_ZOOM:
					for t in range(tile_start, tile_end + 1):
						var tile_resp: Dictionary = _zem.get_tile(chr_id, zoom, t)
						if not tile_resp.get("ok", false):
							_set_status("Tile query failed: %s" % tile_resp.get("error", "error"), true)
							return
						for r in tile_resp.get("reads", []):
							var shifted := _shift_read_coords(r, offset)
							if int(shifted.get("end", 0)) > query_start and int(shifted.get("start", 0)) < query_end:
								all_reads.append(shifted)
				else:
					for t in range(tile_start, tile_end + 1):
						var cov_resp: Dictionary = _zem.get_coverage_tile(chr_id, zoom, t)
						if not cov_resp.get("ok", false):
							_set_status("Coverage query failed: %s" % cov_resp.get("error", "error"), true)
							return
						var shifted_cov := _shift_coverage_coords(cov_resp.get("coverage", {}), offset)
						all_coverage_tiles.append(shifted_cov)

		for aov in ann_overlaps:
			var a_chr_id := int(aov["id"])
			var a_offset := int(aov["offset"])
			var a_local_start := int(aov["local_start"])
			var a_local_end := int(aov["local_end"])
			var ann_resp_part: Dictionary = _zem.get_annotations(a_chr_id, a_local_start, a_local_end, 2500)
			if not ann_resp_part.get("ok", false):
				_set_status("Annotation query failed: %s" % ann_resp_part.get("error", "error"), true)
				return
			for f in ann_resp_part.get("features", []):
				features.append(_shift_feature_coords(f, a_offset))

		ref_sequence = _build_concat_reference(query_start, query_end, overlaps)

	genome_view.set_reads(all_reads)
	genome_view.set_coverage_tiles(all_coverage_tiles)
	genome_view.set_features(features)
	genome_view.set_reference_slice(ref_start, ref_sequence)
	_cache_start = query_start
	_cache_end = query_end
	_cache_zoom = _compute_tile_zoom(_last_bp_per_px)
	_cache_mode = 0 if (_has_bam_loaded and _cache_zoom <= READ_DETAIL_MAX_ZOOM) else 1
	_cache_scope_key = _scope_cache_key()

func _schedule_fetch() -> void:
	if _fetch_timer == null:
		return
	if _fetch_in_progress:
		_fetch_pending = true
		return
	if _fetch_timer.is_stopped():
		_fetch_timer.start()

func _on_fetch_timer_timeout() -> void:
	_fetch_in_progress = true
	_fetch_pending = false
	_refresh_visible_data()
	_fetch_in_progress = false
	if _fetch_pending:
		_fetch_timer.start()

func _segments_overlapping(start_bp: int, end_bp: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for seg in _concat_segments:
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", 0))
		if seg_end <= start_bp or seg_start >= end_bp:
			continue
		var overlap_start := maxi(start_bp, seg_start)
		var overlap_end := mini(end_bp, seg_end)
		out.append({
			"id": int(seg.get("id", -1)),
			"name": str(seg.get("name", "chr")),
			"offset": seg_start,
			"local_start": overlap_start - seg_start,
			"local_end": overlap_end - seg_start,
			"global_start": overlap_start,
			"global_end": overlap_end
		})
	return out

func _shift_read_coords(read: Dictionary, offset: int) -> Dictionary:
	var shifted := read.duplicate(true)
	shifted["start"] = int(shifted.get("start", 0)) + offset
	shifted["end"] = int(shifted.get("end", 0)) + offset
	if int(shifted.get("mate_start", -1)) >= 0:
		shifted["mate_start"] = int(shifted.get("mate_start", -1)) + offset
	if int(shifted.get("mate_end", -1)) >= 0:
		shifted["mate_end"] = int(shifted.get("mate_end", -1)) + offset
	var shifted_snps := PackedInt32Array()
	var snps: PackedInt32Array = shifted.get("snps", PackedInt32Array())
	for s in snps:
		shifted_snps.append(int(s) + offset)
	shifted["snps"] = shifted_snps
	return shifted

func _shift_coverage_coords(cov: Dictionary, offset: int) -> Dictionary:
	if cov.is_empty():
		return cov
	return {
		"start": int(cov.get("start", 0)) + offset,
		"end": int(cov.get("end", 0)) + offset,
		"bins": cov.get("bins", PackedInt32Array())
	}

func _shift_feature_coords(feature: Dictionary, offset: int) -> Dictionary:
	var shifted := feature.duplicate(true)
	shifted["start"] = int(shifted.get("start", 0)) + offset
	shifted["end"] = int(shifted.get("end", 0)) + offset
	return shifted

func _build_concat_reference(query_start: int, query_end: int, overlaps: Array[Dictionary]) -> String:
	var ln := maxi(0, query_end - query_start)
	if ln == 0:
		return ""
	var chars: Array[String] = []
	chars.resize(ln)
	for i in range(ln):
		chars[i] = " "
	for ov in overlaps:
		var chr_id := int(ov["id"])
		var local_start := int(ov["local_start"])
		var local_end := int(ov["local_end"])
		var global_start := int(ov["global_start"])
		var ref_resp: Dictionary = _zem.get_reference_slice(chr_id, local_start, local_end)
		if not ref_resp.get("ok", false):
			continue
		var seq := str(ref_resp.get("sequence", ""))
		var dst := global_start - query_start
		var copy_len := mini(seq.length(), ln - dst)
		for i in range(copy_len):
			chars[dst + i] = seq.substr(i, 1)
	var built := ""
	for c in chars:
		built += c
	return built

func _compute_tile_zoom(bp_per_px: float) -> int:
	var z := int(round(log(max(bp_per_px, 0.001)) / log(2.0)))
	return clampi(z, 0, 12)

func _file_list_has(path: String) -> bool:
	for i in range(file_list.item_count):
		if file_list.get_item_text(i) == path:
			return true
	return false

func _has_fasta(files: PackedStringArray) -> bool:
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext in ["fa", "fasta", "fna", "ffn", "frn", "faa"]:
			return true
	return false

func _has_gff3(files: PackedStringArray) -> bool:
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext in ["gff", "gff3"]:
			return true
	return false

func _reset_loaded_state() -> void:
	file_list.clear()
	_current_chr_id = -1
	_current_chr_name = ""
	_current_chr_len = 0
	_cache_start = -1
	_cache_end = -1
	_invalidate_cache()
	_has_bam_loaded = false
	_has_fasta_loaded = false
	_chromosomes.clear()
	_concat_segments.clear()
	_seq_option.clear()
	_selected_seq_id = -1
	_selected_seq_name = ""
	_auto_play_enabled = false
	_feature_panel_open = false
	_slide_feature_panel(false, false)
	genome_view.clear_all_data()

func _is_viewport_cached(start_bp: int, end_bp: int, zoom: int, mode: int, scope_key: String) -> bool:
	if _cache_start < 0 || _cache_end < 0:
		return false
	if _cache_zoom != zoom or _cache_mode != mode:
		return false
	if _cache_scope_key != scope_key:
		return false
	return start_bp >= _cache_start and end_bp <= _cache_end

func _is_near_cache_right_edge(start_bp: int, end_bp: int) -> bool:
	if _cache_end < 0:
		return true
	var span: int = maxi(1, end_bp - start_bp)
	var remaining_right: int = _cache_end - end_bp
	return remaining_right <= span

func _set_status(message: String, is_error: bool = false) -> void:
	server_status_label.text = message
	server_status_label.tooltip_text = message
	status_message_label.text = message
	status_message_label.tooltip_text = message
	status_message_label.add_theme_color_override("font_color", Color("8b0000") if is_error else _theme_text_color)

func _apply_text_theme_recursive(node: Node, color: Color) -> void:
	if node is Label:
		(node as Label).add_theme_color_override("font_color", color)
	elif node is Button:
		(node as Button).add_theme_color_override("font_color", color)
	elif node is LineEdit:
		(node as LineEdit).add_theme_color_override("font_color", color)
	elif node is OptionButton:
		(node as OptionButton).add_theme_color_override("font_color", color)
	elif node is CheckBox:
		(node as CheckBox).add_theme_color_override("font_color", color)
	elif node is ItemList:
		(node as ItemList).add_theme_color_override("font_color", color)

	for child in node.get_children():
		_apply_text_theme_recursive(child, color)

func _load_or_init_config() -> void:
	var cfg := ConfigFile.new()
	if not FileAccess.file_exists(CONFIG_PATH):
		_save_config()
		return

	var err := cfg.load(CONFIG_PATH)
	if err != OK:
		_save_config()
		return

	host_edit.text = str(cfg.get_value("connection", "host", host_edit.text))
	port_edit.text = str(int(cfg.get_value("connection", "port", int(port_edit.text))))
	ui_scale_slider.value = float(cfg.get_value("ui", "scale", ui_scale_slider.value))
	if cfg.has_section_key("ui", "play_speed_widths_per_sec"):
		play_speed_slider.value = float(cfg.get_value("ui", "play_speed_widths_per_sec", play_speed_slider.value))
	elif cfg.has_section_key("ui", "play_speed_bp_per_sec"):
		# Legacy config key from older builds; map to a conservative default.
		play_speed_slider.value = 0.3
	trackpad_pan_slider.value = float(cfg.get_value("input", "trackpad_pan_sensitivity", trackpad_pan_slider.value))
	trackpad_pinch_slider.value = float(cfg.get_value("input", "trackpad_pinch_sensitivity", trackpad_pinch_slider.value))

	var theme_name := str(cfg.get_value("ui", "theme", theme_option.get_item_text(theme_option.selected)))
	_select_theme_option(theme_name)
	var seq_view := int(cfg.get_value("ui", "sequence_view_mode", SEQ_VIEW_CONCAT))
	seq_view = clampi(seq_view, SEQ_VIEW_CONCAT, SEQ_VIEW_SINGLE)
	_concat_gap_bp = int(cfg.get_value("ui", "concat_gap_bp", DEFAULT_CONCAT_GAP_BP))
	_concat_gap_bp = maxi(0, _concat_gap_bp)
	_concat_gap_spin.value = _concat_gap_bp
	_seq_view_option.select(seq_view)
	_on_seq_view_selected(seq_view)
	var seq_name := str(cfg.get_value("ui", "selected_sequence_name", ""))
	if not seq_name.is_empty():
		_selected_seq_name = seq_name
	var read_view := int(cfg.get_value("ui", "read_view_mode", 0))
	read_view = clampi(read_view, 0, 3)
	_read_view_option.select(read_view)
	_on_read_view_selected(read_view)
	_read_thickness = float(cfg.get_value("ui", "read_thickness", DEFAULT_READ_THICKNESS))
	_read_thickness = clampf(_read_thickness, 2.0, 24.0)
	_read_thickness_spin.value = _read_thickness
	genome_view.set_read_thickness(_read_thickness)
	_show_full_length_regions = bool(cfg.get_value("ui", "show_full_length_regions", false))
	_show_full_region_checkbox.button_pressed = _show_full_length_regions
	genome_view.set_show_full_length_regions(_show_full_length_regions)
	var frag_log := bool(cfg.get_value("ui", "fragment_log_scale", false))
	_fragment_log_checkbox.button_pressed = frag_log
	genome_view.set_fragment_log_scale(frag_log)

func _select_theme_option(theme_name: String) -> void:
	for i in range(theme_option.item_count):
		if theme_option.get_item_text(i) == theme_name:
			theme_option.select(i)
			return

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("connection", "host", host_edit.text.strip_edges())
	cfg.set_value("connection", "port", int(port_edit.text))
	cfg.set_value("ui", "scale", ui_scale_slider.value)
	cfg.set_value("ui", "play_speed_widths_per_sec", play_speed_slider.value)
	cfg.set_value("ui", "theme", theme_option.get_item_text(theme_option.selected))
	cfg.set_value("ui", "sequence_view_mode", _seq_view_option.selected)
	cfg.set_value("ui", "concat_gap_bp", _concat_gap_bp)
	cfg.set_value("ui", "selected_sequence_name", _selected_seq_name)
	cfg.set_value("ui", "read_view_mode", _read_view_option.selected)
	cfg.set_value("ui", "read_thickness", _read_thickness)
	cfg.set_value("ui", "show_full_length_regions", _show_full_length_regions)
	cfg.set_value("ui", "fragment_log_scale", _fragment_log_checkbox.button_pressed)
	cfg.set_value("input", "trackpad_pan_sensitivity", trackpad_pan_slider.value)
	cfg.set_value("input", "trackpad_pinch_sensitivity", trackpad_pinch_slider.value)
	cfg.save(CONFIG_PATH)

func _on_feature_clicked(feature: Dictionary) -> void:
	feature_name_label.text = "Name: %s" % str(feature.get("name", "-"))
	feature_type_label.text = "Type: %s" % str(feature.get("type", "-"))
	feature_range_label.text = "Range: %d - %d" % [int(feature.get("start", 0)), int(feature.get("end", 0))]
	feature_strand_label.text = "Strand: %s" % str(feature.get("strand", "."))
	feature_source_label.text = "Source: %s" % str(feature.get("source", "-"))
	feature_seq_label.text = "Sequence: %s" % str(feature.get("seq_name", _current_chr_name))
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _close_feature_panel() -> void:
	_feature_panel_open = false
	_slide_feature_panel(false, true)

func _input(event: InputEvent) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT:
				genome_view.pan_by_fraction(-0.35)
				accept_event()
			KEY_RIGHT:
				genome_view.pan_by_fraction(0.35)
				accept_event()
			KEY_KP_ADD, KEY_PLUS:
				genome_view.zoom_by(0.78)
				accept_event()
			KEY_KP_SUBTRACT, KEY_MINUS:
				genome_view.zoom_by(1.28)
				accept_event()
			KEY_EQUAL:
				if event.shift_pressed:
					genome_view.zoom_by(0.78)
					accept_event()

func _process(delta: float) -> void:
	if not _auto_play_enabled:
		return
	if _current_chr_len <= 0:
		_auto_play_enabled = false
		return
	var bp_delta: float = play_speed_slider.value * genome_view.get_visible_span_bp() * delta * _auto_play_direction
	var reached_end: bool = genome_view.auto_scroll_bp(bp_delta)
	if reached_end:
		_auto_play_enabled = false
		if _auto_play_direction < 0.0:
			_set_status("Reached start of sequence. Autoplay stopped.")
		else:
			_set_status("Reached end of sequence. Autoplay stopped.")
