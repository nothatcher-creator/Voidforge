extends Node
## Global build/runtime constants for VOIDFORGE.
## Keep hard limits here; player-facing tunables will move to settings resources later.

const GAME_NAME: String = "Voidforge"
const PROJECT_CODENAME: String = "VOIDFORGE"
const BUILD_STAGE: int = 31
const BUILD_VERSION: String = "0.0.31-stage31"
const SAVE_FORMAT_VERSION: int = 1
const TARGET_ENGINE: String = "Godot 4.7.2"

const BASE_VIEWPORT_SIZE: Vector2i = Vector2i(1280, 720)
const DEFAULT_TARGET_FPS: int = 60
const MOBILE_PHYSICS_TPS: int = 60

# Early mobile safety budgets. These are intentionally conservative and will be profiled later.
const MAX_ACTIVE_RIGID_BODIES: int = 96
const MAX_ACTIVE_DEBRIS: int = 64
const MAX_POOLED_PROJECTILES: int = 128
const DEFAULT_SIMULATION_RADIUS_M: float = 2000.0
const DEFAULT_SECTOR_EDGE_M: float = 10000.0

const GRID_SMALL: StringName = &"small"
const GRID_LARGE: StringName = &"large"
const GRID_STATIC: StringName = &"static"

const DATA_ROOT: String = "res://data"
const USER_SAVE_ROOT: String = "user://saves"
const USER_LOG_ROOT: String = "user://logs"

func _ready() -> void:
	Engine.max_fps = DEFAULT_TARGET_FPS
