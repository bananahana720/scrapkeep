extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FieldTips := preload("res://src/ui/field_tips.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")

# The first-meet tips (ui/field_tips.gd, HELP-REFRESH): each of grip, jam, cast, radio, stake,
# companion and active toasts its words once on a fresh profile the moment it is first met,
# says so on the bus as prompt_shown("tip_<id>"), and never repeats, across a new run too. The
# help page's rule lines name the same seven (field_notes.gd FIELD_RULES covers six; SPIL-9 is the
# Pictures caption). The first-timer audit reaches grip, radio and cast; the rest it cannot (a
# jammer, a relay, a seated companion and --actives are not on the bot's path), so this is
# their check.

# A relay's stake post stand-in: the tip reads terms(), relay and reach_point().
class Post:
	extends Node3D
	var relay := RefCounted.new()

	func terms() -> String:
		return "x1 stake, 2 parts"

	func reach_point() -> Vector3:
		return global_position


# A rack stand-in: the tip reads only active_id.
class Rack:
	extends RefCounted
	var active_id := ""


var _game
var _failures := 0
var _wait := 0
var _started := false
var _prompts: Array[String] = []


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
	if not _started:
		_started = true
		_game.ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.events.prompt_shown.connect(func(verb: String): _prompts.append(verb))
		_game.flow.press_start()
		_game.flow.choose_class(0)
		return false
	_wait += 1
	if _wait < 4:
		return false
	_run()
	print("field_tips_test: %s" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	quit(_failures)
	return false


func _tip(id: String, trigger: Callable) -> void:
	var tips = _game.hud.field_tips
	var before := _prompts.count("tip_" + id)
	var was_seen: bool = tips.seen(id)
	trigger.call()
	tips._physics_process(0.016)
	var first := _prompts.count("tip_" + id) - before
	trigger.call()
	tips._physics_process(0.016)
	var again := _prompts.count("tip_" + id) - before
	_report("tip " + id, not was_seen and first == 1 and again == 1 and tips.seen(id),
		"unseen before %s, emitted %d then %d, seen after %s, prompts %s" % [not was_seen, first, again, tips.seen(id), _prompts])


func _run() -> void:
	var tips = _game.hud.field_tips
	_report("in play", _game.flow.in_play(), "state %s" % _game.flow.state_name())
	# Only the radio's tip is already owed on the drop: the dial is on screen.
	tips._physics_process(0.016)
	_report("radio dial tip on the drop", tips.seen("radio") and _prompts.count("tip_radio") == 1, "prompts %s" % [_prompts])
	# A tip met in a fight waits, and is told when the fight lets go (the fight's word budget).
	_game.flow._engaged = true
	_game.player.state.carving = true
	tips._physics_process(0.016)
	_report("a fight holds the grip tip", not tips.seen("grip") and tips.pending.has("grip") and _prompts.count("tip_grip") == 0
		and not _game.hud.toast_texts().has(FieldTips.TIPS["grip"]), "pending %s, prompts %s" % [tips.pending, _prompts])
	_game.flow._engaged = false
	tips._physics_process(0.016)
	_report("the held tip comes after the fight", tips.seen("grip") and tips.pending.is_empty() and _prompts.count("tip_grip") == 1
		and _game.hud.toast_texts().has(FieldTips.TIPS["grip"]), "prompts %s, toasts %s" % [_prompts, _game.hud.toast_texts()])
	_game.flow._engaged = true
	tips._physics_process(0.016)
	_report("a fight takes a showing tip down", not _game.hud.toast_texts().has(FieldTips.TIPS["grip"]), "toasts %s" % [_game.hud.toast_texts()])
	_game.flow._engaged = false
	_game.player.state.carving = false
	_game.player.state.carving = true
	tips._physics_process(0.016)
	_report("grip tip does not repeat", _prompts.count("tip_grip") == 1, "prompts %s" % [_prompts])
	_game.player.state.carving = false
	_tip("jam", func(): _game.player.abilities.jam(0.5))
	_tip("cast", func(): _game.player.abilities.casting = "special")
	_game.player.abilities.casting = ""
	var post := Post.new()
	_game.add_child(post)
	post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH + 5.0, 0.0, 0.0)
	var interact = _game.ctx.root.get_node("Interact")
	interact.devices.append(post)
	tips._physics_process(0.016)
	_report("a stake post out of reach tells nothing", not tips.seen("stake") and _prompts.count("tip_stake") == 0, "prompts %s" % [_prompts])
	_tip("stake", func(): post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH - 5.0, 0.0, 0.0))
	interact.devices.erase(post)
	post.queue_free()
	_tip("companion", func(): _game.combat.companion_assist_full.emit())
	var real_rack = _game.combat.actives
	var rack := Rack.new()
	_game.combat.actives = rack
	tips._physics_process(0.016)
	_report("an empty rack tells nothing", not tips.seen("active"), "prompts %s" % [_prompts])
	_tip("active", func(): rack.active_id = "torch")
	_game.combat.actives = real_rack
	# A new run on the same profile repeats none of them.
	var count := _prompts.size()
	_game.events.run_started.emit("pylon_engineer")
	_game.player.state.carving = true
	tips._physics_process(0.016)
	_game.player.state.carving = false
	_report("no tip repeats in a new run", _prompts.size() == count, "prompts %d then %d" % [count, _prompts.size()])
	var reread := UiProfile.new(_game.storage_dir)
	var saved := true
	for id in FieldTips.TIPS:
		saved = saved and reread.seen(FieldTips.SEEN_PREFIX + id)
	_report("seen tips persist on the profile", saved, "tips %s" % [FieldTips.TIPS.keys()])
	var named := FieldNotes.FIELD_RULES.map(func(r): return r["id"])
	var covered := true
	for id in ["grip", "jam", "cast", "radio", "stake", "active"]:
		covered = covered and id in named and FieldTips.TIPS.has(id)
	_report("every help rule has a tip", covered, "rules %s" % [named])
