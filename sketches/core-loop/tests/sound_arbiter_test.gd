extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const MusicArbiter := preload("res://src/presentation/music_arbiter.gd")
const MelodyLease := preload("res://src/presentation/melody_lease.gd")
const SfxBudget := preload("res://src/presentation/sfx_budget.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const T := preload("res://tests/support/t.gd")

class FakeFlow extends RefCounted:
	var state := "stage"
	var sealed := false
	var warden: Node3D = null

	func in_play() -> bool:
		return state in ["stage", "beacon", "gates", "launch", "boss"]

	func state_name() -> String:
		return state

	func engaged() -> bool:
		return sealed

class FakeRun extends RefCounted:
	var stage := 1
	var armor_mode := false
	var run_id := "arbiter_test"
	var mass := 100.0

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

class FakeElite extends Node3D:
	signal died(where: Vector3, scrap: int)
	var affix := {"id": "rail_strike"}
	var hp := 100.0
	var max_hp := 100.0

var _t := T.new("sound_arbiter_test")
var _prev_stem_dir := ""


func _initialize() -> void:
	_prev_stem_dir = MusicRows.stem_dir
	AceStub.install()
	_test_arbiter_priority_lattice()
	_test_melody_lease_and_trim_epochs()
	_test_sfx_budget_protects_threats()
	_test_champion_yields_to_warden()
	_test_boss_radio_record_on_stage_returns_to_stage()
	_test_boss_phase2_radio_unpin_restores_phase2()
	_test_boss_finale_beats_mid_arena_radio_pin()
	_test_boss_radio_unpin_restores_boss()
	_test_ultimate_and_radio_restore_live_champion()
	_test_death_clears_ultimate_flight()
	_test_drop_set_answer_safe_when_ace_null()
	MusicRows.stem_dir = _prev_stem_dir
	quit(_t.verdict())


func _make_rig() -> Dictionary:
	var events := GameEvents.new()
	var flow := FakeFlow.new()
	var run := FakeRun.new()
	var tuning := Tuning.new()
	tuning.set_option(Tuning.MUSIC_KEY, "ace")
	tuning.set_option(Tuning.WARDEN_FORM_KEY, "form")
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = flow
	ctx.run = run
	ctx.tuning = tuning
	var audio := Audio.new()
	audio.setup(ctx)
	audio.pack_available = func(_id: String) -> bool: return true
	audio.tune_available = func(_id: String) -> bool: return true
	audio.bake_now()
	events.run_started.emit("sable")
	audio._remixes = {}
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	_pump(audio, audio.engine.bar_len() * 2)
	return {"events": events, "flow": flow, "run": run, "tuning": tuning, "ctx": ctx, "audio": audio}


func _free_rig(rig: Dictionary, extras: Array = []) -> void:
	for n in extras:
		if is_instance_valid(n):
			(n as Node).free()
	(rig["audio"] as Node).free()
	(rig["events"] as Node).free()


func _pump(audio: Audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _test_arbiter_priority_lattice() -> void:
	var base := {
		"flow": "stage", "in_play": true, "boss_active": false, "boss_track": "brindle",
		"boss_finale": false, "launch_armed": false, "warden_fighting": false,
		"warden_engaged": false, "warden_sealed": false, "ult_flight": false,
		"radio_hold": "", "radio_pinned": false, "champion_alive": false,
		"moment_id": "", "miniboss_live": false, "stage": 1,
	}
	_t.eq("arbiter stage fallback", MusicArbiter.resolve(base)["owner"], MusicArbiter.OWNER_STAGE)
	_t.eq("arbiter moment beats stage", MusicArbiter.resolve(base.merged({"moment_id": "moss-shop"}, true))["owner"], MusicArbiter.OWNER_MOMENT)
	_t.eq("arbiter champion beats moment", MusicArbiter.resolve(base.merged({"moment_id": "moss-shop", "champion_alive": true}, true))["owner"], MusicArbiter.OWNER_CHAMPION)
	_t.eq("arbiter radio beats champion", MusicArbiter.resolve(base.merged({"champion_alive": true, "radio_hold": "roam-1-1"}, true))["owner"], MusicArbiter.OWNER_RADIO)
	_t.eq("arbiter ult beats radio", MusicArbiter.resolve(base.merged({"radio_hold": "roam-1-1", "ult_flight": true}, true))["owner"], MusicArbiter.OWNER_ULT)
	_t.eq("arbiter warden beats champion and ult", MusicArbiter.resolve(base.merged({"champion_alive": true, "ult_flight": true, "warden_fighting": true}, true))["owner"], MusicArbiter.OWNER_WARDEN)
	_t.eq("arbiter pinned radio beats warden", MusicArbiter.resolve(base.merged({"warden_fighting": true, "radio_hold": "roam-1-1", "radio_pinned": true}, true))["owner"], MusicArbiter.OWNER_RADIO)
	_t.eq("arbiter boss beats unpinned radio", MusicArbiter.resolve(base.merged({"boss_active": true, "radio_hold": "roam-1-1", "radio_pinned": false}, true))["owner"], MusicArbiter.OWNER_BOSS)
	_t.eq("arbiter pinned radio beats boss before finale", MusicArbiter.resolve(base.merged({"boss_active": true, "radio_hold": "roam-1-1", "radio_pinned": true}, true))["owner"], MusicArbiter.OWNER_RADIO)
	_t.eq("arbiter boss finale beats pinned radio", MusicArbiter.resolve(base.merged({"boss_active": true, "boss_finale": true, "radio_hold": "roam-1-1", "radio_pinned": true}, true))["owner"], MusicArbiter.OWNER_BOSS_FINALE)
	_t.eq("arbiter dead beats everything", MusicArbiter.resolve(base.merged({"flow": "dead", "boss_active": true, "boss_finale": true, "radio_hold": "roam-1-1", "radio_pinned": true}, true))["owner"], MusicArbiter.OWNER_DEAD)


func _test_melody_lease_and_trim_epochs() -> void:
	var lease := MelodyLease.new()
	var ep := lease.book("set_answer_a", 1000)
	_t.check("lease blocks preemption while clear", not lease.should_preempt({
		"clock_samples": 1050, "bar_samples": 400, "allowed": true, "warning": false, "busy": false,
		"ace_mode": "level", "ace_section": "travel", "pending_section": "",
	}))
	_t.check("lease preempts on warning", lease.should_preempt({
		"clock_samples": 1050, "bar_samples": 400, "allowed": true, "warning": true, "busy": false,
		"ace_mode": "level", "ace_section": "travel", "pending_section": "",
	}))
	_t.check("lease preempts on directed section", lease.should_preempt({
		"clock_samples": 1050, "bar_samples": 400, "allowed": true, "warning": false, "busy": false,
		"ace_mode": "warden", "ace_section": "drop", "pending_section": "",
	}))
	_t.eq("lease release returns id and bumps epoch", lease.release(), "set_answer_a")
	_t.check("epoch advances after release", lease.epoch > ep)

	var ace := AceSequencer.new()
	ace.mode = "level"
	ace.section = "travel"
	var stale_epoch := ace.trim_epoch
	ace.trim_bar(ace.clock + 200, {"other": 0.25}, 400, 20, 0.8, stale_epoch)
	ace.invalidate_trims(20)
	ace._run({"type": "trim", "trims": {"other": 0.25}, "frames": 20, "epoch": stale_epoch})
	ace._run({"type": "sweep", "depth": 0.8, "frames": 100, "epoch": stale_epoch})
	_t.eq("stale epoch trim does not dim stems", ace.trims, {})
	_t.eq("stale epoch sweep does not engage filter", ace.sweep, 0.0)


func _test_sfx_budget_protects_threats() -> void:
	var budget := SfxBudget.new()
	var playing := {}
	var is_playing := func(id: int) -> bool: return playing.has(id)
	var next_id := 1
	for i in 10:
		var ev := budget.reserve("threat", is_playing)
		_t.eq("nothing steals a threat voice (%d)" % i, ev, [])
		var id := next_id
		next_id += 1
		playing[id] = true
		budget.record("threat", id)
	for i in 30:
		var cls := SfxBudget.voice_class("shot_fired" if i % 2 == 0 else "scrap_collected", false, "SFX")
		for ev in budget.reserve(cls, is_playing):
			playing.erase(ev)
		var id := next_id
		next_id += 1
		playing[id] = true
		budget.record(cls, id)
	_t.eq("all 10 threat voices survive player and reward flood", budget.live_ids("threat").size(), 10)
	_t.check("every threat id stays playing", range(1, 11).all(func(id): return playing.has(id)))
	_t.check("player and reward stay capped at 20 leaving headroom under 32",
		budget.live_ids("player").size() <= 12 and budget.live_ids("reward").size() <= 8 and playing.size() <= 30,
		"live=%d" % playing.size())


func _test_champion_yields_to_warden() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var flow: FakeFlow = rig["flow"]
	var audio: Audio = rig["audio"]
	var elite := FakeElite.new()
	events.enemy_spawned.emit(elite, "elite_brute")
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("champion starts flat champion pack", audio.ace_playing() and audio.ace.flat and "champion" in audio._ace_from, audio._ace_from)
	flow.sealed = true
	events.warden_engaged.emit(1)
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("warden replaces flat champion pack with sectioned stage pack",
		audio.ace_playing() and not audio.ace.flat and audio.ace.mode == "warden",
		"from=%s flat=%s mode=%s" % [audio._ace_from, str(audio.ace.flat if audio.ace != null else null), audio.ace.mode if audio.ace != null else "null"])
	var drop_at: int = audio.ace.follow_guard(85.0, false, true) if audio.ace != null else -1
	_t.check("warden follow_guard books a drop after champion preemption", drop_at >= 0, "drop_at=%d" % drop_at)
	elite.died.emit(Vector3.ZERO, 10)
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("champion dying mid-warden keeps warden pack and mode",
		audio.ace_playing() and not audio.ace.flat and audio.ace.mode == "warden",
		"from=%s mode=%s" % [audio._ace_from, audio.ace.mode if audio.ace != null else "null"])
	_free_rig(rig, [elite])


func _test_boss_radio_record_on_stage_returns_to_stage() -> void:
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var spun := audio.radio_play("boss-brindle", "boss-brindle", false)
	_t.check("boss-backed radio record plays on stage 1", spun and audio.radio_hold == "boss-brindle")
	_pump(audio, audio.engine.bar_len())
	audio.radio_release()
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("releasing boss-backed radio record on stage 1 returns to stage 1 roam, never boss arena",
		audio.radio_hold == "" and audio.engine.track == "level" and "spillway" in audio._ace_from and audio._boss_arena_track == "",
		"track=%s from=%s boss_track=%s" % [audio.engine.track, audio._ace_from, audio._boss_arena_track])
	_free_rig(rig)


func _test_boss_phase2_radio_unpin_restores_phase2() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var flow: FakeFlow = rig["flow"]
	var audio: Audio = rig["audio"]
	flow.state = "boss"
	events.flow_changed.emit("boss")
	events.boss_arena_entered.emit()
	_pump(audio, audio.engine.bar_len() * 2)
	audio._on_boss_phase_with(2)
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("boss phase 2 active before radio pin", "heavy" in audio._ace_from or "furnace" in audio._ace_from, audio._ace_from)
	audio.radio_play("roam-1-1", "roam-1-1", true)
	_pump(audio, audio.engine.bar_len())
	audio.radio_release()
	_pump(audio, audio.engine.bar_len() * 3)
	_t.check("unpinning radio in boss phase 2 restores phase 2 music and brindle track",
		audio.radio_hold == "" and audio.engine.track == "brindle" and ("heavy" in audio._ace_from or "furnace" in audio._ace_from),
		"track=%s from=%s" % [audio.engine.track, audio._ace_from])
	_free_rig(rig)


func _test_boss_finale_beats_mid_arena_radio_pin() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var flow: FakeFlow = rig["flow"]
	var audio: Audio = rig["audio"]
	flow.state = "boss"
	events.flow_changed.emit("boss")
	events.boss_arena_entered.emit()
	_pump(audio, audio.engine.bar_len() * 2)
	_t.eq("boss arena starts brindle", audio.engine.track, "brindle")
	var spun := audio.radio_play("roam-1-1", "roam-1-1", true)
	_t.check("radio pins mid-boss arena", spun and audio.radio_hold == "roam-1-1" and audio.radio_pinned)
	_pump(audio, audio.engine.bar_len())
	var plan := audio.phase_music(3)
	_pump(audio, audio.engine.bar_len() * 3)
	_t.check("boss phase 3 finale takes air over mid-arena radio pin",
		audio.radio_hold == "" and audio.radio_finale and audio.engine.track == "brindle" and not plan.is_empty() and "brindle" in audio._ace_from,
		"radio_hold=%s radio_finale=%s track=%s plan=%s from=%s" % [audio.radio_hold, str(audio.radio_finale), audio.engine.track, str(plan), audio._ace_from])
	_t.check("finale refuses subsequent radio_play in boss arena", not audio.radio_play("roam-1-1", "roam-1-1", true))
	_free_rig(rig)


func _test_boss_radio_unpin_restores_boss() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var flow: FakeFlow = rig["flow"]
	var audio: Audio = rig["audio"]
	flow.state = "boss"
	events.flow_changed.emit("boss")
	events.boss_arena_entered.emit()
	_pump(audio, audio.engine.bar_len() * 2)
	audio.radio_play("roam-1-1", "roam-1-1", true)
	_pump(audio, audio.engine.bar_len())
	audio.radio_release()
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("unpinning radio in boss arena restores boss track and pack",
		audio.radio_hold == "" and audio.engine.track == "brindle" and "brindle" in audio._ace_from,
		"track=%s from=%s" % [audio.engine.track, audio._ace_from])
	_free_rig(rig)


func _test_ultimate_and_radio_restore_live_champion() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var audio: Audio = rig["audio"]
	var elite := FakeElite.new()
	events.enemy_spawned.emit(elite, "elite_brute")
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("champion pack active before ultimate", "champion" in audio._ace_from, audio._ace_from)
	events.ultimate_started.emit("arc_slam", "dive", Vector3.ZERO, Vector3.ZERO, 1.0)
	_pump(audio, audio.engine.beat_len() * 2)
	events.ultimate_landed.emit("arc_slam", Vector3.ZERO, 1, 10.0)
	_pump(audio, audio.engine.bar_len() * 6)
	_t.check("ultimate landing restores live champion pack",
		audio.ace_playing() and "champion" in audio._ace_from,
		"playing=%s from=%s" % [str(audio.ace_playing()), audio._ace_from])
	audio.radio_play("roam-1-1", "roam-1-1", false)
	_pump(audio, audio.engine.bar_len())
	audio.radio_release()
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("radio release restores live champion pack",
		audio.ace_playing() and "champion" in audio._ace_from,
		"playing=%s from=%s" % [str(audio.ace_playing()), audio._ace_from])
	_free_rig(rig, [elite])


func _test_death_clears_ultimate_flight() -> void:
	var rig := _make_rig()
	var events: GameEvents = rig["events"]
	var audio: Audio = rig["audio"]
	events.ultimate_started.emit("arc_slam", "dive", Vector3.ZERO, Vector3.ZERO, 1.0)
	_t.check("ultimate arms flight before death", audio._ult_armed and audio._ult_took_band)
	events.player_died.emit()
	audio._flush_flow()
	_t.check("death clears ultimate flight flags",
		not audio._ult_armed and not audio._ult_took_band,
		"armed=%s took_band=%s" % [str(audio._ult_armed), str(audio._ult_took_band)])
	_free_rig(rig)


func _test_drop_set_answer_safe_when_ace_null() -> void:
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	audio.ace = null
	audio._set_answer = "set_answer_probe"
	audio._drop_set_answer()
	_t.eq("drop_set_answer clears answer when ace is null", audio._set_answer, "")
	_free_rig(rig)
