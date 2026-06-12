extends RefCounted
class_name VimModeController

const VimCommandParserScript = preload("res://scripts/vim_command_parser.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")

const VIM_MARK_LETTERS := "abcdefghijklmnopqrstuvwxyz"
const VIM_MARK_ACTION_SAVE := "save"
const VIM_MARK_ACTION_LOAD := "load"
const VIM_COMMAND_PREFIX_COMMAND := ":"
const VIM_COMMAND_PREFIX_SEARCH := "/"
const VIM_COLON_COMMANDS := ["go", "colorscheme", "q", "quit"]

var host: Node = null
var mode_cb: CheckButton = null
var command_bar: PanelContainer = null
var command_prefix: Label = null
var command_edit: LineEdit = null

var _enabled := false
var _command_active := false
var _command_prefix_text := VIM_COMMAND_PREFIX_COMMAND
var _pending_mark_action := ""
var _completion_matches := PackedStringArray()
var _completion_index := -1


func setup(next_host: Node, next_mode_cb: CheckButton, next_command_bar: PanelContainer, next_command_prefix: Label, next_command_edit: LineEdit) -> void:
	host = next_host
	mode_cb = next_mode_cb
	command_bar = next_command_bar
	command_prefix = next_command_prefix
	command_edit = next_command_edit
	_command_active = false
	_command_prefix_text = VIM_COMMAND_PREFIX_COMMAND
	if command_prefix != null:
		command_prefix.text = ""
	if command_edit != null:
		command_edit.text = ""
		command_edit.editable = false
		command_edit.focus_mode = Control.FOCUS_NONE
		if not command_edit.text_submitted.is_connected(_on_command_submitted):
			command_edit.text_submitted.connect(_on_command_submitted)
		if not command_edit.focus_exited.is_connected(_on_command_focus_exited):
			command_edit.focus_exited.connect(_on_command_focus_exited)
		if not command_edit.gui_input.is_connected(_on_command_edit_gui_input):
			command_edit.gui_input.connect(_on_command_edit_gui_input)
	if mode_cb != null and not mode_cb.toggled.is_connected(_on_mode_toggled):
		mode_cb.toggled.connect(_on_mode_toggled)
	sync_command_bar()


func is_enabled() -> bool:
	return _enabled


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if mode_cb != null and mode_cb.button_pressed != enabled:
		mode_cb.set_pressed_no_signal(enabled)
	if not enabled:
		_command_active = false
		_command_prefix_text = VIM_COMMAND_PREFIX_COMMAND
		_pending_mark_action = ""
		if command_edit != null:
			command_edit.text = ""
			if command_edit.has_focus():
				command_edit.release_focus()
	sync_command_bar()
	if host != null:
		host._update_window_min_height()


func sync_command_bar() -> void:
	if command_bar != null:
		command_bar.visible = _enabled
	if command_prefix != null:
		command_prefix.text = _command_prefix_text if _command_active else ""
	if command_edit != null:
		command_edit.editable = _command_active
		command_edit.focus_mode = Control.FOCUS_ALL if _command_active else Control.FOCUS_NONE
		if _command_active:
			command_edit.grab_focus()
			command_edit.caret_column = command_edit.text.length()
		elif command_edit.has_focus():
			command_edit.release_focus()


func show_message(message: String) -> void:
	if not _enabled or _command_active:
		return
	if command_prefix != null:
		command_prefix.text = ""
	if command_edit != null:
		command_edit.text = message


func apply_theme(palette: Dictionary) -> void:
	if command_prefix != null:
		command_prefix.add_theme_color_override("font_color", palette["text"])
	if command_edit == null:
		return
	var text_color: Color = palette["text"]
	command_edit.add_theme_color_override("font_color", text_color)
	command_edit.add_theme_color_override("font_uneditable_color", text_color)
	command_edit.add_theme_color_override("font_placeholder_color", text_color)
	command_edit.add_theme_color_override("caret_color", text_color)


func handle_escape(event: InputEvent) -> bool:
	if not _command_active:
		return false
	if not _is_escape_key_event(event):
		return false
	_finish_command()
	return true


func handle_input(event: InputEvent) -> bool:
	if not _enabled:
		return false
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return false
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		_pending_mark_action = ""
		return false
	if _command_active or _is_text_entry_focused():
		_pending_mark_action = ""
		return false
	if _handle_mark_target(key_event):
		return true
	if event.is_action_pressed("seqhiker_vim_command"):
		_begin_command(VIM_COMMAND_PREFIX_COMMAND)
		return true
	if event.is_action_pressed("seqhiker_vim_search"):
		_begin_command(VIM_COMMAND_PREFIX_SEARCH)
		return true
	if event.is_action_pressed("seqhiker_vim_mark_save"):
		_begin_mark_action(VIM_MARK_ACTION_SAVE)
		return true
	if event.is_action_pressed("seqhiker_vim_mark_load"):
		_begin_mark_action(VIM_MARK_ACTION_LOAD)
		return true
	if key_event.shift_pressed:
		return false
	if event.is_action_pressed("seqhiker_vim_scroll_left"):
		host._scroll_left_by_step()
		return true
	if event.is_action_pressed("seqhiker_vim_scroll_right"):
		host._scroll_right_by_step()
		return true
	if event.is_action_pressed("seqhiker_vim_zoom_out"):
		host._zoom_out_by_step()
		return true
	if event.is_action_pressed("seqhiker_vim_zoom_in"):
		host._zoom_in_by_step()
		return true
	return false


func _begin_command(prefix_text: String = VIM_COMMAND_PREFIX_COMMAND) -> void:
	if not _enabled or command_edit == null:
		return
	_pending_mark_action = ""
	_reset_completion()
	_command_prefix_text = prefix_text
	_command_active = true
	command_edit.text = ""
	sync_command_bar()


func _finish_command() -> void:
	_command_active = false
	_reset_completion()
	if command_edit != null:
		command_edit.text = ""
	sync_command_bar()


func _execute_command(command: String) -> void:
	var clean := command.strip_edges()
	if clean.is_empty():
		return
	var lower := clean.to_lower()
	if lower == "go" or lower.begins_with("go "):
		_execute_go_command(clean)
	elif lower == VimCommandParserScript.COMMAND_COLORSCHEME or lower.begins_with("%s " % VimCommandParserScript.COMMAND_COLORSCHEME):
		_execute_colorscheme_command(clean)
	elif lower == "q" or lower == "quit":
		_execute_quit_command()


func _execute_colorscheme_command(command: String) -> void:
	var parsed := VimCommandParserScript.parse_colorscheme(command)
	if not bool(parsed.get("ok", false)):
		_show_bar_error(str(parsed.get("error", "usage: colorscheme <theme>")))
		return
	var theme_name := _theme_name_for_input(str(parsed.get("theme", "")))
	if theme_name.is_empty():
		_show_bar_error("unknown theme: %s" % str(parsed.get("theme", "")))
		return
	host._apply_classic_font_defaults_for_theme(theme_name)
	host._select_theme_option(theme_name)
	host._apply_theme(theme_name)
	host._save_config()
	host._set_status("Theme: %s" % theme_name)
	show_message("colorscheme %s" % theme_name)


func _execute_quit_command() -> void:
	if host == null or host.get_tree() == null:
		return
	host.get_tree().quit()


func _show_bar_error(message: String) -> void:
	host._set_status(message, true)
	show_message(message)


func _theme_name_for_input(theme_name: String) -> String:
	var clean := theme_name.strip_edges()
	if clean.is_empty() or host._themes_lib == null:
		return ""
	var lower := clean.to_lower()
	for name in host._themes_lib.theme_names():
		if str(name) == clean:
			return str(name)
	for name in host._themes_lib.theme_names():
		if str(name).to_lower() == lower:
			return str(name)
	return ""


func _execute_search(command: String) -> void:
	if host._app_mode != host.APP_MODE_BROWSER:
		_show_search_error("search is only available in browser view")
		return
	if host._search_controller == null or not host._search_controller.has_method("run_browser_search"):
		_show_search_error("search unavailable")
		return
	if host._chromosomes.is_empty():
		_show_search_error("no sequences loaded")
		return
	var parsed := VimCommandParserScript.parse_search(command, _sequence_names())
	if not bool(parsed.get("ok", false)):
		_show_search_error(str(parsed.get("error", "usage: /annotation [sequence] query")))
		return
	var target := str(parsed.get("target", ""))
	var mode := SearchControllerScript.SEARCH_MODE_ANNOTATION
	if target == VimCommandParserScript.SEARCH_TARGET_DNA:
		mode = SearchControllerScript.SEARCH_MODE_DNA_EXACT
	var sequence_name := str(parsed.get("sequence", ""))
	var query := str(parsed.get("query", "")).strip_edges()
	var chr_filter := PackedInt32Array()
	var scope_label := "All sequences"
	if sequence_name.is_empty():
		for chr_any in host._chromosomes:
			var chromosome: Dictionary = chr_any
			var chr_id := int(chromosome.get("id", -1))
			if chr_id >= 0:
				chr_filter.append(chr_id)
	else:
		var chromosome := _chromosome_for_go_name(sequence_name)
		if chromosome.is_empty():
			_show_search_error("unknown sequence: %s" % sequence_name)
			return
		var chr_id := int(chromosome.get("id", -1))
		if chr_id < 0:
			_show_search_error("sequence unavailable")
			return
		chr_filter.append(chr_id)
		scope_label = str(chromosome.get("name", sequence_name))
	if chr_filter.is_empty():
		_show_search_error("no sequences loaded")
		return
	if not _show_search_panel():
		_show_search_error("search unavailable")
		return
	host._search_controller.run_browser_search(mode, query, chr_filter, scope_label)


func _show_search_error(message: String) -> void:
	host._set_status(message, true)
	show_message(message)


func _show_search_panel() -> bool:
	if host._theme_editor_controller != null and host._theme_editor_controller.is_open():
		return false
	if host._context_panel_controller == null or host._search_controller == null:
		return false
	host._context_panel_controller.prepare_context_panel(host.CONTEXT_PANEL_SEARCH, "Search", false)
	host._search_controller.show_panel()
	host._feature_panel_open = true
	host._slide_feature_panel(true, true)
	return true


func _sequence_names() -> PackedStringArray:
	var out := PackedStringArray()
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		var seq_name := str(chromosome.get("name", "")).strip_edges()
		if not seq_name.is_empty() and out.find(seq_name) < 0:
			out.append(seq_name)
	return out


func _execute_go_command(command: String) -> void:
	if host._app_mode != host.APP_MODE_BROWSER:
		_show_go_error("go is only available in browser view")
		return
	if host._chromosomes.is_empty():
		_show_go_error("no sequences loaded")
		return
	var args := command.substr(2).strip_edges()
	if args.is_empty():
		_show_go_error("usage: go [sequence] start[-end]")
		return
	var target_seq_name := ""
	var range_text := args
	var parsed_range := VimCommandParserScript.parse_go_range(range_text)
	if parsed_range.is_empty():
		var split := VimCommandParserScript.split_go_colon_sequence_and_range(args)
		if split.is_empty():
			split = VimCommandParserScript.split_go_sequence_and_range(args)
		if split.is_empty():
			_show_go_error("usage: go [sequence] start[-end]")
			return
		target_seq_name = str(split.get("sequence", ""))
		range_text = str(split.get("range", ""))
		parsed_range = VimCommandParserScript.parse_go_range(range_text)
		if parsed_range.is_empty():
			_show_go_error("enter a valid position or range")
			return
	var chromosome := _current_go_chromosome() if target_seq_name.is_empty() else _chromosome_for_go_name(target_seq_name)
	if chromosome.is_empty():
		_show_go_error("unknown sequence: %s" % target_seq_name)
		return
	var chr_len := int(chromosome.get("length", 0))
	if chr_len <= 0:
		_show_go_error("sequence length unavailable")
		return
	var start_display := int(parsed_range.get("start", -1))
	var end_display := int(parsed_range.get("end", -1))
	if start_display > chr_len:
		_show_go_error("start position beyond sequence length")
		return
	if end_display >= 0 and end_display > chr_len:
		end_display = chr_len
	var chr_id := int(chromosome.get("id", -1))
	if chr_id < 0:
		_show_go_error("sequence unavailable")
		return
	host._go_on_browser_request(chr_id, start_display, end_display)
	var chr_name := str(chromosome.get("name", "chr"))
	var message := "%s:%d" % [chr_name, start_display]
	if end_display >= 0:
		message = "%s:%d-%d" % [chr_name, start_display, end_display]
	host._set_status(message)
	show_message("jumped to %s" % message)


func _show_go_error(message: String) -> void:
	host._set_status(message, true)
	show_message(message)


func _current_go_chromosome() -> Dictionary:
	var target_id: int = int(host._go_get_browser_target_chr_id())
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		if int(chromosome.get("id", -1)) == target_id:
			return chromosome
	if not host._chromosomes.is_empty():
		return host._chromosomes[0]
	return {}


func _chromosome_for_go_name(seq_name: String) -> Dictionary:
	var target := seq_name.strip_edges().to_lower()
	if target.is_empty():
		return {}
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		if str(chromosome.get("name", "")).strip_edges().to_lower() == target:
			return chromosome
	return {}


func _reset_completion() -> void:
	_completion_matches = PackedStringArray()
	_completion_index = -1


func _handle_command_completion(event: InputEvent) -> bool:
	if not _command_active or command_edit == null:
		return false
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.keycode != KEY_TAB:
		return false
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return true
	var context := _command_completion_context()
	if context.is_empty():
		return true
	var token := str(context.get("token", ""))
	var matches := _completion_matches if _completion_matches.find(token) >= 0 else _completion_matches_for_context(context, token)
	if matches.is_empty():
		_reset_completion()
		return true
	if _completion_matches != matches:
		_completion_matches = matches
		_completion_index = -1
	_completion_index = (_completion_index + 1) % _completion_matches.size()
	var replacement := _completion_matches[_completion_index]
	var head := str(context.get("head", ""))
	var tail := str(context.get("tail", ""))
	command_edit.text = head + replacement + tail
	command_edit.caret_column = head.length() + replacement.length()
	return true


func _command_completion_context() -> Dictionary:
	if _command_prefix_text == VIM_COMMAND_PREFIX_SEARCH:
		return _search_completion_context()
	var command_context := _colon_command_completion_context()
	if not command_context.is_empty():
		return command_context
	var theme_context := _colorscheme_completion_context()
	if not theme_context.is_empty():
		return theme_context
	return _go_completion_context()


func _completion_matches_for_context(context: Dictionary, prefix: String) -> PackedStringArray:
	match str(context.get("kind", "")):
		"command":
			return _colon_command_completion_matches(prefix)
		"theme":
			return _theme_completion_matches(prefix)
		_:
			return _contig_completion_matches(prefix)


func _colon_command_completion_context() -> Dictionary:
	var text := command_edit.text
	var caret := clampi(command_edit.caret_column, 0, text.length())
	var before := text.substr(0, caret)
	var after := text.substr(caret)
	var token_tail_len := 0
	while token_tail_len < after.length():
		if after.unicode_at(token_tail_len) <= 32:
			break
		token_tail_len += 1
	var token_tail := after.substr(0, token_tail_len)
	var tail := after.substr(token_tail_len)
	var token := before + token_tail
	if token.find(" ") >= 0 or token.find("\t") >= 0:
		return {}
	return {"kind": "command", "head": "", "token": token, "tail": tail}


func _go_completion_context() -> Dictionary:
	if host._app_mode != host.APP_MODE_BROWSER:
		return {}
	var text := command_edit.text
	var caret := clampi(command_edit.caret_column, 0, text.length())
	var before := text.substr(0, caret)
	var after := text.substr(caret)
	if not before.to_lower().begins_with("go "):
		return {}
	var token_before := before.substr(3)
	if token_before.find(" ") >= 0 or token_before.find("\t") >= 0:
		return {}
	var token_tail_len := 0
	while token_tail_len < after.length():
		if after.unicode_at(token_tail_len) <= 32:
			break
		token_tail_len += 1
	var token_tail := after.substr(0, token_tail_len)
	var tail := after.substr(token_tail_len)
	var token := token_before + token_tail
	if not VimCommandParserScript.parse_go_range(token).is_empty():
		return {}
	var range_sep := token.rfind(":")
	if range_sep >= 0 and not VimCommandParserScript.parse_go_range(token.substr(range_sep + 1)).is_empty():
		return {}
	return {"kind": "contig", "head": "go ", "token": token, "tail": tail}


func _colorscheme_completion_context() -> Dictionary:
	var command := VimCommandParserScript.COMMAND_COLORSCHEME
	var text := command_edit.text
	var caret := clampi(command_edit.caret_column, 0, text.length())
	var before := text.substr(0, caret)
	var after := text.substr(caret)
	var lower_before := before.to_lower()
	if lower_before == command:
		return {"kind": "theme", "head": "%s " % command, "token": after, "tail": ""}
	if not lower_before.begins_with("%s " % command):
		return {}
	var token := before.substr(command.length() + 1) + after
	return {"kind": "theme", "head": before.substr(0, command.length() + 1), "token": token, "tail": ""}


func _search_completion_context() -> Dictionary:
	if host._app_mode != host.APP_MODE_BROWSER:
		return {}
	var text := command_edit.text
	var caret := clampi(command_edit.caret_column, 0, text.length())
	var before := text.substr(0, caret)
	var after := text.substr(caret)
	var mode_sep := VimCommandParserScript.first_whitespace_index(before)
	if mode_sep < 0:
		return {}
	var target := VimCommandParserScript.search_target_from_token(before.substr(0, mode_sep))
	if target.is_empty():
		return {}
	var token_before := before.substr(mode_sep + 1)
	if token_before.find(" ") >= 0 or token_before.find("\t") >= 0:
		return {}
	var token_tail_len := 0
	while token_tail_len < after.length():
		if after.unicode_at(token_tail_len) <= 32:
			break
		token_tail_len += 1
	var token_tail := after.substr(0, token_tail_len)
	var tail := after.substr(token_tail_len)
	var token := token_before + token_tail
	return {"kind": "contig", "head": before.substr(0, mode_sep + 1), "token": token, "tail": tail}


func _colon_command_completion_matches(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lower_prefix := prefix.to_lower()
	for command_any in VIM_COLON_COMMANDS:
		var command := str(command_any)
		if not lower_prefix.is_empty() and not command.begins_with(lower_prefix):
			continue
		if out.find(command) < 0:
			out.append(command)
	return out


func _contig_completion_matches(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lower_prefix := prefix.to_lower()
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		var seq_name := str(chromosome.get("name", "")).strip_edges()
		if seq_name.is_empty():
			continue
		if not lower_prefix.is_empty() and not seq_name.to_lower().begins_with(lower_prefix):
			continue
		if out.find(seq_name) < 0:
			out.append(seq_name)
	return out


func _theme_completion_matches(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	if host._themes_lib == null:
		return out
	var lower_prefix := prefix.to_lower()
	for theme_name_any in host._themes_lib.theme_names():
		var theme_name := str(theme_name_any).strip_edges()
		if theme_name.is_empty():
			continue
		if not lower_prefix.is_empty() and not theme_name.to_lower().begins_with(lower_prefix):
			continue
		if out.find(theme_name) < 0:
			out.append(theme_name)
	return out


func _on_command_submitted(command: String) -> void:
	var prefix_text := _command_prefix_text
	_finish_command()
	if prefix_text == VIM_COMMAND_PREFIX_SEARCH:
		_execute_search(command)
	else:
		_execute_command(command)


func _on_command_edit_gui_input(event: InputEvent) -> void:
	if handle_escape(event):
		command_edit.accept_event()
		return
	if _handle_command_completion(event):
		command_edit.accept_event()


func _on_command_focus_exited() -> void:
	if _command_active:
		_finish_command()


func _on_mode_toggled(enabled: bool) -> void:
	host._play_toggle_sound(enabled)
	set_enabled(enabled)


func _is_escape_key_event(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	return key_event.pressed and (key_event.keycode == KEY_ESCAPE or event.is_action_pressed("seqhiker_close_right_panel"))


func _begin_mark_action(action: String) -> void:
	_pending_mark_action = action


func _handle_mark_target(key_event: InputEventKey) -> bool:
	if _pending_mark_action.is_empty():
		return false
	var mark_letter := _mark_letter_from_event(key_event)
	if mark_letter.is_empty():
		_pending_mark_action = ""
		return false
	var action := _pending_mark_action
	_pending_mark_action = ""
	if action == VIM_MARK_ACTION_SAVE:
		host._save_view_mark(mark_letter)
	else:
		host._load_view_mark(mark_letter)
	return true


func _mark_letter_from_event(key_event: InputEventKey) -> String:
	if key_event.keycode >= KEY_A and key_event.keycode <= KEY_Z:
		return VIM_MARK_LETTERS.substr(key_event.keycode - KEY_A, 1)
	var typed_code := key_event.unicode
	if typed_code >= 65 and typed_code <= 90:
		return VIM_MARK_LETTERS.substr(typed_code - 65, 1)
	if typed_code >= 97 and typed_code <= 122:
		return VIM_MARK_LETTERS.substr(typed_code - 97, 1)
	return ""


func _is_text_entry_focused() -> bool:
	if host == null:
		return false
	var focus_owner := host.get_viewport().gui_get_focus_owner()
	return (focus_owner is LineEdit) or (focus_owner is TextEdit)
