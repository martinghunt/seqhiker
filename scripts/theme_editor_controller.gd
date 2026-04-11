extends RefCounted
class_name ThemeEditorController

var host: Node = null
var themes_lib: RefCounted = null

var _open := false
var _theme_name := ""
var _palette: Dictionary = {}
var _open_palette_snapshot: Dictionary = {}
var _undo_stack: Array[Dictionary] = []
var _role_pickers := {}

var _title_label: Label = null
var _action_clipper: Control = null
var _close_button: Button = null
var _preview: Control = null
var _feature_custom_content: VBoxContainer = null
var _open_button: Button = null
var _name_edit: LineEdit = null
var _rename_button: Button = null
var _duplicate_button: Button = null
var _undo_button: Button = null
var _reset_button: Button = null
var _delete_button: Button = null
var _export_button: Button = null
var _import_button: Button = null
var _hint_label: Label = null
var _role_buttons := {}
var _export_dialog: FileDialog = null
var _import_dialog: FileDialog = null


func configure(next_host: Node, next_themes_lib: RefCounted) -> void:
	host = next_host
	themes_lib = next_themes_lib


func setup() -> void:
	if host == null:
		return
	_title_label = host.get_node_or_null("Root/TopBar/ThemeEditorTitle")
	_action_clipper = host.get_node_or_null("Root/TopBar/ActionClipper")
	_close_button = host.get_node_or_null("Root/TopBar/ThemeEditorCloseButton")
	_preview = host.get_node_or_null("Root/ContentMargin/ViewportLayer/ThemePreview")
	_feature_custom_content = host.get_node_or_null("Root/ContentMargin/ViewportLayer/FeaturePanel/FeatureMargin/FeatureLayout/FeatureScroll/FeaturePadding/FeatureContent/FeatureCustomContent")
	_open_button = host.get_node_or_null("Root/ContentMargin/ViewportLayer/SettingsPanel/SettingsMargin/SettingsLayout/SettingsScroll/SettingsPadding/SettingsContent/OpenThemeEditorButton")
	_setup_ui()
	_setup_theme_file_dialogs()
	if _open_button != null and not _open_button.pressed.is_connected(_on_open_pressed):
		_open_button.pressed.connect(_on_open_pressed)
	if _close_button != null and not _close_button.pressed.is_connected(close):
		_close_button.pressed.connect(close)


func is_open() -> bool:
	return _open


func focus_controls() -> Array:
	return [
		_open_button,
		_close_button,
		_rename_button,
		_duplicate_button,
		_undo_button,
		_reset_button,
		_export_button,
		_import_button,
		_delete_button
	]


func open_selected_theme_editor() -> void:
	if host == null or host.theme_option == null:
		return
	if host.theme_option.item_count == 0 or host.theme_option.selected < 0:
		return
	host._play_ui_sound("settings_toggle")
	open_for(host.theme_option.get_item_text(host.theme_option.selected))


func open_for(theme_name: String) -> void:
	if host == null or themes_lib == null:
		return
	var selected_name := theme_name
	if not themes_lib.is_user_theme(selected_name):
		selected_name = themes_lib.create_user_theme_from(selected_name)
		_refresh_theme_selector(selected_name)
		host._apply_theme(selected_name)
		host._save_config()
		host._set_status("Created editable theme: %s" % selected_name)
	_theme_name = selected_name
	_palette = themes_lib.palette(selected_name)
	_open_palette_snapshot = _palette.duplicate(true)
	_undo_stack.clear()
	_open = true
	if _name_edit != null:
		_name_edit.focus_mode = Control.FOCUS_ALL
	_set_feature_panel_theme_editor_mode(true)
	_set_theme_editor_topbar(true)
	_refresh_editor_controls()
	_refresh_preview_layout()
	host._apply_palette(_palette, _theme_name)
	host._refresh_main_view_visibility()
	host._settings_open = false
	host._slide_settings(false, true)
	host.feature_title_label.text = "Theme Editor"
	host.feature_close_button.tooltip_text = "Close theme editor"
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)


func close() -> void:
	if not _open or host == null:
		return
	_open = false
	_open_palette_snapshot.clear()
	_undo_stack.clear()
	_set_feature_panel_theme_editor_mode(false)
	_set_theme_editor_topbar(false)
	_reset_preview_layout()
	host.feature_title_label.text = "Feature Details"
	host.feature_close_button.tooltip_text = "Close panel"
	host._refresh_main_view_visibility()
	if host.theme_option != null and host.theme_option.item_count > 0 and host.theme_option.selected >= 0:
		host._apply_theme(host.theme_option.get_item_text(host.theme_option.selected))
	host._feature_panel_open = false
	host._slide_feature_panel(false, true)


func _setup_ui() -> void:
	if _feature_custom_content == null:
		return
	for child in _feature_custom_content.get_children():
		child.queue_free()
	var intro := Label.new()
	intro.text = "Theme editor changes are previewed immediately and saved to the selected user theme."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feature_custom_content.add_child(intro)
	_hint_label = intro

	var name_label := Label.new()
	name_label.text = "Theme Name"
	_feature_custom_content.add_child(name_label)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_feature_custom_content.add_child(name_row)

	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.focus_mode = Control.FOCUS_ALL
	name_row.add_child(_name_edit)

	_rename_button = Button.new()
	_rename_button.text = "Rename"
	name_row.add_child(_rename_button)

	var manage_row := HBoxContainer.new()
	manage_row.add_theme_constant_override("separation", 8)
	_feature_custom_content.add_child(manage_row)

	_duplicate_button = Button.new()
	_duplicate_button.text = "Duplicate"
	manage_row.add_child(_duplicate_button)

	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.disabled = true
	manage_row.add_child(_undo_button)

	_reset_button = Button.new()
	_reset_button.text = "Reset"
	manage_row.add_child(_reset_button)

	_delete_button = Button.new()
	_delete_button.text = "Delete"
	manage_row.add_child(_delete_button)

	var manage_sep := HSeparator.new()
	_feature_custom_content.add_child(manage_sep)

	var io_row := HBoxContainer.new()
	io_row.add_theme_constant_override("separation", 8)
	_feature_custom_content.add_child(io_row)

	_export_button = Button.new()
	_export_button.text = "Export"
	io_row.add_child(_export_button)

	_import_button = Button.new()
	_import_button.text = "Import"
	io_row.add_child(_import_button)

	var io_sep := HSeparator.new()
	_feature_custom_content.add_child(io_sep)

	var role_groups: Array = themes_lib.editor_role_groups() if themes_lib != null and themes_lib.has_method("editor_role_groups") else []
	_role_pickers.clear()
	_role_buttons.clear()
	for group_index in range(role_groups.size()):
		var group: Dictionary = role_groups[group_index] as Dictionary
		var group_label := Label.new()
		group_label.text = str(group.get("title", "Colours"))
		_feature_custom_content.add_child(group_label)
		for role_any in group.get("roles", []):
			var role: Dictionary = role_any as Dictionary
			var role_key := str(role.get("key", ""))
			if role_key.is_empty():
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			_feature_custom_content.add_child(row)
			var role_label := Button.new()
			role_label.text = str(role.get("label", role_key.replace("_", " ").capitalize()))
			role_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			role_label.flat = true
			role_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
			role_label.focus_mode = Control.FOCUS_NONE
			role_label.pressed.connect(_on_role_label_pressed.bind(role_key))
			row.add_child(role_label)
			var picker := ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(68.0, 30.0)
			picker.edit_alpha = false
			picker.color_changed.connect(_on_picker_changed.bind(role_key))
			row.add_child(picker)
			_role_pickers[role_key] = picker
			_role_buttons[role_key] = role_label
		if group_index < role_groups.size() - 1:
			var group_sep := HSeparator.new()
			_feature_custom_content.add_child(group_sep)

	if _name_edit != null and not _name_edit.text_submitted.is_connected(_on_name_submitted):
		_name_edit.text_submitted.connect(_on_name_submitted)
	if _rename_button != null and not _rename_button.pressed.is_connected(_on_rename_pressed):
		_rename_button.pressed.connect(_on_rename_pressed)
	if _duplicate_button != null and not _duplicate_button.pressed.is_connected(_on_duplicate_pressed):
		_duplicate_button.pressed.connect(_on_duplicate_pressed)
	if _undo_button != null and not _undo_button.pressed.is_connected(_on_undo_pressed):
		_undo_button.pressed.connect(_on_undo_pressed)
	if _reset_button != null and not _reset_button.pressed.is_connected(_on_reset_pressed):
		_reset_button.pressed.connect(_on_reset_pressed)
	if _delete_button != null and not _delete_button.pressed.is_connected(_on_delete_pressed):
		_delete_button.pressed.connect(_on_delete_pressed)
	if _export_button != null and not _export_button.pressed.is_connected(_on_export_pressed):
		_export_button.pressed.connect(_on_export_pressed)
	if _import_button != null and not _import_button.pressed.is_connected(_on_import_pressed):
		_import_button.pressed.connect(_on_import_pressed)


func _setup_theme_file_dialogs() -> void:
	if host == null:
		return
	if _export_dialog == null:
		_export_dialog = FileDialog.new()
	_export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	_export_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_export_dialog.use_native_dialog = true
	_export_dialog.title = "Export Theme JSON"
	_export_dialog.filters = PackedStringArray(["*.json ; JSON theme files"])
	_export_dialog.file_selected.connect(_on_export_file_selected)
	host.add_child(_export_dialog)
	if _import_dialog == null:
		_import_dialog = FileDialog.new()
		_import_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		_import_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_import_dialog.use_native_dialog = true
		_import_dialog.title = "Import Theme JSON"
		_import_dialog.filters = PackedStringArray(["*.json ; JSON theme files"])
		_import_dialog.file_selected.connect(_on_import_file_selected)
		host.add_child(_import_dialog)


func _set_feature_panel_theme_editor_mode(enabled: bool) -> void:
	if _feature_custom_content != null:
		_feature_custom_content.visible = enabled
	for node in [host.feature_name_label, host.feature_type_label, host.feature_range_label, host.feature_strand_label, host.feature_source_label, host.feature_seq_label]:
		if node != null:
			node.visible = not enabled


func _set_theme_editor_topbar(enabled: bool) -> void:
	if host.settings_toggle_button != null:
		host.settings_toggle_button.visible = not enabled
	if _action_clipper != null:
		_action_clipper.visible = not enabled
	if _title_label != null:
		_title_label.visible = enabled
		_title_label.text = "Theme Editor" if _theme_name.is_empty() else "Theme Editor: %s" % _theme_name
	if _close_button != null:
		_close_button.visible = enabled


func _refresh_editor_controls() -> void:
	if _name_edit != null:
		_name_edit.focus_mode = Control.FOCUS_ALL
		_name_edit.text = _theme_name
	if _hint_label != null:
		_hint_label.text = "Editing user theme \"%s\". Changes are saved immediately." % _theme_name
	for role_key in _role_pickers.keys():
		var picker: ColorPickerButton = _role_pickers[role_key]
		if picker == null:
			continue
		picker.set_block_signals(true)
		picker.color = _color_for_role(str(role_key))
		picker.set_block_signals(false)
	if _title_label != null and _title_label.visible:
		_title_label.text = "Theme Editor: %s" % _theme_name
	_refresh_undo_button()


func _persist_palette() -> void:
	if not _open or _theme_name.is_empty():
		return
	themes_lib.upsert_user_theme(_theme_name, _palette)
	_refresh_theme_selector(_theme_name)
	host._apply_palette(_palette, _theme_name)
	host._save_config()


func _refresh_undo_button() -> void:
	if _undo_button != null:
		_undo_button.disabled = _undo_stack.is_empty()


func _push_undo_snapshot() -> void:
	_undo_stack.append(_palette.duplicate(true))
	_refresh_undo_button()


func _refresh_theme_selector(selected_name: String = "") -> void:
	if host.theme_option == null:
		return
	var chosen := selected_name
	if chosen.is_empty() and host.theme_option.item_count > 0 and host.theme_option.selected >= 0:
		chosen = host.theme_option.get_item_text(host.theme_option.selected)
	host.theme_option.clear()
	for theme_name in themes_lib.theme_names():
		host.theme_option.add_item(theme_name)
	host._select_theme_option(chosen if not chosen.is_empty() else "Slate")

func _color_for_role(role_key: String) -> Color:
	match role_key:
		"pileup_base_a":
			return (_palette.get("pileup_logo_bases", {}) as Dictionary).get("A", Color.WHITE)
		"pileup_base_c":
			return (_palette.get("pileup_logo_bases", {}) as Dictionary).get("C", Color.WHITE)
		"pileup_base_g":
			return (_palette.get("pileup_logo_bases", {}) as Dictionary).get("G", Color.WHITE)
		"pileup_base_t":
			return (_palette.get("pileup_logo_bases", {}) as Dictionary).get("T", Color.WHITE)
		"pileup_base_d":
			return (_palette.get("pileup_logo_bases", {}) as Dictionary).get("D", Color.WHITE)
		"depth_plot_series_0", "depth_plot_series_1", "depth_plot_series_2", "depth_plot_series_3", "depth_plot_series_4", "depth_plot_series_5":
			var series: Array = _palette.get("depth_plot_series", [])
			var idx := int(role_key.get_slice("_", 3))
			if idx >= 0 and idx < series.size() and series[idx] is Color:
				return series[idx]
			return _palette.get("depth_plot", Color.WHITE)
		_:
			return _palette.get(role_key, Color.WHITE)


func _set_color_for_role(role_key: String, color: Color) -> void:
	match role_key:
		"pileup_base_a", "pileup_base_c", "pileup_base_g", "pileup_base_t", "pileup_base_d":
			var pileup_bases: Dictionary = (_palette.get("pileup_logo_bases", {}) as Dictionary).duplicate(true)
			var base_key := "A"
			if role_key == "pileup_base_c":
				base_key = "C"
			elif role_key == "pileup_base_g":
				base_key = "G"
			elif role_key == "pileup_base_t":
				base_key = "T"
			elif role_key == "pileup_base_d":
				base_key = "D"
			pileup_bases[base_key] = color
			_palette["pileup_logo_bases"] = pileup_bases
		"depth_plot_series_0", "depth_plot_series_1", "depth_plot_series_2", "depth_plot_series_3", "depth_plot_series_4", "depth_plot_series_5":
			var series: Array = (_palette.get("depth_plot_series", []) as Array).duplicate(true)
			var idx := int(role_key.get_slice("_", 3))
			while series.size() <= idx:
				series.append(_palette.get("depth_plot", Color.WHITE))
			series[idx] = color
			_palette["depth_plot_series"] = series
		_:
			_palette[role_key] = color


func refresh_layout() -> void:
	if not _open:
		return
	_refresh_preview_layout()


func _refresh_preview_layout() -> void:
	if _preview == null or host == null:
		return
	var reserved_w: float = host._feature_panel_target_width() + 12.0
	_preview.offset_left = 0.0
	_preview.offset_top = 0.0
	_preview.offset_right = -reserved_w
	_preview.offset_bottom = 0.0


func _reset_preview_layout() -> void:
	if _preview == null:
		return
	_preview.offset_left = 0.0
	_preview.offset_top = 0.0
	_preview.offset_right = 0.0
	_preview.offset_bottom = 0.0


func _on_open_pressed() -> void:
	open_selected_theme_editor()


func _on_role_label_pressed(role_key: String) -> void:
	if _preview != null and _preview.has_method("flash_role"):
		_preview.flash_role(role_key)


func _on_picker_changed(color: Color, role_key: String) -> void:
	if not _open:
		return
	if _color_for_role(role_key) == color:
		return
	_push_undo_snapshot()
	_set_color_for_role(role_key, color)
	_persist_palette()


func _on_name_submitted(_text: String) -> void:
	_on_rename_pressed()


func _on_rename_pressed() -> void:
	if not _open or _name_edit == null:
		return
	var next_name: String = themes_lib.rename_user_theme(_theme_name, _name_edit.text)
	if next_name.is_empty():
		return
	_theme_name = next_name
	_palette = themes_lib.palette(next_name)
	_undo_stack.clear()
	_refresh_theme_selector(next_name)
	_refresh_editor_controls()
	host._apply_palette(_palette, next_name)
	host._save_config()


func _on_duplicate_pressed() -> void:
	if not _open:
		return
	var next_name: String = themes_lib.create_user_theme_from(_theme_name)
	_theme_name = next_name
	_palette = themes_lib.palette(next_name)
	_open_palette_snapshot = _palette.duplicate(true)
	_undo_stack.clear()
	_refresh_theme_selector(next_name)
	_refresh_editor_controls()
	host._apply_palette(_palette, next_name)
	host._save_config()


func _on_reset_pressed() -> void:
	if not _open:
		return
	_palette = _open_palette_snapshot.duplicate(true)
	_undo_stack.clear()
	_persist_palette()
	_refresh_editor_controls()


func _on_undo_pressed() -> void:
	if not _open or _undo_stack.is_empty():
		return
	_palette = _undo_stack.pop_back()
	_persist_palette()
	_refresh_editor_controls()


func _on_delete_pressed() -> void:
	if not _open:
		return
	var remaining_user_themes: PackedStringArray = themes_lib.user_theme_names()
	if remaining_user_themes.size() <= 1 and remaining_user_themes.has(_theme_name):
		host._set_status("Cannot delete the only user theme while editor is open.", true)
		return
	var deleted_name := _theme_name
	themes_lib.delete_user_theme(deleted_name)
	var fallback_name := "Slate"
	for theme_name in themes_lib.theme_names():
		if themes_lib.is_user_theme(theme_name):
			fallback_name = theme_name
			break
	_refresh_theme_selector(fallback_name)
	host._apply_theme(fallback_name)
	host._save_config()
	host._set_status("Deleted theme: %s" % deleted_name)
	if themes_lib.is_user_theme(fallback_name):
		open_for(fallback_name)


func _on_export_pressed() -> void:
	if not _open or themes_lib == null or _export_dialog == null:
		return
	_export_dialog.current_file = "%s.json" % _theme_name
	_export_dialog.current_dir = OS.get_environment("HOME")
	_export_dialog.popup_centered_ratio(0.8)


func _on_import_pressed() -> void:
	if not _open or themes_lib == null or _import_dialog == null:
		return
	_import_dialog.current_dir = OS.get_environment("HOME")
	_import_dialog.popup_centered_ratio(0.8)


func _on_export_file_selected(path: String) -> void:
	if not _open or themes_lib == null:
		return
	if themes_lib.export_theme_json_file(_theme_name, path):
		host._set_status("Exported theme JSON: %s" % path.get_file())
	else:
		host._set_status("Could not export theme JSON.", true)


func _on_import_file_selected(path: String) -> void:
	if not _open or themes_lib == null:
		return
	var imported_name: String = themes_lib.import_user_theme_from_json_file(path)
	if imported_name.is_empty():
		host._set_status("Could not import theme JSON.", true)
		return
	_theme_name = imported_name
	_palette = themes_lib.palette(imported_name)
	_open_palette_snapshot = _palette.duplicate(true)
	_undo_stack.clear()
	_refresh_theme_selector(imported_name)
	_refresh_editor_controls()
	host._apply_palette(_palette, imported_name)
	host._save_config()
	host._set_status("Imported theme JSON: %s" % imported_name)
