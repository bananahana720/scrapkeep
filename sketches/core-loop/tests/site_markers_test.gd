extends SceneTree

# Site markers (map audit unit 4, src/presentation/site_markers.gd): a smoke plume over each waiting rib cache, each
# caged pilot not yet freed and the rogue site while its machine sleeps.
#
# 1. Which sites get a plume: a waiting cache, an unspent cage and an unwoken rogue do; a taken cache, a spent cage and a
#    woken rogue (its plan emptied) do not. sync puts up and takes down plumes to match.
# 2. The distance rule: nothing inside GONE_M (the plume never stands over what it marks) or past FAR_GONE_M (inside the
#    700 m far plane), full between FULL_M and FAR_FULL_M. Planted: a rule with no near fade fails the 6 m line.
# 3. The colour law (LEGIBILITY section 1): each smoke shade sits at least COLOUR_GAP (CIE76) from every colour that
#    means something, so a plume borrows no role. Sand and charcoal are the neutral inks (sand is the rib cache column's
#    own colour, charcoal a machine's steel); the smoke sits near them on purpose and is told from a pickup's column by
#    shape and motion, which the PC film judges. Planted: a smoke row tinted amber fails the same function.
# 4. Sight (map standard point 10a, "sight share per marker top"): on each world 1 park, for each fixed marked site
#    (both rogue sites and every cage), the open 25 m grid cells between FULL_M and FAR_FULL_M of the site that see
#    the plume's body (SIGHT_SHARE of its height, below the top where the smoke has thinned out) over the baked ground,
#    at least SIGHT_MIN. Each prints `MAPCHECK <map> marker_sight <site> ...`.
#    Planted: a plume sunk 400 m into the ground fails. Rib cache spots are drawn per run, so they are not in this read.
# 5. In the game: the park table's stage 1 (park_dam) stands a plume over Rivet's cage and one over the drawn rogue
#    site, and one over each rib cache the build placed; freeing the cage takes its plume down.

const T := preload("res://tests/support/t.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const Sight := preload("res://tests/park_landmark_sight_test.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Palette := preload("res://src/core/palette.gd")
const Game := preload("res://src/game.gd")
const DefenceBars := preload("res://src/core/defence_bars.gd")

const WORLD1 := ["park_dam", "park_flume"]
const COLOUR_GAP := 35.0
const SIGHT_MIN := 0.5
const SIGHT_SHARE := 0.6
const CELL_M := 25.0
const BAKE_CELLS := 800

var t := T.new("site_markers_test")


class FakeCage extends Node3D:
	var quest := ""
	var spent := false


class FakeRescue extends RefCounted:
	var cages: Array = []


class FakeWorld extends Node:
	var rescue
	var rogue_plan := {}


class FakeScrap extends RefCounted:
	var items: Array = []

	func caches() -> Array:
		var out := []
		for item: Node3D in items:
			out.append({"at": item.global_position, "id": "rib", "item": item})
		return out


class FlatTerrain extends RefCounted:
	func height(_x: float, _z: float) -> float:
		return 5.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_which_sites()
	_distance_rule()
	_colour_law()
	_sight()
	await _in_game()
	quit(t.verdict())


func _kinds(list: Array) -> Array:
	var out := []
	for s in list:
		out.append(String(s["kind"]))
	out.sort()
	return out


func _which_sites() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var item := Node3D.new()
	holder.add_child(item)
	item.global_position = Vector3(10.0, 6.2, 20.0)
	var scrap := FakeScrap.new()
	scrap.items = [item]
	var waiting := FakeCage.new()
	waiting.quest = "rivet"
	var freed := FakeCage.new()
	freed.quest = "kest"
	freed.spent = true
	holder.add_child(waiting)
	holder.add_child(freed)
	waiting.global_position = Vector3(60.0, 3.0, -594.0)
	var rescue := FakeRescue.new()
	rescue.cages = [waiting, freed]
	var world := FakeWorld.new()
	holder.add_child(world)
	world.rescue = rescue
	world.rogue_plan = {"kind": "rogue_crane", "site": "dam_mb_mid", "at": Vector2(104.0, 96.0), "radius_m": 38.0, "trigger_m": 63.0}
	var terrain := FlatTerrain.new()

	var list := SiteMarkers.sites(world, scrap, terrain)
	t.eq("a waiting cache, an unspent cage and a sleeping rogue each want a plume", _kinds(list), ["cache", "cage", "rogue"])
	for s in list:
		if s["kind"] == "rogue":
			t.eq("the rogue plume stands on the ground at its site", s["at"], Vector3(104.0, 5.0, 96.0))
		if s["kind"] == "cache":
			t.eq("the cache plume stands on the ground under the panel", s["at"], Vector3(10.0, 5.0, 20.0))
		if s["kind"] == "cage":
			t.eq("the cage plume is the cage's own key", s["key"], "cage:rivet")
	t.eq("nothing at all with no world, scrap or terrain", SiteMarkers.sites(null, null, null), [])

	var markers := SiteMarkers.new()
	holder.add_child(markers)
	markers.sync(list)
	t.eq("sync puts up one plume a site", markers.views.size(), 3)
	var kinds := []
	for view: MeshInstance3D in markers.views.values():
		kinds.append(String(view.get_meta("kind")))
		t.check("%s plume is a quad with no shadow" % view.get_meta("kind"),
			view.mesh is QuadMesh and view.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	kinds.sort()
	t.eq("the plumes are the three kinds", kinds, ["cache", "cage", "rogue"])
	var first: MeshInstance3D = markers.views.values()[0]
	var shared: ShaderMaterial = SiteMarkers._material(String(first.get_meta("kind")))
	t.check("each plume owns a copy of its kind's material", first.material_override != shared
		and (first.material_override as ShaderMaterial).shader == shared.shader
		and (first.material_override as ShaderMaterial).get_shader_parameter("puffs") == shared.get_shader_parameter("puffs"))

	# The cache is taken, the cage freed, the rogue wakes: every plume goes.
	scrap.items = []
	waiting.spent = true
	world.rogue_plan = {}
	var after := SiteMarkers.sites(world, scrap, terrain)
	t.eq("a taken cache, a spent cage and a woken rogue want none", after, [])
	markers.sync(after)
	t.eq("sync takes every plume down", markers.views.size(), 0)

	# Each plume's foot is where it was asked to stand, and a near eye hides it.
	markers.sync(list)
	markers.fade_for(Vector3(104.0, 5.0, 100.0))
	for view: MeshInstance3D in markers.views.values():
		if view.get_meta("kind") == "rogue":
			t.eq("the rogue plume's foot is its site", view.global_position, Vector3(104.0, 5.0, 96.0))
			t.check("an eye 4 m from the rogue site hides its plume", not view.visible)
		if view.get_meta("kind") == "cache":
			t.check("an eye 120 m from the cache shows its plume", view.visible)
	holder.queue_free()


static func _no_near(distance_m: float) -> float:
	return 1.0 - smoothstep(SiteMarkers.FAR_FULL_M, SiteMarkers.FAR_GONE_M, distance_m)


func _distance_rule() -> void:
	t.eq("gone at 6 m", SiteMarkers.near_alpha(6.0), 0.0)
	t.eq("gone at GONE_M", SiteMarkers.near_alpha(SiteMarkers.GONE_M), 0.0)
	t.eq("full at FULL_M", SiteMarkers.near_alpha(SiteMarkers.FULL_M), 1.0)
	t.eq("full at 200 m", SiteMarkers.near_alpha(200.0), 1.0)
	t.eq("full at FAR_FULL_M", SiteMarkers.near_alpha(SiteMarkers.FAR_FULL_M), 1.0)
	t.eq("gone at FAR_GONE_M", SiteMarkers.near_alpha(SiteMarkers.FAR_GONE_M), 0.0)
	t.check("gone before the 700 m far plane", SiteMarkers.FAR_GONE_M < 700.0)
	var last := 0.0
	var rising := true
	for d in range(int(SiteMarkers.GONE_M), int(SiteMarkers.FULL_M) + 1):
		var a := SiteMarkers.near_alpha(float(d))
		rising = rising and a >= last
		last = a
	t.check("the near fade never steps back", rising)
	t.check("planted: no near fade fails the 6 m line", _no_near(6.0) != 0.0, "%.2f" % _no_near(6.0))


const MEANING := {"amber": Palette.AMBER, "hazard": Palette.HAZARD, "slate": Palette.SLATE, "rust": Palette.RUST,
	"brass": Palette.BRASS, "ancient": Palette.ANCIENT, "cobalt": Palette.COBALT}


# [gap, nearest]: the CIE76 distance from tint to the nearest colour that means something (the live colour included).
static func worst_gap(tint: Color) -> Array:
	var worst := [INF, ""]
	var meaning: Dictionary = MEANING.duplicate()
	meaning["live"] = Palette.live()
	for role in meaning:
		var gap := DefenceBars.cie76(tint, meaning[role])
		if gap < worst[0]:
			worst = [gap, role]
	return worst


func _colour_law() -> void:
	for kind in SiteMarkers.KINDS:
		var tint: Color = SiteMarkers.KINDS[kind]["tint"]
		var w := worst_gap(tint)
		print("[colour] %s smoke %s nearest %s at %.1f" % [kind, tint.to_html(false), w[1], w[0]])
		t.check("%s smoke sits >= %.0f from every colour that means something" % [kind, COLOUR_GAP], w[0] >= COLOUR_GAP,
			"%s at %.1f" % [w[1], w[0]])
	var planted: Dictionary = SiteMarkers.KINDS["cache"].duplicate()
	planted["tint"] = Palette.AMBER.lerp(Palette.SAND, 0.2)
	var pw := worst_gap(planted["tint"])
	t.check("planted: a cache row tinted near amber fails the colour law", pw[0] < COLOUR_GAP, "%s at %.1f" % [pw[1], pw[0]])
	t.check("crew smoke and works smoke are far apart", DefenceBars.cie76(SiteMarkers.CREW_SMOKE, SiteMarkers.WORKS_SMOKE) >= 50.0)


# The fixed marked sites of a park: [{id, kind, at: Vector2}].
static func fixed_sites(map_id: String, park: Dictionary) -> Array:
	var out := []
	for s in RogueDirector.read_sites(map_id).get("miniboss_sites", []):
		out.append({"id": String(s["id"]), "kind": "rogue", "at": Vector2(float(s["at"][0]), float(s["at"][1]))})
	for row in park.get("rescue_rows", []):
		out.append({"id": String(row["id"]), "kind": "cage", "at": Vector2(float(row["at"][0]), float(row["at"][1]))})
	return out


# {share, counted}: open cells between FULL_M and FAR_FULL_M of at that see a point height_m over its ground.
static func marker_sight(ground: PackedFloat32Array, holes: PackedByteArray, at: Vector2, height_m: float) -> Dictionary:
	var top := Vector3(at.x, Sight.height(ground, at.x, at.y) + height_m, at.y)
	var counted := 0
	var clear := 0
	var reach := SiteMarkers.FAR_FULL_M
	var steps := int(reach / CELL_M)
	for gj in range(-steps, steps + 1):
		for gi in range(-steps, steps + 1):
			var x := at.x + gi * CELL_M
			var z := at.y + gj * CELL_M
			var planar := Vector2(gi, gj).length() * CELL_M
			if planar < SiteMarkers.FULL_M or planar > reach or absf(x) > Sight.HALF_M or absf(z) > Sight.HALF_M:
				continue
			var ci := clampi(floori((x + Sight.HALF_M) / 2.0), 0, BAKE_CELLS - 1)
			var cj := clampi(floori((z + Sight.HALF_M) / 2.0), 0, BAKE_CELLS - 1)
			if holes[cj * BAKE_CELLS + ci] != 0:
				continue
			counted += 1
			var eye := Vector3(x, Sight.height(ground, x, z) + Sight.EYE_M, z)
			if Sight.clear_ray(ground, eye, top):
				clear += 1
	return {"share": float(clear) / float(counted) if counted > 0 else 0.0, "counted": counted}


func _sight() -> void:
	var tool: GDScript = load(Sight.GRAPH_TOOL)
	var planted_done := false
	for map_id in WORLD1:
		var park: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("%s/%s.json" % [Sight.PARK_DIR, map_id]))
		var bake: Dictionary = tool.load_bake("%s/%s" % [Sight.OUT_DIR, map_id])
		if not t.check("%s bake loads" % map_id, bake["errors"].is_empty(), str(bake["errors"])):
			continue
		var sites := fixed_sites(map_id, park)
		t.check("%s has marked sites" % map_id, sites.size() >= 2, "%d" % sites.size())
		for s in sites:
			var h: float = float(SiteMarkers.KINDS[s["kind"]]["height"]) * SIGHT_SHARE
			var r := marker_sight(bake["ground"], bake["holes"], s["at"], h)
			var ok: bool = r["share"] >= SIGHT_MIN
			print("MAPCHECK %s marker_sight %s %.4f pass>=%.2f %s (%d cells)" % [map_id, s["id"], r["share"], SIGHT_MIN, "PASS" if ok else "FAIL", r["counted"]])
			t.check("%s %s plume body seen from >= %.2f of open cells in reach" % [map_id, s["id"], SIGHT_MIN], ok, "%.4f" % r["share"])
			if not planted_done:
				planted_done = true
				var sunk := marker_sight(bake["ground"], bake["holes"], s["at"], -400.0)
				t.check("planted: a plume sunk 400 m fails the sight line", sunk["share"] < SIGHT_MIN, "%.4f" % sunk["share"])


func _plume_kinds(markers) -> Dictionary:
	var out := {}
	for view: MeshInstance3D in markers.views.values():
		var kind := String(view.get_meta("kind"))
		out[kind] = int(out.get(kind, 0)) + 1
	return out


func _in_game() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.flow.press_start()
	game.flow.choose_class(0)
	game.ctx.calm = true
	game.flow.enter_stage(1, Vector3.ZERO, false)
	for i in 60:
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	var markers = game.presentation.site_markers
	t.eq("stage 1 is park_dam", String(game.ctx.terrain.map().title), "park_dam")
	t.check("the presentation holds the site markers", markers != null and markers.get_parent() == game.presentation)
	var kinds := _plume_kinds(markers)
	var caches: int = game.ctx.build.scrap.cache_count()
	print("[game] park_dam plumes %s, rib caches waiting %d, rogue %s" % [kinds, caches, game.world.rogue_plan.get("site", "")])
	t.eq("park_dam stands one plume over Rivet's cage", int(kinds.get("cage", 0)), 1)
	t.eq("park_dam stands one plume over the sleeping rogue's site", int(kinds.get("rogue", 0)), 1)
	t.check("park_dam placed rib caches", caches > 0, "%d" % caches)
	t.eq("park_dam stands one plume over each waiting rib cache", int(kinds.get("cache", 0)), caches)
	var cage = game.world.rescue.cage("rivet")
	if t.check("park_dam has Rivet's cage", cage != null):
		cage.spent = true
		for i in 30:
			await physics_frame
		t.eq("a freed cage's plume comes down", int(_plume_kinds(markers).get("cage", 0)), 0)
	# Leaving the stage for the arena takes every plume down on the same tick, not up to a read later.
	game.events.stage_content_cleared.emit("test")
	t.eq("clearing the stage's content takes every plume down at once", markers.views.size(), 0)
	game.free()
