extends SceneTree

# A warning edge keeps a lightness step on bright floors (watch "noon bowl lightness", #487). HAZARD
# is L* 60.7, level with the pale noon floors, so the stroke alone reads by hue there; the step comes
# from the charcoal keyline every line sits on (threat_grammar `_lined`). The painter's own mix
# (sRGB, as tools/grade_probe.gd raw() models it): CHARCOAL at UNDERLAY_ALPHA over the floor, the
# stroke at EDGE_ALPHA over that. A dark band's step grows with the floor's lightness, so the noon
# floors are its best case: from floor L* 45 up (the noon bowl floors read 46 to 74 on llvmpipe and
# 79 on the 3060) the keyline sits at least 24 L* under the floor. Across all floors the edge step,
# the larger of floor minus keyline and |stroke minus floor|, holds 18; its low is a mid-grey floor
# near L* 39, not a noon floor. Rendered read: tools/keyline_floor_capture.gd on the noon bowl,
# whose --gate holds every in-view ray to 20 L* with a planted grey control.

const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const Capture := preload("res://tools/keyline_floor_capture.gd")
const T := preload("res://tests/support/t.gd")

const BRIGHT_FROM := 45.0
const BRIGHT_STEP := 24.0
const ANY_STEP := 18.0
const EXPECTED_CHECKS := 11
var _t := T.new("keyline_floor_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_keylines()
	_steps()
	_t.eq("the Slag Bowl is the noon row", WorldLook.arena_look("brindle").get("time", ""), "noon")
	_t.near("the capture gates at the probe's floor", Capture.EDGE_STEP_MIN, 20.0)
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)
	quit(_t.verdict())


static func lstar(c: Color) -> float:
	return DefenceBars._lab(c).x


# The edge and its keyline as the painter builds them, for a ring and a lane.
func _keylines() -> void:
	var ring := {"type": Threat.Type.INSTANT, "tone": Palette.HAZARD, "centre": Vector3.ZERO, "reach": 4.0,
		"progress": 0.5, "live": false, "form": "radial", "r_in": 0.0, "r_out": 7.0, "a0": 0.0, "a1": TAU}
	var lane := {"type": Threat.Type.LANE, "tone": Palette.HAZARD, "centre": Vector3.ZERO, "reach": 4.0,
		"progress": 0.5, "live": false, "form": "lane", "dir": Vector3(1, 0, 0), "back": 0.0, "length": 30.0, "half_width": 2.3}
	for entry in [["ring", ring, func(p: Vector3) -> float: return Vector2(p.x, p.z).length()],
			["lane", lane, func(p: Vector3) -> float: return absf(p.z)]]:
		var edge := _mark(entry[1], "edge")
		var under := _mark(entry[1], "edge_under")
		_t.check(entry[0] + " edge sits on a charcoal keyline", not edge.is_empty() and not under.is_empty()
			and under.tone == Color(Palette.CHARCOAL, Threat.UNDERLAY_ALPHA), str(under.get("tone")))
		if edge.is_empty() or under.is_empty():
			_t.check(entry[0] + " keyline is UNDERLAY wider than the edge", false)
			continue
		var reach := func(tris: PackedVector3Array) -> float:
			var most := 0.0
			for p in tris:
				most = maxf(most, entry[2].call(p))
			return most
		_t.near(entry[0] + " keyline is UNDERLAY wider than the edge", reach.call(under.tris) - reach.call(edge.tris), Threat.UNDERLAY, 0.01)


func _mark(d: Dictionary, role: String) -> Dictionary:
	for m in Threat.all_marks(d):
		if m.role == role:
			return m
	return {}


# Grey floors from black to white, mixed as the painter mixes.
func _steps() -> void:
	var worst := 999.0
	var worst_floor := 0.0
	var bright_worst := 999.0
	var bright_rises := true
	var last_key_step := -999.0
	for g in range(0, 101):
		var floor_c := Color(g / 100.0, g / 100.0, g / 100.0)
		var keyline := floor_c.lerp(Palette.CHARCOAL, Threat.UNDERLAY_ALPHA)
		var stroke := keyline.lerp(Palette.HAZARD, Threat.EDGE_ALPHA)
		var floor_l := lstar(floor_c)
		var key_step := floor_l - lstar(keyline)
		var step := maxf(key_step, absf(lstar(stroke) - floor_l))
		if step < worst:
			worst = step
			worst_floor = floor_l
		if floor_l >= BRIGHT_FROM:
			bright_worst = minf(bright_worst, key_step)
			bright_rises = bright_rises and key_step > last_key_step
			last_key_step = key_step
	_t.check("HAZARD alone sits within 10 L* of a pale noon floor (why the keyline carries the step)",
		absf(lstar(Palette.HAZARD) - 65.0) < 10.0, "%.1f" % lstar(Palette.HAZARD))
	_t.check("from floor L* %.0f up the keyline steps %.0f or more under the floor" % [BRIGHT_FROM, BRIGHT_STEP],
		bright_worst >= BRIGHT_STEP, "%.1f" % bright_worst)
	_t.check("the keyline's step grows as the floor brightens", bright_rises)
	_t.check("every floor keeps an edge step of %.0f" % ANY_STEP, worst >= ANY_STEP, "%.1f at floor L* %.1f" % [worst, worst_floor])
	_t.check("the weakest floor is mid-grey, not a noon floor", worst_floor < BRIGHT_FROM, "%.1f" % worst_floor)
