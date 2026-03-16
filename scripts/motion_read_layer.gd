extends TextureRect
class_name MotionReadLayer

const MotionReadCanvasScript = preload("res://scripts/motion_read_canvas.gd")

var view: GenomeView = null
var render_start_bp := 0.0
var render_end_bp := 0.0
var render_bp_per_px := 1.0
var _viewport: SubViewport = null
var _canvas: Control = null


func configure(next_view: GenomeView) -> void:
	view = next_view
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	stretch_mode = TextureRect.STRETCH_SCALE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_viewport = SubViewport.new()
	_viewport.disable_3d = true
	_viewport.transparent_bg = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_canvas = MotionReadCanvasScript.new()
	_canvas.configure(view)
	_viewport.add_child(_canvas)
	texture = _viewport.get_texture()


func activate(next_start_bp: float, next_end_bp: float, next_bp_per_px: float, content_width_px: float, show_layer: bool = true) -> void:
	render_start_bp = next_start_bp
	render_end_bp = next_end_bp
	render_bp_per_px = next_bp_per_px
	position = Vector2.ZERO
	size = Vector2(maxf(content_width_px, view.size.x), view.size.y)
	if _viewport != null:
		var viewport_size := Vector2i(maxi(1, int(ceil(size.x))), maxi(1, int(ceil(size.y))))
		_viewport.size = viewport_size
		_canvas.set_render_state(render_start_bp, render_end_bp, render_bp_per_px, Vector2(viewport_size))
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	visible = show_layer


func show_layer() -> void:
	visible = true


func covers(start_bp: float, end_bp: float) -> bool:
	return start_bp >= render_start_bp and end_bp <= render_end_bp


func set_offset_px(offset_px: float) -> void:
	position.x = -offset_px


func deactivate() -> void:
	visible = false
	if _viewport != null:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
