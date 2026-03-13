extends Control

const ThemesLibScript = preload("res://scripts/themes.gd")
const ZemClientScript = preload("res://scripts/zem_client.gd")
const LocalZemManagerScript = preload("res://scripts/local_zem_manager.gd")
const TileControllerScript = preload("res://scripts/tile_controller.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")
const GoPanelScene = preload("res://scenes/GoPanel.tscn")
const CONFIG_PATH := "user://seqhiker_settings.cfg"
const ZEM_BIN_SUBDIR := "bin"
const ZEM_DEFAULT_PORT := 9000
const READ_DETAIL_MAX_ZOOM := 7
const READ_RENDER_MAX_BP_PER_PX := 128.0
const DEFAULT_CONCAT_GAP_BP := 50
const DEFAULT_READ_THICKNESS := 8.0
const DEFAULT_READ_MAX_ROWS := 500
const DEFAULT_READ_MIN_MAPQ := 0
const DEFAULT_READ_HIDDEN_FLAGS := 256 | 512 | 1024 | 2048
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
const VIEW_SLOT_COUNT := 9
const VIEW_SLOT_LOAD_ACTION_PREFIX := "seqhiker_view_slot_load_"
const VIEW_SLOT_SAVE_ACTION_PREFIX := "seqhiker_view_slot_save_"
const SAM_FLAG_LABELS := [
	{"bit": 1, "label": "paired"},
	{"bit": 2, "label": "proper pair"},
	{"bit": 4, "label": "unmapped"},
	{"bit": 8, "label": "mate unmapped"},
	{"bit": 16, "label": "reverse strand"},
	{"bit": 32, "label": "mate reverse strand"},
	{"bit": 64, "label": "first in pair"},
	{"bit": 128, "label": "second in pair"},
	{"bit": 256, "label": "secondary alignment"},
	{"bit": 512, "label": "QC fail"},
	{"bit": 1024, "label": "duplicate"},
	{"bit": 2048, "label": "supplementary"}
]
const READ_FILTER_FLAG_LABELS := [
	{"bit": 1, "label": "paired"},
	{"bit": 2, "label": "proper pair"},
	{"bit": 8, "label": "mate unmapped"},
	{"bit": 16, "label": "reverse strand"},
	{"bit": 32, "label": "mate reverse strand"},
	{"bit": 64, "label": "first in pair"},
	{"bit": 128, "label": "second in pair"},
	{"bit": 256, "label": "secondary alignment"},
	{"bit": 512, "label": "QC fail"},
	{"bit": 1024, "label": "duplicate"},
	{"bit": 2048, "label": "supplementary"}
]
@onready var background: ColorRect = $Background
@onready var genome_view: Control = $Root/ContentMargin/ViewportLayer/GenomeView
@onready var settings_panel: PanelContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel
@onready var _viewport_layer: Control = $Root/ContentMargin/ViewportLayer
@onready var _settings_margin: MarginContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin
@onready var _settings_layout: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout
@onready var _settings_header: HBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsHeader
@onready var top_bar: HBoxContainer = $Root/TopBar
@onready var settings_toggle_button: Button = $Root/TopBar/SettingsToggleButton
@onready var search_button: Button = $Root/TopBar/ActionClipper/ActionStrip/SearchButton
@onready var go_button: Button = $Root/TopBar/ActionClipper/ActionStrip/GoButton
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
@onready var feature_panel: PanelContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel
@onready var _feature_margin: MarginContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin
@onready var _feature_layout: VBoxContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout
@onready var _feature_header: HBoxContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureHeader
@onready var feature_close_button: Button = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureHeader/FeatureCloseButton
@onready var feature_title_label: Label = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureHeader/FeatureTitle
@onready var feature_name_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureNameLabel
@onready var feature_type_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureTypeLabel
@onready var feature_range_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureRangeLabel
@onready var feature_strand_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureStrandLabel
@onready var feature_source_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureSourceLabel
@onready var feature_seq_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureSeqLabel
@onready var feature_content: VBoxContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent
@onready var feature_scroll: ScrollContainer = $Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll
@onready var ui_scale_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/UIScaleSlider
@onready var ui_scale_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/UIScaleValue
@onready var _font_size_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/FontSizeSpin
@onready var trackpad_pan_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPanSlider
@onready var trackpad_pan_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPanValue
@onready var trackpad_pinch_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPinchSlider
@onready var trackpad_pinch_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPinchValue
@onready var pan_step_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PanStepSlider
@onready var pan_step_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PanStepValue
@onready var play_speed_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PlaySpeedSlider
@onready var play_speed_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PlaySpeedValue
@onready var theme_option: OptionButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/ThemeOption
@onready var settings_scroll: ScrollContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll
@onready var settings_content: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent
@onready var _track_order_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityLabel
@onready var _track_visibility_box: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox
@onready var _bam_cov_cutoff_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/BAMCoverageCutoffLabel
@onready var _bam_cov_cutoff_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/BAMCoverageCutoffSpin
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
var _go_panel: VBoxContainer
var _go_chr_option: OptionButton
var _go_start_edit: LineEdit
var _go_end_edit: LineEdit
var _go_status_label: Label
var _local_zem_manager: RefCounted
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
var _has_sequence_loaded := false
var _pending_annotation_highlight: Dictionary = {}
var _cache_start := -1
var _cache_end := -1
var _cache_zoom := -1
var _cache_mode := -1
var _cache_need_reference := false
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
var _debug_loaded_files_label: Label
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
var _loaded_file_paths := PackedStringArray()

func _ready() -> void:
	_zem = ZemClientScript.new()
	_local_zem_manager = LocalZemManagerScript.new()
	_local_zem_manager.configure(_zem, ZEM_BIN_SUBDIR)
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
	_load_or_init_config()
	_apply_gc_plot_y_scale()
	_apply_depth_plot_y_scale()
	_apply_gc_plot_height()
	_apply_depth_plot_height()
	_update_window_min_height()
	_apply_theme(theme_option.get_item_text(theme_option.selected))
	call_deferred("_apply_settings_scrollbar_style")
	_on_ui_scale_changed(ui_scale_slider.value)
	_on_trackpad_pan_changed(trackpad_pan_slider.value)
	_on_trackpad_pinch_changed(trackpad_pinch_slider.value)
	_on_pan_step_changed(pan_step_slider.value)
	_on_play_speed_changed(play_speed_slider.value)
	_setup_fetch_timer()
	_setup_view_slot_shortcuts()
	if viewport_label != null:
		viewport_label.visible = true
	_settings_open = false
	_apply_settings_panel_offsets(false)
	settings_panel.visible = false
	_update_feature_panel_width()
	_apply_feature_panel_offsets(false)
	call_deferred("_initialize_settings_panel")
	call_deferred("_startup_connect_local_zem")
	if get_window().has_signal("files_dropped"):
		get_window().files_dropped.connect(_on_files_dropped)

func _initialize_settings_panel() -> void:
	_set_status("Disconnected")
	call_deferred("_update_settings_panel_width")
	call_deferred("_update_feature_panel_width")

func _startup_connect_local_zem() -> void:
	var host := "127.0.0.1"
	var port := ZEM_DEFAULT_PORT
	if not _local_zem_manager.should_try_local(host):
		return
	_set_status("Preparing local zem...")
	await get_tree().process_frame
	if not _local_zem_manager.ensure_local_zem_installed():
		var last_error: String = _local_zem_manager.last_error()
		if not last_error.is_empty():
			_set_status(last_error, true)
		else:
			_set_status("Local zem missing and install failed.", true)
		return
	_set_status("Starting local zem...")
	await get_tree().process_frame
	# Keep startup connect snappy so first frame/UI does not stall.
	if _local_zem_manager.connect_with_local_fallback(host, port, 100, 2, 80):
		_set_status("Connected %s:%d" % [host, port])
	else:
		var last_error: String = _local_zem_manager.last_error()
		if not last_error.is_empty():
			_set_status(last_error, true)

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
	go_button.pressed.connect(_toggle_go_panel)
	genome_view.viewport_changed.connect(_on_viewport_changed)
	genome_view.feature_clicked.connect(_on_feature_selected)
	genome_view.feature_activated.connect(_on_feature_clicked)
	genome_view.read_clicked.connect(_on_read_selected)
	genome_view.read_activated.connect(_on_read_clicked)
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
		go_button,
		pan_left_button,
		jump_start_button,
		pan_right_button,
		jump_end_button,
		zoom_out_button,
		zoom_in_button,
		play_button,
		play_left_button,
		stop_button,
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
	if open:
		settings_panel.visible = true
	var panel_w := _settings_panel_target_width()
	var open_left := 0.0
	var open_right := panel_w
	var closed_left := -panel_w - 2.0
	var closed_right := -2.0
	if animated:
		_settings_tween = create_tween()
		_settings_tween.set_trans(Tween.TRANS_CUBIC)
		_settings_tween.set_ease(Tween.EASE_OUT)
		_settings_tween.parallel().tween_property(settings_panel, "offset_left", open_left if open else closed_left, 0.24)
		_settings_tween.parallel().tween_property(settings_panel, "offset_right", open_right if open else closed_right, 0.24)
		if not open:
			_settings_tween.finished.connect(func() -> void:
				if not _settings_open:
					settings_panel.visible = false
			, CONNECT_ONE_SHOT)
	else:
		_apply_settings_panel_offsets(open)
		settings_panel.visible = open

func _slide_feature_panel(open: bool, animated: bool) -> void:
	if _feature_tween and _feature_tween.is_running():
		_feature_tween.kill()
	_update_feature_panel_width()
	var panel_w := _feature_panel_target_width()
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
		_apply_feature_panel_offsets(open)

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
	_debug_stats_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_debug_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_stats_label.visible = _debug_enabled
	_debug_stats_label.text = ""
	settings_content.add_child(_debug_stats_label)
	_debug_loaded_files_label = Label.new()
	_debug_loaded_files_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_debug_loaded_files_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debug_loaded_files_label.visible = _debug_enabled
	_debug_loaded_files_label.text = ""
	settings_content.add_child(_debug_loaded_files_label)
	_update_loaded_files_debug_label()

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
	_setup_go_panel()

func _setup_go_panel() -> void:
	var panel := GoPanelScene.instantiate()
	_go_panel = panel as VBoxContainer
	if _go_panel == null:
		return
	feature_content.add_child(_go_panel)
	_go_panel.visible = false
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
	if _debug_loaded_files_label != null:
		_debug_loaded_files_label.visible = enabled
	if enabled:
		_update_debug_stats_label()
		_update_loaded_files_debug_label()

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

func _update_loaded_files_debug_label() -> void:
	if _debug_loaded_files_label == null:
		return
	var lines := PackedStringArray(["Loaded files:"])
	if _loaded_file_paths.is_empty():
		lines.append("none")
	else:
		for path in _loaded_file_paths:
			lines.append(path)
	_debug_loaded_files_label.text = "\n".join(lines)
	call_deferred("_update_settings_panel_width")

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
		"map":
			return "Map"
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
	if _track_settings_open and _active_track_settings_id == TRACK_GENOME and track_id != TRACK_GENOME:
		_save_config()
	_set_feature_labels_visible(false)
	if _search_controller != null:
		_search_controller.hide_panel()
	if _go_panel != null:
		_go_panel.visible = false
	if _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false
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
		var filter_title := Label.new()
		filter_title.text = "Filter Reads"
		var mapq_label := Label.new()
		mapq_label.text = "Minimum MAPQ"
		var mapq_spin := SpinBox.new()
		mapq_spin.min_value = 0
		mapq_spin.max_value = 255
		mapq_spin.step = 1
		mapq_spin.allow_greater = false
		mapq_spin.allow_lesser = false
		mapq_spin.value = float(int(track_meta.get("min_mapq", DEFAULT_READ_MIN_MAPQ)))
		var hidden_flags := int(track_meta.get("hidden_flags", DEFAULT_READ_HIDDEN_FLAGS))
		_track_settings_box.add_child(thickness_label)
		_track_settings_box.add_child(thickness_spin)
		_track_settings_box.add_child(max_rows_label)
		_track_settings_box.add_child(max_rows_spin)
		_track_settings_box.add_child(filter_title)
		_track_settings_box.add_child(mapq_label)
		_track_settings_box.add_child(mapq_spin)
		for entry_any in READ_FILTER_FLAG_LABELS:
			var entry: Dictionary = entry_any
			var flag_bit := int(entry.get("bit", 0))
			var flag_cb := CheckBox.new()
			flag_cb.text = "Hide %s" % str(entry.get("label", ""))
			flag_cb.button_pressed = (hidden_flags & flag_bit) != 0
			flag_cb.toggled.connect(func(enabled: bool) -> void:
				for i in range(_bam_tracks.size()):
					var t: Dictionary = _bam_tracks[i]
					if str(t.get("track_id", "")) != track_id:
						continue
					var next_hidden := int(t.get("hidden_flags", 0))
					if enabled:
						next_hidden |= flag_bit
					else:
						next_hidden &= ~flag_bit
					t["hidden_flags"] = next_hidden
					_bam_tracks[i] = t
					break
				_schedule_fetch()
			)
			_track_settings_box.add_child(flag_cb)
			if flag_bit == 2:
				var improper_pair_cb := CheckBox.new()
				improper_pair_cb.text = "Hide improper pair"
				improper_pair_cb.button_pressed = bool(track_meta.get("hide_improper_pair", false))
				improper_pair_cb.toggled.connect(func(enabled: bool) -> void:
					for i in range(_bam_tracks.size()):
						var t: Dictionary = _bam_tracks[i]
						if str(t.get("track_id", "")) != track_id:
							continue
						t["hide_improper_pair"] = enabled
						_bam_tracks[i] = t
						break
					_schedule_fetch()
				)
				_track_settings_box.add_child(improper_pair_cb)
			elif flag_bit == 8:
				var mate_forward_cb := CheckBox.new()
				mate_forward_cb.text = "Hide mate forward strand"
				mate_forward_cb.button_pressed = bool(track_meta.get("hide_mate_forward_strand", false))
				mate_forward_cb.toggled.connect(func(enabled: bool) -> void:
					for i in range(_bam_tracks.size()):
						var t: Dictionary = _bam_tracks[i]
						if str(t.get("track_id", "")) != track_id:
							continue
						t["hide_mate_forward_strand"] = enabled
						_bam_tracks[i] = t
						break
					_schedule_fetch()
				)
				_track_settings_box.add_child(mate_forward_cb)
			elif flag_bit == 16:
				var forward_cb := CheckBox.new()
				forward_cb.text = "Hide forward strand"
				forward_cb.button_pressed = bool(track_meta.get("hide_forward_strand", false))
				forward_cb.toggled.connect(func(enabled: bool) -> void:
					for i in range(_bam_tracks.size()):
						var t: Dictionary = _bam_tracks[i]
						if str(t.get("track_id", "")) != track_id:
							continue
						t["hide_forward_strand"] = enabled
						_bam_tracks[i] = t
						break
					_schedule_fetch()
				)
				_track_settings_box.add_child(forward_cb)
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
		mapq_spin.value_changed.connect(func(value: float) -> void:
			for i in range(_bam_tracks.size()):
				var t: Dictionary = _bam_tracks[i]
				if str(t.get("track_id", "")) == track_id:
					t["min_mapq"] = clampi(int(round(value)), 0, 255)
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
	_maybe_save_genome_track_settings()
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
	if _go_panel != null:
		_go_panel.visible = false
	if _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false
	_search_controller.show_panel()
	_feature_panel_open = true
	_slide_feature_panel(true, true)
	_search_controller.focus_query()

func _toggle_go_panel() -> void:
	if _go_panel == null:
		return
	if _feature_panel_open and _go_panel.visible:
		_close_feature_panel()
		return
	_maybe_save_genome_track_settings()
	_track_settings_open = false
	_active_track_settings_id = ""
	_set_feature_labels_visible(false)
	feature_title_label.text = "Go to position"
	feature_name_label.visible = false
	feature_type_label.visible = false
	feature_range_label.visible = false
	feature_strand_label.visible = false
	feature_source_label.visible = false
	feature_seq_label.visible = false
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _search_controller != null:
		_search_controller.hide_panel()
	if _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false
	_go_panel.visible = true
	_refresh_go_chromosomes()
	_clear_go_status()
	_feature_panel_open = true
	_slide_feature_panel(true, true)

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

func _refresh_go_chromosomes() -> void:
	if _go_chr_option == null:
		return
	_go_chr_option.clear()
	for c in _chromosomes:
		_go_chr_option.add_item(str(c.get("name", "chr")), int(c.get("id", -1)))
	var target_id := _current_chr_id if _current_chr_id >= 0 else _selected_seq_id
	if _seq_view_mode == SEQ_VIEW_CONCAT and _concat_segments.size() > 0:
		var center_bp := int(floor(0.5 * float(_last_start + _last_end)))
		var overlaps := _segments_overlapping(center_bp, center_bp + 1)
		if not overlaps.is_empty():
			target_id = int(overlaps[0].get("id", -1))
	if target_id < 0 and _chromosomes.size() > 0:
		target_id = int(_chromosomes[0].get("id", -1))
	for i in range(_go_chr_option.item_count):
		if int(_go_chr_option.get_item_id(i)) == target_id:
			_go_chr_option.select(i)
			return
	if _go_chr_option.item_count > 0:
		_go_chr_option.select(0)

func _clear_go_status() -> void:
	if _go_status_label != null:
		_go_status_label.text = ""

func _set_go_status(message: String, is_error: bool = false) -> void:
	if _go_status_label != null:
		_go_status_label.text = message
	if is_error:
		_set_status(message, true)

func _parse_go_bp(text: String) -> int:
	var clean := text.strip_edges().replace(",", "").replace(" ", "")
	if clean.is_empty():
		return -1
	if not clean.is_valid_int():
		return -1
	var value := int(clean)
	if value < 0:
		return -1
	return value

func _apply_go_request() -> void:
	if _go_chr_option == null or _go_start_edit == null:
		return
	_clear_go_status()
	if _chromosomes.is_empty():
		_set_go_status("No chromosomes loaded.", true)
		return
	var selected_chr_id := int(_go_chr_option.get_selected_id())
	var chr_len := 0
	var chr_name := ""
	for c in _chromosomes:
		if int(c.get("id", -1)) == selected_chr_id:
			chr_len = int(c.get("length", 0))
			chr_name = str(c.get("name", "chr"))
			break
	if chr_len <= 0:
		_set_go_status("Chromosome length unavailable.", true)
		return
	var start_bp := _parse_go_bp(_go_start_edit.text)
	if start_bp < 0:
		_set_go_status("Enter a valid start position.", true)
		return
	var end_bp := _parse_go_bp(_go_end_edit.text) if _go_end_edit != null else -1
	if start_bp > chr_len:
		_set_go_status("Start position beyond chromosome length.", true)
		return
	if end_bp >= 0 and end_bp < start_bp:
		var swap := start_bp
		start_bp = end_bp
		end_bp = swap
	if end_bp > chr_len:
		end_bp = chr_len
	if _seq_view_mode != SEQ_VIEW_SINGLE:
		_seq_view_option.select(SEQ_VIEW_SINGLE)
		_on_seq_view_selected(SEQ_VIEW_SINGLE)
	for i in range(_seq_option.item_count):
		if int(_seq_option.get_item_id(i)) == selected_chr_id:
			_seq_option.select(i)
			_on_seq_selected(i)
			break
	var width_px := maxf(1.0, genome_view.size.x)
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	if end_bp >= 0:
		var span_bp := maxi(1, end_bp - start_bp)
		var bp_per_px := clampf(float(span_bp) / width_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
		genome_view.set_view_state(float(start_bp), bp_per_px)
		genome_view.clear_region_selection()
		_set_go_status("%s:%d-%d" % [chr_name, start_bp, end_bp])
	else:
		var view_span_bp := int(ceil(current_bp_per_px * width_px))
		var target_start := maxi(0, int(floor(float(start_bp) - 0.5 * float(view_span_bp))))
		genome_view.set_view_state(float(target_start), current_bp_per_px)
		genome_view.clear_region_selection()
		_set_go_status("%s:%d" % [chr_name, start_bp])
	_schedule_fetch()
	_close_feature_panel()

func _search_get_zem() -> RefCounted:
	return _zem

func _search_get_chromosomes() -> Array[Dictionary]:
	return _chromosomes

func _search_get_selected_seq_id() -> int:
	return _selected_seq_id

func _maybe_save_genome_track_settings() -> void:
	if _track_settings_open and _active_track_settings_id == TRACK_GENOME:
		_save_config()

func _set_feature_labels_visible(show_labels: bool) -> void:
	feature_type_label.visible = show_labels
	feature_range_label.visible = show_labels
	feature_strand_label.visible = show_labels
	feature_source_label.visible = show_labels
	feature_seq_label.visible = show_labels

func _on_seq_view_selected(index: int) -> void:
	if _seq_view_option != null and _seq_view_option.selected != index:
		_seq_view_option.select(index)
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
	_apply_panel_style(settings_panel, palette)
	_apply_panel_style(feature_panel, palette)
	_apply_search_theme(palette)
	if _debug_stats_label != null:
		_debug_stats_label.add_theme_color_override("font_color", palette["text"])
	if _debug_loaded_files_label != null:
		_debug_loaded_files_label.add_theme_color_override("font_color", palette["text"])
	_apply_topbar_button_font_size()
	_apply_settings_scrollbar_style()
	call_deferred("_update_settings_panel_width")
	call_deferred("_update_feature_panel_width")

func _update_settings_panel_width() -> void:
	if settings_panel == null or _settings_layout == null or _settings_margin == null or _viewport_layer == null or _settings_header == null:
		return
	var layout_min_w := maxf(
		_settings_header.get_combined_minimum_size().x,
		_measure_settings_content_width(settings_content)
	)
	var margin_left := float(_settings_margin.get_theme_constant("margin_left"))
	var margin_right := float(_settings_margin.get_theme_constant("margin_right"))
	var scroll_right := 22.0
	var width_slack := 18.0
	var target_w := ceilf(layout_min_w + margin_left + margin_right + scroll_right + width_slack)
	if _bam_cov_cutoff_label != null:
		target_w = maxf(target_w, ceilf(_bam_cov_cutoff_label.get_combined_minimum_size().x + margin_left + margin_right + scroll_right + width_slack))
	target_w = maxf(target_w, 300.0)
	var max_w := maxf(300.0, _viewport_layer.size.x - 24.0)
	target_w = minf(target_w, max_w)
	settings_panel.custom_minimum_size.x = target_w
	_apply_settings_panel_offsets(_settings_open)

func _settings_panel_target_width() -> float:
	return maxf(settings_panel.custom_minimum_size.x, 300.0)

func _feature_panel_target_width() -> float:
	return maxf(feature_panel.custom_minimum_size.x, 320.0)

func _apply_settings_panel_offsets(open: bool) -> void:
	var panel_w := _settings_panel_target_width()
	if open:
		settings_panel.offset_left = 0.0
		settings_panel.offset_right = panel_w
	else:
		settings_panel.offset_left = -panel_w - 2.0
		settings_panel.offset_right = -2.0

func _apply_feature_panel_offsets(open: bool) -> void:
	var panel_w := _feature_panel_target_width()
	var closed_w := float(ceili(panel_w)) + 2.0
	if open:
		feature_panel.offset_left = -panel_w
		feature_panel.offset_right = 0.0
	else:
		feature_panel.offset_left = 0.0
		feature_panel.offset_right = closed_w

func _measure_settings_content_width(node: Node) -> float:
	if node == null:
		return 0.0
	if node is Label:
		var label := node as Label
		if label.autowrap_mode != TextServer.AUTOWRAP_OFF:
			return 0.0
	if node is Control:
		var control := node as Control
		var own_width := control.get_combined_minimum_size().x
		var child_width := 0.0
		for child in control.get_children():
			child_width = maxf(child_width, _measure_settings_content_width(child))
		return maxf(own_width, child_width)
	var widest := 0.0
	for child in node.get_children():
		widest = maxf(widest, _measure_settings_content_width(child))
	return widest

func _update_feature_panel_width() -> void:
	if feature_panel == null or _feature_layout == null or _feature_margin == null or _viewport_layer == null or _feature_header == null:
		return
	var layout_min_w := maxf(
		_feature_header.get_combined_minimum_size().x,
		_measure_settings_content_width(feature_content)
	)
	var margin_left := float(_feature_margin.get_theme_constant("margin_left"))
	var margin_right := float(_feature_margin.get_theme_constant("margin_right"))
	var scroll_right := 22.0
	var width_slack := 18.0
	var target_w := ceilf(layout_min_w + margin_left + margin_right + scroll_right + width_slack)
	target_w = maxf(target_w, 320.0)
	var max_w := maxf(320.0, _viewport_layer.size.x - 24.0)
	target_w = minf(target_w, max_w)
	feature_panel.custom_minimum_size.x = target_w
	_apply_feature_panel_offsets(_feature_panel_open)

func _apply_settings_scrollbar_style() -> void:
	_apply_scrollbar_width(settings_scroll)
	_apply_scrollbar_width(feature_scroll)

func _apply_scrollbar_width(scroll: ScrollContainer) -> void:
	if scroll == null:
		return
	var vbar := scroll.get_v_scroll_bar()
	if vbar != null:
		vbar.add_theme_constant_override("scroll_size", 14)
		vbar.custom_minimum_size.x = 14
		vbar.size.x = 14

func _apply_panel_style(panel: PanelContainer, palette: Dictionary) -> void:
	if panel == null:
		return
	var panel_sb := StyleBoxFlat.new()
	var bg: Color = palette["panel"]
	bg.a = 0.95
	panel_sb.bg_color = bg
	panel_sb.border_color = palette["border"]
	panel_sb.set_border_width_all(1)
	panel_sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_sb)

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
	if not _ensure_server_connected():
		return
	var drop_info := _inspect_dropped_files(files)
	if not drop_info.get("ok", false):
		_set_status(str(drop_info.get("error", "Unable to inspect dropped files.")), true)
		return
	var dropped_sequence := bool(drop_info.get("has_sequence", false))
	if int(drop_info.get("sequence_root_count", 0)) > 1:
		_set_status("Drop only one sequence-bearing genome source at a time.", true)
		return
	if dropped_sequence:
		_reset_loaded_state()
	else:
		_view_slots.clear()
	if not _load_dropped_files(files):
		return
	_record_loaded_files(files, dropped_sequence)
	genome_view.load_files(files)
	_refresh_sequence_loaded_state()
	_refresh_chromosomes()
	_refresh_visible_data()

func _ensure_server_connected() -> bool:
	if _zem.ensure_connected():
		_refresh_sequence_loaded_state()
		_set_status("Connected")
		return true
	var host := "127.0.0.1"
	var port := ZEM_DEFAULT_PORT
	if _local_zem_manager.connect_with_local_fallback(host, port):
		_refresh_sequence_loaded_state()
		_set_status("Connected %s:%d" % [host, port])
		return true
	var msg := "Disconnected"
	var last_error: String = _local_zem_manager.last_error()
	if not last_error.is_empty():
		msg = last_error
	_set_status(msg, true)
	return false

func _refresh_sequence_loaded_state() -> void:
	var resp: Dictionary = _zem.get_load_state()
	if resp.get("ok", false):
		_has_sequence_loaded = bool(resp.get("has_sequence", false))

func _inspect_dropped_files(files: PackedStringArray) -> Dictionary:
	var sequence_root_count := 0
	for path in files:
		if path.get_extension().to_lower() == "bam":
			continue
		var resp: Dictionary = _zem.inspect_input(path)
		if not resp.get("ok", false):
			return {"ok": false, "error": "Inspect input failed: %s" % resp.get("error", "error")}
		if bool(resp.get("has_sequence", false)):
			sequence_root_count += 1
	return {
		"ok": true,
		"has_sequence": sequence_root_count > 0,
		"sequence_root_count": sequence_root_count
	}

func _exit_tree() -> void:
	if _tile_controller != null:
		_tile_controller.shutdown()
	if _local_zem_manager != null:
		_local_zem_manager.shutdown_on_exit()

func _load_dropped_files(files: PackedStringArray) -> bool:
	var genome_targets: Array[String] = []
	var bam_targets: Array[String] = []
	for path in files:
		var ext := path.get_extension().to_lower()
		if ext == "bam":
			bam_targets.append(path)
		else:
			if genome_targets.find(path) < 0:
				genome_targets.append(path)
	var pending := genome_targets.duplicate()
	while not pending.is_empty():
		var deferred: Array[String] = []
		var progress := false
		for target in pending:
			var resp: Dictionary = _zem.load_genome(target)
			if resp.get("ok", false):
				progress = true
				continue
			var err_msg := str(resp.get("error", "error"))
			if err_msg.contains("no reference sequence loaded"):
				deferred.append(target)
				continue
			_set_status("Load genome failed: %s" % err_msg, true)
			return false
		if deferred.is_empty():
			break
		if not progress:
			_set_status("Load genome failed: no reference sequence loaded; load a sequence file first.", true)
			return false
		pending = deferred

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
			"max_rows": DEFAULT_READ_MAX_ROWS,
			"min_mapq": DEFAULT_READ_MIN_MAPQ,
			"hidden_flags": DEFAULT_READ_HIDDEN_FLAGS,
			"hide_improper_pair": false,
			"hide_forward_strand": false,
			"hide_mate_forward_strand": false
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
	_refresh_go_chromosomes()
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

func _collapse_gene_cds_features(features_in: Array[Dictionary]) -> Array[Dictionary]:
	var gene_index_by_key := {}
	for i in range(features_in.size()):
		var feature: Dictionary = features_in[i]
		if str(feature.get("type", "")).to_lower() != "gene":
			continue
		gene_index_by_key[_feature_pair_key(feature)] = i
	var drop_indexes := {}
	for i in range(features_in.size()):
		var feature: Dictionary = features_in[i]
		if str(feature.get("type", "")).to_lower() != "cds":
			continue
		var parent_id := str(feature.get("parent", "")).strip_edges()
		if parent_id.is_empty():
			continue
		var pair_key := _feature_pair_key(feature)
		if not gene_index_by_key.has(pair_key):
			continue
		var gene_idx := int(gene_index_by_key[pair_key])
		var gene_feature: Dictionary = features_in[gene_idx]
		if parent_id != str(gene_feature.get("id", "")).strip_edges():
			continue
		gene_feature["paired_cds"] = feature.duplicate(true)
		features_in[gene_idx] = gene_feature
		drop_indexes[i] = true
	var out: Array[Dictionary] = []
	for i in range(features_in.size()):
		if drop_indexes.get(i, false):
			continue
		out.append(features_in[i])
	return out

func _feature_pair_key(feature: Dictionary) -> String:
	return "%s|%s|%d|%d|%s" % [
		str(feature.get("seq_name", "")),
		str(feature.get("strand", "")),
		int(feature.get("start", 0)),
		int(feature.get("end", 0)),
		str(feature.get("source", ""))
	]

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
	var need_annotations: bool = show_aa or show_genome
	var need_reference: bool = genome_view.needs_reference_data(show_aa, show_genome)
	var span: int = maxi(1, _last_end - _last_start)
	var right_span_mult := 3 if _auto_play_enabled else 2
	var query_start: int = maxi(0, _last_start - span)
	var query_end: int = mini(_current_chr_len, _last_end + span * right_span_mult)
	var ref_start := query_start
	var ref_sequence := ""
	var overlaps: Array[Dictionary] = []
	var visible_track_ids := {}
	for t_any in _bam_tracks:
		var track_vis: Dictionary = t_any
		var track_vis_id := str(track_vis.get("track_id", ""))
		visible_track_ids[track_vis_id] = genome_view.is_track_visible(track_vis_id)

	if _seq_view_mode == SEQ_VIEW_SINGLE:
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
		if need_reference:
			ref_sequence = _build_concat_reference(query_start, query_end, overlaps)
	genome_view.set_reference_slice(ref_start, ref_sequence)
	_tile_fetch_serial += 1
	_pending_tile_apply = {
		"serial": _tile_fetch_serial,
		"query_start": query_start,
		"query_end": query_end,
		"need_reference": need_reference,
		"ref_start": ref_start,
		"ref_sequence": ref_sequence
	}
	_tile_controller.request_tiles({
		"serial": _tile_fetch_serial,
		"host": "127.0.0.1",
		"port": ZEM_DEFAULT_PORT,
		"generation": _tile_cache_generation,
		"scope_key": _scope_cache_key(),
			"query_start": query_start,
			"query_end": query_end,
			"last_bp_per_px": _last_bp_per_px,
			"show_reads": show_reads,
			"show_annotations": need_annotations,
			"show_gc_plot": show_gc_plot,
			"show_depth_plot": show_depth_plot,
			"has_bam_loaded": _has_bam_loaded,
			"seq_view_mode": _seq_view_mode,
			"current_chr_id": _current_chr_id,
			"bam_tracks": _bam_tracks,
			"overlaps": overlaps,
			"visible_track_ids": visible_track_ids,
			"gc_window_bp": _gc_window_bp,
			"annotation_cap_total": _annotation_pixel_budget(),
			"annotation_min_len_bp": _annotation_min_feature_len_bp()
			})
	return

func _annotation_pixel_budget() -> int:
	return ANNOT_MAX_ON_SCREEN_MAX

func _annotation_min_feature_len_bp() -> int:
	var min_px := 3.0
	var raw := int(ceil(min_px * _last_bp_per_px))
	return maxi(raw, 1)

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
	var annotation_features_raw: Array = tile_resp.get("annotation_features", [])
	var annotation_stats: Dictionary = tile_resp.get("annotation_stats", {})
	var all_gc_plot_tiles: Array = tile_resp.get("gc_plot_tiles", [])
	var all_depth_plot_tiles: Array = tile_resp.get("depth_plot_tiles", [])
	var all_depth_plot_series: Array = tile_resp.get("depth_plot_series", [])
	var annotation_features: Array[Dictionary] = []
	for feat_any in annotation_features_raw:
		if typeof(feat_any) == TYPE_DICTIONARY:
			annotation_features.append(feat_any)
	annotation_features = _collapse_gene_cds_features(annotation_features)
	genome_view.set_features(annotation_features)
	_apply_pending_annotation_highlight(annotation_features)
	var gc_plot_tiles_typed: Array[Dictionary] = []
	for tile_any in all_gc_plot_tiles:
		if typeof(tile_any) == TYPE_DICTIONARY:
			gc_plot_tiles_typed.append(tile_any)
	var depth_plot_tiles_typed: Array[Dictionary] = []
	for tile_any in all_depth_plot_tiles:
		if typeof(tile_any) == TYPE_DICTIONARY:
			depth_plot_tiles_typed.append(tile_any)
	var depth_plot_series_typed: Array[Dictionary] = []
	for series_any in all_depth_plot_series:
		if typeof(series_any) == TYPE_DICTIONARY:
			depth_plot_series_typed.append(series_any)
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
	genome_view.set_gc_plot_tiles(gc_plot_tiles_typed)
	genome_view.set_depth_plot_tiles(depth_plot_tiles_typed)
	for i in range(depth_plot_series_typed.size()):
		var series: Dictionary = depth_plot_series_typed[i]
		series["color"] = _depth_plot_color_for_track(str(series.get("track_id", "")))
		depth_plot_series_typed[i] = series
	genome_view.set_depth_plot_series(depth_plot_series_typed)
	_cache_start = int(_pending_tile_apply.get("query_start", -1))
	_cache_end = int(_pending_tile_apply.get("query_end", -1))
	_cache_zoom = _compute_tile_zoom(_last_bp_per_px)
	_cache_mode = 0 if (_has_bam_loaded and _any_visible_read_track() and _last_bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
	_cache_need_reference = bool(_pending_tile_apply.get("need_reference", false))
	_cache_scope_key = _scope_cache_key()
	_dbg_ann_tile_requests = int(annotation_stats.get("tile_requests", 0))
	_dbg_ann_tile_cache_hits = int(annotation_stats.get("tile_cache_hits", 0))
	_dbg_ann_tile_queries = int(annotation_stats.get("tile_queries", 0))
	_dbg_ann_features_examined = int(annotation_stats.get("features_examined", 0))
	_dbg_ann_features_out = int(annotation_stats.get("features_out", 0))
	_dbg_ann_fetch_time_ms = float(annotation_stats.get("fetch_time_ms", 0.0))
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

func _record_loaded_files(files: PackedStringArray, replace_existing: bool) -> void:
	if replace_existing:
		_loaded_file_paths = PackedStringArray()
	for path in files:
		if not _loaded_file_paths.has(path):
			_loaded_file_paths.append(path)
	_update_loaded_files_debug_label()

func _reset_loaded_state() -> void:
	_loaded_file_paths = PackedStringArray()
	_update_loaded_files_debug_label()
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
	_has_sequence_loaded = false
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
	if _debug_loaded_files_label != null:
		_debug_loaded_files_label.visible = _debug_enabled
	_refresh_track_order_list(genome_view.get_track_order())

func _select_theme_option(theme_name: String) -> void:
	for i in range(theme_option.item_count):
		if theme_option.get_item_text(i) == theme_name:
			theme_option.select(i)
			return

func _save_config() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("ui", "scale", ui_scale_slider.value)
	cfg.set_value("ui", "play_speed_widths_per_sec", play_speed_slider.value)
	cfg.set_value("ui", "theme", theme_option.get_item_text(theme_option.selected))
	cfg.set_value("ui", "font_size", _ui_font_size)
	cfg.set_value("ui", "sequence_view_mode", _seq_view_mode)
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
	feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var seq_text := "Sequence: %s" % str(feature.get("seq_name", _current_chr_name))
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
	feature_seq_label.text = seq_text
	_feature_panel_open = true
	_slide_feature_panel(true, true)

func _on_feature_selected(feature: Dictionary) -> void:
	if not _feature_panel_open:
		return
	_on_feature_clicked(feature)

func _on_read_clicked(read: Dictionary) -> void:
	_track_settings_open = false
	_active_track_settings_id = ""
	feature_title_label.text = "Feature Details"
	_set_feature_labels_visible(true)
	feature_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_type_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_range_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_strand_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feature_seq_label.autowrap_mode = TextServer.AUTOWRAP_OFF
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
	feature_name_label.text = "Read: %s" % read_name
	feature_type_label.text = "Range: %d - %d (%d bp)" % [start_bp, end_bp, read_len]
	feature_range_label.text = "CIGAR: %s" % cigar
	feature_strand_label.text = "Strand: %s | MAPQ: %d | Flags: %d" % [strand, mapq, flags]
	feature_source_label.text = "%s | Fragment: %d bp" % [mate_text, frag_len]
	feature_seq_label.text = "Flags:\n%s" % _format_read_flags(flags)
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

func _on_read_selected(read: Dictionary) -> void:
	if not _feature_panel_open:
		return
	_on_read_clicked(read)

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

func _format_read_flags(flags: int) -> String:
	var lines: Array[String] = []
	for entry_any in SAM_FLAG_LABELS:
		var entry: Dictionary = entry_any
		var bit := int(entry.get("bit", 0))
		var marker := "✓" if (flags & bit) != 0 else "✗"
		lines.append("%s %s (%d)" % [marker, str(entry.get("label", "")), bit])
	return "\n".join(lines)

func _close_feature_panel() -> void:
	_maybe_save_genome_track_settings()
	_feature_panel_open = false
	_track_settings_open = false
	_active_track_settings_id = ""
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _search_controller != null:
		_search_controller.hide_panel()
	if _go_panel != null:
		_go_panel.visible = false
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
