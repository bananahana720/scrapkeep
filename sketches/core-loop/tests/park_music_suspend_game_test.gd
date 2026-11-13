extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")
const ParkRiser := preload("res://tests/support/park_riser.gd")
# plunge_pool_flood has its own world 1 cues since #496; read them from the row.
var flood_riser := ParkRiser.dam_cue("plunge_pool_flood", "telegraph")
var flood_drop := ParkRiser.dam_cue("plunge_pool_flood", "land")
var t := T.new("park_music_suspend_game_test")

class TransportProbe extends Node:
	var audio
	var director
	var snapshot := {}
	func _physics_process(delta: float) -> void:
		var e = audio.engine
		var bar: int = e.step_len * Harmony.STEPS_PER_BAR
		var origin: int = e.bar_origin + ceili(float(e.clock - e.bar_origin) / bar) * bar
		if e.grid != null:
			origin = e.grid.next_bar(e.clock)
			bar = e.grid.next_bar(origin + 1) - origin
		snapshot = {"stage": director.stage_time + delta, "sample": e.clock, "origin": origin, "bar": bar}

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	t.check("flood row names real cues", MusicRows.CUES.get(flood_riser, {}).get("rise", false) and MusicRows.CUES.has(flood_drop) and not MusicRows.CUES[flood_drop].get("rise", true), str([flood_riser, flood_drop]))
	await _suspension(false)
	await _suspension(true)
	await _suspension(false, true)
	quit(t.verdict())

func _suspension(in_bay: bool, aligned := false) -> void:
	var label := "bay announcement" if in_bay else ("aligned pause announcement" if aligned else "paused announcement")
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	if in_bay: game.flow.beacon_seconds_override = 0.2
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	var safe_at: Vector3 = game.player.ball_position()
	var audio = game.presentation.audio
	audio.bake_now()
	var announcement := []
	var starts := []
	game.events.event_announced.connect(func(id, seconds, _at):
		if id == "plunge_pool_flood":
			announcement.append({"sample": audio.engine.clock + roundi(seconds * Harmony.RATE),
				"at": audio.engine.clock, "lead": roundi(seconds * Harmony.RATE), "stage": game.world.events.stage_time + seconds}))
	game.events.event_started.connect(func(id):
		if id == "plunge_pool_flood":
			var e = audio.engine
			# The next downbeat as the engine books it: the ACE grid when a track plays, else the synth bar.
			var bar: int = e.step_len * Harmony.STEPS_PER_BAR
			var next: int = e.bar_origin + ceili(float(e.clock - e.bar_origin) / bar) * bar
			if e.grid != null:
				next = e.grid.next_bar(e.clock)
			starts.append({"stage": game.world.events.stage_time, "sample": e.clock, "next": next}))
	game.world.director.stage_time = game.world.director.TIER_SECONDS
	for frame in 120:
		await physics_frame
		if not announcement.is_empty(): break
	t.check(label + " real director announcement", not announcement.is_empty(), str(announcement))
	if announcement.is_empty():
		game.queue_free()
		await process_frame
		return
	var flood: Dictionary = game.world.events._park_states.filter(func(s): return s.row.id == "plunge_pool_flood")[0]
	if in_bay:
		game.player.reset_to(game.flow.beacon.global_position + Vector3.UP * 1.5)
		for frame in 120:
			await physics_frame
			if game.world.bay.docked: break
		t.check(label + " real bay docked", game.world.bay.docked, game.flow.state_name())
		game.player.reset_to(game.world.bay.cradle_at)
		game.player.set_frozen(false)
		for frame in 180:
			await physics_frame
			if game.world.bay.inside and game.world.ride == null: break
		game.player.set_frozen(true)
		t.check(label + " entered through cradle", game.world.bay.inside, str(game.player.ball_position()))
	else:
		game.toggle_pause()
	var suspended_stage: float = game.world.events.stage_time
	var music_peak := 0.0
	for block in 80:
		audio._virtual_usec -= int(8192.0 * 1000000.0 / Harmony.RATE)
		audio._pump()
		if audio.engine.clock > announcement[0].sample + 2 * audio.engine.bar_len():
			for sample in audio.out_music:
				music_peak = maxf(music_peak, maxf(absf(sample.x), absf(sample.y)))
	for frame in 12:
		await process_frame
	t.check(label + " stage stays suspended", game.world.events.stage_time == suspended_stage and flood.phase == game.world.events.ANNOUNCED, str([suspended_stage, game.world.events.stage_time, flood.phase]))
	t.check(label + " music transport continues past deadline", audio.engine.clock > announcement[0].sample + 2 * audio.engine.bar_len(), str([audio.engine.clock, announcement[0].sample]))
	t.check(label + " band remains audible", music_peak > 0.0001 and (audio.engine.lounge if in_bay else audio.engine.pause_gain == 0.45), str([music_peak, audio.engine.lounge, audio.engine.pause_gain]))
	t.check(label + " predicted drop cancelled", not audio.engine._actions.any(func(a): return a.get("type") == "park_cue" and a.owner == "plunge_pool_flood" and not a.row.rise), str(audio.engine.pending_actions()))
	t.check(label + " no predicted impact", starts.is_empty() and not audio.engine.park_cue_log.any(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_drop), str(starts))
	var expected_warning := ParkRiser.starts(flood_riser, ParkRiser.options(audio), announcement[0].lead, announcement[0].at)
	var heard: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_riser)
	t.check(label + " original riser cells finish once", heard.map(func(a): return a.at) == expected_warning, str([heard.map(func(a): return a.at), expected_warning]))
	if aligned:
		var e = audio.engine
		var bar: int = e.step_len * Harmony.STEPS_PER_BAR
		var origin: int = e.bar_origin
		if e.grid != null:
			origin = e.grid.next_bar(e.clock)
			bar = e.grid.next_bar(origin + 1) - origin
		var remaining := roundi((float(flood.due_s) - suspended_stage - 1.0 / Engine.physics_ticks_per_second) * Harmony.RATE)
		var target: int = origin + ceili(float(e.clock + remaining - origin) / bar) * bar - remaining
		while e.clock < target:
			audio._render_music(mini(4096, target - e.clock), audio.ace != null and audio.ace.active())
		audio._virtual_usec += 1000000
	var probe := TransportProbe.new()
	probe.audio = audio
	probe.director = game.world.events
	probe.process_physics_priority = -100
	root.add_child(probe)
	if in_bay:
		game.player.reset_to(game.world.bay.deck_point(Vector2.ZERO) - Vector3.UP * (game.world.bay.FALL_OFF + 2.0))
		# Falling off the real deck emits bay_left and resumes World on this tick.
	else:
		game.toggle_pause()
	var resume := {}
	for frame in 120:
		await physics_frame
		if game.world.events.stage_time > suspended_stage:
			resume = probe.snapshot.duplicate()
			if in_bay: game.player.reset_to(safe_at)
			break
	t.check(label + " stage resumes", not resume.is_empty(), str(resume))
	var expected := -1
	var after_fact := false
	if not resume.is_empty():
		var mapped: int = resume.sample + roundi((float(flood.due_s) - float(resume.stage)) * Harmony.RATE)
		expected = resume.origin + ceili(float(mapped - resume.origin) / resume.bar) * resume.bar
		after_fact = mapped < resume.sample or expected != mapped
	audio._guard_park_bookings()
	var rebooked: Array = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.owner == "plunge_pool_flood" and not a.row.rise)
	t.check(label + " resumed booking policy", rebooked.is_empty() if after_fact else (rebooked.size() == 1 and rebooked[0].at == expected), str([after_fact, rebooked.map(func(a): return a.at), expected]))
	if aligned:
		t.check(label + " reachable fresh downbeat", not after_fact and expected > announcement[0].sample, str([expected, resume]))
	for frame in 1200:
		await physics_frame
		if starts.is_empty(): continue
		if after_fact:
			expected = starts[0].next
		if audio.engine.clock > expected + audio.engine.beat_len(): break
	var drops: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_drop)
	t.check(label + " unchanged director landing", float(flood.due_s) == float(announcement[0].stage), str([flood.due_s, announcement[0].stage]))
	t.check(label + " exactly one resumed director drop", starts.size() == 1 and drops.size() == 1 and drops[0].at == expected
		and (after_fact or posmod(expected - resume.get("origin", 0), resume.get("bar", 1)) == 0), str([starts, drops.map(func(a): return a.at), expected, resume]))
	heard = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == flood_riser)
	t.check(label + " resume never replays riser", heard.map(func(a): return a.at) == expected_warning, str(heard.map(func(a): return a.at)))
	probe.queue_free()
	game.queue_free()
	await process_frame
