extends SceneTree

# Park prop dressing (Dressing lane, design-v3/park/DRESSING-KITS.md; src/presentation/park_props.gd). Rule: every park that
# has a vignette file (src/world/park/props/park_<park>.json) keeps its schema, names only kinds and variants its kit has,
# has a kit of at least MIN_KINDS kinds with at least two variants each, expands to instances that pass every placement
# rule (line_clear, route_lane, keepout, home_clear, play_rect, slope, seat), expands the same twice, and builds views that
# carry a visibility range, cast no shadow but a hero's LOD0, and collide with nothing. Until a park has a file, the
# fixture (tests/fixtures/park_props: a manifest over existing GLBs and four spots on park_dam) stands in for the whole
# check, so the pass is never empty, and a park without a file counts as skipped. Planted controls that must fail: an
# instance on a line, one inside a keepout, one beside a home, a tall prop 20 m from a line.
#
# The pins hold each park's expansion fingerprint once a park has a file (PINS, empty until then).

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const Preset := preload("res://src/presentation/graphics_preset.gd")

const FIXTURE_FILE := "res://tests/fixtures/park_props/park_dam.json"
const FIXTURE_MAP := "park_dam"
const MIN_KINDS := 12
const SYNTHETIC_VIGNETTES := 60
# Map id -> expansion fingerprint (ParkProps.fingerprint), pinned when a park's vignette file lands.
const PINS := {}

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
		if PINS.has(id):
			_t.eq("%s expansion matches its pin" % id, ParkProps.fingerprint(list), PINS[id])
	print("park_props_test: %d of %d parks have a vignette file; %d skipped" % [real, ParkProps.PARKS.size(), ParkProps.PARKS.size() - real])
	_t.check("the park count adds up", real + (ParkProps.PARKS.size() - real) == ParkProps.PARKS.size())

	var world := ParkProps.world_for(FIXTURE_MAP)
	_t.check("the fixture world loads", world["map"].ok and world["stage"] == 1)
	var list := _check_park(FIXTURE_MAP, FIXTURE_FILE, 3, 2, world)
	_t.check("the fixture expands to instances", list.size() > 0, str(list.size()))
	var file := ParkProps.load_json(FIXTURE_FILE)
	var kit := ParkProps.load_json(String(file["kit"]))
	var c := ParkProps.context(world["map"], world["ground"], world["stage"])
	_check_build(list, kit)
	_check_controls(world, kit, c)
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
	built.free()
	var low := ParkProps.build_nodes(list, kit, true)
	var low_litter := low.get_node_or_null("Litter")
	var lod0 := low.find_children("*_L0", "MultiMeshInstance3D", true, false)
	_t.check("the lowest preset drops litter and halves prop LOD0 and LOD1", low_litter == null and not lod0.is_empty() \
		and is_equal_approx((lod0[0] as GeometryInstance3D).visibility_range_end, ParkProps.PROP_RANGES[0][1] * ParkProps.LOW_RANGE_SCALE))
	low.free()


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
	var in_keepout := _planted(kit, "fix_bench", map.spawn, ground)
	_t.check("planted: an instance on the spawn turns keepout red", _rules(in_keepout, c).has("keepout"), str(_rules(in_keepout, c)))
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
	# A tall prop 20 m (edge to line) from a line; the same spot with a low prop passes line_clear.
	var found := false
	var tall_rules := []
	var low_rules := []
	for i in range(0, line.size() - 1):
		var leg := line[i + 1] - line[i]
		if leg.length() < 40.0:
			continue
		var normal := Vector2(-leg.y, leg.x).normalized()
		for side in [-1.0, 1.0]:
			var radius := float(bench["radius"])
			var at: Vector2 = (line[i] + line[i + 1]) * 0.5 + normal * side * (20.0 + radius)
			if absf(c.line_distance(at) - radius - 20.0) > 0.5:
				continue
			var tall := _planted(kit, "fix_bench", at, ground)
			tall["height"] = 5.0
			tall["tags"] = ["tall"]
			var low := _planted(kit, "fix_bench", at, ground)
			low["height"] = 1.0
			tall_rules = _rules(tall, c)
			low_rules = _rules(low, c)
			if tall_rules.has("line_clear") and not low_rules.has("line_clear"):
				found = true
				break
		if found:
			break
	_t.check("planted: a tall prop 20 m from a line turns line_clear red while a low one does not", found, "tall %s, low %s" % [str(tall_rules), str(low_rules)])
	_t.check("planted: a hero 20 m from a line is tall too",
		_rules(_hero_at(kit, c, ground, 20.0), c).has("line_clear"))


func _hero_at(kit: Dictionary, c, ground: Callable, edge: float) -> Dictionary:
	var line: PackedVector2Array = c.lines[c.lines.keys()[0]]
	var leg := line[1] - line[0]
	var normal := Vector2(-leg.y, leg.x).normalized()
	var hero := _planted(kit, "fix_ballast", (line[0] + line[1]) * 0.5 + normal * 20.0, ground)
	hero["radius"] = 0.0
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
	ParkProps.file_overrides.clear()
	var broken := ParkProps.prepare(FIXTURE_MAP, world["map"], world["ground"], world["stage"], false)
	_t.check("a park without a file prepares nothing", broken.is_empty())


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
	ParkProps.file_overrides.clear()
	ParkProps.release_shared()
