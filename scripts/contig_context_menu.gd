extends PopupMenu
class_name ContigContextMenu

signal contig_action_selected(action_id: int, segment: Dictionary)

const ACTION_REVERSE_SEGMENT := 1
const ACTION_RESTORE_SEGMENT := 2
const ACTION_REVERSE_ALL := 3
const ACTION_RESTORE_ALL := 4
const ACTION_MOVE_LEFT := 5
const ACTION_MOVE_RIGHT := 6
const ACTION_MOVE_START := 7
const ACTION_MOVE_END := 8

const MOVE_LEFT := 1
const MOVE_RIGHT := 2
const MOVE_START := 3
const MOVE_END := 4

var _segment: Dictionary = {}


func _init() -> void:
	id_pressed.connect(_on_id_pressed)


func popup_for_segment(segment: Dictionary, segments: Array, popup_at_mouse: Callable = Callable()) -> void:
	_segment = segment.duplicate(true)
	var segment_index := _segment_index(segment, segments)
	var has_segments := not segments.is_empty()
	var all_reversed := has_segments
	var any_reversed := false
	for seg_any in segments:
		var seg: Dictionary = seg_any
		if bool(seg.get("reversed", false)):
			any_reversed = true
		if not bool(seg.get("reversed", false)):
			all_reversed = false

	clear()
	add_item("Reverse complement contig", ACTION_REVERSE_SEGMENT)
	set_item_disabled(item_count - 1, bool(segment.get("reversed", false)))
	add_item("Restore contig forward", ACTION_RESTORE_SEGMENT)
	set_item_disabled(item_count - 1, not bool(segment.get("reversed", false)))
	add_separator()
	add_item("Reverse complement all contigs", ACTION_REVERSE_ALL)
	set_item_disabled(item_count - 1, not has_segments or all_reversed)
	add_item("Restore all contigs forward", ACTION_RESTORE_ALL)
	set_item_disabled(item_count - 1, not has_segments or not any_reversed)
	add_separator()
	add_item("Move contig 1 to left", ACTION_MOVE_LEFT)
	set_item_disabled(item_count - 1, segment_index <= 0)
	add_item("Move contig 1 to right", ACTION_MOVE_RIGHT)
	set_item_disabled(item_count - 1, segment_index < 0 or segment_index >= segments.size() - 1)
	add_item("Move contig to start of genome", ACTION_MOVE_START)
	set_item_disabled(item_count - 1, segment_index <= 0)
	add_item("Move contig to end of genome", ACTION_MOVE_END)
	set_item_disabled(item_count - 1, segment_index < 0 or segment_index >= segments.size() - 1)
	if popup_at_mouse.is_valid():
		popup_at_mouse.call(self)
	else:
		popup()


func move_code_for_action(action_id: int) -> int:
	match action_id:
		ACTION_MOVE_LEFT:
			return MOVE_LEFT
		ACTION_MOVE_RIGHT:
			return MOVE_RIGHT
		ACTION_MOVE_START:
			return MOVE_START
		ACTION_MOVE_END:
			return MOVE_END
	return -1


func move_error_label(action_id: int) -> String:
	match action_id:
		ACTION_MOVE_LEFT:
			return "Move left"
		ACTION_MOVE_RIGHT:
			return "Move right"
		ACTION_MOVE_START:
			return "Move to start"
		ACTION_MOVE_END:
			return "Move to end"
	return "Move"


func move_status_text(action_id: int, segment_name: String) -> String:
	match action_id:
		ACTION_MOVE_LEFT:
			return "Moved %s left." % segment_name
		ACTION_MOVE_RIGHT:
			return "Moved %s right." % segment_name
		ACTION_MOVE_START:
			return "Moved %s to the start." % segment_name
		ACTION_MOVE_END:
			return "Moved %s to the end." % segment_name
	return "Moved %s." % segment_name


func _segment_index(segment: Dictionary, segments: Array) -> int:
	var segment_id := int(segment.get("id", -1))
	var segment_start := int(segment.get("start", -1))
	for i in range(segments.size()):
		var seg: Dictionary = segments[i]
		if segment_id >= 0 and int(seg.get("id", -1)) == segment_id:
			return i
		if segment_start >= 0 and int(seg.get("start", -1)) == segment_start:
			return i
	return -1


func _on_id_pressed(action_id: int) -> void:
	if _segment.is_empty():
		return
	contig_action_selected.emit(action_id, _segment.duplicate(true))
