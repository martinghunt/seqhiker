extends RefCounted
class_name VimModeController

const VimCommandParserScript = preload("res://scripts/vim_command_parser.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")

const VIM_MARK_LETTERS := "abcdefghijklmnopqrstuvwxyz"
const VIM_MARK_ACTION_SAVE := "save"
const VIM_MARK_ACTION_LOAD := "load"
const VIM_COMMAND_PREFIX_COMMAND := ":"
const VIM_COMMAND_PREFIX_SEARCH := "/"
const VIM_COLON_COMMANDS := ["go", "colorscheme", "q", "quit", "view"]
const VIM_VIEW_TARGETS := ["comparison", "single"]
const VIM_COMMAND_HISTORY_LIMIT := 100

var host: Node = null
var mode_cb: CheckButton = null
var command_bar: PanelContainer = null
var command_prefix: Label = null
var command_edit: LineEdit = null

var _enabled := false
var _command_active := false
var _command_prefix_text := VIM_COMMAND_PREFIX_COMMAND
var _pending_mark_action := ""
var _pending_go_start := false
var _pending_bracket_contig_delta := 0
var _pending_quit := false
var _count_prefix := ""
var _contig_navigation_anchor_chr_id := -1
var _contig_navigation_anchor_view_start := -1
var _contig_navigation_anchor_view_end := -1
var _completion_matches := PackedStringArray()
var _completion_index := -1
var _colon_history: Array[String] = []
var _search_history: Array[String] = []
var _history_index := -1
var _history_draft := ""
var _applying_history := false


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
		if not command_edit.text_changed.is_connected(_on_command_text_changed):
			command_edit.text_changed.connect(_on_command_text_changed)
	if mode_cb != null and not mode_cb.toggled.is_connected(_on_mode_toggled):
		mode_cb.toggled.connect(_on_mode_toggled)
	sync_command_bar()


func is_enabled() -> bool:
	return _enabled


func is_command_active() -> bool:
	return _command_active


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if mode_cb != null and mode_cb.button_pressed != enabled:
		mode_cb.set_pressed_no_signal(enabled)
	if not enabled:
		_command_active = false
		_command_prefix_text = VIM_COMMAND_PREFIX_COMMAND
		_pending_mark_action = ""
		_pending_go_start = false
		_pending_bracket_contig_delta = 0
		_pending_quit = false
		_count_prefix = ""
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


func _show_pending_count() -> void:
	if _count_prefix.is_empty() or command_edit == null:
		return
	if command_prefix != null:
		command_prefix.text = ""
	command_edit.text = _count_prefix


func _clear_pending_state(clear_count: bool = true) -> void:
	_pending_mark_action = ""
	_pending_go_start = false
	_pending_bracket_contig_delta = 0
	_pending_quit = false
	if clear_count:
		_clear_count_prefix()


func _clear_count_prefix() -> void:
	var old_prefix := _count_prefix
	_count_prefix = ""
	if command_edit != null and not old_prefix.is_empty() and command_edit.text == old_prefix:
		command_edit.text = ""


func _has_pending_state() -> bool:
	return _pending_go_start or _pending_bracket_contig_delta != 0 or _pending_quit or not _pending_mark_action.is_empty() or not _count_prefix.is_empty()


static func _is_shift_modifier_event(key_event: InputEventKey) -> bool:
	return key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT or key_event.key_label == KEY_SHIFT


func _command_count(default_value: int = 1) -> int:
	if _count_prefix.is_empty():
		return default_value
	return maxi(1, int(_count_prefix))


func _consume_count(default_value: int = 1) -> int:
	var count := _command_count(default_value)
	_clear_count_prefix()
	return count


func _handle_count_prefix(key_event: InputEventKey) -> bool:
	if _pending_go_start or _pending_bracket_contig_delta != 0 or _pending_quit or not _pending_mark_action.is_empty():
		return false
	if key_event.shift_pressed:
		return false
	var digit := _digit_from_event(key_event)
	if digit < 0:
		return false
	if digit == 0 and _count_prefix.is_empty():
		return false
	if _count_prefix.length() >= 9:
		return true
	_count_prefix += str(digit)
	_show_pending_count()
	return true


func _digit_from_event(key_event: InputEventKey) -> int:
	var typed_code := key_event.unicode
	if typed_code >= 48 and typed_code <= 57:
		return typed_code - 48
	if key_event.keycode >= KEY_0 and key_event.keycode <= KEY_9:
		return key_event.keycode - KEY_0
	return -1


static func _matches_key(key_event: InputEventKey, keycode: Key, shift_pressed: bool = false) -> bool:
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return false
	var expected_unicode := _unicode_for_key(keycode, shift_pressed)
	if expected_unicode > 0 and _is_ascii_letter_unicode(key_event.unicode):
		return key_event.unicode == expected_unicode
	var key_matches := key_event.keycode == keycode or key_event.physical_keycode == keycode or key_event.key_label == keycode
	return key_matches and key_event.shift_pressed == shift_pressed


static func _is_ascii_letter_unicode(unicode_value: int) -> bool:
	return (unicode_value >= 65 and unicode_value <= 90) or (unicode_value >= 97 and unicode_value <= 122)


static func _unicode_for_key(keycode: Key, shift_pressed: bool) -> int:
	if keycode < KEY_A or keycode > KEY_Z:
		return 0
	return (65 if shift_pressed else 97) + int(keycode - KEY_A)


func show_search_hit_position(index: int, count: int) -> void:
	if count <= 0 or index < 0:
		return
	var message := "search hit %d/%d" % [index + 1, count]
	host._set_status(message)
	show_message(message)


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
	if _is_shift_modifier_event(key_event):
		return _has_pending_state()
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		_clear_pending_state()
		return false
	if _command_active or _is_text_entry_focused():
		_clear_pending_state()
		return false
	if _handle_mark_target(key_event):
		return true
	if _handle_pending_go_start(key_event):
		return true
	if _handle_pending_bracket_contig(key_event):
		return true
	if _handle_pending_quit(key_event):
		return true
	if _handle_count_prefix(key_event):
		return true
	if event.is_action_pressed("seqhiker_vim_command"):
		_begin_command(VIM_COMMAND_PREFIX_COMMAND)
		return true
	if event.is_action_pressed("seqhiker_vim_search"):
		_begin_command(VIM_COMMAND_PREFIX_SEARCH)
		return true
	if _matches_key(key_event, KEY_M):
		_begin_mark_action(VIM_MARK_ACTION_SAVE)
		return true
	if event.is_action_pressed("seqhiker_vim_mark_load"):
		_begin_mark_action(VIM_MARK_ACTION_LOAD)
		return true
	if _matches_key(key_event, KEY_N, true):
		_clear_contig_navigation_anchor()
		_step_search_result(-_consume_count())
		return true
	if _matches_key(key_event, KEY_N):
		_clear_contig_navigation_anchor()
		_step_search_result(_consume_count())
		return true
	if _matches_key(key_event, KEY_G, true):
		_jump_current_sequence_boundary(true)
		return true
	if _matches_key(key_event, KEY_G):
		_begin_go_start_action()
		return true
	if _matches_key(key_event, KEY_Z, true):
		_begin_quit_action()
		return true
	if event.is_action_pressed("seqhiker_vim_contig_next_prefix"):
		_begin_bracket_contig_action(1)
		return true
	if event.is_action_pressed("seqhiker_vim_contig_previous_prefix"):
		_begin_bracket_contig_action(-1)
		return true
	if key_event.shift_pressed:
		_clear_pending_state()
		return false
	if _matches_key(key_event, KEY_H):
		_clear_contig_navigation_anchor()
		host._scroll_left_by_step(_consume_count())
		return true
	if _matches_key(key_event, KEY_L):
		_clear_contig_navigation_anchor()
		host._scroll_right_by_step(_consume_count())
		return true
	if _matches_key(key_event, KEY_J):
		_clear_pending_state()
		host._zoom_out_by_step()
		return true
	if _matches_key(key_event, KEY_K):
		_clear_pending_state()
		host._zoom_in_by_step()
		return true
	_clear_pending_state()
	return false


func _begin_command(prefix_text: String = VIM_COMMAND_PREFIX_COMMAND) -> void:
	if not _enabled or command_edit == null:
		return
	_clear_pending_state()
	_reset_completion()
	_reset_history_navigation()
	_command_prefix_text = prefix_text
	_command_active = true
	command_edit.text = ""
	sync_command_bar()


func _finish_command() -> void:
	_command_active = false
	_reset_completion()
	_reset_history_navigation()
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
	elif lower == "view" or lower.begins_with("view "):
		_execute_view_command(clean)
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
	if host == null:
		return
	if host.has_method("_quit_app"):
		host._quit_app()
	elif host.get_tree() != null:
		host.get_tree().quit()


func _execute_view_command(command: String) -> void:
	var args := command.substr(4).strip_edges().to_lower()
	if args.is_empty():
		_show_bar_error("usage: view single|comparison")
		return
	var next_mode := -1
	var status_message := ""
	if args == "comparison":
		next_mode = host.APP_MODE_COMPARISON
		status_message = "Comparison view"
	elif args == "single":
		next_mode = host.APP_MODE_BROWSER
		status_message = "Single genome view"
	else:
		_show_bar_error("usage: view single|comparison")
		return
	if not host._set_view_mode(next_mode):
		_show_bar_error("view switch unavailable")
		return
	host._set_status(status_message)
	show_message(status_message.to_lower())


func _toggle_view_mode() -> void:
	if not host._toggle_view_mode():
		_show_bar_error("view switch unavailable")
		return
	var message := "comparison view" if host._app_mode == host.APP_MODE_COMPARISON else "single genome view"
	var status_message := "Comparison view" if host._app_mode == host.APP_MODE_COMPARISON else "Single genome view"
	host._set_status(status_message)
	show_message(message)


func _step_search_result(delta: int) -> void:
	if host._search_controller == null or not host._search_controller.has_method("step_result"):
		_show_search_error("no search results")
		return
	var result: Dictionary = host._search_controller.step_result(delta)
	if not bool(result.get("ok", false)):
		_show_search_error(str(result.get("error", "no search results")))
		return
	show_search_hit_position(int(result.get("index", -1)), int(result.get("count", 0)))


func _jump_current_sequence_boundary(at_end: bool, position_override: int = -1) -> void:
	if host._app_mode != host.APP_MODE_BROWSER:
		_show_go_error("jump is only available in browser view")
		return
	if host._chromosomes.is_empty():
		_show_go_error("no sequences loaded")
		return
	var chromosome := _current_go_chromosome()
	if chromosome.is_empty():
		_show_go_error("sequence unavailable")
		return
	var chr_id := int(chromosome.get("id", -1))
	var chr_len := int(chromosome.get("length", 0))
	if chr_id < 0:
		_show_go_error("sequence unavailable")
		return
	if chr_len <= 0:
		_show_go_error("sequence length unavailable")
		return
	var display_pos := chr_len if at_end else 1
	if position_override > 0:
		display_pos = mini(position_override, chr_len)
	host._go_on_browser_request(chr_id, display_pos, -1)
	_set_contig_navigation_anchor(chr_id)
	var chr_name := str(chromosome.get("name", "chr"))
	var message := "%s:%d" % [chr_name, display_pos]
	_clear_pending_state()
	host._set_status(message)
	show_message("jumped to %s" % message)


func _jump_relative_contig(delta: int, count: int = 1) -> void:
	if host._app_mode != host.APP_MODE_BROWSER:
		_show_go_error("contig navigation is only available in browser view")
		return
	var contigs := _navigation_contigs()
	if contigs.is_empty():
		_show_go_error("no sequences loaded")
		return
	var current_index := _current_navigation_contig_index(contigs)
	if current_index < 0:
		_show_go_error("sequence unavailable")
		return
	var effective_delta := delta * maxi(1, count)
	var requested_index := current_index + effective_delta
	var target_index := clampi(requested_index, 0, contigs.size() - 1)
	var hit_boundary := target_index != requested_index
	var target: Dictionary = (contigs[target_index] as Dictionary).duplicate(true)
	var chr_id := int(target.get("id", -1))
	if chr_id < 0:
		_show_go_error("sequence unavailable")
		return
	host._go_on_browser_request(chr_id, 1, -1)
	_set_contig_navigation_anchor(chr_id)
	var chr_name := str(target.get("name", "chr"))
	var message := "%s:1" % chr_name
	_clear_pending_state()
	if hit_boundary:
		show_message("last contig" if effective_delta > 0 else "first contig")
		host._set_status("Last contig." if effective_delta > 0 else "First contig.")
	else:
		host._set_status(message)
		show_message("jumped to %s" % message)


func _navigation_contigs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT and not host._concat_segments.is_empty():
		for seg_any in host._concat_segments:
			var seg: Dictionary = seg_any
			out.append({
				"id": int(seg.get("id", -1)),
				"name": str(seg.get("name", "chr")),
				"start": int(seg.get("start", 0)),
				"end": int(seg.get("end", 0))
			})
		return out
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		out.append({
			"id": int(chromosome.get("id", -1)),
			"name": str(chromosome.get("name", "chr")),
			"start": 0,
			"end": int(chromosome.get("length", 0))
		})
	return out


func _current_navigation_contig_index(contigs: Array[Dictionary]) -> int:
	var anchor_index := _anchored_navigation_contig_index(contigs)
	if anchor_index >= 0:
		return anchor_index
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT and not host._concat_segments.is_empty():
		var center_bp := int(floor(0.5 * float(host._last_start + host._last_end)))
		return _contig_index_for_display_position(contigs, center_bp)
	return _contig_index_for_chr_id(contigs, int(host._go_get_browser_target_chr_id()))


func _set_contig_navigation_anchor(chr_id: int) -> void:
	_contig_navigation_anchor_chr_id = chr_id
	_contig_navigation_anchor_view_start = int(host._last_start)
	_contig_navigation_anchor_view_end = int(host._last_end)


func _clear_contig_navigation_anchor() -> void:
	_contig_navigation_anchor_chr_id = -1
	_contig_navigation_anchor_view_start = -1
	_contig_navigation_anchor_view_end = -1


func _anchored_navigation_contig_index(contigs: Array[Dictionary]) -> int:
	if _contig_navigation_anchor_chr_id < 0:
		return -1
	var anchor_index := _contig_index_for_chr_id(contigs, _contig_navigation_anchor_chr_id)
	if anchor_index < 0:
		_clear_contig_navigation_anchor()
		return -1
	if int(host._last_start) == _contig_navigation_anchor_view_start and int(host._last_end) == _contig_navigation_anchor_view_end:
		return anchor_index
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT and not host._concat_segments.is_empty():
		var center_bp := int(floor(0.5 * float(host._last_start + host._last_end)))
		var center_index := _contig_index_for_display_position(contigs, center_bp)
		if center_index == anchor_index:
			return anchor_index
		_clear_contig_navigation_anchor()
		return center_index
	return anchor_index


static func _contig_at_relative_index(contigs: Array[Dictionary], current_index: int, delta: int) -> Dictionary:
	var target_index := current_index + delta
	if target_index < 0 or target_index >= contigs.size():
		return {}
	return (contigs[target_index] as Dictionary).duplicate(true)


static func _contig_index_for_chr_id(contigs: Array[Dictionary], chr_id: int) -> int:
	for i in range(contigs.size()):
		var contig: Dictionary = contigs[i]
		if int(contig.get("id", -1)) == chr_id:
			return i
	return -1


static func _contig_index_for_display_position(contigs: Array[Dictionary], display_bp: int) -> int:
	if contigs.is_empty():
		return -1
	for i in range(contigs.size()):
		var contig: Dictionary = contigs[i]
		var start_bp := int(contig.get("start", 0))
		var end_bp := int(contig.get("end", start_bp))
		if display_bp >= start_bp and display_bp < end_bp:
			return i
		if display_bp < start_bp:
			return maxi(0, i - 1)
	return contigs.size() - 1


func _show_bar_error(message: String) -> void:
	_clear_pending_state()
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
	_clear_pending_state()
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
	_clear_pending_state()
	host._set_status(message, true)
	show_message(message)


func _current_go_chromosome() -> Dictionary:
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT and not host._concat_segments.is_empty():
		var contigs := _navigation_contigs()
		var current_index := _current_navigation_contig_index(contigs)
		if current_index >= 0 and current_index < contigs.size():
			var contig: Dictionary = contigs[current_index]
			var anchored_chromosome := _chromosome_for_id(int(contig.get("id", -1)))
			if not anchored_chromosome.is_empty():
				return anchored_chromosome
	var target_id: int = int(host._go_get_browser_target_chr_id())
	var target_chromosome := _chromosome_for_id(target_id)
	if not target_chromosome.is_empty():
		return target_chromosome
	if not host._chromosomes.is_empty():
		return host._chromosomes[0]
	return {}


func _chromosome_for_id(chr_id: int) -> Dictionary:
	for chr_any in host._chromosomes:
		var chromosome: Dictionary = chr_any
		if int(chromosome.get("id", -1)) == chr_id:
			return chromosome
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


func _reset_history_navigation() -> void:
	_history_index = -1
	_history_draft = ""


func _record_command_history(prefix_text: String, command: String) -> void:
	var clean := command.strip_edges()
	if clean.is_empty():
		return
	var history := _history_for_prefix(prefix_text)
	if not history.is_empty() and history[-1] == clean:
		_store_history_for_prefix(prefix_text, history)
		return
	history.append(clean)
	while history.size() > VIM_COMMAND_HISTORY_LIMIT:
		history.remove_at(0)
	_store_history_for_prefix(prefix_text, history)


func _history_for_prefix(prefix_text: String) -> Array[String]:
	if prefix_text == VIM_COMMAND_PREFIX_SEARCH:
		return _search_history.duplicate()
	return _colon_history.duplicate()


func _store_history_for_prefix(prefix_text: String, history: Array[String]) -> void:
	if prefix_text == VIM_COMMAND_PREFIX_SEARCH:
		_search_history = history
	else:
		_colon_history = history


func _handle_command_history(event: InputEvent) -> bool:
	if not _command_active or command_edit == null:
		return false
	if not (event is InputEventKey):
		return false
	var key_event := event as InputEventKey
	if not key_event.pressed:
		return false
	if key_event.alt_pressed or key_event.ctrl_pressed or key_event.meta_pressed:
		return false
	if key_event.keycode == KEY_UP or key_event.physical_keycode == KEY_UP or key_event.key_label == KEY_UP:
		_step_command_history(-1)
		return true
	if key_event.keycode == KEY_DOWN or key_event.physical_keycode == KEY_DOWN or key_event.key_label == KEY_DOWN:
		_step_command_history(1)
		return true
	return false


func _step_command_history(direction: int) -> void:
	var history := _history_for_prefix(_command_prefix_text)
	if history.is_empty():
		return
	if direction < 0:
		if _history_index < 0:
			_history_draft = command_edit.text
			_history_index = history.size() - 1
		else:
			_history_index = maxi(0, _history_index - 1)
	else:
		if _history_index < 0:
			return
		if _history_index >= history.size() - 1:
			_history_index = -1
			_apply_history_text(_history_draft)
			return
		_history_index += 1
	_apply_history_text(history[_history_index])


func _apply_history_text(text: String) -> void:
	_applying_history = true
	command_edit.text = text
	command_edit.caret_column = text.length()
	_applying_history = false
	_reset_completion()


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
	var view_context := _view_completion_context()
	if not view_context.is_empty():
		return view_context
	return _go_completion_context()


func _completion_matches_for_context(context: Dictionary, prefix: String) -> PackedStringArray:
	match str(context.get("kind", "")):
		"command":
			return _colon_command_completion_matches(prefix)
		"theme":
			return _theme_completion_matches(prefix)
		"view":
			return _view_completion_matches(prefix)
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


func _view_completion_context() -> Dictionary:
	var command := "view"
	var text := command_edit.text
	var caret := clampi(command_edit.caret_column, 0, text.length())
	var before := text.substr(0, caret)
	var after := text.substr(caret)
	var lower_before := before.to_lower()
	if lower_before == command:
		return {"kind": "view", "head": "%s " % command, "token": after, "tail": ""}
	if not lower_before.begins_with("%s " % command):
		return {}
	var token := before.substr(command.length() + 1) + after
	if token.find(" ") >= 0 or token.find("\t") >= 0:
		return {}
	return {"kind": "view", "head": before.substr(0, command.length() + 1), "token": token, "tail": ""}


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


func _view_completion_matches(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var lower_prefix := prefix.to_lower()
	for target_any in VIM_VIEW_TARGETS:
		var target := str(target_any)
		if not lower_prefix.is_empty() and not target.begins_with(lower_prefix):
			continue
		out.append(target)
	return out


func _on_command_submitted(command: String) -> void:
	var prefix_text := _command_prefix_text
	_record_command_history(prefix_text, command)
	_finish_command()
	if prefix_text == VIM_COMMAND_PREFIX_SEARCH:
		_execute_search(command)
	else:
		_execute_command(command)


func _on_command_edit_gui_input(event: InputEvent) -> void:
	if handle_escape(event):
		command_edit.accept_event()
		return
	if _handle_command_history(event):
		command_edit.accept_event()
		return
	if _handle_command_completion(event):
		command_edit.accept_event()


func _on_command_text_changed(_new_text: String) -> void:
	if _applying_history:
		return
	_reset_history_navigation()
	_reset_completion()


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
	_pending_go_start = false
	_pending_bracket_contig_delta = 0
	_pending_quit = false
	_count_prefix = ""


func _begin_go_start_action() -> void:
	_pending_go_start = true
	_pending_mark_action = ""
	_pending_bracket_contig_delta = 0
	_pending_quit = false


func _begin_bracket_contig_action(delta: int) -> void:
	_pending_bracket_contig_delta = delta
	_pending_go_start = false
	_pending_mark_action = ""
	_pending_quit = false


func _begin_quit_action() -> void:
	_pending_quit = true
	_pending_go_start = false
	_pending_bracket_contig_delta = 0
	_pending_mark_action = ""
	_clear_count_prefix()


func _handle_pending_go_start(key_event: InputEventKey) -> bool:
	if not _pending_go_start:
		return false
	_pending_go_start = false
	if _matches_key(key_event, KEY_G):
		var has_count := not _count_prefix.is_empty()
		var count := _consume_count()
		_jump_current_sequence_boundary(false, count if has_count else -1)
		return true
	if _matches_key(key_event, KEY_V):
		_clear_count_prefix()
		_toggle_view_mode()
		return true
	if key_event.is_action_pressed("seqhiker_vim_contig_previous") or _matches_key(key_event, KEY_C, true):
		_jump_relative_contig(-1, _consume_count())
		return true
	if key_event.is_action_pressed("seqhiker_vim_contig_next") or _matches_key(key_event, KEY_C):
		_jump_relative_contig(1, _consume_count())
		return true
	_clear_count_prefix()
	return false


func _handle_pending_bracket_contig(key_event: InputEventKey) -> bool:
	if _pending_bracket_contig_delta == 0:
		return false
	var delta := _pending_bracket_contig_delta
	_pending_bracket_contig_delta = 0
	if not _matches_key(key_event, KEY_C):
		_clear_count_prefix()
		return false
	_jump_relative_contig(delta, _consume_count())
	return true


func _handle_pending_quit(key_event: InputEventKey) -> bool:
	if not _pending_quit:
		return false
	_pending_quit = false
	if not _matches_key(key_event, KEY_Z, true):
		return false
	_execute_quit_command()
	return true


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
	var viewport := host.get_viewport()
	if viewport == null:
		return false
	var focus_owner := viewport.gui_get_focus_owner()
	return (focus_owner is LineEdit) or (focus_owner is TextEdit)
