extends Node

const Panels := preload("res://src/build/panels.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const Palette := preload("res://src/core/palette.gd")

# How a grey panel pickup lands (IL-01 card section 6): the panel's name and step pop at the
# ball for POP_LIFE in the comic word style, a short ratchet tick plays, and each panel in a
# STREAK_MS streak plays the next note of a pentatonic phrase in the live combat key. The
# phrase is drawn from the run seed, so every run has its own tune and a replay keeps it; a
# reel or dunk drop adds the pinball jackpot over the note. Reduced motion tames the pop (a
# smaller word with no slam or slide, machine_fx's own rule).

const POP_LIFE := 1.2
const POP_HEIGHT := 2.6
# The pop's letters stand about 4.6 percent of the view's height, six tenths of the player's
# ordinary hit word (player_fx.gd WORD_SCREEN), and the longest line 3.3: picked from five
# measured candidates on 10 Nov 2026 (design-v3/SIGHT-PERSONA.md section 7, "A taste call").
const POP_SIZE := 0.5
const POP_SIZE_REDUCED := 0.4
const STREAK_MS := 2000
const PHRASE_LENGTH := 8
# The phrase walks the reward pentatonic (Harmony.PENTATONIC rungs) from the tonic, a step
# or two at a time, so it sings rather than jumps.
const PHRASE_STEPS := [-1, 1, 1, 2, -2, 1]

var ctx
var audio
var machine_fx
var phrase: Array = []
var streak := 0
var _last_ms := -100000
var _phrase_seed := -1
# [id, rung, jackpot] per pickup, for tests and captures.
var played: Array = []


func setup(ctx_ref, audio_ref, machine_fx_ref) -> void:
	ctx = ctx_ref
	audio = audio_ref
	machine_fx = machine_fx_ref
	name = "PanelFx"
	ctx.events.panel_gained.connect(_on_panel_gained)
	ctx.events.run_started.connect(func(_class_id: String): streak = 0)


# The run's phrase: PHRASE_LENGTH rungs of the reward pentatonic, seeded from the run seed.
static func phrase_for(run_seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, "panel_phrase"])
	var rungs := [0]
	while rungs.size() < PHRASE_LENGTH:
		var next: int = clampi(int(rungs.back()) + int(PHRASE_STEPS[rng.randi_range(0, PHRASE_STEPS.size() - 1)]), 0, 7)
		rungs.append(next)
	return rungs


# The rung a pickup at `now_ms` plays, advancing the streak.
func next_rung(now_ms: int) -> int:
	var seed_now: int = ctx.run.run_seed if ctx != null and ctx.run != null else 0
	if seed_now != _phrase_seed or phrase.is_empty():
		_phrase_seed = seed_now
		phrase = phrase_for(seed_now)
	streak = streak + 1 if now_ms - _last_ms < STREAK_MS else 0
	_last_ms = now_ms
	return int(phrase[streak % phrase.size()])


func _on_panel_gained(panel_id: String, _count: int, _at: Vector3, jackpot: bool) -> void:
	var rung := next_rung(Time.get_ticks_msec())
	played.append([panel_id, rung, jackpot])
	if played.size() > 64:
		played.pop_front()
	if audio != null:
		audio.play("panel_gained")
		audio.play("panel_gained", 0.0, Harmony.ratio(Harmony.pentatonic_step(rung)), "SFX", "panel_note")
		if jackpot:
			audio.play("panel_gained", 0.0, 1.0, "SFX", "panel_jackpot")
	if machine_fx != null and ctx.player != null:
		var reduced: bool = machine_fx.reduced_motion
		machine_fx.word(Panels.pop_text(panel_id), ctx.player.shown_position() + Vector3.UP * POP_HEIGHT,
			Palette.AMBER if jackpot else Palette.SAND, true, POP_LIFE, POP_SIZE_REDUCED if reduced else POP_SIZE)
