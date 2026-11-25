extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const Arena := preload("res://src/boss/arena.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const Palette := preload("res://src/core/palette.gd")


const SIZE := Vector2i(1920, 1080)
const TARGETS := {
	"altar": "AltarPost", "cache_pocket": "CacheShell", "cache_pedestal": "CachePedestal",
	"find_board": "RoomBoardFrame", "find_aerial": "FindAerial", "find_seep": "FindSeep*",
	"radio_cache": "RadioMast", "pocket_block": "PocketBlock", "pocket_post": "PocketPost",
	"valve_door": "ValveDoor", "cracked_wall": "CacheWallBack", "bounty_crate": "BountyCrate",
	"slag_mast": "CraneMast", "slag_boom": "CraneBoom", "slag_vent": "VentNozzle_*",
	"bay_cabin": "BayCabin", "bay_bell": "BayBell", "bay_marble_toy": "BayMarbleToy", "bay_yard_wall": "BayYardWall",
	"bay_post": "BayPost", "bay_pin": "BayPin", "cradle_cup": "CradleCup", "cradle_mast": "CradleMast",
	"cable_coil": "@cable",
}

var _out := ""
var _dry := false
var _only: Array = []
var _game
var _found := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--dry":
			_dry = true
		elif arg.begins_with("--only="):
			_only = Array(arg.trim_prefix("--only=").split(","))
	if not _dry and (_out.is_empty() or DisplayServer.get_name() == "headless"):
		printerr("stand_in_capture: needs a rendered display and -- --out=<absolute dir> (or --dry)")
		quit(2)
		return
	if not _dry:
		DirAccess.make_dir_recursive_absolute(_out)
		root.size = SIZE
		root.content_scale_size = SIZE
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_main.call_deferred()


func _main() -> void:
	seed(280928)
	if not _dry:
		GraphicsPreset.apply("high")
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await process_frame
	await process_frame
	_game.tuning.set_option("profile", "sitting")
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(999999.0)
	_game.player.source = Intent.Scripted.new()
	for i in 120:
		await process_frame
	var cam: Camera3D = null
	if not _dry:
		_game.presentation.hide_ui()
		cam = Camera3D.new()
		cam.near = 0.1
		cam.far = 2000.0
		_game.add_child(cam)
	var defs = _game.ctx.stages
	var record := {}
	var stage := 0
	while stage == 0 or not defs.is_last(stage):
		stage += 1
		if _found.size() == TARGETS.size() - (0 if _found.has("bounty_crate") else 1):
			break
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
		for i in 600:
			await process_frame
			if _game.ctx.terrain.is_ready(stage) and i > 60 and _scatter_ready():
				break
		_park_ball()
		if stage == defs.last_of(1):
			var bowl: Node3D = Arena.take_ahead()
			bowl.position = Arena.place_ahead(_game.ctx.terrain, stage)
			_game.ctx.root.add_child(bowl)
			while not bowl.built():
				bowl.build_step()
		_dock_bay(stage)
		_diagnose(stage)
		await _shoot_stage(stage, cam, record)
	if not _found.has("bounty_crate") and _wanted("bounty_crate"):
		await _shoot_rebuilt_crate(cam, record)
	for label: String in TARGETS:
		if _wanted(label) and not record.has(label):
			record[label] = {"found": false}
			print("stand_in_capture: %s (%s) not found in the park" % [label, TARGETS[label]])
	if not _dry:
		var f := FileAccess.open(_out.path_join("shots.json"), FileAccess.WRITE)
		f.store_string(JSON.stringify(record, " "))
		f.close()
	print("stand_in_capture: %d of %d found" % [record.values().filter(func(r): return r.get("found", false)).size(), record.size()])
	quit(0)


func _dock_bay(stage: int) -> void:
	var map = _game.ctx.terrain.map()
	var bay = _game.world.bay
	if bay.docked or map == null or not "bay_dock" in map or map.bay_dock.is_empty():
		return
	var at: Vector2 = map.bay_dock["at"]
	var ground := Vector3(at.x, _game.ctx.terrain.height(at.x, at.y), at.y)
	var ok: bool = bay.dock([{"at": ground, "facing": map.bay_dock["facing"]}], Callable(_game.ctx.terrain, "height"),
		root.get_world_3d().direct_space_state, map)
	print("stand_in_capture: bay docked on stage %d: %s" % [stage, ok])


func _diagnose(stage: int) -> void:
	var tally := {}
	for view: Node in _game.find_children("*", "GeometryInstance3D", true, false):
		var key := String(view.name)
		if view is MultiMeshInstance3D and view.has_meta("kind"):
			key = "@" + String(view.get_meta("kind"))
		for want: String in TARGETS.values():
			if key == want or (want.ends_with("*") and key.begins_with(want.trim_suffix("*"))):
				tally[want + (" vis" if view.is_visible_in_tree() else " hid")] = tally.get(want + (" vis" if view.is_visible_in_tree() else " hid"), 0) + 1
	print("stand_in_capture: stage %d tally %s" % [stage, tally])


func _scatter_ready() -> bool:
	for node in _game.find_children("GroundScatter", "", true, false):
		if node.is_visible_in_tree() and "phase" in node and node.phase != node.Phase.READY:
			return false
	return true


func _wanted(label: String) -> bool:
	return _only.is_empty() or _only.has(label)


func _park_ball() -> void:
	_game.player.set_frozen(true)
	_game.player.body().global_position = Vector3(-4000, 400, -4000)


func _shoot_stage(stage: int, cam: Camera3D, record: Dictionary) -> void:
	for label: String in TARGETS:
		if _found.has(label) or not _wanted(label):
			continue
		var hit := _find(TARGETS[label], false)
		if hit.is_empty():
			hit = _find(TARGETS[label], true)
		if hit.is_empty():
			continue
		var hidden: Array = []
		if hit.has("view"):
			var node: Node = hit["view"]
			while node != null:
				if node is Node3D and not node.visible:
					node.visible = true
					hidden.append(node)
				node = node.get_parent()
		_found[label] = true
		var row := {"found": true, "stage": stage, "revealed": not hidden.is_empty(), "path": hit["path"], "material": hit["material"], "centre": _v(hit["centre"])}
		print("stand_in_capture: %s on stage %d at %s (%s)%s" % [label, stage, hit["centre"], hit["material"], " revealed" if not hidden.is_empty() else ""])
		if cam != null:
			row["close"] = await _shot(cam, label + "_close", hit["centre"], hit["facing"], maxf(hit["radius"] * 3.0, 3.0))
			row["play"] = await _shot(cam, label + "_play", hit["centre"], hit["facing"], 30.0)
		for node: Node3D in hidden:
			node.visible = false
		record[label] = row


func _find(want: String, hidden: bool) -> Dictionary:
	if want.begins_with("@"):
		for view: MultiMeshInstance3D in _game.find_children("Scatter_" + want.trim_prefix("@"), "MultiMeshInstance3D", true, false):
			if not view.is_visible_in_tree() or view.multimesh == null:
				continue
			var origins: PackedVector3Array = view.get_meta("origins", PackedVector3Array())
			if origins.is_empty():
				continue
			var mat = view.material_override
			return {"path": str(view.get_path()), "centre": view.global_transform * origins[0] + Vector3.UP * 0.2, "radius": 0.6, "facing": Vector3.BACK,
				"material": (mat.get_class() + ":" + String(mat.resource_name)) if mat != null else "none"}
		return {}
	for view: MeshInstance3D in _game.find_children("*", "MeshInstance3D", true, false):
		if view.is_visible_in_tree() == hidden or view.mesh == null:
			continue
		var centre: Vector3
		var radius: float
		if want.begins_with("@"):
			continue
		else:
			var name := String(view.name)
			if not (name == want or (want.ends_with("*") and name.begins_with(want.trim_suffix("*")))):
				continue
			var box: AABB = view.global_transform * view.mesh.get_aabb()
			centre = box.get_center()
			radius = box.size.length() * 0.5
		var facing := view.global_basis.z
		facing.y = 0.0
		facing = facing.normalized() if facing.length() > 0.01 else Vector3.BACK
		var mat = view.material_override if view.material_override != null else view.mesh.surface_get_material(0)
		return {"view": view, "path": str(view.get_path()), "centre": centre, "radius": radius, "facing": facing,
			"material": (mat.get_class() + ":" + String(mat.resource_name)) if mat != null else "none"}
	return {}


func _shot(cam: Camera3D, id: String, at: Vector3, facing: Vector3, distance: float) -> Dictionary:
	var dir := (facing.rotated(Vector3.UP, deg_to_rad(30.0)) + Vector3.UP * 0.35).normalized()
	var eye := at + dir * distance
	eye.y = maxf(eye.y, _game.ctx.terrain.height(eye.x, eye.z) + 1.5)
	cam.fov = 55.0
	cam.make_current()
	cam.global_position = eye
	cam.look_at(at)
	for f in 20:
		await process_frame
	root.get_texture().get_image().save_png(_out.path_join(id + ".png"))
	return {"eye": _v(eye), "at": _v(at)}


func _shoot_rebuilt_crate(cam: Camera3D, record: Dictionary) -> void:
	var holder := Node3D.new()
	_game.ctx.root.add_child(holder)
	var p: Vector3 = Arena.place_ahead(_game.ctx.terrain, _game.ctx.stages.last_of(1)) + Vector3(0, 0, -60)
	p.y = _game.ctx.terrain.height(p.x, p.z)
	holder.global_position = p
	var glow := Palette.solid(Palette.AMBER, 1.6)
	var crate := CrackedCache.model_part("CacheChest", holder)
	if crate == null:
		record["bounty_crate"] = {"found": false, "rebuilt": true}
		return
	crate.transform = Transform3D(Basis.from_scale(Vector3(0.7, 0.73, 0.95)), Vector3(0.0, 2.35, -0.5))
	CrackedCache.model_part("CacheLid", crate).position = Vector3.UP * 1.35
	crate.get_child(0).material_override = glow
	crate.material_override = glow
	crate.name = "BountyCrate"
	var box: AABB = crate.global_transform * crate.mesh.get_aabb()
	var row := {"found": true, "rebuilt": true, "material": "StandardMaterial3D:glow", "centre": _v(box.get_center())}
	print("stand_in_capture: bounty_crate rebuilt at %s" % box.get_center())
	if cam != null:
		row["close"] = await _shot(cam, "bounty_crate_close", box.get_center(), Vector3.BACK, 4.0)
		row["play"] = await _shot(cam, "bounty_crate_play", box.get_center(), Vector3.BACK, 30.0)
	record["bounty_crate"] = row


static func _v(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]
