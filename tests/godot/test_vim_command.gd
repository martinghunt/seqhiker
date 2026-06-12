extends "res://tests/godot/test_case.gd"

const VimCommandParserScript = preload("res://scripts/vim_command_parser.gd")
const VimModeControllerScript = preload("res://scripts/vim_mode_controller.gd")
const SearchControllerScript = preload("res://scripts/search_controller.gd")

var _selected_search_hits: Array[Dictionary] = []
var _selected_search_positions: Array[Dictionary] = []


class FakeVimHost:
	extends Node

	const APP_MODE_BROWSER := 0
	const SEQ_VIEW_CONCAT := 0

	var _app_mode := APP_MODE_BROWSER
	var _seq_view_mode := SEQ_VIEW_CONCAT
	var _last_start := 0
	var _last_end := 50
	var _chromosomes: Array[Dictionary] = [
		{"id": 1, "name": "ctg1", "length": 1000},
		{"id": 2, "name": "ctg2", "length": 1000},
		{"id": 3, "name": "ctg3", "length": 1000}
	]
	var _concat_segments: Array[Dictionary] = [
		{"id": 1, "name": "ctg1", "start": 0, "end": 1000},
		{"id": 2, "name": "ctg2", "start": 1050, "end": 2050},
		{"id": 3, "name": "ctg3", "start": 2100, "end": 3100}
	]
	var go_requests: Array[Dictionary] = []
	var status_messages: Array[Dictionary] = []

	func _go_get_browser_target_chr_id() -> int:
		return 1

	func _go_on_browser_request(chr_id: int, start_display: int, end_display: int) -> void:
		go_requests.append({
			"chr_id": chr_id,
			"start": start_display,
			"end": end_display
		})

	func _set_status(message: String, is_error: bool = false) -> void:
		status_messages.append({"message": message, "is_error": is_error})


func test_vim_go_range_parser_accepts_points_and_ranges() -> void:
	assert_eq(VimCommandParserScript.parse_go_range("123"), {"start": 123, "end": -1})
	assert_eq(VimCommandParserScript.parse_go_range("1,234-5,678"), {"start": 1234, "end": 5678})
	assert_eq(VimCommandParserScript.parse_go_range("200-100"), {"start": 100, "end": 200})
	assert_true(VimCommandParserScript.parse_go_range("0").is_empty())
	assert_true(VimCommandParserScript.parse_go_range("abc").is_empty())


func test_vim_go_parser_supports_last_colon_sequence_ranges() -> void:
	var split := VimCommandParserScript.split_go_colon_sequence_and_range("chr1:100-200")
	assert_eq(split, {"sequence": "chr1", "range": "100-200"})

	split = VimCommandParserScript.split_go_colon_sequence_and_range("sample:chr1:42")
	assert_eq(split, {"sequence": "sample:chr1", "range": "42"})

	assert_true(VimCommandParserScript.split_go_colon_sequence_and_range("chr1:abc").is_empty())


func test_vim_go_parser_keeps_space_fallback_for_colon_names() -> void:
	var split := VimCommandParserScript.split_go_sequence_and_range("sample:chr1 100-200")
	assert_eq(split, {"sequence": "sample:chr1", "range": "100-200"})


func test_vim_colorscheme_parser_accepts_standard_command() -> void:
	var parsed := VimCommandParserScript.parse_colorscheme("colorscheme Solarized Dark")
	assert_eq(parsed, {
		"ok": true,
		"theme": "Solarized Dark"
	})


func test_vim_colorscheme_parser_rejects_set_theme_alias() -> void:
	var parsed := VimCommandParserScript.parse_colorscheme("set theme=Slate")
	assert_false(bool(parsed.get("ok", false)))


func test_vim_colon_completion_includes_quit_commands() -> void:
	var controller := VimModeControllerScript.new()
	assert_eq(controller._colon_command_completion_matches("q"), PackedStringArray(["q", "quit"]))


func test_vim_count_helpers_consume_and_clear_feedback() -> void:
	var edit := LineEdit.new()
	var controller := VimModeControllerScript.new()
	controller.command_edit = edit
	controller._count_prefix = "12"
	edit.text = "12"

	assert_eq(controller._command_count(), 12)
	assert_eq(controller._consume_count(), 12)
	assert_eq(controller._count_prefix, "")
	assert_eq(edit.text, "")
	assert_eq(controller._consume_count(), 1)
	edit.free()


func test_vim_command_history_cycles_per_prompt_prefix() -> void:
	var edit := LineEdit.new()
	var controller := VimModeControllerScript.new()
	controller.command_edit = edit
	controller._record_command_history(":", "go ctg1:100")
	controller._record_command_history(":", "colorscheme Classic")
	controller._record_command_history("/", "dna ACGT")

	controller._command_active = true
	controller._command_prefix_text = ":"
	edit.text = "draft"
	assert_true(controller._handle_command_history(_vim_key(KEY_UP)))
	assert_eq(edit.text, "colorscheme Classic")
	assert_true(controller._handle_command_history(_vim_key(KEY_UP)))
	assert_eq(edit.text, "go ctg1:100")
	assert_true(controller._handle_command_history(_vim_key(KEY_UP)))
	assert_eq(edit.text, "go ctg1:100")
	assert_true(controller._handle_command_history(_vim_key(KEY_DOWN)))
	assert_eq(edit.text, "colorscheme Classic")
	assert_true(controller._handle_command_history(_vim_key(KEY_DOWN)))
	assert_eq(edit.text, "draft")

	controller._command_prefix_text = "/"
	edit.text = ""
	assert_true(controller._handle_command_history(_vim_key(KEY_UP)))
	assert_eq(edit.text, "dna ACGT")
	edit.free()


func test_vim_command_history_ignores_empty_dedupes_and_caps() -> void:
	var controller := VimModeControllerScript.new()
	controller._record_command_history(":", "")
	assert_eq(controller._colon_history.size(), 0)
	controller._record_command_history(":", "go 1")
	controller._record_command_history(":", "go 1")
	assert_eq(controller._colon_history, ["go 1"])

	for i in range(105):
		controller._record_command_history(":", "go %d" % i)
	assert_eq(controller._colon_history.size(), 100)
	assert_eq(controller._colon_history[0], "go 5")
	assert_eq(controller._colon_history[-1], "go 104")


func test_vim_key_matching_distinguishes_c_and_shift_c() -> void:
	var key_event := InputEventKey.new()
	key_event.pressed = true
	key_event.keycode = KEY_C
	key_event.shift_pressed = false
	assert_true(VimModeControllerScript._matches_key(key_event, KEY_C))
	assert_false(VimModeControllerScript._matches_key(key_event, KEY_C, true))

	key_event.shift_pressed = true
	assert_false(VimModeControllerScript._matches_key(key_event, KEY_C))
	assert_true(VimModeControllerScript._matches_key(key_event, KEY_C, true))

	var unicode_upper_event := InputEventKey.new()
	unicode_upper_event.pressed = true
	unicode_upper_event.keycode = KEY_NONE
	unicode_upper_event.shift_pressed = false
	unicode_upper_event.unicode = 67
	assert_false(VimModeControllerScript._matches_key(unicode_upper_event, KEY_C))
	assert_true(VimModeControllerScript._matches_key(unicode_upper_event, KEY_C, true))

	var keycode_upper_event := InputEventKey.new()
	keycode_upper_event.pressed = true
	keycode_upper_event.keycode = KEY_C
	keycode_upper_event.shift_pressed = false
	keycode_upper_event.unicode = 67
	assert_false(VimModeControllerScript._matches_key(keycode_upper_event, KEY_C))
	assert_true(VimModeControllerScript._matches_key(keycode_upper_event, KEY_C, true))


func test_vim_counted_gg_jumps_to_counted_position() -> void:
	var host := FakeVimHost.new()
	var edit := LineEdit.new()
	var controller := VimModeControllerScript.new()
	controller.host = host
	controller.command_edit = edit
	controller._enabled = true

	assert_true(controller.handle_input(_vim_key(KEY_5, false, 53)))
	assert_true(controller.handle_input(_vim_key(KEY_0, false, 48)))
	assert_true(controller.handle_input(_vim_key(KEY_0, false, 48)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_eq(host.go_requests[-1], {"chr_id": 1, "start": 500, "end": -1})
	assert_eq(edit.text, "jumped to ctg1:500")
	edit.free()
	host.free()


func test_vim_contig_navigation_repeats_without_viewport_update_and_supports_shift_c() -> void:
	var host := FakeVimHost.new()
	var edit := LineEdit.new()
	var controller := VimModeControllerScript.new()
	controller.host = host
	controller.command_edit = edit
	controller._enabled = true

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 99)))
	assert_eq(host.go_requests[-1], {"chr_id": 2, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 99)))
	assert_eq(host.go_requests[-1], {"chr_id": 3, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, true, 67)))
	assert_eq(host.go_requests[-1], {"chr_id": 2, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 67)))
	assert_eq(host.go_requests[-1], {"chr_id": 1, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 99)))
	assert_eq(host.go_requests[-1], {"chr_id": 2, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_SHIFT, true, 0)))
	assert_true(controller.handle_input(_vim_key(KEY_C, true, 67)))
	assert_eq(host.go_requests[-1], {"chr_id": 1, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 99)))
	assert_eq(host.go_requests[-1], {"chr_id": 2, "start": 1, "end": -1})

	assert_true(controller.handle_input(_vim_key(KEY_5, false, 53)))
	assert_true(controller.handle_input(_vim_key(KEY_0, false, 48)))
	assert_true(controller.handle_input(_vim_key(KEY_0, false, 48)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_eq(host.go_requests[-1], {"chr_id": 2, "start": 500, "end": -1})
	assert_eq(edit.text, "jumped to ctg2:500")

	assert_true(controller.handle_input(_vim_key(KEY_9, false, 57)))
	assert_true(controller.handle_input(_vim_key(KEY_9, false, 57)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, false, 99)))
	assert_eq(host.go_requests[-1], {"chr_id": 3, "start": 1, "end": -1})
	assert_eq(edit.text, "last contig")
	assert_eq(host.status_messages[-1], {"message": "Last contig.", "is_error": false})

	assert_true(controller.handle_input(_vim_key(KEY_9, false, 57)))
	assert_true(controller.handle_input(_vim_key(KEY_9, false, 57)))
	assert_true(controller.handle_input(_vim_key(KEY_G, false, 103)))
	assert_true(controller.handle_input(_vim_key(KEY_C, true, 67)))
	assert_eq(host.go_requests[-1], {"chr_id": 1, "start": 1, "end": -1})
	assert_eq(edit.text, "first contig")
	assert_eq(host.status_messages[-1], {"message": "First contig.", "is_error": false})
	edit.free()
	host.free()


func test_vim_contig_navigation_helpers_respect_order_and_boundaries() -> void:
	var contigs: Array[Dictionary] = [
		{"id": 10, "name": "a", "start": 0, "end": 100},
		{"id": 20, "name": "b", "start": 150, "end": 250},
		{"id": 30, "name": "c", "start": 300, "end": 400}
	]
	assert_eq(VimModeControllerScript._contig_index_for_chr_id(contigs, 20), 1)
	assert_eq(VimModeControllerScript._contig_index_for_chr_id(contigs, 99), -1)
	assert_eq(VimModeControllerScript._contig_index_for_display_position(contigs, 175), 1)
	assert_eq(VimModeControllerScript._contig_index_for_display_position(contigs, 275), 1)
	assert_eq(VimModeControllerScript._contig_at_relative_index(contigs, 0, 2), {"id": 30, "name": "c", "start": 300, "end": 400})
	assert_eq(VimModeControllerScript._contig_at_relative_index(contigs, 1, 1), {"id": 30, "name": "c", "start": 300, "end": 400})
	assert_eq(VimModeControllerScript._contig_at_relative_index(contigs, 1, -1), {"id": 10, "name": "a", "start": 0, "end": 100})
	assert_true(VimModeControllerScript._contig_at_relative_index(contigs, 0, -1).is_empty())
	assert_true(VimModeControllerScript._contig_at_relative_index(contigs, 2, 1).is_empty())


func test_vim_search_result_step_wraps_and_selects_hits() -> void:
	_selected_search_hits.clear()
	_selected_search_positions.clear()
	var results := ItemList.new()
	results.add_item("hit 1")
	results.add_item("hit 2")
	var controller := SearchControllerScript.new()
	controller._callbacks = {
		"on_hit_selected": Callable(self, "_record_selected_search_hit"),
		"on_hit_position_changed": Callable(self, "_record_selected_search_position")
	}
	controller._search_results_list = results
	controller._search_hits = [
		{"label": "hit 1"},
		{"label": "hit 2"}
	]

	var stepped := controller.step_result(1)
	assert_eq(stepped, {"ok": true, "index": 0, "count": 2})
	assert_eq(_selected_search_hits[-1], {"label": "hit 1"})
	assert_eq(_selected_search_positions[-1], {"index": 0, "count": 2})

	stepped = controller.step_result(1)
	assert_eq(stepped, {"ok": true, "index": 1, "count": 2})
	assert_eq(_selected_search_hits[-1], {"label": "hit 2"})
	assert_eq(_selected_search_positions[-1], {"index": 1, "count": 2})

	stepped = controller.step_result(1)
	assert_eq(stepped, {"ok": true, "index": 0, "count": 2})
	assert_eq(_selected_search_hits[-1], {"label": "hit 1"})
	assert_eq(_selected_search_positions[-1], {"index": 0, "count": 2})

	stepped = controller.step_result(-1)
	assert_eq(stepped, {"ok": true, "index": 1, "count": 2})
	assert_eq(_selected_search_hits[-1], {"label": "hit 2"})
	assert_eq(_selected_search_positions[-1], {"index": 1, "count": 2})
	results.free()


func test_vim_search_parser_accepts_annotation_and_dna_prefixes() -> void:
	var parsed := VimCommandParserScript.parse_search("a gene1")
	assert_eq(parsed, {
		"ok": true,
		"target": "annotation",
		"sequence": "",
		"query": "gene1"
	})

	parsed = VimCommandParserScript.parse_search("dn ACGT")
	assert_eq(parsed, {
		"ok": true,
		"target": "dna",
		"sequence": "",
		"query": "ACGT"
	})


func test_vim_search_parser_infers_bare_dna_query() -> void:
	var parsed := VimCommandParserScript.parse_search("ACGT")
	assert_eq(parsed, {
		"ok": true,
		"target": "dna",
		"sequence": "",
		"query": "ACGT"
	})

	parsed = VimCommandParserScript.parse_search("acgt")
	assert_eq(parsed, {
		"ok": true,
		"target": "dna",
		"sequence": "",
		"query": "acgt"
	})


func test_vim_search_parser_does_not_infer_non_dna_single_token() -> void:
	var parsed := VimCommandParserScript.parse_search("gene1")
	assert_false(bool(parsed.get("ok", false)))


func test_vim_search_parser_detects_optional_sequence_name() -> void:
	var sequence_names := PackedStringArray(["contig1", "contig2"])
	var parsed := VimCommandParserScript.parse_search("annot contig2 foo bar", sequence_names)
	assert_eq(parsed, {
		"ok": true,
		"target": "annotation",
		"sequence": "contig2",
		"query": "foo bar"
	})


func test_vim_search_parser_keeps_non_sequence_prefix_in_query() -> void:
	var sequence_names := PackedStringArray(["contig1"])
	var parsed := VimCommandParserScript.parse_search("an missing foo", sequence_names)
	assert_eq(parsed, {
		"ok": true,
		"target": "annotation",
		"sequence": "",
		"query": "missing foo"
	})


func _record_selected_search_hit(hit: Dictionary) -> void:
	_selected_search_hits.append(hit.duplicate(true))


func _record_selected_search_position(index: int, count: int) -> void:
	_selected_search_positions.append({"index": index, "count": count})


func _vim_key(keycode: Key, shift_pressed: bool = false, unicode: int = 0) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.shift_pressed = shift_pressed
	event.unicode = unicode
	return event
