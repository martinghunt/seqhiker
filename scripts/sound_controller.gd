extends RefCounted
class_name SoundController

const SOUND_CHANGE_VIEW := "change_view"
const SOUND_CLEAR_DATA := "clear_data"
const SOUND_BLIP := "blip"
const SOUND_DOWNLOAD := "download"
const SOUND_FILE_DROP := "file_drop"
const SOUND_JUMP := "jump"
const SOUND_TOGGLE_ON := "toggle_on"
const SOUND_TOGGLE_OFF := "toggle_off"
const SOUND_OPEN_RIGHT_PANEL := "open_right_panel"
const SOUND_CLOSE_RIGHT_PANEL := "close_right_panel"
const SOUND_PAN_LEFT := "pan_left"
const SOUND_PAN_RIGHT := "pan_right"
const SOUND_SETTINGS_TOGGLE := "settings_toggle"
const SOUND_ZOOM_IN := "zoom_in"
const SOUND_ZOOM_OUT := "zoom_out"

const SOUND_STREAMS := {
	SOUND_CHANGE_VIEW: preload("res://assets/sounds/change_view.wav"),
	SOUND_CLEAR_DATA: preload("res://assets/sounds/clear_data.wav"),
	SOUND_BLIP: preload("res://assets/sounds/blip.wav"),
	SOUND_DOWNLOAD: preload("res://assets/sounds/download.wav"),
	SOUND_FILE_DROP: preload("res://assets/sounds/file_drop.wav"),
	SOUND_JUMP: preload("res://assets/sounds/jump.wav"),
	SOUND_TOGGLE_ON: preload("res://assets/sounds/toggle_on.wav"),
	SOUND_TOGGLE_OFF: preload("res://assets/sounds/toggle_off.wav"),
	SOUND_OPEN_RIGHT_PANEL: preload("res://assets/sounds/open_right_panel.wav"),
	SOUND_CLOSE_RIGHT_PANEL: preload("res://assets/sounds/close_right_panel.wav"),
	SOUND_PAN_LEFT: preload("res://assets/sounds/pan_left.wav"),
	SOUND_PAN_RIGHT: preload("res://assets/sounds/pan_right.wav"),
	SOUND_SETTINGS_TOGGLE: preload("res://assets/sounds/settings_toggle.wav"),
	SOUND_ZOOM_IN: preload("res://assets/sounds/zoom_in.wav"),
	SOUND_ZOOM_OUT: preload("res://assets/sounds/zoom_out.wav"),
}

var host: Node = null
var enabled := false
var _player: AudioStreamPlayer


func configure(next_host: Node) -> void:
	host = next_host


func setup() -> void:
	if host == null or _player != null:
		return
	_player = AudioStreamPlayer.new()
	_player.name = "UISoundPlayer"
	_player.bus = "Master"
	host.add_child(_player)


func set_enabled(next_enabled: bool) -> void:
	enabled = next_enabled


func play(sound_id: String) -> void:
	if not enabled or _player == null:
		return
	var stream: AudioStream = SOUND_STREAMS.get(sound_id)
	if stream == null:
		return
	_player.stop()
	_player.stream = stream
	_player.play()
