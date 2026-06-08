extends "res://tests/godot/test_case.gd"

const LocalZemManagerScript = preload("res://scripts/local_zem_manager.gd")

var manager: RefCounted
var zem: FakeZemClient


class FakeZemClient:
	extends RefCounted

	var shutdown_count := 0
	var disconnect_count := 0

	func shutdown_server(_timeout_ms: int = 400) -> Dictionary:
		shutdown_count += 1
		return {"ok": true}

	func disconnect_from_server() -> void:
		disconnect_count += 1


func setup() -> void:
	zem = FakeZemClient.new()
	manager = LocalZemManagerScript.new()
	manager.configure(zem, "bin")


func teardown() -> void:
	manager = null
	zem = null


func test_adopt_local_zem_process_keeps_only_owned_valid_pid() -> void:
	manager.adopt_local_zem_process(-1, true)
	manager.adopt_local_zem_process(1234, false)
	assert_false(manager.local_zem_started_by_seqhiker())
	assert_eq(manager.local_zem_pid(), -1)

	manager.adopt_local_zem_process(1234, true)

	assert_true(manager.local_zem_started_by_seqhiker())
	assert_eq(manager.local_zem_pid(), 1234)


func test_disconnect_delegates_to_configured_client() -> void:
	manager.disconnect_from_server()

	assert_eq(zem.disconnect_count, 1)


func test_shutdown_on_exit_is_idempotent() -> void:
	manager.adopt_local_zem_process(1234, true)

	manager.shutdown_on_exit()
	manager.shutdown_on_exit()

	assert_false(manager.local_zem_started_by_seqhiker())
	assert_eq(manager.local_zem_pid(), -1)
	assert_eq(zem.shutdown_count, 1)
	assert_eq(zem.disconnect_count, 1)


func test_should_try_local_only_for_loopback_hosts() -> void:
	assert_true(manager.should_try_local("127.0.0.1"))
	assert_true(manager.should_try_local("localhost"))
	assert_true(manager.should_try_local("::1"))
	assert_false(manager.should_try_local("example.com"))
