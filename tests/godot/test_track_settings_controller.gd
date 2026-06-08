extends "res://tests/godot/test_case.gd"

const ReadTrackSettingsPanelScene = preload("res://scenes/ReadTrackSettingsPanel.tscn")
const TrackSettingsControllerScript = preload("res://scripts/track_settings_controller.gd")

var host: FakeHost
var feature_content: VBoxContainer
var controller: RefCounted


class FakeHost:
	extends Node

	const CONTEXT_PANEL_TRACK_SETTINGS := 2
	const TRACK_AA := "aa"
	const TRACK_GC_PLOT := "gc_plot"
	const TRACK_DEPTH_PLOT := "depth_plot"
	const TRACK_VCF := "vcf"
	const TRACK_GENOME := "genome"
	const SEQ_VIEW_CONCAT := 0
	const SEQ_VIEW_SINGLE := 1
	const DEFAULT_READ_THICKNESS := 8.0
	const DEFAULT_READ_MAX_ROWS := 500
	const DEFAULT_READ_MIN_MAPQ := 0
	const DEFAULT_READ_HIDDEN_FLAGS := 256 | 512 | 1024 | 2048
	const ANNOT_MAX_ON_SCREEN_MIN := 200
	const ANNOT_MAX_ON_SCREEN_MAX := 50000
	const MIN_PLOT_HEIGHT := 50.0
	const MAX_PLOT_HEIGHT := 360.0
	const READ_FILTER_FLAG_LABELS := [
		{"bit": 1, "label": "paired"},
		{"bit": 2, "label": "proper pair"},
		{"bit": 8, "label": "mate unmapped"},
		{"bit": 16, "label": "reverse strand"}
	]

	var _track_settings_box: VBoxContainer
	var _read_track_settings_panel: VBoxContainer
	var _track_settings_open := false
	var _active_track_settings_id := ""
	var _feature_panel_open := false
	var feature_name_label := Label.new()
	var _bam_tracks: Array[Dictionary] = [
		{
			"track_id": "reads:1",
			"label": "sample.bam",
			"view_mode": 0,
			"fragment_log": true,
			"thickness": 8.0,
			"auto_expand_snp_text": true,
			"show_soft_clips": false,
			"show_pileup_logo": false,
			"color_by_mate_contig": false,
			"max_rows": 500,
			"min_mapq": 0,
			"hidden_flags": 0
		}
	]
	var _show_full_length_regions := false
	var _show_stop_codons := false
	var _annotation_max_on_screen := 4400
	var _seq_view_mode := SEQ_VIEW_CONCAT
	var _selected_seq_id := -1
	var _seq_option := OptionButton.new()
	var _concat_gap_bp := 50
	var _axis_coords_with_commas := false
	var _gc_window_bp := 200
	var _gc_plot_height := 100.0
	var _depth_plot_height := 100.0
	var _has_bam_loaded := true
	var _variant_controller: RefCounted = null
	var prepared_title := ""
	var close_count := 0
	var save_count := 0
	var sound_count := 0
	var slide_count := 0
	var fetch_count := 0

	func _track_label_for_id(track_id: String) -> String:
		return "Reads" if track_id.begins_with("reads:") else track_id

	func _prepare_context_panel(_mode: int, title: String, _show_detail_labels: bool) -> void:
		prepared_title = title
		_track_settings_open = false
		_active_track_settings_id = ""

	func _play_ui_sound(_sound_id: String) -> void:
		sound_count += 1

	func _close_feature_panel() -> void:
		close_count += 1
		_feature_panel_open = false

	func _save_config() -> void:
		save_count += 1

	func _bam_track_for_id(track_id: String) -> Dictionary:
		for track in _bam_tracks:
			if str(track.get("track_id", "")) == track_id:
				return track
		return {}

	func _play_toggle_sound(_enabled: bool) -> void:
		sound_count += 1

	func _schedule_fetch() -> void:
		fetch_count += 1

	func _slide_feature_panel(_open: bool, _animated: bool) -> void:
		slide_count += 1

	func _on_active_read_track_view_selected(_index: int) -> void:
		pass

	func _on_active_read_track_fragment_log_toggled(_enabled: bool) -> void:
		pass

	func _on_active_read_track_thickness_changed(_value: float) -> void:
		pass

	func _on_active_read_track_auto_expand_snp_toggled(_enabled: bool) -> void:
		pass

	func _on_active_read_track_show_soft_clips_toggled(_enabled: bool) -> void:
		pass

	func _on_active_read_track_show_pileup_logo_toggled(_enabled: bool) -> void:
		pass

	func _on_active_read_track_mate_contig_color_toggled(_enabled: bool) -> void:
		pass

	func _on_active_read_track_max_rows_changed(_value: float) -> void:
		pass

	func _on_active_read_track_min_mapq_changed(_value: float) -> void:
		pass

	func _on_show_full_region_toggled(_enabled: bool) -> void:
		pass

	func _on_show_stop_codons_toggled(_enabled: bool) -> void:
		pass

	func _on_annotation_max_on_screen_changed(_value: float) -> void:
		pass

	func _on_axis_coords_commas_toggled(_enabled: bool) -> void:
		pass

	func _on_seq_view_selected(_index: int) -> void:
		pass

	func _on_seq_selected(_index: int) -> void:
		pass

	func _on_concat_gap_changed(_value: float) -> void:
		pass

	func _invalidate_cache() -> void:
		pass

	func _apply_gc_plot_height() -> void:
		pass

	func _apply_depth_plot_height() -> void:
		pass

	func _depth_plot_color_for_track(_track_id: String) -> Color:
		return Color.WHITE


func setup() -> void:
	host = FakeHost.new()
	host.add_child(host.feature_name_label)
	host.add_child(host._seq_option)
	feature_content = VBoxContainer.new()
	host.add_child(feature_content)
	controller = TrackSettingsControllerScript.new()
	controller.configure(host)
	controller.setup(feature_content, ReadTrackSettingsPanelScene)


func teardown() -> void:
	host.free()
	host = null
	feature_content = null
	controller = null


func test_setup_creates_read_track_panel() -> void:
	assert_ne(host._track_settings_box, null)
	assert_ne(host._read_track_settings_panel, null)
	var view_option := host._read_track_settings_panel.get_node("ReadViewOption") as OptionButton
	assert_eq(view_option.item_count, 4)


func test_show_read_track_settings_populates_controls() -> void:
	controller.show_track_settings("reads:1")

	assert_true(host._track_settings_open)
	assert_eq(host._active_track_settings_id, "reads:1")
	assert_eq(host.prepared_title, "Reads track settings")
	assert_true(host._read_track_settings_panel.visible)
	var bam_label := host._read_track_settings_panel.get_node("BAMLabel") as Label
	assert_eq(bam_label.text, "BAM: sample.bam")
	var dynamic_options := host._read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
	assert_true(dynamic_options.get_child_count() > 0)


func test_read_filter_toggle_updates_track_and_fetches() -> void:
	controller.show_track_settings("reads:1")
	var dynamic_options := host._read_track_settings_panel.get_node("DynamicOptions") as VBoxContainer
	var paired_cb := dynamic_options.get_child(0) as CheckBox

	paired_cb.button_pressed = true

	assert_true((int(host._bam_tracks[0].get("hidden_flags", 0)) & 1) != 0)
	assert_eq(host.fetch_count, 1)


func test_reopening_same_track_closes_panel() -> void:
	controller.show_track_settings("reads:1")
	controller.show_track_settings("reads:1")

	assert_eq(host.close_count, 1)
