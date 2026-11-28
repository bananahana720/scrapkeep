extends SceneTree

# A warning edge keeps a lightness step on bright floors (watch "noon bowl lightness", #487). HAZARD
# is L* 60.7, level with the pale noon floors, so the stroke alone reads by hue there; the step comes
# from the charcoal keyline every line sits on (threat_grammar `_lined`). Two mixes bracket the
# painter: an sRGB mix (GL Compatibility) and a linear one (Forward+, threat_mark.gdshaderinc blends
# linear colour), CHARCOAL at UNDERLAY_ALPHA over a grey floor and the stroke at EDGE_ALPHA over
# that, before light and grade. On the 3060 (#498 comment 6428905151) the 0.85 keyline read 18.8 to
# 21.0 L* on the bowl's deck (floor L* 44 to 76) where this linear model gives 20.4 at L* 44, so the
# card runs up to about 2 L* under the model: the model must clear the capture's 20 L* gate by
# MARGIN from floor L* 44 up. Below that the step dips on mid-grey floors, and on the dark track
# bands (L* 17 to 34) the stroke carries it. Rendered read: tools/keyline_floor_capture.gd --gate.

const Threat := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const DefenceBars := preload("res://tests/support/defence_bars.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")

const BRIGHT_FROM := 44.0
# tools/keyline_floor_capture.gd EDGE_STEP_MIN (grade_probe's GAP floor) plus the card's shortfall.
const BRIGHT_STEP := 20.0
const MARGIN := 5.0
# The bowl's teal deck as the 3060 rendered it at noon beside the ring (floor L* 44.4, the median of
# the floor annulus in keyline-0.png, #498 comment 6428905151): the weakest floor the gate met.
const DECK_3060 := Color("5f6e5d")
const EXPECTED_CHECKS := 13
var _t := T.new("keyline_floor_test")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_keylines()
	for mix in ["srgb", "linear"]:
		_steps(mix)
	_deck()
	_t.eq("the Slag Bowl is the noon row", WorldLook.arena_look("brindle").get("time", ""), "noon")
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


# The measured deck, mixed both ways. The deck is already graded, so this reads the keyline as if it
# took the deck's light; the rendered gate is the capture.
func _deck() -> void:
	for mix in ["srgb", "linear"]:
		var keyline := DECK_3060.lerp(Palette.CHARCOAL, Threat.UNDERLAY_ALPHA) if mix == "srgb" \
			else DECK_3060.srgb_to_linear().lerp(Palette.CHARCOAL.srgb_to_linear(), Threat.UNDERLAY_ALPHA).linear_to_srgb()
		var step := lstar(DECK_3060) - lstar(keyline)
		_t.check("%s: the keyline steps %.0f or more under the 3060's noon deck" % [mix, BRIGHT_STEP + MARGIN],
			step >= BRIGHT_STEP + MARGIN, "%.1f" % step)


# Grey floors from black to white, mixed in sRGB or in linear light.
func _steps(mix: String) -> void:
	var over := func(under: Color, top: Color, alpha: float) -> Color:
		if mix == "srgb":
			return under.lerp(top, alpha)
		return under.srgb_to_linear().lerp(top.srgb_to_linear(), alpha).linear_to_srgb()
	var worst := 999.0
	var worst_floor := 0.0
	var bright_worst := 999.0
	var bright_rises := true
	var last_key_step := -999.0
	for g in range(0, 101):
		var floor_c := Color(g / 100.0, g / 100.0, g / 100.0)
		var keyline: Color = over.call(floor_c, Palette.CHARCOAL, Threat.UNDERLAY_ALPHA)
		var stroke: Color = over.call(keyline, Palette.HAZARD, Threat.EDGE_ALPHA)
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
	_t.check("%s: from floor L* %.0f up the keyline steps %.0f or more under the floor" % [mix, BRIGHT_FROM, BRIGHT_STEP + MARGIN],
		bright_worst >= BRIGHT_STEP + MARGIN, "%.1f" % bright_worst)
	_t.check("%s: the keyline's step grows as the floor brightens" % mix, bright_rises)
	_t.check("%s: the weakest edge step is on a floor darker than the noon floors" % mix, worst_floor < BRIGHT_FROM,
		"%.1f at floor L* %.1f" % [worst, worst_floor])
