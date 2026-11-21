extends Resource

# One weapon's emission pattern as data (TADR-008): how many bolts a volley throws,
# at what angles, how the volley turns from one trigger pull to the next, and how
# each bolt travels. Parts never touch a weapon's code; they name transformer ids,
# and combat folds those ids over the weapon's base pattern. README.md in this folder
# is the contract writer B's parts use.
#
# Geometry of a volley, around the aim line (the centre ray the reticle marks):
# - arms == 1: a flat fan of `count` bolts, `spread_deg` apart, across the aim line.
# - arms >= 2: one centre bolt on the aim line, plus `arms` radial arms spaced evenly
#   around it. Each arm holds `count` bolts, the first `arm_offset_deg` off the aim
#   line and each next one `spread_deg` further out. A cross is four arms.
# - rotation_deg rolls the whole pattern about the aim line; spin_deg adds that much
#   roll per volley, which is what turns a cross into a spiral.
# - wave_amp (metres) and wave_hz corkscrew each off-centre bolt around its own line.
#   The centre bolt never waves, so the reticle's point is always hit dead on.

const MAX_VOLLEY := 16
const MAX_RATE := 20.0
# A rate of 0 makes the cooldown infinite (the gun dies for the run) and one below 0 fires
# every tick, so no transformer or recipe takes a pattern under one shot in twenty seconds
# (the slowest authored rate is 0.25).
const MIN_RATE := 0.05
const MAX_WAVE := 1.2
const MAX_ARM_OFFSET := 14.0
const MAX_ARMS := 8
const MAX_PIERCE := 3

@export var count := 1
@export var spread_deg := 0.0
@export var arms := 1
@export var arm_offset_deg := 0.0
@export var rotation_deg := 0.0
@export var spin_deg := 0.0
@export var wave_amp := 0.0
@export var wave_hz := 0.0
# Machines a bolt passes through before it stops (helix drill).
@export var pierce := 0
@export var damage := 10.0
@export var rate := 5.0
@export var range_m := 70.0
@export var speed := 120.0
@export var bolt_radius := 0.3
@export var knock := 8.0
@export var chain_jumps := 0
@export var chain_range := 0.0
@export var chain_falloff := 0.7
# Zero means no lattice bonus; its final jump can differ from the weapon falloff.
@export var lattice_chain_falloff := 0.0
# Class-mod scales the specials read: the pylon's opening burst and the runner's overdrive.
@export var burst_scale := 1.0
@export var special_scale := 1.0

const FIELDS := ["count", "spread_deg", "arms", "arm_offset_deg", "rotation_deg", "spin_deg",
	"wave_amp", "wave_hz", "pierce", "damage", "rate", "range_m", "speed", "bolt_radius", "knock",
	"chain_jumps", "chain_range", "chain_falloff", "lattice_chain_falloff", "burst_scale", "special_scale"]

# The transformer catalogue. Each row is pure data: `add` then `mul` then `min` (a
# floor), applied in that order, once per stack. Writer B's parts name these ids.
const TRANSFORMERS := {
	"cross_split": {
		"label": "Cross split", "text": "every shot splits into a cross around your aim",
		"add": {"arms": 3}, "min": {"arm_offset_deg": 7.0},
	},
	"spiral_wave": {
		"label": "Spiral wave", "text": "the spread turns each shot and bolts corkscrew",
		"add": {"spin_deg": 23.0, "wave_amp": 0.35}, "min": {"arms": 2, "arm_offset_deg": 4.0, "wave_hz": 3.0},
	},
	"fan_spread": {
		"label": "Fan spread", "text": "shots fan into a 5-round cone",
		"add": {"count": 4}, "mul": {"damage": 0.65}, "min": {"spread_deg": 7.0},
	},
	"helix_drill": {
		"label": "Helix drill", "text": "shots corkscrew through two machines",
		"add": {"count": 2, "pierce": 1, "wave_amp": 0.35}, "mul": {"damage": 0.75}, "min": {"spread_deg": 6.0, "wave_hz": 3.0},
	},
	"chain_arc": {
		"label": "Chain arc", "text": "hits arc to one more enemy nearby",
		"add": {"chain_jumps": 1, "chain_range": 4.0}, "min": {"chain_range": 9.0},
	},
	"damage_tier": {
		"label": "Hot rounds", "text": "+25% weapon damage",
		"mul": {"damage": 1.25},
	},
	"rate_tier": {
		"label": "Fast cycle", "text": "+20% fire rate",
		"mul": {"rate": 1.2},
	},
	"range_tier": {
		"label": "Long barrel", "text": "+25% range, +10% bolt speed",
		"mul": {"range_m": 1.25, "speed": 1.1},
	},
	"capacitor": {
		"label": "Pylon capacitor", "text": "the pylon's discharge hits harder and arcs further",
		"add": {"chain_range": 3.0}, "mul": {"burst_scale": 1.5},
	},
	"overclock": {
		"label": "Overclock", "text": "+30% fire rate and a longer overdrive",
		"mul": {"rate": 1.3, "special_scale": 1.3},
	},
}


static func make(values: Dictionary) -> Resource:
	var pattern: Resource = load("res://src/combat/pattern.gd").new()
	for key in values:
		pattern.set(key, values[key])
	return pattern


func copy() -> Resource:
	var twin: Resource = load("res://src/combat/pattern.gd").new()
	for key in FIELDS:
		twin.set(key, get(key))
	return twin


static func has_transformer(id: String) -> bool:
	return TRANSFORMERS.has(id)


# A new pattern with every id applied in order. Unknown ids are skipped, so a part
# with no weapon effect costs nothing. The caps are applied last, whatever stacked.
func transformed(ids: Array) -> Resource:
	var out: Resource = copy()
	for id in ids:
		if TRANSFORMERS.has(id):
			out._apply(TRANSFORMERS[id])
	out._clamp()
	return out


func _apply(row: Dictionary) -> void:
	var add: Dictionary = row.get("add", {})
	for key in add:
		set(key, get(key) + add[key])
	var mul: Dictionary = row.get("mul", {})
	for key in mul:
		set(key, get(key) * mul[key])
	var floor_row: Dictionary = row.get("min", {})
	for key in floor_row:
		set(key, maxf(get(key), floor_row[key]) if typeof(get(key)) == TYPE_FLOAT else maxi(get(key), floor_row[key]))


# The visual-clarity caps (principle 4): stacking can multiply damage without limit,
# but never the number of things on screen or how far they wander off the aim line.
func _clamp() -> void:
	arms = clampi(arms, 1, MAX_ARMS)
	count = clampi(count, 1, MAX_VOLLEY)
	rate = clampf(rate, MIN_RATE, MAX_RATE)
	wave_amp = minf(wave_amp, MAX_WAVE)
	pierce = clampi(pierce, 0, MAX_PIERCE)
	arm_offset_deg = minf(arm_offset_deg, MAX_ARM_OFFSET)


func volley_size() -> int:
	var raw := count if arms <= 1 else 1 + arms * count
	return mini(raw, MAX_VOLLEY)


# The bolt layout of volley number `volley`, centre first and then inner to outer, so
# trimming to MAX_VOLLEY drops the outermost bolts. Each entry is a Dictionary:
# `dir` (unit), `phase` (radians, the arm's roll, for the corkscrew) and `centre`.
func layout(forward: Vector3, volley: int) -> Array:
	var fwd := forward.normalized()
	var up_hint := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var right := fwd.cross(up_hint).normalized()
	var up := right.cross(fwd).normalized()
	var roll := deg_to_rad(rotation_deg + spin_deg * volley)
	var out := []
	if arms <= 1:
		for i in count:
			var off := (i - (count - 1) * 0.5) * spread_deg
			var phase := roll if off >= 0.0 else roll + PI
			out.append({"dir": _tilt(fwd, right, up, deg_to_rad(absf(off)), phase), "phase": phase, "centre": is_zero_approx(off)})
	else:
		out.append({"dir": fwd, "phase": roll, "centre": true})
		# Bolts further out along an arm step by the fan spread, or 3 degrees for a
		# single-line weapon, so no two bolts of a volley ever share a line.
		var step := spread_deg if spread_deg > 0.1 else 3.0
		for j in count:
			for a in arms:
				var phase := roll + TAU * a / arms
				var theta := deg_to_rad(arm_offset_deg + step * j)
				out.append({"dir": _tilt(fwd, right, up, theta, phase), "phase": phase, "centre": false})
	if out.size() > MAX_VOLLEY:
		out.resize(MAX_VOLLEY)
	return out


func directions(forward: Vector3, volley: int) -> Array:
	var dirs := []
	for bolt in layout(forward, volley):
		dirs.append(bolt["dir"])
	return dirs


static func _tilt(fwd: Vector3, right: Vector3, up: Vector3, theta: float, phase: float) -> Vector3:
	if is_zero_approx(theta):
		return fwd
	var side := right * cos(phase) + up * sin(phase)
	return (fwd * cos(theta) + side * sin(theta)).normalized()
