extends "res://tests/rivet_kit_test.gd"

const Arena := preload("res://src/boss/arena.gd")
const RunState := preload("res://src/core/run_state.gd")

const Ultimate := preload("res://src/combat/ultimate.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const RivetTree := preload("res://src/core/trees/rivet.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const RideRail := preload("res://src/world/ride_rail.gd")
const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const CodexEntries := preload("res://src/combat/codex_entries.gd")
const Audio := preload("res://src/presentation/audio.gd")
const WorldOneCards := preload("res://src/core/trees/world_one_cards.gd")

# PC-RIVET, 2026-10-11 (design-v3/pilots/rivet.md sections 3, 7, 8, 9 and 10). Expected: 223
# checks, including the count assertion. Shares the kit test's real-game fixture, never its cases.
# Rows are called through the framework's _ult_rows dispatch; the landing through _strike.
# 2026-10-11 (PC-RIVET fix round): 60 -> 67. Full Breach grants on ultimate_landed (CUSTOMIZE.md
# :356), so its discovery is gone; the three Rivet cards now open in the codex after their
# framework card, Line True on the tenth punch; the Breach Skid reads player_ball's skid cone.
# 2026-10-12 (PC-RIVET round 3): exercise the framework's encore transition and both legs' rams.
# Closed Warden guards remain collidable; a staggered core may be passed.
# 2026-10-12 (PC-RIVET r4): 75 -> 86, elevated/covered beam fixtures, camera parallax,
# re-closed guard and independent Breach Skid damage expectation, coordinator rulings.
# 2026-10-12 (PC-RIVET r5): 86 -> 148, ten real shape dispatches, independent height,
# terrain and kit-constant expectations, selected geometry versus rendered vertices,
# and the unchanged centre-based wave limits and Breach Skid inner ring.
# 2026-10-12 (PC-RIVET r6): 148 -> 198, narrow-wall shadows, terrain formats, exposed hulls
# and a real-stage dispatch so the normal terrain commitment must complete within smoke's cap.

# 2026-10-12 (PC-RIVET r7): 198 -> 206, captured alpha Reach peak and bowl landing,
# frozen draw reuse and independent positive damage/terrain controls.
# 2026-10-12 (PC-RIVET r7): 206 -> 219, actual cylinder ray/shadow controls and the
# captured bowl peak, whose terrain extractor previously discarded the whole volume.
# 2026-10-12 (FU-RIVET-SHADOW): 219 -> 223, the empty-shadow subtraction asserted directly
# (cone meets the cell, cell wholly in front of the contact plane, one part, original geometry),
# and the class-V fixture mass read from RunState.HEFT_CLASS_AT[4] and HEFT_PER_MASS.
# 2026-10-12 (FU-RIVET-SHADOW r2): 223 -> 226, the selection path (_in_shape, hull_boundary
# shadows) checked directly: hulls behind the terrain contact select nothing from the empty-shadow
# cell, the unshadowed cell selects two of them, and an in-front hull is still selected.
# 2026-10-16 (BITE-PIN): 226 -> 229. A guard re-closed on the ball, and the landing, hold the
# exceptions of bodies the ball is inside until it is clear (exception_hold.gd).
# 2026-10-17 (RIVET-FREEZE): 229 -> 232. The terrain commit's skipped clips leave parts and
# shadows byte-identical to a plain subtraction pass.


func _initialize() -> void:
	_t = T.new("rivet_set_piece_test")
	_expected_checks = 232
	super._initialize()


func _piece(id: String, heading := Vector3.RIGHT, release := 20.0) -> void:
	var ult = _combat.ultimate
	var from: Vector3 = _player.ball_position()
	var to: Vector3 = from + heading * 25.0
	_player.abilities.ultimate_id = id
	ult._id = id
	ult._plan = {"path": "line", "from": from, "to": to, "flight": 2.4, "seconds": 2.75, "beats": 7,
		"legs": [{"mode": "line", "to": to, "seconds": 2.4, "beats": 7, "strike": true}]}
	ult.last_plan = ult._plan
	# _strike is called after _land advances the index. Most cases dispatch that final strike.
	ult._leg = 1
	ult._beats = 7
	ult._beat_len = 2.4 / 7.0
	ult._peaked = false
	ult._phase = "flight"
	ult._posture_spent = {}
	ult._record = {"volley_hits": 0}
	var ride = RideRail.new()
	ride.mode = RideRail.ARC
	ride.origin = from
	ride.target = to
	ride.heading = heading
	ride.release_speed = release
	ride.velocity = heading * release + Vector3.UP * 6.0
	ride.flight = 2.4
	ride.time = 2.0
	ride.active = true
	ult._ride = ride
	_game.events.ultimate_started.emit(id, "line", from, to, 2.75)


func _tech(id: String, beat: int, aim := Vector3.RIGHT, camera_offset := Vector3.ZERO) -> int:
	_game.camera.set_physics_process(false)
	_game.camera.cam.get_parent().global_position = _player.ball_position() + camera_offset
	_game.camera.cam.global_basis = Basis.looking_at(aim)
	return int(_combat.ultimate._ult_rows[id]["tech"].call(beat, _player.ball_position(), aim, 1.0))


func _damage(enemy: Node3D) -> Array:
	return _hits(enemy).map(func(row): return snappedf(_punch_of(row), 0.01))


func _knob(name: String, value) -> void:
	_player.tree._knobs[name] = value


# Steps the kit's card queue on real physics ticks, as its _physics_process would.
func _step_cards(ticks: int) -> void:
	for i in ticks:
		await physics_frame
		_kit._step_cards()


func _shape_dispatch_fixture() -> void:
	var paths: Array = _kit.shape_paths()
	var expected := ["foundry_cutter/tech", "foundry_cutter/peak", "foundry_cutter/landing",
		"prism_cutter/tech", "prism_cutter/peak", "prism_cutter/landing",
		"juggernaut_drive/tech", "juggernaut_drive/peak", "juggernaut_drive/landing", "juggernaut_drive/drive_step"]
	_t.eq("shape dispatch count guard", paths.size(), 10)
	_t.eq("every registered shape dispatch has an independent fixture", paths.map(func(p): return p["id"] + "/" + p["entry"]), expected)
	_t.eq("framework shape rows come from the kit dispatch registry", _combat.ultimate._ult_rows.keys().filter(func(id): return id in Kit.SHAPE_DISPATCH), Kit.SHAPE_DISPATCH.keys())
	_t.eq("every Rivet set piece is in the shape dispatch registry", Kit.SHAPE_DISPATCH.keys(), Kit.SET_PIECES)
	for path in paths:
		await _fresh()
		var id: String = path["id"]
		var entry: String = path["entry"]
		var label := id + "/" + entry
		_piece(id)
		var wave := id == "juggernaut_drive" and entry == "tech"
		var ram := entry == "drive_step" or (id == "juggernaut_drive" and entry == "peak")
		var inside := _enemy("chaser", 2.0 if ram else 5.0, 4.0 if wave else 0.0)
		var above := _enemy("chaser", 2.0 if ram else 5.0, 4.0 if wave else 0.0)
		above.global_position += Vector3.UP * 100.0
		var covered := _enemy("chaser", 3.5 if ram else 8.0, 4.0 if wave else 0.0)
		for enemy in [inside, above, covered]:
			enemy.set_physics_process(false)
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 30.0, 30.0)
		collision.shape = box
		wall.add_child(collision)
		_game.add_child(wall)
		var wall_x := 2.8 if ram else 6.5
		wall.global_position = _player.ball_position() + Vector3.RIGHT * wall_x
		_game.camera.set_physics_process(false)
		_game.camera.cam.get_parent().global_position = _player.ball_position()
		_game.camera.cam.global_basis = Basis.looking_at(Vector3.RIGHT)
		await physics_frame
		await physics_frame
		match entry:
			"tech":
				_tech(id, 1)
			"peak":
				if id in Kit.BEAM_PIECES:
					_tech(id, 4)
				_combat.ultimate._peak(_player.ball_position())
				if ram:
					_kit.drive_step(_player.ball_position())
			"landing":
				_combat.ultimate._strike(_player.ball_position())
			"drive_step":
				_kit.drive_step(_player.ball_position())
			_:
				_t.check(label + " known entry", false)
		var touched := func(enemy): return enemy._knock.length() > 0.01 if wave else not _hits(enemy).is_empty()
		_t.check(label + " inside target hit", touched.call(inside))
		_t.check(label + " vertically outside target missed", not touched.call(above))
		_t.check(label + " terrain-covered target missed", not touched.call(covered))
		var selected = _kit.get("selected_shapes")
		_t.check(label + " dispatch called the selector", selected is Array and not selected.is_empty())
		var drawn: Array = (_player.indicator.shapes.values() + _kit.volume_indicator.shapes.values()).filter(func(s): return s.has("rivet_shape"))
		_t.check(label + " visual consumes the selected record", selected is Array and not drawn.is_empty() and drawn.all(func(s): return selected.has(s)))
		if id == "foundry_cutter" and entry == "peak":
			var scar: Dictionary = _kit.volume_indicator.shapes.get("rivet_scar", {})
			_t.near("Full Cut drawn width equals the independent kit constant", float(scar.get("width", -1.0)), Weapons.FULL_CUT_WIDTH)
			_t.near("Full Cut drawn angle equals the independent kit constant", float(scar.get("half_angle", -1.0)), deg_to_rad(Weapons.FULL_CUT_DEG * 0.5))
			_t.check("Full Cut committed centre stops at the independent wall face", scar.has("centre_endpoint") and absf((scar["centre_endpoint"] as Vector3).x - _player.ball_position().x - (wall_x - 0.25)) < 0.001)
			var vertices: Array = []
			for cell in scar.get("cells", []):
				for face in cell["faces"]:
					vertices.append_array(face)
			var origin: Vector3 = _player.ball_position()
			_t.check("Full Cut drawn volume stays inside independent height and terrain limits", not vertices.is_empty() and vertices.all(func(v): return absf(v.y - origin.y) <= Weapons.FULL_CUT_WIDTH * 0.5 + 0.001 and v.x - origin.x <= wall_x - 0.25 + 0.001))
			var indicator = _kit.volume_indicator
			var other_shapes: Dictionary = indicator.shapes
			indicator.shapes = {"rivet_scar": scar}
			_kit.volume_indicator._process(0.0)
			var arrays: Array = _kit.volume_indicator._tris.surface_get_arrays(0)
			var rendered: Array = []
			for i in (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size():
				if arrays[Mesh.ARRAY_COLOR][i].a < 1.0:
					rendered.append(arrays[Mesh.ARRAY_VERTEX][i])
			var expected_vertices: Array = []
			if selected is Array and not selected.is_empty():
				for cell in selected[0]["cells"]:
					for face in cell["faces"]:
						for i in range(1, face.size() - 1):
							for v in [face[0], face[i], face[i + 1]]:
								expected_vertices.append(v + Vector3.UP * indicator.LIFT)
			var max_error := 0.0
			if rendered.size() == expected_vertices.size():
				for i in rendered.size():
					max_error = maxf(max_error, rendered[i].distance_to(expected_vertices[i]))
			_t.check("Full Cut rendered fill matches the selection snapshot", not expected_vertices.is_empty() and rendered.size() == expected_vertices.size() and max_error < 0.001, "%d rendered, %d selected vertices, max error %s" % [rendered.size(), expected_vertices.size(), max_error])
			indicator.shapes = other_shapes
		wall.queue_free()
	await _fresh()
	_piece("juggernaut_drive")
	var near_wave := _enemy("chaser", 5.0, Weapons.DRIVE_WAVE_NEAR - 0.1)
	var far_wave := _enemy("chaser", 5.0, Weapons.DRIVE_WAVE_FAR + 0.1)
	near_wave.set_physics_process(false)
	far_wave.set_physics_process(false)
	_tech("juggernaut_drive", 1)
	_t.check("bow wave keeps its centre-based near and far limits", near_wave._knock.length() < 0.01 and far_wave._knock.length() < 0.01)
	await _fresh()
	_piece("foundry_cutter")
	var past_inner := _enemy("chaser", -Weapons.BREACH_INNER - 0.1)
	past_inner.set_physics_process(false)
	_combat.ultimate._strike(_player.ball_position())
	_t.check("Breach Skid inner ring keeps its centre-based radius", _hits(past_inner).is_empty())
	await _fresh()
	_kit._draw_shape("rivet_scar", {"kind": "rivet_volume", "origin": _player.ball_position(), "cells": [{"faces": [], "planes": []}]})
	_t.check("an empty clipped volume never starts a mesh surface", not _player.indicator.shapes.has("rivet_scar") and not _kit.volume_indicator.shapes.has("rivet_scar"))
	await _fresh()


func _terrain_shadow_fixture() -> void:
	for spec in [{"width": 30.0, "kind": "box"}, {"width": 4.0, "kind": "box"},
		{"width": 3.0, "kind": "box"}, {"width": 2.6, "kind": "box"},
		{"width": 2.6, "kind": "trimesh"}, {"width": 2.6, "kind": "convex"}]:
		var width: float = spec["width"]
		var label := "%s %s" % [spec["kind"], width]
		await _fresh()
		_piece("foundry_cutter")
		var front := _enemy("chaser", 5.0)
		var covered := _enemy("chaser", 8.0)
		front.set_physics_process(false)
		covered.set_physics_process(false)
		var exposed_shadow: Node3D = null
		if width == 2.6 and spec["kind"] == "box":
			exposed_shadow = _enemy("chaser", 8.0, 1.3)
			exposed_shadow.set_physics_process(false)
		var wall := StaticBody3D.new()
		wall.collision_layer = 1
		var collision := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.5, 30.0, width)
		collision.shape = box
		if spec["kind"] != "box":
			var mesh := BoxMesh.new()
			mesh.size = box.size
			collision.shape = mesh.create_trimesh_shape() if spec["kind"] == "trimesh" else mesh.create_convex_shape()
		wall.add_child(collision)
		_game.add_child(wall)
		wall.global_position = _player.ball_position() + Vector3.RIGHT * 6.5
		await physics_frame
		await physics_frame
		_tech("foundry_cutter", 4)
		_combat.ultimate._peak(_player.ball_position())
		var hull: float = _combat._hull(covered)
		_t.check("wall %s occludes the whole target hull" % label, width * 0.5 >= hull * 6.25 / (8.0 - hull), "hull=%s" % hull)
		_t.check("wall %s covers the beam aperture" % label, width >= Weapons.FULL_CUT_WIDTH)
		_t.eq("wall %s front target hit exactly once" % label, _damage(front), [Weapons.FULL_CUT_DAMAGE])
		_t.check("wall %s independently blocks the centre ray" % label, not _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_player.ball_position(), covered.global_position, 1)).is_empty())
		_t.check("wall %s covered target receives zero hits" % label, _hits(covered).is_empty(), str(_damage(covered)))
		var vertices: Array = []
		for cell in _kit.volume_indicator.shapes["rivet_scar"]["cells"]:
			for face in cell["faces"]:
				vertices.append_array(face)
		var origin: Vector3 = _player.ball_position()
		_t.check("wall %s drawn vertices exclude the independent shadow" % label, not vertices.is_empty() and vertices.all(func(v):
			var offset: Vector3 = v - origin
			return offset.x <= 6.25 + 0.001 or absf(offset.z) >= width * 0.5 * offset.x / 6.25 - 0.001 or absf(offset.y) >= 15.0 * offset.x / 6.25 - 0.001))
		if exposed_shadow != null:
			var slope := width * 0.5 / 6.25
			var edge_distance := (slope * 8.0 - 1.3) / sqrt(1.0 + slope * slope)
			_t.check("partial hull independently crosses the terrain shadow edge", edge_distance > 0.0 and edge_distance < _combat._hull(exposed_shadow))
			_t.check("partial hull centre ray is blocked", not _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_player.ball_position(), exposed_shadow.global_position, 1)).is_empty())
			_t.eq("exposed part of a terrain-shadow boundary hull hits once", _damage(exposed_shadow), [Weapons.FULL_CUT_DAMAGE])
		wall.queue_free()
	await _fresh()
	_piece("foundry_cutter")
	# Beyond the 45-degree sweep edge plus its half-width, within the 1 m hull.
	var exposed := _enemy("chaser", 8.0, 10.5)
	exposed.set_physics_process(false)
	var distance := (10.5 - 8.0) / sqrt(2.0) - Weapons.FULL_CUT_WIDTH * 0.5
	_t.check("exposed hull centre is outside the sweep, hull intersects it", distance > 0.0 and distance < _combat._hull(exposed))
	_t.check("exposed hull independent centre ray is clear", _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_player.ball_position(), exposed.global_position, 1)).is_empty())
	_tech("foundry_cutter", 4)
	_combat.ultimate._peak(_player.ball_position())
	_t.eq("exposed boundary hull hit exactly once", _damage(exposed), [Weapons.FULL_CUT_DAMAGE])
	# A narrow wall beyond the sweep may constrain hull forgiveness only in its silhouette.
	for wall_present in [false, true]:
		await _fresh()
		_piece("foundry_cutter")
		var outer_hull := _enemy("chaser", 30.5, 4.0)
		outer_hull.set_physics_process(false)
		var wall: StaticBody3D = null
		if wall_present:
			wall = StaticBody3D.new()
			wall.collision_layer = 1
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(0.5, 30.0, 2.6)
			collision.shape = box
			wall.add_child(collision)
			_game.add_child(wall)
			wall.global_position = _player.ball_position() + Vector3.RIGHT * 30.5
			_t.check("outer hull independently intersects reach", sqrt(30.5 * 30.5 + 4.0 * 4.0) - Weapons.FULL_CUT_REACH < _combat._hull(outer_hull))
		await physics_frame
		await physics_frame
		_t.check("outer hull ray clear, wall=%s" % wall_present, _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_player.ball_position(), outer_hull.global_position, 1)).is_empty())
		_tech("foundry_cutter", 4)
		_combat.ultimate._peak(_player.ball_position())
		_t.eq("outer hull hit once, wall=%s" % wall_present, _damage(outer_hull), [Weapons.FULL_CUT_DAMAGE])
		if wall != null:
			wall.queue_free()
	await _fresh()
	_player.reset_to(_game.ctx.terrain.spawn_point(1))
	await physics_frame
	await physics_frame
	var stage_origin: Vector3 = _player.ball_position()
	_t.check("real stage spawn has an independently clear upward ray", _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(stage_origin, stage_origin + Vector3.UP * 5.0, 1)).is_empty())
	_piece("foundry_cutter")
	_tech("foundry_cutter", 4)
	_combat.ultimate._peak(_player.ball_position())
	_t.eq("real stage Full Cut completes one selector commitment", _kit.selected_shapes.size(), 1)
	_t.check("real stage Full Cut retains exposed drawn volume", not _kit.volume_indicator.shapes.get("rivet_scar", {}).is_empty())
	await _fresh()


func _alpha_terrain_cost_fixture() -> void:
	await _fresh()
	_game.ctx.terrain.use(2)
	var reach_at := Vector3(-83.37614, 24.67473, 53.09039)
	var reach_aim := Vector3(-0.479884, -0.166079, 0.861469).normalized()
	_player.reset_to(reach_at)
	await physics_frame
	await physics_frame
	_piece("foundry_cutter", Vector3(-0.456, 0.0, 0.89).normalized())
	_tech("foundry_cutter", 4, reach_aim)
	_combat.ultimate._peak(_player.ball_position())
	_t.eq("captured alpha Reach peak commits through one selector", _kit.selected_shapes.size(), 1)
	_t.check("captured alpha Reach peak draws the committed volume", _kit.volume_indicator.shapes.get("rivet_scar", {}) == _kit.selected_shapes[0])
	var indicator = _kit.volume_indicator
	indicator._process(0.0)
	var changes := [0]
	var changed := func(): changes[0] += 1
	indicator._tris.changed.connect(changed)
	indicator._process(0.0)
	_t.eq("captured alpha frozen volume does not rebuild its mesh", changes[0], 0)
	indicator._tris.changed.disconnect(changed)
	await _fresh()
	var arena := Arena.new()
	arena.position = Vector3(0.0, 50.75909, 118.0)
	_game.add_child(arena)
	# The skipper's traced class III landing, not the stage's spawn point.
	var arena_at := Vector3(-5.500705, 52.86404, 115.151)
	var arena_heading := Vector3(0.99119, 0.0, 0.132449).normalized()
	var prior_mass: float = _game.run.mass
	_game.run.mass = (float(RunState.HEFT_CLASS_AT[2]) - 1.0) / RunState.HEFT_PER_MASS + 0.01
	_player.reset_to(arena_at)
	await physics_frame
	await physics_frame
	_t.eq("captured alpha bowl landing uses class III", _game.run.heft_class(), 3)
	_piece("foundry_cutter", arena_heading)
	var front := _enemy("chaser", 0.0)
	front.global_position = arena_at + arena_heading * 4.0
	front.set_physics_process(false)
	_t.check("captured bowl front target has an independent clear ray", _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(arena_at, front.global_position, 1)).is_empty())
	var health_before: float = front.hp
	_combat.ultimate._strike(_player.ball_position())
	_t.eq("captured alpha bowl landing commits through one selector", _kit.selected_shapes.size(), 1)
	_t.check("captured alpha bowl landing retains exposed volume", not (_kit.selected_shapes[0]["cells"] as Array).is_empty())
	_t.eq("captured alpha bowl landing hits the exposed target exactly once", [snappedf(health_before - float(front.hp), 0.01), _hits(front).size()], [Ultimate.LANDING_DAMAGE * Ultimate.HEFT_MULT[2], 1])
	_game.run.mass = prior_mass
	var peak_at := Vector3(-5.500791, 52.43582, 115.2811)
	var peak_aim := Vector3(0.672423, 0.593669, 0.442046).normalized()
	_player.reset_to(peak_at)
	await physics_frame
	await physics_frame
	_piece("foundry_cutter", arena_heading)
	_tech("foundry_cutter", 4, peak_aim)
	var peak_front := _enemy("chaser", 0.0)
	peak_front.global_position = peak_at + peak_aim * 5.0
	peak_front.set_physics_process(false)
	_t.check("captured bowl peak front target has an independent clear ray", _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(peak_at, peak_front.global_position, 1)).is_empty())
	var peak_health: float = peak_front.hp
	_combat.ultimate._peak(_player.ball_position())
	_t.eq("captured bowl peak commits through one selector", _kit.selected_shapes.size(), 1)
	_t.check("captured bowl peak retains exposed volume beside cylinder terrain", not (_kit.selected_shapes[0]["cells"] as Array).is_empty())
	_t.eq("captured bowl peak hits its exposed target exactly once", [snappedf(peak_health - float(peak_front.hp), 0.01), _hits(peak_front).size()], [Weapons.FULL_CUT_DAMAGE, 1])
	arena.queue_free()
	_game.ctx.terrain.use(1)
	await _fresh()


# RIVET-FREEZE: the terrain commit skips clips a margin proves cannot change a part. Its parts
# and shadows must match one plain _subtract_shadow pass per face, byte for byte, across a flat
# floor grid cutting the slab, a wall, a sliver, faces behind the origin and seeded strays.
func _shade_identity_fixture() -> void:
	var origin := Vector3(0.0, 0.3, 0.0)
	var dir := Vector3(1.0, -0.15, 0.2).normalized()
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	var cells: Array = []
	for i in 8:
		var a := dir.rotated(up, lerpf(-0.6, 0.6, float(i) / 8.0))
		var b := dir.rotated(up, lerpf(-0.6, 0.6, float(i + 1) / 8.0))
		var sa := a.cross(up) * 0.4
		var sb := b.cross(up) * 0.4
		cells.append(_kit._commit_cell([origin + sa, origin + a * 12.0 + sa, origin + b * 12.0 - sb, origin - sb], up, 0.5))
	var faces: Array = []
	for x in range(-2, 14, 2):
		for z in range(-8, 8, 2):
			var p := Vector3(x, -0.4, z)
			faces.append([p, p + Vector3(2.0, 0.0, 0.0), p + Vector3(0.0, 0.0, 2.0)])
			faces.append([p + Vector3(2.0, 0.0, 0.0), p + Vector3(2.0, 0.0, 2.0), p + Vector3(0.0, 0.0, 2.0)])
	faces.append([Vector3(9.0, -1.0, -3.0), Vector3(9.0, 2.0, -3.0), Vector3(9.0, 2.0, 3.0), Vector3(9.0, -1.0, 3.0)])
	faces.append([Vector3(5.0, -0.2, 0.0), Vector3(5.0001, -0.2, 0.0), Vector3(5.0, -0.2, 4.0)])
	faces.append([Vector3(-3.0, -1.0, -1.0), Vector3(-3.0, 1.0, 0.0), Vector3(-3.0, -1.0, 1.0)])
	var rng := RandomNumberGenerator.new()
	rng.seed = 36101
	for i in 40:
		var at := Vector3(rng.randf_range(-2.0, 13.0), rng.randf_range(-1.5, 1.5), rng.randf_range(-5.0, 5.0))
		faces.append([at, at + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-2.0, 2.0)), at + Vector3(rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-2.0, 2.0))])
	var plain := cells.duplicate(true)
	var plain_shadows: Array = []
	for face in faces:
		var shadow: Array = _kit._face_shadow(origin, face)
		if shadow.is_empty():
			continue
		plain_shadows.append(shadow)
		var lit: Array = []
		for cell in plain:
			lit.append_array(_kit._subtract_shadow(cell, shadow))
		plain = lit
	var hull := [{"at": origin + up * 0.5, "normal": up}, {"at": origin - up * 0.5, "normal": -up}]
	var shadows: Array = []
	var fast: Array = _kit._shade(origin, faces, cells.duplicate(true), shadows, hull)
	_t.check("shade fixture carves: the floor and wall change the parts", var_to_bytes(plain) != var_to_bytes(cells))
	_t.check("shade parts match a plain subtraction pass byte for byte", var_to_bytes(fast) == var_to_bytes(plain), "%d vs %d parts" % [fast.size(), plain.size()])
	_t.check("shade shadows match a plain subtraction pass byte for byte", var_to_bytes(shadows) == var_to_bytes(plain_shadows), "%d vs %d shadows" % [shadows.size(), plain_shadows.size()])


# FU-RIVET-SHADOW: the empty-shadow case. The silhouette cone meets the cell, but the whole
# cell lies in front of the terrain contact plane, so the full shadow intersection is empty
# and the cell must come back whole. Built from its own geometry, not the kit's cell helpers.
func _empty_shadow_fixture() -> void:
	var origin := Vector3.ZERO
	var wall := [Vector3(6.5, -1.0, -1.0), Vector3(6.5, 1.0, -1.0), Vector3(6.5, 1.0, 1.0), Vector3(6.5, -1.0, 1.0)]
	var centre := Vector3(6.5, 0.0, 0.0)
	var shadow: Array = []
	for i in wall.size():
		var normal: Vector3 = (wall[i] - origin).cross(wall[(i + 1) % wall.size()] - origin).normalized()
		if normal.dot(centre - origin) > 0.0:
			normal = -normal
		shadow.append({"at": origin, "normal": normal, "terrain": true})
	var contact := {"at": wall[0], "normal": Vector3.LEFT, "terrain": true, "solid": true}
	shadow.append(contact)
	var lo := Vector3(2.0, -0.5, -0.5)
	var hi := Vector3(5.0, 0.5, 0.5)
	var a := Vector3(2.0, -0.5, -0.5)
	var b := Vector3(2.0, 0.5, -0.5)
	var c := Vector3(2.0, 0.5, 0.5)
	var d := Vector3(2.0, -0.5, 0.5)
	var e := Vector3(5.0, -0.5, -0.5)
	var f := Vector3(5.0, 0.5, -0.5)
	var g := Vector3(5.0, 0.5, 0.5)
	var h := Vector3(5.0, -0.5, 0.5)
	var faces: Array = [[a, b, c, d], [e, f, g, h], [a, e, h, d], [b, f, g, c], [a, e, f, b], [d, h, g, c]]
	var corners: Array = [a, b, c, d, e, f, g, h]
	# The six box planes bound the cell for point tests; an empty plane list would count every point as inside.
	var box_planes: Array = [{"at": Vector3(2.0, 0.0, 0.0), "normal": Vector3.LEFT}, {"at": Vector3(5.0, 0.0, 0.0), "normal": Vector3.RIGHT},
		{"at": Vector3(0.0, -0.5, 0.0), "normal": Vector3.DOWN}, {"at": Vector3(0.0, 0.5, 0.0), "normal": Vector3.UP},
		{"at": Vector3(0.0, 0.0, -0.5), "normal": Vector3.FORWARD}, {"at": Vector3(0.0, 0.0, 0.5), "normal": Vector3.BACK}]
	var cell := {"faces": faces, "planes": box_planes, "vertices": corners, "bounds": AABB(lo, hi - lo)}
	var cone_meets := shadow.slice(0, 4).all(func(plane): return (((lo + hi) * 0.5) - plane["at"]).dot(plane["normal"]) <= 0.0)
	var in_front := corners.all(func(v): return (v - contact["at"]).dot(contact["normal"]) > 0.0)
	_t.check("empty shadow fixture: silhouette cone meets the cell and the whole cell is in front of the contact", cone_meets and in_front, "%s %s" % [cone_meets, in_front])
	var parts: Array = _kit._subtract_shadow(cell, shadow)
	_t.eq("empty shadow leaves exactly one part", parts.size(), 1)
	var kept: Dictionary = parts[0] if parts.size() == 1 else {}
	_t.eq("empty shadow keeps the cell's original faces", kept.get("faces", []), faces)
	_t.eq("empty shadow keeps the cell's original vertices", kept.get("vertices", []), corners)
	# The selection path (_in_shape, hull forgiveness on) consumes the same shadow with hull_boundary true.
	# Probes behind the terrain contact select nothing from the empty-shadow cell. The unshadowed cell
	# does select the two probes that reach it, so the negative is not trivial. The in-front probe is the
	# positive control that the same shape still selects.
	var shadowed := {"origin": origin, "kind": "area", "cells": [cell], "shadows": [shadow]}
	var unshadowed := {"origin": origin, "kind": "area", "cells": [cell]}
	var behind := [[Vector3(6.6, 0.0, 0.0), 2.0], [Vector3(9.0, 0.0, 0.0), 2.0], [Vector3(6.6, 0.4, 0.4), 2.0]]
	_t.eq("empty shadow selection: nothing behind the terrain contact is selected", behind.map(func(p): return _kit._in_shape(shadowed, p[0], p[1])), [false, false, false])
	_t.eq("empty shadow selection: the unshadowed cell reaches the two probes that touch it", [_kit._in_shape(unshadowed, behind[0][0], behind[0][1]), _kit._in_shape(unshadowed, behind[2][0], behind[2][1])], [true, true])
	_t.check("empty shadow selection: a hull in front of the contact is still selected", _kit._in_shape(shadowed, Vector3(5.2, 0.0, 0.0), 0.5))


func _cylinder_terrain_fixture() -> void:
	await _fresh()
	_piece("foundry_cutter")
	var origin: Vector3 = _player.ball_position()
	var radius := 1.3
	var distance := 6.5
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = 30.0
	collision.shape = cylinder
	wall.add_child(collision)
	_game.add_child(wall)
	wall.global_position = origin + Vector3.RIGHT * distance
	var front := _enemy("chaser", 5.0)
	var covered := _enemy("chaser", 9.0)
	var exposed := _enemy("chaser", 8.0, 1.6)
	for enemy in [front, covered, exposed]:
		enemy.set_physics_process(false)
	await physics_frame
	await physics_frame
	# A ray tangent to the circle has this slope. Perpendicular distance to that
	# tangent independently qualifies the whole-hull negative and exposed-hull positive.
	var slope := radius / sqrt(distance * distance - radius * radius)
	var whole_clearance := slope * 9.0 / sqrt(1.0 + slope * slope)
	var edge_clearance := (slope * 8.0 - 1.6) / sqrt(1.0 + slope * slope)
	_t.check("cylinder independently covers the whole rear hull", whole_clearance > _combat._hull(covered) and 9.0 - _combat._hull(covered) > distance + radius)
	_t.check("cylinder front target has an independent clear ray", _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, front.global_position, 1)).is_empty())
	_t.check("cylinder rear target has an independent blocked ray", not _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, covered.global_position, 1)).is_empty())
	_t.check("cylinder boundary hull independently exposes an edge", edge_clearance > 0.0 and edge_clearance < _combat._hull(exposed))
	_t.check("cylinder boundary centre ray is independently blocked", not _game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin, exposed.global_position, 1)).is_empty())
	var front_health: float = front.hp
	var exposed_health: float = exposed.hp
	_tech("foundry_cutter", 4)
	_combat.ultimate._peak(origin)
	_t.eq("cylinder front target is hit exactly once", [snappedf(front_health - float(front.hp), 0.01), _hits(front).size()], [Weapons.FULL_CUT_DAMAGE, 1])
	_t.eq("cylinder fully covered target receives no hits", _hits(covered).size(), 0)
	_t.eq("cylinder exposed hull is hit exactly once", [snappedf(exposed_health - float(exposed.hp), 0.01), _hits(exposed).size()], [Weapons.FULL_CUT_DAMAGE, 1])
	_t.check("cylinder clipped drawing consumes the selected record", _kit.volume_indicator.shapes.get("rivet_scar", {}) == _kit.selected_shapes[0])
	wall.queue_free()
	await _fresh()


func _run() -> void:
	await _boot()
	# First, so a broken shadow subtraction fails this direct check before a later fixture can stall.
	_empty_shadow_fixture()
	_shade_identity_fixture()
	await _alpha_terrain_cost_fixture()
	await _cylinder_terrain_fixture()
	await _shape_dispatch_fixture()
	await _terrain_shadow_fixture()
	var ult = _combat.ultimate
	_t.check("three rows register tech, peak and landing", Kit.SET_PIECES.all(func(id): return ult._ult_rows.has(id) and ult._ult_rows[id].keys() == ["tech", "peak", "landing"]))

	# The beam: the reticle ray, 40 m, the class width, three a beat, on beats only.
	_piece("foundry_cutter")
	var on_ray := _enemy("chaser", 10.0)
	var off_ray := _enemy("chaser", 10.0, 3.0)
	var too_far := _enemy("chaser", 42.5)
	_t.eq("a beat cuts the machine on the ray", _tech("foundry_cutter", 1), 1)
	_t.eq("12 x heft on the ray", _damage(on_ray), [12.0])
	_t.check("nothing off the class width or past 40 m", _hits(off_ray).is_empty() and _hits(too_far).is_empty())
	_t.near("class I beam is 0.6 m", _kit.beam_width("foundry_cutter"), 0.6)
	_t.eq("the beam does not knock", Vector3(on_ray._knock.x, 0.0, on_ray._knock.z).length() < 0.01, true)
	await _fresh()
	_piece("foundry_cutter")
	var line := []
	for x in [6.0, 9.0, 12.0, 15.0, 18.0]:
		line.append(_enemy("chaser", x))
	_t.eq("at most three a beat", _tech("foundry_cutter", 1), 3)
	_t.check("nearest first", not _hits(line[0]).is_empty() and not _hits(line[2]).is_empty() and _hits(line[3]).is_empty())
	_t.eq("the middle beat is the peak's, not a cut", _tech("foundry_cutter", 4), 0)
	_t.near("aim 90 degrees off the heading clamps to 60", rad_to_deg(Vector3.RIGHT.angle_to(_kit.beam_dir(Vector3.FORWARD, Vector3.RIGHT))), 60.0, 0.01)
	_knob("ult_volley", 1)
	_struck.clear()
	_t.eq("ult_volley cuts a fourth", _tech("foundry_cutter", 2), 4)
	_knob("ult_volley", 0)

	# An elevated reticle ray must not damage its horizontal projection.
	await _fresh()
	_piece("prism_cutter")
	var elevated := _enemy("chaser", 10.0)
	elevated.global_position += Vector3.UP * 10.0
	elevated.set_physics_process(false)
	var projected := _enemy("chaser", 10.0)
	projected.set_physics_process(false)
	await physics_frame
	var elevated_aim := Vector3(1.0, 1.0, 0.0).normalized()
	_t.eq("an elevated Prism beam cuts its 3D target", _tech("prism_cutter", 1, elevated_aim), 1)
	_t.check("the horizontal projection is outside the elevated beam", _hits(projected).is_empty())
	var drawn_dir: Vector3 = (_kit.beam_shapes[1]["to"] - _kit.beam_shapes[1]["from"]).normalized()
	_t.check("the drawn centre beam keeps the aim elevation", drawn_dir.is_equal_approx(elevated_aim), str(drawn_dir))
	_t.near("the heading clamp preserves elevation", _kit.beam_dir(Vector3(0.0, 1.0, -1.0).normalized(), Vector3.RIGHT).y, elevated_aim.y, 0.0001)

	await _fresh()
	_piece("prism_cutter")
	var front := _enemy("chaser", 5.0)
	var covered := _enemy("chaser", 15.0)
	front.set_physics_process(false)
	covered.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(1.0, 20.0, 20.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	_game.add_child(wall)
	wall.global_position = _player.ball_position() + Vector3.RIGHT * 10.0
	await physics_frame
	await physics_frame
	_t.eq("Prism cuts only the machine before world cover", _tech("prism_cutter", 1), 1)
	_t.check("world cover stops damage behind the wall", not _hits(front).is_empty() and _hits(covered).is_empty())
	_t.near("the drawn beam stops on the wall face", (_kit.beam_shapes[1]["to"] as Vector3).x - _player.ball_position().x, 9.5, 0.001)
	wall.queue_free()

	await _fresh()
	_piece("foundry_cutter")
	var reticle_target := _enemy("chaser", 10.0, 3.0)
	reticle_target.set_physics_process(false)
	await physics_frame
	_t.eq("the camera-to-weapon query cuts the offset reticle target", _tech("foundry_cutter", 1, Vector3.RIGHT, Vector3(0.0, 0.0, 3.0)), 1)
	_t.check("the committed beam turns from the weapon toward the camera ray", (_kit.beam_shapes[0]["to"] as Vector3).z > _player.ball_position().z)

	# Full Cut: 90 degrees once, 18 x heft, out to 30 m.
	await _fresh()
	_piece("foundry_cutter")
	var ball: Vector3 = _player.ball_position()
	var left := _enemy("chaser", 20.0 * cos(deg_to_rad(35.0)), 20.0 * sin(deg_to_rad(35.0)))
	var right := _enemy("chaser", 20.0 * cos(deg_to_rad(35.0)), -20.0 * sin(deg_to_rad(35.0)))
	var wide := _enemy("chaser", 20.0 * cos(deg_to_rad(80.0)), 20.0 * sin(deg_to_rad(80.0)))
	var hits: int = _kit.full_cut(ball, Vector3.RIGHT, 1.0)
	_t.eq("Full Cut sweeps both sides of the aim", [_damage(left), _damage(right)], [[18.0], [18.0]])
	_t.check("and nothing outside 90 degrees", _hits(wide).is_empty() and hits == 2, str(hits))
	_t.check("the scar is drawn", _kit.volume_indicator.shapes.has("rivet_scar"))

	# The Breach Skid: the forward cone at 1.5 x the class radius and the 2.5 m ring.
	await _fresh()
	_piece("foundry_cutter")
	var ahead := _enemy("chaser", 8.0)
	var behind_close := _enemy("chaser", -2.0)
	var behind := _enemy("chaser", -6.0)
	var past := _enemy("chaser", 11.5)
	for i in 3:
		_player.chain.link(true, false)
	_player.abilities.spend("movement")
	var charges: int = _player.abilities.slot("movement").charges
	var landed := []
	var chain_mult: float = _player.chain.multiplier()
	var heft_mult: float = Ultimate.HEFT_MULT[ult._heft_index()]
	var expected_damage: float = Ultimate.LANDING_DAMAGE * chain_mult * heft_mult
	var slam_rate: float = _combat.punch_of("slam", 1.0)
	var on_landed := func(_id: String, _at: Vector3, count: int, dealt: float): landed.append([count, dealt])
	_game.events.ultimate_landed.connect(on_landed)
	ult._strike(_player.ball_position())
	_game.events.ultimate_landed.disconnect(on_landed)
	_t.near("class I cone reaches 9 m", _kit.breach_reach(), 9.0)
	_t.check("the skid cone keeps the Shockwave Skid's 10 m and 1.5 m by default",
		PlayerBall.in_skid_cone(Vector3(9.9, 0.0, 0.0), Vector3.RIGHT) and not PlayerBall.in_skid_cone(Vector3(10.1, 0.0, 0.0), Vector3.RIGHT)
		and PlayerBall.in_skid_cone(Vector3(-1.4, 0.0, 0.0), Vector3.RIGHT) and not PlayerBall.in_skid_cone(Vector3(-1.6, 0.0, 0.0), Vector3.RIGHT))
	# The landing's own scrap raises heft after the strike, so the punch is read at the strike's slam rate.
	var at_strike := func(rows: Array): return rows.map(func(row): return snappedf(float(row[2]) * slam_rate, 0.01))
	_t.eq("ahead and inside the ring are hit", [at_strike.call(_hits(ahead)), at_strike.call(_hits(behind_close))], [[snappedf(expected_damage, 0.01)], [snappedf(expected_damage, 0.01)]])
	_t.check("behind and past the reach are not", _hits(behind).is_empty() and _hits(past).is_empty() and int(landed[0][0]) == 2)
	_t.check("the landing pays the captured chain multiplier", chain_mult > 1.0, str(chain_mult))
	_t.near("ultimate_landed reports the independent total damage", float(landed[0][1]) if landed.size() == 1 else -1.0, expected_damage * 2.0, 0.01)
	_t.eq("the landing ends the chain", _player.chain.combo, 0)
	var release: Vector3 = ult._ride.release_velocity()
	_t.check("the exit is flat along the heading at the banked speed", release.is_equal_approx(Vector3.RIGHT * 20.0), str(release))
	_t.eq("the landing grants one sprint charge", _player.abilities.slot("movement").charges, charges + 1)
	var thrown := Vector3(ahead._knock.x, 0.0, ahead._knock.z)
	_t.check("the skid throws forward", thrown.length() > 0.1 and rad_to_deg(thrown.angle_to(Vector3.RIGHT)) <= 1.0, str(ahead._knock))
	var base_knock := thrown.length()
	await _fresh()
	_piece("foundry_cutter")
	ahead = _enemy("chaser", 8.0)
	_knob("ult_pins", 2.0)
	ult._strike(_player.ball_position())
	_t.near("ult_pins throws twice as hard", Vector3(ahead._knock.x, 0.0, ahead._knock.z).length() / base_knock, 2.0, 0.05)
	_knob("ult_pins", 1.0)
	_knob("ult_radius", 2.0)
	_t.near("ult_radius adds 2 m to the reach", _kit.breach_reach(), 11.0)
	_knob("ult_radius", 0.0)

	# Class V: the beam is 1.0 m and the cone 15 m.
	_game.run.mass = (float(RunState.HEFT_CLASS_AT[4]) - 1.0) / RunState.HEFT_PER_MASS + 0.01
	_t.eq("fixture is heft class V", _game.run.heft_class(), 5)
	_t.check("class V beam 1.0 m, cone 15 m", is_equal_approx(_kit.beam_width("foundry_cutter"), 1.0) and is_equal_approx(_kit.breach_reach(), 15.0),
		"%s %s" % [_kit.beam_width("foundry_cutter"), _kit.breach_reach()])
	_game.run.mass = 0.0

	# Wardens: an open core in the cone shatters; a closed guard takes 45 posture at most.
	await _fresh()
	_piece("foundry_cutter")
	var warden := _enemy("warden", 6.0)
	warden.set_physics_process(false)
	for i in 6:
		_tech("foundry_cutter", 1 + (i % 3))
	ult._strike(_player.ball_position())
	_t.check("a closed guard takes 45 posture at most", warden.posture() <= Ultimate.WARDEN_POSTURE_CAP + 0.001 and warden.posture() > 0.0, str(warden.posture()))
	await _fresh()
	_piece("foundry_cutter")
	warden = _enemy("warden", 6.0)
	warden.set_physics_process(false)
	warden._posture.staggered = true
	var chunks: int = warden.chunks_left()
	ult._strike(_player.ball_position())
	_t.check("an open core in the cone shatters", warden.chunks_left() < chunks, "%d -> %d" % [chunks, warden.chunks_left()])
	await _fresh()
	_piece("foundry_cutter")
	var boss := _boss(10.0)
	_tech("foundry_cutter", 1)
	_t.eq("a boss takes x0.5 from the beam", _damage(boss), [6.0])

	# Prism Cutter: three beams 15 degrees apart, two a beam; Focus is one 1.5 m beam for 30.
	await _fresh()
	_piece("prism_cutter")
	_tech("prism_cutter", 1)
	var dirs: Array = _kit.beam_shapes.map(func(s): return ((s["to"] as Vector3) - (s["from"] as Vector3)).normalized())
	_t.eq("Prism draws three beams", dirs.size(), 3)
	_t.check("15 degrees apart", dirs.size() == 3 and absf(rad_to_deg(dirs[0].angle_to(dirs[1])) - 15.0) < 0.01 and absf(rad_to_deg(dirs[1].angle_to(dirs[2])) - 15.0) < 0.01)
	await _fresh()
	_piece("prism_cutter")
	line = []
	for x in [21.0, 24.0, 27.0]:
		line.append(_enemy("chaser", x))
	_t.eq("each prism beam cuts two", _tech("prism_cutter", 1), 2)
	_t.eq("prism beams deal 8 x heft", _damage(line[0]), [8.0])
	_struck.clear()
	ult._peak(_player.ball_position())
	_t.eq("Focus cuts 30 x heft", _damage(line[2]), [30.0])

	# Juggernaut Drive: each machine rammed once, the bow wave throws outward, no collisions.
	await _fresh()
	_piece("juggernaut_drive")
	var rammed := _enemy("chaser", 1.5)
	var beside := _enemy("chaser", 4.0, 5.0)
	_t.eq("the bow wave throws one beside the path", _tech("juggernaut_drive", 1), 1)
	_t.check("outward, away from the path", beside._knock.z > 0.1 and beside._knock.z > absf(beside._knock.x), str(beside._knock))
	_t.eq("the bow wave deals no damage", _hits(beside), [])
	_kit.drive_step(_player.ball_position())
	_kit.drive_step(_player.ball_position())
	_t.eq("each machine is rammed once", _damage(rammed), [snappedf(30.0 * 1.25, 0.01)])
	_t.check("machine collisions are off for the flight", _player.body().get_collision_exceptions().has(rammed))
	_knob("ult_volley", 1)
	_t.near("ult_volley widens the corridor 1 m", _kit.drive_reach(), 4.0)
	_knob("ult_volley", 0)
	ult._peak(_player.ball_position())
	_t.near("Shoulder widens the corridor to 5 m", _kit.drive_reach(), 5.0)
	ult._strike(_player.ball_position())
	_t.check("crowd control slides off 2.0 s past the recovery", _player.immune_left >= Ultimate.RECOVER_SECONDS + 2.0 - 0.001, str(_player.immune_left))
	_t.check("the landing hands every collision back, held only while the ball is inside", _kit._excepted.is_empty() and _player.body().get_collision_exceptions().all(func(b): return _player.exceptions.releasing(b)))
	_player.reset_to(_player.ball_position() - Vector3.RIGHT * 10.0)
	_player.exceptions.step(DT)
	_t.check("the collisions come back once the ball is clear", _player.body().get_collision_exceptions().is_empty())

	# The framework appends the encore before the first strike and emits started only once.
	await _fresh()
	_piece("juggernaut_drive")
	ult._leg = 0
	_knob("ult_encore", true)
	var first_ram := _enemy("chaser", 1.5)
	_kit._step_piece(DT)
	_player.reset_to(ult._ride.target)
	_enemy("chaser", 15.0)
	ult._land(_player.ball_position())
	_t.check("a machine within 30 m starts the encore leg", ult._leg == 1 and ult._plan["legs"].size() == 2 and ult.phase() == Ultimate.FLIGHT)
	_t.check("the encore keeps the first leg's collision exceptions", _kit._excepted.has(first_ram) and _player.body().get_collision_exceptions().has(first_ram))
	var second_ram := _enemy("chaser", 1.5)
	_kit._step_piece(DT)
	_kit._step_piece(DT)
	_t.eq("the encore still rams each machine once", _damage(second_ram), [snappedf(Weapons.DRIVE_DAMAGE * Weapons.DRIVE_RAM_MULT, 0.01)])
	_t.check("the encore also excepts its new machine", _kit._excepted.has(second_ram) and _player.body().get_collision_exceptions().has(second_ram))
	_knob("ult_encore", false)
	ult._land(_player.ball_position())
	_t.check("the last leg releases all Drive state, holding collisions only while the ball is inside", _kit._piece == "" and _kit._excepted.is_empty() and _player.body().get_collision_exceptions().all(func(b): return _player.exceptions.releasing(b)))
	_player.reset_to(_player.ball_position() - Vector3.RIGHT * 10.0)
	_player.exceptions.step(DT)
	_t.check("the last leg's collisions come back once the ball is clear", _player.body().get_collision_exceptions().is_empty())

	await _fresh()
	_piece("juggernaut_drive")
	warden = _enemy("warden", 2.0)
	warden.set_physics_process(false)
	_kit.drive_step(_player.ball_position())
	_t.check("a closed Warden 2 m ahead can block the flight", not warden.staggered() and not _player.body().get_collision_exceptions().has(warden) and not _kit._excepted.has(warden))
	warden._posture.staggered = true
	_kit.drive_step(_player.ball_position())
	_t.check("a staggered Warden may be passed", _player.body().get_collision_exceptions().has(warden) and _kit._excepted.has(warden))

	warden._posture.staggered = false
	_kit.drive_step(_player.ball_position())
	_t.check("a guard re-closed on the ball leaves the drive and passes the ball until it is clear", not _kit._excepted.has(warden) and _player.exceptions.releasing(warden) and _player.body().get_collision_exceptions().has(warden))
	_player.reset_to(_player.ball_position() - Vector3.RIGHT * 10.0)
	_player.exceptions.step(DT)
	_t.check("once clear the guard blocks the ball again", not _player.exceptions.holding(warden) and not _player.body().get_collision_exceptions().has(warden))

	# ult_beats: two more beats in the plan.
	await _fresh()
	_combat.ultimate._phase = "idle"
	var plain: int = ult.plan(_player.ball_position(), {})["beats"]
	_knob("ult_beats", 2)
	_t.eq("ult_beats adds two beats", int(ult.plan(_player.ball_position(), {})["beats"]) - plain, 2)
	_knob("ult_beats", 0)

	# The tree: depth 3 swaps, one of each per pair; depth 4 knobs; movement stays with Rivet.
	var nodes: Array = RivetTree.NODES
	var pairs_ok := true
	for i in range(2, 6):
		var kids := [nodes[2 * i + 2].get("swap", {}).get("ultimate", ""), nodes[2 * i + 3].get("swap", {}).get("ultimate", "")]
		kids.sort()
		pairs_ok = pairs_ok and kids == ["juggernaut_drive", "prism_cutter"]
	_t.check("every world-2 pair offers one Prism and one Juggernaut", pairs_ok)
	var a := AbilityState.new()
	a.fit(ClassDef.by_id("runner_gunner"))
	UpgradeTree.apply_pick(a, nodes[6])
	var b := AbilityState.new()
	b.fit(ClassDef.by_id("runner_gunner"))
	UpgradeTree.apply_pick(b, nodes[7])
	_t.eq("r_crossfire and r_magnet_blast swap Q", [nodes[6]["id"], a.ultimate_id, nodes[7]["id"], b.ultimate_id],
		["r_crossfire", "prism_cutter", "r_magnet_blast", "juggernaut_drive"])
	_t.check("every depth-4 node turns one ultimate knob", nodes.slice(14).all(func(n): return n.get("knob", {}).keys().filter(func(k): return String(k).begins_with("ult_")).size() == 1))
	_t.eq("depths 1 and 2 carry no ultimate op", nodes.slice(0, 6).filter(func(n): return n.has("swap") and n["swap"].has("ultimate") or n.get("knob", {}).keys().any(func(k): return String(k).begins_with("ult_"))), [])
	_t.check("every changed node stays with Rivet (class_id, capped)", nodes.slice(6).all(func(n): return n.get("class_id", "") == "runner_gunner" and n.get("stack_rule", "") == "capped"))
	_t.eq("the tree is sound", UpgradeTree.problems("runner_gunner"), [])
	var tree := UpgradeTree.new()
	tree.reset("runner_gunner")
	var sweep_ok := true
	for copies in range(1, 21):
		tree.picks = []
		for c in copies:
			tree.picks.append("r_demolisher")
		tree._resolve()
		sweep_ok = sweep_ok and float(tree.knob("ult_pins")) == 2.0 and tree.procs().is_empty()
	_t.check("stack sweep: 1 to 20 copies keep ult_pins capped at 2.0, no proc chain", sweep_ok)
	_t.eq("set-piece card lines", [WorldOneCards.set_piece_line(nodes[6]), WorldOneCards.set_piece_line(nodes[17])],
		[WorldOneCards.SET_PIECE_LINES["prism_cutter"], WorldOneCards.SET_PIECE_LINES["ult_pins"]])
	_t.check("Rivet's depth-4 cards use his own cut, drive and skid wording", nodes.slice(14).all(func(n):
		var card_line := WorldOneCards.set_piece_line(n, WorldOneCards.SET_PIECE_LINES, "runner_gunner")
		var knobs: Array = n["knob"].keys().filter(func(k): return String(k).begins_with("ult_"))
		return card_line == WorldOneCards.SET_PIECE_LINES.get("runner_gunner:" + String(knobs[0]), WorldOneCards.SET_PIECE_LINES.get(knobs[0], "")) and card_line != ""))

	# Cards and grants: the discoveries are declared, detected in the kit and pay the three items.
	await _fresh()
	_piece("foundry_cutter")
	for x in [5.0, 7.0, 9.0]:
		_enemy("chaser", x)
	for x in [-1.0, 1.5, 3.0]:
		_enemy("chaser", x, 1.0)
	_tech("foundry_cutter", 1)
	var six := []
	var on_six := func(id: String, _at: Vector3, count: int, _dealt: float): six.append([id, count])
	_game.events.ultimate_landed.connect(on_six)
	ult._strike(_player.ball_position())
	_game.events.ultimate_landed.disconnect(on_six)
	_t.check("a Foundry Cutter landing on six reports six hits, which Full Breach reads", six.size() == 1 and six[0][0] == "foundry_cutter" and int(six[0][1]) >= 6, str(six))
	_t.check("a beam that cut three queues the Foundry Cutter card", _kit._cards.has("rivet_foundry_cutter"))
	_kit._shrugs = 0
	for i in Kit.SHRUG_HITS:
		_game.events.cc_ignored.emit("test")
	_t.check("the 30th ignored hit queues Shrugged Off", _kit._cards.has("rivet_shrugged"))
	# The Line Drive card: the pin that follows a punch, on a second machine.
	var puncher := _enemy("chaser", 20.0)
	var pinned := _enemy("chaser", 22.0)
	_kit.last_punch = {"id": puncher.get_instance_id(), "clock": _kit._clock, "punch": 1.0, "dir": Vector3.RIGHT}
	_game.events.enemy_pinned.emit(pinned, 1.0)
	_t.check("the pin after a punch queues the Line Drive card", _kit._cards.has("rivet_line_drive"))
	# B6's rule: a pilot card waits for the framework card it extends, then opens once. The
	# framework's own landing above opened set_piece; nothing here has opened loaded_line.
	await _step_cards(4)
	var log: Array = _combat.discovery_log
	_t.check("Line Drive waits for loaded_line; Foundry Cutter opens after set_piece",
		not _combat.discovered.has("rivet_line_drive") and _combat.discovered.has("rivet_shrugged")
		and log.has("set_piece") and log.find("set_piece") < log.find("rivet_foundry_cutter"), str(log))
	_combat._discover("loaded_line", _player.ball_position())
	await _step_cards(8)
	_kit.last_punch = {"id": puncher.get_instance_id(), "clock": _kit._clock, "punch": 1.0, "dir": Vector3.RIGHT}
	_game.events.enemy_pinned.emit(pinned, 1.0)
	await _step_cards(4)
	_t.check("then each opens in the codex exactly once", ["rivet_line_drive", "rivet_foundry_cutter", "rivet_shrugged"].all(func(id): return log.count(id) == 1)
		and _kit._cards.is_empty(), "%s left %s" % [log, _kit._cards.keys()])
	# Line True: ten Line Drive punches landed in one stage.
	var target := _enemy("chaser", 6.0)
	for i in Kit.LINE_TRUE_PUNCHES - 1:
		_kit._punch(target, 10.0, 1.0, Vector3.RIGHT)
	await _step_cards(4)
	_t.check("nine punches do not open Line True", not _combat.discovered.has("rivet_line_true") and not _kit._cards.has("rivet_line_true"))
	_kit._punch(target, 10.0, 1.0, Vector3.RIGHT)
	await _step_cards(4)
	_t.check("the tenth punch opens Line True once", log.count("rivet_line_true") == 1, str(log))
	var ids := ["rivet_line_drive", "rivet_foundry_cutter", "rivet_line_true", "rivet_shrugged"]
	_t.check("each card is declared with a kit detector", ids.all(func(id): return CodexEntries.ids().has(id) and CodexEntries.DETECTORS[id]["script"] == "res://src/combat/rivet_kit.gd"))
	var grants := {"ach_rivet_line_true": "trail_rivet_swarf", "ach_rivet_shrugged": "outfit_rivet_hood"}
	var grants_ok := true
	for id in grants:
		var row: Dictionary = Achievements.row(id)
		grants_ok = grants_ok and row.get("on") == "synergy_discovered" and not row["where"].has("first_time") \
			and Achievements.reward_of(id).get("cosmetic", "") == grants[id]
	_t.check("two grants on named discoveries pay two items", grants_ok)
	var breach: Dictionary = Achievements.row("ach_rivet_full_breach")
	_t.check("Full Breach grants on one base Foundry Cutter landing of six machines",
		breach.get("on") == "ultimate_landed" and breach.get("where") == {"ultimate_id": "foundry_cutter"} and breach.get("at_least") == {"hits": 6}
		and int(breach.get("count", 0)) == 1 and Achievements.reward_of("ach_rivet_full_breach").get("cosmetic", "") == "shell_rivet_calibrated", str(breach))
	grants["ach_rivet_full_breach"] = "shell_rivet_calibrated"
	_t.check("the items wait for their art", grants.values().all(func(id): return Cosmetics.PENDING_ART.has(id)))
	_t.check("both line cues are keyed and read the Rivet motif", Audio.KEYED_SOUNDS.has(Audio.RIVET_LINE["punch"]) and Audio.KEYED_SOUNDS.has(Audio.RIVET_LINE["arrive"])
		and Audio.RIVET_LINE["motif"] == ClassDef.by_id("runner_gunner").motif)
	_finish()
