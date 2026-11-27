# smoke: solo timeout=180s
extends SceneTree
const Game = preload("res://src/game.gd")
const Intent = preload("res://src/movement/intent.gd")
const Reactor = preload("res://src/combat/warden_reactor.gd")
const Warden = preload("res://src/combat/warden.gd")
const Run = preload("res://src/core/run_state.gd")
const Tuning = preload("res://src/movement/tuning.gd")
const StageLocks = preload("res://src/world/stage_locks.gd")
const T = preload("res://tests/support/t.gd")
var t = T.new("park_reactor_sheet_heft_test")
var game

# How many landed sheet rams break the dam Warden at a given heft (unit WT-PARK-BOT). The pilot
# is put on the sheet's foot rolling at cruise toward the relic at every pulse, as
# park_reactor_rhythm_test.gd does, so every cycle lands one ram and the count is the rule's.
# A heft-1.0 ball needs ceil(3 x 2.2) = 7, the posture bands' "at least twice grown" and no
# more; a grown ball that wore one unit of mass but still holds the grown class needs 3.

class Body extends RefCounted:
	var touching: Array = []
	func get_colliding_bodies() -> Array: return touching
class Ball extends RefCounted:
	var rigid := Body.new()
	var heft_of: Callable
	func _init() -> void: heft_of = Callable(self, "heft")
	func heft() -> float: return Run.HEFT_CLASS_AT[0]
	func body(): return rigid
class Mount extends RefCounted:
	var mount_driver = Reactor.new()
	var target := Ball.new()
	func family_point() -> String: return "core"

func _initialize() -> void: _run.call_deferred()

# One sheet pays one ram: the ball's contacts on successive frames of one live sheet (the double
# count seen in the fight test's traces) add no second ram's gain; the next cycle's sheet pays again.
func _one_sheet_one_ram() -> void:
	var mount := Mount.new()
	var driver = mount.mount_driver
	driver.gates_opened = 2
	driver.sheet_left = Reactor.SHEET_SECONDS
	driver.entered_sheet_cycle = 2
	mount.target.rigid.touching = [mount]
	var posture = Reactor.DamPosture.new({})
	posture.mounted_warden = weakref(mount)
	var hit := {"kind": "stomp", "punch": 40.0, "plating": 90.0, "smash": false, "tier": 1, "charging": false,
		"frame": 10, "hp": 650.0, "max_hp": 650.0, "point": "core"}
	var gains := []
	for frame in [10, 11]:
		hit["frame"] = frame
		var result: Dictionary = posture.judge(hit)
		posture.apply(result, frame)
		gains.append(snappedf(float(result.get("gain", -1.0)), 0.0001))
	driver.gates_opened = 3
	driver.entered_sheet_cycle = 3
	hit["frame"] = 400
	var next: Dictionary = posture.judge(hit)
	gains.append(snappedf(float(next.get("gain", -1.0)), 0.0001))
	t.check("a second contact in the same sheet adds no second ram; the next sheet pays again",
		gains[0] > 0.0 and gains[1] == 0.0 and gains[2] == gains[0], str(gains))
	mount.target.rigid.touching.clear()

func _run() -> void:
	StageLocks.active = false
	_one_sheet_one_ram()
	var small: Dictionary = await _rams(Run.HEFT_CLASS_AT[0], 0)
	t.check("a heft-1.0 ball breaks the dam on its seventh sheet ram", small.broken and small.rams == 7, str(small))
	var worn: Dictionary = await _rams(Run.HEFT_CLASS_AT[2], 1)
	t.check("the worn ball sits under the grown mark and still holds the grown class", worn.heft < Run.HEFT_CLASS_AT[2] and worn.held == 3, str(worn))
	t.check("a grown-class ball one wear unit under the mark breaks on its third sheet ram", worn.broken and worn.rams == 3, str(worn))
	StageLocks.active = true
	quit(t.verdict())

func _rams(heft: float, worn_units: int) -> Dictionary:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = true
	game.flow.press_start()
	game.flow.choose_class(1)
	game.run.set_max_hp(99999.0)
	game.run.defend_hook = func(_amount: float, _hp: float) -> float: return 0.0
	game.player.source = Intent.Scripted.new()
	game.run.grant_start_mass((heft - Run.HEFT_CLASS_AT[0]) / Run.HEFT_PER_MASS)
	for i in 40: await physics_frame
	for i in worn_units:
		game.run.wear_step(60.0 / Run.WEAR_PER_MINUTE, 1.0, 1.0, true)
	var ring: Vector3 = game.ctx.terrain.beacon_point(game.run.stage)
	game.player.reset_to(game.ctx.terrain.drop_point(ring.x, ring.z, Tuning.RADIUS), Vector3.ZERO)
	for i in 2: await physics_frame
	var w = game.flow.warden
	var sheet = w.mount_driver
	var result = {"broken": false, "rams": 0, "heft": game.run.heft(), "held": game.run.heft_class(), "engaged": game.flow.engaged()}
	game.events.enemy_struck.connect(func(enemy, kind, _force):
		if enemy == w and kind in ["ram", "stomp", "slam"] and sheet.sheet_live(): result.rams += 1)
	game.events.beacon_unsealed.connect(func(_stage): result.broken = true)
	var last_cycle := -1
	for tick in roundi(Warden.PULSE_CYCLE * 20 * Engine.physics_ticks_per_second):
		if result.broken: break
		if sheet.sheet_live() and sheet.gates_opened != last_cycle:
			last_cycle = sheet.gates_opened
			var foot: Vector3 = w.home + sheet.sheet_dir * (Reactor.SHEET_RUN - Tuning.RADIUS)
			var start_at: Vector3 = game.ctx.terrain.drop_point(foot.x, foot.z, Tuning.RADIUS)
			game.player.reset_to(start_at, -sheet.sheet_dir * game.player.tuning.f("cruise"))
		elif not sheet.sheet_live():
			var wait: Vector3 = w.home + Vector3.FORWARD * (Reactor.SHEET_RUN - Tuning.RADIUS)
			game.player.reset_to(game.ctx.terrain.drop_point(wait.x, wait.z, Tuning.RADIUS), Vector3.ZERO)
		await physics_frame
	game.free()
	await physics_frame
	return result
