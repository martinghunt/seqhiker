extends RefCounted

const SEARCH_TARGET_ANNOTATION := "annotation"
const SEARCH_TARGET_DNA := "dna"
const COMMAND_COLORSCHEME := "colorscheme"


static func split_go_colon_sequence_and_range(args: String) -> Dictionary:
	var clean := args.strip_edges()
	var colon_idx := clean.rfind(":")
	if colon_idx < 0:
		return {}
	var seq_name := clean.substr(0, colon_idx).strip_edges()
	var range_text := clean.substr(colon_idx + 1).strip_edges()
	if seq_name.is_empty() or range_text.is_empty():
		return {}
	if parse_go_range(range_text).is_empty():
		return {}
	return {"sequence": seq_name, "range": range_text}


static func split_go_sequence_and_range(args: String) -> Dictionary:
	var clean := args.strip_edges()
	var last_space := -1
	for i in range(clean.length() - 1, -1, -1):
		var code := clean.unicode_at(i)
		if code <= 32:
			last_space = i
			break
	if last_space < 0:
		return {}
	var seq_name := clean.substr(0, last_space).strip_edges()
	var range_text := clean.substr(last_space + 1).strip_edges()
	if seq_name.is_empty() or range_text.is_empty():
		return {}
	return {"sequence": seq_name, "range": range_text}


static func parse_go_range(text: String) -> Dictionary:
	var clean := text.strip_edges().replace(",", "").replace(" ", "")
	if clean.is_empty():
		return {}
	var dash_idx := clean.find("-")
	if dash_idx < 0:
		var point := parse_bp(clean)
		return {"start": point, "end": -1} if point >= 1 else {}
	if clean.find("-", dash_idx + 1) >= 0:
		return {}
	var start_text := clean.substr(0, dash_idx)
	var end_text := clean.substr(dash_idx + 1)
	var start_display := parse_bp(start_text)
	var end_display := parse_bp(end_text)
	if start_display < 1 or end_display < 1:
		return {}
	if end_display < start_display:
		var swap := start_display
		start_display = end_display
		end_display = swap
	return {"start": start_display, "end": end_display}


static func parse_bp(text: String) -> int:
	if text.is_empty() or not text.is_valid_int():
		return -1
	var value := int(text)
	return value if value >= 1 else -1


static func parse_search(text: String, sequence_names: PackedStringArray = PackedStringArray()) -> Dictionary:
	var clean := text.strip_edges()
	if clean.is_empty():
		return _search_error()
	var mode_sep := first_whitespace_index(clean)
	if mode_sep < 0:
		if is_dna_query(clean):
			return {
				"ok": true,
				"target": SEARCH_TARGET_DNA,
				"sequence": "",
				"query": clean
			}
		return _search_error("enter a search query")
	var target := search_target_from_token(clean.substr(0, mode_sep))
	if target.is_empty():
		return _search_error("search type must be annotation or dna")
	var rest := clean.substr(mode_sep + 1).strip_edges()
	if rest.is_empty():
		return _search_error("enter a search query")
	var sequence_name := sequence_name_at_start(rest, sequence_names)
	if sequence_name.is_empty():
		return {
			"ok": true,
			"target": target,
			"sequence": "",
			"query": rest
		}
	var query := rest.substr(sequence_name.length()).strip_edges()
	if query.is_empty():
		return _search_error("enter a search query")
	return {
		"ok": true,
		"target": target,
		"sequence": sequence_name,
		"query": query
	}


static func search_target_from_token(token: String) -> String:
	var clean := token.strip_edges().to_lower()
	if clean.is_empty():
		return ""
	var is_annotation := SEARCH_TARGET_ANNOTATION.begins_with(clean)
	var is_dna := SEARCH_TARGET_DNA.begins_with(clean)
	if is_annotation and not is_dna:
		return SEARCH_TARGET_ANNOTATION
	if is_dna and not is_annotation:
		return SEARCH_TARGET_DNA
	return ""


static func is_dna_query(text: String) -> bool:
	var clean := text.strip_edges()
	if clean.is_empty():
		return false
	for i in range(clean.length()):
		match clean.unicode_at(i):
			65, 67, 71, 84, 97, 99, 103, 116:
				continue
			_:
				return false
	return true


static func first_whitespace_index(text: String) -> int:
	for i in range(text.length()):
		if text.unicode_at(i) <= 32:
			return i
	return -1


static func sequence_name_at_start(text: String, sequence_names: PackedStringArray) -> String:
	var clean := text.strip_edges()
	var lower := clean.to_lower()
	var names: Array[String] = []
	for name_any in sequence_names:
		var name := str(name_any).strip_edges()
		if not name.is_empty():
			names.append(name)
	names.sort_custom(func(a: String, b: String) -> bool:
		return a.length() > b.length()
	)
	for name in names:
		var lower_name := name.to_lower()
		if lower == lower_name:
			return name
		if lower.length() <= lower_name.length():
			continue
		if not lower.begins_with(lower_name):
			continue
		if clean.unicode_at(lower_name.length()) <= 32:
			return name
	return ""


static func _search_error(message: String = "usage: /annotation [sequence] query") -> Dictionary:
	return {
		"ok": false,
		"error": message
	}


static func parse_colorscheme(text: String) -> Dictionary:
	var clean := text.strip_edges()
	if clean == COMMAND_COLORSCHEME:
		return _colorscheme_error("usage: colorscheme <theme>")
	if not clean.to_lower().begins_with("%s " % COMMAND_COLORSCHEME):
		return _colorscheme_error()
	var theme_name := clean.substr(COMMAND_COLORSCHEME.length()).strip_edges()
	if theme_name.is_empty():
		return _colorscheme_error("usage: colorscheme <theme>")
	return {
		"ok": true,
		"theme": theme_name
	}


static func _colorscheme_error(message: String = "not a colorscheme command") -> Dictionary:
	return {
		"ok": false,
		"error": message
	}
