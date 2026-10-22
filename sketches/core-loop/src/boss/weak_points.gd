extends RefCounted

# A boss's named weak points as one rule object with no scene access (challenge lane, #241).
# A point is SHUT until a tell opens it; a reel impact on an OPEN point lands at full posture
# gain and wears its seal, and a broken seal removes that point's attack family. Every other hit
# is chipped. judge() answers what a hit would do and changes nothing, apply() is the one place
# a hit changes state, step() runs the re-seal clock and the crew's fit clock.
# Off (no parts, or enabled false) is the identity: judge() scales nothing and no state moves.

enum { SHUT, OPEN, BROKEN }

const CHIP := 0.3
const OPEN_SECONDS := 6.0
const FIT_SECONDS := 3.5
const FIT_MIN := 2
# An opened point stays open at least this long, by any re-seal path: ChallengeDials.TELL_FLOOR, so the opening reads.
const OPEN_MIN := 0.6

# The numbers this rule runs on. A caller's dictionary overrides any of them by key
# ("chip", "open_seconds", "fit_seconds", "fit_min"); a missing key keeps the constant above.
var chip := CHIP
var open_seconds := OPEN_SECONDS
var fit_seconds := FIT_SECONDS
var fit_min := FIT_MIN
var enabled := true

# id -> {seal_hp, max_hp, removes, state, opened_at, first_open, fit_since, fitters}
var _parts := {}


# parts: [{id, seal_hp, removes}]. An empty list is the off rule.
func _init(parts := [], numbers := {}, on := true) -> void:
	chip = float(numbers.get("chip", CHIP))
	open_seconds = float(numbers.get("open_seconds", OPEN_SECONDS))
	fit_seconds = float(numbers.get("fit_seconds", FIT_SECONDS))
	fit_min = int(numbers.get("fit_min", FIT_MIN))
	enabled = on
	for part in parts:
		var hp := float(part.get("seal_hp", 0.0))
		_parts[String(part["id"])] = {"seal_hp": hp, "max_hp": hp, "removes": String(part.get("removes", "")),
				"state": SHUT, "opened_at": 0.0, "first_open": 0.0, "fit_since": -1.0, "fitters": 0}


# The identity rule: every hit counts in full and nothing ever changes.
static func off() -> RefCounted:
	return load("res://src/boss/weak_points.gd").new([], {}, false)


func active() -> bool:
	return enabled and not _parts.is_empty()


# hit: {point ("" for the body), reel, punch, gain}. The answer is
# {gain_scale, point, damage, broke, removes}.
func judge(hit: Dictionary) -> Dictionary:
	var id := String(hit.get("point", ""))
	var result := {"gain_scale": 1.0, "point": id, "damage": 0.0, "broke": false, "removes": ""}
	if not active():
		return result
	if bool(hit.get("reel", false)) and state(id) == OPEN:
		var part: Dictionary = _parts[id]
		var punch := maxf(0.0, float(hit.get("punch", 0.0)))
		result["damage"] = minf(punch, float(part["seal_hp"]))
		result["broke"] = punch >= float(part["seal_hp"])
		result["removes"] = part["removes"] if result["broke"] else ""
		return result
	result["gain_scale"] = chip
	return result


# Lands a judged answer. Only a reel impact on an OPEN point (damage or a break) changes anything;
# it also restarts that point's re-seal clock.
func apply(answer: Dictionary, now: float) -> void:
	if not active():
		return
	var id := String(answer.get("point", ""))
	if state(id) != OPEN or float(answer.get("gain_scale", 1.0)) < 1.0:
		return
	var part: Dictionary = _parts[id]
	part["opened_at"] = now
	part["seal_hp"] = maxf(0.0, float(part["seal_hp"]) - float(answer.get("damage", 0.0)))
	if bool(answer.get("broke", false)):
		part["seal_hp"] = 0.0
		part["state"] = BROKEN
		part["fit_since"] = -1.0


# A tell opens a SHUT point. False when the id is unknown, the point is not SHUT, or the rule is off.
func open(id: String, now: float) -> bool:
	if not active() or state(id) != SHUT:
		return false
	var part: Dictionary = _parts[id]
	part["state"] = OPEN
	part["opened_at"] = now
	part["first_open"] = now
	part["fit_since"] = now if int(part["fitters"]) >= fit_min else -1.0
	return true


# The crew: a fitter joins a point, and the fit clock runs while fit_min or more are on it.
func begin_fit(id: String, now: float) -> void:
	if not active() or not _parts.has(id):
		return
	var part: Dictionary = _parts[id]
	part["fitters"] = int(part["fitters"]) + 1
	if int(part["fitters"]) >= fit_min and float(part["fit_since"]) < 0.0 and int(part["state"]) == OPEN:
		part["fit_since"] = now


# A fitter is knocked off (or gives up): one fewer, and the clock stops below fit_min.
func knock_fit(id: String) -> void:
	if not active() or not _parts.has(id):
		return
	var part: Dictionary = _parts[id]
	part["fitters"] = maxi(0, int(part["fitters"]) - 1)
	if int(part["fitters"]) < fit_min:
		part["fit_since"] = -1.0


func fitters(id: String) -> int:
	return int(_parts[id]["fitters"]) if _parts.has(id) else 0


# Re-seals an OPEN point whose window ran out or whose fit was held long enough, never before OPEN_MIN
# seconds after it opened.
func step(now: float) -> void:
	if not active():
		return
	for id in _parts:
		var part: Dictionary = _parts[id]
		if int(part["state"]) != OPEN:
			continue
		if now - float(part["first_open"]) < OPEN_MIN:
			continue
		var fitted: bool = float(part["fit_since"]) >= 0.0 and now - float(part["fit_since"]) >= fit_seconds
		if fitted or now - float(part["opened_at"]) >= open_seconds:
			part["state"] = SHUT
			part["fit_since"] = -1.0


func has(id: String) -> bool:
	return _parts.has(id)


# SHUT, OPEN or BROKEN; an unknown id (the body) reads SHUT.
func state(id: String) -> int:
	return int(_parts[id]["state"]) if _parts.has(id) else SHUT


func open_points() -> Array:
	var out := []
	for id in _parts:
		if int(_parts[id]["state"]) == OPEN:
			out.append(id)
	return out


func seal_hp(id: String) -> float:
	return float(_parts[id]["seal_hp"]) if _parts.has(id) else 0.0


# The attack families whose point is BROKEN, without repeats.
func removed_families() -> Array:
	var out := []
	for id in _parts:
		var family := String(_parts[id]["removes"])
		if int(_parts[id]["state"]) == BROKEN and family != "" and not out.has(family):
			out.append(family)
	return out
