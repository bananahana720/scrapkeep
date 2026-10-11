extends SceneTree

# SQ3 pack stagger window (W13-INTEGRATION-3.md, SQ3): every ordinary pack kind built on
# counter.gd shares one interrupt window, with impact resistance as the per-kind dial.
# For each built Fleet kind on counter.gd, one at a time, in its warning:
# - a real ram knock (combat._hit) is logged with the speed it left on the unit; when it
#   is at or over the unit's interrupt speed the attack breaks and the unit staggers on
#   that tick, for STAGGER_WINDOW, the same frame count on every kind within one tick;
# - a knock under the interrupt speed staggers nothing (the negative control);
# - a kind that cannot be interrupted keeps its attack and never staggers;
# - the ball, rolling free beside it, never loses speed on the tick a target staggers or
#   in the window after (a stall is a one-tick drop over STALL_SHARE).
# The Warden keeps its own posture break (boss_posture.gd STAGGER_SECONDS 4.0).

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Roster := preload("res://src/combat/roster.gd")
const Counter := preload("res://src/combat/counter.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const T := preload("res://tests/support/t.gd")

const TICK := 1.0 / 60.0
const WARN_LIMIT := 360
const STALL_SHARE := 0.05
const BALL_SPEED := 14.0
const OFFSET := Vector3(15.0, 0.0, 0.0)

var _game
var _test := T.new("pack_stagger_test")
var _rows: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _kinds() -> Array:
	var kinds: Array = []
	for id in Roster.ROWS:
		if _game.combat.fleet.makes(String(id)):
			kinds.append(String(id))
	return kinds


func _spawn(kind: String):
	var at: Vector3 = _game.player.ball_position() + OFFSET
	var enemy = _game.combat.spawn_enemy(kind, _game.ctx.terrain.drop_point(at.x, at.z, 1.8))
	return enemy


func _to_warn(enemy) -> bool:
	enemy._rest = 0.0
	for frame in WARN_LIMIT:
		await physics_frame
		if not is_instance_valid(enemy):
			return false
		if enemy.phase == Counter.Phase.WARN and enemy._t >= TICK * 2.0:
			return true
		# Keep the ball where the unit can reach it.
		if frame % 60 == 59:
			_game.player.reset_to(enemy.global_position - OFFSET * 0.6)
	return false


func _ball_speed() -> float:
	var v: Vector3 = _game.player.body().linear_velocity
	return Vector2(v.x, v.z).length()


# One kind: knock it in its warning with a real ram, log the knock and the stagger.
func _probe(kind: String) -> Dictionary:
	var row := {"kind": kind}
	var enemy = _spawn(kind)
	if not (enemy is Counter):
		row["skip"] = "not on counter.gd"
		enemy.free()
		return row
	enemy.hp = 100000.0
	row["interruptible"] = enemy.interruptible
	row["impact_resist"] = float(enemy.impact_resist)
	row["interrupt_speed"] = float(enemy.interrupt_speed())
	if not await _to_warn(enemy):
		row["skip"] = "never warned in %d frames" % WARN_LIMIT
		if is_instance_valid(enemy):
			enemy.free()
		return row
	# The ball rolls free away from the unit; nothing touches it during the window.
	var start: Vector3 = enemy.global_position - OFFSET * 1.2
	_game.player.reset_to(_game.ctx.terrain.drop_point(start.x, start.z, 1.05), Vector3(-BALL_SPEED, 0.0, 0.0))
	await _frames(2)
	var ram: Dictionary = EventKinds.impact("ram")
	var before := _ball_speed()
	_game.combat._hit(enemy, "ram", 1.0, Vector3.RIGHT, float(ram["knock"]), "", "", "ram")
	row["knock"] = float(enemy._knocked_speed())
	await physics_frame
	var after := _ball_speed()
	row["staggered_on_tick"] = enemy.staggered()
	row["phase_after"] = enemy.state_name()
	var worst := after / maxf(before, 0.001)
	var frames := 1 if enemy.staggered() else 0
	var last := after
	for i in int(ceil(Counter.STAGGER_WINDOW / TICK)) + 10:
		await physics_frame
		var now := _ball_speed()
		worst = minf(worst, now / maxf(last, 0.001))
		last = now
		if enemy.staggered():
			frames += 1
		elif frames > 0:
			break
	row["frames"] = frames
	row["ball_worst_tick"] = worst
	row["ball_at_stagger"] = [before, after]
	enemy.free()
	# Negative control: a knock under the interrupt speed staggers nothing.
	if enemy_interruptible(row):
		var low = _spawn(kind)
		low.hp = 100000.0
		if await _to_warn(low):
			var soft: float = float(row["interrupt_speed"]) * 0.5 * float(low.weight)
			_game.combat._hit(low, "ram", 1.0, Vector3.RIGHT, soft, "", "", "ram")
			row["soft_knock"] = float(low._knocked_speed())
			await physics_frame
			row["soft_staggered"] = low.staggered()
			row["soft_phase"] = low.state_name()
		if is_instance_valid(low):
			low.free()
	return row


func enemy_interruptible(row: Dictionary) -> bool:
	return bool(row.get("interruptible", false))


func _run() -> void:
	await _boot()
	_test.check("stagger window constant", Counter.STAGGER_WINDOW > 0.0 and is_finite(Counter.STAGGER_WINDOW),
		"Counter.STAGGER_WINDOW %.3f s (start value, comps/roboquest/enemies-and-telegraphs.md:11)" % Counter.STAGGER_WINDOW)
	_test.check("Warden posture break untouched", BossPosture.STAGGER_SECONDS == 4.0,
		"boss_posture.gd STAGGER_SECONDS %.2f" % BossPosture.STAGGER_SECONDS)
	var kinds := _kinds()
	for kind in kinds:
		_rows.append(await _probe(kind))
		await _frames(3)
	var expected := int(round(Counter.STAGGER_WINDOW / TICK))
	var windows: Array = []
	var probed := 0
	var stalls := 0
	print("kind | interruptible | impact_resist | interrupt m/s | logged knock m/s | staggered on tick | phase | window frames | ball worst tick | soft knock -> staggered")
	for row in _rows:
		if row.has("skip"):
			print("%s | skipped: %s" % [row["kind"], row["skip"]])
			continue
		probed += 1
		print("%s | %s | %.2f | %.2f | %.2f | %s | %s | %d | %.4f | %s" % [row["kind"], row["interruptible"], row["impact_resist"],
			row["interrupt_speed"], row["knock"], row["staggered_on_tick"], row["phase_after"], row["frames"],
			row["ball_worst_tick"], "%.2f -> %s" % [row.get("soft_knock", 0.0), row.get("soft_staggered", "-")]])
		var fields_ok: bool = is_finite(float(row["impact_resist"])) and float(row["impact_resist"]) > 0.0 and is_finite(float(row["knock"]))
		_test.check(row["kind"] + " fields", fields_ok, "impact_resist %.2f, knock %.2f" % [row["impact_resist"], row["knock"]])
		if bool(row["interruptible"]):
			var over: bool = float(row["knock"]) >= float(row["interrupt_speed"])
			if over:
				_test.check(row["kind"] + " interrupts", bool(row["staggered_on_tick"]) and row["phase_after"] == "roam",
					"logged knock %.2f >= %.2f: staggered %s, phase %s on the next tick" % [row["knock"], row["interrupt_speed"], row["staggered_on_tick"], row["phase_after"]])
				windows.append(int(row["frames"]))
				_test.check(row["kind"] + " window", absi(int(row["frames"]) - expected) <= 1,
					"%d frames staggered, want %d within one tick" % [row["frames"], expected])
			else:
				_test.check(row["kind"] + " knock under its resist", not bool(row["staggered_on_tick"]),
					"logged knock %.2f < %.2f: no stagger" % [row["knock"], row["interrupt_speed"]])
			if row.has("soft_knock"):
				_test.check(row["kind"] + " soft knock", not bool(row["soft_staggered"]) and row["soft_phase"] == "warn",
					"knock %.2f under %.2f: staggered %s, phase %s" % [row["soft_knock"], row["interrupt_speed"], row["soft_staggered"], row["soft_phase"]])
		else:
			_test.check(row["kind"] + " immune keeps its attack", not bool(row["staggered_on_tick"]) and row["phase_after"] != "roam" and int(row["frames"]) == 0,
				"not interruptible: staggered %s, phase %s" % [row["staggered_on_tick"], row["phase_after"]])
		var stalled: bool = float(row["ball_worst_tick"]) < 1.0 - STALL_SHARE
		if stalled:
			stalls += 1
		_test.check(row["kind"] + " ball keeps speed", not stalled,
			"worst one-tick ball speed ratio %.4f over the stagger window (ball %.2f -> %.2f m/s on the stagger tick)"
				% [row["ball_worst_tick"], row["ball_at_stagger"][0], row["ball_at_stagger"][1]])
	_test.check("kinds probed", probed >= 10, "%d of %d built Fleet kinds probed in their warning" % [probed, kinds.size()])
	_test.check("windows staggered", windows.size() >= 5, "%d interruptible kinds staggered" % windows.size())
	if not windows.is_empty():
		_test.check("one window for every pack kind", windows.max() - windows.min() <= 1,
			"window frames min %d max %d (want equal within one physics tick)" % [windows.min(), windows.max()])
	_test.check("zero stalls", stalls == 0, "%d stalls in the scripted run" % stalls)
	_game.free()
	quit(_test.verdict())
