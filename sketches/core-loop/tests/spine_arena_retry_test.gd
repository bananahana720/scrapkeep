extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const BossDouble := preload("res://tests/doubles/spine_boss_double.gd")
const DeathCause := preload("res://src/core/death_cause.gd")

# The arena's own attempt (FIXWAVE spine [C] and minors), through the real flow, codex
# and run log with a boss that publishes the live seam:
#   - entering the arena clears with reason "arena", an arena retry with "arena_retry";
#   - an arena discovery pays its burst again after R, while a stage-3 discovery made
#     before the arena stays paid; T replaying stage 3 rewinds both;
#   - the objective reads the boss's live plating and objective; the death screen says who
#     scrapped you and the gap as the build met the fight, in the words RUN OVER uses;
#   - arena deaths go in the run log's own arena record, not stage 3's deaths;
#   - one held R retries once, from the death screen or from play;
#   - the summary ignores keys for its first beat, then Space leaves it.


class LiveBoss:
	extends BossDouble

	var plating := 120.0
	var chase := ""

	func live_plating() -> float:
		return plating

	func objective_text() -> String:
		return chase


# Preserve the legacy three-stage rule on a double using surviving maps.
# 2026-10-04: retire with F6 the local plating cases; keep the flow regression.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _boss
var _failures := 0
var _phase := "boot"
var _wait := 0
var _cleared: Array[String] = []
var _facts: Array[String] = []
var _s := {}


func _initialize() -> void:
	_game = LegacyGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	var flow = _game.flow
	var run = _game.run
	var codex = _game.codex
	match _phase:
		"boot":
			_boss = LiveBoss.new()
			_game.add_child(_boss)
			_boss.setup(_game.ctx)
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.events.stage_content_cleared.connect(func(reason: String): _cleared.append(reason))
			_game.events.synergy_discovered.connect(func(id: String, _c: String, _f: bool): _facts.append(id))
			for id in ["i3_stage_trick", "i3_arena_trick"]:
				codex.declare({"id": id, "category": "enemy", "name": id, "hint": "", "clue": "", "text": ""})
			flow.press_start()
			flow.choose_class(0)
			flow.enter_stage(3, Vector3(0.0, 0.0, 16.0), false)
			codex.mark_discovered("i3_stage_trick")
			flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_s["entry_scrap"] = run.scrap
			codex.mark_discovered("i3_arena_trick")
			_s["paid_first"] = run.scrap - _s["entry_scrap"]
			_boss.plating = 150.0
			_s["objective_live"] = flow.objective_text()
			_boss.chase = "Brindle is running: ram or stomp his scooter."
			_s["objective_chase"] = flow.objective_text()
			_boss.chase = ""
			run.damage(1.0e9, "test")
			_boss.plating = 0.0
			_s["said"] = String(_game.screens.said_body())
			_s["cause"] = String(flow.death_cause)
			_s["tip"] = String(flow.death_tip)
			_s["memo"] = DeathCause.memo(run.run_seed, run.stage)
			_s["arena_deaths"] = (_game.run_log._record.get("arena", {}).get("deaths", []) as Array).size()
			_s["stage3_deaths"] = (_game.run_log._stages[3]["deaths"] as Array).size()
			# R is still down from the moment of death: the frame on the death screen sees it, and the
			# retry that follows (the store-less flow's stage retry) leaves it latched until release.
			_game.step_restart_hold(0.1, true)
			flow.retry_stage()
			_s["after_r"] = flow.state_name()
			_s["scrap_after_r"] = run.scrap
			_game.step_restart_hold(0.6, true)
			_s["clears_while_held"] = _cleared.size()
			codex.mark_discovered("i3_arena_trick")
			codex.mark_discovered("i3_stage_trick")
			_s["paid_again"] = run.scrap - _s["scrap_after_r"]
			_s["facts_after_retry"] = _facts.duplicate()
			_game.step_restart_hold(0.1, false)
			_game.step_restart_hold(0.6, true)
			_s["clears_after_release"] = _cleared.size()
			run.damage(1.0e9, "test")
			flow.replay_stage(3)
			codex.mark_discovered("i3_stage_trick")
			_s["facts_after_t"] = _facts.duplicate()
			_report_arena()
			flow.enter_boss(Vector3(15.0, 0.0, 0.0))
			_boss.defeat()
			var held := InputEventKey.new()
			held.keycode = KEY_SPACE
			held.physical_keycode = KEY_SPACE
			held.pressed = true
			Input.parse_input_event(held)
			Input.flush_buffered_events()
			_phase = "victory"
			_wait = 0
		"victory":
			if flow.state_name() == "summary" and not _s.has("summary_first"):
				_s["summary_first"] = _game._screen_key(KEY_SPACE)
				_s["after_early_space"] = flow.state_name()
				held_release()
				if _game.screens.ending_open():
					_game.screens._close_ending()
				_game.summary_latched = false
				_game._screen_key(KEY_SPACE)
				_s["after_late_space"] = flow.state_name()
				_report("summary guard", _s["after_early_space"] == "summary" and _s["after_late_space"] == "class_select",
					"Space the moment the summary appeared left flow in %s; after the latch opened Space went to %s"
						% [_s["after_early_space"], _s["after_late_space"]])
				print("spine_arena_retry_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
			if _wait > 90 * 6:
				_report("summary guard", false, "no summary 6 s after the win; flow in %s" % flow.state_name())
				quit(1)
				return true
	return false


func _report_arena() -> void:
	_report("clear reasons", _cleared.slice(0, 2) == ["arena", "arena_retry"],
		"arena entry and arena retry published stage_content_cleared %s" % [_cleared.slice(0, 2)])
	_report("arena codex rewind", _s["paid_first"] == 60 and _s["paid_again"] == 60
			and _s["facts_after_retry"].count("i3_arena_trick") == 2 and _s["facts_after_retry"].count("i3_stage_trick") == 1,
		"an arena trick paid %d scrap, and %d again after R; the stage-3 trick made before the arena fired %d time(s) by then"
			% [_s["paid_first"], _s["paid_again"], _s["facts_after_retry"].count("i3_stage_trick")])
	_report("T rewinds both", _s["facts_after_t"].count("i3_stage_trick") == 2,
		"after T replayed stage 3 the stage-3 trick fired again (%d in all)" % _s["facts_after_t"].count("i3_stage_trick"))
	_report("live boss objective", "150" in _s["objective_live"] and _s["objective_chase"].begins_with("Brindle is running"),
		"objective with live plating 150: \"%s\"; during the chase: \"%s\"" % [_s["objective_live"], _s["objective_chase"]])
	_report("death screen words", _s["cause"].begins_with("Scrapped by ") and _s["tip"].contains("plating 120.")
			and _s["said"] == "%s\n%s\nNext shift: %s" % [_s["cause"], _s["memo"], _s["tip"]],
		"met the hull at plating 120 and died against a bow at 150; cause, the Foreman's loss memo, then the crew's tip (W1-75): \"%s\"" % _s["said"].replace("\n", " | "))
	_report("arena run log", _s["arena_deaths"] == 1 and _s["stage3_deaths"] == 0,
		"an arena death went to the arena record (%d) and not to stage 3's deaths (%d)" % [_s["arena_deaths"], _s["stage3_deaths"]])
	_report("one retry per held R", _s["after_r"] == "boss" and _s["clears_while_held"] == 2 and _s["clears_after_release"] == 3,
		"a stage retry with R held since the death put flow in %s; holding R 0.6 s after it made %d clears in all (needs 2); release and hold again made %d (needs 3)"
			% [_s["after_r"], _s["clears_while_held"], _s["clears_after_release"]])


func held_release() -> void:
	var up := InputEventKey.new()
	up.keycode = KEY_SPACE
	up.physical_keycode = KEY_SPACE
	up.pressed = false
	Input.parse_input_event(up)
	Input.flush_buffered_events()
