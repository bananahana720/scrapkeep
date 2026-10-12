extends SceneTree

# PILOT-CLIPS 7.2 items 1-11, using delivered clips and the real game bus.
# 57 asset checks, 3 base, 33 rest shots, 2 filters, 17 ultimate, 8 slam,
# 2026-10-12: explicit story targets have no named physical contact. Add two checks
# for declared contact or the documented 40-percent control-throw fallback.
# 5 ready queue, 6 controls, 1 machinery, 2 velocity, 5 preview, 1 count = 140.
const EXPECTED := 140
const CLASS_ID := "pylon_engineer"
const Game := preload("res://src/game.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")
const Mecha := preload("res://src/presentation/mecha_motion.gd")
const Preview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")

class FreshProfile extends RefCounted:
	var seen_ids := []
	func seen(id: String) -> bool:
		return id in seen_ids
	func mark_seen(id: String) -> void:
		seen_ids.append(id)

var _t := T.new("pilot_clips_sable_test")
var _phase := "idle"

func _initialize() -> void:
	_run.call_deferred()

func _playing(rec: Dictionary, clip: String) -> bool:
	return rec.animator.is_playing() and rec.animator.current_animation == clip

func _handoff(rec: Dictionary, label: String) -> void:
	Trigger.finish(rec)
	_t.check(label + " returns to idle_loop", _playing(rec, "idle_loop"))
	_t.check(label + " hand-off bones are at rest", Trigger.bones_at_rest(rec.pilot))

func _rest_shot(hero, rec: Dictionary, emit: Callable, clip: String) -> void:
	hero._process(20.0)
	emit.call()
	_t.check(clip + " real signal plays the clip", _playing(rec, clip))
	_handoff(rec, clip)

func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(1)
	await process_frame
	var hero = game.presentation.hero_assets
	var player = game.player
	player.fit_class(ClassDef.by_id(CLASS_ID))
	hero._process(0.0)
	var rec: Dictionary = hero.shell_of(player)
	if not _t.check("Sable fits an animator", rec.get("animator") != null):
		_done(game)
		return
	player.set_piece_phase = func() -> String: return _phase
	var animator: AnimationPlayer = rec.animator
	var roster := Trigger.roster()
	_t.check("Sable pose table exists", Trigger.has_table("sable"))
	var names: Array = Array(roster.kept) + Array(roster.new)
	_t.eq("delivered animation count", animator.get_animation_list().size(), 18)
	for clip in names:
		var animation := animator.get_animation(clip) if animator.has_animation(clip) else null
		_t.check(clip + " exists", animation != null)
		_t.check(clip + " loop kind matches roster", animation != null and (animation.loop_mode != Animation.LOOP_NONE) == String(clip).ends_with("_loop"))
		var end: int = roster.end_frames.sable.get(clip, 0)
		_t.check(clip + " duration matches contract", animation != null and (end == 0 or absf(animation.length - (end - 1) / 30.0) < 1.0 / 60.0))
	_t.check("fit starts idle_loop", _playing(rec, "idle_loop"))
	_t.eq("idle base priority", int(rec.priority), -1)
	_t.check("idle base loops", animator.has_animation("idle_loop") and animator.get_animation("idle_loop").loop_mode == Animation.LOOP_LINEAR)
	var body_before := Vector3(13, -2, 7)
	var state_before := Vector3(12, -1, 8)
	player.body().linear_velocity = body_before
	player.state.velocity = state_before
	var events = game.events
	_rest_shot(hero, rec, func(): events.heft_class_changed.emit(2, 10.0), "class_up")
	_rest_shot(hero, rec, func(): events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO), "cast_special")
	_rest_shot(hero, rec, func(): events.line_skill_fired.emit("bank_shot", null, Vector3.ZERO, "enemy"), "cast_line")
	_rest_shot(hero, rec, func(): events.ultimate_ready.emit("cable_run"), "ult_ready")
	_rest_shot(hero, rec, func(): events.drop_landed.emit(1), "drop_land")
	_rest_shot(hero, rec, func(): events.evolution_fired.emit("wrecking_ball"), "big_cheer")
	_rest_shot(hero, rec, func(): events.player_hit.emit(1.0, "test"), "wince")
	_rest_shot(hero, rec, func(): events.player_died.emit(), "slump")
	_rest_shot(hero, rec, func(): events.near_miss.emit("chaser", Vector3.ZERO), "phew")
	_rest_shot(hero, rec, func(): events.harpoon_bit.emit(null, Vector3.ZERO), "brace")
	_rest_shot(hero, rec, func(): events.harpoon_smashed.emit(null, Vector3.ZERO, 30.0), "heave")
	events.slot_cast.emit("line", "bank_shot", Vector3.ZERO)
	_t.check("line slot loads without playing a cast", _playing(rec, "idle_loop") and rec.reaction == "")
	events.heft_class_dropped.emit(1, 5.0)
	_t.check("heft class drop plays nothing", _playing(rec, "idle_loop"))
	_ultimate(hero, rec, events)
	_slam(game, hero, player, rec)
	hero._process(20.0)
	events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO)
	_t.check("ready queue begins with cast_special", _playing(rec, "cast_special"))
	events.ultimate_ready.emit("cable_run")
	_t.check("ready waits behind cast", _playing(rec, "cast_special") and rec.queued.get("clip", "") == "ult_ready")
	Trigger.finish(rec)
	_t.check("ready plays after cast", _playing(rec, "ult_ready"))
	_handoff(rec, "queued ready")
	_controls(hero, rec, events)
	_t.check("no machinery row is rejected", rec.mecha.skip_lines.filter(func(line): return String(line).begins_with("SKIP machinery")).is_empty())
	_t.eq("clips preserve physical velocity", player.body().linear_velocity, body_before)
	_t.eq("clips preserve state velocity", player.state.velocity, state_before)
	_preview()
	_done(game)

func _ultimate(hero, rec: Dictionary, events) -> void:
	hero._process(20.0)
	_phase = "windup"
	events.ultimate_started.emit("cable_run", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("five-argument ultimate start plays wind-up", _playing(rec, "ult_windup"))
	_phase = "flight"
	if _playing(rec, "ult_windup"):
		rec.animator.advance(0.34)
	_t.check("wind-up reaches ride base after 0.34 seconds", _playing(rec, "ult_ride_loop"))
	_t.eq("ride priority", int(rec.priority), 64)
	events.player_hit.emit(1.0, "test")
	_t.check("hit cannot break ride", _playing(rec, "ult_ride_loop"))
	events.ultimate_peak.emit("cable_run", Vector3.ZERO)
	_t.check("peak plays strike", _playing(rec, "ult_strike"))
	Trigger.finish(rec)
	_t.check("strike returns to ride during flight", _playing(rec, "ult_ride_loop"))
	_phase = "idle"
	events.ultimate_landed.emit("cable_run", Vector3.ZERO, 2, 40.0)
	_t.check("landing plays recovery", _playing(rec, "ult_recover"))
	_handoff(rec, "landing recovery")
	_phase = "flight"
	hero._to_base(rec)
	events.ultimate_peak.emit("cable_run", Vector3.ZERO)
	_t.check("second peak plays strike", _playing(rec, "ult_strike"))
	_phase = "idle"
	Trigger.finish(rec)
	_t.check("strike ending outside flight plays recovery", _playing(rec, "ult_recover"))
	_handoff(rec, "outside-flight recovery")
	_phase = "windup"
	events.ultimate_started.emit("cable_run", "line", Vector3.ZERO, Vector3(0, 0, -10), 2.0)
	_t.check("recall starts during wind-up", _playing(rec, "ult_windup"))
	_phase = "idle"
	events.ultimate_cancelled.emit("cable_run", "recall", true)
	_t.check("recall interrupts wind-up with recovery", _playing(rec, "ult_recover"))
	_handoff(rec, "recall recovery")

func _slam(game, hero, player, rec: Dictionary) -> void:
	hero._process(20.0)
	var far: Vector3 = player.ball_position() + Vector3(500, 0, 500)
	var enemy = game.combat.spawn_enemy("chaser", far + Vector3(2, 0, 0))
	var on_slam := func(_at, _strength, _flatness): _t.check("real slam begins smash before outcome", _playing(rec, "smash"))
	game.events.slammed.connect(on_slam, CONNECT_ONE_SHOT)
	player._on_slammed(far, 30.0, 1.0)
	_t.check("real hit queues drop_land behind smash", _playing(rec, "smash") and rec.queued.get("clip", "") == "drop_land")
	Trigger.finish(rec)
	_t.check("hit payoff plays after smash", _playing(rec, "drop_land"))
	_handoff(rec, "slam hit")
	enemy.free()
	hero._process(20.0)
	player._on_slammed(far + Vector3(100, 0, 0), 30.0, 1.0)
	_t.check("real slam miss cuts in with wince", _playing(rec, "wince"))
	_handoff(rec, "slam miss")

func _controls(hero, rec: Dictionary, events) -> void:
	var table: Dictionary = hero._pilot_table(CLASS_ID)
	for clip in ["cast_special", "cast_line"]:
		hero._process(20.0)
		var contact: Dictionary = table.get("clips", {}).get(clip, {}).get("contact", {})
		var control := String(contact.get("control", "GaugeLever" if clip == "cast_special" else "SpoolBrake"))
		var node := rec.pod.find_child(("Control." + control).replace(".", "_"), true, false) as Node3D
		var before := node.rotation_degrees.x if node != null else 0.0
		if clip == "cast_special":
			events.slot_cast.emit("special", "arc_discharge", Vector3.ZERO)
		else:
			events.line_skill_fired.emit("bank_shot", null, Vector3.ZERO, "enemy")
		var resolved: Dictionary = hero._contact_of(rec, clip)
		var seconds := float(resolved.get("seconds", 0.0))
		var expected_seconds: float = (float(contact.frame) - 1.0) / 30.0 if contact.has("frame") else 0.4 * rec.animator.get_animation(clip).length
		_t.check(clip + " resolves declared contact or documented fallback", String(resolved.get("control", "")) == control and is_equal_approx(seconds, expected_seconds))
		rec.mecha.step(seconds + 0.05)
		_t.check(clip + " real control moves or records its absence", (node != null and absf(node.rotation_degrees.x - before) > Mecha.LEVER_DEG * 0.5) or (node == null and "SKIP control " + control in rec.mecha.skip_lines))
		var pod := Trigger.fixture_pod(["Control." + control])
		root.add_child(pod.get_parent())
		var fixture := Mecha.new(pod, pod.get_parent().get_node("Core"), CLASS_ID)
		fixture.cast(clip, control, seconds)
		fixture.step(seconds + 0.05)
		var handle := pod.find_child(("Control." + control).replace(".", "_"), true, false) as Node3D
		_t.check(clip + " positive control exceeds half throw", handle.rotation_degrees.x > Mecha.LEVER_DEG * 0.5)
		pod.get_parent().free()
		Trigger.finish(rec)

func _preview() -> void:
	var preview := Preview.new(ClassDef.by_id(CLASS_ID))
	preview.ui_profile = FreshProfile.new()
	root.add_child(preview)
	preview.open = 1.0
	preview.track_focus()
	_t.eq("first fresh-profile focus selects unlock", preview.last_focus_clip, "unlock")
	_t.check("preview plays delivered unlock", preview._animator.is_playing() and preview._animator.current_animation == "unlock")
	if preview._animator.current_animation == "unlock":
		preview._animator.advance(preview._animator.current_animation_length + 0.01)
	_t.check("preview unlock ends on idle_loop", preview._animator.current_animation == "idle_loop")
	_t.check("preview unlock hand-off is rest", Trigger.bones_at_rest(preview._pilot))
	preview.open = 0.0
	preview.track_focus()
	preview.open = 1.0
	preview.track_focus()
	_t.check("second focus keeps idle without unlock", preview.last_focus_clip == "" and preview._animator.current_animation == "idle_loop")
	preview.free()

func _done(game) -> void:
	_t.eq("expected check count", _t.checks + 1, EXPECTED)
	game.queue_free()
	quit(_t.verdict())
