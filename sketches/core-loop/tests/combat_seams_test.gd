extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# The spine's Warden gate, objective line and crush pass-through, run against the real
# combat spawner instead of the spine's test double (spine_warden_gate_test,
# spine_objective_test and spine_crush_test swap one in). Same method as those tests.
# 1. Gate: with force_warden, flow spawns combat's real Warden. A chip below plating
#    publishes strike_deflected on the bus; a real strike to half health shows 0.5 on
#    the beacon the next tick; the killing strike, 60 m outside the ring, opens the gates
#    at once and fires beacon_unsealed once.
#    enemy_killed(warden) arrives while the Warden is still in the tree, already
#    colliding with nothing and reading integrity 0: the kill path, not a free.
# 2. Objective: stage 1 reads its Warden plating (StageDefs) and the real punch_now();
#    stage 2 reads its own.
# 3. Crush: at heft 3 the ball rolls through a real chaser at 20 m/s, keeps 95% of its
#    speed and kills it once; at heft 1 the same approach rams it, knocks it and it lives.

const DT := 1.0 / 90.0
const OUTSIDE := 60.0
# Flat top shelf east of the stampede ring; the wave-3 causeway now crosses x -106..-82 (2026-10-03).
const DRIVE_FROM := Vector2(50.0, -108.0)
const AHEAD := 14.0
const SPEED := 20.0
const HEAVY_MASS := 300
const KEEP := 0.95
const WINDOW := 150

var _game
var _combat
var _source := Intent.Scripted.new()
var _failures := 0
var _phase := "setup"
var _unsealed := 0
var _deflected := 0
var _charges: Array = []
var _runs: Array = []
var _run := {}
var _ticks := 0
var _kills := 0
var _kill_seen := {}
# Our own reference: flow's handler clears flow.warden before this test's handler runs.
var _warden_ref: Node3D


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	match _phase:
		"setup":
			_setup()
			_gate()
			_objective()
			_start_crush()
			_phase = "crush"
		"crush":
			return _step_crush()
	return false


func _setup() -> void:
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = _source
	_game.events.beacon_unsealed.connect(func(_s: int): _unsealed += 1)
	_game.events.enemy_killed.connect(_on_killed)
	_game.events.beacon_charge_changed.connect(func(f: float): _charges.append(f))
	_game.events.strike_deflected.connect(func(_e: Node3D, _k: String, _p: float, _pl: float): _deflected += 1)
	_game.flow.press_start()
	_game.flow.choose_class(1)


# At the moment enemy_killed arrives for the Warden, the node must still exist (the kill
# came through the kill path, not a free), collide with nothing, and read integrity 0.
func _on_killed(kind: String, _at: Vector3, _scrap: int) -> void:
	if kind != "warden" or _kill_seen.size() > 0:
		return
	var warden = _warden_ref
	var valid := is_instance_valid(warden)
	_kill_seen = {
		"valid": valid,
		"layer": warden.collision_layer if valid else -1,
		"integrity": _combat.integrity_of(warden) if valid else -1.0,
	}


func _put_ball(at: Vector3) -> void:
	_game.player.reset_to(at)
	_game.player.body().global_position = at


func _gate() -> void:
	var flow = _game.flow
	var warden: Node3D = flow.warden
	var real: bool = is_instance_valid(warden) and warden.get_script() == load("res://src/combat/warden.gd")
	_report("real_warden", real and flow.sealed and warden.plating == StageDefs.of(1)["warden_plating"] and warden.max_hp == StageDefs.of(1)["warden_hp"],
		"flow spawned combat's own Warden through the spawner: plating %.0f, hp %.0f, sealed %s"
			% [warden.plating if real else -1.0, warden.max_hp if real else -1.0, flow.sealed])
	if not real:
		return
	_warden_ref = warden
	_combat.strike(warden, "runner", 10.0)
	_report("deflect_on_bus", _deflected == 1, "a 10-punch shot on plating %.0f published strike_deflected %d time(s) on the real bus" % [warden.plating, _deflected])
	warden.hp = warden.max_hp
	_combat.strike(warden, "runner", warden.max_hp * 0.5)
	flow.physics_step(DT)
	var half: float = flow.beacon.fraction()
	_report("charge_is_damage", absf(half - 0.5) <= 0.02 and absf(_charges[-1] - 0.5) <= 0.02,
		"a real strike to half health: beacon %.3f on the next tick, published %.3f" % [half, _charges[-1]])
	var mast: Vector3 = flow.beacon.global_position
	var away := mast + Vector3(flow.beacon.radius + OUTSIDE, 0.0, 0.0)
	_put_ball(_game.ctx.terrain.drop_point(away.x, away.z, 1.0))
	_combat.strike(warden, "runner", warden.max_hp)
	var at_once: String = flow.state_name()
	flow.physics_step(DT)
	_report("kill_path", _kill_seen.get("valid", false) and _kill_seen.get("layer", -1) == 0 and _kill_seen.get("integrity", -1.0) == 0.0,
		"enemy_killed(warden) arrived with the Warden still in the tree %s, collision layer %d, integrity %.1f"
			% [_kill_seen.get("valid", false), _kill_seen.get("layer", -1), _kill_seen.get("integrity", -1.0)])
	_report("break_opens_gates", at_once == "gates" and flow.state_name() == "gates" and _unsealed == 1 and _charges[-1] == 1.0 and not flow.sealed,
		"killing strike %.0f m outside the ring: state %s at once, %s a tick later, beacon_unsealed %d time(s)"
			% [OUTSIDE, at_once, flow.state_name(), _unsealed])


func _objective() -> void:
	_game.flow.enter_stage(1, Vector3(0.0, 0.0, 14.0), false)
	var one: String = _game.flow.objective_text()
	var punch := int(_combat.punch_now())
	_report("objective_1", one.contains("plating %d" % int(StageDefs.of(1)["warden_plating"])) and one.contains("Punch %d" % punch) and not one.to_lower().contains("optional"),
		"\"%s\" (real punch_now %d)" % [one, punch])
	_game.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var two: String = _game.flow.objective_text()
	_report("objective_2", two.contains("plating %d" % int(StageDefs.of(2)["warden_plating"])) and not two.to_lower().contains("optional"), "\"%s\"" % two)


func _start_crush() -> void:
	_game.flow.enter_stage(1, Vector3.ZERO, false)
	_game.flow.force_warden = false
	_game.events.enemy_killed.connect(func(kind: String, _a: Vector3, _v: int):
		if kind == "chaser":
			_kills += 1)
	_game.events.enemy_struck.connect(_on_struck)
	_game.run.add_scrap(HEAVY_MASS, Vector3.ZERO)
	_approach("heavy")


func _approach(label: String) -> void:
	_kills = 0
	_ticks = 0
	var at: Vector3 = _game.ctx.terrain.drop_point(DRIVE_FROM.x, DRIVE_FROM.y, 1.0)
	_game.player.reset_to(at, Vector3.RIGHT * SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(Vector3.RIGHT)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	var spot := Vector2(DRIVE_FROM.x + AHEAD, DRIVE_FROM.y)
	var enemy: Node3D = _combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(spot.x, spot.y, 1.6))
	_run = {"label": label, "heft": _game.run.heft(), "enemy": enemy, "enemy_x": spot.x, "hp": enemy.max_hp}


func _on_struck(_enemy: Node3D, kind: String, force: float) -> void:
	if _phase == "crush" and not _run.has("before"):
		_run["before"] = _game.player.planar_velocity().length()
		_run["struck_kind"] = kind
		_run["force"] = force


func _step_crush() -> bool:
	_ticks += 1
	var speed: float = _game.player.planar_velocity().length()
	var ball: Vector3 = _game.player.ball_position()
	if not _run.has("passed") and ball.x >= _run["enemy_x"]:
		_run["passed"] = _ticks
	elif _run.has("passed") and not _run.has("after"):
		_run["after"] = speed
	if _ticks < WINDOW:
		return false
	var enemy = _run["enemy"]
	_run["alive"] = is_instance_valid(enemy) and not enemy.is_dead()
	_run["knocks"] = enemy.knocks if is_instance_valid(enemy) else 0
	_run["kills"] = _kills
	_runs.append(_run)
	if _runs.size() == 1:
		_game.run.lose_scrap(HEAVY_MASS, Vector3.ZERO, "test")
		_approach("light")
		return false
	var heavy: Dictionary = _runs[0]
	var light: Dictionary = _runs[1]
	var before: float = heavy.get("before", -1.0)
	var after: float = heavy.get("after", -1.0)
	_report("crush_keeps_speed", before > 0.0 and after >= before * KEEP and heavy["kills"] == 1 and not heavy["alive"],
		"heft %.1f at %.0f m/s into a %.0f hp chaser: struck (%s) at %.2f m/s, %.2f m/s after passing it (needs >= %.0f%%), %d kill(s)"
			% [heavy["heft"], SPEED, heavy["hp"], heavy.get("struck_kind", "none"), before, after, KEEP * 100.0, heavy["kills"]])
	_report("light_ram_bounces", light["alive"] and light["kills"] == 0 and light["knocks"] >= 1 and light.get("struck_kind", "") == "ram",
		"heft %.1f, same approach: rammed (%s), knocked %d time(s), chaser alive %s, %d kill(s)"
			% [light["heft"], light.get("struck_kind", "none"), light["knocks"], light["alive"], light["kills"]])
	var ok := _failures == 0
	print("combat_seams_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true
