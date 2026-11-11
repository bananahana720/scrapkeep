extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CalledShot := preload("res://src/build/called_shot.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# Called Shot (src/build/called_shot.gd, docs/design/loops.md Spec 3) at the real park_dam Warden:
# the hold turns DUNK, CHAIN, BOWL every half second and a tap calls nothing; the flag is off by
# default and a woken Warden then opens no window; with --called-shot=on a held haul aimed at the
# Warden calls what shows on release; a call met by its cause lifts the gate pair off the common
# rung; a missed call burns a core and leaves the pair where the cores put it; no call changes
# nothing. Evidence limit: the rule and its wiring, not a played break; whether players vary their
# call is the sitting's question.

var _t := T.new("called_shot_test")
var _facts: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_rules()
	await _off()
	await _on()
	quit(_t.verdict())


func _rules() -> void:
	_t.eq("a hold shows the verbs in turn", [CalledShot.showing(0.3), CalledShot.showing(0.5), CalledShot.showing(1.0),
		CalledShot.showing(1.6), CalledShot.showing(2.0)], ["", "DUNK", "CHAIN", "BOWL", "DUNK"])
	for kind in ["call_window", "shot_called", "call_met", "call_missed"]:
		_t.check("%s has a WORLD_ROWS row" % kind, not EventKinds.world_row(kind).is_empty())


func _game(flags: PackedStringArray):
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	game.player.source = Intent.Scripted.new()
	game.player.tuning.apply_args(flags)
	_facts = []
	game.events.world_fact.connect(func(kind: String, _at: Vector3): _facts.append(kind))
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 8:
		await physics_frame
	game.ctx.calm = true
	return game


# Sets the ball rolling at the Warden from behind, so the chase lens looks at it (the window reads
# the aim from the lens, ctx.aim_forward).
func _face_warden(game) -> void:
	var w: Vector3 = game.flow.warden.global_position
	var ball: Vector3 = game.player.ball_position()
	var dir := Vector3(w.x - ball.x, 0.0, w.z - ball.z).normalized()
	var spot := w - dir * 40.0
	game.player.reset_to(game.ctx.terrain.drop_point(spot.x, spot.z, 1.0), dir * 6.0)
	await _sim(1.0)


func _sim(seconds: float) -> void:
	for i in roundi(seconds * Engine.physics_ticks_per_second):
		await physics_frame


# Holds haul for `seconds`, then lets go and gives the release a tick.
func _hold(game, seconds: float) -> void:
	game.player.source.hold = {"brake_held": true}
	await _sim(seconds)
	game.player.source.hold = {}
	await _sim(0.05)


func _off() -> void:
	var game = await _game(PackedStringArray())
	var shot = game.build.called_shot
	_t.eq("flag off by default", game.player.tuning.option("called_shot"), "off")
	game.events.warden_engaged.emit(game.ctx.run.stage)
	_t.eq("a woken Warden opens no window", shot.state, "")
	var before: Array = shot.gate_rarities()
	_t.eq("and the gate reads the cores as before", before, ["common"])
	game.queue_free()
	await process_frame


func _on() -> void:
	var game = await _game(PackedStringArray(["--called-shot=on"]))
	var shot = game.build.called_shot
	var warden: Node3D = game.flow.warden
	_t.check("the park has its Warden", is_instance_valid(warden))
	game.events.warden_engaged.emit(game.ctx.run.stage)
	_t.eq("the Warden's wake opens the window", shot.state, "window")
	_t.eq("on its drum", _facts.count("call_window"), 1)

	await _face_warden(game)
	await _hold(game, 0.3)
	_t.eq("a tap calls nothing", [shot.state, shot.called], ["window", ""])
	await _hold(game, 1.2)
	_t.eq("letting go calls what shows", [shot.state, shot.called], ["called", "CHAIN"])
	_t.eq("the call inks", _facts.count("shot_called"), 1)
	_t.eq("the stamp stands over the Warden", shot.stamp_text(), "CHAIN")
	await _hold(game, 0.7)
	_t.eq("one call a Warden", shot.called, "CHAIN")

	# Met: a hit while the chain stands at its threshold, then the gate.
	game.player.chain.combo = CalledShot.CHAIN_COMBO
	game.ctx.spawner.strike(warden, "ram", 10.0)
	game.player.chain.combo = 0
	var met: Array = shot.gate_rarities()
	_t.eq("the call is met", shot.verdict, "met")
	_t.check("a met call lifts the pair off the common rung", not met.is_empty() and not "common" in met, str(met))
	_t.eq("CALLED is heard", _facts.count("call_met"), 1)

	# Missed: a DUNK call that breaks some other way burns a core.
	shot.clear()
	game.events.warden_engaged.emit(game.ctx.run.stage)
	await _face_warden(game)
	await _hold(game, 0.6)
	_t.eq("a short hold calls DUNK", shot.called, "DUNK")
	game.ctx.run.add_core("test", Vector3.ZERO)
	game.ctx.spawner.strike(warden, "ram", 10.0)
	var missed: Array = shot.gate_rarities()
	_t.eq("the call is missed", shot.verdict, "missed")
	_t.eq("a missed call burns the core", game.ctx.run.bonus_cores, 0)
	_t.eq("so the pair sits on the common rung", missed, ["common"])
	_t.eq("the miss drops dry", _facts.count("call_missed"), 1)

	# No call: the window closes and the gate reads the cores as before.
	shot.clear()
	game.ctx.run.add_core("test", Vector3.ZERO)
	game.events.warden_engaged.emit(game.ctx.run.stage)
	await _sim(CalledShot.CALL_WINDOW_S + 0.2)
	_t.eq("an unused window closes", shot.state, "closed")
	_t.eq("no call leaves the gate as it was", shot.gate_rarities(), ["common", "rare"])
	_t.eq("and the core stays", game.ctx.run.bonus_cores, 1)

	# BOWL met by a flung body: a Warden takes it on its posture path, which strikes nothing.
	shot.clear()
	game.events.warden_engaged.emit(game.ctx.run.stage)
	await _face_warden(game)
	await _hold(game, 1.6)
	_t.eq("a long hold calls BOWL", shot.called, "BOWL")
	game.ctx.spawner.flail_hit(warden, 10.0, warden.global_position + Vector3(4.0, 0.0, 0.0), 1.0)
	shot.gate_rarities()
	_t.eq("a flung body meets BOWL", shot.verdict, "met")

	# DUNK met through a real break: a dunk spent on the Warden, then the Warden broken, and the
	# stage's own gate roll settles the call.
	shot.clear()
	var offered := []
	game.events.reward_offered.connect(func(offers: Array): offered.append(offers.size()))
	game.events.warden_engaged.emit(game.ctx.run.stage)
	await _face_warden(game)
	await _hold(game, 0.6)
	_t.eq("a short hold calls DUNK again", shot.called, "DUNK")
	game.player.dunk.store(5.0, "test", "test", Color.WHITE)
	game.player.dunk.spend(warden)
	# A posture Warden loses health only to what a shatter armed (int_arena_standdown_test's break).
	warden._armed = warden.max_hp
	game.ctx.spawner.strike(warden, "arc", 1000000.0)
	var ticks := 0
	while offered.is_empty() and ticks < 120:
		await physics_frame
		ticks += 1
	_t.check("the break opens the gates", not offered.is_empty(), "%d ticks" % ticks)
	_t.eq("the gate roll settles the call as met", shot.verdict, "met")
	game.queue_free()
	await process_frame
