extends SceneTree

# World 1's three acts of light and the 2010 finish (W46-03; WORLD1-DEMO-CATALYST.md C1, ruling ei).
#   - The dam (dawn), the flume (morning) and the Slag Bowl (noon's sun, its own gold light) are three looks, not one: every pair's
#     light colours (sun, ambient, fog lean, sky zenith, horizon and glow) sit ACT_MIN_DE or more apart, mean CIE76.
#   - The colour law: HAZARD is for live danger only, so no colour in any act's row sits within HAZARD_MIN_DE of it.
#   - Fleet paint takes the bone edge and rim layer, which glows a cool sky tint in shade; a casting (edge 0 bake, wear 0.5 everywhere) gets no bone;
#     brass is one satin finish whether a script builds it or a model's brass slot carries it.
#   - The palette holds the wave's later colours: the Kindness purple inside hue 300 to 330 (ruling ci) and a sodium
#     floodlight amber apart from AMBER and HAZARD.
#   - Worlds 2 and 3 are parked (ruling at): every stage look there, bare and with its map, is the one at 1266fec1.
#   - PF-47: at every distance a park prop or hero has a detail level drawn whole, so no hand-over is see-through, and
#     never two at once, so no band draws a prop twice.
#   - The seven code-drawn player marks' colour sites resolve (tools/vertex_colour_probe.gd, the hand-off to W46-13), and
#     every one of their materials reads its colours as sRGB (W46-13), so none washes out on the PC's renderer.
#   - Dam Night Shift (W46-13): its row is picked only by its look id, sits ACT_MIN_DE or more from each of the three acts,
#     keeps clear of HAZARD and of the Kindness purple; every floodlight mast passes the park prop placement rules as a
#     tall prop; the night's dressing carries no collider, and its lights stay in the tree, dark, when the day returns.
# Planted, each must fail its own judge: an act copied from another, a glow set to HAZARD, the old cross-fade ranges,
# two levels whole over one band, a night copied from the dawn, a mast stood on a ride line, a mark with the switch off.
# Evidence limit: headless values. The look is judged from the Mac stills and the sheet on the W46-03 pull request.

const T := preload("res://tests/support/t.gd")
const WorldLook := preload("res://src/presentation/world_look.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Palette := preload("res://src/core/palette.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Bars := preload("res://src/core/defence_bars.gd")
const Probe := preload("res://tools/vertex_colour_probe.gd")
const ShiftVariants := preload("res://src/core/shift_variants.gd")

# The camp lamp post the night stands as a floodlight mast (assets/models/camp/camp_lamp_post.glb, its whole aabb at scale 1):
# 4.5 m tall, its lamp arm reaching 1.2 m off the pole.
const MAST_HEIGHT_M := 4.5
const MAST_RADIUS_M := 1.2
# Mean CIE76 over the act keys between any two acts; 12 is a step two stills side by side show at a glance (ours, inferred).
const ACT_MIN_DE := 12.0
# No act colour within this of HAZARD (colour_cvd_test's 20 floor, plus margin).
const HAZARD_MIN_DE := 25.0
const ACT_KEYS := ["sun_color", "ambient", "fog_tint"]
const GRADE_KEYS := ["top", "horizon", "glow"]
const EXPECTED_CHECKS := 51
# sha256 of var_to_str(WorldLook.stage_look(stage, world, map)) at 1266fec1, the wave's base, for every world 2 and 3
# stage bare, with its stage map and with the park of its time. Re-pin only with a ruling that unparks the world.
const PARKED_PINS := {
	"3 2 ": "6f1b40c8db768f00dae1cf4be8740524ccb7c73d8eb842e5cf6412bec22e3836",
	"3 2 dig": "6f1b40c8db768f00dae1cf4be8740524ccb7c73d8eb842e5cf6412bec22e3836",
	"3 2 park_pit": "8b4335454baa5842ae6bbe03e5247b09afe017d11d7f53d5be059eb0c8a0e036",
	"4 2 ": "dfc3137051e51054b8eeda107b8c2bd8dedfca636623e03e3d398e66fb0729c8",
	"4 2 dig_deep": "dfc3137051e51054b8eeda107b8c2bd8dedfca636623e03e3d398e66fb0729c8",
	"4 2 park_sinkhole": "2b153bba2223158d1f173665c2dc110256cc958afa3cc26d7b7bf46177026652",
	"5 3 ": "1fb84207ab17100af71b4b115086f3299bf72d8b0742011c80005c8a90af867d",
	"5 3 highdraft": "1fb84207ab17100af71b4b115086f3299bf72d8b0742011c80005c8a90af867d",
	"5 3 park_islands": "1fb84207ab17100af71b4b115086f3299bf72d8b0742011c80005c8a90af867d",
	"6 3 ": "d2e39c36fc456c2a7c81577547915b56e1f06b5a56fbc80f2ee51bb17e6d51ce",
	"6 3 highdraft_crown": "d2e39c36fc456c2a7c81577547915b56e1f06b5a56fbc80f2ee51bb17e6d51ce",
	"6 3 park_crown": "d2e39c36fc456c2a7c81577547915b56e1f06b5a56fbc80f2ee51bb17e6d51ce",
}

var _t := T.new("world_look_acts_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_acts()
	_parked()
	_finish()
	_palette()
	_hand_overs()
	_marks()
	_night()
	_night_masts()
	await _night_dress()
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
	var over: Dictionary = WorldLook.DAYLIT_ARENAS.brindle.over
	_t.check("the bowl's gold is its own arena row over noon's sun: its smoke, ambient and sky are its own, its sun angle noon's",
		looks.bowl.fog.color == over.fog.color and looks.bowl.ambient == over.ambient and looks.bowl.grade.horizon == over.grade.horizon
		and looks.bowl.ambient != WorldLook.TIME_ROWS.noon.ambient and looks.bowl.sun_rotation == WorldLook.TIME_ROWS.noon.sun_rotation)
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
	_t.check("owned Fleet paint takes the bone edge and rim layer in place", mesh.surface_get_material(0) == paint
		and paint.next_pass == BakeLook.edge_lift())
	var shader := (BakeLook.edge_lift().shader as Shader).code
	var sky: Color = BakeLook.edge_lift().get_shader_parameter("sky")
	_t.check("the layer mixes toward bone, glows a cool sky tint in shade and draws nothing where it lifts nothing", shader.contains("blend_mix")
		and shader.contains("discard") and BakeLook.edge_lift().get_shader_parameter("bone") == Palette.SAND and sky.b > sky.r
		and float(BakeLook.edge_lift().get_shader_parameter("glow")) > 0.0)
	_t.check("the rim rises toward the silhouette and is none head on", BakeLook.lift_alpha(0.5, 1.0) == 0.0
		and is_equal_approx(BakeLook.lift_alpha(0.5, 0.0), BakeLook.RIM) and BakeLook.lift_alpha(0.5, 0.2) > BakeLook.lift_alpha(0.5, 0.6))
	var shaded := mesh.surface_get_material(1) as StandardMaterial3D
	_t.check("rubber is shaded but takes no edge layer", shaded.get_meta("bake_look", false) and shaded.next_pass == null)
	var brass_twin := mesh.surface_get_material(2) as StandardMaterial3D
	_t.check("a model's brass slot takes the one satin brass", brass_twin.get_meta("brass_finish", false)
		and is_equal_approx(brass_twin.roughness, Palette.BRASS_FINISH.roughness) and is_equal_approx(brass_twin.metallic, Palette.BRASS_FINISH.metallic))
	var shell := mesh.surface_get_material(3) as StandardMaterial3D
	_t.check("a casting's shell takes no edge layer, and its edge 0 bake gives no bone head on", shell.next_pass == null and BakeLook.lift_alpha(0.5) == 0.0)
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


# Worlds 2 and 3 are parked: every stage look there is its 1266fec1 one (the noon row is the open pit's, not the bowl's).
func _parked() -> void:
	var moved := []
	for key: String in PARKED_PINS:
		var parts := key.split(" ")
		var look := WorldLook.stage_look(int(parts[0]), int(parts[1]), parts[2])
		if var_to_str(look).sha256_text() != PARKED_PINS[key]:
			moved.append(key)
	_t.check("worlds 2 and 3 keep their 1266fec1 stage looks", moved.is_empty() and PARKED_PINS.size() == 12, str(moved))


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


# Where a level is drawn whole: from its begin plus begin margin (0 when it has no begin) to its end less end margin.
static func whole_span(level: Array) -> Vector2:
	var lo: float = float(level[0]) + float(level[2]) if float(level[0]) > 0.0 else 0.0
	var hi: float = float(level[1]) - float(level[3]) if float(level[1]) > 0.0 else INF
	return Vector2(lo, hi)


# The longest band, in metres, over which two levels are both drawn whole (0 when they only meet at a point).
static func double_whole(levels: Array) -> float:
	var widest := 0.0
	for i in levels.size():
		for j in range(i + 1, levels.size()):
			var a := whole_span(levels[i])
			var b := whole_span(levels[j])
			widest = maxf(widest, minf(a.y, b.y) - maxf(a.x, b.x))
	return widest


func _hand_overs() -> void:
	for spec in [["hero", true, false], ["prop", false, false], ["prop at the lowest preset", false, true]]:
		var levels := ParkProps.levels(spec[1], spec[2])
		var ghost := first_ghost(levels)
		var twice := double_whole(levels)
		_t.check("PF-47: a %s has a level drawn whole at every distance, never two over a band" % spec[0], ghost < 0.0 and twice <= 0.0,
			"first ghost at %.2f m, two whole over %.2f m" % [ghost, twice])
	_t.check("planted: two levels whole over one band (the next begins 12 m early) fails",
		double_whole([[0.0, 70.0, 0.0, 8.0], [50.0, 180.0, 0.0, 8.0]]) > 0.0)
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
	var washed := rows.filter(func(row: Dictionary) -> bool: return not washed_free(row))
	_t.check("every mark's material reads its colours as sRGB (W46-13)", washed.is_empty(), str(washed.map(func(row): return row.mark)))
	var planted: Dictionary = rows[0].duplicate()
	planted.srgb = false
	_t.check("planted: a mark with the switch off fails", not washed_free(planted))


# A mark whose material says its written colours are sRGB draws its own colour on the PC's renderer (the probe's
# --marks=1 measures it on a display).
static func washed_free(row: Dictionary) -> bool:
	return not row.has("error") and bool(row.get("srgb", false))


func _night() -> void:
	var dam := StageDefs.first_of(1)
	var map := String(StageDefs.of(dam).get("map", ""))
	var night := WorldLook.stage_look(dam, 1, map, {}, ShiftVariants.NIGHT_LOOK_ID)
	var looks := acts()
	_t.check("the night is picked by its look id alone: no id and an unknown id are the dam's own look",
		WorldLook.stage_look(dam, 1, map, {}, "") == looks.dam and WorldLook.stage_look(dam, 1, map, {}, "no_such_look") == looks.dam
		and night.get("look_id") == ShiftVariants.NIGHT_LOOK_ID and not looks.dam.has("look_id"))
	_t.check("the night look keeps the dam's own sky kind and fog density", night.sky == looks.dam.sky
		and is_equal_approx(float(night.fog.density), float(looks.dam.fog.density)))
	for id in ["dam", "flume", "bowl"]:
		var d := act_distance(night, looks[id])
		print("act distance night-%s: %.1f" % [id, d])
		_t.check("the night and the %s light differ by %.0f or more (mean CIE76)" % [id, ACT_MIN_DE], d >= ACT_MIN_DE, "%.1f" % d)
	var planted: Dictionary = night.duplicate(true)
	for key in ACT_KEYS:
		planted[key] = looks.dam[key]
	planted.grade = looks.dam.grade.duplicate()
	_t.check("planted: a night copied from the dawn fails the distance", act_distance(planted, looks.dam) < ACT_MIN_DE)
	var near := nearest_hazard(night)
	_t.check("the night uses no colour within %.0f of HAZARD (its sodium lamps included)" % HAZARD_MIN_DE, near >= HAZARD_MIN_DE
		and colours_in(night, []).has(Palette.SODIUM), "nearest %.1f" % near)
	var purple := colours_in(night, []).filter(func(c: Color) -> bool:
		return Bars.cie76(Color(c, 1.0), Palette.KINDNESS) < 20.0 or (c.s > 0.2 and c.h * 360.0 >= 300.0 and c.h * 360.0 <= 330.0))
	_t.check("the night has no purple: hue 300 to 330 is the Foreman's Kindness alone (ruling ci)", purple.is_empty(), str(purple))
	_t.check("the night's sky is darker than the dawn's: its zenith and horizon both fall in lightness",
		(night.grade.top as Color).get_luminance() < (looks.dam.grade.top as Color).get_luminance()
		and (night.grade.horizon as Color).get_luminance() < (looks.dam.grade.horizon as Color).get_luminance())


# A floodlight mast as the park prop rules see it: a tall prop of the mast's own footprint, seated on the ground.
static func mast_instance(at: Vector2, ground: Callable, floods: Dictionary) -> Dictionary:
	var radius := MAST_RADIUS_M * float(floods.scale)
	var y: float = (ground.call(at.x, at.y, 0.0) as Vector3).y
	var floating := 0.0
	var steepest := 0.0
	for k in 8:
		var rim := at + Vector2.from_angle(k * TAU / 8.0) * radius
		var rim_y: float = (ground.call(rim.x, rim.y, 0.0) as Vector3).y
		floating = maxf(floating, y - rim_y)
		steepest = maxf(steepest, rad_to_deg(atan(absf(rim_y - y) / radius)))
	return {"vignette": "night_flood", "kind": "night_flood", "class": ParkProps.PROP, "tags": ["tall"], "pos": Vector3(at.x, y, at.y),
		"radius": radius, "height": MAST_HEIGHT_M * float(floods.scale), "float_m": floating, "slope_deg": steepest, "line_clear_m": 0.0,
		"litter": false}


func _night_masts() -> void:
	var floods: Dictionary = WorldLook.LOOK_ROWS[ShiftVariants.NIGHT_LOOK_ID].floods
	var world := ParkProps.world_for("park_dam")
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	var bad := []
	for row: Array in floods.at:
		var fails := ParkProps.check_one(mast_instance(Vector2(row[0], row[1]), world["ground"], floods), c)
		if not fails.is_empty():
			bad.append([row, fails.map(func(f): return f.rule)])
	_t.check("every night floodlight mast passes the park prop placement rules as a tall prop", bad.is_empty() and floods.at.size() >= 10,
		str(bad))
	var on_line: Vector2 = Vector2(-150, -690)
	_t.check("planted: a mast stood on the run's spawn fails the placement rules",
		not ParkProps.check_one(mast_instance(on_line, world["ground"], floods), c).is_empty())


# A ground at height 0 and a terrain double for the night's dressing.
class FlatTerrain:
	var environment := Environment.new()
	func height(_x: float, _z: float) -> float:
		return 0.0


class StillBall:
	func shown_position() -> Vector3:
		return Vector3(-30.0, 0.0, -560.0)


func _night_dress() -> void:
	var host := Node3D.new()
	var stage := Node3D.new()
	host.add_child(stage)
	root.add_child(host)
	var holder := Node3D.new()
	holder.name = WorldLook.NODE
	stage.add_child(holder)
	var terrain := FlatTerrain.new()
	var night := WorldLook.stage_look(1, 1, "park_dam", {}, ShiftVariants.NIGHT_LOOK_ID)
	WorldLook.NightShift.enter(stage, terrain, night, StillBall.new())
	var dress := holder.get_node_or_null(WorldLook.NightShift.DRESS)
	var lights := host.get_node_or_null(WorldLook.NightShift.LIGHTS)
	var masts: int = night.floods.at.size()
	_t.check("the night dresses the stage with its masts and their lamp glows", dress != null
		and dress.find_children("Glow*", "MeshInstance3D", false, false).size() == masts and dress.heads().size() == masts)
	var solid := dress.find_children("*", "CollisionObject3D", true, false) + dress.find_children("*", "CollisionShape3D", true, false) if dress != null else [null]
	_t.check("the night's dressing carries no collider (the camp lamp post's own is dropped)", solid.is_empty(), str(solid))
	var lamps: Array = lights.find_children("*", "Light3D", false, false) if lights != null else []
	_t.check("the night's lights hang on the stage roots' parent, sodium, shadowless", lamps.size() == int(night.floods.lamps.count)
		+ night.floods.dam.at.size() and lamps.all(func(l: Light3D) -> bool: return l.light_color == Palette.SODIUM and not l.shadow_enabled))
	var ids := lamps.map(func(l): return l.get_instance_id())
	WorldLook.NightShift.enter(stage, terrain, WorldLook.stage_look(1, 1, "park_dam"), StillBall.new())
	await process_frame
	await process_frame
	var kept := ids.filter(func(id): return instance_from_id(id) != null)
	_t.check("the day takes the dressing away but keeps every night light, dark", holder.get_node_or_null(WorldLook.NightShift.DRESS) == null
		and kept.size() == ids.size() and kept.all(func(id): return not (instance_from_id(id) as Light3D).visible))
	host.free()
