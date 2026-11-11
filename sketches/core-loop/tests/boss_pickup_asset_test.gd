extends SceneTree

const Game := preload("res://src/game.gd")
const Boss := preload("res://src/boss/boss.gd")
const Palette := preload("res://src/core/palette.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const GLB := "res://assets/models/bosses/boss_pickup.glb"
# Re-pinned 2026-10-09 (BUGFIX-BOSS F001): _cancel_hazards now drips out scrap a magnet
# still holds when phase 1 ends, which only phase 1 used to pay back; pickup meshes unchanged.
# Re-pinned 2026-10-17 (boss phase moments): phase 3 entry passes enter_scuttle to cockpit_open,
# so the model's shield flips with the clip before it hides; pickup meshes unchanged.
# Re-pinned 2026-10-18 (#94 reduce flashes): the crane warning glow pulses at FlashGuard.rate,
# so the Reduce flashes toggle slows it; pickup meshes unchanged. Was 5f85f822.
# Re-pinned 2026-10-19 (Challenge C3a dials): Brindle's damage, cadence, tell, punish and combo read
# ChallengeDials, identical at the defaults (run_tier_test); pickup meshes unchanged. Was 8ec6e239.
# Re-pinned 2026-10-23 (boss phases, #391): the Furnace reprise, the Scuttle hook turn and the transition
# beat (fight_phases.gd); pickup meshes unchanged. Was bdc7f158.
# Re-pinned 2026-10-27 (world 1 hitches): enter_arena takes the bowl the beacon built ahead
# (Arena.take_ahead) instead of building it on the entry frame; pickup meshes unchanged. Was 3b589a48.
# Re-pinned 2026-10-28 (ruling aw): take_spill lands an armour hit's spill in the bowl as shed piles
# through _spawn_pickup, paid back by recover_mass; pickup meshes unchanged. Was e6d147b7.
# Re-pinned 2026-10-29 (bowl tail): pickups_left names each pile's source so the bot can tell shed
# armour from the rest; pickup meshes unchanged. Was 36c7a9ba.
# Re-pinned 2026-10-30 (w28 cautious red team): the slag and charge hits, and the hazard step after a
# killing slag ring, return when their damage ended the run, so a death to Brindle reads no torn-down
# arena; pickup meshes unchanged. Was e34f3fd2.
# Re-pinned 2026-11-08 (state-machine audit, #616): drone pads clear at a phase turn and the phase 3
# charge states are named constants with an unknown-state fallback; pickup meshes unchanged. Was acf817b9.
# Re-pinned 2026-11-09 (objective plate): plate_reading hands the HUD the phase and whether the cockpit
# is open, read-only; pickup meshes unchanged. Was 5121cd32.
# Re-pinned 2026-11-09 (charge fling, #639): the hull turns onto a charge's heading through the tell instead
# of snapping at the commit, and the Scuttle counts short tries for its hint; pickup meshes unchanged. Was 059a4a6d.
# Re-pinned 2026-11-09 (ruling bs, held floor bank, #660): hits on a held hull bank toward the next phase's bar
# (banking, bank_cap, _bank); pickup meshes unchanged. Was b8cc7630.
# Re-pinned 2026-11-10 (first-timer film, PF-17 and PF-18): plate_reading no longer calls the cockpit open while a
# Scuttle charge is committed (charge_coming), and plate_targets hands the HUD the places the plate's row
# names; both read-only, no hit or warning changes; pickup meshes unchanged. Was 894f3522.
# Re-pinned 2026-11-09 (one call places the ball): the intro and the rescue place the ball with reset_to
# alone, no write to its body after; pickup meshes unchanged. Was 894f3522.
# Re-pinned 2026-11-10 (w33 gate, stacking #709 onto #708): both changes in boss.gd together. Was 51880956 (#708) / 8cfc6e3b (#709).
# Re-pinned 2026-11-10 (second first-timer film, PF-17): plate_targets names each thing it marks ({at, what});
# pickup meshes unchanged. Was 2304483c.
# Re-pinned 2026-11-11 (w36 gate, arena fix 101d6001): a dropped lobber stops its physics tick when the
# arena is left, so it never ticks against the removed bowl; pickup meshes unchanged. Was 9165b6e4.
const BASE_LOGIC_SHA := "2381fc95e181c32c6ae7981029b66c31496aeb00e2fd5c4de60eff89d967e0dc"

var failures := 0
var game


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _finish() -> void:
	print("boss_pickup_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	if game != null:
		game.free()
	quit(0 if failures == 0 else 1)


func _measure(node: Node3D) -> Dictionary:
	var tris := 0
	var vertices := 0
	var draws := 0
	var primitive := 0
	var opaque := true
	var low := Vector3(INF, INF, INF)
	var high := -low
	var meshes := node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		meshes.append(node)
	for found in meshes:
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			opaque = false
			continue
		if mi.mesh is PrimitiveMesh:
			primitive += 1
		var xf := mi.transform
		var ancestor := mi.get_parent()
		while ancestor != node and ancestor is Node3D:
			xf = ancestor.transform * xf
			ancestor = ancestor.get_parent()
		if mi == node:
			xf = Transform3D.IDENTITY
		for s in mi.mesh.get_surface_count():
			draws += 1
			var arrays := mi.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var ix = arrays[Mesh.ARRAY_INDEX]
			vertices += vs.size()
			tris += (ix.size() if ix != null else vs.size()) / 3
			for v in vs:
				var p: Vector3 = xf * v
				low = low.min(p)
				high = high.max(p)
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mi.material_override
			if mat == null:
				mat = mi.mesh.surface_get_material(s)
			opaque = opaque and mat != null
			if mat is BaseMaterial3D:
				opaque = opaque and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and mat.albedo_color.a >= 0.999
			elif mat is ShaderMaterial:
				opaque = opaque and mat.shader != null and mat.shader.resource_path == "res://assets/shaders/pickup.gdshader" \
					and not mat.shader.code.contains("ALPHA")
			else:
				opaque = false
			if arrays[Mesh.ARRAY_COLOR] != null:
				for c in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
					opaque = opaque and c.a >= 0.999
	return {"tris": tris, "vertices": vertices, "draws": draws, "primitive": primitive,
		"opaque": opaque, "low": low, "high": high}


func _budget(node: Node3D, label: String) -> Dictionary:
	var m := _measure(node)
	print("%s: %d T / %d V / %d D" % [label, m.tris, m.vertices, m.draws])
	_check(m.tris > 0 and m.tris <= 1100 and m.vertices <= 2100 and m.draws > 0 and m.draws <= 3, label + " D3 budget")
	_check(m.opaque, label + " opaque materials")
	return m


func _named(node: Node, expected: Array) -> void:
	var names := []
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		names.append(String(mi.name))
	names.sort()
	_check(names == expected, "exact named mesh parts")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var packed := load(GLB) as PackedScene if ResourceLoader.exists(GLB) else null
	_check(packed != null, "GLB loads")
	if packed == null:
		_finish()
		return
	var scene := packed.instantiate()
	var asset := _budget(scene, "asset")
	_check(asset.tris <= 270 and asset.vertices <= 610 and asset.draws == 1, "single draw prop budget")
	_named(scene, ["ScrapChunk"])
	_check(asset.low.x >= -0.351 and asset.low.y >= -0.351 and asset.low.z >= -0.351
		and asset.high.x <= 0.351 and asset.high.y <= 0.351 and asset.high.z <= 0.351, "scrap inside existing 0.7 m cube")
	scene.free()
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	var boss = game.ctx.boss
	var arena := Node3D.new()
	game.add_child(arena)
	boss.arena = arena
	boss.clock = 0.25
	var at := Vector3(3, 4, 5)
	boss._spawn_pickup(at, 7, "spill")
	var pickup: Node3D = boss._pickups[0].node
	var live := _budget(pickup, "live")
	_check(pickup.name == "BrindleReward" and pickup.find_child("ScrapCore", false, false) is MeshInstance3D
		and pickup.find_child("RewardCanister", false, false) is MeshInstance3D and live.primitive == 1,
		"Brindle keeps a small GLB core inside a procedural canister")
	_check(live.draws == 3, "core, canister and band use three live draws")
	_check(pickup.find_children("*", "CollisionObject3D", true, false).is_empty()
		and pickup.find_children("*", "CollisionShape3D", true, false).is_empty(), "pickup has no collider")
	_check(pickup.global_position.is_equal_approx(Vector3(at.x, at.y - 0.9, at.z))
		and pickup.rotation.is_equal_approx(Vector3.ZERO), "ground placement without hover")
	var record: Dictionary = boss._pickups[0]
	_check(record.value == 7 and record.at == at and record.age == 0.0 and record.source == "spill", "unchanged scrap value and collection record")
	var field := ScrapField.new()
	field.setup()
	var canister := pickup.find_child("RewardCanister", false, false) as MeshInstance3D
	var mat := canister.material_override as ShaderMaterial
	var field_mat := field._material as ShaderMaterial
	_check(mat != null and field_mat != null and mat.shader == field_mat.shader
		and mat.get_shader_parameter("glow_color") == Palette.AMBER
		and mat.shader.code.contains("ALBEDO = COLOR.rgb;"), "uses the shared field shader for the amber reward")
	field.free()
	boss._spawn_pickup(at + Vector3.RIGHT, 9, "returned")
	var other: Node3D = boss._pickups[1].node
	_check(other.find_child("RewardCanister", false, false) is MeshInstance3D
		and other.find_child("ScrapCore", false, false) is MeshInstance3D, "each canister keeps its core and painted body")
	var initial_yaw := pickup.rotation.y
	boss._step_trail(Vector3(200, 200, 200))
	_check(is_equal_approx(pickup.rotation.y - initial_yaw, boss._delta * 2.5), "base pickup spin rate")
	var source := FileAccess.get_file_as_string("res://src/boss/boss.gd")
	var start := source.find("func _spawn_pickup")
	var mesh_start := source.find("\tvar node := Node3D.new()", start)
	var mesh_end := source.find("\tvar canister_mesh := CylinderMesh.new()", mesh_start)
	var logic := source.substr(0, mesh_start) + source.substr(mesh_end)
	logic = logic.replace("static var _pickup_materials := {}\n", "")
	logic = logic.replace("\tnode.material_override = _pickup_materials[material_key]\n", "\tnode.material_override = Palette.solid(Palette.ARC, 2.0)\n")
	_check(logic.sha256_text() == BASE_LOGIC_SHA, "entire boss source outside mesh construction unchanged")
	_finish()
