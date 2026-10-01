extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Roster := preload("res://src/combat/roster.gd")

# Rivet's sprint ignores every hold (DESIGN-V2 section 10.2): every holding counter
# that can reach a grounded ball stands round Rivet while his sprint runs, and each one
# that fires is refused at the crowd-control door (cc_ignored with its mechanic) with
# no hold taken. Then the sprint stops and the same field holds him: the control.

const HOLDERS := ["mag_trapper", "hooker", "bola_thrower", "winch_drone", "gyro_jammer", "swatter", "ramp_flipper",
	"catch_trap"]
const RING := 9.5
const SPRINT_SECONDS := 7.0
const CONTROL_SECONDS := 6.0

var _game
var _holds
var _source := Intent.Scripted.new()
var _failures := 0
var _step := 0
var _clock := 0.0
var _ignored := {}
var _sprinting := true


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	if _step == 0:
		_setup()
		_step = 1
		return false
	_clock += delta
	var kit = _game.player.kit
	if _sprinting:
		kit.sprinting = true
		kit.sprint_left = 99.0
	if _step == 1 and _clock >= SPRINT_SECONDS:
		var expected := {}
		for kind in HOLDERS:
			expected[Roster.row(kind)["mechanic"]] = true
		var missing: Array = expected.keys().filter(func(m): return not _ignored.has(m))
		_report("sprint ignores every hold", _holds.catches == 0 and missing.is_empty(),
			"%d holds taken while sprinting; refused at the door: %s; never tried: %s" % [_holds.catches, _ignored.keys(), missing])
		_sprinting = false
		kit.sprinting = false
		_source.hold = {}
		_step = 2
		_clock = 0.0
	elif _step == 2 and (_holds.catches > 0 or _clock >= CONTROL_SECONDS):
		_report("control", _holds.catches > 0, "without the sprint the same field held Rivet %d times in %.1f s" % [_holds.catches, _clock])
		return _finish()
	return false


func _setup() -> void:
	var ctx = _game.ctx
	ctx.calm = true
	_game.player.source = _source
	_source.hold = {"movement_held": true}
	_game.flow.press_start()
	_game.flow.choose_class(1)
	_game.run.set_max_hp(99999.0)
	_holds = ctx.spawner.fleet.holds
	_game.events.cc_ignored.connect(func(kind: String): _ignored[kind] = true)
	var ball: Vector3 = ctx.terrain.drop_point(ctx.terrain.spawn_point(1).x, ctx.terrain.spawn_point(1).z, 1.05)
	_game.player.reset_to(ball)
	for i in HOLDERS.size():
		var angle := TAU * i / HOLDERS.size()
		var at: Vector3 = ball + Vector3(cos(angle), 0.0, sin(angle)) * RING
		var unit: Node3D = ctx.spawner.spawn_enemy(HOLDERS[i], ctx.terrain.drop_point(at.x, at.z, 1.8))
		unit._rest = 0.2 + 0.25 * i


func _finish() -> bool:
	var ok := _failures == 0
	print("enemy_rivet_test: %s" % ("PASS" if ok else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if ok else 1)
	return true
