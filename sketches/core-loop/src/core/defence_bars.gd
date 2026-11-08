extends RefCounted
# SG7: three defence bar classes, one regen rule and one existing palette row each, so a bar's
# look predicts how to attack it (comps/gunfire/enemies-and-bosses.md, "three-defence-bars";
# BIBLE.md:489 a committed attack means what it shows, :769 combat meanings stay consistent
# across regions). LEGIBILITY.md section 2 holds the matching row set.
#
# id        armour | shield | health, CLASS_IDS order.
# palette   the Palette constant the bar wears. No new meaning colour: armour wears the boss
#           plating brass, shield wears slate (the colour law's "not yet": burst it first), health wears
#           neutral sand. Not ANCIENT: that already means "weak point opened, hit it now".
# pattern   the cue that survives a colour-blind read (colour alone may not separate the
#           classes for a colour-blind player): segmented blocks, a hollow outline, a plain solid fill.
# regen     none | after_delay. The one rule that says how the bar comes back.
# breaks    true when reaching zero is permanent (armour breaks; shield goes down and returns).
# attack    the one line a player reads off the bar.
const Palette := preload("res://src/core/palette.gd")
const Elements := preload("res://src/build/elements.gd")

const CLASS_IDS := ["armour", "shield", "health"]
const CLASS_FIELDS := ["palette", "pattern", "regen", "breaks", "attack"]
const CLASSES := {
	"armour": {"palette": "BRASS", "pattern": "segments", "regen": "none", "breaks": true,
		"attack": "break it once; it stays broken"},
	"shield": {"palette": "SLATE", "pattern": "outline", "regen": "after_delay", "breaks": false,
		"attack": "burst it before it recovers"},
	"health": {"palette": "SAND", "pattern": "solid", "regen": "none", "breaks": false,
		"attack": "just damage"},
}

# Every defence state a bar can show, each on exactly one class. The Warden plating states
# (K-UNITS KF2 to KF4) read this table.
const STATES := {
	"plating_intact": "armour",
	"plating_cracked": "armour",
	"plating_broken": "armour",
	"shield_up": "shield",
	"shield_down": "shield",
	"hull": "health",
}

# Start values, not final: comps/gunfire/enemies-and-bosses.md reports shield regen of 10 percent
# per second after 5 s on most normal enemies. Scrapkeep tunes both from play.
const SHIELD_REGEN_DELAY := 5.0
const SHIELD_REGEN_PER_S := 0.10

# HAZE_MIX is a start value: how far a bar's colour is pulled toward the dust before a player
# reads it. It models the haze at the K-F read distance of 150 m (K-UNITS.md:427); no distance
# enters any computation here.
const HAZE_MIX := 0.2
const HAZE_COLOR := Palette.SANDSTONE
# A read that lands further than this from every class names none (a hazard klaxon is not a bar).
const READ_REACH := 45.0


static func colour_of(id: String) -> Color:
	var row: Dictionary = CLASSES.get(id, {})
	if row.is_empty():
		push_error("DefenceBars.colour_of: no class named '%s'" % id)
		return Palette.SAND
	return Palette.new().get_script().get_script_constant_map()[row["palette"]]


static func bar_class(state: String) -> String:
	return STATES.get(state, "")


# One bar's pool. hit() and tick() are the only two inputs, so each class rule has one place.
class Pool extends RefCounted:
	var class_id := ""
	var max_value := 0.0
	var value := 0.0
	var broken := false
	var _since_hit := 0.0

	# value stays in [0, max_value]: a negative maximum reads as an empty pool, and an empty pool
	# of a breaking class starts broken, as one emptied by a hit would be.
	func _init(id: String, maximum: float) -> void:
		class_id = id
		max_value = maxf(0.0, maximum)
		value = max_value
		broken = max_value == 0.0 and CLASSES[class_id]["breaks"]

	# element is the hit's element id ("" for none); its multiplier is the class's row in
	# Elements.LAYER_MULT (SG2), the one table every layer reads. A negative hit does not fill
	# the pool past its maximum.
	func hit(amount: float, element := "") -> void:
		value = clampf(value - amount * Elements.layer_mult(class_id, element), 0.0, max_value)
		_since_hit = 0.0
		if value == 0.0 and CLASSES[class_id]["breaks"]:
			broken = true

	func tick(delta: float) -> void:
		if broken or CLASSES[class_id]["regen"] != "after_delay":
			return
		var before := _since_hit
		_since_hit += delta
		var live := _since_hit - maxf(before, SHIELD_REGEN_DELAY)
		if live > 0.0:
			value = minf(max_value, value + max_value * SHIELD_REGEN_PER_S * live)


# The colour a bar shows at the modeled haze start value: its row pulled toward the haze.
static func hazed(colour: Color) -> Color:
	return colour.lerp(HAZE_COLOR, HAZE_MIX)


# Two bars of each class at mixed fill, modeled at the 150 m haze start value (HAZE_MIX). Read
# by colour alone: at this range the pattern cue is under a pixel. It is a colour model, not a
# rendered frame.
static func fixture_frame() -> Array:
	var frame := []
	for id in CLASS_IDS:
		for fill in [1.0, 0.4]:
			var base := colour_of(id).lerp(Color.BLACK, 0.15 * (1.0 - fill))
			frame.append({"class": id, "fill": fill, "seen": hazed(base)})
	return frame


# Names the class a hazed colour belongs to, or "" when it is near none.
static func blind_read(seen: Color) -> String:
	var best := ""
	var best_gap := INF
	for id in CLASS_IDS:
		var gap := cie76(seen, hazed(colour_of(id)))
		if gap < best_gap:
			best_gap = gap
			best = id
	if best_gap > READ_REACH:
		return ""
	return best


static func cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var r := _linear(c.r)
	var g := _linear(c.g)
	var b := _linear(c.b)
	var x := (r * 0.4124564 + g * 0.3575761 + b * 0.1804375) / 0.95047
	var y := r * 0.2126729 + g * 0.7151522 + b * 0.0721750
	var z := (b * 0.9503041 + g * 0.1191920 + r * 0.0193339) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


static func _linear(v: float) -> float:
	return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
