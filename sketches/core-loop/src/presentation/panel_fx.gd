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
# A pop that lands while the last one is still up takes the next free one of POP_ROWS lines, POP_LINE
# higher, so pickups in a row never print on top of each other. Two lines only: at the play camera a
# third would stand across the objective plate. While both lines are held a pop waits for one to clear
# (a cleared camp drops several panels at once, and a third pop on the bottom line printed over the
# first, play finding from the goal plate film). The step is about one and a half of the pop's letter lines
# (0.48 m at POP_SIZE), which keeps the upper line under the hint line below the objective plate.
const POP_LINE := 0.7
const POP_ROWS := 2
# A pop never shows later than POP_LIFE after its pickup sound (sight and sound of one event are
# paired, PF-19). A line is held a frame's slack short of POP_LIFE so a waiting pop is up inside
# that window, and at most POP_ROWS pops wait: a longer pile folds into the lines waiting, as
# "+3 FIN" when they are one kind, "+3 PANELS" when they are not.
const ROW_HOLD := POP_LIFE - 0.05
const MIXED_NOUN := "PANELS"
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
# Seconds each pop line is still held, and the pops waiting for a line: [panel_id, jackpot, count].
# A folded line of mixed kinds has the id "".
var _row_left: Array = []
var _waiting: Array = []


func setup(ctx_ref, audio_ref, machine_fx_ref) -> void:
	ctx = ctx_ref
	audio = audio_ref
	machine_fx = machine_fx_ref
	name = "PanelFx"
	ctx.events.panel_gained.connect(_on_panel_gained)
	ctx.events.run_started.connect(_on_run_started)


func _on_run_started(_class_id: String) -> void:
	streak = 0
	_waiting.clear()
	_row_left.clear()


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
	_wait(panel_id, jackpot)
	_release()


# A pop joins the line of pops waiting for a row; past POP_ROWS it folds into one already waiting.
func _wait(panel_id: String, jackpot: bool) -> void:
	if _waiting.size() < POP_ROWS:
		_waiting.append([panel_id, jackpot, 1])
		return
	var line: Array = _waiting.back()
	for waiting in _waiting:
		if waiting[0] == panel_id:
			line = waiting
			break
	if line[0] != panel_id:
		line[0] = ""
	line[1] = bool(line[1]) or jackpot
	line[2] = _count(line) + 1


static func _count(pop: Array) -> int:
	return int(pop[2]) if pop.size() > 2 else 1


# The words of a waiting pop: its panel's own pop, or "+N NOUN" for a folded line.
static func pop_words(pop: Array) -> String:
	var n := _count(pop)
	if n == 1:
		return Panels.pop_text(pop[0])
	var noun: String = String(Panels.row(pop[0]).get("noun", "")).to_upper() if pop[0] != "" else ""
	return "+%d %s" % [n, noun if noun != "" else MIXED_NOUN]


# Shows waiting pops while a line is free, oldest first.
func _release() -> void:
	while not _waiting.is_empty():
		var lift := next_pop_lift()
		if lift < 0.0:
			return
		var pop: Array = _waiting.pop_front()
		if machine_fx == null or ctx == null or ctx.player == null:
			continue
		var reduced: bool = machine_fx.reduced_motion
		machine_fx.word(pop_words(pop), ctx.player.shown_position() + Vector3.UP * (POP_HEIGHT + lift),
			Palette.AMBER if pop[1] else Palette.SAND, true, POP_LIFE, POP_SIZE_REDUCED if reduced else POP_SIZE)


# How far above POP_HEIGHT the next pop stands, holding that line for POP_LIFE: the lowest free line,
# or -1 while every line is held.
func next_pop_lift() -> float:
	if _row_left.size() != POP_ROWS:
		_row_left.resize(POP_ROWS)
		_row_left.fill(0.0)
	for row in POP_ROWS:
		if float(_row_left[row]) <= 0.0:
			_row_left[row] = ROW_HOLD
			return row * POP_LINE
	return -1.0


func _process(delta: float) -> void:
	for row in _row_left.size():
		_row_left[row] = maxf(float(_row_left[row]) - delta, 0.0)
	if not _waiting.is_empty():
		_release()
