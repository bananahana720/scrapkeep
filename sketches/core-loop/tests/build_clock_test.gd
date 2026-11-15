extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const RunClock := preload("res://src/build/run_clock.gd")
const Director := preload("res://src/world/director.gd")

# The run clock, the difficulty clock and the two challenge modifiers (DESIGN-V2
# section 7, PROGRESSION section 1):
#   - the build's difficulty schedule is the director's (45 s a tier, two tiers), so
#     the bar W1 draws can never drift from the spawns it predicts;
#   - clock_record() carries the run seconds, the stage's filling difficulty bar with
#     its tier and pause flag, and the par ghost;
#   - the par ghost is the best Warden break on record in runs.ndjson, split against
#     this stage's clock, and shows with the par modifier;
#   - Scrapless is tagged on the run: a gate takes nothing yet still launches, and a
#     kill drops no scrap.

var _game
var _build
var _failures := 0
var _ticks := 0
var _phase := 0
var _wait := 0
var _chosen: Array = []
var _start := {}


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_build = _game.ctx.build
		_write_record()
		_build.set_modifiers({"par": true})
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.events.reward_chosen.connect(func(id: String): _chosen.append(id))
		return false
	if _ticks < 12:
		return false
	match _phase:
		0:
			_check_schedule()
			_start = _build.clock_record()
			_phase = 1
		1:
			_wait += 1
			if _wait >= 45:
				_check_record()
				_game.flow.new_run()
				_phase = 2
				_wait = 0
		2:
			_wait += 1
			if _wait == 2:
				_build.set_modifiers({"scrapless": true})
				_game.flow.new_run()
			if _wait >= 6:
				_check_scrapless()
				return _finish()
	return false


# A past run whose stage-1 Warden broke at 900 ticks.
func _write_record() -> void:
	var dir: String = _game.codex.storage_dir
	var line := {"run_id": "old", "stages": [{"stage": 1, "ticks_to_warden_break": 900}, {"stage": 2, "ticks_to_warden_break": null}]}
	_game.codex.append_line(dir.path_join("runs.ndjson"), JSON.stringify(line))


func _check_schedule() -> void:
	var per_stage := true
	for stage in range(0, 8):
		var clock := RunClock.new()
		clock.stage = stage
		per_stage = per_stage and clock.tiers() == Director.clock_tiers(stage)
	_report("difficulty schedule is the director's", RunClock.DIFFICULTY_TICK == Director.TIER_SECONDS
			and RunClock.DIFFICULTY_TIERS == Director.MAX_TIME_TIERS and per_stage,
		"build %.0f s x %d tiers, director %.0f s x %d; every stage's last tier agrees: %s" % [RunClock.DIFFICULTY_TICK, RunClock.DIFFICULTY_TIERS,
			Director.TIER_SECONDS, Director.MAX_TIME_TIERS, per_stage])


func _check_record() -> void:
	var r: Dictionary = _build.clock_record()
	var d: Dictionary = r["difficulty"]
	var par: Dictionary = r["par"]
	var ticks_per_second := float(Engine.physics_ticks_per_second)
	var best_ok: bool = par["best"] != null and absf(float(par["best"]) - 900.0 / ticks_per_second) < 0.01
	var split_ok: bool = par["split"] != null and absf(float(par["split"]) - (r["stage_seconds"] - float(par["best"]))) < 0.01
	_report("clock record", d["fraction"] > _start["difficulty"]["fraction"] and d["tiers"] == Director.clock_tiers(1) and d["tier"] == 0
			and not d["paused"] and d["icon"] == "res_difficulty" and r["timer_icon"] == "res_timer" and r["tags"] == ["par"],
		"45 ticks in stage 1: difficulty %.4f -> %.4f of the bar, tier %d of %d; tags %s" % [_start["difficulty"]["fraction"],
			d["fraction"], d["tier"], d["tiers"], r["tags"]])
	_report("par ghost", par["on"] and best_ok and split_ok and not par["broken"],
		"best stage-1 break on record %.2f s; split now %.2f s" % [float(par["best"]) if par["best"] != null else -1.0,
			float(par["split"]) if par["split"] != null else 0.0])


func _check_scrapless() -> void:
	var run = _game.run
	var before: int = run.parts.size()
	_build._on_gate_chosen("hot_rivets")
	var field_before: int = _build.scrap.count()
	run.record_kill("chaser", _game.player.ball_position() + Vector3(3.0, 0.0, 0.0), 12)
	var dropped: int = _build.scrap.count() - field_before
	_report("scrapless", _build.run_tags() == ["scrapless"] and run.get_meta("run_tags", []) == ["scrapless"]
			and run.parts.size() == before and _chosen == ["hot_rivets"] and dropped == 0 and not _build.clock_record()["par"]["on"],
		"tags %s; a gate added %d parts and still published reward_chosen %s; a 12-scrap kill dropped %d pieces"
			% [_build.run_tags(), run.parts.size() - before, _chosen, dropped])


func _finish() -> bool:
	print("build_clock_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true
