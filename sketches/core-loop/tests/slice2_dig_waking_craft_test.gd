extends SceneTree

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossHarness := preload("res://tests/doubles/boss_harness.gd")
const ModuleHarness := preload("res://tests/doubles/module_harness.gd")
const EnemyBossCraft := preload("res://src/presentation/craft/enemy_boss_craft.gd")
const DigScenery := preload("res://src/presentation/dig_scenery.gd")
const WardenSwarm := preload("res://src/combat/warden_swarm.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const Comfort := preload("res://src/core/comfort.gd")

var t := T.new("slice2_dig_waking_craft_test")


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for _i in n:
		await physics_frame


func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 2000.0), roundi(v.y * 2000.0), roundi(v.z * 2000.0)]


func _audit_mesh(mesh: ArrayMesh, label: String, closed := true) -> void:
	var open_edges := 0
	var non_manifold := 0
	var degenerate := 0
	var bad_wind := 0
	var has_uv := true
	var has_tan := true
	var has_col := true
	var tri_total := 0
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs = arrays[Mesh.ARRAY_TEX_UV]
		var tans = arrays[Mesh.ARRAY_TANGENT]
		var cols = arrays[Mesh.ARRAY_COLOR]
		var ix = arrays[Mesh.ARRAY_INDEX]
		has_uv = has_uv and uvs != null and (uvs as PackedVector2Array).size() == vs.size()
		has_tan = has_tan and tans != null and (tans as PackedFloat32Array).size() == vs.size() * 4
		has_col = has_col and cols != null and (cols as PackedColorArray).size() == vs.size()
		var edges := {}
		var count: int = ix.size() if ix != null else vs.size()
		for k in range(0, count, 3):
			var i0: int = ix[k] if ix != null else k
			var i1: int = ix[k + 1] if ix != null else k + 1
			var i2: int = ix[k + 2] if ix != null else k + 2
			var a: Vector3 = vs[i0]
			var b: Vector3 = vs[i1]
			var c: Vector3 = vs[i2]
			var cross := (b - a).cross(c - a)
			if cross.length_squared() < 1e-12:
				degenerate += 1
				continue
			tri_total += 1
			var navg := (ns[i0] + ns[i1] + ns[i2]).normalized()
			if cross.dot(navg) > 0.0:
				bad_wind += 1
			var keys := [_vkey(a), _vkey(b), _vkey(c)]
			for e in 3:
				var u: String = keys[e]
				var v: String = keys[(e + 1) % 3]
				var ek := (u + "|" + v) if u < v else (v + "|" + u)
				edges[ek] = int(edges.get(ek, 0)) + 1
		if closed:
			for c_val in edges.values():
				var cnt := int(c_val)
				if cnt == 1:
					open_edges += 1
				elif cnt > 2:
					non_manifold += 1
	var detail := "tris=%d open=%d nm=%d deg=%d wind=%d uv=%s tan=%s col=%s" % [tri_total, open_edges, non_manifold, degenerate, bad_wind, has_uv, has_tan, has_col]
	t.check("%s topology valid" % label, tri_total > 0 and open_edges == 0 and non_manifold == 0 and degenerate == 0 and bad_wind == 0 and has_uv and has_tan and has_col, detail)


func _check_meshes() -> void:
	_audit_mesh(EnemyBossCraft.reward_canister_shell(0.38, 0.72), "reward_canister_shell")
	_audit_mesh(EnemyBossCraft.reward_canister_band(0.405, 0.12), "reward_canister_band")
	_audit_mesh(EnemyBossCraft.reward_scrap_fallback(0.7), "reward_scrap_fallback")
	_audit_mesh(EnemyBossCraft.brindle_scooter_hull(Vector3(2.0, 1.0, 2.8)), "brindle_scooter_hull")
	_audit_mesh(EnemyBossCraft.admirals_crest_badge(0.5, 0.14), "admirals_crest_badge")
	_audit_mesh(EnemyBossCraft.dig_cable_coupler(0.48), "dig_cable_coupler")
	_audit_mesh(EnemyBossCraft.dig_cable_segment(0.42, 0.24, 1.0), "dig_cable_segment")
	_audit_mesh(EnemyBossCraft.dig_skylight_collar(6.0), "dig_skylight_collar")
	_audit_mesh(EnemyBossCraft.dig_skylight_beam(6.0, 14.0, 46.0), "dig_skylight_beam", false)
	_audit_mesh(EnemyBossCraft.swarm_pool_disc(40.0, 1.0), "swarm_pool_disc")
	_audit_mesh(EnemyBossCraft.waking_arena_pad(36.0, 2.0), "waking_arena_pad")
	_audit_mesh(EnemyBossCraft.pit_jaw_fallback_mesh(1.5, 0.12), "pit_jaw_fallback_mesh")
	_audit_mesh(EnemyBossCraft.burrow_marker_mesh(1.6, 0.05), "burrow_marker_mesh")
	_audit_mesh(EnemyBossCraft.swarm_remnant_body(0.75, 0.22), "swarm_remnant_body")
	_audit_mesh(EnemyBossCraft.swarm_remnant_seam(0.41, 0.24), "swarm_remnant_seam")
	_audit_mesh(EnemyBossCraft.ramp_flipper_plate(Vector3(5.76, 0.18, 5.76)), "ramp_flipper_plate")

	var pad_mesh := EnemyBossCraft.waking_arena_pad(36.0, 2.0)
	var vs: PackedVector3Array = pad_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var flat_ok := true
	for v in vs:
		if v.y > 0.99 and Vector2(v.x, v.z).length() < 35.8:
			flat_ok = flat_ok and is_equal_approx(v.y, 1.0)
	t.check("waking_arena_pad top deck stays strictly flat at y=1.0", flat_ok)


func _check_runtime() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.flow.force_warden = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await _frames(6)

	game.flow.enter_stage(3, Vector3.ZERO, false)
	await _frames(10)
	var pit_root: Node3D = game.ctx.terrain.geometry_root(3)
	var pit_scenery := pit_root.get_node_or_null("DigScenery")
	var pit_prims := 0
	var pit_pulses := 0
	if pit_scenery != null:
		for mi: MeshInstance3D in pit_scenery.find_children("*", "MeshInstance3D", true, false):
			if String(mi.name).begins_with("CablePulse_"):
				pit_pulses += 1
				if mi.mesh is PrimitiveMesh:
					pit_prims += 1
				t.check("CablePulse positive basis det", mi.global_transform.basis.determinant() > 0.0)
	t.check("park_pit upgrades CablePulse couplers with zero PrimitiveMesh", pit_pulses >= 10 and pit_prims == 0, "pulses=%d prims=%d" % [pit_pulses, pit_prims])

	game.flow.enter_stage(4, Vector3.ZERO, false)
	await _frames(10)
	var sink_root: Node3D = game.ctx.terrain.geometry_root(4)
	var sink_scenery := sink_root.get_node_or_null("DigScenery")
	var shaft_count := 0
	var sink_prim_count := 0
	if sink_scenery != null:
		for mi: MeshInstance3D in sink_scenery.find_children("*", "MeshInstance3D", true, false):
			var n := String(mi.name)
			if n.begins_with("SkylightShaft_"):
				shaft_count += 1
				if mi.mesh is PrimitiveMesh:
					sink_prim_count += 1
			elif n.begins_with("CablePulse_") and mi.mesh is PrimitiveMesh:
				sink_prim_count += 1
	t.check("park_sinkhole SkylightShafts and CablePulses built with zero PrimitiveMesh",
		shaft_count == 6 and sink_prim_count == 0,
		"shafts=%d prims=%d" % [shaft_count, sink_prim_count])

	var s4_warden = game.flow.warden
	if t.check("stage 4 sinkhole warden spawns", is_instance_valid(s4_warden) and s4_warden.mounting == WardenSwarm.SINKHOLE):
		var slab: Node3D = s4_warden.mount_driver._slab
		var pool_mesh := slab.get_node_or_null("SwarmPoolMesh") as MeshInstance3D if is_instance_valid(slab) else null
		t.check("SwarmPoolFloor uses sculpted ArrayMesh and ShaderMaterial",
			pool_mesh != null and pool_mesh.mesh is ArrayMesh and pool_mesh.material_override is ShaderMaterial)

	var dig_fx = sink_scenery.get_node_or_null("DigFx") if sink_scenery != null else null
	if dig_fx != null and not dig_fx.cable_pulses.is_empty():
		Comfort.reduced_motion = true
		dig_fx._clock = 1.25
		dig_fx._tick_wayfinding_fx()
		var calm_scale: Vector3 = (dig_fx.cable_pulses[0]["node"] as MeshInstance3D).scale
		t.check("DigFx reduced_motion keeps CablePulse scale steady at 1.0", calm_scale.is_equal_approx(Vector3.ONE))
		Comfort.reduced_motion = false

	ModuleHarness.enter_world(game, 2)
	await _frames(6)
	var waking_mod = ModuleHarness.module(game, 2)
	var waking_pad_prims := 0
	var waking_bodies: Array = [waking_mod.pad] + waking_mod._floor_bodies.values()
	for body in waking_bodies:
		for child in body.get_children():
			if child is MeshInstance3D and child.mesh is PrimitiveMesh:
				waking_pad_prims += 1
	t.eq("Waking arena pads have zero CylinderMesh primitives", waking_pad_prims, 0)
	var dress = waking_mod._arena_dress
	if t.check("ArenaWakingDress active", dress != null):
		var lamp_pools: Array = dress.find_children("LampPool*", "OmniLight3D", true, false)
		var culled_lamps: Array = lamp_pools.filter(func(l: OmniLight3D): return l.distance_fade_enabled and l.distance_fade_begin >= 50.0 and l.distance_fade_begin <= 68.0)
		t.eq("All 32 LampPool OmniLight3Ds enable Forward+ distance fade tuned for 60m shaft", culled_lamps.size(), 32)
		var active_at_cam := 0
		var cam_probe: Vector3 = waking_mod._floor_bodies[1].global_position + Vector3(0.0, 10.0, 26.0)
		for l: OmniLight3D in lamp_pools:
			if l.global_position.distance_to(cam_probe) <= l.distance_fade_begin + l.distance_fade_length:
				active_at_cam += 1
		t.check("Waking camera frustum lights near wall (>= 8) while culling opposite wall (<= 26)", active_at_cam >= 8 and active_at_cam <= 26, "active_lamps=%d" % active_at_cam)
		var cut_faces: Node = dress.get_node_or_null("ShaftCutFaces")
		var cut_culled := true
		for view: MultiMeshInstance3D in cut_faces.get_children():
			cut_culled = cut_culled and view.visibility_range_end > 0.0 and view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.check("ShaftCutFaces enables visibility_range_end and disables shadow casting", cut_culled)
	waking_mod.exit_arena()

	game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(6)
	game.ctx.spawner = game.combat
	BossHarness.enter(game, Vector3(18.0, 0.0, 0.0))
	await _frames(6)
	var boss = game.boss
	var ship = boss.ship
	var at: Vector3 = boss.arena.point_at(0.4, 22.0, 0.9)
	boss._spawn_pickup(at, 10, "spill")
	boss._spawn_pickup(at + Vector3(2.0, 0.0, 0.0), 8, "returned")
	var reward: Node3D = boss._pickups[-2]["node"]
	var reward2: Node3D = boss._pickups[-1]["node"]
	var canister := reward.find_child("RewardCanister", false, false) as MeshInstance3D
	var band := canister.find_child("BoneBand", false, false) as MeshInstance3D if canister != null else null
	var canister2 := reward2.find_child("RewardCanister", false, false) as MeshInstance3D
	var band2 := canister2.find_child("BoneBand", false, false) as MeshInstance3D if canister2 != null else null
	t.check("Live Slag Bowl RewardCanister and BoneBand use sculpted ArrayMesh with zero PrimitiveMesh on multiple pickups",
		canister != null and canister.mesh is ArrayMesh and band != null and band.mesh is ArrayMesh and band.material_override != null and band.material_override.next_pass != null
		and canister2 != null and canister2.mesh is ArrayMesh and band2 != null and band2.mesh is ArrayMesh and band2.material_override != null and band2.material_override.next_pass != null)

	var armour0 := ship.model.find_child("Armour0", true, false) as MeshInstance3D if ship.model != null else null
	var armour0_s0 := armour0.get_surface_override_material(0) if armour0 != null else null
	var armour0_s1 := armour0.get_surface_override_material(1) if armour0 != null else null
	ship.trigger_strike_flash()
	t.check("FX-27 Brindle hull strike flash activates cleanly", ship.strike_flashing())
	if armour0 != null:
		t.check("FX-27 hull flash leaves Armour0 surfaces untouched (W1-48)",
			armour0.get_surface_override_material(0) == armour0_s0 and armour0.get_surface_override_material(1) == armour0_s1)
	for _i in 30:
		ship._physics_process(0.02)
	t.check("FX-27 hull strike flash decays back to idle", not ship.strike_flashing())

	FlashGuard.on = true
	ship.trigger_strike_flash()
	t.check("FX-27 hull strike flash respects FlashGuard duration reduction", ship.strike_flashing() and ship._strike_flash_duration < 0.20)
	FlashGuard.on = false
	for _i in 30:
		ship._physics_process(0.02)

	boss._sync_crest()
	game.run.add_part("admirals_crest", "boss")
	boss._sync_crest()
	var crest: Node3D = boss.crest()
	var badge := crest.get_node_or_null("AdmiralsCrestBadge") as MeshInstance3D if crest != null else null
	t.check("AdmiralsCrest uses sculpted ArrayMesh and ShaderMaterial",
		badge != null and badge.mesh is ArrayMesh and badge.material_override is ShaderMaterial)
	boss.exit_arena()

	game.free()
	EnemyBossCraft.reset_for_tests()


func _run() -> void:
	_check_meshes()
	await _check_runtime()
	quit(t.verdict())
