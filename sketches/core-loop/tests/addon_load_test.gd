extends SceneTree

const T := preload("res://tests/support/t.gd")

# Collision mode the test asks of Terrain3D. Park terrain is visual only (TADR-011): the
# trimesh collider is ours, so this stays 0 (Terrain3DCollision.DISABLED).
const COLLISION_MODE := 0

# Wave 13 KB1: Terrain3D v1.0.2 loads headless from the vendored copy, with collision off
# and no editor plugin entry. Plain region of 64 m, one pixel per metre, no sketch code.


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("addon_load_test")
	t.check("Terrain3D class registered", ClassDB.class_exists("Terrain3D"))
	t.check("Terrain3DTextureAsset class registered", ClassDB.class_exists("Terrain3DTextureAsset"))
	var project := FileAccess.get_file_as_string("res://project.godot")
	t.check("no [editor_plugins] entry for the addon", project.find("terrain_3d") == -1 and project.find("[editor_plugins]") == -1)
	var holder := Node3D.new()
	root.add_child(holder)
	var terrain: Node3D = ClassDB.instantiate("Terrain3D")
	terrain.region_size = 64
	holder.add_child(terrain)
	terrain.collision.mode = COLLISION_MODE
	var height := Image.create_empty(64, 64, false, Image.FORMAT_RF)
	for j in 64:
		for i in 64:
			height.set_pixel(i, j, Color(float(i) * 0.5, 0.0, 0.0, 1.0))
	terrain.data.import_images([height, null, null], Vector3(0.0, 0.0, 0.0), 0.0, 1.0)
	t.eq("one region imported", terrain.data.get_region_count(), 1)
	t.eq("visual only: collision disabled", int(terrain.collision.mode), 0)
	var got: float = terrain.data.get_height(Vector3(10.0, 0.0, 10.0))
	t.check("region height reads back", absf(got - 5.0) < 0.01, "got %.4f, want 5.0" % got)
	holder.queue_free()
	await process_frame
	quit(t.verdict())
