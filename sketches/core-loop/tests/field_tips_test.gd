extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const FieldTips := preload("res://src/ui/field_tips.gd")
const FieldNotes := preload("res://src/ui/field_notes.gd")
const UiProfile := preload("res://src/ui/ui_profile.gd")
const Palette := preload("res://src/core/palette.gd")

# The first-meet tips (ui/field_tips.gd, HELP-REFRESH): each of grip, jam, cast, radio, stake,
# companion, active and dunk toasts its words once on a fresh profile when first met, one tip per toast
# lifetime, and counts as told (prompt_shown("tip_<id>") and the profile's seen list) only after
# its toast has been on screen for MIN_SHOWN; a tip taken down sooner is told again later. A fight
# (an engaged, unbroken Warden, or the boss arena) holds tips back. Pacing (systems audit pass E):
# the drop owes no tip, though Tally's bar carries Gather Plate's cast time and the radio dial is
# up; at most one tip goes up in a run's first OPENING seconds, so the dunk and the first cast met
# there show one, then the other after OPENING; the radio waits for a cleared stage and hangs its
# keys on the dial while its tip is up; the grip waits for a real carve (events.carved) that
# touched a wall, so open ground and a dune face tell nothing; the active waits for a fight met in the run (a hit or a kill). The help page's rule lines name six of the
# eight (field_notes.gd FIELD_RULES; SPIL-9 is the Pictures caption, the dunk has no rule line). The first-timer audit
# reaches grip, radio and cast; the rest it cannot (a jammer, a relay, a seated companion and
# actives are not on the bot's path), so this is their check. The dunk tip toasts on the first stored
# charge. While stage 1's start-pick card is up, the radio and active tips wait (w22 first-timer
# watch 5), and a radio tip already waiting leaves the queue: checked on the rack here, and on the
# radio with a fresh profile at the end.

# A relay's stake post stand-in: the tip reads terms(), relay and reach_point().
class Post:
	extends Node3D
	var relay := RefCounted.new()

	func terms() -> String:
		return "x1 stake, 2 parts"

	func reach_point() -> Vector3:
		return global_position


# A rack stand-in: the tip reads enabled() (the actives option) and active_id.
class Rack:
	extends RefCounted
	var active_id := ""
	var on := true

	func enabled() -> bool:
		return on


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
		# Actives are on by default (24 Oct); the active tip is driven below by a stand-in rack.
		_game.tuning.set_option("actives", "off")
		_game.flow.press_start()
		var tally := -1
		for i in _game.flow.classes.size():
			if _game.flow.classes[i].id == "tally":
				tally = i
		_game.flow.choose_class(tally)
		return false
	_wait += 1
	if _wait < 4:
		return false
	_run()
	print("field_tips_test: %s" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures])
	quit(_failures)
	return false


# Steps the tips, the stage card and the HUD's toast clock together, `seconds` at 60 Hz; returns,
# per step, the tip id whose words the toast row drew ("" for none or other words).
func _advance(seconds: float) -> Array[String]:
	var tips = _game.hud.field_tips
	var drawn: Array[String] = []
	var dt := 1.0 / 60.0
	var card = _game.hud.launch_card
	for i in int(ceil(seconds / dt)):
		tips._physics_process(dt)
		# The stage card fades on its own tween, which no frame steps while this runs.
		if card._tween != null and card._tween.is_valid():
			card._tween.custom_step(dt)
		_game.hud._step_toast(dt)
		var on: String = _game.hud.toast_on_screen()
		drawn.append(FieldTips.TIPS.find_key(on) if FieldTips.TIPS.values().has(on) else "")
	return drawn


# A carve of 0.5 s on a face with `normal`, ended as rigid_ball.gd ends one: the flag drops, then
# events.carved.
func _carve(normal: Vector3) -> void:
	var state = _game.player.state
	state.grounded = true
	state.contact_normal = normal
	state.carving = true
	_advance(0.5)
	state.carving = false
	state.contact_normal = Vector3.UP
	_game.events.carved.emit(_game.player.ball_position(), 0.5, 20.0)
	_advance(1.0 / 60.0)


func _fight(on: bool) -> void:
	_game.flow._engaged = on
	_game.flow.sealed = on


func _tip(id: String, trigger: Callable) -> void:
	var tips = _game.hud.field_tips
	# Past the opening's one tip, which the start of the test checks.
	tips._run_time = maxf(tips._run_time, FieldTips.OPENING)
	_advance(3.0)
	var before := _prompts.count("tip_" + id)
	var was_seen: bool = tips.seen(id)
	trigger.call()
	_advance(3.0)
	var first := _prompts.count("tip_" + id) - before
	trigger.call()
	_advance(3.0)
	var again := _prompts.count("tip_" + id) - before
	_report("tip " + id, not was_seen and first == 1 and again == 1 and tips.seen(id),
		"unseen before %s, emitted %d then %d, seen after %s, prompts %s" % [not was_seen, first, again, tips.seen(id), _prompts])


# Frames on which `id` was drawn: [first index, last index, count].
static func _span(drawn: Array[String], id: String) -> Array:
	var first := drawn.find(id)
	return [first, drawn.rfind(id), drawn.count(id)]


func _run() -> void:
	var tips = _game.hud.field_tips
	var dt := 1.0 / 60.0
	var min_frames := int(ceil(FieldTips.MIN_SHOWN / dt))
	_report("in play", _game.flow.in_play(), "state %s" % _game.flow.state_name())
	var deck = _game.get("radio_deck")
	var dial_up: bool = deck != null and deck.dial != null and deck.dial.is_visible_in_tree()
	# The drop: the dial is up and the bar holds a cast time, and no tip is owed yet.
	var drop := _advance(8.0)
	_report("the drop owes no tip", _game.run.class_def.id == "tally" and dial_up and drop.filter(func(id): return id != "").is_empty()
		and tips.pending.is_empty() and _prompts.filter(func(p): return p.begins_with("tip_")).is_empty(),
		"class %s, dial %s, pending %s, prompts %s" % [_game.run.class_def.id, dial_up, tips.pending, _prompts])
	# Inside the opening, two verbs met: one tip goes up, the other waits for OPENING.
	_report("still in the opening", tips._run_time < FieldTips.OPENING - 6.0, "run time %.1f" % tips._run_time)
	_game.player.dunk.store(10.0, "", "tally", Color.WHITE)
	_game.player.abilities.casting = "special"
	var opening := _advance(5.0)
	_game.player.abilities.casting = ""
	var dunk := _span(opening, "dunk")
	_report("one tip in the opening", dunk[2] >= min_frames and tips.seen("dunk") and opening.count("cast") == 0
		and tips.pending.has("cast") and not tips.seen("cast"), "dunk frames %s, cast frames %d, pending %s" % [dunk, opening.count("cast"), tips.pending])
	var after_opening := _advance(FieldTips.OPENING - tips._run_time + 4.0)
	var cast := _span(after_opening, "cast")
	_report("the waiting tip goes up after the opening", cast[2] >= min_frames and tips.seen("cast") and _prompts.count("tip_cast") == 1
		and _prompts.find("tip_dunk") < _prompts.find("tip_cast"), "cast frames %s, prompts %s" % [cast, _prompts])
	_game.player.dunk.clear()
	# The radio waits for a cleared stage, then its dial draws its keys while the tip is up.
	_report("no radio tip before a stage is cleared", not tips.seen("radio") and not tips.pending.has("radio"), "pending %s" % [tips.pending])
	_game.events.stage_cleared.emit(1)
	_advance(0.2)
	var teaching: bool = deck.dial.teaching()
	var radio_on := _advance(4.0)
	_report("a cleared stage lets the radio tip up, keys on the dial", teaching and radio_on.count("radio") > 0 and tips.seen("radio")
		and _prompts.count("tip_radio") == 1, "teaching %s, frames %d, prompts %s" % [teaching, radio_on.count("radio"), _prompts])
	_game.player.abilities.casting = "special"
	_advance(3.0)
	_game.player.abilities.casting = ""
	_report("cast tip does not repeat when a cast starts", _prompts.count("tip_cast") == 1, "prompts %s" % [_prompts])
	# Open ground: a carve on the flat, and one down a dune face (30 degrees, past CARVE_DOT but no
	# wall), each end with events.carved and tell nothing (PC film 93d3fd86, frame 0016).
	_carve(Vector3.UP)
	_carve(Vector3(0.5, 0.866, 0.0))
	_report("a carve on open ground or a dune is no grip lesson", not tips.pending.has("grip") and not tips.seen("grip")
		and tips.showing != "grip", "pending %s, showing %s" % [tips.pending, tips.showing])
	# A seam hop sets the carving flag for a moment: no tip. A real carve ends with events.carved.
	_game.player.state.carving = true
	_advance(1.0)
	_game.player.state.carving = false
	_report("a seam hop is no grip lesson", not tips.pending.has("grip") and not tips.seen("grip"), "pending %s" % [tips.pending])
	# A tip met in a fight waits, and is told when the fight lets go (the fight's word budget).
	_fight(true)
	_carve(Vector3(0.95, 0.1, 0.0).normalized())
	_advance(1.0)
	_report("a fight holds the grip tip", not tips.seen("grip") and tips.pending.has("grip") and _prompts.count("tip_grip") == 0
		and not _game.hud.toast_texts().has(FieldTips.TIPS["grip"]), "pending %s, prompts %s" % [tips.pending, _prompts])
	# A Warden broken: flow unseals, the engaged flag stays up until the next beacon, and the
	# fight is over all the same.
	_game.flow.sealed = false
	_advance(0.1)
	_report("a broken Warden lets the tip up", tips.showing == "grip" and _game.hud.toast_on_screen() == FieldTips.TIPS["grip"]
		and not tips.seen("grip"), "showing %s, toasts %s" % [tips.showing, _game.hud.toast_texts()])
	# The Warden's fight comes back before the tip has been up MIN_SHOWN: it comes down unseen.
	_fight(true)
	_advance(0.1)
	_report("a fight takes a showing tip down, untold", not _game.hud.toast_texts().has(FieldTips.TIPS["grip"])
		and not tips.seen("grip") and _prompts.count("tip_grip") == 0 and tips.pending.has("grip"),
		"toasts %s, pending %s, prompts %s" % [_game.hud.toast_texts(), tips.pending, _prompts])
	_fight(false)
	# The boss arena holds it too, whatever the Warden flag says.
	var stage_state: int = _game.flow.state
	_game.flow.state = _game.flow.BOSS
	var in_arena := _advance(3.0)
	_report("no tip toasts in the boss arena", in_arena.count("grip") == 0 and _prompts.count("tip_grip") == 0 and tips.pending.has("grip"),
		"flow %s, frames %d, pending %s, prompts %s" % [_game.flow.state_name(), in_arena.count("grip"), tips.pending, _prompts])
	_game.flow.state = stage_state
	_advance(3.0)
	_report("the dropped tip is told again later", tips.seen("grip") and tips.pending.is_empty() and _prompts.count("tip_grip") == 1,
		"prompts %s, pending %s" % [_prompts, tips.pending])
	# A jam met in a fight and still untold when a new run starts stays dropped: the jam count
	# only grows and lives across runs, so the new run's frames must not read it as a fresh jam.
	_fight(true)
	_game.player.abilities.jam(0.5)
	_advance(0.2)
	var jam_held: bool = tips.pending.has("jam") and not tips.seen("jam")
	_game.events.run_started.emit("pylon_engineer")
	_fight(false)
	var jam_after := _advance(3.0)
	_report("an old run's untold jam does not show in the new run", jam_held and jam_after.count("jam") == 0
		and not tips.pending.has("jam") and not tips.seen("jam") and _prompts.count("tip_jam") == 0,
		"held %s, frames %d, pending %s, prompts %s" % [jam_held, jam_after.count("jam"), tips.pending, _prompts])
	# Another toast replacing a tip before MIN_SHOWN sends it back to wait, and it is told after.
	_game.player.abilities.jam(0.5)
	_advance(0.1)
	var jam_up: bool = tips.showing == "jam"
	_game.hud.toast("Some other words", Palette.SAND, "diamond", 3)
	_advance(0.1)
	_report("a replaced tip is not told", jam_up and not tips.seen("jam") and tips.pending.has("jam") and _prompts.count("tip_jam") == 0,
		"was up %s, pending %s, prompts %s" % [jam_up, tips.pending, _prompts])
	_advance(6.0)
	_report("the replaced tip is told after", tips.seen("jam") and _prompts.count("tip_jam") == 1, "prompts %s" % [_prompts])
	_carve(Vector3(0.95, 0.1, 0.0).normalized())
	_advance(3.0)
	_report("grip tip does not repeat", _prompts.count("tip_grip") == 1, "prompts %s" % [_prompts])
	var post := Post.new()
	_game.add_child(post)
	post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH + 5.0, 0.0, 0.0)
	var interact = _game.ctx.root.get_node("Interact")
	interact.devices.append(post)
	_advance(3.0)
	_report("a stake post out of reach tells nothing", not tips.seen("stake") and _prompts.count("tip_stake") == 0, "prompts %s" % [_prompts])
	# A tip still waiting when a new run starts belongs to the old run's moment: it is dropped, not
	# shown in the new run, and told only when met again.
	_fight(true)
	post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH - 5.0, 0.0, 0.0)
	_advance(0.5)
	var held: bool = tips.pending.has("stake")
	_game.events.run_started.emit("pylon_engineer")
	_report("a new run clears the queue", held and tips.pending.is_empty() and tips.showing == "",
		"held %s, pending %s, showing %s" % [held, tips.pending, tips.showing])
	_fight(false)
	post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH + 5.0, 0.0, 0.0)
	var after_run := _advance(3.0)
	_report("an old run's pending tip does not show in the new run", after_run.count("stake") == 0 and not tips.seen("stake")
		and _prompts.count("tip_stake") == 0, "frames %d, prompts %s" % [after_run.count("stake"), _prompts])
	# A tip on screen, not yet told, comes down with the old run and stays unseen.
	_game.combat.companion_assist_full.emit()
	_advance(0.1)
	var up: bool = tips.showing == "companion" and _game.hud.toast_on_screen() == FieldTips.TIPS["companion"]
	_game.events.run_started.emit("pylon_engineer")
	var gone := _advance(3.0)
	_report("a new run takes an untold tip down", up and gone.count("companion") == 0 and not tips.seen("companion")
		and _prompts.count("tip_companion") == 0 and not _game.hud.toast_texts().has(FieldTips.TIPS["companion"]),
		"was up %s, frames %d, prompts %s" % [up, gone.count("companion"), _prompts])
	_tip("stake", func(): post.global_position = _game.player.ball_position() + Vector3(FieldTips.STAKE_REACH - 5.0, 0.0, 0.0))
	interact.devices.erase(post)
	_tip("companion", func(): _game.combat.companion_assist_full.emit())
	var real_rack = _game.combat.actives
	var rack := Rack.new()
	_game.combat.actives = rack
	_advance(3.0)
	_report("an empty rack tells nothing", not tips.seen("active"), "prompts %s" % [_prompts])
	rack.on = false
	rack.active_id = "torch"
	_advance(3.0)
	_report("a rack with actives off tells nothing", not tips.seen("active") and tips.pending.is_empty(), "prompts %s" % [_prompts])
	rack.on = true
	var card = _game.flow.start_card
	var card_was: bool = card.visible
	card.visible = true
	rack.active_id = "torch"
	var under_card := _advance(3.0)
	_report("the start card holds the active tip", under_card.count("active") == 0 and not tips.pending.has("active")
		and not tips.seen("active"), "frames %d, pending %s" % [under_card.count("active"), tips.pending])
	card.visible = card_was
	# A rack before any fight in the run waits; the first kill lets it up.
	var calm := _advance(3.0)
	_report("a rack before a fight tells nothing", calm.count("active") == 0 and not tips.seen("active"), "pending %s" % [tips.pending])
	rack.active_id = ""
	_game.events.enemy_killed.emit("grunt", Vector3.ZERO, 1)
	_tip("active", func(): rack.active_id = "torch")
	_game.combat.actives = real_rack
	# A new run on the same profile repeats none of them, every verb met again.
	var count := _prompts.size()
	_game.events.run_started.emit("pylon_engineer")
	_game.combat.actives = rack
	rack.active_id = "torch"
	_carve(Vector3(0.95, 0.1, 0.0).normalized())
	_game.events.player_hit.emit(5.0, "test")
	_game.events.stage_cleared.emit(1)
	_game.player.abilities.jam(0.5)
	_game.player.abilities.casting = "special"
	_game.combat.companion_assist_full.emit()
	_game.player.dunk.store(10.0, "", "tally", Color.WHITE)
	interact.devices.append(post)
	post.global_position = _game.player.ball_position()
	var again_run := _advance(3.0)
	_game.player.abilities.casting = ""
	interact.devices.erase(post)
	_game.combat.actives = real_rack
	var drawn_tips := again_run.filter(func(id): return id != "")
	_report("no tip repeats in a new run", _prompts.size() == count and drawn_tips.is_empty() and tips.pending.is_empty(),
		"prompts %d then %d, drawn %s, pending %s" % [count, _prompts.size(), drawn_tips, tips.pending])
	post.queue_free()
	var reread := UiProfile.new(_game.storage_dir)
	var saved := true
	for id in FieldTips.TIPS:
		saved = saved and reread.seen(FieldTips.SEEN_PREFIX + id)
	_report("seen tips persist on the profile", saved, "tips %s" % [FieldTips.TIPS.keys()])
	var named := FieldNotes.FIELD_RULES.map(func(r): return r["id"])
	var covered := true
	for id in ["grip", "radio", "stake", "active"]:
		covered = covered and id in named and FieldTips.TIPS.has(id)
	# Jam and cast keep their tips; their rule lines became the picture captions (ruling cx).
	for id in ["jam", "cast"]:
		covered = covered and FieldTips.TIPS.has(id)
	_report("every help rule has a tip", covered, "rules %s" % [named])
	_radio_waits_for_the_pick()


# A fresh profile with the start-pick card up: the dial is drawn but its tip waits for the pick.
func _radio_waits_for_the_pick() -> void:
	var tips = _game.hud.field_tips
	var old_profile = tips.profile
	var fresh_dir := "user://field_tips_test_fresh_%d" % OS.get_process_id()
	tips.profile = UiProfile.new(fresh_dir)
	_game.events.stage_cleared.emit(1)
	tips.pending.append("radio")
	_game.player.dunk.clear()
	var card = _game.flow.start_card
	var card_was: bool = card.visible
	card.visible = true
	var deck = _game.get("radio_deck")
	var dial_up: bool = deck != null and deck.dial != null and deck.dial.is_visible_in_tree()
	var held := _advance(3.0)
	_report("the start card holds the radio tip", dial_up and held.count("radio") == 0 and not tips.pending.has("radio")
		and not tips.seen("radio"), "dial %s, frames %d, pending %s" % [dial_up, held.count("radio"), tips.pending])
	card.visible = false
	# The launch take that reveals the card holds the tip too (its HOLD phase, set bare).
	var take = _game.launch_take
	take.phase = take.HOLD
	var under_take := _advance(1.0)
	_report("the launch take holds the radio tip", under_take.count("radio") == 0 and not tips.pending.has("radio"),
		"frames %d, pending %s" % [under_take.count("radio"), tips.pending])
	take.phase = take.IDLE
	var after := _advance(8.0)
	_report("the radio tip follows the pick", after.count("radio") > 0 and tips.seen("radio"), "frames %d" % after.count("radio"))
	card.visible = card_was
	tips.profile = old_profile
	DirAccess.remove_absolute(fresh_dir.path_join(UiProfile.FILE))
	DirAccess.remove_absolute(fresh_dir)
