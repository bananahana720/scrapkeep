# smoke: solo timeout=180s
extends SceneTree

const Game = preload("res://src/game.gd")
const BotDriver = preload("res://tools/bot_driver.gd")
const Run = preload("res://src/core/run_state.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Arena = preload("res://tests/posture_bands_reactor_test.gd")
const SimClock = preload("res://src/core/sim_clock.gd")
const Posture = preload("res://src/core/boss_posture.gd")
const Combat = preload("res://src/combat/combat.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_boundary_test")

class Hands extends BotDriver:
	func _specials(_fight, _evading: bool) -> void: pass
	func _act(steer: Vector3, aim, delta: float, fight: Node3D = null, evade := true) -> void:
		super._act(steer, aim, delta, fight, evade)
		source.hold.erase("fire_held")

func _initialize() -> void:
	SimClock.ticks = true
	_run.call_deferred()

func _run() -> void:
	await _fight(Run.HEFT_CLASS_AT[2], "grown")
	await _fight(Run.HEFT_CLASS_AT[0], "small")
	quit(t.verdict())

func _fight(heft: float, label: String) -> Dictionary:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	# The checks are the sheet's solver publication and its class-scaled gain at a boundary contact. Wall grip's
	# downforce (#61, on by default) presses the bot's first stomp 6 cm in, inside family-point reach (2.27 m against
	# 2.30 m), so no boundary contact comes before the stagger; without it the stomp lands at 2.33 m.
	game.player.tuning.set_option("grip", "off")
	game.flow.force_warden = true
	var bot = Hands.new(game, "skipper", 1)
	bot.start()
	game.run.grant_start_mass((heft - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var dir: Vector3 = sheet._face_heading(w)
	var foot: Vector3 = w.home + dir * minf(BotDriver.RUNUP, Reactor.SHEET_RUN - BotDriver.RUNUP_EDGE)
	game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, game.player.tuning.RADIUS), Vector3.ZERO)
	var boundary: Array = []
	game.events.enemy_struck.connect(func(enemy, kind, force):
		if enemy != w or kind not in ["ram", "stomp", "slam"]: return
		var distance: float = game.player.ball_position().distance_to(w.family_point_at())
		if distance <= w.FAMILY_POINT_RADIUS + game.player.tuning.RADIUS or not sheet.sheet_live() or sheet.entered_sheet_cycle != sheet.gates_opened: return
		boundary.append({"kind": kind, "force": force, "before": w.posture(), "heft": game.run.heft(), "colliding": game.player.body().get_colliding_bodies().has(w), "distance": distance, "entry": sheet.entered_sheet_cycle, "cycle": sheet.gates_opened, "live": sheet.sheet_live()}))
	for i in ceili(1.5 * Arena.EXPECT_GROWN_S * Engine.physics_ticks_per_second):
		bot.tick(1.0 / Engine.physics_ticks_per_second)
		await physics_frame
		if not boundary.is_empty(): break
	t.check(label + " observes a real solver boundary contact", not boundary.is_empty(), str(boundary))
	if not boundary.is_empty():
		var hit: Dictionary = boundary[0]
		t.check(label + " solver publication is live with current-cycle entry", hit.colliding and hit.live and hit.entry == hit.cycle and hit.distance > w.FAMILY_POINT_RADIUS + game.player.tuning.RADIUS, str(hit))
		var stage: Dictionary = game.ctx.stages.DEFS[game.run.stage - 1]
		var numbers: Dictionary = stage.get("posture", {})
		var strike: Array = Combat.STRIKE_DAMAGE[hit.kind]
		var punch: float = (float(strike[0]) + float(hit.force) * float(strike[1])) * float(hit.heft)
		var grown_punch: float = (float(strike[0]) + float(hit.force) * float(strike[1])) * Run.HEFT_CLASS_AT[2]
		var low: float = numbers.get("mult_min", Posture.MULT_MIN)
		var high: float = numbers.get("mult_max", Posture.MULT_MAX)
		# 2026-10-15 WT-PARK-BOT merge: the sheet ram uses the mount's own heft curve, not the stage's.
		var curve: float = Reactor.MOUNTED_POSTURE.heft_curve
		var plating: float = stage.warden_plating
		var expected: float = Posture.FULL / float(Reactor.MOUNTED_POSTURE.sheet_ram_breaks) * pow(clampf(punch / plating, low, high), curve) / pow(clampf(grown_punch / plating, low, high), curve)
		t.near(label + " boundary solver contact receives class-scaled sheet gain", w.posture() - float(hit.before), expected)
	game.free()
	await physics_frame
	return {}
