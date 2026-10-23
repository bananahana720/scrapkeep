extends SceneTree

const AmbientKinds := preload("res://src/core/ambient_kinds.gd")
const ArenaWakingDress := preload("res://src/presentation/arena_waking_dress.gd")
const Palette := preload("res://src/core/palette.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const T := preload("res://tests/support/t.gd")

# The consumed colour band, lit (L-W19-consumed). Andrew approved a magenta-violet "consumed" band: hue 300 to 330 degrees,
# saturation 0.6 or more, a steady emissive seam. It must stay apart from the lilac life band (AmbientKinds.LIFE_HUE /
# LIFE_SAT) and clear every warning hue. Those bands are albedo, but the player sees them lit, so this test lights the
# consumed sample and every in-band life colour under every light look the game uses and checks the bands still part.
# Lighting's half only: Dressing owns Palette.CONSUMED and ambient_palette_test.
#
# Sources of the band: the hue 300 to 330 range is the DECISIONS row "Map design veto pass" in
# project-guide/handoff/DECISIONS.md. That row is on main at c23449cb (PR #378) and is not yet on stage/alpha-w18. The
# saturation >= 0.6 floor and the d24bc0 sample are from the map design page section 9,
# https://claude.ai/artifact/48ATT1f4HUQ7PHi7NoqZRY. Switch CONSUMED to Palette.CONSUMED when Dressing lands it.
#
# Light model: linear-light Lambert, one directional term per light, no tonemap, no exposure or saturation grade, no fog,
# no lamp pool, no light falloff (omni and spot range are ignored):
#   lit = albedo_lin * (ambient_lin * energy + sum over lights of color_lin * energy * max(0, n.l))
# A "rig" is the lights the game draws in one place: {lights: [{color, energy, dir}], ambient, energy, normals: [{name, n}]}.
# Stage, mind and camp rigs (rig_of_look) are the row's sun plus the SkyFill graphics_preset._apply_fill adds (fill energy,
# colour, pitch, yaw = sun yaw + 180). Normals there are built from the sun and fill directions:
#   sun-facing    n = l_sun          side          n = 60 degrees from l_sun toward l_fill (n.l_sun = 0.5)
#   ambient only  n perpendicular to l_sun and l_fill (the bare ambient term)       fill-facing  n = l_fill
# The Waking pit (rig_waking) is NOT lit by its row's sun: that row has sun_visible false and arena_waking_dress.gd hides every
# DirectionalLight3D (:192-193). The game draws CoreKey, a SpotLight3D (colour WorldLook.ARENAS.waking.key, energy
# ArenaWakingDress.LIGHTS.core_key.energy), and ReactorBounce, an OmniLight3D (colour Color("91b4ce") at
# arena_waking_dress.gd:169, energy LIGHTS.reactor.energy), over the row's ambient. No sun and no fill. Falloff is ignored.
# Not modelled: the Waking RimPools, amber floor lights (ARENAS.waking.floor_accent = Palette.AMBER, LIGHTS.rim_pool.energy 1.0,
# arena_waking_dress.gd:22 and :265-267). Warm light moves the sample toward the warning side, which gate (d) covers; Waking's
# tightest warning gap is 88.6.
# _follow_reactor (arena_waking_dress.gd:336-339) puts ReactorBounce at warden.family_point_at(), which is the Warden position
# plus point_offset(), by default Vector3.UP * 4.0 (src/combat/warden.gd:264-265). The reactor hangs above the Warden, so the
# floor sees both lights, and a surface's direction to each light depends on where it stands. So no direction is assumed:
# the Waking cells are an envelope, every (key n.l, reactor n.l) pair with each weight in {0, 0.5, 1}, over the ambient
# (9 cells; (0, 0) is ambient only). The grid step is 0.5, so it samples the mix and is not a continuous bound; the minimum
# lit saturation sits at the ambient-only corner (0, 0), where neither light adds its hue. That bounds the mix of the two
# lights on any surface at those weights.
# Hue and saturation are read on the lit colour divided by its largest channel, so energy alone cannot clip it (HSV hue and
# saturation are scale-free). All CIE76 gaps in one rig and normal (one "cell") share one brightness factor, cell_scale: the
# largest lit channel among the sample and the three warning colours; life colours are scaled by it and clamped at 1.
# Gates: lit consumed never inside the life region; lit life never inside the consumed region; lit consumed at least MIN_GAP
# CIE76 from every lit life colour and from lit HAZARD, AMBER and MOLTEN. The lit hue/sat of the sample in 300-330 is reported
# only ("lit drift", per #241 ruling 6367828092).

# Sample from the map design page section 9. Switch to Palette.CONSUMED when Dressing lands it.
const CONSUMED := Color("d24bc0")
const CONSUMED_HUE := Vector2(300.0, 330.0)
const CONSUMED_SAT_MIN := 0.6
# Same floor as ambient_palette_test.gd MIN_GAP (CIE76), copied here because tests do not import each other.
const MIN_GAP := 25.0
const MOLTEN := Color("ff7a2e")  # src/boss/hazard.gd MOLTEN, a const on a Node script, copied.
# Pinned from a real run (as tests/park_day_light_test.gd pins its count): 6 stages x 3 worlds, 6 park maps, waking, mind, camp.
const EXPECTED_LOOKS := 27
const EXPECTED_CHECKS := 700

var _t := T.new("consumed_light_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func _run() -> void:
	var looks := looks_all()
	var life := life_colours()
	_t.eq("every light look was read", looks.size(), EXPECTED_LOOKS)
	_t.check("life colours were read", life.size() > 0, "%d in-band life colours" % life.size())
	_controls()
	var cells := 0
	for entry in looks:
		for n in entry.rig.normals.size():
			_real(entry.label, entry.rig, n, life)
			cells += 1
	print("consumed_light_test: %d looks, %d cells, %d life colours" % [looks.size(), cells, life.size()])
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)


func _real(label: String, rig: Dictionary, n: int, life: Array) -> void:
	var where := "%s / %s" % [label, rig.normals[n].name]
	var hs := lit_hs(CONSUMED, rig, n)
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
		var lh := lit_hs(c, rig, n)
		if in_consumed_band(lh.x, lh.y):
			clean = false
			worst = c.to_html(false)
			worst_hs = lh
		var d := pair_gap(CONSUMED, c, rig, n)
		if d < nearest:
			nearest = d
			nearest_c = c.to_html(false)
	_t.check("no lit life colour reaches the consumed region: " + where, clean,
		"all %d clear" % life.size() if clean else "%s lit hue %.1f sat %.3f" % [worst, worst_hs.x, worst_hs.y])
	_t.check("consumed lit is %.0f CIE76 from every lit life colour: %s" % [MIN_GAP, where], gap_ok(nearest),
		"nearest %s gap %.1f" % [nearest_c, nearest])
	var gaps := warning_gaps(CONSUMED, rig, n)
	for name in gaps:
		_t.check("consumed lit is %.0f CIE76 from %s lit: %s" % [MIN_GAP, name, where], gap_ok(gaps[name]), "gap %.1f" % gaps[name])


# Planted controls run the same functions as the real checks, so a pass above means the check could have failed.
func _controls() -> void:
	var white_look := {"sun_color": Color.WHITE, "sun_energy": 1.0, "sun_rotation": Vector3(-45.0, 0.0, 0.0), "ambient": Color.WHITE,
		"energy": 0.3, "fill": 0.5, "fill_pitch": -45.0, "fill_color": Color.WHITE}
	var white := rig_of_look(white_look)
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
	var orange_look := white_look.duplicate()
	orange_look.sun_color = Palette.HAZARD
	orange_look.sun_energy = 6.0
	orange_look.ambient = Palette.HAZARD
	orange_look.fill_color = Palette.HAZARD
	var orange := rig_of_look(orange_look)
	var ii_hs := lit_hs(CONSUMED, orange, 0)
	var ii_gaps := warning_gaps(CONSUMED, orange, 0)
	var closest := 999.0
	for name in ii_gaps:
		closest = minf(closest, ii_gaps[name])
	_t.check("control ii: a HAZARD-orange light at energy 6 pushes the sample out of band", not in_consumed_band(ii_hs.x, ii_hs.y),
		"hue %.1f sat %.3f -> out of band, as planted" % [ii_hs.x, ii_hs.y])
	_t.check("control ii: the same light puts the sample inside the warning gap", not gap_ok(closest),
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
	_t.check("control v: a life colour equal to the sample fails the pairwise gap", not gap_ok(same), "gap %.1f < %.0f, as planted" % [same, MIN_GAP])
	# (vii) the weight-envelope branch of lit_linear ("w"): every control above uses the white rig, so plant two here.
	var env := {"ambient": Color.WHITE, "energy": 0.3, "lights": [{"color": Palette.HAZARD, "energy": 2.0, "dir": Vector3.ZERO}],
		"normals": [{"name": "key 1.0", "w": [1.0]}, {"name": "key 0.0", "w": [0.0]}]}
	var vii_hs := lit_hs(CONSUMED, env, 0)
	_t.check("control vii: key weight 1 under a HAZARD key pushes the sample out of band", not in_consumed_band(vii_hs.x, vii_hs.y),
		"hue %.1f sat %.3f -> out of band, as planted" % [vii_hs.x, vii_hs.y])
	var amb_only := lit_linear(CONSUMED, {"ambient": Color.WHITE, "energy": 0.3, "lights": [], "normals": [{"name": "none", "w": []}]}, 0)
	var w0 := lit_linear(CONSUMED, env, 1)
	var w1 := lit_linear(CONSUMED, env, 0)
	_t.check("control vii: key weight 0 equals ambient only and weight 1 differs (a branch that ignores w fails)",
		absf(w0.r - amb_only.r) + absf(w0.g - amb_only.g) + absf(w0.b - amb_only.b) < 1e-6 and absf(w1.r - w0.r) > 0.01,  # 1e-6 and 0.01: float tolerances
		"weight 0 matches ambient, weight 1 red %.4f vs %.4f" % [w1.r, w0.r])
	# (vi) the thresholds themselves: inclusive edges, asserted once so a change of > to >= shows. Hue 300 is the one degree the
	# two hue ranges share; the saturation ranges (life up to 0.55, consumed from 0.6) keep the regions apart there.
	# The literal edge values below (300, 330, 0.6, 0.55) are intentional change detectors on the band values.
	_t.check("edge: hue 300 sat 0.6 is consumed", in_consumed_band(300.0, 0.6), "inclusive on both hue 300 and sat 0.6")
	_t.check("edge: hue 330 sat 0.6 is consumed", in_consumed_band(330.0, 0.6), "inclusive on hue 330")
	_t.check("edge: hue 299.99 and 330.01 are not consumed", not in_consumed_band(299.99, 0.9) and not in_consumed_band(330.01, 0.9), "outside the hue range")
	_t.check("edge: sat 0.5999 is not consumed", not in_consumed_band(315.0, 0.5999), "just under the floor")
	_t.check("edge: hue 300 sat 0.55 is life", in_life_region(300.0, 0.55), "inclusive on hue 300 and sat 0.55")
	_t.check("edge: hue 250 sat 0.15 is life", in_life_region(AmbientKinds.LIFE_HUE.x, AmbientKinds.LIFE_SAT.x), "inclusive on the low edges")
	_t.check("edge: sat 0.5501 is not life", not in_life_region(280.0, 0.5501), "just over the life ceiling")
	_t.check("edge: hue 300 is in both hue ranges but no point is in both regions",
		in_life_region(300.0, 0.55) and in_consumed_band(300.0, 0.6) and not in_life_region(300.0, 0.6) and not in_consumed_band(300.0, 0.55),
		"the saturation ranges are disjoint (life <= 0.55 < 0.6 <= consumed)")
	_t.check("edge: a gap of exactly 25 passes and 24.999 fails", gap_ok(25.0) and not gap_ok(24.999), "inclusive at MIN_GAP")
	# A constructed pair: two greys whose CIE76 gap is exactly the L* difference. L* 50 and 75 are 25 apart.
	var grey_lo := Color(_grey_for_lstar(50.0), _grey_for_lstar(50.0), _grey_for_lstar(50.0))
	var grey_hi := Color(_grey_for_lstar(75.0), _grey_for_lstar(75.0), _grey_for_lstar(75.0))
	var grey_gap := cie76(grey_lo, grey_hi)
	# 0.05 below is a float tolerance on the constructed pair, not a band value.
	_t.check("edge: two greys 25 L* apart measure about 25 CIE76", absf(grey_gap - 25.0) < 0.05, "gap %.4f" % grey_gap)


# The sRGB value of the neutral grey with the given L* (inverse of _lab on a grey).
static func _grey_for_lstar(lstar: float) -> float:
	var y := pow((lstar + 16.0) / 116.0, 3.0)
	return Color(y, y, y).linear_to_srgb().r


# --- the lighting model -----------------------------------------------------------------------------------------------

# Every light look the game uses, as a rig: the stage_look rows (each time row on each world row), the park Dig maps, the
# Waking pit, the Mind arena and the camp. WorldLook.PARK_ROWS has world 2 only, so a park map is lit as world 2 and its stage
# label is a superset: it names the stage the map is entered at (ParkDefs.of(stage).map), not a new world/time pair.
# {label, rig}.
static func looks_all() -> Array:
	var result := []
	for stage in range(1, 7):
		for world in [1, 2, 3]:
			result.append({"label": "stage %d %s w%d" % [stage, WorldLook.time_id(stage), world], "rig": rig_of_look(WorldLook.stage_look(stage, world))})
		var map: String = String(ParkDefs.of(stage).get("map", ""))
		if map.begins_with("park_"):
			result.append({"label": "stage %d %s w2 %s" % [stage, WorldLook.time_id(stage), map], "rig": rig_of_look(WorldLook.stage_look(stage, 2, map))})
	result.append({"label": "arena waking", "rig": rig_waking()})
	result.append({"label": "arena mind", "rig": rig_of_look(WorldLook.ARENAS.mind)})
	result.append({"label": "camp", "rig": rig_of_look(WorldLook.CAMP)})
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


# A WorldLook row as a rig: the sun, the SkyFill, and the row's ambient.
static func rig_of_look(look: Dictionary) -> Dictionary:
	var l_sun := _toward(look.sun_rotation)
	var l_fill := _toward(Vector3(look.fill_pitch, look.sun_rotation.y + 180.0, 0.0))
	var across := (l_fill - l_sun * l_sun.dot(l_fill)).normalized()
	return {"ambient": look.ambient, "energy": look.energy,
		"lights": [{"color": look.sun_color, "energy": look.sun_energy, "dir": l_sun}, {"color": look.fill_color, "energy": look.fill, "dir": l_fill}],
		"normals": [{"name": "sun-facing", "n": l_sun},
			{"name": "side", "n": (l_sun * cos(PI / 3.0) + across * sin(PI / 3.0)).normalized()},
			{"name": "ambient only", "n": l_sun.cross(l_fill).normalized()},
			{"name": "fill-facing", "n": l_fill}]}


# The Waking pit as the game lights it (see the header): CoreKey and ReactorBounce over the row's ambient, as a weight envelope.
# A normal here carries "w", the n.l weight per light, instead of a vector; lit_linear uses it directly.
static func rig_waking() -> Dictionary:
	var row: Dictionary = WorldLook.ARENAS.waking
	var normals := []
	for k in [0.0, 0.5, 1.0]:
		for r in [0.0, 0.5, 1.0]:
			normals.append({"name": "key %.1f reactor %.1f" % [k, r], "w": [k, r]})
	return {"ambient": row.ambient, "energy": row.energy,
		"lights": [{"color": row.key, "energy": ArenaWakingDress.LIGHTS.core_key.energy, "dir": Vector3.ZERO},
			{"color": Color("91b4ce"), "energy": ArenaWakingDress.LIGHTS.reactor.energy, "dir": Vector3.ZERO}],
		"normals": normals}


# The lit linear colour (unclipped) of an sRGB albedo under a rig at normal index n.
static func lit_linear(albedo: Color, rig: Dictionary, n: int) -> Color:
	var spec: Dictionary = rig.normals[n]
	var amb: Color = rig.ambient.srgb_to_linear()
	var light := Color(amb.r * rig.energy, amb.g * rig.energy, amb.b * rig.energy)
	for i in rig.lights.size():
		var l: Dictionary = rig.lights[i]
		var c: Color = l.color.srgb_to_linear()
		var weight: float = float(spec.w[i]) if spec.has("w") else maxf(0.0, spec.n.dot(l.dir))
		var k: float = l.energy * weight
		light = Color(light.r + c.r * k, light.g + c.g * k, light.b + c.b * k)
	var a := albedo.srgb_to_linear()
	return Color(a.r * light.r, a.g * light.g, a.b * light.b)


# True when an albedo's lit channel exceeds the cell's shared scale and so clamps at 1 in lit_scaled.
static func clamps(albedo: Color, rig: Dictionary, n: int) -> bool:
	return _peak(lit_linear(albedo, rig, n)) > cell_scale(rig, n) * (1.0 + 1e-6)  # float tolerance


static func gap_ok(gap: float) -> bool:
	return gap >= MIN_GAP


static func _peak(c: Color) -> float:
	return maxf(c.r, maxf(c.g, c.b))


# Hue in degrees and saturation of the lit colour, normalised by its largest channel.
static func lit_hs(albedo: Color, rig: Dictionary, n: int) -> Vector2:
	var lin := lit_linear(albedo, rig, n)
	var peak := _peak(lin)
	if peak <= 0.0:
		return Vector2.ZERO
	var c := Color(lin.r / peak, lin.g / peak, lin.b / peak).linear_to_srgb()
	return Vector2(c.h * 360.0, c.s)


static func in_consumed_band(hue: float, sat: float) -> bool:
	return hue >= CONSUMED_HUE.x and hue <= CONSUMED_HUE.y and sat >= CONSUMED_SAT_MIN


# The lit sRGB colours of the sample and the warning colours under a look, scaled by one shared factor: {name: Color}.
static func lit_group(sample: Color, rig: Dictionary, n: int) -> Dictionary:
	var named := {"sample": sample, "HAZARD": Palette.HAZARD, "AMBER": Palette.AMBER, "MOLTEN": MOLTEN}
	var lin := {}
	var peak := 0.0
	for name in named:
		lin[name] = lit_linear(named[name], rig, n)
		peak = maxf(peak, _peak(lin[name]))
	var out := {}
	for name in lin:
		var c: Color = lin[name]
		out[name] = Color(c.r / peak, c.g / peak, c.b / peak).linear_to_srgb() if peak > 0.0 else Color.BLACK
	return out


static func in_life_region(hue: float, sat: float) -> bool:
	return hue >= AmbientKinds.LIFE_HUE.x and hue <= AmbientKinds.LIFE_HUE.y and sat >= AmbientKinds.LIFE_SAT.x and sat <= AmbientKinds.LIFE_SAT.y


# The cell's shared brightness factor: the largest lit channel among the sample and the three warning colours.
static func cell_scale(rig: Dictionary, n: int) -> float:
	var peak := 0.0
	for c in [CONSUMED, Palette.HAZARD, Palette.AMBER, MOLTEN]:
		peak = maxf(peak, _peak(lit_linear(c, rig, n)))
	return peak


# Lit sRGB of an albedo on the cell's shared scale (clamped to 1).
static func lit_scaled(albedo: Color, rig: Dictionary, n: int) -> Color:
	var k := cell_scale(rig, n)
	var lin := lit_linear(albedo, rig, n)
	if k <= 0.0:
		return Color.BLACK
	return Color(minf(lin.r / k, 1.0), minf(lin.g / k, 1.0), minf(lin.b / k, 1.0)).linear_to_srgb()


# CIE76 between two albedos lit under one look and normal, on the cell's shared brightness scale.
static func pair_gap(a: Color, b: Color, rig: Dictionary, n: int) -> float:
	return cie76(lit_scaled(a, rig, n), lit_scaled(b, rig, n))


static func warning_gaps(sample: Color, rig: Dictionary, n: int) -> Dictionary:
	var group := lit_group(sample, rig, n)
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
