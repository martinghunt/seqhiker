extends Control

const ThemesLibScript = preload("res://scripts/themes.gd")
const ZemClientScript = preload("res://scripts/zem_client.gd")
const LocalZemManagerScript = preload("res://scripts/local_zem_manager.gd")
const TileControllerScript = preload("res://scripts/tile_controller.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")
const GoControllerScript = preload("res://scripts/go_controller.gd")
const TopBarControllerScript = preload("res://scripts/top_bar_controller.gd")
const AnnotationCacheControllerScript = preload("res://scripts/annotation_cache_controller.gd")
const FeaturePanelControllerScript = preload("res://scripts/feature_panel_controller.gd")
const SessionLoaderScript = preload("res://scripts/session_loader.gd")
const ComparisonControllerScript = preload("res://scripts/comparison_controller.gd")
const ReadTrackSettingsPanelScene = preload("res://scenes/ReadTrackSettingsPanel.tscn")
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
const GENOME_CACHE_MAX_MB_DEFAULT := 50
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
const CONTEXT_PANEL_NONE := 0
const CONTEXT_PANEL_FEATURE := 1
const CONTEXT_PANEL_TRACK_SETTINGS := 2
const CONTEXT_PANEL_SEARCH := 3
const CONTEXT_PANEL_GO := 4
const CONTEXT_PANEL_DOWNLOAD := 5
const CONTEXT_PANEL_SELECTED_MATCHES := 6
const DEFAULT_PLOT_HEIGHT := 100.0
const MIN_PLOT_HEIGHT := 50.0
const MAX_PLOT_HEIGHT := 360.0
const ROOT_VERTICAL_GAP := 8.0
const CONTENT_MARGIN_BOTTOM := 10.0
const READS_TRACK_MIN_HEIGHT := 140.0
const DEFAULT_UI_FONT_SIZE := 15
const MIN_UI_FONT_SIZE := 8
const MAX_UI_FONT_SIZE := 26
const VIEW_SLOT_COUNT := 9
const APP_MODE_BROWSER := 0
const APP_MODE_COMPARISON := 1
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
@onready var screenshot_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ScreenshotButton
@onready var search_button: Button = $Root/TopBar/ActionClipper/ActionStrip/SearchButton
@onready var go_button: Button = $Root/TopBar/ActionClipper/ActionStrip/GoButton
@onready var download_button: Button = $Root/TopBar/ActionClipper/ActionStrip/DownloadButton
@onready var comparison_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ComparisonButton
@onready var comparison_save_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ComparisonSaveButton
@onready var comparison_clear_button: Button = $Root/TopBar/ActionClipper/ActionStrip/ComparisonClearButton
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
@onready var comparison_view: Control = $Root/ContentMargin/ViewportLayer/ComparisonView
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
@onready var _font_size_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/FontSizeRow/FontSizeSlider
@onready var trackpad_pan_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPanSlider
@onready var trackpad_pinch_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackpadPinchSlider
@onready var enable_vertical_swipe_zoom_button: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/EnableVerticalSwipeZoom
@onready var mouse_wheel_zoom_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/MouseWheelZoomSlider
@onready var invert_mouse_wheel_zoom_button: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/InvertMouseWheelZoom
@onready var mouse_wheel_pan_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/MouseWheelPanSlider
@onready var pan_step_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PanStepRow/PanStepSlider
@onready var pan_step_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PanStepRow/PanStepValue
@onready var play_speed_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PlaySpeedRow/PlaySpeedSlider
@onready var play_speed_value: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/PlaySpeedRow/PlaySpeedValue
@onready var animate_pan_zoom_slider: HSlider = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/AnimatePanZoomSlider
@onready var theme_option: OptionButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/ThemeOption
@onready var ui_font_option: OptionButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/UIFontOption
@onready var sequence_letter_font_option: OptionButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/SequenceLetterFontOption
@onready var settings_scroll: ScrollContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll
@onready var settings_content: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent
@onready var _track_order_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityLabel
@onready var _track_visibility_box: VBoxContainer = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox
@onready var _track_visibility_aa: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox/ShowAATrack
@onready var _track_visibility_genome: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox/ShowGenomeTrack
@onready var _track_visibility_gc_plot: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox/ShowGCPlotTrack
@onready var _track_visibility_depth_plot: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox/ShowDepthPlotTrack
@onready var _track_visibility_map: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/TrackVisibilityBox/ShowMapTrack
@onready var _bam_cov_cutoff_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/BAMCoverageCutoffLabel
@onready var _bam_cov_cutoff_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/BAMCoverageCutoffSpin
@onready var _genome_cache_spin: SpinBox = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/GenomeCacheSpin
@onready var _genome_cache_clear_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/ClearGenomeCacheButton
@onready var _generate_test_data_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/UseTestDataButton
@onready var _open_user_data_dir_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/OpenUserDataDirButton
@onready var _debug_toggle: CheckButton = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/DebugToggle
@onready var _debug_stats_label: RichTextLabel = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/DebugStatsLabel
@onready var _debug_loaded_files_label: Label = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/DebugLoadedFilesLabel
@onready var close_settings_button: Button = $Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsHeader/CloseSettingsButton

var _settings_open := false
var _settings_tween: Tween
var _settings_toggle_icon_label: Label
var _feature_panel_open := false
var _context_panel_mode := CONTEXT_PANEL_NONE
var _feature_tween: Tween
var _fetch_timer: Timer
var _fetch_in_progress := false
var _fetch_pending := false
var tile_fetch_serial := 0
var _tile_cache_generation := 0

var _zem: RefCounted
var _tile_controller: RefCounted
var _search_controller: RefCounted
var _go_controller: RefCounted
var _top_bar_controller: RefCounted
var _annotation_cache_controller: RefCounted
var _feature_panel_controller: RefCounted
var _session_loader: RefCounted
var _comparison_controller: RefCounted
var _download_panel: VBoxContainer
var _download_accession_edit: LineEdit
var _download_action_button: Button
var _download_status_label: RichTextLabel
var _download_thread: Thread
var _download_in_progress := false
var _screenshot_dialog: FileDialog
var _comparison_save_dialog: FileDialog
var _startup_zem_prepare_thread: Thread
var _startup_zem_connect_thread: Thread
var _startup_zem_host := "127.0.0.1"
var _startup_zem_port := ZEM_DEFAULT_PORT
var _local_zem_manager: RefCounted
var _connected_zem_version := ""
var _current_chr_id := -1
var _current_chr_name := ""
var _current_chr_len := 0
var _last_start := 0
var _last_end := 0
var _prev_view_start := 0
var _prev_view_end := 0
var _last_bp_per_px := 8.0
var _selection_active := false
var _selection_start := 0
var _selection_end := 0
var _has_bam_loaded := false
var _bam_tracks: Array[Dictionary] = []
var _bam_track_serial := 0
var center_strand_scroll_pending := false
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
var _auto_play_tween_active := false
var _read_view_label: Label
var _read_view_option: OptionButton
var _fragment_log_checkbox: CheckBox
var _read_thickness_label: Label
var _read_thickness_spin: SpinBox
var _show_full_region_checkbox: CheckBox
var _track_order_list: ItemList
var _read_mate_jump_button: Button
var read_mate_jump_start := -1
var read_mate_jump_end := -1
var read_mate_jump_ref_id := -1
var _ui_font_size := DEFAULT_UI_FONT_SIZE
var _ui_font_name := "Noto Sans"
var _sequence_letter_font_name := "Anonymous Pro"
var _track_dragging := false
var _track_drag_index := -1
var _track_drop_index := -1
var _pending_pan_target_start := -1.0
var _pending_pan_target_end := -1
var _pending_pan_bp_per_px := -1.0
var _pending_pan_duration := 0.35
var _pending_pan_active := false
var _pending_pan_linear := false
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
var _read_track_settings_panel: VBoxContainer
var _track_settings_open := false
var _active_track_settings_id := ""
var _debug_enabled := false
var _bam_cov_precompute_cutoff_bp := BAM_COV_PRECOMPUTE_CUTOFF_DEFAULT
var _genome_cache_max_mb := GENOME_CACHE_MAX_MB_DEFAULT
var _generate_test_data_thread: Thread
var _generate_test_data_in_progress := false
var _generate_comparison_test_data_thread: Thread
var _generate_comparison_test_data_in_progress := false
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
var _view_slots := {
	APP_MODE_BROWSER: {},
	APP_MODE_COMPARISON: {}
}
var _view_slot_shortcut_buttons: Array[Button] = []
var _pan_step_percent := 75.0
var _loaded_file_paths := PackedStringArray()
var _app_mode := APP_MODE_BROWSER
var _settings_view_label: Label
var _settings_view_box: VBoxContainer
var _settings_shared_label: Label
var _settings_shared_box: VBoxContainer
var _shared_colorize_nucleotides_cb: CheckButton

func _ready() -> void:
	_zem = ZemClientScript.new()
	_local_zem_manager = LocalZemManagerScript.new()
	_local_zem_manager.configure(_zem, ZEM_BIN_SUBDIR)
	_tile_controller = TileControllerScript.new()
	_search_controller = SearchControllerScript.new()
	_annotation_cache_controller = AnnotationCacheControllerScript.new()
	_annotation_cache_controller.configure(self)
	_feature_panel_controller = FeaturePanelControllerScript.new()
	_feature_panel_controller.configure(self)
	_session_loader = SessionLoaderScript.new()
	_session_loader.configure(self)
	_tile_controller.configure(Callable(self, "_compute_tile_zoom"))
	_themes_lib = ThemesLibScript.new()
	_comparison_controller = ComparisonControllerScript.new()
	_comparison_controller.configure(self, _zem, _themes_lib, comparison_view)
	_top_bar_controller = TopBarControllerScript.new()
	_top_bar_controller.configure(self)
	_disable_button_focus()
	_top_bar_controller.setup()
	_setup_theme_selector()
	_setup_ui_font_selector()
	_setup_sequence_letter_font_selector()
	_setup_font_size_control()
	_setup_read_view_controls()
	_setup_sequence_controls()
	_setup_track_visibility_controls()
	_sync_bam_read_tracks()
	_setup_debug_controls()
	_setup_track_settings_panel()
	_connect_ui()
	_setup_settings_sections()
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
	_on_enable_vertical_swipe_zoom_toggled(enable_vertical_swipe_zoom_button.button_pressed)
	_on_mouse_wheel_zoom_changed(mouse_wheel_zoom_slider.value)
	_on_invert_mouse_wheel_zoom_toggled(invert_mouse_wheel_zoom_button.button_pressed)
	_on_mouse_wheel_pan_changed(mouse_wheel_pan_slider.value)
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
	if screenshot_button != null:
		screenshot_button.pressed.connect(_on_screenshot_pressed)
	_setup_screenshot_dialog()
	_setup_comparison_save_dialog()
	_comparison_controller.configure(self, _zem, _themes_lib, comparison_view)
	_comparison_controller.setup()

func _setup_screenshot_dialog() -> void:
	_screenshot_dialog = FileDialog.new()
	_screenshot_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_screenshot_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_screenshot_dialog.use_native_dialog = true
	_screenshot_dialog.title = "Save Screenshot as SVG"
	_screenshot_dialog.filters = PackedStringArray(["*.svg ; SVG files"])
	_screenshot_dialog.file_selected.connect(_on_screenshot_file_selected)
	add_child(_screenshot_dialog)

func _setup_comparison_save_dialog() -> void:
	_comparison_save_dialog = FileDialog.new()
	_comparison_save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_comparison_save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_comparison_save_dialog.use_native_dialog = true
	_comparison_save_dialog.title = "Save Comparison Session"
	_comparison_save_dialog.filters = PackedStringArray(["*.seqhikercmp ; Seqhiker comparison sessions"])
	_comparison_save_dialog.file_selected.connect(_on_comparison_save_file_selected)
	add_child(_comparison_save_dialog)

func _setup_settings_sections() -> void:
	if settings_content == null:
		return
	_settings_view_label = Label.new()
	_settings_view_box = VBoxContainer.new()
	_settings_view_box.add_theme_constant_override("separation", 8)
	_settings_shared_label = Label.new()
	_settings_shared_box = VBoxContainer.new()
	_settings_shared_box.add_theme_constant_override("separation", 8)

	var original_children: Array[Node] = []
	for child in settings_content.get_children():
		original_children.append(child)
	settings_content.add_child(_settings_view_label)
	settings_content.add_child(_settings_view_box)
	settings_content.add_child(_settings_shared_label)
	settings_content.add_child(_settings_shared_box)

	var browser_names := {
		"TrackVisibilityLabel": true,
		"TrackVisibilityBox": true,
		"BAMCoverageCutoffLabel": true,
		"BAMCoverageCutoffSpin": true,
		"PlaySpeedLabel": true,
		"PlaySpeedRow": true
	}
	for child in original_children:
		if child == null:
			continue
		if bool(browser_names.get(child.name, false)):
			settings_content.remove_child(child)
			_settings_view_box.add_child(child)
		else:
			settings_content.remove_child(child)
			_settings_shared_box.add_child(child)

	if _comparison_controller != null:
		_comparison_controller.setup_settings(_settings_view_box)

	_shared_colorize_nucleotides_cb = CheckButton.new()
	_shared_colorize_nucleotides_cb.text = "Color nucleotides by base"
	_shared_colorize_nucleotides_cb.button_pressed = _colorize_nucleotides
	_shared_colorize_nucleotides_cb.toggled.connect(_on_colorize_nucleotides_toggled)
	var insert_at := -1
	for i in range(_settings_shared_box.get_child_count()):
		if _settings_shared_box.get_child(i) == ui_font_option:
			insert_at = i
			break
	if insert_at >= 0:
		_settings_shared_box.add_child(_shared_colorize_nucleotides_cb)
		_settings_shared_box.move_child(_shared_colorize_nucleotides_cb, insert_at)
	else:
		_settings_shared_box.add_child(_shared_colorize_nucleotides_cb)

	_refresh_settings_sections()

func _refresh_settings_sections() -> void:
	if _settings_view_label == null or _settings_view_box == null or _settings_shared_label == null or _settings_shared_box == null:
		return
	_settings_view_label.text = "Comparison Options" if _app_mode == APP_MODE_COMPARISON else "Browser Options"
	_settings_shared_label.text = "Shared Options"
	var browser_visible := _app_mode == APP_MODE_BROWSER
	for child in _settings_view_box.get_children():
		child.visible = browser_visible
	if _comparison_controller != null:
		_comparison_controller.refresh_settings(_app_mode)

func _toggle_comparison_mode() -> void:
	if _top_bar_controller != null:
		_top_bar_controller.toggle_comparison_mode()

func _set_app_mode(next_mode: int) -> void:
	if _top_bar_controller != null:
		_top_bar_controller.set_app_mode(next_mode)

func _apply_view_mode_visibility(previous_mode: int, next_mode: int) -> void:
	if _top_bar_controller != null:
		_top_bar_controller._apply_view_mode_visibility(previous_mode, next_mode)

func _refresh_comparison_topbar_state() -> void:
	if _top_bar_controller != null:
		_top_bar_controller.refresh_comparison_topbar_state()

func _active_view_has_data_to_clear() -> bool:
	return _top_bar_controller != null and _top_bar_controller._active_view_has_data_to_clear()

func _spin_clear_button() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._spin_clear_button()

func _on_screenshot_pressed() -> void:
	if _top_bar_controller != null:
		_top_bar_controller.on_screenshot_pressed()

func _on_screenshot_file_selected(path: String) -> void:
	if _top_bar_controller != null:
		_top_bar_controller.on_screenshot_file_selected(path)

func _on_comparison_save_pressed() -> void:
	if _top_bar_controller != null:
		_top_bar_controller.on_comparison_save_pressed()

func _on_comparison_save_file_selected(path: String) -> void:
	if _top_bar_controller != null:
		_top_bar_controller.on_comparison_save_file_selected(path)

func _initialize_settings_panel() -> void:
	_set_status("Disconnected")
	genome_view.set_empty_state_status("")
	call_deferred("_update_settings_panel_width")
	call_deferred("_update_feature_panel_width")

func _startup_connect_local_zem() -> void:
	_startup_zem_host = "127.0.0.1"
	_startup_zem_port = ZEM_DEFAULT_PORT
	if not _local_zem_manager.should_try_local(_startup_zem_host):
		return
	_set_status("Preparing local zem...")
	genome_view.set_empty_state_status("Preparing local zem...")
	_startup_zem_prepare_thread = Thread.new()
	var err := _startup_zem_prepare_thread.start(Callable(self, "_startup_prepare_local_zem_worker"))
	if err != OK:
		_startup_zem_prepare_thread = null
		_set_status("Could not start local zem preparation thread: %s" % error_string(err), true)
		genome_view.set_empty_state_status("Could not start local zem preparation.")
		return

func _startup_prepare_local_zem_worker() -> Dictionary:
	var ok: bool = _local_zem_manager.ensure_local_zem_installed()
	return {
		"ok": ok,
		"error": _local_zem_manager.last_error()
	}

func _finish_startup_prepare_local_zem(result: Variant) -> void:
	var resp: Dictionary = result if result is Dictionary else {}
	if not bool(resp.get("ok", false)):
		var last_error := str(resp.get("error", "")).strip_edges()
		if not last_error.is_empty():
			_set_status(last_error, true)
			genome_view.set_empty_state_status(last_error)
		else:
			_set_status("Local zem missing and install failed.", true)
			genome_view.set_empty_state_status("Local zem missing and install failed.")
		return
	genome_view.set_empty_state_status("Starting local zem...")
	_set_status("Starting local zem...")
	_startup_zem_connect_thread = Thread.new()
	var err := _startup_zem_connect_thread.start(Callable(self, "_startup_connect_local_zem_worker").bind(_startup_zem_host, _startup_zem_port))
	if err != OK:
		_startup_zem_connect_thread = null
		_set_status("Could not start local zem connection thread: %s" % error_string(err), true)
		genome_view.set_empty_state_status("Could not start local zem.")

func _startup_connect_local_zem_worker(host: String, port: int) -> Dictionary:
	var ok: bool = _local_zem_manager.connect_with_local_fallback(host, port, 100, 180, 100)
	return {
		"ok": ok,
		"error": _local_zem_manager.last_error()
	}

func _finish_startup_connect_local_zem(result: Variant) -> void:
	var resp: Dictionary = result if result is Dictionary else {}
	if not bool(resp.get("ok", false)):
		var last_error := str(resp.get("error", "")).strip_edges()
		if not last_error.is_empty():
			_set_status(last_error, true)
			genome_view.set_empty_state_status(last_error)
		else:
			_set_status("Unable to start local zem.", true)
			genome_view.set_empty_state_status("Unable to start local zem.")
		return
	_zem.disconnect_from_server()
	if not _zem.connect_to_server(_startup_zem_host, _startup_zem_port, 500):
		_set_status("Local zem started but reconnect failed.", true)
		genome_view.set_empty_state_status("Local zem started but reconnect failed.")
		return
	var version_resp: Dictionary = _zem.get_server_version()
	_connected_zem_version = str(version_resp.get("version", "")).strip_edges() if bool(version_resp.get("ok", false)) else ""
	_set_status("Connected %s:%d" % [_startup_zem_host, _startup_zem_port])
	genome_view.set_empty_state_status("")
	_update_debug_stats_label()

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
		if theme_option.get_item_text(i) == "Slate":
			theme_option.select(i)
			break


func _setup_ui_font_selector() -> void:
	ui_font_option.clear()
	ui_font_option.add_item("Noto Sans")
	ui_font_option.add_item("DejaVu Sans")
	ui_font_option.add_item("Courier New")
	ui_font_option.add_item("Anonymous Pro")
	for i in range(ui_font_option.item_count):
		if ui_font_option.get_item_text(i) == _ui_font_name:
			ui_font_option.select(i)
			break


func _setup_sequence_letter_font_selector() -> void:
	sequence_letter_font_option.clear()
	sequence_letter_font_option.add_item("Noto Sans")
	sequence_letter_font_option.add_item("DejaVu Sans")
	sequence_letter_font_option.add_item("Anonymous Pro")
	sequence_letter_font_option.add_item("Courier New")
	for i in range(sequence_letter_font_option.item_count):
		if sequence_letter_font_option.get_item_text(i) == _sequence_letter_font_name:
			sequence_letter_font_option.select(i)
			break

func _setup_font_size_control() -> void:
	_font_size_slider.min_value = MIN_UI_FONT_SIZE
	_font_size_slider.max_value = MAX_UI_FONT_SIZE
	_font_size_slider.step = 1
	_font_size_slider.value = _ui_font_size
	if not _font_size_slider.drag_ended.is_connected(_on_font_size_drag_ended):
		_font_size_slider.drag_ended.connect(_on_font_size_drag_ended)

func _connect_ui() -> void:
	settings_toggle_button.pressed.connect(_toggle_settings)
	close_settings_button.pressed.connect(_close_settings)
	pan_left_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("pan_all_by_fraction"):
				comparison_view.pan_all_by_fraction(-_pan_step_percent / 100.0)
			return
		_pan_view_by_fraction(-_pan_step_percent / 100.0)
	)
	jump_start_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("move_all_to_boundary"):
				comparison_view.move_all_to_boundary(false)
			return
		_navigate_to_boundary(false)
	)
	pan_right_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("pan_all_by_fraction"):
				comparison_view.pan_all_by_fraction(_pan_step_percent / 100.0)
			return
		_pan_view_by_fraction(_pan_step_percent / 100.0)
	)
	jump_end_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("move_all_to_boundary"):
				comparison_view.move_all_to_boundary(true)
			return
		_navigate_to_boundary(true)
	)
	zoom_in_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("zoom_by"):
				comparison_view.zoom_by(0.78)
			return
		genome_view.zoom_by(0.78)
	)
	zoom_out_button.pressed.connect(func() -> void:
		if _app_mode == APP_MODE_COMPARISON:
			if comparison_view != null and comparison_view.has_method("zoom_by"):
				comparison_view.zoom_by(1.28)
			return
		genome_view.zoom_by(1.28)
	)
	play_button.pressed.connect(_start_auto_play)
	play_left_button.pressed.connect(_start_auto_play_left)
	stop_button.pressed.connect(_stop_auto_play)
	comparison_button.pressed.connect(_toggle_comparison_mode)
	comparison_save_button.pressed.connect(_on_comparison_save_pressed)
	comparison_clear_button.pressed.connect(_on_comparison_clear_pressed)
	search_button.pressed.connect(_toggle_search_panel)
	go_button.pressed.connect(_toggle_go_panel)
	download_button.pressed.connect(_toggle_download_panel)
	genome_view.viewport_changed.connect(_on_viewport_changed)
	comparison_view.viewport_changed.connect(_on_comparison_viewport_changed)
	genome_view.map_jump_requested.connect(_on_map_jump_requested)
	genome_view.center_jump_requested.connect(_on_center_jump_requested)
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
	enable_vertical_swipe_zoom_button.toggled.connect(_on_enable_vertical_swipe_zoom_toggled)
	mouse_wheel_zoom_slider.value_changed.connect(_on_mouse_wheel_zoom_changed)
	invert_mouse_wheel_zoom_button.toggled.connect(_on_invert_mouse_wheel_zoom_toggled)
	mouse_wheel_pan_slider.value_changed.connect(_on_mouse_wheel_pan_changed)
	pan_step_slider.value_changed.connect(_on_pan_step_changed)
	play_speed_slider.value_changed.connect(_on_play_speed_changed)
	animate_pan_zoom_slider.value_changed.connect(_on_animate_pan_zoom_speed_changed)
	theme_option.item_selected.connect(_on_theme_selected)
	ui_font_option.item_selected.connect(_on_ui_font_selected)
	sequence_letter_font_option.item_selected.connect(_on_sequence_letter_font_selected)
	feature_close_button.pressed.connect(_close_feature_panel)
	_show_full_region_checkbox.toggled.connect(_on_show_full_region_toggled)
	if _track_order_list != null:
		_track_order_list.gui_input.connect(_on_track_order_list_gui_input)
	_seq_view_option.item_selected.connect(_on_seq_view_selected)
	_seq_option.item_selected.connect(_on_seq_selected)
	_concat_gap_spin.value_changed.connect(_on_concat_gap_changed)

func _pan_view_by_fraction(fraction: float, duration: float = 0.35, linear: bool = false) -> void:
	var plot_w := maxf(1.0, genome_view.size.x - genome_view.TRACK_LEFT_PAD - genome_view.TRACK_RIGHT_PAD)
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var span := plot_w * current_bp_per_px
	var max_start := maxf(0.0, float(_current_chr_len) - span)
	var target_start := clampf(genome_view.view_start_bp + span * fraction, 0.0, max_start)
	var target_end := int(minf(float(_current_chr_len), target_start + span))
	var show_aa: bool = bool(genome_view.is_track_visible(TRACK_AA))
	var show_genome: bool = bool(genome_view.is_track_visible(TRACK_GENOME))
	var need_reference: bool = bool(genome_view.needs_reference_data(show_aa, show_genome))
	var zoom := _compute_tile_zoom(current_bp_per_px)
	var mode := 0 if (_has_bam_loaded and _any_visible_read_track() and current_bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
	var annotations_ready := _is_viewport_cached(int(target_start), target_end, zoom, mode, need_reference, _scope_cache_key())
	var reads_ready := true
	if _annotation_cache_controller.detailed_read_strips_enabled(current_bp_per_px):
		_annotation_cache_controller.prefetch_detailed_read_target(int(target_start), target_end, current_bp_per_px)
		reads_ready = _annotation_cache_controller.detailed_read_target_ready(int(target_start), target_end, current_bp_per_px)
	if not annotations_ready:
		_annotation_cache_controller.prefetch_visible_target(int(target_start), target_end, current_bp_per_px)
	if linear and _auto_play_enabled:
		var next_target_start := clampf(target_start + span * fraction, 0.0, max_start)
		var next_target_end := int(minf(float(_current_chr_len), next_target_start + span))
		if _annotation_cache_controller.detailed_read_strips_enabled(current_bp_per_px):
			_annotation_cache_controller.prefetch_detailed_read_target(int(next_target_start), next_target_end, current_bp_per_px)
		var next_annotations_ready := _is_viewport_cached(int(next_target_start), next_target_end, zoom, mode, need_reference, _scope_cache_key())
		if not next_annotations_ready:
			_annotation_cache_controller.prefetch_visible_target(int(next_target_start), next_target_end, current_bp_per_px)
	if reads_ready and annotations_ready:
		_pending_pan_active = false
		if _annotation_cache_controller.detailed_read_strips_enabled(current_bp_per_px):
			_annotation_cache_controller.apply_detailed_read_span(int(minf(genome_view.view_start_bp, target_start)), int(maxf(_last_end, target_end)), current_bp_per_px)
		if linear:
			genome_view.pan_to_start_linear(target_start, duration)
		else:
			genome_view.pan_to_start(target_start, duration)
		return
	if _annotation_cache_controller.detailed_read_strips_enabled(current_bp_per_px) or not annotations_ready:
		_pending_pan_target_start = target_start
		_pending_pan_target_end = target_end
		_pending_pan_bp_per_px = current_bp_per_px
		_pending_pan_duration = duration
		_pending_pan_linear = linear
		_pending_pan_active = true
		return
	genome_view.pan_by_fraction(fraction, duration)

func _disable_button_focus() -> void:
	var controls := [
		settings_toggle_button,
		comparison_button,
		comparison_save_button,
		comparison_clear_button,
		search_button,
		go_button,
		download_button,
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
		mouse_wheel_zoom_slider,
		mouse_wheel_pan_slider,
		pan_step_slider,
		play_speed_slider,
		animate_pan_zoom_slider
	]
	for c in controls:
		if c != null:
			c.focus_mode = Control.FOCUS_NONE

func _setup_settings_toggle_icon() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._setup_settings_toggle_icon()

func _setup_comparison_toggle_icon() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._setup_comparison_toggle_icon()

func _setup_comparison_clear_icon() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._setup_comparison_clear_icon()

func _update_settings_toggle_icon_pivot() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._update_settings_toggle_icon_pivot()

func _update_comparison_toggle_icon_pivot() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._update_comparison_toggle_icon_pivot()

func _update_comparison_clear_icon_pivot() -> void:
	if _top_bar_controller != null:
		_top_bar_controller._update_comparison_clear_icon_pivot()

func _setup_topbar_icon_button(button: Button, glyph: String) -> Dictionary:
	if _top_bar_controller != null:
		return _top_bar_controller._setup_topbar_icon_button(button, glyph)
	return {}

func _update_topbar_icon_pivot(icon_label: Label) -> void:
	if _top_bar_controller != null:
		_top_bar_controller._update_topbar_icon_pivot(icon_label)

func _spin_topbar_icon(icon_label: Label, delta_degrees: float, duration: float, tween: Tween) -> Tween:
	if _top_bar_controller != null:
		return _top_bar_controller._spin_topbar_icon(icon_label, delta_degrees, duration, tween)
	return tween

func _apply_comparison_toggle_icon_state(animated: bool) -> void:
	if _top_bar_controller != null:
		_top_bar_controller._apply_comparison_toggle_icon_state(animated)

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
		_annotation_cache_controller.update_detailed_read_strips(start_bp, end_bp, bp_per_px)
		var zoom := _compute_tile_zoom(bp_per_px)
		var mode := 0 if (_has_bam_loaded and _any_visible_read_track() and bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
		var needs_fetch := not _is_viewport_cached(start_bp, end_bp, zoom, mode, need_reference, _scope_cache_key())
		if _auto_play_enabled and _is_near_cache_edge(start_bp, end_bp):
			needs_fetch = true
		if needs_fetch:
			_schedule_fetch()
	_prev_view_start = start_bp
	_prev_view_end = end_bp

func _on_comparison_viewport_changed(visible_span_bp: int) -> void:
	if _app_mode != APP_MODE_COMPARISON or viewport_label == null:
		return
	if _comparison_controller != null and _comparison_controller.has_genomes():
		viewport_label.text = _format_comparison_viewport_label(visible_span_bp)
	else:
		viewport_label.text = "Comparison view"

func _format_viewport_label(start_bp: int, end_bp: int, _bp_per_px: float) -> String:
	var coord_start := start_bp
	var coord_end := end_bp
	var span_bp := maxi(0, end_bp - start_bp)
	var span_text := "visible"
	var coord_end_inclusive := false
	if _selection_active:
		coord_start = _selection_start
		coord_end = _selection_end
		span_bp = maxi(0, _selection_end - _selection_start + 1)
		span_text = "selected"
		coord_end_inclusive = true
	if _seq_view_mode != SEQ_VIEW_CONCAT:
		return "%s:%d - %d bp  |  %d bp %s" % [
			_current_chr_name,
			_display_range_start_bp(coord_start),
			_display_range_end_bp(coord_end, coord_end_inclusive),
			span_bp,
			span_text
		]
	var overlap_end := coord_end + 1 if coord_end_inclusive else coord_end
	var overlaps := _segments_overlapping(coord_start, overlap_end)
	if overlaps.is_empty():
		return "concat:%d - %d bp  |  %d bp %s" % [
			_display_range_start_bp(coord_start),
			_display_range_end_bp(coord_end, coord_end_inclusive),
			span_bp,
			span_text
		]
	if overlaps.size() == 1:
		var seg := overlaps[0]
		return "%s:%d - %d bp  |  %d bp %s" % [
			str(seg.get("name", "chr")),
			_display_range_start_bp(int(seg.get("local_start", 0))),
			_display_range_end_bp(int(seg.get("local_end", 0))),
			span_bp, span_text
		]
	var first := overlaps[0]
	var last := overlaps[overlaps.size() - 1]
	var prefix := "%s:%d-%d | %s:%d-%d" % [
		str(first.get("name", "chr")),
		_display_range_start_bp(int(first.get("local_start", 0))),
		_display_range_end_bp(int(first.get("local_end", 0))),
		str(last.get("name", "chr")),
		_display_range_start_bp(int(last.get("local_start", 0))),
		_display_range_end_bp(int(last.get("local_end", 0)))
	]
	if overlaps.size() > 2:
		prefix += " (+%d)" % (overlaps.size() - 2)
	return "%s  |  %d bp %s" % [prefix, span_bp, span_text]

func _format_comparison_viewport_label(visible_span_bp: int) -> String:
	return "%s bp visible" % _format_int_with_commas(maxi(0, visible_span_bp))

func _format_int_with_commas(value: int) -> String:
	var n := maxi(0, value)
	var text := str(n)
	var out := ""
	while text.length() > 3:
		out = "," + text.substr(text.length() - 3, 3) + out
		text = text.substr(0, text.length() - 3)
	return text + out

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
		if _settings_toggle_icon_label != null:
			var spin_delta := -180.0 if open else 180.0
			_settings_tween = _spin_topbar_icon(_settings_toggle_icon_label, spin_delta, 0.36, _settings_tween)
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
	_update_feature_panel_width(not animated)
	var panel_w := _feature_panel_target_width()
	var closed_w: float = float(ceili(panel_w)) + 2.0
	var target_left: float = -panel_w if open else 0.0
	var target_right: float = 0.0 if open else closed_w
	if open:
		feature_panel.visible = true
	if animated:
		_feature_tween = create_tween()
		_feature_tween.set_trans(Tween.TRANS_CUBIC)
		_feature_tween.set_ease(Tween.EASE_OUT)
		_feature_tween.parallel().tween_property(feature_panel, "offset_left", target_left, 0.24)
		_feature_tween.parallel().tween_property(feature_panel, "offset_right", target_right, 0.24)
		if not open:
			_feature_tween.finished.connect(func() -> void:
				if not _feature_panel_open:
					feature_panel.visible = false
			, CONNECT_ONE_SHOT)
	else:
		_apply_feature_panel_offsets(open)
		feature_panel.visible = open

func _on_ui_scale_value_changed(_value: float) -> void:
	pass

func _on_ui_scale_drag_ended(_value_changed: bool) -> void:
	_on_ui_scale_changed(ui_scale_slider.value)

func _on_ui_scale_changed(value: float) -> void:
	get_window().content_scale_factor = value

func _on_trackpad_pan_changed(value: float) -> void:
	genome_view.set_trackpad_pan_sensitivity(value)
	if comparison_view != null and comparison_view.has_method("set_trackpad_pan_sensitivity"):
		comparison_view.set_trackpad_pan_sensitivity(value)

func _on_trackpad_pinch_changed(value: float) -> void:
	genome_view.set_trackpad_pinch_sensitivity(value)
	if comparison_view != null and comparison_view.has_method("set_trackpad_pinch_sensitivity"):
		comparison_view.set_trackpad_pinch_sensitivity(value)

func _on_enable_vertical_swipe_zoom_toggled(enabled: bool) -> void:
	enable_vertical_swipe_zoom_button.button_pressed = enabled
	genome_view.set_vertical_swipe_zoom_enabled(enabled)
	if comparison_view != null and comparison_view.has_method("set_vertical_swipe_zoom_enabled"):
		comparison_view.set_vertical_swipe_zoom_enabled(enabled)

func _on_mouse_wheel_zoom_changed(value: float) -> void:
	genome_view.set_mouse_wheel_zoom_sensitivity(value)
	if comparison_view != null and comparison_view.has_method("set_mouse_wheel_zoom_sensitivity"):
		comparison_view.set_mouse_wheel_zoom_sensitivity(value)

func _on_invert_mouse_wheel_zoom_toggled(enabled: bool) -> void:
	invert_mouse_wheel_zoom_button.button_pressed = enabled
	genome_view.set_invert_mouse_wheel_zoom(enabled)
	if comparison_view != null and comparison_view.has_method("set_invert_mouse_wheel_zoom"):
		comparison_view.set_invert_mouse_wheel_zoom(enabled)

func _on_mouse_wheel_pan_changed(value: float) -> void:
	genome_view.set_mouse_wheel_pan_sensitivity(value)
	if comparison_view != null and comparison_view.has_method("set_mouse_wheel_pan_sensitivity"):
		comparison_view.set_mouse_wheel_pan_sensitivity(value)

func _on_pan_step_changed(value: float) -> void:
	_pan_step_percent = clampf(value, 1.0, 100.0)
	if pan_step_slider != null and absf(pan_step_slider.value - _pan_step_percent) > 0.0001:
		pan_step_slider.value = _pan_step_percent
	pan_step_value.text = "%d%%" % int(round(_pan_step_percent))

func _on_play_speed_changed(value: float) -> void:
	play_speed_value.text = "%.2f" % value

func _on_animate_pan_zoom_speed_changed(value: float) -> void:
	var speed := clampf(value, 1.0, 3.0)
	if animate_pan_zoom_slider != null and absf(animate_pan_zoom_slider.value - speed) > 0.0001:
		animate_pan_zoom_slider.value = speed
	genome_view.set_pan_zoom_animation_speed(speed)

func _on_font_size_drag_ended(_value_changed: bool) -> void:
	_on_font_size_changed(_font_size_slider.value)

func _on_font_size_changed(value: float) -> void:
	_ui_font_size = clampi(int(round(value)), MIN_UI_FONT_SIZE, MAX_UI_FONT_SIZE)
	if _font_size_slider != null and int(_font_size_slider.value) != _ui_font_size:
		_font_size_slider.value = _ui_font_size
	_apply_theme(theme_option.get_item_text(theme_option.selected))

func _start_auto_play() -> void:
	if _current_chr_len <= 0:
		_set_status("Cannot play: no chromosome loaded.", true)
		return
	_auto_play_enabled = true
	_auto_play_direction = 1.0
	_auto_play_tween_active = false

func _start_auto_play_left() -> void:
	if _current_chr_len <= 0:
		_set_status("Cannot play: no chromosome loaded.", true)
		return
	_auto_play_enabled = true
	_auto_play_direction = -1.0
	_auto_play_tween_active = false

func _stop_auto_play() -> void:
	_auto_play_enabled = false
	_auto_play_tween_active = false
	genome_view.end_motion_read_layer()
	_apply_settled_detailed_reads_if_needed()


func _cancel_motion_navigation() -> void:
	_auto_play_enabled = false
	_auto_play_tween_active = false
	_pending_pan_active = false
	genome_view.end_motion_read_layer()
	_annotation_cache_controller.cancel_all_requests()


func _navigate_to_view(target_start: float, target_bp_per_px: float) -> void:
	_cancel_motion_navigation()
	genome_view.set_view_state(target_start, target_bp_per_px)
	_invalidate_viewport_cache()
	_schedule_fetch()


func _navigate_to_centered_range(start_bp: int, end_bp: int, target_bp_per_px: float) -> void:
	var width_px := maxf(1.0, genome_view.size.x)
	var view_span_bp := int(ceil(target_bp_per_px * width_px))
	var center_bp := 0.5 * float(start_bp + end_bp)
	var target_start := maxi(0, int(floor(center_bp - 0.5 * float(view_span_bp))))
	_navigate_to_view(float(target_start), target_bp_per_px)


func _navigate_to_boundary(at_end: bool) -> void:
	if _current_chr_len <= 0:
		return
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var target_start := float(_current_chr_len) if at_end else 0.0
	_navigate_to_view(target_start, current_bp_per_px)


func _start_next_auto_play_segment() -> void:
	if not _auto_play_enabled or _current_chr_len <= 0:
		return
	if _auto_play_tween_active:
		return
	var target_fraction := 0.75 * _auto_play_direction
	var duration := 0.75 / maxf(0.05, play_speed_slider.value)
	_auto_play_tween_active = true
	_pan_view_by_fraction(target_fraction, duration, true)


func _prepare_auto_play_motion() -> void:
	if _current_chr_len <= 0:
		return
	var bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	if not _annotation_cache_controller.detailed_read_strips_enabled(bp_per_px):
		genome_view.end_motion_read_layer()
		return
	var visible_span := maxi(1, _last_end - _last_start)
	var render_start := _last_start
	var render_end := _last_end
	if _auto_play_direction >= 0.0:
		render_start = maxi(0, _last_start - int(round(float(visible_span) * 0.75)))
		render_end = mini(_current_chr_len, _last_end + int(round(float(visible_span) * 3.0)))
	else:
		render_start = maxi(0, _last_start - int(round(float(visible_span) * 3.0)))
		render_end = mini(_current_chr_len, _last_end + int(round(float(visible_span) * 0.75)))
	var refresh_margin_bp := float(visible_span)
	if genome_view.motion_read_layer_has_autoplay_margin(float(_last_start), float(_last_end), _auto_play_direction, refresh_margin_bp):
		return
	_annotation_cache_controller.prefetch_detailed_read_target(render_start, render_end, bp_per_px)
	if _annotation_cache_controller.detailed_read_target_ready(render_start, render_end, bp_per_px):
		_annotation_cache_controller.apply_detailed_read_span(render_start, render_end, bp_per_px)
		genome_view.begin_motion_read_layer_for_range(float(render_start), float(render_end))


func _apply_settled_detailed_reads_if_needed() -> void:
	if _annotation_cache_controller.detailed_read_strips_enabled(_last_bp_per_px):
		_annotation_cache_controller.apply_detailed_read_span(_last_start, _last_end, _last_bp_per_px)

func _on_theme_selected(index: int) -> void:
	_apply_classic_font_defaults_for_theme(theme_option.get_item_text(index))
	_apply_theme(theme_option.get_item_text(index))


func _on_ui_font_selected(index: int) -> void:
	if index < 0 or index >= ui_font_option.item_count:
		return
	_ui_font_name = ui_font_option.get_item_text(index)
	_apply_theme(theme_option.get_item_text(theme_option.selected))
	_save_config()


func _on_sequence_letter_font_selected(index: int) -> void:
	if index < 0 or index >= sequence_letter_font_option.item_count:
		return
	_sequence_letter_font_name = sequence_letter_font_option.get_item_text(index)
	genome_view.set_sequence_letter_font_name(_sequence_letter_font_name)
	if comparison_view != null and comparison_view.has_method("set_sequence_letter_font_name"):
		comparison_view.set_sequence_letter_font_name(_sequence_letter_font_name)
	_save_config()


func _apply_classic_font_defaults_for_theme(theme_name: String) -> void:
	if theme_name != "Classic":
		return
	_ui_font_name = "Courier New"
	for i in range(ui_font_option.item_count):
		if ui_font_option.get_item_text(i) == _ui_font_name:
			ui_font_option.select(i)
			break
	_sequence_letter_font_name = "Courier New"
	for i in range(sequence_letter_font_option.item_count):
		if sequence_letter_font_option.get_item_text(i) == _sequence_letter_font_name:
			sequence_letter_font_option.select(i)
			break
	genome_view.set_sequence_letter_font_name(_sequence_letter_font_name)
	if comparison_view != null and comparison_view.has_method("set_sequence_letter_font_name"):
		comparison_view.set_sequence_letter_font_name(_sequence_letter_font_name)

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
	_track_visibility_aa.toggled.connect(_on_track_visibility_toggled.bind(TRACK_AA))
	_track_visibility_genome.toggled.connect(_on_track_visibility_toggled.bind(TRACK_GENOME))
	_track_visibility_gc_plot.toggled.connect(_on_track_visibility_toggled.bind(TRACK_GC_PLOT))
	_track_visibility_depth_plot.toggled.connect(_on_track_visibility_toggled.bind(TRACK_DEPTH_PLOT))
	_track_visibility_map.toggled.connect(_on_track_visibility_toggled.bind("map"))
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
	_genome_cache_spin.min_value = 1
	_genome_cache_spin.max_value = 100000
	_genome_cache_spin.step = 10
	_genome_cache_spin.value = _genome_cache_max_mb
	_genome_cache_spin.allow_greater = false
	_genome_cache_spin.allow_lesser = false
	if not _genome_cache_spin.value_changed.is_connected(_on_genome_cache_max_changed):
		_genome_cache_spin.value_changed.connect(_on_genome_cache_max_changed)
	if not _genome_cache_clear_button.pressed.is_connected(_clear_genome_cache):
		_genome_cache_clear_button.pressed.connect(_clear_genome_cache)
	if not _generate_test_data_button.pressed.is_connected(_start_generate_test_data):
		_generate_test_data_button.pressed.connect(_start_generate_test_data)
	if not _open_user_data_dir_button.pressed.is_connected(_open_user_data_dir):
		_open_user_data_dir_button.pressed.connect(_open_user_data_dir)
	_debug_toggle.button_pressed = _debug_enabled
	if not _debug_toggle.toggled.is_connected(_on_debug_toggled):
		_debug_toggle.toggled.connect(_on_debug_toggled)
	_debug_stats_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_debug_stats_label.visible = _debug_enabled
	_debug_stats_label.text = ""
	_debug_loaded_files_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_debug_loaded_files_label.visible = _debug_enabled
	_debug_loaded_files_label.text = ""
	_update_loaded_files_debug_label()

func _on_bam_cov_cutoff_changed(value: float) -> void:
	_bam_cov_precompute_cutoff_bp = maxi(0, int(round(value)))

func _on_genome_cache_max_changed(value: float) -> void:
	_genome_cache_max_mb = maxi(1, int(round(value)))

func _genome_cache_dir() -> String:
	return OS.get_user_data_dir().path_join("genomes_cache")

func _genome_cache_max_bytes() -> int:
	return _genome_cache_max_mb * 1024 * 1024

func _clear_genome_cache() -> void:
	var cache_dir := _genome_cache_dir()
	if not DirAccess.dir_exists_absolute(cache_dir):
		_set_status("Genome cache already empty.")
		return
	if not _delete_dir_contents_absolute(cache_dir):
		_set_status("Failed to clear genome cache.", true)
		return
	_set_status("Genome cache cleared.")

func _generated_test_data_dir() -> String:
	return OS.get_user_data_dir().path_join("generated_test_data")

func _generated_comparison_test_data_dir() -> String:
	return OS.get_user_data_dir().path_join("generated_comparison_test_data")

func _set_generate_test_data_controls_enabled(enabled: bool) -> void:
	if _generate_test_data_button != null:
		_generate_test_data_button.disabled = not enabled

func _set_generate_comparison_test_data_controls_enabled(enabled: bool) -> void:
	if _comparison_controller != null:
		_comparison_controller.set_generate_test_genomes_enabled(enabled)

func _open_user_data_dir() -> void:
	var user_dir := ProjectSettings.globalize_path("user://")
	if user_dir.strip_edges() == "":
		_set_status("Could not resolve user data directory.", true)
		return
	var err := OS.shell_open(user_dir)
	if err != OK:
		_set_status("Could not open user data directory.", true)

func _start_generate_test_data() -> void:
	if _generate_test_data_in_progress:
		return
	if not _session_loader.ensure_server_connected():
		return
	var out_dir := _generated_test_data_dir()
	var mk_err := DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK and not DirAccess.dir_exists_absolute(out_dir):
		_set_status("Could not create generated test data directory.", true)
		return
	var conn: Dictionary = _zem.connection_info()
	_generate_test_data_thread = Thread.new()
	var err := _generate_test_data_thread.start(
		Callable(self, "_generate_test_data_thread_main").bind(
			str(conn.get("host", "127.0.0.1")),
			int(conn.get("port", ZEM_DEFAULT_PORT)),
			out_dir
		)
	)
	if err != OK:
		_generate_test_data_thread = null
		_set_status("Could not start test-data thread: %s" % error_string(err), true)
		return
	_generate_test_data_in_progress = true
	_set_generate_test_data_controls_enabled(false)
	_set_status("Generating built-in test data...")

func _start_generate_comparison_test_data() -> void:
	if _generate_comparison_test_data_in_progress:
		return
	if not _session_loader.ensure_server_connected():
		return
	var out_dir := _generated_comparison_test_data_dir()
	var mk_err := DirAccess.make_dir_recursive_absolute(out_dir)
	if mk_err != OK and not DirAccess.dir_exists_absolute(out_dir):
		_set_status("Could not create generated comparison test data directory.", true)
		return
	var conn: Dictionary = _zem.connection_info()
	_generate_comparison_test_data_thread = Thread.new()
	var err := _generate_comparison_test_data_thread.start(
		Callable(self, "_generate_comparison_test_data_thread_main").bind(
			str(conn.get("host", "127.0.0.1")),
			int(conn.get("port", ZEM_DEFAULT_PORT)),
			out_dir
		)
	)
	if err != OK:
		_generate_comparison_test_data_thread = null
		_set_status("Could not start comparison test-data thread: %s" % error_string(err), true)
		return
	_generate_comparison_test_data_in_progress = true
	_set_generate_comparison_test_data_controls_enabled(false)
	_set_status("Generating comparison test genomes...")

func _generate_test_data_thread_main(host_ip: String, port: int, out_dir: String) -> Dictionary:
	var client = ZemClientScript.new()
	if not client.connect_to_server(host_ip, port, 2000):
		return {"ok": false, "error": "Unable to connect to %s:%d" % [host_ip, port]}
	return client.generate_test_data(out_dir)

func _generate_comparison_test_data_thread_main(host_ip: String, port: int, out_dir: String) -> Dictionary:
	var client = ZemClientScript.new()
	if not client.connect_to_server(host_ip, port, 2000):
		return {"ok": false, "error": "Unable to connect to %s:%d" % [host_ip, port]}
	return client.generate_comparison_test_data(out_dir)

func _finish_generate_test_data(result_any: Variant) -> void:
	_generate_test_data_in_progress = false
	_set_generate_test_data_controls_enabled(true)
	var result: Dictionary = result_any if result_any is Dictionary else {}
	if result.is_empty() or not result.get("ok", false):
		_set_status("Generate test data failed: %s" % result.get("error", "error"), true)
		return
	var files: PackedStringArray = result.get("files", PackedStringArray())
	if files.is_empty():
		_set_status("Generate test data failed: no files returned.", true)
		return
	var load_resp: Dictionary = _session_loader.load_server_paths(files)
	if not load_resp.get("ok", false):
		_set_status("Generate test data load failed: %s" % load_resp.get("error", "error"), true)
		return
	_set_status("Generated and loaded test data.")

func _finish_generate_comparison_test_data(result_any: Variant) -> void:
	_generate_comparison_test_data_in_progress = false
	_set_generate_comparison_test_data_controls_enabled(true)
	var result: Dictionary = result_any if result_any is Dictionary else {}
	if result.is_empty() or not result.get("ok", false):
		_set_status("Generate comparison test data failed: %s" % result.get("error", "error"), true)
		return
	var files: PackedStringArray = result.get("files", PackedStringArray())
	if files.is_empty():
		_set_status("Generate comparison test data failed: no files returned.", true)
		return
	_set_app_mode(APP_MODE_COMPARISON)
	if _comparison_controller == null or not _comparison_controller.load_generated_genomes(files):
		_set_status("Generate comparison test data load failed.", true)
		return
	_refresh_comparison_topbar_state()
	_set_status("Generated and loaded comparison test genomes.")

func _delete_dir_contents_absolute(dir_path: String) -> bool:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	while true:
		var entry_name := dir.get_next()
		if entry_name.is_empty():
			break
		if entry_name == "." or entry_name == "..":
			continue
		var child_path := dir_path.path_join(entry_name)
		if dir.current_is_dir():
			if not _delete_dir_contents_absolute(child_path):
				dir.list_dir_end()
				return false
			if DirAccess.remove_absolute(child_path) != OK:
				dir.list_dir_end()
				return false
		else:
			if DirAccess.remove_absolute(child_path) != OK:
				dir.list_dir_end()
				return false
	dir.list_dir_end()
	return true

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
	_read_track_settings_panel = ReadTrackSettingsPanelScene.instantiate() as VBoxContainer
	if _read_track_settings_panel != null:
		_read_track_settings_panel.visible = false
		_track_settings_box.add_child(_read_track_settings_panel)
		var read_view_option := _read_track_settings_panel.get_node("ReadViewOption") as OptionButton
		if read_view_option != null and read_view_option.item_count == 0:
			read_view_option.add_item("Stack", 0)
			read_view_option.add_item("Strand Stack", 1)
			read_view_option.add_item("Paired", 2)
			read_view_option.add_item("Fragment Size", 3)
		if read_view_option != null and not read_view_option.item_selected.is_connected(_on_active_read_track_view_selected):
			read_view_option.item_selected.connect(_on_active_read_track_view_selected)
		var frag_cb := _read_track_settings_panel.get_node("FragmentLogScale") as CheckButton
		if frag_cb != null and not frag_cb.toggled.is_connected(_on_active_read_track_fragment_log_toggled):
			frag_cb.toggled.connect(_on_active_read_track_fragment_log_toggled)
		var thickness_spin := _read_track_settings_panel.get_node("ReadThicknessSpin") as SpinBox
		if thickness_spin != null and not thickness_spin.value_changed.is_connected(_on_active_read_track_thickness_changed):
			thickness_spin.value_changed.connect(_on_active_read_track_thickness_changed)
		var auto_expand_snp_cb := _read_track_settings_panel.get_node("AutoExpandSNPText") as CheckButton
		if auto_expand_snp_cb != null and not auto_expand_snp_cb.toggled.is_connected(_on_active_read_track_auto_expand_snp_toggled):
			auto_expand_snp_cb.toggled.connect(_on_active_read_track_auto_expand_snp_toggled)
		var show_soft_clips_cb := _read_track_settings_panel.get_node("ShowSoftClips") as CheckButton
		if show_soft_clips_cb != null and not show_soft_clips_cb.toggled.is_connected(_on_active_read_track_show_soft_clips_toggled):
			show_soft_clips_cb.toggled.connect(_on_active_read_track_show_soft_clips_toggled)
		var show_pileup_logo_cb := _read_track_settings_panel.get_node("ShowPileupLogo") as CheckButton
		if show_pileup_logo_cb != null and not show_pileup_logo_cb.toggled.is_connected(_on_active_read_track_show_pileup_logo_toggled):
			show_pileup_logo_cb.toggled.connect(_on_active_read_track_show_pileup_logo_toggled)
		var mate_contig_color_cb := _read_track_settings_panel.get_node("MateContigColor") as CheckButton
		if mate_contig_color_cb != null and not mate_contig_color_cb.toggled.is_connected(_on_active_read_track_mate_contig_color_toggled):
			mate_contig_color_cb.toggled.connect(_on_active_read_track_mate_contig_color_toggled)
		var max_rows_spin := _read_track_settings_panel.get_node("MaxRowsSpin") as SpinBox
		if max_rows_spin != null and not max_rows_spin.value_changed.is_connected(_on_active_read_track_max_rows_changed):
			max_rows_spin.value_changed.connect(_on_active_read_track_max_rows_changed)
		var mapq_spin := _read_track_settings_panel.get_node("MapQSpin") as SpinBox
		if mapq_spin != null and not mapq_spin.value_changed.is_connected(_on_active_read_track_min_mapq_changed):
			mapq_spin.value_changed.connect(_on_active_read_track_min_mapq_changed)
	_search_controller.setup(feature_content, {
		"get_zem": Callable(self, "_search_get_zem"),
		"get_app_mode": Callable(self, "_search_get_app_mode"),
		"get_chromosomes": Callable(self, "_search_get_chromosomes"),
		"get_comparison_genomes": Callable(self, "_search_get_comparison_genomes"),
		"get_selected_seq_id": Callable(self, "_search_get_selected_seq_id"),
		"on_hit_selected": Callable(self, "_jump_to_search_hit")
	})
	_go_controller = GoControllerScript.new()
	_go_controller.setup(feature_content, {
		"get_app_mode": Callable(self, "_go_get_app_mode"),
		"get_chromosomes": Callable(self, "_go_get_chromosomes"),
		"get_comparison_genomes": Callable(self, "_go_get_comparison_genomes"),
		"get_browser_target_chr_id": Callable(self, "_go_get_browser_target_chr_id"),
		"on_browser_go_request": Callable(self, "_go_on_browser_request"),
		"on_comparison_go_request": Callable(self, "_go_on_comparison_request"),
		"report_error_status": Callable(self, "_set_status"),
		"request_close_panel": Callable(self, "_close_feature_panel")
	})
	_setup_download_panel()

func _setup_download_panel() -> void:
	_download_panel = VBoxContainer.new()
	_download_panel.visible = false
	_download_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_download_panel.add_theme_constant_override("separation", 8)
	feature_content.add_child(_download_panel)

	var hint := Label.new()
	hint.text = "Enter an accession such as NC_000913.3 or GCF_000005845.2."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_download_panel.add_child(hint)

	_download_accession_edit = LineEdit.new()
	_download_accession_edit.placeholder_text = "Accession"
	_download_accession_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_download_panel.add_child(_download_accession_edit)

	_download_action_button = Button.new()
	_download_action_button.text = "Download and Load"
	_download_action_button.size_flags_horizontal = Control.SIZE_FILL
	_download_panel.add_child(_download_action_button)

	_download_status_label = RichTextLabel.new()
	_download_status_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_download_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_download_status_label.fit_content = true
	_download_status_label.scroll_active = false
	_download_status_label.selection_enabled = true
	_download_panel.add_child(_download_status_label)

	if _download_action_button != null:
		_download_action_button.pressed.connect(_start_download_genome)
	if _download_accession_edit != null:
		_download_accession_edit.text_submitted.connect(func(_text: String) -> void:
			_start_download_genome()
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
	if comparison_view != null and comparison_view.has_method("set_colorize_nucleotides"):
		comparison_view.set_colorize_nucleotides(enabled)

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

func _update_active_bam_track(mutator: Callable) -> void:
	if not _active_track_settings_id.begins_with("reads:"):
		return
	for i in range(_bam_tracks.size()):
		var t: Dictionary = _bam_tracks[i]
		if str(t.get("track_id", "")) != _active_track_settings_id:
			continue
		mutator.call(t)
		_bam_tracks[i] = t
		if _annotation_cache_controller.detailed_read_strips_enabled(_last_bp_per_px):
			_annotation_cache_controller.apply_detailed_read_span(_last_start, _last_end, _last_bp_per_px)
		_schedule_fetch()
		return

func _on_active_read_track_view_selected(index: int) -> void:
	if _read_track_settings_panel == null:
		return
	var frag_cb := _read_track_settings_panel.get_node("FragmentLogScale") as CheckButton
	if frag_cb != null:
		frag_cb.visible = index == 3
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["view_mode"] = index
	)

func _on_active_read_track_fragment_log_toggled(enabled: bool) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["fragment_log"] = enabled
	)

func _on_active_read_track_thickness_changed(value: float) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["thickness"] = clampf(value, 2.0, 24.0)
	)

func _on_active_read_track_auto_expand_snp_toggled(enabled: bool) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["auto_expand_snp_text"] = enabled
	)

func _on_active_read_track_show_soft_clips_toggled(enabled: bool) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["show_soft_clips"] = enabled
	)

func _on_active_read_track_show_pileup_logo_toggled(enabled: bool) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["show_pileup_logo"] = enabled
	)

func _on_active_read_track_mate_contig_color_toggled(enabled: bool) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["color_by_mate_contig"] = enabled
	)

func _on_active_read_track_max_rows_changed(value: float) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["max_rows"] = maxi(0, int(round(value)))
	)

func _on_active_read_track_min_mapq_changed(value: float) -> void:
	_update_active_bam_track(func(t: Dictionary) -> void:
		t["min_mapq"] = clampi(int(round(value)), 0, 255)
	)

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
	var version_resp: Dictionary = _zem.get_server_version()
	var status_prefix := "ERROR" if _last_status_is_error else "OK"
	var status_message := _last_status_message
	if bool(version_resp.get("ok", false)):
		_connected_zem_version = str(version_resp.get("version", "")).strip_edges()
		status_prefix = "OK"
		var conn_info: Dictionary = _zem.connection_info()
		status_message = "Connected %s:%d" % [str(conn_info.get("host", "127.0.0.1")), int(conn_info.get("port", ZEM_DEFAULT_PORT))]
	var hit_pct := 0.0
	if _dbg_ann_tile_requests > 0:
		hit_pct = 100.0 * float(_dbg_ann_tile_cache_hits) / float(_dbg_ann_tile_requests)
	var draw_stats: Dictionary = genome_view.annotation_debug_stats()
	var godot_version := str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()
	var zem_version := _connected_zem_version if not _connected_zem_version.is_empty() else "unknown"
	var versions_match := "true" if not godot_version.is_empty() and godot_version == _connected_zem_version else "false"
	_debug_stats_label.text = "Godot version: %s\nZem version: %s\nVersions match: %s\nServer [%s]: %s\nViewport: %s\nScale: %s\nAnn tiles req=%d, cache_hit=%d (%.1f%%), queried=%d\nAnn feats in=%d, out=%d, fetch=%.2fms\nAnn draw seen=%d, drawn=%d, labels=%d, hitboxes=%d, draw=%.2fms" % [
		godot_version,
		zem_version,
		versions_match,
		status_prefix,
		status_message,
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
	var visible_ids := {}
	for id_any in order:
		var track_id := str(id_any)
		if track_id == TRACK_READS or track_id.begins_with("reads:"):
			continue
		visible_ids[track_id] = true
	var controls := {
		TRACK_AA: _track_visibility_aa,
		TRACK_GENOME: _track_visibility_genome,
		TRACK_GC_PLOT: _track_visibility_gc_plot,
		TRACK_DEPTH_PLOT: _track_visibility_depth_plot,
		"map": _track_visibility_map
	}
	for track_id_any in controls.keys():
		var track_id := str(track_id_any)
		var cb := controls[track_id] as CheckButton
		if cb == null:
			continue
		cb.visible = bool(visible_ids.get(track_id, false))
		if not cb.visible:
			continue
		var is_depth: bool = track_id == TRACK_DEPTH_PLOT
		if is_depth and not _has_bam_loaded:
			genome_view.set_track_visible(track_id, false)
		cb.set_pressed_no_signal(genome_view.is_track_visible(track_id))
		cb.disabled = is_depth and not _has_bam_loaded

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
	var series_colors: Array = _themes_lib.depth_plot_series(theme_option.get_item_text(theme_option.selected))
	if series_colors.is_empty():
		return genome_view.palette.get("depth_plot", genome_view.palette.get("read", Color("808080")))
	return series_colors[idx % series_colors.size()]

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
	_prepare_context_panel(CONTEXT_PANEL_TRACK_SETTINGS, "%s track settings" % _track_label_for_id(track_id), false)
	feature_name_label.visible = true
	feature_name_label.text = ""
	for child in _track_settings_box.get_children():
		if child == _read_track_settings_panel:
			child.visible = false
			var dynamic_options := _read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
			if dynamic_options != null:
				for dynamic_child in dynamic_options.get_children():
					dynamic_child.queue_free()
			continue
		child.queue_free()
	_track_settings_box.visible = true
	_track_settings_open = true
	_active_track_settings_id = track_id
	if track_id.begins_with("reads:"):
		var track_meta := _bam_track_for_id(track_id)
		var bam_name := str(track_meta.get("label", track_meta.get("path", "BAM")))
		var bam_label := _read_track_settings_panel.get_node("BAMLabel") as Label
		var view_option := _read_track_settings_panel.get_node("ReadViewOption") as OptionButton
		var frag_cb := _read_track_settings_panel.get_node("FragmentLogScale") as CheckButton
		var thickness_spin := _read_track_settings_panel.get_node("ReadThicknessSpin") as SpinBox
		var auto_expand_snp_cb := _read_track_settings_panel.get_node("AutoExpandSNPText") as CheckButton
		var show_soft_clips_cb := _read_track_settings_panel.get_node("ShowSoftClips") as CheckButton
		var show_pileup_logo_cb := _read_track_settings_panel.get_node("ShowPileupLogo") as CheckButton
		var mate_contig_color_cb := _read_track_settings_panel.get_node("MateContigColor") as CheckButton
		var max_rows_spin := _read_track_settings_panel.get_node("MaxRowsSpin") as SpinBox
		var mapq_spin := _read_track_settings_panel.get_node("MapQSpin") as SpinBox
		var dynamic_options := _read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
		if _read_track_settings_panel != null:
			_read_track_settings_panel.visible = true
		if bam_label != null:
			bam_label.text = "BAM: %s" % bam_name
		if view_option != null:
			view_option.select(int(track_meta.get("view_mode", 0)))
		if frag_cb != null:
			frag_cb.button_pressed = bool(track_meta.get("fragment_log", true))
			frag_cb.visible = view_option != null and view_option.selected == 3
		if thickness_spin != null:
			thickness_spin.value = float(track_meta.get("thickness", DEFAULT_READ_THICKNESS))
		if auto_expand_snp_cb != null:
			auto_expand_snp_cb.button_pressed = bool(track_meta.get("auto_expand_snp_text", true))
		if show_soft_clips_cb != null:
			show_soft_clips_cb.button_pressed = bool(track_meta.get("show_soft_clips", false))
		if show_pileup_logo_cb != null:
			show_pileup_logo_cb.button_pressed = bool(track_meta.get("show_pileup_logo", false))
		if mate_contig_color_cb != null:
			mate_contig_color_cb.button_pressed = bool(track_meta.get("color_by_mate_contig", false))
		if max_rows_spin != null:
			max_rows_spin.value = float(int(track_meta.get("max_rows", DEFAULT_READ_MAX_ROWS)))
		if mapq_spin != null:
			mapq_spin.value = float(int(track_meta.get("min_mapq", DEFAULT_READ_MIN_MAPQ)))
		if dynamic_options != null:
			for child in dynamic_options.get_children():
				child.queue_free()
		var hidden_flags := int(track_meta.get("hidden_flags", DEFAULT_READ_HIDDEN_FLAGS))
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
			dynamic_options.add_child(flag_cb)
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
				dynamic_options.add_child(improper_pair_cb)
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
				dynamic_options.add_child(mate_forward_cb)
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
				dynamic_options.add_child(forward_cb)
	elif track_id == "aa":
		var region_cb := CheckButton.new()
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
		var coord_commas_cb := CheckButton.new()
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
	if _feature_panel_open and _context_panel_mode == CONTEXT_PANEL_SEARCH:
		_close_feature_panel()
		return
	_prepare_context_panel(CONTEXT_PANEL_SEARCH, "Search", false)
	_search_controller.show_panel()
	_feature_panel_open = true
	_slide_feature_panel(true, true)
	_search_controller.focus_query()

func _toggle_go_panel() -> void:
	if _go_controller == null:
		return
	if _feature_panel_open and _context_panel_mode == CONTEXT_PANEL_GO:
		_close_feature_panel()
		return
	_prepare_context_panel(CONTEXT_PANEL_GO, "Go to position", false)
	_go_controller.show_panel()
	_feature_panel_open = true
	_slide_feature_panel(true, true)
	_go_controller.focus_start()

func _toggle_download_panel() -> void:
	if _download_panel == null:
		return
	if _feature_panel_open and _context_panel_mode == CONTEXT_PANEL_DOWNLOAD:
		_close_feature_panel()
		return
	_prepare_context_panel(CONTEXT_PANEL_DOWNLOAD, "Download Genome", false)
	_download_panel.visible = true
	if not _download_in_progress:
		_set_download_status("")
	_feature_panel_open = true
	_slide_feature_panel(true, true)
	if _download_accession_edit != null:
		_download_accession_edit.grab_focus()

func _prepare_context_panel(mode: int, title: String, show_detail_labels: bool) -> void:
	if _context_panel_mode == CONTEXT_PANEL_TRACK_SETTINGS and mode != CONTEXT_PANEL_TRACK_SETTINGS:
		_maybe_save_genome_track_settings()
	_context_panel_mode = mode
	_track_settings_open = false
	_active_track_settings_id = ""
	feature_title_label.text = title
	feature_name_label.visible = show_detail_labels
	feature_type_label.visible = show_detail_labels
	feature_range_label.visible = show_detail_labels
	feature_strand_label.visible = show_detail_labels
	feature_source_label.visible = show_detail_labels
	feature_seq_label.visible = show_detail_labels
	_hide_context_subpanels()

func _hide_context_subpanels() -> void:
	if _track_settings_box != null:
		_track_settings_box.visible = false
	if _feature_panel_controller != null:
		_feature_panel_controller.hide_subpanels()
	if _search_controller != null:
		_search_controller.hide_panel()
	if _go_controller != null:
		_go_controller.hide_panel()
	if _download_panel != null:
		_download_panel.visible = false
	if _read_mate_jump_button != null:
		_read_mate_jump_button.visible = false

func _jump_to_search_hit(hit_any: Dictionary) -> void:
	var hit: Dictionary = hit_any
	if str(hit.get("context", "")) == "comparison":
		if _app_mode != APP_MODE_COMPARISON:
			return
		_comparison_controller.focus_search_hit(hit)
		return
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
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	_navigate_to_centered_range(start_bp, end_bp, current_bp_per_px)
	if hit_kind == "dna":
		_pending_annotation_highlight = {}
		genome_view.clear_selected_feature()
		genome_view.set_region_selection(start_bp, maxi(start_bp, end_bp - 1))
	else:
		_pending_annotation_highlight = hit.duplicate(true)
		genome_view.clear_region_selection()


func _on_map_jump_requested(bp_center: float) -> void:
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var target_start := maxi(0, int(floor(bp_center - genome_view.get_visible_span_bp() * 0.5)))
	_navigate_to_view(float(target_start), current_bp_per_px)

func _on_center_jump_requested(bp_center: float) -> void:
	var target_start := maxi(0, int(floor(bp_center - genome_view.get_visible_span_bp() * 0.5)))
	_cancel_motion_navigation()
	genome_view.pan_to_start(float(target_start))

func _display_point_bp(bp: int) -> int:
	return bp + 1

func _display_range_start_bp(start_bp: int) -> int:
	return start_bp + 1

func _display_range_end_bp(end_bp: int, is_inclusive: bool = false) -> int:
	return end_bp + 1 if is_inclusive else end_bp

func _go_get_app_mode() -> int:
	return _app_mode

func _go_get_chromosomes() -> Array[Dictionary]:
	return _chromosomes

func _go_get_comparison_genomes() -> Array[Dictionary]:
	return _comparison_controller.get_genomes() if _comparison_controller != null else []

func _go_get_browser_target_chr_id() -> int:
	var target_id := _current_chr_id if _current_chr_id >= 0 else _selected_seq_id
	if _seq_view_mode == SEQ_VIEW_CONCAT and _concat_segments.size() > 0:
		var center_bp := int(floor(0.5 * float(_last_start + _last_end)))
		var overlaps := _segments_overlapping(center_bp, center_bp + 1)
		if not overlaps.is_empty():
			target_id = int(overlaps[0].get("id", -1))
	return target_id

func _go_on_comparison_request(genome_id: int, segment: Dictionary, start_display: int, end_display: int) -> void:
	var seg_start := int(segment.get("start", 0))
	var start_bp := seg_start + start_display - 1
	var end_bp := seg_start + end_display if end_display >= 0 else start_bp + 1
	if end_display >= 0:
		_comparison_controller.focus_genome_range_with_zoom(genome_id, start_bp, end_bp)
	else:
		_comparison_controller.focus_genome_range(genome_id, start_bp, end_bp)

func _go_on_browser_request(chr_id: int, start_display: int, end_display: int) -> void:
	var width_px := maxf(1.0, genome_view.size.x)
	var current_bp_per_px := clampf(_last_bp_per_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
	var offset_bp := 0
	if _seq_view_mode == SEQ_VIEW_CONCAT:
		for seg in _concat_segments:
			if int(seg.get("id", -1)) == chr_id:
				offset_bp = int(seg.get("start", 0))
				break
	else:
		for i in range(_seq_option.item_count):
			if int(_seq_option.get_item_id(i)) == chr_id:
				_seq_option.select(i)
				_on_seq_selected(i)
				break
	if end_display >= 0:
		var start_bp := offset_bp + start_display - 1
		var end_bp := offset_bp + end_display
		var span_bp := maxi(1, end_bp - start_bp)
		var bp_per_px := clampf(float(span_bp) / width_px, genome_view.min_bp_per_px, genome_view.max_bp_per_px)
		_navigate_to_view(float(start_bp), bp_per_px)
	else:
		var point_bp := offset_bp + start_display - 1
		_navigate_to_centered_range(point_bp, point_bp + 1, current_bp_per_px)
	genome_view.clear_region_selection()

func _search_get_zem() -> RefCounted:
	return _zem

func _search_get_app_mode() -> int:
	return _app_mode

func _search_get_chromosomes() -> Array[Dictionary]:
	return _chromosomes

func _search_get_comparison_genomes() -> Array[Dictionary]:
	if _comparison_controller == null:
		return []
	return _comparison_controller.get_genomes()

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

func _set_download_status(message: String, is_error: bool = false) -> void:
	if _download_status_label != null:
		_download_status_label.text = message
	if is_error:
		_set_status(message, true)
	call_deferred("_update_feature_panel_width")

func _set_download_controls_enabled(enabled: bool) -> void:
	if _download_accession_edit != null:
		_download_accession_edit.editable = enabled
	if _download_action_button != null:
		_download_action_button.disabled = not enabled

func _start_download_genome() -> void:
	if _download_in_progress:
		return
	if _download_accession_edit == null:
		return
	var accession := _download_accession_edit.text.strip_edges()
	if accession.is_empty():
		_set_download_status("Enter an accession.", true)
		return
	if not _session_loader.ensure_server_connected():
		return
	var cache_dir := _genome_cache_dir()
	var mk_err := DirAccess.make_dir_recursive_absolute(cache_dir)
	if mk_err != OK and not DirAccess.dir_exists_absolute(cache_dir):
		_set_download_status("Could not create genome cache directory.", true)
		return
	var conn: Dictionary = _zem.connection_info()
	_download_thread = Thread.new()
	var err := _download_thread.start(
		Callable(self, "_download_genome_thread").bind(
			accession,
			str(conn.get("host", "127.0.0.1")),
			int(conn.get("port", ZEM_DEFAULT_PORT)),
			cache_dir,
			_genome_cache_max_bytes()
		)
	)
	if err != OK:
		_download_thread = null
		_set_download_status("Could not start download thread: %s" % error_string(err), true)
		return
	_download_in_progress = true
	_set_download_controls_enabled(false)
	_set_download_status("Downloading %s..." % accession)

func _download_genome_thread(accession: String, host_ip: String, port: int, cache_dir: String, max_cache_bytes: int) -> Dictionary:
	var client = ZemClientScript.new()
	if not client.connect_to_server(host_ip, port, 2000):
		return {"ok": false, "error": "Unable to connect to %s:%d" % [host_ip, port]}
	return client.download_genome(accession, cache_dir, max_cache_bytes)

func _finish_download_genome(result_any: Variant) -> void:
	_download_in_progress = false
	_set_download_controls_enabled(true)
	var result: Dictionary = result_any if result_any is Dictionary else {}
	if result.is_empty() or not result.get("ok", false):
		_set_download_status("Download failed: %s" % result.get("error", "error"), true)
		return
	var files: PackedStringArray = result.get("files", PackedStringArray())
	if files.is_empty():
		_set_download_status("Download failed: no genome files returned.", true)
		return
	if _app_mode == APP_MODE_COMPARISON and _comparison_controller != null:
		if not _comparison_controller.add_input_files(files):
			_set_download_status("Downloaded files, but could not add a comparison genome.", true)
			return
		_comparison_controller.finalize_added_genomes()
		_set_download_status("Downloaded and added to comparison:\n%s" % "\n".join(files))
		return
	_session_loader.apply_already_loaded_genome(files)
	_set_download_status("Downloaded and loaded:\n%s" % "\n".join(files))

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
	self.theme = _themes_lib.make_theme(theme_name, _ui_font_size, _ui_font_name)
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
	call_deferred("_update_settings_toggle_icon_pivot")
	_apply_settings_scrollbar_style()
	if _comparison_controller != null:
		_comparison_controller.refresh_view(theme_name)
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

func _update_feature_panel_width(apply_offsets: bool = true) -> void:
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
	if apply_offsets and (_feature_tween == null or not _feature_tween.is_running()):
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
	if _top_bar_controller != null:
		_top_bar_controller.apply_topbar_button_font_size()

func _on_files_dropped(files: PackedStringArray) -> void:
	if not _ensure_server_connected():
		return
	for file_any in files:
		var path := str(file_any)
		if path.is_empty():
			continue
		var inspect: Dictionary = _zem.inspect_input(path)
		if bool(inspect.get("ok", false)) and bool(inspect.get("is_comparison_session", false)):
			_set_app_mode(APP_MODE_COMPARISON)
			if _comparison_controller != null:
				_comparison_controller.load_session(path)
			_refresh_comparison_topbar_state()
			return
	if _app_mode == APP_MODE_COMPARISON:
		if _comparison_controller != null:
			_comparison_controller.handle_files_dropped(files)
		_refresh_comparison_topbar_state()
		return
	_session_loader.on_files_dropped(files)

func _on_comparison_clear_pressed() -> void:
	if _top_bar_controller != null:
		_top_bar_controller.on_clear_pressed()

func _ensure_server_connected() -> bool:
	return _session_loader.ensure_server_connected()

func _refresh_sequence_loaded_state() -> void:
	_session_loader.refresh_sequence_loaded_state()

func _inspect_dropped_files(files: PackedStringArray) -> Dictionary:
	return _session_loader.inspect_dropped_files(files)

func _exit_tree() -> void:
	if _tile_controller != null:
		_tile_controller.shutdown()
	if _download_thread != null and _download_thread.is_started():
		_download_thread.wait_to_finish()
		_download_thread = null
	if _generate_test_data_thread != null and _generate_test_data_thread.is_started():
		_generate_test_data_thread.wait_to_finish()
		_generate_test_data_thread = null
	if _generate_comparison_test_data_thread != null and _generate_comparison_test_data_thread.is_started():
		_generate_comparison_test_data_thread.wait_to_finish()
		_generate_comparison_test_data_thread = null
	if _startup_zem_prepare_thread != null and _startup_zem_prepare_thread.is_started():
		_startup_zem_prepare_thread.wait_to_finish()
		_startup_zem_prepare_thread = null
	if _startup_zem_connect_thread != null and _startup_zem_connect_thread.is_started():
		_startup_zem_connect_thread.wait_to_finish()
		_startup_zem_connect_thread = null
	if _local_zem_manager != null:
		_local_zem_manager.shutdown_on_exit()

func _load_dropped_files(files: PackedStringArray) -> bool:
	return _session_loader.load_dropped_files(files)

func _refresh_chromosomes(reset_viewport: bool = true) -> void:
	_session_loader.refresh_chromosomes(reset_viewport)

func _rebuild_concat_segments() -> void:
	_session_loader.rebuild_concat_segments()

func _refresh_sequence_options() -> void:
	_session_loader.refresh_sequence_options()

func _apply_sequence_view(reset_viewport: bool) -> void:
	_session_loader.apply_sequence_view(reset_viewport)

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
	var gene_index_by_id := {}
	var feature_index_by_id := {}
	for i in range(features_in.size()):
		var feature: Dictionary = features_in[i]
		var feature_id := str(feature.get("id", "")).strip_edges()
		if not feature_id.is_empty():
			feature_index_by_id[feature_id] = i
		if str(feature.get("type", "")).to_lower() != "gene":
			continue
		gene_index_by_key[_feature_pair_key(feature)] = i
		if not feature_id.is_empty():
			gene_index_by_id[feature_id] = i
	var drop_indexes := {}
	var cds_parts_by_gene := {}
	for i in range(features_in.size()):
		var feature: Dictionary = features_in[i]
		if str(feature.get("type", "")).to_lower() != "cds":
			continue
		var parent_id := str(feature.get("parent", "")).strip_edges()
		if parent_id.is_empty():
			continue
		var gene_idx := -1
		if gene_index_by_id.has(parent_id):
			gene_idx = int(gene_index_by_id[parent_id])
		elif feature_index_by_id.has(parent_id):
			var parent_feature: Dictionary = features_in[int(feature_index_by_id[parent_id])]
			var grandparent_id := str(parent_feature.get("parent", "")).strip_edges()
			if gene_index_by_id.has(grandparent_id):
				gene_idx = int(gene_index_by_id[grandparent_id])
		if gene_idx < 0:
			var pair_key := _feature_pair_key(feature)
			if not gene_index_by_key.has(pair_key):
				continue
			gene_idx = int(gene_index_by_key[pair_key])
		var parts: Array = cds_parts_by_gene.get(gene_idx, [])
		parts.append(feature.duplicate(true))
		cds_parts_by_gene[gene_idx] = parts
		drop_indexes[i] = true
	for gene_idx_any in cds_parts_by_gene.keys():
		var gene_idx := int(gene_idx_any)
		var gene_feature: Dictionary = features_in[gene_idx]
		var parts: Array = cds_parts_by_gene[gene_idx]
		parts.sort_custom(func(a_any: Variant, b_any: Variant) -> bool:
			var a: Dictionary = a_any
			var b: Dictionary = b_any
			return int(a.get("start", 0)) < int(b.get("start", 0))
		)
		gene_feature["cds_parts"] = parts
		if parts.size() == 1:
			gene_feature["paired_cds"] = parts[0]
		features_in[gene_idx] = gene_feature
	var multipart_gene_ids := {}
	for gene_idx_any in cds_parts_by_gene.keys():
		var gene_idx := int(gene_idx_any)
		var gene_feature: Dictionary = features_in[gene_idx]
		var gene_id := str(gene_feature.get("id", "")).strip_edges()
		var parts: Array = cds_parts_by_gene[gene_idx]
		if parts.size() > 1 and not gene_id.is_empty():
			multipart_gene_ids[gene_id] = true
	for i in range(features_in.size()):
		if drop_indexes.get(i, false):
			continue
		var feature: Dictionary = features_in[i]
		if str(feature.get("type", "")).to_lower() == "gene":
			continue
		var parent_id := str(feature.get("parent", "")).strip_edges()
		if parent_id.is_empty():
			continue
		if multipart_gene_ids.has(parent_id):
			drop_indexes[i] = true
			continue
		if feature_index_by_id.has(parent_id):
			var parent_feature: Dictionary = features_in[int(feature_index_by_id[parent_id])]
			var grandparent_id := str(parent_feature.get("parent", "")).strip_edges()
			if multipart_gene_ids.has(grandparent_id):
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

func _invalidate_viewport_cache() -> void:
	_cache_start = -1
	_cache_end = -1
	_cache_zoom = -1
	_cache_mode = -1
	_cache_need_reference = false
	_cache_scope_key = ""

func _finish_sync_fetch_attempt() -> void:
	if not _fetch_in_progress:
		return
	_fetch_in_progress = false
	if _fetch_pending and _fetch_timer != null:
		_fetch_timer.start()

func _refresh_visible_data() -> void:
	_annotation_cache_controller.refresh_visible_data()

func _annotation_pixel_budget() -> int:
	return _annotation_cache_controller.annotation_pixel_budget()

func _annotation_min_feature_len_bp() -> int:
	return _annotation_cache_controller.annotation_min_feature_len_bp()

func _schedule_fetch() -> void:
	_annotation_cache_controller.schedule_fetch()

func _on_fetch_timer_timeout() -> void:
	_annotation_cache_controller.on_fetch_timer_timeout()

func _drain_tile_fetch_result() -> void:
	_annotation_cache_controller.drain_tile_fetch_result()

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

func _compute_tile_zoom(bp_per_px: float) -> int:
	var z := int(round(log(max(bp_per_px, 0.001)) / log(2.0)))
	return clampi(z, 0, 16)

func _record_loaded_files(files: PackedStringArray, replace_existing: bool) -> void:
	_session_loader.record_loaded_files(files, replace_existing)

func _reset_loaded_state() -> void:
	_session_loader.reset_loaded_state()
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
	var slot_bank: Dictionary = _view_slots.get(_app_mode, {})
	if _app_mode == APP_MODE_COMPARISON:
		if _comparison_controller == null or not _comparison_controller.has_genomes():
			_set_status("No comparison genomes loaded: cannot save view slot.", true)
			return
		slot_bank[slot_idx] = {
			"app_mode": APP_MODE_COMPARISON,
			"scope_key": _comparison_controller.get_view_slot_scope_key(),
			"comparison_state": _comparison_controller.get_view_slot_state()
		}
		_view_slots[_app_mode] = slot_bank
		_set_status("Saved view slot %d." % slot_idx)
		return
	if _current_chr_len <= 0:
		_set_status("No genome loaded: cannot save view slot.", true)
		return
	var state: Dictionary = genome_view.get_view_state()
	slot_bank[slot_idx] = {
		"scope_key": _scope_cache_key(),
		"seq_view_mode": _seq_view_mode,
		"seq_id": _selected_seq_id,
		"start_bp": float(state.get("start_bp", _last_start)),
		"bp_per_px": float(state.get("bp_per_px", _last_bp_per_px))
	}
	_view_slots[_app_mode] = slot_bank
	_set_status("Saved view slot %d." % slot_idx)

func _load_view_slot(slot_idx: int) -> void:
	var slot_bank: Dictionary = _view_slots.get(_app_mode, {})
	if not slot_bank.has(slot_idx):
		_set_status("View slot %d is empty." % slot_idx, true)
		return
	var slot_any = slot_bank[slot_idx]
	if typeof(slot_any) != TYPE_DICTIONARY:
		_set_status("View slot %d is invalid." % slot_idx, true)
		return
	var slot: Dictionary = slot_any
	var slot_mode := int(slot.get("app_mode", APP_MODE_BROWSER))
	if slot_mode == APP_MODE_COMPARISON:
		if _comparison_controller == null or not _comparison_controller.has_genomes():
			_set_status("No comparison genomes loaded: cannot load view slot.", true)
			return
		var slot_scope_cmp := str(slot.get("scope_key", ""))
		if slot_scope_cmp != _comparison_controller.get_view_slot_scope_key():
			_set_status("View slot %d is from a different comparison scope." % slot_idx, true)
			return
		var cmp_state_any: Variant = slot.get("comparison_state", {})
		if typeof(cmp_state_any) != TYPE_DICTIONARY:
			_set_status("View slot %d is invalid." % slot_idx, true)
			return
		_comparison_controller.apply_view_slot_state(cmp_state_any)
		_set_status("Loaded view slot %d." % slot_idx)
		return
	if _current_chr_len <= 0:
		_set_status("No genome loaded: cannot load view slot.", true)
		return
	var slot_scope := str(slot.get("scope_key", ""))
	if slot_scope != _scope_cache_key():
		_set_status("View slot %d is from a different genome/session scope." % slot_idx, true)
		return
	var seq_slot_mode := int(slot.get("seq_view_mode", _seq_view_mode))
	if seq_slot_mode != _seq_view_mode:
		_seq_view_option.select(seq_slot_mode)
		_on_seq_view_selected(seq_slot_mode)
	if seq_slot_mode == SEQ_VIEW_SINGLE:
		var target_id := int(slot.get("seq_id", _selected_seq_id))
		for i in range(_seq_option.item_count):
			if int(_seq_option.get_item_id(i)) == target_id:
				_seq_option.select(i)
				_on_seq_selected(i)
				break
	_navigate_to_view(float(slot.get("start_bp", _last_start)), float(slot.get("bp_per_px", _last_bp_per_px)))
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
	var left_threshold: int = maxi(1, int(round(float(span) * 0.4)))
	var right_threshold: int = maxi(1, int(round(float(span) * 0.4)))
	var remaining_left: int = start_bp - _cache_start
	var remaining_right: int = _cache_end - end_bp
	return remaining_left <= left_threshold or remaining_right <= right_threshold

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
	enable_vertical_swipe_zoom_button.button_pressed = bool(cfg.get_value("input", "enable_vertical_swipe_zoom", true))
	mouse_wheel_zoom_slider.value = float(cfg.get_value("input", "mouse_wheel_zoom_sensitivity", mouse_wheel_zoom_slider.value))
	invert_mouse_wheel_zoom_button.button_pressed = bool(cfg.get_value("input", "invert_mouse_wheel_zoom", false))
	mouse_wheel_pan_slider.value = float(cfg.get_value("input", "mouse_wheel_pan_sensitivity", mouse_wheel_pan_slider.value))
	pan_step_slider.value = clampf(float(cfg.get_value("input", "pan_step_percent", 75.0)), 1.0, 100.0)
	_on_pan_step_changed(pan_step_slider.value)
	_ui_font_size = clampi(int(cfg.get_value("ui", "font_size", DEFAULT_UI_FONT_SIZE)), MIN_UI_FONT_SIZE, MAX_UI_FONT_SIZE)
	if _font_size_slider != null:
		_font_size_slider.value = _ui_font_size
	_ui_font_name = str(cfg.get_value("ui", "font_name", "Noto Sans"))
	for i in range(ui_font_option.item_count):
		if ui_font_option.get_item_text(i) == _ui_font_name:
			ui_font_option.select(i)
			break
	_sequence_letter_font_name = str(cfg.get_value("ui", "sequence_letter_font", "Anonymous Pro"))
	for i in range(sequence_letter_font_option.item_count):
		if sequence_letter_font_option.get_item_text(i) == _sequence_letter_font_name:
			sequence_letter_font_option.select(i)
			break
	genome_view.set_sequence_letter_font_name(_sequence_letter_font_name)
	if comparison_view != null and comparison_view.has_method("set_sequence_letter_font_name"):
		comparison_view.set_sequence_letter_font_name(_sequence_letter_font_name)
	var default_anim_speed := 1.5
	if cfg.has_section_key("ui", "animate_pan_zoom_speed"):
		default_anim_speed = float(cfg.get_value("ui", "animate_pan_zoom_speed", 1.0))
		if default_anim_speed <= 0.0:
			default_anim_speed = 3.0
		elif default_anim_speed < 1.0:
			default_anim_speed = 1.0
		elif default_anim_speed > 3.0:
			default_anim_speed = 3.0
	elif cfg.has_section_key("ui", "animate_pan_zoom"):
		default_anim_speed = 1.5 if bool(cfg.get_value("ui", "animate_pan_zoom", true)) else 0.0
		if default_anim_speed <= 0.0:
			default_anim_speed = 3.0
	animate_pan_zoom_slider.value = clampf(default_anim_speed, 1.0, 3.0)
	_on_animate_pan_zoom_speed_changed(animate_pan_zoom_slider.value)

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
	_genome_cache_max_mb = maxi(1, int(cfg.get_value("ui", "genome_cache_max_mb", GENOME_CACHE_MAX_MB_DEFAULT)))
	if _genome_cache_spin != null:
		_genome_cache_spin.value = _genome_cache_max_mb
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
	cfg.set_value("ui", "animate_pan_zoom_speed", animate_pan_zoom_slider.value)
	cfg.set_value("ui", "theme", theme_option.get_item_text(theme_option.selected))
	cfg.set_value("ui", "font_name", _ui_font_name)
	cfg.set_value("ui", "font_size", _ui_font_size)
	cfg.set_value("ui", "sequence_letter_font", _sequence_letter_font_name)
	cfg.set_value("ui", "sequence_view_mode", _seq_view_mode)
	cfg.set_value("ui", "concat_gap_bp", _concat_gap_bp)
	cfg.set_value("ui", "selected_sequence_name", _selected_seq_name)
	cfg.set_value("ui", "show_full_length_regions", _show_full_length_regions)
	cfg.set_value("ui", "colorize_nucleotides", _colorize_nucleotides)
	cfg.set_value("ui", "axis_coords_with_commas", _axis_coords_with_commas)
	cfg.set_value("ui", "gc_window_bp", _gc_window_bp)
	cfg.set_value("ui", "bam_cov_precompute_cutoff_bp", _bam_cov_precompute_cutoff_bp)
	cfg.set_value("ui", "genome_cache_max_mb", _genome_cache_max_mb)
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
	cfg.set_value("input", "enable_vertical_swipe_zoom", enable_vertical_swipe_zoom_button.button_pressed)
	cfg.set_value("input", "mouse_wheel_zoom_sensitivity", mouse_wheel_zoom_slider.value)
	cfg.set_value("input", "invert_mouse_wheel_zoom", invert_mouse_wheel_zoom_button.button_pressed)
	cfg.set_value("input", "mouse_wheel_pan_sensitivity", mouse_wheel_pan_slider.value)
	cfg.set_value("input", "pan_step_percent", _pan_step_percent)
	cfg.save(CONFIG_PATH)

func _on_feature_clicked(feature: Dictionary) -> void:
	_feature_panel_controller.on_feature_clicked(feature)

func _on_feature_selected(feature: Dictionary) -> void:
	_feature_panel_controller.on_feature_selected(feature)

func _on_read_clicked(read: Dictionary) -> void:
	_feature_panel_controller.on_read_clicked(read)

func _on_read_selected(read: Dictionary) -> void:
	_feature_panel_controller.on_read_selected(read)

func _on_comparison_match_selected(match: Dictionary, was_double_click: bool = false) -> void:
	if was_double_click and not _feature_panel_open:
		return
	_feature_panel_controller.on_comparison_match_clicked(match)

func _on_comparison_feature_selected(feature: Dictionary, was_double_click: bool = false) -> void:
	if was_double_click:
		_feature_panel_controller.on_feature_clicked(feature)
	else:
		_feature_panel_controller.on_feature_selected(feature)

func _on_comparison_match_cleared() -> void:
	if not _feature_panel_open:
		return
	if feature_title_label.text != "Comparison Match":
		return
	_close_feature_panel()

func _on_comparison_region_selected(selection: Dictionary) -> void:
	_feature_panel_controller.show_selected_matches(selection)

func _on_comparison_region_cleared() -> void:
	if not _feature_panel_open:
		return
	if feature_title_label.text != "selected matches":
		return
	_close_feature_panel()

func _on_selected_comparison_region_match(match: Dictionary) -> void:
	if _comparison_controller == null:
		return
	_comparison_controller.focus_match_payload(match)

func _jump_to_mate(start_bp: int, end_bp: int) -> void:
	_feature_panel_controller.jump_to_mate(start_bp, end_bp)

func _format_read_flags(flags: int) -> String:
	return _feature_panel_controller.format_read_flags(flags)

func _close_feature_panel() -> void:
	if _context_panel_mode == CONTEXT_PANEL_SELECTED_MATCHES and _comparison_controller != null:
		_comparison_controller.clear_region_selection()
	_feature_panel_controller.close_feature_panel()

func _process(_delta: float) -> void:
	_drain_tile_fetch_result()
	if _pending_pan_active:
		var show_aa: bool = bool(genome_view.is_track_visible(TRACK_AA))
		var show_genome: bool = bool(genome_view.is_track_visible(TRACK_GENOME))
		var need_reference: bool = bool(genome_view.needs_reference_data(show_aa, show_genome))
		var zoom := _compute_tile_zoom(_pending_pan_bp_per_px)
		var mode := 0 if (_has_bam_loaded and _any_visible_read_track() and _pending_pan_bp_per_px <= READ_RENDER_MAX_BP_PER_PX) else 1
		var annotations_ready := _is_viewport_cached(int(_pending_pan_target_start), _pending_pan_target_end, zoom, mode, need_reference, _scope_cache_key())
		var reads_ready := true
		if _annotation_cache_controller.detailed_read_strips_enabled(_pending_pan_bp_per_px):
			reads_ready = _annotation_cache_controller.detailed_read_target_ready(int(_pending_pan_target_start), _pending_pan_target_end, _pending_pan_bp_per_px)
		if reads_ready and annotations_ready:
			_pending_pan_active = false
			if _annotation_cache_controller.detailed_read_strips_enabled(_pending_pan_bp_per_px):
				_annotation_cache_controller.apply_detailed_read_span(int(minf(genome_view.view_start_bp, _pending_pan_target_start)), int(maxf(_last_end, _pending_pan_target_end)), _pending_pan_bp_per_px)
			if _pending_pan_linear:
				genome_view.pan_to_start_linear(_pending_pan_target_start, _pending_pan_duration)
			else:
				genome_view.pan_to_start(_pending_pan_target_start, _pending_pan_duration)
			if _auto_play_enabled:
				_auto_play_tween_active = false
	elif _auto_play_enabled and _auto_play_tween_active and not genome_view.is_pan_animating():
		_auto_play_tween_active = false
	if _download_thread != null and _download_thread.is_started() and not _download_thread.is_alive():
		var download_result: Variant = _download_thread.wait_to_finish()
		_download_thread = null
		_finish_download_genome(download_result)
	if _generate_test_data_thread != null and _generate_test_data_thread.is_started() and not _generate_test_data_thread.is_alive():
		var generate_result: Variant = _generate_test_data_thread.wait_to_finish()
		_generate_test_data_thread = null
		_finish_generate_test_data(generate_result)
	if _generate_comparison_test_data_thread != null and _generate_comparison_test_data_thread.is_started() and not _generate_comparison_test_data_thread.is_alive():
		var comparison_generate_result: Variant = _generate_comparison_test_data_thread.wait_to_finish()
		_generate_comparison_test_data_thread = null
		_finish_generate_comparison_test_data(comparison_generate_result)
	if _startup_zem_prepare_thread != null and _startup_zem_prepare_thread.is_started() and not _startup_zem_prepare_thread.is_alive():
		var prepare_result: Variant = _startup_zem_prepare_thread.wait_to_finish()
		_startup_zem_prepare_thread = null
		_finish_startup_prepare_local_zem(prepare_result)
	if _startup_zem_connect_thread != null and _startup_zem_connect_thread.is_started() and not _startup_zem_connect_thread.is_alive():
		var connect_result: Variant = _startup_zem_connect_thread.wait_to_finish()
		_startup_zem_connect_thread = null
		_finish_startup_connect_local_zem(connect_result)
	if not _auto_play_enabled:
		return
	if _current_chr_len <= 0:
		_auto_play_enabled = false
		_auto_play_tween_active = false
		genome_view.end_motion_read_layer()
		_apply_settled_detailed_reads_if_needed()
		return
	if (_auto_play_direction > 0.0 and _last_end >= _current_chr_len) or (_auto_play_direction < 0.0 and _last_start <= 0):
		_auto_play_enabled = false
		_auto_play_tween_active = false
		genome_view.end_motion_read_layer()
		_apply_settled_detailed_reads_if_needed()
		if _auto_play_direction < 0.0:
			_set_status("Reached start of sequence. Autoplay stopped.")
		else:
			_set_status("Reached end of sequence. Autoplay stopped.")
		return
	_start_next_auto_play_segment()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("seqhiker_close_right_panel"):
		if _feature_panel_open:
			_close_feature_panel()
			get_viewport().set_input_as_handled()
