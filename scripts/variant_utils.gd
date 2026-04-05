extends RefCounted
class_name VariantUtils


static func display_kind(kind: int, ref: String, alt_summary: String) -> int:
	if kind != 5:
		return kind
	if ref.is_empty() or alt_summary.is_empty():
		return kind
	var alts := alt_summary.split(",", false)
	if alts.is_empty():
		return kind
	var all_snp := ref.length() == 1
	var all_insertion := true
	var all_deletion := true
	for alt_any in alts:
		var alt := str(alt_any)
		if alt.length() != 1:
			all_snp = false
		if alt.length() <= ref.length() or not alt.begins_with(ref):
			all_insertion = false
		if alt.length() != 1 or ref.length() <= 1 or alt[0] != ref[0]:
			all_deletion = false
		if alt.length() == 1 and ref.length() == 1:
			continue
		if alt.length() > ref.length() and alt.begins_with(ref):
			continue
		if alt.length() == 1 and ref.length() > 1 and alt[0] == ref[0]:
			continue
		all_snp = false
	if all_snp:
		return 1
	if all_insertion:
		return 3
	if all_deletion:
		return 4
	return kind
