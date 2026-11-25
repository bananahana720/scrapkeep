# 2026-10-12, W13 smoke triage: class c re-pin for b200529.
# interact.gd SHA256 aef96a7a9ddf81bfb96ba96b7bef9cac836da62eaa1548add9f162976c60347a -> 52023d69247026b37e2ddbf86c4a91f28bb619f78232c4aa968143322f023087; stake-device dispatch.
extends SceneTree

const Game := preload("res://src/game.gd")
const Cache := preload("res://src/world/cracked_cache.gd")
const Bet := preload("res://src/world/bet_crate.gd")
const Altar := preload("res://src/world/ambush_altar.gd")
const Palette := preload("res://src/core/palette.gd")
const ASSETS := [
	[Cache, "cracked_cache", ["CacheShell", "CacheRoof", "CacheWall", "CacheChest", "CacheLid", "CachePedestal"], 6],
	[Bet, "bet_crate", ["BetHousing", "OddsDial", "OddsNeedle"], 3],
	[Altar, "ambush_altar", ["AltarPost", "AltarCap", "AltarBand", "AltarRing"], 4],
]
# VX8: only an attack wears hazard stripes, so the altar keeps no floor ring. The GLB still ships
# the part; the runtime leaves it out. The bone band is the model's own (W1-22, 12 Nov 2026).
const UNUSED_RUNTIME := {"ambush_altar": ["AltarRing"]}
var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s -> %s" % [label, "PASS" if ok else "FAIL"])


func _device(script: Script, suffix: String) -> Node3D:
	var device := script.new() as Node3D
	root.add_child(device)
	device.position = Vector3(0, 40, 0)
	device.setup(game.ctx, game.world.interact, {"id": "asset_" + suffix})
	return device


func _dispose(device: Node3D) -> void:
	device.stand_down()
	device.free()


func _measure(node: Node, require_colours: bool) -> Dictionary:
	var totals := {"tris": 0, "verts": 0, "draws": 0}
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		_check(mi.mesh != null, String(mi.name) + " has a mesh")
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var arrays := mi.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices = arrays[Mesh.ARRAY_INDEX]
			totals.verts += verts.size()
			totals.tris += (indices.size() if indices != null else verts.size()) / 3
			totals.draws += 1
			var active := mi.get_active_material(s)
			var material := active as BaseMaterial3D
			# The cache's workshop finish (VX3) is a shader that multiplies the vertex colour.
			var shaded: bool = active is ShaderMaterial and active.shader != null and active.shader.code.contains("COLOR.rgb")
			if not require_colours:
				_check(shaded or (material != null and (material.vertex_color_use_as_albedo or material.albedo_texture != null)),
					String(mi.name) + " runtime surface consumes colour or texture")
			if require_colours:
				_check(arrays[Mesh.ARRAY_COLOR] != null and arrays[Mesh.ARRAY_COLOR].size() == verts.size(),
					String(mi.name) + " exported colour per vertex")
			if material != null:
				_check(material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED, String(mi.name) + " opaque")
	return totals


func _collisions(device: Node3D) -> Array:
	var rows := []
	for shape: CollisionShape3D in device.find_children("*", "CollisionShape3D", true, false):
		var body := shape.get_parent() as StaticBody3D
		var box := shape.shape as BoxShape3D
		_check(body != null and box != null, "cache retains box collider")
		if body != null and box != null:
			rows.append([box.size, device.global_transform.affine_inverse() * shape.global_transform, body.collision_layer, body.collision_mask])
	return rows


func _run() -> void:
	while game.flow == null:
		await process_frame
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	if "--loader-fixture" in OS.get_cmdline_user_args():
		_check_loader_fixture()
		_finish()
		return
	for row in ASSETS:
		var path := "res://assets/models/world_one/%s.glb" % row[1]
		var packed := load(path) as PackedScene
		_check(packed != null, row[1] + " GLB loads")
		if packed == null:
			continue
		var scene := packed.instantiate()
		var totals := _measure(scene, true)
		print("%s budget: %d T / %d V / %d D" % [row[1], totals.tris, totals.verts, totals.draws])
		_check(totals.tris > 0 and totals.tris <= 1100 and totals.verts <= 2100 and totals.draws == row[3], row[1] + " budget")
		for part_name in row[2]:
			_check(scene.find_child(part_name, true, false) is MeshInstance3D, row[1] + " named part " + part_name)
		_check(scene.find_children("*", "CollisionShape3D", true, false).is_empty(), row[1] + " GLB has no physics")
		_check_colour_language(scene, row[1])
		scene.free()
		var script: Script = row[0]
		var constants: Dictionary = script.get_script_constant_map()
		for key in BASE_CONSTS[row[1]]:
			_check(constants.has(key) and constants[key] == BASE_CONSTS[row[1]][key], row[1] + " original constant " + key)
		var parts: Array = script._parts()
		_check(parts.size() == row[2].size(), row[1] + " cached runtime parts")
		var device := _device(script, row[1])
		_measure(device, false)
		_check(device.find_children("*", "CollisionObject3D", true, false).size() == (5 if device is Cache else 0), row[1] + " physics body count unchanged")
		var boxes := 0
		for view: MeshInstance3D in device.find_children("*", "MeshInstance3D", true, false):
			if view.mesh is BoxMesh:
				boxes += 1
		_check(boxes == 0, row[1] + " builds no greybox boxes")
		for part_name in row[2]:
			if part_name in UNUSED_RUNTIME.get(row[1], []):
				_check(device.find_child(part_name, true, false) == null, row[1] + " leaves out " + part_name)
				continue
			_check(device.find_child(part_name, true, false) is MeshInstance3D, row[1] + " runtime part " + part_name)
		if device is Cache:
			_check_cache(device)
		elif device is Bet:
			_check_bet(device)
		else:
			_check_altar(device)
		_dispose(device)
	_check_gameplay_sources()
	_finish()


func _finish() -> void:
	print("device_props_asset_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	game.free()
	quit(0 if failures == 0 else 1)


func _check_cache(device) -> void:
	var expected := [
		[Vector3(14, 7.5, 1), Vector3(0, 2.25, -5.5)],
		[Vector3(1, 7.5, 12), Vector3(-6.5, 2.25, 0)],
		[Vector3(1, 7.5, 12), Vector3(6.5, 2.25, 0)],
		[Vector3(14, 1, 12), Vector3(0, 6.5, 0)],
		[Vector3(12, 7.5, 1), Vector3(0, 2.25, 5.5)],
	]
	var before := _collisions(device)
	_check(before.size() == 5, "cache has exactly the original five colliders")
	for i in mini(before.size(), expected.size()):
		_check(before[i][0] == expected[i][0] and before[i][1].is_equal_approx(Transform3D(Basis.IDENTITY, expected[i][1]))
			and before[i][2] == 1 and before[i][3] == 1, "cache collider dimensions, transform and order %d" % i)
	var saved: Array = Cache._shared
	Cache._shared = []
	var fallback := _device(Cache, "fallback")
	_check(_collisions(fallback) == before, "cache fallback and dressed collisions identical")
	_check(fallback._lid is MeshInstance3D and fallback._lid.mesh is BoxMesh, "cache greybox fallback retained")
	_dispose(fallback)
	Cache._shared = saved
	_check(device.state == Cache.SEALED and device._wall.visible, "cache sealed fracture panel visible")
	device.crumble()
	_check(device.state == Cache.OPEN and not device._wall.visible and device._wall.position.y < -390, "cache cracked wall vanishes and opens route")
	var lid_start: Transform3D = device._lid.transform
	device.fire()
	_check(device.state == Cache.PICKING and not device._lid.transform.is_equal_approx(lid_start), "cache opened lid moves")
	var shown := 0
	for pedestal in device._pedestals:
		if pedestal.node.visible:
			shown += 1
	_check(shown == 3, "cache picking shows three model pedestals")
	_measure(device, false)
	device.take(0)
	for pedestal in device._pedestals:
		_check(not pedestal.node.visible, "cache taken hides offer pedestal")
	_check(device.state == Cache.TAKEN and device.spent, "cache taken state")


func _check_bet(device) -> void:
	_check(_collisions(device).is_empty(), "bet has no collider")
	var saved: Array = Bet._shared
	Bet._shared = []
	var fallback := _device(Bet, "fallback")
	_check(fallback._needle.get_child_count() > 0, "bet greybox fallback retained")
	_dispose(fallback)
	Bet._shared = saved
	var twin := _device(Bet, "twin")
	_check(twin._needle.mesh == device._needle.mesh and twin._needle != device._needle, "bet shares mesh with independent state pivot")
	game.run.bonus_cores = 2
	device.fire()
	device.outcome = true
	device.tick(0.1)
	_check(device.rolling and absf(device._needle.rotation.z) > 0.01 and twin._needle.rotation.z == 0, "bet rolling spins only its needle")
	device.tick(Bet.SPIN)
	_check(device._landed and is_equal_approx(device._needle.rotation.z, PI * 0.5), "bet heads needle lands on mint left half")
	device.tick(Bet.LAND)
	var landed: Transform3D = device._needle.transform
	device.tick(1.0)
	_check(device.spent and not device.rolling and device._needle.transform.is_equal_approx(landed), "bet spent keeps landed outcome visible")
	game.run.bonus_cores = 2
	twin.fire()
	twin.outcome = false
	twin.tick(Bet.SPIN + Bet.LAND)
	_check(is_equal_approx(twin._needle.rotation.z, -PI * 0.5) and twin.spent, "bet tails needle lands on rust right half")
	_dispose(twin)


func _check_altar(device) -> void:
	_check(_collisions(device).is_empty(), "altar has no collider")
	var saved: Array = Altar._shared
	Altar._shared = []
	var fallback := _device(Altar, "fallback")
	_check(fallback._cap is MeshInstance3D and fallback._cap.mesh is BoxMesh, "altar greybox fallback retained")
	_dispose(fallback)
	Altar._shared = saved
	var idle: float = device._cap.rotation.y
	device.tick(0.1)
	_check(is_equal_approx(device._cap.rotation.y - idle, 0.06) and device._ring == null, "altar idle cap turns with no floor ring")
	device.fire()
	var armed: float = device._cap.rotation.y
	device.tick(0.1)
	_check(device.running and is_equal_approx(device._cap.rotation.y - armed, 0.4), "altar armed running cap speeds up")
	device._end(true)
	_check(device.spent and device.won, "altar cleared is spent and won")
	var twin := _device(Altar, "timeout")
	twin.fire()
	twin._end(false)
	_check(twin.spent and not twin.won, "altar expired is spent and lost")
	_dispose(twin)


func _check_gameplay_sources() -> void:
	for stem in SOURCE_PINS:
		var source := FileAccess.get_file_as_string("res://src/world/%s.gd" % stem)
		var tail := "func " + source.get_slice("func " + SOURCE_PINS[stem][0], 1)
		tail = tail.get_slice("\n\nstatic func _slot_material", 0).get_slice("\n\nfunc _collision_box", 0)
		tail = tail.strip_edges()
		_check(tail.sha256_text() == SOURCE_PINS[stem][1], stem + " interaction, timing, reward and state logic unchanged")
	for path in INHERITED_PINS:
		_check(FileAccess.get_sha256("res://src/world/" + path + ".gd") == INHERITED_PINS[path], path + " unchanged source")


const SOURCE_PINS := {
	# 2026-10-08: re-pinned for crumble()'s fired light becoming an emission change (Forward+ crash fix).
	# 2026-10-09: re-pinned for take() publishing the cache_spent world fact (wave 12 vx-ground, VX-FX's ember keys on it).
	# 2026-11-11: re-pinned for the relic offer becoming a relic-rung part (systems audit pass D fold).
	# 2026-11-12: re-pinned for the pedestal gem becoming its rung's TierMark shape (W1-26).
	# 2026-11-24: re-pinned for fire() lid hinge tween, staggered pedestal rise and brass glint burst (W46-ANIM-VFX-FLAIR).
	# 2026-11-25: re-pinned for _relic_offer() passing include_alt = true so all 12 W50 swap relics can drop in-run.
	"cracked_cache": ["stand_down()", "aaf96c816d49040ac55ca6b4560139f36458c09e0abda73162a86efddc6322b0"],
	"bet_crate": ["reach_point()", "dc1b7b8203b6c2018894e88689885c366ed5edd5d928cae60f6370082acb2e16"],
	"ambush_altar": ["reach_point()", "7a1a73f6c7f2d8fc8645eb7565f763f0fb95d0d7701598998f46905bc9aa6db3"],
}
const INHERITED_PINS := {
	# 2026-11-19: device and interactables re-pinned for the prompt drawing Interact's bound key or
	# button in place of a fixed E (Wave 44 audit).
	"device": "df8c6c95e0c30134840d77dd9070190071c9325f377d1ec29c5ab5458b96ba36",
	"interactables": "693003acc330eaffb583edf65056f45c13b09918795409fb3b2e7e7fa86b8713",
	"interact": "52023d69247026b37e2ddbf86c4a91f28bb619f78232c4aa968143322f023087",
}


func _check_loader_fixture() -> void:
	for row in ASSETS:
		var script: Script = row[0]
		_check(script._parts().is_empty() and script._parts().is_empty(), row[1] + " malformed asset cached as empty")
		var device := _device(script, "malformed_" + row[1])
		_check(device.find_child(row[2][0], true, false) == null, row[1] + " malformed asset uses fallback")
		var boxes := 0
		for view: MeshInstance3D in device.find_children("*", "MeshInstance3D", true, false):
			if view.mesh is BoxMesh:
				boxes += 1
		_check(boxes > 0, row[1] + " malformed asset still builds old visual")
		_dispose(device)


func _has_colour(mesh: Mesh, colour: Color, side := 0) -> bool:
	var found := false
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var colours = arrays[Mesh.ARRAY_COLOR]
		var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		if colours == null:
			continue
		for i in colours.size():
			var value: Color = colours[i]
			var linear := colour.srgb_to_linear()
			var a := Vector3(value.r, value.g, value.b)
			var b := Vector3(colour.r, colour.g, colour.b)
			var c := Vector3(linear.r, linear.g, linear.b)
			if a.distance_to(b) < 0.015 or a.distance_to(c) < 0.015:
				found = true
				if (side < 0 and points[i].x > 0.01) or (side > 0 and points[i].x < -0.01):
					return false
	return found


func _check_colour_language(scene: Node, stem: String) -> void:
	if stem == "cracked_cache":
		var chest := scene.find_child("CacheChest", true, false) as MeshInstance3D
		_check(chest != null and chest.mesh != null and _has_colour(chest.mesh, Palette.VERDIGRIS), "cache chest retains verdigris concrete language")
	elif stem == "bet_crate":
		var dial := scene.find_child("OddsDial", true, false) as MeshInstance3D
		var housing := scene.find_child("BetHousing", true, false) as MeshInstance3D
		_check(dial != null and dial.mesh != null and _has_colour(dial.mesh, Palette.ARC, -1)
			and _has_colour(dial.mesh, Palette.RUST, 1), "odds face is mint left and rust right")
		_check(housing != null and housing.mesh != null and _has_colour(housing.mesh, Palette.COPPER)
			and _has_colour(housing.mesh, Palette.HAZARD), "bet copper and HAZARD stripe retained")
	else:
		var post := scene.find_child("AltarPost", true, false) as MeshInstance3D
		var cap := scene.find_child("AltarCap", true, false) as MeshInstance3D
		var ring := scene.find_child("AltarRing", true, false) as MeshInstance3D
		_check(post != null and post.mesh != null and _has_colour(post.mesh, Palette.COPPER), "altar post retains copper")
		_check(cap != null and cap.mesh != null and ring != null and ring.mesh != null
			and _has_colour(cap.mesh, Palette.HAZARD) and _has_colour(ring.mesh, Palette.HAZARD), "altar cap and ring retain HAZARD")


const BASE_CONSTS := {
	"cracked_cache": {
		"BREAK_SPEED": 18.0, "SPRINT_SPEED": 8.0, "WALL_REACH": 3.0, "SLAM_REACH": 7.0,
		"HALF_W": 6.0, "HALF_D": 5.0, "HEIGHT": 6.0, "SINK": 1.5, "PICKS": 3,
		"PICK_RARITIES": ["common", "rare"], "PEDESTAL_REACH": 1.7, "RELIC_CHANCE": 0.2,
		"PEDESTALS": [Vector3(-4, 0, -3), Vector3(0, 0, -3.5), Vector3(4, 0, -3)],
	},
	"bet_crate": {"ODDS": 0.5, "SPIN": 0.9, "LAND": 0.35, "TURNS": 3.0},
	"ambush_altar": {"SECONDS": 30.0, "RING": 10.0, "PACK": ["chaser", "chaser", "lobber"]},
}
