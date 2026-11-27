extends Node

const AppShell := preload("res://src/core/app_shell.gd")
const Activities := preload("res://src/world/activities.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const MusicEngine := preload("res://src/presentation/music_engine.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const MixRows := preload("res://src/presentation/mix_rows.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const AceSequencer := preload("res://src/presentation/ace_sequencer.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const Streak := preload("res://src/presentation/streak.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Redline := preload("res://src/combat/redline.gd")
const Augments := preload("res://src/movement/augments.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Roster := preload("res://src/combat/roster.gd")
const Rogue := preload("res://src/combat/rogue.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const Interactables := preload("res://src/world/interactables.gd")
const Companion := preload("res://src/core/companion.gd")
const SpillwayStory := preload("res://src/presentation/spillway_story.gd")
const TuneRows := preload("res://src/core/tune_rows.gd")
const TuneEar := preload("res://src/presentation/tune_ear.gd")
const SetDirector := preload("res://src/presentation/set_director.gd")
const DeckMoves := preload("res://src/presentation/deck_moves.gd")
const MusicArbiter := preload("res://src/presentation/music_arbiter.gd")
const MelodyLease := preload("res://src/presentation/melody_lease.gd")
const SfxBudget := preload("res://src/presentation/sfx_budget.gd")
const MusicDsp := preload("res://src/presentation/music_dsp.gd")
const CHIRP_COOLDOWN := 0.75
const CHIRP_LOG_CAP := 256
const LOG_CAP := 2048
const SpecialAudio := preload("res://src/presentation/special_audio.gd")
const MenuSounds := preload("res://src/presentation/menu_sounds.gd")
var _menu_sounds := MenuSounds.new()
var _specials := {}
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
var pack_available: Callable = PhaseMusic.available
var _phase_music_done := 0
var _stage_now := 0
var _champions := {}
var _champion_hyped := false
var _champion_euro := {}
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
var tune_available: Callable = TuneMoments.available
var title_available: Callable = func(row: String) -> bool: return MusicRows.pack_on_disk(MusicRows.resolve(row)["ace_manifest"])
var _moments: Array = []
var _moment_seq := 0
var _moment_playing := ""
var _remixes := {}
var _remix_rng := RandomNumberGenerator.new()
var _warden_engaged := false
var _warden_fighting := false
var specials_heard: Array = []

const SPIN_ENERGY := [0.15, 0.5, 0.9]

signal tune_heard(id: String)
signal radio_yielded(reason: String)


const BUSES := MixRows.BUS_DB
const GEN_BUFFER := 0.1
const POLYPHONY := 32
const VOICE_LIMIT := SfxBank.VOICE_LIMIT
const MIN_GAP_MS := SfxBank.MIN_GAP_MS
const PRIORITY_DB := [-6.0, -3.0, 0.0, 0.0]
signal hit_on_beat(enemy: Node3D, kind: String)
const ONBEAT_WINDOW_S := 0.08
const ONBEAT_SOUND := "onbeat_clap"
const ONBEAT_DB := -8.0
var beat_offset_hook := Callable()
var _onbeat_at := -(1 << 40)
signal skill_on_beat(kind: String, big: bool)
const SKILL_ANSWER_NOTES := 2
var _skill_answer_at := -(1 << 40)
const KILL_COMBO_WINDOW_MS := 1500
const ARMOR_SHED_BIG_FROM := 150.0
const ARMOR_SHED_FULL := 250.0
const MENU_STATES := ["title", "class_select", "summary", "dead"]
const WEAPON_PITCH := {"arc_caster": -3.0, "rapid_laser": 4.0, "claw_sweep": -5.0, "cannon_lane": -7.0,
	"gather_plate": 2.0, "link_clips": 3.0, "balance_due": 5.0}
const VOLUME_STEP := 0.1
const VAULT_KILL_SOUND := "vault_drop"

const LOCK_TICK_GAP := 0.25
const FAIL_GAP := 0.25
const DRY_TICK_GAP := 0.1
const CHAIN_STEPS := 5
const CHAIN_BITE_HOLD_S := 0.25
const CAUSE_RESOLVE_GAP := 4.0
const NOTE_SPACING := 0.14
const HUM_STATES := ["latched_world", "latched_body", "smash_committed"]
const HUM_FAR := 45.0
const HUM_NEAR := 3.0
const HUM_DB := 0.0
const THREAT_RELEASE := {"threat_lane": "threat_tear"}
const DANGER_SOUNDS := SfxBank.DANGER_SOUNDS
const LANDING_FALLBACK_MS := 2000
const LAUNCH_BUILD_SECONDS := 1.6
const KEYED_SOUNDS := SfxBank.KEYED_SOUNDS
const KEST_SOUNDS := SfxBank.KEST_SOUNDS
const LINE_CLAW_DRAG := {"sound": "line_claw_drag", "ratchet": "clank", "motif": "tarn", "step_seconds": 0.1}
var _line_claw_stream: AudioStreamWAV
const RIVET_LINE := {"punch": "rivet_line_punch", "arrive": "rivet_line_arrive", "motif": "rivet", "roll_step": 0.0625}
const POSTURE_QUARTER := 25.0
const GUARD_CRITICAL := 85.0
const GUARD_CRITICAL_REARM := 60.0
const BEACON_OPEN_DB := -4.0
const POSTURE_PHRASE := 0
const SHATTER_LOW := "chunk_low"
const EVENT_SECONDS := {"hold_the_relay": 18.0, "surge_run": 22.0, "scrap_stampede": 16.0}

const CHARACTER_KINDS := ["enemy_rebounded", "enemy_pinned", "vault_kicked", "gauge_charging", "gauge_released",
	"gauge_cancelled", "sprint_started", "cc_ignored", "cloak_started", "cloak_broken", "sticky_detonated",
	"rocket_jumped", "blink_used", "arc_slammed", "skid_smashed", "demo_slammed", "tree_offered", "tree_picked"]
const ENEMY_KINDS := ["hold_broken", "hold_ended", "tenacity_gained",
	"shield_vaulted", "swarm_scattered", "mind_adapted", "weak_point_opened", "enemy_ringed_out"]

var ctx
var _posture_seen := {}
var _guard_steps := {}
var _guard_warned := {}
var _warden_charging := false
var _unwarned := {}
var engine: MusicEngine
var ace: AceSequencer
var ace_manifest := ""
var title_row := "title"
var _on_title := false
const WON_SUMMARY_ROW := "summary"
var camp_open := false
var _ace_row_manifest := ""
var _ace_from := ""
var _render_from := -1
var ace_missing := ""
var _ace_failed := false
var _ace_task := -1
var _ace_slot: Array = []
var _ace_loaded_from := ""
var _ring_capacity := 0
# Godot headless Dummy audio driver pulls 4096 frames per period.
var queue_target := AceSequencer.QUEUE_TARGET
var _skips_seen := 0
var _ace_pumped_usec := 0
var _ace_gap_usec := 0
var _park_held := false
const UNMUTE_RAMP := AceSequencer.STOP_RAMP
var _unmute_at := -1
var _ace_flight := false
var _handover_at := -1
var _release_answered := false
var _ace_arrival_stage := 0
var _ace_arrival_at := -1
var _band_fade_start := -1
var _character_wired := {}
var _optional_listeners := {}
var _motif := ""
var _babble := {}
# Serialized because GDScript lazy operator cache is not thread-safe on concurrent cold calls.
var _babble_job := {}
var _babble_queue: Array = []
var _babble_asked := {}
var sound_ready := false
var _pitch_rng := RandomNumberGenerator.new()
var cue_log: Array = []
var cue_log_total: int = 0
var cue_log_cap: int = LOG_CAP
var last_play_frame := -1
var _logged_pitch := -1.0
var chirp_log: Array = []
var _chirp_last := {}
var volumes := {"Music": 0.8, "SFX": 1.0, "UI": 1.0}
var muted := false
# False on Godot Dummy audio driver; quitting right after freeing a playing player leaks playback.
var live_output := true
var bakes_ahead := true

var _music_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback
var _stinger_pb: AudioStreamGeneratorPlayback
var _sfx: AudioStreamPlaybackPolyphonic
var lane_hums := {}
var _ui: AudioStreamPlaybackPolyphonic
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voices := {}
var _sfx_budget := SfxBudget.new()
var _melody_lease := MelodyLease.new()
var music_dsp := MusicDsp.new()
var _boss_arena_track := ""
var _last_start := {}
var clock := 0.0
var hum_on := false
var _line_was := ""
var hum_pitch := 1.0
var _chain_bite_ms := -100000.0
const STREAK_LAND_RUNG := 2
const STREAK_BAR_RUNG := 5
const STREAK_VOICE := "bell"
const STREAK_BODY := "keys"
const CHAIN_CRASH := "chain_crash"
const HOME_TRIAD := [62, 65, 69]
const DUNK_VOICE := "mallet"
const DUNK_STORED_MIDI := 81
const DUNK_SPENT_MIDI := 74
const DEATH_FALL := [56, 53, 50]
const DEATH_FALL_VOICE := "brass"
const SET_CHIME := [77, 81, 86]
const SET_CHIME_VOICES := {"arc": "clav", "frost": "bell"}
const SET_CHIME_DONE_VOICE := "beep"
const SET_CHIME_LEAD_S := 0.12
const SET_CHIME_DUCK := 0.6
const PILOT_QUOTE_BARS := 8
const CALL_LEAD_S := 0.3
const CALL_DUCK := 0.6
var _calling := ""
var _streak_landed_ms := -100000
var _summary_due := -1
var _grid_key := ""
var _hum_voice := -1
var _gates := {}
var _fired_this_run := {}
var _notes: Array = []
var scrap_streak := Streak.for_kind("scrap_collected")
var cog_streak := Streak.for_kind("cogs_collected")
var kill_streak := Streak.for_kind("enemy_killed")
var reclaim_streak := Streak.for_kind("armor_reclaim")
var _hull_seen := 0.0
var _shed_heard := false
var _beacon_rung := -1
var _gates_announced := false
var _heft_class := 1
var _unseal_ms := -100000
var _boss_phase := 1
var _weak_combo := 0
var _launch_armed := false
var _landing_theme := -1
var _entered_ms := -1
var _launch_stage := false
var drop_log: Array = []
var _ult_lift := false
var _ult_armed := false
const ULT_BAND_BACK := ["recall", "bail"]
const STAGE_BAND_MODES := ["level", "warden"]
var _ult_took_band := false
var _pressure := 0.0
var parameter_threat_weights := Vector2(0.8, 0.2)
var parameter_threat_range := 48.0
var _parameter_graph
var _parameter_map := ""
var _parameter_run := ""
var _parameter_armour_peak := 100.0
var _miniboss: Node3D
var _park_cues := {}
var _park_transport_snapshot := {}
var park_cue_late: Array[Dictionary] = []
var out_music := PackedVector2Array()

var _event_id := ""
var _event_started_ms := -1
var _event_progress_live := false
var _chase_lead0 := -1.0
var _weak_last := -100000
var _flow_queue: Array = []
var _overlay: Label
var _overlay_until := 0
var _virtual_usec := 0.0
var _ear := TuneEar.new()
var spinning := ""
var spin_detent := 2
var _spin_restore := Callable()
var radio_hold := ""
var radio_pinned := false
var radio_silenced := false
var _radio_args := []
var _radio_respin_due := false
var radio_finale := false
var _radio_boss := []

static var _bake_task := -1
static var _baked := false
static var _bake_done := false
static var _rest_task := -1
static var _opening_task := -1


static func reset_for_tests() -> void:
	SfxBank.bake_cancel = true
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
	if _rest_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_rest_task)
		_rest_task = -1
	if _opening_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_opening_task)
		_opening_task = -1
	_baked = false
	_bake_done = false
	SfxBank.bake_cancel = false
	SfxBank.reset_voice_sidecar()


func _init() -> void:
	_pitch_rng.seed = 0xA0D10


func _log_cue(entry: Array) -> void:
	cue_log_total += 1
	if cue_log_cap > 0:
		while cue_log.size() >= cue_log_cap:
			cue_log.pop_front()
	cue_log.push_back(entry)


func cues_since(mark: int) -> Array:
	var dropped := cue_log_total - cue_log.size()
	return cue_log.slice(maxi(mark - dropped, 0))


func reset_cue_log() -> void:
	cue_log.clear()
	cue_log_total = 0


func _log_drop(entry: Array) -> void:
	if drop_log.size() >= LOG_CAP:
		drop_log.pop_front()
	drop_log.push_back(entry)


func _drawn_with_workers() -> bool:
	return bakes_ahead_on(AudioServer.get_driver_name(), AppShell.headless())


static func bakes_ahead_on(audio_driver: String, headless: bool) -> bool:
	return audio_driver != "Dummy" or not headless


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Audio"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	live_output = AudioServer.get_driver_name() != "Dummy"
	bakes_ahead = _drawn_with_workers()
	engine = MusicEngine.new()
	engine.warm_stingers = bakes_ahead
	if ctx.has_method("aim_forward"):
		engine.set_parameter_source(sample_run_parameters)
		engine.parameter_commit.connect(_commit_band_parameters)
	_music_player = _generator_player("Music", "MusicStream")
	_stinger_player = _generator_player(MusicDsp.STINGER_BUS, "StingerStream")
	_sfx_player = _poly_player("SFX", "SfxVoices")
	_ui_player = _poly_player("UI", "UiVoices")
	_make_overlay()
	_configure_voice_from_args()
	_connect_all(ctx.events)
	_wire_rail()
	_start_bake()
	ace_manifest = MusicRows.resolve(title_now())["ace_manifest"]
	_ace_row_manifest = ace_manifest
	_start_ace_load()
	read_ace_ahead(_music_row(1)["ace_manifest"])
	_flow_queue.append(["idle"])


static func _sound_ids() -> Array:
	var ids: Array = Rows.sound_ids()
	for kind in EventKinds.THREAT_ROWS:
		ids.append(EventKinds.THREAT_ROWS[kind]["sound"])
	for extra in ["womp", "build_riser", "vault_rise", "vault_drop", "synergy_hit"]:
		if not extra in ids:
			ids.append(extra)
	for id in SfxBank.TRIM_DB:
		if not id in ids:
			ids.append(id)
	for id in SfxBank.motif_cue_ids():
		if not id in ids:
			ids.append(id)
	for id in SfxBank.EVENT_CUES:
		if not id in ids:
			ids.append(id)
	for sting in SpillwayStory.STINGS.values():
		ids.append(SfxBank.stinger_id("1_1", sting))
	for midi in SfxBank.break_midis(POSTURE_PHRASE):
		ids.append(SfxBank.cause_note_id(midi))
	for cause in EventKinds.CAUSE_ROWS:
		for note in EventKinds.cause_motif(cause):
			var id := SfxBank.cause_note_id(Harmony.note_midi(String(note)))
			if not id in ids:
				ids.append(id)
	for id in _home_landing_ids():
		ids.append(id)
	for class_id in Harmony.CLASS_MOTIFS:
		var whip := SfxBank.whip_notes(class_id)
		for midi in [whip[1], whip[2]]:
			if not SfxBank.grid_note_id(whip[0], midi) in ids:
				ids.append(SfxBank.grid_note_id(whip[0], midi))
	for midi in [DUNK_STORED_MIDI, DUNK_SPENT_MIDI]:
		ids.append(SfxBank.grid_note_id(DUNK_VOICE, midi))
	for midi in DEATH_FALL:
		ids.append(SfxBank.grid_note_id(DEATH_FALL_VOICE, midi))
	return ids


static func _home_landing_ids() -> Array:
	var ids: Array = []
	var cap := int(EventKinds.juice("enemy_killed").get("chain_cap", 9))
	for rung in range(STREAK_LAND_RUNG, cap + 1):
		for id in _landing_ids(rung, HOME_TRIAD):
			if not id in ids:
				ids.append(id)
	return ids


static func _landing_ids(rung: int, tones: Array) -> Array:
	var last: int = SfxBank.KILL_POP_MIDI + Harmony.pentatonic_step(rung)
	var land := Harmony.tone_below(last, tones)
	var ids: Array = [SfxBank.grid_note_id(STREAK_VOICE, land), SfxBank.grid_note_id(STREAK_BODY, land - 12)]
	if rung >= STREAK_BAR_RUNG:
		ids.append(SfxBank.grid_note_id(STREAK_VOICE, last))
	return ids


static func _bake_everything(ids: Array) -> void:
	SfxBank.bake_all(ids)
	MusicEngine.prepare()
	_bake_done = not SfxBank.bake_cancel


func _start_bake() -> void:
	if _baked or _bake_task >= 0:
		return
	_bake_done = false
	_bake_task = WorkerThreadPool.add_task(_bake_everything.bind(_sound_ids()), true, "presentation audio bake")


static func _poll_bake() -> bool:
	if _baked:
		return true
	if _bake_task >= 0 and WorkerThreadPool.is_task_completed(_bake_task):
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = _bake_done
	return _baked


func _start_ace_load() -> void:
	if ace_manifest == "" or _ace_task >= 0 or not _ace_slot.is_empty() or ace != null or _ace_failed or not ace_wanted():
		return
	_ace_loaded_from = ace_manifest
	_ace_slot = []
	_ace_task = WorkerThreadPool.add_task(_ace_loader(_ace_loaded_from, _ace_slot), true, "presentation ACE stems")


var _ace_ahead := {}


func read_ace_ahead(manifest: String) -> void:
	if manifest == "" or _ace_failed or _ace_ahead.has(manifest) or not ace_wanted() or AceSequencer.kept(manifest) \
			or "--ace-check" in OS.get_cmdline_args() or "--ace-check" in OS.get_cmdline_user_args():
		return
	_ace_ahead[manifest] = WorkerThreadPool.add_task(_ace_loader(manifest, []), true, "presentation ACE read-ahead")


func _read_ahead_after(stage: int) -> void:
	var stages = _music_stages()
	if stages.is_world_last(stage):
		var boss := _boss_track()
		if boss in MusicEngine.BOSS_TRACKS:
			read_ace_ahead(MusicRows.resolve(_boss_entry(boss))["ace_manifest"])
	if not stages.is_last(stage):
		var tune := level_tune(stage + 1, true)
		read_ace_ahead(MusicRows.resolve(tune)["ace_manifest"] if tune != "" else _music_row(stage + 1)["ace_manifest"])


func _read_ahead_phases(boss: String) -> void:
	var heavy := PhaseMusic.track_for_phase(boss, 2, pack_available)
	if heavy != "":
		read_ace_ahead(MusicRows.resolve(heavy)["ace_manifest"])
	var final_track := String(PhaseMusic.final_plan(boss, pack_available)["track"])
	if final_track != "":
		read_ace_ahead(MusicRows.resolve(final_track)["ace_manifest"])


func _settle_ace_ahead(wait := "") -> void:
	for manifest in _ace_ahead.keys():
		var task: int = _ace_ahead[manifest]
		if manifest == wait or WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_ace_ahead.erase(manifest)


static func _ace_loader(manifest: String, slot: Array) -> Callable:
	return func(): slot.append(AceSequencer.new(manifest))


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_settle_workers()
		for task in _ace_ahead.values():
			WorkerThreadPool.wait_for_task_completion(task)
		_ace_ahead.clear()
		music_dsp.reset()


func bake_opening_now() -> void:
	bake_now()
	_finish_opening()
	MusicEngine.prepare_opening()


func _ready_for_run() -> void:
	if not bakes_ahead:
		return
	if not sound_ready:
		bake_now()
	_finish_opening()


static func _finish_opening() -> void:
	if _opening_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_opening_task)
		_opening_task = -1


static func _start_band_bakes() -> void:
	if _opening_task < 0:
		_opening_task = WorkerThreadPool.add_task(MusicEngine.prepare_opening, false, "presentation opening band bake")
	if _rest_task < 0:
		_rest_task = WorkerThreadPool.add_task(MusicEngine.prepare_rest, true, "presentation band bake")


func bake_now() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = _bake_done
	if not _baked:
		_bake_everything(_sound_ids())
		_baked = _bake_done
	_on_ready()


func _enter_tree() -> void:
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	if not get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.connect(_on_focus_changed)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	if get_viewport().gui_focus_changed.is_connected(_on_focus_changed):
		get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	_settle_workers()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	_sfx = null
	_sfx_budget.clear()
	music_dsp.reset()
	_voice_db.clear()
	_roomed.clear()
	_ui = null
	_music_pb = null
	_stinger_pb = null


func _settle_workers() -> void:
	var started := Time.get_ticks_msec()
	SfxBank.bake_cancel = true
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
		_baked = _bake_done
	_finish_opening()
	if _rest_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_rest_task)
		_rest_task = -1
	SfxBank.bake_cancel = false
	if _ace_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ace_task)
		_ace_task = -1
	MusicEngine.settle_stingers()
	_settle_babble()
	if OS.is_stdout_verbose():
		print("AUDIO_SETTLE ms=%d" % (Time.get_ticks_msec() - started))


func _on_ready() -> void:
	if sound_ready:
		return
	sound_ready = true
	if bakes_ahead:
		_start_band_bakes()
	_virtual_usec = _transport_usec()
	if not live_output:
		return
	_sfx_player.play()
	_ui_player.play()
	_sfx = _sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_ui = _ui_player.get_stream_playback() as AudioStreamPlaybackPolyphonic
	_start_rings()
	if ace_wanted():
		print("ACE music: generator ring %d frames, queue target %d" % [_ring_capacity, queue_target])
	_pump()


func _start_rings() -> void:
	_render_music(nearest_po2(int(Harmony.RATE * GEN_BUFFER)) - 1, ace != null and ace.active())
	_music_player.play()
	_stinger_player.play()
	_music_pb = _music_player.get_stream_playback()
	_stinger_pb = _stinger_player.get_stream_playback()
	_ring_capacity = _music_pb.get_frames_available()
	if not (_music_pb.push_buffer(out_music) and _stinger_pb.push_buffer(engine.out_stinger)):
		push_warning("Music: the first block (%d frames) did not fit the %d-frame ring" % [out_music.size(), _ring_capacity])


func _make_buses() -> void:
	for bus in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, "Master")
		AudioServer.set_bus_volume_db(index, BUSES[bus])
		if bus == "SFX":
			AudioServer.add_bus_effect(index, _compressor(MixRows.SFX_COMP))
			AudioServer.add_bus_effect(index, _limiter(MixRows.SFX_CEILING_DB))
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		AudioServer.add_bus_effect(master, _compressor(MixRows.MASTER_COMP))
		AudioServer.add_bus_effect(master, _limiter(MixRows.MASTER_CEILING_DB))
	music_dsp.setup()
	_apply_volumes()


static func _compressor(row: Dictionary) -> AudioEffectCompressor:
	var comp := AudioEffectCompressor.new()
	comp.threshold = float(row["threshold_db"])
	comp.ratio = float(row["ratio"])
	comp.attack_us = float(row["attack_us"])
	comp.release_ms = float(row["release_ms"])
	comp.gain = float(row["gain_db"])
	return comp


static func _limiter(ceiling_db: float) -> AudioEffectHardLimiter:
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = ceiling_db
	return limiter


var mix_db := {}
var _focus_until := -1.0
var _live_sfx := 0
var _live_frame := -1


func _tend_mix(delta: float) -> void:
	var state := mix_state()
	var focus := clock < _focus_until or _slowed
	var room := _drop_room_now()
	var moved := false
	for bus in BUSES:
		var want := MixRows.state_db(state, bus) + (float(MixRows.FOCUS.get(bus, 0.0)) if focus else 0.0) + float(room.get(bus, 0.0))
		var now := float(mix_db.get(bus, want))
		var next := MixRows.glide(now, want, delta, room.has(bus)) if mix_db.has(bus) else want
		if not mix_db.has(bus) or absf(next - now) > 0.001:
			moved = true
		mix_db[bus] = next
	if moved:
		_apply_volumes()
	music_dsp.step(delta, _dsp_state())


func _dsp_state() -> Dictionary:
	var hp_low := false
	if ctx != null and ctx.run != null and ctx.run.get("max_hp") != null:
		var max_hp := float(ctx.run.max_hp)
		hp_low = max_hp > 0.0 and float(ctx.run.hp) < max_hp * 0.3
	var armour_low := _hull_seen > 0.0 and ace != null and ace.parameters.has("armour") and float(ace.parameters["armour"]) < 0.3
	var low_hull := hp_low or armour_low
	var tension := 0.0
	if _launch_armed or _ult_armed:
		tension = 1.0
	elif ace_playing() and ace.mode == "warden" and ace.section == "telegraph":
		tension = 0.65
	return {
		"focus": clock < _focus_until,
		"slowed": _slowed,
		"low_hull": low_hull,
		"build_tension": tension,
	}


var _drop_room := []


func _make_drop_room(at: int, band = null) -> void:
	var tuning = ctx.get("tuning") if ctx != null else null
	var name: String = tuning.option(Tuning.DROP_ROOM_KEY) if tuning != null else "off"
	if not MixRows.DROP_ROOM.has(name):
		_drop_room = []
		return
	var owner = band if band != null else (ace if ace_playing() else engine)
	if owner == null:
		_drop_room = []
		return
	var bar: int = ace.grid_bar if owner == ace else engine.bar_len()
	var from := at - int(MixRows.DROP_ROOM_LEAD_S * Harmony.RATE)
	_drop_room = [owner, from, at + MixRows.DROP_ROOM_BARS * bar, MixRows.DROP_ROOM[name]]


func _drop_room_now() -> Dictionary:
	if _drop_room.is_empty():
		return {}
	var owner = _drop_room[0]
	var valid: bool = (owner == ace and ace_playing()) or (owner == engine and engine != null)
	if owner == null or not valid:
		_drop_room = []
		return {}
	var queued := 0
	if live_output and _music_pb != null:
		queued = _ring_capacity - _music_pb.get_frames_available()
	var heard: int = ace.audible_sample(queued) if owner == ace else maxi(engine.clock - queued, 0)
	if heard >= int(_drop_room[2]):
		_drop_room = []
		return {}
	return _drop_room[3] if heard >= int(_drop_room[1]) else {}


func _live_sfx_voices() -> int:
	var frame := Engine.get_process_frames()
	if frame != _live_frame:
		_live_frame = frame
		_live_sfx = 0
		if _sfx != null:
			for sound in _voices:
				for id in _voices[sound]:
					if _sfx.is_stream_playing(id):
						_live_sfx += 1
	return _live_sfx


func _is_telegraph(kind: String, sound: String) -> bool:
	return sound in DANGER_SOUNDS or EventKinds.THREAT_ROWS.has(kind)


func _focus() -> void:
	_focus_until = clock + float(MixRows.FOCUS["hold_s"])
	_melody_lease.bump_epoch()


const SLOW_KIND := "slow_motion"
var _slowed := false


func slowed(on: bool) -> void:
	if on == _slowed:
		return
	_slowed = on
	if is_inside_tree() and not get_tree().paused:
		play(SLOW_KIND, 0.0, 1.0, "SFX", "slow_dip" if on else "slow_rise")


func _generator_player(bus: String, node_name: String) -> AudioStreamPlayer:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = Harmony.RATE
	generator.buffer_length = GEN_BUFFER
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = generator
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _poly_player(bus: String, node_name: String) -> AudioStreamPlayer:
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = POLYPHONY
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = poly
	player.bus = bus
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _on_focus_changed(_control: Control) -> void:
	_menu_sounds.focus_moved()


func note_menu_nav() -> void:
	_menu_sounds.nav_noted()


func _step_menu_sounds() -> void:
	var nav := false
	for action in MenuSounds.NAV:
		nav = nav or Input.is_action_pressed(action)
	for code in MenuSounds.WASD:
		nav = nav or Input.is_physical_key_pressed(code)
	var held := get_viewport().gui_get_focus_owner() != null
	for kind in _menu_sounds.step(nav, Input.is_action_pressed("ui_accept"), Input.is_action_pressed("ui_cancel"), held):
		match kind:
			"menu_move":
				play("menu_move", 0.0, 1.0, "UI", "menu_move", 0)
			"menu_confirm":
				play("menu_confirm", 0.0, 1.0, "UI", "menu_confirm", 1)
			"menu_back":
				play("menu_back", 0.0, 1.0, "UI", "menu_back", 1)


func _process(delta: float) -> void:
	clock += delta
	_step_cannon_cues()
	if not _ace_ahead.is_empty():
		_settle_ace_ahead()
	if not sound_ready:
		if _poll_bake():
			_on_ready()
		else:
			_start_bake()
			return
	if is_inside_tree():
		_step_menu_sounds()
	engine.pause_gain = 0.45 if get_tree().paused else 1.0
	if ace != null:
		ace.pause_gain = engine.pause_gain
	_tend_mix(delta / maxf(Engine.time_scale, 0.05))
	_tend_room()
	_flush_flow()
	_tend_kill_streak()
	_warm_grid_key()
	_play_due_notes()
	_tend_tally()
	_tend_cadence()
	_tend_site_flips()
	_tend_hum()
	_tend_specials()
	_tend_kettle()
	_tend_heat()
	_tend_champions()
	_tend_moments()
	_follow_warden()
	_follow_escalation()
	_tend_set()
	_tend_ear(delta)
	_tend_babble()
	if _launch_armed and _landing_theme >= 0 and SimClock.msec() - _entered_ms > LANDING_FALLBACK_MS:
		_land_drop()
	_pump()
	if _overlay != null and _overlay.visible and Time.get_ticks_msec() > _overlay_until:
		_overlay.visible = false


func _pump(virtual_frames := -1) -> void:
	_guard_park_bookings()
	if _ace_arrival_stage > 0 and _ace_arrival_at >= 0 and engine.clock > _ace_arrival_at and not engine.in_drop():
		var stage := _ace_arrival_stage
		_ace_arrival_stage = 0
		_ace_arrival_at = -1
		_ace_return(stage, engine.next_bar())
	if ace != null:
		ace.set_fight_floor(_ace_fight_floor())
		_answer_release()
	var ace_live := ace != null and ace.active()
	_hand_over_band()
	_release_grid()
	if _summary_due >= 0 and engine.clock >= _summary_due:
		_ace_named(summary_row(false), engine.next_beat(), false, false)
	if not live_output:
		var now := _transport_usec()
		var owed := virtual_frames if virtual_frames >= 0 else int((now - _virtual_usec) * Harmony.RATE / 1000000.0)
		if owed > 0:
			var requested := mini(owed, 8192)
			var frames := _park_render_limit(requested)
			var elapsed := (owed - requested + frames) * 1000000.0 / Harmony.RATE
			_virtual_usec += elapsed if SimClock.ticks else int(elapsed)
			if frames > 0:
				_render_music(frames, ace_live)
		return
	if _music_pb == null or _stinger_pb == null:
		return
	var frames := mini(_music_pb.get_frames_available(), _stinger_pb.get_frames_available())
	var settle := false
	if not ace_live:
		_skips_seen = _music_pb.get_skips()
		_ace_pumped_usec = 0
	else:
		var now := Time.get_ticks_usec()
		var gap := now - _ace_pumped_usec
		if _ace_pumped_usec == 0:
			settle = true
		elif _gap_is_stall(gap):
			_note_stall(gap)
			settle = true
		elif _park_held:
			_note_park_hold(gap)
			settle = true
		else:
			_ace_gap_usec = gap
			_deepen_on_skip()
		_ace_pumped_usec = now
		var target := _ring_capacity if _launch_armed else queue_target
		frames = mini(ace.frames_to_pump(_music_pb, _ring_capacity, target), _stinger_pb.get_frames_available())
	var wanted := mini(frames, 8192)
	frames = _park_render_limit(wanted)
	if frames > 0:
		_render_music(frames, ace_live)
		_music_pb.push_buffer(out_music)
		_stinger_pb.push_buffer(engine.out_stinger)
	_park_held = frames < wanted and (_ring_capacity - _music_pb.get_frames_available()) * 2 < queue_target
	if settle:
		_skips_seen = _music_pb.get_skips()


func _transport_usec() -> int:
	if SimClock.ticks:
		return int(Engine.get_physics_frames() * 1000000 / Engine.physics_ticks_per_second)
	return Time.get_ticks_usec()


func _render_music(frames: int, ace_live: bool) -> void:
	var from := engine.clock
	_unmute_for_handover(frames)
	_render_from = from
	engine.render(frames)
	_render_from = -1
	var music := _ace_render(frames, ace_live)
	_fade_in_band(from, frames, engine.out_landmark)
	if not ace_live:
		out_music = engine.out_music
	elif engine.band_muted:
		out_music = music
	else:
		out_music = _with_band(music, from)
	if ace_live:
		for i in frames:
			out_music[i] += engine.out_landmark[i]


func _commit_band_parameters(at: int, values: Dictionary, released: bool, lift: bool, reason: String) -> void:
	if ace != null:
		ace.commit_parameters(at, values, released and not _release_answered, lift, reason, {"phrase_step": engine._bar_step, "phrase": engine._parameter_phrase_due})
	if values.has("approach"):
		landmark_moment(_landmark_id(), float(values["approach"]))


func _hand_over_band() -> void:
	if not ace_playing():
		_ace_flight = false
		_handover_at = -1
		_unmute_band()
		return
	if engine.band_muted or _handover_at >= 0:
		return
	if _band_fade_start < 0 or _band_fade_start > engine.clock:
		_band_fade_start = ace.sound_from()
	engine.band_muted = _band_fade_start >= 0 and engine.clock >= _band_fade_start + AceSequencer.STOP_RAMP


func _with_band(music: PackedVector2Array, from: int) -> PackedVector2Array:
	var band := engine.out_music
	var n := mini(music.size(), band.size())
	if _band_fade_start < 0:
		for i in n:
			music[i] += band[i] - engine.out_landmark[i]
		return music
	var inv := 1.0 / AceSequencer.STOP_RAMP
	for i in n:
		var g := clampf(1.0 - float(from + i - _band_fade_start) * inv, 0.0, 1.0)
		if g > 0.0:
			music[i] += (band[i] - engine.out_landmark[i]) * g
	return music


func _unmute_band(from := -1) -> void:
	_band_fade_start = -1
	if not engine.band_muted:
		return
	engine.band_muted = false
	_unmute_at = from if from >= 0 else engine.clock


func _unmute_for_handover(frames: int) -> void:
	if _handover_at >= 0 and engine.band_muted and engine.clock + frames > _handover_at - UNMUTE_RAMP:
		_unmute_band(_handover_at - UNMUTE_RAMP)


func _fade_in_band(from: int, frames: int, landmark := PackedVector2Array()) -> void:
	if _unmute_at < 0:
		return
	if from >= _unmute_at + UNMUTE_RAMP:
		_unmute_at = -1
		return
	var band := engine.out_music
	var n := mini(frames, band.size())
	for i in n:
		var g := clampf(float(from + i - _unmute_at) / UNMUTE_RAMP, 0.0, 1.0)
		if g >= 1.0:
			break
		var hum := Vector2.ZERO if landmark.is_empty() else landmark[i]
		band[i] = (band[i] - hum) * g + hum
	engine.out_music = band


# Godot audio buffer (512-1024 frames) is under half the queue.
func _gap_is_stall(gap_usec: int) -> bool:
	return gap_usec * Harmony.RATE * 2 > queue_target * 1000000


func _deepen_on_skip() -> void:
	_deepen_for(_music_pb.get_skips())


func _deepen_for(skips: int) -> void:
	if skips <= _skips_seen:
		return
	var took := skips - _skips_seen
	_skips_seen = skips
	if queue_target + 1024 <= _ring_capacity - 1024:
		queue_target += 1024
		print("ACE music: the ring ran dry (%d skips) at frame %d, stage %d, %d ms since the last pump; queue target now %d frames" % [took, Engine.get_process_frames(), _stage_now, _ace_gap_usec / 1000, queue_target])


func _note_stall(gap_usec: int) -> void:
	var skips := _music_pb.get_skips()
	if skips > _skips_seen:
		print("ACE music: a %d ms gap between pumps outlasted the queue (%d skips) at frame %d, stage %d%s" % [gap_usec / 1000, skips - _skips_seen, Engine.get_process_frames(), _stage_now, ", launch armed" if _launch_armed else ""])
	_skips_seen = skips


func _note_park_hold(gap_usec: int) -> void:
	var skips := _music_pb.get_skips()
	if skips > _skips_seen:
		print("ACE music: a park cue's hold emptied the ring (%d skips) at frame %d, stage %d, %d ms since the last pump" % [skips - _skips_seen, Engine.get_process_frames(), _stage_now, gap_usec / 1000])
	_skips_seen = skips


func _ace_render(frames: int, live: bool) -> PackedVector2Array:
	if ace == null:
		return PackedVector2Array()
	if live:
		return ace.render(frames).duplicate()
	ace.advance(frames)
	return PackedVector2Array()


func ace_wanted() -> bool:
	var tuning = ctx.get("tuning")
	return tuning != null and tuning.option(Tuning.MUSIC_KEY) == "ace"


func ace_ready() -> bool:
	if ace_manifest == "":
		return false
	if ace != null and _ace_from == ace_manifest:
		return true
	if _ace_failed or not ace_wanted():
		return false
	var loaded: AceSequencer = null
	if _ace_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ace_task)
		_ace_task = -1
	if not _ace_slot.is_empty() and _ace_loaded_from == ace_manifest:
		loaded = _ace_slot[0]
	_ace_slot = []
	if loaded == null:
		_settle_ace_ahead(ace_manifest)
		loaded = AceSequencer.new(ace_manifest)
	if not loaded.ready():
		_ace_failed = true
		ace_missing = loaded.missing
		push_warning("ACE music: missing %s; playing the synth engine instead" % ace_missing)
		return false
	if ace != null:
		var swap_ramp: int = clampi(ace.grid_beat / 2, AceSequencer.STOP_RAMP, int(AceSequencer.RATE * 0.25))
		ace.stop(swap_ramp)
		loaded.fading.append_array(ace.fading)
	ace = loaded
	_ace_from = ace_manifest
	ace.clock = _render_from if _render_from >= 0 else engine.clock
	ace.set_breath(breath())
	ace.set_pump(DeckMoves.pump_for(deck_style()) if not ace.flat and bool(MusicArbiter.resolve(_arbiter_state())["allow_dj"]) else {})
	ace.ultimate_lift = _ult_lift
	_melody_lease.bump_epoch()
	_prime_band_parameters()
	return true


func _ace_fight_floor() -> float:
	if engine.mode != MusicEngine.PLAY or engine.track == "level":
		return 0.0
	if engine.track == "warden" and engine.section == "open" and engine._cadence_bar < 0:
		return 0.0
	return engine._floor()


func _prime_band_parameters() -> void:
	ace.set_fight_floor(_ace_fight_floor())
	ace.parameter_enabled = engine.parameter_source.is_valid()
	if ace.parameter_enabled:
		ace.parameters = engine.parameter_committed_values.duplicate()
		ace.parameter_released = engine.parameter_committed_released and not _release_answered
		ace._parameter_danger_floor = engine.parameter_committed_danger_floor
		ace.pressure = float(ace.parameters.get("threat", 0.0))
		ace.ultimate_lift = engine.ultimate_lift


var _music_warned := {}


func _warn_music_once(key: String, message: String) -> void:
	if _music_warned.has(key):
		return
	_music_warned[key] = true
	_emit_music_warning(message)


func _emit_music_warning(message: String) -> void:
	push_warning(message)


func _music_stages():
	var stages = ctx.get("stages") if ctx != null else null
	return stages if stages != null else MusicRows.StageDefs


func _music_row(stage: int) -> Dictionary:
	var stages = _music_stages()
	return MusicRows.resolve(stages.of(stage), "", stages)


func _stage_theme(stage: int) -> int:
	var stages = _music_stages()
	return MusicRows.stage_theme(stages.of(stage), stages)


func _boss_track() -> String:
	var track := "brindle"
	var stages = ctx.get("stages") if ctx != null else null
	var run = ctx.get("run") if ctx != null else null
	if stages == null or run == null:
		return track
	var world: int = stages.world_of(int(run.stage))
	var flow = ctx.get("flow")
	var row: Dictionary = flow.boss_row(world) if flow != null and flow.has_method("boss_row") else Worlds.boss_of(world)
	track = str(row.get("music", "brindle"))
	if not track in MusicEngine.BOSS_TRACKS:
		_warn_music_once("boss_track_" + track, "music: boss track '%s' has no music yet; playing brindle" % track)
		return "brindle"
	return track


func _ace_package_for(stage: int) -> String:
	var manifest: String = _music_row(stage)["ace_manifest"]
	if manifest != "":
		return manifest.get_base_dir().get_file()
	var row: Dictionary = _music_stages().of(stage)
	var package := str(row.get("music", {}).get("ace", ""))
	if package != "":
		_warn_music_once("ace_" + package, "music: ACE package '%s' is not loadable; playing the synth band" % package)
	return ""


func _ace_stage(stage: int, at: int, fight := false) -> void:
	if radio_hold != "":
		return
	_moment_playing = "" if fight else TuneMoments.top(_moments, tune_available)
	var tune := level_tune(stage, fight)
	var manifest: String = MusicRows.resolve(tune)["ace_manifest"] if tune != "" else _music_row(stage)["ace_manifest"]
	_select_ace_manifest(manifest)
	if (at < 0 and _launch_armed) or (_ace_flight and ace_playing()):
		_ace_arrival_stage = stage
		_ace_arrival_at = -1
		return
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	if (manifest != "" if tune != "" else _ace_package_for(stage) != "") and ace_ready():
		_ace_flight = false
		_handover_at = -1
		_prime_band_parameters()
		ace.start_level(at if at >= 0 else engine.clock, fight)
		engine.grid = ace
		return
	if _ace_flight and ace_playing():
		return
	_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)


func _select_ace_manifest(manifest: String) -> void:
	if manifest != _ace_row_manifest:
		if ace_manifest == _ace_row_manifest:
			ace_manifest = manifest
			_ace_failed = false
			ace_missing = ""
		_ace_row_manifest = manifest


func music_state() -> Dictionary:
	var zone := ""
	if ctx != null and ctx.get("run") != null:
		zone = MusicRows.zone_id(int(ctx.run.stage), _music_stages())
	var pack := _ace_from.get_base_dir().get_file().replace("_", "-") if ace_playing() else ""
	return {"mode": MusicEngine.MODE_NAMES[engine.mode], "track": engine.track, "section": engine.section,
		"lounge": engine.lounge, "zone": zone, "pack": pack}


func _tend_ear(delta: float) -> void:
	if spinning != "":
		return
	var id := _ear.listen(TuneRows.key_of(music_state()), delta)
	if id != "":
		tune_heard.emit(id)


func knows_tune(id: String) -> void:
	_ear.knows(id)


func spin(id: String, live := false, row: Dictionary = {}) -> bool:
	if row.is_empty():
		row = TuneRows.row(id)
	if row.is_empty() or not sound_ready:
		return false
	if spinning == "":
		_spin_restore = engine.parameter_source
	spinning = id
	if not live:
		engine.set_parameter_source(func(): return {"threat": SPIN_ENERGY[spin_detent]})
	engine.cancel_pending()
	if ace_playing():
		ace.set_bay(false)
	var source: Dictionary = row["source"]
	var kind := String(source["kind"])
	if kind == "menu":
		var won := bool(source.get("won", true))
		engine.schedule_mode(engine.clock, MusicEngine.IDLE)
		engine.menu_theme(source["pack"], won, engine.clock)
		_ace_named(source["pack"], engine.clock, false, won)
		return true
	if kind == "boss" or (kind == "pack" and source.has("boss")):
		var boss := String(source["boss"])
		engine.force_track(boss, MusicRows.stage_theme(boss), "1", true)
		_ace_named(String(source.get("pack", boss)), engine.clock, true)
		return true
	var zone := String(source["zone"])
	engine.force_track({"warden": "warden", "miniboss": "miniboss"}.get(kind, "level"), MusicRows.stage_theme(zone))
	if kind == "miniboss":
		_ace_end()
		return true
	var tune: String = MusicRows.take_manifest(id) if kind == "pack" and id.begins_with("take-") else (MusicRows.ROWS.get(id, {}).get("ace_manifest", "") if kind == "pack" else "")
	_select_ace_manifest(tune)
	if tune == "" or not ace_ready():
		_select_ace_manifest(MusicRows.resolve(zone)["ace_manifest"])
	if ace_ready():
		_ace_flight = false
		_handover_at = -1
		_prime_band_parameters()
		ace.start_level(engine.clock)
		engine.grid = ace
		if kind == "warden":
			ace.commit_warden()
	else:
		_ace_end()
	if kind == "lounge" or source.get("lounge", false):
		engine.set_lounge(true)
		if ace_playing():
			ace.set_bay(true)
	return true


func set_spin_detent(detent: int) -> void:
	spin_detent = clampi(detent, 0, SPIN_ENERGY.size() - 1)


func stop_spin() -> void:
	if spinning == "":
		return
	_release_spin()
	engine.cancel_pending()
	var at := engine.next_beat()
	engine.schedule_mode(at, MusicEngine.IDLE)
	engine.menu_theme("title", true, at)
	_menu_home(at)


func _release_spin() -> void:
	if spinning == "":
		return
	spinning = ""
	engine.set_parameter_source(_spin_restore)
	_spin_restore = Callable()
	if ace_playing():
		ace.set_bay(false)


func radio_play(id: String, record: String, pinned := false) -> bool:
	var parent := TuneRows.row(record)
	if parent.is_empty() or not sound_ready:
		return false
	if radio_finale and _in_boss_arena():
		return false
	var boss_before := _active_boss_track() if _in_boss_arena() else ""
	var play_id := record
	var row := parent
	if id != record and MusicRows.take_manifest(id) != "":
		var source: Dictionary = parent["source"].duplicate()
		if source["kind"] != "menu":
			source["kind"] = "pack"
			source["pack"] = id
		row = parent.duplicate()
		row["source"] = source
		play_id = id
	if not spin(play_id, true, row):
		return false
	radio_hold = id
	radio_pinned = pinned
	_tend_deck()
	if boss_before != "" and _radio_boss.is_empty():
		_radio_boss = ["boss_arena_entered", boss_before]
	_radio_args = [id, record, pinned]
	_radio_respin_due = false
	_log_cue(["radio", id, "needle", engine.clock, 1.0])
	return true


func _radio_respin() -> void:
	if _radio_args.size() == 3:
		radio_play(_radio_args[0], _radio_args[1], _radio_args[2])


func radio_release() -> void:
	if radio_hold == "":
		return
	var held_boss := _active_boss_track()
	_radio_drop("")
	if not sound_ready or ctx == null or ctx.get("flow") == null or not ctx.flow.in_play():
		return
	var plan := MusicArbiter.resolve(_arbiter_state())
	if plan["owner"] in [MusicArbiter.OWNER_BOSS, MusicArbiter.OWNER_BOSS_FINALE] and held_boss in MusicEngine.BOSS_TRACKS:
		engine.cancel_pending()
		_begin_boss("boss_arena_entered", held_boss)
		engine.set_brindle_phase(_boss_phase)
		if _boss_phase > 1 or bool(plan["is_boss_finale"]):
			_phase_music_done = 1
			phase_music(_boss_phase)
		_log_cue(["radio", "score", "bar", engine.next_bar(), 1.0])
		return
	if _stage_now <= 0:
		return
	engine.cancel_pending()
	if plan["owner"] == MusicArbiter.OWNER_WARDEN:
		engine.force_track("warden", _stage_theme(_stage_now))
	elif is_instance_valid(_miniboss):
		engine.force_track("level", _stage_theme(_stage_now))
		engine.begin_miniboss()
	else:
		engine.force_track("level", _stage_theme(_stage_now))
	_moment_playing = ""
	_ace_return(_stage_now, engine.next_bar())
	_log_cue(["radio", "score", "bar", engine.next_bar(), 1.0])


func _radio_drop(reason: String) -> void:
	if radio_hold == "":
		return
	radio_hold = ""
	radio_pinned = false
	_radio_args = []
	_radio_boss = []
	_radio_respin_due = false
	_release_spin()
	if reason != "":
		radio_yielded.emit(reason)


func set_radio_silenced(on: bool) -> void:
	if radio_silenced == on:
		return
	radio_silenced = on
	_apply_volumes()


func score_tune_wanted() -> String:
	var top := TuneMoments.top(_moments, tune_available)
	if top != "":
		return top
	if _stage_now <= 0 or ctx == null or ctx.get("run") == null:
		return ""
	var zone := MusicRows.zone_id(_stage_now, _music_stages())
	return ("warden-" if _warden_engaged else "roam-") + zone


func moment_live() -> bool:
	return TuneMoments.top(_moments, tune_available) != ""


func tune_unheard(id: String) -> bool:
	return id != "" and not TuneRows.row(id).is_empty() and not _ear.heard(id)


func title_theme(theme: String) -> void:
	var row := "title-" + theme.to_lower()
	if not MusicRows.ROWS.has(row) or not title_available.call(row):
		row = "title"
	if row == title_row:
		return
	title_row = row
	if _on_title and sound_ready:
		_ace_named(title_row, engine.next_bar())
		_on_title = true


func title_now() -> String:
	if title_row == "title" and title_available.call("title-a"):
		return "title-a"
	return title_row


func summary_row(won: bool) -> String:
	if won and not title_available.call(WON_SUMMARY_ROW) and title_available.call("title-c"):
		return "title-c"
	return "summary"


func camp_theme(open: bool) -> void:
	if camp_open == open:
		return
	camp_open = open
	if sound_ready and spinning == "" and radio_hold == "":
		_menu_home(engine.next_bar())


func _menu_home(at: int) -> void:
	if camp_open and title_available.call("camp"):
		_ace_named("camp", at)
		return
	_ace_named(title_now(), at)
	_on_title = true


func _ace_named(id: String, at: int, boss := false, won := true) -> void:
	_summary_due = -1
	_on_title = false
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	var manifest: String = MusicRows.resolve(id)["ace_manifest"]
	var keep := manifest == _ace_from and ace_playing() and ace.mode == "menu"
	_select_ace_manifest(manifest)
	if ace_ready():
		if keep and not boss:
			return
		_ace_flight = false
		_handover_at = -1
		_prime_band_parameters()
		if boss:
			ace.start_boss(at)
		else:
			ace.start_menu(at, won)
		engine.grid = ace
		return
	_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)


func _in_boss_arena() -> bool:
	if _flow_state == "boss":
		return true
	var flow_node = ctx.get("flow") if ctx != null else null
	return flow_node != null and flow_node.has_method("state_name") and String(flow_node.state_name()) == "boss"


func _active_boss_track() -> String:
	if not _radio_boss.is_empty():
		return String(_radio_boss[1])
	if _boss_arena_track != "":
		return _boss_arena_track
	if _in_boss_arena():
		return _boss_track()
	return ""


func _has_live_champion() -> bool:
	for id in _champions:
		if is_instance_valid(_champions[id]):
			return true
	return false


func _champion_pack_id() -> String:
	for id in _champion_euro:
		if _champions.has(id) and is_instance_valid(_champions[id]):
			var final_track := PhaseMusic.champion_final(pack_available)
			if final_track != "":
				return final_track
	var champion := TuneMoments.remixed("champion", PhaseMusic.CHAMPION, _remixes, tune_available)
	if champion == PhaseMusic.CHAMPION and not pack_available.call(PhaseMusic.CHAMPION):
		return ""
	return champion


func _arbiter_state() -> Dictionary:
	var flow_node = ctx.get("flow") if ctx != null else null
	var in_play := true
	if flow_node != null and flow_node.has_method("in_play"):
		in_play = bool(flow_node.in_play())
	elif _flow_state != "":
		in_play = _flow_state in ["stage", "beacon", "gates", "launch", "boss"]
	var boss_active := _in_boss_arena() or _boss_arena_track != ""
	var sealed := flow_node != null and bool(flow_node.get("sealed"))
	return {
		"flow": _flow_state,
		"in_play": in_play,
		"boss_active": boss_active,
		"boss_track": _active_boss_track() if boss_active else "",
		"boss_finale": radio_finale or (boss_active and PhaseMusic.is_final(_boss_phase)),
		"launch_armed": _launch_armed,
		"warden_fighting": _warden_fighting,
		"warden_engaged": _warden_engaged,
		"warden_sealed": sealed,
		"ult_flight": _ult_armed and (_ult_took_band or _ace_flight),
		"radio_hold": radio_hold,
		"radio_pinned": radio_pinned,
		"champion_alive": _has_live_champion() and _champion_pack_id() != "",
		"moment_id": TuneMoments.top(_moments, tune_available),
		"miniboss_live": is_instance_valid(_miniboss),
		"stage": _stage_now,
	}


func _restore_champion_pack(at: int) -> bool:
	var pack := _champion_pack_id()
	if pack == "":
		return false
	_champion_hyped = true
	_ace_named(pack, at, true)
	return true


func _disarm_ultimate() -> void:
	_ult_armed = false
	_ult_took_band = false


func _ace_return(stage: int, at: int) -> void:
	var plan := MusicArbiter.resolve(_arbiter_state())
	match plan["owner"]:
		MusicArbiter.OWNER_WARDEN:
			_ace_stage(stage, at, true)
		MusicArbiter.OWNER_CHAMPION:
			if not _restore_champion_pack(at):
				_ace_stage(stage, at, false)
		MusicArbiter.OWNER_ULT, MusicArbiter.OWNER_LAUNCH, MusicArbiter.OWNER_DEAD:
			return
		_:
			_ace_stage(stage, at, false)


func _ult_band_stays_off() -> void:
	_ult_took_band = false
	_ace_arrival_stage = 0
	_ace_arrival_at = -1


func _ace_end(ramp := AceSequencer.STOP_RAMP) -> void:
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	engine.grid = null
	_ace_flight = false
	_handover_at = -1
	if ace != null and ace.mode != "off":
		ace.stop(ramp)
	_unmute_band()
	_release_grid()


func _ace_end_at(at: int) -> void:
	if not ace_playing():
		_ace_end()
		return
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	_ace_flight = false
	ace.cancel_shots()
	ace.set_pump({})
	ace.stop_at(at, AceSequencer.STOP_RAMP)
	_handover_at = at


func ace_playing() -> bool:
	return ace != null and ace.mode != "off"


func _answer_release() -> void:
	if _release_answered and not engine.parameters_released():
		_release_answered = false
	if not ace.lead_returned:
		return
	_release_answered = engine.parameters_released()
	ace.clear_release()
	ace.lead_returned = false


func _release_grid() -> void:
	if engine.grid != null and not ace_playing():
		engine.grid = null


func breath() -> String:
	return ctx.tuning.option(Tuning.BREATH_KEY) if ctx.tuning != null else "hard"


func set_breath(style: String) -> void:
	if ctx.tuning != null:
		ctx.tuning.set_option(Tuning.BREATH_KEY, style)
	if ace != null:
		ace.set_breath(breath())


func live_key() -> int:
	if not ace_playing():
		return engine.key
	var queued := 0
	if live_output and _music_pb != null:
		queued = _ring_capacity - _music_pb.get_frames_available()
	return ace.key_at(ace.audible_sample(queued))


func _duck(amount: float, hold_seconds: float) -> void:
	engine.duck(amount, hold_seconds)
	if ace_playing():
		ace.duck(amount, hold_seconds)


var _voice_db := {}
var _roomed := {}
var _room_for := ""
var _room_until_ms := -1


func _make_room(kind: String, sound: String) -> void:
	var hold := float(MixRows.MAKE_ROOM[sound]["hold_s"])
	if MixRows.MAKE_ROOM[sound].has("only") and Time.get_ticks_msec() < _room_until_ms and _room_for != sound:
		return
	if not MixRows.MAKE_ROOM[sound].has("only"):
		_restore_roomed()
	_room_for = sound
	_room_until_ms = Time.get_ticks_msec() + int(hold * 1000.0)
	_log_cue([kind, sound, "room", engine.clock, hold, float(MixRows.MAKE_ROOM[sound]["db"]), MixRows.MAKE_ROOM[sound].get("only", [])])
	if _sfx == null:
		return
	for id in _voice_db:
		var row: Array = _voice_db[id]
		var room := _room_offset(row[0])
		if room != 0.0 and not _roomed.has(id) and _sfx.is_stream_playing(id):
			_roomed[id] = row[1]
			_sfx.set_stream_volume(id, float(row[1]) + room)
			_log_gain(kind, row[0], "duck", row[2], room)


func _room_offset(sound: String, sounding := true) -> float:
	if Time.get_ticks_msec() >= _room_until_ms:
		return 0.0
	return MixRows.room_db(_room_for, sound, sound in DANGER_SOUNDS, sounding)


func _log_gain(kind: String, sound: String, how: String, start: int, db: float) -> void:
	_log_cue([kind, sound, how, engine.clock, start, db])


func _restore_roomed() -> void:
	if _sfx != null:
		for id in _roomed:
			if _sfx.is_stream_playing(id):
				_sfx.set_stream_volume(id, float(_roomed[id]))
				var voice: Array = _voice_db.get(id, ["", 0.0, -1])
				_log_gain(_room_for, voice[0], "restore", voice[2], 0.0)
	_roomed.clear()


func _tend_room() -> void:
	if Time.get_ticks_msec() < _room_until_ms or _sfx == null:
		return
	_restore_roomed()
	if _voice_db.size() > 64:
		for id in _voice_db.keys():
			if not _sfx.is_stream_playing(id):
				_voice_db.erase(id)


func play(kind: String, db := 0.0, pitch := 1.0, bus := "SFX", sound_override := "", priority_override := -1) -> bool:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind, cue_context())
	if kind.ends_with("_refused"):
		_menu_sounds.refused()
	if not _admit(kind, sound, pitch):
		return false
	var tier := SfxBank.resolve(sound, pitch)
	db += story_duck_db(kind)
	var priority := Rows.priority(kind) if priority_override < 0 else priority_override
	if _is_telegraph(kind, sound):
		_focus()
	elif priority < 2 and bus == "SFX" and sound in MixRows.CROWD_SOUNDS:
		db += MixRows.crowd_db(_live_sfx_voices(), priority)
	var asked := pitch
	pitch = float(tier["pitch"])
	if sound in KEYED_SOUNDS or sound in KEST_SOUNDS:
		pitch *= Harmony.ratio(live_key())
		asked *= Harmony.ratio(live_key())
	_logged_pitch = asked if tier["id"] != sound else -1.0
	_start(kind, sound, SfxBank.stream(tier["id"]), SfxBank.trim_db(tier["id"]) + PRIORITY_DB[priority] + db, pitch, bus)
	_logged_pitch = -1.0
	if bus == "SFX":
		_live_sfx += 1
		if MixRows.MAKE_ROOM.has(sound):
			_make_room(kind, sound)
	if priority >= 2:
		_duck(0.55, 0.35)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, 0.45)
	return true


const HEARD_NEAR_M := 10.0
const HEARD_FAR_M := 45.0
const HEARD_FAR_DB := -12.0


func play_at(kind: String, at: Vector3, db := 0.0, pitch := 1.0, bus := "SFX", sound_override := "") -> bool:
	return play(kind, db + distance_db(at), pitch, bus, sound_override)


func distance_db(at: Vector3) -> float:
	var ball = ctx.player if ctx != null else null
	if ball == null or not is_instance_valid(ball) or not ball.has_method("shown_position"):
		return 0.0
	var far := (at.distance_to(ball.shown_position()) - HEARD_NEAR_M) / (HEARD_FAR_M - HEARD_NEAR_M)
	return HEARD_FAR_DB * clampf(far, 0.0, 1.0)


const WARDEN_FIGHT := "warden"

const STORY_KIND := "story_sting"
const STORY_DUCKED := ["run_started", "world_entered", "stage_entered", "rescue_completed", "beacon_unsealed"]
const STORY_QUESTS := ["rivet"]
const STORY_DUCK_DB := -14.0
const STORY_HOLD_MS := 2500
var _story_until_ms := 0


func story_sting(name: String) -> bool:
	_story_until_ms = Time.get_ticks_msec() + STORY_HOLD_MS
	return play(STORY_KIND, 0.0, 1.0, "SFX", SfxBank.stinger_id("1_1", name))


func story_duck_db(kind: String) -> float:
	if kind in STORY_DUCKED and Time.get_ticks_msec() < _story_until_ms:
		return STORY_DUCK_DB
	return 0.0


func chirp(cue: String, now := -1.0) -> bool:
	var kind := String(Companion.CUES.get(cue, {}).get("chirp", ""))
	if kind == "":
		return false
	if now < 0.0:
		now = Time.get_ticks_msec() / 1000.0
	var fired: bool = not _chirp_last.has(cue) or now - float(_chirp_last[cue]) >= CHIRP_COOLDOWN
	chirp_log.append([cue, kind, String(EventKinds.UI_ROWS.get(kind, {}).get("sound", "")), now, fired])
	if chirp_log.size() > CHIRP_LOG_CAP:
		chirp_log.pop_front()
	if not fired:
		return false
	_chirp_last[cue] = now
	var sting := SfxBank.assist_sting_id(cue.trim_prefix("assist_"), _heft_class, _motif) if cue.begins_with("assist_") else ""
	if sting != "":
		on_beat(kind, 0.0, false, 1, sting)
		return true
	play(kind, 0.0, 1.0, "UI")
	return true


func speak(kind: String, text: String, beat: int) -> bool:
	if text == "" or not _admit(kind, "babble", 1.0):
		return false
	var live := live_key()
	var key := "%d|%d|%s" % [beat, live, text]
	if not _babble.has(key) and bakes_ahead:
		_babble_asked["%d|%s" % [beat, text]] = key
		_babble_queue.append([key, kind, text, beat, live])
		_next_babble()
		return true
	if not _babble.has(key):
		_babble[key] = Synth.to_wav(SfxBank.babble(text, beat, live))
	_start(kind, "babble", _babble[key], SfxBank.trim_db("babble"), 1.0, "SFX")
	return true


func babble_state(text: String, beat: int) -> String:
	var key: String = _babble_asked.get("%d|%s" % [beat, text], "%d|%d|%s" % [beat, live_key(), text])
	if _babble.has(key):
		return "ready"
	if String(_babble_job.get("key", "")) == key or _babble_queue.any(func(ask: Array): return ask[0] == key):
		return "rendering"
	return "none"


static func band_bakes() -> Dictionary:
	var held := _opening_task >= 0 or _rest_task >= 0
	var running := (_opening_task >= 0 and not WorkerThreadPool.is_task_completed(_opening_task)) \
		or (_rest_task >= 0 and not WorkerThreadPool.is_task_completed(_rest_task))
	return {"held": held, "running": running}


func _next_babble() -> void:
	if not _babble_job.is_empty() or _babble_queue.is_empty():
		return
	var ask: Array = _babble_queue.pop_front()
	var out: Array = []
	var task := WorkerThreadPool.add_task(func(): out.append(SfxBank.babble(ask[2], ask[3], ask[4])), true, "babble")
	_babble_job = {"key": ask[0], "kind": ask[1], "task": task, "out": out}


func _tend_babble() -> void:
	if _babble_job.is_empty() or not WorkerThreadPool.is_task_completed(_babble_job.task):
		return
	WorkerThreadPool.wait_for_task_completion(_babble_job.task)
	var key: String = _babble_job.key
	if not _babble.has(key) and not _babble_job.out.is_empty():
		_babble[key] = Synth.to_wav(_babble_job.out[0])
	if _babble.has(key) and not _babble_job.get("silent", false):
		_start(_babble_job.kind, "babble", _babble[key], SfxBank.trim_db("babble"), 1.0, "SFX")
	_babble_job = {}
	_next_babble()


func _settle_babble() -> void:
	if not _babble_job.is_empty():
		WorkerThreadPool.wait_for_task_completion(_babble_job.task)
	_babble_job = {}
	_babble_queue.clear()


func _drop_babble() -> void:
	_babble_queue.clear()
	if not _babble_job.is_empty():
		_babble_job["silent"] = true


func call_in(kind: String, speaker: String, text: String) -> float:
	if text == "" or clock < float(_gates.get("call_in", -1000.0)) or clock < _focus_until or not _admit(kind, "babble", 1.0):
		return 0.0
	var step := grid_unit(4)
	var at := engine.clock + int(CALL_LEAD_S * Harmony.RATE)
	if SfxBank.caller_on_grid(speaker):
		at += posmod(next_grid(4) - at, step)
	var id := SfxBank.say_id(speaker, text)
	SfxBank.keep_said(id)
	engine.schedule_stinger_at(id, at, 0.0, false, step)
	var seconds := float(at - engine.clock) / Harmony.RATE + SfxBank.say_seconds(speaker, text, step)
	_gates["call_in"] = clock + seconds
	_calling = id
	_duck(CALL_DUCK, seconds)
	_log_cue([kind, "babble", "call", at, 1.0])
	return seconds


func call_end() -> void:
	if _calling == "" or clock >= float(_gates.get("call_in", -1000.0)):
		return
	engine.cancel_stinger(_calling)
	engine.free_duck()
	if ace_playing():
		ace.free_duck()
	_gates["call_in"] = clock
	_calling = ""
	_log_cue(["call_end", "babble", "now", engine.clock, 1.0])


func cue_context() -> Dictionary:
	return {"motif": _motif}


func _admit(kind: String, sound: String, pitch: float) -> bool:
	if not sound_ready or sound == "":
		_log_cue([kind, sound, "skip", -1, pitch])
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(sound, -100000)) < int(MIN_GAP_MS.get(sound, 0)):
		_log_cue([kind, sound, "skip", -1, pitch])
		return false
	_last_start[sound] = now
	return true


func _start(kind: String, sound: String, stream: AudioStream, volume: float, pitch: float, bus: String) -> void:
	var playback := _ui if bus == "UI" else _sfx
	if playback != null:
		var cls := SfxBudget.voice_class(kind, _is_telegraph(kind, sound), bus)
		for old_id in _sfx_budget.reserve(cls, playback.is_stream_playing):
			playback.stop_stream(old_id)
		var live: Array = _voices.get(sound, [])
		live = live.filter(func(id: int): return playback.is_stream_playing(id))
		if live.size() >= int(VOICE_LIMIT.get(sound, MixRows.VOICE_DEFAULT)):
			playback.stop_stream(live.pop_front())
		var room := _room_offset(sound, false) if playback == _sfx else 0.0
		var id := playback.play_stream(stream, 0.0, volume + room, pitch, AudioServer.PLAYBACK_TYPE_DEFAULT, bus)
		if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			live.append(id)
			_sfx_budget.record(cls, id)
			if playback == _sfx:
				_voice_db[id] = [sound, volume, engine.clock]
				if room != 0.0:
					_roomed[id] = volume
					_log_gain(kind, sound, "duck", engine.clock, room)
		_voices[sound] = live
	last_play_frame = Engine.get_process_frames()
	_log_cue([kind, sound, "now", engine.clock, pitch if _logged_pitch < 0.0 else _logged_pitch, volume])


func note_cue(kind: String, sound: String, volume: float, bus := "SFX") -> void:
	if engine == null:
		return
	var against := float(BUSES.get(bus, 0.0)) + float(mix_db.get(bus, 0.0)) - float(BUSES["SFX"]) - float(mix_db.get("SFX", 0.0))
	_log_cue([kind, sound, "now", engine.clock, 1.0, volume + against])


func stop(sound: String) -> void:
	if _sfx != null:
		for id in _voices.get(sound, []):
			if _sfx.is_stream_playing(id):
				_sfx.stop_stream(id)
	_voices.erase(sound)


func _on_node_added(node: Node) -> void:
	if node.has_method("threat_kind"):
		_warn_threat.call_deferred(node)


func _warn_threat(node: Node) -> void:
	if not is_instance_valid(node) or not node.is_inside_tree() or not node.is_in_group("threat"):
		return
	var kind: String = node.threat_kind()
	var row: Dictionary = EventKinds.THREAT_ROWS.get(kind, {})
	if row.is_empty():
		return
	var db: float = PRIORITY_DB[int(row["priority"])] - PRIORITY_DB[Rows.priority(kind)] - _threat_distance_db(node)
	var sounded := play(kind, db, 1.0, "SFX", row["sound"])
	for layer in [node.get("owner_voice"), node.get("mechanic_tag")]:
		if layer is String and layer != "":
			play(kind, db, 1.0, "SFX", layer)
	if int(row["priority"]) >= 2:
		engine.duck(0.55, 0.35)
	if kind in THREAT_RELEASE and node.has_signal("went_live"):
		if sounded:
			var voices: Array = _voices.get(row["sound"], [])
			lane_hums[node.get_instance_id()] = voices.back() if not voices.is_empty() else -1
		node.went_live.connect(_release_threat.bind(node, kind), CONNECT_ONE_SHOT)
		node.tree_exiting.connect(_end_hum.bind(node.get_instance_id()), CONNECT_ONE_SHOT)


func _release_threat(node: Node, kind: String) -> void:
	_end_hum(node.get_instance_id())
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var row: Dictionary = EventKinds.THREAT_ROWS[kind]
	play(kind, PRIORITY_DB[int(row["priority"])] - PRIORITY_DB[Rows.priority(kind)] - _threat_distance_db(node), 1.0, "SFX", THREAT_RELEASE[kind])


func _end_hum(node_id: int) -> void:
	if not lane_hums.has(node_id):
		return
	var id: int = lane_hums[node_id]
	lane_hums.erase(node_id)
	if id >= 0 and _sfx != null and _sfx.is_stream_playing(id):
		_sfx.stop_stream(id)
	_log_cue(["threat_lane", EventKinds.THREAT_ROWS["threat_lane"]["sound"], "stop", engine.clock, 1.0])


func _threat_distance_db(node: Node) -> float:
	if ctx == null or ctx.player == null or not node.has_method("threat_at"):
		return 0.0
	var gap: float = (node.threat_at() as Vector3).distance_to(ctx.player.shown_position())
	return 9.0 * clampf((gap - 20.0) / 40.0, 0.0, 1.0)


func on_beat(kind: String, db := 0.0, lane := false, repeats := 1, sound_override := "") -> int:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind, cue_context())
	if not sound_ready or sound == "":
		_log_cue([kind, sound, "skip", -1, 1.0])
		return -1
	var start := engine.schedule_stinger(sound, db + story_duck_db(kind), lane, repeats)
	var beats: int = SfxBank.STINGER_BEATS.get(sound, 1)
	_duck(0.6, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	if _is_telegraph(kind, sound):
		_focus_until = maxf(_focus_until, clock + float(start - engine.clock) / Harmony.RATE + float(MixRows.FOCUS["hold_s"]))
	_log_cue([kind, sound, "beat", start, 1.0])
	return start


func _connect_all(events) -> void:
	_wire_cannon(events)
	events.run_started.connect(func(class_id: String):
		_ready_for_run()
		_set_overtime = false
		_heft_class = 1
		_boss_phase = 1
		_phase_music_done = 0
		_hull_seen = 0.0
		_fired_this_run.clear()
		_posture_seen.clear()
		_guard_steps.clear()
		_guard_warned.clear()
		_cadence_prev.clear()
		_visited_sites_seen.clear()
		_cable_flips = 0
		_sync_rail_ids()
		_synth_form_state = "closed"
		_line_was = ""
		_motif = motif_of(class_id)
		engine.set_class_motif(_motif)
		engine.set_fleet_ticks(0)
		new_run_tunes()
		_flow_queue.append(["run"]))
	events.warden_engaged.connect(func(_stage: int): warden_took_band())
	events.activity_done.connect(func(id: String, at: Vector3):
		end_moment("event", id)
		if id == "cracked_cache":
			_play_site_flip("cracked_cache:%d,%d" % [roundi(at.x), roundi(at.z)])
		else:
			_play_site_flip("activity:%s:%d,%d" % [id, roundi(at.x), roundi(at.z)]))
	events.synergy_discovered.connect(func(id: String, _category: String, _first: bool): tune_found(id))
	events.flow_changed.connect(_on_flow_changed)
	events.world_entered.connect(func(world: int): _flow_queue.append(["world", world]))
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(stage: int): _flow_queue.append(["clear", stage]))
	events.run_ended.connect(func(won: bool):
		engine.set_reactor_pedal(false)
		_boss_phase = 1
		_phase_music_done = 0
		_cadence_prev.clear()
		_visited_sites_seen.clear()
		_cable_flips = 0
		_sync_rail_ids()
		_line_was = ""
		_stop_hum()
		_flow_queue.append(["end", won]))
	events.beacon_charge_changed.connect(_on_beacon)
	events.scrap_collected.connect(_on_scrap)
	events.cogs_collected.connect(_on_cogs)
	events.achievement_earned.connect(func(_id: String): play("achievement_earned"))
	events.rescue_completed.connect(func(quest: String):
		if quest in STORY_QUESTS:
			_story_until_ms = Time.get_ticks_msec() + STORY_HOLD_MS
		play("rescue_completed")
		_play_site_flip("cage:" + quest))
	events.part_gained.connect(func(_part: String, _source: String): play("part_gained"))
	events.player_hit.connect(_on_player_hit)
	events.player_died.connect(_on_died)
	events.enemy_killed.connect(_on_kill)
	events.milestone_won.connect(func(_event_id: String): _flow_queue.append(["milestone"]))
	events.jumped.connect(func(air: bool): play("jumped", 0.0, Harmony.ratio(7.0) if air else 1.0))
	events.boosted.connect(func(_direction: Vector3): play("boosted"))
	events.dashed.connect(func(_direction: Vector3): play("dashed"))
	events.landed.connect(_on_landed)
	events.slammed.connect(_on_slammed)
	_connect_dunk()
	_connect_redline()
	events.mounted.connect(func(_at: Vector3, banked: float): play("mounted", 0.0, Harmony.ratio(minf(banked / 4.0, 7.0))))
	events.dismounted.connect(_on_dismounted)
	events.enemy_spawned.connect(_on_enemy_spawned)
	events.enemy_struck.connect(_on_struck)
	events.shot_fired.connect(_on_shot)
	events.special_used.connect(func(_special: String, _at: Vector3):
		play("special_used")
		skill_answer("special_used", null))
	events.gauge_released.connect(func(_id: String, _fraction: float): skill_answer("gauge_released", null))
	events.line_skill_fired.connect(func(_id: String, target: Node3D, _at: Vector3, _on: String):
		skill_answer("line_skill_fired", target))
	events.active_fired.connect(_on_active_fired)
	events.active_heat.connect(_on_active_heat)
	events.reward_offered.connect(_on_offered)
	events.reward_chosen.connect(func(_part: String): play("reward_chosen"))
	events.event_announced.connect(_on_event_announced)
	events.event_started.connect(_on_event_started)
	events.event_ended.connect(_on_event_ended)
	events.launched.connect(_on_launched)
	events.pressure_changed.connect(_on_pressure)
	events.run_started.connect(func(_class_id: String): _set_ult_lift(false))
	events.ultimate_ready.connect(_on_ultimate_ready)
	events.ultimate_started.connect(_on_ultimate_started)
	events.ultimate_peak.connect(_on_ultimate_peak)
	events.ultimate_landed.connect(_on_ultimate_landed)
	events.ultimate_cancelled.connect(_on_ultimate_cancelled)
	events.line_skill_loaded.connect(func(_id: String, _seconds: float): play("line_skill_loaded"))
	events.line_skill_fired.connect(_sable_bank)
	events.stage_content_cleared.connect(func(_reason: String): _sable_bank_wait = false)
	events.player_died.connect(func(): _sable_bank_wait = false)
	events.dismounted.connect(func(_v: Vector3):
		if _sable_bank_wait:
			_sable_bank_wait = false
			_sable_bank_sound())
	events.line_skill_fired.connect(_on_tarn_claw_drag)
	events.line_skill_fired.connect(_on_rivet_line_drive)
	_wire_tally(events)
	_wire_ultimate_beat()
	wire_optional()
	_wire_armor()


func wire_optional() -> void:
	var events = ctx.events
	_wire_armor()
	_wire_rail()
	_listen_optional(events, "beacon_unsealed", func(_stage: int):
		_warden_fighting = false
		_flow_queue.append(["unseal"]))
	_listen_optional(events, "heft_class_changed", _on_heft_class)
	_listen_optional(events, "heft_class_dropped", _on_heft_dropped)
	_listen_optional(events, "scrap_lost", func(amount: int, _at: Vector3, _total: int, _cause: String): play("scrap_lost", clampf(amount / 20.0, 0.0, 1.0) * 4.0 - 3.0))
	_listen_optional(events, "strike_deflected", _on_deflected)
	_listen_optional(events, "posture_changed", _on_posture_changed)
	_listen_optional(events, "threat_rose", func(tier: int):
		on_beat("threat_rose", minf(tier, 3) * 1.0)
		engine.set_fleet_ticks(tier)
		if ace_playing():
			ace.threat_rose(tier))
	_listen_optional(events, "vent_charging", func(at: Vector3, _seconds: float):
		if _is_warden_at(at):
			_warden_charging = true
			engine.parameter_danger("warden_charge")
		play("vent_charging")
		engine.set_reactor_pedal(true))
	_listen_optional(events, "vent_erupted", func(at: Vector3):
		if _is_warden_at(at):
			_warden_charging = false
		play("vent_erupted")
		engine.set_reactor_pedal(false))
	_listen_optional(events, "bay_entered", func(_banked_speed: float):
		play("bay_entered")
		engine.set_lounge(true)
		if ace_playing():
			ace.set_bay(true)
		begin_moment("shop", "bay", "moss-shop"))
	_listen_optional(events, "bay_left", func(_velocity: Vector3):
		play("bay_left")
		engine.set_lounge(false)
		if ace_playing():
			ace.set_bay(false)
		end_moment("jukebox", "bay_jukebox")
		end_moment("shop", "bay"))
	_listen_optional(events, "world_fact", func(kind: String, at: Vector3):
		var row := EventKinds.world_row(kind)
		if kind == "kindness_offered" and not row.is_empty():
			_play_kindness_chime(row)
		elif not row.is_empty():
			play("world_fact", 0.0, 1.0, "SFX", Rows.heard(row, cue_context()), int(row.get("priority", 0)))
		_set_world_fact(kind)
		if kind == "cache_spent":
			_play_site_flip("cache_spent:%d,%d" % [roundi(at.x), roundi(at.z)])
		elif kind == "warden_gate_pip" and _site_markers() == null:
			_cable_flips += 1
			_play_site_flip("cable:%d" % _cable_flips)
		if kind == "bay_jukebox":
			jukebox_flipped()
		elif kind == "fabricator_used":
			fabricator_used())
	if ctx.get("build") != null and ctx.build.has_signal("shell_air_changed") and not ctx.build.shell_air_changed.is_connected(_on_shell_air):
		ctx.build.shell_air_changed.connect(_on_shell_air)
	_listen_optional(events, "interact_armed", func(family: String, _id: String, _at: Vector3):
		play("interact_armed", 0.0, 1.0, "SFX", Rows.heard(Interactables.sound(family, "arm"), cue_context())))
	_listen_optional(events, "interact_fired", func(family: String, _id: String, _at: Vector3):
		play("interact_fired", 0.0, 1.0, "SFX", Rows.heard(Interactables.sound(family, "fire"), cue_context())))
	_listen_optional(events, "ambush_ended", func(_id: String, won: bool, _at: Vector3):
		play("ambush_ended", 0.0, 1.0, "SFX", Rows.heard(Interactables.sound("fight", "won" if won else "lost"), cue_context())))
	_listen_optional(events, "bet_resolved", func(_id: String, won: bool, _stake: int, _at: Vector3):
		play("bet_resolved", 0.0, 1.0, "SFX", Rows.heard(Interactables.sound("bet", "won" if won else "lost"), cue_context())))
	_listen_optional(events, "activity_done", func(id: String, _at: Vector3):
		if not Activities.RULES.get(id, {}).has("bundle"):
			play("activity_done", 0.0, 1.0, "SFX", Rows.heard(EventKinds.activity_row(id), cue_context())))
	_listen_optional(events, "core_gained", _on_core)
	_listen_optional(events, "drop_landed", func(_hits: int): play("drop_landed"))
	_listen_optional(events, "missed_drop", func(): play("missed_drop"), true)
	_listen_optional(events, "evolution_fired", func(_part: String): play("evolution_fired"))
	_listen_optional(events, "quick_break", func(_stage: int, _seconds: float, _at: Vector3): play("quick_break"))
	_listen_optional(events, "near_miss", _on_near_miss)
	_listen_optional(events, "synergy_discovered", _on_synergy)
	_listen_optional(events, "line_state_changed", _on_line_state)
	_listen_optional(events, "grapple_released", _stop_hum, true)
	_listen_optional(events, "verb_failed", _on_verb_failed)
	_listen_optional(events, "cause_armed", _on_cause_armed)
	_listen_optional(events, "cause_fired", _on_cause_fired)
	_listen_optional(events, "interaction_found", func(): play("interaction_found"), true)
	_listen_optional(events, "element_resolved", func(_element: String, _material: String, behaviour: String, _at: Vector3):
		play("element_resolved", 0.0, 1.0, "SFX", Rows.element_sound(behaviour)))
	_listen_optional(events, "warden_engaged", func(engaged: int):
		_read_ahead_after(engaged)
		_begin_boss("warden_engaged", "warden")
		engine.parameter_danger("warden_engaged")
		if ace_playing() and ace.flat and radio_hold == "" and _stage_now > 0 \
				and MusicArbiter.resolve(_arbiter_state())["owner"] == MusicArbiter.OWNER_WARDEN:
			_champion_hyped = false
			_moment_playing = ""
			_ace_stage(_stage_now, engine.next_bar(), true)
		elif ace_playing():
			ace.commit_warden()
		elif _ace_arrival_stage > 0 and _ace_arrival_at >= 0:
			var stage := _ace_arrival_stage
			_ace_arrival_stage = 0
			_ace_arrival_at = -1
			_ace_stage(stage, engine.next_bar(), true))
	_listen_optional(events, "boss_arena_entered", func():
		_read_ahead_phases(_boss_track())
		_boss_phase = 1
		_phase_music_done = 0
		_disarm_launch()
		_begin_boss("boss_arena_entered", _boss_track()), true)
	var phase_args := _argc(events, "boss_phase_changed")
	if phase_args >= 1:
		_listen_optional(events, "boss_phase_changed", _on_boss_phase_with.unbind(phase_args - 1) if phase_args > 1 else _on_boss_phase_with)
	else:
		_listen_optional(events, "boss_phase_changed", _on_boss_phase, true)
	_listen_optional(events, "boss_defeated", func(): _on_boss_defeated(), true)
	_listen_optional(events, "boss_attack_telegraphed", _on_boss_telegraph)
	_listen_optional(events, "attack_cued", _on_attack_cued)
	_listen_optional(events, "fight_phase_changed", _on_fight_phase)
	_listen_optional(events, "boss_weak_point_hit", _on_weak_point)
	_listen_optional(events, "boss_reeled", func(_at: Vector3, _scrap: int): play("boss_reeled"))
	_listen_optional(events, "event_progress", _on_event_progress)
	_listen_optional(events, "stage_content_cleared", func(reason: String):
		_disarm_launch()
		_event_id = ""
		_chase_lead0 = -1.0
		_cadence_prev.clear()
		_visited_sites_seen.clear()
		_cable_flips = 0
		_sync_rail_ids()
		if reason in ["arena", "arena_retry"]:
			_boss_phase = 1
			_phase_music_done = 1 if reason == "arena_retry" else 0
			engine.parameters_arena_entered()
			if ace != null:
				ace.clear_release()
		if reason == "arena_retry" and sound_ready:
			engine.cancel_pending()
			engine.fill_into(engine.restart_boss(_boss_track()))
		engine.set_overcharge(0)
		if ctx.run.has_method("heft_class"):
			_heft_class = int(ctx.run.heft_class())
			engine.set_heft_lift(_heft_class - 1)
		if reason != "arena_retry" and sound_ready and engine.mode != MusicEngine.PLAY and engine.track == _boss_track():
			engine.cancel_pending()
			engine.restart_boss(_boss_track())
		play("stage_content_cleared"))
	_listen_optional(events, "hold_started", func(kind: String, _at: Vector3):
		play("hold_started", 0.0, 1.0, "SFX", Rows.sound("hold_started", cue_context().merged({"hold": kind}))))
	_listen_optional(events, "pack_arrived", func(faction: String, _at: Vector3, _kinds: Array):
		play("pack_arrived", 0.0, 1.0, "SFX", Rows.sound("pack_arrived", cue_context().merged({"faction": faction}))))
	for kind in CHARACTER_KINDS + ENEMY_KINDS:
		if events.has_signal(kind) and not _character_wired.has(kind):
			_character_wired[kind] = true
			if kind == "vault_kicked":
				events.connect(kind, _on_vault_kicked)
			else:
				events.connect(kind, play.bind(kind).unbind(_argc(events, kind)))


static func motif_of(class_id: String) -> String:
	var def: Resource = ClassDef.by_id(class_id)
	return String(def.motif) if def != null else class_id


func _on_vault_kicked(_at: Vector3, speed: float) -> void:
	play("vault_kicked", 0.0, Harmony.ratio(12.0 * clampf(speed / Augments.VAULT_CAP, 0.0, 1.0)))


func _listen_optional(events: Object, signal_name: String, callable: Callable, loose := false) -> bool:
	if not events.has_signal(signal_name):
		return false
	var key := "%d:%s" % [events.get_instance_id(), signal_name]
	if not _optional_listeners.has(key):
		_optional_listeners[key] = callable
	return _listen(events, signal_name, _optional_listeners[key], loose)


static func _listen(events: Object, signal_name: String, callable: Callable, loose := false) -> bool:
	if not events.has_signal(signal_name):
		return false
	var target := callable
	if loose:
		var argc := SignalWire.arg_count(events, signal_name)
		if argc > 0:
			target = callable.unbind(argc)
	if events.is_connected(signal_name, target):
		return true
	if _named_listener(callable):
		for connection in events.get_signal_connection_list(signal_name):
			var connected: Callable = connection["callable"]
			if _named_listener(connected) and connected.get_object() == callable.get_object() and connected.get_method() == callable.get_method():
				return true
	events.connect(signal_name, target)
	return true


static func _named_listener(callable: Callable) -> bool:
	var named := Callable(callable.get_object(), callable.get_method())
	var bound := callable.get_bound_arguments()
	if not bound.is_empty():
		named = named.bindv(bound)
	var unbound := callable.get_unbound_arguments_count()
	if unbound > 0:
		named = named.unbind(unbound)
	return callable == named


func _gate(key: String, gap: float) -> bool:
	if clock < float(_gates.get(key, -1000.0)):
		return false
	_gates[key] = clock + gap
	return true


func _grammar_cue(kind: String, sound: String, bus := "SFX", pitch := 1.0) -> bool:
	return play(kind, -PRIORITY_DB[Rows.priority(kind)], pitch, bus, sound)


func _on_chain_state(state: String, cause: String) -> void:
	match state:
		"chain_link":
			var chaser = ctx.get("player")
			var links: int = chaser.chain.links if chaser != null and chaser.get("chain") != null else 0
			if links < 2:
				return
			var sound := EventKinds.line_sound(state)
			if sound == EventKinds.NONE or sound == "":
				return
			var steps := mini(links - 1, CHAIN_STEPS)
			if _grammar_cue("line_state_changed", sound, "SFX", Harmony.ladder_ratio(SfxBank.BITE_MIDI, steps)):
				_chain_bite_ms = clock
		"chain_end":
			if cause == "paid":
				return
			var ender = ctx.get("player")
			if ender == null or ender.get("chain") == null or ender.chain.finished.is_empty():
				return
			if int(ender.chain.finished.back()["combo"]) < 2:
				return
			var sound := EventKinds.line_sound(state)
			if sound != EventKinds.NONE and sound != "":
				_grammar_cue("line_state_changed", sound)
		"chain_miss":
			var sound := EventKinds.line_sound(state)
			if sound != EventKinds.NONE and sound != "" and _gate("dry_tick", DRY_TICK_GAP):
				_grammar_cue("line_state_changed", sound)


func _on_line_state(state: String, _target: Node3D, _at: Vector3, cause: String) -> void:
	if state.begins_with("chain_"):
		_on_chain_state(state, cause)
		return
	if state in HUM_STATES:
		_start_hum()
	else:
		_stop_hum()
	var docked := _line_was == "rewinding" and state != "rewinding"
	_line_was = state
	if docked:
		_grammar_cue("line_state_changed", EventKinds.line_sound("rewinding"))
	if state == "rewinding":
		return
	var sound := EventKinds.line_sound(state)
	if sound == EventKinds.NONE or sound == "":
		return
	match state:
		"locked":
			if not _gate("lock_tick", LOCK_TICK_GAP):
				return
		"dry_fire":
			if not _gate("dry_tick", DRY_TICK_GAP):
				return
		"latched_body":
			if clock - _chain_bite_ms > CHAIN_BITE_HOLD_S:
				_grammar_cue("harpoon_bit", sound)
			else:
				_chain_bite_ms = -100000.0
			return
		"smash_lands":
			if _recent_ms(Rows.sound("slammed")) > int(MIN_GAP_MS.get(Rows.sound("slammed"), 60)):
				_grammar_cue("harpoon_smashed", sound)
			_grammar_cue("harpoon_smashed", "smash_crack")
			return
	_grammar_cue("line_state_changed", sound)


func _recent_ms(sound: String) -> int:
	return Time.get_ticks_msec() - int(_last_start.get(sound, -100000))


func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	var sound := String(Bindings.VERBS.get(verb, {}).get("fail", EventKinds.NONE))
	if sound == EventKinds.NONE or sound == "":
		return
	if not _gate("fail:" + verb, FAIL_GAP):
		return
	if sound == "dry_tick" and not _gate("dry_tick", DRY_TICK_GAP):
		return
	_grammar_cue("verb_failed", sound)


func _on_cause_armed(id: String) -> void:
	var motif := EventKinds.cause_motif(id)
	for i in mini(2, motif.size()):
		_notes.append([clock + NOTE_SPACING * i, "cause_armed", Harmony.note_midi(String(motif[i])), id])
	_play_due_notes()


func _on_cause_fired(id: String, _target: Node3D, _at: Vector3) -> void:
	var motif := EventKinds.cause_motif(id)
	if motif.size() < 3:
		return
	var first := not _fired_this_run.has(id)
	_fired_this_run[id] = true
	if first:
		_gates["cause:" + id] = clock + CAUSE_RESOLVE_GAP
	elif not _gate("cause:" + id, CAUSE_RESOLVE_GAP):
		return
	var at := clock
	for note in _notes:
		if note.size() > 3 and note[3] == id:
			at = maxf(at, float(note[0]) + NOTE_SPACING)
	_notes.append([at, "cause_fired", Harmony.note_midi(String(motif[2])), id])
	_play_due_notes()


func _play_due_notes() -> void:
	var waiting: Array = []
	for note in _notes:
		if note[0] > clock:
			waiting.append(note)
		elif sound_ready:
			play(note[1], -PRIORITY_DB[Rows.priority(note[1])], 1.0, "SFX", SfxBank.cause_note_id(note[2]))
	_notes = waiting


static func hum_ratio(gap: float) -> float:
	return pow(2.0, clampf((HUM_FAR - gap) / (HUM_FAR - HUM_NEAR), 0.0, 1.0))


func _start_hum() -> void:
	if not sound_ready:
		return
	if not hum_on:
		hum_on = true
		if _sfx != null:
			_hum_voice = _sfx.play_stream(SfxBank.stream("line_hum"), 0.0, SfxBank.trim_db("line_hum") + HUM_DB, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, "SFX")
		_log_cue(["line_state_changed", "line_hum", "now", engine.clock, 1.0])
	_tend_hum()


func _stop_hum() -> void:
	if not hum_on:
		return
	hum_on = false
	if _sfx != null and _hum_voice != AudioStreamPlaybackPolyphonic.INVALID_ID and _sfx.is_stream_playing(_hum_voice):
		_sfx.stop_stream(_hum_voice)
	_hum_voice = -1
	hum_pitch = 1.0
	_log_cue(["line_state_changed", "line_hum", "stop", engine.clock, 1.0])


func _tend_hum() -> void:
	if ctx == null:
		return
	var player = ctx.get("player")
	if player == null or player.get("kit") == null:
		return
	var kit = player.kit
	var standing: bool = kit.hooked and not player.frozen()
	if not hum_on:
		if standing and _line_was in HUM_STATES:
			_start_hum()
		return
	if not standing:
		_stop_hum()
		return
	hum_pitch = hum_ratio(player.shown_position().distance_to(kit.anchor)) if kit.on_body else 1.0
	if _sfx != null and _hum_voice != AudioStreamPlaybackPolyphonic.INVALID_ID:
		_sfx.set_stream_pitch_scale(_hum_voice, hum_pitch)


const SHELL_RISE_SEMITONES := 7.0
const SHELL_RETURN_SEMITONES := -5.0


func _on_shell_air(_factor: float, rose: bool) -> void:
	play("world_fact", 0.0, Harmony.ratio(SHELL_RISE_SEMITONES if rose else SHELL_RETURN_SEMITONES), "SFX", Rows.heard(EventKinds.world_row("shell_air_shift"), cue_context()))


func park_transport(stage_s: float) -> Dictionary:
	_sync_park_deadlines()
	if sound_ready:
		_flush_flow()
	var bar: int = engine.bar_len()
	var origin: int = engine.next_bar()
	if engine.grid != null:
		origin = engine.grid.next_bar(engine.clock)
		bar = engine.grid.next_bar(origin + 1) - origin
	_park_transport_snapshot = {"bar_s": float(bar) / Harmony.RATE,
		"bar_origin_s": stage_s + float(origin - engine.clock) / Harmony.RATE,
		"origin": origin}
	_remap_suspended_park_cues()
	return {"bar_s": _park_transport_snapshot.bar_s, "bar_origin_s": _park_transport_snapshot.bar_origin_s}


func _park_stage_suspended() -> bool:
	if get_tree().paused:
		return true
	if ctx == null or ctx.get("root") == null:
		return false
	var world = ctx.root.get("world")
	return world != null and world.bay != null and world.bay.inside


func _remap_suspended_park_cues() -> void:
	if _park_stage_suspended():
		return
	for event_id in _park_cues:
		var cue: Dictionary = _park_cues[event_id]
		if not cue.get("remap", false):
			continue
		var state := _park_event_state(event_id)
		if state.is_empty():
			continue
		cue.landing_s = float(state.due_s)
		cue.transport = _park_transport_snapshot.duplicate()
		var mapped := _park_sample_at(cue.landing_s, cue.transport)
		var bar := roundi(float(cue.transport.bar_s) * Harmony.RATE)
		cue.due = int(cue.transport.origin) + ceili(float(mapped - int(cue.transport.origin)) / bar) * bar
		if engine.grid != null:
			cue.due = engine.grid.next_bar(maxi(mapped, engine.clock))
		cue.after_land = mapped < engine.clock or int(cue.due) != mapped
		cue.remap = false


func _park_sample_at(landing_s: float, snapshot: Dictionary) -> int:
	return int(snapshot.origin) + roundi((landing_s - float(snapshot.bar_origin_s)) * Harmony.RATE)


func _update_park_deadline(event_id: String, cue: Dictionary, state: Dictionary) -> void:
	if float(state.due_s) == float(cue.landing_s):
		return
	engine.cancel_park_drop(event_id)
	cue.landing_s = float(state.due_s)
	cue.transport = _park_transport_snapshot.duplicate()
	cue.due = _park_sample_at(cue.landing_s, cue.transport)
	cue.booked = false
	cue.after_land = false


func _sync_park_deadlines() -> void:
	for event_id in _park_cues:
		var state := _park_event_state(event_id)
		if not state.is_empty() and not _park_cues[event_id].get("remap", false):
			_update_park_deadline(event_id, _park_cues[event_id], state)


func _restore_park_drop(event_id: String, cue: Dictionary) -> void:
	if cue.booked or cue.get("remap", false):
		return
	if cue.get("after_land", false):
		var state := _park_event_state(event_id)
		var director = _park_director()
		if state.is_empty() or director == null or state.phase != director.LIVE:
			return
		cue.due = engine.next_bar() if engine.grid == null else engine.grid.next_bar(engine.clock)
		cue.after_land = false
	if int(cue.due) < engine.clock:
		if park_cue_late.size() >= LOG_CAP:
			park_cue_late.pop_front()
		park_cue_late.append({"id": event_id, "due": cue.due, "clock": engine.clock})
		return
	_book_park_drop(event_id, cue)
	cue.booked = true


func _park_director():
	if ctx == null or ctx.get("root") == null:
		return null
	var world = ctx.root.get("world")
	return world.events if world != null else null


func _park_event_state(event_id: String) -> Dictionary:
	var director = _park_director()
	if director != null:
		for state in director._park_states:
			if state.row.id == event_id and not state.weather:
				return state
	return {}


func _park_event_row(event_id: String) -> Dictionary:
	var state := _park_event_state(event_id)
	if not state.is_empty():
		return state.row
	if ctx == null or ctx.get("terrain") == null:
		return {}
	var map = ctx.terrain.map()
	if not "park" in map:
		return {}
	for row in map.park.get("event_rows", []):
		if row.id == event_id:
			return row
	return {}


func _on_event_announced(event_id: String, seconds: float, _at: Vector3) -> void:
	var state := _park_event_state(event_id)
	var row := _park_event_row(event_id)
	if row.is_empty():
		if seconds > 0.0:
			on_beat("event_announced")
		else:
			_unwarned[event_id] = true
		return
	if sound_ready:
		_flush_flow()
	engine.cancel_park_cue(event_id)
	var options := {"theme": engine.theme, "motif": _motif,
		"stage": MusicRows.zone_id(_stage_now, _music_stages()) if _stage_now > 0 else "",
		"ancient":MusicRows.ANCIENT_VOICES.get(row.effect.get("miniboss", ""), "reactor")}
	var lead := roundi(seconds * Harmony.RATE)
	var landing_s := -1.0
	if not state.is_empty():
		var fact: Dictionary = _park_director()._park_fact(state, "announced")
		landing_s = float(fact.landing_s)
		lead = roundi((landing_s - float(fact.time_s)) * Harmony.RATE)
	_set_incoming_at = clock + float(lead) / Harmony.RATE
	_park_cues[event_id] = {"row": row, "options": options, "due": engine.clock + lead,
		"landing_s": landing_s, "booked": true, "transport": _park_transport_snapshot.duplicate()}
	if landing_s >= 0.0 and not _park_transport_snapshot.is_empty():
		_park_cues[event_id].due = _park_sample_at(landing_s, _park_transport_snapshot)
	engine.park_cue(row.music_cue.telegraph, lead, engine.clock, options,
		PRIORITY_DB[Rows.priority("event_announced")], event_id)
	_book_park_drop(event_id, _park_cues[event_id])
	_duck(0.6, seconds)


func _book_park_drop(event_id: String, cue: Dictionary) -> void:
	engine.park_cue(cue.row.music_cue.land, 0, cue.due, cue.options,
		PRIORITY_DB[Rows.priority("event_started")], event_id)


func _guard_park_bookings() -> void:
	var director = _park_director()
	if director == null:
		return
	for event_id in _park_cues.keys():
		var cue: Dictionary = _park_cues[event_id]
		var state := _park_event_state(event_id)
		if state.is_empty() or state.phase not in [director.ANNOUNCED, director.LIVE]:
			engine.cancel_park_cue(event_id)
			_park_cues.erase(event_id)
			continue
		if state.phase == director.ANNOUNCED and _park_stage_suspended():
			engine.cancel_park_drop(event_id)
			cue.booked = false
			cue.remap = true
			continue
		if cue.get("remap", false):
			continue
		_update_park_deadline(event_id, cue, state)
		if state.phase == director.LIVE:
			_restore_park_drop(event_id, cue)
			continue
		var safe: bool = not state.holding and director.stage_time >= director._park_quiet_until \
			and director._park_capacity(state) and director._park_route_safe(state) \
			and director._park_clear(state, ctx.player.ball_position(), ctx.player.state.velocity, state.context)
		if not safe:
			engine.cancel_park_drop(event_id)
			cue.booked = false
		else:
			_restore_park_drop(event_id, cue)


func _park_render_limit(frames: int) -> int:
	var director = _park_director()
	if director == null or _park_stage_suspended():
		return frames
	for owner in _park_cues:
		var state := _park_event_state(owner)
		var cue: Dictionary = _park_cues[owner]
		if not state.is_empty() and state.phase == director.ANNOUNCED and not state.holding \
			and not cue.get("remap", false) and not cue.get("after_land", false):
			frames = mini(frames, maxi(0, int(cue.due) - engine.clock))
	return frames


func _park_event_land(event_id: String) -> bool:
	if not _park_cues.has(event_id):
		return false
	var cue: Dictionary = _park_cues[event_id]
	var state := _park_event_state(event_id)
	if not state.is_empty():
		_update_park_deadline(event_id, cue, state)
	_restore_park_drop(event_id, cue)
	_park_cues.erase(event_id)
	return true


func _on_event_started(event_id: String) -> void:
	begin_moment("event", event_id, TuneMoments.event_tune(event_id))
	if _park_event_land(event_id) or _unwarned.erase(event_id):
		return
	on_beat("event_started")
	if event_id in EVENT_SECONDS:
		_event_id = event_id
		_event_started_ms = Time.get_ticks_msec()
		_event_progress_live = false


func _on_event_ended(event_id: String, outcome: String) -> void:
	end_moment("event", event_id)
	if not _park_event_row(event_id).is_empty():
		engine.cancel_park_cue(event_id)
		_park_cues.erase(event_id)
		return
	var participatory := event_id == _event_id and engine.track == "level"
	_event_id = ""
	if not participatory or not sound_ready:
		on_beat("event_ended", -6.0 if outcome != "won" else 0.0)
		return
	if outcome == "won":
		var at := engine.resolve_event(true)
		if at >= 0:
			engine.schedule_stinger_at(Rows.sound("milestone_won"), at)
			_log_cue(["event_ended", Rows.sound("milestone_won"), "beat", at, 1.0])
	else:
		engine.resolve_event(false)
		_log_cue(["event_ended", "settle", "bar", engine.next_bar(), 1.0])


func _on_event_progress(event_id: String, fraction: float) -> void:
	if event_id != _event_id or not sound_ready:
		return
	_event_progress_live = true
	if engine.track != "level":
		return
	engine.escalate(clampf(fraction, 0.0, 1.0), false)


func _on_flow_changed(state: String) -> void:
	_flow_state = state
	if state != "title" and radio_hold == "":
		_release_spin()
	if state in MENU_STATES:
		play("flow_changed", 0.0, 1.0, "UI")
	if state == "title" or state == "class_select":
		_flow_queue.append(["idle"])
	if state == "boss" and sound_ready and engine.mode != MusicEngine.PLAY:
		engine.schedule_mode(engine.next_beat(), MusicEngine.PLAY)


var _flow_state := ""
var _combat := false


func mix_state() -> String:
	_combat = MixRows.combat_after(_combat, _pressure)
	var shop := _moments.any(func(m): return m.kind == "shop")
	return MixRows.resolve(_flow_state, camp_open, engine.track if engine != null else "level", _boss_phase, shop, _combat)


func _on_stage_entered(stage: int, retry: bool) -> void:
	_drop_babble()
	_stage_now = stage
	_boss_arena_track = ""
	_boss_phase = 1
	_phase_music_done = 0
	_cadence_prev.clear()
	_visited_sites_seen.clear()
	_cable_flips = 0
	_sync_rail_ids()
	_set_overtime = false
	_set_incoming_at = -1.0
	_champions.clear()
	_champion_euro.clear()
	_champion_hyped = false
	_posture_seen.clear()
	_guard_steps.clear()
	_guard_warned.clear()
	_moments.clear()
	_moment_playing = ""
	_warden_engaged = false
	_warden_fighting = false
	engine.parameters_stage_entered()
	for event_id in _park_cues:
		engine.cancel_park_cue(event_id)
	_park_cues.clear()
	_park_transport_snapshot.clear()
	_line_was = ""
	sync_ult_lift.call_deferred()
	engine.set_overcharge(0)
	if retry:
		_disarm_launch()
	elif _launch_armed:
		_landing_theme = _stage_theme(stage)
		_entered_ms = SimClock.msec()
		_launch_stage = true
	if ctx.run.has_method("heft_class"):
		_heft_class = int(ctx.run.heft_class())
		engine.set_heft_lift(_heft_class - 1)
	_beacon_rung = -1
	_gates_announced = false
	scrap_streak.reset()
	kill_streak.reset()
	reclaim_streak.reset()
	_streak_landed_ms = kill_streak.last_ms
	engine.set_fleet_ticks(0)
	engine.set_reactor_pedal(false)
	_event_id = ""
	_flow_queue.append(["stage", stage, retry])
	_warm_park_risers.call_deferred(stage)


func _warm_park_risers(stage: int) -> void:
	if ctx == null or ctx.get("terrain") == null:
		return
	var map = ctx.terrain.map()
	if not "park" in map:
		return
	var zone := MusicRows.zone_id(stage, _music_stages())
	var ids: Array[String] = []
	for row in map.park.get("event_rows", []):
		var cue := String(row.get("music_cue", {}).get("telegraph", ""))
		var sound := SfxBank.stinger_id(zone, cue)
		if cue != "" and not sound in ids and SfxBank.file_exists(sound):
			ids.append(sound)
	engine.warm_samples(ids)


func _on_beacon(fraction: float) -> void:
	var rung := 10 if fraction >= 1.0 else int(fraction * 8.0)
	if rung <= _beacon_rung:
		return
	_beacon_rung = rung
	play("beacon_charge_changed", 2.0 if rung == 10 else 0.0, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_player_hit(amount: float, _source: String) -> void:
	if _armor_on():
		var hull := float(ctx.run.metrics.get("hull_damage", 0.0))
		var took := hull if hull < _hull_seen else hull - _hull_seen
		_hull_seen = hull
		var shed := _shed_heard
		_shed_heard = false
		if took <= 0.0001:
			if not shed:
				play("armor_deflect")
			return
		amount = took
	play("player_hit", clampf(amount / 10.0, 0.0, 1.0) * 4.0 - 4.0)


func _armor_on() -> bool:
	var run = ctx.get("run")
	return run != null and bool(run.get("armor_mode"))


func _wire_armor() -> void:
	var run = ctx.get("run")
	if run != null and run.has_signal("armor_hit") and not run.armor_hit.is_connected(_on_armor_hit):
		run.armor_hit.connect(_on_armor_hit)
	var combat = ctx.get("spawner")
	var trail = combat.get("wear_trail") if combat != null else null
	if trail != null and not trail.patched.is_connected(_on_wear_patch):
		trail.patched.connect(_on_wear_patch)
	var build = ctx.get("build")
	var field = build.get("scrap") if build != null else null
	if field != null and field.has_signal("recovered") and not field.recovered.is_connected(_on_spill_recovered):
		field.recovered.connect(_on_spill_recovered)


func _on_armor_hit(removed: float, _spill: int, _source: String) -> void:
	_shed_heard = true
	var size := clampf(removed / ARMOR_SHED_FULL, 0.0, 1.0)
	var sound := "armor_shed_small" if removed < ARMOR_SHED_BIG_FROM * 0.4 else ("armor_shed_big" if removed >= ARMOR_SHED_BIG_FROM else "armor_shed")
	play("armor_hit", lerpf(-2.0, 2.0, size), Harmony.ratio(lerpf(2.0, -3.0, size)), "SFX", sound)


func _on_wear_patch(_at: Vector3) -> void:
	play("wear_sputter")


func _on_spill_recovered(value: int) -> void:
	var rung: int = reclaim_streak.bump(Time.get_ticks_msec())
	play("armor_reclaim", clampf(value / 8.0, 0.0, 1.0) * 1.5 - 1.0, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_scrap(amount: int, _at: Vector3, _total: int) -> void:
	var rung: int = scrap_streak.bump(Time.get_ticks_msec())
	play("scrap_collected", minf(amount, 5.0) * 0.6, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_cogs(amount: int, _total: int) -> void:
	var rung: int = cog_streak.bump(Time.get_ticks_msec())
	play("cogs_collected", minf(amount, 5.0) * 0.6, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_enemy_spawned(enemy: Node3D, kind: String) -> void:
	if SpecialAudio.is_special(kind):
		special_spawned(enemy, kind)
		return
	if enemy != null and enemy.get("affix") is Dictionary and not (enemy.get("affix") as Dictionary).is_empty():
		_champion_joined(enemy)
	var boss := is_miniboss(kind)
	if not Roster.is_ancient(Roster.faction_of(kind)):
		play("enemy_spawned", 3.0 if boss else 0.0, Harmony.ratio(-5.0) if boss else 1.0)
	if boss:
		_miniboss = enemy
	if boss and sound_ready and radio_hold == "":
		engine.begin_miniboss()
	if boss and enemy != null:
		var key := str(enemy.get_instance_id())
		enemy.tree_exiting.connect(end_moment.bind("miniboss", key), CONNECT_ONE_SHOT)
		enemy.tree_exiting.connect(_on_miniboss_gone.bind(enemy), CONNECT_ONE_SHOT)
		begin_moment("miniboss", key, miniboss_tune(kind))


func special_spawned(enemy: Node3D, name: String) -> void:
	if enemy == null or not is_instance_valid(enemy) or not SpecialAudio.is_special(name):
		return
	var id := enemy.get_instance_id()
	if _specials.has(id):
		return
	var player: AudioStreamPlayer3D = null
	if sound_ready:
		player = SpecialAudio.presence_player(name)
		enemy.add_child(player)
	_specials[id] = {"node": enemy, "name": name, "player": player}
	on_beat("special_spawn", 0.0, false, 1, SpecialAudio.cue(name, "spawn"))
	if enemy.has_signal("special_tell"):
		enemy.connect("special_tell", func(moment: String): if moment == "tell": special_tell(enemy))
	if enemy.has_signal("dispatched"):
		enemy.connect("dispatched", func(_add = null): special_drop(enemy))
	if enemy.has_signal("died"):
		enemy.connect("died", func(_a = null, _b = null): special_broken(enemy))
	enemy.tree_exiting.connect(_special_gone.bind(id), CONNECT_ONE_SHOT)


func special_tell(enemy: Node3D) -> bool:
	var row: Dictionary = _specials.get(enemy.get_instance_id(), {})
	if row.is_empty():
		return false
	return play("special_tell", 0.0, 1.0, "SFX", SpecialAudio.cue(row["name"], "tell"))


func special_drop(enemy: Node3D) -> int:
	var row: Dictionary = _specials.get(enemy.get_instance_id(), {})
	if row.is_empty():
		return -1
	return on_beat("special_drop", SpecialAudio.DROP_DB, false, 1, SpecialAudio.cue(row["name"], "drop"))


func special_broken(enemy: Node3D) -> bool:
	var id := enemy.get_instance_id()
	var row: Dictionary = _specials.get(id, {})
	if row.is_empty():
		return false
	_specials.erase(id)
	var player = row["player"]
	if player != null and is_instance_valid(player):
		player.stop()
	return play("special_break", 0.0, 1.0, "SFX", SpecialAudio.cue(row["name"], "break", SpecialAudio.rammed(enemy)))


func _special_gone(id: int) -> void:
	_specials.erase(id)


func _tend_specials() -> void:
	if _specials.is_empty():
		specials_heard = []
		return
	var from := Vector3.ZERO
	var player = ctx.get("player") if ctx != null else null
	if player != null and player.has_method("shown_position"):
		from = player.shown_position()
	var distances := {}
	for id in _specials.keys():
		var row: Dictionary = _specials[id]
		if not is_instance_valid(row["node"]):
			_specials.erase(id)
			continue
		distances[id] = (row["node"] as Node3D).global_position.distance_to(from)
	specials_heard = SpecialAudio.heard(distances)
	for id in _specials:
		var p = _specials[id]["player"]
		if p == null or not is_instance_valid(p):
			continue
		var loud: bool = id in specials_heard
		if loud and not p.playing:
			p.play()
		elif not loud and p.playing:
			p.stop()


func _begin_boss(kind: String, music: String) -> void:
	if not sound_ready:
		return
	if kind == "boss_arena_entered":
		radio_finale = false
		_champion_hyped = false
		_synth_form_state = "closed"
	if music in MusicEngine.BOSS_TRACKS:
		_boss_arena_track = music
	if radio_hold != "":
		if radio_pinned:
			on_beat(kind, 0.0, true)
			_radio_boss = [kind, music]
			return
		_radio_drop("boss")
	if engine.track == music or engine.mode != MusicEngine.PLAY:
		engine.cancel_pending()
		var again := engine.restart_boss(music)
		_phase_music_done = 1
		if music in MusicEngine.BOSS_TRACKS:
			_ace_named(_boss_entry(music), again, true)
		_log_cue([kind, "restart", "beat", again, 1.0])
		return
	var at := engine.begin_boss(music)
	if at < 0:
		return
	_phase_music_done = 1
	if music in MusicEngine.BOSS_TRACKS:
		_ace_named(_boss_entry(music), at, true)
	var sound := Rows.sound(kind)
	if sound != "":
		engine.schedule_stinger_at(sound, at)
	_log_cue([kind, sound, "bar", at, 1.0])


func _on_boss_phase() -> void:
	_boss_phase += 1
	_trigger_boss_phase(_boss_phase)


func _on_boss_phase_with(phase) -> void:
	var next := int(phase)
	if next <= 1:
		_boss_phase = maxi(next, 1)
		_set_boss_phase_section(_boss_phase)
		phase_music(_boss_phase)
		return
	if next <= _boss_phase:
		return
	_boss_phase = next
	_trigger_boss_phase(_boss_phase)


func _set_boss_phase_section(phase: int) -> void:
	if engine == null:
		return
	var boss := engine.track
	if phase <= PhaseMusic.LAST_PHASE and boss in MusicEngine.BOSS_TRACKS:
		engine.set_boss_state("%s:%d" % [boss, clampi(phase, 1, PhaseMusic.LAST_PHASE)])
	else:
		engine.set_brindle_phase(phase)


func _trigger_boss_phase(phase: int) -> void:
	_set_boss_phase_section(phase)
	var plan := phase_music(phase)
	if plan.has("at"):
		_clash_at("boss_phase_changed", int(plan["at"]))
	else:
		on_beat("boss_phase_changed")


func _clash_at(kind: String, at: int) -> int:
	var sound := Rows.sound(kind, cue_context())
	if not sound_ready or sound == "":
		_log_cue([kind, sound, "skip", -1, 1.0])
		return -1
	engine.schedule_stinger_at(sound, at, story_duck_db(kind))
	var beats: int = SfxBank.STINGER_BEATS.get(sound, 1)
	var hold := float(maxi(at - engine.clock, 0) + beats * Harmony.BEAT) / Harmony.RATE
	_duck(0.6, hold)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, hold)
	_log_cue([kind, sound, "beat", at, 1.0])
	return at


func phase_music(phase: int) -> Dictionary:
	var boss := engine.track
	if PhaseMusic.is_final(phase) and sound_ready:
		if radio_hold != "":
			var held_kind := String(_radio_boss[0]) if not _radio_boss.is_empty() else "boss_arena_entered"
			var held_boss := _active_boss_track()
			if held_boss in MusicEngine.BOSS_TRACKS:
				_radio_drop("finale")
				_begin_boss(held_kind, held_boss)
				_phase_music_done = 1
				boss = held_boss
		radio_finale = true
	if radio_hold != "":
		return {}
	if not boss in MusicEngine.BOSS_TRACKS and (_in_boss_arena() or _boss_arena_track != ""):
		boss = _active_boss_track()
	if not sound_ready or phase <= _phase_music_done or not ace_wanted():
		return {}
	if not boss in MusicEngine.BOSS_TRACKS:
		return {}
	_phase_music_done = phase
	if PhaseMusic.is_final(phase):
		var plan := PhaseMusic.final_plan(boss, pack_available)
		if plan["track"] == "":
			return {}
		var when := PhaseMusic.drop_plan(engine.clock, _next_bar(), _bar_len(), Harmony.RATE)
		if plan["hype"]:
			engine.schedule_stinger_at("hype_drop", int(when["start"]))
			_log_cue(["boss_phase_music", "hype_drop", "beat", int(when["start"]), 1.0])
		_ace_named(plan["track"], int(when["drop"]), true)
		_log_cue(["boss_phase_music", plan["track"], "bar", int(when["drop"]), 1.0])
		var lift := Worlds.boss_finale_lift(boss)
		if lift > 0:
			_log_cue(["boss_phase_music", "mind_finale_lift", "bar", int(when["drop"]), Harmony.ratio(float(lift))])
		return {"track": plan["track"], "hype": plan["hype"], "at": when["drop"], "lift_semitones": lift}
	var track := PhaseMusic.track_for_phase(boss, phase, pack_available)
	if track == "" or not pack_available.call(track):
		return {}
	var at := _next_bar()
	_ace_named(track, at, true)
	_log_cue(["boss_phase_music", track, "bar", at, 1.0])
	return {"track": track, "hype": false, "at": at}


func _champion_joined(enemy: Node3D) -> void:
	var id := enemy.get_instance_id()
	if _champions.has(id):
		return
	_champions[id] = enemy
	if enemy.has_signal("died"):
		enemy.connect("died", func(_a = null, _b = null): _champion_gone(id))
	enemy.tree_exiting.connect(_champion_gone.bind(id), CONNECT_ONE_SHOT)
	if _champion_hyped or not sound_ready or not ace_wanted() or engine.track != "level":
		return
	if MusicArbiter.resolve(_arbiter_state())["owner"] != MusicArbiter.OWNER_CHAMPION:
		return
	var champion := _champion_pack_id()
	if champion == "":
		return
	_champion_hyped = true
	_ace_named(champion, engine.next_bar(), true)
	_log_cue(["champion_joined", champion, "bar", engine.next_bar(), 1.0])


func _champion_gone(id: int) -> void:
	if not _champions.has(id):
		return
	_champions.erase(id)
	_champion_euro.erase(id)
	if _champions.is_empty() and _champion_hyped:
		_champion_hyped = false
		if _stage_now > 0 and engine.track == "level":
			var owner := String(MusicArbiter.resolve(_arbiter_state())["owner"])
			if owner in [MusicArbiter.OWNER_STAGE, MusicArbiter.OWNER_MOMENT]:
				_ace_stage(_stage_now, engine.next_bar())
				_log_cue(["champion_gone", "stage", "bar", engine.next_bar(), 1.0])


func new_run_tunes() -> void:
	_moments.clear()
	_moment_playing = ""
	_remix_rng.randomize()
	_remixes = TuneMoments.roll_remixes(_remix_rng)
	if not _remixes.is_empty():
		_log_cue(["tune_remixes", ",".join(_remixes.values()), "run", engine.clock, 1.0])


func level_tune(stage: int, fight := false) -> String:
	var top := "" if fight else TuneMoments.top(_moments, tune_available)
	if top != "":
		return top
	return TuneMoments.stage_tune(MusicRows.zone_id(stage, _music_stages()), _run_modifiers(), _remixes, tune_available)


func _run_modifiers() -> Array:
	var build = ctx.get("build") if ctx != null else null
	var clock = build.get("clock") if build != null else null
	return clock.tags() if clock != null and clock.has_method("tags") else []


func _boss_entry(music: String) -> String:
	return TuneMoments.remixed(music, PhaseMusic.entry_track(music, pack_available), _remixes, tune_available)


func begin_moment(kind: String, key: String, id: String) -> void:
	if id == "" or (_warden_fighting and kind in TuneMoments.NOT_IN_A_FIGHT):
		return
	end_moment(kind, key, false)
	_moment_seq += 1
	var until := -1
	if kind in TuneMoments.ONE_PASS:
		until = engine.next_bar() + TuneMoments.pass_frames(id)
	_moments.append({"id": id, "kind": kind, "key": key, "seq": _moment_seq, "until": until})
	_refresh_moment()


func end_moment(kind: String, key := "", refresh := true) -> void:
	var before := _moments.size()
	_moments = _moments.filter(func(m): return not (m.kind == kind and (key == "" or m.key == key)))
	if refresh and _moments.size() != before:
		_refresh_moment()


func _refresh_moment(fight := false) -> void:
	if radio_hold != "" or not sound_ready or not ace_wanted() or _champion_hyped or _stage_now <= 0:
		return
	if not engine.track in ["level", "miniboss"]:
		return
	var want := "" if fight else TuneMoments.top(_moments, tune_available)
	if want == _moment_playing:
		return
	_moment_playing = want
	var at := engine.next_bar()
	_ace_stage(_stage_now, at, fight)
	_log_cue(["tune_moment", want if want != "" else "stage", "bar", at, 1.0])


func _tend_moments() -> void:
	for m in _moments:
		if int(m.until) >= 0 and engine.clock >= int(m.until):
			end_moment(m.kind, m.key)
			return


func activity_cue(activity_id: String, phase: String) -> void:
	if phase == "telegraph":
		begin_moment("event", activity_id, TuneMoments.activity_tune(activity_id))


func jukebox_flipped() -> void:
	if _moments.any(func(m): return m.kind == "jukebox"):
		end_moment("jukebox")
	elif not TuneRows.shut("secret-after-hours", ctx.get("profile"), _sitting()):
		begin_moment("jukebox", "bay_jukebox", "secret-after-hours")


func _sitting() -> bool:
	var tuning = ctx.get("tuning")
	return tuning != null and tuning.sitting()


func fabricator_used() -> void:
	begin_moment("fabricator", "fabricator_used", TuneMoments.tune_for("fabricator", "fabricator_used"))


func tune_found(discovery_id: String) -> void:
	begin_moment("find", discovery_id, TuneMoments.find_tune(discovery_id))


func warden_took_band() -> void:
	_warden_engaged = true
	_warden_fighting = true
	_synth_form_state = "closed"
	_moments.clear()
	if _champion_hyped:
		_champion_hyped = false
		_moment_playing = ""
		if radio_hold == "" and sound_ready and ace_wanted() and _stage_now > 0:
			_ace_stage(_stage_now, engine.next_bar(), true)
		return
	_refresh_moment(true)


func landmark_moment(landmark_id: String, approach: float) -> void:
	var id := TuneMoments.landmark_tune(landmark_id)
	if id == "":
		return
	var holding := _moments.any(func(m): return m.kind == "landmark")
	var hold := TuneMoments.landmark_holds(approach, holding, _warden_engaged)
	if hold and not holding:
		begin_moment("landmark", landmark_id, id)
	elif holding and not hold:
		end_moment("landmark")


func _landmark_id() -> String:
	if ctx == null or ctx.get("terrain") == null or not ctx.terrain.has_method("map"):
		return ""
	var map = ctx.terrain.map()
	if map == null or not "park" in map or not map.park is Dictionary:
		return ""
	return String(map.park.get("landmark", {}).get("id", ""))


func _tend_champions() -> void:
	var final_track := PhaseMusic.champion_final(pack_available)
	if not _champion_hyped or final_track == "":
		return
	for id in _champions.keys():
		var enemy = _champions[id]
		if not is_instance_valid(enemy) or _champion_euro.has(id):
			continue
		if PhaseMusic.champion_in_final_third(_num(enemy, "hp", 1.0), _num(enemy, "max_hp", 1.0)):
			if MusicArbiter.resolve(_arbiter_state())["owner"] != MusicArbiter.OWNER_CHAMPION:
				return
			_champion_euro[id] = true
			var when := PhaseMusic.drop_plan(engine.clock, engine.next_bar(), engine.bar_len(), Harmony.RATE)
			engine.schedule_stinger_at("hype_drop", int(when["start"]))
			_ace_named(final_track, int(when["drop"]), true)
			_log_cue(["champion_final", final_track, "bar", int(when["drop"]), 1.0])
			return


static func _argc(events: Object, signal_name: String) -> int:
	return SignalWire.arg_count(events, signal_name) if events.has_signal(signal_name) else -1


func _on_boss_defeated() -> void:
	_radio_drop("victory")
	radio_finale = false
	_boss_arena_track = ""
	_boss_phase = 1
	_phase_music_done = 0
	on_beat("boss_defeated", 0.0, true)
	engine.victory()


func _on_miniboss_gone(enemy: Node) -> void:
	if enemy != _miniboss or engine == null or engine.track == "miniboss":
		return
	var survivor := _miniboss_survivor()
	if survivor != null and survivor != enemy:
		_miniboss = survivor
		return
	_miniboss = null
	engine.drop_pending_track("miniboss")


func _miniboss_survivor() -> Node3D:
	for enemy in get_tree().get_nodes_in_group("enemy") if is_inside_tree() else []:
		if is_instance_valid(enemy) and is_miniboss(String(enemy.get("kind"))) and not enemy.is_dead():
			return enemy
	return null


static func is_miniboss(kind: String) -> bool:
	return kind == "miniboss" or Rogue.ROWS.has(kind)


static func miniboss_tune(kind: String) -> String:
	var anthem := String(Rogue.ROWS.get(kind, {}).get("anthem", ""))
	return anthem if TuneMoments.TUNES.has(anthem) else "miniboss"


func _on_kill(_kind: String, _at: Vector3, _value: int) -> void:
	var killed_kind := _kind
	if Rogue.ROWS.has(killed_kind) and _site_markers() == null:
		_play_site_flip("rogue:" + killed_kind)
	if is_miniboss(_kind) and _miniboss_survivor() != null:
		_miniboss = _miniboss_survivor()
		_kind = ""
	if is_miniboss(_kind) and is_instance_valid(_miniboss):
		var key := str(_miniboss.get_instance_id())
		end_moment("miniboss", key)
	if is_miniboss(_kind) and engine.track == "miniboss":
		engine.miniboss_drop()
		_miniboss = null
	if _kind == "vault":
		play("enemy_killed", 2.0, 1.0, "SFX", VAULT_KILL_SOUND)
	var rung: int = kill_streak.bump(Time.get_ticks_msec())
	play("enemy_killed")
	if rung >= STREAK_LAND_RUNG:
		_warm_landing(rung)
	if rung >= 1:
		var tiers: Array = SfxBank.TIER_CUES["kill_chain_tier"]
		play("enemy_killed", 0.0, 1.0, "SFX", tiers[mini(rung, tiers.size()) - 1])


func _on_ace_grid() -> bool:
	return ace != null and engine.grid == ace and ace.mode != "off" and ace.section != ""


func skill_answer(kind: String, target: Node3D) -> Array:
	if absf(beat_offset_s()) > ONBEAT_WINDOW_S or engine.clock - _skill_answer_at < engine.beat_len() / 2:
		return []
	_skill_answer_at = engine.clock
	var big := big_foe(target)
	var motif := Harmony.motif_or_first(_motif if _motif != "" else Harmony.CLASS_MOTIFS[0])
	var cells: Array = motif["cells"]
	if not big:
		cells = cells.slice(0, SKILL_ANSWER_NOTES)
	var unit := grid_unit(4)
	var start := next_grid(4)
	var booked := []
	for cell in cells:
		var at := start + int(cell[0]) * unit
		_note_at("skill_on_beat", String(motif["voice"]), int(cell[1]), at)
		booked.append([String(motif["voice"]), int(cell[1]), at])
	if big and motif.has("band"):
		var last: Array = cells[cells.size() - 1]
		var midi := int(last[1]) + int(motif.get("band_octave", 0))
		var at := start + int(last[0]) * unit
		_note_at("skill_on_beat", String(motif["band"]), midi, at, SfxBank.GRID_UNDER_DB)
		booked.append([String(motif["band"]), midi, at])
	skill_on_beat.emit(kind, big)
	return booked


func big_foe(target: Node3D) -> bool:
	if ctx != null and "boss" in ctx and ctx.boss != null and ctx.boss.has_method("active") and ctx.boss.active():
		return true
	if not is_instance_valid(target):
		return false
	return target.has_meta("elite_pack") or target == _miniboss or target.get("boss") != null \
			or (ctx != null and ctx.flow != null and ctx.flow.get("warden") == target)


func grid_unit(per_beat: int) -> int:
	return maxi(1, (ace.grid_beat if _on_ace_grid() else engine.beat_len()) / per_beat)


func next_grid(per_beat: int) -> int:
	var unit := grid_unit(per_beat)
	var origin: int = ace.origin if _on_ace_grid() else engine.grid_origin
	return engine.clock + posmod(origin - engine.clock, unit)


func _next_bar() -> int:
	return ace.next_bar() if _on_ace_grid() else engine.next_bar()


func _bar_len() -> int:
	return ace.grid_bar if _on_ace_grid() else engine.bar_len()


func _play_kindness_chime(row: Dictionary) -> int:
	var sound := Rows.heard(row, cue_context())
	if sound == "":
		_log_cue(["world_fact", sound, "skip", -1, 1.0])
		return -1
	var priority := int(row.get("priority", 1))
	if engine != null and engine.mode == MusicEngine.PLAY:
		if not _admit("world_fact", sound, 1.0):
			return -1
		var unit := grid_unit(4)
		var at := next_grid(4)
		if clock < _focus_until:
			var earliest := engine.clock + ceili((_focus_until - clock) * Harmony.RATE)
			while at < earliest:
				at += unit
		engine.schedule_stinger_at(sound, at, PRIORITY_DB[priority])
		_log_cue(["world_fact", sound, "grid", at, 1.0])
		return at
	if clock < _focus_until:
		_log_cue(["world_fact", sound, "skip", -1, 1.0])
		return -1
	play("world_fact", 0.0, 1.0, "SFX", sound, priority)
	return engine.clock if engine != null else -1


func _note_at(kind: String, voice: String, midi: int, at: int, db := 0.0, home := false) -> void:
	var id := SfxBank.grid_note_id(voice, midi)
	engine.schedule_stinger_at(id, at, db + PRIORITY_DB[Rows.priority(kind)], home)
	_log_cue([kind, id, "grid", at, 1.0])


func _landing_tones(at: int) -> Array:
	return HOME_TRIAD if ace_playing() else engine.chord_at(at)["tones"]


func _warm_landing(rung: int) -> void:
	var due: int = engine.clock + kill_streak.window_ms * Harmony.RATE / 1000
	for at in [due, due + 4 * grid_unit(1)]:
		for id in _landing_ids(rung, _landing_tones(at)):
			engine.warm_stinger(id, at)
		if rung >= STREAK_BAR_RUNG and clock >= float(_gates.get("pilot_quote", -1000.0)):
			engine.warm_stinger(_pilot_quote_id(), at, false, grid_unit(4))


func _warm_grid_key() -> void:
	var motif: String = _motif if _motif != "" else Harmony.CLASS_MOTIFS[0]
	var now := "%d:%s" % [engine.stinger_key(engine.clock), motif]
	if now == _grid_key:
		return
	_grid_key = now
	var whip := SfxBank.whip_notes(motif)
	for id in [SfxBank.grid_note_id(whip[0], whip[1]), SfxBank.grid_note_id(whip[0], whip[2]),
			SfxBank.grid_note_id(DUNK_VOICE, DUNK_STORED_MIDI), SfxBank.grid_note_id(DUNK_VOICE, DUNK_SPENT_MIDI)]:
		engine.warm_stinger(id, engine.clock)
	var row := Harmony.motif_or_first(motif)
	for cell in row["cells"]:
		engine.warm_stinger(SfxBank.grid_note_id(String(row["voice"]), int(cell[1])), engine.clock)
	if row.has("band") and not row["cells"].is_empty():
		var last: Array = row["cells"][row["cells"].size() - 1]
		engine.warm_stinger(SfxBank.grid_note_id(String(row["band"]), int(last[1]) + int(row.get("band_octave", 0))), engine.clock)


func _tend_kill_streak() -> void:
	if kill_streak.length == 0 or kill_streak.last_ms == _streak_landed_ms or kill_streak.live(Time.get_ticks_msec()):
		return
	_streak_landed_ms = kill_streak.last_ms
	if kill_streak.rung >= STREAK_LAND_RUNG and sound_ready and engine.mode == MusicEngine.PLAY:
		land_streak(kill_streak.rung)


func land_streak(rung: int) -> int:
	var last: int = SfxBank.KILL_POP_MIDI + Harmony.pentatonic_step(rung)
	var long := rung >= STREAK_BAR_RUNG
	var at := _next_bar() if long else engine.next_beat()
	if long:
		var hold := next_grid(4)
		if at - hold >= grid_unit(2):
			_note_at("enemy_killed", STREAK_VOICE, last, hold, SfxBank.GRID_UNDER_DB)
		engine.schedule_stinger_at(CHAIN_CRASH, at, PRIORITY_DB[Rows.priority("enemy_killed")], true)
		_log_cue(["enemy_killed", CHAIN_CRASH, "bar", at, 1.0])
	var land := Harmony.tone_below(last, _landing_tones(at))
	_note_at("enemy_killed", STREAK_VOICE, land, at)
	_note_at("enemy_killed", STREAK_BODY, land - 12, at, SfxBank.GRID_UNDER_DB)
	if long:
		_quote_pilot(at + grid_unit(1))
	return at


func _quote_pilot(at: int) -> void:
	if not _gate("pilot_quote", pilot_quote_gap()):
		return
	var id := _pilot_quote_id()
	engine.schedule_stinger_at(id, at, PRIORITY_DB[Rows.priority("enemy_killed")], false, grid_unit(4))
	_log_cue(["enemy_killed", id, "quote", at, 1.0])


func pilot_quote_gap() -> float:
	return float(PILOT_QUOTE_BARS * 4 * grid_unit(1)) / Harmony.RATE


func _pilot_quote_id() -> String:
	return SfxBank.pilot_quote_id(_motif if _motif != "" else Harmony.CLASS_MOTIFS[0])


func set_complete(element: String) -> int:
	if not sound_ready or engine.mode != MusicEngine.PLAY:
		return -1
	var voice: String = SET_CHIME_VOICES.get(element, SET_CHIME_VOICES["frost"])
	var eighth := grid_unit(2)
	var first := next_grid(2)
	while first - engine.clock < int(SET_CHIME_LEAD_S * Harmony.RATE):
		first += eighth
	for i in SET_CHIME.size():
		var done: bool = i == SET_CHIME.size() - 1
		_note_at("synergy_discovered", SET_CHIME_DONE_VOICE if done else voice, SET_CHIME[i], first + i * eighth,
			0.0 if done else SfxBank.GRID_UNDER_DB)
	_duck(SET_CHIME_DUCK, float(first + SET_CHIME.size() * eighth - engine.clock) / Harmony.RATE)
	return first


func _on_near_miss(_kind: String, _at: Vector3) -> void:
	if not play("near_miss"):
		return
	var notes := SfxBank.whip_notes(_motif if _motif != "" else Harmony.CLASS_MOTIFS[0])
	var at := next_grid(4)
	_note_at("near_miss", notes[0], notes[1], at)
	_note_at("near_miss", notes[0], notes[2], at + grid_unit(4))


func _on_died() -> void:
	_line_was = ""
	_cadence_prev.clear()
	_sync_rail_ids()
	_stop_hum()
	play("player_died")
	_flow_queue.append(["dead"])


func _on_slammed(_at: Vector3, strength: float, flatness: float) -> void:
	if strength < 0.05:
		return
	play("slammed", lerpf(-8.0, 0.0, clampf(strength, 0.0, 1.0)), lerpf(1.1, 0.9, clampf(strength - 0.5, 0.0, 1.0)))
	var weight := clampf(strength, 0.0, 1.0) * lerpf(0.5, 1.0, clampf(flatness, 0.0, 1.0))
	play("slammed", lerpf(-12.0, 0.0, weight), Harmony.ratio(lerpf(0.0, -5.0, weight)), "SFX", "womp")


func _on_launched(_velocity: Vector3) -> void:
	play("launched")
	if not sound_ready or engine.mode != MusicEngine.PLAY or engine.track == _boss_track():
		return
	_ult_armed = false
	_ult_band_stays_off()
	if ace_playing() and ace.mode == "piece":
		_ace_flight = true
		_launch_armed = true
		_landing_theme = -1
		_launch_stage = false
		return
	if ace_playing():
		_ace_end(ace.grid_beat)
	engine.start_build(LAUNCH_BUILD_SECONDS, true)
	_launch_armed = true
	_landing_theme = -1
	_launch_stage = false


func _on_landed(impact: float) -> void:
	play("landed", lerpf(-12.0, 2.0, clampf(impact / 30.0, 0.0, 1.0)), lerpf(1.1, 0.85, clampf(impact / 30.0, 0.0, 1.0)))
	if _launch_armed and _landing_theme >= 0:
		_land_drop()


func _land_drop() -> void:
	var touchdown := engine.clock
	if _radio_respin_due:
		_radio_respin_due = false
		_radio_respin()
	var at := engine.drop_now(4, 0.85, {}, _landing_theme if radio_hold == "" else -1)
	if _ace_arrival_stage > 0:
		_ace_arrival_at = at
	_log_drop([touchdown, at])
	if _ace_flight:
		_ace_flight = false
		if ace_playing():
			ace.stop_at(at, ace.grid_beat)
			_handover_at = at
	_log_cue(["landed", "drop", "beat", at, 1.0])
	_launch_armed = false
	_landing_theme = -1


func _wire_ultimate_beat() -> void:
	var spawner = ctx.get("spawner") if ctx != null else null
	if spawner == null or spawner.get("ultimate") == null:
		return
	spawner.ultimate.stakes.note = sable_note
	spawner.ultimate.beat_seconds = func() -> float:
		if not sound_ready or engine.mode != MusicEngine.PLAY:
			return 0.0
		return 60.0 / engine.bpm()


func pressure_now() -> float:
	return _pressure


func ace_pressure() -> float:
	return _pressure + (AceSequencer.ULTIMATE_STEP if _ult_lift else 0.0)


func _set_ult_lift(on: bool) -> void:
	_ult_lift = on
	engine.set_ultimate_lift(on)
	if ace != null and (not ace.parameter_enabled or not ace.active()):
		ace.set_ultimate_lift(on)


func sync_ult_lift() -> void:
	var player = ctx.get("player") if ctx != null else null
	if player == null or player.abilities.meter == null:
		return
	var full: bool = player.abilities.meter.full()
	if full != _ult_lift:
		_set_ult_lift(full)


func _on_ultimate_ready(_id: String) -> void:
	_set_ult_lift(true)
	on_beat("ultimate_ready")


func _on_ultimate_started(_id: String, _path: String, _from: Vector3, _to: Vector3, seconds: float) -> void:
	play("ultimate_started")
	if not sound_ready or engine.mode != MusicEngine.PLAY:
		return
	if engine.track == _boss_track() and not _id.begins_with("cannon_"):
		return
	_ult_armed = true
	_ult_took_band = false
	if ace_playing() and ace.mode == "piece":
		_ace_flight = true
		return
	if ace_playing():
		var stage_band: bool = ace.mode in STAGE_BAND_MODES
		_ace_end(ace.grid_beat)
		_ult_took_band = stage_band
	engine.start_build(seconds, true)


func _on_ultimate_peak(id: String, _at: Vector3) -> void:
	if id.begins_with("cannon_"):
		cannon_motif("cannon_peak", false, false, 12)
	elif id in ["windhover", "air_raid", "minelayer"]:
		kest_cue("ultimate_peak", "raid_kest_stinger")
	elif id in ["cable_run", "ball_lightning", "outpost"]:
		on_beat("ultimate_peak", PRIORITY_DB[Rows.priority("ultimate_peak")], false, 1, String(SABLE_SOUNDS["sable_peak"]))
	else:
		on_beat("ultimate_peak")


func kest_cue(kind: String, sound: String, grid := "beat", pitch := 1.0) -> int:
	var keyed_pitch := pitch * Harmony.ratio(live_key())
	if not _admit(kind, sound, keyed_pitch):
		return -1
	var priority_db: float = PRIORITY_DB[Rows.priority(kind)]
	var gain: float = SfxBank.trim_db(sound) + priority_db
	if grid == "now":
		_start(kind, sound, SfxBank.stream(sound), gain, keyed_pitch, "SFX")
		return engine.clock
	var at := engine.next_beat()
	if grid == "eighth":
		var eighth := maxi(1, engine.beat_len() / 2)
		at = engine.clock + posmod(eighth - posmod(engine.clock - engine.grid_origin, eighth), eighth)
	engine.schedule_stinger_at(sound, at, priority_db)
	_duck(0.6, float(at - engine.clock + SfxBank.STINGER_BEATS.get(sound, 1) * engine.beat_len()) / Harmony.RATE)
	_log_cue([kind, sound, grid, at, keyed_pitch, gain])
	return at


func kest_roll(note: int) -> int:
	return kest_cue("ultimate_peak", "tick_kest_%d" % note, "eighth")


func _on_ultimate_landed(_id: String, _at: Vector3, _hits: int, _damage: float) -> void:
	play("ultimate_landed")
	if _id.begins_with("cannon_"):
		cannon_motif("cannon_landing", false, true)
	if _id in ["windhover", "air_raid", "minelayer"]:
		kest_cue("ultimate_landed", "raid_kest_boom")
	if _ult_armed:
		var touchdown := engine.clock
		var at: int
		if _id.begins_with("cannon_"):
			at = touchdown
			engine._add_action(at, {"type": "drop", "bars": 4, "weight": 0.85, "then": {}, "theme": -1, "set": {"ult": false}})
		else:
			at = engine.drop_now(4, 0.85, {}, -1, {"ult": false})
		_log_drop([touchdown, at])
		if _ace_flight:
			_ace_flight = false
			if ace_playing():
				ace.stop_at(at, ace.grid_beat)
				_handover_at = at
		if _ult_took_band and _stage_now > 0 and _ace_arrival_stage == 0 and not ace_playing() and engine.track in STAGE_BAND_MODES:
			_ace_arrival_stage = _stage_now
			_ace_arrival_at = at
		_ult_took_band = false
		_log_cue(["ultimate_landed", "drop", "beat", at, 1.0])
		_ult_armed = false
	_set_ult_lift(false)


func _on_ultimate_cancelled(_id: String, _reason: String, refunded: bool) -> void:
	play("ultimate_cancelled")
	if _ult_armed:
		_ult_armed = false
		if _ace_flight:
			_ace_flight = false
			_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)
		engine.cancel_build()
		if _ult_took_band and _stage_now > 0 and _reason in ULT_BAND_BACK and not ace_playing() and engine.track in STAGE_BAND_MODES:
			_ace_return(_stage_now, engine.next_bar())
		_ult_took_band = false
	if not refunded:
		_set_ult_lift(false)


func _disarm_launch() -> void:
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	if _ace_flight:
		_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)
	if _launch_armed:
		engine.cancel_build()
	_launch_armed = false
	_landing_theme = -1
	_launch_stage = false


func _follow_warden() -> void:
	if engine.track != "warden" or engine.section == "drop":
		return
	if ctx.flow == null or not ctx.flow.has_method("warden_integrity"):
		return
	engine.warden_charge(1.0 - float(ctx.flow.warden_integrity()))


func _follow_escalation() -> void:
	if not sound_ready or engine.mode != MusicEngine.PLAY:
		return
	match engine.track:
		"miniboss":
			if is_instance_valid(_miniboss) and ctx.spawner != null and ctx.spawner.has_method("integrity_of"):
				engine.escalate(1.0 - float(ctx.spawner.integrity_of(_miniboss)))
		"brindle", "waking", "mind":
			_follow_brindle()
		"level":
			if _event_id != "" and not _event_progress_live:
				var seconds: float = EVENT_SECONDS.get(_event_id, 20.0)
				engine.escalate(clampf((Time.get_ticks_msec() - _event_started_ms) / 1000.0 / seconds, 0.0, 1.0), false)


func _follow_brindle() -> void:
	var boss = ctx.get("boss")
	if boss == null or not is_instance_valid(boss):
		return
	if engine.section == "chase":
		var scooter = boss.get("scooter")
		if scooter is Node3D and is_instance_valid(scooter) and boss.has_method("scooter_landed") and boss.scooter_landed():
			var lead: float = (scooter as Node3D).global_position.distance_to(ctx.player.shown_position())
			if _chase_lead0 < 0.0:
				_chase_lead0 = maxf(lead, 1.0)
			engine.chase(clampf(1.0 - lead / _chase_lead0, 0.0, 1.0))
		return
	if boss.has_method("music_state"):
		var state: Dictionary = boss.music_state()
		if not state.is_empty():
			var next_phase := int(state.get("phase", _boss_phase))
			if next_phase > _boss_phase and next_phase <= 3:
				_boss_phase = next_phase
				engine.set_boss_state("%s:%d" % [String(state.get("id", engine.track)), _boss_phase])
				phase_music(_boss_phase)
			engine.brindle_hp(float(state["in_phase"]), bool(state["held"]), float(state["phase_seconds"]))
		return


static func _num(object: Object, property: String, fallback: float) -> float:
	var value = object.get(property)
	return float(value) if value is int or value is float else fallback


func _on_dismounted(velocity: Vector3) -> void:
	if velocity.length() < 1.0:
		play("dismounted", -8.0, 0.75)
		return
	play("dismounted", 0.0, Harmony.ratio(clampf(velocity.length() / 5.0, 0.0, 7.0)))


func _on_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "synergy":
		play("enemy_struck", -8.0, Harmony.ratio(Harmony.pentatonic_step(_pitch_rng.randi() % 5)), "SFX", "synergy_hit")
		return
	if is_instance_valid(enemy) and enemy.get("kind") == "vault":
		play("enemy_struck", -2.0, Harmony.ratio(lerpf(0.0, 9.0, 1.0 - _integrity(enemy))), "SFX", "vault_rise")
		return
	var contact := kind in ["stomp", "ram", "slam"]
	var db := lerpf(-6.0, 1.0, clampf(force / 30.0, 0.0, 1.0)) if contact else -5.0
	if _on_posture_fight(enemy):
		play("enemy_struck", db, _posture_note_ratio(enemy))
	else:
		play("enemy_struck", db, (1.0 if contact else 1.15) * _warden_ladder(enemy))
	if contact:
		_grown_layers(db)
	_pay_beat(enemy, kind)


const GROWN_LAYERS := [[2, "grown_sub"], [3, "grown_crack"], [4, "grown_tail"], [4, "grown_rattle"]]


func _grown_layers(db: float) -> void:
	var heft := _heft_class
	if ctx != null and ctx.run != null and ctx.run.has_method("heft_class"):
		heft = int(ctx.run.heft_class())
	for layer in GROWN_LAYERS:
		if heft >= int(layer[0]):
			play("enemy_struck", db, 1.0, "SFX", layer[1])


func _pay_beat(enemy: Node3D, kind: String) -> void:
	if absf(beat_offset_s()) > ONBEAT_WINDOW_S or engine.clock - _onbeat_at < engine.beat_len() / 2:
		return
	_onbeat_at = engine.clock
	var stab := SfxBank.rendered(ONBEAT_SOUND)
	if stab != null:
		_start("hit_on_beat", ONBEAT_SOUND, stab, PRIORITY_DB[Rows.priority("enemy_struck")] + ONBEAT_DB, 1.0, "SFX")
	else:
		_log_cue(["hit_on_beat", ONBEAT_SOUND, "absent", engine.clock, 1.0])
	hit_on_beat.emit(enemy, kind)


func beat_offset_s() -> float:
	if beat_offset_hook.is_valid():
		return beat_offset_hook.call()
	if not sound_ready or engine.mode != MusicEngine.PLAY:
		return INF
	var heard := engine.clock
	if live_output and _music_pb != null:
		heard -= _ring_capacity - _music_pb.get_frames_available()
	var length: int = engine.beat_len()
	var next: int = engine.next_beat()
	while next - length > heard:
		next -= length
	var to_next := next - heard
	var from_last := heard - (next - length)
	return (-float(to_next) if to_next < from_last else float(from_last)) / Harmony.RATE


func _on_posture_fight(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and enemy.has_method("fight") and enemy.fight() == "posture" \
			and ctx.flow != null and (ctx.flow.get("warden") == enemy or enemy.get("boss") != null)


func _posture_note_ratio(enemy: Node3D) -> float:
	var midis := SfxBank.break_midis(POSTURE_PHRASE)
	var quarter := clampi(int(enemy.posture() / POSTURE_QUARTER), 0, midis.size() - 1)
	return Harmony.ratio(midis[quarter] - Harmony.HOME)


func _on_posture_changed(enemy: Node3D, posture: float, staggered: bool) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	var seen: Array = _posture_seen.get(id, [false, BossPosture.CHUNKS])
	var chunks: int = enemy.chunks_left()
	_posture_seen[id] = [staggered, chunks]
	if staggered and not seen[0]:
		_stagger_chord()
		_cut_charge()
	var shattered := chunks < int(seen[1])
	_guard_warning(enemy, posture, staggered)
	if shattered:
		play("posture_changed", 6.0, 1.0, "SFX", Rows.heard(EventKinds.state_row("chunk_shatter"), cue_context()))
		play("posture_changed", 6.0, 1.0, "SFX", SHATTER_LOW)
	if _is_form_fight(enemy) and chunks > 0:
		var fell := _guard_step_fell(enemy, bool(seen[0]) and not staggered)
		_follow_warden_form(posture, staggered, (fell or (shattered and chunks > 0)) and not staggered)


func _is_form_fight(enemy: Node3D) -> bool:
	if not is_instance_valid(enemy):
		return false
	if ctx != null and ctx.flow != null and ctx.flow.get("warden") == enemy:
		return true
	return enemy.get("boss") != null and (engine.track in MusicEngine.BOSS_TRACKS or _active_boss_track() in MusicEngine.BOSS_TRACKS)


func _guard_warning(enemy: Node3D, posture: float, staggered: bool) -> void:
	if not _on_posture_fight(enemy):
		return
	var id := enemy.get_instance_id()
	if staggered or posture < GUARD_CRITICAL_REARM:
		_guard_warned.erase(id)
		return
	if posture >= GUARD_CRITICAL and not _guard_warned.has(id):
		_guard_warned[id] = true
		play("guard_critical")


func _guard_step_fell(enemy: Node3D, stagger_ended: bool) -> bool:
	var left: int = enemy.phase_chunks_left() if enemy.has_method("phase_chunks_left") else enemy.chunks_left()
	var id := enemy.get_instance_id()
	var lowest := int(_guard_steps.get(id, BossPosture.CHUNKS))
	_guard_steps[id] = left if stagger_ended else mini(lowest, left)
	return left < lowest and left > 0


func _follow_warden_form(posture: float, staggered: bool, landed: bool) -> void:
	var tuning = ctx.get("tuning") if ctx != null else null
	if tuning == null or radio_hold != "":
		return
	var on_ace := ace_playing()
	var on_synth := sound_ready and engine != null and engine.mode == MusicEngine.PLAY and (engine.track == "warden" or engine.track in MusicEngine.BOSS_TRACKS)
	if not on_ace and not on_synth:
		return
	if tuning.option(Tuning.WARDEN_FORM_KEY) != "form":
		_warden_posture = 0.0
		_warden_staggered = false
		if on_ace:
			ace.follow_guard(0.0, false, false)
		if on_synth:
			_reset_synth_form()
		return
	_warden_posture = posture
	_warden_staggered = staggered
	var ace_at := -1
	if on_ace:
		ace_at = ace.follow_guard(posture, staggered, landed)
		if ace_at >= 0:
			_log_cue(["warden_form", "drop", "beat", ace_at, 1.0, 0.0])
			_make_drop_room(ace_at)
			_tend_deck()
			deck_moves.on_drop(ace, ace_at, deck_style())
	if on_synth:
		var synth_at := _follow_synth_form(posture, staggered, landed)
		if synth_at >= 0 and ace_at < 0:
			_log_cue(["warden_form", "drop", "beat", synth_at, 1.0, 0.0])
			_make_drop_room(synth_at, engine)


func _reset_synth_form() -> void:
	if _synth_form_state == "open":
		engine.hold_dominant(false)
		if engine.track == "warden" and engine.section == "open":
			engine.warden_section("build")
	elif _synth_form_state == "telegraph":
		engine.cancel_build("synth_form")
	_synth_form_state = "closed"


func _follow_synth_form(posture: float, staggered: bool, landed: bool) -> int:
	var prev := _synth_form_state
	var state := AceSequencer.guard_state(prev, posture, staggered)
	_synth_form_state = state
	if landed:
		engine.hold_dominant(false)
		if engine.track == "warden" or (engine.track in MusicEngine.BOSS_TRACKS and engine.section in ["1", "2", "3"]):
			return engine.drop_now(4, 0.9)
		return -1
	if state == "open":
		if prev != "open":
			if engine.track == "warden":
				engine.warden_section("open")
			engine.hold_dominant(true)
		return -1
	if prev == "open":
		engine.hold_dominant(false)
		if engine.track == "warden":
			engine.warden_section("build")
	elif prev == "telegraph" and state == "closed":
		engine.cancel_build("synth_form")
	if state == "telegraph":
		var tight := clampf((posture - AceSequencer.GUARD_TIGHT) / (100.0 - AceSequencer.GUARD_TIGHT), 0.0, 1.0)
		if engine.track == "warden":
			engine.warden_charge(lerpf(MusicEngine.WARDEN_BUILD_FROM, 1.0, tight), "synth_form")
		elif engine.track in MusicEngine.BOSS_TRACKS:
			engine.brindle_hp(clampf(posture / 100.0, 0.0, 1.0), true, tight, "synth_form")
	return -1


func _stagger_chord() -> void:
	var key := Harmony.ratio(live_key())
	for midi in SfxBank.break_midis(POSTURE_PHRASE):
		play("posture_changed", 6.0, key, "SFX", SfxBank.cause_note_id(midi))
	play("posture_changed", 6.0, 1.0, "SFX", Rows.heard(EventKinds.state_row("open"), cue_context()))


func _is_warden_at(at: Vector3) -> bool:
	if ctx == null or ctx.flow == null:
		return false
	var warden = ctx.flow.get("warden")
	return is_instance_valid(warden) and warden.global_position.is_equal_approx(at)


func _cut_charge() -> void:
	if not _warden_charging:
		return
	_warden_charging = false
	var sound := Rows.sound("vent_charging", cue_context())
	stop(sound)
	engine.set_reactor_pedal(false)
	_log_cue(["posture_changed", sound, "stop", engine.clock, 1.0, 0.0])


func _warden_ladder(enemy: Node3D) -> float:
	if ctx.flow == null or not is_instance_valid(enemy) or ctx.flow.get("warden") != enemy:
		return 1.0
	return Harmony.ratio(Harmony.pentatonic_step(int((1.0 - _integrity(enemy)) * 6.0)))


func _integrity(enemy: Node3D) -> float:
	if ctx.spawner != null and ctx.spawner.has_method("integrity_of"):
		return float(ctx.spawner.integrity_of(enemy))
	return 1.0


func _connect_dunk() -> void:
	var dunk = ctx.player.get("dunk") if ctx != null and ctx.get("player") != null else null
	if dunk == null:
		return
	dunk.stored.connect(func(_record: Dictionary):
		if play("slammed", -4.0, Harmony.ratio(7.0), "SFX", "smash_whistle"):
			_note_at("slammed", DUNK_VOICE, DUNK_STORED_MIDI, next_grid(4)))
	dunk.spent.connect(func(_record: Dictionary, _enemy: Node3D):
		if play("slammed", 0.0, 1.0, "SFX", "smash_crack"):
			_note_at("slammed", DUNK_VOICE, DUNK_SPENT_MIDI, next_grid(4)))


const REDLINE_RUNGS := [0.0, 2.0, 7.0, 9.0]
var _redline_band := 0


func _connect_redline() -> void:
	var redline = ctx.player.get("redline") if ctx != null and ctx.get("player") != null else null
	if redline == null:
		return
	_hits_hot_heard = redline.hits_hot
	redline.changed.connect(func(value: float, band: int):
		if band > _redline_band:
			play("slammed", -6.0, Harmony.ratio(REDLINE_RUNGS[band]), "SFX", "smash_whistle")
		if band >= HOT_BAND and _redline_band < HOT_BAND:
			_cool_due = false
			play("slammed", -2.0, 1.0, "SFX", "heat_rise")
		elif band < HOT_BAND and _redline_band >= HOT_BAND:
			_cool_due = value > 0.0
		_redline_band = band)
	redline.detonated.connect(func(_at: Vector3, _force: float):
		play("slammed", 2.0, Harmony.ratio(-5.0), "SFX", "smash_crack"))
	redline.cooked_off.connect(func(_at: Vector3, _force: float):
		play("slammed", 0.0, Harmony.ratio(-7.0), "SFX", "smash_crack"))


const HOT_BAND := 2
var _cool_due := false
var _hits_hot_heard := 0


func _tend_heat() -> void:
	var redline = ctx.player.get("redline") if ctx != null and ctx.get("player") != null else null
	if redline == null:
		return
	if _cool_due:
		_cool_due = false
		play("slammed", 0.0, 1.0, "SFX", "heat_cool")
	var hits: int = redline.hits_hot
	if hits > _hits_hot_heard:
		play("slammed", 0.0, 1.0, "SFX", "heat_hot_hit")
	_hits_hot_heard = hits


var _kettle_on := false


func _tend_kettle() -> void:
	var redline = ctx.player.get("redline") if ctx != null and ctx.get("player") != null else null
	var left: float = redline.fuse_left() if redline != null else -1.0
	var due := left > 0.0 and left <= Redline.KETTLE_S
	var sounding: bool = _kettle_on and _sfx != null and Array(_voices.get("heat_kettle", [])).any(func(id: int): return _sfx.is_stream_playing(id))
	if due and not sounding:
		_kettle_on = play("slammed", 0.0, 1.0, "SFX", "heat_kettle")
	elif not due and _kettle_on and left <= 0.0:
		_kettle_on = false
		stop("heat_kettle")


func _on_active_fired(active_id: String, _at: Vector3, _count: int) -> void:
	var sound := "active_" + active_id
	play("active_fired", 0.0, 1.0, "SFX", sound if SfxBank.has_recipe(sound) else "")


func _on_active_heat(active_id: String, _at: Vector3, fraction: float) -> void:
	var sound := "active_%s_heat" % active_id
	if SfxBank.has_recipe(sound):
		play("active_fired", lerpf(-8.0, 0.0, fraction), Harmony.ratio(lerpf(0.0, 12.0, fraction)), "SFX", sound)


func _on_shot(weapon_id: String, _from: Vector3, _to: Vector3) -> void:
	var cents := _pitch_rng.randf_range(-25.0, 25.0) / 100.0
	play("shot_fired", 0.0, Harmony.ratio(WEAPON_PITCH.get(weapon_id, 0.0) + cents))
	_tend_cadence()


func _on_offered(_offers: Array) -> void:
	if _gates_announced:
		return
	_gates_announced = true
	_flow_queue.append(["gates"])


func _on_heft_class(heft_class: int, _heft: float) -> void:
	engine.set_heft_lift(heft_class - 1)
	if heft_class > _heft_class:
		on_beat("heft_class_changed")
	elif heft_class < _heft_class:
		on_beat("heft_class_changed", 0.0, false, 1, "class_down")
	_heft_class = heft_class


func _on_heft_dropped(heft_class: int, _heft: float) -> void:
	on_beat("heft_class_dropped")
	engine.set_heft_lift(heft_class - 1)
	_heft_class = heft_class


const BRINDLE_TELEGRAPHS := {
	"crane_sweep": "tele_crane_sweep", "slag_ring_a": "tele_slag_ring", "slag_ring_b": "tele_slag_ring",
	"slag_ring_inner": "tele_slag_ring", "charge": "tele_charge", "charge_wall": "tele_charge_wall", "eject": "tele_eject",
}


func _on_boss_telegraph(attack_id: String, seconds_until: float) -> void:
	if engine.track == "warden":
		engine.parameter_danger("boss_attack_telegraphed")
	play("boss_attack_telegraphed", 0.0, Harmony.ratio(lerpf(3.0, 0.0, clampf(seconds_until / 1.5, 0.0, 1.0))), "SFX", String(BRINDLE_TELEGRAPHS.get(attack_id, "")))


func _on_fight_phase(fight_id: String, phase: int, _phases: int) -> void:
	if fight_id == WARDEN_FIGHT:
		if phase >= 2:
			engine.parameter_danger("warden_engaged")
			_log_cue(["fight_phase_changed", fight_id, "phase", engine.clock, float(phase)])
		return
	if phase < 2 or PhaseMusic.BOSS_SYNTH_THEME.has(fight_id):
		return
	var moved := false
	for m in _moments:
		if m.kind == "miniboss" and not String(m.id).ends_with(PhaseMusic.HEAVY):
			var heavy := String(m.id) + PhaseMusic.HEAVY
			if tune_available.call(heavy):
				m.id = heavy
				moved = true
	if moved:
		_refresh_moment()


func _on_attack_cued(_fight_id: String, _attack_id: String, _seconds_until: float) -> void:
	play("attack_cued")


func _on_weak_point(_point_id: String) -> void:
	var now := Time.get_ticks_msec()
	_weak_combo = mini(_weak_combo + 1, 7) if now - _weak_last < KILL_COMBO_WINDOW_MS else 0
	_weak_last = now
	play("boss_weak_point_hit", 0.0, Harmony.ratio(Harmony.pentatonic_step(_weak_combo)))


func _on_deflected(_enemy: Node3D, _kind: String, punch: float, plating: float) -> void:
	var closeness := clampf(punch / maxf(plating, 1.0), 0.0, 1.0)
	play("strike_deflected", 0.0, Harmony.ratio(lerpf(-7.0, 0.0, closeness)) * _warden_ladder(_enemy))


func _on_core(_source: String, _at: Vector3, count: int) -> void:
	play("core_gained", 0.0, Harmony.ratio(Harmony.pentatonic_step(maxi(count - 1, 0))))
	engine.set_overcharge(count)


func _on_synergy(_id: String, _category: String, first_time: bool) -> void:
	on_beat("synergy_discovered", 0.0 if first_time else -6.0)


func sample_run_parameters() -> Dictionary:
	if ctx.run == null or ctx.player == null or ctx.flow == null or not ctx.flow.in_play():
		return {}
	var at: Vector3 = ctx.player.shown_position()
	var forward: Vector3 = ctx.aim_forward()
	var enemies: Array = get_tree().get_nodes_in_group("enemy") if is_inside_tree() else []
	var values := {"threat": run_threat(at, forward, enemies, parameter_threat_weights, parameter_threat_range)}
	values["speed"] = ctx.player.speed_fraction()
	values["chain"] = chain_fader(int(ctx.player.chain.combo) if ctx.player.get("chain") != null else 0)
	var map_id: String = ctx.flow.stage_def().get("map", "")
	if map_id != _parameter_map:
		_parameter_map = map_id
		_parameter_graph = null
		var path := "res://assets/park/%s/graph.bin" % map_id
		if map_id.begins_with("park_") and FileAccess.file_exists(path):
			_parameter_graph = Activities.shared_graph(path)
	if _parameter_graph != null:
		var span: float = _parameter_graph.d_landmark(_parameter_graph.spawn_node)
		var remaining: float = _parameter_graph.d_landmark(at)
		if span > 0.0 and is_finite(remaining):
			values["approach"] = clampf(1.0 - remaining / span, 0.0, 1.0)
	if ctx.run.run_id != _parameter_run:
		_parameter_run = ctx.run.run_id
		_parameter_armour_peak = 100.0
	if ctx.run.armor_mode:
		_parameter_armour_peak = maxf(_parameter_armour_peak, ctx.run.mass)
		values["armour"] = ctx.run.mass / _parameter_armour_peak
	return values


static func chain_fader(links: int) -> float:
	return clampf(float(links - 1) / 3.0, 0.0, 1.0)


static func run_threat(at: Vector3, forward: Vector3, enemies: Array, weights := Vector2(0.8, 0.2), radius := 48.0) -> float:
	var safe := 1.0
	var total := maxf(weights.x + weights.y, 0.001)
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("is_dead") or enemy.is_dead():
			continue
		var offset: Vector3 = enemy.global_position - at
		var proximity := maxf(0.0, 1.0 - offset.length() / maxf(radius, 0.001))
		var facing := maxf(0.0, forward.normalized().dot(offset.normalized()))
		var value := proximity * (weights.x + weights.y * facing) / total
		safe *= 1.0 - value
	return 1.0 - safe


func _on_pressure(pressure: float) -> void:
	_pressure = pressure
	_log_cue(["pressure_changed", "music_pressure", "music", engine.clock, 1.0])
	if not engine.parameter_source.is_valid():
		engine.set_pressure(pressure)
	if ace_playing() and not engine.parameter_source.is_valid():
		ace.set_pressure(pressure)


func _flush_flow() -> void:
	if _flow_queue.is_empty():
		return
	var burst := _flow_queue
	_flow_queue = []
	var kinds := burst.map(func(item: Array): return item[0])
	if "run" in kinds or "idle" in kinds or "stage" in kinds:
		_summary_due = -1
	for item in burst:
		match item[0]:
			"run":
				_radio_drop("flow")
				_disarm_launch()
				_disarm_ultimate()
				_boss_arena_track = ""
				engine.cancel_pending()
				engine.parameters_run_started()
				var start := on_beat("run_started", 0.0, true)
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY, _stage_theme(1))
				_ace_stage(1, start)
			"world":
				on_beat("world_entered", 0.0, true, 1, SfxBank.world_stinger(item[1]))
			"stage":
				var stage: int = item[1]
				var retry: bool = item[2]
				if not retry and "run" in kinds:
					continue
				if radio_hold != "":
					on_beat("stage_entered", 0.0, true, clampi(stage, 1, 4))
					if not retry and _launch_stage:
						_launch_stage = false
						_radio_respin_due = true
					else:
						_radio_respin()
					continue
				if not retry and _launch_stage:
					_launch_stage = false
					_ace_stage(stage, -1)
					continue
				if retry:
					engine.cancel_pending()
					var back := engine.retry_restart(MusicEngine.PLAY, _stage_theme(stage))
					_ace_stage(stage, back)
					engine.schedule_stinger_at(Rows.sound("stage_entered"), back)
					_log_cue(["stage_entered", Rows.sound("stage_entered"), "beat", back, 1.0])
					continue
				var start := on_beat("stage_entered", 0.0, true, clampi(stage, 1, 4))
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY, _stage_theme(stage))
				_ace_stage(stage, start)
			"clear":
				if "end" in kinds:
					_disarm_launch()
					continue
				var start := on_beat("stage_cleared", 0.0, true)
				if start >= 0 and not _launch_armed:
					engine.schedule_cadence(start)
			"end":
				_radio_drop("flow")
				_disarm_ultimate()
				_boss_arena_track = ""
				var won: bool = item[1]
				_streak_landed_ms = kill_streak.last_ms
				var held := _handover_at if not won and "dead" in kinds and ace_playing() else -1
				if held < 0:
					_ace_end()
				var start := on_beat("run_ended", 0.0, true) if won else -1
				if start >= 0:
					engine.schedule_cadence(start + Harmony.BAR)
					engine.schedule_mode(start + Harmony.BAR * 3, MusicEngine.IDLE)
					engine.menu_theme("summary", true, start + Harmony.BAR * 3)
					_ace_named(summary_row(true), start + Harmony.BAR * 3, false, true)
				else:
					var at := engine.next_beat()
					engine.schedule_mode(at, MusicEngine.IDLE)
					if sound_ready:
						engine.menu_theme("summary", won, at)
						if held >= 0:
							_summary_due = held
						else:
							_ace_named(summary_row(won), at, false, won)
			"dead":
				_radio_drop("flow")
				_disarm_launch()
				_disarm_ultimate()
				_boss_arena_track = ""
				engine.cancel_pending()
				_streak_landed_ms = kill_streak.last_ms
				var at := engine.death_break()
				_ace_end_at(at)
				if sound_ready:
					for i in DEATH_FALL.size():
						_note_at("player_died", DEATH_FALL_VOICE, DEATH_FALL[i], at + i * grid_unit(2), SfxBank.DEATH_FALL_DB, true)
			"idle":
				_radio_drop("flow")
				_disarm_ultimate()
				_boss_arena_track = ""
				var at := engine.next_beat()
				engine.schedule_mode(at, MusicEngine.IDLE)
				if sound_ready:
					engine.menu_theme("title", true, at)
					_menu_home(at)
			"unseal":
				_release_answered = false
				_ult_band_stays_off()
				engine.parameters_warden_broken()
				_unseal_ms = Time.get_ticks_msec()
				if ace_playing():
					ace.warden_broken()
				if engine.track == "warden" and sound_ready:
					var at := engine.unseal_drop()
					var stinger_db := story_duck_db("beacon_unsealed")
					engine.schedule_stinger_at(Rows.sound("beacon_unsealed"), at, stinger_db)
					_log_cue(["beacon_unsealed", Rows.sound("beacon_unsealed"), "beat", at, 1.0])
					var opened := Rows.heard(EventKinds.state_row("beacon_open"))
					engine.schedule_stinger_at(opened, at, stinger_db + BEACON_OPEN_DB)
					_log_cue(["beacon_open", opened, "beat", at, 1.0])
				else:
					engine.drop_pending_track("warden")
					on_beat("beacon_unsealed", 0.0, true)
			"gates":
				if "unseal" in kinds or Time.get_ticks_msec() - _unseal_ms < 2500:
					continue
				on_beat("reward_offered", 0.0, true)
			"milestone":
				on_beat("milestone_won", 0.0, true)


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	match key.physical_keycode:
		KEY_MINUS:
			nudge("Music", -VOLUME_STEP)
		KEY_EQUAL:
			nudge("Music", VOLUME_STEP)
		KEY_BRACKETLEFT:
			nudge("SFX", -VOLUME_STEP)
		KEY_BRACKETRIGHT:
			nudge("SFX", VOLUME_STEP)
		KEY_M:
			muted = not muted
			_apply_volumes()
			_show_mixer()
		KEY_F6:
			if not ctx.dev:
				return
			engine.boss_pivot = not engine.boss_pivot
			_show_text("Boss tempo: %s (F6)" % ("129 by metric modulation" if engine.boss_pivot else "four on the floor held at 172"))
		_:
			return
	get_viewport().set_input_as_handled()


func nudge(bus: String, amount: float) -> void:
	volumes[bus] = clampf(snappedf(volumes[bus] + amount, 0.01), 0.0, 1.0)
	if bus == "SFX":
		volumes["UI"] = volumes["SFX"]
	_apply_volumes()
	_show_mixer()
	play("flow_changed", 0.0, Harmony.ratio(Harmony.pentatonic_step(int(volumes[bus] * 8.0))), "UI")


func _apply_volumes() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var level := float(volumes.get(bus, volumes["SFX"]))
		AudioServer.set_bus_volume_linear(index, level * db_to_linear(BUSES[bus] + float(mix_db.get(bus, 0.0))))
		AudioServer.set_bus_mute(index, muted or (radio_silenced and bus == "Music"))


func set_volume(bus: String, level: float) -> void:
	if not volumes.has(bus):
		return
	volumes[bus] = clampf(snappedf(level, 0.01), 0.0, 1.0)
	if bus == "SFX":
		volumes["UI"] = volumes["SFX"]
	_apply_volumes()


func _make_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_overlay = Label.new()
	_overlay.add_theme_font_size_override("font_size", 18)
	_overlay.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_overlay.add_theme_constant_override("outline_size", 8)
	_overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_overlay.position = Vector2(-360.0, -60.0)
	_overlay.visible = false
	layer.add_child(_overlay)


func _show_text(text: String) -> void:
	if _overlay == null:
		return
	_overlay.text = text
	_overlay.visible = true
	_overlay_until = Time.get_ticks_msec() + 2200


func _show_mixer() -> void:
	if _overlay == null:
		return
	if muted:
		_overlay.text = "Sound muted (M)"
	else:
		_overlay.text = "Music %d%%  (- =)    Effects %d%%  ([ ])    M mutes" % [roundi(volumes["Music"] * 100.0), roundi(volumes["SFX"] * 100.0)]
	_overlay.visible = true
	_overlay_until = Time.get_ticks_msec() + 1600


const SABLE_SOUNDS := {"sable_bank": "vault_rise", "sable_ratchet": "pylon_plant", "sable_peak": "sable_arpeggio"}
const SABLE_NOTES := [62, 65, 69, 72, 76, 74, 77, 81, 84, 88, 86]
var sable_note_log: Array = []
var _sable_bank_wait := false


func _sable_bank(id: String, _target: Node3D, _at: Vector3, _on: String) -> void:
	if id != "bank_shot":
		return
	if ctx.player.kit.line_state == Augments.LINE_SMASH:
		_sable_bank_wait = true
	else:
		_sable_bank_sound()


func _sable_bank_sound() -> void:
	var speed: float = ctx.player.state.velocity.length()
	var pitch := Harmony.ratio(12.0 * clampf(speed / 45.0, 0.0, 1.0) + mini(5, maxi(0, ctx.player.chain.combo - 1)))
	play("line_skill_fired", 0.0, 1.0, "SFX", SABLE_SOUNDS["sable_ratchet"])
	play("line_skill_fired", 0.0, pitch, "SFX", SABLE_SOUNDS["sable_bank"])


func sable_note(kind: String, number: int) -> void:
	var midi: int = 62 if kind in ["rain", "sentry"] else SABLE_NOTES[clampi(number - 1, 0, SABLE_NOTES.size() - 1)]
	var at := engine.next_beat() if engine.mode == MusicEngine.PLAY else engine.clock
	sable_note_log.append({"kind": kind, "number": number, "sample": at, "midi": midi})
	if sound_ready:
		if engine.mode == MusicEngine.PLAY:
			var id := SfxBank.cause_note_id(midi)
			if _admit("ultimate_peak", id, 1.0):
				engine.schedule_stinger_at(id, at, PRIORITY_DB[Rows.priority("ultimate_peak")])
		else:
			play("ultimate_peak", 0.0, Harmony.ratio(live_key()), "SFX", SfxBank.cause_note_id(midi))


const CANNON_CUES := {
	"cannon_live": {"row": "special_used"},
	"cannon_call": {"row": "special_used"},
	"cannon_weapon": {"row": "shot_fired"},
	"cannon_recoil": {"row": "dashed"},
	"cannon_smash": {"row": "slammed"},
	"cannon_line": {"row": "line_skill_fired"},
	"cannon_line_live": {"row": "line_skill_fired"},
	"cannon_peak": {"row": "ultimate_peak"},
	"cannon_landing": {"row": "ultimate_landed"},
	"cannon_recital": {"row": "synergy_discovered"},
	"cannon_answer": {"row": "mind_adapted"},
	"mind_quiet_gun_phase": {"row": "boss_phase_changed"},
	"mind_quiet_gun_fall": {"row": "boss_defeated"},
	"ending_cannon": {"row": "run_ended"},
}
var cannon_log: Array = []
var _cannon_queue: Array = []
var _cannon_threat_at := -INF
static var _cannon_streams := {}


func _wire_cannon(events) -> void:
	events.mind_adapted.connect(_cannon_answer)
	events.boss_attack_telegraphed.connect(func(_id: String, _warn: float): _cannon_threat_at = clock)
	events.run_started.connect(func(_id: String): _cannon_queue.clear())


func _cannon_beat_delay() -> float:
	var delay := float(engine.next_beat() - engine.clock) / Harmony.RATE
	if clock - _cannon_threat_at <= 0.2:
		delay += float(engine.beat_len()) / Harmony.RATE
	return maxf(0.0, delay)


func cannon_family(family: String, onbeat := false, kind := "cannon_live") -> void:
	var note := Harmony.family_note(family)
	if note < 0:
		return
	_cannon_cue(kind, [note], _cannon_beat_delay() if onbeat else 0.0)


func cannon_line(combo: int) -> void:
	var notes := Harmony.motif_notes("cannon")
	if combo < 5:
		_cannon_cue("cannon_line", [notes[clampi(combo - 1, 0, 3)]])
	else:
		_cannon_cue("cannon_line", notes, 0.0, false)


func cannon_motif(kind: String, onbeat := false, chord := false, octave := 0) -> void:
	var notes := Harmony.motif_notes("cannon").map(func(note): return int(note) + octave)
	_cannon_cue(kind, notes, _cannon_beat_delay() if onbeat else 0.0, chord)


func _cannon_answer(_habit: String, _icon: String) -> void:
	if _motif != "cannon":
		return
	var quote := SfxBank.stream("mind_cannon")
	var delay: float = quote.get_length() / Harmony.ratio(live_key()) + float(engine.beat_len()) / Harmony.RATE
	_cannon_cue("cannon_answer", Harmony.motif_notes("cannon"), delay, false)


func _cannon_cue(kind: String, notes: Array, delay := 0.0, chord := true) -> void:
	var row := {"kind": kind, "notes": notes, "due": clock + delay, "chord": chord}
	if delay > 0.0:
		_cannon_queue.append(row)
	else:
		_cannon_play(row)


func _cannon_play(row: Dictionary) -> void:
	var notes: Array = row["notes"]
	var key := "%s:%s" % [str(notes), row["chord"]]
	var kind: String = CANNON_CUES[row["kind"]]["row"]
	var sound := Rows.sound(kind, cue_context())
	var db: float = SfxBank.trim_db(sound) + PRIORITY_DB[Rows.priority(kind)]
	var pitch := Harmony.ratio(live_key())
	cannon_log.append({"kind": row["kind"], "row": kind, "sound": sound, "notes": notes.duplicate(), "at": clock, "due": row["due"], "db": db, "chord": row["chord"]})
	if not _admit(kind, sound, pitch):
		return
	if not _cannon_streams.has(key):
		var buf := Synth.buffer(Synth.seconds(2.6) + Harmony.STEP * notes.size())
		for i in notes.size():
			Synth.add_into(buf, Synth.note("chime", int(notes[i])), 0 if row["chord"] else i * Harmony.STEP, 0.7 / sqrt(float(notes.size())))
		_cannon_streams[key] = Synth.to_wav(buf)
	_start(kind, sound, _cannon_streams[key], db, pitch, "SFX")


func _step_cannon_cues() -> void:
	var waiting: Array = []
	for row in _cannon_queue:
		if clock + 0.000001 >= float(row["due"]):
			_cannon_play(row)
		else:
			waiting.append(row)
	_cannon_queue = waiting


func _on_tarn_claw_drag(id: String, _target: Node3D, _at: Vector3, _on: String) -> void:
	if id != "claw_drag":
		return
	if _line_claw_stream == null:
		var notes: Array = Harmony.motif_notes(LINE_CLAW_DRAG["motif"])
		var step: float = LINE_CLAW_DRAG["step_seconds"]
		var samples := Synth.buffer(Synth.seconds(0.9))
		Synth.add_into(samples, SfxBank.samples(LINE_CLAW_DRAG["ratchet"]), 0, 0.5)
		for i in notes.size():
			var note := Synth.note("reese", int(notes[i]))
			var duration := Synth.seconds(0.45 if i == notes.size() - 1 else 0.1)
			Synth.add_into(samples, Synth.declick(note.slice(0, duration)), Synth.seconds(step * (i + 1)), 0.65)
		_line_claw_stream = Synth.to_wav(Synth.normalize(samples))
	var pitch := Harmony.ratio(live_key() + Harmony.pentatonic_step(clampi(int(ctx.player.chain.combo) - 1, 0, CHAIN_STEPS)))
	if _admit("line_skill_fired", "line_claw_drag", pitch):
		_start("line_skill_fired", "line_claw_drag", _line_claw_stream, SfxBank.trim_db("line_claw_drag") + PRIORITY_DB[Rows.priority("line_skill_fired")], pitch, "SFX")


func _rivet_snare(steps: int) -> PackedFloat32Array:
	var source := Synth.snare()
	var ratio := Harmony.ratio(steps)
	var samples := Synth.buffer(ceili(source.size() / ratio))
	for i in samples.size():
		var at := minf(i * ratio, source.size() - 1)
		var lo := floori(at)
		samples[i] = lerpf(source[lo], source[mini(lo + 1, source.size() - 1)], at - lo)
	return Synth.declick(samples)


func _on_rivet_line_drive(id: String, _target: Node3D, _at: Vector3, on: String) -> void:
	if id != "line_drive" or ctx == null:
		return
	var spawner = ctx.get("spawner")
	var kit = spawner.get_node_or_null("RivetKit") if spawner != null else null
	var cue: Dictionary = kit.last_cue if kit != null else {}
	var notes: Array = Harmony.motif_notes(RIVET_LINE["motif"])
	var pitch := Harmony.ratio(live_key())
	var duration_ratio := 1.0 / pitch
	if on == "body":
		var stab := Harmony.scale_shift(int(notes[0]), clampi(int(ctx.player.chain.combo) - 1, 0, CHAIN_STEPS), Harmony.PENTATONIC)
		var samples := Synth.buffer(Synth.seconds(0.9 / duration_ratio))
		Synth.add_into(samples, Synth.declick(Synth.note("clav", stab)), 0, 0.7)
		var snare := _rivet_snare(stab - int(notes[0]))
		Synth.add_into(samples, snare, Synth.seconds(float(cue.get("delay", 0.0)) / duration_ratio), 0.5)
		Synth.add_into(samples, snare, Synth.seconds((float(cue.get("delay", 0.0)) + 0.03) / duration_ratio), 0.35)
		if _admit("line_skill_fired", RIVET_LINE["punch"], pitch):
			_start("line_skill_fired", RIVET_LINE["punch"], Synth.to_wav(Synth.normalize(samples)),
				SfxBank.trim_db(RIVET_LINE["punch"]) + PRIORITY_DB[Rows.priority("line_skill_fired")], pitch, "SFX")
		return
	var seconds := float(cue.get("seconds", 0.0))
	var samples := Synth.buffer(Synth.seconds((seconds + 0.5) / duration_ratio))
	var step: float = RIVET_LINE["roll_step"] / duration_ratio
	var tick := 0.0
	while tick < seconds / duration_ratio:
		Synth.add_into(samples, Synth.hat(false), Synth.seconds(tick), 0.35)
		tick += step
	Synth.add_into(samples, Synth.declick(Synth.note("clav", int(notes[notes.size() - 1]))), Synth.seconds(seconds / duration_ratio), 0.8)
	if _admit("line_skill_fired", RIVET_LINE["arrive"], pitch):
		_start("line_skill_fired", RIVET_LINE["arrive"], Synth.to_wav(Synth.normalize(samples)),
			SfxBank.trim_db(RIVET_LINE["arrive"]) + PRIORITY_DB[Rows.priority("line_skill_fired")], pitch, "SFX")
const TALLY_SOUNDS := {"plate": "plate_tally", "clip": "clip_tally", "stroke": "stroke_tally", "settle": "settle_tally"}
const TALLY_CUES := {
	"tally_plate": {"kind": "special_used", "sound": "plate_tally", "steps": [-12]},
	"tally_clip": {"kind": "line_skill_fired", "sound": "clip_tally", "steps": [0, 2, 3]},
	"tally_stroke": {"kind": "ultimate_peak", "sound": "stroke_tally", "steps": [0, 2, 3, 5]},
	"tally_total": {"kind": "ultimate_landed", "sound": "stroke_tally", "steps": [12]},
	"tally_settle": {"kind": "ultimate_landed", "sound": "settle_tally", "steps": [0, 3, 5, 7, 10, 12, 15, 17, 19, 22]},
}
const TALLY_PIECES := ["plate_return", "plate_audit", "plate_flywheel"]
const TALLY_SIXTEENTHS := 4.0
const TALLY_HOME_BPM := 172.0
var _tally_notes: Array = []
var _tally_beat := -1
var _tally_streams := {}


func _wire_tally(events) -> void:
	events.special_used.connect(func(id: String, _at: Vector3):
		if id == "gather_plate":
			_tally_cue("tally_plate", 0))
	events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, _on: String):
		if not id in ["link_clips", "link_double"]:
			return
		var combat = ctx.get("spawner") if ctx != null else null
		var clips: int = int(combat.last_card.get("hits", 1)) if combat != null else 1
		var lift := clampi(int(ctx.player.chain.combo) - 1, 0, CHAIN_STEPS)
		for i in clampi(clips, 1, TALLY_CUES["tally_clip"]["steps"].size()):
			_tally_cue("tally_clip", i, lift, i))
	events.ultimate_peak.connect(func(id: String, _at: Vector3):
		if id in TALLY_PIECES:
			for i in TALLY_CUES["tally_stroke"]["steps"].size():
				_tally_cue("tally_stroke", i, 0, i))
	events.ultimate_landed.connect(func(id: String, _at: Vector3, _hits: int, _damage: float):
		if not id in TALLY_PIECES:
			return
		_tally_cue("tally_total", 0)
		var combat = ctx.get("spawner") if ctx != null else null
		var settles: int = int(combat.tally_last_settle.get("settles", 0)) if combat != null else 0
		for i in mini(settles, TALLY_CUES["tally_settle"]["steps"].size()):
			_tally_cue("tally_settle", i, 0, i + 1))


func _tally_sixteenth() -> float:
	var bpm: float = engine.bpm() if engine != null and engine.mode == MusicEngine.PLAY else 0.0
	return 60.0 / (bpm if bpm > 0.0 else TALLY_HOME_BPM) / TALLY_SIXTEENTHS


func _tally_cue(cue: String, step: int, lift := 0, slot := 0) -> void:
	var row: Dictionary = TALLY_CUES[cue]
	var steps: Array = row["steps"]
	var semis: int = int(steps[step % steps.size()])
	if lift != 0:
		semis = Harmony.scale_shift(Harmony.HOME + semis, lift, Harmony.DORIAN) - Harmony.HOME
	var note := [clock + slot * _tally_sixteenth(), row["kind"], row["sound"], 62 + semis, cue == "tally_total"]
	if slot == 0:
		_tally_play(note)
	else:
		_tally_notes.append(note)


func _tend_tally() -> void:
	var combat = ctx.get("spawner") if ctx != null else null
	if combat != null and combat.get("ultimate") != null and combat.get("tally_piece") != null:
		var ult = combat.ultimate
		if ult.phase() == "flight" and String(combat.tally_piece) != "":
			if int(ult._beat) != _tally_beat and int(ult._beat) > 0:
				_tally_cue("tally_stroke", int(ult._beat) - 1)
			_tally_beat = int(ult._beat)
		else:
			_tally_beat = -1
	var waiting: Array = []
	for note in _tally_notes:
		if float(note[0]) > clock:
			waiting.append(note)
		else:
			_tally_play(note)
	_tally_notes = waiting


func _tally_play(note: Array) -> void:
	var kind := String(note[1])
	var sound := String(note[2])
	var pitch := Harmony.ratio(live_key())
	if not _admit(kind, sound, pitch):
		return
	var key := "%s:%d:%s" % [sound, int(note[3]), bool(note[4])]
	if not _tally_streams.has(key):
		_tally_streams[key] = Synth.to_wav(SfxBank.tally_recipe(sound, int(note[3]), bool(note[4])))
	_start(kind, sound, _tally_streams[key], SfxBank.trim_db(sound) + PRIORITY_DB[Rows.priority(kind)], pitch, "SFX")


var set_director := SetDirector.new()
var deck_moves := DeckMoves.new()
var _warden_posture := 0.0
var _warden_staggered := false
var _synth_form_state := "closed"
var _set_bar_at := -1
var _set_overtime := false
var _set_incoming_at := -1.0
var _set_answer := ""
var _set_answer_at := -1
const SET_ANSWER_YIELDS := ["open", "drop", "break"]


func set_director_on() -> bool:
	var tuning = ctx.get("tuning") if ctx != null else null
	return tuning != null and tuning.option(Tuning.SET_DIRECTOR_KEY) == "on"


func deck_style() -> String:
	var tuning = ctx.get("tuning") if ctx != null else null
	return tuning.option(Tuning.DECK_KEY) if tuning != null else "off"


func _tend_deck() -> void:
	var allow := ace_playing() and not ace.flat and _handover_at < 0 and bool(MusicArbiter.resolve(_arbiter_state())["allow_dj"])
	deck_moves.tend(ace, {"style": deck_style(), "allow": allow, "posture": _warden_posture, "staggered": _warden_staggered})


func _tend_set() -> void:
	_tend_deck()
	if not ace_playing() or not ace.mode in ["level", "warden", "piece"] or ace.section == "" or not set_director_on():
		_drop_set_answer()
		if _set_bar_at >= 0:
			_set_bar_at = -1
			set_director.reset()
		return
	if _set_answer != "" and _set_answer_spoiled():
		_drop_set_answer()
		ace.invalidate_trims(grid_unit(4))
	var at: int = ace.next_bar()
	if at == _set_bar_at or at - ace.clock > ace.grid_bar / 2:
		return
	_set_bar_at = at
	var plan := set_director.read(set_room(at))
	var ramp := grid_unit(4)
	if not plan.trims.is_empty() or plan.sweep > 0.0:
		ace.trim_bar(at, plan.trims, ace.grid_bar, ramp, plan.sweep, ace.trim_epoch)
	if plan.answer != "":
		_set_answer = SfxBank.SET_ANSWER + plan.answer
		_set_answer_at = at
		_melody_lease.book(_set_answer, at)
		engine.schedule_stinger_at(_set_answer, at, PRIORITY_DB[1], false, ramp)
		_log_cue(["set_answer", _set_answer, "grid", at, 1.0, PRIORITY_DB[1] + SfxBank.trim_db(_set_answer)])
	if plan.move != "hold":
		_log_cue(["set_move", plan.move, plan.mood, at, 1.0])


func _set_answer_spoiled() -> bool:
	var allowed := bool(MusicArbiter.resolve(_arbiter_state())["allow_dj"]) and not ace.flat
	var spoiled := _melody_lease.should_preempt({
		"answer_id": _set_answer,
		"answer_at": _set_answer_at,
		"clock_samples": ace.clock,
		"bar_samples": ace.grid_bar,
		"allowed": allowed,
		"warning": clock < _focus_until or _warden_charging,
		"busy": _set_busy(),
		"ace_mode": ace.mode,
		"ace_section": ace.section,
		"pending_section": String(ace.pending.get("section", "")),
	})
	if ace.clock >= _set_answer_at + ace.grid_bar:
		_set_answer = ""
	return spoiled


func _drop_set_answer() -> void:
	if _set_answer != "":
		engine.cancel_stinger(_set_answer)
		var at: int = ace.clock if ace != null else (engine.clock if engine != null else 0)
		_log_cue(["set_answer_dropped", _set_answer, "grid", at, 1.0])
		_set_answer = ""
		_melody_lease.release()


func _set_busy() -> bool:
	var quoted := float(_gates.get("pilot_quote", -1000.0)) - pilot_quote_gap()
	return clock < float(_gates.get("call_in", -1000.0)) or clock - quoted < 2.0 * float(ace.grid_bar) / Harmony.RATE


func set_room(at: int) -> Dictionary:
	var room := sample_run_parameters()
	room["sample"] = at
	if _hull_seen <= 0.0:
		room.erase("armour")
	room["pressure"] = _pressure
	room["heat"] = _redline_band
	room["overtime"] = _set_overtime
	match ace.mode:
		"piece":
			room["fight"] = "piece"
		"warden":
			room["fight"] = ace.section if ace.section in ["open", "drop"] else ace.warden_state
	if ace.section in ace.PROTECTED:
		room["fight"] = "directed"
	if ace.section == "main" and ace.mode != "piece":
		room["fight"] = "anthem"
	room["warning"] = clock < _focus_until or _warden_charging
	room["busy"] = _set_busy()
	if _set_incoming_at > clock:
		var bar_s := float(ace.grid_bar) / Harmony.RATE
		var lands_s := _set_incoming_at - clock - float(at - ace.clock) / Harmony.RATE
		room["incoming_bars"] = maxi(1, ceili(lands_s / bar_s)) if lands_s > 0.0 else 0
	return room


func _set_world_fact(kind: String) -> void:
	if kind == "overtime_rung":
		_set_overtime = true
	elif kind == "overtime_paid":
		_set_overtime = false


const VOICE_SYNTH := "synth"
const VOICE_TTS := "tts"
const VOICE_DEFAULT_SUBPATHS := ["artifacts/local/w46-audio/voice", "artifacts/local/w46-audio", "res://assets/audio/voice"]

var _cadence_prev := {}
var _rail_ids := {}
var _rail_wired_buffs: Object = null
var _visited_sites_seen := {}
var _cable_flips := 0
var voice_mode := VOICE_SYNTH
var voice_dir := ""
var _voice_clips := {}
var _voice_manifest_loaded := false


func _weapon_cadence() -> Dictionary:
	var combat = ctx.get("spawner") if ctx != null else null
	var driver = combat.get("weapon_driver") if combat != null else null
	if driver == null or not driver.has_method("state_snapshot"):
		return {}
	return driver.state_snapshot()


func _play_cadence(kind: String) -> void:
	play(kind, 0.0, 1.0, "SFX")


func _tend_cadence() -> void:
	var snap := _weapon_cadence()
	if snap.is_empty():
		_cadence_prev.clear()
		return
	var trigger := String(snap.get("trigger", ""))
	var weapon := String(snap.get("weapon", ""))
	if trigger == "" or trigger == "hold_auto":
		_cadence_prev = snap
		return
	if _cadence_prev.is_empty() or String(_cadence_prev.get("trigger", "")) != trigger or String(_cadence_prev.get("weapon", "")) != weapon:
		_cadence_prev = snap
		return
	var prev_win := String(_cadence_prev.get("window", "idle"))
	var win := String(snap.get("window", "idle"))
	match trigger:
		"press":
			if bool(snap.get("reloading", false)) and win == "open" and prev_win != "open":
				_play_cadence("cadence_rivet_notch_open")
			elif win == "hit" and prev_win != "hit":
				_play_cadence("cadence_rivet_notch_hit")
			elif bool(snap.get("reloading", false)) and win == "spent" and prev_win != "spent":
				_play_cadence("cadence_rivet_spent")
		"tap_charge":
			var was_charging := bool(_cadence_prev.get("charging", false))
			var charging := bool(snap.get("charging", false))
			var was_full := was_charging and float(_cadence_prev.get("charge", 0.0)) >= 0.999
			var is_full := charging and float(snap.get("charge", 0.0)) >= 0.999
			if is_full and not was_full:
				_play_cadence("cadence_sable_full")
			elif was_charging and not charging and float(snap.get("recover", 0.0)) > 0.0:
				_play_cadence("cadence_sable_bolt")
		"lob_snap":
			if win == "open" and prev_win != "open":
				_play_cadence("cadence_kest_window")
			elif win == "hit" and prev_win != "hit":
				_play_cadence("cadence_kest_snap")
		"beats":
			if win == "open" and prev_win != "open":
				_play_cadence("cadence_tarn_window")
			elif win == "hit" and prev_win != "hit":
				_play_cadence("cadence_tarn_rend")
		"stamp":
			if win == "open" and prev_win != "open":
				_play_cadence("cadence_tally_beat")
			if int(snap.get("stamp_streak", 0)) > int(_cadence_prev.get("stamp_streak", 0)):
				_play_cadence("cadence_tally_paid")
		"lock":
			var was_painted := bool(_cadence_prev.get("painted", false))
			var painted := bool(snap.get("painted", false))
			var prev_stage := String(_cadence_prev.get("lock_stage", "idle"))
			var stage := String(snap.get("lock_stage", "idle"))
			if painted and stage == "rail" and not (was_painted and prev_stage == "rail"):
				_play_cadence("cadence_cannon_lock")
			elif win == "hit" and prev_win != "hit":
				_play_cadence("cadence_cannon_rail")
			elif was_painted and not painted and prev_stage == "barrage" and float(snap.get("recover", 0.0)) > 0.0:
				_play_cadence("cadence_cannon_barrage")
	_cadence_prev = snap


func _wire_rail() -> void:
	var buffs = ctx.get("buffs") if ctx != null else null
	if buffs == null or buffs == _rail_wired_buffs:
		return
	if _rail_wired_buffs != null and is_instance_valid(_rail_wired_buffs):
		if _rail_wired_buffs.has_signal("buff_changed") and _rail_wired_buffs.buff_changed.is_connected(_on_buff_changed):
			_rail_wired_buffs.buff_changed.disconnect(_on_buff_changed)
		if _rail_wired_buffs.has_signal("buff_expired") and _rail_wired_buffs.buff_expired.is_connected(_on_buff_expired):
			_rail_wired_buffs.buff_expired.disconnect(_on_buff_expired)
	_rail_wired_buffs = buffs
	if buffs.has_signal("buff_changed") and not buffs.buff_changed.is_connected(_on_buff_changed):
		buffs.buff_changed.connect(_on_buff_changed)
	if buffs.has_signal("buff_expired") and not buffs.buff_expired.is_connected(_on_buff_expired):
		buffs.buff_expired.connect(_on_buff_expired)
	_sync_rail_ids()


func _sync_rail_ids() -> void:
	_rail_ids.clear()
	var buffs = ctx.get("buffs") if ctx != null else null
	if buffs == null or not buffs.has_method("active_rows"):
		return
	for row in buffs.active_rows():
		var id := String(row.get("id", ""))
		if id != "":
			_rail_ids[id] = true


func _in_play_for_rail() -> bool:
	var flow = ctx.get("flow") if ctx != null else null
	if flow == null or not flow.has_method("in_play"):
		return true
	return bool(flow.in_play())


func _play_rail(kind: String) -> void:
	play(kind, 0.0, 1.0, "UI")


func _on_buff_changed() -> void:
	var buffs = ctx.get("buffs") if ctx != null else null
	if buffs == null or not buffs.has_method("active_rows"):
		_rail_ids.clear()
		return
	var now_ids := {}
	for row in buffs.active_rows():
		var id := String(row.get("id", ""))
		if id != "":
			now_ids[id] = true
	if not _in_play_for_rail():
		_rail_ids = now_ids
		return
	var added := false
	for id in now_ids:
		if not _rail_ids.has(id):
			added = true
			break
	_rail_ids = now_ids
	if added:
		_play_rail("rail_rise")


func _on_buff_expired(id: String) -> void:
	if id == "" or not _rail_ids.has(id):
		return
	_rail_ids.erase(id)
	if _in_play_for_rail():
		_play_rail("rail_sink")


func _site_markers() -> Object:
	var parent = get_parent()
	var markers = parent.get("site_markers") if parent != null else null
	if markers != null and markers.has_method("visited_sites"):
		return markers
	return null


func _play_site_flip(site_key: String) -> void:
	if site_key == "" or _visited_sites_seen.has(site_key):
		return
	_visited_sites_seen[site_key] = true
	var flip_kind := "site_flip"
	play(flip_kind, 0.0, 1.0, "UI")


func _tend_site_flips() -> void:
	var markers := _site_markers()
	if markers == null:
		return
	for row in markers.visited_sites():
		var key := String(row.get("key", ""))
		if key != "":
			_play_site_flip(key)


static func parse_voice_args(args: PackedStringArray) -> Dictionary:
	var mode := VOICE_SYNTH
	for arg in args:
		if arg.begins_with("--voice="):
			var raw := arg.substr("--voice=".length()).strip_edges().to_lower()
			mode = VOICE_TTS if raw == VOICE_TTS else VOICE_SYNTH
	return {"mode": mode, "dir": OS.get_environment("SCRAPKEEP_VOICE_DIR").strip_edges()}


func _configure_voice_from_args() -> void:
	var all_args := PackedStringArray()
	all_args.append_array(OS.get_cmdline_args())
	all_args.append_array(OS.get_cmdline_user_args())
	var parsed := parse_voice_args(all_args)
	set_voice_mode(String(parsed["mode"]), String(parsed["dir"]))


func set_voice_mode(mode: String, dir := "") -> void:
	voice_mode = VOICE_TTS if mode.strip_edges().to_lower() == VOICE_TTS else VOICE_SYNTH
	voice_dir = dir.strip_edges()
	_voice_clips.clear()
	_voice_manifest_loaded = false
	if voice_mode != VOICE_TTS:
		SfxBank.set_voice_sidecar(false, {})
		return
	_load_voice_manifest()
	SfxBank.set_voice_sidecar(true, _voice_clips)


func voice_manifest_loaded() -> bool:
	return _voice_manifest_loaded


func voice_clip_for(speaker: String, text: String) -> String:
	if voice_mode != VOICE_TTS or speaker in SfxBank.SYNTH_ONLY_SPEAKERS:
		return ""
	return SfxBank.voice_clip_path(speaker, text)


func _voice_candidate_dirs() -> Array[String]:
	var out: Array[String] = []
	if voice_dir != "":
		out.append(voice_dir)
		return out
	var res_abs := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var repo_abs := res_abs.path_join("../..").simplify_path()
	for sub in VOICE_DEFAULT_SUBPATHS:
		if sub.begins_with("res://") or sub.begins_with("user://"):
			out.append(sub)
		else:
			out.append(repo_abs.path_join(sub))
	return out


func _load_voice_manifest() -> void:
	for base_dir in _voice_candidate_dirs():
		if base_dir == "":
			continue
		var manifest_path := ""
		var clip_root := base_dir
		if base_dir.ends_with(".json") and FileAccess.file_exists(base_dir):
			manifest_path = base_dir
			clip_root = base_dir.get_base_dir()
		elif FileAccess.file_exists(base_dir.path_join("manifest.json")):
			manifest_path = base_dir.path_join("manifest.json")
			clip_root = base_dir
		elif FileAccess.file_exists(base_dir.path_join("voice").path_join("manifest.json")):
			manifest_path = base_dir.path_join("voice").path_join("manifest.json")
			clip_root = base_dir
		elif FileAccess.file_exists(base_dir.get_base_dir().path_join("manifest.json")):
			manifest_path = base_dir.get_base_dir().path_join("manifest.json")
			clip_root = base_dir.get_base_dir()
		if manifest_path == "":
			continue
		var raw := FileAccess.get_file_as_string(manifest_path)
		if raw.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(raw)
		if parsed is Array:
			_ingest_voice_entries(parsed, clip_root, base_dir)
			_voice_manifest_loaded = true
			return
		if parsed is Dictionary:
			_ingest_voice_manifest(parsed, clip_root, base_dir)
			_voice_manifest_loaded = true
			return


func _ingest_voice_entries(items: Array, clip_root: String, base_dir: String) -> void:
	for entry in items:
		if not entry is Dictionary:
			continue
		if bool(entry.get("audition_only", false)):
			continue
		var speaker := String(entry.get("speaker", entry.get("caller", ""))).strip_edges().to_lower()
		var text := String(entry.get("text", entry.get("line", "")))
		var file := String(entry.get("file", entry.get("path", entry.get("wav", ""))))
		_register_voice_clip(speaker, text, file, clip_root, base_dir)


func _ingest_voice_manifest(data: Dictionary, clip_root: String, base_dir: String) -> void:
	for list_key in ["clips", "entries", "lines"]:
		var items = data.get(list_key)
		if items is Array:
			_ingest_voice_entries(items, clip_root, base_dir)
		elif items is Dictionary:
			for k in items:
				var key_s := String(k)
				var val = items[k]
				if val is String and key_s.begins_with(SfxBank.SAY):
					var parts := SfxBank._said(key_s)
					_register_voice_clip(String(parts[0]).to_lower(), String(parts[1]), val, clip_root, base_dir)
				elif val is Dictionary:
					for line_text in val:
						_register_voice_clip(key_s.to_lower(), String(line_text), String(val[line_text]), clip_root, base_dir)
	var speakers = data.get("speakers")
	if speakers is Dictionary:
		for speaker_key in speakers:
			var sp := String(speaker_key).strip_edges().to_lower()
			var lines = speakers[speaker_key]
			if lines is Dictionary:
				for line_text in lines:
					_register_voice_clip(sp, String(line_text), String(lines[line_text]), clip_root, base_dir)


func _register_voice_clip(speaker: String, text: String, file: String, clip_root: String, base_dir: String) -> void:
	if speaker == "" or file == "" or speaker in SfxBank.SYNTH_ONLY_SPEAKERS:
		return
	var resolved := _resolve_voice_file(file, clip_root, base_dir)
	if resolved == "":
		return
	var key_text := "*" if text == "" or text == "*" else text
	_voice_clips["%s|%s" % [speaker, key_text]] = resolved
	if key_text != "*":
		_voice_clips["%s|%s" % [speaker, key_text.strip_edges().to_lower()]] = resolved


static func _resolve_voice_file(file: String, clip_root: String, base_dir: String) -> String:
	if file.is_absolute_path() or file.begins_with("res://") or file.begins_with("user://"):
		return file if FileAccess.file_exists(file) else ""
	for root_dir in [clip_root, clip_root.get_base_dir(), base_dir, base_dir.get_base_dir(), clip_root.path_join("voice")]:
		var root_s := String(root_dir)
		if root_s == "":
			continue
		var candidate := root_s.path_join(file)
		if FileAccess.file_exists(candidate):
			return candidate
	return ""
