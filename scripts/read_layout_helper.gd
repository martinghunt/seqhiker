extends RefCounted
class_name ReadLayoutHelper

const READ_VIEW_STRAND := 1
const READ_VIEW_PAIRED := 2
const READ_VIEW_FRAGMENT := 3

func attach_indel_markers(read: Dictionary) -> void:
	var cigar := str(read.get("cigar", ""))
	if cigar.is_empty():
		return
	var ref_pos := int(read.get("start", 0))
	var num := 0
	var del_starts := PackedInt32Array()
	var del_ends := PackedInt32Array()
	var ins_positions := PackedInt32Array()
	for i in range(cigar.length()):
		var ch := cigar.substr(i, 1)
		if ch >= "0" and ch <= "9":
			num = num * 10 + int(ch.to_int())
			continue
		var ln := num
		num = 0
		if ln <= 0:
			continue
		match ch:
			"M", "=", "X":
				ref_pos += ln
			"D", "N":
				del_starts.append(ref_pos)
				del_ends.append(ref_pos + ln)
				ref_pos += ln
			"I":
				ins_positions.append(ref_pos)
			"S", "H", "P":
				pass
			_:
				pass
	read["del_starts"] = del_starts
	read["del_ends"] = del_ends
	read["ins_positions"] = ins_positions

func build_layout(reads_in: Array[Dictionary], view_mode: int, fragment_log: bool, row_limit: int, view_start: int, view_end: int) -> Dictionary:
	var laid_out_reads: Array[Dictionary] = []
	var strand_forward_rows := 0
	var strand_reverse_rows := 0
	var read_row_count := 0
	if reads_in.is_empty():
		return {
			"laid_out_reads": laid_out_reads,
			"read_row_count": 0,
			"strand_forward_rows": 0,
			"strand_reverse_rows": 0
		}
	if view_mode == READ_VIEW_FRAGMENT:
		var max_frag := 1.0
		for read in reads_in:
			var f := float(maxi(1, int(read.get("fragment_len", 0))))
			if f > max_frag:
				max_frag = f
		for read in reads_in:
			var laid_out: Dictionary = read.duplicate(true)
			var f := float(maxi(1, int(laid_out.get("fragment_len", 0))))
			var norm := 0.0
			if fragment_log:
				norm = log(f + 1.0) / log(max_frag + 1.0)
			else:
				norm = f / max_frag
			laid_out["frag_norm"] = clampf(norm, 0.0, 1.0)
			laid_out_reads.append(laid_out)
		return {
			"laid_out_reads": laid_out_reads,
			"read_row_count": 0,
			"strand_forward_rows": 0,
			"strand_reverse_rows": 0
		}
	if view_mode == READ_VIEW_STRAND:
		var forward_reads: Array[Dictionary] = []
		var reverse_reads: Array[Dictionary] = []
		for read in reads_in:
			if bool(read.get("reverse", false)):
				reverse_reads.append(read)
			else:
				forward_reads.append(read)
		var total_limit := maxi(0, row_limit)
		var forward_limit := 0
		var reverse_limit := 0
		if total_limit > 0:
			forward_limit = int(ceil(float(total_limit) * 0.5))
			reverse_limit = total_limit - forward_limit
		var forward_layout := _pack_reads_into_rows(forward_reads, false, forward_limit, view_start, view_end)
		var reverse_layout := _pack_reads_into_rows(reverse_reads, false, reverse_limit, view_start, view_end)
		laid_out_reads.append_array(forward_layout.get("laid_out_reads", []))
		laid_out_reads.append_array(reverse_layout.get("laid_out_reads", []))
		strand_forward_rows = int(forward_layout.get("row_count", 0))
		strand_reverse_rows = int(reverse_layout.get("row_count", 0))
		read_row_count = maxi(strand_forward_rows, strand_reverse_rows)
		return {
			"laid_out_reads": laid_out_reads,
			"read_row_count": read_row_count,
			"strand_forward_rows": strand_forward_rows,
			"strand_reverse_rows": strand_reverse_rows
		}
	var packed := _pack_reads_into_rows(reads_in, view_mode == READ_VIEW_PAIRED, row_limit, view_start, view_end)
	return {
		"laid_out_reads": packed.get("laid_out_reads", []),
		"read_row_count": int(packed.get("row_count", 0)),
		"strand_forward_rows": 0,
		"strand_reverse_rows": 0
	}

func _pack_reads_into_rows(source_reads: Array[Dictionary], use_pair_span: bool, row_limit: int, view_start: int, view_end: int) -> Dictionary:
	var laid_out_reads: Array[Dictionary] = []
	if source_reads.is_empty():
		return {"laid_out_reads": laid_out_reads, "row_count": 0}
	var sorted_reads: Array = source_reads.duplicate(true)
	sorted_reads.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa := _layout_span_start(a, use_pair_span, view_start, view_end)
		var sb := _layout_span_start(b, use_pair_span, view_start, view_end)
		if sa == sb:
			return _layout_span_end(a, use_pair_span, view_start, view_end) < _layout_span_end(b, use_pair_span, view_start, view_end)
		return sa < sb
	)
	var row_ends: Array[int] = []
	for read_any in sorted_reads:
		var read: Dictionary = read_any
		var s := _layout_span_start(read, use_pair_span, view_start, view_end)
		var e := _layout_span_end(read, use_pair_span, view_start, view_end)
		var chosen := -1
		for i in range(row_ends.size()):
			if s > row_ends[i]:
				chosen = i
				break
		if chosen == -1:
			if row_limit > 0 and row_ends.size() >= row_limit:
				continue
			chosen = row_ends.size()
			row_ends.append(e)
		else:
			row_ends[chosen] = e
		var laid_out := read.duplicate(true)
		laid_out["row"] = chosen
		laid_out_reads.append(laid_out)
	return {"laid_out_reads": laid_out_reads, "row_count": row_ends.size()}

func _layout_span_start(read: Dictionary, use_pair_span: bool, view_start: int, view_end: int) -> int:
	var s := int(read.get("start", 0))
	if not use_pair_span or not _should_use_mate_span_for_packing(read, view_start, view_end):
		return s
	var mate_start := int(read.get("mate_start", -1))
	if mate_start >= 0:
		return mini(s, mate_start)
	return s

func _layout_span_end(read: Dictionary, use_pair_span: bool, view_start: int, view_end: int) -> int:
	var s := int(read.get("start", 0))
	var e := int(read.get("end", s + 1))
	if not use_pair_span or not _should_use_mate_span_for_packing(read, view_start, view_end):
		return e
	var mate_end := int(read.get("mate_end", -1))
	if mate_end > 0:
		return maxi(e, mate_end)
	return e

func _should_use_mate_span_for_packing(read: Dictionary, view_start: int, view_end: int) -> bool:
	var mate_start := int(read.get("mate_start", -1))
	var mate_end := int(read.get("mate_end", -1))
	if mate_start < 0 or mate_end <= mate_start:
		return false
	var view_span := maxi(1, view_end - view_start)
	var max_distance := view_span * 2
	var read_start := int(read.get("start", 0))
	var read_end := int(read.get("end", read_start + 1))
	var read_center := int((read_start + read_end) / 2.0)
	var mate_center := int((mate_start + mate_end) / 2.0)
	return absi(mate_center - read_center) <= max_distance
