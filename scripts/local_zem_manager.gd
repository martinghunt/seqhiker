extends RefCounted
class_name LocalZemManager

var _zem: RefCounted
var _bin_subdir := "bin"
var _local_zem_path := ""
var _local_zem_pid := -1
var _local_zem_started_by_seqhiker := false
var _local_zem_install_checked := false
var _last_connect_error := ""

func configure(zem_client: RefCounted, bin_subdir: String) -> void:
	_zem = zem_client
	_bin_subdir = bin_subdir

func last_error() -> String:
	return _last_connect_error

func should_try_local(host: String) -> bool:
	var h := host.to_lower()
	return h == "127.0.0.1" or h == "localhost" or h == "::1"

func connect_with_local_fallback(host: String, port: int, connect_timeout_ms: int = 1200, wait_attempts: int = 15, wait_step_ms: int = 120) -> bool:
	_last_connect_error = ""
	var try_local := should_try_local(host)
	if try_local:
		if not ensure_local_zem_installed():
			_last_connect_error = "Local zem binary missing and install failed for %s:%d" % [host, port]
			return false
	if _zem.connect_to_server(host, port, connect_timeout_ms):
		var probe_existing := _probe_zem_ready()
		if bool(probe_existing.get("ok", false)):
			return true
		_last_connect_error = "Connected but zem probe failed: %s" % str(probe_existing.get("error", "unknown error"))
		_zem.disconnect_from_server()
	if not try_local:
		if _last_connect_error.is_empty():
			_last_connect_error = "Unable to connect to %s:%d" % [host, port]
		return false
	if not _start_local_zem(host, port):
		if _last_connect_error.is_empty():
			_last_connect_error = "Unable to start local zem at %s:%d" % [host, port]
		return false
	for _i in range(maxi(1, wait_attempts)):
		OS.delay_msec(maxi(1, wait_step_ms))
		if _zem.connect_to_server(host, port, connect_timeout_ms):
			var probe_started := _probe_zem_ready()
			if bool(probe_started.get("ok", false)):
				return true
			_last_connect_error = "Local zem started but probe failed: %s" % str(probe_started.get("error", "unknown error"))
			_zem.disconnect_from_server()
	if _last_connect_error.is_empty():
		_last_connect_error = "Local zem did not become ready at %s:%d" % [host, port]
	return false

func ensure_local_zem_installed() -> bool:
	if _local_zem_install_checked and not _local_zem_path.is_empty() and FileAccess.file_exists(_local_zem_path):
		return true
	_local_zem_install_checked = true
	var bin_name := _zem_binary_name()
	var user_bin_dir_abs := OS.get_user_data_dir().path_join(_bin_subdir)
	var mk_err := DirAccess.make_dir_recursive_absolute(user_bin_dir_abs)
	if mk_err != OK and not DirAccess.dir_exists_absolute(user_bin_dir_abs):
		_last_connect_error = "Failed to create local bin dir: %s" % user_bin_dir_abs
		return false
	var target_abs := user_bin_dir_abs.path_join(bin_name)
	_local_zem_path = target_abs
	var source := _find_zem_source(bin_name)
	if source.is_empty():
		if FileAccess.file_exists(target_abs):
			_last_connect_error = ""
			return true
		_last_connect_error = "No bundled zem found at res://bin/%s" % bin_name
		return false
	if not FileAccess.file_exists(target_abs):
		if not _copy_file_any_to_abs(source, target_abs):
			_last_connect_error = "Failed to copy zem into %s" % target_abs
			return false
	else:
		var src_hash := FileAccess.get_sha256(source)
		var dst_hash := FileAccess.get_sha256(target_abs)
		if src_hash.is_empty() or dst_hash.is_empty() or src_hash != dst_hash:
			if not _copy_file_any_to_abs(source, target_abs):
				_last_connect_error = "Failed to update zem in %s" % target_abs
				return false
	if not OS.has_feature("windows"):
		OS.execute("chmod", ["+x", target_abs], [], true)
	_last_connect_error = ""
	return true

func shutdown_on_exit() -> void:
	if not _local_zem_started_by_seqhiker:
		return
	var shutdown_ok := false
	var resp: Dictionary = _zem.shutdown_server(400)
	shutdown_ok = bool(resp.get("ok", false))
	if not shutdown_ok and _local_zem_pid > 0:
		OS.kill(_local_zem_pid)
	_zem.disconnect_from_server()

func _probe_zem_ready() -> Dictionary:
	var resp: Dictionary = _zem.get_annotation_counts()
	if bool(resp.get("ok", false)):
		return {"ok": true}
	return {"ok": false, "error": str(resp.get("error", "probe failed"))}

func _start_local_zem(host: String, port: int) -> bool:
	if not ensure_local_zem_installed():
		return false
	if _local_zem_path.is_empty() or not FileAccess.file_exists(_local_zem_path):
		return false
	var listen_addr := "%s:%d" % [host, port]
	var args := PackedStringArray(["-listen", listen_addr])
	var pid := OS.create_process(_local_zem_path, args, false)
	if pid <= 0:
		return false
	_local_zem_pid = pid
	_local_zem_started_by_seqhiker = true
	return true

func _find_zem_source(bin_name: String) -> String:
	var packaged := "res://bin/%s" % bin_name
	if FileAccess.file_exists(packaged):
		return packaged
	var dev_abs := ProjectSettings.globalize_path("res://zem/%s" % bin_name)
	if FileAccess.file_exists(dev_abs):
		return dev_abs
	return ""

func _copy_file_any_to_abs(source: String, target_abs: String) -> bool:
	var src := FileAccess.open(source, FileAccess.READ)
	if src == null:
		return false
	var dst := FileAccess.open(target_abs, FileAccess.WRITE)
	if dst == null:
		src.close()
		return false
	dst.store_buffer(src.get_buffer(src.get_length()))
	dst.close()
	src.close()
	return true

func _zem_binary_name() -> String:
	if OS.has_feature("windows"):
		return "zem.exe"
	return "zem"
