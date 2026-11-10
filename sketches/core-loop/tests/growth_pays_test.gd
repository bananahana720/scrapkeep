extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")

# Growth pays on the slice (wave R4, unit GR), on a live game:
# - a chaser's kill drops 12 scrap and a lobber's 16 on the slice and default alpha
#   table, and a build sheet kill_scrap of 2.0 doubles both;
# - taking each activity's gem raises run.mass and run.scrap by exactly 180, once, and still adds
#   the part; a finished activity whose gem is not yet taken adds nothing; a retry restores the
#   activity and it pays again;
# - from mass 0, the three gems alone put the ball in heft class 3 and fire heft_class_changed twice;
# - the run log's stage row carries the ball's mass, heft and class when the Warden was engaged,
#   null before, and a retry's engagement replaces them.
# Every wait is counted in physics frames.

const SEED := 11
const PAY := 180
const PICKUP_SPEED := 14.0
const PICKUP_FRAMES := 40

var _game
var _t := preload("res://tests/support/t.gd").new("growth_pays_test")
var _source := Intent.Scripted.new()
var _class_ups := 0


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot(table: String) -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = table
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.rng.seed = SEED
	_game.player.source = _source
	_class_ups = 0
	_game.events.heft_class_changed.connect(func(_c: int, _h: float): _class_ups += 1)
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	await _frames(2)


func _quiet() -> void:
	for e in _game.get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e):
			e.queue_free()
	_game.build.scrap.clear()


func _ground(at: Vector3, lift := 1.05) -> Vector3:
	return _game.ctx.terrain.drop_point(at.x, at.z, lift)


func _drop_count(kind: String, value: int) -> int:
	_game.build.scrap.clear()
	_game.build._on_enemy_killed(kind, _game.player.ball_position() + Vector3(40.0, 0.0, 0.0), value)
	return _game.build.scrap.count()


func _run() -> void:
	await _boot("slice")
	await _kills("the slice")
	await _activities()
	await _retry()
	await _run_log()
	_game.free()
	await _frames(2)
	await _boot("")
	await _kills("the default table")
	_game.free()
	await _frames(2)
	quit(_t.verdict())


# ---- Kills ----

func _kills(label: String) -> void:
	# 2026-10-04: both posture tables pay the alpha kill_scrap multiplier of 4.0.
	var chaser := 12
	var lobber := 16
	_t.eq("a chaser's kill drops %d on %s" % [chaser, label], _drop_count("chaser", 3), chaser)
	_t.eq("a lobber's kill drops %d on %s" % [lobber, label], _drop_count("lobber", 4), lobber)
	var sheet = _game.build.sheet
	var was: float = sheet.kill_scrap
	sheet.kill_scrap = 2.0
	_t.eq("a sheet kill_scrap of 2.0 doubles the chaser on %s" % label, _drop_count("chaser", 3), chaser * 2)
	_t.eq("and the lobber on %s" % label, _drop_count("lobber", 4), lobber * 2)
	sheet.kill_scrap = was
	_game.build.scrap.clear()


# ---- Activities ----

# Finishes the site at its own ground, then rolls the ball through its gem. Returns the mass,
# scrap, part count and class-up count before the gem, after the finish alone, and after the take.
func _take(id: String) -> Dictionary:
	_quiet()
	# The Warden leaves at the end of this tick. The ball goes into its ring on the next, so the
	# ring never wakes a Warden that is on its way out.
	await physics_frame
	var acts = _game.world.activities
	var s = acts.site(id)
	var at: Vector3 = s.global_position
	var far := _ground(at + Vector3(0.0, 0.0, 60.0))
	_game.player.reset_to(far, Vector3.ZERO)
	_game.player.set_velocity_now(Vector3.ZERO)
	await _frames(2)
	_quiet()
	var run = _game.run
	var before := {"mass": run.mass, "scrap": run.scrap, "parts": run.parts.size(), "ups": _class_ups}
	acts._finish(s, at)
	await _frames(3)
	var finished := {"mass": run.mass, "scrap": run.scrap, "parts": run.parts.size()}
	var own_before: int = run.parts.count(s.pickup_part)
	var start := _ground(at + Vector3(0.0, 0.0, 6.0))
	_game.player.reset_to(start, Vector3(0.0, 0.0, -PICKUP_SPEED))
	_game.player.set_velocity_now(Vector3(0.0, 0.0, -PICKUP_SPEED))
	for i in PICKUP_FRAMES:
		_game.build.scrap.clear()
		await physics_frame
	var after := {"mass": run.mass, "scrap": run.scrap, "parts": run.parts.size(), "ups": _class_ups}
	# 2026-10-04 (EV1): a gem's part may complete an evolution pair, which grants a second part
	# through add_part. So the gem's own part is counted by id, not by the parts list length.
	after["own"] = run.parts.count(s.pickup_part)
	return {"before": before, "finished": finished, "after": after, "had_gem": s.pickup_part != "", "own_before": own_before}


func _activities() -> void:
	_game.run.mass = 0.0
	_game.run.scrap = 0
	_class_ups = 0
	for id in ["ambush_altar", "cracked_cache", "hauler_bounty"]:
		var r: Dictionary = await _take(id)
		var b: Dictionary = r["before"]
		var f: Dictionary = r["finished"]
		var a: Dictionary = r["after"]
		_t.check("%s: finishing alone adds no mass and no scrap" % id, r["had_gem"] and f["mass"] == b["mass"] and f["scrap"] == b["scrap"],
			"mass %s to %s, scrap %s to %s" % [b["mass"], f["mass"], b["scrap"], f["scrap"]])
		_t.eq("%s: the gem raises mass by 180, once" % id, a["mass"] - b["mass"], float(PAY))
		_t.eq("%s: the gem raises scrap by 180, once" % id, a["scrap"] - b["scrap"], PAY)
		_t.eq("%s: the gem still adds its part" % id, a["own"] - r["own_before"], 1)
	_t.eq("three gems from mass 0 reach heft class 3", _game.run.heft_class(), 3)
	_t.eq("and heft_class_changed fired twice", _class_ups, 2)


func _retry() -> void:
	_game.flow.retry_stage()
	await _frames(3)
	var r: Dictionary = await _take("ambush_altar")
	var gained: float = r["after"]["mass"] - r["before"]["mass"]
	_t.eq("after a retry the restored altar pays 180 again", gained, float(PAY))


# ---- The run log ----

func _run_log() -> void:
	_game.flow.retry_stage()
	await _frames(3)
	var row: Dictionary = _game.run_log._stage(_game.run.stage)
	_t.check("before the Warden wakes the engage fields are null", row.get("mass_at_engage", 0) == null and row.get("heft_at_engage", 0) == null
		and row.get("heft_class_at_engage", 0) == null, "row %s" % [[row.get("mass_at_engage", "absent"), row.get("heft_at_engage", "absent"), row.get("heft_class_at_engage", "absent")]])
	_game.run.mass = 300.0
	_game.events.warden_engaged.emit(_game.run.stage)
	row = _game.run_log._stage(_game.run.stage)
	_t.eq("mass at engage", row.get("mass_at_engage"), 300.0)
	_t.near("heft at engage", float(row.get("heft_at_engage", -1.0)), _game.run.heft())
	_t.eq("heft class at engage", row.get("heft_class_at_engage"), _game.run.heft_class())
	_game.run.mass = 600.0
	_game.events.warden_engaged.emit(_game.run.stage)
	row = _game.run_log._stage(_game.run.stage)
	_t.eq("a later engagement replaces the mass", row.get("mass_at_engage"), 600.0)
	_t.eq("and the class", row.get("heft_class_at_engage"), _game.run.heft_class())
