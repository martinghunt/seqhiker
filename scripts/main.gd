extends Control

const ThemesLibScript = preload("res://scripts/themes.gd")
const ZemClientScript = preload("res://scripts/zem_client.gd")
const TileControllerScript = preload("res://scripts/tile_controller.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")
const CONFIG_PATH := "user://seqhiker_settings.cfg"
const ZEM_BIN_SUBDIR := "bin"
const ZEM_DEFAULT_PORT := 9000
const READ_DETAIL_MAX_ZOOM := 7
const READ_RENDER_MAX_BP_PER_PX := 128.0
const DEFAULT_CONCAT_GAP_BP := 50
const DEFAULT_READ_THICKNESS := 8.0
const DEFAULT_READ_MAX_ROWS := 500
const ANNOT_TILE_BASE_BP := 1024
const ANNOT_MAX_TILES := 64
const ANNOT_MIN_TOTAL := 800
const ANNOT_MAX_TOTAL := 12000
const ANNOT_TILE_CACHE_MAX_ENTRIES := 512
const BAM_COV_PRECOMPUTE_CUTOFF_DEFAULT := 15000000
const ANNOT_MAX_ON_SCREEN_DEFAULT := 4400
const ANNOT_MAX_ON_SCREEN_MIN := 200
const ANNOT_MAX_ON_SCREEN_MAX := 50000
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
const ROOT_VERTICAL_GAP := 8.0
const CONTENT_MARGIN_BOTTOM := 10.0
const READS_TRACK_MIN_HEIGHT := 140.0
const DEFAULT_UI_FONT_SIZE := 15
const MIN_UI_FONT_SIZE := 9
const MAX_UI_FONT_SIZE := 24
const DEPTH_SERIES_COLORS := [
	Color("345995"),
	Color("2a9d8f"),
	Color("e76f51"),
	Color("6d597a"),
	Color("4f772d"),
	Color("b56576")
]
const FILE_LIST_PLACEHOLDER := "none"
const VIEW_SLOT_COUNT := 9
const VIEW_SLOT_LOAD_ACTION_PREFIX := "seqhiker_view_slot_load_"
const VIEW_SLOT_SAVE_ACTION_PREFIX := "seqhiker_view_slot_save_"
@onready var background: ColorRect = $Background
@onready var genome_view: Control = $Root/ContentMargin/ViewportLayer/GenomeView
@onready var settings_panel: PanelContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel
@onready var top_bar: HBoxContainer = $Root/TopBar
@onready var settings_toggle_button: Button = $Root/TopBar/SettingsToggleButton
@onready var search_button: Button = $Root/TopBar/ActionClipper/ActionStrip/SearchButton
@onready var pan_left_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PanLeftButton
@onready var jump_start_button: Button = $Root/TopBar/ActionClipper/ActionStrip/JumpStartButton
@onready var pan_right_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PanRightButton
@onready var jump_end_button: Button = $Root/TopBar/ActionClipper/ActionStrip/JumpEndButton
@onready var zoom_out_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ZoomOutButton
@onready var zoom_in_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ZoomInButton
@onready var play_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PlayButton
@onready var play_left_button: Button = $Root/TopBar/ActionClipper/ActionStrip/PlayLeftButton
@onready var stop_button: Button = $Root/TopBar/ActionClipper/ActionStrip/StopButton
@onready var viewport_label: Label = $Root/TopBar/ActionClipper/ActionStrip/ViewportLabel
@onready var server_status_label: Label = $Root/TopBar/ActionClipper/ActionStrip/ServerStatusLabel
@onready var feature_panel: PanelContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel
@onready var feature_close_button: Button = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureHeader/FeatureCloseButton
@onready var feature_title_label: Label = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureHeader/FeatureTitle
@onready var feature_name_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureNameLabel
@onready var feature_type_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureTypeLabel
@onready var feature_range_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureRangeLabel
@onready var feature_strand_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureStrandLabel
@onready var feature_source_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureSourceLabel
@onready var feature_seq_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent/FeatureSeqLabel
@onready var feature_content: VBoxContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeatureContent
@onready var ui_scale_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/UIScaleSlider
@onready var ui_scale_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/UIScaleValue
@onready var _font_size_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/FontSizeSpin
@onready var trackpad_pan_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPanSlider
@onready var trackpad_pan_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPanValue
@onready var trackpad_pinch_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPinchSlider
@onready var trackpad_pinch_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackpadPinchValue
@onready var pan_step_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PanStepSlider
@onready var pan_step_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PanStepValue
@onready var play_speed_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PlaySpeedSlider
@onready var play_speed_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PlaySpeedValue
@onready var theme_option: OptionButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ThemeOption
@onready var settings_content: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent
@onready var file_list: ItemList = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/FileList
@onready var _track_order_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackVisibilityLabel
@onready var _track_visibility_box: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/TrackVisibilityBox
@onready var _bam_cov_cutoff_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/BAMCoverageCutoffSpin
@onready var server_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ServerLabel
@onready var host_edit: LineEdit = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/HostEdit
@onready var port_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PortLabel
@onready var port_edit: LineEdit = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/PortEdit
@onready var connect_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ConnectButton
@onready var status_title_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/StatusTitle
@onready var status_message_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/StatusMessageLabel
@onready var server_separator: HSeparator = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsContent/ServerSeparator
@onready var close_settings_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsHeader/CloseSettingsButton

var _settings_open := false
var _settings_tween: Tween
var _feature_panel_open := false
var _feature_tween: Tween
var _fetch_timer: Timer
var _fetch_in_progress := false
var _fetch_pending := false
var _tile_fetch_serial := 0
var _tile_cache_generation := 0
var _pending_tile_apply: Dictionary = {}

var _zem: RefCounted
var _tile_controller: RefCounted
var _search_controller: RefCounted
var _local_zem_path := ""
var _local_zem_pid := -1
var _local_zem_started_by_seqhiker := false
var _local_zem_install_checked := false
var _last_connect_error := ""
var _current_chr_id := -1
var _current_chr_name := ""
var _current_chr_len := 0
var _last_start := 0
var _last_end := 0
var _last_bp_per_px := 8.0
var _selection_active := false
var _selection_start := 0
var _selection_end := 0
var _has_bam_loaded := false
var _bam_tracks: Array[Dictionary] = []
var _bam_track_serial := 0
var _center_strand_scroll_pending := false
var _has_fasta_loaded := false
var _pending_annotation_highlight: Dictionary = {}
var _cache_start := -1
var _cache_end := -1
var _cache_zoom := -1
var _cache_mode := -1
var _cache_need_reference := false
var _cache_scope_key := ""
var _annotation_tile_cache: Dictionary = {}
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
var _track_order_list: ItemList
var _read_mate_jump_button: Button
var _read_mate_jump_start := -1
var _read_mate_jump_end := -1
var _ui_font_size := DEFAULT_UI_FONT_SIZE
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
var _axis_coords_with_commas := false
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
var _debug_enabled := false
var _debug_toggle: CheckBox
var _debug_stats_label: Label
var _bam_cov_precompute_cutoff_bp := BAM_COV_PRECOMPUTE_CUTOFF_DEFAULT
var _annotation_max_on_screen := ANNOT_MAX_ON_SCREEN_DEFAULT
var _annotation_counts_by_chr := {}
var _dbg_ann_tile_requests := 0
var _dbg_ann_tile_cache_hits := 0
var _dbg_ann_tile_queries := 0
var _dbg_ann_features_examined := 0
var _dbg_ann_features_out := 0
var _dbg_ann_fetch_time_ms := 0.0
var _last_status_message := "Disconnected"
var _last_status_is_error := false
var _last_viewport_message := "0 - 0 bp  |  0 bp visible"
var _last_bp_per_px_message := "0.00 bp/px"
var _view_slots: Dictionary = {}
var _view_slot_shortcut_buttons: Array[Button] = []
var _pan_step_percent := 75.0

func _ready() -> void:
	_zem = ZemClientScript.new()
	_tile_controller = TileControllerScript.new()
	_search_controller = SearchControllerScript.new()
	_tile_controller.configure(Callable(self, "_compute_tile_zoom"))
	_themes_lib = ThemesLibScript.new()
	_disable_button_focus()
	_setup_theme_selector()
	_setup_font_size_control()
	_setup_read_view_controls()
	_setup_sequence_controls()
	_setup_track_visibility_controls()
	_sync_bam_read_tracks()
	_setup_debug_controls()
	_setup_track_settings_panel()
	_connect_ui()
	_hide_server_settings_section()
	_refresh_file_list_ui()
	_load_or_init_config()
	_apply_gc_plot_y_scale()
	_apply_depth_plot_y_scale()
	_apply_gc_plot_height()
	_apply_depth_plot_height()
	_update_window_min_height()
	_apply_theme(theme_option.get_item_text(theme_option.selected))
	_on_ui_scale_changed(ui_scale_slider.value)
	_on_trackpad_pan_changed(trackpad_pan_slider.value)
	_on_trackpad_pinch_changed(trackpad_pinch_slider.value)
	_on_pan_step_changed(pan_step_slider.value)
	_on_play_speed_changed(play_speed_slider.value)
	_setup_fetch_timer()
	_setup_view_slot_shortcuts()
	if server_status_label != null:
		server_status_label.visible = false
	if viewport_label != null:
		viewport_label.visible = true
	call_deferred("_initialize_settings_panel")
	call_deferred("_startup_connect_local_zem")
	if get_window().has_signal("files_dropped"):
		get_window().files_dropped.connect(_on_files_dropped)

func _initialize_settings_panel() -> void:
	_set_status("Disconnected")
	_slide_settings(false, false)
	_slide_feature_panel(false, false)

func _startup_connect_local_zem() -> void:
	var host := host_edit.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(port_edit.text)
	if port <= 0:
		port = ZEM_DEFAULT_PORT
	if not _should_try_local_zem(host):
		return
	_set_status("Preparing local zem...")
	await get_tree().process_frame
	if not _ensure_local_zem_installed():
		if not _last_connect_error.is_empty():
			_set_status(_last_connect_error, true)
		else:
			_set_status("Local zem missing and install failed.", true)
		return
	_set_status("Starting local zem...")
	await get_tree().process_frame
	# Keep startup connect snappy so first frame/UI does not stall.
	if _connect_with_local_fallback(host, port, 100, 2, 80):
		_set_status("Connected %s:%d" % [host, port])
	elif not _last_connect_error.is_empty():
		_set_status(_last_connect_error, true)

func _setup_fetch_timer() -> void:
	_fetch_timer = Timer.new()
	_fetch_timer.one_shot = true
	_fetch_timer.wait_time = 0.08
	_fetch_timer.timeout.connect(_on_fetch_timer_timeout)
	add_child(_fetch_timer)

func _hide_server_settings_section() -> void:
	server_label.visible = false
	host_edit.visible = false
	port_label.visible = false
	port_edit.visible = false
	connect_button.visible = false
	status_title_label.visible = false
	status_message_label.visible = false
	server_separator.visible = false

func _setup_theme_selector() -> void:
	theme_option.clear()
	for theme_name in _themes_lib.theme_names():
		theme_option.add_item(theme_name)
	for i in range(theme_option.item_count):
		if theme_option.get_item_text(i) == "Light":
			theme_option.select(i)
			break

func _setup_font_size_control() -> void:
	_font_size_spin.min_value = MIN_UI_FONT_SIZE
	_font_size_spin.max_value = MAX_UI_FONT_SIZE
	_font_size_spin.step = 1
	_font_size_spin.value = _ui_font_size
	if not _font_size_spin.value_changed.is_connected(_on_font_size_changed):
		_font_size_spin.value_changed.connect(_on_font_size_changed)

func _connect_ui() -> void:
	settings_toggle_button.pressed.connect(_toggle_settings)
	close_settings_button.pressed.connect(_close_settings)
	connect_button.pressed.connect(_connect_server)
	pan_left_button.pressed.connect(func() -> void: genome_view.pan_by_fraction(-_pan_step_percent / 100.0))
	jump_start_button.pressed.connect(func() -> void: genome_view.jump_to_start())
	pan_right_button.pressed.connect(func() -> void: genome_view.pan_by_fraction(_pan_step_percent / 100.0))
	jump_end_button.pressed.connect(func() -> void: genome_view.jump_to_end())
	zoom_in_button.pressed.connect(func() -> void: genome_view.zoom_by(0.78))
	zoom_out_button.pressed.connect(func() -> void: genome_view.zoom_by(1.28))
	play_button.pressed.connect(_start_auto_play)
	play_left_button.pressed.connect(_start_auto_play_left)
	stop_button.pressed.connect(_stop_auto_play)
	search_button.pressed.connect(_toggle_search_panel)
	genome_view.viewport_changed.connect(_on_viewport_changed)
	genome_view.feature_clicked.connect(_on_feature_clicked)
	genome_view.read_clicked.connect(_on_read_clicked)
	genome_view.region_selection_changed.connect(_on_region_selection_changed)
	genome_view.track_settings_requested.connect(_on_track_settings_requested)
	genome_view.track_order_changed.connect(_on_track_order_changed)
	genome_view.track_visibility_changed.connect(_on_track_visibility_changed)
	ui_scale_slider.value_changed.connect(_on_ui_scale_value_changed)
	ui_scale_slider.drag_ended.connect(_on_ui_scale_drag_ended)
	trackpad_pan_slider.value_changed.connect(_on_trackpad_pan_changed)
	trackpad_pinch_slider.value_changed.connect(_on_trackpad_pinch_changed)
	pan_step_slider.value_changed.connect(_on_pan_step_changed)
	play_speed_slider.value_changed.connect(_on_play_speed_changed)
	theme_option.item_selected.connect(_on_theme_selected)
	feature_close_button.pressed.connect(_close_feature_panel)
	_show_full_region_checkbox.toggled.connect(_on_show_full_region_toggled)
	if _track_order_list != null:
		_track_order_list.gui_input.connect(_on_track_order_list_gui_input)
	_seq_view_option.item_selected.connect(_on_seq_view_selected)
	_seq_option.item_selected.connect(_on_seq_selected)
	_concat_gap_spin.value_changed.connect(_on_concat_gap_changed)

func _disable_button_focus() -> void:
	var controls := [
		settings_toggle_button,
		search_button,
		pan_left_button,
		jump_start_button,
		pan_right_button,
		jump_end_button,
		zoom_out_button,
		zoom_in_button,
		play_button,
		play_left_button,
		stop_button,
		connect_button,
		close_settings_button,
		feature_close_button,
		ui_scale_slider,
		trackpad_pan_slider,
		trackpad_pinch_slider,
		pan_step_slider,
		play_speed_slider
	]
	for c in controls:
		if c != null:
			c.focus_mode = Control.FOCUS_NONE

func _connect_server() -> void:
	var host := host_edit.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(port_edit.text)
	if port <= 0:
		port = ZEM_DEFAULT_PORT
	var ok: bool = _connect_with_local_fallback(host, port)
	if ok:
		_set_status("Connected %s:%d" % [host, port])
		_refresh_chromosomes()
	else:
		var msg := "Connection failed"
		if not _last_connect_error.is_empty():
			msg = _last_connect_error
		_set_status(msg, true)

func _on_viewport_changed(start_bp: int, end_bp: int, bp_per_px: float) -> void:
	_last_start = start_bp
	_last_end = end_bp
	_last_bp_per_px = bp_per_px
	_last_viewport_message = _format_viewport_label(start_bp, end_bp, bp_per_px)
	_last_bp_per_px_message = "%.2f bp/px" % bp_per_px
	viewport_label.text = _last_viewport_message
	if _debug_enabled:
		_update_debug_stats_label()
	var show_aa: bool = bool(genome_view.is_track_visible(TRACK_AA))
	var show_genome: bool = bool(genome_view.is_track_visible(TRACK_GENOME))
	var need_reference: bool = bool(genome_view.needs_reference_data(show_aa, show_genome))
	if genome_view.is_zoom_animating():
		if need_reference and not _cache_need_reference:
			_schedule_fetch()
		return
	if _current_chr_len > 0:
		var zoom := _compute_tile_zoom(bp_per_px)
		var mode := 0 if (_has_bam_loaded and _any_visible_read_track() and bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
		var needs_fetch := not _is_viewport_cached(start_bp, end_bp, zoom, mode, need_reference, _scope_cache_key())
		if _is_near_cache_edge(start_bp, end_bp):
			needs_fetch = true
		if needs_fetch:
			_schedule_fetch()

func _format_viewport_label(start_bp: int, end_bp: int, _bp_per_px: float) -> String:
	var coord_start := start_bp
	var coord_end := end_bp
	var span_bp := maxi(0, end_bp - start_bp)
	var span_text := "visible"
	if _selection_active:
		coord_start = _selection_start
		coord_end = _selection_end
		span_bp = maxi(0, _selection_end - _selection_start + 1)
		span_text = "selected"
	if _seq_view_mode != SEQ_VIEW_CONCAT:
		return "%s:%d - %d bp  |  %d bp %s" % [_current_chr_name, coord_start, coord_end, span_bp, span_text]
	var overlaps := _segments_overlapping(coord_start, coord_end)
	if overlaps.is_empty():
		return "concat:%d - %d bp  |  %d bp %s" % [coord_start, coord_end, span_bp, span_text]
	if overlaps.size() == 1:
		var seg := overlaps[0]
		return "%s:%d - %d bp  |  %d bp %s" % [
			str(seg.get("name", "chr")),
			int(seg.get("local_start", 0)),
			int(seg.get("local_end", 0)),
			span_bp, span_text
		]
	var first := overlaps[0]
	var last := overlaps[overlaps.size() - 1]
	var prefix := "%s:%d-%d | %s:%d-%d" % [
		str(first.get("name", "chr")),
		int(first.get("local_start", 0)),
		int(first.get("local_end", 0)),
		str(last.get("name", "chr")),
		int(last.get("local_start", 0)),
		int(last.get("local_end", 0))
	]
	if overlaps.size() > 2:
		prefix += " (+%d)" % (overlaps.size() - 2)
	return "%s  |  %d bp %s" % [prefix, span_bp, span_text]

func _on_region_selection_changed(active: bool, start_bp: int, end_bp: int) -> void:
	_selection_active = active
	if active:
		_selection_start = mini(start_bp, end_bp)
		_selection_end = maxi(start_bp, end_bp)
	else:
		_selection_start = 0
		_selection_end = 0
	_last_viewport_message = _format_viewport_label(_last_start, _last_end, _last_bp_per_px)
	viewport_label.text = _last_viewport_message
	if _debug_enabled:
		_update_debug_stats_label()

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
	var closed_x: float = -float(ceili(panel_w)) - 2.0
	var target_x: float = 0.0 if open else closed_x
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
	var closed_w: float = float(ceili(panel_w)) + 2.0
	var target_left: float = -panel_w if open else 0.0
	var target_right: float = 0.0 if open else closed_w
	if animated:
		_feature_tween = create_tween()
		_feature_tween.set_trans(Tween.TRANS_CUBIC)
		_feature_tween.set_ease(Tween.EASE_OUT)
		_feature_tween.parallel().tween_property(feature_panel, "offset_left", target_left, 0.24)
		_feature_tween.parallel().tween_property(feature_panel, "offset_right", target_right, 0.24)
	else:
		feature_panel.offset_left = target_left
		feature_panel.offset_right = target_right

func _on_ui_scale_value_changed(value: float) -> void:
	ui_scale_value.text = "%.2fx" % value

func _on_ui_scale_drag_ended(_value_changed: bool) -> void:
	_on_ui_scale_changed(ui_scale_slider.value)

func _on_ui_scale_changed(value: float) -> void:
	get_window().content_scale_factor = value
	ui_scale_value.text = "%.2fx" % value

func _on_trackpad_pan_changed(value: float) -> void:
	trackpad_pan_value.text = "%.2fx" % value
	genome_view.set_trackpad_pan_sensitivity(value)

func _on_trackpad_pinch_changed(value: float) -> void:
	trackpad_pinch_value.text = "%.2fx" % value
	genome_view.set_trackpad_pinch_sensitivity(value)

func _on_pan_step_changed(value: float) -> void:
	_pan_step_percent = clampf(value, 1.0, 100.0)
	if pan_step_slider != null and absf(pan_step_slider.value - _pan_step_percent) > 0.0001:
		pan_step_slider.value = _pan_step_percent
	pan_step_value.text = "%d%%" % int(round(_pan_step_percent))

func _on_play_speed_changed(value: float) -> void:
	play_speed_value.text = "%.2f widths/s" % value

func _on_font_size_changed(value: float) -> void:
	_ui_font_size = clampi(int(round(value)), MIN_UI_FONT_SIZE, MAX_UI_FONT_SIZE)
	if _font_size_spin != null and int(_font_size_spin.value) != _ui_font_size:
		_font_size_spin.value = _ui_font_size
	_apply_theme(theme_option.get_item_text(theme_option.selected))

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
	_fragment_log_checkbox.button_pressed = true
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
	genome_view.set_fragment_log_scale(true)
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

func _setup_track_visibility_controls() -> void:
	_track_order_label.text = "Track Visibility"
	_track_visibility_box.add_theme_constant_override("separation", 4)
	_refresh_track_visibility_controls(genome_view.get_track_order())

func _setup_debug_controls() -> void:
	_bam_cov_cutoff_spin.min_value = 0
	_bam_cov_cutoff_spin.max_value = 500000000
	_bam_cov_cutoff_spin.step = 1000000
	_bam_cov_cutoff_spin.value = _bam_cov_precompute_cutoff_bp
	_bam_cov_cutoff_spin.allow_greater = false
	_bam_cov_cutoff_spin.allow_lesser = false
	if not _bam_cov_cutoff_spin.value_changed.is_connected(_on_bam_cov_cutoff_changed):
		_bam_cov_cutoff_spin.value_changed.connect(_on_bam_cov_cutoff_changed)
	_debug_toggle = CheckBox.new()
	_debug_toggle.text = "Debug"
	_debug_toggle.button_pressed = _debug_enabled
	_debug_toggle.toggled.connect(_on_debug_toggled)
	settings_content.add_child(_debug_toggle)
	_debug_stats_label = Label.new()
	_debug_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_debug_stats_label.visible = _debug_enabled
	_debug_stats_label.text = ""
	settings_content.add_child(_debug_stats_label)

func _on_bam_cov_cutoff_changed(value: float) -> void:
	_bam_cov_precompute_cutoff_bp = maxi(0, int(round(value)))

func _on_annotation_max_on_screen_changed(value: float) -> void:
	_annotation_max_on_screen = clampi(int(value), ANNOT_MAX_ON_SCREEN_MIN, ANNOT_MAX_ON_SCREEN_MAX)
	genome_view.set_annotation_max_on_screen(_annotation_max_on_screen)
	_invalidate_cache()
	if _current_chr_len > 0:
		_schedule_fetch()

func _setup_track_settings_panel() -> void:
	_track_settings_box = VBoxContainer.new()
	_track_settings_box.visible = false
	feature_content.add_child(_track_settings_box)
	_search_controller.setup(feature_content, {
		"get_zem": Callable(self, "_search_get_zem"),
		"get_chromosomes": Callable(self, "_search_get_chromosomes"),
		"get_selected_seq_id": Callable(self, "_search_get_selected_seq_id"),
		"on_hit_selected": Callable(self, "_jump_to_search_hit")
	})

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

func _on_axis_coords_commas_toggled(enabled: bool) -> void:
	_axis_coords_with_commas = enabled
	genome_view.set_axis_coords_with_commas(enabled)

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
	if _any_visible_read_track():
		reads_min_h = READS_TRACK_MIN_HEIGHT
	var tracks_h: float = genome_view.minimum_required_height(reads_min_h)
	var topbar_h := 0.0
	if top_bar != null:
		topbar_h = top_bar.get_combined_minimum_size().y
	var min_h: float = topbar_h + ROOT_VERTICAL_GAP + CONTENT_MARGIN_BOTTOM + tracks_h
	var w := get_window()
	if w != null:
		w.min_size.y = maxi(200, ceili(min_h))

func _on_debug_toggled(enabled: bool) -> void:
	_debug_enabled = enabled
	if _debug_stats_label != null:
		_debug_stats_label.visible = enabled
	if enabled:
		_update_debug_stats_label()

func _reset_debug_annotation_counters() -> void:
	_dbg_ann_tile_requests = 0
	_dbg_ann_tile_cache_hits = 0
	_dbg_ann_tile_queries = 0
	_dbg_ann_features_examined = 0
	_dbg_ann_features_out = 0
	_dbg_ann_fetch_time_ms = 0.0

func _update_debug_stats_label() -> void:
	if _debug_stats_label == null:
		return
	if not _debug_enabled:
		_debug_stats_label.text = ""
		return
	var hit_pct := 0.0
	if _dbg_ann_tile_requests > 0:
		hit_pct = 100.0 * float(_dbg_ann_tile_cache_hits) / float(_dbg_ann_tile_requests)
	var draw_stats: Dictionary = genome_view.annotation_debug_stats()
	var status_prefix := "ERROR" if _last_status_is_error else "OK"
	_debug_stats_label.text = "Server [%s]: %s\nViewport: %s\nScale: %s\nAnn tiles req=%d, cache_hit=%d (%.1f%%), queried=%d\nAnn feats in=%d, out=%d, fetch=%.2fms\nAnn draw seen=%d, drawn=%d, labels=%d, hitboxes=%d, draw=%.2fms" % [
		status_prefix,
		_last_status_message,
		_last_viewport_message,
		_last_bp_per_px_message,
		_dbg_ann_tile_requests,
		_dbg_ann_tile_cache_hits,
		hit_pct,
		_dbg_ann_tile_queries,
		_dbg_ann_features_examined,
		_dbg_ann_features_out,
		_dbg_ann_fetch_time_ms,
		int(draw_stats.get("seen", 0)),
		int(draw_stats.get("drawn", 0)),
		int(draw_stats.get("labels", 0)),
		int(draw_stats.get("hitboxes", 0)),
		float(draw_stats.get("draw_ms", 0.0))
	]
	if int(draw_stats.get("culled_density", 0)) > 0:
		_debug_stats_label.text += "\nAnn draw culled_density=%d" % int(draw_stats.get("culled_density", 0))

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
	if _track_order_list == null:
		return
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
	_refresh_track_visibility_controls(order)
	_update_window_min_height()

func _on_track_visibility_changed(_track_id: String, _visible: bool) -> void:
	if _track_id.begins_with("reads:") and not _visible:
		for i in range(_bam_tracks.size() - 1, -1, -1):
			var t: Dictionary = _bam_tracks[i]
			if str(t.get("track_id", "")) == _track_id:
				_bam_tracks.remove_at(i)
				break
		_sync_bam_read_tracks()
		_has_bam_loaded = not _bam_tracks.is_empty()
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
	if track_id.begins_with("reads:"):
		return "Reads"
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

func _bam_track_for_id(track_id: String) -> Dictionary:
	for t_any in _bam_tracks:
		var t: Dictionary = t_any
		if str(t.get("track_id", "")) == track_id:
			return t
	return {}

func _any_visible_read_track() -> bool:
	for t_any in _bam_tracks:
		var track_id := str((t_any as Dictionary).get("track_id", ""))
		if genome_view.is_track_visible(track_id):
			return true
	return false

func _depth_plot_color_for_track(track_id: String) -> Color:
	var idx := 0
	for i in range(_bam_tracks.size()):
		var t: Dictionary = _bam_tracks[i]
		if str(t.get("track_id", "")) == track_id:
			idx = i
			break
	return DEPTH_SERIES_COLORS[idx % DEPTH_SERIES_COLORS.size()]

func _existing_bam_source_id(bam_path: String) -> int:
	for t_any in _bam_tracks:
		var t: Dictionary = t_any
		if str(t.get("path", "")) == bam_path:
			return int(t.get("source_id", 0))
	return 0

func _sync_bam_read_tracks() -> void:
	var read_ids := PackedStringArray()
	for t_any in _bam_tracks:
		var t: Dictionary = t_any
		read_ids.append(str(t.get("track_id", "")))
	genome_view.sync_read_tracks(read_ids)
	var order: PackedStringArray = genome_view.get_track_order()
	var out := PackedStringArray()
	for id in read_ids:
		out.append(id)
	for id_any in order:
		var id := str(id_any)
		if id == "reads" or id.begins_with("reads:"):
			continue
		out.append(id)
	genome_view.set_track_order(out)

func _on_track_settings_requested(track_id: String) -> void:
	if _track_settings_box == null:
		return
	if _track_settings_open and _active_track_settings_id == track_id and _feature_panel_open:
		_close_feature_panel()
		return
	_set_feature_labels_visible(false)
	if _search_controller != null:
		_search_controller.hide_panel()
	feature_name_label.visible = true
	feature_title_label.text = "%s track settings" % _track_label_for_id(track_id)
	feature_name_label.text = ""
	for child in _track_settings_box.get_children():
		child.queue_free()
	_track_settings_box.visible = true
	_track_settings_open = true
	_active_track_settings_id = track_id
	if track_id.begins_with("reads:"):
		var track_meta := _bam_track_for_id(track_id)
		var bam_name := str(track_meta.get("label", track_meta.get("path", "BAM")))
		var bam_label := Label.new()
		bam_label.text = "BAM: %s" % bam_name
		bam_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bam_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_track_settings_box.add_child(bam_label)
		var view_label := Label.new()
		view_label.text = "Read View"
		var view_option := OptionButton.new()
		view_option.add_item("Stack", 0)
		view_option.add_item("Strand Stack", 1)
		view_option.add_item("Paired", 2)
		view_option.add_item("Fragment Size", 3)
		view_option.select(int(track_meta.get("view_mode", 0)))
		_track_settings_box.add_child(view_label)
		_track_settings_box.add_child(view_option)
		var frag_cb := CheckBox.new()
		frag_cb.text = "Log fragment Y scale"
		frag_cb.button_pressed = bool(track_meta.get("fragment_log", true))
		frag_cb.visible = view_option.selected == 3
		_track_settings_box.add_child(frag_cb)
		var thickness_label := Label.new()
		thickness_label.text = "Read Thickness"
		var thickness_spin := SpinBox.new()
		thickness_spin.min_value = 2
		thickness_spin.max_value = 24
		thickness_spin.step = 1
		thickness_spin.value = float(track_meta.get("thickness", DEFAULT_READ_THICKNESS))
		var max_rows_label := Label.new()
		max_rows_label.text = "Max Visible Rows (0 = unlimited)"
		var max_rows_spin := SpinBox.new()
		max_rows_spin.min_value = 0
		max_rows_spin.max_value = 5000
		max_rows_spin.step = 10
		max_rows_spin.allow_greater = false
		max_rows_spin.allow_lesser = false
		max_rows_spin.value = float(int(track_meta.get("max_rows", DEFAULT_READ_MAX_ROWS)))
		_track_settings_box.add_child(thickness_label)
		_track_settings_box.add_child(thickness_spin)
		_track_settings_box.add_child(max_rows_label)
		_track_settings_box.add_child(max_rows_spin)
		view_option.item_selected.connect(func(index: int) -> void:
			frag_cb.visible = index == 3
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				if str(t.get("track_id", "")) == track_id:
					t["view_mode"] = index
					_bam_tracks[i] = t
					break
			_schedule_fetch()
		)
		frag_cb.toggled.connect(func(enabled: bool) -> void:
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				if str(t.get("track_id", "")) == track_id:
					t["fragment_log"] = enabled
					_bam_tracks[i] = t
					break
			_schedule_fetch()
		)
		thickness_spin.value_changed.connect(func(value: float) -> void:
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				if str(t.get("track_id", "")) == track_id:
					t["thickness"] = clampf(value, 2.0, 24.0)
					_bam_tracks[i] = t
					break
			_schedule_fetch()
		)
		max_rows_spin.value_changed.connect(func(value: float) -> void:
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				if str(t.get("track_id", "")) == track_id:
					t["max_rows"] = maxi(0, int(round(value)))
					_bam_tracks[i] = t
					break
			_schedule_fetch()
		)
	elif track_id == "aa":
		var region_cb := CheckBox.new()
		region_cb.text = "Show full-length region annotations"
		region_cb.button_pressed = _show_full_length_regions
		region_cb.toggled.connect(_on_show_full_region_toggled)
		var max_ann_label := Label.new()
		max_ann_label.text = "Max annotations on screen"
		var max_ann_spin := SpinBox.new()
		max_ann_spin.min_value = ANNOT_MAX_ON_SCREEN_MIN
		max_ann_spin.max_value = ANNOT_MAX_ON_SCREEN_MAX
		max_ann_spin.step = 100
		max_ann_spin.value = _annotation_max_on_screen
		max_ann_spin.value_changed.connect(_on_annotation_max_on_screen_changed)
		_track_settings_box.add_child(region_cb)
		_track_settings_box.add_child(max_ann_label)
		_track_settings_box.add_child(max_ann_spin)
	elif track_id == "genome":
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
		var coord_commas_cb := CheckBox.new()
		coord_commas_cb.text = "Use commas in axis coordinates"
		coord_commas_cb.button_pressed = _axis_coords_with_commas
		coord_commas_cb.toggled.connect(_on_axis_coords_commas_toggled)
		_track_settings_box.add_child(coord_commas_cb)
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
	elif track_id == "gc_plot":
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
		_track_settings_box.add_child(win_label)
		_track_settings_box.add_child(win_spin)
		_track_settings_box.add_child(height_label)
		_track_settings_box.add_child(height_spin)
	elif track_id == "depth_plot":
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
		_track_settings_box.add_child(height_label2)
		_track_settings_box.add_child(height_spin2)
		var legend_title := Label.new()
		legend_title.text = "Depth Lines"
		_track_settings_box.add_child(legend_title)
		if _bam_tracks.is_empty():
			var legend_empty := Label.new()
			legend_empty.text = "None"
			_track_settings_box.add_child(legend_empty)
		else:
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				var tid := str(t.get("track_id", ""))
				var row := HBoxContainer.new()
				row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				var swatch := ColorRect.new()
				swatch.custom_minimum_size = Vector2(14, 14)
				swatch.color = _depth_plot_color_for_track(tid)
				var name_label := Label.new()
				name_label.text = "BAM %d: %s" % [i + 1, str(t.get("label", tid))]
				name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(swatch)
				row.add_child(name_label)
				_track_settings_box.add_child(row)
	else:
		var info := Label.new()
		info.text = "No track-specific settings yet."
		_track_settings_box.add_child(info)
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _toggle_search_panel() -> void:
	if _search_controller == null:
		return
	if _feature_panel_open and _search_controller.is_visible():
		_close_feature_panel()
		return
	_track_settings_open = false
	_active_track_settings_id = ""
	_set_feature_labels_visible(false)
	feature_title_label.text = "Search"
	feature_name_label.visible = false
	feature_type_label.visible = false
	feature_range_label.visible = false
	feature_strand_label.visible = false
	feature_source_label.visible = false
	feature_seq_label.visible = false
	if _track_settings_box != null:
		_track_settings_box.visible = false
	_search_controller.show_panel()
	_feature_panel_open = true
	_slide_feature_panel(true, true)
	_search_controller.focus_query()

func _jump_to_search_hit(hit_any: Dictionary) -> void:
	var hit: Dictionary = hit_any
	var hit_kind := str(hit.get("kind", ""))
	var chr_id := int(hit.get("chr_id", -1))
	var start_bp := int(hit.get("start", 0))
	var end_bp := int(hit.get("end", start_bp + 1))
	if _seq_view_mode != SEQ_VIEW_SINGLE:
		_seq_view_option.select(SEQ_VIEW_SINGLE)
		_on_seq_view_selected(SEQ_VIEW_SINGLE)
	for i in range(_seq_option.item_count):
		if int(_seq_option.get_item_id(i)) == chr_id:
			_seq_option.select(i)
			_on_seq_selected(i)
			break
	var width_px := maxf(1.0, genome_view.size.x)
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var view_span_bp := int(ceil(current_bp_per_px * width_px))
	var center_bp := 0.5 * float(start_bp + end_bp)
	var target_start := maxi(0, int(floor(center_bp - 0.5 * float(view_span_bp))))
	genome_view.set_view_state(float(target_start), current_bp_per_px)
	if hit_kind == "dna":
		_pending_annotation_highlight = {}
		genome_view.clear_selected_feature()
		genome_view.set_region_selection(start_bp, maxi(start_bp, end_bp - 1))
	else:
		_pending_annotation_highlight = hit.duplicate(true)
		genome_view.clear_region_selection()
	_schedule_fetch()

func _search_get_zem() -> RefCounted:
	return _zem

func _search_get_chromosomes() -> Array[Dictionary]:
	return _chromosomes

func _search_get_selected_seq_id() -> int:
	return _selected_seq_id

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
	self.theme = _themes_lib.make_theme(theme_name, _ui_font_size)
	_theme_text_color = palette["text"]
	_theme_error_color = palette["status_error"]
	background.color = palette["bg"]
	genome_view.set_palette(_themes_lib.genome_palette(theme_name))
	genome_view.set_base_font_size(_ui_font_size)
	feature_name_label.add_theme_color_override("default_color", palette["text"])
	feature_type_label.add_theme_color_override("default_color", palette["text"])
	feature_range_label.add_theme_color_override("default_color", palette["text"])
	feature_strand_label.add_theme_color_override("default_color", palette["text"])
	feature_source_label.add_theme_color_override("default_color", palette["text"])
	feature_seq_label.add_theme_color_override("default_color", palette["text"])
	status_message_label.add_theme_color_override("font_color", palette["text"])
	_apply_search_theme(palette)
	_apply_topbar_button_font_size()

func _apply_search_theme(palette: Dictionary) -> void:
	if _search_controller != null:
		_search_controller.apply_theme(palette)

func _apply_topbar_button_font_size() -> void:
	var topbar_font_size := clampi(_ui_font_size + 6, MIN_UI_FONT_SIZE, MAX_UI_FONT_SIZE + 6)
	var topbar_buttons := [
		settings_toggle_button,
		search_button,
		pan_left_button,
		pan_right_button,
		zoom_out_button,
		zoom_in_button,
		play_left_button,
		stop_button,
		play_button
	]
	for b_any in topbar_buttons:
		var b: Button = b_any
		b.add_theme_font_size_override("font_size", topbar_font_size)

func _on_files_dropped(files: PackedStringArray) -> void:
	var dropped_fasta := _has_fasta(files)
	var dropped_gff3 := _has_gff3(files)
	var dropped_sequence := _has_sequence_file(files)
	if dropped_gff3 and not (_has_fasta_loaded or dropped_fasta):
		_set_status("Refusing GFF3 load: drop a FASTA first.", true)
		return
	if dropped_fasta:
		_reset_loaded_state()
	elif dropped_sequence:
		_view_slots.clear()
	for f in files:
		if _is_file_list_placeholder():
			file_list.clear()
		if not _file_list_has(f):
			file_list.add_item(f)
	_refresh_file_list_ui()
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
	var host := host_edit.text.strip_edges()
	if host.is_empty():
		host = "127.0.0.1"
	var port := int(port_edit.text)
	if port <= 0:
		port = ZEM_DEFAULT_PORT
	if _connect_with_local_fallback(host, port):
		_set_status("Connected %s:%d" % [host, port])
		return true
	var msg := "Disconnected"
	if not _last_connect_error.is_empty():
		msg = _last_connect_error
	_set_status(msg, true)
	return false

func _connect_with_local_fallback(host: String, port: int, connect_timeout_ms: int = 1200, wait_attempts: int = 15, wait_step_ms: int = 120) -> bool:
	_last_connect_error = ""
	var try_local := _should_try_local_zem(host)
	if try_local:
		if not _ensure_local_zem_installed():
			_last_connect_error = "Local zem binary missing and install failed for %s:%d" % [host, port]
			return false
	if _zem.connect_to_server(host, port, connect_timeout_ms):
		var probe_existing := _probe_zem_ready()
		if bool(probe_existing.get("ok", false)):
			return true
		_last_connect_error = "Connected but zem probe failed: %s" % str(probe_existing.get("error", "unknown error"))
		_zem.disconnect_from_server()
	if not try_local:
		if _last_connect_error.is_empty():
			_last_connect_error = "Unable to connect to %s:%d" % [host, port]
		return false
	if not _start_local_zem(host, port):
		if _last_connect_error.is_empty():
			_last_connect_error = "Unable to start local zem at %s:%d" % [host, port]
		return false
	for _i in range(maxi(1, wait_attempts)):
		OS.delay_msec(maxi(1, wait_step_ms))
		if _zem.connect_to_server(host, port, connect_timeout_ms):
			var probe_started := _probe_zem_ready()
			if bool(probe_started.get("ok", false)):
				return true
			_last_connect_error = "Local zem started but probe failed: %s" % str(probe_started.get("error", "unknown error"))
			_zem.disconnect_from_server()
	if _last_connect_error.is_empty():
		_last_connect_error = "Local zem did not become ready at %s:%d" % [host, port]
	return false

func _probe_zem_ready() -> Dictionary:
	var resp: Dictionary = _zem.get_annotation_counts()
	if bool(resp.get("ok", false)):
		return {"ok": true}
	return {"ok": false, "error": str(resp.get("error", "probe failed"))}

func _should_try_local_zem(host: String) -> bool:
	var h := host.to_lower()
	return h == "127.0.0.1" or h == "localhost" or h == "::1"

func _start_local_zem(host: String, port: int) -> bool:
	if not _ensure_local_zem_installed():
		return false
	if _local_zem_path.is_empty() or not FileAccess.file_exists(_local_zem_path):
		return false
	var listen_addr := "%s:%d" % [host, port]
	var args := PackedStringArray(["-listen", listen_addr])
	var pid := OS.create_process(_local_zem_path, args, false)
	if pid <= 0:
		return false
	_local_zem_pid = pid
	_local_zem_started_by_seqhiker = true
	return true

func _ensure_local_zem_installed() -> bool:
	if _local_zem_install_checked and not _local_zem_path.is_empty() and FileAccess.file_exists(_local_zem_path):
		return true
	_local_zem_install_checked = true
	var bin_name := _zem_binary_name()
	var user_bin_dir_abs := OS.get_user_data_dir().path_join(ZEM_BIN_SUBDIR)
	var mk_err := DirAccess.make_dir_recursive_absolute(user_bin_dir_abs)
	if mk_err != OK and not DirAccess.dir_exists_absolute(user_bin_dir_abs):
		_last_connect_error = "Failed to create local bin dir: %s" % user_bin_dir_abs
		return false
	var target_abs := user_bin_dir_abs.path_join(bin_name)
	_local_zem_path = target_abs
	var source := _find_zem_source(bin_name)
	if source.is_empty():
		if FileAccess.file_exists(target_abs):
			_last_connect_error = ""
			return true
		_last_connect_error = "No bundled zem found at res://bin/%s" % bin_name
		return false
	if not FileAccess.file_exists(target_abs):
		if not _copy_file_any_to_abs(source, target_abs):
			_last_connect_error = "Failed to copy zem into %s" % target_abs
			return false
	else:
		var src_hash := FileAccess.get_sha256(source)
		var dst_hash := FileAccess.get_sha256(target_abs)
		if src_hash.is_empty() or dst_hash.is_empty() or src_hash != dst_hash:
			if not _copy_file_any_to_abs(source, target_abs):
				_last_connect_error = "Failed to update zem in %s" % target_abs
				return false
	if not OS.has_feature("windows"):
		OS.execute("chmod", ["+x", target_abs], [], true)
	_last_connect_error = ""
	return true

func _find_zem_source(bin_name: String) -> String:
	var packaged := "res://bin/%s" % bin_name
	if FileAccess.file_exists(packaged):
		return packaged
	var dev_abs := ProjectSettings.globalize_path("res://zem/%s" % bin_name)
	if FileAccess.file_exists(dev_abs):
		return dev_abs
	return ""

func _copy_file_any_to_abs(source: String, target_abs: String) -> bool:
	var src := FileAccess.open(source, FileAccess.READ)
	if src == null:
		return false
	var dst := FileAccess.open(target_abs, FileAccess.WRITE)
	if dst == null:
		src.close()
		return false
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()
	return true

func _zem_binary_name() -> String:
	if OS.has_feature("windows"):
		return "zem.exe"
	return "zem"

func _exit_tree() -> void:
	if _tile_controller != null:
		_tile_controller.shutdown()
	_shutdown_local_zem_on_exit()

func _shutdown_local_zem_on_exit() -> void:
	if not _local_zem_started_by_seqhiker:
		return
	var shutdown_ok := false
	var resp: Dictionary = _zem.shutdown_server(400)
	shutdown_ok = bool(resp.get("ok", false))
	if not shutdown_ok and _local_zem_pid > 0:
		OS.kill(_local_zem_pid)
	_zem.disconnect_from_server()

func _load_dropped_files(files: PackedStringArray) -> bool:
	var genome_targets: Dictionary = {}
	var bam_targets: Array[String] = []
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext == "bam":
			bam_targets.append(path)
		else:
			genome_targets[path] = true
	for target in genome_targets.keys():
		var resp: Dictionary = _zem.load_genome(target)
		if not resp.get("ok", false):
			_set_status("Load genome failed: %s" % resp.get("error", "error"), true)
			return false

	genome_view.set_read_loading_message("Loading BAMs...")
	for bam_path in bam_targets:
		var source_id := _existing_bam_source_id(bam_path)
		if source_id <= 0:
			var cutoff_bp := _bam_cov_precompute_cutoff_bp
			if cutoff_bp > 0:
				genome_view.set_read_loading_message("Loading %s and precomputing depth..." % bam_path.get_file())
			else:
				genome_view.set_read_loading_message("Loading %s..." % bam_path.get_file())
			var bam_resp: Dictionary = _zem.load_bam(bam_path, cutoff_bp)
			if not bam_resp.get("ok", false):
				genome_view.set_read_loading_message("")
				_set_status("Load BAM failed: %s" % bam_resp.get("error", "error"), true)
				return false
			source_id = int(bam_resp.get("source_id", 0))
		_bam_track_serial += 1
		var label := bam_path.get_file()
		var track_id := "reads:%d" % _bam_track_serial
		_bam_tracks.append({
			"source_id": source_id,
			"path": bam_path,
			"label": label,
			"track_id": track_id,
			"view_mode": 0,
			"fragment_log": true,
			"thickness": DEFAULT_READ_THICKNESS,
			"max_rows": DEFAULT_READ_MAX_ROWS
		})
		_has_bam_loaded = true
		_center_strand_scroll_pending = true
		_sync_bam_read_tracks()
		genome_view.set_track_visible(track_id, true)
	genome_view.set_read_loading_message("")
	return true

func _refresh_chromosomes() -> void:
	var resp: Dictionary = _zem.get_chromosomes()
	if not resp.get("ok", false):
		_set_status("Chrom query failed: %s" % resp.get("error", "error"), true)
		return
	var chroms_any = resp.get("chromosomes", [])
	var chroms: Array[Dictionary] = []
	for c in chroms_any:
		if typeof(c) == TYPE_DICTIONARY:
			chroms.append(c)
	if chroms.is_empty():
		_set_status("No chromosomes loaded", true)
		return
	_chromosomes = chroms
	var counts_resp: Dictionary = _zem.get_annotation_counts()
	if counts_resp.get("ok", false):
		_annotation_counts_by_chr = counts_resp.get("counts", {})
	else:
		_annotation_counts_by_chr = {}
		_set_status("Annotation preload disabled: counts unavailable (restart zem)", true)
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

func _apply_pending_annotation_highlight(features: Array[Dictionary]) -> void:
	if _pending_annotation_highlight.is_empty():
		return
	var hit: Dictionary = _pending_annotation_highlight
	_pending_annotation_highlight = {}
	if features.is_empty():
		return
	var hit_start := int(hit.get("start", 0))
	var hit_end := int(hit.get("end", hit_start + 1))
	var hit_label := str(hit.get("label", "")).strip_edges()
	var hit_chr := str(hit.get("chr_name", "")).strip_edges()
	for f_any in features:
		var f: Dictionary = f_any
		if int(f.get("start", 0)) != hit_start:
			continue
		if int(f.get("end", hit_start + 1)) != hit_end:
			continue
		if not hit_chr.is_empty() and str(f.get("seq_name", "")) != hit_chr:
			continue
		if not hit_label.is_empty():
			var fname := str(f.get("name", "")).strip_edges()
			var ftype := str(f.get("type", "")).strip_edges()
			if hit_label != fname and hit_label != ftype:
				continue
		genome_view.set_selected_feature(f, false)
		return

func _scope_cache_key() -> String:
	if _seq_view_mode == SEQ_VIEW_SINGLE:
		return "single:%d" % _current_chr_id
	return "concat:%d:%d" % [_concat_segments.size(), _concat_gap_bp]

func _invalidate_cache() -> void:
	_cache_start = -1
	_cache_end = -1
	_cache_zoom = -1
	_cache_mode = -1
	_cache_need_reference = false
	_cache_scope_key = ""
	_annotation_tile_cache.clear()
	_tile_cache_generation += 1
	_fetch_in_progress = false
	if _tile_controller != null:
		_tile_controller.reset()

func _finish_sync_fetch_attempt() -> void:
	if not _fetch_in_progress:
		return
	_fetch_in_progress = false
	if _fetch_pending and _fetch_timer != null:
		_fetch_timer.start()

func _refresh_visible_data() -> void:
	if _current_chr_len <= 0:
		_finish_sync_fetch_attempt()
		return
	if _debug_enabled:
		_reset_debug_annotation_counters()
	var show_reads: bool = _any_visible_read_track()
	var show_aa: bool = bool(genome_view.is_track_visible(TRACK_AA))
	var show_gc_plot: bool = bool(genome_view.is_track_visible(TRACK_GC_PLOT))
	var show_depth_plot: bool = bool(genome_view.is_track_visible(TRACK_DEPTH_PLOT))
	var show_genome: bool = bool(genome_view.is_track_visible(TRACK_GENOME))
	var need_reference: bool = genome_view.needs_reference_data(show_aa, show_genome)
	var span: int = maxi(1, _last_end - _last_start)
	var right_span_mult := 3 if _auto_play_enabled else 2
	var query_start: int = maxi(0, _last_start - span)
	var query_end: int = mini(_current_chr_len, _last_end + span * right_span_mult)
	var features: Array[Dictionary] = []
	var ref_start := query_start
	var ref_sequence := ""
	var overlaps: Array[Dictionary] = []
	var ann_overlaps: Array[Dictionary] = []
	var visible_track_ids := {}
	for t_any in _bam_tracks:
		var track_vis: Dictionary = t_any
		var track_vis_id := str(track_vis.get("track_id", ""))
		visible_track_ids[track_vis_id] = genome_view.is_track_visible(track_vis_id)

	if _seq_view_mode == SEQ_VIEW_SINGLE:
		if show_aa:
			var ann_resp := _get_annotations_window_preloaded(_current_chr_id, query_start, query_end)
			if not ann_resp.get("ok", false):
				_set_status("Annotation query failed: %s" % ann_resp.get("error", "error"), true)
				_finish_sync_fetch_attempt()
				return
			features = ann_resp.get("features", [])

		if need_reference:
			var ref_resp: Dictionary = _zem.get_reference_slice(_current_chr_id, query_start, query_end)
			if not ref_resp.get("ok", false):
				_set_status("Reference query failed: %s" % ref_resp.get("error", "error"), true)
				_finish_sync_fetch_attempt()
				return
			ref_start = int(ref_resp.get("slice_start", query_start))
			ref_sequence = str(ref_resp.get("sequence", ""))
	else:
		overlaps = _segments_overlapping(query_start, query_end)
		ann_overlaps = _segments_overlapping(query_start, query_end) if show_aa else ([] as Array[Dictionary])
		for aov in ann_overlaps:
			var a_chr_id := int(aov["id"])
			var a_offset := int(aov["offset"])
			var a_local_start := int(aov["local_start"])
			var a_local_end := int(aov["local_end"])
			var ann_resp_part := _get_annotations_window_preloaded(a_chr_id, a_local_start, a_local_end)
			if not ann_resp_part.get("ok", false):
				_set_status("Annotation query failed: %s" % ann_resp_part.get("error", "error"), true)
				_finish_sync_fetch_attempt()
				return
			for f in ann_resp_part.get("features", []):
				features.append(_shift_feature_coords(f, a_offset))

		if need_reference:
			ref_sequence = _build_concat_reference(query_start, query_end, overlaps)
	genome_view.set_features(features)
	genome_view.set_reference_slice(ref_start, ref_sequence)
	_apply_pending_annotation_highlight(features)
	_tile_fetch_serial += 1
	_pending_tile_apply = {
		"serial": _tile_fetch_serial,
		"query_start": query_start,
		"query_end": query_end,
		"need_reference": need_reference,
		"features": features,
		"ref_start": ref_start,
		"ref_sequence": ref_sequence
	}
	_tile_controller.request_tiles({
		"serial": _tile_fetch_serial,
		"host": host_edit.text.strip_edges() if not host_edit.text.strip_edges().is_empty() else "127.0.0.1",
		"port": int(port_edit.text) if int(port_edit.text) > 0 else ZEM_DEFAULT_PORT,
		"generation": _tile_cache_generation,
		"scope_key": _scope_cache_key(),
		"query_start": query_start,
		"query_end": query_end,
		"last_bp_per_px": _last_bp_per_px,
		"show_reads": show_reads,
		"show_gc_plot": show_gc_plot,
		"show_depth_plot": show_depth_plot,
		"has_bam_loaded": _has_bam_loaded,
		"seq_view_mode": _seq_view_mode,
		"current_chr_id": _current_chr_id,
		"bam_tracks": _bam_tracks,
		"overlaps": overlaps,
		"visible_track_ids": visible_track_ids,
		"gc_window_bp": _gc_window_bp
	})
	return

func _annotation_pixel_budget() -> int:
	var span := maxi(1, _last_end - _last_start)
	var px := int(ceil(float(span) / maxf(0.001, _last_bp_per_px)))
	var max_budget := clampi(_annotation_max_on_screen, ANNOT_MAX_ON_SCREEN_MIN, ANNOT_MAX_ON_SCREEN_MAX)
	if _last_bp_per_px >= 20.0:
		return maxi(120, int(round(float(max_budget) * 0.18)))
	if _last_bp_per_px >= 10.0:
		return maxi(220, int(round(float(max_budget) * 0.33)))
	if _last_bp_per_px >= 5.0:
		return maxi(320, int(round(float(max_budget) * 0.5)))
	return clampi(px * 2, ANNOT_MIN_TOTAL, max_budget)

func _annotation_min_feature_len_bp() -> int:
	return clampi(int(ceil(1.2 * _last_bp_per_px)), 1, 200)

func _annotation_tile_key(chr_id: int, zoom: int, tile_index: int, min_len_bp: int) -> String:
	return "%s|%d|%d|%d|%d" % [_scope_cache_key(), chr_id, zoom, tile_index, min_len_bp]

func _get_annotations_window_preloaded(chr_id: int, start_bp: int, end_bp: int) -> Dictionary:
	return _get_annotations_window_tiled(chr_id, start_bp, end_bp)

func _get_annotations_window_tiled(chr_id: int, start_bp: int, end_bp: int) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	if end_bp <= start_bp:
		return {"ok": true, "features": []}
	var zoom := _compute_tile_zoom(_last_bp_per_px)
	var tile_w := ANNOT_TILE_BASE_BP << zoom
	var tile_start := int(floor(float(start_bp) / float(tile_w)))
	var tile_end := int(floor(float(maxi(end_bp - 1, start_bp)) / float(tile_w)))
	if tile_end < tile_start:
		tile_end = tile_start
	var total_tiles := tile_end - tile_start + 1
	var min_len_bp := _annotation_min_feature_len_bp()
	var cap_total := _annotation_pixel_budget()
	var out: Array[Dictionary] = []
	var seen: Dictionary = {}
	if total_tiles > ANNOT_MAX_TILES:
		var chunk_count := ANNOT_MAX_TILES
		var span := maxi(1, end_bp - start_bp)
		var cap_per_chunk := clampi(int(ceil(float(cap_total) / float(maxi(1, chunk_count)) * 2.0)), 64, cap_total)
		for i in range(chunk_count):
			var c_start := start_bp + int(floor(float(i) * float(span) / float(chunk_count)))
			var c_end := start_bp + int(ceil(float(i + 1) * float(span) / float(chunk_count)))
			if c_end <= c_start:
				c_end = c_start + 1
			if _debug_enabled:
				_dbg_ann_tile_requests += 1
				_dbg_ann_tile_queries += 1
			var resp_chunk: Dictionary = _zem.get_annotations(chr_id, c_start, c_end, cap_per_chunk, min_len_bp)
			if not resp_chunk.get("ok", false):
				return resp_chunk
			var chunk_feats: Array = resp_chunk.get("features", [])
			if _debug_enabled:
				_dbg_ann_features_examined += chunk_feats.size()
			for f in chunk_feats:
				var feat: Dictionary = f
				var feat_start := int(feat.get("start", 0))
				var feat_end := int(feat.get("end", feat_start))
				if feat_end <= start_bp or feat_start >= end_bp:
					continue
				var key_f := _feature_dedupe_key(feat)
				if seen.get(key_f, false):
					continue
				seen[key_f] = true
				out.append(feat)
				if out.size() >= cap_total:
					out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						var sa := int(a.get("start", 0))
						var sb := int(b.get("start", 0))
						if sa == sb:
							return int(a.get("end", sa)) < int(b.get("end", sb))
						return sa < sb
					)
					if _debug_enabled:
						_dbg_ann_features_out += out.size()
						_dbg_ann_fetch_time_ms += float(Time.get_ticks_usec() - t0) / 1000.0
					return {"ok": true, "features": out}
	else:
		var tile_count := total_tiles
		var cap_per_tile := clampi(int(ceil(float(cap_total) / float(maxi(1, tile_count)) * 1.5)), 128, cap_total)
		for t in range(tile_start, tile_end + 1):
			if _debug_enabled:
				_dbg_ann_tile_requests += 1
			var t_start := t * tile_w
			var t_end := t_start + tile_w
			var key := _annotation_tile_key(chr_id, zoom, t, min_len_bp)
			var cached: Array[Dictionary] = []
			if _annotation_tile_cache.has(key):
				cached = _annotation_tile_cache[key]
				if _debug_enabled:
					_dbg_ann_tile_cache_hits += 1
			if cached.is_empty():
				var resp: Dictionary = _zem.get_annotations(chr_id, t_start, t_end, cap_per_tile, min_len_bp)
				if not resp.get("ok", false):
					return resp
				cached = resp.get("features", [])
				if _debug_enabled:
					_dbg_ann_tile_queries += 1
				if _annotation_tile_cache.size() >= ANNOT_TILE_CACHE_MAX_ENTRIES:
					_annotation_tile_cache.clear()
				_annotation_tile_cache[key] = cached
			if _debug_enabled:
				_dbg_ann_features_examined += cached.size()
			for f in cached:
				var feat: Dictionary = f
				var feat_start := int(feat.get("start", 0))
				var feat_end := int(feat.get("end", feat_start))
				if feat_end <= start_bp or feat_start >= end_bp:
					continue
				var key_f := _feature_dedupe_key(feat)
				if seen.get(key_f, false):
					continue
				seen[key_f] = true
				out.append(feat)
				if out.size() >= cap_total:
					out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
						var sa := int(a.get("start", 0))
						var sb := int(b.get("start", 0))
						if sa == sb:
							return int(a.get("end", sa)) < int(b.get("end", sb))
						return sa < sb
					)
					if _debug_enabled:
						_dbg_ann_features_out += out.size()
						_dbg_ann_fetch_time_ms += float(Time.get_ticks_usec() - t0) / 1000.0
					return {"ok": true, "features": out}
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := int(a.get("start", 0))
		var sb := int(b.get("start", 0))
		if sa == sb:
			return int(a.get("end", sa)) < int(b.get("end", sb))
		return sa < sb
	)
	if _debug_enabled:
		_dbg_ann_features_out += out.size()
		_dbg_ann_fetch_time_ms += float(Time.get_ticks_usec() - t0) / 1000.0
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

func _drain_tile_fetch_result() -> void:
	if _tile_controller == null:
		return
	var tile_resp: Dictionary = _tile_controller.poll_result()
	if tile_resp.is_empty():
		return
	if not tile_resp.get("ok", false):
		_set_status(str(tile_resp.get("error", "Tile fetch failed")), true)
		_fetch_in_progress = false
		if _fetch_pending:
			_fetch_timer.start()
		return
	var serial := int(tile_resp.get("serial", -1))
	if serial != int(_pending_tile_apply.get("serial", -2)):
		_fetch_in_progress = false
		if _fetch_pending:
			_fetch_timer.start()
		return
	var read_payload_by_track = tile_resp.get("read_payload_by_track", {})
	var all_gc_plot_tiles: Array[Dictionary] = tile_resp.get("gc_plot_tiles", [])
	var all_depth_plot_tiles: Array[Dictionary] = tile_resp.get("depth_plot_tiles", [])
	var all_depth_plot_series: Array[Dictionary] = tile_resp.get("depth_plot_series", [])
	for t_any in _bam_tracks:
		var track: Dictionary = t_any
		var track_id := str(track.get("track_id", ""))
		var payload: Dictionary = read_payload_by_track.get(track_id, {"reads": [], "coverage": []})
		genome_view.set_read_track_payload(
			track_id,
			payload,
			int(track.get("view_mode", 0)),
			bool(track.get("fragment_log", true)),
			float(track.get("thickness", DEFAULT_READ_THICKNESS)),
			int(track.get("max_rows", DEFAULT_READ_MAX_ROWS))
		)
		if _center_strand_scroll_pending and int(track.get("view_mode", 0)) == 1 and (payload.get("reads", []) as Array).size() > 0:
			genome_view.center_strand_scroll_for_track(track_id)
			_center_strand_scroll_pending = false
	genome_view.set_gc_plot_tiles(all_gc_plot_tiles)
	genome_view.set_depth_plot_tiles(all_depth_plot_tiles)
	for i in range(all_depth_plot_series.size()):
		var series: Dictionary = all_depth_plot_series[i]
		series["color"] = _depth_plot_color_for_track(str(series.get("track_id", "")))
		all_depth_plot_series[i] = series
	genome_view.set_depth_plot_series(all_depth_plot_series)
	_cache_start = int(_pending_tile_apply.get("query_start", -1))
	_cache_end = int(_pending_tile_apply.get("query_end", -1))
	_cache_zoom = _compute_tile_zoom(_last_bp_per_px)
	_cache_mode = 0 if (_has_bam_loaded and _any_visible_read_track() and _last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
	_cache_need_reference = bool(_pending_tile_apply.get("need_reference", false))
	_cache_scope_key = _scope_cache_key()
	if _debug_enabled:
		_update_debug_stats_label()
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
	return clampi(z, 0, 16)

func _file_list_has(path: String) -> bool:
	if _is_file_list_placeholder():
		return false
	for i in range(file_list.item_count):
		if file_list.get_item_text(i) == path:
			return true
	return false

func _is_file_list_placeholder() -> bool:
	return file_list.item_count == 1 and file_list.get_item_text(0) == FILE_LIST_PLACEHOLDER

func _refresh_file_list_ui() -> void:
	if file_list == null:
		return
	file_list.size_flags_vertical = Control.SIZE_FILL
	if file_list.item_count == 0:
		file_list.add_item(FILE_LIST_PLACEHOLDER)
		file_list.set_item_disabled(0, true)
	for i in range(file_list.item_count):
		if file_list.is_item_disabled(i):
			var muted := _theme_text_color
			muted.a = 0.7
			file_list.set_item_custom_fg_color(i, muted)
		else:
			file_list.set_item_custom_fg_color(i, _theme_text_color)
	var font := file_list.get_theme_font("font")
	var font_size := file_list.get_theme_font_size("font_size")
	var row_h := 20.0
	if font != null and font_size > 0:
		row_h = maxf(16.0, font.get_height(font_size) + 6.0)
	file_list.custom_minimum_size.y = row_h * float(file_list.item_count) + 8.0

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

func _has_sequence_file(files: PackedStringArray) -> bool:
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext in ["bam", "gff", "gff3"]:
			continue
		return true
	return false

func _reset_loaded_state() -> void:
	file_list.clear()
	_refresh_file_list_ui()
	_view_slots.clear()
	_current_chr_id = -1
	_current_chr_name = ""
	_current_chr_len = 0
	_cache_start = -1
	_cache_end = -1
	_invalidate_cache()
	_has_bam_loaded = false
	_bam_tracks.clear()
	_bam_track_serial = 0
	_has_fasta_loaded = false
	_chromosomes.clear()
	_annotation_counts_by_chr.clear()
	_concat_segments.clear()
	_seq_option.clear()
	_selected_seq_id = -1
	_selected_seq_name = ""
	_auto_play_enabled = false
	_feature_panel_open = false
	_slide_feature_panel(false, false)
	genome_view.clear_all_data()
	_sync_bam_read_tracks()

func _setup_view_slot_shortcuts() -> void:
	for b in _view_slot_shortcut_buttons:
		if is_instance_valid(b):
			b.queue_free()
	_view_slot_shortcut_buttons.clear()
	for i in range(1, VIEW_SLOT_COUNT + 1):
		_view_slot_shortcut_buttons.append(_make_view_slot_button(VIEW_SLOT_LOAD_ACTION_PREFIX + str(i), _load_view_slot.bind(i)))
		_view_slot_shortcut_buttons.append(_make_view_slot_button(VIEW_SLOT_SAVE_ACTION_PREFIX + str(i), _save_view_slot.bind(i)))

func _make_view_slot_button(action_name: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = ""
	b.custom_minimum_size = Vector2.ZERO
	b.size = Vector2.ZERO
	b.position = Vector2(-1000.0, -1000.0)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.focus_mode = Control.FOCUS_NONE
	b.modulate.a = 0.0
	var ev := InputEventAction.new()
	ev.action = StringName(action_name)
	var sc := Shortcut.new()
	sc.events = [ev]
	b.shortcut = sc
	b.shortcut_in_tooltip = false
	b.pressed.connect(callback)
	add_child(b)
	return b

func _save_view_slot(slot_idx: int) -> void:
	if _current_chr_len <= 0:
		_set_status("No genome loaded: cannot save view slot.", true)
		return
	var state: Dictionary = genome_view.get_view_state()
	_view_slots[slot_idx] = {
		"scope_key": _scope_cache_key(),
		"seq_view_mode": _seq_view_mode,
		"seq_id": _selected_seq_id,
		"start_bp": float(state.get("start_bp", _last_start)),
		"bp_per_px": float(state.get("bp_per_px", _last_bp_per_px))
	}
	_set_status("Saved view slot %d." % slot_idx)

func _load_view_slot(slot_idx: int) -> void:
	if _current_chr_len <= 0:
		_set_status("No genome loaded: cannot load view slot.", true)
		return
	if not _view_slots.has(slot_idx):
		_set_status("View slot %d is empty." % slot_idx, true)
		return
	var slot_any = _view_slots[slot_idx]
	if typeof(slot_any) != TYPE_DICTIONARY:
		_set_status("View slot %d is invalid." % slot_idx, true)
		return
	var slot: Dictionary = slot_any
	var slot_scope := str(slot.get("scope_key", ""))
	if slot_scope != _scope_cache_key():
		_set_status("View slot %d is from a different genome/session scope." % slot_idx, true)
		return
	var slot_mode := int(slot.get("seq_view_mode", _seq_view_mode))
	if slot_mode != _seq_view_mode:
		_seq_view_option.select(slot_mode)
		_on_seq_view_selected(slot_mode)
	if slot_mode == SEQ_VIEW_SINGLE:
		var target_id := int(slot.get("seq_id", _selected_seq_id))
		for i in range(_seq_option.item_count):
			if int(_seq_option.get_item_id(i)) == target_id:
				_seq_option.select(i)
				_on_seq_selected(i)
				break
	genome_view.set_view_state(float(slot.get("start_bp", _last_start)), float(slot.get("bp_per_px", _last_bp_per_px)))
	_schedule_fetch()
	_set_status("Loaded view slot %d." % slot_idx)

func _is_viewport_cached(start_bp: int, end_bp: int, zoom: int, mode: int, need_reference: bool, scope_key: String) -> bool:
	if _cache_start < 0 || _cache_end < 0:
		return false
	if _cache_zoom != zoom or _cache_mode != mode:
		return false
	if _cache_need_reference != need_reference:
		return false
	if _cache_scope_key != scope_key:
		return false
	return start_bp >= _cache_start and end_bp <= _cache_end

func _is_near_cache_edge(start_bp: int, end_bp: int) -> bool:
	if _cache_end < 0:
		return true
	var span: int = maxi(1, end_bp - start_bp)
	var threshold: int = maxi(1, int(round(float(span) * 0.5)))
	var remaining_left: int = start_bp - _cache_start
	var remaining_right: int = _cache_end - end_bp
	return remaining_left <= threshold or remaining_right <= threshold

func _set_status(message: String, is_error: bool = false) -> void:
	_last_status_message = message
	_last_status_is_error = is_error
	status_message_label.text = message
	status_message_label.tooltip_text = message
	status_message_label.add_theme_color_override("font_color", _theme_error_color if is_error else _theme_text_color)
	if _debug_enabled:
		_update_debug_stats_label()

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
	pan_step_slider.value = clampf(float(cfg.get_value("input", "pan_step_percent", 75.0)), 1.0, 100.0)
	_on_pan_step_changed(pan_step_slider.value)
	_ui_font_size = clampi(int(cfg.get_value("ui", "font_size", DEFAULT_UI_FONT_SIZE)), MIN_UI_FONT_SIZE, MAX_UI_FONT_SIZE)
	if _font_size_spin != null:
		_font_size_spin.value = _ui_font_size

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
	_show_full_length_regions = bool(cfg.get_value("ui", "show_full_length_regions", false))
	_show_full_region_checkbox.button_pressed = _show_full_length_regions
	genome_view.set_show_full_length_regions(_show_full_length_regions)
	_colorize_nucleotides = bool(cfg.get_value("ui", "colorize_nucleotides", true))
	genome_view.set_colorize_nucleotides(_colorize_nucleotides)
	_axis_coords_with_commas = bool(cfg.get_value("ui", "axis_coords_with_commas", false))
	genome_view.set_axis_coords_with_commas(_axis_coords_with_commas)
	_gc_window_bp = int(cfg.get_value("ui", "gc_window_bp", DEFAULT_GC_WINDOW_BP))
	_gc_window_bp = clampi(_gc_window_bp, 1, 1000000)
	_bam_cov_precompute_cutoff_bp = maxi(0, int(cfg.get_value("ui", "bam_cov_precompute_cutoff_bp", BAM_COV_PRECOMPUTE_CUTOFF_DEFAULT)))
	if _bam_cov_cutoff_spin != null:
		_bam_cov_cutoff_spin.value = _bam_cov_precompute_cutoff_bp
	_annotation_max_on_screen = clampi(int(cfg.get_value("ui", "annotation_max_on_screen", ANNOT_MAX_ON_SCREEN_DEFAULT)), ANNOT_MAX_ON_SCREEN_MIN, ANNOT_MAX_ON_SCREEN_MAX)
	genome_view.set_annotation_max_on_screen(_annotation_max_on_screen)
	_gc_plot_y_mode = clampi(int(cfg.get_value("ui", "gc_plot_y_mode", PLOT_Y_UNIT)), PLOT_Y_UNIT, PLOT_Y_FIXED)
	_gc_plot_y_min = float(cfg.get_value("ui", "gc_plot_y_min", 0.0))
	_gc_plot_y_max = float(cfg.get_value("ui", "gc_plot_y_max", 1.0))
	_apply_gc_plot_y_scale()
	_depth_plot_y_mode = clampi(int(cfg.get_value("ui", "depth_plot_y_mode", PLOT_Y_AUTOSCALE)), PLOT_Y_UNIT, PLOT_Y_FIXED)
	_depth_plot_y_min = float(cfg.get_value("ui", "depth_plot_y_min", 0.0))
	_depth_plot_y_max = float(cfg.get_value("ui", "depth_plot_y_max", 100.0))
	_apply_depth_plot_y_scale()
	_debug_enabled = bool(cfg.get_value("ui", "debug_enabled", false))
	if _debug_toggle != null:
		_debug_toggle.button_pressed = _debug_enabled
	if _debug_stats_label != null:
		_debug_stats_label.visible = _debug_enabled
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
	cfg.set_value("ui", "font_size", _ui_font_size)
	cfg.set_value("ui", "sequence_view_mode", _seq_view_option.selected)
	cfg.set_value("ui", "concat_gap_bp", _concat_gap_bp)
	cfg.set_value("ui", "selected_sequence_name", _selected_seq_name)
	cfg.set_value("ui", "show_full_length_regions", _show_full_length_regions)
	cfg.set_value("ui", "colorize_nucleotides", _colorize_nucleotides)
	cfg.set_value("ui", "axis_coords_with_commas", _axis_coords_with_commas)
	cfg.set_value("ui", "gc_window_bp", _gc_window_bp)
	cfg.set_value("ui", "bam_cov_precompute_cutoff_bp", _bam_cov_precompute_cutoff_bp)
	cfg.set_value("ui", "annotation_max_on_screen", _annotation_max_on_screen)
	cfg.set_value("ui", "gc_plot_y_mode", _gc_plot_y_mode)
	cfg.set_value("ui", "gc_plot_y_min", _gc_plot_y_min)
	cfg.set_value("ui", "gc_plot_y_max", _gc_plot_y_max)
	cfg.set_value("ui", "depth_plot_y_mode", _depth_plot_y_mode)
	cfg.set_value("ui", "depth_plot_y_min", _depth_plot_y_min)
	cfg.set_value("ui", "depth_plot_y_max", _depth_plot_y_max)
	cfg.set_value("ui", "debug_enabled", _debug_enabled)
	cfg.set_value("input", "trackpad_pan_sensitivity", trackpad_pan_slider.value)
	cfg.set_value("input", "trackpad_pinch_sensitivity", trackpad_pinch_slider.value)
	cfg.set_value("input", "pan_step_percent", _pan_step_percent)
	cfg.save(CONFIG_PATH)

func _on_feature_clicked(feature: Dictionary) -> void:
	_track_settings_open = false
	_active_track_settings_id = ""
	feature_title_label.text = "Feature Details"
	_set_feature_labels_visible(true)
	feature_name_label.visible = true
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _search_controller != null:
		_search_controller.hide_panel()
	if _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false
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
	feature_title_label.text = "Feature Details"
	_set_feature_labels_visible(true)
	feature_name_label.visible = true
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _search_controller != null:
		_search_controller.hide_panel()
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
	if mate_start >= 0 and mate_end > mate_start:
		if _read_mate_jump_button == null:
			_read_mate_jump_button = Button.new()
			_read_mate_jump_button.text = "Jump to mate"
			_read_mate_jump_button.size_flags_horizontal = Control.SIZE_FILL
			feature_content.add_child(_read_mate_jump_button)
			_read_mate_jump_button.pressed.connect(func() -> void:
				_jump_to_mate(_read_mate_jump_start, _read_mate_jump_end)
			)
		_read_mate_jump_button.visible = true
		_read_mate_jump_start = mate_start
		_read_mate_jump_end = mate_end
	elif _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _jump_to_mate(start_bp: int, end_bp: int) -> void:
	if _current_chr_len <= 0:
		return
	if start_bp < 0 or end_bp <= start_bp:
		return
	var width_px := maxf(1.0, genome_view.size.x)
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var view_span_bp := int(ceil(current_bp_per_px * width_px))
	var center_bp := 0.5 * float(start_bp + end_bp)
	var target_start := maxi(0, int(floor(center_bp - 0.5 * float(view_span_bp))))
	genome_view.set_view_state(float(target_start), current_bp_per_px)
	genome_view.clear_region_selection()
	_schedule_fetch()

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
	genome_view.clear_selected_feature()
	genome_view.clear_selected_read()
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _search_controller != null:
		_search_controller.hide_panel()
	_slide_feature_panel(false, true)

func _process(delta: float) -> void:
	_drain_tile_fetch_result()
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("seqhiker_close_right_panel"):
		if _feature_panel_open:
			_close_feature_panel()
			get_viewport().set_input_as_handled()
