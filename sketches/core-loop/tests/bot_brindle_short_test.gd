# smoke: solo (a skipper bot fights Brindle's Furnace and Scuttle with a bare ball; reads simulated time against caps)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")

# Brindle's hull fills its posture bar on the square of punch over plating 110, so a bare ball
# (heft 1, punch about 45 at the top roll) glances off it, and the Furnace slag drains heft that
# far. The park seed-2 runs of Tally, Tarn and Demolitions then stalled at the 420 s boss cap
# (PARK-BOSS). The cause was the hull's collider: it stayed at the arena centre while the ship
# moved, so the hull the ball saw took no contact. The run starts normally at heft 1, jumps to
# stage 2, enters the arena and jumps to the phase; the bot must take the phase's chunk inside
# the cap, and the hull's physics body must stand where its node stands.
#
# Evidence limit: one seed and one pilot per phase, entered with a placed ball; it says a bare
# ball can break the phase, not how a full run reaches it or how it feels.

const SEED := 2
const JUMP_STAGE := 2
const HEFT_MAX := 1.3
const CASES := [
	{"phase": 2, "pilot": "tally", "cap_s": 120.0},
	{"phase": 3, "pilot": "tarn", "cap_s": 120.0},
]

var _t := T.new("bot_brindle_short_test")
var _case := 0
var _game
var _driver
var _boss
var _ticks := 0
var _chunks := 0
var _heft := 0.0
var _drift := 0.0


func _initialize() -> void:
	_start()


func _start() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_driver = null
	_boss = null
	_ticks = 0
	_heft = 0.0
	_drift = 0.0


func _physics_process(delta: float) -> bool:
	if _game.flow == null:
		return false
	var c: Dictionary = CASES[_case]
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", SEED)
		_driver.class_index = BotDriver.class_index_for(SEED, String(c["pilot"]))
		_driver.start()
		return false
	if _boss == null:
		if _game.flow.state_name() == "stage" and _game.run.stage == 1:
			_game.flow.enter_stage(JUMP_STAGE, Vector3(0.0, 0.0, 14.0), false)
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss = _game.ctx.boss
			_boss.jump_to_phase(int(c["phase"]))
			_chunks = int(_boss.chunks_left())
		else:
			_driver.tick(delta)
		return false
	_ticks += 1
	var over: bool = _driver.tick(delta)
	_heft = maxf(_heft, _game.run.heft())
	var hull: Node3D = _boss.ship.hull
	var body: Transform3D = PhysicsServer3D.body_get_state(hull.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM)
	_drift = maxf(_drift, body.origin.distance_to(hull.global_position))
	var took: bool = int(_boss.chunks_left()) < _chunks
	var seconds := float(_ticks) / float(Engine.physics_ticks_per_second)
	if not (took or over or seconds > float(c["cap_s"])):
		return false
	var label := "phase %d %s" % [c["phase"], c["pilot"]]
	_t.check("%s hull body follows the hull" % label, _drift < 0.5, "largest body-to-node gap %.2f m" % _drift)
	_t.check("%s stays a bare ball" % label, _heft <= HEFT_MAX, "peak heft %.2f, want <= %.2f" % [_heft, HEFT_MAX])
	_t.check("%s takes the chunk" % label, took, "%.1f s of a %.0f s cap, chunks %d -> %d, bot outcome '%s'"
		% [seconds, c["cap_s"], _chunks, _boss.chunks_left(), _driver.outcome])
	_game.free()
	_case += 1
	if _case >= CASES.size():
		quit(_t.verdict())
		return true
	_start()
	return false
