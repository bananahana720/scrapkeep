extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")


const STREAK := 2.0

var _game
var _driver
var _out := ""
var _seed := 1
var _policy := "skipper"
var _until := 3
var _tick_cap := 0
var _every := 4
var _interp := true
var _ticks := 0
var _frames := 0
var _checked := 0
var _before := {}
var _rested := {}
var _stepped := {}
var _armed := false
var _rows := {}
var _done := false


class Late extends Node:
	var audit

	func _process(_delta: float) -> void:
		audit._after_process()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--seed="):
			_seed = int(arg.trim_prefix("--seed="))
		elif arg.begins_with("--policy="):
			_policy = arg.trim_prefix("--policy=")
		elif arg.begins_with("--until="):
			_until = int(arg.trim_prefix("--until="))
		elif arg.begins_with("--ticks="):
			_tick_cap = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--every="):
			_every = maxi(1, int(arg.trim_prefix("--every=")))
		elif arg.begins_with("--interp="):
			_interp = arg.trim_prefix("--interp=") != "0"
	if _out == "":
		printerr("interp_audit: --out=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_out)
	seed(_seed)
	_game = Game.new()
	_game.test_mode = true
	_game.run_store_path = _out.path_join("entrance.json")
	root.add_child(_game)
	# Headless never draws, so frame_pre_draw never fires: a node that processes last stands in.
	var late := Late.new()
	late.audit = self
	late.process_priority = 2147483647
	root.add_child(late)


func _physics_process(delta: float) -> bool:
	if _done or _game == null or _game.flow == null:
		return false
	if _driver == null:
		_game.codex.storage_dir = _out
		_game.run_log.storage_dir = _out
		_game.run_moments.storage_dir = _out
		_driver = BotDriver.new(_game, _policy, _seed)
		_game.presentation.audio.bake_opening_now()
		_game.run.run_seed_override = _seed
		physics_interpolation = _interp
		_driver.start(false)
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	if not over and _until > 0 and _game.run.stage > _until:
		over = true
	if not over and _tick_cap > 0 and _ticks >= _tick_cap:
		over = true
	if over:
		_finish()
	return false


func _process(_delta: float) -> bool:
	if _done or _driver == null:
		return false
	_frames += 1
	_armed = _frames % _every == 0
	if not _armed:
		return false
	_before.clear()
	_stepped.clear()
	for node: Node3D in root.find_children("*", "Node3D", true, false):
		var id := node.get_instance_id()
		_before[id] = node.transform
		if _rested.has(id) and not node.transform.is_equal_approx(_rested[id]):
			_stepped[id] = true
	return false


func _after_process() -> void:
	if _done:
		return
	if (_frames + 1) % _every == 0:
		_rested.clear()
		for node: Node3D in root.find_children("*", "Node3D", true, false):
			_rested[node.get_instance_id()] = node.transform
	if not _armed:
		return
	_armed = false
	_checked += 1
	var stage: int = _game.run.stage if _game.run != null else 0
	for node: Node3D in root.find_children("*", "Node3D", true, false):
		if not node.is_visible_in_tree():
			continue
		var id := node.get_instance_id()
		var interpolated := node.is_physics_interpolated()
		if _before.has(id) and not node.transform.is_equal_approx(_before[id]):
			_note("MOVER" if interpolated else "off", node, stage, 0.0)
			continue
		if interpolated:
			var gap := node.get_global_transform_interpolated().origin.distance_to(node.global_position)
			if gap > STREAK:
				_note("STREAK", node, stage, gap)
				continue
		if _stepped.has(id):
			_note("smooth" if interpolated else "STEP", node, stage, node.transform.origin.distance_to(_rested[id].origin))


func _note(kind: String, node: Node3D, stage: int, gap: float) -> void:
	var key := kind + " " + _key(node)
	if not _rows.has(key):
		_rows[key] = {"kind": kind, "where": _key(node), "frames": 0, "stages": {}, "max_gap": 0.0,
			"class": node.get_class(), "sample": String(node.get_path()), "first_tick": _ticks}
	var row: Dictionary = _rows[key]
	row.frames += 1
	row.stages[stage] = true
	row.max_gap = maxf(row.max_gap, gap)


func _key(node: Node3D) -> String:
	var names: Array[String] = []
	var at: Node = node
	while at != null and at != root:
		var script: Script = at.get_script()
		if script != null and script.resource_path != "":
			names.reverse()
			return script.resource_path.trim_prefix("res://") + (" > " + "/".join(names) if names.size() > 0 else "")
		names.append(_plain(String(at.name)))
		at = at.get_parent()
	names.reverse()
	return "(no script) " + "/".join(names)


func _plain(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		if not (c >= "0" and c <= "9") and c != "@":
			out += c
	return out


func _finish() -> void:
	_done = true
	var rows: Array = _rows.values()
	rows.sort_custom(func(a, b):
		if a.kind != b.kind:
			return a.kind < b.kind
		return a.frames > b.frames)
	print("INTERP_AUDIT interpolation=%s seed=%d policy=%s ticks=%d frames=%d checked=%d stage=%d outcome=%s" % [
		physics_interpolation, _seed, _policy, _ticks, _frames, _checked, _game.run.stage, _driver.outcome])
	for row in rows:
		var stages: Array = row.stages.keys()
		stages.sort()
		row.stages = stages
		print("%-6s %6d  stages=%s  gap=%.1f  %s  [%s] %s" % [row.kind, row.frames, stages, row.max_gap,
			row.where, row["class"], row.sample])
	var file := FileAccess.open(_out.path_join("interp-audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"ticks": _ticks, "frames": _frames, "checked": _checked, "rows": rows}, "\t"))
	file.close()
	quit(0)
