extends RefCounted

# Heat on the shell (docs/design/loops.md, Spec 1; Andrew approved the top three loops on
# 11 Nov 2026 18:42Z and asked for them before the sitting). Speed and skims fill it; at the
# top the next hit detonates; while it is high, every hit on the ball lands harder. The player
# owns the one instance and ticks it; combat's damage door reads taken_scale() and spends the
# cook-off on the hull; presentation and audio read the signals, so the shell, the sound and
# the pad cannot drift apart. It is called Redline in code because "heat" already names the
# overdrive rim (player_fx.gd) and an active's burn (audio.gd).
#
# Behind `--heat`: "off" (the game as it was), "watch" (counts the seconds and skims, changes
# nothing, the A/B base for the kill line) and "on". Pure state: no scene, so the rule is
# testable without one.
#
# Built for the prototype (loops.md "The prototype"): two sources (blazing seconds and skims),
# the taken multiplier, the detonation and the cook-off. Cushions, stolen damage families and
# the wipeout come after the kill line is read.

const SpeedTier := preload("res://src/movement/speed_tier.gd")

const MAX := 100.0
# Start values from loops.md Spec 1. The lab tunes them.
const FILL_BLAZING_PER_S := 12.0
const FILL_SKIM := 25.0
const DRAIN_PER_S := 20.0
const HOT_AT := 50.0
# Where the shell starts to show it (band 1, the rim's first warmth).
const WARM_AT := MAX * 0.25
const HOT_DAMAGE_TAKEN := 1.5
const BLAST_RADIUS := 7.0
# The blast strikes every enemy inside the radius as a slam at this many times the force of
# the contact that set it off, with the slam's own linear falloff.
const BLAST_FORCE := 2.0
const COOK_OFF_S := 4.0
const COOK_OFF_FORCE := 0.5
# A cook-off at rest still blows: it reads the ball's speed or this, whichever is more.
const COOK_OFF_MIN_SPEED := 14.0
const COOK_OFF_SELF_HULL := 0.10
const COOK_OFF_SOURCE := "heat_cook_off"
# A skim only counts when the ball is rolling: no pay for the stall (ruling cu).
const SKIM_MIN_TIER := SpeedTier.CRUISE
# The kinds of contact a redline shell spends on: the ball's own hits, a reel impact included.
const SPEND_KINDS := ["ram", "stomp", "slam"]

const OFF := "off"
const WATCH := "watch"
const ON := "on"

var mode := OFF
var value := 0.0
# Seconds the redline shell has waited for a hit; the cook-off fires at COOK_OFF_S.
var waited := 0.0
# Counts for the run log and the kill line, kept in watch mode too.
var rolled_s := 0.0
var blazing_s := 0.0
var skims := 0
var detonations := 0
var cook_offs := 0
var hits_hot := 0

# value: 0..MAX; band: 0 cool, 1 warm (a quarter up), 2 hot (HOT_AT), 3 redline (MAX).
signal changed(value: float, band: int)
# The shell reached MAX.
signal redlined
# A contact spent the redline shell: the blast's centre and the force it strikes with.
signal detonated(at: Vector3, force: float)
# No hit came in COOK_OFF_S: the shell blew where it is.
signal cooked_off(at: Vector3, force: float)
# A skim filled the shell.
signal skimmed(at: Vector3)


func on() -> bool:
	return mode == ON


func set_mode(next: String) -> void:
	mode = next if next in [OFF, WATCH, ON] else OFF
	clear()


static func band_of(v: float) -> int:
	if v >= MAX:
		return 3
	if v >= HOT_AT:
		return 2
	if v >= WARM_AT:
		return 1
	return 0


func band() -> int:
	return band_of(value)


# How warm the shell shows, 0 below WARM_AT (or with the flag not on) to 1 at MAX.
func warmth() -> float:
	if not on() or value < WARM_AT:
		return 0.0
	return value / MAX


# 0 at WARM_AT to 1 at HOT_AT: how far the shell has turned from its first warmth to hot.
func hot_share() -> float:
	return clampf((value - WARM_AT) / (HOT_AT - WARM_AT), 0.0, 1.0)


func hot() -> bool:
	return on() and value >= HOT_AT


func redline() -> bool:
	return on() and value >= MAX


# What a hit on the ball is multiplied by right now.
func taken_scale() -> float:
	return HOT_DAMAGE_TAKEN if hot() else 1.0


# One physics tick at speed tier `tier`. `at` is the ball, for a cook-off's blast;
# `force` what a cook-off strikes with before COOK_OFF_FORCE.
func tick(delta: float, tier: int, at := Vector3.ZERO, force := 0.0) -> void:
	if mode == OFF:
		return
	if tier >= SpeedTier.CRUISE:
		rolled_s += delta
	if tier >= SpeedTier.BLAZING:
		blazing_s += delta
	if mode != ON:
		return
	if value >= MAX:
		waited += delta
		if waited >= COOK_OFF_S:
			_set_value(0.0)
			cook_offs += 1
			cooked_off.emit(at, maxf(force, COOK_OFF_MIN_SPEED) * COOK_OFF_FORCE)
		return
	if tier >= SpeedTier.BLAZING:
		_set_value(value + FILL_BLAZING_PER_S * delta)
	elif tier < SpeedTier.FAST:
		_set_value(value - DRAIN_PER_S * delta)


# A near miss: the ball was inside a committed threat and left it before it landed.
func skim(tier: int, at := Vector3.ZERO) -> bool:
	if mode == OFF or tier < SKIM_MIN_TIER:
		return false
	skims += 1
	if mode != ON or value >= MAX:
		return false
	_set_value(value + FILL_SKIM)
	skimmed.emit(at)
	return true


# A contact of `kind` landed at `at` with `force`. Returns the blast force when the shell was
# at redline and spends it, else 0.0.
func spend(kind: String, at: Vector3, force: float) -> float:
	if not redline() or not kind in SPEND_KINDS:
		return 0.0
	_set_value(0.0)
	detonations += 1
	var blast := force * BLAST_FORCE
	detonated.emit(at, blast)
	return blast


# A hit on the ball landed while hot (counted for the kill line's "deaths while hot").
func note_hit() -> void:
	if hot():
		hits_hot += 1


func clear() -> void:
	waited = 0.0
	if value != 0.0:
		_set_value(0.0)


func reset_counts() -> void:
	rolled_s = 0.0
	blazing_s = 0.0
	skims = 0
	detonations = 0
	cook_offs = 0
	hits_hot = 0


# The run log's block (run_log.gd), written only when the flag is not off.
func summary() -> Dictionary:
	return {"mode": mode, "rolled_s": snappedf(rolled_s, 0.01), "blazing_s": snappedf(blazing_s, 0.01),
		"skims": skims, "detonations": detonations, "cook_offs": cook_offs, "hits_hot": hits_hot}


func _set_value(next: float) -> void:
	var before := band()
	var was := value
	value = clampf(next, 0.0, MAX)
	if value < MAX:
		waited = 0.0
	if value == was:
		return
	changed.emit(value, band())
	if band() == 3 and before != 3:
		redlined.emit()
