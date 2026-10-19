extends SceneTree

# Park prop dressing (Dressing lane, design-v3/park/DRESSING-KITS.md; src/presentation/park_props.gd). Rule: every park that
# has a vignette file (src/world/park/props/park_<park>.json) keeps its schema, names only kinds and variants its kit has,
# has a kit of at least MIN_KINDS kinds with at least two variants each, expands to instances that pass every placement
# rule (line_clear, route_lane, keepout, home_clear, play_rect, slope, seat), expands the same twice, and builds views that
# carry a visibility range, cast no shadow but a hero's LOD0, and collide with nothing. Until a park has a file, the
# fixture (tests/fixtures/park_props: a manifest over existing GLBs and four spots on park_dam) stands in for the whole
# check, so the pass is never empty, and a park without a file is not counted. Planted controls that must fail: an
# instance on a line, one inside a keepout, one beside a home, tier edges at the line and a kicker run-out.
#
# Each park's vignette file pins its own expansion fingerprint in a top-level "pin" field, so the six park PRs never
# edit a shared table here. A park file without a pin fails and prints the value to pin.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")

const FIXTURE_FILE := "res://tests/fixtures/park_props/park_dam.json"
const FIXTURE_MAP := "park_dam"
const MIN_KINDS := 12
const SYNTHETIC_VIGNETTES := 60

var _t := T.new("park_props_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var real := 0
	for id in ParkProps.PARKS:
		var path: String = ParkProps.FILE_DIR + id + ".json"
		if not FileAccess.file_exists(path):
			continue
		real += 1
		var world := ParkProps.world_for(id)
		var list := _check_park(id, path, MIN_KINDS, 2, world)
		var got := ParkProps.fingerprint(list)
		var file: Dictionary = ParkProps.load_json(path)
		print("park_props_test: %s fingerprint %d" % [id, got])
		_t.check("%s pins its fingerprint" % id, file.has("pin"))
		_t.eq("%s expansion matches its pin" % id, got, int(file.get("pin", -1)))
	print("park_props_test: %d of %d parks have a vignette file; %d without one" % [real, ParkProps.PARKS.size(), ParkProps.PARKS.size() - real])

	var world := ParkProps.world_for(FIXTURE_MAP)
	_t.check("the fixture world loads", world["map"].ok and world["stage"] == 1)
	var list := _check_park(FIXTURE_MAP, FIXTURE_FILE, 3, 2, world)
	_t.check("the fixture expands to instances", list.size() > 0, str(list.size()))
	var file := ParkProps.load_json(FIXTURE_FILE)
	var kit := ParkProps.load_json(String(file["kit"]))
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	_check_build(list, kit)
	_check_kits(kit)
	_check_controls(world, kit, c)
	_check_file_bands(file, kit)
	_check_ground_rows(kit)
	_check_low_ground(kit)
	_check_synthetic(file, kit, world)
	_check_prepare(file, kit, world, list)
	await _check_game()
	quit(_t.verdict())


# Schema, kit, placement, determinism for one vignette file. Returns the expanded instances.
func _check_park(id: String, path: String, min_kinds: int, min_variants: int, world: Dictionary) -> Array:
	var file := ParkProps.load_json(path)
	var kit := ParkProps.load_json(String(file.get("kit", "")))
	_t.check("%s: vignette file and kit load" % id, not file.is_empty() and not kit.is_empty(), path)
	_t.eq("%s: file map is the park" % id, file.get("map"), id)
	_t.eq("%s: kit schema and glbs" % id, ParkProps.kit_errors(kit, min_kinds, min_variants), [])
	_t.eq("%s: file schema and kit names" % id, ParkProps.file_errors(file, kit), [])
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	_t.eq("%s: every home site and line waypoint resolves" % id, c.unresolved, [])
	var list := ParkProps.expand(file, kit, world["map"], world["ground"], c)
	var authored := 0
	for spot: Dictionary in file.get("spots", []):
		authored += (file["templates"][spot["template"]]["props"] as Array).size()
	var vignette := list.filter(func(i: Dictionary) -> bool: return not i["litter"])
	_t.eq("%s: every authored prop expands" % id, vignette.size(), authored)
	var violations := ParkProps.validate(list, world["map"], world["ground"], world["stage"], c)
	_t.check("%s: %d instances (%d litter) pass every placement rule" % [id, list.size(), list.size() - vignette.size()], violations.is_empty(),
		"%d violations, first %s" % [violations.size(), str(violations.slice(0, 3))])
	var again := ParkProps.expand(file, kit, world["map"], world["ground"])
	_t.eq("%s: expansion is deterministic" % id, ParkProps.fingerprint(again), ParkProps.fingerprint(list))
	var max_float := 0.0
	for inst: Dictionary in list:
		max_float = maxf(max_float, inst["float_m"])
	print("park_props_test: %s max foot float %.3f m over %d instances" % [id, max_float, list.size()])
	_t.check("%s: no foot floats past %.2f m" % [id, ParkProps.SEAT_FLOAT_MAX_M], max_float <= ParkProps.SEAT_FLOAT_MAX_M, str(max_float))
	return list


func _check_build(list: Array, kit: Dictionary) -> void:
	ParkProps.release_shared()
	var built := ParkProps.build_nodes(list, kit)
	root.add_child(built)
	var views := built.find_children("*", "GeometryInstance3D", true, false)
	_t.check("the build makes views", views.size() > 0, str(views.size()))
	var bad_range := []
	var bad_shadow := []
	var bad_meta := []
	var heroes := 0
	var multis := 0
	var litter_views := 0
	for view: GeometryInstance3D in views:
		var lod: int = view.get_meta("dress_lod", -1)
		var klass: String = view.get_meta("dress_class", "")
		var litter := view.get_parent().name == "Litter"
		litter_views += 1 if litter else 0
		if view.visibility_range_end <= 0.0:
			bad_range.append(view.name)
		var table: Array = ParkProps.HERO_RANGES if klass == ParkProps.HERO else ParkProps.PROP_RANGES
		if lod < 0 or lod > 2:
			bad_meta.append(view.name)
			continue
		if litter:
			if lod != 1 or view.visibility_range_begin != 0.0 or view.visibility_range_end < ParkProps.LITTER_RANGE[1]:
				bad_range.append(String(view.name) + " litter range")
		elif view.visibility_range_begin != table[lod][0] or view.visibility_range_end != table[lod][1]:
			bad_range.append(String(view.name) + " contract range")
		if view.visibility_range_fade_mode != GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF:
			bad_range.append(String(view.name) + " fade")
		var want_shadow := klass == ParkProps.HERO and lod == 0
		if (view.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF) != want_shadow:
			bad_shadow.append(view.name)
		if not view.is_in_group(ParkProps.GROUP) or not view.has_meta("dress_kind"):
			bad_meta.append(view.name)
		if klass == ParkProps.HERO:
			heroes += 1
		if view is MultiMeshInstance3D:
			multis += 1
			if (view as MultiMeshInstance3D).multimesh.instance_count < 1 or (view as MultiMeshInstance3D).multimesh.transform_format != MultiMesh.TRANSFORM_3D:
				bad_meta.append(String(view.name) + " multimesh")
	var colourless := []
	for view: GeometryInstance3D in views:
		var shown: Mesh = (view as MultiMeshInstance3D).multimesh.mesh if view is MultiMeshInstance3D else (view as MeshInstance3D).mesh
		colourless.append_array(ParkProps.colour_errors(shown, String(view.name), view))
	_t.eq("every built MultiMesh and hero mesh surface has ARRAY_COLOR and a vertex-colour material", colourless.slice(0, 3), [])
	_t.eq("every view has a visibility range end and the contract's ranges", bad_range, [])
	_t.eq("shadows are off but a hero's LOD0", bad_shadow, [])
	_t.eq("every view is grouped and tagged", bad_meta, [])
	_t.check("the fixture builds hero views (3 LODs each) and batched props", heroes > 0 and heroes % 3 == 0 and multis > 0, "%d hero, %d multimesh, %d litter" % [heroes, multis, litter_views])
	_t.check("no collision objects under the props", built.find_children("*", "CollisionObject3D", true, false).is_empty() and built.find_children("*", "CollisionShape3D", true, false).is_empty())
	# One batch per (mesh, LOD) per vignette: names are unique inside a holder and a prop kind has three LODs.
	var names_unique := true
	for holder in built.get_children():
		var seen := {}
		for view in holder.get_children():
			names_unique = names_unique and not seen.has(view.name)
			seen[view.name] = true
	_t.check("each (mesh, LOD) has one view per vignette", names_unique)
	# The far LOD of a vignette's props is one merged mesh (one draw), carrying every non-hero member.
	var far_ok := true
	var far_tris_ok := true
	var far_views := 0
	for holder in built.get_children():
		if holder.name == "Litter":
			continue
		var members := list.filter(func(i: Dictionary) -> bool: return not i["litter"] and "Vignette_" + String(i["vignette"]) == String(holder.name) and i["class"] != ParkProps.HERO)
		var far := holder.find_children("*", "GeometryInstance3D", false, false).filter(func(v: Node) -> bool: return v.get_meta("dress_lod", -1) == 2 and v.get_meta("dress_class", "") != ParkProps.HERO)
		far_views += far.size()
		far_ok = far_ok and far.size() == (1 if not members.is_empty() else 0) and not (far[0] is MultiMeshInstance3D if not far.is_empty() else false) \
			and (far.is_empty() or int(far[0].get_meta("dress_count")) == members.size())
		var want_tris := 0
		for inst: Dictionary in members:
			want_tris += int(kit["kinds"][inst["kind"]]["variants"][inst["v"]]["tris"][2])
		if not far.is_empty():
			var arrays: Array = ((far[0] as MeshInstance3D).mesh as ArrayMesh).surface_get_arrays(0)
			far_tris_ok = far_tris_ok and (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 == want_tris
	_t.check("each vignette's props share one merged LOD2 view carrying every member and its LOD2 triangles", far_ok and far_tris_ok and far_views > 0, "%d far views" % far_views)
	built.free()
	var low := ParkProps.build_nodes(list, kit, true)
	var low_litter := low.get_node_or_null("Litter")
	var lod0 := low.find_children("*_L0", "MultiMeshInstance3D", true, false)
	_t.check("the lowest preset drops litter and halves prop LOD0 and LOD1", low_litter == null and not lod0.is_empty() \
		and is_equal_approx((lod0[0] as GeometryInstance3D).visibility_range_end, ParkProps.PROP_RANGES[0][1] * ParkProps.LOW_RANGE_SCALE))
	low.free()


const FLOORS := {ParkProps.HERO: [6000, 20000], ParkProps.PROP: [300, 3000]}
const PROP_LOD2_MIN_TRIS := 40
const PERCH_MIN_HEIGHT_M := 6.0


# Every kit manifest the repo carries (the fixture's, plus assets/models/park/props/*/manifest.json): triangle budgets by class and
# LOD, vertex colours on every LOD0 mesh, and the optional perch anchors.
func _check_kits(fixture_kit: Dictionary) -> void:
	var kits := {"fixture": fixture_kit}
	var base := "res://assets/models/park/props/"
	for dir in DirAccess.get_directories_at(base):
		var path := base + dir + "/manifest.json"
		if FileAccess.file_exists(path):
			kits[dir] = ParkProps.load_json(path)
	var bad_tris := []
	var bad_colour := []
	var bad_perch := []
	var variants := 0
	for name in kits:
		bad_perch.append_array(_perch_errors(kits[name], name))
		for kind in kits[name].get("kinds", {}):
			var def: Dictionary = kits[name]["kinds"][kind]
			for v in def["variants"]:
				var row: Dictionary = def["variants"][v]
				var label := "%s/%s/%s" % [name, kind, v]
				variants += 1
				bad_tris.append_array(_tri_errors(label, String(def["class"]), row["tris"], name == "fixture"))
				var probe := MeshInstance3D.new()
				probe.mesh = ParkProps._mesh(String(row["lod"][0]))
				ParkProps.style_view(probe)
				bad_colour.append_array(ParkProps.colour_errors(probe.mesh, label, probe))
				probe.free()
	_t.check("%d kit variants read" % variants, variants > 0)
	_t.eq("LOD triangles: LOD0 in the class floor and cap, LOD1 40 to 60%, LOD2 10 to 20% (props at least 40)", bad_tris.slice(0, 4), [])
	_t.eq("every kit LOD0 mesh has ARRAY_COLOR and a vertex-colour material", bad_colour.slice(0, 4), [])
	_t.eq("every perch is three finite numbers inside the variant's bounds and at least 6 m up", bad_perch.slice(0, 4), [])
	# Planted: the budget and perch checks must catch a bad row, and a mesh whose imported material ignores COLOR_0 must fail.
	_t.check("planted: LOD0 under the hero floor fails", not _tri_errors("p", ParkProps.HERO, [5000, 2500, 750], false).is_empty())
	_t.check("planted: LOD1 at 70% fails", not _tri_errors("p", ParkProps.PROP, [1000, 700, 150], false).is_empty())
	_t.check("planted: a prop LOD2 under 40 triangles fails", not _tri_errors("p", ParkProps.PROP, [300, 150, 39], false).is_empty())
	_t.check("planted: a prop at 1000 / 500 / 150 passes", _tri_errors("p", ParkProps.PROP, [1000, 500, 150], false).is_empty())
	var perch_kit := {"kinds": {"k": {"variants": {"a": {"height": 7.0, "radius": 2.0, "perch": [0.0, 7.0, 0.0]}}}}}
	_t.eq("planted: a sound perch passes", _perch_errors(perch_kit, "p"), [])
	for bad in [[0.0, 5.0, 0.0], [0.0, 9.0, 0.0], [3.0, 7.0, 0.0], [0.0, 7.0], [0.0, NAN, 0.0]]:
		perch_kit["kinds"]["k"]["variants"]["a"]["perch"] = bad
		_t.check("planted: perch %s fails" % var_to_str(bad), not _perch_errors(perch_kit, "p").is_empty())
	var path := String(fixture_kit["kinds"].values()[0]["variants"].values()[0]["lod"][0])
	var raw := _raw_mesh(path)
	var view := MeshInstance3D.new()
	view.mesh = raw
	_t.check("planted: the imported mesh, its material ignoring COLOR_0, fails the colour check", not ParkProps.colour_errors(raw, "raw", view).is_empty())
	ParkProps.style_view(view)
	_t.eq("planted: style_view fixes it", ParkProps.colour_errors(raw, "styled", view), [])
	var flag_off := StandardMaterial3D.new()
	view.material_override = flag_off
	_t.check("planted: a view whose material has vertex_color_use_as_albedo off fails", not ParkProps.colour_errors(raw, "off", view).is_empty())
	view.free()


func _raw_mesh(path: String) -> Mesh:
	var scene: Node = (load(path) as PackedScene).instantiate()
	var found := scene.find_children("*", "MeshInstance3D", true, false)
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	scene.free()
	return mesh


# LOD0 within the class floor and cap (the fixture's stand-in GLBs are exempt from the floor), LOD1 40 to 60%, LOD2 10 to 20% of LOD0.
func _tri_errors(label: String, klass: String, tris: Array, fixture: bool) -> Array:
	var errors := []
	var lod0 := float(tris[0])
	var bounds: Array = FLOORS[klass]
	if lod0 > bounds[1] or (lod0 < bounds[0] and not fixture):
		errors.append("%s LOD0 %d tris outside %s %d to %d" % [label, tris[0], klass, bounds[0], bounds[1]])
	if fixture:
		return errors
	if float(tris[1]) < lod0 * 0.4 or float(tris[1]) > lod0 * 0.6:
		errors.append("%s LOD1 %d is %.0f%% of LOD0, want 40 to 60" % [label, tris[1], 100.0 * tris[1] / lod0])
	if float(tris[2]) < lod0 * 0.1 or float(tris[2]) > lod0 * 0.2 or (klass == ParkProps.PROP and tris[2] < PROP_LOD2_MIN_TRIS):
		errors.append("%s LOD2 %d is %.0f%% of LOD0, want 10 to 20 (props at least %d)" % [label, tris[2], 100.0 * tris[2] / lod0, PROP_LOD2_MIN_TRIS])
	return errors


# design-v3/park/PERCH-ANCHOR.md: a variant's optional perch is [x, y, z], finite, above the foot, no more than 0.5 m over its height;
# also inside the footprint radius and on a variant at least PERCH_MIN_HEIGHT_M tall.
func _perch_errors(kit: Dictionary, name: String) -> Array:
	var errors := []
	for kind in kit.get("kinds", {}):
		for v in kit["kinds"][kind]["variants"]:
			var row: Dictionary = kit["kinds"][kind]["variants"][v]
			if not row.has("perch"):
				continue
			var label := "%s/%s/%s perch" % [name, kind, v]
			var perch = row["perch"]
			if not perch is Array or (perch as Array).size() != 3 or not (perch as Array).all(func(n) -> bool: return (n is float or n is int) and is_finite(float(n))):
				errors.append(label + " is not three finite numbers")
				continue
			var radius := float(row["radius"]) + 0.01
			if float(perch[1]) <= 0.0 or float(perch[1]) > float(row["height"]) + 0.5:
				errors.append("%s y %s is outside 0 to height %s (+0.5)" % [label, str(perch[1]), str(row["height"])])
			if absf(float(perch[0])) > radius or absf(float(perch[2])) > radius:
				errors.append("%s x/z %s is outside the footprint radius %s" % [label, str(perch), str(row["radius"])])
			if float(row["height"]) < PERCH_MIN_HEIGHT_M or float(perch[1]) < PERCH_MIN_HEIGHT_M:
				errors.append("%s on a variant %s tall at y %s: want at least %.0f m" % [label, str(row["height"]), str(perch[1]), PERCH_MIN_HEIGHT_M])
	return errors


# Litter band_m must sit inside the tier bands (near at least 6, far at most 64).
func _check_file_bands(file: Dictionary, kit: Dictionary) -> void:
	for band in [[3.0, 40.0], [10.0, 70.0]]:
		var bad := file.duplicate(true)
		bad["litter"]["band_m"] = band
		_t.check("planted: litter band %s is a file error" % str(band), not ParkProps.file_errors(bad, kit).is_empty())
	var ok := file.duplicate(true)
	ok["litter"]["band_m"] = [6.0, 64.0]
	_t.eq("planted: litter band [6, 64] passes", ParkProps.file_errors(ok, kit), [])


# ground_rows, the explicit surfaces: islands' sky_island stamps are 1,600 m long, so ParkSites leaves them unbucketed; the
# context indexes them itself. Listed rows are placement surfaces inset GROUND_ROW_INSET_M; every other rule still applies.
func _check_ground_rows(kit: Dictionary) -> void:
	var world := ParkProps.world_for("park_islands")
	var map = world["map"]
	var ground: Callable = world["ground"]
	var c := ParkProps.context(map, ground, world["stage"])
	var row := {}
	for r: Dictionary in map.park["park_rows"]:
		if r["id"] == "lookout_mesa" or r["id"] == "anvil_rock":
			row = r
			if r["id"] == "anvil_rock":
				break
	_t.check("islands has a long stamped sky_island row", not row.is_empty() and float(row["size"][2]) > ParkProps.ParkSites.STAMP_KEEP_M)
	_t.check("the context indexes the long sky_island stamps ParkSites skips", c.stamped.size() > 0)
	var half := ParkMap.footprint_half_extents(row)
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var centre := ParkProps._pair(row["at"])
	var none := func(_inst: Dictionary) -> void:
		pass
	# Candidate points on a grid in the row's frame (x across half.x, y along half.y), world = centre + local.rotated(-yaw).
	var inner := []
	var edge5 := []
	var outer := []
	for iy in range(-int(half.y) + 12, int(half.y) - 12, 20):
		for ix in [-1, 1]:
			edge5.append(centre + Vector2(ix * (half.x - 5.0), iy).rotated(-yaw))
		for dx in range(-int(half.x) + 14, int(half.x) - 14, 14):
			inner.append(centre + Vector2(dx, iy).rotated(-yaw))
	for dx in range(-int(half.x) + 14, int(half.x) - 14, 14):
		for sy in [-1, 1]:
			edge5.append(centre + Vector2(dx, sy * (half.y - 5.0)).rotated(-yaw))
	var unlisted := _only("keepout", inner, kit, c, ground, none)
	_t.check("planted: an unlisted sky_island point turns keepout red (a long stamp ParkSites skips)", not unlisted.is_empty(), "%d candidates" % inner.size())
	var listed := ParkProps.context(map, ground, world["stage"])
	listed.use_ground_rows([row["id"]])
	var passes := _only_rules([], inner, kit, listed, ground)
	_t.check("planted: a listed sky_island point at least 8 m inside passes every rule", not passes.is_empty())
	var inset := _only_rules(["ground_row"], edge5, kit, listed, ground)
	_t.check("planted: a listed sky_island point 5 m inside the edge fails ground_row alone", not inset.is_empty())
	var outside := _only_rules(["ground_row"], _grid(map.play_rect, 40), kit, listed, ground)
	_t.check("planted: a point outside every listed row fails ground_row alone", not outside.is_empty())
	_t.check("planted: without ground_rows the same outside point is not ground_row's to judge", not outside.is_empty() and not _rules(outside, c).has("ground_row"))
	# Schema: a home row, an unknown id and a bare string are file errors.
	var file := {"schema": ParkProps.FILE_SCHEMA, "map": "park_islands", "kit": "res://x", "templates": {"t": {"props": [{"kind": "fix_bench", "v": "*", "at": [0, 0]}]}}, "spots": [{"id": "s", "template": "t", "at": [0, 0]}]}
	var home_row := ""
	for h: Dictionary in map.park["home_rows"]:
		home_row = String(h["site"])
		break
	for bad in [[home_row], ["no_such_row"], "lookout_mesa", []]:
		var broken := file.duplicate(true)
		broken["ground_rows"] = bad
		_t.check("planted: ground_rows %s is a file error" % var_to_str(bad), ParkProps.file_errors(broken, kit, map).any(func(e: String) -> bool: return e.begins_with("ground_rows")))
	var fine := file.duplicate(true)
	fine["ground_rows"] = ["twin_fins"]
	_t.check("planted: listing a non-home row is no ground_rows error", not ParkProps.file_errors(fine, kit, map).any(func(e: String) -> bool: return e.begins_with("ground_rows")))
	_t.check("planted: a file without ground_rows has no ground_rows error", not ParkProps.file_errors(file, kit, map).any(func(e: String) -> bool: return e.begins_with("ground_rows")))


# low_ground_rows, low clutter in area rows (opt-in): crown's drop_ramp is a 160 by 200 m flow_line, islands' lookout_mesa a 1,600 m
# home stamp. A listed row admits instances up to LOW_GROUND_MAX_M; every other rule still applies.
func _check_low_ground(kit: Dictionary) -> void:
	var crown := ParkProps.world_for("park_crown")
	var cmap = crown["map"]
	var cground: Callable = crown["ground"]
	var row := _park_row(cmap, "drop_ramp")
	_t.check("crown has the drop_ramp flow_line", not row.is_empty() and row["element"] == "flow_line")
	var points := _row_grid(row, 6, 10)
	var plain := ParkProps.context(cmap, cground, crown["stage"])
	var listed := ParkProps.context(cmap, cground, crown["stage"])
	listed.use_low_ground_rows(["drop_ramp"])
	var low := 0.8
	var ok := _first_low([], points, kit, listed, cground, low)
	_t.check("planted: a 0.8 m prop inside a listed flow_line passes every rule", not ok.is_empty(), "%d candidates" % points.size())
	if not ok.is_empty():
		var at := Vector2(ok["pos"].x, ok["pos"].z)
		_t.eq("planted: a 1.4 m prop at the same point fails low_ground alone", _rules(_with(ok, "height", 1.4), listed), ["low_ground"])
		_t.eq("planted: a 1.0 m prop at the same point passes", _rules(_with(ok, "height", 1.0), listed), [])
		_t.eq("planted: the same 0.8 m point with the row unlisted fails keepout alone", _rules(ok, plain), ["keepout"])
		# A kicker run-out over the point: keepout, though the row is listed.
		var kicked := ParkProps.context(cmap, cground, crown["stage"])
		kicked.use_low_ground_rows(["drop_ramp"])
		var rows: Array = cmap.park["park_rows"]
		kicked.sites._keepouts = ParkProps.kicker_keepouts(kicked.sites._keepouts, [{"id": "planted_lip", "at": at - Vector2(0.0, 20.0), "dir": Vector2(0.0, 1.0), "width": 20.0}], rows)
		_t.eq("planted: a 0.8 m prop inside a listed row and a kicker run-out fails keepout", _rules(ok, kicked), ["keepout"])
		# A planted camp 10 m off: home_clear still binds in a listed row.
		var camped := ParkProps.context(cmap, cground, crown["stage"])
		camped.use_low_ground_rows(["drop_ramp"])
		camped.camps.append(at + Vector2(10.0, 0.0))
		_t.eq("planted: a 0.8 m prop 10 m from a camp inside a listed row fails home_clear alone", _rules(ok, camped), ["home_clear"])
	var near_line := _first_low(["line_clear"], _row_grid(row, 2, 4), kit, listed, cground, low, func(inst: Dictionary) -> bool:
		var d: float = listed.line_distance(Vector2(inst["pos"].x, inst["pos"].z)) - float(inst["radius"])
		return d > 2.0 and d < 5.5)
	_t.check("planted: a 0.8 m prop in a listed row about 4 m from a line fails line_clear alone", not near_line.is_empty())

	# Schema: narrow features and narrow area rows are file errors; a long home stamp and a big flow_line are not.
	var islands := ParkProps.world_for("park_islands")
	var imap = islands["map"]
	var file := {"schema": ParkProps.FILE_SCHEMA, "map": "park_islands", "kit": "res://x", "templates": {"t": {"props": [{"kind": "fix_bench", "v": "*", "at": [0, 0]}]}}, "spots": [{"id": "s", "template": "t", "at": [0, 0]}]}
	var rows_ok := func(ids: Array, map) -> bool:
		var f := file.duplicate(true)
		f["low_ground_rows"] = ids
		return not ParkProps.file_errors(f, kit, map).any(func(e: String) -> bool: return e.begins_with("low_ground_rows"))
	for narrow in ["lookout_lip", "net_carve", "ore_adit", "fin_chute", "mooring_mesa", "run_turn_wash", "no_such_row"]:
		_t.check("planted: listing %s is a file error" % narrow, not rows_ok.call([narrow], imap))
	_t.check("planted: an empty or non-list low_ground_rows is a file error", not rows_ok.call([], imap))
	var wide := file.duplicate(true)
	wide["low_ground_rows"] = "lookout_mesa"
	_t.check("planted: a bare-string low_ground_rows is a file error", ParkProps.file_errors(wide, kit, imap).any(func(e: String) -> bool: return e.begins_with("low_ground_rows")))
	_t.check("planted: the 1,600 m lookout_mesa home stamp is accepted", rows_ok.call(["lookout_mesa"], imap))
	_t.check("planted: a sky_island strip (anvil_rock) and a 240 by 140 m sky_island (twin_fins) are accepted", rows_ok.call(["anvil_rock", "twin_fins"], imap))
	_t.check("planted: crown's drop_ramp is accepted", rows_ok.call(["drop_ramp"], cmap))

	# A listed home stamp: the home's footprint stops being home_clear, its camps do not.
	var mesa := _park_row(imap, "lookout_mesa")
	var mesa_points := _row_grid(mesa, 20, 10)
	var iplain := ParkProps.context(imap, islands["ground"], islands["stage"])
	var ilisted := ParkProps.context(imap, islands["ground"], islands["stage"])
	ilisted.use_low_ground_rows(["lookout_mesa"])
	var spot := _first_low([], mesa_points, kit, ilisted, islands["ground"], low)
	_t.check("planted: a 0.8 m prop on a listed home stamp passes (no whole-footprint home_clear)", not spot.is_empty(), "%d candidates" % mesa_points.size())
	if not spot.is_empty():
		var rules := _rules(spot, iplain)
		_t.check("planted: the same point on the unlisted home stamp fails home_clear and keepout", rules.has("home_clear") and rules.has("keepout"), str(rules))
		_t.eq("planted: a 1.4 m prop there fails low_ground alone", _rules(_with(spot, "height", 1.4), ilisted).filter(func(r: String) -> bool: return r != "line_clear"), ["low_ground"])
		var at := Vector2(spot["pos"].x, spot["pos"].z)
		ilisted.camps.append(at + Vector2(10.0, 0.0))
		_t.eq("planted: a prop within 25 m of one of the stamp's camps fails home_clear alone", _rules(spot, ilisted), ["home_clear"])


func _park_row(map, id: String) -> Dictionary:
	for r: Dictionary in map.park["park_rows"]:
		if r["id"] == id:
			return r
	return {}


# World points on a grid of `step` m in a row's frame, inset `inset` m from its footprint edge (x across half.x, y along half.y).
func _row_grid(row: Dictionary, step: int, inset: int) -> Array:
	var half := ParkMap.footprint_half_extents(row)
	var yaw := deg_to_rad(float(row["yaw_deg"]))
	var centre := ParkProps._pair(row["at"])
	var out := []
	for ix in range(-int(half.x) + inset, int(half.x) - inset + 1, step):
		for iy in range(-int(half.y) + inset, int(half.y) - inset + 1, step):
			out.append(centre + Vector2(ix, iy).rotated(-yaw))
	return out


# The first candidate whose planted bench of `height` breaks exactly `rules` (and passes accept, if given); {} if none. The bench is
# laid flat and seated (slope and seat are other controls' to judge; crown's drop_ramp is a steep drop).
func _first_low(rules: Array, points: Array, kit: Dictionary, c, ground: Callable, height: float, accept := Callable()) -> Dictionary:
	for at: Vector2 in points:
		var inst := _with(_with(_with(_planted(kit, "fix_bench", at, ground), "height", height), "slope_deg", 0.0), "float_m", 0.0)
		if _rules(inst, c) == rules and (accept.is_null() or accept.call(inst)):
			return inst
	return {}


func _grid(rect: Rect2, step: int) -> Array:
	var out := []
	for x in range(int(rect.position.x) + step, int(rect.end.x), step):
		for z in range(int(rect.position.y) + step, int(rect.end.y), step):
			out.append(Vector2(x, z))
	return out


# The first candidate whose planted bench breaks exactly `rules` (in any order), {} if none.
func _only_rules(rules: Array, points: Array, kit: Dictionary, c, ground: Callable) -> Dictionary:
	for at: Vector2 in points:
		var inst := _planted(kit, "fix_bench", at, ground)
		var got := _rules(inst, c)
		got.sort()
		var want := rules.duplicate()
		want.sort()
		if got == want:
			return inst
	return {}


# Planted controls: each must turn the validator red, and a clean twin must not.
func _check_controls(world: Dictionary, kit: Dictionary, c) -> void:
	var map = world["map"]
	var ground: Callable = world["ground"]
	var bench := _planted(kit, "fix_bench", Vector2.ZERO, ground)
	var key: String = c.lines.keys()[0]
	var line: PackedVector2Array = c.lines[key]
	var mid := (line[0] + line[1]) * 0.5
	var on_line := _planted(kit, "fix_bench", mid, ground)
	_t.check("planted: an instance on a line turns line_clear red", _rules(on_line, c).has("line_clear"), str(_rules(on_line, c)))
	var mids := []
	for name in c.lines:
		var pts: PackedVector2Array = c.lines[name]
		for i in range(0, pts.size() - 1):
			mids.append((pts[i] + pts[i + 1]) * 0.5)
	var none_mutation := func(_inst: Dictionary) -> void:
		pass
	_t.check("planted: a point on a line turns line_clear red and nothing else", not _only("line_clear", mids, kit, c, ground, none_mutation).is_empty())
	var in_keepout := _planted(kit, "fix_bench", map.spawn, ground)
	_t.check("planted: an instance on the spawn turns keepout red", _rules(in_keepout, c).has("keepout"), str(_rules(in_keepout, c)))
	# A spawn-style keepout (spawn, vault, gate slot, activity site, device) clear of every line: keepout alone.
	var site_points := []
	for row: Dictionary in c.sites._keepouts:
		if row.get("ride", false):
			continue
		for pt: Vector2 in row["points"]:
			for off in [Vector2.ZERO, Vector2(3, 0), Vector2(-3, 0), Vector2(0, 3), Vector2(0, -3), Vector2(7, 0), Vector2(-7, 0), Vector2(0, 7), Vector2(0, -7)]:
				site_points.append(pt + off)
	var site_hit := _only("keepout", site_points, kit, c, ground, none_mutation)
	_t.check("planted: a point inside a site keepout (spawn style) turns keepout red and nothing else", not site_hit.is_empty(), "%d candidates" % site_points.size())
	# Beside a home: a ring of points round each home's row, the first that breaks only home_clear.
	var beside := {}
	for home: Dictionary in c.homes:
		var row: Dictionary = home["row"]
		var centre := Vector2(float(row["at"][0]), float(row["at"][1]))
		for dist in range(8, 140, 4):
			for k in 36:
				var at := centre + Vector2.from_angle(k * TAU / 36.0) * dist
				var probe := _planted(kit, "fix_bench", at, ground)
				if _rules(probe, c) == ["home_clear"]:
					beside = {"home": home["id"], "inst": probe}
					break
			if not beside.is_empty():
				break
		if not beside.is_empty():
			break
	_t.check("planted: an instance beside a home turns home_clear red (and nothing else)", not beside.is_empty() and _rules(beside["inst"], c) == ["home_clear"],
		str(beside.get("home", "no spot")))
	# Height tiers: edge-to-line minimums LOW 6 m, MID 10 m, TALL 20 m; each fails just inside and passes just outside.
	var tiers := [["low", 1.0, [], 5.0, 7.0], ["mid", 2.0, [], 9.0, 11.0], ["tall", 5.0, ["tall"], 19.0, 21.0]]
	for tier: Array in tiers:
		var near := _line_spot(kit, c, ground, tier, tier[3])
		var far := _line_spot(kit, c, ground, tier, tier[4])
		_t.check("planted: a %s prop at %.0f m from a line turns line_clear red" % [tier[0], tier[3]], not near.is_empty() and _rules(near, c).has("line_clear"))
		_t.check("planted: a %s prop at %.0f m from a line passes line_clear" % [tier[0], tier[4]], not far.is_empty() and not _rules(far, c).has("line_clear"))
	var hero19 := _hero_at(kit, c, ground, 19.0)
	var at19 := Vector2(hero19["pos"].x, hero19["pos"].z)
	_t.check("planted: the hero's point is 19 m from the nearest line", absf(c.line_distance(at19) - 19.0) < 0.5, str(c.line_distance(at19)))
	_t.check("planted: a hero 19 m from a line is tall too", _rules(hero19, c).has("line_clear"))
	var twin := hero19.duplicate()
	twin["class"] = ParkProps.PROP
	twin["height"] = 2.0
	twin["tags"] = []
	_t.check("planted: a non-hero twin at the same point passes the MID tier", not _rules(twin, c).has("line_clear"), str(_rules(twin, c)))
	_check_branches(map, kit, c, ground)


# One planted instance per remaining validator branch, each of which must produce exactly its rule.
func _check_branches(map, kit: Dictionary, c, ground: Callable) -> void:
	var grid := []
	var rect: Rect2 = c.rect
	for x in range(int(rect.position.x) + 10, int(rect.end.x), 10):
		for z in range(int(rect.position.y) + 10, int(rect.end.y), 10):
			grid.append(Vector2(x, z))
	var lane_points := []
	for z: Dictionary in c.lanes:
		lane_points.append(((z["a"] as Vector2) + (z["b"] as Vector2)) * 0.5)
	var row_points := []
	var open_rows := []
	var rail_rows := []
	for row: Dictionary in map.park.get("park_rows", []):
		if ParkProps.Context.blocks_props(row):
			row_points.append(ParkProps._pair(row["at"]))
			if row["element"] in ["kicker", "rail"]:
				rail_rows.append(row)
		elif row["element"] in ["ground", "bank"]:
			open_rows.append(row)
	var camp_points := []
	for camp: Vector2 in c.camps:
		for dist in [20.0, 22.0, 24.0]:
			for k in 36:
				camp_points.append(camp + Vector2.from_angle(k * TAU / 36.0) * dist)
	var two_m := func(inst: Dictionary) -> void:
		inst["height"] = 2.0
	var none := func(_inst: Dictionary) -> void:
		pass
	var steep := func(inst: Dictionary) -> void:
		inst["slope_deg"] = ParkProps.SLOPE_MAX_DEG + 5.0
	var floaty := func(inst: Dictionary) -> void:
		inst["float_m"] = ParkProps.SEAT_FLOAT_MAX_M + 0.15
	var tall_at := func(at: Vector2) -> Dictionary:
		var inst := _planted(kit, "fix_bench", at, ground)
		inst["height"] = 5.0
		inst["tags"] = ["tall"]
		return inst
	var lane_ok := false
	var lane_low_free := false
	for at: Vector2 in lane_points:
		if _rules(tall_at.call(at), c).has("route_lane"):
			lane_ok = true
			lane_low_free = not _rules(_planted(kit, "fix_bench", at, ground), c).has("route_lane")
			break
	_t.check("planted: a tall prop on a route lane leg turns route_lane red, a low one on it does not", lane_ok and lane_low_free)
	_t.check("planted: a point inside a ride-feature row footprint turns keepout red and nothing else", not _only("keepout", row_points, kit, c, ground, none).is_empty())
	var in_open := false
	for row: Dictionary in open_rows:
		for at: Vector2 in grid:
			if ParkMap.footprint_contains(row, at, 0.0) and not _rules(_planted(kit, "fix_bench", at, ground), c).has("keepout"):
				in_open = true
				break
		if in_open:
			break
	_t.check("planted: a low prop inside a ground or bank row passes keepout", in_open)
	var in_ride := false
	for row: Dictionary in rail_rows:
		in_ride = in_ride or _rules(_planted(kit, "fix_bench", ParkProps._pair(row["at"]), ground), c).has("keepout")
	_t.check("planted: a low prop inside a kicker or rail row fails keepout", in_ride and not rail_rows.is_empty())
	_t.check("planted: a point beside an enemy camp turns home_clear red and nothing else", not c.camps.is_empty() and not _only("home_clear", camp_points, kit, c, ground, none).is_empty())
	_t.check("planted: a slope over %.0f degrees turns slope red and nothing else" % ParkProps.SLOPE_MAX_DEG, not _only("slope", grid, kit, c, ground, steep).is_empty())
	_t.check("planted: a foot floating over %.2f m turns seat red and nothing else" % ParkProps.SEAT_FLOAT_MAX_M, not _only("seat", grid, kit, c, ground, floaty).is_empty())
	_check_kickers()
	var outside := _planted(kit, "fix_bench", rect.end + Vector2(20.0, 20.0), ground)
	_t.eq("planted: a point outside the play rect turns play_rect red and nothing else", _rules(outside, c), ["play_rect"])


# A 1,600 m lip (the islands' mesa rim): the old circle blocks everywhere, the capsules block only the lip and its run-out.
func _check_kickers() -> void:
	var kicker := {"id": "lip", "at": Vector2(100.0, 200.0), "dir": Vector2(0.0, 1.0), "width": 1600.0}
	var rows := [{"id": "lip", "size": [12.0, 0.01, 1600.0]}]
	var capsules := ParkProps.kicker_keepouts([], [kicker], rows)
	var circle := [{"what": "kicker ramp", "points": PackedVector2Array([Vector2(100.0, 188.0), Vector2(100.0, 205.0)]), "radius": 803.0, "ride": true}]
	var behind := Vector2(100.0, 170.0)
	_t.check("kicker: a point 30 m behind a long lip's centre was blocked by the circle", SetDressing.blocked(circle, behind, 3.0) != "")
	_t.eq("kicker: it passes under the capsules", SetDressing.blocked(capsules, behind, 3.0), "")
	_t.eq("kicker: a point 30 m behind the lip, 600 m along it, passes too", SetDressing.blocked(capsules, Vector2(700.0, 170.0), 3.0), "")
	_t.eq("kicker: a point on the lip fails keepout", SetDressing.blocked(capsules, Vector2(100.0, 200.0), 3.0), "kicker ramp")
	_t.eq("kicker: a point 600 m along the lip fails keepout", SetDressing.blocked(capsules, Vector2(700.0, 200.0), 3.0), "kicker ramp")
	_t.eq("kicker: a point in the run-out fails keepout", SetDressing.blocked(capsules, Vector2(100.0, 215.0), 3.0), "kicker run-out")
	_t.eq("kicker: a point 35 m ahead of the lip fails keepout", SetDressing.blocked(capsules, Vector2(100.0, 235.0), 3.0), "kicker run-out")
	_t.eq("kicker: a point 70 m ahead of the lip passes", SetDressing.blocked(capsules, Vector2(100.0, 270.0), 3.0), "")


# The first candidate whose planted bench, after mutate, breaks exactly the rule (and passes accept, if given); {} if none.
func _only(rule: String, points: Array, kit: Dictionary, c, ground: Callable, mutate: Callable, accept := Callable()) -> Dictionary:
	for at: Vector2 in points:
		var inst := _planted(kit, "fix_bench", at, ground)
		mutate.call(inst)
		if _rules(inst, c) == [rule] and (accept.is_null() or accept.call(inst)):
			return inst
	return {}


func _with(inst: Dictionary, key: String, value) -> Dictionary:
	var copy := inst.duplicate()
	copy[key] = value
	return copy


# A planted bench of a tier [name, height, tags, ...] whose footprint edge is `edge` m from the nearest line leg, or {}.
func _line_spot(kit: Dictionary, c, ground: Callable, tier: Array, edge: float) -> Dictionary:
	for key in c.lines:
		var line: PackedVector2Array = c.lines[key]
		for i in range(0, line.size() - 1):
			var leg := line[i + 1] - line[i]
			if leg.length() < 40.0:
				continue
			var normal := Vector2(-leg.y, leg.x).normalized()
			for side in [-1.0, 1.0]:
				var inst := _planted(kit, "fix_bench", (line[i] + line[i + 1]) * 0.5, ground)
				var at: Vector2 = (line[i] + line[i + 1]) * 0.5 + normal * side * (edge + float(inst["radius"]))
				if absf(c.line_distance(at) - float(inst["radius"]) - edge) > 0.3 or not c.rect.has_point(at):
					continue
				inst = _planted(kit, "fix_bench", at, ground)
				inst["height"] = tier[1]
				inst["tags"] = tier[2]
				return inst
	return {}


func _hero_at(kit: Dictionary, c, ground: Callable, edge: float) -> Dictionary:
	var line: PackedVector2Array = c.lines[c.lines.keys()[0]]
	var leg := line[1] - line[0]
	var normal := Vector2(-leg.y, leg.x).normalized()
	var hero := _planted(kit, "fix_ballast", (line[0] + line[1]) * 0.5 + normal * edge, ground)
	hero["radius"] = 0.0
	hero["class"] = ParkProps.HERO
	hero["height"] = 2.0
	return hero


func _planted(kit: Dictionary, kind: String, at: Vector2, ground: Callable) -> Dictionary:
	var variant: String = (kit["kinds"][kind]["variants"] as Dictionary).keys()[0]
	return ParkProps._instance("planted", kind, variant, kit, at, 0.0, 1.0, 0.0, ground, false)


func _rules(inst: Dictionary, c) -> Array:
	var rules := []
	for v: Dictionary in ParkProps.check_one(inst, c):
		if not rules.has(v["rule"]):
			rules.append(v["rule"])
	return rules


# The fixture's spots copied to SYNTHETIC_VIGNETTES vignettes (tools/park_props_plan.gd --bench times the same file).
func _check_synthetic(file: Dictionary, kit: Dictionary, world: Dictionary) -> void:
	var big := file.duplicate(true)
	var spots: Array = []
	var source: Array = file["spots"]
	for i in SYNTHETIC_VIGNETTES:
		var spot: Dictionary = (source[i % source.size()] as Dictionary).duplicate(true)
		spot["id"] = "synthetic_%d" % i
		spots.append(spot)
	big["spots"] = spots
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	var list := ParkProps.expand(big, kit, world["map"], world["ground"], c)
	var built := ParkProps.build_nodes(list, kit)
	_t.check("a %d-vignette file expands and builds" % SYNTHETIC_VIGNETTES, list.size() > SYNTHETIC_VIGNETTES and built.get_child_count() >= SYNTHETIC_VIGNETTES)
	built.free()


# prepare() is what the worker runs: it equals the plain expansion and warms every mesh the build reads.
func _check_prepare(file: Dictionary, kit: Dictionary, world: Dictionary, list: Array) -> void:
	ParkProps.file_overrides[FIXTURE_MAP] = FIXTURE_FILE
	ParkProps.release_shared()
	var out := ParkProps.prepare(FIXTURE_MAP, world["map"], world["ground"], world["stage"], false)
	_t.eq("prepare equals the plain expansion", ParkProps.fingerprint(out.get("list", [])), ParkProps.fingerprint(list))
	_t.eq("prepare reports no schema errors", out.get("errors"), [])
	_t.check("prepare warmed the meshes the build reads", ParkProps._meshes.size() > 0 and not ParkProps._meshes.values().has(null), str(ParkProps._meshes.size()))
	ParkProps.file_overrides[FIXTURE_MAP] = "res://tests/fixtures/park_props/no_such_file.json"
	var broken := ParkProps.prepare(FIXTURE_MAP, world["map"], world["ground"], world["stage"], false)
	_t.check("a park without a file prepares nothing", broken.is_empty())
	ParkProps.file_overrides.clear()


# The live node: a park stage with a vignette file builds ParkProps under the presentation, whatever the set-dressing flag.
func _check_game() -> void:
	ParkProps.file_overrides[FIXTURE_MAP] = FIXTURE_FILE
	var game := Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	await process_frame
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	await physics_frame
	await physics_frame
	var props = game.presentation.park_props
	props.finish()
	_t.check("the presentation carries ParkProps on a park table", props != null and props.name == "ParkProps")
	_t.check("stage 1 builds the park's views", props.map_id == FIXTURE_MAP and props.views.size() > 0 and props.instances.size() > 0, "%d views" % props.views.size())
	_t.check("the stage's views are grouped", props.views.all(func(v: GeometryInstance3D) -> bool: return v.is_in_group(ParkProps.GROUP)))
	_t.check("the live node has no collision", props.find_children("*", "CollisionObject3D", true, false).is_empty())
	game.ctx.events.stage_content_cleared.emit("test")
	_t.check("stage_content_cleared hides the props", not props.visible)
	Preset.apply("low")
	props = game.presentation.park_props
	props.finish()
	_t.check("the lowest preset keeps ParkProps (without set dressing) and drops litter", props != null and game.presentation.set_dressing == null \
		and props.views.size() > 0 and props.get_node_or_null("Litter") == null)
	Preset.apply("high")
	props = game.presentation.park_props
	props.finish()
	_t.check("the shipped high rebuilds them", props != null and props.views.size() > 0)
	game.queue_free()
	await physics_frame
	await physics_frame
	_t.check("No static keeps a map, mesh, shape or material once the Game is freed: ParkProps' mesh cache is empty", ParkProps._meshes.is_empty() and ParkProps._cache_owner == "", str(ParkProps._meshes.size()))
	ParkProps.file_overrides.clear()
	ParkProps.release_shared()
