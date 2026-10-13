extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("park_music_hold_game_test")
var game
var booked := []
var started := []
var due := -1
var lead := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
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
	game.events.event_announced.connect(func(id, seconds):
		if id == "plunge_pool_flood":
			lead = seconds
			due = audio.engine.clock + roundi(seconds * Harmony.RATE)
			booked = audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.id == "drop_flood").duplicate(true))
	game.events.event_started.connect(func(id): started.append(id))
	game.world.director.stage_time = 45.0
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
	t.check("uncommitted drop blocks rendering at its deadline", audio.engine.clock == due and not audio.engine.park_cue_log.any(func(a): return a.id == "drop_flood"), str([audio.engine.clock, due]))
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
	t.check("held-event booking cancelled", not audio.engine._actions.any(func(a): return a.get("type") == "park_cue" and a.id == "drop_flood"), str(audio.engine._actions.filter(func(a): return a.get("type") == "park_cue" and a.id == "drop_flood")))
	t.check("held-event drop never sounds", not audio.engine.park_cue_log.any(func(a): return a.id == "drop_flood"), str(audio.engine.park_cue_log.filter(func(a): return a.id == "drop_flood")))
	game.queue_free()
	await process_frame
	await _warning_through_hold()
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
	game.events.event_announced.connect(func(id, seconds):
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
	var row = preload("res://src/presentation/music_rows.gd").cue("riser_natural", {"theme": audio.engine.theme})
	var expected := []
	for cell in row.notes.size():
		expected.append([warning[0].at + roundi(float(warning[0].lead) * cell / row.notes.size()),
			warning[0].at + roundi(float(warning[0].lead) * (cell + 1) / row.notes.size())])
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
	var heard: Array = audio.engine.park_cue_log.filter(func(a): return a.owner == "plunge_pool_flood" and a.id == "riser_natural")
	t.check("unsafe lead preserves all original riser cells", heard.map(func(a): return [a.at, a.end]) == expected,
		str([heard.map(func(a): return [a.at, a.end]), expected]))
	t.check("unsafe lead holds drop silent", flood.holding and not audio.engine.park_cue_log.any(func(a): return a.owner == "plunge_pool_flood" and a.id == "drop_flood"), str(flood.holding))
	game.queue_free()
	await process_frame
