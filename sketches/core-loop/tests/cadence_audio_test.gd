extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const SfxBudget := preload("res://src/presentation/sfx_budget.gd")
const MusicArbiter := preload("res://src/presentation/music_arbiter.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const SoundEdges := preload("res://tests/sound_edges_test.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const T := preload("res://tests/support/t.gd")

# W46 E3-04 focused audio suite:
# 1) All 17 cadence, Nixie rail, and site-flip recipes exist, bake distinct buffers, have clean
#    edges, stay under -1.5 dBTP, and stay off DANGER_SOUNDS / STINGER_BEATS.
# 2) All 6 pilots' weapon cadence state transitions drive their dedicated player-class cues.
# 3) Nixie tube rail posts >= 3 s -> rail_rise (UI), sub-3 s flash stays quiet, expiry -> rail_sink (UI).
# 4) Visited-site flip chime fires once per site key across activities, rescues, gate pips, rogues,
#    and SiteMarkers.visited_sites().
# 5) Voice-class & SoundArbiter isolation: cadence cues are "player", rail/flip are "ui", none ever
#    ducks/pins/owns music or steals a threat voice.
# 6) Audit A Note #4: _boss_phase & _phase_music_done reset across retry/new-run/defeat and
#    _on_boss_phase_with(1) never leaks a prior attempt's phase.
# 7) Opt-in --voice=tts|synth sidecar loader: default synth, missing-dir fallback with zero errors,
#    valid 44.1 kHz 16-bit mono WAV load for non-Cannon callers, missing-line synth fallback,
#    Cannon ALWAYS stays procedural synth chime even when listed in manifest.json.

const CADENCE_CUES := [
	"cadence_rivet_notch_open", "cadence_rivet_notch_hit", "cadence_rivet_spent",
	"cadence_sable_full", "cadence_sable_bolt",
	"cadence_kest_window", "cadence_kest_snap",
	"cadence_tarn_window", "cadence_tarn_rend",
	"cadence_tally_beat", "cadence_tally_paid",
	"cadence_cannon_lock", "cadence_cannon_rail", "cadence_cannon_barrage",
]
const RAIL_AND_FLIP_CUES := ["rail_rise", "rail_sink", "site_flip"]


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
	var run_id := "e304_test"
	var mass := 100.0


class FakeCombat extends RefCounted:
	var weapon_driver: WeaponDriver = null


class FakeCtx extends RefCounted:
	var events: Node
	var flow: FakeFlow
	var run: FakeRun
	var tuning: Tuning
	var buffs: BuffLedger
	var spawner: FakeCombat
	var player = null
	var stages = null
	var boss = null
	var terrain = null
	var build = null
	var root = null
	var dev := false
	var calm := true


class FakeGuard extends Node3D:
	var boss = null
	var _chunks := 4

	func fight() -> String:
		return "posture"

	func posture() -> float:
		return 80.0

	func chunks_left() -> int:
		return _chunks

	func phase_chunks_left() -> int:
		return _chunks


class FakeSiteMarkers extends RefCounted:
	var rows: Array = []

	func visited_sites() -> Array:
		return rows


class FakePresentation extends Node:
	var site_markers: Object = null


class FakeIntent extends RefCounted:
	var fire_held := false
	var fire_pressed := false
	var fire_released := false


var _t := T.new("cadence_audio_test")
var _prev_stem_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_prev_stem_dir = MusicRows.stem_dir
	AceStub.install()
	_test_recipes_and_edges()
	_test_six_pilot_cadences()
	_test_nixie_rail_clacks()
	_test_site_flip_chime()
	_test_voice_class_and_arbiter_isolation()
	_test_boss_phase_reset_hygiene()
	_test_voice_sidecar_loader()
	Audio.reset_for_tests()
	MusicRows.stem_dir = _prev_stem_dir
	quit(_t.verdict())


func _make_rig() -> Dictionary:
	var events := GameEvents.new()
	var flow := FakeFlow.new()
	var run := FakeRun.new()
	var tuning := Tuning.new()
	tuning.set_option(Tuning.MUSIC_KEY, "synth")
	var buffs := BuffLedger.new()
	var combat := FakeCombat.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = flow
	ctx.run = run
	ctx.tuning = tuning
	ctx.buffs = buffs
	ctx.spawner = combat
	var pres := FakePresentation.new()
	var markers := FakeSiteMarkers.new()
	pres.site_markers = markers
	var audio := Audio.new()
	pres.add_child(audio)
	root.add_child(pres)
	audio.setup(ctx)
	audio.bake_now()
	events.run_started.emit("rivet")
	audio._remixes = {}
	events.stage_entered.emit(1, false)
	audio._flush_flow()
	_pump(audio, audio.engine.bar_len() * 2)
	return {
		"events": events, "flow": flow, "run": run, "tuning": tuning,
		"buffs": buffs, "combat": combat, "ctx": ctx, "pres": pres,
		"markers": markers, "audio": audio,
	}


func _free_rig(rig: Dictionary, extras: Array = []) -> void:
	for n in extras:
		if is_instance_valid(n):
			(n as Node).free()
	(rig["pres"] as Node).free()
	(rig["events"] as Node).free()


func _pump(audio: Audio, frames: int) -> void:
	var until: int = audio.engine.clock + frames
	while audio.engine.clock < until:
		audio._pump(mini(4096, until - audio.engine.clock))


func _test_recipes_and_edges() -> void:
	var all_ids: Array = []
	all_ids.append_array(CADENCE_CUES)
	all_ids.append_array(RAIL_AND_FLIP_CUES)
	var seen_bufs := {}
	var bad: Array = []
	var hot: Array = []
	var ceiling := db_to_linear(-1.5)
	for id in all_ids:
		var buf := SfxBank.samples(id)
		var faults := SoundEdges.faults(buf)
		if not SfxBank.has_recipe(id) or not SfxBank.plays_own(id) or not SfxBank.TRIM_DB.has(id) or not faults.is_empty():
			bad.append("%s:%s" % [id, str(faults)])
		var trimmed_peak := Synth.peak(buf) * db_to_linear(SfxBank.trim_db(id))
		if trimmed_peak > ceiling:
			hot.append("%s:%.3f" % [id, trimmed_peak])
		if id in SfxBank.DANGER_SOUNDS or SfxBank.STINGER_BEATS.has(id):
			bad.append("%s:danger_or_stinger" % id)
		seen_bufs[buf] = id
	_t.check("all 17 E3-04 recipes exist, play own sound, have clean edges, and stay off danger/stinger tables",
		bad.is_empty() and seen_bufs.size() == all_ids.size(),
		"bad=%s distinct=%d/%d" % [str(bad), seen_bufs.size(), all_ids.size()])
	_t.check("all 17 trimmed recipes stay under -1.5 dBTP", hot.is_empty(), "hot=%s" % [hot])
	for id in CADENCE_CUES:
		_t.check("EventKinds.UI_ROWS owns %s" % id, EventKinds.UI_ROWS.has(id) and String(EventKinds.UI_ROWS[id]["sound"]) == id)
	for id in ["rail_rise", "rail_sink"]:
		_t.check("EventKinds.UI_ROWS owns %s" % id, EventKinds.UI_ROWS.has(id) and String(EventKinds.UI_ROWS[id]["sound"]) == id)
	_t.check("EventKinds.WORLD_ROWS owns site_flip", EventKinds.WORLD_ROWS.has("site_flip") and String(EventKinds.WORLD_ROWS["site_flip"]["sound"]) == "site_flip")


func _step_intent(driver: WeaponDriver, weapon: String, pattern: Resource, rate_hz: float, dt: float,
		held: bool, pressed := false, released := false, ctx: Dictionary = {}) -> Array:
	var intent := FakeIntent.new()
	intent.fire_held = held
	intent.fire_pressed = pressed
	intent.fire_released = released
	return driver.step(dt, intent, weapon, pattern, rate_hz, ctx)


func _heard_kinds(audio: Audio) -> Array:
	return audio.cue_log.filter(func(e: Array): return e.size() >= 3 and e[2] == "now").map(func(e: Array): return String(e[1]))


func _test_six_pilot_cadences() -> void:
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var combat: FakeCombat = rig["combat"]

	# 1. Rivet (press): notch open -> notch hit; plus notch open -> spent miss.
	var rivet_driver := WeaponDriver.new()
	combat.weapon_driver = rivet_driver
	var rivet_pat := Weapons.base(Weapons.RAPID_LASER)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	# Empty the 6-round drum to trigger reload.
	for i in 6:
		_step_intent(rivet_driver, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.2, true, true, false)
		_step_intent(rivet_driver, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.2, false, false, true)
		audio._tend_cadence()
	# Step into active reload notch window.
	for _s in 30:
		_step_intent(rivet_driver, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.05, false)
		audio._tend_cadence()
		if String(rivet_driver.state_snapshot().get("window", "")) == WeaponDriver.WINDOW_OPEN:
			break
	# Press inside notch for hot-round latch.
	_step_intent(rivet_driver, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.02, true, true, false)
	audio._tend_cadence()
	var rivet_heard := _heard_kinds(audio)
	_t.check("Rivet plays notch_open and notch_hit on active reload",
		"cadence_rivet_notch_open" in rivet_heard and "cadence_rivet_notch_hit" in rivet_heard,
		"heard=%s" % [rivet_heard])
	# Now miss the notch early to trigger spent clunk.
	var rivet_miss := WeaponDriver.new()
	combat.weapon_driver = rivet_miss
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	for i in 6:
		_step_intent(rivet_miss, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.2, true, true, false)
		_step_intent(rivet_miss, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.2, false, false, true)
		audio._tend_cadence()
	_step_intent(rivet_miss, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.05, false)
	audio._tend_cadence()
	_step_intent(rivet_miss, Weapons.RAPID_LASER, rivet_pat, 4.0, 0.02, true, true, false)
	audio._tend_cadence()
	_t.check("Rivet plays cadence_rivet_spent on missed notch",
		"cadence_rivet_spent" in _heard_kinds(audio), "heard=%s" % [_heard_kinds(audio)])

	# 2. Sable (tap_charge): full-charge tick + charged bolt release.
	var sable_driver := WeaponDriver.new()
	combat.weapon_driver = sable_driver
	var sable_pat := Weapons.base(Weapons.ARC_CASTER)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	_step_intent(sable_driver, Weapons.ARC_CASTER, sable_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 40:
		_step_intent(sable_driver, Weapons.ARC_CASTER, sable_pat, 2.0, 0.05, true)
		audio._tend_cadence()
		if float(sable_driver.state_snapshot().get("charge", 0.0)) >= 0.999:
			break
	_step_intent(sable_driver, Weapons.ARC_CASTER, sable_pat, 2.0, 0.02, false, false, true)
	audio._tend_cadence()
	var sable_heard := _heard_kinds(audio)
	_t.check("Sable plays cadence_sable_full and cadence_sable_bolt",
		"cadence_sable_full" in sable_heard and "cadence_sable_bolt" in sable_heard,
		"heard=%s" % [sable_heard])

	# 3. Kest (lob_snap): throw -> snap window open -> second press snap burst.
	var kest_driver := WeaponDriver.new()
	combat.weapon_driver = kest_driver
	var kest_pat := Weapons.base(Weapons.STICKY_CHARGE)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	_step_intent(kest_driver, Weapons.STICKY_CHARGE, kest_pat, 2.0, 0.02, true, true, false)
	_step_intent(kest_driver, Weapons.STICKY_CHARGE, kest_pat, 2.0, 0.02, false, false, true)
	audio._tend_cadence()
	for _s in 30:
		_step_intent(kest_driver, Weapons.STICKY_CHARGE, kest_pat, 2.0, 0.05, false)
		audio._tend_cadence()
		if String(kest_driver.state_snapshot().get("window", "")) == WeaponDriver.WINDOW_OPEN:
			break
	_step_intent(kest_driver, Weapons.STICKY_CHARGE, kest_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	var kest_heard := _heard_kinds(audio)
	_t.check("Kest plays cadence_kest_window and cadence_kest_snap",
		"cadence_kest_window" in kest_heard and "cadence_kest_snap" in kest_heard,
		"heard=%s" % [kest_heard])

	# 4. Tarn (beats): Beat 1 -> Beat 2 -> Beat 3 window open -> Beat 3 rend hit.
	var tarn_driver := WeaponDriver.new()
	combat.weapon_driver = tarn_driver
	var tarn_pat := Weapons.base(Weapons.CLAW_SWEEP)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	# Beat 1
	_step_intent(tarn_driver, Weapons.CLAW_SWEEP, tarn_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 25:
		_step_intent(tarn_driver, Weapons.CLAW_SWEEP, tarn_pat, 2.0, 0.05, false)
		audio._tend_cadence()
		if float(tarn_driver.state_snapshot().get("cooldown", 1.0)) <= 0.0:
			break
	# Beat 2
	_step_intent(tarn_driver, Weapons.CLAW_SWEEP, tarn_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 25:
		_step_intent(tarn_driver, Weapons.CLAW_SWEEP, tarn_pat, 2.0, 0.05, false)
		audio._tend_cadence()
		if String(tarn_driver.state_snapshot().get("window", "")) == WeaponDriver.WINDOW_OPEN:
			break
	# Beat 3 rend inside window
	_step_intent(tarn_driver, Weapons.CLAW_SWEEP, tarn_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	var tarn_heard := _heard_kinds(audio)
	_t.check("Tarn plays cadence_tarn_window and cadence_tarn_rend",
		"cadence_tarn_window" in tarn_heard and "cadence_tarn_rend" in tarn_heard,
		"heard=%s" % [tarn_heard])

	# 5. Tally (stamp): plain cast -> wait into beat window -> beat tick open -> PAID stamp commit.
	var tally_driver := WeaponDriver.new()
	combat.weapon_driver = tally_driver
	var tally_pat := Weapons.base(Weapons.LEDGER_READER)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	_step_intent(tally_driver, Weapons.LEDGER_READER, tally_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 25:
		_step_intent(tally_driver, Weapons.LEDGER_READER, tally_pat, 2.0, 0.05, false)
		audio._tend_cadence()
		if String(tally_driver.state_snapshot().get("window", "")) == WeaponDriver.WINDOW_OPEN:
			break
	_step_intent(tally_driver, Weapons.LEDGER_READER, tally_pat, 2.0, 0.02, true, true, false)
	audio._tend_cadence()
	var tally_heard := _heard_kinds(audio)
	_t.check("Tally plays cadence_tally_beat and cadence_tally_paid",
		"cadence_tally_beat" in tally_heard and "cadence_tally_paid" in tally_heard,
		"heard=%s" % [tally_heard])

	# 6. Cannon (lock): lock flush -> rail release; plus full hold -> barrage release.
	var cannon_driver := WeaponDriver.new()
	combat.weapon_driver = cannon_driver
	var cannon_pat := Weapons.base(Weapons.CANNON_LANE)
	audio.cue_log.clear()
	audio._cadence_prev.clear()
	audio._tend_cadence()
	_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 30:
		_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.05, true)
		audio._tend_cadence()
		if String(cannon_driver.state_snapshot().get("lock_stage", "")) == "rail":
			break
	_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.02, false, false, true)
	audio._tend_cadence()
	# Wait out recover, then paint all the way to barrage and release.
	for _s in 30:
		_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.05, false)
		audio._tend_cadence()
		if float(cannon_driver.state_snapshot().get("recover", 1.0)) <= 0.0:
			break
	_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.02, true, true, false)
	audio._tend_cadence()
	for _s in 60:
		_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.05, true)
		audio._tend_cadence()
		if String(cannon_driver.state_snapshot().get("lock_stage", "")) == "barrage":
			break
	_step_intent(cannon_driver, Weapons.CANNON_LANE, cannon_pat, 1.5, 0.02, false, false, true)
	audio._tend_cadence()
	var cannon_heard := _heard_kinds(audio)
	_t.check("Cannon plays cadence_cannon_lock, cadence_cannon_rail, and cadence_cannon_barrage",
		"cadence_cannon_lock" in cannon_heard
		and "cadence_cannon_rail" in cannon_heard
		and "cadence_cannon_barrage" in cannon_heard,
		"heard=%s" % [cannon_heard])

	_free_rig(rig)


func _test_nixie_rail_clacks() -> void:
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var buffs: BuffLedger = rig["buffs"]
	audio.cue_log.clear()

	# Short (< 3 s) flash stays off the rail and makes no relay clack.
	buffs.post("flash_short", {"duration_s": 1.5})
	_t.eq("sub-3s buff plays no rail relay clack", _heard_kinds(audio), [])

	# >= 3 s buff rises onto the rail -> rail_rise on UI bus.
	buffs.post("overdrive_test", {"duration_s": 5.0})
	_t.eq("posting a >=3s buff plays rail_rise", _heard_kinds(audio), ["rail_rise"])

	# Refreshing an already-active buff does not double-clack.
	audio.cue_log.clear()
	buffs.post("overdrive_test", {"duration_s": 5.0})
	_t.eq("refreshing an active buff does not replay rail_rise", _heard_kinds(audio), [])

	# Expiring the buff drops the rail -> rail_sink on UI bus.
	audio.cue_log.clear()
	buffs.step(6.0)
	_t.eq("expiring an active buff plays rail_sink", _heard_kinds(audio), ["rail_sink"])

	_free_rig(rig)

	# Regression (Context wiring order): buffs.bind_events(events) BEFORE audio.setup(ctx).
	# Attempt/stage/death/run clears must NEVER emit a spurious rail_sink clack; only real expiry does.
	var events := GameEvents.new()
	var flow := FakeFlow.new()
	var run := FakeRun.new()
	var tuning := Tuning.new()
	tuning.set_option(Tuning.MUSIC_KEY, "synth")
	var bound_buffs := BuffLedger.new()
	bound_buffs.bind_events(events)
	var combat := FakeCombat.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = flow
	ctx.run = run
	ctx.tuning = tuning
	ctx.buffs = bound_buffs
	ctx.spawner = combat
	var pres := FakePresentation.new()
	var bound_audio := Audio.new()
	pres.add_child(bound_audio)
	root.add_child(pres)
	bound_audio.setup(ctx)
	bound_audio.bake_now()
	events.run_started.emit("rivet")
	bound_audio._remixes = {}
	events.stage_entered.emit(1, false)
	bound_audio._flush_flow()
	_pump(bound_audio, bound_audio.engine.bar_len() * 2)

	var boundary_sinks := []
	for boundary in ["stage_content_cleared", "stage_entered", "player_died", "run_started", "run_ended"]:
		bound_buffs.post("overdrive_%s" % boundary, {"duration_s": 5.0})
		bound_audio.cue_log.clear()
		match boundary:
			"stage_content_cleared":
				events.stage_content_cleared.emit("retry")
			"stage_entered":
				events.stage_entered.emit(2, false)
			"player_died":
				events.player_died.emit()
			"run_started":
				events.run_started.emit("rivet")
			"run_ended":
				events.run_ended.emit(false)
		if "rail_sink" in _heard_kinds(bound_audio):
			boundary_sinks.append(boundary)
	_t.eq("bound BuffLedger emits 0 rail_sink clacks on retry/stage/death/run boundaries", boundary_sinks, [])

	# Real timer expiry still fires rail_sink once.
	bound_buffs.post("overdrive_expire", {"duration_s": 5.0})
	bound_audio.cue_log.clear()
	bound_buffs.step(6.0)
	_t.eq("bound BuffLedger real timer expiry plays rail_sink once", _heard_kinds(bound_audio), ["rail_sink"])

	pres.free()
	events.free()


func _test_site_flip_chime() -> void:
	# 1. Real SiteMarkers wired onto pres.site_markers: zero double-fires and cache_spent chimes.
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var events: GameEvents = rig["events"]
	var pres: FakePresentation = rig["pres"]
	var real_markers := SiteMarkers.new()
	pres.add_child(real_markers)
	real_markers.setup(rig["ctx"])
	pres.site_markers = real_markers
	audio._visited_sites_seen.clear()
	audio.cue_log.clear()

	# Cracked cache pocket activity: SiteMarkers._on_activity_done + Audio share exact key -> 1 flip.
	var pocket_at := Vector3(12.2, 0.0, -8.7)
	events.activity_done.emit("cracked_cache", pocket_at)
	audio._tend_site_flips()
	audio._tend_site_flips()
	var pocket_flips: Array = _heard_kinds(audio).filter(func(k: String): return k == "site_flip")
	_t.eq("cracked_cache pocket chimes once with real SiteMarkers", pocket_flips.size(), 1)
	# Repeat emit at same pocket is idempotent.
	audio.cue_log.clear()
	events.activity_done.emit("cracked_cache", pocket_at)
	audio._tend_site_flips()
	_t.eq("repeat cracked_cache emit at same position does not double-chime",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 0)

	# Conduit cable / warden_gate_pip: SiteMarkers owns cable:<id> -> 1 flip total.
	audio.cue_log.clear()
	events.world_fact.emit("warden_gate_pip", Vector3(20.0, 0.0, 4.0))
	real_markers.mark_visited("cable:west", "cable", Vector3(20.0, 0.0, 4.0))
	audio._tend_site_flips()
	audio._tend_site_flips()
	_t.eq("warden_gate_pip + ConduitCable mark_visited chimes once with real SiteMarkers",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 1)

	# Rogue kill: SiteMarkers._on_enemy_killed owns rogue key -> 1 flip total.
	audio.cue_log.clear()
	var rogue_kind := String(Rogue.ROWS.keys()[0])
	events.enemy_killed.emit(rogue_kind, Vector3(-15.0, 0.0, 6.0), 10)
	audio._tend_site_flips()
	audio._tend_site_flips()
	_t.eq("rogue kill chimes once with real SiteMarkers",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 1)

	# CrackedCache device world_fact("cache_spent", at): chimes once per distinct position.
	audio.cue_log.clear()
	events.world_fact.emit("cache_spent", Vector3(5.0, 0.0, 5.0))
	events.world_fact.emit("cache_spent", Vector3(5.0, 0.0, 5.0))
	events.world_fact.emit("cache_spent", Vector3(30.0, 0.0, 12.0))
	audio._tend_site_flips()
	_t.eq("CrackedCache device cache_spent chimes once per distinct position",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 2)

	# Non-cracked_cache activities with same id at distinct positions chime once per position.
	audio.cue_log.clear()
	events.activity_done.emit("pump_house", Vector3(10.0, 0.0, 0.0))
	events.activity_done.emit("pump_house", Vector3(10.0, 0.0, 0.0))
	events.activity_done.emit("pump_house", Vector3(40.0, 0.0, 0.0))
	audio._tend_site_flips()
	_t.eq("two same-id non-cracked_cache activities at distinct positions chime twice",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 2)

	# Rescue completed + SiteMarkers mark_visited on same cage key -> 1 flip total.
	audio.cue_log.clear()
	events.rescue_completed.emit("kest")
	real_markers.mark_visited("cage:kest", "cage", Vector3(0.0, 0.0, 18.0))
	audio._tend_site_flips()
	_t.eq("rescue_completed + cage SiteMarker chimes once",
		_heard_kinds(audio).filter(func(k: String): return k == "site_flip").size(), 1)

	_free_rig(rig)


func _test_voice_class_and_arbiter_isolation() -> void:
	for id in CADENCE_CUES:
		_t.eq("cadence cue %s uses player voice class" % id, SfxBudget.voice_class(id, id in SfxBank.DANGER_SOUNDS, "SFX"), "player")
	for id in RAIL_AND_FLIP_CUES:
		_t.eq("rail/flip cue %s uses ui voice class" % id, SfxBudget.voice_class(id, id in SfxBank.DANGER_SOUNDS, "UI"), "ui")

	# Threat voices are never displaced by cadence cues under SfxBudget saturation.
	var budget := SfxBudget.new()
	var playing := {}
	var threat_ids: Array = []
	var next_id := 1
	for i in int(SfxBudget.BUDGET["threat"]):
		budget.reserve("threat", func(vid: int) -> bool: return playing.has(vid))
		budget.record("threat", next_id)
		playing[next_id] = true
		threat_ids.append(next_id)
		next_id += 1
	var displaced := false
	for id in CADENCE_CUES:
		var cls := SfxBudget.voice_class(id, id in SfxBank.DANGER_SOUNDS, "SFX")
		var evicts := budget.reserve(cls, func(vid: int) -> bool: return playing.has(vid))
		for ev in evicts:
			if int(ev) in threat_ids:
				displaced = true
			playing.erase(int(ev))
		budget.record(cls, next_id)
		playing[next_id] = true
		next_id += 1
	_t.check("cadence cues never evict a threat voice", not displaced)

	# Firing every cadence/rail/flip cue never ducks music, raises focus, or alters MusicArbiter ownership.
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var track_before: String = audio.engine.track
	var arbiter_before: Dictionary = MusicArbiter.resolve(audio._arbiter_state())
	var focus_before: float = audio._focus_until
	var duck_until_before: int = audio.engine._duck_until
	var duck_target_before: float = audio.engine._duck_target
	for id in CADENCE_CUES:
		audio._play_cadence(id)
	audio._play_rail("rail_rise")
	audio._play_rail("rail_sink")
	audio._play_site_flip("test:isolation")
	_t.check("cadence/rail/flip cues never duck music, set focus, or change MusicArbiter owner",
		audio.engine.track == track_before
		and MusicArbiter.resolve(audio._arbiter_state()) == arbiter_before
		and audio._focus_until == focus_before
		and audio.engine._duck_until == duck_until_before
		and is_equal_approx(audio.engine._duck_target, duck_target_before),
		"track=%s->%s focus=%.2f->%.2f duck_until=%d->%d" % [
			track_before, audio.engine.track, focus_before, audio._focus_until, duck_until_before, audio.engine._duck_until])
	_free_rig(rig)


func _test_boss_phase_reset_hygiene() -> void:
	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	var events: GameEvents = rig["events"]
	var guard := FakeGuard.new()
	root.add_child(guard)
	rig["ctx"].boss = guard

	# Enter Brindle phase 2 then phase 3.
	events.boss_arena_entered.emit()
	_t.eq("boss_arena_entered starts _boss_phase at 1", audio._boss_phase, 1)
	events.boss_phase_changed.emit(2, "phase_2")
	events.boss_phase_changed.emit(3, "phase_3")
	_t.eq("_boss_phase reaches 3 during fight", audio._boss_phase, 3)

	# Retry clears arena and resets _boss_phase cleanly to 1.
	events.stage_content_cleared.emit("arena_retry")
	_t.check("arena_retry resets _boss_phase to 1 and _phase_music_done to 1",
		audio._boss_phase == 1 and audio._phase_music_done == 1,
		"phase=%d music_done=%d" % [audio._boss_phase, audio._phase_music_done])

	# Explicit _on_boss_phase_with(1) when _boss_phase was stale resets to 1 without emitting a clash.
	audio._boss_phase = 3
	audio.cue_log.clear()
	audio._on_boss_phase_with(1)
	var clashes: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_changed")
	_t.check("_on_boss_phase_with(1) resets stale _boss_phase to 1 without playing a clash",
		audio._boss_phase == 1 and clashes.is_empty(),
		"phase=%d clashes=%s" % [audio._boss_phase, str(clashes)])

	# Subsequent phase 2 on the fresh attempt fires cleanly.
	events.boss_phase_changed.emit(2, "phase_2")
	var p2_clashes: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_changed")
	_t.check("fresh attempt after reset fires phase 2 clash cleanly",
		audio._boss_phase == 2 and p2_clashes.size() == 1,
		"phase=%d clashes=%s" % [audio._boss_phase, str(p2_clashes)])

	# Boss defeat and run_started also reset _boss_phase and _phase_music_done.
	events.boss_defeated.emit()
	_t.check("boss_defeated resets _boss_phase to 1 and _phase_music_done to 0",
		audio._boss_phase == 1 and audio._phase_music_done == 0)
	audio._boss_phase = 3
	audio._phase_music_done = 3
	events.run_started.emit("sable")
	_t.check("run_started resets _boss_phase to 1 and _phase_music_done to 0",
		audio._boss_phase == 1 and audio._phase_music_done == 0)

	_free_rig(rig, [guard])


func _write_mono_wav(path: String, hz: float, seconds: float) -> void:
	var n := int(round(seconds * Harmony.RATE))
	var data_bytes := n * 2
	var bytes := PackedByteArray()
	bytes.resize(44 + data_bytes)
	bytes.encode_u32(0, 0x46464952) # "RIFF"
	bytes.encode_u32(4, 36 + data_bytes)
	bytes.encode_u32(8, 0x45564157) # "WAVE"
	bytes.encode_u32(12, 0x20746d66) # "fmt "
	bytes.encode_u32(16, 16)
	bytes.encode_u16(20, 1) # PCM
	bytes.encode_u16(22, 1) # mono
	bytes.encode_u32(24, Harmony.RATE)
	bytes.encode_u32(28, Harmony.RATE * 2)
	bytes.encode_u16(32, 2)
	bytes.encode_u16(34, 16)
	bytes.encode_u32(36, 0x61746164) # "data"
	bytes.encode_u32(40, data_bytes)
	for i in n:
		var env := minf(1.0, float(i) / 40.0) * minf(1.0, float(n - 1 - i) / 80.0)
		var sample := clampi(roundi(sin(TAU * hz * float(i) / Harmony.RATE) * env * 16000.0), -32768, 32767)
		bytes.encode_s16(44 + i * 2, sample)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(bytes)
	f.close()


func _remove_dir_recursive(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path.path_join(entry)
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(dir_path)


func _test_voice_sidecar_loader() -> void:
	# Default CLI parsing is strictly "synth".
	_t.eq("empty args default to synth voice mode", Audio.parse_voice_args([])["mode"], "synth")
	_t.eq("--voice=tts parses to tts mode",
		Audio.parse_voice_args(["--voice=tts"])["mode"], "tts")
	_t.eq("--voice=synth parses to synth mode",
		Audio.parse_voice_args(["--voice=synth"])["mode"], "synth")
	_t.eq("unknown --voice value falls back to synth",
		Audio.parse_voice_args(["--voice=garbage"])["mode"], "synth")

	var rig := _make_rig()
	var audio: Audio = rig["audio"]
	_t.eq("Audio defaults to synth mode", audio.voice_mode, Audio.VOICE_SYNTH)

	# Missing directory falls back cleanly to procedural synth with zero errors.
	var missing_dir := ProjectSettings.globalize_path("user://e304_missing_voice_%d" % OS.get_process_id())
	audio.set_voice_mode("tts", missing_dir)
	var line := "Eyes on the spillway."
	var synth_buf := VoiceSynth._say("sable", line)
	_t.check("--voice=tts with missing dir falls back cleanly to synth",
		not audio.voice_manifest_loaded() and audio.voice_clip_for("sable", line) == ""
		and Synth.peak(synth_buf) > 0.1)

	# Valid sidecar manifest + 44.1 kHz 16-bit mono WAV loads for non-Cannon callers,
	# falls back to synth on missing lines, and NEVER overrides Cannon.
	var tmp_dir := ProjectSettings.globalize_path("user://e304_voice_%d" % OS.get_process_id())
	DirAccess.make_dir_recursive_absolute(tmp_dir)
	var sable_wav := tmp_dir.path_join("sable_line.wav")
	var cannon_wav := tmp_dir.path_join("cannon_line.wav")
	_write_mono_wav(sable_wav, 440.0, 0.25)
	_write_mono_wav(cannon_wav, 330.0, 0.30)
	var manifest := {
		"clips": [
			{"speaker": "sable", "text": line, "file": "sable_line.wav"},
			{"speaker": "cannon", "text": line, "file": "cannon_line.wav"},
		],
	}
	var mf := FileAccess.open(tmp_dir.path_join("manifest.json"), FileAccess.WRITE)
	mf.store_string(JSON.stringify(manifest))
	mf.close()

	var cannon_synth_before := VoiceSynth._say("cannon", line)
	audio.set_voice_mode("tts", tmp_dir)
	var sable_tts_buf := VoiceSynth._say("sable", line)
	var sable_tts_dur := VoiceSynth.say_seconds("sable", line)
	var rivet_fallback_buf := VoiceSynth._say("rivet", line)
	var cannon_after := VoiceSynth._say("cannon", line)

	_t.check("--voice=tts loads matching non-Cannon WAV with exact duration",
		audio.voice_manifest_loaded()
		and audio.voice_clip_for("sable", line) == sable_wav
		and sable_tts_buf.size() == int(round(0.25 * Harmony.RATE))
		and is_equal_approx(sable_tts_dur, 0.25),
		"loaded=%s clip=%s size=%d dur=%.3f" % [str(audio.voice_manifest_loaded()), audio.voice_clip_for("sable", line), sable_tts_buf.size(), sable_tts_dur])
	_t.check("unmatched caller in --voice=tts falls back cleanly to synth",
		audio.voice_clip_for("rivet", line) == "" and Synth.peak(rivet_fallback_buf) > 0.1)
	_t.check("Cannon ALWAYS stays procedural synth chime even when listed in manifest.json",
		audio.voice_clip_for("cannon", line) == ""
		and VoiceSynth.voice_clip_path("cannon", line) == ""
		and cannon_after == cannon_synth_before)

	# Top-level JSON Array manifest (matching w46-audio/voice/manifest.json layout):
	# parent-relative "voice/<speaker>/<clip>.wav" paths, skipping audition_only: true rows.
	var arr_root := ProjectSettings.globalize_path("user://e304_voice_arr_%d" % OS.get_process_id())
	var arr_voice := arr_root.path_join("voice")
	var brindle_dir := arr_voice.path_join("brindle")
	var cannon_dir := arr_voice.path_join("cannon")
	DirAccess.make_dir_recursive_absolute(brindle_dir)
	DirAccess.make_dir_recursive_absolute(cannon_dir)
	var canonical_wav := brindle_dir.path_join("intro_dam.wav")
	var audition_wav := brindle_dir.path_join("intro_dam_alt.wav")
	var audition_only_wav := brindle_dir.path_join("audition_only.wav")
	var arr_cannon_wav := cannon_dir.path_join("cannon_line.wav")
	_write_mono_wav(canonical_wav, 300.0, 0.20)
	_write_mono_wav(audition_wav, 500.0, 0.40)
	_write_mono_wav(audition_only_wav, 600.0, 0.35)
	_write_mono_wav(arr_cannon_wav, 330.0, 0.30)
	var brindle_line := "Your repair reserve is now Fleet inventory. Thank you."
	var audition_line := "Audition take only."
	var arr_manifest := [
		{"speaker": "brindle", "text": brindle_line, "file": "voice/brindle/intro_dam.wav"},
		{"speaker": "brindle", "text": brindle_line, "file": "voice/brindle/intro_dam_alt.wav", "audition_only": true},
		{"speaker": "brindle", "text": audition_line, "file": "voice/brindle/audition_only.wav", "audition_only": true},
		{"speaker": "cannon", "text": line, "file": "voice/cannon/cannon_line.wav"},
	]
	var amf := FileAccess.open(arr_voice.path_join("manifest.json"), FileAccess.WRITE)
	amf.store_string(JSON.stringify(arr_manifest))
	amf.close()

	audio.set_voice_mode("tts", arr_voice)
	var brindle_buf := VoiceSynth._say("brindle", brindle_line)
	_t.check("top-level JSON Array manifest resolves parent-relative voice/... canonical WAV",
		audio.voice_manifest_loaded()
		and audio.voice_clip_for("brindle", brindle_line) == canonical_wav
		and brindle_buf.size() == int(round(0.20 * Harmony.RATE)),
		"loaded=%s clip=%s size=%d" % [str(audio.voice_manifest_loaded()), audio.voice_clip_for("brindle", brindle_line), brindle_buf.size()])
	_t.check("audition_only: true entries are skipped and never overwrite canonical clips",
		audio.voice_clip_for("brindle", audition_line) == ""
		and audio.voice_clip_for("brindle", brindle_line) == canonical_wav)
	_t.check("Cannon remains synth-only in top-level JSON Array manifest",
		audio.voice_clip_for("cannon", line) == ""
		and VoiceSynth.voice_clip_path("cannon", line) == "")

	# Pointing at the parent directory (arr_root, where manifest.json lives under voice/) also loads cleanly.
	audio.set_voice_mode("tts", arr_root)
	var parent_brindle_buf := VoiceSynth._say("brindle", brindle_line)
	_t.check("parent dir containing voice/manifest.json resolves canonical WAV and skips audition_only",
		audio.voice_manifest_loaded()
		and audio.voice_clip_for("brindle", brindle_line) == canonical_wav
		and parent_brindle_buf.size() == int(round(0.20 * Harmony.RATE))
		and audio.voice_clip_for("brindle", audition_line) == ""
		and audio.voice_clip_for("cannon", line) == "",
		"loaded=%s clip=%s size=%d" % [str(audio.voice_manifest_loaded()), audio.voice_clip_for("brindle", brindle_line), parent_brindle_buf.size()])

	# Switching back to synth or calling Audio.reset_for_tests() restores synth cleanly.
	audio.set_voice_mode("synth")
	_t.check("set_voice_mode('synth') restores procedural synth for Sable",
		audio.voice_clip_for("sable", line) == "" and VoiceSynth._say("sable", line) == synth_buf)

	_remove_dir_recursive(arr_root)
	_remove_dir_recursive(tmp_dir)
	_free_rig(rig)
