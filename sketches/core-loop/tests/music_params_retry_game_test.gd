extends SceneTree

const Game := preload("res://src/game.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const T := preload("res://tests/support/t.gd")

var t := T.new("music_params_retry_game_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.press_start()
	game.flow.choose_class(0)
	game.player.set_frozen(true)
	game.world.set_physics_process(false)
	game.combat.set_physics_process(false)
	var audio = game.presentation.audio
	audio.bake_now()
	audio.set_process(false)
	audio._flush_flow()
	var engine = audio.engine
	var ult = game.combat.ultimate
	var present: bool = Array(DirAccess.get_files_at("res://assets/music_ace/spillway")).any(func(name): return name.ends_with(".ogg"))
	_pump_to(audio, engine.clock + Harmony.BAR * 2)
	t.eq("retry fixture performs expected band", audio.ace_playing(), present)
	for full in [false, true]:
		ult.meter.locked = false
		ult.meter.reset()
		if full:
			ult.meter.refund(ult.meter.CAP)
		ult._on_stage_entered(game.run.stage, false)
		if full:
			game.events.ultimate_cancelled.emit("ult_default", "death", false)
		else:
			ult.meter.refund(ult.meter.CAP)
			game.events.ultimate_ready.emit("ult_default")
		_pump_to(audio, engine.clock + Harmony.BAR * 2)
		t.eq("retry has opposite live lift entry_full=%s" % full, engine.ultimate_lift, not full)
		ult._on_stage_entered(game.run.stage, true)
		audio._on_stage_entered(game.run.stage, true)
		await process_frame
		audio._flush_flow()
		_pump_to(audio, engine.clock + Harmony.BAR * 2)
		t.eq("retry restores meter entry_full=%s" % full, ult.meter.full(), full)
		t.eq("retry restores source-enabled synth lift entry_full=%s" % full, engine.ultimate_lift, full)
		if present:
			t.check("retry keeps performing ACE entry_full=%s" % full, audio.ace_playing() and engine.band_muted)
			t.eq("retry restores performing ACE lift entry_full=%s" % full, audio.ace.ultimate_lift, full)
		else:
			t.check("retry keeps audible synth fallback entry_full=%s" % full, not audio.ace_playing() and not engine.band_muted)
		t.check("retry band produces PCM entry_full=%s" % full, Array(audio.out_music).any(func(v): return v.length_squared() > 0.0))
	game.queue_free()
	await process_frame
	quit(t.verdict())


func _pump_to(audio, until: int) -> void:
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))
