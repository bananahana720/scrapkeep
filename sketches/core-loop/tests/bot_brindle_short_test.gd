# smoke: solo timeout=360s (four fixed-90-fps children side by side; a skipper bot fights Brindle's Furnace and Scuttle with a bare ball; reads simulated time against caps)
extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const T := preload("res://tests/support/t.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")
const SimClock := preload("res://src/core/sim_clock.gd")

# Brindle's hull fills its posture bar on the square of punch over plating 110, so a bare ball
# (heft 1, punch about 45 at the top roll) glances off it, and the Furnace slag drains heft that
# far. The park seed-2 runs of Tally, Tarn and Demolitions then stalled at the 420 s boss cap
# (PARK-BOSS). The cause was the hull's collider: it stayed at the arena centre while the ship
# moved, so the hull the ball saw took no contact. The run starts normally at heft 1, jumps to
# stage 2, enters the arena and jumps to the phase; the bot must take the phase's chunk inside
# the cap, and the hull's physics body must stand where its node stands.
#
# The claim is that a bare ball CAN break each phase, so each pilot plays SEEDS side by side and the phase passes when
# any seed takes the chunk inside the cap; every seed must keep the hull's body on its node and stay a bare ball. One
# seed was a pin on chaos: the bowl entry's move from 210 to 245 degrees (PR 753) flipped seed 2 from a take to a
# death, while across seeds 1 to 6 the new entry took 7 of 12 phases and the old one 2 of 12, with the first hit no
# earlier (12 Nov). A hull the ball cannot touch takes no chunk on any seed.
#
# Evidence limit: four seeds and one pilot per phase, entered with a placed ball; it says a bare ball can break the
# phase, not how often, how a full run reaches it or how it feels.

const SEEDS := [1, 2, 3, 4]
const JUMP_STAGE := 2
const HEFT_MAX := 1.3
# Float tolerance on the 1.30 limit, not a looser rule (the phase 2 tally peak printed 1.30 when the
# run's discovery bursts still counted; with the codex seen it reads 1.00, scrapkeep#231).
const HEFT_EPS := 0.005
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
var _seed := 0


func _initialize() -> void:
	# The phases run in a fixed-90-fps child with hit-stop on the tick count, as bot_run.gd plays:
	# on the wall clock the phase 2 peak heft moved with CPU load (1.12 to 1.30 on one commit).
	if not OS.get_cmdline_user_args().has("--child"):
		var jobs: Array = SEEDS.map(func(s): return {"script": "res://tests/bot_brindle_short_test.gd", "args": ["--child", "--seed=%d" % s]})
		var results := ChildRuns.run(jobs, 300.0)
		var took := {}
		for i in results.size():
			var result: Dictionary = results[i]
			print(result["log"])
			_t.check("seed %d ran clean" % SEEDS[i], result["code"] == 0 and not result["timed_out"] and ChildRuns.summary(result)["errors"].is_empty(),
				"exit %s, timed out %s" % [result["code"], result["timed_out"]])
			for line in String(result["log"]).split("\n"):
				if line.begins_with("CHUNK "):
					var parts := line.split(" ")
					took[parts[1]] = int(took.get(parts[1], 0)) + (1 if parts[3] == "took" else 0)
		for c in CASES:
			var key := "phase%d" % c["phase"]
			_t.check("phase %d %s takes the chunk on some seed" % [c["phase"], c["pilot"]], int(took.get(key, 0)) > 0,
				"%d of %d seeds" % [int(took.get(key, 0)), SEEDS.size()])
		quit(_t.verdict())
		return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seed="):
			_seed = int(arg.substr(7))
	SimClock.ticks = true
	seed(1)
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
	if _game == null or _game.flow == null:
		return false
	var c: Dictionary = CASES[_case]
	if _driver == null:
		_driver = BotDriver.new(_game, "skipper", _seed)
		_driver.class_index = BotDriver.class_index_for(_seed, String(c["pilot"]))
		_driver.start()
		return false
	if _boss == null:
		if _game.flow.state_name() == "stage" and _game.run.stage == 1:
			_game.flow.enter_stage(JUMP_STAGE, Vector3(0.0, 0.0, 14.0), false)
			_game.flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss = _game.ctx.boss
			_boss.jump_to_phase(int(c["phase"]))
			_chunks = int(_boss.chunks_left())
			# A bare ball has not grown. A run's first discovery of each codex entry pays a scrap
			# burst (flow.discovery_burst, 40 at stage 2), and which tricks a bot happens to set off
			# first moves with any physics change: Tally's set piece and its cash-in paid 80 and took
			# the peak from 1.30 to 1.36 once spawned enemies entered physics where they stand
			# (scrapkeep#231). So the phase starts with the run's codex already seen; kill scrap
			# still counts.
			for id in _game.ctx.codex._entries:
				_game.ctx.codex._run_seen[id] = true
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
	var label := "phase %d %s seed %d" % [c["phase"], c["pilot"], _seed]
	_t.check("%s hull body follows the hull" % label, _drift < 0.5, "largest body-to-node gap %.2f m" % _drift)
	_t.check("%s stays a bare ball" % label, _heft <= HEFT_MAX + HEFT_EPS, "peak heft %.2f, want <= %.2f" % [_heft, HEFT_MAX])
	print("CHUNK phase%d %d %s %.1f s of a %.0f s cap, chunks %d -> %d, bot outcome '%s'"
		% [c["phase"], _seed, "took" if took else "missed", seconds, c["cap_s"], _chunks, _boss.chunks_left(), _driver.outcome])
	_game.free()
	_case += 1
	if _case >= CASES.size():
		quit(_t.verdict())
		return true
	_start()
	return false
