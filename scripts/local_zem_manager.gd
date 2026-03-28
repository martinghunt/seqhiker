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
			if try_local and not _connected_server_version_matches():
				_zem.shutdown_server(400)
				_zem.disconnect_from_server()
			else:
				return true
		else:
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
		var legacy_abs := user_bin_dir_abs.path_join(_legacy_zem_binary_name())
		if FileAccess.file_exists(target_abs):
			_last_connect_error = ""
			return true
		if FileAccess.file_exists(legacy_abs):
			_local_zem_path = legacy_abs
			_last_connect_error = ""
			return true
		_last_connect_error = "No bundled zem found at res://bin/%s" % bin_name
		return false
	var expected_version := _expected_zem_version()
	var target_matches_version := FileAccess.file_exists(target_abs) and _installed_binary_version_matches(target_abs)
	var src_hash := ""
	var dst_hash := ""
	if FileAccess.file_exists(target_abs):
		src_hash = FileAccess.get_sha256(source)
		dst_hash = FileAccess.get_sha256(target_abs)
	if FileAccess.file_exists(target_abs) and target_matches_version and not src_hash.is_empty() and src_hash == dst_hash:
		_last_connect_error = ""
		return true
	if not FileAccess.file_exists(target_abs):
		if not _copy_file_any_to_abs(source, target_abs):
			_last_connect_error = "Failed to copy zem into %s" % target_abs
			return false
	elif not target_matches_version:
		if not _copy_file_any_to_abs(source, target_abs):
			_last_connect_error = "Failed to replace zem in %s" % target_abs
			return false
	else:
		if src_hash.is_empty() or dst_hash.is_empty() or src_hash != dst_hash:
			if not _copy_file_any_to_abs(source, target_abs):
				_last_connect_error = "Failed to update zem in %s" % target_abs
				return false
	if not OS.has_feature("windows"):
		OS.execute("chmod", ["+x", target_abs], [], true)
	if not _write_installed_version(target_abs):
		_last_connect_error = "Failed to write zem version marker for %s" % target_abs
		return false
	if not expected_version.is_empty() and not _installed_binary_version_matches(target_abs):
		_last_connect_error = "Installed zem version does not match project version %s" % expected_version
		return false
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
	var packaged_legacy := "res://bin/%s" % _legacy_zem_binary_name()
	if FileAccess.file_exists(packaged_legacy):
		return packaged_legacy
	var dev_abs := ProjectSettings.globalize_path("res://zem/%s" % bin_name)
	if FileAccess.file_exists(dev_abs):
		return dev_abs
	var dev_abs_legacy := ProjectSettings.globalize_path("res://zem/%s" % _legacy_zem_binary_name())
	if FileAccess.file_exists(dev_abs_legacy):
		return dev_abs_legacy
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
		return "seqhiker-zem.exe"
	return "seqhiker-zem"

func _legacy_zem_binary_name() -> String:
	if OS.has_feature("windows"):
		return "zem.exe"
	return "zem"

func _expected_zem_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "")).strip_edges()

func _installed_binary_version_matches(binary_path: String) -> bool:
	var expected_version := _expected_zem_version()
	if expected_version.is_empty():
		return true
	var actual_version := _read_installed_version(binary_path)
	return not actual_version.is_empty() and actual_version == expected_version

func _version_marker_path(binary_path: String) -> String:
	return "%s.version" % binary_path

func _read_installed_version(binary_path: String) -> String:
	var marker_path := _version_marker_path(binary_path)
	if marker_path.is_empty() or not FileAccess.file_exists(marker_path):
		return ""
	var file := FileAccess.open(marker_path, FileAccess.READ)
	if file == null:
		return ""
	var version := file.get_as_text().strip_edges()
	file.close()
	return version

func _write_installed_version(binary_path: String) -> bool:
	var expected_version := _expected_zem_version()
	if expected_version.is_empty():
		return true
	var marker_path := _version_marker_path(binary_path)
	var file := FileAccess.open(marker_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(expected_version + "\n")
	file.close()
	return true

func _connected_server_version_matches() -> bool:
	var expected_version := _expected_zem_version()
	if expected_version.is_empty():
		return true
	var resp: Dictionary = _zem.get_server_version()
	if not bool(resp.get("ok", false)):
		_last_connect_error = "Connected but zem version probe failed: %s" % str(resp.get("error", "unknown error"))
		return false
	var actual_version := str(resp.get("version", "")).strip_edges()
	if actual_version == expected_version:
		return true
	_last_connect_error = "Zem version mismatch: app %s, server %s" % [expected_version, actual_version]
	return false
