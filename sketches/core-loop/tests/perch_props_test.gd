extends SceneTree

const PerchPoints := preload("res://src/world/perch_points.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const ParkGround := preload("res://tests/support/park_ground.gd")
const Terrain := preload("res://src/world/terrain.gd")
const T := preload("res://tests/support/t.gd")

# The Dispatcher's third perch source (src/world/perch_points.gd props(); design-v3/park/PERCH-ANCHOR.md): a tall
# Dressing prop whose kit variant carries a `perch` anchor [x, y, z] (prop-local metres, foot centre origin) offers
# its deck centre, inst.pos + inst.basis * (inst.scale * local), through the same gates as the landform tops.
# Fixture kit and vignette: tests/fixtures/perch_props (mast variants a 8 m, b 3 m, c 14 m, d none). Planted
# negatives that must be refused: a 3 m and a 14 m anchor, a scaled anchor out of band, NaN, a two-element list, a
# litter instance, a perch on a route lane, one in a solid footprint, one outside the play rect, one on a slope.
# Parks have no vignette file yet, so perch_near must answer exactly as it did before this source existed.

const KIT_PATH := "res://tests/fixtures/perch_props/manifest.json"
const FILE_PATH := "res://tests/fixtures/perch_props/park_dam.json"
const FIXTURE_MAP := "park_dam"
const MAST_AT := Vector2(-284.0, 204.0)

var _t := T.new("perch_props_test")


func _flat(_x: float, _z: float) -> float:
	return 0.0


func _park() -> Dictionary:
	return {
		"park_rows": [{"id": "bowl", "element": "bowl", "recipe": "greybox:bowl", "at": [60.0, 60.0], "size": [30.0, 6.0, 30.0], "yaw_deg": 0.0, "stamp": "", "y": null}],
		"activity_rows": [{"id": "a", "at": [-80.0, 0.0]}, {"id": "b", "at": [-10.0, 0.0]}],
		"routes": [],
		"waymarks": ["a", "b"],
		"play_rect": [-200.0, -200.0, 400.0, 400.0],
	}


func _inst(kind_v: String, at: Vector3, yaw := 0.0, scale := 1.0, litter := false) -> Dictionary:
	return {"vignette": "t", "kind": "fix_mast", "v": kind_v, "class": "dress_hero", "tags": ["tall"], "pos": at,
		"basis": Basis(Vector3.UP, yaw), "scale": scale, "radius": scale, "height": 9.0 * scale, "litter": litter}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var kit := ParkProps.load_json(KIT_PATH)
	_t.check("the fixture kit loads and passes the kit schema", not kit.is_empty() and ParkProps.kit_errors(kit).is_empty(), str(ParkProps.kit_errors(kit)))
	_t.check("the fixture kit carries perch keys", PerchPoints.kit_has_perch(kit))
	_t.eq("the fixture kit's perch entries are well formed", PerchPoints.perch_errors(kit), [])
	var park := _park()

	# A tall prop with perch [0, 8, 0] gives a top 8 m over its foot.
	var one := PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0))], kit, park, _flat)
	_t.eq("an 8 m anchor gives the top at pos + 8 m", one, [Vector4(40.0, 8.0, 100.0, 0.0)])
	_t.eq("props() is deterministic", PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0))], kit, park, _flat), one)
	var hill := func(_x: float, _z: float) -> float: return 20.0
	_t.eq("the top rides the foot height over a hill", PerchPoints.props([_inst("a", Vector3(40.0, 20.0, 100.0))], kit, park, hill), [Vector4(40.0, 28.0, 100.0, 20.0)])

	# Scale and yaw transform the offset.
	var offset := kit.duplicate(true)
	offset["kinds"]["fix_mast"]["variants"]["a"]["perch"] = [2, 4, 0]
	var turned := PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0), PI * 0.5, 2.0)], offset, park, _flat)
	_t.check("scale 2 doubles the offset and yaw 90 turns +x onto -z", turned.size() == 1 and absf(turned[0].x - 40.0) < 0.001 and absf(turned[0].z - 96.0) < 0.001 and absf(turned[0].y - 8.0) < 0.001, str(turned))
	offset["kinds"]["fix_mast"]["variants"]["a"]["perch"] = [2, 8, 0]
	var plain_turn := PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0))], offset, park, _flat)
	_t.eq("with no yaw and scale 1 the +x offset stays on x", plain_turn, [Vector4(42.0, 8.0, 100.0, 0.0)])

	# Planted negatives.
	_t.eq("negative: a 3 m anchor is no perch", PerchPoints.props([_inst("b", Vector3(40.0, 0.0, 100.0))], kit, park, _flat), [])
	_t.eq("negative: a 14 m anchor is no perch", PerchPoints.props([_inst("c", Vector3(40.0, 0.0, 100.0))], kit, park, _flat), [])
	_t.eq("negative: scale 1.5 lifts the 8 m anchor to 12 m, out of band", PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0), 0.0, 1.5)], kit, park, _flat), [])
	_t.eq("negative: scale 0.5 lowers it to 4 m, out of band", PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0), 0.0, 0.5)], kit, park, _flat), [])
	_t.eq("negative: a variant with no perch key offers none", PerchPoints.props([_inst("d", Vector3(40.0, 0.0, 100.0))], kit, park, _flat), [])
	_t.eq("negative: a litter instance is refused", PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0), 0.0, 1.0, true)], kit, park, _flat), [])
	_t.eq("negative: a perch on a route lane is refused", PerchPoints.props([_inst("a", Vector3(-40.0, 0.0, 0.0))], kit, park, _flat), [])
	_t.eq("positive control: the same prop 60 m off the lane is kept", PerchPoints.props([_inst("a", Vector3(-40.0, 0.0, 60.0))], kit, park, _flat).size(), 1)
	_t.eq("negative: a perch inside a solid footprint is refused", PerchPoints.props([_inst("a", Vector3(60.0, 0.0, 60.0))], kit, park, _flat), [])
	_t.eq("negative: a perch outside the play rect is refused", PerchPoints.props([_inst("a", Vector3(195.0, 0.0, 100.0))], kit, park, _flat), [])
	var slope := func(x: float, _z: float) -> float: return x * 0.7
	_t.eq("negative: a deck on a 35 degree slope is not flat", PerchPoints.props([_inst("a", Vector3(40.0, 28.0, 100.0))], kit, park, slope), [])
	for bad in [[0, 8], [0, NAN, 0], [0, INF, 0], [0, "8", 0], "up", {"y": 8}, null, [0, 8, 0, 0], []]:
		var broken := kit.duplicate(true)
		broken["kinds"]["fix_mast"]["variants"]["a"]["perch"] = bad
		_t.eq("negative: perch %s is refused" % var_to_str(bad), PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0))], broken, park, _flat), [])
		_t.check("perch_errors reports perch %s" % var_to_str(bad), PerchPoints.perch_errors(broken).size() == 1, str(PerchPoints.perch_errors(broken)))
	var low := kit.duplicate(true)
	low["kinds"]["fix_mast"]["variants"]["a"]["perch"] = [0, -1, 0]
	_t.check("perch_errors reports an anchor under the foot", PerchPoints.perch_errors(low).size() == 1)
	var tall := kit.duplicate(true)
	tall["kinds"]["fix_mast"]["variants"]["a"]["perch"] = [0, 12, 0]
	_t.check("perch_errors reports an anchor above the variant height", PerchPoints.perch_errors(tall).size() == 1)
	var malformed_inst := {"kind": "fix_mast", "v": "a", "litter": false, "pos": Vector3(40.0, 0.0, 100.0), "scale": NAN, "basis": Basis()}
	_t.eq("negative: a non-finite scale is refused", PerchPoints.props([malformed_inst, {"kind": "nope", "v": "a"}, "junk", {}], kit, park, _flat), [])

	# Spacing: two masts closer than SPACING_M keep one; a landform top already taken crowds a prop top out.
	var pair := PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0)), _inst("a", Vector3(46.0, 0.0, 100.0))], kit, park, _flat)
	_t.eq("two masts 6 m apart keep the first", pair, [Vector4(40.0, 8.0, 100.0, 0.0)])
	var far_pair := PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0)), _inst("a", Vector3(60.0, 0.0, 100.0))], kit, park, _flat)
	_t.eq("two masts 20 m apart keep both", far_pair.size(), 2)
	_t.eq("a taken landform top within 14 m drops the prop top", PerchPoints.props([_inst("a", Vector3(40.0, 0.0, 100.0))], kit, park, _flat, [Vector4(45.0, 8.0, 100.0, 0.0)]), [])

	# Through pick(): the prop top is a valid answer and a band-broken one is not.
	_t.eq("pick() returns the prop top", PerchPoints.pick([], Vector3(40.0, 0.0, 130.0), _flat, [], 1, one), Vector3(40.0, 8.0, 100.0))

	# Expansion through ParkProps on the fixture file and the real park_dam ground.
	var world := ParkProps.world_for(FIXTURE_MAP)
	var file := ParkProps.load_json(FILE_PATH)
	_t.eq("the fixture vignette file passes its schema", ParkProps.file_errors(file, kit), [])
	var list := ParkProps.expand(file, kit, world["map"], world["ground"], ParkProps.context(world["map"], world["ground"], world["stage"]))
	_t.eq("the fixture expands to one mast", list.size(), 1)
	var ground := ParkGround.ground(FIXTURE_MAP)
	var found := PerchPoints.props(list, kit, world["map"].park, ground)
	var foot := ground.call(MAST_AT.x, MAST_AT.y) as float
	_t.check("the expanded mast gives a deck 8 m over its foot", found.size() == 1 and absf(found[0].x - MAST_AT.x) < 0.001 and absf(found[0].z - MAST_AT.y) < 0.001 and absf(found[0].y - (foot + 8.0)) < 0.01, str(found))

	# A park with no perch keys: the same tops as before, whatever the instances.
	var plain := kit.duplicate(true)
	for v in plain["kinds"]["fix_mast"]["variants"]:
		plain["kinds"]["fix_mast"]["variants"][v].erase("perch")
	_t.check("a kit with no perch keys reports none", not PerchPoints.kit_has_perch(plain) and PerchPoints.perch_errors(plain).is_empty())
	_t.eq("a kit with no perch keys offers no prop tops", PerchPoints.props(list, plain, world["map"].park, ground), [])
	_t.eq("no instances, no prop tops", PerchPoints.props([], kit, world["map"].park, ground), [])
	_terrain()
	quit(_t.verdict())


# terrain.perch_near with the fixture vignette file on stage 1 (park_dam): a finite deck near the mast, INF with the file
# removed, and the unchanged answers of today's data (no vignette file) before and after.
func _terrain() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var terrain := Terrain.new(ParkDefs)
	terrain.build(world)
	var m = terrain.map()
	_t.check("terrain stage 1 is park_dam", m is ParkMap and String(m.park.get("map", "")) == FIXTURE_MAP)
	var near := Vector3(MAST_AT.x + 20.0, 0.0, MAST_AT.y)
	var before := terrain.perch_near(near, 3)
	print("perch_props_test: shipped answer beside the mast spot: %s" % str(before))
	# Today's answers on real packs equal the two-source pick exactly.
	var packs := ParkGround.pack_points(m.park, 40)
	var same := true
	var posts := PerchPoints.derive(m.park, terrain.height)
	var ledges := PerchPoints.ledges(m.park, terrain.height)
	var blocked := PerchPoints.blockers(m.park)
	for i in packs.size():
		same = same and terrain.perch_near(packs[i], i) == PerchPoints.pick(posts, packs[i], terrain.height, blocked, i, ledges)
	_t.check("with no vignette file perch_near equals the posts-and-landform pick on %d packs" % packs.size(), same)

	terrain._perches.clear()
	ParkProps.file_overrides[FIXTURE_MAP] = FILE_PATH
	var deck := terrain.perch_near(near, 3)
	_t.check("with the fixture vignette file a finite deck stands near the mast", deck.is_finite(), str(deck))
	if deck.is_finite():
		var foot := terrain.height(MAST_AT.x, MAST_AT.y)
		_t.check("it is the mast's deck, 8 m over its foot", deck.distance_to(Vector3(MAST_AT.x, foot + 8.0, MAST_AT.y)) < 0.01, str(deck))
		_t.check("within 40 m of the pack", Vector2(deck.x, deck.z).distance_to(Vector2(near.x, near.z)) <= PerchPoints.RANGE_M + 0.001)
	_t.eq("the same salt picks the same deck", terrain.perch_near(near, 3), deck)
	_t.eq("a pack 100 m from the mast gets none", terrain.perch_near(Vector3(MAST_AT.x + 100.0, 0.0, MAST_AT.y), 3), Vector3.INF)

	terrain._perches.clear()
	ParkProps.file_overrides[FIXTURE_MAP] = "res://tests/fixtures/perch_props/does_not_exist.json"
	_t.eq("with the file removed perch_near answers INF again", terrain.perch_near(near, 3), Vector3.INF)
	terrain._perches.clear()
	ParkProps.file_overrides.clear()
	_t.eq("with the override cleared perch_near answers as before", terrain.perch_near(near, 3), before)
	world.queue_free()
