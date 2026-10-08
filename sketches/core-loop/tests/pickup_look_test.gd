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
	var brindle: Node3D = game.ctx.boss._pickups[0].node
	var canister := brindle.find_child("RewardCanister", false, false) as MeshInstance3D
	_pickup(canister.material_override, Palette.AMBER, "Brindle")
	var reward_material := canister.material_override as ShaderMaterial
	t.check("Brindle reward body is amber", reward_material != null
		and reward_material.get_shader_parameter("glow_color") == Palette.AMBER
		and (canister.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_COLOR][0] == Palette.AMBER)
	t.check("Brindle reward uses the shared field shader", canister.material_override is ShaderMaterial
		and reward_material.shader.resource_path == SHADER
		and reward_material.get_shader_parameter("glow_color") == Palette.AMBER)
	t.check("Brindle reward uses a canister silhouette", brindle.name == "BrindleReward"
		and canister != null and canister.mesh is ArrayMesh
		and canister.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size() > 0)
	t.check("Brindle reward has a bone band", brindle.find_child("BoneBand", true, false) is MeshInstance3D)
	var rested_y := brindle.position.y
	t.near("Brindle reward has zero vertical hover offset", rested_y, 3.1)
	var reward_aabb := canister.mesh.get_aabb()
	t.near("Brindle reward bottom sits on ground", canister.global_position.y
		+ reward_aabb.position.y * canister.scale.y * brindle.scale.y, 3.1, 0.05)
	t.check("Brindle reward is readable at arena distance", reward_aabb.size.y * canister.scale.y * brindle.scale.y >= 0.5)
	game.ctx.boss._step_trail(Vector3(200, 200, 200))
	t.near("Brindle reward has zero hover offset", brindle.position.y, rested_y)
	t.check("Brindle reward remains grounded after a field tick", is_equal_approx(brindle.position.y, rested_y))
	var vault = game.ctx.spawner.spawn_enemy("vault", Vector3(0, 30, 0))
	var lamp := vault.find_child("VaultLamp", true, false) as MeshInstance3D
	t.check("vault has its modelled lamp", lamp != null)
	if lamp != null:
		var material := lamp.get_active_material(0) as StandardMaterial3D
		t.check("vault lamp reads as lit amber while locked", material != null
			and material.albedo_color.is_equal_approx(Palette.AMBER)
			and material.emission.is_equal_approx(Palette.AMBER)
			and material.emission_enabled and material.emission_energy_multiplier > 0.0)
	var hatches := 0
	for side in 4:
		var hatch: Node = vault.find_child("VaultHatch%d" % side, true, false)
		hatches += 1 if hatch is Node3D else 0
	t.eq("vault has four hatch rings", hatches, 4)
	t.check("vault combines hatches into one charcoal draw", vault.find_child("VaultHatches", true, false) is MeshInstance3D)
	t.check("vault adds no per-instance light", vault.find_children("*", "Light3D", true, false).is_empty())
	vault.hp = 1.0
	game.combat.strike(vault, "runner", 10.0)
	t.check("vault opening extinguishes the lamp", vault._opened and vault._lamp_material.emission_energy_multiplier == 0.0)
	t.check("vault open cue drops the hatch ring", vault._hatch_model.position.y < 0.0)
	game.free()
	quit(t.verdict())
