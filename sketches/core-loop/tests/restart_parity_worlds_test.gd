extends SceneTree

const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Game := preload("res://src/game.gd")

# Every way back to a stage start leaves no dirty world state behind, on the default table
# with a store. A fingerprint of the stage's world (overlays, breach plates and their ground,
# barges, the harpoon line, the ball's pose) is taken at the stage's first entry. Three dirty
# states, each crossed with three ways back, must bring that fingerprint back:
#   states: a breach plate dropped on world 2's first stage (terrain.overlays leaves
#           start_overlays), a barge moving on world 3's first stage, and a harpoon line
#           mid-tow (a committed haul on a body) on world 2's second stage;
#   paths:  flow.retry_stage(); the title then Continue (resume_run); the title then a new run
#           and a fresh entry of the stage.

const DIR := "user://restart_parity_worlds_test/"
const PATH := DIR + "run.json"
const ENTRY_V := Vector3(0.0, 0.0, 14.0)
const STATES := ["breach plate", "moving barge", "harpoon mid-tow"]
const PATHS := ["retry", "continue", "title"]

var _game
var _failures := 0
var _checks := 0
var _start := {}
var _target: Node3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	_clean()
	_run.call_deferred()


func _clean() -> void:
	for name in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + name)


func _report(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _boot():
	var game := Game.new()
	game.test_mode = true
	game.run_store_path = PATH
	root.add_child(game)
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	return game


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


func _new_run() -> void:
	_game.flow.show_title()
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(2)


func _stage_of(state: String) -> int:
	var stages = _game.ctx.stages
	match state:
		"breach plate":
			return stages.first_of(2)
		"moving barge":
			return stages.first_of(3)
	return stages.first_of(2) + 1


func _fingerprint() -> Dictionary:
	var t = _game.ctx.terrain
	var w = _game.world
	var m = t.map()
	var overlays := Array(t.overlays.duplicate())
	overlays.sort()
	var plates := {}
	if "breach_plates" in m:
		for plate in m.breach_plates:
			var id: String = plate["id"]
			var c: Vector2 = (plate["rect"] as Rect2).get_center()
			var shown := []
			if "swaps" in m and m.swaps.has(id):
				for side in ["before", "after"]:
					for node in m.swaps[id][side]:
						shown.append(node.visible)
			plates[id] = [w.breach.breached(id) if w.breach != null else null, snappedf(t.height(c.x, c.y), 0.01), shown]
	var barges := []
	if w.contraptions.has(t.stage):
		for b in w.contraptions[t.stage].barges:
			# Where the lane puts the barge at its time: a sync_to_physics body shows a move only
			# after the next physics step, so its node transform lags the placement.
			barges.append([snappedf(b["time"], 0.001), _lane(b).snapped(Vector3.ONE * 0.01), b["velocity"]])
	var kit = _game.player.kit
	return {
		"stage": _game.run.stage, "terrain_stage": t.stage, "flow": _game.flow.state_name(),
		"overlays": overlays, "plates": plates, "barges": barges,
		"line": [kit.hooked, kit.on_body, kit.anchor_body != null, kit.line_state, kit.winching, kit.smash_left, _game.player.get("_line_state")],
		"ball": _game.player.body().global_position.snapped(Vector3.ONE * 0.01),
	}


func _lane(b: Dictionary) -> Vector3:
	var spec: Dictionary = b["spec"]
	return (spec["a"] as Vector3).lerp(spec["b"], _game.world.contraptions[_game.ctx.terrain.stage].barge_offset(spec, b["time"]))


# After a physics step every barge body stands where its lane says.
func _barges_settled() -> String:
	await _physics(2)
	var w = _game.world
	var stage: int = _game.ctx.terrain.stage
	if not w.contraptions.has(stage):
		return ""
	for b in w.contraptions[stage].barges:
		var at: Vector3 = b["body"].transform.origin
		if at.distance_to(_lane(b)) > 0.05:
			return "%s body at %s, lane %s" % [b["spec"]["id"], at, _lane(b)]
	return ""


# Makes the state dirty on the live stage; returns a line saying what changed.
func _dirty(state: String) -> String:
	var t = _game.ctx.terrain
	var w = _game.world
	match state:
		"breach plate":
			var plate: Dictionary = t.map().breach_plates[0]
			var c: Vector2 = (plate["rect"] as Rect2).get_center()
			w._on_slammed(Vector3(c.x, t.height(c.x, c.y), c.y), 1.0, 1.0)
			return "overlays %s, start %s" % [t.overlays, t.map().start_overlays]
		"moving barge":
			var c = w.contraptions[t.stage]
			var far := Vector3(0.0, -500.0, 0.0)
			# Mid-lane: off both docks, between the dwells.
			for i in 400:
				c.step(0.1, far, Vector3.ZERO, _game.player.kit, false)
				var along: float = c.barge_offset(c.barges[0]["spec"], c.barges[0]["time"])
				if along > 0.1 and along < 0.9:
					break
			return "barge time %.1f at %s" % [c.barges[0]["time"], _lane(c.barges[0])]
	var kit = _game.player.kit
	var ball: Vector3 = _game.player.body().global_position
	_target = Node3D.new()
	_game.add_child(_target)
	_target.global_position = ball + Vector3(0.0, 0.0, 12.0)
	kit.hooked = true
	kit.on_body = true
	kit.anchor_body = _target
	kit.anchor_offset = Vector3.ZERO
	kit.anchor = _target.global_position
	kit.rope = 12.0
	kit.line_state = Augments.LINE_SMASH
	kit.smash_left = 1.0
	kit.smash_floor = 20.0
	await _physics(3)
	return "hooked %s on body %s line_state %d smash_left %.2f" % [kit.hooked, kit.on_body, kit.line_state, kit.smash_left]


func _go_back(path: String) -> bool:
	match path:
		"retry":
			_game.flow.retry_stage()
			return true
		"continue":
			_game.flow.show_title()
			return _game.flow.resume_run()
	var stage: int = _game.run.stage
	await _new_run()
	var fresh: bool = _game.run.stage == _game.ctx.stages.first_of(1) and _game.flow.state_name() == "stage"
	_game.flow.enter_stage(stage, ENTRY_V, false)
	return fresh


func _run() -> void:
	_game = _boot()
	await _frames(2)
	for state in STATES:
		for path in PATHS:
			await _new_run()
			var stage := _stage_of(state)
			_game.flow.enter_stage(stage, ENTRY_V, false)
			if not _start.has(stage):
				_start[stage] = _fingerprint()
			var start: Dictionary = _start[stage]
			var what: String = await _dirty(state)
			var dirty := _fingerprint()
			var went: bool = await _go_back(path)
			var back := _fingerprint()
			var unsettled: String = await _barges_settled() if state == "moving barge" else ""
			_report("%s / %s" % [state, path], dirty != start and went and back == start and unsettled == "",
				"stage %d: dirtied (%s) differs %s; back via %s %s; fingerprint %s%s" \
					% [stage, what, dirty != start, path, went, "returned" if back == start else "differs: %s against start %s" % [back, start],
						"" if state != "moving barge" else "; barge bodies on their lanes" if unsettled == "" else "; " + unsettled])
			if is_instance_valid(_target):
				_target.free()

	_game.free()
	_clean()
	DirAccess.remove_absolute(DIR)
	print("restart_parity_worlds_test: %s" % ("PASS (%d checks)" % _checks if _failures == 0 else "FAIL (%d of %d)" % [_failures, _checks]))
	quit(0 if _failures == 0 else 1)
