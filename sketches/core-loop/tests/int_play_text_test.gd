extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const StageDefs := preload("res://tests/doubles/two_world_defs.gd").FirstWorld
const EventView := preload("res://src/world/event_view.gd")

# The words Andrew reads in play (FIXWAVE spine, build and world minors), checked on
# the real title screen, field notes, HUD and stage-1 world of a non-calm run:
#   - the title and the notes teach the demo's objective: Wardens and their guard, three
#     stages, then Admiral Brindle; the notes cover the arena's R and T;
#   - an undiscovered codex card prints its clue once;
#   - a lost event toasts as a loss, a passed or won one adds no "over" toast;
#   - a stage's resting weather (announced with no lead) toasts no "incoming";
#   - the vault carries a prompt naming its rare part, bonus core and plating, and the
#     event sign names the bonus core;
#   - stage 3's hint says when the magnet can be shot.

# Legacy three-stage wording and event signs use the event-enabled double.
# F6 2026-10-04: the stage 3 hint is the posture line, not the magnet lesson.
class LegacyGame extends "res://src/game.gd":
	func _chosen_table():
		return preload("res://tests/doubles/two_world_defs.gd").FirstWorld

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0
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
	match _phase:
		"boot":
			if _wait == 3:
				_s["title"] = _game.screens.said_body()
				_game.player.source = Intent.Scripted.new()
				_game.flow.press_start()
				_game.flow.choose_class(0)
				_phase = "play"
				_wait = 0
		"play":
			if _wait == 20:
				_check_words()
				_check_toasts()
				_check_world()
				print("int_play_text_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _check_words() -> void:
	var title: String = _s["title"]
	var notes := "\n".join(FieldNotes.TESTING)
	var keys := FieldNotes.SCREEN_KEYS.map(func(k): return k["keys"])
	_report("objective taught", title.contains(FieldNotes.OBJECTIVE) and FieldNotes.OBJECTIVE.contains("Take it back") and FieldNotes.OBJECTIVE.contains("Wardens")
			and not FieldNotes.OBJECTIVE.contains("plating")
			and not title.contains("Charge each beacon") and notes.contains("Brindle") and not notes.contains("a summary after stage 3")
			and "N" in keys and not ("T" in keys) and not notes.contains("T replays that world's last stage"),
		"title reads \"%s\"; notes name Brindle %s and teach the arena's T %s; screen keys %s (N expected, T not)"
			% [title.replace("\n", " / "), notes.contains("Brindle"), notes.contains("T replays that world's last stage"), keys])
	var build_card := FieldNotes.hint_card_text("◆", "Chain Arc + something that splits", "something that splits")
	var enemy_card := FieldNotes.hint_card_text("×", "Lobbers hate their own mail.", "a lobber's shell + a bat")
	_report("clue printed once", build_card.count("something that splits") == 1 and enemy_card.split("\n").size() == 3,
		"build card \"%s\"; enemy card \"%s\"" % [build_card.replace("\n", " / "), enemy_card.replace("\n", " / ")])
	var hint: String = StageDefs.of(3)["warden_hint"]
	_report("stage 3 hint", hint.contains("smash the core"), "stage 3's Warden hint reads \"%s\"" % hint)


func _check_toasts() -> void:
	var hud = _game.get_node("Hud")
	var before: Array = hud.toast_texts()
	_game.events.event_ended.emit("surge_run", "passed")
	_game.events.event_ended.emit("hold_the_relay", "won")
	var after_quiet: Array = hud.toast_texts()
	_game.events.event_ended.emit("surge_run", "lost")
	var after_lost: Array = hud.toast_texts()
	var lost := after_lost.filter(func(t): return String(t).begins_with("Surge Run lost"))
	_report("lost event toast", after_quiet == before and lost.size() == 1 and not after_lost.any(func(t): return String(t).ends_with(" over")),
		"passed and won ends added %d toasts; a lost Surge Run toasts %s" % [after_quiet.size() - before.size(), lost])
	# "incoming" is a warning: the stage's resting weather is announced with no lead and warns of nothing.
	hud.clear_toasts()
	_game.events.event_announced.emit("dawn_still", 0.0, Vector3.INF)
	var resting: Array = hud.toast_texts()
	_game.events.event_announced.emit("monsoon_buildup", 20.0, Vector3.INF)
	var coming: Array = hud.toast_texts()
	_report("only weather on its way toasts as incoming", resting.is_empty() and coming == ["Monsoon Buildup incoming"],
		"resting weather toasts %s; a monsoon 20 s out toasts %s" % [resting, coming])


func _check_world() -> void:
	var world = _game.get_node("World")
	var view = world.view
	var prompt: String = view.vault_prompt.text
	var signs: Array = view._offer_nodes.map(func(e): return (e["sign"] as Label3D).text)
	_report("vault prompt", world.vault != null and prompt.begins_with("Vault: rare part + bonus core (plating ")
			and EventView.vault_text(95.0) == "Vault: rare part + bonus core (plating 95)",
		"the stage-1 vault stands (%s) with the prompt \"%s\"" % [world.vault != null, prompt])
	_report("event sign", not signs.is_empty() and signs.all(func(t): return String(t).contains("milestone part + bonus core")),
		"event signs read %s" % [signs.map(func(t): return String(t).replace("\n", " / "))])
