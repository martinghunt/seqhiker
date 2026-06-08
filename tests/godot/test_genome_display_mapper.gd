extends "res://tests/godot/test_case.gd"

const GenomeDisplayMapperScript = preload("res://scripts/genome_display_mapper.gd")

var mapper: RefCounted


func setup() -> void:
	mapper = GenomeDisplayMapperScript.new()


func teardown() -> void:
	mapper = null


func test_linear_soft_clips_extend_display_edges() -> void:
	var tracks: Array[Dictionary] = [
		{
			"reads": [
				{"start": 0, "end": 20, "soft_clip_left": "AAAA"},
				{"start": 80, "end": 100, "soft_clip_right": "TT"}
			]
		}
	]
	var segments: Array[Dictionary] = []

	mapper.recompute(100, tracks, segments)

	assert_eq(mapper.leading_pad_bp, 4.0)
	assert_eq(mapper.trailing_pad_bp, 2.0)
	assert_eq(mapper.display_total_length_bp(), 106.0)
	assert_eq(mapper.display_bp_for_genome_bp(0), 4.0)
	assert_eq(mapper.genome_bp_for_display_bp(3.0), 0.0)
	assert_eq(mapper.genome_bp_for_display_bp(106.0), 100.0)


func test_concat_soft_clips_insert_gap_between_adjacent_segments() -> void:
	var tracks: Array[Dictionary] = [
		{
			"reads": [
				{"start": 80, "end": 100, "soft_clip_right": "TTTTTTTTTT"},
				{"start": 100, "end": 120, "soft_clip_left": "AAAAA"}
			]
		}
	]
	var segments: Array[Dictionary] = [
		{"id": 1, "start": 0, "end": 100},
		{"id": 2, "start": 100, "end": 200}
	]

	mapper.recompute(200, tracks, segments)

	assert_eq(mapper.leading_pad_bp, 0.0)
	assert_eq(mapper.trailing_pad_bp, 0.0)
	assert_eq(mapper.gap_overrides.size(), 1)
	assert_eq(mapper.gap_overrides[0], {"next_start": 100.0, "extra_bp": 15.0})
	assert_eq(mapper.display_total_length_bp(), 215.0)
	assert_eq(mapper.display_bp_for_genome_bp(99), 99.0)
	assert_eq(mapper.display_bp_for_genome_bp(100), 115.0)
	assert_eq(mapper.genome_bp_for_display_bp(105.0), 100.0)


func test_display_start_uses_leading_pad_only_at_left_boundary() -> void:
	var tracks: Array[Dictionary] = [
		{"reads": [{"start": 0, "end": 10, "soft_clip_left": "AAAA"}]}
	]
	var segments: Array[Dictionary] = []

	mapper.recompute(100, tracks, segments)

	assert_eq(mapper.display_start_bp_for_view(0.0, 10.0, 5.0), 0.0)
	assert_eq(mapper.display_start_bp_for_view(10.0, 10.0, 5.0), 14.0)
