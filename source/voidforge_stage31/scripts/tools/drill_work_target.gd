class_name DrillWorkTarget
extends StaticBody3D
## Stage 31 non-deforming development target. Stage 32 replaces this with mineable asteroid material.

signal drill_work_received(amount: float, total_work: float)

@export var target_display_name: String = "Bore Calibration Stone"
@export_range(1.0, 10000.0, 0.1) var calibration_work_goal: float = 100.0
@export var accepts_drilling: bool = true

var total_drill_work: float = 0.0

func can_receive_drill_work(_source: Node = null) -> bool:
	return accepts_drilling

func apply_drill_work(amount: float, _source: Node = null) -> float:
	if not accepts_drilling or amount <= 0.0:
		return 0.0
	total_drill_work += amount
	drill_work_received.emit(amount, total_drill_work)
	return amount

func get_drill_target_name() -> String:
	return target_display_name

func get_drill_progress() -> float:
	return clampf(total_drill_work / maxf(calibration_work_goal, 0.001), 0.0, 1.0)

func reset_drill_work() -> void:
	total_drill_work = 0.0
