extends "res://tests/godot/test_case.gd"

const AnnotationFeatureNavigationControllerScript = preload("res://scripts/annotation_feature_navigation_controller.gd")
const FeatureAnnotationUtilsScript = preload("res://scripts/feature_annotation_utils.gd")


class FakeGenomeView:
	extends Node

	var selected_key := ""

	func get_selected_feature_key() -> String:
		return selected_key


class FakeZem:
	extends RefCounted

	var features_by_chr := {}
	var requests: Array[Dictionary] = []

	func get_annotations(chr_id: int, start_bp: int, end_bp: int, max_records: int = 2000, min_feature_len_bp: int = 1) -> Dictionary:
		requests.append({
			"chr_id": chr_id,
			"start": start_bp,
			"end": end_bp,
			"max_records": max_records,
			"min_feature_len_bp": min_feature_len_bp
		})
		return {"ok": true, "features": features_by_chr.get(chr_id, [])}


class FakeHost:
	extends Node

	const APP_MODE_BROWSER := 0
	const APP_MODE_COMPARISON := 1
	const SEQ_VIEW_CONCAT := 0
	const SEQ_VIEW_SINGLE := 1

	var _app_mode := APP_MODE_BROWSER
	var _seq_view_mode := SEQ_VIEW_CONCAT
	var _zem := FakeZem.new()
	var _current_chr_id := -2
	var _current_chr_name := "concat"
	var _current_chr_len := 2200
	var _selected_seq_id := 1
	var _chromosomes: Array[Dictionary] = [
		{"id": 1, "name": "ctg1", "length": 100},
		{"id": 2, "name": "ctg2", "length": 100},
		{"id": 3, "name": "ctg3", "length": 100},
		{"id": 4, "name": "ctg4", "length": 100}
	]
	var _concat_segments: Array[Dictionary] = [
		{"id": 1, "name": "ctg1", "raw_name": "ctg1", "length": 100, "start": 0, "end": 100},
		{"id": 2, "name": "ctg2", "raw_name": "ctg2", "length": 100, "start": 1000, "end": 1100},
		{"id": 3, "name": "ctg3", "raw_name": "ctg3", "length": 100, "start": 2000, "end": 2100},
		{"id": 4, "name": "ctg4", "raw_name": "ctg4", "length": 100, "start": 3000, "end": 3100}
	]
	var genome_view := FakeGenomeView.new()
	var controller: RefCounted = null
	var jumped_features: Array[Dictionary] = []

	func _collapse_gene_cds_features(features_in: Array[Dictionary]) -> Array[Dictionary]:
		return features_in

	func _shift_feature_coords(feature: Dictionary, offset: int) -> Dictionary:
		var shifted := feature.duplicate(true)
		shifted["start"] = int(shifted.get("start", 0)) + offset
		shifted["end"] = int(shifted.get("end", 0)) + offset
		return shifted

	func _jump_to_annotation_feature(feature: Dictionary) -> void:
		jumped_features.append(feature.duplicate(true))
		genome_view.selected_key = FeatureAnnotationUtilsScript.feature_key(feature)
		if controller != null:
			controller.set_selected_feature(feature)


func test_annotation_feature_navigation_steps_counts_and_clamps_in_concat() -> void:
	var host := FakeHost.new()
	var controller := AnnotationFeatureNavigationControllerScript.new()
	controller.configure(host)
	host.controller = controller
	host._zem.features_by_chr[2] = [
		{"seq_name": "ctg2", "start": 10, "end": 20, "name": "geneA", "type": "gene"},
		{"seq_name": "ctg2", "start": 30, "end": 40, "name": "geneB", "type": "gene"},
		{"seq_name": "ctg2", "start": 50, "end": 60, "name": "geneC", "type": "gene"}
	]
	host._zem.features_by_chr[3] = [
		{"seq_name": "ctg3", "start": 5, "end": 15, "name": "geneD", "type": "gene"},
		{"seq_name": "ctg3", "start": 25, "end": 35, "name": "geneE", "type": "gene"}
	]
	var selected_feature := {
		"seq_name": "ctg2",
		"start": 1010,
		"end": 1020,
		"name": "geneA",
		"type": "gene"
	}
	host.genome_view.selected_key = FeatureAnnotationUtilsScript.feature_key(selected_feature)
	controller.set_selected_feature(selected_feature)

	var result := controller.step_feature(2)
	assert_eq(result, {"ok": true, "index": 2, "count": 3, "label": "geneC", "boundary": ""})
	assert_eq(host._zem.requests[-1], {"chr_id": 2, "start": 0, "end": 100, "max_records": 65535, "min_feature_len_bp": 1})
	assert_eq(host.jumped_features[-1]["start"], 1050)
	assert_eq(host.jumped_features[-1]["end"], 1060)

	result = controller.step_feature(1)
	assert_eq(result, {"ok": true, "index": 0, "count": 2, "label": "geneD", "boundary": ""})
	assert_eq(host._zem.requests[-1], {"chr_id": 3, "start": 0, "end": 100, "max_records": 65535, "min_feature_len_bp": 1})
	assert_eq(host.jumped_features[-1]["start"], 2005)
	assert_eq(host.jumped_features[-1]["end"], 2015)

	result = controller.step_feature(-1)
	assert_eq(result, {"ok": true, "index": 2, "count": 3, "label": "geneC", "boundary": ""})
	assert_eq(host.jumped_features[-1]["start"], 1050)

	result = controller.step_feature(9)
	assert_eq(result, {"ok": true, "index": 1, "count": 2, "label": "geneE", "boundary": "last"})
	assert_eq(host.jumped_features[-1]["start"], 2025)

	result = controller.step_feature(-9)
	assert_eq(result, {"ok": true, "index": 0, "count": 3, "label": "geneA", "boundary": "first"})
	assert_eq(host.jumped_features[-1]["start"], 1010)
	host.free()
