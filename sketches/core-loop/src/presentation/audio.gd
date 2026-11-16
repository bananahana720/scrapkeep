extends Node

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
# v2 W3 characters: the vault cap the vault cue is pitched against.
const Augments := preload("res://src/movement/augments.gd")
# v2 W9: the class row names the motif every class cue resolves through, and the roster
# tells an ancient from the Fleet.
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
# SR7: the shortest gap between two chirps of one companion cue (start value, comps
# ror2/companions.md "Lab measure": at most once per trigger within a cooldown).
const CHIRP_COOLDOWN := 0.75
const CHIRP_LOG_CAP := 256
const SpecialAudio := preload("res://src/presentation/special_audio.gd")
const MenuSounds := preload("res://src/presentation/menu_sounds.gd")
var _menu_sounds := MenuSounds.new()
# The live kill-first specials: enemy instance id -> {"node", "name", "player"}.
var _specials := {}
const PhaseMusic := preload("res://src/presentation/phase_music.gd")
# The highest boss phase whose track has been started, the stage the band returns to when the
# champions are gone, and the live champions (enemy id -> node) with the ones already on euro.
var pack_available: Callable = PhaseMusic.available
var _phase_music_done := 0
var _stage_now := 0
var _champions := {}
var _champion_hyped := false
var _champion_euro := {}
const TuneMoments := preload("res://src/presentation/tune_moments.gd")
# The place-and-moment tunes (tune_moments.gd): the live moments ({"id", "kind", "key", "seq",
# "until"}), the one the level band plays now, this run's rare remixes and their own rng (never
# the run's), and whether this stage's Warden has taken the landmark's place.
var tune_available: Callable = TuneMoments.available
# Whether a title row's pack is on disk (title_theme); tests swap it.
var title_available: Callable = func(row: String) -> bool: return MusicRows.pack_on_disk(MusicRows.resolve(row)["ace_manifest"])
var _moments: Array = []
var _moment_seq := 0
var _moment_playing := ""
var _remixes := {}
var _remix_rng := RandomNumberGenerator.new()
var _warden_engaged := false
# A Warden's fight is on: from its engage until its arena opens.
var _warden_fighting := false
var specials_heard: Array = []

# Moss's jukebox: the band's intensity at each of the dial's three detents (idle, cruise,
# full tilt), fed as the threat parameter while a record spins, so the drums and the lead
# build as they do with speed in play.
const SPIN_ENERGY := [0.15, 0.5, 0.9]

# A jukebox tune heard in play for long enough to count (tune_ear.gd); fires once per id.
signal tune_heard(id: String)
# The pilot radio's track gave the air back to the score: a boss, a death, the run's end.
signal radio_yielded(reason: String)

# The audio director. It hears every GameEvents fact, picks the sound its event_kinds
# row names and decides one thing: now or on the beat.
#   Now: anything the player caused (a jump, a hit, a pickup, a death, the gate you
#   rolled through). Feedback that waits for a beat feels laggy.
#   On the beat: announcements the world or the flow makes (a stage, the gates, the
#   klaxon, a milestone, the stage clear). They go through the band so they land in
#   time, and flow stingers queue in one lane so they never talk over each other.
# It also owns the mixer: Music, SFX, UI and Ambient buses, the master chain, the state
# snapshots, the telegraph focus, ducking and volume keys. Every mix number is a row in
# mix_rows.gd.

const BUSES := MixRows.BUS_DB
const GEN_BUFFER := 0.1
const POLYPHONY := 32
# Simultaneous voices per cue and the shortest gap between two starts (SfxBank, from mix_rows.gd).
const VOICE_LIMIT := SfxBank.VOICE_LIMIT
const MIN_GAP_MS := SfxBank.MIN_GAP_MS
const PRIORITY_DB := [-6.0, -3.0, 0.0, 0.0]
# Hitting on the beat pays in sound and look only (Andrew, Q10 "Sound only", 17 Oct 22:12Z):
# a hit within ONBEAT_WINDOW_S of a beat the player hears adds a clap (ONBEAT_SOUND), and fires
# hit_on_beat for the comic word. At most once a
# beat. Damage never reads it.
signal hit_on_beat(enemy: Node3D, kind: String)
const ONBEAT_WINDOW_S := 0.08
# A hit on the beat claps with the band's drums (design-v3/sound/feedback_set.py): percussion, so it
# never sits on the melody. ONBEAT_DB puts it about at a ranged hit's level, 8 dB under the sax stab it replaced.
const ONBEAT_SOUND := "onbeat_clap"
const ONBEAT_DB := -8.0
# Tests set this to stand in for the beat clock: it returns the signed offset in seconds.
var beat_offset_hook := Callable()
var _onbeat_at := -(1 << 40)
# A pilot's skill cast on the beat is answered by the band (Andrew, 13 Nov 02:17Z to 02:19Z): the skill's own
# sound plays when pressed, never moved to the grid; inside ONBEAT_WINDOW_S the pilot's motif joins on
# the next sixteenths in its own voice. A hidden reward, sound and look only like the on-beat hit
# (Q10). SKILL_ANSWER_NOTES of the motif's cells, all of them against an elite, a miniboss, the
# Warden, or anything in a live boss fight, with the last note doubled in the motif's band voice. Only
# a line skill names its foe (at its bite); a special or gauge release counts as big only in a boss
# fight. Cooldowns stop a skill from repeating it, so the gate only keeps two cues of one cast
# (a gauge release and its special) or two skills on one beat from stacking.
signal skill_on_beat(kind: String, big: bool)
const SKILL_ANSWER_NOTES := 2
var _skill_answer_at := -(1 << 40)
# Weak-point hits inside this window climb like a kill chain. Pickups and kills climb by
# their streaks, whose windows are in EventKinds.JUICE.
const KILL_COMBO_WINDOW_MS := 1500
# The plate shed's size: scrap removed at which the big clatter starts (the small one
# stops at 40% of it) and at which pitch and level bottom out.
const ARMOR_SHED_BIG_FROM := 150.0
const ARMOR_SHED_FULL := 250.0
const MENU_STATES := ["title", "class_select", "summary", "dead"]
# Weapon voices per class, so each class sounds like itself (identity, principle 5).
# Tally's three cards climb E, F, G over D, the motif's count intervals.
const WEAPON_PITCH := {"arc_caster": -3.0, "rapid_laser": 4.0, "claw_sweep": -5.0, "cannon_lane": -7.0,
	"gather_plate": 2.0, "link_clips": 3.0, "balance_due": 5.0}
const VOLUME_STEP := 0.1
const VAULT_KILL_SOUND := "vault_drop"

# The harpoon line's grammar (design-v3/LEGIBILITY.md sections 3 and 5). Gaps are in seconds on
# the audio clock, which _process advances by its delta so a test can step it.
const LOCK_TICK_GAP := 0.25
const FAIL_GAP := 0.25
const DRY_TICK_GAP := 0.1
# Rungs of the reward ladder a chain link's bite can climb: link six is the octave.
const CHAIN_STEPS := 5
const CHAIN_BITE_HOLD_S := 0.25
const CAUSE_RESOLVE_GAP := 4.0
const NOTE_SPACING := 0.14
# The hum stands while the line does, and climbs an octave as the gap closes from far to near.
const HUM_STATES := ["latched_world", "latched_body", "smash_committed"]
const HUM_FAR := 45.0
const HUM_NEAR := 3.0
const HUM_DB := 0.0
# A threat kind whose warning has a release half, played when the threat goes live.
const THREAT_RELEASE := {"threat_lane": "threat_tear"}
# Danger, keyed and Kest sound lists live in SfxBank next to TRIM_DB.
const DANGER_SOUNDS := SfxBank.DANGER_SOUNDS
# A launch whose landing never comes (a fall into the next stage's rail) still drops. Timed on
# SimClock: the drop restarts the band and so the bar grid that park events land on.
const LANDING_FALLBACK_MS := 2000
# Expected launch-to-landing time, for the pace of the build's sweep.
const LAUNCH_BUILD_SECONDS := 1.6
const KEYED_SOUNDS := SfxBank.KEYED_SOUNDS
const KEST_SOUNDS := SfxBank.KEST_SOUNDS
# The Warden's posture fight is heard as one phrase (SfxBank.BREAK_PHRASES, variant 0): a
# hit plays the note of the guard's quarter, the stagger sounds all four with the open
# row's sound, a shattered chunk plays its row's sound over a low hit.
# --- P-C Tarn audio ---
const LINE_CLAW_DRAG := {"sound": "line_claw_drag", "ratchet": "clank", "motif": "tarn", "step_seconds": 0.1}
var _line_claw_stream: AudioStreamWAV
# --- end Tarn ---
# --- P-C Rivet audio ---
# Line Drive (design-v3/pilots/rivet.md section 2.3, Sound). The punch: one clav stab on the
# motif's hammered note as the pulse leaves, a snare flam when it lands (the kit's pulse delay),
# one rung of the reward ladder up per chain link. The haul: a closed-hat roll for the haul's length, landing the
# motif's fourth on arrival. Both read the kit's last_cue, so the cue and the act share one record.
const RIVET_LINE := {"punch": "rivet_line_punch", "arrive": "rivet_line_arrive", "motif": "rivet", "roll_step": 0.0625}
# --- end Rivet ---
const POSTURE_QUARTER := 25.0
const POSTURE_PHRASE := 0
const SHATTER_LOW := "chunk_low"
# Event progress until the spine publishes event_progress(event_id, fraction): the
# seconds each participatory event usually takes (REQUEST in the hand-back).
const EVENT_SECONDS := {"hold_the_relay": 18.0, "surge_run": 22.0, "scrap_stampede": 16.0}

# v2 W3 characters: the class-ability facts, heard through their event rows.
const CHARACTER_KINDS := ["enemy_rebounded", "enemy_pinned", "vault_kicked", "gauge_charging", "gauge_released",
	"gauge_cancelled", "sprint_started", "cc_ignored", "cloak_started", "cloak_broken", "sticky_detonated",
	"rocket_jumped", "blink_used", "arc_slammed", "skid_smashed", "demo_slammed", "tree_offered", "tree_picked"]
# v2 W7 enemies: holds, tenacity and the ancients' tells. Each plays its event row's
# sound through the same wiring as the character facts. vent_charging and vent_erupted
# also drive the reactor pedal (v2 W5b), and hold_started and pack_arrived resolve by
# who holds or arrives (v2 W9), so they get their own listeners below.
const ENEMY_KINDS := ["hold_broken", "hold_ended", "tenacity_gained",
	"shield_vaulted", "swarm_scattered", "mind_adapted", "weak_point_opened", "enemy_ringed_out"]

var ctx
# Per posture Warden, the stagger and chunk count the last posture_changed showed.
var _posture_seen := {}
# The fewest guard steps each Warden has been seen with (_guard_step_fell).
var _guard_steps := {}
# True from a charge cue the Warden began until vent_erupted or a stagger cuts it.
var _warden_charging := false
# Events announced with no lead, until each starts: see _on_event_announced.
var _unwarned := {}
var engine: MusicEngine
# The ACE band (--music=ace): the zone's music row selects its manifest; a zone with
# no pack, or any missing file, plays the synth.
var ace: AceSequencer
var ace_manifest := ""
# The title's music row: "title" until an opening names its theme (title_theme).
var title_row := "title"
var _on_title := false
# The row a won run's summary and the ending play: theme C, the show opening, with its whole-step
# lift (Andrew, "Won run and ending", 17 Oct). The summary pack holds it: won, its return section
# plays two bars of theme C and then theme C lifted a whole step (tools/ace/package_core_packs.py);
# lost, its travel loop is the jazz-club summary. A pack not on disk falls back to the plain title-c.
const WON_SUMMARY_ROW := "summary"
# The camp page is open on the title (screens.gd): the camp pick plays while it is.
var camp_open := false
# The manifest the zone rows last selected. A caller that sets ace_manifest away from it
# (a test's missing package) keeps its pick across stage entries (fix round D, 2026-10-04).
var _ace_row_manifest := ""
var _ace_from := ""
# The transport sample the block engine.render is rendering began at, -1 outside a render.
var _render_from := -1
# The file a failed load named, "" when the package loaded or was never asked for.
var ace_missing := ""
var _ace_failed := false
# The stems load on a worker while the title shows (24 Oggs, 5.8 MB): the task, its
# result and the manifest it read. ace_ready() waits for the rest of it, or loads them
# in place when the option or the manifest changed after setup. The worker writes into
# _ace_slot, never into this node, so a node freed mid-load is not locked by the call.
var _ace_task := -1
var _ace_slot: Array = []
var _ace_loaded_from := ""
var _ring_capacity := 0
# The ACE ring's depth: the POC's QUEUE_TARGET, raised a step whenever the ring runs dry,
# for a device that pulls more per period than the 512 or 1024 frames it was sized on
# (the headless Dummy driver pulls 4096).
var queue_target := AceSequencer.QUEUE_TARGET
var _skips_seen := 0
var _ace_pumped_usec := 0
var _ace_gap_usec := 0
# The last pump stopped short of the queue at a park cue's due, so the ring may run dry by design.
var _park_held := false
# The synth band fades in over this many frames when it comes back from mute, so a voice
# still sounding under the mute never steps to full level. _unmute_at is the transport
# sample the ramp starts from, -1 when none runs.
const UNMUTE_RAMP := AceSequencer.STOP_RAMP
var _unmute_at := -1
# A set piece heard through a launch's flight: the flight holds the ACE band, and the
# landing hands it to the synth on a beat. _handover_at is that beat while it is coming.
var _ace_flight := false
var _handover_at := -1
# The recorded band's kill cadence has answered the Warden break whose release the engine still
# carries (_answer_release): that release no longer reaches the recorded band.
var _release_answered := false
var _ace_arrival_stage := 0
var _ace_arrival_at := -1
# The transport sample the synth band starts fading out under the ACE band, -1 when the
# synth band plays alone. It fades over AceSequencer.STOP_RAMP and is muted after.
var _band_fade_start := -1
# v2 W3 characters: which of CHARACTER_KINDS are already connected.
var _character_wired := {}
var _optional_listeners := {}
# v2 W9: the run's class motif id (class_def motif), from run_started.
var _motif := ""
# Moss's babble, baked once per line, beat and key: {"beat|key|text": AudioStreamWAV}.
var _babble := {}
var sound_ready := false
var _pitch_rng := RandomNumberGenerator.new()
# Every cue decided: [kind, sound, "now" | "beat" | "music" | "skip", start_sample, pitch].
var cue_log: Array = []
# The process frame of the last play_stream call, so a test can count frames from event to play().
var last_play_frame := -1
# The pitch the log shows for a tiered cue (the caller's ladder rung); -1 logs the played pitch.
var _logged_pitch := -1.0
var chirp_log: Array = []
var _chirp_last := {}
var volumes := {"Music": 0.8, "SFX": 1.0, "UI": 1.0}
var muted := false
# False on the dummy driver (headless tests, or a machine with no sound device): no
# players start, and the band runs on a real-time clock so every cue decision and beat
# still happens. Quitting right after freeing a playing player leaks its playback.
var live_output := true

var _music_player: AudioStreamPlayer
var _stinger_player: AudioStreamPlayer
var _music_pb: AudioStreamGeneratorPlayback
var _stinger_pb: AudioStreamGeneratorPlayback
var _sfx: AudioStreamPlaybackPolyphonic
# Lane threat instance id -> its held hum voice (-1 without live output), until the lane goes live or leaves.
var lane_hums := {}
var _ui: AudioStreamPlaybackPolyphonic
var _sfx_player: AudioStreamPlayer
var _ui_player: AudioStreamPlayer
var _voices := {}
var _last_start := {}
var clock := 0.0
var hum_on := false
# The line state before the current one, so the dock click plays when the hook leaves rewinding.
var _line_was := ""
var hum_pitch := 1.0
var _chain_bite_ms := -100000.0
# Melodic payoff on the grid (AUDIO-V3 section 5). The player's own contact sounds on its frame
# (rule 1) and no climb leaves the reward ladder (rule 3). The tune a frame cannot carry lands on
# the band's grid, a sixteenth later at most, as grid notes in the stinger lane, keyed to the band:
# a kill chain's landing on a chord tone (rule 5), the near miss's two whip notes (rule 4), and the
# dunk's banked fifth and paid home note.
# A kill chain that reached STREAK_LAND_RUNG lands on the next beat when its window closes. One
# that reached STREAK_BAR_RUNG restates its last note and lands on the next bar line under a crash.
const STREAK_LAND_RUNG := 2
const STREAK_BAR_RUNG := 5
const STREAK_VOICE := "bell"
const STREAK_BODY := "keys"
const CHAIN_CRASH := "chain_crash"
# The recorded band's chords are not in its manifest. Home's triad is in every key it plays.
const HOME_TRIAD := [62, 65, 69]
# The dunk banks on the fifth and pays on home.
const DUNK_VOICE := "mallet"
const DUNK_STORED_MIDI := 81
const DUNK_SPENT_MIDI := 74
# A death's fall: the death cue's dying tritone (Ab over D) collapses through F onto D, in
# eighths from the beat the band stops on, on the cue's own brass and in the cue's key.
const DEATH_FALL := [56, 53, 50]
const DEATH_FALL_VOICE := "brass"
# A completed part set: three notes for its three parts climb the home chord (F A D) in eighths,
# the first two in the voice of the set's element and under the third, which is the appliance
# beep's "done" on high D. The first note waits SET_CHIME_LEAD_S, the time a worker needs to
# make the three in the live key (a note is 17 to 25 ms).
const SET_CHIME := [77, 81, 86]
const SET_CHIME_VOICES := {"arc": "clav", "frost": "bell"}
const SET_CHIME_DONE_VOICE := "beep"
const SET_CHIME_LEAD_S := 0.12
# The band sits at this gain under the chime. Its notes are the home chord's, which the band is
# playing too: over the recorded band the last note stood only 2 to 5 dB over the band's own D
# (PC listen, 9 November 2026).
const SET_CHIME_DUCK := 0.6
# The band answers a long chain by name: the pilot's quote starts a beat after the chain lands, and
# not again for PILOT_QUOTE_BARS bars of the sounding band (sound/INTEGRATION.md section 6), so it
# stays a treat.
const PILOT_QUOTE_BARS := 8
# A call-in is booked this far ahead, the time a worker has to make the line, and the band
# sits at this gain under it.
const CALL_LEAD_S := 0.3
const CALL_DUCK := 0.6
# The bank id of the line the last caller was booked to say, for call_end.
var _calling := ""
# The last_ms of the kill chain whose end has been heard.
var _streak_landed_ms := -100000
# The beat a death holds the recorded band to; the lost summary's pack starts once it has passed
# (the sequencer holds one pack at a time). -1 when none waits.
var _summary_due := -1
# The key and class the whip's and the dunk's grid notes were last made for (_warm_grid_key).
var _grid_key := ""
var _hum_voice := -1
var _gates := {}
var _fired_this_run := {}
var _notes: Array = []
# The pickup streak and the kill chain. Audio bumps them as it plays each rung; juice
# reads the same records at the end of the frame to draw the chain and the pulse.
var scrap_streak := Streak.for_kind("scrap_collected")
var cog_streak := Streak.for_kind("cogs_collected")
var kill_streak := Streak.for_kind("enemy_killed")
# Armour mode only: recovered spill clusters climb like a pickup streak, and the hull
# damage already heard, so a hit is hurt only when the hull took some.
var reclaim_streak := Streak.for_kind("armor_reclaim")
var _hull_seen := 0.0
# True once armor_hit sounded for the hit in flight; player_hit reads and clears it.
var _shed_heard := false
var _beacon_rung := -1
var _gates_announced := false
var _heft_class := 1
var _unseal_ms := -100000
var _boss_phase := 1
var _weak_combo := 0
# The launch build: armed on launched, handed its stage on stage_entered, dropped on
# the first landing after it. [touchdown_sample, drop_sample] per landing drop.
var _launch_armed := false
var _landing_theme := -1
var _entered_ms := -1
var _launch_stage := false
var drop_log: Array = []
# The set piece (SKILL-BAR section 4, music): the meter's lift is on (one synth intensity step,
# one ACE pressure step), and a wind-up's build waits for its landing's drop. _pressure is
# the last systemic pressure, which the ACE step sits on top of.
var _ult_lift := false
var _ult_armed := false
# The ultimate in the air ended the stage's own recorded band (roaming or its Warden fight,
# never a boss's or a champion's pack): its landing books the band back, and so does a cancel
# for one of these reasons. A launch or the Warden's break in between takes the music for
# itself and drops the booking (_ult_band_stays_off).
const ULT_BAND_BACK := ["recall", "bail"]
const STAGE_BAND_MODES := ["level", "warden"]
var _ult_took_band := false
var _pressure := 0.0
# Lab knobs: facing is weighted by proximity, so a distant face cannot dominate.
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
# The Music-bus block after selecting or mixing the recorded and synthesized bands.
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
# The record Moss's jukebox is playing, "" when the game drives the music.
var spinning := ""
var spin_detent := 2
var _spin_restore := Callable()
# The pilot radio (radio_deck.gd): the track it holds over the run, "" while the score plays.
# While it holds, the stage, moment, champion and miniboss cues leave the band alone (their
# stingers still sound); a boss or a Warden takes the air back unless the track is pinned.
# Off mutes the Music bus alone: hits, stingers and musical answers ride the SFX bus.
var radio_hold := ""
var radio_pinned := false
var radio_silenced := false
var _radio_args := []
var _radio_respin_due := false
# A boss's final phase has the air (Andrew, card 20:52:55Z 17 Oct: the finale wins over a pin);
# the boss music a pinned track held off, as [kind, music], to start when the finale takes over.
var radio_finale := false
var _radio_boss := []

static var _bake_task := -1
static var _baked := false
static var _bake_done := false
static var _rest_task := -1
static var _opening_task := -1


func _init() -> void:
	_pitch_rng.seed = 0xA0D10


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Audio"
	# Music keeps playing, softer, while the tree is paused, and the keys still work.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_buses()
	live_output = AudioServer.get_driver_name() != "Dummy"
	engine = MusicEngine.new()
	engine.warm_stingers = live_output
	if ctx.has_method("aim_forward"):
		engine.set_parameter_source(sample_run_parameters)
		engine.parameter_commit.connect(_commit_band_parameters)
	_music_player = _generator_player("Music", "MusicStream")
	_stinger_player = _generator_player("SFX", "StingerStream")
	_sfx_player = _poly_player("SFX", "SfxVoices")
	_ui_player = _poly_player("UI", "UiVoices")
	_make_overlay()
	_connect_all(ctx.events)
	_start_bake()
	# The worker preloads the take the first title plays (title A when it is on disk).
	ace_manifest = MusicRows.resolve(title_now())["ace_manifest"]
	_ace_row_manifest = ace_manifest
	_start_ace_load()
	read_ace_ahead(_music_row(1)["ace_manifest"])
	_flow_queue.append(["idle"])


# --- Baking -------------------------------------------------------------------------
# Baking the bank and the band's notes takes about two seconds of CPU, so it runs on
# a worker at startup and the title never waits for it. Nothing touches the caches
# on the main thread until the bake is done; cues before then are skipped.

static func _sound_ids() -> Array:
	var ids: Array = Rows.sound_ids()
	for kind in EventKinds.THREAT_ROWS:
		ids.append(EventKinds.THREAT_ROWS[kind]["sound"])
	for extra in ["womp", "build_riser", "vault_rise", "vault_drop", "synergy_hit"]:
		if not extra in ids:
			ids.append(extra)
	# Every baked recipe a row can resolve to (a class motif, a hold, an arrival, the bell).
	for id in SfxBank.TRIM_DB:
		if not id in ids:
			ids.append(id)
	# The event-set files, tier files included (a tier plays by rung, so it must be baked).
	for id in SfxBank.EVENT_CUES:
		if not id in ids:
			ids.append(id)
	# The story stings: their first play decoded the file on the main thread (Warden sighted,
	# gates and the bowl handoff, 20-40 ms frames on the 4080).
	for sting in SpillwayStory.STINGS.values():
		ids.append(SfxBank.stinger_id("1_1", sting))
	for midi in SfxBank.break_midis(POSTURE_PHRASE):
		ids.append(SfxBank.cause_note_id(midi))
	for cause in EventKinds.CAUSE_ROWS:
		for note in EventKinds.cause_motif(cause):
			var id := SfxBank.cause_note_id(Harmony.note_midi(String(note)))
			if not id in ids:
				ids.append(id)
	# The grid notes whose pitch is known ahead: every class's whip, the dunk's pair, the death's
	# fall, and a kill chain's landings over the recorded band. A note costs 17 to 25 ms to make,
	# a frame hitch if its beat has to make it. A landing over the synth band follows the chord
	# and is made on a worker as the chain climbs (_warm_landing).
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


# Every note a kill chain can land or hold on over the home triad, in D.
static func _home_landing_ids() -> Array:
	var ids: Array = []
	var cap := int(EventKinds.juice("enemy_killed").get("chain_cap", 9))
	for rung in range(STREAK_LAND_RUNG, cap + 1):
		for id in _landing_ids(rung, HOME_TRIAD):
			if not id in ids:
				ids.append(id)
	return ids


# The notes of a chain's landing from rung over tones: the bell, the keys an octave below, and
# a long chain's held last note.
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
	# The startup jobs here and below are high priority on purpose: a low-priority one
	# queues behind the bake on a small pool (the pool reserves a few low-priority threads,
	# one on 2 to 4), and a process that quits with it still queued never exits.
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


# Packages read ahead on a worker, by manifest: task ids. A switch of package on the main
# thread read the new package's 24 Oggs in its tick: 63 ms at each stage entry in the cloud, and
# the 4080's Dig entry tick held 114 to 118 ms (board #934, 13 Nov 2026). Read ahead, the switch
# finds the streams kept (AceSequencer.kept) and reads none.
var _ace_ahead := {}


func read_ace_ahead(manifest: String) -> void:
	# The export proof reads the first ACE_CHECK line, which a read-ahead's band would race to print.
	if manifest == "" or _ace_failed or _ace_ahead.has(manifest) or not ace_wanted() or AceSequencer.kept(manifest) \
			or "--ace-check" in OS.get_cmdline_args() or "--ace-check" in OS.get_cmdline_user_args():
		return
	_ace_ahead[manifest] = WorkerThreadPool.add_task(_ace_loader(manifest, []), true, "presentation ACE read-ahead")


# The packages a Warden's engage leads to: the next stage's band, and after a world's last
# stage the boss's entry anthem. Read when the world starts building the next stage.
func _read_ahead_after(stage: int) -> void:
	var stages = _music_stages()
	if stages.is_world_last(stage):
		var boss := _boss_track()
		if boss in MusicEngine.BOSS_TRACKS:
			read_ace_ahead(MusicRows.resolve(_boss_entry(boss))["ace_manifest"])
	if not stages.is_last(stage):
		# The next stage's remix or modifier tune when it has one, as _ace_stage picks.
		var tune := level_tune(stage + 1, true)
		read_ace_ahead(MusicRows.resolve(tune)["ace_manifest"] if tune != "" else _music_row(stage + 1)["ace_manifest"])


# The boss's later phase packs, read as the fight opens (Brindle's anthem: heavy, then heavier).
func _read_ahead_phases(boss: String) -> void:
	var heavy := PhaseMusic.track_for_phase(boss, 2, pack_available)
	if heavy != "":
		read_ace_ahead(MusicRows.resolve(heavy)["ace_manifest"])
	var final_track := String(PhaseMusic.final_plan(boss, pack_available)["track"])
	if final_track != "":
		read_ace_ahead(MusicRows.resolve(final_track)["ace_manifest"])


# Ends finished read-aheads; wait names one the band needs now, which it waits for.
func _settle_ace_ahead(wait := "") -> void:
	for manifest in _ace_ahead.keys():
		var task: int = _ace_ahead[manifest]
		if manifest == wait or WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
			_ace_ahead.erase(manifest)


# Built in a static function so the lambda holds no self: a task bound to this node locks
# it for the whole load, and freeing it then fails ("Object is locked") and corrupts the heap.
static func _ace_loader(manifest: String, slot: Array) -> Callable:
	return func(): slot.append(AceSequencer.new(manifest))


func _notification(what: int) -> void:
	# A node freed outside the tree (the tests) still waits for its stems to finish loading.
	if what == NOTIFICATION_PREDELETE:
		if _ace_task >= 0:
			WorkerThreadPool.wait_for_task_completion(_ace_task)
			_ace_task = -1
		for task in _ace_ahead.values():
			WorkerThreadPool.wait_for_task_completion(task)
		_ace_ahead.clear()


# Blocks until stage 1's whole band is baked, as a player's time on the title allows for.
# Bots call it; the headless game never starts the worker.
func bake_opening_now() -> void:
	bake_now()
	_finish_opening()
	MusicEngine.prepare_opening()


# A live run that starts before stage 1's band is baked waits for it, as on a loading frame.
func _ready_for_run() -> void:
	if not live_output:
		return
	if not sound_ready:
		bake_now()
	_finish_opening()


static func _finish_opening() -> void:
	if _opening_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_opening_task)
		_opening_task = -1


# The rest of stage 1's band bakes behind the title, and the other themes and the bosses
# behind stage 1. Only a game with a sound device starts them (_on_ready): headless runs render
# on demand instead, so a test never waits on the worker at quit; bots call bake_opening_now.
static func _start_band_bakes() -> void:
	if _opening_task < 0:
		_opening_task = WorkerThreadPool.add_task(MusicEngine.prepare_opening, false, "presentation opening band bake")
	if _rest_task < 0:
		_rest_task = WorkerThreadPool.add_task(MusicEngine.prepare_rest, true, "presentation band bake")


# Blocks until the bank is baked; the tests call it, the game never needs to.
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
	# Stop every player and drop the playbacks, or the polyphonic ones outlive the tree.
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
	_sfx = null
	_voice_db.clear()
	_roomed.clear()
	_ui = null
	_music_pb = null
	_stinger_pb = null


# Leaving the tree lets go of every worker this node started, and abandons the bakes still
# running instead of waiting them out: the band bake behind the title is about ten seconds of
# work. The cancel flag is up across the bank, opening and band bakes. A bake checks it between
# notes, and one still queued returns as it starts. The caches keep what landed, and a note
# asked for later renders on demand.
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
	# The stems and the warmed stingers are short and cannot be abandoned part way.
	if _ace_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_ace_task)
		_ace_task = -1
	MusicEngine.settle_stingers()
	if OS.is_stdout_verbose():
		print("AUDIO_SETTLE ms=%d" % (Time.get_ticks_msec() - started))


func _on_ready() -> void:
	if sound_ready:
		return
	sound_ready = true
	if live_output:
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


# The rings start with their first block rendered: started empty, the driver's first pull
# (8 mixes in the AppImage dry run) lands while that block renders, and the title's first ACE
# pump reads those skips as a dry ring. A generator's ring holds its buffer length rounded
# up to a power of two, less one frame; a block that does not fit is never pushed.
func _start_rings() -> void:
	_render_music(nearest_po2(int(Harmony.RATE * GEN_BUFFER)) - 1, ace != null and ace.active())
	_music_player.play()
	_stinger_player.play()
	_music_pb = _music_player.get_stream_playback()
	_stinger_pb = _stinger_player.get_stream_playback()
	_ring_capacity = _music_pb.get_frames_available()
	if not (_music_pb.push_buffer(out_music) and _stinger_pb.push_buffer(engine.out_stinger)):
		push_warning("Music: the first block (%d frames) did not fit the %d-frame ring" % [out_music.size(), _ring_capacity])


# --- Buses and players --------------------------------------------------------------

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


# The state snapshot and the telegraph focus, glided per bus (mix_rows.gd). _mix_db is each
# bus's live offset; _live_sfx counts the effect voices sounding, for the crowd rule.
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


# Room for the Warden form's drop (tuning drop_room, mix_rows.gd DROP_ROOM): the band that
# booked the drop and the transport span its offsets hold for. A new band (a pack change)
# ends it.
var _drop_room := []


func _make_drop_room(at: int) -> void:
	var tuning = ctx.get("tuning") if ctx != null else null
	var name: String = tuning.option(Tuning.DROP_ROOM_KEY) if tuning != null else "off"
	if not MixRows.DROP_ROOM.has(name):
		_drop_room = []
		return
	var from := at - int(MixRows.DROP_ROOM_LEAD_S * AceSequencer.RATE)
	_drop_room = [ace, from, at + MixRows.DROP_ROOM_BARS * ace.grid_bar, MixRows.DROP_ROOM[name]]


func _drop_room_now() -> Dictionary:
	if _drop_room.is_empty():
		return {}
	if _drop_room[0] != ace or ace == null:
		_drop_room = []
		return {}
	# Timed on the sample the player hears, not the render head (as live_key reads the key).
	var queued := 0
	if live_output and _music_pb != null:
		queued = _ring_capacity - _music_pb.get_frames_available()
	var heard: int = ace.audible_sample(queued)
	if heard >= int(_drop_room[2]):
		_drop_room = []
		return {}
	return _drop_room[3] if heard >= int(_drop_room[1]) else {}


# The effect voices sounding, counted once a frame (plus the ones started since).
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


# A warning the player must hear: a danger sound or a threat row. Rewards at priority 2 keep
# the band's own duck but do not pull the bus down.
func _is_telegraph(kind: String, sound: String) -> bool:
	return sound in DANGER_SOUNDS or EventKinds.THREAT_ROWS.has(kind)


func _focus() -> void:
	_focus_until = clock + float(MixRows.FOCUS["hold_s"])


# The world slows for a close-up and comes back (game.slow_motion): a falling sweep as it slows,
# the music and the ambience held under it as they are for a warning, and a rising sweep as the
# speed returns. A pause lifts the slow motion without a sound, and the fall sounds again when
# play resumes inside the window. A game torn down mid-window has left the tree: no sound.
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


# Move, confirm and back for every page a pad or the keys can move through (menu_sounds.gd).
func _step_menu_sounds() -> void:
	var nav := false
	for action in MenuSounds.NAV:
		nav = nav or Input.is_action_pressed(action)
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
			# A cancelled bake leaves nobody running it; the survivor starts it again.
			_start_bake()
			return
	if is_inside_tree():
		_step_menu_sounds()
	engine.pause_gain = 0.45 if get_tree().paused else 1.0
	if ace != null:
		ace.pause_gain = engine.pause_gain
	# The mix glides in real time: under slow motion the frame's delta is scaled down, and the
	# hold that marks it would arrive late by the same factor.
	_tend_mix(delta / maxf(Engine.time_scale, 0.05))
	_tend_room()
	_flush_flow()
	_tend_kill_streak()
	_warm_grid_key()
	_play_due_notes()
	_tend_tally()
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
	if _launch_armed and _landing_theme >= 0 and SimClock.msec() - _entered_ms > LANDING_FALLBACK_MS:
		_land_drop()
	_pump()
	if _overlay != null and _overlay.visible and Time.get_ticks_msec() > _overlay_until:
		_overlay.visible = false


# Renders the same frames into both streams, so the band and the stinger lane stay
# sample-locked. The synth band fills its ring; the ACE band keeps it at the POC's
# QUEUE_TARGET, so a contact reaches the speaker sooner.
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
		# No device: advance the band by the real time that passed, as a speaker would.
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
		# Skips the synth alone took are not an ACE dry-run.
		_skips_seen = _music_pb.get_skips()
		_ace_pumped_usec = 0
	else:
		var now := Time.get_ticks_usec()
		var gap := now - _ace_pumped_usec
		# The ring's skips before the band's first pump are the synth's (a bot's opening bake
		# blocks the main thread for seconds after the rings start). A skip after a long gap
		# between pumps is a one-off long frame, not the device's period: it should not cost
		# every later contact the latency of a deeper queue. Either way the emptied ring keeps
		# skipping until this pump's block is pushed, so the count settles after it.
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
		# A launch's flight answers no contact and lands on the next stage's entry frame
		# (about 120 ms on the 4080), so the ring fills whole until the landing.
		var target := _ring_capacity if _launch_armed else queue_target
		frames = mini(ace.frames_to_pump(_music_pb, _ring_capacity, target), _stinger_pb.get_frames_available())
	var wanted := mini(frames, 8192)
	frames = _park_render_limit(wanted)
	if frames > 0:
		_render_music(frames, ace_live)
		_music_pb.push_buffer(out_music)
		_stinger_pb.push_buffer(engine.out_stinger)
	# A clamp that leaves most of the queue in the ring cannot be what empties it.
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
	# The committed approach is the landmark's reach (sample_run_parameters): its tune in and out.
	if values.has("approach"):
		landmark_moment(_landmark_id(), float(values["approach"]))


# One band at a time, handed over without a hole: the synth band plays until the ACE
# band's first fade-in, fades out over STOP_RAMP from there, and stays muted while the
# ACE band plays (through its drop gaps too). When the ACE band stops, the synth band
# comes back at once and the ACE fade tail is summed over it.
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


# The ACE frames with the synth band summed in at its hand-over gain (1 before the fade
# starts, 0 after it ends). from is the transport sample of the block's first frame.
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


# The synth band comes back from mute: its ramp starts at from (the next transport sample
# by default) and ends UNMUTE_RAMP frames later.
func _unmute_band(from := -1) -> void:
	_band_fade_start = -1
	if not engine.band_muted:
		return
	engine.band_muted = false
	_unmute_at = from if from >= 0 else engine.clock


# The landing's beat is coming inside this block: the synth band un-mutes so its ramp ends
# on the beat and the drop's first hit sounds whole.
func _unmute_for_handover(frames: int) -> void:
	if _handover_at >= 0 and engine.band_muted and engine.clock + frames > _handover_at - UNMUTE_RAMP:
		_unmute_band(_handover_at - UNMUTE_RAMP)


# The synth band's block, scaled by the un-mute ramp; from is the transport sample of its
# first frame.
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


# The device takes the ring a mix buffer at a time, so a gap short of the whole queue can
# already empty it. Godot's buffer (512-1024 frames) is under half the queue: a skip after a
# shorter gap is a period the queue does not cover, and deepens it; after a longer one, the frame's.
func _gap_is_stall(gap_usec: int) -> bool:
	return gap_usec * Harmony.RATE * 2 > queue_target * 1000000


func _deepen_on_skip() -> void:
	_deepen_for(_music_pb.get_skips())


# A skip the ring took since the last look deepens the queue by a step, up to the ring.
func _deepen_for(skips: int) -> void:
	if skips <= _skips_seen:
		return
	var took := skips - _skips_seen
	_skips_seen = skips
	if queue_target + 1024 <= _ring_capacity - 1024:
		queue_target += 1024
		print("ACE music: the ring ran dry (%d skips) at frame %d, stage %d, %d ms since the last pump; queue target now %d frames" % [took, Engine.get_process_frames(), _stage_now, _ace_gap_usec / 1000, queue_target])


# Skips a long gap between pumps took are logged as the frame's, and the queue stays put.
func _note_stall(gap_usec: int) -> void:
	var skips := _music_pb.get_skips()
	if skips > _skips_seen:
		print("ACE music: a %d ms gap between pumps outlasted the queue (%d skips) at frame %d, stage %d%s" % [gap_usec / 1000, skips - _skips_seen, Engine.get_process_frames(), _stage_now, ", launch armed" if _launch_armed else ""])
	_skips_seen = skips


# A park cue's hold leaves the booked sample unrendered until physics lands it, so a landing
# later than the queue empties the ring: that is the hold's, not the device's, and logged as such.
func _note_park_hold(gap_usec: int) -> void:
	var skips := _music_pb.get_skips()
	if skips > _skips_seen:
		print("ACE music: a park cue's hold emptied the ring (%d skips) at frame %d, stage %d, %d ms since the last pump" % [skips - _skips_seen, Engine.get_process_frames(), _stage_now, gap_usec / 1000])
	_skips_seen = skips


# The ACE transport runs with the engine's even while silent, so both count the same samples.
func _ace_render(frames: int, live: bool) -> PackedVector2Array:
	if ace == null:
		return PackedVector2Array()
	if live:
		return ace.render(frames).duplicate()
	ace.advance(frames)
	return PackedVector2Array()


func ace_wanted() -> bool:
	# Some tests set the director up on a stand-in context with no tuning.
	var tuning = ctx.get("tuning")
	return tuning != null and tuning.option(Tuning.MUSIC_KEY) == "ace"


# Loads the ACE package on first need. A missing manifest or stem is one warning naming
# the file, and the synth plays on.
func ace_ready() -> bool:
	if ace_manifest == "":
		return false
	if ace != null and _ace_from == ace_manifest:
		return true
	if _ace_failed or not ace_wanted():
		return false
	var loaded: AceSequencer = null
	if _ace_task >= 0:
		# Loading started at setup; wait only for what is left of it.
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
		ace.stop(AceSequencer.STOP_RAMP)
		loaded.fading.append_array(ace.fading)
	ace = loaded
	_ace_from = ace_manifest
	# A package swapped in from inside engine.render (a commit's landmark tune) has not
	# rendered this block yet: it starts where the block did, or it runs ahead of the transport.
	ace.clock = _render_from if _render_from >= 0 else engine.clock
	ace.set_breath(breath())
	ace.ultimate_lift = _ult_lift
	_prime_band_parameters()
	return true


# The stems follow the band engine's fight layering: in a Warden, miniboss or boss fight the
# melody is held at the engine's section floor (warden 0.55 to 1.0, miniboss 0.8, brindle 0.8
# to 1.0), whatever the threat feed says. The Warden's open window is the held breath: the
# engine's OPEN_GAINS drop every melodic layer there (outside a cadence), so the stems get no
# floor either.
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


# Resolve both choices through the same zone row, preserving legacy music overrides.
func _music_row(stage: int) -> Dictionary:
	var stages = _music_stages()
	return MusicRows.resolve(stages.of(stage), "", stages)


func _stage_theme(stage: int) -> int:
	var stages = _music_stages()
	return MusicRows.stage_theme(stages.of(stage), stages)


# The boss track for the world being fought: its row's music, or Brindle's when the
# engine has no such track yet.
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


# The stage's row names the ACE package to play, or "" for the synth band.
func _ace_package_for(stage: int) -> String:
	var manifest: String = _music_row(stage)["ace_manifest"]
	if manifest != "":
		return manifest.get_base_dir().get_file()
	var row: Dictionary = _music_stages().of(stage)
	var package := str(row.get("music", {}).get("ace", ""))
	if package != "":
		_warn_music_once("ace_" + package, "music: ACE package '%s' is not loadable; playing the synth band" % package)
	return ""


# A stage whose row names an ACE package starts the ACE band at transport sample at; any
# other stage hands back to the synth, except that the band held through a launch's flight waits for the landing.
func _ace_stage(stage: int, at: int, fight := false) -> void:
	if radio_hold != "":
		return
	# The live moment's tune, else the stage's remix or modifier tune, else the stage's own pack.
	# A Warden's fight takes the band from every moment.
	_moment_playing = "" if fight else TuneMoments.top(_moments, tune_available)
	var tune := level_tune(stage, fight)
	var manifest: String = MusicRows.resolve(tune)["ace_manifest"] if tune != "" else _music_row(stage)["ace_manifest"]
	_select_ace_manifest(manifest)
	# Preserve the launch riser and landing drop before the destination's recorded bed.
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


# --- Moss's jukebox ------------------------------------------------------------------
# What the band is playing, in the words TuneRows.key_of reads.
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


# A tune the profile already holds: the ear never reports it again.
func knows_tune(id: String) -> void:
	_ear.knows(id)


# Puts a found record on: the band cuts to its track now (a needle drop, not a phrase), at
# the dial's energy. The ACE band plays the recorded take when its package is on disk; the
# synth plays it otherwise. False when the id names no row or the band is not baked yet.
# live keeps the run's parameters (speed, combo, threat) driving the band, for the radio; a row
# stands in for the id's own (a radio take played over its parent record's source).
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
	# A place-and-moment pack plays its own recording, else its zone's.
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


# The dial: 0 idle, 1 cruise, 2 full tilt. Heard from the next parameter sample.
func set_spin_detent(detent: int) -> void:
	spin_detent = clampi(detent, 0, SPIN_ENERGY.size() - 1)


# Lifts the needle: the title theme comes back on the next beat.
func stop_spin() -> void:
	if spinning == "":
		return
	_release_spin()
	engine.cancel_pending()
	var at := engine.next_beat()
	engine.schedule_mode(at, MusicEngine.IDLE)
	engine.menu_theme("title", true, at)
	_menu_home(at)


# The game takes the music back (a run starts while a record plays): the parameters return
# to the run's source and the flow's own cues pick the track.
func _release_spin() -> void:
	if spinning == "":
		return
	spinning = ""
	engine.set_parameter_source(_spin_restore)
	_spin_restore = Callable()
	if ace_playing():
		ace.set_bay(false)


# --- The pilot radio ------------------------------------------------------------------
# radio_deck.gd decides; these carry it out. A radio track is a needle drop on the band (the
# jukebox's spin) with the run's own parameters still driving it, so drums follow speed and the
# lead follows the combo, and every hit and musical answer lands on the radio track's beat.

# Puts a track on: id is what the radio names (a take or a jukebox record), record the jukebox
# record whose source the band plays. A take with its own recorded pack plays that pack over
# its record's source; until then its record stands in. False when the band cannot play it.
func radio_play(id: String, record: String, pinned := false) -> bool:
	var parent := TuneRows.row(record)
	if parent.is_empty() or not sound_ready:
		return false
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
	_radio_args = [id, record, pinned]
	_radio_respin_due = false
	cue_log.append(["radio", id, "needle", engine.clock, 1.0])
	return true


func _radio_respin() -> void:
	if _radio_args.size() == 3:
		radio_play(_radio_args[0], _radio_args[1], _radio_args[2])


# The score takes the air back on the next beat: the stage's band (or the Warden's, or the
# miniboss's darkened level) with the live moment's tune, as if the radio had never played.
func radio_release() -> void:
	if radio_hold == "":
		return
	_radio_drop("")
	if not sound_ready or _stage_now <= 0 or ctx == null or ctx.get("flow") == null or not ctx.flow.in_play():
		return
	engine.cancel_pending()
	if is_instance_valid(_miniboss):
		engine.force_track("level", _stage_theme(_stage_now))
		engine.begin_miniboss()
	else:
		engine.force_track("warden" if _warden_engaged and ctx.flow.get("sealed") else "level", _stage_theme(_stage_now))
	_moment_playing = ""
	_ace_return(_stage_now, engine.next_bar())
	cue_log.append(["radio", "score", "bar", engine.next_bar(), 1.0])


# The hold ends with no music of its own: the cue that ended it (a boss, a death, the run's
# end) plays next. reason "" is the deck's own release.
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


# The record the score plays, or is about to play, here: the live moment's tune, else the
# stage's roam (the Warden's once it is engaged), else "" outside a stage.
func score_tune_wanted() -> String:
	var top := TuneMoments.top(_moments, tune_available)
	if top != "":
		return top
	if _stage_now <= 0 or ctx == null or ctx.get("run") == null:
		return ""
	var zone := MusicRows.zone_id(_stage_now, _music_stages())
	return ("warden-" if _warden_engaged else "roam-") + zone


# A place or moment tune is live (a landmark in reach, an event, a miniboss, the bay).
func moment_live() -> bool:
	return TuneMoments.top(_moments, tune_available) != ""


# A record the ear has not reported and the profile does not hold.
func tune_unheard(id: String) -> bool:
	return id != "" and not TuneRows.row(id).is_empty() and not _ear.heard(id)


# The title opening (title_stage.gd) names its theme as its intro starts: the title plays that
# theme's take from its first bar. A theme with no pack on disk keeps the plain title.
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


# The title row that plays now: the opening's theme, else title A (the keepers' theme, which
# the rotation opens on), else the plain title.
func title_now() -> String:
	if title_row == "title" and title_available.call("title-a"):
		return "title-a"
	return title_row


func summary_row(won: bool) -> String:
	if won and not title_available.call(WON_SUMMARY_ROW) and title_available.call("title-c"):
		return "title-c"
	return "summary"


# screens.gd says when the camp page opens and closes: the camp take plays while it is open,
# and the title theme comes back when it closes. A camp with no pack on disk keeps the title.
func camp_theme(open: bool) -> void:
	if camp_open == open:
		return
	camp_open = open
	if sound_ready and spinning == "" and radio_hold == "":
		_menu_home(engine.next_bar())


# The music of the title screen at transport sample at: the camp's while the camp is open,
# else the title row.
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


# The stage's recorded band comes back at `at` (after a radio hold, an ultimate's drop, a
# landing). Inside a sealed Warden fight it goes straight to the fight's sections: the shelf
# (the world's roaming take) never plays inside an arena.
func _ace_return(stage: int, at: int) -> void:
	_ace_stage(stage, at, _warden_engaged and bool(ctx.flow.get("sealed")))


# The music has moved on from the stage an ultimate took the recorded band from (a launch,
# the Warden's break): the band is not booked back, and one already booked is dropped. A
# launch's own arrival is booked after this, at the stage it lands in.
func _ult_band_stays_off() -> void:
	_ult_took_band = false
	_ace_arrival_stage = 0
	_ace_arrival_at = -1


# The ACE band stops and the synth band plays again from this moment, so a note it starts
# now (the death boom, a restart's first beat) is heard over the ACE fade tail.
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


# The recorded band plays to transport sample at and stops there, and the synth band comes back
# on that sample: a death ends on the beat its boom lands on, not mid-beat.
func _ace_end_at(at: int) -> void:
	if not ace_playing():
		_ace_end()
		return
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	_ace_flight = false
	ace.stop_at(at, AceSequencer.STOP_RAMP)
	_handover_at = at


func ace_playing() -> bool:
	return ace != null and ace.mode != "off"


# The recorded band's kill cadence has entered: it answers the Warden break, so the release
# stops reaching the recorded band (ruling bt), and a tune moment, a find or a pack swap that
# restarts that band on the shelf afterwards starts it with its lead. The engine keeps its own
# release to the next stage: the landmark hum and the synth band stay stripped as before. A
# band that plays no cadence (a flat pack) keeps the release to the next stage too.
func _answer_release() -> void:
	if _release_answered and not engine.parameters_released():
		_release_answered = false
	if not ace.lead_returned:
		return
	_release_answered = engine.parameters_released()
	ace.clear_release()
	ace.lead_returned = false


# The synth takes the stage stingers back once the ACE band has stopped.
func _release_grid() -> void:
	if engine.grid != null and not ace_playing():
		engine.grid = null


func breath() -> String:
	return ctx.tuning.option(Tuning.BREATH_KEY) if ctx.tuning != null else "hard"


# The pause menu's Breath row and the title's B: the style lands on the open sounding now.
func set_breath(style: String) -> void:
	if ctx.tuning != null:
		ctx.tuning.set_option(Tuning.BREATH_KEY, style)
	if ace != null:
		ace.set_breath(breath())


# The key a keyed cue sounds in: the ACE key at the audible sample, or the band's key.
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


# Room for a cue the player must hear (MixRows.MAKE_ROOM): while it holds, every other effect
# voice but a warning sits room_db under the level it started at. _voice_db keeps each SFX
# voice's [sound, start level] for the way back; _roomed holds the ones pushed down. The hold
# runs on the wall clock, so slow motion does not stretch it.
var _voice_db := {}
var _roomed := {}
var _room_for := ""
var _room_until_ms := -1


func _make_room(kind: String, sound: String) -> void:
	var hold := float(MixRows.MAKE_ROOM[sound]["hold_s"])
	# A narrow room (an "only" row) never cuts a held room short; a hit's room wins over it.
	if MixRows.MAKE_ROOM[sound].has("only") and Time.get_ticks_msec() < _room_until_ms and _room_for != sound:
		return
	# A room without "only" takes over: the voices an "only" room ducked go back to their level.
	if not MixRows.MAKE_ROOM[sound].has("only"):
		_restore_roomed()
	_room_for = sound
	_room_until_ms = Time.get_ticks_msec() + int(hold * 1000.0)
	# [kind, sound, "room", clock, hold, dB, the row's "only" list, empty when it names none]: tools/mix/mixsim.py reads it.
	cue_log.append([kind, sound, "room", engine.clock, hold, float(MixRows.MAKE_ROOM[sound]["db"]), MixRows.MAKE_ROOM[sound].get("only", [])])
	if _sfx == null:
		return
	for id in _voice_db:
		var row: Array = _voice_db[id]
		var room := _room_offset(row[0])
		if room != 0.0 and not _roomed.has(id) and _sfx.is_stream_playing(id):
			_roomed[id] = row[1]
			_sfx.set_stream_volume(id, float(row[1]) + room)
			_log_gain(kind, row[0], "duck", row[2], room)


# What a voice of sound takes now: the held room's offset, or 0. A voice that has not started
# yet (sounding false) takes none from a row that names its sounds.
func _room_offset(sound: String, sounding := true) -> float:
	if Time.get_ticks_msec() >= _room_until_ms:
		return 0.0
	return MixRows.room_db(_room_for, sound, sound in DANGER_SOUNDS, sounding)


# One row per voice gain the room applies, so mixsim.py replays what the game did and holds no copy
# of the rule. [kind, sound, "duck" or "restore", clock now, the voice's start clock, dB offset]: the
# voice is the one whose "now" row has that sound and start clock; a duck row sets its offset from the
# clock now, a restore row sets it back to 0. The start clock is the voice's key (the log has no voice ids).
func _log_gain(kind: String, sound: String, how: String, start: int, db: float) -> void:
	cue_log.append([kind, sound, how, engine.clock, start, db])


# The voices a room pushed down go back to their own level.
func _restore_roomed() -> void:
	if _sfx != null:
		for id in _roomed:
			if _sfx.is_stream_playing(id):
				_sfx.set_stream_volume(id, float(_roomed[id]))
				var voice: Array = _voice_db.get(id, ["", 0.0, -1])
				_log_gain(_room_for, voice[0], "restore", voice[2], 0.0)
	_roomed.clear()


# The room ends: the voices it pushed down come back to their own level, and the record of
# finished voices is cleared.
func _tend_room() -> void:
	if Time.get_ticks_msec() < _room_until_ms or _sfx == null:
		return
	_restore_roomed()
	if _voice_db.size() > 64:
		for id in _voice_db.keys():
			if not _sfx.is_stream_playing(id):
				_voice_db.erase(id)


# --- Playing a cue ------------------------------------------------------------------

# Plays a cue now. Returns false if it was gated by the voice limit or the gap. With no
# override the kind's row decides, resolved for the run's class.
func play(kind: String, db := 0.0, pitch := 1.0, bus := "SFX", sound_override := "", priority_override := -1) -> bool:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind, cue_context())
	if not _admit(kind, sound, pitch):
		return false
	# A tiered key plays its tier's file, picked by the rung the caller sent as its pitch,
	# before the live key moves that pitch.
	# The cue log keeps the pitch the caller asked for, so the ladder stays readable there.
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


# World 1's story stings (spillway_story.gd): one designed one-shot per story row, played now
# when the row starts, from assets/audio/stingers/1_1/<name>.wav. The bus fact of the same moment
# (the generic stage, world, rescue or unseal sound) is not dropped, because its beat also starts
# the stage music; it is ducked STORY_DUCK_DB for STORY_HOLD_MS so the sting is the moment's voice.
const STORY_KIND := "story_sting"
const STORY_DUCKED := ["run_started", "world_entered", "stage_entered", "rescue_completed", "beacon_unsealed"]
const STORY_QUESTS := ["rivet"]
const STORY_DUCK_DB := -14.0
const STORY_HOLD_MS := 2500
var _story_until_ms := 0


func story_sting(name: String) -> bool:
	_story_until_ms = Time.get_ticks_msec() + STORY_HOLD_MS
	return play(STORY_KIND, 0.0, 1.0, "SFX", SfxBank.stinger_id("1_1", name))


# The duck the generic sound of kind takes while a story sting holds its moment.
func story_duck_db(kind: String) -> float:
	if kind in STORY_DUCKED and Time.get_ticks_msec() < _story_until_ms:
		return STORY_DUCK_DB
	return 0.0


# SPIL-9's chirp (SR7): it reads the cue the body shows from the same Companion.CUES row, so
# animation, chirp and motif cannot drift apart, and sounds a cue at most once per
# CHIRP_COOLDOWN s (a start value; the lab tunes it). now is seconds; -1 reads the clock.
# chirp_log rows are [cue, kind, motif sound, now, fired]. True when it sounded.
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
	# A called assist plays its own sting on the next beat, grown to the heft class; a move
	# without one keeps the row's chirp.
	var sting := SfxBank.assist_sting_id(cue.trim_prefix("assist_"), _heft_class, _motif) if cue.begins_with("assist_") else ""
	if sting != "":
		on_beat(kind, 0.0, false, 1, sting)
		return true
	play(kind, 0.0, 1.0, "UI")
	return true


# Moss says a line (SOUND-STORY section 8): one babble blip per letter, baked in the
# live key once per line and beat. beat is SfxBank's 1 to 6 for the conversation loop,
# BABBLE_LEVEL for a bark or BABBLE_RELENT for the sigh. SFX bus at the babble trim and
# no duck: the lounge already sits about 4 LU under it (DESIGN-NOTES, v2 W5 note 8).
func speak(kind: String, text: String, beat: int) -> bool:
	if text == "" or not _admit(kind, "babble", 1.0):
		return false
	var live := live_key()
	var key := "%d|%d|%s" % [beat, live, text]
	if not _babble.has(key):
		_babble[key] = Synth.to_wav(SfxBank.babble(text, beat, live))
	_start(kind, "babble", _babble[key], SfxBank.trim_db("babble"), 1.0, "SFX")
	return true


# A caller's line on the call card (SOUND-STORY section 8, "Who talks on what"): the caller's
# chirp, then babble in their own voice. It is made on a worker and sounded CALL_LEAD_S
# later, so no frame waits for it, and a caller on the grid starts on the band's sixteenth.
# The band dips under the voice by about what the lounge gives Moss at his bench. Returns
# how long the voice lasts from now, for the card's hold; 0.0 when it stays silent, as it
# does while an earlier caller is still talking.
func call_in(kind: String, speaker: String, text: String) -> float:
	if text == "" or clock < float(_gates.get("call_in", -1000.0)) or not _admit(kind, "babble", 1.0):
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
	cue_log.append([kind, "babble", "call", at, 1.0])
	return seconds


# The card that showed a caller closed before the voice was done (a fight went live, the run
# ended): the caller stops, booked or sounding, the band comes back up and the next caller
# may talk. Nothing happens when nobody is talking. A shorter dip another cue asked for in
# that moment is freed with it.
func call_end() -> void:
	if _calling == "" or clock >= float(_gates.get("call_in", -1000.0)):
		return
	engine.cancel_stinger(_calling)
	engine.free_duck()
	if ace_playing():
		ace.free_duck()
	_gates["call_in"] = clock
	_calling = ""
	cue_log.append(["call_end", "babble", "now", engine.clock, 1.0])


# What the run's rows resolve by: the player's class motif.
func cue_context() -> Dictionary:
	return {"motif": _motif}


# False (and logged) while the bank bakes, for a row with no sound, or inside the cue's gap.
func _admit(kind: String, sound: String, pitch: float) -> bool:
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	var now := Time.get_ticks_msec()
	if now - int(_last_start.get(sound, -100000)) < int(MIN_GAP_MS.get(sound, 0)):
		cue_log.append([kind, sound, "skip", -1, pitch])
		return false
	_last_start[sound] = now
	return true


func _start(kind: String, sound: String, stream: AudioStream, volume: float, pitch: float, bus: String) -> void:
	var playback := _ui if bus == "UI" else _sfx
	if playback != null:
		var live: Array = _voices.get(sound, [])
		live = live.filter(func(id: int): return playback.is_stream_playing(id))
		if live.size() >= int(VOICE_LIMIT.get(sound, MixRows.VOICE_DEFAULT)):
			playback.stop_stream(live.pop_front())
		var room := _room_offset(sound, false) if playback == _sfx else 0.0
		var id := playback.play_stream(stream, 0.0, volume + room, pitch, AudioServer.PLAYBACK_TYPE_DEFAULT, bus)
		if id != AudioStreamPlaybackPolyphonic.INVALID_ID:
			live.append(id)
			if playback == _sfx:
				_voice_db[id] = [sound, volume, engine.clock]
				if room != 0.0:
					_roomed[id] = volume
					_log_gain(kind, sound, "duck", engine.clock, room)
		_voices[sound] = live
	last_play_frame = Engine.get_process_frames()
	cue_log.append([kind, sound, "now", engine.clock, pitch if _logged_pitch < 0.0 else _logged_pitch, volume])


# A start of a sound played outside this director on bus (the world's water and steam,
# world_fx_sound.gd), logged like _start's rows so the mix tools hear it. The mix tools give every
# effect one gain, so the row carries the voice's level plus its bus against the effects bus now.
func note_cue(kind: String, sound: String, volume: float, bus := "SFX") -> void:
	if engine == null:
		return
	var against := float(BUSES.get(bus, 0.0)) + float(mix_db.get(bus, 0.0)) - float(BUSES["SFX"]) - float(mix_db.get("SFX", 0.0))
	cue_log.append([kind, sound, "now", engine.clock, 1.0, volume + against])


# Cuts every voice of a sound on the SFX bus at once: a ceremony skipped mid-build drops
# its drum roll so the burst lands clean.
func stop(sound: String) -> void:
	if _sfx != null:
		for id in _voices.get(sound, []):
			if _sfx.is_stream_playing(id):
				_sfx.stop_stream(id)
	_voices.erase(sound)


# v2 W2 threat grammar. A committed threat warns on the game frame it is declared, never
# on the beat (SOUND-STORY.md section 7): its type's row sound, then the owner's voice
# and the mechanic tag when the threat carries them. Only hostile threats join the
# "threat" group, so the player's own rings and harmless fields stay silent. The check
# runs at the end of the frame, after the committing code has set the layers.
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


# The release half of a threat's grammar on the frame it goes live: the held hum stops and
# the lane's tear plays, because the tear is fire time.
func _release_threat(node: Node, kind: String) -> void:
	_end_hum(node.get_instance_id())
	if not is_instance_valid(node) or not node.is_inside_tree():
		return
	var row: Dictionary = EventKinds.THREAT_ROWS[kind]
	play(kind, PRIORITY_DB[int(row["priority"])] - PRIORITY_DB[Rows.priority(kind)] - _threat_distance_db(node), 1.0, "SFX", THREAT_RELEASE[kind])


# Stops a lane's held hum: at its tear, or when the lane leaves before it goes live.
func _end_hum(node_id: int) -> void:
	if not lane_hums.has(node_id):
		return
	var id: int = lane_hums[node_id]
	lane_hums.erase(node_id)
	if id >= 0 and _sfx != null and _sfx.is_stream_playing(id):
		_sfx.stop_stream(id)
	cue_log.append(["threat_lane", EventKinds.THREAT_ROWS["threat_lane"]["sound"], "stop", engine.clock, 1.0])


# Cues here are not positional, so a far threat is only quieter: full within 20 m,
# 9 dB down from 60 m.
func _threat_distance_db(node: Node) -> float:
	if ctx == null or ctx.player == null or not node.has_method("threat_at"):
		return 0.0
	var gap: float = (node.threat_at() as Vector3).distance_to(ctx.player.shown_position())
	return 9.0 * clampf((gap - 20.0) / 40.0, 0.0, 1.0)


# Plays a cue on the next beat through the band. lane queues it behind flow stingers.
func on_beat(kind: String, db := 0.0, lane := false, repeats := 1, sound_override := "") -> int:
	var sound: String = sound_override if sound_override != "" else Rows.sound(kind, cue_context())
	if not sound_ready or sound == "":
		cue_log.append([kind, sound, "skip", -1, 1.0])
		return -1
	var start := engine.schedule_stinger(sound, db + story_duck_db(kind), lane, repeats)
	var beats: int = SfxBank.STINGER_BEATS.get(sound, 1)
	_duck(0.6, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	if sound in DANGER_SOUNDS:
		engine.duck_bass(0.3, float(start - engine.clock + beats * Harmony.BEAT) / Harmony.RATE)
	if _is_telegraph(kind, sound):
		_focus_until = maxf(_focus_until, clock + float(start - engine.clock) / Harmony.RATE + float(MixRows.FOCUS["hold_s"]))
	cue_log.append([kind, sound, "beat", start, 1.0])
	return start


# --- Facts --------------------------------------------------------------------------

func _connect_all(events) -> void:
	_wire_cannon(events)
	events.run_started.connect(func(class_id: String):
		_ready_for_run()
		_set_overtime = false
		_heft_class = 1
		_hull_seen = 0.0
		_fired_this_run.clear()
		_line_was = ""
		_motif = motif_of(class_id)
		engine.set_class_motif(_motif)
		engine.set_fleet_ticks(0)
		new_run_tunes()
		_flow_queue.append(["run"]))
	events.warden_engaged.connect(func(_stage: int): warden_took_band())
	events.activity_done.connect(func(id: String, _at: Vector3): end_moment("event", id))
	events.synergy_discovered.connect(func(id: String, _category: String, _first: bool): tune_found(id))
	events.flow_changed.connect(_on_flow_changed)
	events.world_entered.connect(func(world: int): _flow_queue.append(["world", world]))
	events.stage_entered.connect(_on_stage_entered)
	events.stage_cleared.connect(func(stage: int): _flow_queue.append(["clear", stage]))
	events.run_ended.connect(func(won: bool):
		engine.set_reactor_pedal(false)
		_line_was = ""
		_stop_hum()
		_flow_queue.append(["end", won]))
	events.beacon_charge_changed.connect(_on_beacon)
	events.scrap_collected.connect(_on_scrap)
	events.cogs_collected.connect(_on_cogs)
	events.achievement_earned.connect(func(_id: String): play("achievement_earned"))
	# Rivet's cage has a story sting (spillway_story, a later listener than this one), so its duck
	# window opens here, before the generic fanfare plays, rather than when the sting starts.
	events.rescue_completed.connect(func(quest: String):
		if quest in STORY_QUESTS:
			_story_until_ms = Time.get_ticks_msec() + STORY_HOLD_MS
		play("rescue_completed"))
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


# The demo-spec signals the spine is adding. Each one is connected only if the bus
# has it, and this can be called again once it does (tests add them locally).
func wire_optional() -> void:
	var events = ctx.events
	_wire_armor()
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
	# The reactor relic is the only ancient that colours the band: a tritone pedal
	# under the sub while its vent charges (DESIGN-V2 section 11 audio rulings).
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
	# Moss's lounge is a layer mask over the stage theme, entered and left with the
	# bay (SOUND-STORY.md section 8).
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
	# v2 W6 world: one row per world_fact kind (event_kinds.gd WORLD_ROWS); a kind with
	# no row plays nothing, since play() already skips an empty sound override.
	_listen_optional(events, "world_fact", func(kind: String, _at: Vector3):
		# A world row's own priority, not the bare world_fact kind's 0: the Overtime ring, the sluice and
		# the Called Shot results were 6 dB under a pickup and never dipped the band (sound-gaps 12 Nov).
		var row := EventKinds.world_row(kind)
		play("world_fact", 0.0, 1.0, "SFX", Rows.heard(row, cue_context()), int(row.get("priority", 0)))
		_set_world_fact(kind)
		if kind == "bay_jukebox":
			jukebox_flipped()
		elif kind == "fabricator_used":
			fabricator_used())
	# The shell's air factor moved (build.gd shell_air_changed): the row's spring, up a fifth on the
	# rise and down a fourth on the return, so the two read apart without looking.
	if ctx.get("build") != null and ctx.build.has_signal("shell_air_changed") and not ctx.build.shell_air_changed.is_connected(_on_shell_air):
		ctx.build.shell_air_changed.connect(_on_shell_air)
	# The hot-wired Fit / Recycle offer is build-local (no bus signal, no event row): one brass
	# pair per offer, played by name.
	# v3 interact: each fact in its family's sound register (world/interactables.gd), so
	# a bet's drum roll, clunk and crack and an altar's anvil and riser come from the row.
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
		if ace_playing():
			ace.commit_warden()
		elif _ace_arrival_stage > 0 and _ace_arrival_at >= 0:
			# A drop still holds the recorded band (an ultimate's, a landing's): the Warden's
			# entrance takes it back now, not when the drops are over.
			var stage := _ace_arrival_stage
			_ace_arrival_stage = 0
			_ace_arrival_at = -1
			_ace_stage(stage, engine.next_bar(), true))
	_listen_optional(events, "boss_arena_entered", func():
		_read_ahead_phases(_boss_track())
		_boss_phase = 1
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
	# The Brindle reel (W1-61): each paid hit sheds scrap with its row's scrap tick.
	_listen_optional(events, "boss_reeled", func(_at: Vector3, _scrap: int): play("boss_reeled"))
	_listen_optional(events, "event_progress", _on_event_progress)
	# The stage's content leaves before the arena: a soft fade, and any launch build
	# resolves into the arena music instead of a landing.
	_listen_optional(events, "stage_content_cleared", func(reason: String):
		_disarm_launch()
		_event_id = ""
		_chase_lead0 = -1.0
		# Arena entry and retry are the fight's stage entry: a flume Warden's break no longer
		# strips the band, synth or ACE stems, and a Warden-break commit still queued is void.
		if reason in ["arena", "arena_retry"]:
			engine.parameters_arena_entered()
			if ace != null:
				ace.clear_release()
		if reason == "arena_retry" and sound_ready:
			# R in the arena: Brindle's music from phase 1, out of DEAD mode, with a pickup.
			engine.cancel_pending()
			engine.fill_into(engine.restart_boss(_boss_track()))
		# The stage's bonus cores stay with the stage; a restore may have moved heft.
		engine.set_overcharge(0)
		if ctx.run.has_method("heft_class"):
			_heft_class = int(ctx.run.heft_class())
			engine.set_heft_lift(_heft_class - 1)
		if reason != "arena_retry" and sound_ready and engine.mode != MusicEngine.PLAY and engine.track == _boss_track():
			engine.cancel_pending()
			engine.restart_boss(_boss_track())
		play("stage_content_cleared"))
	# v2 W9: a hold sounds the holding unit's loop, and a pack its faction's arrival (the
	# Fleet stamp, the reactor tick, the swarm lock, the Mind's quote of your motif).
	_listen_optional(events, "hold_started", func(kind: String, _at: Vector3):
		play("hold_started", 0.0, 1.0, "SFX", Rows.sound("hold_started", cue_context().merged({"hold": kind}))))
	_listen_optional(events, "pack_arrived", func(faction: String, _at: Vector3, _kinds: Array):
		play("pack_arrived", 0.0, 1.0, "SFX", Rows.sound("pack_arrived", cue_context().merged({"faction": faction}))))
	# v2 W3 characters: each class-ability fact plays its event row's sound_next once W5
	# has baked it (resolved for the run's class), else its stand-in.
	for kind in CHARACTER_KINDS + ENEMY_KINDS:
		if events.has_signal(kind) and not _character_wired.has(kind):
			_character_wired[kind] = true
			if kind == "vault_kicked":
				events.connect(kind, _on_vault_kicked)
			else:
				events.connect(kind, play.bind(kind).unbind(_argc(events, kind)))


# run_started carries the class row's id (pylon_engineer); the band and every class cue
# want its motif id (sable). A motif id passes through as itself.
static func motif_of(class_id: String) -> String:
	var def: Resource = ClassDef.by_id(class_id)
	return String(def.motif) if def != null else class_id


# Sable's vault is an octave leap: the top note climbs with exit speed and reaches the
# octave at the vault cap (SOUND-STORY section 3), so a weak kick falls short of it.
func _on_vault_kicked(_at: Vector3, speed: float) -> void:
	play("vault_kicked", 0.0, Harmony.ratio(12.0 * clampf(speed / Augments.VAULT_CAP, 0.0, 1.0)))


# Optional facts have one handler each; reuse its identity when late wiring runs again.
func _listen_optional(events: Object, signal_name: String, callable: Callable, loose := false) -> bool:
	if not events.has_signal(signal_name):
		return false
	var key := "%d:%s" % [events.get_instance_id(), signal_name]
	if not _optional_listeners.has(key):
		_optional_listeners[key] = callable
	return _listen(events, signal_name, _optional_listeners[key], loose)


# Connects once. loose drops whatever arguments the signal carries.
static func _listen(events: Object, signal_name: String, callable: Callable, loose := false) -> bool:
	if not events.has_signal(signal_name):
		return false
	var target := callable
	if loose:
		var argc := SignalWire.arg_count(events, signal_name)
		if argc > 0:
			target = callable.unbind(argc)
	# Signal identity also recognises the same lambda through an unbind wrapper.
	if events.is_connected(signal_name, target):
		return true
	if _named_listener(callable):
		for connection in events.get_signal_connection_list(signal_name):
			var connected: Callable = connection["callable"]
			if _named_listener(connected) and connected.get_object() == callable.get_object() and connected.get_method() == callable.get_method():
				return true
	events.connect(signal_name, target)
	return true


# bind/unbind make named methods custom too; reconstruction excludes even a named lambda.
static func _named_listener(callable: Callable) -> bool:
	var named := Callable(callable.get_object(), callable.get_method())
	var bound := callable.get_bound_arguments()
	if not bound.is_empty():
		named = named.bindv(bound)
	var unbound := callable.get_unbound_arguments_count()
	if unbound > 0:
		named = named.unbind(unbound)
	return callable == named


# --- The harpoon line and the synergy motifs ------------------------------------------

# True when the named gate is open, and then closes it for `gap` seconds.
func _gate(key: String, gap: float) -> bool:
	if clock < float(_gates.get(key, -1000.0)):
		return false
	_gates[key] = clock + gap
	return true


# A grammar cue at its trim: the row's priority offset is taken back out, so the level is the
# bank's own, which is what the table of levels in sfx_bank.gd is written against.
func _grammar_cue(kind: String, sound: String, bus := "SFX", pitch := 1.0) -> bool:
	return play(kind, -PRIORITY_DB[Rows.priority(kind)], pitch, bus, sound)


# The chain's link bite climbs a rung of the reward ladder per link beyond the first (A, C, D, F,
# G, then A an octave up at link six, CHAIN_STEPS), never a semitone (AUDIO-V3 section 5 rule 3),
# and the smash that pays it lands at the root. Link 1 plays nothing here: the line's own
# latched_body bite is the combo-1 sound, exactly as without a chain.
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
			# Combo 1 is exactly today's game: only a chain that reached 2 zips.
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
		# A chain fact is not the line's state: no hum, no _line_was.
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
			# A chained bite already sounded, pitched, a frame ago.
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


# A refused press plays its verb's own cue. The harpoon's refusal is the dry tick that its dry
# fire state also plays, so the two share one gate and a refusal is heard once.
func _on_verb_failed(verb: String, _reason: String, _at: Vector3) -> void:
	var sound := String(Bindings.VERBS.get(verb, {}).get("fail", EventKinds.NONE))
	if sound == EventKinds.NONE or sound == "":
		return
	if not _gate("fail:" + verb, FAIL_GAP):
		return
	if sound == "dry_tick" and not _gate("dry_tick", DRY_TICK_GAP):
		return
	_grammar_cue("verb_failed", sound)


# The first two notes of a synergy's phrase when it goes live. The third waits for the effect.
func _on_cause_armed(id: String) -> void:
	var motif := EventKinds.cause_motif(id)
	for i in mini(2, motif.size()):
		_notes.append([clock + NOTE_SPACING * i, "cause_armed", Harmony.note_midi(String(motif[i])), id])
	_play_due_notes()


# The phrase resolves the first time the effect really happens in a run; after that the third
# note alone marks a firing, at most once per synergy every few seconds.
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


# The pitch ratio of the hum at a gap: 1 at HUM_FAR and above, 2 at HUM_NEAR and below.
static func hum_ratio(gap: float) -> float:
	return pow(2.0, clampf((HUM_FAR - gap) / (HUM_FAR - HUM_NEAR), 0.0, 1.0))


func _start_hum() -> void:
	if not sound_ready:
		return
	if not hum_on:
		hum_on = true
		if _sfx != null:
			_hum_voice = _sfx.play_stream(SfxBank.stream("line_hum"), 0.0, SfxBank.trim_db("line_hum") + HUM_DB, 1.0, AudioServer.PLAYBACK_TYPE_DEFAULT, "SFX")
		cue_log.append(["line_state_changed", "line_hum", "now", engine.clock, 1.0])
	_tend_hum()


func _stop_hum() -> void:
	if not hum_on:
		return
	hum_on = false
	if _sfx != null and _hum_voice != AudioStreamPlaybackPolyphonic.INVALID_ID and _sfx.is_stream_playing(_hum_voice):
		_sfx.stop_stream(_hum_voice)
	_hum_voice = -1
	hum_pitch = 1.0
	cue_log.append(["line_state_changed", "line_hum", "stop", engine.clock, 1.0])


# Follows the line each frame: its pitch from the gap on a body, and an end the line never
# announced (a reset or a restore) stops it.
func _tend_hum() -> void:
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


# Stage seconds and transport samples meet at the advance that schedules the event.
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


# Resumption changes the stage-to-sample mapping, never the director's deadline.
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


# The previous advance can reschedule without publishing a new fact. Capture it
# before the next scheduling snapshot replaces the one that committed its deadline.
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
		# An announcement with no lead warns of nothing (a stage's resting weather as the stage
		# starts): no klaxon, and no start cue when it begins.
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
	# The set director's set piece: one with a row, landing where its cue lands.
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


# Check the director's exact guards before a block can render the predicted impact: the same
# guards on the same ball, so the tick's place and the tick's velocity, never the drawn place.
# Holding starts at the deadline; checking clearance during the lead protects the ring.
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


# Leave the booked sample unrendered until physics commits or cancels the landing.
# A clearance check cannot revoke samples already pushed into a device's ring.
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
		# Each event earns the progress feed again: one that never sends it keeps the timer.
		_event_progress_live = false


# A win drops back into the level with the milestone stinger on the drop beat; a pass
# or a loss settles home gracefully, with no punishing sting.
func _on_event_ended(event_id: String, outcome: String) -> void:
	end_moment("event", event_id)
	if not _park_event_row(event_id).is_empty():
		engine.cancel_park_cue(event_id)
		_park_cues.erase(event_id)
		return
	# Only an event the band escalated on the level track steers it home: one that ends during
	# a Warden or miniboss fight leaves that fight's track and build alone.
	var participatory := event_id == _event_id and engine.track == "level"
	_event_id = ""
	if not participatory or not sound_ready:
		on_beat("event_ended", -6.0 if outcome != "won" else 0.0)
		return
	if outcome == "won":
		var at := engine.resolve_event(true)
		if at >= 0:
			engine.schedule_stinger_at(Rows.sound("milestone_won"), at)
			cue_log.append(["event_ended", Rows.sound("milestone_won"), "beat", at, 1.0])
	else:
		engine.resolve_event(false)
		cue_log.append(["event_ended", "settle", "bar", engine.next_bar(), 1.0])


# The spine's event_progress(event_id, fraction), once it lands, replaces the timer.
func _on_event_progress(event_id: String, fraction: float) -> void:
	if event_id != _event_id or not sound_ready:
		return
	_event_progress_live = true
	# An event only escalates the level track; a fight track (a relay's own miniboss, a Warden)
	# follows its fight, and two fractions would fight over one build.
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
	# Back in the arena (entry or retry) the band plays, whatever a death left it in.
	if state == "boss" and sound_ready and engine.mode != MusicEngine.PLAY:
		engine.schedule_mode(engine.next_beat(), MusicEngine.PLAY)


# The mix state (mix_rows.gd STATES) from the flow, the band's track, the boss phase, the shop
# moment and the systemic pressure, with hysteresis on the fight's edge.
var _flow_state := ""
var _combat := false


func mix_state() -> String:
	_combat = MixRows.combat_after(_combat, _pressure)
	var shop := _moments.any(func(m): return m.kind == "shop")
	return MixRows.resolve(_flow_state, camp_open, engine.track if engine != null else "level", _boss_phase, shop, _combat)


func _on_stage_entered(stage: int, retry: bool) -> void:
	_stage_now = stage
	_set_overtime = false
	_set_incoming_at = -1.0
	_champions.clear()
	_champion_euro.clear()
	_champion_hyped = false
	# A stage starts with no moments; the stage band the flow starts is the music to return to.
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
	# A retry restores the meter to its stage-entry value silently; the lift follows the meter
	# once every stage_entered handler has run (SKILL-BAR section 4, one fact for every layer).
	sync_ult_lift.call_deferred()
	engine.set_overcharge(0)
	if retry:
		_disarm_launch()
	elif _launch_armed:
		# The stage the launch was flying to: its theme arrives with the landing drop.
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
	# Each stage starts its own difficulty clock and never carries a vent pedal over.
	engine.set_fleet_ticks(0)
	engine.set_reactor_pedal(false)
	# An event torn down with its stage (no event_ended) must not escalate the next stage. Cleared
	# here, at the entry itself, so an event the new stage starts this frame keeps its id.
	_event_id = ""
	_flow_queue.append(["stage", stage, retry])
	_warm_park_risers.call_deferred(stage)


# A rendered event riser's length is read on the frame its event is announced (park_cue), so
# the stage's riser files are decoded on a worker at entry: the dam's first fleet call baked
# its riser there, 27-30 ms frames on the 4080. Deferred past the world's own handler, which
# swaps in the stage's map.
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


# The beacon climbs the reward ladder as it charges and lands on home, two octaves up.
func _on_beacon(fraction: float) -> void:
	var rung := 10 if fraction >= 1.0 else int(fraction * 8.0)
	if rung <= _beacon_rung:
		return
	_beacon_rung = rung
	play("beacon_charge_changed", 2.0 if rung == 10 else 0.0, Harmony.ratio(Harmony.pentatonic_step(rung)))


# A hit. Flag off it is the base sound for the whole hit. In armour mode the hull's own
# damage decides: an armour-only hit already sounded as the plates shedding (armor_hit
# fires first), so it stays silent here, and a hit turned aside entirely plays the soft
# deflect tick, and a hit that reached the hull is as loud as the hull damage it did.
# hull_damage only grows within a run, so a smaller reading is a new run and the count
# starts again.
func _on_player_hit(amount: float, _source: String) -> void:
	if _armor_on():
		var hull := float(ctx.run.metrics.get("hull_damage", 0.0))
		var took := hull if hull < _hull_seen else hull - _hull_seen
		_hull_seen = hull
		var shed := _shed_heard
		_shed_heard = false
		if took <= 0.0001:
			# Nothing shed and no hull damage: the hit was turned aside entirely.
			if not shed:
				play("armor_deflect")
			return
		amount = took
	play("player_hit", clampf(amount / 10.0, 0.0, 1.0) * 4.0 - 4.0)


func _armor_on() -> bool:
	var run = ctx.get("run")
	return run != null and bool(run.get("armor_mode"))


# The armour cues hang off two sources the bus does not carry: the run's armor_hit and the
# scrap field's recovered. Connected once each, and only if the source exists, so a test
# double without them, or a later call, is harmless. Neither ever fires with --scrap off.
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


# Scrap knocked off the ball: a clatter whose size follows the scrap removed (three
# baked sizes, then lower and louder up to ARMOR_SHED_FULL scrap).
func _on_armor_hit(removed: float, _spill: int, _source: String) -> void:
	_shed_heard = true
	var size := clampf(removed / ARMOR_SHED_FULL, 0.0, 1.0)
	var sound := "armor_shed_small" if removed < ARMOR_SHED_BIG_FROM * 0.4 else ("armor_shed_big" if removed >= ARMOR_SHED_BIG_FROM else "armor_shed")
	play("armor_hit", lerpf(-2.0, 2.0, size), Harmony.ratio(lerpf(2.0, -3.0, size)), "SFX", sound)


# Rivet's wear trail left a patch: one soft sputter, quiet against the armour cues.
func _on_wear_patch(_at: Vector3) -> void:
	play("wear_sputter")


# A spilled cluster rolled back up: a chime that climbs the pentatonic through a run.
func _on_spill_recovered(value: int) -> void:
	var rung: int = reclaim_streak.bump(Time.get_ticks_msec())
	play("armor_reclaim", clampf(value / 8.0, 0.0, 1.0) * 1.5 - 1.0, Harmony.ratio(Harmony.pentatonic_step(rung)))


func _on_scrap(amount: int, _at: Vector3, _total: int) -> void:
	var rung: int = scrap_streak.bump(Time.get_ticks_msec())
	play("scrap_collected", minf(amount, 5.0) * 0.6, Harmony.ratio(Harmony.pentatonic_step(rung)))


# Gears climb their own pentatonic run, apart from scrap's.
func _on_cogs(amount: int, _total: int) -> void:
	var rung: int = cog_streak.bump(Time.get_ticks_msec())
	play("cogs_collected", minf(amount, 5.0) * 0.6, Harmony.ratio(Harmony.pentatonic_step(rung)))


# The growl is the Fleet's voice: an ancient (a relic, a drone, a hand, a Warden) never
# makes it, and its pack arrives on its own family's cue (pack_arrived).
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


# --- The kill-first specials (INTEGRATION.md section 7, item 5) ----------------------

# A special arrives: its presence loop starts on a player of its own (so it never takes a
# combat voice), its spawn cue lands on the next beat, and its tell and death are followed.
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
		# The bodies emit special_tell(moment); the tell cue sounds on the "tell" moment only.
		enemy.connect("special_tell", func(moment: String): if moment == "tell": special_tell(enemy))
	if enemy.has_signal("dispatched"):
		enemy.connect("dispatched", func(_add = null): special_drop(enemy))
	if enemy.has_signal("died"):
		enemy.connect("died", func(_a = null, _b = null): special_broken(enemy))
	enemy.tree_exiting.connect(_special_gone.bind(id), CONNECT_ONE_SHOT)


# The visual tell shows this frame: the cue sounds this frame, never on the beat.
func special_tell(enemy: Node3D) -> bool:
	var row: Dictionary = _specials.get(enemy.get_instance_id(), {})
	if row.is_empty():
		return false
	return play("special_tell", 0.0, 1.0, "SFX", SpecialAudio.cue(row["name"], "tell"))


# A Dispatcher landed a chaser: its spawn cue answers it on the next beat, a notch under the
# arrival. It takes no presence player, so the two-loop cap is untouched. -1 when it sounds nothing.
func special_drop(enemy: Node3D) -> int:
	var row: Dictionary = _specials.get(enemy.get_instance_id(), {})
	if row.is_empty():
		return -1
	return on_beat("special_drop", SpecialAudio.DROP_DB, false, 1, SpecialAudio.cue(row["name"], "drop"))


# The special died: its loop stops and its break sounds, the splitter's by how it was rammed.
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


# At most SpecialAudio.CAP presence loops sound, the nearest to the player first.
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


# The boss music begins on the next bar, after the metric modulation when it pivots,
# and the row's cue marks the moment it begins.
func _begin_boss(kind: String, music: String) -> void:
	if not sound_ready:
		return
	if kind == "boss_arena_entered":
		radio_finale = false
	if radio_hold != "":
		if radio_pinned:
			on_beat(kind, 0.0, true)
			_radio_boss = [kind, music]
			return
		_radio_drop("boss")
	if engine.track == music or engine.mode != MusicEngine.PLAY:
		# A retry into the fight: the band left DEAD (or never left the boss track), so
		# it restarts the boss music in play mode on the next beat, not the keys alone.
		engine.cancel_pending()
		var again := engine.restart_boss(music)
		_phase_music_done = 1
		if music in MusicEngine.BOSS_TRACKS:
			_ace_named(_boss_entry(music), again, true)
		cue_log.append([kind, "restart", "beat", again, 1.0])
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
	cue_log.append([kind, sound, "bar", at, 1.0])


# boss_phase_changed(phase, name) in wave 4; with no phase argument, count up.
func _on_boss_phase() -> void:
	_boss_phase += 1
	on_beat("boss_phase_changed")
	engine.set_brindle_phase(_boss_phase)
	phase_music(_boss_phase)


func _on_boss_phase_with(phase) -> void:
	_boss_phase = int(phase)
	on_beat("boss_phase_changed")
	engine.set_brindle_phase(_boss_phase)
	phase_music(_boss_phase)


# The ACE band follows the boss phase (INTEGRATION.md section 6): Brindle swaps to its phase
# track on the next downbeat; in the last phase hype_drop's riser starts so its drop lands on a
# downbeat and the Eurodance track enters on it, falling back to the base final track (with no
# drop) when the euro pack is not on disk. A pack that is not on disk changes nothing. Returns
# the plan it carried out, {} for none.
func phase_music(phase: int) -> Dictionary:
	var boss := engine.track
	if PhaseMusic.is_final(phase) and sound_ready:
		if radio_hold != "" and not _radio_boss.is_empty():
			# The finale takes the air from a pinned track: the boss music it held off starts
			# now, and the final track lands on it. The deck puts the pin back after the fight.
			var held: Array = _radio_boss
			_radio_drop("finale")
			_begin_boss(held[0], held[1])
			_phase_music_done = 1
			boss = String(held[1])
		radio_finale = true
	if radio_hold != "":
		return {}
	if not sound_ready or phase <= _phase_music_done or not ace_wanted():
		return {}
	if not boss in MusicEngine.BOSS_TRACKS:
		return {}
	_phase_music_done = phase
	if PhaseMusic.is_final(phase):
		var plan := PhaseMusic.final_plan(boss, pack_available)
		if plan["track"] == "":
			return {}
		var when := PhaseMusic.drop_plan(engine.clock, engine.next_bar(), engine.bar_len(), Harmony.RATE)
		if plan["hype"]:
			engine.schedule_stinger_at("hype_drop", int(when["start"]))
			cue_log.append(["boss_phase_music", "hype_drop", "beat", int(when["start"]), 1.0])
		_ace_named(plan["track"], int(when["drop"]), true)
		cue_log.append(["boss_phase_music", plan["track"], "bar", int(when["drop"]), 1.0])
		return {"track": plan["track"], "hype": plan["hype"], "at": when["drop"]}
	var track := PhaseMusic.track_for_phase(boss, phase, pack_available)
	if track == "" or not pack_available.call(track):
		return {}
	var at := engine.next_bar()
	_ace_named(track, at, true)
	cue_log.append(["boss_phase_music", track, "bar", at, 1.0])
	return {"track": track, "hype": false, "at": at}


# A champion (an elite with an affix) joins: the combat band moves to champion-hype on the next
# downbeat, and back to the stage's band when the last one dies. In its final health third it
# gets the hype drop and euro-champion. Only on the level track, and only with the packs on disk.
func _champion_joined(enemy: Node3D) -> void:
	var id := enemy.get_instance_id()
	if _champions.has(id):
		return
	_champions[id] = enemy
	if enemy.has_signal("died"):
		enemy.connect("died", func(_a = null, _b = null): _champion_gone(id))
	enemy.tree_exiting.connect(_champion_gone.bind(id), CONNECT_ONE_SHOT)
	if radio_hold != "" or _champion_hyped or not sound_ready or not ace_wanted() or engine.track != "level":
		return
	# A run that rolled the chiptune remix hears it in the champion's place.
	var champion := TuneMoments.remixed("champion", PhaseMusic.CHAMPION, _remixes, tune_available)
	if champion == PhaseMusic.CHAMPION and not pack_available.call(PhaseMusic.CHAMPION):
		return
	_champion_hyped = true
	_ace_named(champion, engine.next_bar(), true)
	cue_log.append(["champion_joined", champion, "bar", engine.next_bar(), 1.0])


func _champion_gone(id: int) -> void:
	if not _champions.has(id):
		return
	_champions.erase(id)
	_champion_euro.erase(id)
	if _champions.is_empty() and _champion_hyped:
		_champion_hyped = false
		if _stage_now > 0 and engine.track == "level":
			_ace_stage(_stage_now, engine.next_bar())
			cue_log.append(["champion_gone", "stage", "bar", engine.next_bar(), 1.0])


# --- The place-and-moment tunes (tune_moments.gd, design-v3/sound/tunes.json) -----------
# A moment (a landmark in reach, an event, the bay, a find, a miniboss) puts its tune on the
# level band on the next downbeat; when it ends, the band goes back on the next downbeat to the
# next live moment or the stage's own music. A tune whose pack is not on disk changes nothing.

func new_run_tunes() -> void:
	_moments.clear()
	_moment_playing = ""
	_remix_rng.randomize()
	_remixes = TuneMoments.roll_remixes(_remix_rng)
	if not _remixes.is_empty():
		cue_log.append(["tune_remixes", ",".join(_remixes.values()), "run", engine.clock, 1.0])


# What the level band plays on this stage: the live moment's tune, else the run's modifier or
# rolled remix for the stage, else "" for the stage's own pack.
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


# A tune on its one pass does not begin inside a Warden's fight (warden_took_band), and
# neither does an event's.
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


# key "" ends every moment of the kind.
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
	cue_log.append(["tune_moment", want if want != "" else "stage", "bar", at, 1.0])


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


# A roll through a stocked fabricator hoop (build.gd world_fact "fabricator_used"): one pass of
# The Fabricator; another hoop while it plays restarts the pass without restarting the track.
func fabricator_used() -> void:
	begin_moment("fabricator", "fabricator_used", TuneMoments.tune_for("fabricator", "fabricator_used"))


func tune_found(discovery_id: String) -> void:
	begin_moment("find", discovery_id, TuneMoments.find_tune(discovery_id))


# A Warden's fight takes the band from every moment: the landmark's tune ends and stays away
# for the stage, a tune on its one pass (a find, the fabricator) is cut short and none begins
# until the arena opens, and an event's tune still running ends too (one that begins inside
# the fight does not start: TuneMoments.NOT_IN_A_FIGHT). A moment's recording has
# no fight sections and its own tempo, so one left playing holds the grid over the whole fight
# and the Warden's pivot never comes. The stage's own recording comes back straight into the
# fight's sections.
func warden_took_band() -> void:
	_warden_engaged = true
	_warden_fighting = true
	_moments.clear()
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
			_champion_euro[id] = true
			var when := PhaseMusic.drop_plan(engine.clock, engine.next_bar(), engine.bar_len(), Harmony.RATE)
			engine.schedule_stinger_at("hype_drop", int(when["start"]))
			_ace_named(final_track, int(when["drop"]), true)
			cue_log.append(["champion_final", final_track, "bar", int(when["drop"]), 1.0])
			return


static func _argc(events: Object, signal_name: String) -> int:
	return SignalWire.arg_count(events, signal_name) if events.has_signal(signal_name) else -1


func _on_boss_defeated() -> void:
	_radio_drop("victory")
	radio_finale = false
	on_beat("boss_defeated", 0.0, true)
	engine.victory()


# A live miniboss other than the one dying on this kill (enemy.gd marks it dead first).
# A miniboss that leaves (killed, or cleared with its stage) before its track has landed takes
# the queued switch with it, so the band never enters a fight that is already over. A landed
# track is left alone: a kill pays its own drop (_on_kill), and a stage teardown or launch
# hands the band on through its own restart or landing drop.
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


# The surge miniboss and the rogue fleet machines share the miniboss track and moment.
static func is_miniboss(kind: String) -> bool:
	return kind == "miniboss" or Rogue.ROWS.has(kind)


# A rogue plays its own anthem once its TUNES row exists (the music lane adds it with the
# track); until then, and for the surge miniboss, the miniboss tune.
static func miniboss_tune(kind: String) -> String:
	var anthem := String(Rogue.ROWS.get(kind, {}).get("anthem", ""))
	return anthem if TuneMoments.TUNES.has(anthem) else "miniboss"


func _on_kill(_kind: String, _at: Vector3, _value: int) -> void:
	# A rogue and a surge miniboss can share a stage: while another one still fights, the
	# track holds and the music follows the survivor (each moment ends with its own body).
	if is_miniboss(_kind) and _miniboss_survivor() != null:
		_miniboss = _miniboss_survivor()
		_kind = ""
	if is_miniboss(_kind) and is_instance_valid(_miniboss):
		var key := str(_miniboss.get_instance_id())
		end_moment("miniboss", key)
	if is_miniboss(_kind) and engine.track == "miniboss":
		# The payoff on the kill: the drop home on the next beat, then the cadence.
		engine.miniboss_drop()
		_miniboss = null
	if _kind == "vault":
		# A small drop, on the moment the vault breaks.
		play("enemy_killed", 2.0, 1.0, "SFX", VAULT_KILL_SOUND)
	var rung: int = kill_streak.bump(Time.get_ticks_msec())
	# The pop is percussion (SOUND-BIBLE rule 7): the chain grows by its tier layer, not by pitch.
	play("enemy_killed")
	if rung >= STREAK_LAND_RUNG:
		_warm_landing(rung)
	# Each link past the first adds its tier's stab (INTEGRATION section 3), five rungs.
	if rung >= 1:
		var tiers: Array = SfxBank.TIER_CUES["kill_chain_tier"]
		play("enemy_killed", 0.0, 1.0, "SFX", tiers[mini(rung, tiers.size()) - 1])


# True while the recorded band's grid is the one the player hears.
func _on_ace_grid() -> bool:
	return ace != null and engine.grid == ace and ace.mode != "off" and ace.section != ""


# The band answers a skill cast on the beat (SKILL_ANSWER_NOTES above). Returns the notes booked,
# empty off the beat. target is the foe the skill named, or null.
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


# A foe that earns the band's whole answer: an elite pack's member, a miniboss, the Warden, or
# anything while a boss fight is live.
func big_foe(target: Node3D) -> bool:
	if ctx != null and "boss" in ctx and ctx.boss != null and ctx.boss.has_method("active") and ctx.boss.active():
		return true
	if not is_instance_valid(target):
		return false
	return target.has_meta("elite_pack") or target == _miniboss or target.get("boss") != null \
			or (ctx != null and ctx.flow != null and ctx.flow.get("warden") == target)


# One division of the sounding band's beat in samples: per_beat 4 is a sixteenth, 2 an eighth.
func grid_unit(per_beat: int) -> int:
	return maxi(1, (ace.grid_beat if _on_ace_grid() else engine.beat_len()) / per_beat)


# The next point of the sounding band's grid at or after the play head.
func next_grid(per_beat: int) -> int:
	var unit := grid_unit(per_beat)
	var origin: int = ace.origin if _on_ace_grid() else engine.grid_origin
	return engine.clock + posmod(origin - engine.clock, unit)


func _next_bar() -> int:
	return ace.next_bar() if _on_ace_grid() else engine.next_bar()


# One pitched note of kind's cue in the stinger lane at transport sample at, at the grid note's
# trim and the kind's priority. home keeps it in D (schedule_stinger_at).
func _note_at(kind: String, voice: String, midi: int, at: int, db := 0.0, home := false) -> void:
	var id := SfxBank.grid_note_id(voice, midi)
	engine.schedule_stinger_at(id, at, db + PRIORITY_DB[Rows.priority(kind)], home)
	cue_log.append([kind, id, "grid", at, 1.0])


# The chord tones a landing at transport sample at falls to. The recorded band names no chords,
# so over it a chain lands on the home triad.
func _landing_tones(at: int) -> Array:
	return HOME_TRIAD if ace_playing() else engine.chord_at(at)["tones"]


# A landing's notes are made on a worker while the chain is still live: the window that has to
# close before it lands is the lead. The chord is read for the bar the window closes in and the
# one after it, which a landing on the next beat or bar line falls in.
func _warm_landing(rung: int) -> void:
	var due: int = engine.clock + kill_streak.window_ms * Harmony.RATE / 1000
	for at in [due, due + 4 * grid_unit(1)]:
		for id in _landing_ids(rung, _landing_tones(at)):
			engine.warm_stinger(id, at)
		# The quote a long chain earns, unless the last one is too recent to earn another.
		if rung >= STREAK_BAR_RUNG and clock >= float(_gates.get("pilot_quote", -1000.0)):
			engine.warm_stinger(_pilot_quote_id(), at, false, grid_unit(4))


# The whip and the dunk answer a sixteenth after their contact, too soon to make a note: theirs
# are made as a new key arrives (or a new class in it).
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
	# A skill's answer starts a sixteenth after the cast, too soon to make its notes then.
	var row := Harmony.motif_or_first(motif)
	for cell in row["cells"]:
		engine.warm_stinger(SfxBank.grid_note_id(String(row["voice"]), int(cell[1])), engine.clock)
	if row.has("band") and not row["cells"].is_empty():
		var last: Array = row["cells"][row["cells"].size() - 1]
		engine.warm_stinger(SfxBank.grid_note_id(String(row["band"]), int(last[1]) + int(row.get("band_octave", 0))), engine.clock)


# The kill chain's window has closed: a chain worth hearing lands, once.
func _tend_kill_streak() -> void:
	if kill_streak.length == 0 or kill_streak.last_ms == _streak_landed_ms or kill_streak.live(Time.get_ticks_msec()):
		return
	_streak_landed_ms = kill_streak.last_ms
	if kill_streak.rung >= STREAK_LAND_RUNG and sound_ready and engine.mode == MusicEngine.PLAY:
		land_streak(kill_streak.rung)


# The ladder was the question and this is the answer: the line falls from the chain's last note
# to the chord tone under it, on the next beat, on the pop's bell with keys an octave below. A
# long chain (STREAK_BAR_RUNG) restates its last note on the next sixteenth and lands on the bar
# line under a crash. Returns the transport sample of the landing.
func land_streak(rung: int) -> int:
	var last: int = SfxBank.KILL_POP_MIDI + Harmony.pentatonic_step(rung)
	var long := rung >= STREAK_BAR_RUNG
	var at := _next_bar() if long else engine.next_beat()
	if long:
		var hold := next_grid(4)
		if at - hold >= grid_unit(2):
			_note_at("enemy_killed", STREAK_VOICE, last, hold, SfxBank.GRID_UNDER_DB)
		# The crash has no pitch, so it stays the boot bake's whatever the key.
		engine.schedule_stinger_at(CHAIN_CRASH, at, PRIORITY_DB[Rows.priority("enemy_killed")], true)
		cue_log.append(["enemy_killed", CHAIN_CRASH, "bar", at, 1.0])
	var land := Harmony.tone_below(last, _landing_tones(at))
	_note_at("enemy_killed", STREAK_VOICE, land, at)
	_note_at("enemy_killed", STREAK_BODY, land - 12, at, SfxBank.GRID_UNDER_DB)
	if long:
		_quote_pilot(at + grid_unit(1))
	return at


# The band answers a long chain by name (SOUND-BIBLE, "Pilot quotes"): the pilot's own motif on
# the sax from transport sample at, in the sounding band's eighths and key.
func _quote_pilot(at: int) -> void:
	if not _gate("pilot_quote", pilot_quote_gap()):
		return
	var id := _pilot_quote_id()
	engine.schedule_stinger_at(id, at, PRIORITY_DB[Rows.priority("enemy_killed")], false, grid_unit(4))
	cue_log.append(["enemy_killed", id, "quote", at, 1.0])


# The seconds between two quotes: PILOT_QUOTE_BARS bars of four beats at the sounding band's tempo.
func pilot_quote_gap() -> float:
	return float(PILOT_QUOTE_BARS * 4 * grid_unit(1)) / Harmony.RATE


func _pilot_quote_id() -> String:
	return SfxBank.pilot_quote_id(_motif if _motif != "" else Harmony.CLASS_MOTIFS[0])


# A part set's banner is up (presentation.gd): its chime, on the band's next eighths and in the
# live key. element is the one the set adds: an arc set climbs on the clavinet and a frost set on
# the bell. Returns the transport sample of the first note, or -1 when no band is playing to
# time it.
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


# The near miss is a reward in the class's own voice and ducks nothing (AUDIO-V3 section 5 rule
# 4): the air on its frame, then the class whip's two notes on the next two sixteenths.
func _on_near_miss(_kind: String, _at: Vector3) -> void:
	if not play("near_miss"):
		return
	var notes := SfxBank.whip_notes(_motif if _motif != "" else Harmony.CLASS_MOTIFS[0])
	var at := next_grid(4)
	_note_at("near_miss", notes[0], notes[1], at)
	_note_at("near_miss", notes[0], notes[2], at + grid_unit(4))


func _on_died() -> void:
	_line_was = ""
	_stop_hum()
	play("player_died")
	_flow_queue.append(["dead"])


func _on_slammed(_at: Vector3, strength: float, flatness: float) -> void:
	if strength < 0.05:
		return
	play("slammed", lerpf(-8.0, 0.0, clampf(strength, 0.0, 1.0)), lerpf(1.1, 0.9, clampf(strength - 0.5, 0.0, 1.0)))
	# The womp is the player's own action, so it sounds this frame, never on a beat.
	# The flat full plant is the biggest: loudest and a fourth lower.
	var weight := clampf(strength, 0.0, 1.0) * lerpf(0.5, 1.0, clampf(flatness, 0.0, 1.0))
	play("slammed", lerpf(-12.0, 0.0, weight), Harmony.ratio(lerpf(0.0, -5.0, weight)), "SFX", "womp")


func _on_launched(_velocity: Vector3) -> void:
	play("launched")
	# From the level, a miniboss or the Warden's drop (players take the gate inside
	# the unseal drop); never out of Brindle's arena.
	if not sound_ready or engine.mode != MusicEngine.PLAY or engine.track == _boss_track():
		return
	# One flight owns the band at a time, and a launch outranks an ultimate still in the air:
	# the ultimate's later cancel (its stage-entry abort) or landing must not end the launch's
	# riser or ACE piece.
	_ult_armed = false
	_ult_band_stays_off()
	# A launch out of the Warden's break is directed from A to B: the piece plays through
	# the flight and the landing hands it to the synth on a beat (_land_drop). Any other
	# ACE mode (an unsealed stage's gate) hands to the synth now, so its launch riser sounds.
	if ace_playing() and ace.mode == "piece":
		_ace_flight = true
		_launch_armed = true
		_landing_theme = -1
		_launch_stage = false
		return
	if ace_playing():
		_ace_end(ace.grid_beat)
	# The launch is the build: the riser, the snare roll and the sweep carry the flight.
	engine.start_build(LAUNCH_BUILD_SECONDS, true)
	_launch_armed = true
	_landing_theme = -1
	_launch_stage = false


func _on_landed(impact: float) -> void:
	play("landed", lerpf(-12.0, 2.0, clampf(impact / 30.0, 0.0, 1.0)), lerpf(1.1, 0.85, clampf(impact / 30.0, 0.0, 1.0)))
	if _launch_armed and _landing_theme >= 0:
		_land_drop()


# The landing is the drop: on the next beat, never more than one beat after touchdown,
# in the new stage's theme.
func _land_drop() -> void:
	var touchdown := engine.clock
	if _radio_respin_due:
		_radio_respin_due = false
		_radio_respin()
	var at := engine.drop_now(4, 0.85, {}, _landing_theme if radio_hold == "" else -1)
	if _ace_arrival_stage > 0:
		_ace_arrival_at = at
	drop_log.append([touchdown, at])
	if _ace_flight:
		# The piece sounds to the landing's beat, fades under the synth drop over a beat and
		# leaves the synth band to un-mute so its ramp ends on that beat.
		_ace_flight = false
		if ace_playing():
			ace.stop_at(at, ace.grid_beat)
			_handover_at = at
	cue_log.append(["landed", "drop", "beat", at, 1.0])
	_launch_armed = false
	_landing_theme = -1


# --- The set piece (SKILL-BAR section 4, music) -------------------------------------------

# The set piece reads its flight's beat from the band: seconds per beat of the music playing,
# 0 when none plays (the flight then takes 2.4 s).
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


# What the ACE band hears as pressure: the systemic pressure plus the meter's step.
func ace_pressure() -> float:
	return _pressure + (AceSequencer.ULTIMATE_STEP if _ult_lift else 0.0)


func _set_ult_lift(on: bool) -> void:
	_ult_lift = on
	engine.set_ultimate_lift(on)
	# Written whether or not the band plays: a level band that ended for the flight keeps its
	# sequencer, and a resume must not carry a lift the landing already released.
	if ace != null and (not ace.parameter_enabled or not ace.active()):
		ace.set_ultimate_lift(on)


# The lift reads the meter: on when it is full, off otherwise. No meter, no change.
func sync_ult_lift() -> void:
	var player = ctx.get("player") if ctx != null else null
	if player == null or player.abilities.meter == null:
		return
	var full: bool = player.abilities.meter.full()
	if full != _ult_lift:
		_set_ult_lift(full)


# Full: the class motif an octave up and a bell on the beat, and one layer lifts at the bar.
func _on_ultimate_ready(_id: String) -> void:
	_set_ult_lift(true)
	on_beat("ultimate_ready")


# The wind-up is the build, as a launch is: the riser carries the flight. A directed ACE piece
# holds through the flight and hands over on the landing's beat, as a Warden launch does.
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
	cue_log.append([kind, sound, grid, at, keyed_pitch, gain])
	return at


func kest_roll(note: int) -> int:
	return kest_cue("ultimate_peak", "tick_kest_%d" % note, "eighth")


# The landing is the drop, on the next beat, never more than one beat after touchdown; the
# lift releases with it (the meter is empty).
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
			# Time on target shares touchdown; waiting for the next beat separates the shells from the drop.
			at = touchdown
			engine._add_action(at, {"type": "drop", "bars": 4, "weight": 0.85, "then": {}, "theme": -1, "set": {"ult": false}})
		else:
			at = engine.drop_now(4, 0.85, {}, -1, {"ult": false})
		drop_log.append([touchdown, at])
		if _ace_flight:
			_ace_flight = false
			if ace_playing():
				ace.stop_at(at, ace.grid_beat)
				_handover_at = at
		if _ult_took_band and _stage_now > 0 and _ace_arrival_stage == 0 and not ace_playing() and engine.track in STAGE_BAND_MODES:
			# The synth band's build and drop are the ultimate's; the stage's recorded band comes
			# back on the bar after the drop (_pump). A band something else already started, or a
			# boss that arrived in between, keeps its own.
			_ace_arrival_stage = _stage_now
			_ace_arrival_at = at
		_ult_took_band = false
		cue_log.append(["ultimate_landed", "drop", "beat", at, 1.0])
		_ult_armed = false
	_set_ult_lift(false)


# A cancel drops the build. A recall refunds the meter, so the lift stays; any other cancel
# spent it, so the lift goes.
func _on_ultimate_cancelled(_id: String, _reason: String, refunded: bool) -> void:
	play("ultimate_cancelled")
	if _ult_armed:
		_ult_armed = false
		if _ace_flight:
			_ace_flight = false
			_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)
		engine.cancel_build()
		# A recall or a bail leaves the player in the stage, so its band comes back; a death or
		# a stage's end has its own music.
		if _ult_took_band and _stage_now > 0 and _reason in ULT_BAND_BACK and not ace_playing() and engine.track in STAGE_BAND_MODES:
			_ace_return(_stage_now, engine.next_bar())
		_ult_took_band = false
	if not refunded:
		_set_ult_lift(false)


func _disarm_launch() -> void:
	_ace_arrival_stage = 0
	_ace_arrival_at = -1
	if _ace_flight:
		# The landing that would hand the band over is not coming.
		_ace_end(ace.grid_beat if ace_playing() else AceSequencer.STOP_RAMP)
	if _launch_armed:
		engine.cancel_build()
	_launch_armed = false
	_landing_theme = -1
	_launch_stage = false


# The Warden's last quarter is the build; the spine's integrity query is read-only.
func _follow_warden() -> void:
	if engine.track != "warden" or engine.section == "drop":
		return
	if ctx.flow == null or not ctx.flow.has_method("warden_integrity"):
		return
	engine.warden_charge(1.0 - float(ctx.flow.warden_integrity()))


# The B-arc for the miniboss, the live event, Brindle's phases and the chase, each on
# its own real state (guarded reads; nothing here decides an outcome).
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


# A number the boss module exposes, or the default when it (or a test double) has none.
static func _num(object: Object, property: String, fallback: float) -> float:
	var value = object.get(property)
	return float(value) if value is int or value is float else fallback


func _on_dismounted(velocity: Vector3) -> void:
	# E drops off quietly; the slingshot sings higher the faster it throws you.
	if velocity.length() < 1.0:
		play("dismounted", -8.0, 0.75)
		return
	play("dismounted", 0.0, Harmony.ratio(clampf(velocity.length() / 5.0, 0.0, 7.0)))


func _on_struck(enemy: Node3D, kind: String, force: float) -> void:
	if kind == "synergy":
		# A synergy's shockwave: its own light chime, never the slam family.
		play("enemy_struck", -8.0, Harmony.ratio(Harmony.pentatonic_step(_pitch_rng.randi() % 5)), "SFX", "synergy_hit")
		return
	if is_instance_valid(enemy) and enemy.get("kind") == "vault":
		# The vault's riser climbs as its integrity falls.
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


# A grown pilot's contact hits carry more weight: one layer per heft class past I, started on
# the hit's own frame with the hit's level. A sub drop from II, a heavier crack from III, a long
# rumbling tail and a scrap rattle from IV, so a heft IV slam sounds about twice as layered.
const GROWN_LAYERS := [[2, "grown_sub"], [3, "grown_crack"], [4, "grown_tail"], [4, "grown_rattle"]]


func _grown_layers(db: float) -> void:
	var heft := _heft_class
	if ctx != null and ctx.run != null and ctx.run.has_method("heft_class"):
		heft = int(ctx.run.heft_class())
	for layer in GROWN_LAYERS:
		if heft >= int(layer[0]):
			play("enemy_struck", db, 1.0, "SFX", layer[1])


# The hit's own sound has already played, so the beat never delays it.
func _pay_beat(enemy: Node3D, kind: String) -> void:
	if absf(beat_offset_s()) > ONBEAT_WINDOW_S or engine.clock - _onbeat_at < engine.beat_len() / 2:
		return
	_onbeat_at = engine.clock
	var stab := SfxBank.rendered(ONBEAT_SOUND)
	if stab != null:
		_start("hit_on_beat", ONBEAT_SOUND, stab, PRIORITY_DB[Rows.priority("enemy_struck")] + ONBEAT_DB, 1.0, "SFX")
	else:
		cue_log.append(["hit_on_beat", ONBEAT_SOUND, "absent", engine.clock, 1.0])
	hit_on_beat.emit(enemy, kind)


# How far the moment the player hears is from its nearest beat, in seconds: negative before
# the beat, positive after. INF while no music plays.
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


# The pitch of the phrase's note for the guard's quarter: under 25 the first, 75 and over
# the fourth, so each hit sounds one step higher than the last that stayed in its quarter.
func _posture_note_ratio(enemy: Node3D) -> float:
	var midis := SfxBank.break_midis(POSTURE_PHRASE)
	var quarter := clampi(int(enemy.posture() / POSTURE_QUARTER), 0, midis.size() - 1)
	return Harmony.ratio(midis[quarter] - Harmony.HOME)


# The stagger lands the chord and cuts the charge it cancelled; a shattered chunk is its
# row's sound over a low hit. A draining guard changes posture and makes no sound.
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
	if shattered:
		play("posture_changed", 6.0, 1.0, "SFX", Rows.heard(EventKinds.state_row("chunk_shatter"), cue_context()))
		play("posture_changed", 6.0, 1.0, "SFX", SHATTER_LOW)
	# The reading that breaks the Warden asks the band for nothing: the break answers it on the
	# next frame, and a build opened here would be opened only to be thrown away (8 ms on the
	# break's frame, measured on the PC).
	if ctx.flow != null and ctx.flow.get("warden") == enemy and chunks > 0:
		# A hit that fills the bar from low down opens a stagger and passes a quarter on the same
		# reading: the stagger's held breath answers it, not a drop.
		# A smash inside the dam's stagger takes a real chunk while the wiped bar reads no
		# quarter gone: a real chunk shattered with some left lands the drop there too.
		var fell := _guard_step_fell(enemy, bool(seen[0]) and not staggered)
		_follow_warden_form(posture, staggered, (fell or (shattered and chunks > 0)) and not staggered)


# Whether this reading took a step off the Warden's guard and left it standing: the hit that
# lands the drop. The guard is counted as the fight's phases count it (warden.gd
# phase_chunks_left): the real chunks, or the bar's quarters on the dam, whose rule breaks all
# four chunks on the last ram, so its real count goes from four to none in one step. The lowest
# count seen is kept, so a bar that drains while the ball is away and fills again lands no drop
# twice. The end of a stagger is the one moment the dam's bar is wiped: the count starts again
# from there, so the climb after it lands its drops too.
func _guard_step_fell(enemy: Node3D, stagger_ended: bool) -> bool:
	var left: int = enemy.phase_chunks_left() if enemy.has_method("phase_chunks_left") else enemy.chunks_left()
	var id := enemy.get_instance_id()
	var lowest := int(_guard_steps.get(id, BossPosture.CHUNKS))
	_guard_steps[id] = left if stagger_ended else mini(lowest, left)
	return left < lowest and left > 0


# The Warden's fight plays the recorded band like a set (AUDIO-V3 section 1.1, read for the
# posture fight): the pilot's hits tighten the build, the stagger is the held breath, and
# the hit that shatters a chunk lands the drop on the next beat. The chunk that breaks the
# Warden lands no drop: the break and the kill cadence answer it (ruling bt). With the
# launch switch on "loop" the band is told a guard that never moves, so the build loops.
func _follow_warden_form(posture: float, staggered: bool, landed: bool) -> void:
	var tuning = ctx.get("tuning")
	if not ace_playing() or tuning == null:
		return
	if tuning.option(Tuning.WARDEN_FORM_KEY) != "form":
		ace.follow_guard(0.0, false, false)
		return
	var at: int = ace.follow_guard(posture, staggered, landed)
	if at >= 0:
		cue_log.append(["warden_form", "drop", "beat", at, 1.0, 0.0])
		_make_drop_room(at)


func _stagger_chord() -> void:
	var key := Harmony.ratio(live_key())
	for midi in SfxBank.break_midis(POSTURE_PHRASE):
		play("posture_changed", 6.0, key, "SFX", SfxBank.cause_note_id(midi))
	play("posture_changed", 6.0, 1.0, "SFX", Rows.heard(EventKinds.state_row("open"), cue_context()))


# Whether a charge cue began at the Warden's own position (the Warden emits it from there).
func _is_warden_at(at: Vector3) -> bool:
	if ctx == null or ctx.flow == null:
		return false
	var warden = ctx.flow.get("warden")
	return is_instance_valid(warden) and warden.global_position.is_equal_approx(at)


# A stagger cancels the pulse the Warden was charging, and vent_erupted never comes to end
# the cue that began with it.
func _cut_charge() -> void:
	if not _warden_charging:
		return
	_warden_charging = false
	var sound := Rows.sound("vent_charging", cue_context())
	stop(sound)
	engine.set_reactor_pedal(false)
	cue_log.append(["posture_changed", sound, "stop", engine.clock, 1.0, 0.0])


# Hits on the Warden climb the pentatonic as its integrity falls; the unseal resolves
# them home. 1.0 for anything else.
func _warden_ladder(enemy: Node3D) -> float:
	if ctx.flow == null or not is_instance_valid(enemy) or ctx.flow.get("warden") != enemy:
		return 1.0
	return Harmony.ratio(Harmony.pentatonic_step(int((1.0 - _integrity(enemy)) * 6.0)))


func _integrity(enemy: Node3D) -> float:
	if ctx.spawner != null and ctx.spawner.has_method("integrity_of"):
		return float(ctx.spawner.integrity_of(enemy))
	return 1.0


# The dunk charge (dunk.gd) cues: a held charge is a whistle up, its spend a crack. They read
# the one record the glow reads and borrow the slammed row and existing sound ids, so the
# event table stays as it is; Effects restyles them. Each is answered by one note on the next
# sixteenth: the charge banks on the fifth (A) and the spend pays on home (D), so the setup and
# its payoff are a cadence.
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


# Heat on the shell (redline.gd) cues: each band it climbs into is a whistle a pentatonic rung
# higher (a quarter on D's second, hot on the fifth, redline on the sixth), and a blast or a
# cook-off is the slam's crack pitched down a fourth. They borrow the slammed row and existing
# sound ids, like the dunk's, so the event table stays as it is.
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
		# One sound per crossing of the hot line, not per frame the value moves.
		if band >= HOT_BAND and _redline_band < HOT_BAND:
			_cool_due = false
			play("slammed", -2.0, 1.0, "SFX", "heat_rise")
		elif band < HOT_BAND and _redline_band >= HOT_BAND:
			# The shell drains a little each frame, so a drop straight to empty is never a cooling: it is a
			# blast or a cook-off (each has its own crack), or a clear on a death, a new stage or a mode change.
			_cool_due = value > 0.0
		_redline_band = band)
	redline.detonated.connect(func(_at: Vector3, _force: float):
		play("slammed", 2.0, Harmony.ratio(-5.0), "SFX", "smash_crack"))
	redline.cooked_off.connect(func(_at: Vector3, _force: float):
		play("slammed", 0.0, Harmony.ratio(-7.0), "SFX", "smash_crack"))


# The hot line (Redline.HOT_AT) is band 2. The cooling plays on the next frame's tend, and a hit taken
# hot is read off Redline's own count.
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


# The cook-off's warning (loops.md Spec 1): over the last Redline.KETTLE_S of a shell held at redline the
# kettle whistles, climbing to the tritone; it stops the moment the heat is spent, cooks off or falls.
var _kettle_on := false


func _tend_kettle() -> void:
	var redline = ctx.player.get("redline") if ctx != null and ctx.get("player") != null else null
	var left: float = redline.fuse_left() if redline != null else -1.0
	var due := left > 0.0 and left <= Redline.KETTLE_S
	# A pause or slow motion can outlast the 2 s whistle on a game-time fuse: whistle again.
	var sounding: bool = _kettle_on and _sfx != null and Array(_voices.get("heat_kettle", [])).any(func(id: int): return _sfx.is_stream_playing(id))
	if due and not sounding:
		_kettle_on = play("slammed", 0.0, 1.0, "SFX", "heat_kettle")
	elif not due and _kettle_on and left <= 0.0:
		_kettle_on = false
		stop("heat_kettle")


# Each active sounds its own launch ("active_" + id) when the bank has it, else the row's.
func _on_active_fired(active_id: String, _at: Vector3, _count: int) -> void:
	var sound := "active_" + active_id
	play("active_fired", 0.0, 1.0, "SFX", sound if SfxBank.has_recipe(sound) else "")


# An active's heat building on a machine ("active_" + id + "_heat"): it climbs an octave and
# swells as the heat nears the strike, so a long first burn is heard working.
func _on_active_heat(active_id: String, _at: Vector3, fraction: float) -> void:
	var sound := "active_%s_heat" % active_id
	if SfxBank.has_recipe(sound):
		play("active_fired", lerpf(-8.0, 0.0, fraction), Harmony.ratio(lerpf(0.0, 12.0, fraction)), "SFX", sound)


func _on_shot(weapon_id: String, _from: Vector3, _to: Vector3) -> void:
	var cents := _pitch_rng.randf_range(-25.0, 25.0) / 100.0
	play("shot_fired", 0.0, Harmony.ratio(WEAPON_PITCH.get(weapon_id, 0.0) + cents))


func _on_offered(_offers: Array) -> void:
	# The gates re-announce when they move; the fanfare plays once per opening.
	if _gates_announced:
		return
	_gates_announced = true
	_flow_queue.append(["gates"])


# Up a class climbs on the next beat; down a class (a crane theft) falls back softly.
# Direction comes from the last class heard until the spine publishes its own.
func _on_heft_class(heft_class: int, _heft: float) -> void:
	engine.set_heft_lift(heft_class - 1)
	if heft_class > _heft_class:
		on_beat("heft_class_changed")
	elif heft_class < _heft_class:
		on_beat("heft_class_changed", 0.0, false, 1, "class_down")
	_heft_class = heft_class


# A class lost has its own signal now: the climb falls back on the next beat.
func _on_heft_dropped(heft_class: int, _heft: float) -> void:
	on_beat("heft_class_dropped")
	engine.set_heft_lift(heft_class - 1)
	_heft_class = heft_class


# Brindle's attack ids (boss.gd) and the wind-up each warns with. Every one keeps the boss_telegraph
# opening, so all read as "Brindle is about to hit", and goes its own way after it. An id not named here
# (the Mind's, the Warden's) keeps the shared boss_telegraph.
const BRINDLE_TELEGRAPHS := {
	"crane_sweep": "tele_crane_sweep", "slag_ring_a": "tele_slag_ring", "slag_ring_b": "tele_slag_ring",
	"charge": "tele_charge", "charge_wall": "tele_charge_wall", "eject": "tele_eject",
}


# Danger is never quantized: the telegraph sounds the frame the boss winds up, and
# the shorter the warning the higher it sits, so a quick swing reads as urgent.
func _on_boss_telegraph(attack_id: String, seconds_until: float) -> void:
	if engine.track == "warden":
		engine.parameter_danger("boss_attack_telegraphed")
	play("boss_attack_telegraphed", 0.0, Harmony.ratio(lerpf(3.0, 0.0, clampf(seconds_until / 1.5, 0.0, 1.0))), "SFX", String(BRINDLE_TELEGRAPHS.get(attack_id, "")))


# A mini-boss's later phase (fight_phases.gd): its live anthem moment moves to the phase
# variant, "<tune>-heavy", on the next downbeat, when that tune's pack is on disk. Bosses
# follow boss_phase_changed (phase_music) instead.
func _on_fight_phase(fight_id: String, phase: int, _phases: int) -> void:
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


# A cued follow-up's ratchet: never quantized, it is the warning the short tell leans on.
func _on_attack_cued(_fight_id: String, _attack_id: String, _seconds_until: float) -> void:
	play("attack_cued")


# Weak-point hits climb the pentatonic like a combo, so a string of them sings.
func _on_weak_point(_point_id: String) -> void:
	var now := Time.get_ticks_msec()
	_weak_combo = mini(_weak_combo + 1, 7) if now - _weak_last < KILL_COMBO_WINDOW_MS else 0
	_weak_last = now
	play("boss_weak_point_hit", 0.0, Harmony.ratio(Harmony.pentatonic_step(_weak_combo)))


# A bounced hit clanks lower the further you are from breaking through.
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
	# The momentum faders: rolling speed as a fraction of top speed drives the drums, and
	# the chain length ((links - 1) / 3: a third at 2, full at 4) opens the lead stem.
	values["speed"] = ctx.player.speed_fraction()
	values["chain"] = chain_fader(int(ctx.player.chain.combo) if ctx.player.get("chain") != null else 0)
	var map_id: String = ctx.flow.stage_def().get("map", "")
	if map_id != _parameter_map:
		_parameter_map = map_id
		_parameter_graph = null
		var path := "res://assets/park/%s/graph.bin" % map_id
		# Shared with activities, which reads it on stage entry, so the first sample costs no read.
		if map_id.begins_with("park_") and FileAccess.file_exists(path):
			_parameter_graph = Activities.shared_graph(path)
	if _parameter_graph != null:
		var span: float = _parameter_graph.d_landmark(_parameter_graph.spawn_node)
		var remaining: float = _parameter_graph.d_landmark(at)
		if span > 0.0 and is_finite(remaining):
			values["approach"] = 1.0 - remaining / span
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
	cue_log.append(["pressure_changed", "music_pressure", "music", engine.clock, 1.0])
	if not engine.parameter_source.is_valid():
		engine.set_pressure(pressure)
	if ace_playing() and not engine.parameter_source.is_valid():
		ace.set_pressure(pressure)


# Flow facts arrive in bursts inside one frame (a clear and the next stage; a run and
# stage 1; the last clear and the run end). They are read together once per frame so
# each burst becomes one musical phrase instead of a pile of stingers.
func _flush_flow() -> void:
	if _flow_queue.is_empty():
		return
	var burst := _flow_queue
	_flow_queue = []
	var kinds := burst.map(func(item: Array): return item[0])
	# A new run, the menu or a stage takes the band from a lost summary still waiting on its beat.
	if "run" in kinds or "idle" in kinds or "stage" in kinds:
		_summary_due = -1
	for item in burst:
		match item[0]:
			"run":
				_radio_drop("flow")
				_disarm_launch()
				engine.cancel_pending()
				var start := on_beat("run_started", 0.0, true)
				if start >= 0:
					engine.schedule_restart(start, MusicEngine.PLAY, _stage_theme(1))
				_ace_stage(1, start)
			"world":
				# The world's stinger on the lane, after the run's and before the stage's (the
				# bus emits world_entered before stage_entered); a launch's landing replaces
				# only the stage hit.
				on_beat("world_entered", 0.0, true, 1, SfxBank.world_stinger(item[1]))
			"stage":
				var stage: int = item[1]
				var retry: bool = item[2]
				if not retry and "run" in kinds:
					continue
				if radio_hold != "":
					# The radio keeps the air: the stage hit sounds on its beat, and the track
					# drops back in on the landing after a launch, else now.
					on_beat("stage_entered", 0.0, true, clampi(stage, 1, 4))
					if not retry and _launch_stage:
						_launch_stage = false
						_radio_respin_due = true
					else:
						_radio_respin()
					continue
				if not retry and _launch_stage:
					# The landing drop announces this stage.
					_launch_stage = false
					_ace_stage(stage, -1)
					continue
				if retry:
					# A pickup fill back into the groove, then the stage hit on its beat.
					engine.cancel_pending()
					var back := engine.retry_restart(MusicEngine.PLAY, _stage_theme(stage))
					_ace_stage(stage, back)
					engine.schedule_stinger_at(Rows.sound("stage_entered"), back)
					cue_log.append(["stage_entered", Rows.sound("stage_entered"), "beat", back, 1.0])
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
				# Mid-launch the build carries the music; the jingle rings over it.
				if start >= 0 and not _launch_armed:
					engine.schedule_cadence(start)
			"end":
				_radio_drop("flow")
				var won: bool = item[1]
				# A chain the run's end cut short never lands over the summary.
				_streak_landed_ms = kill_streak.last_ms
				# A death in this burst holds the recorded band to its beat (_ace_end_at). The
				# lost summary's pack waits for that beat: starting it now would swap the packs
				# and cut the band mid-beat.
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
					# on_beat returns -1 until sound is ready, so this is the guarded handoff for both outcomes.
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
				engine.cancel_pending()
				# A chain the death cut short never lands: the band reads PLAY until the boom's beat.
				_streak_landed_ms = kill_streak.last_ms
				# The band, recorded or synth, plays to the next beat and ends there under the
				# boom. The death cue itself sounded on the death's frame (_on_died).
				var at := engine.death_break()
				_ace_end_at(at)
				if sound_ready:
					for i in DEATH_FALL.size():
						_note_at("player_died", DEATH_FALL_VOICE, DEATH_FALL[i], at + i * grid_unit(2), SfxBank.DEATH_FALL_DB, true)
			"idle":
				_radio_drop("flow")
				var at := engine.next_beat()
				engine.schedule_mode(at, MusicEngine.IDLE)
				# The title's own theme, kept across the class select.
				if sound_ready:
					engine.menu_theme("title", true, at)
					_menu_home(at)
			"unseal":
				_release_answered = false
				# The break is the synth band's when an ultimate holds the recorded one.
				_ult_band_stays_off()
				engine.parameters_warden_broken()
				_unseal_ms = Time.get_ticks_msec()
				if ace_playing():
					ace.warden_broken()
				if engine.track == "warden" and sound_ready:
					# The heaviest drop of the stage, on the next beat, with the unseal
					# stinger on the same downbeat.
					var at := engine.unseal_drop()
					engine.schedule_stinger_at(Rows.sound("beacon_unsealed"), at, story_duck_db("beacon_unsealed"))
					cue_log.append(["beacon_unsealed", Rows.sound("beacon_unsealed"), "beat", at, 1.0])
				else:
					# A Warden broken inside its pivot bar: the track switch is void.
					engine.drop_pending_track("warden")
					on_beat("beacon_unsealed", 0.0, true)
			"gates":
				# The unseal stinger already says the gates are open.
				if "unseal" in kinds or Time.get_ticks_msec() - _unseal_ms < 2500:
					continue
				on_beat("reward_offered", 0.0, true)
			"milestone":
				on_beat("milestone_won", 0.0, true)


# --- Mixer keys ---------------------------------------------------------------------
# - and = move the music, [ and ] move the effects, M mutes everything.

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


# The player's slider times the bus row and the state's offset. Ambient follows the effects slider.
func _apply_volumes() -> void:
	for bus in BUSES:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			continue
		var level := float(volumes.get(bus, volumes["SFX"]))
		AudioServer.set_bus_volume_linear(index, level * db_to_linear(BUSES[bus] + float(mix_db.get(bus, 0.0))))
		AudioServer.set_bus_mute(index, muted or (radio_silenced and bus == "Music"))


# The pause menu's volume rows set a bus to a level; the keys above nudge it.
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


# --- P-C Sable audio ---------------------------------------------------------------
# Reuse the shipped octave, ratchet and motif recipes at the bank's calibrated levels.
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


# --- P-C Cannon cues -------------------------------------------------------------------
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


# --- P-C Tarn line_claw_drag ---
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
	# A rung of the reward ladder per chain link, like the bite (never a semitone).
	var pitch := Harmony.ratio(live_key() + Harmony.pentatonic_step(clampi(int(ctx.player.chain.combo) - 1, 0, CHAIN_STEPS)))
	if _admit("line_skill_fired", "line_claw_drag", pitch):
		_start("line_skill_fired", "line_claw_drag", _line_claw_stream, SfxBank.trim_db("line_claw_drag") + PRIORITY_DB[Rows.priority("line_skill_fired")], pitch, "SFX")
# --- end Tarn ---


# --- P-C Rivet line_drive ---
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
	# Playback lasts 1 / pitch of the stored buffer time. Physical offsets divide by that ratio.
	var duration_ratio := 1.0 / pitch
	if on == "body":
		# The stab climbs the reward ladder from the hammered note, a rung per chain link.
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
# --- end Rivet ---
# --- P-C Tally audio ---
# Notes are baked at their written pitch, then transposed together into the live key.
# The four bank recipes carry the paper punch and bell independently of cog_tick.
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
# SOUND-STORY.md:31, the tempo her strokes keep when no music plays.
const TALLY_HOME_BPM := 172.0
var _tally_notes: Array = []
var _tally_beat := -1
var _tally_streams := {}


func _wire_tally(events) -> void:
	events.special_used.connect(func(id: String, _at: Vector3):
		if id == "gather_plate":
			_tally_cue("tally_plate", 0))
	events.line_skill_fired.connect(func(id: String, _target: Node3D, _at: Vector3, _on: String):
		if id != "link_clips":
			return
		var combat = ctx.get("spawner") if ctx != null else null
		var clips: int = int(combat.last_card.get("hits", 1)) if combat != null else 1
		# Her stepwise D, E, F climbs D dorian a step per chain link (never chromatically): every
		# clip stays in the band's mode and off the tritone, which a moved phrase would reach.
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


# Seconds per sixteenth of the music playing, or of the motif's 172 BPM home with none.
func _tally_sixteenth() -> float:
	var bpm: float = engine.bpm() if engine != null and engine.mode == MusicEngine.PLAY else 0.0
	return 60.0 / (bpm if bpm > 0.0 else TALLY_HOME_BPM) / TALLY_SIXTEENTHS


# Queues one note of a TALLY_CUES row: step index `step`, lifted `lift` steps of D dorian, `slot`
# sixteenths from now.
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


# Plays due notes, and one ledger stroke per flight beat of her set piece (D, E, F, G, round again).
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
# --- end Tally ---


# --- The set director ----------------------------------------------------------------------

# The DJ behind the recorded band (set_director.gd, SOUND-BIBLE "The set"), behind the launch
# switch set_director. Half a bar before each bar line of the sounding band it reads the room
# and books that bar's plan: stem trims on the bar, and June's answer as a stinger on the bar.
# It never moves game time and never touches the synth band.
var set_director := SetDirector.new()
var _set_bar_at := -1
var _set_overtime := false
var _set_incoming_at := -1.0
var _set_answer := ""
var _set_answer_at := -1
const SET_ANSWER_YIELDS := ["open", "drop", "break"]


func set_director_on() -> bool:
	var tuning = ctx.get("tuning") if ctx != null else null
	return tuning != null and tuning.option(Tuning.SET_DIRECTOR_KEY) == "on"


func _tend_set() -> void:
	if not ace_playing() or not ace.mode in ["level", "warden", "piece"] or ace.section == "" or not set_director_on():
		_drop_set_answer()
		if _set_bar_at >= 0:
			_set_bar_at = -1
			set_director.reset()
		return
	if _set_answer != "" and _set_answer_spoiled():
		_drop_set_answer()
		ace.trim_at(maxi(ace.clock, _set_answer_at - grid_unit(4)), {}, grid_unit(4))
	var at: int = ace.next_bar()
	if at == _set_bar_at or at - ace.clock > ace.grid_bar / 2:
		return
	_set_bar_at = at
	var plan := set_director.read(set_room(at))
	var ramp := grid_unit(4)
	if not plan.trims.is_empty() or plan.sweep > 0.0:
		ace.trim_bar(at, plan.trims, ace.grid_bar, ramp, plan.sweep)
	if plan.answer != "":
		_set_answer = SfxBank.SET_ANSWER + plan.answer
		_set_answer_at = at
		engine.schedule_stinger_at(_set_answer, at, PRIORITY_DB[1], false, ramp)
		cue_log.append(["set_answer", _set_answer, "grid", at, 1.0, PRIORITY_DB[1] + SfxBank.trim_db(_set_answer)])
	if plan.move != "hold":
		cue_log.append(["set_move", plan.move, plan.mood, at, 1.0])


# June's booked answer gives way when the bar it was booked for turns into a fight section,
# a warning, a caller or a pilot quote after it was booked, through to the end of its bar.
func _set_answer_spoiled() -> bool:
	if ace.clock >= _set_answer_at + ace.grid_bar:
		_set_answer = ""
		return false
	var next := String(ace.pending.get("section", ""))
	if ace.mode == "piece" or ace.section in SET_ANSWER_YIELDS or next in SET_ANSWER_YIELDS:
		return true
	return clock < _focus_until or _warden_charging or _set_busy()


func _drop_set_answer() -> void:
	if _set_answer != "":
		engine.cancel_stinger(_set_answer)
		cue_log.append(["set_answer_dropped", _set_answer, "grid", ace.clock, 1.0])
		_set_answer = ""


# Another melodic cue owns the bar: a caller still talking, or a pilot quote inside two bars.
func _set_busy() -> bool:
	var quoted := float(_gates.get("pilot_quote", -1000.0)) - pilot_quote_gap()
	return clock < float(_gates.get("call_in", -1000.0)) or clock - quoted < 2.0 * float(ace.grid_bar) / Harmony.RATE


# The room as the director reads it for the bar at transport sample at.
func set_room(at: int) -> Dictionary:
	var room := sample_run_parameters()
	room["sample"] = at
	# Hanging on means armour lost to hits, not a shell still empty at the start of a run.
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
	# A section the band directs itself (a pivot, the Warden's break, return and home) is its own move.
	if ace.section in ace.PROTECTED:
		room["fight"] = "directed"
	# A flat pack (a miniboss, Brindle or a moment tune plays one "main" section) is an anthem:
	# June stays out, the turnaround moves still play.
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
