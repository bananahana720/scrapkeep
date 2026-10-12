extends SceneTree

# PILOT-CLIPS 7.2 items 1..11, using the shipped clips and the real game bus.
# No synthetic clips: the seven-clip asset must fail before the rebuild.
# Expected checks: 103, including the count assertion. Missing clips stop safely.

const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const UIProfile := preload("res://src/ui/ui_profile.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")
const EXPECTED := 103
const CLASS_ID := "tarn"

var _t := T.new("pilot_clips_tarn_test")
var _phase := "idle"


func _initialize() -> void:
	_run.call_deferred()


func _playing(rec: Dictionary, clip: String) -> bool:
	return rec.animator.is_playing() and rec.animator.current_animation == clip


func _idle(rec: Dictionary, label: String) -> void:
	Trigger.finish(rec)
	_t.check(label + " returns to idle_loop", _playing(rec, "idle_loop"))
	_t.check(label + " hand-off bones at rest", Trigger.bones_at_rest(rec.pilot))


func _done(game) -> void:
	_t.eq("stated check count", _t.checks + 1, EXPECTED)
	game.free()
	quit(_t.verdict())


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	await process_frame
	var player = game.player
	var hero = game.presentation.hero_assets
	player.fit_class(ClassDef.by_id(CLASS_ID))
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("Tarn fitted with animator", is_instance_valid(rec.get("animator"))):
		_done(game)
		return
	var missing := Trigger.missing_clips(rec.animator, true)
	_t.eq("shipped GLB carries all 18 clips", missing, [])
	if not missing.is_empty():
		_done(game)
		return
	_t.eq("exactly 18 imported clips", rec.animator.get_animation_list().size(), 18)
	for clip in Trigger.required_clips(true):
		_t.eq(clip + " loop policy", rec.animator.get_animation(clip).loop_mode,
			Animation.LOOP_LINEAR if String(clip).ends_with("_loop") else Animation.LOOP_NONE)
	_t.check("fit starts idle_loop", _playing(rec, "idle_loop"))
	_t.eq("idle priority", int(rec.priority), -1)
	player.set_piece_phase = func() -> String: return _phase
	var events = game.events
	var body_before: Vector3 = player.body().linear_velocity
	var state_before: Vector3 = player.state.velocity
	_rows(hero, rec, events)
	_ultimate(hero, rec, events)
	_slam(game, hero, player, rec)
	_control(hero, rec, events)
	_kept(hero, rec, events)
	_t.check("body velocity unchanged by clips", player.body().linear_velocity.is_equal_approx(body_before))
	_t.check("state velocity unchanged by clips", player.state.velocity.is_equal_approx(state_before))
	var invalid: Array = rec.mecha.skip_lines.filter(func(line): return String(line).begins_with("SKIP machinery"))
	_t.eq("zero rejected machinery rows", invalid.size(), 0)
	_card()
	_done(game)


func _rows(hero, rec: Dictionary, events) -> void:
	events.slot_cast.emit("line", "claw_drag", Vector3.ZERO)
	_t.check("line slot load plays nothing", _playing(rec, "idle_loop") and rec.reaction == "")
	events.slot_cast.emit("special", "claw_clamp", Vector3.ZERO)
	_t.check("special cast plays cast_special", _playing(rec, "cast_special"))
	events.ultimate_ready.emit("redjaw_rend")
	_t.check("ready waits behind special", _playing(rec, "cast_special"))
	_t.eq("ready queued", String(rec.queued.get("clip", "")), "ult_ready")
	Trigger.finish(rec)
	_t.check("ready plays after special", _playing(rec, "ult_ready"))
	_idle(rec, "ready")
	hero._process(20.0)
	events.slot_cast.emit("special", "claw_clamp", Vector3.ZERO)
	_t.check("standalone special cast", _playing(rec, "cast_special"))
	_idle(rec, "special")
	hero._process(20.0)
	events.line_skill_fired.emit("claw_drag", null, Vector3.ZERO, "enemy")
	_t.check("line bite plays cast_line", _playing(rec, "cast_line"))
	_idle(rec, "line bite")
	hero._process(20.0)
	events.ultimate_ready.emit("redjaw_rend")
	_t.check("standalone ready cue", _playing(rec, "ult_ready"))
	_idle(rec, "standalone ready")
	hero._process(20.0)
	events.heft_class_changed.emit(2, 10.0)
	_t.check("class rise plays class_up", _playing(rec, "class_up"))
	_idle(rec, "class rise")
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("class drop plays nothing", _playing(rec, "idle_loop"))
	hero._process(20.0)


func _ultimate(hero, rec: Dictionary, events) -> void:
	_phase = "windup"
	events.ultimate_started.emit("redjaw_rend", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five-argument start plays windup", _playing(rec, "ult_windup"))
	_t.eq("windup priority", int(rec.priority), 70)
	_phase = "flight"
	rec.animator.advance(0.34)
	_t.check("past 0.34 s in flight plays ride", _playing(rec, "ult_ride_loop"))
	_t.eq("ride priority", int(rec.priority), 64)
	events.player_hit.emit(1.0, "test")
	_t.check("hit refused during ride", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("redjaw_rend", Vector3.ZERO)
	_t.check("peak plays strike", _playing(rec, "ult_strike"))
	Trigger.finish(rec)
	_t.check("strike returns to ride in flight", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("redjaw_rend", Vector3.ZERO)
	_t.check("second peak plays strike", _playing(rec, "ult_strike"))
	events.ultimate_landed.emit("redjaw_rend", Vector3.ZERO, 1, 10.0)
	_t.check("landing cuts strike with recover", _playing(rec, "ult_recover"))
	_t.eq("landing priority", int(rec.priority), 69)
	_phase = "idle"
	_idle(rec, "landing")
	_phase = "flight"
	events.ultimate_peak.emit("redjaw_rend", Vector3.ZERO)
	_t.check("third peak plays strike", _playing(rec, "ult_strike"))
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("strike ending outside flight hands to recover", _playing(rec, "ult_recover"))
	_idle(rec, "late strike")
	_phase = "windup"
	events.ultimate_started.emit("redjaw_rend", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("cancel begins in windup", _playing(rec, "ult_windup"))
	_phase = "idle"
	events.ultimate_cancelled.emit("redjaw_rend", "recall", true)
	_t.check("recall cuts windup with recover", _playing(rec, "ult_recover"))
	_t.eq("recall priority", int(rec.priority), 72)
	_idle(rec, "recall")
	hero._process(20.0)


func _slam(game, hero, player, rec: Dictionary) -> void:
	var far: Vector3 = player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	game.events.slammed.emit(far, 30.0, 1.0)
	_t.check("slam starts smash", _playing(rec, "smash"))
	player._on_slammed(far, 30.0, 1.0)
	_t.check("hit leaves smash playing", _playing(rec, "smash"))
	_t.eq("hit queues drop_land", String(rec.queued.get("clip", "")), "drop_land")
	Trigger.finish(rec)
	_t.check("drop_land follows smash", _playing(rec, "drop_land"))
	_idle(rec, "drop")
	enemy.free()
	hero._process(20.0)
	game.events.slammed.emit(far, 30.0, 1.0)
	player._on_slammed(far, 30.0, 1.0)
	_t.check("miss cuts smash with wince", _playing(rec, "wince"))
	_idle(rec, "miss")
	hero._process(20.0)


func _control(hero, rec: Dictionary, events) -> void:
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://src/presentation/clips/tarn.json"))
	var contact: Dictionary = table.clips.cast_special.contact
	var name := "Control." + String(contact.control)
	var node: Node3D = rec.pod.find_child(name.replace(".", "_"), true, false)
	var before := node.rotation_degrees.x if node != null else 0.0
	events.slot_cast.emit("special", "claw_clamp", Vector3.ZERO)
	_t.check("control probe starts special", _playing(rec, "cast_special"))
	var duration := (float(contact.frame) - 1.0) / 30.0 + 0.05
	for i in roundi(duration / 0.005):
		rec.mecha.step(0.005, {})
	if node == null:
		_t.check("missing cast control counted", ("SKIP control " + String(contact.control)) in rec.mecha.skip_lines)
	else:
		_t.check("control exceeds half throw at contact plus 0.05 s", node.rotation_degrees.x - before > Mecha.LEVER_DEG * 0.5)
	_idle(rec, "control probe")


func _card() -> void:
	var dir := "user://pilot-clips-tarn-profile"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.remove_absolute(dir.path_join(UIProfile.FILE))
	var profile := UIProfile.new(dir)
	var preview := ClassPreview.new(ClassDef.by_id(CLASS_ID))
	preview.ui_profile = profile
	preview.open = 1.0
	preview.track_focus()
	_t.eq("fresh profile first focus unlock", preview.last_focus_clip, "unlock")
	_t.eq("card animator plays unlock", String(preview._animator.current_animation), "unlock")
	preview._animator.advance(preview._animator.current_animation_length + 0.01)
	_t.eq("card unlock returns to idle", String(preview._animator.current_animation), "idle_loop")
	_t.check("card unlock hand-off bones at rest", Trigger.bones_at_rest(preview._pilot))
	_t.check("profile remembers ceremony", profile.seen("unlock_clip_tarn"))
	preview.open = 0.0
	preview.track_focus()
	preview.open = 1.0
	preview.track_focus()
	_t.eq("second focus skips ceremony", preview.last_focus_clip, "")
	_t.eq("second focus keeps idle", String(preview._animator.current_animation), "idle_loop")
	preview.free()
	DirAccess.remove_absolute(dir.path_join(UIProfile.FILE))


func _kept(hero, rec: Dictionary, events) -> void:
	for clip in ["phew", "brace", "heave", "big_cheer", "slump"]:
		hero._process(20.0)
		match clip:
			"phew": events.near_miss.emit("chaser", Vector3.ZERO)
			"brace": events.harpoon_bit.emit(null, Vector3.ZERO)
			"heave": events.harpoon_smashed.emit(null, Vector3.ZERO, 30.0)
			"big_cheer": events.boss_defeated.emit()
			"slump": events.player_died.emit()
		_t.check("kept bus reaction " + clip, _playing(rec, clip))
		_idle(rec, clip)
