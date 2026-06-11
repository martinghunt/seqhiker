extends RefCounted
class_name TrackControlsController

var host: Node = null
var _track_dragging := false
var _track_drag_index := -1
var _track_drop_index := -1


func configure(next_host: Node) -> void:
	host = next_host


func setup() -> void:
	if host == null:
		return
	host._track_order_label.text = "Track Visibility"
	host._track_visibility_box.add_theme_constant_override("separation", 4)
	if host._track_visibility_vcf == null:
		host._track_visibility_vcf = CheckButton.new()
	host._track_visibility_vcf.text = " VCF"
	if host._track_visibility_vcf.get_parent() != host._track_visibility_box:
		if host._track_visibility_vcf.get_parent() != null:
			host._track_visibility_vcf.get_parent().remove_child(host._track_visibility_vcf)
		host._track_visibility_box.add_child(host._track_visibility_vcf)
	_connect_track_visibility_toggle(host._track_visibility_aa, host.TRACK_AA)
	_connect_track_visibility_toggle(host._track_visibility_genome, host.TRACK_GENOME)
	_connect_track_visibility_toggle(host._track_visibility_gc_plot, host.TRACK_GC_PLOT)
	_connect_track_visibility_toggle(host._track_visibility_depth_plot, host.TRACK_DEPTH_PLOT)
	_connect_track_visibility_toggle(host._track_visibility_vcf, host.TRACK_VCF)
	_connect_track_visibility_toggle(host._track_visibility_map, "map")
	if not host.genome_view.track_order_changed.is_connected(_on_track_order_changed):
		host.genome_view.track_order_changed.connect(_on_track_order_changed)
	if not host.genome_view.track_visibility_changed.is_connected(_on_track_visibility_changed):
		host.genome_view.track_visibility_changed.connect(_on_track_visibility_changed)
	if host._track_order_list != null and not host._track_order_list.gui_input.is_connected(_on_track_order_list_gui_input):
		host._track_order_list.gui_input.connect(_on_track_order_list_gui_input)
	refresh_track_visibility_controls(host.genome_view.get_track_order())


func refresh_track_order_list(order: PackedStringArray, select_idx: int = -1) -> void:
	if host == null or host._track_order_list == null:
		return
	host._track_order_list.clear()
	for id in order:
		host._track_order_list.add_item(host._track_label_for_id(str(id)))
	if host._track_order_list.item_count <= 0:
		return
	var idx := select_idx
	if idx < 0 or idx >= host._track_order_list.item_count:
		idx = 0
	host._track_order_list.select(idx)
	refresh_track_visibility_controls(order)


func refresh_track_visibility_controls(order: PackedStringArray) -> void:
	if host == null or host._track_visibility_box == null:
		return
	var visible_ids := {}
	for id_any in order:
		var track_id := str(id_any)
		if track_id == host.TRACK_READS or track_id.begins_with("reads:"):
			continue
		visible_ids[track_id] = true
	var controls := {
		host.TRACK_AA: host._track_visibility_aa,
		host.TRACK_VCF: host._track_visibility_vcf,
		host.TRACK_GENOME: host._track_visibility_genome,
		host.TRACK_GC_PLOT: host._track_visibility_gc_plot,
		host.TRACK_DEPTH_PLOT: host._track_visibility_depth_plot,
		"map": host._track_visibility_map
	}
	for track_id_any in controls.keys():
		var track_id := str(track_id_any)
		var cb := controls[track_id] as CheckButton
		if cb == null:
			continue
		var available := bool(visible_ids.get(track_id, false))
		if track_id == host.TRACK_VCF and host._variant_sources.is_empty():
			available = false
			host.genome_view.set_track_visible(track_id, false)
		cb.visible = available
		if not cb.visible:
			continue
		var is_depth: bool = track_id == host.TRACK_DEPTH_PLOT
		if is_depth and not host._has_bam_loaded:
			host.genome_view.set_track_visible(track_id, false)
		cb.set_pressed_no_signal(host.genome_view.is_track_visible(track_id))
		cb.disabled = is_depth and not host._has_bam_loaded


func _on_track_order_changed(order: PackedStringArray) -> void:
	refresh_track_order_list(order)
	refresh_track_visibility_controls(order)
	host._update_window_min_height()


func _on_track_visibility_changed(track_id: String, visible: bool) -> void:
	if track_id.begins_with("reads:") and not visible:
		for i in range(host._bam_tracks.size() - 1, -1, -1):
			var t: Dictionary = host._bam_tracks[i]
			if str(t.get("track_id", "")) == track_id:
				host._bam_tracks.remove_at(i)
				break
		host._sync_bam_read_tracks()
		host._has_bam_loaded = not host._bam_tracks.is_empty()
	refresh_track_visibility_controls(host.genome_view.get_track_order())
	host._update_window_min_height()
	host._invalidate_cache()
	if host._current_chr_len > 0:
		host._schedule_fetch()


func _on_track_visibility_toggled(checked: bool, track_id: String) -> void:
	if track_id == host.TRACK_DEPTH_PLOT and checked and not host._has_bam_loaded:
		host._set_status("Read depth plot requires BAM.", true)
		refresh_track_visibility_controls(host.genome_view.get_track_order())
		return
	host._play_toggle_sound(checked)
	host.genome_view.set_track_visible(track_id, checked)
	host._invalidate_cache()
	if host._current_chr_len > 0:
		host._schedule_fetch()


func _on_track_order_list_gui_input(event: InputEvent) -> void:
	if host == null or host._track_order_list == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			var idx: int = host._track_order_list.get_item_at_position(host._track_order_list.get_local_mouse_position(), true)
			if idx >= 0:
				_track_dragging = true
				_track_drag_index = idx
				_track_drop_index = idx
				host._track_order_list.select(idx)
				host._track_order_list.accept_event()
			return
		if _track_dragging:
			_apply_track_drag_drop()
			host._track_order_list.accept_event()
		_track_dragging = false
		_track_drag_index = -1
		_track_drop_index = -1
	elif event is InputEventMouseMotion and _track_dragging:
		var idx: int = host._track_order_list.get_item_at_position(host._track_order_list.get_local_mouse_position(), true)
		if idx >= 0:
			_track_drop_index = idx
			host._track_order_list.select(idx)


func _apply_track_drag_drop() -> void:
	if _track_drag_index < 0:
		return
	var order: PackedStringArray = host.genome_view.get_track_order()
	if order.is_empty() or _track_drag_index >= order.size():
		return
	var drop_idx := _track_drop_index
	if drop_idx < 0:
		var mp: Vector2 = host._track_order_list.get_local_mouse_position()
		drop_idx = 0 if mp.y < 0.0 else host._track_order_list.item_count - 1
	drop_idx = clampi(drop_idx, 0, order.size() - 1)
	if drop_idx == _track_drag_index:
		return
	var moving: String = str(order[_track_drag_index])
	order.remove_at(_track_drag_index)
	if drop_idx > _track_drag_index:
		drop_idx -= 1
	order.insert(drop_idx, moving)
	host.genome_view.set_track_order(order)
	refresh_track_order_list(host.genome_view.get_track_order(), drop_idx)


func _connect_track_visibility_toggle(control: CheckButton, track_id: String) -> void:
	if control == null:
		return
	var target := Callable(self, "_on_track_visibility_toggled").bind(track_id)
	if not control.toggled.is_connected(target):
		control.toggled.connect(target)
