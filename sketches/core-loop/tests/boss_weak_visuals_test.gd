extends SceneTree

const WeakPart := preload("res://src/boss/weak_part.gd")
const WeakPoints := preload("res://src/boss/weak_points.gd")
const ThreatGrammar := preload("res://src/combat/threat_grammar.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# The hatch and override part's three looks (challenge lane, weak points step 2c, after the boss_weak_points art
# board): SHUT is an intact petrol cover, OPEN lights ancient-green notches at the seat, BROKEN is dark. No state
# lights hazard red or orange, and a part is never in the threat group.
#
# Evidence limit: reads materials and node visibility; how it reads on screen needs a GPU render and a human.

var _t := T.new("boss_weak_visuals_test")


func _initialize() -> void:
	var states := {"SHUT": WeakPoints.SHUT, "OPEN": WeakPoints.OPEN, "BROKEN": WeakPoints.BROKEN}
	for label in states:
		var part := WeakPart.new()
		root.add_child(part)
		part.setup("hatch_1", Vector3.BACK)
		part.set_state(states[label])
		var lit: Array = part.lit_colors()
		var clean := true
		for c in lit:
			clean = clean and not _hot(c)
		_t.check("%s: no lit surface is hazard red or orange" % label, clean, str(lit))
		_t.check("%s: never in the threat group" % label, not part.is_in_group(ThreatGrammar.GROUP), "")
		match label:
			"SHUT":
				_t.check("SHUT: cover shown, no seat light", part._cover.visible and not part._notches.visible and lit.is_empty(), str(lit))
			"OPEN":
				var all_ancient := not lit.is_empty()
				for c in lit:
					all_ancient = all_ancient and c.is_equal_approx(Palette.ANCIENT)
				_t.check("OPEN: the dominant (every) lit seat colour is ancient green", all_ancient, str(lit))
				_t.check("OPEN: more than one notch, and the cavity itself stays unlit charcoal",
						lit.size() >= 4 and not part._cavity_material.emission_enabled, str(lit.size()))
			"BROKEN":
				_t.check("BROKEN: no lit seat material, cover gone, wreck shown", lit.is_empty() and not part._cover.visible and part._wreck.visible, str(lit))
				_t.check("BROKEN: the rim is discontinuous (a bar gone)", not part._frame[3].visible, "")
				_t.check("BROKEN: not hookable", not part.hookable(), "")
		part.free()
	var hot_control: Color = Palette.HAZARD
	_t.check("control: the hot check sees hazard red and orange", _hot(hot_control) and _hot(Color(1.0, 0.62, 0.18)), "")
	_t.check("control: the hot check passes ancient green", not _hot(Palette.ANCIENT), "")
	quit(_t.verdict())


# Hazard red, orange and anything near them: red-dominant and bright, green well below red.
func _hot(c: Color) -> bool:
	return c.r > 0.8 and c.g < 0.75 and c.b < 0.5
