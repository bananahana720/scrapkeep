extends SceneTree

# PILOT-CLIPS 7.2 items 1 to 11, using shipped clips and the real game bus.
# No synthetic clips: this test must fail on the seven-clip baseline.
const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const UIProfile := preload("res://src/ui/ui_profile.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")

const CLASS_ID := "demolitions_caster"
const EXPECTED := 81
const TABLE_PATH := "res://src/presentation/clips/kest.json"

var _t := T.new("pilot_clips_kest_test")
var _phase := "idle"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(2)
	await process_frame
	var hero = game.presentation.hero_assets
	var player = game.player
	player.fit_class(ClassDef.by_id(CLASS_ID))
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("Kest is fitted with an animator", is_instance_valid(rec.get("animator"))):
		_done(game)
		return
	for clip in Trigger.required_clips(true):
		_t.check("shipped Kest carries " + String(clip), rec.animator.has_animation(clip))
	if not Trigger.missing_clips(rec.animator, true).is_empty():
		_done(game)
		return
	player.set_piece_phase = func() -> String: return _phase
	_t.check("fit starts idle_loop", _playing(rec, "idle_loop"))
	_t.eq("idle priority", int(rec.priority), -1)
	_t.eq("idle loops", rec.animator.get_animation("idle_loop").loop_mode, Animation.LOOP_LINEAR)
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	var rows: Array = table.get("machinery", [])
	_t.check("machinery rows are present", not rows.is_empty())
	var valid := true
	for row in rows:
		valid = valid and row.fact in Mecha.FACTS and row.motion in Mecha.MOTIONS
	_t.check("every machinery row uses the runtime vocabulary", valid)
	var bad: Array = rec.mecha.skip_lines.filter(func(line): return String(line).begins_with("SKIP machinery"))
	_t.eq("zero rejected machinery rows", bad, [])
	var velocity := Vector3(13, -2, 7)
	var state_velocity := Vector3(12, -1, 8)
	player.body().linear_velocity = velocity
	player.state.velocity = state_velocity
	var events = game.events
	for clip in ["class_up", "cast_special", "cast_line", "ult_ready", "smash"]:
		hero._process(20.0)
		match clip:
			"class_up": events.heft_class_changed.emit(2, 10.0)
			"cast_special": events.slot_cast.emit("special", "detonation_line", Vector3.ZERO)
			"cast_line": events.line_skill_fired.emit("cable_charge", null, Vector3.ZERO, "body")
			"ult_ready": events.ultimate_ready.emit("windhover")
			"smash": events.slammed.emit(Vector3.ZERO, 30.0, 1.0)
		_t.check("real signal plays " + clip, _playing(rec, clip))
		_to_idle(rec, clip)
	hero._process(20.0)
	events.slot_cast.emit("line", "cable_charge", Vector3.ZERO)
	_t.check("line selection plays nothing before the bite", _playing(rec, "idle_loop"))
	events.slot_cast.emit("weapon", "sticky_charge", Vector3.ZERO)
	_t.check("weapon slot is filtered out", _playing(rec, "idle_loop"))
	_ultimate(hero, rec, events)
	_slam(game, hero, player, rec)
	hero._process(20.0)
	events.slot_cast.emit("special", "detonation_line", Vector3.ZERO)
	events.ultimate_ready.emit("windhover")
	_t.check("ready waits behind the cast", _playing(rec, "cast_special"))
	_t.eq("ready queued", String(rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(rec)
	_t.check("ready plays after the cast", _playing(rec, "ult_ready"))
	_to_idle(rec, "queued ready")
	hero._process(20.0)
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("class drop plays nothing", _playing(rec, "idle_loop"))
	_controls(hero, rec, events, table)
	_t.eq("clips preserve body velocity", player.body().linear_velocity, velocity)
	_t.eq("clips preserve state velocity", player.state.velocity, state_velocity)
	_preview()
	_done(game)


func _playing(rec: Dictionary, clip: String) -> bool:
	return rec.animator.is_playing() and rec.animator.current_animation == clip


func _to_idle(rec: Dictionary, label: String) -> void:
	Trigger.finish(rec)
	_t.check(label + " hands back to idle_loop", _playing(rec, "idle_loop"))
	_t.check(label + " hand-off frame is at rest", Trigger.bones_at_rest(rec.pilot))


func _ultimate(hero, rec: Dictionary, events) -> void:
	_phase = "windup"
	events.ultimate_started.emit("windhover", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five-argument start plays wind-up", _playing(rec, "ult_windup"))
	_phase = "flight"
	rec.animator.advance(0.34)
	_t.check("past 0.34 seconds in flight plays ride", _playing(rec, "ult_ride_loop"))
	_t.eq("ride loops", rec.animator.get_animation("ult_ride_loop").loop_mode, Animation.LOOP_LINEAR)
	_t.eq("ride priority", int(rec.priority), 64)
	events.player_hit.emit(1.0, "test")
	_t.check("hit cannot break the ride", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("windhover", Vector3.ZERO)
	_t.check("peak plays strike", _playing(rec, "ult_strike"))
	Trigger.finish(rec)
	_t.check("strike returns to ride in flight", _playing(rec, "ult_ride_loop"))
	_phase = "idle"
	events.ultimate_landed.emit("windhover", Vector3.ZERO, 2, 40.0)
	_t.check("landing plays recovery", _playing(rec, "ult_recover"))
	_to_idle(rec, "landing recovery")
	_phase = "flight"
	events.ultimate_peak.emit("windhover", Vector3.ZERO)
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("strike ending after flight plays recovery", _playing(rec, "ult_recover"))
	Trigger.finish(rec)
	_t.check("late recovery returns to idle", _playing(rec, "idle_loop"))
	hero._process(20.0)
	_phase = "windup"
	events.ultimate_started.emit("windhover", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_phase = "idle"
	events.ultimate_cancelled.emit("windhover", "recall", true)
	_t.check("recall cuts the wind-up with recovery", _playing(rec, "ult_recover"))
	Trigger.finish(rec)
	_t.check("cancelled ultimate returns to idle", _playing(rec, "idle_loop"))


func _slam(game, hero, player, rec: Dictionary) -> void:
	hero._process(20.0)
	var far: Vector3 = player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	player._on_slammed(far, 30.0, 1.0)
	_t.check("real hit slam starts smash", _playing(rec, "smash"))
	_t.eq("real hit queues drop_land", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("real hit plays drop_land after smash", _playing(rec, "drop_land"))
	Trigger.finish(rec)
	_t.check("real hit ends on idle", _playing(rec, "idle_loop"))
	enemy.free()
	hero._process(20.0)
	player._on_slammed(far + Vector3(100, 0, 0), 30.0, 1.0)
	_t.check("real miss cuts smash with wince", _playing(rec, "wince"))
	Trigger.finish(rec)
	_t.check("real miss ends on idle", _playing(rec, "idle_loop"))


func _controls(hero, rec: Dictionary, events, table: Dictionary) -> void:
	for clip in ["cast_special", "cast_line"]:
		hero._process(20.0)
		var contact: Dictionary = table.clips[clip].contact
		var control := String(contact.control)
		var node: Node3D = rec.mecha._node("Control." + control)
		_t.eq(clip + " names its bank control", control, "FusePlunger" if clip == "cast_special" else "ChargeKey")
		var before := node.position if node != null else Vector3.ZERO
		if clip == "cast_special":
			events.slot_cast.emit("special", "detonation_line", Vector3.ZERO)
		else:
			events.line_skill_fired.emit("cable_charge", null, Vector3.ZERO, "body")
		var seconds := (float(contact.frame) - 1.0) / 30.0 + 0.05
		for step in ceili(seconds / 0.005):
			hero._process(0.005)
		if node == null:
			_t.check(clip + " missing control is counted", rec.mecha.skip_lines.has("SKIP control " + control))
		else:
			_t.check(clip + " control moved past half throw", before.y - node.position.y > Mecha.PLUNGER_M * 0.5)
		Trigger.finish(rec)


func _preview() -> void:
	var dir := "user://kest-clip-fresh-profile"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(dir.path_join(UIProfile.FILE))
	var profile := UIProfile.new(dir)
	var preview := ClassPreview.new(ClassDef.by_id(CLASS_ID))
	preview.ui_profile = profile
	root.add_child(preview)
	preview.open = 1.0
	preview.track_focus()
	_t.eq("fresh profile first focus plays unlock", preview.last_focus_clip, "unlock")
	_t.check("profile records unlock as seen", profile.seen("unlock_clip_" + CLASS_ID))
	preview._animator.advance(preview._animator.current_animation_length + 0.01)
	_t.eq("unlock returns to idle", preview._animator.current_animation, "idle_loop")
	_t.check("unlock ends at seated rest", Trigger.bones_at_rest(preview._pilot))
	preview.open = 0.0
	preview.track_focus()
	preview.open = 1.0
	preview.track_focus()
	_t.eq("second focus does not replay unlock", preview.last_focus_clip, "")
	_t.eq("second focus keeps idle", preview._animator.current_animation, "idle_loop")
	preview.free()
	DirAccess.remove_absolute(dir.path_join(UIProfile.FILE))


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.queue_free()
	quit(_t.verdict())
