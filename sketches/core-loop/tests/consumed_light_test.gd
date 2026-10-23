extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")

# The consumed colour band, lit (L-W19-consumed). Andrew approved a magenta-violet "consumed" band: hue 300 to 330 degrees,
# saturation 0.6 or more, a steady emissive seam (map design page section 9; DECISIONS #378). It must stay apart from the
# lilac life band (AmbientKinds.LIFE_HUE / LIFE_SAT) and clear every warning hue. Those bands are albedo, but the player
# sees them lit, so this test lights the consumed sample and every in-band life colour under every light look the game
# uses and checks the bands still part. Lighting's half only: Dressing owns Palette.CONSUMED and ambient_palette_test.
#
# Light model (linear light Lambert, no tonemap, no exposure or saturation grade, no fog or lamps):
#   lit = albedo_lin * (sun_lin * sun_energy * max(0, n.l_sun) + ambient_lin * energy + fill_lin * fill * max(0, n.l_fill))
# The fill is the SkyFill directional light graphics_preset._apply_fill adds to every look (fill energy, colour, pitch,
# yaw = sun yaw + 180). Hue and saturation are read on the lit colour divided by its largest channel, so energy alone
# cannot clip it (HSV hue and saturation are scale-free). The CIE76 gaps scale the sample and the three warning colours by
# one shared factor (the largest lit channel among the four) so their relative lightness survives.
# Gates: lit consumed never inside the life region; lit life never inside the consumed region; lit consumed at least MIN_GAP CIE76
# from every lit life colour and from lit HAZARD, AMBER and MOLTEN. The lit hue/sat of the sample in 300-330 is reported only
# ("lit drift", per #241 ruling 6367828092). All CIE76 gaps in one look and normal share one brightness factor (cell_scale).
# Normals, built from the look's own sun and fill directions:
#   sun-facing    n = l_sun                          (n.l_sun = 1)
#   side          n = 60 degrees from l_sun toward l_fill, in their plane (n.l_sun = 0.5)
#   ambient only  n perpendicular to l_sun and l_fill (n.l_sun = 0, n.l_fill = 0: the bare ambient term)
#   fill-facing   n = l_fill                         (the wall the key misses; an extra normal beyond the card's three)

# Map design page section 9 / DECISIONS #378. Switch to Palette.CONSUMED when Dressing lands it.
const CONSUMED := Color("d24bc0")
const CONSUMED_HUE := Vector2(300.0, 330.0)
const CONSUMED_SAT_MIN := 0.6
# Same floor as ambient_palette_test.gd MIN_GAP (CIE76), copied here because tests do not import each other.
const MIN_GAP := 25.0
const MOLTEN := Color("ff7a2e")  # src/boss/hazard.gd MOLTEN, a const on a Node script, copied.
const NORMALS := ["sun-facing", "side", "ambient only", "fill-facing"]

var _t := T.new("consumed_light_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	var looks := looks_all()
	var life := life_colours()
	_t.check("looks were read", looks.size() >= 20, "%d looks" % looks.size())
	_t.check("life colours were read", life.size() > 0, "%d in-band life colours" % life.size())
	_controls()
	for entry in looks:
		for n in NORMALS.size():
			_real(entry.label, entry.look, n, life)
	print("consumed_light_test: %d looks x %d normals, %d life colours" % [looks.size(), NORMALS.size(), life.size()])


func _real(label: String, look: Dictionary, n: int, life: Array) -> void:
	var where := "%s / %s" % [label, NORMALS[n]]
	var hs := lit_hs(CONSUMED, look, n)
	print("lit drift (info; per #241 ruling 6367828092): %s %s lit hue %.1f sat %.3f%s" % [where, CONSUMED.to_html(false), hs.x, hs.y,
		"" if in_consumed_band(hs.x, hs.y) else " (outside 300-330 / 0.6)"])
	_t.check("lit consumed never inside the life region: " + where, not in_life_region(hs.x, hs.y),
		"lit hue %.1f sat %.3f (life region hue %.0f-%.0f, sat %.2f-%.2f)" % [hs.x, hs.y, AmbientKinds.LIFE_HUE.x, AmbientKinds.LIFE_HUE.y, AmbientKinds.LIFE_SAT.x, AmbientKinds.LIFE_SAT.y])
	var worst := ""
	var worst_hs := Vector2.ZERO
	var clean := true
	var nearest := 999.0
	var nearest_c := ""
	for c in life:
		var lh := lit_hs(c, look, n)
		if in_consumed_band(lh.x, lh.y):
			clean = false
			worst = c.to_html(false)
			worst_hs = lh
		var d := pair_gap(CONSUMED, c, look, n)
		if d < nearest:
			nearest = d
			nearest_c = c.to_html(false)
	_t.check("no lit life colour reaches the consumed region: " + where, clean,
		"all %d clear" % life.size() if clean else "%s lit hue %.1f sat %.3f" % [worst, worst_hs.x, worst_hs.y])
	_t.check("consumed lit is %.0f CIE76 from every lit life colour: %s" % [MIN_GAP, where], nearest >= MIN_GAP,
		"nearest %s gap %.1f" % [nearest_c, nearest])
	var gaps := warning_gaps(CONSUMED, look, n)
	for name in gaps:
		_t.check("consumed lit is %.0f CIE76 from %s lit: %s" % [MIN_GAP, name, where], gaps[name] >= MIN_GAP, "gap %.1f" % gaps[name])


# Planted controls run the same functions as the real checks, so a pass above means the check could have failed.
func _controls() -> void:
	var white := {"sun_color": Color.WHITE, "sun_energy": 1.0, "sun_rotation": Vector3(-45.0, 0.0, 0.0), "ambient": Color.WHITE,
		"energy": 0.3, "fill": 0.5, "fill_pitch": -45.0, "fill_color": Color.WHITE}
	# (0) a gate: the sample itself (albedo, unlit) is in the consumed band, so (i) and (ii) fail for the planted reason only.
	var base := Vector2(CONSUMED.h * 360.0, CONSUMED.s)
	_t.check("the sample albedo is hue 300-330 and sat >= 0.6", in_consumed_band(base.x, base.y), "hue %.1f sat %.3f" % [base.x, base.y])
	var white_hs := lit_hs(CONSUMED, white, 0)
	_t.check("control 0: the sample is in band under white light", in_consumed_band(white_hs.x, white_hs.y), "hue %.1f sat %.3f" % [white_hs.x, white_hs.y])
	# (i) a "consumed" colour at hue 290 sits inside the life band's neighbourhood and must fail the band check.
	var inside_life := Color.from_hsv(290.0 / 360.0, 0.7, 0.8)
	var i_hs := lit_hs(inside_life, white, 0)
	_t.check("control i: a consumed colour at hue 290 fails the band check", not in_consumed_band(i_hs.x, i_hs.y),
		"hue %.1f sat %.3f -> fails, as planted" % [i_hs.x, i_hs.y])
	# (ii) a pure HAZARD-orange light at high energy drags the sample out of band and onto the warning side.
	var orange := white.duplicate()
	orange.sun_color = Palette.HAZARD
	orange.sun_energy = 6.0
	orange.ambient = Palette.HAZARD
	orange.fill_color = Palette.HAZARD
	var ii_hs := lit_hs(CONSUMED, orange, 0)
	var ii_gaps := warning_gaps(CONSUMED, orange, 0)
	var closest := 999.0
	for name in ii_gaps:
		closest = minf(closest, ii_gaps[name])
	_t.check("control ii: a HAZARD-orange light at energy 6 pushes the sample out of band", not in_consumed_band(ii_hs.x, ii_hs.y),
		"hue %.1f sat %.3f -> out of band, as planted" % [ii_hs.x, ii_hs.y])
	_t.check("control ii: the same light puts the sample inside the warning gap", closest < MIN_GAP,
		"closest warning gap %.1f < %.0f, as planted" % [closest, MIN_GAP])
	# (iii) a life colour at hue 315, sat 0.7 is a consumed colour in life's clothes and must trip the no-overlap check.
	var imposter := Color.from_hsv(315.0 / 360.0, 0.7, 0.8)
	var iii_hs := lit_hs(imposter, white, 0)
	_t.check("control iii: a life colour at hue 315 sat 0.7 trips the overlap check", in_consumed_band(iii_hs.x, iii_hs.y),
		"hue %.1f sat %.3f -> inside the consumed band, caught as planted" % [iii_hs.x, iii_hs.y])
	# (iv) a consumed colour at hue 270 sat 0.4 sits in the life region and must trip the life-region gate.
	var in_life := Color.from_hsv(270.0 / 360.0, 0.4, 0.8)
	var iv_hs := lit_hs(in_life, white, 0)
	_t.check("control iv: a consumed colour at hue 270 sat 0.4 trips the life-region gate", in_life_region(iv_hs.x, iv_hs.y),
		"hue %.1f sat %.3f -> inside the life region, caught as planted" % [iv_hs.x, iv_hs.y])
	# (v) a life colour equal to the sample has a zero pairwise gap and must fail the pairwise gate.
	var same := pair_gap(CONSUMED, CONSUMED, white, 0)
	_t.check("control v: a life colour equal to the sample fails the pairwise gap", same < MIN_GAP, "gap %.1f < %.0f, as planted" % [same, MIN_GAP])


# --- the lighting model -----------------------------------------------------------------------------------------------

# Every light look the game uses, as stage_look assembles it: each time row on each world row (and the park Dig maps, whose
# open-sky fill replaces the dome's), then the waking and mind arenas and the camp. {label, look}.
static func looks_all() -> Array:
	var result := []
	for stage in range(1, 7):
		for world in [1, 2, 3]:
			result.append({"label": "stage %d %s w%d" % [stage, WorldLook.time_id(stage), world], "look": WorldLook.stage_look(stage, world)})
		var map: String = String(ParkDefs.of(stage).get("map", ""))
		if map.begins_with("park_"):
			result.append({"label": "stage %d %s w2 %s" % [stage, WorldLook.time_id(stage), map], "look": WorldLook.stage_look(stage, 2, map)})
	result.append({"label": "arena waking", "look": WorldLook.ARENAS.waking})
	result.append({"label": "arena mind", "look": WorldLook.ARENAS.mind})
	result.append({"label": "camp", "look": WorldLook.CAMP})
	return result


# Every life-band palette entry in the ambient record (accents are neutral and not the band's).
static func life_colours() -> Array:
	var seen := {}
	var result := []
	for id in AmbientKinds.KINDS:
		var palette: Dictionary = AmbientKinds.KINDS[id].palette
		for name in palette:
			var c: Color = palette[name]
			if AmbientKinds.in_band(c) and not seen.has(c.to_html(false)):
				seen[c.to_html(false)] = true
				result.append(c)
	return result


static func _toward(rotation_deg: Vector3) -> Vector3:
	return Basis.from_euler(Vector3(deg_to_rad(rotation_deg.x), deg_to_rad(rotation_deg.y), 0.0)).z


static func normal_for(look: Dictionary, n: int) -> Vector3:
	var l_sun := _toward(look.sun_rotation)
	var l_fill := _toward(Vector3(look.fill_pitch, look.sun_rotation.y + 180.0, 0.0))
	match n:
		0:
			return l_sun
		1:
			# 60 degrees from l_sun toward l_fill, in their plane.
			var across := (l_fill - l_sun * l_sun.dot(l_fill)).normalized()
			return (l_sun * cos(PI / 3.0) + across * sin(PI / 3.0)).normalized()
		2:
			return l_sun.cross(l_fill).normalized()
		_:
			return l_fill


# The lit linear colour (unclipped) of an sRGB albedo under a look at normal index n.
static func lit_linear(albedo: Color, look: Dictionary, n: int) -> Color:
	var normal := normal_for(look, n)
	var sun := maxf(0.0, normal.dot(_toward(look.sun_rotation)))
	var fill := maxf(0.0, normal.dot(_toward(Vector3(look.fill_pitch, look.sun_rotation.y + 180.0, 0.0))))
	var key: Color = look.sun_color.srgb_to_linear()
	var amb: Color = look.ambient.srgb_to_linear()
	var fc: Color = look.fill_color.srgb_to_linear()
	var light := Color(
		key.r * look.sun_energy * sun + amb.r * look.energy + fc.r * look.fill * fill,
		key.g * look.sun_energy * sun + amb.g * look.energy + fc.g * look.fill * fill,
		key.b * look.sun_energy * sun + amb.b * look.energy + fc.b * look.fill * fill)
	var a := albedo.srgb_to_linear()
	return Color(a.r * light.r, a.g * light.g, a.b * light.b)


static func _peak(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


# Hue in degrees and saturation of the lit colour, normalised by its largest channel.
static func lit_hs(albedo: Color, look: Dictionary, n: int) -> Vector2:
	var lin := lit_linear(albedo, look, n)
	var peak := _peak(lin)
	if peak <= 0.0:
		return Vector2.ZERO
	var c := Color(lin.r / peak, lin.g / peak, lin.b / peak).linear_to_srgb()
	return Vector2(c.h * 360.0, c.s)


static func in_consumed_band(hue: float, sat: float) -> bool:
	return hue >= CONSUMED_HUE.x and hue <= CONSUMED_HUE.y and sat >= CONSUMED_SAT_MIN


# The lit sRGB colours of the sample and the warning colours under a look, scaled by one shared factor: {name: Color}.
static func lit_group(sample: Color, look: Dictionary, n: int) -> Dictionary:
	var named := {"sample": sample, "HAZARD": Palette.HAZARD, "AMBER": Palette.AMBER, "MOLTEN": MOLTEN}
	var lin := {}
	var peak := 0.0
	for name in named:
		lin[name] = lit_linear(named[name], look, n)
		peak = maxf(peak, _peak(lin[name]))
	var out := {}
	for name in lin:
		var c: Color = lin[name]
		out[name] = Color(c.r / peak, c.g / peak, c.b / peak).linear_to_srgb() if peak > 0.0 else Color.BLACK
	return out


static func in_life_region(hue: float, sat: float) -> bool:
	return hue >= AmbientKinds.LIFE_HUE.x and hue <= AmbientKinds.LIFE_HUE.y and sat >= AmbientKinds.LIFE_SAT.x and sat <= AmbientKinds.LIFE_SAT.y


# The cell's shared brightness factor: the largest lit channel among the sample and the three warning colours.
static func cell_scale(look: Dictionary, n: int) -> float:
	var peak := 0.0
	for c in [CONSUMED, Palette.HAZARD, Palette.AMBER, MOLTEN]:
		peak = maxf(peak, _peak(lit_linear(c, look, n)))
	return peak


# Lit sRGB of an albedo on the cell's shared scale (clamped to 1).
static func lit_scaled(albedo: Color, look: Dictionary, n: int) -> Color:
	var k := cell_scale(look, n)
	var lin := lit_linear(albedo, look, n)
	if k <= 0.0:
		return Color.BLACK
	return Color(minf(lin.r / k, 1.0), minf(lin.g / k, 1.0), minf(lin.b / k, 1.0)).linear_to_srgb()


# CIE76 between two albedos lit under one look and normal, on the cell's shared brightness scale.
static func pair_gap(a: Color, b: Color, look: Dictionary, n: int) -> float:
	return cie76(lit_scaled(a, look, n), lit_scaled(b, look, n))


static func warning_gaps(sample: Color, look: Dictionary, n: int) -> Dictionary:
	var group := lit_group(sample, look, n)
	var gaps := {}
	for name in ["HAZARD", "AMBER", "MOLTEN"]:
		gaps[name] = cie76(group.sample, group[name])
	return gaps


# CIE76 as ambient_palette_test.gd computes it (sRGB in, D65 white).
static func cie76(a: Color, b: Color) -> float:
	return _lab(a).distance_to(_lab(b))


static func _lab(c: Color) -> Vector3:
	var lin := c.srgb_to_linear()
	var x := (lin.r * 0.4124564 + lin.g * 0.3575761 + lin.b * 0.1804375) / 0.95047
	var y := lin.r * 0.2126729 + lin.g * 0.7151522 + lin.b * 0.0721750
	var z := (lin.b * 0.9503041 + lin.g * 0.1191920 + lin.r * 0.0193339) / 1.08883
	return Vector3(116.0 * _f(y) - 16.0, 500.0 * (_f(x) - _f(y)), 200.0 * (_f(y) - _f(z)))


static func _f(t: float) -> float:
	return pow(t, 1.0 / 3.0) if t > 0.008856 else 7.787 * t + 16.0 / 116.0
