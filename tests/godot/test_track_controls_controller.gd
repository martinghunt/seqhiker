extends "res://tests/godot/test_case.gd"

const TrackControlsControllerScript = preload("res://scripts/track_controls_controller.gd")

var host: FakeHost
var controller: RefCounted


class FakeGenomeView:
	extends Node

	signal track_order_changed(order: PackedStringArray)
	signal track_visibility_changed(track_id: String, visible: bool)

	var order := PackedStringArray(["reads:1", "depth_plot", "gc_plot", "aa", "vcf", "genome", "map"])
	var visible_by_track := {
		"aa": true,
		"vcf": true,
		"genome": true,
		"gc_plot": true,
		"depth_plot": true,
		"map": true,
		"reads:1": true,
		"reads:2": true
	}

	func get_track_order() -> PackedStringArray:
		return order.duplicate()

	func set_track_order(next_order: PackedStringArray) -> void:
		order = next_order.duplicate()
		emit_signal("track_order_changed", order.duplicate())

	func is_track_visible(track_id: String) -> bool:
		return bool(visible_by_track.get(track_id, true))

	func set_track_visible(track_id: String, visible: bool) -> void:
		if bool(visible_by_track.get(track_id, true)) == visible:
			return
		visible_by_track[track_id] = visible
		emit_signal("track_visibility_changed", track_id, visible)


class FakeHost:
	extends Node

	const TRACK_READS := "reads"
	const TRACK_AA := "aa"
	const TRACK_GC_PLOT := "gc_plot"
	const TRACK_DEPTH_PLOT := "depth_plot"
	const TRACK_VCF := "vcf"
	const TRACK_GENOME := "genome"

	var genome_view := FakeGenomeView.new()
	var _track_order_label := Label.new()
	var _track_visibility_box := VBoxContainer.new()
	var _track_visibility_aa := CheckButton.new()
	var _track_visibility_genome := CheckButton.new()
	var _track_visibility_gc_plot := CheckButton.new()
	var _track_visibility_depth_plot := CheckButton.new()
	var _track_visibility_map := CheckButton.new()
	var _track_visibility_vcf: CheckButton = null
	var _track_order_list := ItemList.new()
	var _variant_sources: Array[Dictionary] = [{"path": "variants.vcf"}]
	var _has_bam_loaded := true
	var _current_chr_len := 1000
	var _bam_tracks: Array[Dictionary] = [
		{"track_id": "reads:1"},
		{"track_id": "reads:2"}
	]
	var sound_count := 0
	var status_messages: Array[Dictionary] = []
	var sync_count := 0
	var window_min_height_count := 0
	var invalidate_count := 0
	var schedule_count := 0

	func _track_label_for_id(track_id: String) -> String:
		match track_id:
			"reads:1":
				return "Reads"
			"aa":
				return "AA / Annotation"
			"vcf":
				return "VCF"
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

	func _play_toggle_sound(_enabled: bool) -> void:
		sound_count += 1

	func _set_status(message: String, is_error: bool = false) -> void:
		status_messages.append({"message": message, "is_error": is_error})

	func _sync_bam_read_tracks() -> void:
		sync_count += 1

	func _update_window_min_height() -> void:
		window_min_height_count += 1

	func _invalidate_cache() -> void:
		invalidate_count += 1

	func _schedule_fetch() -> void:
		schedule_count += 1


func setup() -> void:
	host = FakeHost.new()
	host.add_child(host.genome_view)
	host.add_child(host._track_order_label)
	host.add_child(host._track_visibility_box)
	host._track_visibility_box.add_child(host._track_visibility_map)
	host._track_visibility_box.add_child(host._track_visibility_genome)
	host._track_visibility_box.add_child(host._track_visibility_aa)
	host._track_visibility_box.add_child(host._track_visibility_gc_plot)
	host._track_visibility_box.add_child(host._track_visibility_depth_plot)
	host.add_child(host._track_order_list)
	controller = TrackControlsControllerScript.new()
	controller.configure(host)
	controller.setup()


func teardown() -> void:
	host.free()
	host = null
	controller = null


func test_setup_adds_vcf_control_and_populates_order_list() -> void:
	controller.refresh_track_order_list(host.genome_view.get_track_order())

	assert_ne(host._track_visibility_vcf, null)
	assert_eq(host._track_order_label.text, "Track Visibility")
	assert_eq(host._track_order_list.item_count, host.genome_view.order.size())
	assert_true(host._track_visibility_vcf.visible)


func test_unavailable_vcf_and_depth_controls_are_disabled_or_hidden() -> void:
	host._variant_sources.clear()
	host._has_bam_loaded = false

	controller.refresh_track_visibility_controls(host.genome_view.get_track_order())

	assert_false(host._track_visibility_vcf.visible)
	assert_false(host.genome_view.is_track_visible(host.TRACK_VCF))
	assert_true(host._track_visibility_depth_plot.disabled)
	assert_false(host.genome_view.is_track_visible(host.TRACK_DEPTH_PLOT))


func test_toggle_track_updates_view_and_refreshes_data() -> void:
	host._track_visibility_aa.button_pressed = false

	assert_false(host.genome_view.is_track_visible(host.TRACK_AA))
	assert_eq(host.sound_count, 1)
	assert_true(host.invalidate_count > 0)
	assert_true(host.schedule_count > 0)


func test_depth_toggle_without_bam_shows_status_and_stays_off() -> void:
	host._has_bam_loaded = false

	host._track_visibility_depth_plot.button_pressed = false
	host._track_visibility_depth_plot.button_pressed = true

	assert_eq(host.status_messages.size(), 1)
	assert_false(host.genome_view.is_track_visible(host.TRACK_DEPTH_PLOT))
	assert_eq(host.sound_count, 1)


func test_hiding_read_track_removes_its_bam_track() -> void:
	controller._on_track_visibility_changed("reads:2", false)

	assert_eq(host._bam_tracks.size(), 1)
	assert_eq(str(host._bam_tracks[0].get("track_id", "")), "reads:1")
	assert_eq(host.sync_count, 1)
	assert_true(host._has_bam_loaded)


func test_drag_drop_reorders_tracks() -> void:
	host.genome_view.order = PackedStringArray(["reads:1", "aa", "genome", "map"])
	controller.refresh_track_order_list(host.genome_view.get_track_order())
	controller._track_drag_index = 1
	controller._track_drop_index = 3

	controller._apply_track_drag_drop()

	assert_eq(host.genome_view.order, PackedStringArray(["reads:1", "genome", "aa", "map"]))
	assert_eq(host._track_order_list.get_selected_items()[0], 2)
