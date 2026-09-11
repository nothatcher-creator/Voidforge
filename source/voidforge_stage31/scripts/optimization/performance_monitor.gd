extends PanelContainer
## Development-only lightweight performance readout.
## Avoids expensive per-frame enumeration so it can remain enabled on Android test builds.

@export_range(0.1, 2.0, 0.05) var update_interval_seconds: float = 0.25

@onready var stats_label: Label = $StatsLabel

var _sample_time: float = 0.0
var _sample_frames: int = 0

func _ready() -> void:
	_refresh_display(1.0 / 60.0)

func _process(delta: float) -> void:
	_sample_time += delta
	_sample_frames += 1
	if _sample_time < update_interval_seconds:
		return

	var average_delta := _sample_time / float(maxi(_sample_frames, 1))
	_refresh_display(average_delta)
	_sample_time = 0.0
	_sample_frames = 0

func _refresh_display(average_delta: float) -> void:
	if stats_label == null:
		return

	var fps := Engine.get_frames_per_second()
	var frame_ms := average_delta * 1000.0
	var mobile_renderer := str(ProjectSettings.get_setting(
		"rendering/renderer/rendering_method.mobile",
		"unknown"
	))
	stats_label.text = (
		"DEV PERFORMANCE\n"
		+ "FPS: %d\n" % fps
		+ "Frame: %.2f ms\n" % frame_ms
		+ "Renderer: %s\n" % mobile_renderer
		+ "Stage: %d" % GameConfig.BUILD_STAGE
	)
