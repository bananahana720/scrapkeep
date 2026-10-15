extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")


# A spawner with no integrity_of(), so flow has to tell this stage's Warden by where
# the kill happened (within 6 m of where it stood).
class BareSpawner:
	extends Node

	var ctx

	func spawn_enemy(kind: String, at: Vector3, _affix_id := "") -> Node3D:
		var enemy := Node3D.new()
		enemy.set_meta("kind", kind)
		ctx.root.add_child(enemy)
		enemy.global_position = at
		return enemy

	func kill(enemy: Node3D, at: Vector3) -> void:
		ctx.run.record_kill(enemy.get_meta("kind"), at, 0)

# The Warden is the stage's one MUST. Circling the ring charges nothing while it
# stands; its damage is the charge the beacon shows; its death opens the gates
# wherever the ball is. Uses a spawner double, so it tests the spine's side only.

const DT := 1.0 / 90.0
const CIRCLE_SECONDS := 120.0
const CIRCLE_RADIUS := 10.0
const OUTSIDE := 60.0

var _game
var _double
var _started := false
var _failures := 0
var _unsealed := 0
var _engaged := 0
var _charges: Array[float] = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _put_ball(at: Vector3) -> void:
	_game.player.body().global_position = at
	_game.player.reset_to(at)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if _started:
		return false
	_started = true
	_double = SpawnerDouble.new()
	_game.add_child(_double)
	_double.setup(_game.ctx)
	_game.ctx.spawner = _double
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.player.source = Intent.Scripted.new()
	_game.events.beacon_unsealed.connect(func(_s: int): _unsealed += 1)
	_game.events.warden_engaged.connect(func(_s: int): _engaged += 1)
	_game.events.beacon_charge_changed.connect(func(f: float): _charges.append(f))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_run_checks()
	print("spine_warden_gate_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return false


func _run_checks() -> void:
	var flow = _game.flow
	var warden: Node3D = flow.warden
	_report("sealed", flow.sealed and is_instance_valid(warden) and warden.kind == "warden" and warden.plating == StageDefs.of(1)["warden_plating"],
		"stage 1 is sealed by a warden with plating %.0f and hp %.0f" % [warden.plating if warden else -1.0, warden.max_hp if warden else -1.0])

	var mast: Vector3 = flow.beacon.global_position
	var worst := 0.0
	var left_beacon := false
	var steps := int(CIRCLE_SECONDS / DT)
	for i in steps:
		var angle := TAU * float(i) / 540.0
		var spot := mast + Vector3(cos(angle), 0.0, sin(angle)) * CIRCLE_RADIUS
		_put_ball(_game.ctx.terrain.drop_point(spot.x, spot.z, 1.0))
		flow.physics_step(DT)
		worst = maxf(worst, flow.beacon.fraction())
		if i > 0 and flow.state_name() != "beacon":
			left_beacon = true
	_report("no presence charge", not left_beacon and worst == 0.0 and flow.state_name() == "beacon",
		"circling inside the ring for %.0f s: state %s throughout %s, charge never above %.3f"
			% [CIRCLE_SECONDS, flow.state_name(), not left_beacon, worst])

	var engaged_by_ring := _engaged
	_double.strike(warden, "arc", warden.max_hp * 0.5)
	flow.physics_step(DT)
	var half: float = flow.beacon.fraction()
	_report("charge is damage", absf(half - 0.5) <= 0.02 and absf(_charges[-1] - 0.5) <= 0.02,
		"warden struck to half hp: beacon %.3f on the next tick, published %.3f" % [half, _charges[-1]])

	var away := mast + Vector3(flow.beacon.radius + OUTSIDE, 0.0, 0.0)
	_put_ball(_game.ctx.terrain.drop_point(away.x, away.z, 1.0))
	var gap: float = Vector2(away.x - mast.x, away.z - mast.z).length() - flow.beacon.radius
	_double.strike(warden, "arc", warden.max_hp)
	var at_once: String = flow.state_name()
	flow.physics_step(DT)
	_report("break opens gates", at_once == "gates" and flow.state_name() == "gates" and _unsealed == 1 and _charges[-1] == 1.0 and not flow.sealed,
		"killing strike %.0f m outside the ring: state %s at once, %s a tick later, beacon_unsealed fired %d time(s), last charge %.2f"
			% [gap, at_once, flow.state_name(), _unsealed, _charges[-1]])
	_report("warden engaged once", engaged_by_ring == 1 and _engaged == 1,
		"warden_engaged fired %d time(s) on ring entry and %d in total after two strikes" % [engaged_by_ring, _engaged])
	_late_kill_checks(mast)
	_foreign_kill_checks(mast)
	_vanish_checks()
	_bare_spawner_checks()


# B1: a spawner that records the kill late must not see a charge of 1.0 before it does.
func _late_kill_checks(mast: Vector3) -> void:
	var flow = _game.flow
	flow.retry_stage()
	_put_ball(_game.ctx.terrain.drop_point(mast.x + 5.0, mast.z, 1.0))
	flow.physics_step(DT)
	_charges.clear()
	var unsealed_before := _unsealed
	_double.delay_deaths = true
	_double.strike(flow.warden, "arc", 99999.0)
	var worst := 0.0
	for i in 5:
		flow.physics_step(DT)
		worst = maxf(worst, flow.beacon.fraction())
	var published: float = _charges.max() if not _charges.is_empty() else 0.0
	var held: bool = flow.state_name() == "beacon" and published < 1.0 and worst < 1.0 and _unsealed == unsealed_before
	_double.finish_pending()
	_double.delay_deaths = false
	_report("late kill", held and flow.state_name() == "gates" and _unsealed == unsealed_before + 1 and _charges[-1] == 1.0,
		"HP at 0 with the kill held back 5 ticks: state beacon, charge at most %.2f shown and %.2f published; the kill then opened the gates"
			% [worst, published])


# B2: only this stage's Warden unseals it.
func _foreign_kill_checks(mast: Vector3) -> void:
	var flow = _game.flow
	flow.retry_stage()
	var unsealed_before := _unsealed
	var far: Vector3 = _game.ctx.terrain.drop_point(mast.x + 80.0, mast.z + 40.0, 0.0)
	var stray: Node3D = _double.spawn_enemy("warden", far)
	_double.strike(stray, "arc", 99999.0)
	flow.physics_step(DT)
	_report("foreign warden", flow.sealed and flow.state_name() != "gates" and _unsealed == unsealed_before and is_instance_valid(flow.warden),
		"another warden killed 89 m away left this stage sealed (%s), state %s" % [flow.sealed, flow.state_name()])


# N1: without integrity_of, a warden kill 7 m from this stage's Warden is someone else's;
# one at 3 m is this one.
func _bare_spawner_checks() -> void:
	var flow = _game.flow
	var bare := BareSpawner.new()
	bare.ctx = _game.ctx
	_game.add_child(bare)
	_game.ctx.spawner = bare
	flow.retry_stage()
	var warden: Node3D = flow.warden
	var unsealed_before := _unsealed
	bare.kill(warden, warden.global_position + Vector3(7.0, 0.0, 0.0))
	var far_sealed: bool = flow.sealed and flow.state_name() != "gates"
	bare.kill(warden, warden.global_position + Vector3(3.0, 0.0, 0.0))
	_report("identity by position", far_sealed and not flow.sealed and flow.state_name() == "gates" and _unsealed == unsealed_before + 1,
		"no integrity_of(): a kill 7 m away left it sealed (%s); one 3 m away unsealed it (state %s)" % [far_sealed, flow.state_name()])
	_game.ctx.spawner = _double


# B2: a Warden that leaves without a kill opens the stage the normal way and is logged.
func _vanish_checks() -> void:
	var flow = _game.flow
	var unsealed_before := _unsealed
	var anomalies_before: int = _game.run.anomalies.size()
	flow.warden.free()
	flow.physics_step(DT)
	var noted: bool = _game.run.anomalies.size() == anomalies_before + 1 and _game.run.anomalies[-1]["kind"] == "warden_vanished"
	_report("vanished warden", flow.state_name() == "gates" and not flow.sealed and _unsealed == unsealed_before + 1 and noted and _charges[-1] == 1.0,
		"freed without record_kill: state %s, beacon_unsealed fired %d time(s), run anomaly %s"
			% [flow.state_name(), _unsealed - unsealed_before, _game.run.anomalies[-1] if noted else "missing"])
