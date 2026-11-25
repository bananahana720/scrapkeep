extends RefCounted
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

const STATES := {
	"plating_intact": "armour",
	"plating_cracked": "armour",
	"plating_broken": "armour",
	"shield_up": "shield",
	"shield_down": "shield",
	"hull": "health",
}

const SHIELD_REGEN_DELAY := 5.0
const SHIELD_REGEN_PER_S := 0.10

const HAZE_MIX := 0.2
const HAZE_COLOR := Palette.SANDSTONE
const READ_REACH := 45.0


static func colour_of(id: String) -> Color:
	var row: Dictionary = CLASSES.get(id, {})
	if row.is_empty():
		push_error("DefenceBars.colour_of: no class named '%s'" % id)
		return Palette.SAND
	return Palette.new().get_script().get_script_constant_map()[row["palette"]]


static func bar_class(state: String) -> String:
	return STATES.get(state, "")


class Pool extends RefCounted:
	var class_id := ""
	var max_value := 0.0
	var value := 0.0
	var broken := false
	var _since_hit := 0.0

	func _init(id: String, maximum: float) -> void:
		class_id = id
		max_value = maxf(0.0, maximum)
		value = max_value
		broken = max_value == 0.0 and CLASSES[class_id]["breaks"]

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


static func hazed(colour: Color) -> Color:
	return colour.lerp(HAZE_COLOR, HAZE_MIX)


static func fixture_frame() -> Array:
	var frame := []
	for id in CLASS_IDS:
		for fill in [1.0, 0.4]:
			var base := colour_of(id).lerp(Color.BLACK, 0.15 * (1.0 - fill))
			frame.append({"class": id, "fill": fill, "seen": hazed(base)})
	return frame


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
