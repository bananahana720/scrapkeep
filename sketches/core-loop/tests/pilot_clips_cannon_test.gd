extends SceneTree

# PILOT-CLIPS 7.2 items 1 through 11 on the shipped Cannon GLB and real game bus.
# No synthetic animations. EXPECTED includes the final count assertion.
const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Preview := preload("res://src/ui/class_preview.gd")
const Profile := preload("res://src/ui/ui_profile.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")
const CLASS_ID := "remembered_cannon"
const EXPECTED := 118
var _t := T.new("pilot_clips_cannon_test")
var _phase := "idle"
var _hero
var _player
var _events
var _rec: Dictionary


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
	_hero = game.presentation.hero_assets
	_player = game.player
	_events = game.events
	_player.fit_class(ClassDef.by_id(CLASS_ID))
	_hero._process(0.0)
	_rec = _hero.shell_of(_player)
	if not _t.check("Cannon fits with an animator", is_instance_valid(_rec.get("animator"))):
		_done(game)
		return
	_player.set_piece_phase = func() -> String: return _phase
	var animator: AnimationPlayer = _rec.animator
	var clips := Array(animator.get_animation_list())
	clips.sort()
	var want := Trigger.required_clips(true)
	want.sort()
	_t.eq("exact eighteen shipped clips", clips, want)
	for clip in want:
		var animation := animator.get_animation(clip) if animator.has_animation(clip) else null
		_t.check("loop mode " + clip, animation != null and (animation.loop_mode != Animation.LOOP_NONE) == String(clip).ends_with("_loop"))
	_t.check("fitted base is idle_loop", _playing("idle_loop"))
	_t.eq("idle priority", int(_rec.priority), -1)
	_reactions()
	_ultimate()
	_slam(game)
	_queue()
	_control()
	_preview()
	var rows: Array = _hero._pilot_table(CLASS_ID).get("machinery", [])
	_t.check("machinery rows use runtime vocabulary", not rows.is_empty() and rows.all(func(row): return row.fact in Mecha.FACTS and row.motion in Mecha.MOTIONS))
	var invalid := Array(_rec.mecha.skip_lines).filter(func(line): return String(line).begins_with("S" + "KIP machinery"))
	_t.eq("no rejected machinery rows", invalid.size(), 0)
	_done(game)


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.free()
	quit(_t.verdict())


func _playing(clip: String) -> bool:
	return _rec.animator.is_playing() and _rec.animator.current_animation == clip


func _reset() -> void:
	_phase = "idle"
	_rec.queued = {}
	_hero._process(20.0)
	_hero._to_base(_rec)
	_rec.animator.advance(0.0)


func _finish_idle(label: String) -> void:
	Trigger.finish(_rec)
	_rec.animator.advance(0.0)
	_t.check(label + " returns to idle_loop", _playing("idle_loop"))
	_t.check(label + " hands off at rest", Trigger.bones_at_rest(_rec.pilot))


func _shot(event: String, args: Array, clip: String) -> void:
	_reset()
	var body_before: Vector3 = _player.body().linear_velocity
	var state_before: Vector3 = _player.state.velocity
	_events.emit_signal.callv([event] + args)
	_t.check(event + " plays " + clip, _playing(clip))
	_finish_idle(clip)
	_t.check(clip + " preserves both velocities", _player.body().linear_velocity == body_before and _player.state.velocity == state_before)


func _reactions() -> void:
	_shot("drop_landed", [1], "drop_land")
	_shot("boss_defeated", [], "big_cheer")
	_shot("player_hit", [1.0, "test"], "wince")
	_shot("player_died", [], "slump")
	_shot("near_miss", ["chaser", Vector3.ZERO], "phew")
	_shot("harpoon_bit", [null, Vector3.ZERO], "brace")
	_shot("harpoon_smashed", [null, Vector3.ZERO, 30.0], "heave")
	_shot("heft_class_changed", [2, 10.0], "class_up")
	_shot("slot_cast", ["special", "cannon_plate", Vector3.ZERO], "cast_special")
	_shot("line_skill_fired", ["lane_charge", null, Vector3.ZERO, "enemy"], "cast_line")
	_shot("ultimate_ready", ["fire_mission"], "ult_ready")
	_reset()
	_events.slot_cast.emit("line", "lane_charge", Vector3.ZERO)
	_t.check("loading line slot plays nothing", _playing("idle_loop") and _rec.reaction == "")
	_events.slot_cast.emit("weapon", "lane_call", Vector3.ZERO)
	_t.check("weapon slot plays nothing", _playing("idle_loop") and _rec.reaction == "")
	_events.heft_class_dropped.emit(1, 5.0)
	_t.check("heft drop plays nothing", _playing("idle_loop") and _rec.reaction == "")


func _start_ultimate() -> void:
	_phase = "windup"
	_events.ultimate_started.emit("fire_mission", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)


func _ultimate() -> void:
	_reset()
	_start_ultimate()
	_t.check("five-argument start plays windup", _playing("ult_windup"))
	_t.eq("windup priority", int(_rec.priority), 70)
	_phase = "flight"
	_rec.animator.advance(0.34)
	_t.check("past 0.34 seconds the base is ride", _playing("ult_ride_loop"))
	_t.eq("ride priority", int(_rec.priority), 64)
	_events.player_hit.emit(1.0, "test")
	_t.check("a hit cannot break the ride", _playing("ult_ride_loop"))
	_events.ultimate_peak.emit("fire_mission", Vector3.ZERO)
	_t.check("apex plays strike", _playing("ult_strike"))
	Trigger.finish(_rec)
	_t.check("strike in flight returns to ride", _playing("ult_ride_loop"))
	_events.ultimate_landed.emit("fire_mission", Vector3.ZERO, 2, 40.0)
	_t.check("landing plays recovery", _playing("ult_recover"))
	_phase = "idle"
	_finish_idle("landing recovery")
	_reset()
	_phase = "flight"
	_events.ultimate_peak.emit("fire_mission", Vector3.ZERO)
	_t.check("late strike starts", _playing("ult_strike"))
	_phase = "idle"
	Trigger.finish(_rec)
	_t.check("strike ending after flight plays recovery", _playing("ult_recover"))
	_finish_idle("late recovery")
	_reset()
	_start_ultimate()
	_t.check("recall starts during windup", _playing("ult_windup"))
	_phase = "idle"
	_events.ultimate_cancelled.emit("fire_mission", "recall", true)
	_t.check("recall cuts windup with recovery", _playing("ult_recover"))
	_t.eq("recall recovery priority", int(_rec.priority), 72)
	_finish_idle("recall recovery")


func _slam(game) -> void:
	_reset()
	var far: Vector3 = _player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	_events.slammed.emit(far, 30.0, 1.0)
	_t.check("hit slam starts smash", _playing("smash"))
	_player._on_slammed(far, 30.0, 1.0)
	_t.check("real hit resolution leaves smash playing", _playing("smash"))
	_t.eq("hit queues drop_land", String(_rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(_rec)
	_t.check("smash finishes into drop_land", _playing("drop_land"))
	_finish_idle("hit slam")
	enemy.free()
	_reset()
	_events.slammed.emit(far, 30.0, 1.0)
	_player._on_slammed(far, 30.0, 1.0)
	_t.check("real miss cuts smash with wince", _playing("wince"))
	_t.check("miss queues nothing", _rec.queued.is_empty())
	_finish_idle("miss slam")


func _queue() -> void:
	_reset()
	_events.slot_cast.emit("special", "cannon_plate", Vector3.ZERO)
	_events.ultimate_ready.emit("fire_mission")
	_t.check("ready waits behind special", _playing("cast_special"))
	_t.eq("ready occupies queue", String(_rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(_rec)
	_t.check("cast end plays queued ready", _playing("ult_ready"))
	_t.check("queue clears after ready plays", _rec.queued.is_empty())
	_finish_idle("queued ready")


func _control() -> void:
	_reset()
	var control := _rec.pod.find_child("Control_PlateCrank", true, false) as Node3D
	var table: Dictionary = _hero._pilot_table(CLASS_ID)
	var contact: Dictionary = table.get("clips", {}).get("cast_special", {}).get("contact", {})
	_t.check("special has a contact frame", contact.has("frame") and contact.get("control", "") == "PlateCrank")
	_events.slot_cast.emit("special", "cannon_plate", Vector3.ZERO)
	if control == null:
		print("SKIP control PlateCrank")
		_t.check("absent control is counted", _rec.mecha.skip_lines.has("SKIP control PlateCrank"))
	else:
		var before := control.rotation_degrees.x
		var seconds := (float(contact.get("frame", 1)) - 1.0) / 30.0 + 0.05
		for i in ceili(seconds / 0.005):
			_hero._step_mecha(_rec, _player, 0.005)
		_t.check("crank past half throw at contact plus 0.05 s", absf(control.rotation_degrees.x - before) > Mecha.CRANK_DEG * 0.5)
	_finish_idle("control cast")


func _preview() -> void:
	var dir := "user://pilot-clips-cannon-fresh"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join(Profile.FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var profile := Profile.new(dir)
	var card := Preview.new(ClassDef.by_id(CLASS_ID))
	card.ui_profile = profile
	root.add_child(card)
	card.set_process(false)
	_t.eq("first fresh-profile focus plays unlock", card.focus_clip(), "unlock")
	_t.check("card animator plays unlock", card._animator != null and card._animator.current_animation == "unlock")
	_t.check("first focus persists seen id", profile.seen(Preview.UNLOCK_SEEN + CLASS_ID))
	Trigger.finish({"animator": card._animator})
	_t.check("unlock ends in card idle", card._animator != null and card._animator.current_animation == "idle_loop" and card._animator.is_playing())
	_t.check("unlock hand-off rests bones", Trigger.bones_at_rest(card._pilot))
	_t.eq("second focus plays no unlock", card.focus_clip(), "")
	_t.check("second focus keeps idle playing", card._animator != null and card._animator.current_animation == "idle_loop" and card._animator.is_playing())
	card.free()
	DirAccess.remove_absolute(path)
