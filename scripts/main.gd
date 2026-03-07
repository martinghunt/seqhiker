extends Control

const ThemesLibScript = preload("res://scripts/themes.gd")
const ZemClientScript = preload("res://scripts/zem_client.gd")
const CONFIG_PATH := "user://seqhiker_settings.cfg"
const READ_DETAIL_MAX_ZOOM := 7
const DEFAULT_CONCAT_GAP_BP := 50
const DEFAULT_READ_THICKNESS := 8.0
const ANNOT_CHUNK_TARGET_BP := 120000
const ANNOT_MAX_CHUNKS := 24
const ANNOT_MAX_PER_CHUNK := 2500
const ANNOT_MAX_TOTAL := 12000
const TRACK_READS := "reads"
const TRACK_AA := "aa"
const TRACK_GC_PLOT := "gc_plot"
const TRACK_DEPTH_PLOT := "depth_plot"
const TRACK_GENOME := "genome"
const SEQ_VIEW_CONCAT := 0
const SEQ_VIEW_SINGLE := 1
const DEFAULT_GC_WINDOW_BP := 200
const PLOT_Y_UNIT := 0
const PLOT_Y_AUTOSCALE := 1
const PLOT_Y_FIXED := 2
const DEFAULT_PLOT_HEIGHT := 100.0
const MIN_PLOT_HEIGHT := 50.0
const MAX_PLOT_HEIGHT := 360.0
const TOPBAR_MIN_HEIGHT := 48.0
const ROOT_VERTICAL_GAP := 8.0
const CONTENT_MARGIN_BOTTOM := 10.0
const READS_TRACK_MIN_HEIGHT := 140.0
const UI_FONT_SIZE := 13

@onready var background: ColorRect = $Background
@onready var genome_view: Control = $Root/ContentMargin/GenomeView
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var settings_toggle_button: Button = $Root/TopBar/SettingsToggleButton
@onready var pan_left_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PanLeftButton
@onready var pan_right_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PanRightButton
@onready var zoom_out_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ZoomOutButton
@onready var zoom_in_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ZoomInButton
@onready var play_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PlayButton
@onready var play_left_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PlayLeftButton
@onready var stop_button: Button = $Root/TopBar/ActionClipper/ActionStrip/StopButton
@onready var viewport_label: Label = $Root/TopBar/ActionClipper/ActionStrip/ViewportLabel
@onready var server_status_label: Label = $Root/TopBar/ActionClipper/ActionStrip/ServerStatusLabel
@onready var feature_panel: PanelContainer = $FeaturePanel
@onready var feature_close_button: Button = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureCloseButton
@onready var feature_name_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureNameLabel
@onready var feature_type_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureTypeLabel
@onready var feature_range_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureRangeLabel
@onready var feature_strand_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureStrandLabel
@onready var feature_source_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureSourceLabel
@onready var feature_seq_label: RichTextLabel = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent/FeatureSeqLabel
@onready var feature_content: VBoxContainer = $FeaturePanel/FeatureMargin/FeatureScroll/FeatureContent
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
var _center_strand_scroll_pending := false
var _has_fasta_loaded := false
var _cache_start := -1
var _cache_end := -1
var _cache_zoom := -1
var _cache_mode := -1
var _cache_scope_key := ""
var _theme_text_color: Color = Color.BLACK
var _theme_error_color: Color = Color("8b0000")
var _themes_lib: RefCounted
var _auto_play_enabled := false
var _auto_play_direction := 1.0
var _read_view_label: Label
var _read_view_option: OptionButton
var _fragment_log_checkbox: CheckBox
var _read_thickness_label: Label
var _read_thickness_spin: SpinBox
var _show_full_region_checkbox: CheckBox
var _track_order_label: Label
var _track_order_list: ItemList
var _track_visibility_box: VBoxContainer
var _track_dragging := false
var _track_drag_index := -1
var _track_drop_index := -1
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
var _colorize_nucleotides := true
var _gc_window_bp := DEFAULT_GC_WINDOW_BP
var _gc_plot_y_mode := PLOT_Y_UNIT
var _gc_plot_y_min := 0.0
var _gc_plot_y_max := 1.0
var _depth_plot_y_mode := PLOT_Y_AUTOSCALE
var _depth_plot_y_min := 0.0
var _depth_plot_y_max := 100.0
var _gc_plot_height := DEFAULT_PLOT_HEIGHT
var _depth_plot_height := DEFAULT_PLOT_HEIGHT
var _chromosomes: Array[Dictionary] = []
var _concat_segments: Array[Dictionary] = []
var _track_settings_box: VBoxContainer
var _track_settings_open := false
var _active_track_settings_id := ""

func _ready() -> void:
	_zem = ZemClientScript.new()
	_themes_lib = ThemesLibScript.new()
	_disable_button_focus()
	_setup_theme_selector()
	_setup_read_view_controls()
	_setup_sequence_controls()
	_setup_track_order_controls()
	_setup_track_settings_panel()
	_connect_ui()
	_load_or_init_config()
	_apply_gc_plot_y_scale()
	_apply_depth_plot_y_scale()
	_apply_gc_plot_height()
	_apply_depth_plot_height()
	_update_window_min_height()
	_apply_theme(theme_option.get_item_text(theme_option.selected))
	_on_trackpad_pan_changed(trackpad_pan_slider.value)
	_on_trackpad_pinch_changed(trackpad_pinch_slider.value)
	_on_play_speed_changed(play_speed_slider.value)
	_setup_fetch_timer()
	call_deferred("_initialize_settings_panel")
	if get_window().has_signal("files_dropped"):
		get_window().files_dropped.connect(_on_files_dropped)

func _initialize_settings_panel() -> void:
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
	for theme_name in _themes_lib.theme_names():
		theme_option.add_item(theme_name)
	for i in range(theme_option.item_count):
		if theme_option.get_item_text(i) == "Light":
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
	genome_view.read_clicked.connect(_on_read_clicked)
	genome_view.track_settings_requested.connect(_on_track_settings_requested)
	genome_view.track_order_changed.connect(_on_track_order_changed)
	genome_view.track_visibility_changed.connect(_on_track_visibility_changed)
	ui_scale_slider.value_changed.connect(_on_ui_scale_changed)
	trackpad_pan_slider.value_changed.connect(_on_trackpad_pan_changed)
	trackpad_pinch_slider.value_changed.connect(_on_trackpad_pinch_changed)
	play_speed_slider.value_changed.connect(_on_play_speed_changed)
	theme_option.item_selected.connect(_on_theme_selected)
	feature_close_button.pressed.connect(_close_feature_panel)
	_show_full_region_checkbox.toggled.connect(_on_show_full_region_toggled)
	_track_order_list.gui_input.connect(_on_track_order_list_gui_input)
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
	_slide_settings(_settings_open, true)
	if not _settings_open:
		_save_config()

func _close_settings() -> void:
	_settings_open = false
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

func _setup_track_order_controls() -> void:
	_track_order_label = Label.new()
	_track_order_label.text = "Track Order"
	_track_order_list = ItemList.new()
	_track_order_list.select_mode = ItemList.SELECT_SINGLE
	_track_order_list.custom_minimum_size = Vector2(0, 84)
	_track_visibility_box = VBoxContainer.new()
	_track_visibility_box.add_theme_constant_override("separation", 4)
	settings_content.add_child(_track_order_label)
	settings_content.add_child(_track_order_list)
	settings_content.add_child(_track_visibility_box)
	_refresh_track_order_list(genome_view.get_track_order(), 0)
	_refresh_track_visibility_controls(genome_view.get_track_order())

func _setup_track_settings_panel() -> void:
	_track_settings_box = VBoxContainer.new()
	_track_settings_box.visible = false
	feature_content.add_child(_track_settings_box)

func _on_read_view_selected(index: int) -> void:
	_read_view_option.select(index)
	genome_view.set_read_view_mode(index)

func _on_fragment_log_toggled(enabled: bool) -> void:
	_fragment_log_checkbox.button_pressed = enabled
	genome_view.set_fragment_log_scale(enabled)

func _on_read_thickness_changed(value: float) -> void:
	_read_thickness = clampf(value, 2.0, 24.0)
	genome_view.set_read_thickness(_read_thickness)

func _on_show_full_region_toggled(enabled: bool) -> void:
	_show_full_length_regions = enabled
	genome_view.set_show_full_length_regions(enabled)

func _on_colorize_nucleotides_toggled(enabled: bool) -> void:
	_colorize_nucleotides = enabled
	genome_view.set_colorize_nucleotides(enabled)

func _apply_gc_plot_y_scale() -> void:
	if _gc_plot_y_max <= _gc_plot_y_min:
		_gc_plot_y_max = _gc_plot_y_min + 1.0
	genome_view.set_gc_plot_y_scale(_gc_plot_y_mode, _gc_plot_y_min, _gc_plot_y_max)

func _apply_depth_plot_y_scale() -> void:
	if _depth_plot_y_max <= _depth_plot_y_min:
		_depth_plot_y_max = _depth_plot_y_min + 1.0
	genome_view.set_depth_plot_y_scale(_depth_plot_y_mode, _depth_plot_y_min, _depth_plot_y_max)

func _apply_gc_plot_height() -> void:
	_gc_plot_height = clampf(_gc_plot_height, MIN_PLOT_HEIGHT, MAX_PLOT_HEIGHT)
	genome_view.set_gc_plot_height(_gc_plot_height)
	_update_window_min_height()

func _apply_depth_plot_height() -> void:
	_depth_plot_height = clampf(_depth_plot_height, MIN_PLOT_HEIGHT, MAX_PLOT_HEIGHT)
	genome_view.set_depth_plot_height(_depth_plot_height)
	_update_window_min_height()

func _update_window_min_height() -> void:
	var reads_min_h := 24.0
	if genome_view.is_track_visible(TRACK_READS):
		reads_min_h = READS_TRACK_MIN_HEIGHT
	var tracks_h: float = genome_view.minimum_required_height(reads_min_h)
	var min_h: float = TOPBAR_MIN_HEIGHT + ROOT_VERTICAL_GAP + CONTENT_MARGIN_BOTTOM + tracks_h
	var w := get_window()
	if w != null:
		w.min_size.y = maxi(200, ceili(min_h))

func _on_track_order_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var idx := _track_order_list.get_item_at_position(_track_order_list.get_local_mouse_position(), true)
			if idx >= 0:
				_track_dragging = true
				_track_drag_index = idx
				_track_drop_index = idx
				_track_order_list.select(idx)
				_track_order_list.accept_event()
			return
		if _track_dragging:
			_apply_track_drag_drop()
			_track_order_list.accept_event()
		_track_dragging = false
		_track_drag_index = -1
		_track_drop_index = -1
	elif event is InputEventMouseMotion and _track_dragging:
		var idx := _track_order_list.get_item_at_position(_track_order_list.get_local_mouse_position(), true)
		if idx >= 0:
			_track_drop_index = idx
			_track_order_list.select(idx)

func _apply_track_drag_drop() -> void:
	if _track_drag_index < 0:
		return
	var order: PackedStringArray = genome_view.get_track_order()
	if order.is_empty() or _track_drag_index >= order.size():
		return
	var drop_idx := _track_drop_index
	if drop_idx < 0:
		var mp := _track_order_list.get_local_mouse_position()
		drop_idx = 0 if mp.y < 0.0 else _track_order_list.item_count - 1
	drop_idx = clampi(drop_idx, 0, order.size() - 1)
	if drop_idx == _track_drag_index:
		return
	var moving: String = str(order[_track_drag_index])
	order.remove_at(_track_drag_index)
	if drop_idx > _track_drag_index:
		drop_idx -= 1
	order.insert(drop_idx, moving)
	genome_view.set_track_order(order)
	_refresh_track_order_list(genome_view.get_track_order(), drop_idx)

func _refresh_track_order_list(order: PackedStringArray, select_idx: int = -1) -> void:
	_track_order_list.clear()
	for id in order:
		_track_order_list.add_item(_track_label_for_id(str(id)))
	if _track_order_list.item_count <= 0:
		return
	var idx := select_idx
	if idx < 0 or idx >= _track_order_list.item_count:
		idx = 0
	_track_order_list.select(idx)
	_refresh_track_visibility_controls(order)

func _refresh_track_visibility_controls(order: PackedStringArray) -> void:
	if _track_visibility_box == null:
		return
	for child in _track_visibility_box.get_children():
		child.queue_free()
	for id_any in order:
		var track_id := str(id_any)
		var cb := CheckBox.new()
		cb.text = "Show %s" % _track_label_for_id(track_id)
		var is_depth := track_id == TRACK_DEPTH_PLOT
		if is_depth and not _has_bam_loaded:
			genome_view.set_track_visible(track_id, false)
		cb.button_pressed = genome_view.is_track_visible(track_id)
		cb.disabled = is_depth and not _has_bam_loaded
		cb.toggled.connect(_on_track_visibility_toggled.bind(track_id))
		_track_visibility_box.add_child(cb)

func _on_track_order_changed(order: PackedStringArray) -> void:
	_refresh_track_order_list(order)
	_update_window_min_height()

func _on_track_visibility_changed(_track_id: String, _visible: bool) -> void:
	_refresh_track_visibility_controls(genome_view.get_track_order())
	_update_window_min_height()
	_invalidate_cache()
	if _current_chr_len > 0:
		_schedule_fetch()

func _on_track_visibility_toggled(checked: bool, track_id: String) -> void:
	if track_id == TRACK_DEPTH_PLOT and checked and not _has_bam_loaded:
		_set_status("Read depth plot requires BAM.", true)
		_refresh_track_visibility_controls(genome_view.get_track_order())
		return
	genome_view.set_track_visible(track_id, checked)

func _track_label_for_id(track_id: String) -> String:
	match track_id:
		"reads":
			return "Reads"
		"aa":
			return "AA / Annotation"
		"gc_plot":
			return "GC Plot"
		"depth_plot":
			return "Depth Plot"
		"genome":
			return "Genome"
		_:
			return track_id

func _on_track_settings_requested(track_id: String) -> void:
	if _track_settings_box == null:
		return
	if _track_settings_open and _active_track_settings_id == track_id and _feature_panel_open:
		_close_feature_panel()
		return
	_set_feature_labels_visible(false)
	feature_name_label.visible = true
	feature_name_label.text = "Track Settings: %s" % _track_label_for_id(track_id)
	for child in _track_settings_box.get_children():
		child.queue_free()
	_track_settings_box.visible = true
	_track_settings_open = true
	_active_track_settings_id = track_id
	match track_id:
		"reads":
			var view_label := Label.new()
			view_label.text = "Read View"
			var view_option := OptionButton.new()
			view_option.add_item("Stack", 0)
			view_option.add_item("Strand Stack", 1)
			view_option.add_item("Paired", 2)
			view_option.add_item("Fragment Size", 3)
			view_option.select(_read_view_option.selected)
			_track_settings_box.add_child(view_label)
			_track_settings_box.add_child(view_option)
			var frag_cb := CheckBox.new()
			frag_cb.text = "Log fragment Y scale"
			frag_cb.button_pressed = _fragment_log_checkbox.button_pressed
			frag_cb.visible = view_option.selected == 3
			view_option.item_selected.connect(func(index: int) -> void:
				_on_read_view_selected(index)
				frag_cb.visible = index == 3
			)
			frag_cb.toggled.connect(_on_fragment_log_toggled)
			_track_settings_box.add_child(frag_cb)
			var thickness_label := Label.new()
			thickness_label.text = "Read Thickness"
			var thickness_spin := SpinBox.new()
			thickness_spin.min_value = 2
			thickness_spin.max_value = 24
			thickness_spin.step = 1
			thickness_spin.value = _read_thickness
			thickness_spin.value_changed.connect(_on_read_thickness_changed)
			_track_settings_box.add_child(thickness_label)
			_track_settings_box.add_child(thickness_spin)
		"aa":
			var region_cb := CheckBox.new()
			region_cb.text = "Show full-length region annotations"
			region_cb.button_pressed = _show_full_length_regions
			region_cb.toggled.connect(_on_show_full_region_toggled)
			_track_settings_box.add_child(region_cb)
		"genome":
			var seq_view_label := Label.new()
			seq_view_label.text = "Sequence View"
			var seq_view_option := OptionButton.new()
			seq_view_option.add_item("Concatenate", SEQ_VIEW_CONCAT)
			seq_view_option.add_item("Single Sequence", SEQ_VIEW_SINGLE)
			seq_view_option.select(_seq_view_mode)
			_track_settings_box.add_child(seq_view_label)
			_track_settings_box.add_child(seq_view_option)
			var seq_label := Label.new()
			seq_label.text = "Sequence"
			var seq_option := OptionButton.new()
			for i in range(_seq_option.item_count):
				seq_option.add_item(_seq_option.get_item_text(i), _seq_option.get_item_id(i))
			if _selected_seq_id >= 0:
				for i in range(seq_option.item_count):
					if seq_option.get_item_id(i) == _selected_seq_id:
						seq_option.select(i)
						break
			seq_option.visible = _seq_view_mode == SEQ_VIEW_SINGLE
			seq_label.visible = seq_option.visible
			_track_settings_box.add_child(seq_label)
			_track_settings_box.add_child(seq_option)
			var gap_label := Label.new()
			gap_label.text = "Concat Gap (bp)"
			var gap_spin := SpinBox.new()
			gap_spin.min_value = 0
			gap_spin.max_value = 10000
			gap_spin.step = 10
			gap_spin.value = _concat_gap_bp
			_track_settings_box.add_child(gap_label)
			_track_settings_box.add_child(gap_spin)
			var colorize_cb := CheckBox.new()
			colorize_cb.text = "Color nucleotides by base"
			colorize_cb.button_pressed = _colorize_nucleotides
			colorize_cb.toggled.connect(_on_colorize_nucleotides_toggled)
			_track_settings_box.add_child(colorize_cb)
			seq_view_option.item_selected.connect(func(index: int) -> void:
				_on_seq_view_selected(index)
				var single := index == SEQ_VIEW_SINGLE
				seq_option.visible = single
				seq_label.visible = single
			)
			seq_option.item_selected.connect(func(index: int) -> void:
				if index < 0 or index >= seq_option.item_count:
					return
				var target_id := int(seq_option.get_item_id(index))
				for j in range(_seq_option.item_count):
					if _seq_option.get_item_id(j) == target_id:
						_seq_option.select(j)
						break
				_on_seq_selected(_seq_option.selected)
			)
			gap_spin.value_changed.connect(_on_concat_gap_changed)
		"gc_plot":
			var win_label := Label.new()
			win_label.text = "GC Window (bp)"
			var win_spin := SpinBox.new()
			win_spin.min_value = 1
			win_spin.max_value = 1000000
			win_spin.step = 1
			win_spin.value = _gc_window_bp
			win_spin.value_changed.connect(func(value: float) -> void:
				_gc_window_bp = clampi(int(value), 1, 1000000)
				_invalidate_cache()
				_schedule_fetch()
			)
			var height_label := Label.new()
			height_label.text = "Track Height (px)"
			var height_spin := SpinBox.new()
			height_spin.min_value = MIN_PLOT_HEIGHT
			height_spin.max_value = MAX_PLOT_HEIGHT
			height_spin.step = 1
			height_spin.value = _gc_plot_height
			height_spin.value_changed.connect(func(value: float) -> void:
				_gc_plot_height = value
				_apply_gc_plot_height()
			)
			var y_mode_label := Label.new()
			y_mode_label.text = "Y Scale"
			var y_mode_option := OptionButton.new()
			y_mode_option.add_item("0..1", PLOT_Y_UNIT)
			y_mode_option.add_item("Autoscale Visible", PLOT_Y_AUTOSCALE)
			y_mode_option.add_item("Fixed Min/Max", PLOT_Y_FIXED)
			y_mode_option.select(_gc_plot_y_mode)
			var y_min_label := Label.new()
			y_min_label.text = "Y Min"
			var y_min_spin := SpinBox.new()
			y_min_spin.min_value = -10.0
			y_min_spin.max_value = 10.0
			y_min_spin.step = 0.01
			y_min_spin.value = _gc_plot_y_min
			var y_max_label := Label.new()
			y_max_label.text = "Y Max"
			var y_max_spin := SpinBox.new()
			y_max_spin.min_value = -10.0
			y_max_spin.max_value = 10.0
			y_max_spin.step = 0.01
			y_max_spin.value = _gc_plot_y_max
			var fixed_visible := _gc_plot_y_mode == PLOT_Y_FIXED
			y_min_label.visible = fixed_visible
			y_min_spin.visible = fixed_visible
			y_max_label.visible = fixed_visible
			y_max_spin.visible = fixed_visible
			y_mode_option.item_selected.connect(func(index: int) -> void:
				_gc_plot_y_mode = clampi(index, PLOT_Y_UNIT, PLOT_Y_FIXED)
				var show_fixed := _gc_plot_y_mode == PLOT_Y_FIXED
				y_min_label.visible = show_fixed
				y_min_spin.visible = show_fixed
				y_max_label.visible = show_fixed
				y_max_spin.visible = show_fixed
				_apply_gc_plot_y_scale()
			)
			y_min_spin.value_changed.connect(func(value: float) -> void:
				_gc_plot_y_min = value
				_apply_gc_plot_y_scale()
			)
			y_max_spin.value_changed.connect(func(value: float) -> void:
				_gc_plot_y_max = value
				_apply_gc_plot_y_scale()
			)
			_track_settings_box.add_child(win_label)
			_track_settings_box.add_child(win_spin)
			_track_settings_box.add_child(height_label)
			_track_settings_box.add_child(height_spin)
			_track_settings_box.add_child(y_mode_label)
			_track_settings_box.add_child(y_mode_option)
			_track_settings_box.add_child(y_min_label)
			_track_settings_box.add_child(y_min_spin)
			_track_settings_box.add_child(y_max_label)
			_track_settings_box.add_child(y_max_spin)
		"depth_plot":
			if not _has_bam_loaded:
				var no_bam := Label.new()
				no_bam.text = "Load BAM to enable depth plot."
				_track_settings_box.add_child(no_bam)
			var height_label2 := Label.new()
			height_label2.text = "Track Height (px)"
			var height_spin2 := SpinBox.new()
			height_spin2.min_value = MIN_PLOT_HEIGHT
			height_spin2.max_value = MAX_PLOT_HEIGHT
			height_spin2.step = 1
			height_spin2.value = _depth_plot_height
			height_spin2.value_changed.connect(func(value: float) -> void:
				_depth_plot_height = value
				_apply_depth_plot_height()
			)
			var y_mode_label2 := Label.new()
			y_mode_label2.text = "Y Scale"
			var y_mode_option2 := OptionButton.new()
			y_mode_option2.add_item("0..1", PLOT_Y_UNIT)
			y_mode_option2.add_item("Autoscale Visible", PLOT_Y_AUTOSCALE)
			y_mode_option2.add_item("Fixed Min/Max", PLOT_Y_FIXED)
			y_mode_option2.select(_depth_plot_y_mode)
			var y_min_label2 := Label.new()
			y_min_label2.text = "Y Min"
			var y_min_spin2 := SpinBox.new()
			y_min_spin2.min_value = -10.0
			y_min_spin2.max_value = 1000000.0
			y_min_spin2.step = 1.0
			y_min_spin2.value = _depth_plot_y_min
			var y_max_label2 := Label.new()
			y_max_label2.text = "Y Max"
			var y_max_spin2 := SpinBox.new()
			y_max_spin2.min_value = -10.0
			y_max_spin2.max_value = 1000000.0
			y_max_spin2.step = 1.0
			y_max_spin2.value = _depth_plot_y_max
			var fixed_visible2 := _depth_plot_y_mode == PLOT_Y_FIXED
			y_min_label2.visible = fixed_visible2
			y_min_spin2.visible = fixed_visible2
			y_max_label2.visible = fixed_visible2
			y_max_spin2.visible = fixed_visible2
			y_mode_option2.item_selected.connect(func(index: int) -> void:
				_depth_plot_y_mode = clampi(index, PLOT_Y_UNIT, PLOT_Y_FIXED)
				var show_fixed2 := _depth_plot_y_mode == PLOT_Y_FIXED
				y_min_label2.visible = show_fixed2
				y_min_spin2.visible = show_fixed2
				y_max_label2.visible = show_fixed2
				y_max_spin2.visible = show_fixed2
				_apply_depth_plot_y_scale()
			)
			y_min_spin2.value_changed.connect(func(value: float) -> void:
				_depth_plot_y_min = value
				_apply_depth_plot_y_scale()
			)
			y_max_spin2.value_changed.connect(func(value: float) -> void:
				_depth_plot_y_max = value
				_apply_depth_plot_y_scale()
			)
			_track_settings_box.add_child(height_label2)
			_track_settings_box.add_child(height_spin2)
			_track_settings_box.add_child(y_mode_label2)
			_track_settings_box.add_child(y_mode_option2)
			_track_settings_box.add_child(y_min_label2)
			_track_settings_box.add_child(y_min_spin2)
			_track_settings_box.add_child(y_max_label2)
			_track_settings_box.add_child(y_max_spin2)
		_:
			var info := Label.new()
			info.text = "No track-specific settings yet."
			_track_settings_box.add_child(info)
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _set_feature_labels_visible(show_labels: bool) -> void:
	feature_type_label.visible = show_labels
	feature_range_label.visible = show_labels
	feature_strand_label.visible = show_labels
	feature_source_label.visible = show_labels
	feature_seq_label.visible = show_labels

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
	if not _themes_lib.has_theme(theme_name):
		return
	var palette: Dictionary = _themes_lib.palette(theme_name)
	self.theme = _themes_lib.make_theme(theme_name, UI_FONT_SIZE)
	_theme_text_color = palette["text"]
	_theme_error_color = palette["status_error"]
	background.color = palette["bg"]
	genome_view.set_palette(_themes_lib.genome_palette(theme_name))
	feature_name_label.add_theme_color_override("default_color", palette["text"])
	feature_type_label.add_theme_color_override("default_color", palette["text"])
	feature_range_label.add_theme_color_override("default_color", palette["text"])
	feature_strand_label.add_theme_color_override("default_color", palette["text"])
	feature_source_label.add_theme_color_override("default_color", palette["text"])
	feature_seq_label.add_theme_color_override("default_color", palette["text"])
	status_message_label.add_theme_color_override("font_color", palette["text"])

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
		_center_strand_scroll_pending = true
		genome_view.set_track_visible(TRACK_READS, true)
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
	var show_reads: bool = bool(genome_view.is_track_visible(TRACK_READS))
	var show_aa: bool = bool(genome_view.is_track_visible(TRACK_AA))
	var show_gc_plot: bool = bool(genome_view.is_track_visible(TRACK_GC_PLOT))
	var show_depth_plot: bool = bool(genome_view.is_track_visible(TRACK_DEPTH_PLOT))
	var show_genome: bool = bool(genome_view.is_track_visible(TRACK_GENOME))
	var need_reference: bool = show_aa or show_genome
	var span: int = maxi(1, _last_end - _last_start)
	var right_span_mult := 3 if _auto_play_enabled else 1
	var query_start: int = maxi(0, _last_start - span)
	var query_end: int = mini(_current_chr_len, _last_end + span * right_span_mult)
	var all_reads: Array[Dictionary] = []
	var all_coverage_tiles: Array[Dictionary] = []
	var all_gc_plot_tiles: Array[Dictionary] = []
	var all_depth_plot_tiles: Array[Dictionary] = []
	var features: Array[Dictionary] = []
	var ref_start := query_start
	var ref_sequence := ""

	if _seq_view_mode == SEQ_VIEW_SINGLE:
		if _has_bam_loaded and show_reads:
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
		if show_gc_plot:
			var zoom_plot := _compute_tile_zoom(_last_bp_per_px)
			var tile_width_plot := 1024 << zoom_plot
			var tile_start_plot := int(floor(float(query_start) / float(tile_width_plot)))
			var tile_end_plot := int(floor(float(query_end) / float(tile_width_plot)))
			for t in range(tile_start_plot, tile_end_plot + 1):
				var plot_resp: Dictionary = _zem.get_gc_plot_tile(_current_chr_id, zoom_plot, t, _gc_window_bp)
				if not plot_resp.get("ok", false):
					_set_status("GC plot query failed: %s" % plot_resp.get("error", "error"), true)
					return
				all_gc_plot_tiles.append(plot_resp.get("plot", {}))
		if show_depth_plot and _has_bam_loaded:
			var zoom_plot := _compute_tile_zoom(_last_bp_per_px)
			var tile_width_plot := 1024 << zoom_plot
			var tile_start_plot := int(floor(float(query_start) / float(tile_width_plot)))
			var tile_end_plot := int(floor(float(query_end) / float(tile_width_plot)))
			for t in range(tile_start_plot, tile_end_plot + 1):
				var cov_resp_plot: Dictionary = _zem.get_coverage_tile(_current_chr_id, zoom_plot, t)
				if not cov_resp_plot.get("ok", false):
					_set_status("Depth query failed: %s" % cov_resp_plot.get("error", "error"), true)
					return
				all_depth_plot_tiles.append(_coverage_to_plot_tile(cov_resp_plot.get("coverage", {})))

		if show_aa:
			var ann_resp := _get_annotations_window_paged(_current_chr_id, query_start, query_end)
			if not ann_resp.get("ok", false):
				_set_status("Annotation query failed: %s" % ann_resp.get("error", "error"), true)
				return
			features = ann_resp.get("features", [])

		if need_reference:
			var ref_resp: Dictionary = _zem.get_reference_slice(_current_chr_id, query_start, query_end)
			if not ref_resp.get("ok", false):
				_set_status("Reference query failed: %s" % ref_resp.get("error", "error"), true)
				return
			ref_start = int(ref_resp.get("slice_start", query_start))
			ref_sequence = str(ref_resp.get("sequence", ""))
	else:
		var overlaps := _segments_overlapping(query_start, query_end)
		var ann_overlaps := _segments_overlapping(query_start, query_end) if show_aa else ([] as Array[Dictionary])
		var zoom := _compute_tile_zoom(_last_bp_per_px)
		for ov in overlaps:
			var chr_id := int(ov["id"])
			var offset := int(ov["offset"])
			var local_start := int(ov["local_start"])
			var local_end := int(ov["local_end"])
			if _has_bam_loaded and show_reads:
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
			if show_gc_plot:
				var tile_width_plot := 1024 << zoom
				var tile_start_plot := int(floor(float(local_start) / float(tile_width_plot)))
				var tile_end_plot := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width_plot)))
				for t in range(tile_start_plot, tile_end_plot + 1):
					var plot_resp: Dictionary = _zem.get_gc_plot_tile(chr_id, zoom, t, _gc_window_bp)
					if not plot_resp.get("ok", false):
						_set_status("GC plot query failed: %s" % plot_resp.get("error", "error"), true)
						return
					all_gc_plot_tiles.append(_shift_plot_coords(plot_resp.get("plot", {}), offset))
			if show_depth_plot and _has_bam_loaded:
				var tile_width_plot := 1024 << zoom
				var tile_start_plot := int(floor(float(local_start) / float(tile_width_plot)))
				var tile_end_plot := int(floor(float(maxi(local_end - 1, local_start)) / float(tile_width_plot)))
				for t in range(tile_start_plot, tile_end_plot + 1):
					var cov_resp_plot: Dictionary = _zem.get_coverage_tile(chr_id, zoom, t)
					if not cov_resp_plot.get("ok", false):
						_set_status("Depth query failed: %s" % cov_resp_plot.get("error", "error"), true)
						return
					var shifted_cov_plot := _shift_coverage_coords(cov_resp_plot.get("coverage", {}), offset)
					all_depth_plot_tiles.append(_coverage_to_plot_tile(shifted_cov_plot))

		for aov in ann_overlaps:
			var a_chr_id := int(aov["id"])
			var a_offset := int(aov["offset"])
			var a_local_start := int(aov["local_start"])
			var a_local_end := int(aov["local_end"])
			var ann_resp_part := _get_annotations_window_paged(a_chr_id, a_local_start, a_local_end)
			if not ann_resp_part.get("ok", false):
				_set_status("Annotation query failed: %s" % ann_resp_part.get("error", "error"), true)
				return
			for f in ann_resp_part.get("features", []):
				features.append(_shift_feature_coords(f, a_offset))

		if need_reference:
			ref_sequence = _build_concat_reference(query_start, query_end, overlaps)

	genome_view.set_reads(all_reads)
	genome_view.set_coverage_tiles(all_coverage_tiles)
	genome_view.set_gc_plot_tiles(all_gc_plot_tiles)
	genome_view.set_depth_plot_tiles(all_depth_plot_tiles)
	genome_view.set_features(features)
	genome_view.set_reference_slice(ref_start, ref_sequence)
	if _center_strand_scroll_pending and _read_view_option.selected == 1 and all_reads.size() > 0:
		genome_view.center_strand_scroll()
		_center_strand_scroll_pending = false
	_cache_start = query_start
	_cache_end = query_end
	_cache_zoom = _compute_tile_zoom(_last_bp_per_px)
	_cache_mode = 0 if (_has_bam_loaded and _cache_zoom <= READ_DETAIL_MAX_ZOOM) else 1
	_cache_scope_key = _scope_cache_key()

func _get_annotations_window_paged(chr_id: int, start_bp: int, end_bp: int) -> Dictionary:
	if end_bp <= start_bp:
		return {"ok": true, "features": []}
	var span := end_bp - start_bp
	var chunk_count := clampi(int(ceil(float(span) / float(ANNOT_CHUNK_TARGET_BP))), 1, ANNOT_MAX_CHUNKS)
	var chunk_span := maxi(1, int(ceil(float(span) / float(chunk_count))))
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	for i in range(chunk_count):
		var chunk_start := start_bp + i * chunk_span
		if chunk_start >= end_bp:
			break
		var chunk_end := mini(end_bp, chunk_start + chunk_span)
		var resp: Dictionary = _zem.get_annotations(chr_id, chunk_start, chunk_end, ANNOT_MAX_PER_CHUNK)
		if not resp.get("ok", false):
			return resp
		for f in resp.get("features", []):
			var feat: Dictionary = f
			var key := _feature_dedupe_key(feat)
			if seen.get(key, false):
				continue
			seen[key] = true
			out.append(feat)
			if out.size() >= ANNOT_MAX_TOTAL:
				out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
					var sa := int(a.get("start", 0))
					var sb := int(b.get("start", 0))
					if sa == sb:
						return int(a.get("end", sa)) < int(b.get("end", sb))
					return sa < sb
				)
				return {"ok": true, "features": out}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("start", 0))
		var sb := int(b.get("start", 0))
		if sa == sb:
			return int(a.get("end", sa)) < int(b.get("end", sb))
		return sa < sb
	)
	return {"ok": true, "features": out}

func _feature_dedupe_key(feature: Dictionary) -> String:
	return "%d|%d|%s|%s|%s|%s" % [
		int(feature.get("start", 0)),
		int(feature.get("end", 0)),
		str(feature.get("strand", ".")),
		str(feature.get("type", "")),
		str(feature.get("name", "")),
		str(feature.get("source", ""))
	]

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

func _shift_plot_coords(plot: Dictionary, offset: int) -> Dictionary:
	if plot.is_empty():
		return plot
	return {
		"start": int(plot.get("start", 0)) + offset,
		"end": int(plot.get("end", 0)) + offset,
		"window": int(plot.get("window", _gc_window_bp)),
		"values": plot.get("values", PackedFloat32Array())
	}

func _coverage_to_plot_tile(cov: Dictionary) -> Dictionary:
	if cov.is_empty():
		return {}
	var bins: PackedInt32Array = cov.get("bins", PackedInt32Array())
	var values := PackedFloat32Array()
	values.resize(bins.size())
	for i in range(bins.size()):
		values[i] = float(bins[i])
	return {
		"start": int(cov.get("start", 0)),
		"end": int(cov.get("end", 0)),
		"window": 1,
		"values": values
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
	status_message_label.add_theme_color_override("font_color", _theme_error_color if is_error else _theme_text_color)

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
	_colorize_nucleotides = bool(cfg.get_value("ui", "colorize_nucleotides", true))
	genome_view.set_colorize_nucleotides(_colorize_nucleotides)
	_gc_window_bp = int(cfg.get_value("ui", "gc_window_bp", DEFAULT_GC_WINDOW_BP))
	_gc_window_bp = clampi(_gc_window_bp, 1, 1000000)
	_gc_plot_y_mode = clampi(int(cfg.get_value("ui", "gc_plot_y_mode", PLOT_Y_UNIT)), PLOT_Y_UNIT, PLOT_Y_FIXED)
	_gc_plot_y_min = float(cfg.get_value("ui", "gc_plot_y_min", 0.0))
	_gc_plot_y_max = float(cfg.get_value("ui", "gc_plot_y_max", 1.0))
	_apply_gc_plot_y_scale()
	_depth_plot_y_mode = clampi(int(cfg.get_value("ui", "depth_plot_y_mode", PLOT_Y_AUTOSCALE)), PLOT_Y_UNIT, PLOT_Y_FIXED)
	_depth_plot_y_min = float(cfg.get_value("ui", "depth_plot_y_min", 0.0))
	_depth_plot_y_max = float(cfg.get_value("ui", "depth_plot_y_max", 100.0))
	_apply_depth_plot_y_scale()
	var frag_log := bool(cfg.get_value("ui", "fragment_log_scale", false))
	_fragment_log_checkbox.button_pressed = frag_log
	genome_view.set_fragment_log_scale(frag_log)
	_refresh_track_order_list(genome_view.get_track_order())

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
	cfg.set_value("ui", "colorize_nucleotides", _colorize_nucleotides)
	cfg.set_value("ui", "gc_window_bp", _gc_window_bp)
	cfg.set_value("ui", "gc_plot_y_mode", _gc_plot_y_mode)
	cfg.set_value("ui", "gc_plot_y_min", _gc_plot_y_min)
	cfg.set_value("ui", "gc_plot_y_max", _gc_plot_y_max)
	cfg.set_value("ui", "depth_plot_y_mode", _depth_plot_y_mode)
	cfg.set_value("ui", "depth_plot_y_min", _depth_plot_y_min)
	cfg.set_value("ui", "depth_plot_y_max", _depth_plot_y_max)
	cfg.set_value("ui", "fragment_log_scale", _fragment_log_checkbox.button_pressed)
	cfg.set_value("input", "trackpad_pan_sensitivity", trackpad_pan_slider.value)
	cfg.set_value("input", "trackpad_pinch_sensitivity", trackpad_pinch_slider.value)
	cfg.save(CONFIG_PATH)

func _on_feature_clicked(feature: Dictionary) -> void:
	_track_settings_open = false
	_active_track_settings_id = ""
	_set_feature_labels_visible(true)
	if _track_settings_box != null:
		_track_settings_box.visible = false
	feature_name_label.text = "Name: %s" % str(feature.get("name", "-"))
	feature_type_label.text = "Type: %s" % str(feature.get("type", "-"))
	feature_range_label.text = "Range: %d - %d" % [int(feature.get("start", 0)), int(feature.get("end", 0))]
	feature_strand_label.text = "Strand: %s" % str(feature.get("strand", "."))
	var feature_id := str(feature.get("id", "")).strip_edges()
	if feature_id.is_empty():
		feature_source_label.text = "Source: %s" % str(feature.get("source", "-"))
	else:
		feature_source_label.text = "Source: %s | ID=%s" % [str(feature.get("source", "-")), feature_id]
	feature_seq_label.text = "Sequence: %s" % str(feature.get("seq_name", _current_chr_name))
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _on_read_clicked(read: Dictionary) -> void:
	_track_settings_open = false
	_active_track_settings_id = ""
	_set_feature_labels_visible(true)
	if _track_settings_box != null:
		_track_settings_box.visible = false
	var read_name := str(read.get("name", ""))
	if read_name.is_empty():
		read_name = "(unnamed)"
	var start_bp := int(read.get("start", 0))
	var end_bp := int(read.get("end", start_bp))
	var read_len := maxi(0, end_bp - start_bp)
	var cigar := str(read.get("cigar", ""))
	if cigar.is_empty():
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
	var snp_text := _format_read_snps(read.get("snps", PackedInt32Array()) as PackedInt32Array)
	feature_name_label.text = "Read: %s" % read_name
	feature_type_label.text = "Range: %d - %d (%d bp)" % [start_bp, end_bp, read_len]
	feature_range_label.text = "CIGAR: %s" % cigar
	feature_strand_label.text = "Strand: %s | MAPQ: %d | Flags: %d" % [strand, mapq, flags]
	feature_source_label.text = "%s | Fragment: %d bp" % [mate_text, frag_len]
	feature_seq_label.text = "SNPs: %s" % snp_text
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _format_read_snps(snps: PackedInt32Array) -> String:
	if snps.is_empty():
		return "none"
	var parts: Array[String] = []
	var limit := mini(12, snps.size())
	for i in range(limit):
		parts.append(str(int(snps[i])))
	if snps.size() > limit:
		parts.append("...")
	return "%d [%s]" % [snps.size(), ", ".join(parts)]

func _close_feature_panel() -> void:
	_feature_panel_open = false
	_track_settings_open = false
	_active_track_settings_id = ""
	if _track_settings_box != null:
		_track_settings_box.visible = false
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
