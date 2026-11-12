extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")
const ParkRiser := preload("res://tests/support/park_riser.gd")
# plunge_pool_flood has its own world 1 cues since #496; read them from the row.
var flood_riser := ParkRiser.dam_cue("plunge_pool_flood", "telegraph")
var flood_drop := ParkRiser.dam_cue("plunge_pool_flood", "land")

var t := T.new("park_music_hold_game_test")
var game
var booked := []
var started := []
var due := -1
var lead := 0.0


class TransportProbe extends Node:
	var audio
	var director
	var snapshot := {}

	func _physics_process(delta: float) -> void:
		var engine = audio.engine
		var bar: int = engine.step_len * Harmony.STEPS_PER_BAR
		var origin: int = engine.bar_origin + ceili(float(engine.clock - engine.bar_origin) / bar) * bar
		snapshot = {"stage": director.stage_time + delta, "sample": engine.clock, "origin": origin, "bar": bar}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	t.check("flood row names real cues", MusicRows.CUES.get(flood_riser, {}).get("rise", false) and MusicRows.CUES.has(flood_drop) and not MusicRows.CUES[flood_drop].get("rise", true), str([flood_riser, flood_drop]))
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	game.events.event_announced.connect(func(id, seconds, _at):
		if id == "plunge_pool_flood":
			lead = seconds
			due = audio.engine.clock + roundi(seconds * Harmony.RATE)
			booked = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.id == flood_drop).duplicate(true))
	game.events.event_started.connect(func(id): started.append(id))
	game.world.director.stage_time = game.world.director.TIER_SECONDS
	for frame in 120:
		await physics_frame
		if due >= 0:
			break
	t.check("real Game drop booked before hold", booked.size() == 1 and booked[0].at == due, str([booked, due]))
	# A queued output block can reach the deadline before the next physics decision.
	# Exercise the real headless pump with that buffered lead, then enter the site.
	for block in 64:
		audio._virtual_usec -= int(8192.0 * 1000000.0 / Harmony.RATE)
		audio._pump()
		if audio.engine.clock >= due:
			break
	t.check("uncommitted drop blocks rendering at its deadline", audio.engine.clock == due and not audio.engine.park_cue_log.any(func(a): return a.id == flood_drop), str([audio.engine.clock, due]))
	var flood: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "plunge_pool_flood")[0]
	var at: Vector3 = game.world.events._park_at(flood)
	game.player.reset_to(at + Vector3.UP * game.player.Tuning.RADIUS)
	game.player.set_frozen(true)
	game.player.state.grounded = true
	for frame in 760:
		await physics_frame
		game.player.state.grounded = true
	t.check("real Game director holds unsafe flood", flood.holding and not started.has("plunge_pool_flood"), str([flood.holding, started, game.world.events.stage_time, lead]))
	t.check("held-event render crossed booked deadline", due >= 0 and audio.engine.clock > due, str([audio.engine.clock, due]))
	t.check("held-event booking cancelled", not audio.engine._actions.any(func(a): return a.get("type") == "park_cue" and a.id == flood_drop), str(audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.id == flood_drop)))
	t.check("held-event drop never sounds", not audio.engine.park_cue_log.any(func(a): return a.id == flood_drop), str(audio.engine.park_cue_log.filter(func(a): return a.id == flood_drop)))
	game.queue_free()
	await process_frame
	await _warning_through_hold()
	await _recovery(true)
	await _recovery(false)
	await _recovery(false, true)
	quit(t.verdict())


func _warning_through_hold() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var audio = game.presentation.audio
	audio.bake_now()
	var warning := []
	game.events.event_announced.connect(func(id, seconds, _at):
		if id == "plunge_pool_flood":
			warning.append({"at": audio.engine.clock, "lead": roundi(seconds * Harmony.RATE)}))
	game.world.director.stage_time = game.world.director.TIER_SECONDS
	for frame in 120:
		await physics_frame
		if not warning.is_empty():
			break
	t.check("early unsafe warning announced", not warning.is_empty(), str(warning))
	if warning.is_empty():
		game.queue_free()
		await process_frame
		return
	var flood: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "plunge_pool_flood")[0]
	var expected := ParkRiser.pieces(flood_riser, ParkRiser.options(audio), warning[0].lead, warning[0].at)
	audio._virtual_usec -= int(8192.0 * 1000000.0 / Harmony.RATE)
	audio._pump()
	var voices: Array = audio.engine._voices.filter(func(v): return v.park_owned and v.park_owner == "plunge_pool_flood")
	var warning_voice = voices[0] if not voices.is_empty() else null
	var warning_end: int = warning_voice.end if warning_voice != null else -1
	# Enter while most of the original warning is still ahead of the render head.
	game.player.reset_to(game.world.events._park_at(flood) + Vector3.UP * game.player.Tuning.RADIUS)
	game.player.set_frozen(true)
	game.player.state.grounded = true
	audio._guard_park_bookings()
	t.check("unsafe lead preserves active riser voice", warning_voice != null and warning_voice.end == warning_end,
		str([warning_voice.end if warning_voice != null else -1, warning_end]))
	for frame in 760:
		await physics_frame
		game.player.state.grounded = true
	var heard: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_riser)
	t.check("unsafe lead preserves all original riser cells", heard.map(func(a): return [a.at, a.end]) == expected,
		str([heard.map(func(a): return [a.at, a.end]), expected]))
	t.check("unsafe lead holds drop silent", flood.holding and not audio.engine.park_cue_log.any(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_drop), str(flood.holding))
	game.queue_free()
	await process_frame


func _recovery(before_deadline: bool, direct_live := false) -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var safe_at: Vector3 = game.player.ball_position()
	var audio = game.presentation.audio
	audio.bake_now()
	var probe := TransportProbe.new()
	probe.audio = audio
	probe.director = game.world.events
	probe.process_physics_priority = -100
	root.add_child(probe)
	var announcement := []
	var landed := []
	game.events.event_announced.connect(func(id, seconds, _at):
		if id == "plunge_pool_flood":
			announcement.append({"sample": audio.engine.clock + roundi(seconds * Harmony.RATE), "stage": game.world.events.stage_time + seconds}))
	game.events.event_started.connect(func(id):
		if id == "plunge_pool_flood":
			landed.append(probe.snapshot.duplicate()))
	game.world.director.stage_time = game.world.director.TIER_SECONDS
	for frame in 120:
		await physics_frame
		if not announcement.is_empty():
			break
	var label := "clearance recovery" if before_deadline else ("hold direct LIVE recovery" if direct_live else "held recovery")
	t.check(label + " announced", not announcement.is_empty(), str(announcement))
	if announcement.is_empty():
		probe.queue_free()
		game.queue_free()
		await process_frame
		return
	var flood: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "plunge_pool_flood")[0]
	game.player.reset_to(game.world.events._park_at(flood) + Vector3.UP * game.player.Tuning.RADIUS)
	game.player.set_frozen(true)
	game.player.state.grounded = true
	for frame in (30 if before_deadline else 900):
		await physics_frame
		game.player.state.grounded = true
		if not before_deadline and flood.holding:
			break
	t.check(label + " cancelled before recovery", not audio.engine._actions.any(func(a): return a.get("type") == "park_cue" and a.owner == "plunge_pool_flood" and not a.row.rise)
		and (game.world.events.stage_time < announcement[0].stage if before_deadline else flood.holding), str([flood.holding, game.world.events.stage_time]))
	if before_deadline:
		for block in 64:
			audio._virtual_usec -= int(8192.0 * 1000000.0 / Harmony.RATE)
			audio._pump()
			if audio.engine.clock >= announcement[0].sample:
				break
		t.check(label + " cancelled deadline remains unrendered", audio.engine.clock == announcement[0].sample, str([audio.engine.clock, announcement[0].sample]))
	if not before_deadline:
		for frame in 12:
			await physics_frame
		if direct_live:
			# Align the render head, not the director rules, so release commits in one advance.
			var bar: int = audio.engine.step_len * Harmony.STEPS_PER_BAR
			var target: int = audio.engine.bar_origin + ceili(float(audio.engine.clock - audio.engine.bar_origin) / bar) * bar
			while audio.engine.clock < target:
				var frames: int = mini(4096, target - audio.engine.clock)
				audio.engine.render(frames)
			# Prevent wall-clock rounding from moving the head before the scheduling tick.
			audio._virtual_usec += 1000000
	game.player.reset_to(safe_at)
	game.player.set_frozen(true)
	var expected: int = announcement[0].sample
	var scheduling := {}
	var previous_due: float = flood.due_s
	for frame in 900:
		await physics_frame
		if float(flood.due_s) != previous_due and scheduling.is_empty():
			scheduling = probe.snapshot.duplicate()
			var origin_stage: float = scheduling.stage + float(scheduling.origin - scheduling.sample) / Harmony.RATE
			expected = scheduling.origin + roundi((float(flood.due_s) - origin_stage) * Harmony.RATE)
		if not landed.is_empty() and audio.engine.clock > expected + audio.engine.beat_len():
			break
	var drops: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_drop)
	var bar: int = audio.engine.step_len * Harmony.STEPS_PER_BAR
	t.check(label + " committed deadline", not landed.is_empty() and (float(flood.due_s) == announcement[0].stage if before_deadline else float(flood.due_s) > announcement[0].stage), str([flood.due_s, announcement, scheduling]))
	t.check(label + " exactly one mapped downbeat", drops.size() == 1 and drops[0].at == expected and posmod(expected - audio.engine.bar_origin, bar) == 0,
		str([drops.map(func(a): return a.at), expected, audio.engine.bar_origin, bar]))
	if direct_live:
		t.check(label + " committed on release advance", not landed.is_empty() and not scheduling.is_empty() and is_equal_approx(landed[0].stage, scheduling.stage), str([landed, scheduling]))
	probe.queue_free()
	game.queue_free()
	await process_frame
