extends RefCounted
class_name TopBarController

const CLEAR_DISSOLVE_SHADER := """
shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 cell = floor(UV * vec2(220.0, 140.0));
	float noise = hash21(cell);
	float edge = smoothstep(progress - 0.10, progress + 0.02, noise);
	float glow = smoothstep(0.0, 0.08, edge) * (1.0 - smoothstep(0.08, 0.22, edge));
	vec3 fizz = tex.rgb + vec3(glow * 0.22);
	COLOR = vec4(fizz, tex.a * (1.0 - edge));
}
"""

var host: Node = null
var _comparison_toggle_tween: Tween
var _comparison_toggle_icon_label: Label
var _comparison_clear_tween: Tween
var _comparison_clear_icon_label: Label
var _view_mode_tween: Tween
var _clear_effect_tween: Tween
var _clear_effect_overlay: TextureRect
var _clear_effect_material: ShaderMaterial


func configure(next_host: Node) -> void:
	host = next_host


func setup() -> void:
	_setup_settings_toggle_icon()
	_setup_comparison_toggle_icon()
	_setup_comparison_clear_icon()


func toggle_comparison_mode() -> void:
	if host == null:
		return
	if host._app_mode == host.APP_MODE_COMPARISON:
		set_app_mode(host.APP_MODE_BROWSER)
		return
	set_app_mode(host.APP_MODE_COMPARISON)
	if host._comparison_controller != null:
		host._comparison_controller.ensure_seed_genome_loaded(host._loaded_file_paths)
		host._comparison_controller.refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
	refresh_comparison_topbar_state()


func set_app_mode(next_mode: int) -> void:
	if host == null:
		return
	var previous_mode: int = int(host._app_mode)
	host._app_mode = next_mode
	var comparison_active: bool = host._app_mode == host.APP_MODE_COMPARISON
	_apply_view_mode_visibility(previous_mode, next_mode)
	if host._search_controller != null:
		host._search_controller.refresh_context()
	_apply_comparison_toggle_icon_state(true)
	refresh_comparison_topbar_state()
	if host.viewport_label != null:
		if comparison_active:
			if host._comparison_controller != null and host._comparison_controller.has_genomes():
				host.viewport_label.text = host._format_comparison_viewport_label(host.comparison_view.get_visible_span_bp())
			else:
				host.viewport_label.text = "Comparison view"
		else:
			host.viewport_label.text = host._last_viewport_message if host._has_sequence_loaded else "No genome loaded"
	host._refresh_settings_sections()


func refresh_comparison_topbar_state() -> void:
	if host == null:
		return
	var comparison_active: bool = host._app_mode == host.APP_MODE_COMPARISON
	if host.comparison_button != null:
		host.comparison_button.tooltip_text = "Switch to single genome view" if comparison_active else "Switch to comparison view"
	if host.comparison_save_button != null:
		host.comparison_save_button.visible = comparison_active
	if host.comparison_clear_button != null:
		host.comparison_clear_button.visible = true
		if comparison_active:
			host.comparison_clear_button.tooltip_text = "Clear comparison view"
			host.comparison_clear_button.disabled = false
		else:
			host.comparison_clear_button.tooltip_text = "Clear browser view"
			host.comparison_clear_button.disabled = false


func on_screenshot_pressed() -> void:
	if host == null or host._screenshot_dialog == null:
		return
	if host.screenshot_button != null:
		host.screenshot_button.set_pressed_no_signal(false)
		host.screenshot_button.release_focus()
	if not _active_view_has_data_to_clear():
		return
	host._screenshot_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).get_base_dir()
	host._screenshot_dialog.current_file = "seqhiker-view.svg"
	host._screenshot_dialog.popup_centered_ratio(0.7)


func on_screenshot_file_selected(path: String) -> void:
	if host == null:
		return
	var out_path := path
	if not out_path.to_lower().ends_with(".svg"):
		out_path += ".svg"
	var ok := false
	if host._app_mode == host.APP_MODE_COMPARISON:
		ok = host.comparison_view != null and host.comparison_view.has_method("export_current_view_svg") and host.comparison_view.export_current_view_svg(out_path)
	else:
		ok = host.genome_view.export_current_view_svg(out_path)
	if ok:
		host._set_status("Saved screenshot: %s" % out_path)
	else:
		host._set_status("Failed to save screenshot: %s" % out_path, true)


func on_comparison_save_pressed() -> void:
	if host == null:
		return
	if host._comparison_controller == null or not host._comparison_controller.has_genomes():
		host._set_status("No comparison loaded: cannot save session.", true)
		return
	if host._comparison_save_dialog == null:
		return
	host._comparison_save_dialog.current_dir = OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP).get_base_dir()
	host._comparison_save_dialog.current_file = "comparison.seqhikercmp"
	host._comparison_save_dialog.popup_centered_ratio(0.7)


func on_comparison_save_file_selected(path: String) -> void:
	if host == null:
		return
	var out_path := path
	if not out_path.to_lower().ends_with(".seqhikercmp"):
		out_path += ".seqhikercmp"
	if host._comparison_controller != null:
		host._comparison_controller.save_session(out_path)


func on_clear_pressed() -> void:
	if host == null:
		return
	if not _active_view_has_data_to_clear():
		return
	_spin_clear_button()
	var clear_action := Callable(self, "_clear_comparison_view") if host._app_mode == host.APP_MODE_COMPARISON else Callable(self, "_clear_browser_view")
	if _play_clear_effect(clear_action):
		return
	clear_action.call()


func _clear_comparison_view() -> void:
	if host._app_mode == host.APP_MODE_COMPARISON:
		if host._comparison_controller == null:
			return
		if not host._comparison_controller.clear_state():
			return
		host._close_feature_panel()
		host._comparison_controller.refresh_view(host.theme_option.get_item_text(host.theme_option.selected))
		refresh_comparison_topbar_state()
		host._set_status("Cleared comparison view")
		return


func _clear_browser_view() -> void:
	host._reset_loaded_state()
	host._close_feature_panel()
	refresh_comparison_topbar_state()
	host._set_status("Cleared browser view")


func _play_clear_effect(clear_action: Callable) -> bool:
	if host == null:
		return false
	var active_view: Control = host.comparison_view if host._app_mode == host.APP_MODE_COMPARISON else host.genome_view
	if active_view == null or host._viewport_layer == null:
		return false
	var global_rect := active_view.get_global_rect()
	if global_rect.size.x < 2.0 or global_rect.size.y < 2.0:
		return false
	var viewport_tex := host.get_viewport().get_texture()
	if viewport_tex == null:
		return false
	var image := viewport_tex.get_image()
	if image == null or image.is_empty():
		return false
	var visible_rect: Rect2 = host.get_viewport().get_visible_rect()
	var viewport_scale := Vector2(
		float(image.get_width()) / maxf(1.0, visible_rect.size.x),
		float(image.get_height()) / maxf(1.0, visible_rect.size.y)
	)
	var canvas_origin: Vector2 = active_view.get_global_transform_with_canvas().origin
	var crop_pos: Vector2 = (canvas_origin * viewport_scale).round()
	var crop_size: Vector2 = (global_rect.size * viewport_scale).round()
	var crop_rect := Rect2i(
		clampi(int(crop_pos.x), 0, image.get_width()),
		clampi(int(crop_pos.y), 0, image.get_height()),
		clampi(int(crop_size.x), 0, image.get_width()),
		clampi(int(crop_size.y), 0, image.get_height())
	)
	crop_rect.size.x = mini(crop_rect.size.x, image.get_width() - crop_rect.position.x)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return false
	var cropped := image.get_region(crop_rect)
	if cropped == null or cropped.is_empty():
		return false
	_ensure_clear_effect_overlay()
	if _clear_effect_overlay == null or _clear_effect_material == null:
		return false
	var layer_origin: Vector2 = host._viewport_layer.get_global_rect().position
	_clear_effect_overlay.position = global_rect.position - layer_origin
	_clear_effect_overlay.size = global_rect.size
	_clear_effect_overlay.texture = ImageTexture.create_from_image(cropped)
	_clear_effect_overlay.visible = true
	_clear_effect_overlay.modulate = Color(1, 1, 1, 1)
	_clear_effect_material.set_shader_parameter("progress", 0.0)
	var duration := _effective_clear_animation_duration(0.34)
	if duration <= 0.0:
		clear_action.call()
		_hide_clear_effect_overlay()
		return true
	if _clear_effect_tween != null and _clear_effect_tween.is_running():
		_clear_effect_tween.kill()
	_clear_effect_tween = host.create_tween()
	_clear_effect_tween.set_trans(Tween.TRANS_CUBIC)
	_clear_effect_tween.set_ease(Tween.EASE_IN)
	_clear_effect_tween.tween_method(_set_clear_effect_progress, 0.0, 1.0, duration)
	_clear_effect_tween.finished.connect(func() -> void:
		_clear_effect_tween = null
		clear_action.call()
		_hide_clear_effect_overlay()
	, CONNECT_ONE_SHOT)
	return true


func _ensure_clear_effect_overlay() -> void:
	if _clear_effect_overlay != null and is_instance_valid(_clear_effect_overlay):
		return
	if host == null or host._viewport_layer == null:
		return
	_clear_effect_overlay = TextureRect.new()
	_clear_effect_overlay.name = "ClearEffectOverlay"
	_clear_effect_overlay.visible = false
	_clear_effect_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_effect_overlay.stretch_mode = TextureRect.STRETCH_SCALE
	_clear_effect_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_clear_effect_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = CLEAR_DISSOLVE_SHADER
	_clear_effect_material.shader = shader
	_clear_effect_overlay.material = _clear_effect_material
	host._viewport_layer.add_child(_clear_effect_overlay)
	if host.settings_panel != null:
		host._viewport_layer.move_child(_clear_effect_overlay, host.settings_panel.get_index())


func _set_clear_effect_progress(value: float) -> void:
	if _clear_effect_material == null:
		return
	_clear_effect_material.set_shader_parameter("progress", value)


func _hide_clear_effect_overlay() -> void:
	if _clear_effect_overlay == null:
		return
	_clear_effect_overlay.visible = false
	_clear_effect_overlay.texture = null


func _effective_clear_animation_duration(base_duration: float) -> float:
	if host == null or base_duration <= 0.0:
		return 0.0
	var speed := 1.0
	if host.animate_pan_zoom_slider != null:
		speed = clampf(host.animate_pan_zoom_slider.value, 1.0, 3.0)
	if speed >= 3.0:
		return 0.0
	var t := inverse_lerp(1.0, 3.0, speed)
	return lerpf(base_duration * 1.5, 0.0, t)


func apply_topbar_button_font_size() -> void:
	if host == null:
		return
	var topbar_font_size := clampi(host._ui_font_size + 6, host.MIN_UI_FONT_SIZE, host.MAX_UI_FONT_SIZE + 6)
	var topbar_button_size := Vector2(topbar_font_size + 14, topbar_font_size + 14)
	var topbar_buttons := [
		host.settings_toggle_button,
		host.comparison_button,
		host.comparison_save_button,
		host.comparison_clear_button,
		host.search_button,
		host.go_button,
		host.screenshot_button,
		host.download_button,
		host.jump_start_button,
		host.jump_end_button,
		host.pan_left_button,
		host.pan_right_button,
		host.zoom_out_button,
		host.zoom_in_button,
		host.play_left_button,
		host.stop_button,
		host.play_button,
	]
	for b_any in topbar_buttons:
		var b: Button = b_any
		b.add_theme_font_size_override("font_size", topbar_font_size)
		b.custom_minimum_size = topbar_button_size
	if host._settings_toggle_icon_label != null:
		host._settings_toggle_icon_label.add_theme_font_size_override("font_size", topbar_font_size)
		_update_settings_toggle_icon_pivot()
	if _comparison_toggle_icon_label != null:
		_comparison_toggle_icon_label.add_theme_font_size_override("font_size", topbar_font_size)
		_update_comparison_toggle_icon_pivot()
	if _comparison_clear_icon_label != null:
		_comparison_clear_icon_label.add_theme_font_size_override("font_size", topbar_font_size)
		_update_comparison_clear_icon_pivot()


func _active_view_has_data_to_clear() -> bool:
	if host._app_mode == host.APP_MODE_COMPARISON:
		return host._comparison_controller != null and host._comparison_controller.has_genomes()
	return host._has_sequence_loaded or not host._bam_tracks.is_empty()


func _spin_clear_button() -> void:
	if _comparison_clear_icon_label == null:
		return
	if _comparison_clear_tween != null and _comparison_clear_tween.is_running():
		_comparison_clear_tween.kill()
	_comparison_clear_tween = _spin_topbar_icon(_comparison_clear_icon_label, -360.0, 0.36, null)
	_comparison_clear_tween.finished.connect(func() -> void:
		_comparison_clear_tween = null
	, CONNECT_ONE_SHOT)


func _setup_settings_toggle_icon() -> void:
	if host.settings_toggle_button == null:
		return
	host.settings_toggle_button.clip_contents = true
	if host.top_bar != null:
		host.top_bar.clip_contents = true
	var icon_parts := _setup_topbar_icon_button(host.settings_toggle_button, "C")
	host._settings_toggle_icon_label = icon_parts.get("label")
	host.call_deferred("_update_settings_toggle_icon_pivot")


func _setup_comparison_toggle_icon() -> void:
	if host.comparison_button == null:
		return
	var icon_parts := _setup_topbar_icon_button(host.comparison_button, "M")
	_comparison_toggle_icon_label = icon_parts.get("label")
	host.call_deferred("_update_comparison_toggle_icon_pivot")
	host.call_deferred("_apply_comparison_toggle_icon_state", false)


func _setup_comparison_clear_icon() -> void:
	if host.comparison_clear_button == null:
		return
	var icon_parts := _setup_topbar_icon_button(host.comparison_clear_button, "N")
	_comparison_clear_icon_label = icon_parts.get("label")
	host.call_deferred("_update_comparison_clear_icon_pivot")


func _update_settings_toggle_icon_pivot() -> void:
	_update_topbar_icon_pivot(host._settings_toggle_icon_label)


func _update_comparison_toggle_icon_pivot() -> void:
	_update_topbar_icon_pivot(_comparison_toggle_icon_label)


func _update_comparison_clear_icon_pivot() -> void:
	_update_topbar_icon_pivot(_comparison_clear_icon_label)


func _setup_topbar_icon_button(button: Button, glyph: String) -> Dictionary:
	button.text = ""
	button.clip_contents = true
	var icon_container := button.get_node_or_null("IconContainer") as CenterContainer
	if icon_container == null:
		icon_container = CenterContainer.new()
		icon_container.name = "IconContainer"
		icon_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(icon_container)
	var icon_label := icon_container.get_node_or_null("IconLabel") as Label
	if icon_label == null:
		icon_label = Label.new()
		icon_label.name = "IconLabel"
		icon_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_container.add_child(icon_label)
	icon_label.text = glyph
	if button.has_theme_font_override("font"):
		icon_label.add_theme_font_override("font", button.get_theme_font("font"))
	if button.has_theme_font_size_override("font_size"):
		icon_label.add_theme_font_size_override("font_size", button.get_theme_font_size("font_size"))
	return {"container": icon_container, "label": icon_label}


func _update_topbar_icon_pivot(icon_label: Label) -> void:
	if icon_label == null:
		return
	var icon_size := icon_label.get_combined_minimum_size()
	icon_label.pivot_offset = icon_size * 0.5


func _spin_topbar_icon(icon_label: Label, delta_degrees: float, duration: float, tween: Tween) -> Tween:
	if icon_label == null:
		return tween
	_update_topbar_icon_pivot(icon_label)
	var next_tween := tween
	if next_tween == null:
		next_tween = host.create_tween()
		next_tween.set_trans(Tween.TRANS_CUBIC)
		next_tween.set_ease(Tween.EASE_OUT)
	next_tween.parallel().tween_property(icon_label, "rotation_degrees", icon_label.rotation_degrees + delta_degrees, duration)
	return next_tween


func _apply_comparison_toggle_icon_state(animated: bool) -> void:
	if _comparison_toggle_icon_label == null:
		return
	var in_comparison: bool = host._app_mode == host.APP_MODE_COMPARISON
	var target_rotation := 0.0
	var target_scale := Vector2(-1.0, -1.0) if in_comparison else Vector2.ONE
	if _comparison_toggle_tween != null and _comparison_toggle_tween.is_running():
		_comparison_toggle_tween.kill()
	_update_comparison_toggle_icon_pivot()
	if animated:
		_comparison_toggle_tween = host.create_tween()
		_comparison_toggle_tween.set_trans(Tween.TRANS_CUBIC)
		_comparison_toggle_tween.set_ease(Tween.EASE_OUT)
		_comparison_toggle_tween.parallel().tween_property(_comparison_toggle_icon_label, "rotation_degrees", target_rotation, 0.36)
		_comparison_toggle_tween.parallel().tween_property(_comparison_toggle_icon_label, "scale", target_scale, 0.36)
		_comparison_toggle_tween.finished.connect(func() -> void:
			_comparison_toggle_tween = null
		, CONNECT_ONE_SHOT)
	else:
		_comparison_toggle_icon_label.rotation_degrees = target_rotation
		_comparison_toggle_icon_label.scale = target_scale


func _apply_view_mode_visibility(previous_mode: int, next_mode: int) -> void:
	var browser_view: Control = host.genome_view
	var compare_view: Control = host.comparison_view
	if browser_view == null or compare_view == null:
		return
	var comparison_active: bool = next_mode == host.APP_MODE_COMPARISON
	var target_view: Control = compare_view if comparison_active else browser_view
	var source_view: Control = browser_view if comparison_active else compare_view
	target_view.mouse_filter = Control.MOUSE_FILTER_PASS
	source_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if previous_mode == next_mode or not source_view.visible:
		if _view_mode_tween != null and _view_mode_tween.is_running():
			_view_mode_tween.kill()
			_view_mode_tween = null
		source_view.visible = false
		source_view.modulate.a = 1.0
		target_view.visible = true
		target_view.modulate.a = 1.0
		return
	if _view_mode_tween != null and _view_mode_tween.is_running():
		_view_mode_tween.kill()
	target_view.visible = true
	source_view.visible = true
	target_view.modulate.a = 0.0
	source_view.modulate.a = 1.0
	_view_mode_tween = host.create_tween()
	_view_mode_tween.set_trans(Tween.TRANS_CUBIC)
	_view_mode_tween.set_ease(Tween.EASE_OUT)
	_view_mode_tween.parallel().tween_property(target_view, "modulate:a", 1.0, 0.18)
	_view_mode_tween.parallel().tween_property(source_view, "modulate:a", 0.0, 0.18)
	_view_mode_tween.finished.connect(func() -> void:
		source_view.visible = false
		source_view.modulate.a = 1.0
		target_view.modulate.a = 1.0
		_view_mode_tween = null
	, CONNECT_ONE_SHOT)
