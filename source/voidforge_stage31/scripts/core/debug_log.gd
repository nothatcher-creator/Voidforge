extends Node
## Lightweight file + console logger intended to remain safe in offline Android builds.

const LOG_DIR: String = "user://logs"
const LOG_PATH: String = "user://logs/voidforge.log"
const PREVIOUS_LOG_PATH: String = "user://logs/voidforge.previous.log"
const MAX_LOG_BYTES: int = 1_048_576

var _file: FileAccess
var _session_started: bool = false

func _ready() -> void:
	_initialize()

func info(scope: String, message: String) -> void:
	_write("INFO", scope, message)

func warn(scope: String, message: String) -> void:
	_write("WARN", scope, message)
	push_warning("[%s] %s" % [scope, message])

func error(scope: String, message: String) -> void:
	_write("ERROR", scope, message)
	push_error("[%s] %s" % [scope, message])

func _initialize() -> void:
	if _session_started:
		return
	_session_started = true
	var absolute_log_dir := ProjectSettings.globalize_path(LOG_DIR)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_log_dir)
	if dir_error != OK and dir_error != ERR_ALREADY_EXISTS:
		push_error("[DebugLog] Could not create log directory. Error: %s" % dir_error)
		return
	_rotate_if_needed()
	var open_mode := FileAccess.READ_WRITE if FileAccess.file_exists(LOG_PATH) else FileAccess.WRITE_READ
	_file = FileAccess.open(LOG_PATH, open_mode)
	if _file == null:
		push_error("[DebugLog] Could not open log file. Error: %s" % FileAccess.get_open_error())
		return
	_file.seek_end()
	_write("INFO", "DebugLog", "Session started | %s | stage %d" % [GameConfig.BUILD_VERSION, GameConfig.BUILD_STAGE])

func _rotate_if_needed() -> void:
	if not FileAccess.file_exists(LOG_PATH):
		return
	var current := FileAccess.open(LOG_PATH, FileAccess.READ)
	if current == null:
		return
	var should_rotate := current.get_length() >= MAX_LOG_BYTES
	current.close()
	if not should_rotate:
		return
	if FileAccess.file_exists(PREVIOUS_LOG_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PREVIOUS_LOG_PATH))
	DirAccess.rename_absolute(
		ProjectSettings.globalize_path(LOG_PATH),
		ProjectSettings.globalize_path(PREVIOUS_LOG_PATH)
	)

func _write(level: String, scope: String, message: String) -> void:
	if not _session_started:
		_initialize()
	var timestamp := Time.get_datetime_string_from_system(false, true)
	var line := "%s | %-5s | %-16s | %s" % [timestamp, level, scope, message]
	print(line)
	if _file != null:
		_file.store_line(line)
		_file.flush()
