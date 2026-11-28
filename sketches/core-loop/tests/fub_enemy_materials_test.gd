extends SceneTree

const T := preload("res://tests/support/t.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const ENEMIES := ["anchor_crew", "bola_thrower", "burrower", "catch_trap", "chaser", "deflector", "drill_crew", "gyro_jammer", "hooker", "kite_drone", "lamp_swarm", "line_cutter", "lobber", "mag_trapper", "netcaster", "plated_brute", "ramp_flipper", "reactor_relic", "swatter", "winch_drone"]
var fixtures: Array[PackedScene] = []

func _initialize() -> void:
	var t := T.new("fub_enemy_materials_test")
	for enemy in ENEMIES:
		var script = load("res://src/combat/%s.gd" % enemy)
		var text := FileAccess.get_file_as_string("res://src/combat/%s.gd" % enemy)
		var regex := RegEx.new()
		regex.compile("res://assets/models/[^\"]+\\.glb")
		var path := regex.search(text).get_string()
		var original := load(path) as PackedScene
		var scene := original.instantiate()
		for view: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
			view.mesh = view.mesh.duplicate()
			for surface in view.mesh.get_surface_count():
				view.mesh.surface_set_material(surface, null)
		var packed := PackedScene.new()
		packed.pack(scene)
		scene.free()
		packed.take_over_path(path)
		fixtures.append(packed)
		if enemy == "lamp_swarm":
			var node = script.new()
			node._crew = MeshInstance3D.new()
			node.add_child(node._crew)
			node._material = PaletteMaterials.solid(Color.WHITE)
			node._build_tool()
			t.eq("lamp swarm builds without surface materials", node.lamps.size(), node.LAMP_COUNT)
			node.free()
		else:
			var parts = script._parts()
			t.check(enemy + " handles material-less surfaces", parts != null and (not parts.is_empty() or enemy == "ramp_flipper"))
			t.check(enemy + " repeats cached result", script._parts() == parts)
	quit(t.verdict())
