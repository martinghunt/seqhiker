extends Control
class_name MotionReadCanvas

var view: GenomeView = null
var render_start_bp := 0.0
var render_end_bp := 0.0
var render_bp_per_px := 1.0


func configure(next_view: GenomeView) -> void:
	view = next_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_render_state(next_start_bp: float, next_end_bp: float, next_bp_per_px: float, canvas_size: Vector2) -> void:
	render_start_bp = next_start_bp
	render_end_bp = next_end_bp
	render_bp_per_px = next_bp_per_px
	size = canvas_size
	queue_redraw()


func _draw() -> void:
	if view == null:
		return
	var previous_track_id := view._active_read_track_id
	var track_rects := view._track_layout_rects()
	for track_id_any in view._track_order:
		var track_id := str(track_id_any)
		if not view._is_read_track(track_id):
			continue
		if not view.is_track_visible(track_id):
			continue
		if not track_rects.has(track_id):
			continue
		view._activate_read_track(track_id)
		if view.bp_per_px > view.DETAILED_READ_MAX_BP_PER_PX:
			continue
		var area: Rect2 = track_rects[track_id]
		view._read_renderer.draw_detailed_reads_to(self, area, render_start_bp, render_bp_per_px, render_end_bp, track_id)
	if not previous_track_id.is_empty() and view._read_track_states.has(previous_track_id):
		view._activate_read_track(previous_track_id)
