extends RefCounted
class_name SeqhikerTestCase

var _failures: Array[String] = []


func setup() -> void:
	pass


func teardown() -> void:
	pass


func clear_failures() -> void:
	_failures.clear()


func failures() -> Array[String]:
	return _failures.duplicate()


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(value: bool, message: String = "") -> void:
	if not value:
		fail(_message_or_default(message, "Expected true."))


func assert_false(value: bool, message: String = "") -> void:
	if value:
		fail(_message_or_default(message, "Expected false."))


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		fail(_message_or_default(message, "Expected %s, got %s." % [str(expected), str(actual)]))


func assert_ne(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		fail(_message_or_default(message, "Expected value different from %s." % str(expected)))


func _message_or_default(message: String, default_message: String) -> String:
	return default_message if message.is_empty() else message
