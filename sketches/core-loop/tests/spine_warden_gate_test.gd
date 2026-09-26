extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const SpawnerDouble := preload("res://tests/doubles/spine_spawner_double.gd")

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
	_report("sealed", flow.sealed and is_instance_valid(warden) and warden.kind == "warden" and warden.plating == 30.0,
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
