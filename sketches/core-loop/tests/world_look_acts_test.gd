extends SceneTree

# World 1's three acts of light and the 2010 finish (W46-03; WORLD1-DEMO-CATALYST.md C1, ruling ei).
#   - The dam (dawn), the flume (morning) and the Slag Bowl (noon, plus its smoke) are three looks, not one: every pair's
#     light colours (sun, ambient, fog lean, sky zenith, horizon and glow) sit ACT_MIN_DE or more apart, mean CIE76.
#   - The colour law: HAZARD is for live danger only, so no colour in any act's row sits within HAZARD_MIN_DE of it.
#   - Fleet paint takes the bone edge layer and the shade rim; a casting (edge 0 bake, wear 0.5 everywhere) gets no bone;
#     brass is one satin finish whether a script builds it or a model's brass slot carries it.
#   - The palette holds the wave's later colours: the Kindness purple inside hue 300 to 330 (ruling ci) and a sodium
#     floodlight amber apart from AMBER and HAZARD.
#   - PF-47: at every distance a park prop or hero has a detail level drawn whole, so no hand-over is see-through.
#   - The seven code-drawn player marks' colour sites resolve (tools/vertex_colour_probe.gd, the hand-off to W46-13).
# Planted, each must fail its own judge: an act copied from another, a glow set to HAZARD, the old cross-fade ranges.
# Evidence limit: headless values. The look is judged from the Mac stills and the sheet on the W46-03 pull request.

const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Palette := preload("res://src/core/palette.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Bars := preload("res://src/core/defence_bars.gd")
const Probe := preload("res://tools/vertex_colour_probe.gd")

# Mean CIE76 over the act keys between any two acts; 12 is a step two stills side by side show at a glance (ours, inferred).
const ACT_MIN_DE := 12.0
# No act colour within this of HAZARD (colour_cvd_test's 20 floor, plus margin).
const HAZARD_MIN_DE := 25.0
const ACT_KEYS := ["sun_color", "ambient", "fog_tint"]
const GRADE_KEYS := ["top", "horizon", "glow"]
const EXPECTED_CHECKS := 31

var _t := T.new("world_look_acts_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_acts()
	_finish()
	_palette()
	_hand_overs()
	_marks()
	_t.eq("every check ran", _t.checks, EXPECTED_CHECKS)
	quit(_t.verdict())


static func acts() -> Dictionary:
	var dam := StageDefs.first_of(1)
	var flume := StageDefs.last_of(1)
	return {"dam": WorldLook.stage_look(dam, 1, String(StageDefs.of(dam).get("map", ""))),
		"flume": WorldLook.stage_look(flume, 1, String(StageDefs.of(flume).get("map", ""))),
		"bowl": WorldLook.arena_look("brindle")}


static func key_colours(look: Dictionary) -> Array:
	var out := []
	for key in ACT_KEYS:
		out.append(look[key])
	for key in GRADE_KEYS:
		out.append(look.grade[key])
	return out


static func act_distance(a: Dictionary, b: Dictionary) -> float:
	var ca := key_colours(a)
	var cb := key_colours(b)
	var sum := 0.0
	for i in ca.size():
		sum += Bars.cie76(ca[i], cb[i])
	return sum / ca.size()


# Every Color anywhere in a row (nested fog, grade and air dictionaries included).
static func colours_in(value, out: Array) -> Array:
	if value is Color:
		out.append(value)
	elif value is Dictionary:
		for key in value:
			colours_in(value[key], out)
	return out


static func nearest_hazard(look: Dictionary) -> float:
	var nearest := INF
	for c: Color in colours_in(look, []):
		nearest = minf(nearest, Bars.cie76(Color(c, 1.0), Palette.HAZARD))
	return nearest


func _acts() -> void:
	var looks := acts()
	_t.check("the acts are dawn, morning and noon", looks.dam.time == "dawn" and looks.flume.time == "morning" and looks.bowl.time == "noon")
	var ids := ["dam", "flume", "bowl"]
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var d := act_distance(looks[ids[i]], looks[ids[j]])
			print("act distance %s-%s: %.1f" % [ids[i], ids[j], d])
			_t.check("%s and %s light differ by %.0f or more (mean CIE76)" % [ids[i], ids[j], ACT_MIN_DE], d >= ACT_MIN_DE, "%.1f" % d)
	_t.check("planted: an act copied from another fails the distance", act_distance(looks.dam, looks.dam.duplicate(true)) < ACT_MIN_DE)
	for id in ids:
		var near := nearest_hazard(looks[id])
		_t.check("%s uses no colour within %.0f of HAZARD" % [id, HAZARD_MIN_DE], near >= HAZARD_MIN_DE, "nearest %.1f" % near)
	var planted: Dictionary = looks.bowl.duplicate(true)
	planted.grade.glow = Palette.HAZARD
	_t.check("planted: a glow set to HAZARD fails the colour law", nearest_hazard(planted) < HAZARD_MIN_DE)
	_t.check("the bowl's smoke covers only the bowl: its fog is its own, its ambient and sky are noon's",
		looks.bowl.fog.color == WorldLook.DAYLIT_ARENAS.brindle.over.fog.color and looks.bowl.ambient == WorldLook.TIME_ROWS.noon.ambient
		and looks.bowl.grade.horizon == WorldLook.TIME_ROWS.noon.grade.horizon)
	_t.check("the dawn shade is violet-indigo: its ambient leans blue over red and green", (looks.dam.ambient as Color).b > (looks.dam.ambient as Color).r
		and (looks.dam.ambient as Color).r >= (looks.dam.ambient as Color).g)
	_t.check("the flume's ambient is turquoise: green and blue over red", (looks.flume.ambient as Color).g > (looks.flume.ambient as Color).r
		and (looks.flume.ambient as Color).b > (looks.flume.ambient as Color).r)
	_t.check("the bowl's sun is furnace gold: red over green over blue", (looks.bowl.sun_color as Color).r > (looks.bowl.sun_color as Color).g
		and (looks.bowl.sun_color as Color).g > (looks.bowl.sun_color as Color).b)


func _surface(mesh: ArrayMesh, slot: String, wear_v: float, mat: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([1, 0, 0, 1, 1, 0, 0, 1, 1, 0, 0, 1])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.DOWN])
	arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(1, wear_v), Vector2(1, wear_v), Vector2(1, wear_v)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var i := mesh.get_surface_count() - 1
	mesh.surface_set_name(i, slot)
	mesh.surface_set_material(i, mat)


func _finish() -> void:
	_t.check("the edge layer: no bone on a neutral face or a crease, LIFT at the most worn edge",
		BakeLook.lift_alpha(0.5) == 0.0 and BakeLook.lift_alpha(1.0) == 0.0 and is_equal_approx(BakeLook.lift_alpha(0.0), BakeLook.LIFT)
		and BakeLook.lift_alpha(0.1) > BakeLook.lift_alpha(0.3))
	var paint := Palette.solid(Palette.RUST)
	var rubber := Palette.solid(Palette.CHARCOAL)
	var tag := Palette.solid(Color("b89a40"))
	var casting := Palette.solid(Palette.VERDIGRIS)
	var body := ArrayMesh.new()
	_surface(body, "fleet_paint", 0.0, paint)
	_surface(body, "rubber", 0.0, rubber)
	_surface(body, "requisition_tag", 0.5, tag)
	_surface(body, "bare_metal", 0.5, casting)
	var view := MeshInstance3D.new()
	view.mesh = body
	var root_node := Node3D.new()
	root_node.add_child(view)
	BakeLook.dress(root_node, [paint])
	var mesh := view.mesh
	_t.check("owned Fleet paint takes the bone edge layer and a light-tinted rim in place", mesh.surface_get_material(0) == paint
		and paint.next_pass == BakeLook.edge_lift() and paint.rim_enabled and paint.rim_tint == 0.0 and is_equal_approx(paint.rim, BakeLook.RIM))
	var shader := (BakeLook.edge_lift().shader as Shader).code
	_t.check("the edge layer mixes toward bone and draws nothing where it lifts nothing", shader.contains("blend_mix") and shader.contains("discard")
		and BakeLook.edge_lift().get_shader_parameter("bone") == Palette.SAND)
	var shaded := mesh.surface_get_material(1) as StandardMaterial3D
	_t.check("rubber is shaded but takes no edge layer or rim", shaded.get_meta("bake_look", false) and shaded.next_pass == null and not shaded.rim_enabled)
	var brass_twin := mesh.surface_get_material(2) as StandardMaterial3D
	_t.check("a model's brass slot takes the one satin brass", brass_twin.get_meta("brass_finish", false)
		and is_equal_approx(brass_twin.roughness, Palette.BRASS_FINISH.roughness) and is_equal_approx(brass_twin.metallic, Palette.BRASS_FINISH.metallic))
	var shell := mesh.surface_get_material(3) as StandardMaterial3D
	_t.check("a casting's shell takes no edge layer, and its edge 0 bake gives no bone", shell.next_pass == null and BakeLook.lift_alpha(0.5) == 0.0)
	var script_brass := Palette.solid(Palette.BRASS, 0.8)
	_t.check("a script's brass solid is the same satin brass, its glow kept", script_brass.get_meta("brass_finish", false)
		and is_equal_approx(script_brass.roughness, brass_twin.roughness) and is_equal_approx(script_brass.metallic, brass_twin.metallic)
		and script_brass.emission_enabled)
	_t.check("another colour's solid keeps its own finish", not Palette.solid(Palette.RUST).get_meta("brass_finish", false))
	var debris := BakeLook.unbaked(paint) as StandardMaterial3D
	_t.check("a borrowed unbaked copy drops the edge layer", debris.next_pass == null)
	root_node.free()


func _palette() -> void:
	var purple := Palette.KINDNESS
	_t.check("the Kindness purple is inside hue 300 to 330 (ruling ci)", purple.h * 360.0 >= 300.0 and purple.h * 360.0 <= 330.0 and purple.s > 0.5,
		"hue %.1f" % (purple.h * 360.0))
	_t.check("the sodium floodlight is its own amber: apart from AMBER and HAZARD", Bars.cie76(Palette.SODIUM, Palette.AMBER) >= 10.0
		and Bars.cie76(Palette.SODIUM, Palette.HAZARD) >= HAZARD_MIN_DE,
		"%.1f from AMBER, %.1f from HAZARD" % [Bars.cie76(Palette.SODIUM, Palette.AMBER), Bars.cie76(Palette.SODIUM, Palette.HAZARD)])
	var used := false
	for look: Dictionary in acts().values():
		for c: Color in colours_in(look, []):
			used = used or Bars.cie76(Color(c, 1.0), purple) < 20.0
	_t.check("no act light is purple", not used)


# Godot's FADE_SELF: a level is hidden past end + end margin and before begin - begin margin, fades over end +- end margin and
# begin +- begin margin, and is whole between.
static func level_alpha(level: Array, d: float) -> float:
	var begin: float = level[0]
	var end: float = level[1]
	var bm: float = level[2]
	var em: float = level[3]
	if (end > 0.0 and d > end + em) or (begin > 0.0 and d < begin - bm):
		return 0.0
	var a := 1.0
	if end > 0.0 and em > 0.0 and d > end - em:
		a = minf(a, 1.0 - (d - (end - em)) / (2.0 * em))
	if begin > 0.0 and bm > 0.0 and d < begin + bm:
		a = minf(a, (d - (begin - bm)) / (2.0 * bm))
	return clampf(a, 0.0, 1.0)


# The first distance (0.25 m steps) short of the last level's own fade where no level is whole, or -1.
static func first_ghost(levels: Array) -> float:
	var last: Array = levels[levels.size() - 1]
	var d := 0.0
	while d < float(last[1]) - float(last[3]):
		var whole := false
		for level: Array in levels:
			whole = whole or level_alpha(level, d) >= 0.999
		if not whole:
			return d
		d += 0.25
	return -1.0


func _hand_overs() -> void:
	for spec in [["hero", true, false], ["prop", false, false], ["prop at the lowest preset", false, true]]:
		var ghost := first_ghost(ParkProps.levels(spec[1], spec[2]))
		_t.check("PF-47: a %s has a level drawn whole at every distance" % spec[0], ghost < 0.0, "first ghost at %.2f m" % ghost)
	var old := [[0.0, 70.0, 0.0, 8.0], [70.0, 180.0, 8.0, 8.0], [180.0, 450.0, 8.0, 8.0]]
	_t.check("planted: the old cross-fade (both levels half drawn at 70 m) fails", first_ghost(old) > 0.0 and first_ghost(old) < 70.0
		and is_equal_approx(level_alpha(old[0], 70.0), 0.5) and is_equal_approx(level_alpha(old[1], 70.0), 0.5))
	var hero := ParkProps.levels(true)
	_t.check("the hero hand-overs stay at 70 and 180 m, the next level whole one margin before",
		hero[0][1] == 70.0 and hero[1][1] == 180.0 and hero[1][0] == 70.0 - ParkProps.HERO_MARGIN_M and hero[2][0] == 180.0 - ParkProps.HERO_MARGIN_M)


func _marks() -> void:
	var rows: Array = Probe.mark_sites()
	var lost := rows.filter(func(row: Dictionary) -> bool: return row.has("error"))
	_t.check("the seven player marks' colour sites resolve", rows.size() == 7 and lost.is_empty(), str(lost))
	for row: Dictionary in rows:
		if not row.has("error"):
			print("MARK %s: material %s:%d srgb %s, colour %s:%d" % [row.mark, row.file, row.material_line, row.srgb, row.file, row.colour_line])
