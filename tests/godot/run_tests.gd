extends SceneTree

const TEST_SCRIPTS := [
	"res://tests/godot/test_annotation_cache_controller.gd",
	"res://tests/godot/test_local_zem_manager.gd",
	"res://tests/godot/test_track_controls_controller.gd",
	"res://tests/godot/test_track_settings_controller.gd"
]


func _initialize() -> void:
	var total := 0
	var failed := 0
	for path in TEST_SCRIPTS:
		var script: Script = load(path)
		if script == null:
			printerr("FAIL %s: could not load script" % path)
			failed += 1
			continue
		var test: Object = script.new()
		var test_names := _test_method_names(test)
		for test_name in test_names:
			total += 1
			test.clear_failures()
			if test.has_method("setup"):
				test.setup()
			test.call(test_name)
			if test.has_method("teardown"):
				test.teardown()
			var failures: Array = test.failures()
			if failures.is_empty():
				print("PASS %s.%s" % [path.get_file().get_basename(), test_name])
			else:
				failed += 1
				printerr("FAIL %s.%s" % [path.get_file().get_basename(), test_name])
				for failure_any in failures:
					printerr("  - %s" % str(failure_any))
	if failed == 0:
		if total == 0:
			printerr("Godot tests failed: no tests were discovered")
			quit(1)
			return
		print("Godot tests passed: %d" % total)
		quit(0)
	else:
		printerr("Godot tests failed: %d of %d" % [failed, total])
		quit(1)


func _test_method_names(test: Object) -> Array[String]:
	var names: Array[String] = []
	for method_any in test.get_method_list():
		var method: Dictionary = method_any
		var name := str(method.get("name", ""))
		if name.begins_with("test_"):
			names.append(name)
	names.sort()
	return names
