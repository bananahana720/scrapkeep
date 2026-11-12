extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const T := preload("res://tests/support/t.gd")
const ParkRiser := preload("res://tests/support/park_riser.gd")
const IDS := ["plunge_pool_flood", "east_bench_dropship"]
const FAMILY_CUES := ["riser_fleet", "drop_fleet", "drop_fleet_anvil", "riser_ancient", "drop_ancient",
	"riser_mind_quote", "drop_mind_wrong", "riser_industrial", "drop_industrial", "drop_boiler"]
var t := T.new("park_music_multi_game_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for id in FAMILY_CUES:
		var row := MusicRows.cue(id, {"ancient": "mind", "motif": "tarn"})
		t.check(id + " resolves existing grammar", not row.is_empty() and not row.get("notes", []).is_empty(), str(row))
	await _two_events("synth")
	await _two_events("ace")
	quit(t.verdict())


func _two_events(band: String) -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.ctx.tuning.set_option("music", band)
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	game.world.set_physics_process(false)
	var audio = game.presentation.audio
	audio.set_process(false)
	audio.bake_now()
	audio._flush_flow()
	var director = game.world.events
	director.set_clock_tier(1)
	var stems_present: bool = Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg"))
	var fallback: bool = band == "ace" and not stems_present
	t.check(band + " all park families registered", ["natural", "fleet", "ancient", "industrial"].all(
		func(family): return director._park_families.has(family)), str(director._park_families.keys()))
	if fallback:
		t.check("absent ACE package selects synth fallback", not audio.ace_playing() and audio.ace == null
			and audio.ace_missing != "" and not audio.engine.band_muted, str(audio.ace_missing))
	else:
		t.check(band + " selected band active", audio.ace_playing() if band == "ace" else not audio.ace_playing(), str(audio.ace_missing))
	var announcements := {}
	game.events.event_announced.connect(func(id, seconds, _at):
		if id in IDS:
			var bar: int = audio.engine.step_len * Harmony.STEPS_PER_BAR
			var origin: int = audio.engine.bar_origin
			if band == "ace" and not fallback:
				var seq = audio.ace
				var clip: Dictionary = seq.clips[seq.sections[str(seq.pending.section)].clip]
				bar = int(clip.bar)
				origin = int(seq.pending.at) - posmod(int(seq.pending.entry) - int(clip.entry), bar)
			announcements[id] = {"sample": audio.engine.clock, "due": audio.engine.clock + roundi(seconds * Harmony.RATE),
				"bar": bar, "origin": origin, "lead": roundi(seconds * Harmony.RATE)})
	# One output window contains several physics advances, without any intervening render.
	for tick in 4:
		var context := {"grounded": true, "ball_radius_m": game.player.Tuning.RADIUS}.merged(
			audio.park_transport(director.stage_time + 1.0 / 90.0))
		game.world._publish(director.advance(1.0 / 90.0, game.player.ball_position(), Vector3.ZERO, context))
		if announcements.size() == IDS.size():
			break
	t.check(band + " two events share output window", announcements.size() == IDS.size() and
		announcements.values().all(func(a): return a.sample == audio.engine.clock), str(announcements))
	if announcements.size() != IDS.size():
		game.queue_free()
		await process_frame
		return
	var deadlines := {}
	for id in IDS:
		var expected: Dictionary = announcements[id]
		var actions: Array = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.owner == id and not a.row.rise)
		t.check(band + " " + id + " own director downbeat", actions.size() == 1 and actions[0].at == expected.due
			and posmod(expected.due - expected.origin, expected.bar) == 0, str([actions.map(func(a): return a.at), expected]))
		deadlines[id] = audio._park_event_state(id).due_s
	game.toggle_pause()
	audio._process(0.0)
	var stage: float = director.stage_time
	var target: int = maxi(announcements[IDS[0]].due, announcements[IDS[1]].due) + 2 * Harmony.BAR
	var peak := 0.0
	for block in 100:
		audio._virtual_usec -= int(8192.0 * 1000000.0 / Harmony.RATE)
		audio._pump()
		if audio.engine.clock > target:
			var output = audio.get("out_music")
			if output is PackedVector2Array:
				for sample in output:
					peak = maxf(peak, maxf(absf(sample.x), absf(sample.y)))
	t.check(band + " paused transport passes both deadlines", audio.engine.clock > target, str([audio.engine.clock, target]))
	t.check(band + " paused selected band remains audible", peak > 0.0001, str(peak))
	t.check(band + " pause leaves director suspended", director.stage_time == stage, str([stage, director.stage_time]))
	for id in IDS:
		var state: Dictionary = audio._park_event_state(id)
		t.check(band + " " + id + " remains announced with unchanged deadline", state.phase == director.ANNOUNCED and state.due_s == deadlines[id], str([state.phase, state.due_s]))
		t.check(band + " " + id + " predicted impact cancelled", not audio.engine._actions.any(func(a): return a.get("type") == "park_cue" and a.owner == id and not a.row.rise)
			and not audio.engine.park_cue_log.any(func(a): return a.owner == id and not MusicRows.cue(a.id).rise), id)
		var expected_cells := ParkRiser.starts(state.row.music_cue.telegraph, ParkRiser.options(audio), announcements[id].lead, announcements[id].sample)
		var cells: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == id)
		t.check(band + " " + id + " warning cells complete once", cells.map(func(a): return a.at) == expected_cells, str([cells.map(func(a): return a.at), expected_cells]))
	game.toggle_pause()
	game.queue_free()
	await process_frame
