extends SceneTree

const Game := preload("res://src/game.gd")
const Field := preload("res://src/build/scrap_field.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")
const SHADER := "res://assets/shaders/pickup.gdshader"

var t := T.new("pickup_look_test")


func _initialize() -> void:
	_run.call_deferred()


func _pickup(material: Material, color: Color, label: String) -> void:
	var mat := material as ShaderMaterial
	t.check(label + " vertex paint with bounded rim emission", mat != null,
		"pickup must use the opaque vertex-colour rim shader")
	if mat == null:
		return
	t.check(label + " shared pickup shader", mat.shader != null and mat.shader.resource_path == SHADER)
	t.eq(label + " palette glow", mat.get_shader_parameter("glow_color"), color)
	t.near(label + " face emission", mat.get_shader_parameter("face_energy"), 0.06)
	t.near(label + " rim emission", mat.get_shader_parameter("rim_energy"), 1.25)
	t.near(label + " emission ceiling", mat.get_shader_parameter("emission_ceiling"), 1.35)
	var code := mat.shader.code
	t.check(label + " original opaque painted faces", code.contains("ALBEDO = COLOR.rgb;")
		and not code.contains("ALPHA") and not code.contains("unshaded") and not code.contains("void vertex"))
	t.check(label + " view-dependent glow with a ceiling", code.contains("dot(normalize(NORMAL), normalize(VIEW))")
		and code.contains("EMISSION = glow_color.rgb * min(") and code.contains("emission_ceiling"))
	t.check(label + " gentle pulse cannot extinguish rim", code.contains("0.9 + 0.1 * sin(TIME * 2.0)"))


func _run() -> void:
	var field := Field.new()
	root.add_child(field)
	field.setup()
	for i in 32:
		var item := field._add(Vector3(i * 1.37, 1.4, i * 0.41))
		_pickup(item.material_override, Palette.ARC, "scrap %d" % i)
	var recovery := field._add(Vector3.ZERO, field._cluster_mesh, field._cluster_material)
	_pickup(recovery.material_override, Palette.AMBER, "recovery")
	field.free()
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.ctx.calm = true
	var arena := Node3D.new()
	game.add_child(arena)
	game.ctx.boss.arena = arena
	game.ctx.boss._spawn_pickup(Vector3(3, 4, 5), 7, "spill")
	_pickup(game.ctx.boss._pickups[0].node.material_override, Palette.ARC, "Brindle")
	var vault = game.ctx.spawner.spawn_enemy("vault", Vector3(0, 30, 0))
	var lamp := vault.find_child("VaultLamp", true, false) as MeshInstance3D
	t.check("vault has its modelled lamp", lamp != null)
	if lamp != null:
		var material := lamp.mesh.surface_get_material(0) as StandardMaterial3D
		t.check("vault lamp retains palette bone with emission ceiling", material != null
			and material.albedo_color.is_equal_approx(Palette.SAND)
			and material.emission.is_equal_approx(Palette.SAND)
			and material.emission_enabled and material.emission_energy_multiplier > 0.0
			and material.emission_energy_multiplier <= 0.35,
			"bone lamp emission must be positive and at most 0.35")
	game.free()
	quit(t.verdict())
