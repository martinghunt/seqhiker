extends "res://tests/godot/test_case.gd"

const VimCommandParserScript = preload("res://scripts/vim_command_parser.gd")
const VimModeControllerScript = preload("res://scripts/vim_mode_controller.gd")


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
