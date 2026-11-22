extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const MusicDsp := preload("res://src/presentation/music_dsp.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const T := preload("res://tests/support/t.gd")

class FakeFlow extends RefCounted:
	var state := "stage"
	var sealed := false

	func in_play() -> bool:
		return state in ["stage", "beacon", "gates", "launch", "boss"]

	func state_name() -> String:
		return state

class FakeRun extends RefCounted:
	var stage := 1
	var armor_mode := false
	var run_id := "dsp_test"
	var mass := 100.0
	var max_hp := 100.0
	var hp := 100.0

class FakeCtx extends RefCounted:
	var events: Node
	var flow: FakeFlow
	var run: FakeRun
	var tuning: Tuning
	var player = null
	var spawner = null
	var stages = null
	var boss = null
	var terrain = null
	var build = null
	var root = null
	var dev := false
	var calm := true

var _t := T.new("music_dsp_test")
var _prev_stem_dir := ""


func _initialize() -> void:
	_prev_stem_dir = MusicRows.stem_dir
	AceStub.install()
	_test_bus_setup_and_idempotency()
	_test_warning_eq_carving()
	_test_lpf_low_hull_slowmo_and_sweep()
	_test_empty_starting_shell_not_low_hull()
	_test_hpf_build_tension_and_release()
	_test_pack_swap_smooth_crossfade()
	MusicRows.stem_dir = _prev_stem_dir
	quit(_t.verdict())


func _make_audio() -> Dictionary:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = FakeFlow.new()
	ctx.run = FakeRun.new()
	ctx.tuning = Tuning.new()
	ctx.tuning.set_option(Tuning.MUSIC_KEY, "ace")
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	return {"events": events, "ctx": ctx, "audio": audio}


func _free_audio(rig: Dictionary) -> void:
	var audio: Audio = rig["audio"]
	audio.music_dsp.reset()
	audio.free()
	(rig["events"] as Node).free()


func _test_bus_setup_and_idempotency() -> void:
	var rig := _make_audio()
	var audio: Audio = rig["audio"]
	var music_idx := AudioServer.get_bus_index(MusicDsp.MUSIC_BUS)
	var before_count := AudioServer.get_bus_effect_count(music_idx)
	audio.music_dsp.setup()
	var after_count := AudioServer.get_bus_effect_count(music_idx)
	_t.eq("repeated setup does not stack duplicate Music bus effects", after_count, before_count)
	var snap := audio.music_dsp.snapshot()
	_t.check("resting Music bus effects are bypassed", not snap["eq_enabled"] and not snap["lpf_enabled"] and not snap["hpf_enabled"], str(snap))
	_t.eq("StingerMusic bus sends to SFX", snap["stinger_send"], "SFX")
	_t.check("StingerMusic carries room reverb", snap["stinger_reverb"])
	_t.eq("stinger player routes through StingerMusic", audio._stinger_player.bus, MusicDsp.STINGER_BUS)
	_free_audio(rig)


func _test_warning_eq_carving() -> void:
	var rig := _make_audio()
	var audio: Audio = rig["audio"]
	audio._focus()
	for i in 6:
		audio._tend_mix(0.05)
	var active := audio.music_dsp.snapshot()
	_t.check("warning focus enables EQ6 and carves 3.2 kHz near -4 dB",
		active["eq_enabled"] and active["eq_3k2_db"] <= -3.5 and active["eq_1k_db"] <= -2.0,
		str(active))
	audio.clock += 2.0
	for i in 20:
		audio._tend_mix(0.05)
	var recovered := audio.music_dsp.snapshot()
	_t.check("EQ6 recovers to 0 dB and bypasses after focus ends",
		not recovered["eq_enabled"] and absf(float(recovered["eq_3k2_db"])) < 0.05,
		str(recovered))
	_free_audio(rig)


func _test_lpf_low_hull_slowmo_and_sweep() -> void:
	var rig := _make_audio()
	var audio: Audio = rig["audio"]
	audio.slowed(true)
	for i in 8:
		audio._tend_mix(0.05)
	var slow := audio.music_dsp.snapshot()
	_t.check("slow motion engages Music LPF around 2500 Hz",
		slow["lpf_enabled"] and float(slow["lpf_hz"]) <= 2700.0 and float(slow["lpf_hz"]) >= 2300.0,
		str(slow))
	audio.slowed(false)
	audio.music_dsp.step(0.2, {"low_hull": true})
	audio.music_dsp.step(0.2, {"low_hull": true})
	var hull := audio.music_dsp.snapshot()
	_t.check("low hull pulls Music LPF down toward 700 Hz",
		hull["lpf_enabled"] and float(hull["lpf_hz"]) <= 900.0,
		str(hull))
	for i in 30:
		audio.music_dsp.step(0.05, {})
	var clean := audio.music_dsp.snapshot()
	_t.check("LPF recovers to transparent and bypasses at rest",
		not clean["lpf_enabled"] and float(clean["lpf_hz"]) >= 20400.0,
		str(clean))
	_free_audio(rig)


func _test_empty_starting_shell_not_low_hull() -> void:
	var rig := _make_audio()
	var events: GameEvents = rig["events"]
	var ctx: FakeCtx = rig["ctx"]
	var audio: Audio = rig["audio"]
	audio.pack_available = func(_id: String) -> bool: return true
	audio.tune_available = func(_id: String) -> bool: return true
	ctx.run.armor_mode = true
	ctx.run.mass = 0.0
	ctx.run.max_hp = 100.0
	ctx.run.hp = 100.0
	events.run_started.emit("sable")
	audio._remixes = {}
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	audio.ace.parameters["armour"] = 0.0
	for i in 10:
		audio._tend_mix(0.05)
	var fresh_state := audio._dsp_state()
	var fresh_dsp := audio.music_dsp.snapshot()
	_t.check("empty starting shell (mass 0, full hp, no hull damage) is not low_hull and keeps LPF bypassed",
		not bool(fresh_state["low_hull"]) and not fresh_dsp["lpf_enabled"],
		"state=%s dsp=%s" % [str(fresh_state), str(fresh_dsp)])
	audio._hull_seen = 12.0
	audio.ace.parameters["armour"] = 0.2
	for i in 10:
		audio._tend_mix(0.05)
	var hurt_state := audio._dsp_state()
	var hurt_dsp := audio.music_dsp.snapshot()
	_t.check("damaged hull with low armour engages 700 Hz LPF",
		bool(hurt_state["low_hull"]) and hurt_dsp["lpf_enabled"] and float(hurt_dsp["lpf_hz"]) <= 900.0,
		"state=%s dsp=%s" % [str(hurt_state), str(hurt_dsp)])
	audio._hull_seen = 0.0
	audio.ace.parameters["armour"] = 0.8
	ctx.run.hp = 20.0
	var hp_state := audio._dsp_state()
	_t.check("low hull HP below 30% engages low_hull even with armour restored",
		bool(hp_state["low_hull"]),
		str(hp_state))
	_free_audio(rig)


func _test_hpf_build_tension_and_release() -> void:
	var rig := _make_audio()
	var audio: Audio = rig["audio"]
	audio._launch_armed = true
	for i in 20:
		audio._tend_mix(0.05)
	var building := audio.music_dsp.snapshot()
	_t.check("launch build engages Music HPF sweep above 250 Hz",
		building["hpf_enabled"] and float(building["hpf_hz"]) >= 250.0,
		str(building))
	audio._launch_armed = false
	for i in 12:
		audio._tend_mix(0.05)
	var dropped := audio.music_dsp.snapshot()
	_t.check("drop releases HPF back to 20 Hz and bypasses",
		not dropped["hpf_enabled"] and float(dropped["hpf_hz"]) <= 25.0,
		str(dropped))
	_free_audio(rig)


func _test_pack_swap_smooth_crossfade() -> void:
	var rig := _make_audio()
	var events: GameEvents = rig["events"]
	var audio: Audio = rig["audio"]
	audio.pack_available = func(_id: String) -> bool: return true
	audio.tune_available = func(_id: String) -> bool: return true
	events.run_started.emit("sable")
	audio._remixes = {}
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	var until: int = audio.engine.clock + audio.engine.bar_len() * 2
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))
	var old_beat: int = audio.ace.grid_beat
	var old_voices: int = audio.ace.voices.size()
	audio._ace_named("champion-hype", audio.engine.next_bar(), true)
	var expected_ramp: int = clampi(old_beat / 2, AceSequencer.STOP_RAMP, int(AceSequencer.RATE * 0.25))
	_t.check("pack swap carries fading tails with beat-scaled crossfade (> 10 ms STOP_RAMP)",
		old_voices > 0 and expected_ramp > AceSequencer.STOP_RAMP and not audio.ace.fading.is_empty(),
		"old_voices=%d expected_ramp=%d fading=%d" % [old_voices, expected_ramp, audio.ace.fading.size()])
	if not audio.ace.fading.is_empty():
		var v: AceSequencer.Voice = audio.ace.fading[0]
		_t.check("fading tail ramp step is smoother than hard 10 ms cut",
			v.step < 1.0 / float(AceSequencer.STOP_RAMP),
			"step=%f stop_step=%f" % [v.step, 1.0 / float(AceSequencer.STOP_RAMP)])
	_free_audio(rig)
