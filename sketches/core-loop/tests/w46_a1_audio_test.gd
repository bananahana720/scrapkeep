extends SceneTree

const Audio := preload("res://src/presentation/audio.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Rows := preload("res://src/presentation/rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Foreman := preload("res://src/combat/foreman.gd")
const CampHub := preload("res://src/world/camp_hub.gd")
const SoundEdges := preload("res://tests/sound_edges_test.gd")
const AceStub := preload("res://tests/support/ace_stub.gd")
const T := preload("res://tests/support/t.gd")

# W46-A1 focused audio suite covering:
# 1) Camp freed-pilot babble voices through Audio.call_in (quiet on null/unready/busy/telegraph)
# 2) Foreman's Kindness sterile on-the-grid chime (kindness_offered -> kindness_chime, no telegraph overlap)
# 3) Own sounds for Wave 46 C2/C3 events (sluice_warning, sluice_open, quick_sync, shift_over) + Foreman emits
# 4) Brindle phase-turn clash beat & +10/+20 BPM anthem sync
# 5) Warden form on both the synth band and Brindle (respecting WARDEN_FORM_KEY and radio pin)
# 6) Audio.reset_for_tests() setting SfxBank.bake_cancel = true before waiting and clearing it after


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
	var run_id := "w46_a1_test"
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


class FakeChaser extends Node3D:
	var kind := "chaser"
	var dead := false
	var rallied := false

	func is_dead() -> bool:
		return dead

	func can_rally() -> bool:
		return not dead

	func rally_to(_slot: Vector3, _dur: float) -> bool:
		rallied = true
		return true

	func react(_kind: String, _dir: Vector3, _a: bool, _b: bool) -> void:
		pass

	func cancel_rally() -> void:
		pass


class FakeTarget extends Node3D:
	func ball_position() -> Vector3:
		return global_position


class FakeFleet extends Node:
	var ctx
	var combat = null
	var discovered: Array = []

	func discover(id: String, at: Vector3) -> void:
		discovered.append([id, at])


class FakeCampGame extends RefCounted:
	var _audio_ref

	func _init(a) -> void:
		_audio_ref = a

	func audio():
		return _audio_ref


class FakeCampBall extends RefCounted:
	func ball_position() -> Vector3:
		return Vector3(0.0, 0.0, 5.0)


var _t := T.new("w46_a1_audio_test")
var _prev_stem_dir := ""


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_prev_stem_dir = MusicRows.stem_dir
	AceStub.install()
	_test_camp_pilot_babble()
	_test_kindness_chime()
	_test_w46_own_sounds_and_foreman()
	_test_brindle_phase_clash_and_anthem()
	_test_warden_form_synth_and_brindle()
	_test_reset_for_tests_cancels_bake()
	MusicRows.stem_dir = _prev_stem_dir
	quit(_t.verdict())


func _make_rig(music_mode := "synth", warden_form := "form") -> Dictionary:
	var events := GameEvents.new()
	var flow := FakeFlow.new()
	var run := FakeRun.new()
	var tuning := Tuning.new()
	tuning.set_option(Tuning.MUSIC_KEY, music_mode)
	tuning.set_option(Tuning.WARDEN_FORM_KEY, warden_form)
	var ctx := FakeCtx.new()
	ctx.events = events
	ctx.flow = flow
	ctx.run = run
	ctx.tuning = tuning
	var audio := Audio.new()
	audio.setup(ctx)
	audio.pack_available = func(_id: String) -> bool: return music_mode == "ace"
	audio.tune_available = func(_id: String) -> bool: return music_mode == "ace"
	audio.bake_now()
	events.run_started.emit("rivet")
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


func _test_camp_pilot_babble() -> void:
	var rig := _make_rig("synth", "form")
	var audio: Audio = rig["audio"]
	audio.cue_log.clear()
	audio._last_start.clear()

	# CampHub._quip_from wires pilot_quipped to audio.call_in("camp_quip", speaker, words).
	var hub := CampHub.new()
	root.add_child(hub)
	var hub_root := Node3D.new()
	var fig := Node3D.new()
	hub_root.add_child(fig)
	root.add_child(hub_root)
	hub.root = hub_root
	hub.ball = FakeCampBall.new()
	hub.game = FakeCampGame.new(audio)
	hub.walking = true
	hub._crew["runner_gunner"] = fig
	var quipped: Array = []
	hub.pilot_quipped.connect(func(speaker: String, row_id: String, words: String): quipped.append([speaker, row_id, words]))
	hub._quip_from("runner_gunner")
	var camp_calls: Array = audio.cue_log.filter(func(e: Array): return e[0] == "camp_quip" and e[2] == "call")
	_t.check("camp _quip_from emits pilot_quipped and calls audio.call_in",
		quipped.size() == 1 and quipped[0][0] == "rivet" and camp_calls.size() == 1 and camp_calls[0][1] == "babble",
		"quipped=%s calls=%s" % [str(quipped), str(camp_calls)])

	# Active caller blocks a second camp quip (one voice at a time).
	var blocked_caller: float = audio.call_in("camp_quip", "kest", "Hold steady.")
	_t.eq("camp quip never interrupts an active caller", blocked_caller, 0.0)

	# Advance past the first call, then raise telegraph focus: camp quip must not interrupt a telegraph.
	audio.clock += 30.0
	audio._focus()
	var blocked_tele: float = audio.call_in("camp_quip", "sable", "Eyes up.")
	_t.eq("camp quip never interrupts an active telegraph cue", blocked_tele, 0.0)

	# Clear focus, confirm unready/headless audio stays silent cleanly.
	audio._focus_until = -1.0
	audio.sound_ready = false
	var unready: float = audio.call_in("camp_quip", "sable", "Eyes up.")
	_t.eq("camp quip stays silent when audio is not ready", unready, 0.0)

	# Null audio on CampHub stays silent without crashing.
	hub.game = FakeCampGame.new(null)
	hub._quipped.clear()
	hub._quip_from("runner_gunner")
	_t.eq("camp _quip_from handles null audio cleanly", quipped.size(), 2)

	var turn = fig.get_meta("turn") if fig.has_meta("turn") else null
	if turn is Tween and (turn as Tween).is_valid():
		(turn as Tween).kill()
	hub_root.free()
	hub.free()
	_free_rig(rig)


func _test_kindness_chime() -> void:
	var row := EventKinds.world_row("kindness_offered")
	_t.check("kindness_offered row exists in WORLD_ROWS and hears kindness_chime",
		not row.is_empty() and Rows.heard(row) == "kindness_chime", str(row))
	_t.check("kindness_chime has recipe, trim, keyed, not danger, clean edges",
		SfxBank.has_recipe("kindness_chime") and SfxBank.plays_own("kindness_chime")
		and SfxBank.TRIM_DB.has("kindness_chime") and "kindness_chime" in SfxBank.KEYED_SOUNDS
		and not "kindness_chime" in SfxBank.DANGER_SOUNDS
		and SoundEdges.faults(SfxBank.samples("kindness_chime")).is_empty())

	var rig := _make_rig("synth", "form")
	var events: GameEvents = rig["events"]
	var audio: Audio = rig["audio"]
	audio.cue_log.clear()
	audio._last_start.clear()
	events.world_fact.emit("kindness_offered", Vector3.ZERO)
	var chimes: Array = audio.cue_log.filter(func(e: Array): return e[1] == "kindness_chime")
	var at: int = int(chimes[0][3]) if chimes.size() == 1 else -1
	var unit: int = audio.grid_unit(4)
	_t.check("kindness_offered schedules kindness_chime quantized onto next_grid(4)",
		chimes.size() == 1 and chimes[0][2] == "grid" and posmod(at - audio.next_grid(4), unit) == 0,
		"chimes=%s unit=%d" % [str(chimes), unit])

	# Never overlaps an active telegraph cue: defers to the first sixteenth after focus clears.
	audio.cue_log.clear()
	audio._last_start.clear()
	audio._focus()
	var focus_end_sample: int = audio.engine.clock + ceili((audio._focus_until - audio.clock) * Harmony.RATE)
	events.world_fact.emit("kindness_offered", Vector3.ZERO)
	var deferred: Array = audio.cue_log.filter(func(e: Array): return e[1] == "kindness_chime")
	var def_at: int = int(deferred[0][3]) if deferred.size() == 1 else -1
	_t.check("kindness_offered defers past active telegraph focus onto the grid",
		deferred.size() == 1 and deferred[0][2] == "grid" and def_at >= focus_end_sample and posmod(def_at - audio.next_grid(4), unit) == 0,
		"deferred=%s focus_end=%d" % [str(deferred), focus_end_sample])
	_free_rig(rig)


func _test_w46_own_sounds_and_foreman() -> void:
	for id in ["sluice_valve_warning", "sluice_valve_open", "quick_sync_horn", "shift_over_sigh"]:
		var buf := SfxBank.samples(id)
		_t.check("%s has own clean recipe" % id,
			SfxBank.has_recipe(id) and SfxBank.plays_own(id) and SfxBank.TRIM_DB.has(id)
			and SoundEdges.faults(buf).is_empty(), str(SoundEdges.faults(buf)))
	_t.eq("sluice_warning hears sluice_valve_warning", Rows.heard(EventKinds.world_row("sluice_warning")), "sluice_valve_warning")
	_t.eq("sluice_open hears sluice_valve_open", Rows.heard(EventKinds.world_row("sluice_open")), "sluice_valve_open")
	_t.check("sluice_valve_warning is a danger sound distinct from arena_wave_whistle",
		"sluice_valve_warning" in SfxBank.DANGER_SOUNDS
		and SfxBank.samples("sluice_valve_warning") != SfxBank.samples("arena_wave_whistle"))
	_t.check("sluice_valve_open has slam gap parity and differs from arena_lock_slam",
		MixRows.MIN_GAP_MS.has("sluice_valve_open") and "sluice_valve_open" in SfxBank.LANDINGS
		and SfxBank.samples("sluice_valve_open") != SfxBank.samples("arena_lock_slam"))

	# Foreman emits world_fact("quick_sync") on _snap_formation and world_fact("shift_over") on _die with standing crew.
	var rig := _make_rig("synth", "form")
	var events: GameEvents = rig["events"]
	var audio: Audio = rig["audio"]
	var facts: Array = []
	events.world_fact.connect(func(kind: String, _at: Vector3): facts.append(kind))

	var world := Node3D.new()
	root.add_child(world)
	var fleet := FakeFleet.new()
	fleet.ctx = rig["ctx"]
	world.add_child(fleet)
	var target := FakeTarget.new()
	target.position = Vector3(0.0, 0.0, -8.0)
	world.add_child(target)
	var chaser := FakeChaser.new()
	chaser.position = Vector3(2.0, 0.0, -2.0)
	chaser.add_to_group("enemy")
	world.add_child(chaser)
	var foreman := Foreman.new()
	foreman.spec = {"fleet": fleet}
	foreman.target = target
	foreman.world_root = world
	foreman.crew = [chaser]
	world.add_child(foreman)

	audio.cue_log.clear()
	audio._last_start.clear()
	foreman._snap_formation()
	_t.check("Foreman _snap_formation emits quick_sync world_fact and plays quick_sync_horn",
		"quick_sync" in facts and audio.cue_log.any(func(e: Array): return e[1] == "quick_sync_horn" and e[2] == "now"),
		"facts=%s cues=%s" % [str(facts), str(audio.cue_log)])

	audio.cue_log.clear()
	audio._last_start.clear()
	foreman._die()
	_t.check("Foreman _die with standing crew emits shift_over world_fact and plays shift_over_sigh",
		"shift_over" in facts and audio.cue_log.any(func(e: Array): return e[1] == "shift_over_sigh" and e[2] == "now"),
		"facts=%s cues=%s" % [str(facts), str(audio.cue_log)])

	_free_rig(rig, [world])


func _test_brindle_phase_clash_and_anthem() -> void:
	# ACE anthem sync: phase 2 (+10 BPM) and phase 3 (+20 BPM) clash beats land on exact anthem drop samples.
	var rig := _make_rig("ace", "form")
	var events: GameEvents = rig["events"]
	var flow: FakeFlow = rig["flow"]
	var audio: Audio = rig["audio"]
	flow.state = "boss"
	events.flow_changed.emit("boss")
	events.boss_arena_entered.emit()
	_pump(audio, audio.engine.bar_len() * 2)
	_t.check("boss arena opens on Brindle ACE anthem", audio.ace_playing() and audio.engine.track == "brindle")

	audio.cue_log.clear()
	audio._on_boss_phase_with(2)
	var p2_music: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_music" and e[1] == "anthem-brindle-heavy")
	var p2_clash: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_changed")
	_t.check("Brindle phase 2 clash beat locks onto +10 BPM anthem drop sample",
		p2_music.size() == 1 and p2_clash.size() == 1 and int(p2_clash[0][3]) == int(p2_music[0][3]),
		"music=%s clash=%s" % [str(p2_music), str(p2_clash)])
	_pump(audio, audio.engine.bar_len() * 2)

	audio.cue_log.clear()
	audio._on_boss_phase_with(3)
	var p3_hype: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_music" and e[1] == "hype_drop")
	var p3_music: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_music" and e[1] == "anthem-brindle-heavier")
	var p3_clash: Array = audio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_changed")
	_t.check("Brindle phase 3 clash beat locks onto +20 BPM anthem drop sample after 2s hype_drop",
		p3_hype.size() == 1 and p3_music.size() == 1 and p3_clash.size() == 1
		and int(p3_music[0][3]) - int(p3_hype[0][3]) == roundi(2.0 * Harmony.RATE)
		and int(p3_clash[0][3]) == int(p3_music[0][3]),
		"hype=%s music=%s clash=%s" % [str(p3_hype), str(p3_music), str(p3_clash)])
	_free_rig(rig)

	# Synth-only fallback: clash lands on engine.next_beat() with engine.set_brindle_phase.
	var srig := _make_rig("synth", "form")
	var sevents: GameEvents = srig["events"]
	var sflow: FakeFlow = srig["flow"]
	var saudio: Audio = srig["audio"]
	sflow.state = "boss"
	sevents.flow_changed.emit("boss")
	sevents.boss_arena_entered.emit()
	_pump(saudio, saudio.engine.bar_len() * 2)
	saudio.cue_log.clear()
	var want_beat: int = saudio.engine.next_beat()
	saudio._on_boss_phase_with(2)
	var sclash: Array = saudio.cue_log.filter(func(e: Array): return e[0] == "boss_phase_changed")
	_t.check("Brindle synth phase 2 clash lands on next beat",
		sclash.size() == 1 and int(sclash[0][3]) == want_beat, "clash=%s want=%d" % [str(sclash), want_beat])
	_free_rig(srig)


func _test_warden_form_synth_and_brindle() -> void:
	# 1) Synth Warden form: tight build -> stagger open + hold_dominant -> chunk shatter drop.
	var wrig := _make_rig("synth", "form")
	var wevents: GameEvents = wrig["events"]
	var wflow: FakeFlow = wrig["flow"]
	var waudio: Audio = wrig["audio"]
	var warden := FakeGuard.new()
	root.add_child(warden)
	wflow.sealed = true
	wflow.warden = warden
	wevents.warden_engaged.emit(1)
	_pump(waudio, waudio.engine.bar_len() * 2)
	_t.eq("synth warden fight starts warden track", waudio.engine.track, "warden")

	wevents.posture_changed.emit(warden, 75.0, false)
	_t.check("synth warden tight build engages build", waudio.engine.building() and waudio._synth_form_state == "telegraph",
		"building=%s state=%s" % [str(waudio.engine.building()), waudio._synth_form_state])
	wevents.posture_changed.emit(warden, 100.0, true)
	_t.check("synth warden stagger holds breath (open + dominant)",
		waudio.engine.section == "open" and waudio.engine._dominant_held and waudio._synth_form_state == "open",
		"section=%s dom=%s state=%s" % [waudio.engine.section, str(waudio.engine._dominant_held), waudio._synth_form_state])
	waudio.cue_log.clear()
	warden._chunks = 3
	wevents.posture_changed.emit(warden, 10.0, false)
	var wdrops: Array = waudio.cue_log.filter(func(e: Array): return e[0] == "warden_form")
	_pump(waudio, waudio.engine.beat_len() + 64)
	_t.check("synth warden chunk shatter lands drop and releases dominant hold",
		wdrops.size() == 1 and waudio.engine.in_drop() and not waudio.engine._dominant_held,
		"drops=%s in_drop=%s dom=%s" % [str(wdrops), str(waudio.engine.in_drop()), str(waudio.engine._dominant_held)])

	# Loop mode disables synth warden form.
	wrig["tuning"].set_option(Tuning.WARDEN_FORM_KEY, "loop")
	waudio.cue_log.clear()
	warden._chunks = 2
	wevents.posture_changed.emit(warden, 80.0, false)
	_t.check("loop mode suppresses synth warden form drops",
		waudio.cue_log.filter(func(e: Array): return e[0] == "warden_form").is_empty() and waudio._synth_form_state == "closed")
	_free_rig(wrig, [warden])

	# 2) Brindle form on synth AND ACE, respecting radio pin.
	for mode in ["synth", "ace"]:
		var brig := _make_rig(mode, "form")
		var bevents: GameEvents = brig["events"]
		var bflow: FakeFlow = brig["flow"]
		var baudio: Audio = brig["audio"]
		var brindle := FakeGuard.new()
		brindle.boss = true
		root.add_child(brindle)
		bflow.state = "boss"
		bevents.flow_changed.emit("boss")
		bevents.boss_arena_entered.emit()
		_pump(baudio, baudio.engine.bar_len() * 2)
		_t.eq("%s brindle arena starts brindle track" % mode, baudio.engine.track, "brindle")

		bevents.posture_changed.emit(brindle, 80.0, false)
		_t.check("%s brindle tight build moves form to telegraph" % mode,
			baudio._synth_form_state == "telegraph" and baudio.engine.building(),
			"state=%s building=%s" % [baudio._synth_form_state, str(baudio.engine.building())])
		bevents.posture_changed.emit(brindle, 100.0, true)
		_t.check("%s brindle stagger holds dominant breath without leaving brindle" % mode,
			baudio.engine._dominant_held and baudio.engine.track == "brindle" and baudio.engine.section == "1",
			"dom=%s track=%s sec=%s" % [str(baudio.engine._dominant_held), baudio.engine.track, baudio.engine.section])
		baudio.cue_log.clear()
		brindle._chunks = 3
		bevents.posture_changed.emit(brindle, 15.0, false)
		var bdrops: Array = baudio.cue_log.filter(func(e: Array): return e[0] == "warden_form")
		_pump(baudio, baudio.engine.beat_len() + 64)
		_t.check("%s brindle chunk shatter lands warden_form drop while staying on brindle phase 1" % mode,
			bdrops.size() == 1 and baudio.engine.track == "brindle" and baudio.engine.section == "1" and not baudio.engine._dominant_held,
			"drops=%s track=%s sec=%s" % [str(bdrops), baudio.engine.track, baudio.engine.section])

		# Pinned radio blocks form changes (preserves BossMusicInArena / DeckObeysArbiter).
		baudio.radio_play("roam-1-1", "roam-1-1", true)
		baudio.cue_log.clear()
		brindle._chunks = 2
		bevents.posture_changed.emit(brindle, 20.0, false)
		_t.check("%s brindle form respects pinned radio" % mode,
			baudio.cue_log.filter(func(e: Array): return e[0] == "warden_form").is_empty() and baudio.radio_hold == "roam-1-1")
		_free_rig(brig, [brindle])


func _test_reset_for_tests_cancels_bake() -> void:
	var saw_cancel := [false]
	var started := Semaphore.new()
	SfxBank.bake_cancel = false
	Audio._baked = true
	Audio._bake_done = true
	Audio._bake_task = WorkerThreadPool.add_task(func() -> void:
		started.post()
		var spins := 0
		while not SfxBank.bake_cancel and spins < 5000000:
			spins += 1
		saw_cancel[0] = SfxBank.bake_cancel
	, false, "w46_a1_cancel_probe")
	started.wait()
	Audio.reset_for_tests()
	_t.check("Audio.reset_for_tests sets SfxBank.bake_cancel before waiting and clears it after",
		saw_cancel[0] and not SfxBank.bake_cancel and not Audio._baked and not Audio._bake_done
		and Audio._bake_task == -1 and Audio._rest_task == -1 and Audio._opening_task == -1,
		"saw_cancel=%s bake_cancel=%s" % [str(saw_cancel[0]), str(SfxBank.bake_cancel)])
