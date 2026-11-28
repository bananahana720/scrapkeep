# smoke: solo timeout=90s
extends SceneTree

const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Posture = preload("res://src/core/boss_posture.gd")
const Run = preload("res://src/core/run_state.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const Combat = preload("res://src/combat/combat.gd")
const Warden = preload("res://src/combat/warden.gd")
const T = preload("res://tests/support/t.gd")

var t = T.new("park_reactor_entry_test")
var game

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	await _outside_contact(false)
	await _outside_contact(true)
	quit(t.verdict())

func _outside_contact(previous_entry: bool) -> void:
	var label := "previous-cycle entry" if previous_entry else "no entry"
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.player.source = Intent.Scripted.new()
	game.run.grant_start_mass((Run.HEFT_CLASS_AT[2] - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	for i in 40: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var core: Vector3 = w.family_point_at()
	var ring: Vector3 = game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x, ring.z, Tuning.RADIUS), Vector3.ZERO)
	for i in roundi(Warden.PULSE_CYCLE * 2.0 * Engine.physics_ticks_per_second):
		if sheet.sheet_live(): break
		await physics_frame
	t.check(label + " uses a normal charge and live sheet", sheet.sheet_live() and w.pulses > 0)
	var entry_cycle: int = sheet.entered_sheet_cycle
	if previous_entry:
		var foot: Vector3 = w.home + sheet.sheet_dir * (Reactor.SHEET_RUN - Tuning.RADIUS)
		game.player.reset_to(game.ctx.terrain.drop_point(foot.x, foot.z, Tuning.RADIUS), -sheet.sheet_dir * game.player.tuning.f("cruise"))
		for i in 10:
			await physics_frame
			if sheet.entered_sheet_cycle == sheet.gates_opened: break
		entry_cycle = sheet.gates_opened
		t.eq("the prior cycle has a real sheet entry", sheet.entered_sheet_cycle, entry_cycle)
		for i in roundi(Warden.PULSE_CYCLE * 2.0 * Engine.physics_ticks_per_second):
			if sheet.sheet_live() and sheet.gates_opened > entry_cycle: break
			game.player.reset_to(core - sheet.sheet_dir * (w.FAMILY_POINT_RADIUS + Tuning.RADIUS + Tuning.RADIUS), Vector3.ZERO)
			await physics_frame
		t.check("the contact cycle follows the entered cycle", sheet.sheet_live() and sheet.gates_opened > entry_cycle)
	else:
		t.eq("no cycle has an entry", entry_cycle, -1)
	var at: Vector3 = core - sheet.sheet_dir * (w.FAMILY_POINT_RADIUS + Tuning.RADIUS + Tuning.RADIUS)
	t.check(label + " starts behind the sheet footprint", (at - w.home).dot(sheet.sheet_dir) < 0.0)
	var contacts: Array = []
	var solved: Array = []
	game.player.body().enemy_touched.connect(func(enemy, _normal):
		if enemy == w: solved.append(game.player.ball_position()))
	game.events.enemy_struck.connect(func(enemy, kind, force):
		if enemy == w and kind in Posture.BASE:
			contacts.append({"kind": kind, "force": force, "before": w.posture(), "live": sheet.sheet_live(), "entry": sheet.entered_sheet_cycle, "cycle": sheet.gates_opened, "at": game.player.ball_position()}))
	game.player.reset_to(at, sheet.sheet_dir * game.player.tuning.f("cruise"))
	for i in 60:
		await physics_frame
		if not contacts.is_empty(): break
	t.check(label + " reaches the aligned core through solver contact", not solved.is_empty() and not contacts.is_empty(), str(contacts))
	if not contacts.is_empty():
		var hit: Dictionary = contacts[0]
		t.check(label + " contact is live with no current entry", hit.live and hit.entry == entry_cycle and hit.entry != hit.cycle, str(hit))
		t.check(label + " contact stays outside the footprint", (hit.at - w.home).dot(sheet.sheet_dir) < 0.0, str(hit.at))
		var stage: Dictionary = game.ctx.stages.DEFS[game.run.stage - 1]
		var numbers: Dictionary = stage.get("posture", {})
		var strike: Array = Combat.STRIKE_DAMAGE[hit.kind]
		var punch: float = (float(strike[0]) + float(hit.force) * float(strike[1])) * game.run.heft()
		var base: float = numbers.get("base", {}).get(hit.kind, Posture.BASE[hit.kind])
		var ratio: float = punch / float(stage.warden_plating)
		var expected := base * pow(clampf(ratio, numbers.get("mult_min", Posture.MULT_MIN), numbers.get("mult_max", Posture.MULT_MAX)), numbers.get("curve", 1.0))
		t.near(label + " receives ordinary stage-owned gain", w.posture() - float(hit.before), expected)
	game.free()
	await physics_frame
