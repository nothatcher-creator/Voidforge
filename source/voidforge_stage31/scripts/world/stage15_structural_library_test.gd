extends Node3D
## Active Stage 15 wrapper. Retains the playable Stage 14 slice and adds production
## structural galleries for both large/static-scale and small-grid content.

const LARGE_BLOCK_IDS: Array[StringName] = [
	&"frame_lattice_large",
	&"frame_reinforced_large",
	&"beam_long_large",
	&"pillar_tall_large",
	&"panel_service_large",
	&"grate_walkway_large",
	&"armor_shell_light_large",
	&"armor_shell_heavy_large",
	&"armor_wedge_large",
	&"armor_corner_large",
	&"armor_buttress_large",
]
const SMALL_BLOCK_IDS: Array[StringName] = [
	&"frame_spar_small",
	&"frame_truss_small",
	&"panel_service_small",
	&"armor_shell_small",
]

@onready var large_gallery: Node3D = $LargeStructuralGallery
@onready var small_gallery: Node3D = $SmallStructuralGallery
@onready var build_controller: Node3D = $Stage14BlockDatabaseTest/Stage13GridSaveLoadTest/Stage12BlockRemovalTest/Stage11BlockRotationTest/Stage10BlockPlacementTest/Stage9GridTest/Stage8HotbarTest/Stage5InteractionTest/Stage3PlayerMovementTest/FirstPersonPlayer/BuildController

func _ready() -> void:
	_seed_gallery(large_gallery, LARGE_BLOCK_IDS)
	_seed_gallery(small_gallery, SMALL_BLOCK_IDS)
	if build_controller != null:
		build_controller.call("set_build_block_id", &"frame_lattice_large")
		build_controller.call("reset_orientation")
	var large_errors := large_gallery.call("get_integrity_errors") as Array if large_gallery != null else ["Large gallery missing"]
	var small_errors := small_gallery.call("get_integrity_errors") as Array if small_gallery != null else ["Small gallery missing"]
	if large_errors.is_empty() and small_errors.is_empty():
		DebugLog.info(
			"Stage15Test",
			"Structural library active | %d production blocks | %d large-gallery + %d small-gallery" % [
				LARGE_BLOCK_IDS.size() + SMALL_BLOCK_IDS.size(),
				int(large_gallery.call("get_block_count")),
				int(small_gallery.call("get_block_count")),
			]
		)
	else:
		DebugLog.error("Stage15Test", "Structural gallery integrity failed: %s | %s" % [str(large_errors), str(small_errors)])

func _seed_gallery(grid: Node3D, block_ids: Array[StringName]) -> void:
	if grid == null:
		return
	if int(grid.call("get_block_count")) > 0:
		return
	var cursor_x := 0
	for block_id in block_ids:
		var definition := BlockDB.call("get_block", block_id) as Resource
		if definition == null:
			DebugLog.error("Stage15Test", "Missing production block '%s' while seeding gallery" % String(block_id))
			continue
		var instance := grid.call("place_block", definition, Vector3i(cursor_x, 0, 0), 0) as Resource
		if instance == null:
			DebugLog.error("Stage15Test", "Failed to place gallery block '%s'" % String(block_id))
			continue
		cursor_x += Vector3i(definition.get("dimensions_cells")).x + 1
