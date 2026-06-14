extends RefCounted
class_name AnnotationFeatureNavigationController

const FeatureAnnotationUtilsScript = preload("res://scripts/feature_annotation_utils.gd")

var host: Node = null
var _selected_annotation_feature: Dictionary = {}


func configure(next_host: Node) -> void:
	host = next_host


func set_selected_feature(feature: Dictionary) -> void:
	if feature.is_empty():
		clear_selected_feature()
		return
	_selected_annotation_feature = feature.duplicate(true)


func clear_selected_feature() -> void:
	_selected_annotation_feature = {}


func step_feature(delta: int) -> Dictionary:
	if host == null:
		return {"ok": false, "error": "feature navigation unavailable"}
	if host._app_mode != host.APP_MODE_BROWSER:
		return {"ok": false, "error": "feature navigation is only available in browser view"}
	if delta == 0:
		return {"ok": false, "error": "no feature movement"}
	if host._zem == null:
		return {"ok": false, "error": "annotation navigation unavailable"}
	if not _has_active_selected_feature():
		clear_selected_feature()
		return {"ok": false, "error": "no annotation feature selected"}
	var context := _feature_context(_selected_annotation_feature)
	if context.is_empty():
		return {"ok": false, "error": "selected annotation feature unavailable"}
	var feature_result := _features_for_context(context)
	if not bool(feature_result.get("ok", false)):
		return feature_result
	var display_features: Array[Dictionary] = feature_result.get("features", [])
	if display_features.is_empty():
		return {"ok": false, "error": "no annotation features"}
	var current_index := _current_feature_index(display_features, _selected_annotation_feature, delta)
	var requested_index := current_index + delta
	if requested_index >= 0 and requested_index < display_features.size():
		var target: Dictionary = display_features[requested_index].duplicate(true)
		return _jump_result(target, requested_index, display_features.size(), "")
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT and int(context.get("segment_index", -1)) >= 0:
		var cross_result := _concat_boundary_result(context, display_features, requested_index, delta)
		if not cross_result.is_empty():
			return cross_result
	var target_index := clampi(requested_index, 0, display_features.size() - 1)
	var clamped_target: Dictionary = display_features[target_index].duplicate(true)
	return _jump_result(clamped_target, target_index, display_features.size(), "last" if delta > 0 else "first")


func _has_active_selected_feature() -> bool:
	if _selected_annotation_feature.is_empty():
		return false
	if host == null or host.genome_view == null:
		return true
	if host.genome_view.has_method("get_selected_feature_key"):
		var selected_key := str(host.genome_view.get_selected_feature_key())
		if selected_key.is_empty():
			return false
		return selected_key == FeatureAnnotationUtilsScript.feature_key(_selected_annotation_feature)
	return true


func _feature_context(feature: Dictionary) -> Dictionary:
	if feature.is_empty():
		return {}
	if host._seq_view_mode == host.SEQ_VIEW_CONCAT:
		var seg := _concat_segment_for_feature(feature)
		if seg.is_empty():
			return {}
		var seg_chr_id := int(seg.get("id", -1))
		var seg_chromosome := _chromosome_for_id(seg_chr_id)
		return {
			"chr_id": seg_chr_id,
			"chr_len": int(seg.get("length", seg_chromosome.get("length", 0))),
			"name": str(seg.get("raw_name", seg.get("name", "chr"))),
			"offset": int(seg.get("start", 0)),
			"segment_index": int(seg.get("_index", -1))
		}
	var chr_id: int = int(host._current_chr_id) if int(host._current_chr_id) >= 0 else int(host._selected_seq_id)
	var chromosome := _chromosome_for_id(chr_id)
	return {
		"chr_id": chr_id,
		"chr_len": int(chromosome.get("length", host._current_chr_len)),
		"name": str(chromosome.get("name", host._current_chr_name)),
		"offset": 0,
		"segment_index": -1
	}


func _features_for_context(context: Dictionary) -> Dictionary:
	var chr_id := int(context.get("chr_id", -1))
	var chr_len := int(context.get("chr_len", 0))
	if chr_id < 0 or chr_len <= 0:
		return {"ok": false, "error": "selected annotation sequence unavailable"}
	var resp: Dictionary = host._zem.get_annotations(chr_id, 0, chr_len, 65535, 1)
	if not bool(resp.get("ok", false)):
		return {"ok": false, "error": "annotation query failed: %s" % str(resp.get("error", "error"))}
	var raw_features: Array[Dictionary] = []
	for feat_any in resp.get("features", []):
		if typeof(feat_any) != TYPE_DICTIONARY:
			continue
		var feat: Dictionary = feat_any
		raw_features.append(feat.duplicate(true))
	var display_features := _display_features_for_context(raw_features, context)
	display_features = host._collapse_gene_cds_features(display_features)
	_sort_features(display_features)
	return {"ok": true, "features": display_features}


func _features_for_concat_segment(segment_index: int) -> Dictionary:
	if segment_index < 0 or segment_index >= host._concat_segments.size():
		return {"ok": false, "error": "selected annotation sequence unavailable"}
	var seg: Dictionary = (host._concat_segments[segment_index] as Dictionary).duplicate(true)
	seg["_index"] = segment_index
	var chr_id := int(seg.get("id", -1))
	var chromosome := _chromosome_for_id(chr_id)
	var context := {
		"chr_id": chr_id,
		"chr_len": int(seg.get("length", chromosome.get("length", 0))),
		"name": str(seg.get("raw_name", seg.get("name", "chr"))),
		"offset": int(seg.get("start", 0)),
		"segment_index": segment_index
	}
	return _features_for_context(context)


func _concat_boundary_result(context: Dictionary, display_features: Array[Dictionary], requested_index: int, delta: int) -> Dictionary:
	var segment_index := int(context.get("segment_index", -1))
	if delta > 0 and requested_index >= display_features.size():
		var forward_skip := requested_index - display_features.size()
		return _concat_forward_result(segment_index + 1, forward_skip, display_features)
	if delta < 0 and requested_index < 0:
		var backward_skip := -requested_index - 1
		return _concat_backward_result(segment_index - 1, backward_skip, display_features)
	return {}


func _concat_forward_result(start_segment_index: int, skip_count: int, fallback_features: Array[Dictionary]) -> Dictionary:
	var last_non_empty_features: Array[Dictionary] = []
	for segment_index in range(start_segment_index, host._concat_segments.size()):
		var feature_result := _features_for_concat_segment(segment_index)
		if not bool(feature_result.get("ok", false)):
			return feature_result
		var features: Array[Dictionary] = feature_result.get("features", [])
		if features.is_empty():
			continue
		last_non_empty_features = features
		if skip_count < features.size():
			var target: Dictionary = features[skip_count].duplicate(true)
			return _jump_result(target, skip_count, features.size(), "")
		skip_count -= features.size()
	if not last_non_empty_features.is_empty():
		var last_index := last_non_empty_features.size() - 1
		var last_target: Dictionary = last_non_empty_features[last_index].duplicate(true)
		return _jump_result(last_target, last_index, last_non_empty_features.size(), "last")
	if fallback_features.is_empty():
		return {}
	var fallback_index := fallback_features.size() - 1
	var fallback_target: Dictionary = fallback_features[fallback_index].duplicate(true)
	return _jump_result(fallback_target, fallback_index, fallback_features.size(), "last")


func _concat_backward_result(start_segment_index: int, skip_count: int, fallback_features: Array[Dictionary]) -> Dictionary:
	var first_non_empty_features: Array[Dictionary] = []
	for segment_index in range(start_segment_index, -1, -1):
		var feature_result := _features_for_concat_segment(segment_index)
		if not bool(feature_result.get("ok", false)):
			return feature_result
		var features: Array[Dictionary] = feature_result.get("features", [])
		if features.is_empty():
			continue
		first_non_empty_features = features
		if skip_count < features.size():
			var target_index := features.size() - 1 - skip_count
			var target: Dictionary = features[target_index].duplicate(true)
			return _jump_result(target, target_index, features.size(), "")
		skip_count -= features.size()
	if not first_non_empty_features.is_empty():
		var first_target: Dictionary = first_non_empty_features[0].duplicate(true)
		return _jump_result(first_target, 0, first_non_empty_features.size(), "first")
	if fallback_features.is_empty():
		return {}
	var fallback_target: Dictionary = fallback_features[0].duplicate(true)
	return _jump_result(fallback_target, 0, fallback_features.size(), "first")


func _jump_result(target: Dictionary, index: int, count: int, boundary: String) -> Dictionary:
	host._jump_to_annotation_feature(target)
	return {
		"ok": true,
		"index": index,
		"count": count,
		"label": _feature_label(target),
		"boundary": boundary
	}


func _concat_segment_for_feature(feature: Dictionary) -> Dictionary:
	var seq_name := str(feature.get("seq_name", "")).strip_edges()
	if not seq_name.is_empty():
		for i in range(host._concat_segments.size()):
			var seg_by_name: Dictionary = (host._concat_segments[i] as Dictionary).duplicate(true)
			if seq_name == str(seg_by_name.get("raw_name", "")) or seq_name == str(seg_by_name.get("name", "")):
				seg_by_name["_index"] = i
				return seg_by_name
	var start_bp := int(feature.get("start", 0))
	var end_bp := int(feature.get("end", start_bp + 1))
	for i in range(host._concat_segments.size()):
		var seg: Dictionary = (host._concat_segments[i] as Dictionary).duplicate(true)
		var seg_start := int(seg.get("start", 0))
		var seg_end := int(seg.get("end", seg_start))
		if start_bp >= seg_start and start_bp < seg_end:
			seg["_index"] = i
			return seg
		if end_bp > seg_start and end_bp <= seg_end:
			seg["_index"] = i
			return seg
	return {}


func _chromosome_for_id(chr_id: int) -> Dictionary:
	for c_any in host._chromosomes:
		var chromosome: Dictionary = c_any
		if int(chromosome.get("id", -1)) == chr_id:
			return chromosome
	return {}


func _display_features_for_context(raw_features: Array[Dictionary], context: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var offset := int(context.get("offset", 0))
	for raw_feature in raw_features:
		if host._seq_view_mode == host.SEQ_VIEW_CONCAT:
			out.append(host._shift_feature_coords(raw_feature, offset))
		else:
			out.append(raw_feature.duplicate(true))
	return out


func _sort_features(features: Array[Dictionary]) -> void:
	features.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_start := int(a.get("start", 0))
		var b_start := int(b.get("start", 0))
		if a_start == b_start:
			return int(a.get("end", a_start)) < int(b.get("end", b_start))
		return a_start < b_start
	)


func _current_feature_index(features: Array[Dictionary], selected_feature: Dictionary, delta: int) -> int:
	var selected_key := FeatureAnnotationUtilsScript.feature_key(selected_feature)
	for i in range(features.size()):
		if FeatureAnnotationUtilsScript.feature_key(features[i]) == selected_key:
			return i
	var selected_start := int(selected_feature.get("start", 0))
	if delta > 0:
		var before_or_at := -1
		for i in range(features.size()):
			if int(features[i].get("start", 0)) <= selected_start:
				before_or_at = i
			else:
				break
		return before_or_at
	var after_or_at := features.size()
	for i in range(features.size()):
		if int(features[i].get("start", 0)) >= selected_start:
			after_or_at = i
			break
	return after_or_at


func _feature_label(feature: Dictionary) -> String:
	var label := str(feature.get("name", "")).strip_edges()
	if label.is_empty():
		label = str(feature.get("id", "")).strip_edges()
	if label.is_empty():
		label = str(feature.get("type", "")).strip_edges()
	if label.is_empty():
		label = "feature"
	return label
