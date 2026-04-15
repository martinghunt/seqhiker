extends Control
class_name ThemePreviewSection

@export var section_key := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_THEME_CHANGED:
		queue_redraw()


func _draw() -> void:
	var preview := _find_preview()
	if preview == null:
		return
	var role_regions := {}
	preview.draw_preview_section(self, section_key, Rect2(Vector2.ZERO, size), role_regions)
	preview.draw_flash_overlay_on(self, role_regions)


func _find_preview() -> ThemePreview:
	var node := get_parent()
	while node != null:
		if node is ThemePreview:
			return node as ThemePreview
		node = node.get_parent()
	return null
