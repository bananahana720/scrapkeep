extends SceneTree

const Boss := preload("res://src/boss/boss.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t := T.new("fua_boss_pickup_material_test")
	var arena := Node3D.new()
	root.add_child(arena)
	var boss := Boss.new()
	boss.arena = arena
	boss._spawn_pickup(Vector3.ZERO, 7, "spill")
	boss._spawn_pickup(Vector3.RIGHT, 9, "returned")
	var first: MeshInstance3D = boss._pickups[0].node
	var second: MeshInstance3D = boss._pickups[1].node
	t.check("real pickup model loads", first.name == "ScrapChunk" and first.material_override is ShaderMaterial)
	t.check("two boss pickups share one material instance", first.material_override == second.material_override)
	var other_boss := Boss.new()
	other_boss.arena = arena
	other_boss._spawn_pickup(Vector3.LEFT, 1, "kill")
	t.check("material is shared across boss instances", first.material_override == other_boss._pickups[0].node.material_override)
	var mat := first.material_override as ShaderMaterial
	if mat != null:
		t.eq("shared material keeps field slot", mat.resource_name, "field")
		t.eq("shared material keeps mint glow", mat.get_shader_parameter("glow_color"), Palette.ARC)
		t.near("shared material keeps face energy", mat.get_shader_parameter("face_energy"), 0.06)
		t.near("shared material keeps rim energy", mat.get_shader_parameter("rim_energy"), 1.25)
		t.near("shared material keeps emission ceiling", mat.get_shader_parameter("emission_ceiling"), 1.35)
	boss.free()
	other_boss.free()
	arena.free()
	quit(t.verdict())
