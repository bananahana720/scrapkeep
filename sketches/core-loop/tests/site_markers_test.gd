extends SceneTree

# Site markers (map audit unit 4, src/presentation/site_markers.gd): a smoke plume over each waiting rib cache, each
# caged pilot not yet freed and the rogue site while its machine sleeps.
#
# 1. Which sites get a plume: a waiting cache, an unspent cage and an unwoken rogue do; a taken cache, a spent cage and a
#    woken rogue (its plan emptied) do not. sync puts up and takes down plumes to match; a plume whose site is done
#    fades out over LEAVE_S (the rogue wakes 63 m out, at full strength) and goes, and a stage change takes every plume
#    down at once, fading ones too. A cache plume stands on the ground under its panel, a deck if the panel is on one.
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
# 6. The furnace column (hand-overs audit T6): Brindle's bowl stands one on the world's last stage until its launch, and
#    no other boss, stage or state does. It has no far fade and past PULL_M is drawn pulled in along the eye's ray at the
#    share that keeps its pixels. Its glow is the bowl melt's colour, held to the melt's hue line. In the game it stands on park_flume, past the exit
#    gate where the launch lands, and not on park_dam. Planted: a far column left unpulled stands past the far plane.
# 5. In the game: the park table's stage 1 (park_dam) stands a plume over Rivet's cage and one over the drawn rogue
#    site, and one over each rib cache the build placed; freeing the cage takes its plume down.

const T := preload("res://tests/support/t.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const Sight := preload("res://tests/park_landmark_sight_test.gd")
const RogueDirector := preload("res://src/world/rogue_director.gd")
const Palette := preload("res://src/core/palette.gd")
const Yard := preload("res://src/presentation/arena_bowl_yard.gd")
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

	func waiting() -> Array:
		var out := []
		for c in cages:
			if not c.spent:
				out.append({"quest": c.quest, "at": c.global_position})
		return out


class FakeWorld extends Node:
	var rescue
	var rogue_plan := {}


class FakeScrap extends RefCounted:
	var items: Array = []

	func caches() -> Array:
		var out := []
		for item: Node3D in items:
			out.append({"at": item.global_position, "foot": item.global_position + Vector3.DOWN * 1.2, "id": "rib", "item": item})
		return out


class FlatTerrain extends RefCounted:
	func height(x: float, _z: float) -> float:
		return 2.0 if x < 50.0 else 5.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_which_sites()
	_distance_rule()
	_colour_law()
	_sight()
	_furnace()
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
	# A panel on a deck at 5.0 over ground the terrain reads lower: the deck is what the plume stands on.
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
			t.eq("the cache plume stands under its panel, on the deck it floats over and not the ground below", s["at"], Vector3(10.0, 5.0, 20.0))
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
	t.eq("a sync with no fade leaves nothing fading", markers.leaving.size(), 0)

	# Each plume's foot is where it was asked to stand, and a near eye hides it.
	markers.sync(list)
	markers.fade_for(Vector3(104.0, 5.0, 100.0))
	for view: MeshInstance3D in markers.views.values():
		if view.get_meta("kind") == "rogue":
			t.eq("the rogue plume's foot is its site", view.global_position, Vector3(104.0, 5.0, 96.0))
			t.check("an eye 4 m from the rogue site hides its plume", not view.visible)
		if view.get_meta("kind") == "cache":
			t.check("an eye 120 m from the cache shows its plume", view.visible)
			t.eq("at 120 m a plume keeps its true size", view.scale, Vector3.ONE)

	# The rogue wakes with the eye 63 m out: its plume fades out over LEAVE_S, not in one frame.
	var eye := Vector3(104.0, 5.0, 159.0)
	markers.fade_for(eye)
	var rogue: MeshInstance3D = markers.views["rogue:dam_mb_mid"]
	world.rogue_plan = {}
	markers.sync(SiteMarkers.sites(world, scrap, terrain), true)
	t.check("a woken rogue's plume leaves the site list but keeps fading", not markers.views.has("rogue:dam_mb_mid") and markers.leaving.has(rogue))
	markers.leave(SiteMarkers.LEAVE_S * 0.5)
	markers.fade_for(eye)
	var mid := float(rogue.material_override.get_shader_parameter("near_alpha"))
	t.check("half way out it shows half its share", is_equal_approx(mid, 0.5 * SiteMarkers.near_alpha(63.0)), "%.3f" % mid)
	markers.leave(SiteMarkers.LEAVE_S * 0.6)
	t.check("past LEAVE_S it is gone", not markers.leaving.has(rogue) and rogue.is_queued_for_deletion())
	# Planted: the same wake with no fade drops the plume in one frame.
	markers.sync(list)
	markers.fade_for(eye + Vector3.ONE)
	world.rogue_plan = {}
	markers.sync(SiteMarkers.sites(world, scrap, terrain))
	t.check("planted: a sync with no fade drops the plume at once", markers.leaving.is_empty() and not markers.views.has("rogue:dam_mb_mid"))

	# A new stage takes every plume down at once, fading ones too, and reads its own sites on the next frame.
	world.rogue_plan = {"kind": "rogue_crane", "site": "dam_mb_mid", "at": Vector2(104.0, 96.0), "radius_m": 38.0, "trigger_m": 63.0}
	markers.sync(SiteMarkers.sites(world, scrap, terrain))
	markers.fade_for(eye + Vector3.ONE * 2.0)
	world.rogue_plan = {}
	markers.sync(SiteMarkers.sites(world, scrap, terrain), true)
	markers._clock = SiteMarkers.READ_EVERY
	markers._on_stage_entered(2, false)
	t.check("entering a stage takes every plume down, fading ones too", markers.views.is_empty() and markers.leaving.is_empty())
	t.eq("and reads the new stage's sites on the next frame", markers._clock, 0.0)

	# An eye that has not moved redraws nothing; one that has, does.
	markers.sync(list)
	markers.fade_for(eye)
	var cache_view: MeshInstance3D = null
	for key in markers.views:
		if String(key).begins_with("cache"):
			cache_view = markers.views[key]
	cache_view.material_override.set_shader_parameter("near_alpha", -1.0)
	markers.fade_for(eye + Vector3(0.1, 0.0, 0.0))
	t.eq("a still eye skips the redraw", float(cache_view.material_override.get_shader_parameter("near_alpha")), -1.0)
	markers.fade_for(eye + Vector3(5.0, 0.0, 0.0))
	t.check("a moved eye redraws", float(cache_view.material_override.get_shader_parameter("near_alpha")) >= 0.0)
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
	t.eq("true size up to GROW_FROM_M", SiteMarkers.grow(100.0), 1.0)
	t.near("grows with distance past it, keeping its screen size", SiteMarkers.grow(260.0), 2.0)
	t.eq("never more than GROW_MAX", SiteMarkers.grow(590.0), SiteMarkers.GROW_MAX)
	for kind in SiteMarkers.KINDS:
		var row: Dictionary = SiteMarkers.KINDS[kind]
		if row.get("far", false):
			t.check("%s column drawn at PULL_M stays inside the 700 m far plane" % kind, SiteMarkers.PULL_M + float(row["height"]) < 700.0)
		else:
			t.check("%s plume at its largest stays under the far plane's reach" % kind, float(row["height"]) * SiteMarkers.GROW_MAX < 150.0)
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
	# The furnace glow is slag light, held to the bowl melt's own rule (arena_bowl_yard.gd): gold of MELT_MIN_HUE, so it
	# never takes the live slag's or HAZARD's red-orange. Planted: HAZARD fails it.
	var hue := SiteMarkers.FURNACE_GLOW.h * 360.0
	t.check("the furnace glow sits on the gold side of the melt's hue line", hue >= Yard.MELT_MIN_HUE and hue < 60.0, "%.1f" % hue)
	t.check("planted: HAZARD fails the melt's hue line", Palette.HAZARD.h * 360.0 < Yard.MELT_MIN_HUE)
	t.check("crew smoke and works smoke are far apart", DefenceBars.cie76(SiteMarkers.CREW_SMOKE, SiteMarkers.WORKS_SMOKE) >= 50.0)


func _furnace() -> void:
	var foot := Vector3(10.0, 4.0, 20.0)
	t.eq("the furnace stands on Brindle's world's last stage", SiteMarkers.furnace_site(true, "brindle", true, foot),
		{"key": "furnace", "kind": "furnace", "at": foot})
	t.eq("none before the world's last stage", SiteMarkers.furnace_site(false, "brindle", true, foot), {})
	t.eq("none for another boss", SiteMarkers.furnace_site(true, "waking", true, foot), {})
	t.eq("none once the run has left the stage", SiteMarkers.furnace_site(true, "brindle", false, foot), {})
	t.eq("none with no bowl read", SiteMarkers.furnace_site(true, "brindle", true, null), {})
	t.eq("no far fade at 2 km", SiteMarkers.near_alpha(2000.0, true), 1.0)
	t.eq("the near fade still holds for a far kind", SiteMarkers.near_alpha(6.0, true), 0.0)
	t.eq("drawn true inside PULL_M", SiteMarkers.pull(300.0), 1.0)
	t.near("pulled to half at twice PULL_M", SiteMarkers.pull(SiteMarkers.PULL_M * 2.0), 0.5)
	var holder := Node3D.new()
	root.add_child(holder)
	var markers = SiteMarkers.new()
	holder.add_child(markers)
	var at := Vector3(SiteMarkers.PULL_M * 2.0, 0.0, 0.0)
	markers.sync([{"key": "furnace", "kind": "furnace", "at": at}])
	var eye := Vector3(0.0, 30.0, 0.0)
	markers.fade_for(eye)
	var view: MeshInstance3D = markers.views["furnace"]
	t.check("a far column shows", view.visible)
	t.check("drawn at PULL_M on the eye's ray", view.global_position.distance_to(eye + (at - eye) * 0.5) < 0.01, str(view.global_position))
	t.near("at half its size, so it covers the same pixels", view.scale.x, 0.5)
	var planted := Vector2(at.x - eye.x, at.z - eye.z).length()
	t.check("planted: an unpulled column would stand past the far plane", planted > 700.0, "%.0f" % planted)
	markers.fade_for(Vector3(SiteMarkers.PULL_M * 2.0 - 100.0, 30.0, 0.0))
	t.check("close in it stands at its own foot", view.global_position.distance_to(at) < 0.01 and is_equal_approx(view.scale.x, 1.0))
	holder.free()


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
	t.eq("park_dam stands no furnace column", int(kinds.get("furnace", 0)), 0)
	game.flow.enter_stage(2, Vector3.ZERO, false)
	for i in 30:
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
	t.eq("stage 2 is park_flume", String(game.ctx.terrain.map().title), "park_flume")
	var furnace = markers.views.get("furnace")
	if t.check("park_flume stands the furnace column", furnace != null, str(_plume_kinds(markers))):
		var foot: Vector3 = furnace.get_meta("at")
		var exit: Dictionary = game.ctx.terrain.map_for(2).handover()["exit"]
		var gate: Vector2 = exit["at"]
		var heading := deg_to_rad(float(exit["heading_deg"]))
		var to_foot := Vector2(foot.x, foot.z) - gate
		print("[game] furnace foot %s, %.0f m from the exit gate" % [foot, to_foot.length()])
		t.check("it stands within 80 m of the flume's exit gate", to_foot.length() < 80.0, "%.0f" % to_foot.length())
		t.check("it stands ahead of the gate, where the launch aims", to_foot.dot(Vector2(sin(heading), cos(heading))) > 0.0)
		t.near("on the ground under the bowl", foot.y, game.ctx.terrain.height(foot.x, foot.z))
	# Leaving the stage for the arena takes every plume down on the same tick, not up to a read later.
	game.events.stage_content_cleared.emit("test")
	t.eq("clearing the stage's content takes every plume down at once", markers.views.size(), 0)
	game.free()
