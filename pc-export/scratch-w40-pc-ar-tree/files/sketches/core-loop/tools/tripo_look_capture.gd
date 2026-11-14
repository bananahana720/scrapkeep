extends SceneTree
# SCRATCH ONLY (PC lane job AR, 13 Nov 2026), not for any game branch.
# PR 985's Tripo siblings in the running game, with and without --models=tripo (pass it on the command line;
# ModelVariants reads it). Same seed and framing both ways. Each target gets a close shot and a mid shot
# placed inside its LOD1 range, so the detail-level swap shows.
#   <godot> --path sketches/core-loop --script res://tools/tripo_look_capture.gd -- --out=/abs --phase=camp|park [--models=tripo]
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")

const SIZE := Vector2i(1920, 1080)
const PROPS := {1: ["gate_wheelhouse", "mixer_wreck", "survey_tent"], 2: ["skiff_on_blocks", "boom_crane_wreck"]}

var _out := ""
var _phase := "park"
var _game
var _cam: Camera3D
var _rec := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--phase="):
			_phase = arg.trim_prefix("--phase=")
	if _out.is_empty() or DisplayServer.get_name() == "headless":
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _save(id: String) -> void:
	await _frames(12)
	root.get_texture().get_image().save_png(_out.path_join(id + ".png"))


func _hide_hud() -> void:
	for node in root.find_children("*", "CanvasLayer", true, false):
		node.visible = false


func _shot(id: String, at: Vector3, facing: Vector3, distance: float, rise := 0.35) -> Dictionary:
	var dir := (facing.rotated(Vector3.UP, deg_to_rad(30.0)) + Vector3.UP * rise).normalized()
	var eye := at + dir * distance
	if _game.ctx != null and _game.ctx.terrain != null and _phase == "park":
		eye.y = maxf(eye.y, _game.ctx.terrain.height(eye.x, eye.z) + 1.5)
	_cam.fov = 55.0
	_cam.make_current()
	_cam.global_position = eye
	_cam.look_at(at)
	_hide_hud()
	await _save(id)
	return {"eye": _v(eye), "at": _v(at), "distance": snappedf(distance, 0.1)}


func _main() -> void:
	seed(280928)
	GraphicsPreset.apply("high")
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await _frames(2)
	_cam = Camera3D.new()
	_cam.near = 0.1
	_cam.far = 2000.0
	_game.add_child(_cam)
	_rec["tripo"] = ModelVariants.enabled()
	if _phase == "camp":
		await _camp()
	else:
		await _park()
	var f := FileAccess.open(_out.path_join("shots-%s.json" % _phase), FileAccess.WRITE)
	f.store_string(JSON.stringify(_rec, " "))
	f.close()
	print("tripo_look_capture: done ", _rec.keys())
	quit(0)


func _camp() -> void:
	_game.screens.toggle_camp()
	for i in 900:
		await process_frame
		if _game.screens.walk_live():
			break
	await _frames(120)
	var hub = _game.camp_hub
	var pet: Node3D = hub.get("_pet")
	if pet == null:
		_rec["camp_pet"] = {"found": false}
		return
	var box := _aabb(pet)
	var facing := pet.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
	_rec["camp_pet"] = {"found": true, "centre": _v(box.get_center()), "size": _v(box.size),
		"close": await _shot("camp_pet_close", box.get_center(), facing, maxf(box.size.length() * 2.5, 2.5)),
		"mid": await _shot("camp_pet_mid", box.get_center(), facing, 14.0)}


func _park() -> void:
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	await _frames(120)
	for stage in [1, 2]:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		for i in 900:
			await process_frame
			if _game.ctx.terrain.is_ready(stage) and i > 90 and _scatter_ready():
				break
		await _frames(30)
		var parked := Vector3(-4000, 400, -4000)
		_game.player.set_frozen(true)
		_game.player.body().global_position = parked
		for kind: String in PROPS[stage]:
			await _prop(kind)
		if stage == 1:
			await _chasers()
		else:
			await _tender()


func _scatter_ready() -> bool:
	for node in _game.find_children("GroundScatter", "", true, false):
		if node.is_visible_in_tree() and "phase" in node and node.phase != node.Phase.READY:
			return false
	return true


# The first near (lod 0) view of a kit kind, and the begin of that instance's lod 1 range.
func _prop(kind: String) -> void:
	var near: GeometryInstance3D = null
	for view: GeometryInstance3D in _game.find_children("*", "GeometryInstance3D", true, false):
		if view.get_meta("dress_kind", "") == kind and int(view.get_meta("dress_lod", -1)) == 0 and view is MeshInstance3D and view.mesh != null:
			near = view
			break
	if near == null:
		_rec[kind] = {"found": false}
		print("tripo_look_capture: %s not found" % kind)
		return
	var box: AABB = near.global_transform * near.mesh.get_aabb()
	var lod1_begin := 0.0
	for view: GeometryInstance3D in _game.find_children("*", "GeometryInstance3D", true, false):
		if view.get_meta("dress_kind", "") == kind and int(view.get_meta("dress_lod", -1)) == 1:
			if view is MeshInstance3D and view.mesh != null and (view.global_transform * view.mesh.get_aabb()).get_center().distance_to(box.get_center()) < 2.0:
				lod1_begin = view.visibility_range_begin
				break
	if lod1_begin <= 0.0:
		lod1_begin = near.visibility_range_end
	var facing := near.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
	var ground: float = _game.ctx.terrain.height(box.get_center().x, box.get_center().z)
	_rec[kind] = {"found": true, "centre": _v(box.get_center()), "size": _v(box.size), "base_above_ground_m": snappedf(box.position.y - ground, 0.01),
		"mesh": String(near.mesh.resource_path), "lod1_begin_m": lod1_begin, "lod0_end_m": near.visibility_range_end,
		"close": await _shot(kind + "_close", box.get_center(), facing, maxf(box.size.length() * 1.2, 4.0)),
		"mid": await _shot(kind + "_mid", box.get_center(), facing, lod1_begin + 15.0)}


func _chasers() -> void:
	var terrain = _game.ctx.terrain
	var at: Vector3 = terrain.drop_point(-65.0, -130.0, 1.0)
	_game.player.set_frozen(false)
	_game.player.reset_to(at)
	await _frames(30)
	var ahead := Vector3(0, 0, -1)
	var spawned := []
	for k in 3:
		var p: Vector3 = terrain.drop_point(at.x + (k - 1) * 3.0, at.z - 9.0 - k, 1.0)
		spawned.append(_game.ctx.spawner.spawn_enemy("chaser", p))
	await _frames(150)
	var centre := Vector3.ZERO
	var live := 0
	for e in spawned:
		if is_instance_valid(e):
			centre += e.global_position
			live += 1
	centre = centre / maxf(live, 1) + Vector3.UP * 0.8
	paused = true
	var game_cam := root.get_viewport().get_camera_3d()
	_hide_hud()
	await _save("dam_chasers_play")
	var row := {"found": live > 0, "live": live, "centre": _v(centre),
		"play_cam": _v(game_cam.global_position) if game_cam != null else null}
	var mesh_path := ""
	for e in spawned:
		if is_instance_valid(e):
			for m: MeshInstance3D in e.find_children("*", "MeshInstance3D", true, false):
				if m.mesh != null and m.mesh.resource_path != "":
					mesh_path = m.mesh.resource_path
					break
			break
	row["mesh"] = mesh_path
	row["close"] = await _shot("dam_chasers_close", centre, ahead.rotated(Vector3.UP, PI), 7.0)
	row["mid"] = await _shot("dam_chasers_mid", centre, ahead.rotated(Vector3.UP, PI), 40.0)
	paused = false
	_rec["dam_chasers"] = row
	for e in spawned:
		if is_instance_valid(e):
			e.queue_free()
	_game.player.set_frozen(true)
	_game.player.body().global_position = Vector3(-4000, 400, -4000)
	await _frames(10)


# The boom tender beside Boom 3 (the flume's boom_crane_wreck vignette).
func _tender() -> void:
	var crane = _rec.get("boom_crane_wreck", {})
	var terrain = _game.ctx.terrain
	var base := Vector3(-65.0, 0.0, -130.0)
	if crane.get("found", false):
		var c: Array = crane["centre"]
		base = Vector3(c[0], 0.0, c[2]) + Vector3(9.0, 0.0, 0.0)
	var at: Vector3 = terrain.drop_point(base.x, base.z, 0.5)
	var tender = _game.ctx.spawner.spawn_enemy("boom_tender", at)
	await _frames(90)
	if tender == null or not is_instance_valid(tender):
		_rec["boom_tender"] = {"found": false}
		return
	var box := _aabb(tender)
	var facing: Vector3 = tender.global_basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
	paused = true
	_rec["boom_tender"] = {"found": true, "centre": _v(box.get_center()), "size": _v(box.size), "beside_boom3": crane.get("found", false),
		"close": await _shot("boom_tender_close", box.get_center(), facing, maxf(box.size.length() * 1.3, 6.0)),
		"mid": await _shot("boom_tender_mid", box.get_center(), facing, 45.0)}
	paused = false


func _aabb(node: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if m.mesh == null or not m.is_visible_in_tree():
			continue
		var b: AABB = m.global_transform * m.mesh.get_aabb()
		box = b if first else box.merge(b)
		first = false
	if first:
		box = AABB(node.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	return box


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
