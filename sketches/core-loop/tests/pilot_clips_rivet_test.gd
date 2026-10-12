extends SceneTree

# PILOT-CLIPS 7.2 items 1 to 11, using the shipped clips and the real game bus.
# No synthetic clips: the seven-clip baseline must fail before a rebuild.
const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Preview := preload("res://src/ui/class_preview.gd")
const Profile := preload("res://src/ui/ui_profile.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const T := preload("res://tests/support/t.gd")
const CLASS_ID := "runner_gunner"
const EXPECTED := 78

var _t := T.new("pilot_clips_rivet_test")
var _phase := "idle"
var _control_skips := 0


func _initialize() -> void:
	_run.call_deferred()


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
	player.fit_class(ClassDef.by_id(CLASS_ID))
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("Rivet has a fitted animator", is_instance_valid(rec.get("animator"))):
		_done(game)
		return
	var missing := Trigger.missing_clips(rec.animator, true)
	_t.eq("shipped Rivet has all 18 roster clips", missing, [])
	if not missing.is_empty():
		_done(game)
		return
	player.set_piece_phase = func() -> String: return _phase
	_t.check("fit starts idle_loop", _playing(rec, "idle_loop"))
	_t.eq("idle priority", int(rec.priority), -1)
	_t.eq("idle loops", rec.animator.get_animation("idle_loop").loop_mode, Animation.LOOP_LINEAR)
	_rows(hero, rec, game.events, player)
	_ultimate(hero, rec, game.events)
	_slam(game, hero, rec)
	_ready(hero, rec, game.events)
	_card()
	var machinery_skips := 0
	for line in rec.mecha.skip_lines:
		if String(line).begins_with("SKIP machinery"):
			machinery_skips += 1
	_t.eq("no machinery vocabulary skips", machinery_skips, 0)
	print("RIVET_CONTROL_SKIPS: %d" % _control_skips)
	_done(game)


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.free()
	quit(_t.verdict())


func _playing(rec: Dictionary, clip: String) -> bool:
	return rec.animator.is_playing() and rec.animator.current_animation == clip


func _reset(hero, rec: Dictionary) -> void:
	hero._process(20.0)
	hero._to_base(rec)


func _idle_end(rec: Dictionary, label: String) -> void:
	Trigger.finish(rec)
	_t.check(label + " returns to idle", _playing(rec, "idle_loop") and rec.reaction == "")
	_t.check(label + " hands off at bone rest", Trigger.bones_at_rest(rec.pilot))


func _rows(hero, rec: Dictionary, events, player) -> void:
	var body_before: Vector3 = player.body().linear_velocity
	var state_before: Vector3 = player.state.velocity
	events.slot_cast.emit("line", "line_drive", Vector3.ZERO)
	_t.check("slot_cast line is filtered out", _playing(rec, "idle_loop") and rec.reaction == "")
	events.slot_cast.emit("weapon", "rapid_laser", Vector3.ZERO)
	_t.check("slot_cast weapon is filtered out", _playing(rec, "idle_loop") and rec.reaction == "")
	events.slot_cast.emit("special", "overdrive_blast", Vector3.ZERO)
	_t.check("slot_cast special plays cast_special", _playing(rec, "cast_special"))
	var contact: Dictionary = hero._contact_of(rec, "cast_special")
	_t.eq("special contacts the lever", contact.control, "Lever")
	var lever = rec.pod.find_child("Control_Lever", true, false)
	if lever == null:
		lever = rec.pod.find_child("Control.Lever", true, false)
	if lever == null:
		_control_skips += 1
		_t.check("absent lever is recorded by the driver", "SKIP control Lever" in rec.mecha.skip_lines)
	else:
		var before: float = lever.rotation_degrees.x
		for step in ceili((float(contact.seconds) + 0.05) / 0.005):
			hero._step_mecha(rec, player, 0.005)
		_t.check("lever passes half throw after contact plus 0.05 s", absf(lever.rotation_degrees.x - before) > 17.5)
	_idle_end(rec, "cast_special")
	_reset(hero, rec)
	events.line_skill_fired.emit("line_drive", null, Vector3.ZERO, "enemy")
	_t.check("line bite plays cast_line", _playing(rec, "cast_line"))
	_idle_end(rec, "cast_line")
	_reset(hero, rec)
	events.heft_class_changed.emit(2, 10.0)
	_t.check("class rise plays class_up", _playing(rec, "class_up"))
	_idle_end(rec, "class_up")
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("class drop plays nothing", _playing(rec, "idle_loop"))
	_reset(hero, rec)
	events.ultimate_ready.emit("foundry_cutter")
	_t.check("ultimate_ready plays ult_ready", _playing(rec, "ult_ready"))
	_idle_end(rec, "ult_ready")
	for clip in Trigger.roster().kept:
		_reset(hero, rec)
		rec.animator.play(clip, 0.0)
		rec.animator.advance(0.0)
		_idle_end(rec, clip)
	_t.eq("clips preserve body velocity", player.body().linear_velocity, body_before)
	_t.eq("clips preserve state velocity", player.state.velocity, state_before)
	_reset(hero, rec)


func _ultimate(hero, rec: Dictionary, events) -> void:
	_phase = "windup"
	events.ultimate_started.emit("foundry_cutter", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five arguments start windup", _playing(rec, "ult_windup"))
	_phase = "flight"
	rec.animator.advance(0.34)
	_t.check("past 0.34 s flight holds ride", _playing(rec, "ult_ride_loop"))
	_t.eq("ride priority", int(rec.priority), 64)
	_t.eq("ride loops", rec.animator.get_animation("ult_ride_loop").loop_mode, Animation.LOOP_LINEAR)
	events.player_hit.emit(1.0, "test")
	_t.check("ride refuses player_hit", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("foundry_cutter", Vector3.ZERO)
	_t.check("peak plays strike", _playing(rec, "ult_strike"))
	Trigger.finish(rec)
	_t.check("strike returns to ride in flight", _playing(rec, "ult_ride_loop"))
	events.ultimate_landed.emit("foundry_cutter", Vector3.ZERO, 2, 40.0)
	_t.check("landing plays recovery", _playing(rec, "ult_recover"))
	_phase = "idle"
	_idle_end(rec, "ult_recover")
	_phase = "flight"
	events.ultimate_peak.emit("foundry_cutter", Vector3.ZERO)
	_t.check("second strike starts", _playing(rec, "ult_strike"))
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("strike ending after flight routes to recovery", _playing(rec, "ult_recover"))
	_idle_end(rec, "late ult_recover")
	_phase = "windup"
	events.ultimate_started.emit("foundry_cutter", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("cancel case starts windup", _playing(rec, "ult_windup"))
	_phase = "idle"
	events.ultimate_cancelled.emit("foundry_cutter", "recall", true)
	_t.check("recall during windup plays recovery", _playing(rec, "ult_recover"))
	_idle_end(rec, "cancel recovery")
	_reset(hero, rec)


func _slam(game, hero, rec: Dictionary) -> void:
	var far: Vector3 = game.player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	game.player._on_slammed(far, 30.0, 1.0)
	_t.check("real slam hit plays smash", _playing(rec, "smash"))
	_t.eq("real slam queues drop_land", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("smash hit hands off to drop_land", _playing(rec, "drop_land"))
	_idle_end(rec, "slam payoff")
	enemy.free()
	_reset(hero, rec)
	game.player._on_slammed(far + Vector3(500, 0, 500), 30.0, 1.0)
	_t.check("real slam miss cuts smash with wince", _playing(rec, "wince"))
	_idle_end(rec, "slam miss")
	_reset(hero, rec)


func _ready(hero, rec: Dictionary, events) -> void:
	events.slot_cast.emit("special", "overdrive_blast", Vector3.ZERO)
	events.ultimate_ready.emit("foundry_cutter")
	_t.check("ready waits behind special", _playing(rec, "cast_special"))
	_t.eq("ready occupies queue", String(rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(rec)
	_t.check("ready plays after cast", _playing(rec, "ult_ready"))
	_idle_end(rec, "queued ready")
	_reset(hero, rec)


func _card() -> void:
	var dir := "user://rivet-clip-test"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(dir.path_join(Profile.FILE))
	var profile := Profile.new(dir)
	var card := Preview.new(ClassDef.by_id(CLASS_ID))
	card.ui_profile = profile
	root.add_child(card)
	card.open = 1.0
	card.track_focus()
	_t.eq("fresh profile first focus selects unlock", card.last_focus_clip, "unlock")
	_t.eq("card animator plays unlock", card._animator.current_animation, "unlock")
	_t.check("profile records unlock once", profile.seen("unlock_clip_" + CLASS_ID))
	card._animator.advance(card._animator.current_animation_length + 0.01)
	_t.eq("unlock ends on card idle", card._animator.current_animation, "idle_loop")
	_t.check("card unlock hands off at rest", Trigger.bones_at_rest(card._pilot))
	card.open = 0.0
	card.track_focus()
	card.open = 1.0
	card.track_focus()
	_t.eq("second focus selects no unlock", card.last_focus_clip, "")
	_t.eq("second focus keeps idle", card._animator.current_animation, "idle_loop")
	card.free()
	DirAccess.remove_absolute(profile.path)
	DirAccess.remove_absolute(dir)
