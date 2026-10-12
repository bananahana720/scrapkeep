extends SceneTree

# PE-TALLY, 2026-10-11: shipped clips and the real bus, PILOT-CLIPS section 7.2 items 1-11.
# No synthetic animations. EXPECTED includes the final count assertion.
const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Preview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED := 112

class FreshProfile:

	extends RefCounted
	var _seen: Array = []
	func seen(id: String) -> bool:
		return id in _seen
	func mark_seen(id: String) -> void:
		_seen.append(id)

var _t := T.new("pilot_clips_tally_test")
var _phase := "idle"


func _initialize() -> void:
	_run.call_deferred()


func _playing(rec: Dictionary, clip: String) -> bool:
	return rec.animator.is_playing() and rec.animator.current_animation == clip


func _rest_end(rec: Dictionary) -> void:
	Trigger.finish(rec)
	_t.check("one-shot returns to idle_loop", _playing(rec, "idle_loop"))
	_t.check("every bone at rest at hand-off", Trigger.bones_at_rest(rec.pilot))


func _reset(hero, rec: Dictionary) -> void:
	_phase = "idle"
	rec.queued.clear()
	hero._to_base(rec)
	hero._process(20.0)


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	var hero = game.presentation.hero_assets
	var player = game.player
	player.fit_class(ClassDef.by_id("tally"))
	player.set_piece_phase = func() -> String: return _phase
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("Tally fitted with animator", rec.has("animator") and is_instance_valid(rec.get("animator"))):
		_done(game)
		return
	var wanted := Trigger.required_clips(true)
	var names: Array = Array(rec.animator.get_animation_list())
	names.erase("RESET")
	names.sort()
	wanted.sort()
	_t.eq("exactly the eighteen roster clips", names, wanted)
	var ends: Dictionary = Trigger.roster().end_frames.tally
	for clip in wanted:
		var present: bool = rec.animator.has_animation(clip)
		_t.check("shipped " + clip, present)
		var animation: Animation = rec.animator.get_animation(clip) if present else null
		_t.check("loop suffix " + clip, animation != null and (animation.loop_mode != Animation.LOOP_NONE) == String(clip).ends_with("_loop"))
		if ends.has(clip):
			_t.check("end frame " + clip, animation != null and absf(animation.length - (float(ends[clip]) - 1.0) / 30.0) < 0.001)
	if not Trigger.missing_clips(rec.animator, true).is_empty():
		_done(game)
		return
	_t.check("fitted base is idle_loop", _playing(rec, "idle_loop"))
	_t.eq("idle priority", int(rec.priority), -1)
	var events = game.events
	for clip in ["class_up", "cast_special", "cast_line", "ult_ready", "smash"]:
		_reset(hero, rec)
		match clip:
			"class_up": events.heft_class_changed.emit(2, 10.0)
			"cast_special": events.slot_cast.emit("special", "gather_plate", Vector3.ZERO)
			"cast_line": events.line_skill_fired.emit("link_clips", null, Vector3.ZERO, "enemy")
			"ult_ready": events.ultimate_ready.emit("plate_return")
			"smash": events.slammed.emit(Vector3.ZERO, 30.0, 1.0)
		_t.check("real bus plays " + clip, _playing(rec, clip))
		_rest_end(rec)
	_reset(hero, rec)
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("heft drop plays nothing", _playing(rec, "idle_loop"))
	events.slot_cast.emit("line", "link_clips", Vector3.ZERO)
	_t.check("line load plays nothing before the bite", _playing(rec, "idle_loop") and rec.reaction == "")
	events.slot_cast.emit("weapon", "balance_due", Vector3.ZERO)
	_t.check("weapon slot plays nothing", _playing(rec, "idle_loop"))
	_ultimate(hero, rec, events)
	_slam(game, hero, player, rec)
	_reset(hero, rec)
	events.slot_cast.emit("special", "gather_plate", Vector3.ZERO)
	events.ultimate_ready.emit("plate_return")
	_t.check("ready waits behind cast", _playing(rec, "cast_special"))
	_t.eq("ready queued", String(rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(rec)
	_t.check("ready plays after cast", _playing(rec, "ult_ready"))
	_rest_end(rec)
	_control(game, hero, player, rec)
	_reset(hero, rec)
	var body_velocity: Vector3 = player.body().linear_velocity
	var state_velocity: Vector3 = player.state.velocity
	events.line_skill_fired.emit("link_clips", null, Vector3.ZERO, "enemy")
	rec.animator.advance(0.1)
	_t.eq("clip leaves body velocity unchanged", player.body().linear_velocity, body_velocity)
	_t.eq("clip leaves state velocity unchanged", player.state.velocity, state_velocity)
	_rest_end(rec)
	_preview()
	_t.check("machinery vocabulary accepted", rec.mecha.skip_lines.filter(func(line): return String(line).begins_with("SKIP machinery")).is_empty())
	_done(game)


func _ultimate(hero, rec: Dictionary, events) -> void:
	_reset(hero, rec)
	_phase = "windup"
	events.ultimate_started.emit("plate_return", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five arguments play windup", _playing(rec, "ult_windup"))
	_phase = "flight"
	rec.animator.advance(0.34)
	_t.check("past 0.34 seconds base is ride", _playing(rec, "ult_ride_loop"))
	_t.eq("ride priority", int(rec.priority), 64)
	events.player_hit.emit(1.0, "test")
	_t.check("ride refuses hit", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("plate_return", Vector3.ZERO)
	_t.check("peak plays strike", _playing(rec, "ult_strike"))
	Trigger.finish(rec)
	_t.check("strike returns to ride in flight", _playing(rec, "ult_ride_loop"))
	_phase = "idle"
	events.ultimate_landed.emit("plate_return", Vector3.ZERO, 2, 40.0)
	_t.check("landing plays recover", _playing(rec, "ult_recover"))
	_rest_end(rec)
	_phase = "flight"
	events.ultimate_peak.emit("plate_return", Vector3.ZERO)
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("strike ending idle returns through recovery", _playing(rec, "ult_recover"))
	_rest_end(rec)
	_phase = "windup"
	events.ultimate_started.emit("plate_return", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_phase = "idle"
	events.ultimate_cancelled.emit("plate_return", "recall", true)
	_t.check("recall cuts windup with recovery", _playing(rec, "ult_recover") and int(rec.priority) == 72)
	_rest_end(rec)


func _slam(game, hero, player, rec: Dictionary) -> void:
	_reset(hero, rec)
	var at: Vector3 = player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", at + Vector3(2, 0, 0))
	player._on_slammed(at, 30.0, 1.0)
	_t.check("real hit slam plays smash", _playing(rec, "smash"))
	_t.eq("real hit slam queues drop_land", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("smash ends in drop_land", _playing(rec, "drop_land"))
	_rest_end(rec)
	enemy.free()
	_reset(hero, rec)
	player._on_slammed(at + Vector3(100, 0, 100), 30.0, 1.0)
	_t.check("real miss cuts smash with wince", _playing(rec, "wince"))
	_rest_end(rec)


func _control(game, hero, player, rec: Dictionary) -> void:
	_reset(hero, rec)
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/tally.json"))
	var contact: Dictionary = table.clips.cast_special.contact
	var control: Node3D = rec.pod.find_child(("Control." + String(contact.control)).replace(".", "_"), true, false)
	var before := control.position if control != null else Vector3.ZERO
	game.events.slot_cast.emit("special", "gather_plate", Vector3.ZERO)
	var sample_time := (float(contact.frame) - 1.0) / 30.0 + 0.05
	for i in ceili(sample_time / 0.005):
		hero._step_mecha(rec, player, 0.005)
	if control == null:
		var line := "SKIP control " + String(contact.control)
		print(line)
		_t.check("missing control counted", line in rec.mecha.skip_lines)
	else:
		_t.check("card tab past half throw at contact plus 0.05 s", before.y - control.position.y > 0.03)
	_rest_end(rec)


func _preview() -> void:
	var profile := FreshProfile.new()
	var card := Preview.new(ClassDef.by_id("tally"))
	card.ui_profile = profile
	root.add_child(card)
	card.open = 1.0
	card.track_focus()
	_t.eq("fresh profile focus starts unlock", card.last_focus_clip, "unlock")
	_t.check("card plays real unlock", card._animator.current_animation == "unlock")
	Trigger.finish({"animator": card._animator})
	_t.check("unlock returns to idle", card._animator.current_animation == "idle_loop")
	_t.check("unlock hand-off bones at rest", Trigger.bones_at_rest(card._pilot))
	card.open = 0.0
	card.track_focus()
	card.open = 1.0
	card.track_focus()
	_t.check("second focus plays only idle", card.last_focus_clip == "" and card._animator.current_animation == "idle_loop")
	_t.check("profile remembers Tally unlock", profile.seen("unlock_clip_tally"))
	card.free()


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.queue_free()
	quit(_t.verdict())
