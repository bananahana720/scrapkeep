extends SceneTree

# Run with the scratch-home headless runner. FIN_VARIANT may be shell_rivet_calibrated.
# FIN_EXIT=bail cancels a second drive after the actual peak, while still in flight.
const Game := preload("res://src/game.gd")
const Classes := preload("res://src/core/class_def.gd")
const PILOT := "runner_gunner"
const RECIPE := "res://src/presentation/clips/rivet.json"
const NAMES := ["Fin.L", "Fin.R"]
const AXES := {"x": Vector3.RIGHT, "y": Vector3.UP, "z": Vector3.BACK}
const EPSILON_DEG := 0.25
var rules := {}
var bones := {}
var peak := {}
var ended := ""
var failures: Array[String] = []


class EndOfPresentation extends Node:
	signal sampled

	func _process(_delta: float) -> void:
		sampled.emit()


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_drive")


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)


func _snapshot(open: bool) -> Dictionary:
	var sample := {}
	for fin in NAMES:
		if not bones.has(fin) or not rules.has(fin):
			sample[fin] = null
			continue
		var rig: Skeleton3D = bones[fin]
		var index := rig.find_bone(fin)
		var rest := rig.get_bone_rest(index).basis.get_rotation_quaternion()
		var delta := (rest.inverse() * rig.get_bone_pose_rotation(index)).normalized()
		var target := float(rules[fin].deg) if open else 0.0
		var goal := Quaternion(Vector3(AXES[rules[fin].axis]), deg_to_rad(target))
		var error := rad_to_deg(delta.angle_to(goal))
		sample[fin] = {"angle_from_rest_deg": rad_to_deg(delta.angle_to(Quaternion.IDENTITY)),
			"target_deg": target, "axis": rules[fin].axis, "rotation_error_deg": error}
		_check(error <= EPSILON_DEG, "%s misses signed target %s by %.3f degrees" % [fin, target, error])
	return sample


func _drive() -> void:
	var variant := OS.get_environment("FIN_VARIANT")
	var mode := OS.get_environment("FIN_EXIT")
	if mode.is_empty():
		mode = "land"
	_check(variant in ["", "shell_rivet_calibrated"] and mode in ["land", "bail"], "unsupported drive")
	var recipe: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(RECIPE))
	for row in recipe.machinery:
		if row.node in NAMES and row.motion == "turn" and row.start.axis in AXES and float(row.start.deg) != 0:
			rules[row.node] = row.start
	_check(rules.size() == NAMES.size(), "expected two signed targets in Rivet's clip recipe")
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	_check(game.ctx.tuning.sitting_earned(), "expected --profile=sitting-earned at game boot")
	game.ctx.rng.seed = 280928
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.run_seed = 280928
	for tick in 12:
		await physics_frame
	if not variant.is_empty():
		game.ctx.profile.unlock_cosmetic(variant)
		game.ctx.profile.equip(PILOT, "shell", variant)
	game.player.fit_class(Classes.by_id(PILOT))
	var hero = game.presentation.hero_assets
	var frame := EndOfPresentation.new()
	frame.process_priority = hero.process_priority + 1
	root.add_child(frame)
	for tick in 3:
		await process_frame
	var rec: Dictionary = hero.shell_of(game.player)
	_check(rec.get("class", "") == PILOT and rec.get("variant", "") == variant, "expected worn shell")
	for rig: Skeleton3D in rec.core.find_children("*", "Skeleton3D", true, false):
		for fin in NAMES:
			if rig.find_bone(fin) >= 0:
				_check(not bones.has(fin), "duplicate fitted bone " + fin)
				bones[fin] = rig
	for fin in NAMES:
		_check(bones.has(fin), "missing fitted bone " + fin)
	var before := _snapshot(false)
	var ult = game.combat.ultimate
	game.events.ultimate_peak.connect(func(id: String, _at: Vector3):
		peak = {"piece": id, "phase": ult.phase(), "reaction": rec.get("reaction", ""),
			"physics_tick": Engine.get_physics_frames()})
	game.events.ultimate_landed.connect(func(_id: String, _at: Vector3, _hits: int, _damage: float): ended = "land")
	game.events.ultimate_cancelled.connect(func(_id: String, why: String, _refunded: bool): ended = why)
	ult.meter.locked = false
	ult.meter.refund(ult.meter.CAP)
	var origin: Vector3 = game.player.ball_position() + Vector3.UP * 2
	var press_tick := Engine.get_physics_frames()
	var refused: String = ult.press({"origin": origin, "forward": Vector3(1, -0.25, 0).normalized()})
	_check(refused.is_empty(), "Foundry Cutter refused: " + refused)
	for tick in 420:
		await frame.sampled
		if not peak.is_empty() and not peak.has("pose"):
			peak["sample_physics_tick"] = Engine.get_physics_frames()
			peak["pose"] = _snapshot(true)
			if mode == "bail":
				ult.bail()
		if not ended.is_empty():
			break
	_check(peak.get("piece") == "foundry_cutter" and peak.get("phase") == "flight"
		and peak.get("reaction") == "ult_strike", "expected real Foundry Cutter peak and strike")
	_check(ended == mode, "expected " + mode + ", got " + ended)
	for tick in 90:
		await physics_frame
	var after := _snapshot(false)
	print("FIN_RIDE ", JSON.stringify({"pilot": rec.get("class"), "worn_variant": rec.get("variant", ""),
		"table": game.table, "profile": game.ctx.tuning.option("profile"), "look": hero.ball_look(),
		"press_physics_tick": press_tick, "mode": mode, "ended": ended, "targets": rules, "rest": before, "peak": peak, "after": after,
		"tolerance_deg": EPSILON_DEG, "failures": failures}))
	game.free()
	quit(0 if failures.is_empty() else 1)
