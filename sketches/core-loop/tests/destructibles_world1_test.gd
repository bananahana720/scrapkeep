extends SceneTree
# smoke: solo timeout=300s (reads both world 1 bakes and graphs, walks every route twice per park)

# World 1 heft destructibles placement (W45-C unit D, design-v3/HEFT-DESTRUCTIBLES.md sections 2, 6, 7 and 10.2).
# Reads the destructible_rows of park_dam.json and park_flume.json against each park's committed bake, graph and
# lines, and builds them through Destructibles.build as world.gd does:
#   T7    every row registers (0 refused); every piece is seated on ParkTerrain (each of nine footprint samples within
#         SEAT_M of the piece's foot); every piece passes the dressing placement rules (ParkProps.check_one: line_clear
#         by height tier, telegraph, keepout, home_clear, play_rect, slope), a flat apron round it, and the forbidden list (route lanes, ridden
#         and grapple rows, guarded societies, anchor posts, contraptions, survival yards); at most MAX_SHORTCUTS shortcut
#         pieces a stage, each with open ground behind it that a solid piece leaves connected; and every required
#         route walks on the committed graph with every piece solid (a ground edge that crosses a piece grown by the
#         ball's radius is cut). Planted: a row on a route lane, one on a forbidden row, one that floats and one
#         buried each fail; a ring of pieces round the drop-in breaks the walk.
#   T8    every intact piece 2.0 m or taller stands on the cover layer (Projectile.COVER_MASK); a shattered one has
#         collision_layer 0 and a disabled shape. Planted: an intact tall piece moved off layer 1 fails.
#   Loot  the stage budget (BUDGET_SCRAP, BUDGET_COGS) is under the module's cap (35 / 20); breaking every piece pays
#         at most that, through the isolated stream, and leaves a ScrapField-style shared stream and the panel drop
#         roll where they were. Planted: a drop drawn from the shared stream moves it.
#   T10   no piece is a collider without a mesh while intact, and none keeps a collider after it shatters.
#   Test G the world 1 heft-class histogram at the world's end, read from the committed economy audit runs, decides
#         the tier ceiling (tier 5 ships only where class V is the median); breaking every stage piece adds at most
#         0.078 heft (under 16% of the smallest class interval) and at most 3% of a stage's median cogs. Planted: an
#         uncapped 100-scrap arm fails the bound.
# Shortcuts (spec section 6): no world 1 row carries "shortcut" today. A shortcut must keep every rule above, so it
# stands 20 m or more off every route leg; a graph search over both parks for a legal wall that forces a detour beyond
# walking round the wall itself (the dam's best was 23 m, the same at every open-ground spot) found no narrow passage
# for one to close. The check stays so a later card that finds one is held to it.
# T11, the snag roll, boots the game and is a separate mode of this file (the default run stays static):
#   $GODOT_BIN --headless --fixed-fps 90 --path sketches/core-loop -s tests/destructibles_world1_test.gd -- --snag=park_dam
# It rolls tools/qa/snag_probe.gd's lanes (ride lanes over a low piece, graze lanes along a tall one's faces) at
# cruise with a Class I ball past every piece as the stage built it, then breaks every piece and rolls the same lanes
# again. Pass: no snag on anything but a piece itself while they stand, and no snag at all once they are gone.
# tests/snag_sweep_test.gd is its planted control (run it first: a zero means nothing if the probe is blind).
#
# Output: one `DESTRUCT <park> <measure> <value>` line per measure, plus PASS or FAIL rows from tests/support/t.gd.

const T := preload("res://tests/support/t.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Probe := preload("res://tools/qa/snag_probe.gd")
const ParkDefs := preload("res://src/core/park_defs.gd")
const Destructibles := preload("res://src/world/destructibles.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const GraphTool := preload("res://tools/park_graph.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Panels := preload("res://src/build/panels.gd")
const RunState := preload("res://src/core/run_state.gd")

const MAPS := ["park_dam", "park_flume"]
const SEAT_M := 0.15
# The apron round a piece: ground within APRON_M of its footprint stays within APRON_RISE_M of its foot, so a ball
# that grazes or rides past it rolls on open ground, not off a cliff edge or up a bank (the snag roll's lanes run
# about 10 m past a piece).
const APRON_M := 12.0
const APRON_RISE_M := 1.5
# Within the apron no two ground samples APRON_STEP_M apart differ by more than APRON_LIP_M (about 22 degrees): a
# terrain lip a ball meets side-on beside a piece snags it whether or not the piece stands.
const APRON_STEP_M := 1.5
const APRON_LIP_M := 0.6
# Two pieces keep this much open ground between their footprints, so no cleft forms between them.
const PIECE_GAP_M := 10.0
const BALL_M := 1.0
const COVER_M := 2.0
const PIECES_MIN := 12
const PIECES_MAX := 15
const BUDGET_SCRAP := 32
const BUDGET_COGS := 16
const MAX_SHORTCUTS := 2
const TIER_CEILING := 4
# How far a piece keeps from a forbidden row's footprint, an anchor post, a contraption and a survival yard.
const ROW_CLEAR_M := 12.0
const POST_CLEAR_M := 12.0
const CONTRAPTION_CLEAR_M := 12.0
const YARD_CLEAR_M := 20.0
# A shortcut's open ground: graph nodes this far past each face along its short axis.
const SHORTCUT_REACH_M := 10.0
# Rows a piece never stands on or beside: ridden rows, grapple footings and anchor fields smaller than this, landform
# blocks (the canyon walls, hoodoo stacks, ramps) that are ground rows but stand up out of the floor.
const FIELD_SMALL_M := 100.0
const RIDDEN := ["kicker", "drop", "half_pipe", "rail", "grind_line", "elevated_line", "flow_line", "ledge", "bowl",
	"tunnel", "sky_island", "terrace"]
const ECONOMY := "../../docs/systems-audit/economy/evidence/%s-runs.json"
const ECONOMY_ARMS := ["before", "after-scale-off", "after-scale-on"]
const HEFT_STEP := 0.078
const COG_SHARE := 0.03

var t := T.new("destructibles_world1_test")


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--snag="):
			_snag.call_deferred(arg.substr(7))
			return
	_run.call_deferred()


func _run() -> void:
	var stage_rows := {}
	for map_id in MAPS:
		var w := world(map_id)
		var rows: Array = w["park"].get("destructible_rows", [])
		stage_rows[map_id] = rows
		_t7(map_id, w, rows)
		_route_walk(map_id, w, rows)
		await _t8_t10(map_id, w, rows)
		_loot(map_id, w, rows)
	_planted(world("park_dam"))
	_test_g(stage_rows)
	quit(t.verdict())


# ---- the world a park's rows are judged against ------------------------------------------------------------

# {map, ground, stage, park, ctx (ParkProps.Context), posts, owned}: the park file, its committed bake's ground and
# the placement context the dressing rules read.
static func world(map_id: String) -> Dictionary:
	var w := ParkProps.world_for(map_id)
	w["park"] = (w["map"] as ParkMap).park
	w["ctx"] = ParkProps.context(w["map"], w["ground"], int(w["stage"]))
	var posts := PackedVector2Array()
	var fields: Dictionary = ParkRecipes.field_posts(w["park"]["park_rows"], ParkRecipes.clear_zones(w["park"]))
	for i in fields:
		posts.append_array(fields[i])
	w["posts"] = posts
	var owned: Array = []
	for row in w["park"].get("contraption_rows", []):
		owned.append(String(row.get("id", "")))
	w["owned"] = owned
	return w


static func ground_y(w: Dictionary, p: Vector2) -> float:
	return ((w["ground"] as Callable).call(p.x, p.y, 0.0) as Vector3).y


# The piece's centre, its eight footprint corners and edge midpoints, in world xz, grown by `grow`.
static func footprint(row: Dictionary, grow := 0.0) -> PackedVector2Array:
	var at := _v3(row["at"])
	var half := Vector2(float(row["size"][0]), float(row["size"][2])) * 0.5 + Vector2.ONE * grow
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	var basis := Basis(Vector3.UP, yaw)
	var out := PackedVector2Array()
	for sx in [-1.0, 0.0, 1.0]:
		for sz in [-1.0, 0.0, 1.0]:
			var w3: Vector3 = basis * Vector3(half.x * sx, 0.0, half.y * sz)
			out.append(Vector2(at.x + w3.x, at.z + w3.z))
	return out


static func radius_of(row: Dictionary) -> float:
	return Vector2(float(row["size"][0]), float(row["size"][2])).length() * 0.5


# The seat a row's `at` should carry: the ground under its centre plus half its height.
static func seated_y(w: Dictionary, row: Dictionary) -> float:
	var at := _v3(row["at"])
	return ground_y(w, Vector2(at.x, at.z)) + float(row["size"][1]) * 0.5


# Every reason the row may not stand where it does, [] when it may. One home for the placement rules of the spec's
# sections 2.2 and 6 against a world 1 park.
static func placement_errors(row: Dictionary, w: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var taken := {}
	for id in w["owned"]:
		taken[id] = true
	var why := Destructibles.validate_row(row, taken)
	if why != "":
		out.append("refused: " + why)
		return out
	var at := _v3(row["at"])
	var p := Vector2(at.x, at.z)
	var r := radius_of(row)
	var height := float(row["size"][1])
	var foot := at.y - height * 0.5
	# Seat: the foot within SEAT_M of the ground at every sample, so nothing floats and nothing is buried.
	var worst := 0.0
	for q in footprint(row):
		worst = maxf(worst, absf(foot - ground_y(w, q)))
	if worst > SEAT_M:
		out.append("seat: foot %.2f m off the ground, want at most %.2f" % [worst, SEAT_M])
	# The dressing rules a collision-free prop obeys; a solid piece never gets a looser one.
	var inst := {"vignette": String(row["id"]), "kind": "destructible", "v": "", "class": ParkProps.PROP, "tags": [],
		"pos": at, "radius": r, "height": height, "float_m": 0.0, "slope_deg": 0.0, "line_clear_m": 0.0}
	for v in ParkProps.check_one(inst, w["ctx"]):
		out.append("%s: %s" % [v["rule"], v["detail"]])
	# Required progression: no piece touches a route or waymark leg's lane.
	if ParkRecipes.in_clear((w["ctx"] as ParkProps.Context).lanes, p, r):
		out.append("route: inside a route lane")
	var park: Dictionary = w["park"]
	var grown := footprint_quad(row, ROW_CLEAR_M)
	for prow: Dictionary in park["park_rows"]:
		var element := String(prow.get("element", ""))
		var size: Array = prow["size"]
		var small := maxf(absf(float(size[0])), absf(float(size[2]))) < FIELD_SMALL_M
		var forbidden := element in RIDDEN or String(prow.get("society", "")) in Destructibles.GUARDED_SOCIETIES \
			or (element == "anchor_field" and small) or (element in ["ground", "bank"] and small and float(size[1]) > 2.0) \
			or String(prow.get("home", "")) != ""
		if not forbidden:
			continue
		if not Geometry2D.intersect_polygons(grown, row_quad(prow)).is_empty():
			out.append("row: on or beside %s %s" % [element, prow["id"]])
	for post: Vector2 in w["posts"]:
		if post.distance_to(p) < POST_CLEAR_M + r:
			out.append("anchor: %.1f m from an anchor post" % post.distance_to(p))
			break
	for c: Dictionary in park.get("contraption_rows", []):
		if c.has("at"):
			var cp := Vector2(float(c["at"][0]), float(c["at"][1]))
			if cp.distance_to(p) < CONTRAPTION_CLEAR_M + r:
				out.append("contraption: %.1f m from %s" % [cp.distance_to(p), c["id"]])
	for y: Dictionary in park.get("survival_rows", []):
		var yp := Vector2(float(y["at"][0]), float(y["at"][1]))
		if yp.distance_to(p) < YARD_CLEAR_M + r:
			out.append("yard: %.1f m from %s" % [yp.distance_to(p), y["id"]])
	if out.is_empty():
		var why_apron := apron_error(w, p, r, foot)
		if why_apron != "":
			out.append(why_apron)
	return out


# The ground round a piece: within APRON_M of its footprint no sample is more than APRON_RISE_M off its foot (no cliff
# edge or bank beside it), and no two neighbouring samples differ by more than APRON_LIP_M (no lip). "" when clear.
static func apron_error(w: Dictionary, p: Vector2, r: float, foot: float) -> String:
	var half := r + APRON_M
	var n := ceili(half * 2.0 / APRON_STEP_M) + 1
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	var rise := 0.0
	for j in n:
		for i in n:
			var h := ground_y(w, p + Vector2(-half + i * APRON_STEP_M, -half + j * APRON_STEP_M))
			heights[j * n + i] = h
			rise = maxf(rise, absf(h - foot))
	if rise > APRON_RISE_M:
		return "apron: ground within %.0f m is %.1f m off the foot, want at most %.1f" % [APRON_M, rise, APRON_RISE_M]
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			if (i + 1 < n and absf(heights[j * n + i + 1] - h) > APRON_LIP_M) or (j + 1 < n and absf(heights[(j + 1) * n + i] - h) > APRON_LIP_M):
				return "apron: a ground lip within %.0f m" % APRON_M
	return ""


# Pairs of rows whose footprints stand closer than PIECE_GAP_M: ["a b distance"].
static func crowded(rows: Array) -> Array[String]:
	var out: Array[String] = []
	for i in rows.size():
		for k in range(i + 1, rows.size()):
			var a := _v3(rows[i]["at"])
			var b := _v3(rows[k]["at"])
			var gap := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) - radius_of(rows[i]) - radius_of(rows[k])
			if gap < PIECE_GAP_M:
				out.append("%s %s %.1f" % [rows[i]["id"], rows[k]["id"], gap])
	return out


# ---- T7: registration, seat, rules, shortcuts ---------------------------------------------------------------

func _t7(map_id: String, w: Dictionary, rows: Array) -> void:
	t.check("%s has %d to %d pieces" % [map_id, PIECES_MIN, PIECES_MAX], rows.size() >= PIECES_MIN and rows.size() <= PIECES_MAX, "%d" % rows.size())
	var pieces := Destructibles.new()
	pieces.build({"destructible_rows": rows}, {"root": root, "owned_ids": w["owned"], "no_visuals": true})
	t.eq("%s rows refused by Destructibles.build" % map_id, pieces.refusals().size(), 0)
	t.eq("%s pieces registered" % map_id, pieces.ids().size(), rows.size())
	pieces.teardown()
	pieces.queue_free()
	var bad := 0
	var tiers := {}
	var shortcuts := 0
	for row: Dictionary in rows:
		var errors := placement_errors(row, w)
		if not errors.is_empty():
			bad += 1
			print("DESTRUCT %s %s %s" % [map_id, row.get("id", "?"), "; ".join(errors)])
		tiers[int(row["tier"])] = int(tiers.get(int(row["tier"]), 0)) + 1
		if bool(row.get("shortcut", false)):
			shortcuts += 1
			t.check("%s shortcut %s has open ground behind it" % [map_id, row["id"]], shortcut_open(w, row, rows))
	t.eq("%s pieces breaking a placement rule" % map_id, bad, 0)
	t.eq("%s piece pairs closer than %.0f m" % [map_id, PIECE_GAP_M], crowded(rows), [] as Array[String])
	t.check("%s shortcut pieces at most %d" % [map_id, MAX_SHORTCUTS], shortcuts <= MAX_SHORTCUTS, "%d" % shortcuts)
	t.check("%s tiers stay within 1 to %d" % [map_id, TIER_CEILING], tiers.keys().all(func(k): return k >= 1 and k <= TIER_CEILING), str(tiers))
	print("DESTRUCT %s pieces %d tiers %s shortcuts %d" % [map_id, rows.size(), str(tiers), shortcuts])


# A shortcut fronts open ground: on the committed graph, open nodes stand past both of its long faces, a ground edge
# crosses its footprint (the ground under it is ridden today), and with every piece solid the two sides still join.
static func shortcut_open(w: Dictionary, row: Dictionary, rows: Array) -> bool:
	var graph = ParkGraph.read(ParkMap.graph_path_for(String(w["park"]["map"]) + ".json"))
	if graph == null:
		return false
	var at := _v3(row["at"])
	var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
	var across: Vector3 = Basis(Vector3.UP, yaw) * Vector3(0.0, 0.0, float(row["size"][2]) * 0.5 + SHORTCUT_REACH_M)
	var a: int = graph.nearest(Vector3(at.x + across.x, at.y, at.z + across.z))
	var b: int = graph.nearest(Vector3(at.x - across.x, at.y, at.z - across.z))
	if a < 0 or b < 0 or (graph.flags(a) & ParkGraph.OPEN) == 0 or (graph.flags(b) & ParkGraph.OPEN) == 0:
		return false
	var crossed := false
	var poly := footprint_quad(row, BALL_M)
	for n in graph.disc_nodes(Vector2(at.x, at.z), 12.0):
		for e in range(graph.off[n], graph.off[n + 1]):
			if graph.ride[e] < 0 and _segment_hits(Vector2(graph.px[n], graph.pz[n]), Vector2(graph.px[graph.to[e]], graph.pz[graph.to[e]]), poly):
				crossed = true
	if not crossed:
		return false
	var solid = blocked_graph(graph, rows)
	var seen: PackedByteArray = solid.reach(PackedInt32Array([a]))
	return seen[b] == 1


# ---- the route walk -----------------------------------------------------------------------------------------

# The piece's footprint corners in order, grown by `grow`.
static func footprint_quad(row: Dictionary, grow := 0.0) -> PackedVector2Array:
	var at := _v3(row["at"])
	var half := Vector2(float(row["size"][0]), float(row["size"][2])) * 0.5 + Vector2.ONE * grow
	var basis := Basis(Vector3.UP, deg_to_rad(float(row.get("yaw_deg", 0.0))))
	var out := PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var w3: Vector3 = basis * Vector3(half.x * s.x, 0.0, half.y * s.y)
		out.append(Vector2(at.x + w3.x, at.z + w3.z))
	return out


# A park row's footprint corners in world xz, in ParkMap.footprint_contains' frame (local x carries size[2]).
static func row_quad(prow: Dictionary) -> PackedVector2Array:
	var half := ParkMap.footprint_half_extents(prow)
	var centre := Vector2(float(prow["at"][0]), float(prow["at"][1]))
	var yaw := deg_to_rad(float(prow.get("yaw_deg", 0.0)))
	var out := PackedVector2Array()
	for s: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		out.append(centre + Vector2(half.x * s.x, half.y * s.y).rotated(-yaw))
	return out


static func _segment_hits(a: Vector2, b: Vector2, quad: PackedVector2Array) -> bool:
	if Geometry2D.is_point_in_polygon(a, quad) or Geometry2D.is_point_in_polygon(b, quad):
		return true
	for k in quad.size():
		if Geometry2D.segment_intersects_segment(a, b, quad[k], quad[(k + 1) % quad.size()]) != null:
			return true
	return false


# The graph with every ground edge cut that crosses a piece's footprint grown by the ball's radius: every piece
# treated as solid, as a Class I ball meets anything above tier 1. Ride edges (kickers, cables, lifts) fly over.
static func blocked_graph(graph, rows: Array):
	var g = ParkGraph.from_bytes(graph.to_bytes())
	var quads: Array = []
	var boxes: Array[Rect2] = []
	for row: Dictionary in rows:
		var quad := footprint_quad(row, BALL_M)
		quads.append(quad)
		var box := Rect2(quad[0], Vector2.ZERO)
		for q in quad:
			box = box.expand(q)
		boxes.append(box)
	var off := PackedInt32Array([0])
	var to := PackedInt32Array()
	var length := PackedFloat32Array()
	var ride := PackedInt32Array()
	for n in g.px.size():
		var a := Vector2(g.px[n], g.pz[n])
		for e in range(g.off[n], g.off[n + 1]):
			var m: int = g.to[e]
			var keep := true
			if g.ride[e] < 0:
				var b := Vector2(g.px[m], g.pz[m])
				var seg := Rect2(a, Vector2.ZERO).expand(b)
				for k in quads.size():
					if boxes[k].intersects(seg, true) and _segment_hits(a, b, quads[k]):
						keep = false
						break
			if keep:
				to.append(m)
				length.append(g.length[e])
				ride.append(g.ride[e])
		off.append(to.size())
	g.off = off
	g.to = to
	g.length = length
	g.ride = ride
	g.reverse()
	return g


# Breaks on the committed graph, then with every piece solid; both must be none.
static func route_breaks(w: Dictionary, rows: Array) -> Dictionary:
	var graph = ParkGraph.read(ParkMap.graph_path_for(String(w["park"]["map"]) + ".json"))
	if graph == null:
		return {"error": "no graph"}
	return {"base": GraphTool.route_breaks(graph, w["park"]), "solid": GraphTool.route_breaks(blocked_graph(graph, rows), w["park"]),
		"cut": graph.to.size() - blocked_graph(graph, rows).to.size()}


func _route_walk(map_id: String, w: Dictionary, rows: Array) -> void:
	var r := route_breaks(w, rows)
	if not t.check("%s graph loads" % map_id, not r.has("error")):
		return
	t.eq("%s route breaks on the committed graph" % map_id, (r["base"] as Array).size(), 0)
	t.eq("%s route breaks with every piece solid at class I" % map_id, (r["solid"] as Array).size(), 0)
	print("DESTRUCT %s route_walk routes %d breaks %d edges_cut %d" % [map_id, (w["park"]["routes"] as Array).size(), (r["solid"] as Array).size(), r["cut"]])


# ---- T8 and T10: cover and invisible walls ------------------------------------------------------------------

func _t8_t10(map_id: String, w: Dictionary, rows: Array) -> void:
	var pieces := Destructibles.new()
	pieces.build({"destructible_rows": rows}, {"root": root, "owned_ids": w["owned"], "no_visuals": false, "run_seed": 7})
	pieces.finish_build()
	await physics_frame
	var r := cover_read(pieces, rows)
	t.check("%s has hard-cover pieces" % map_id, r["hard"] > 0, "%d" % r["hard"])
	t.eq("%s intact tall pieces off the cover layer" % map_id, r["off_cover"], 0)
	t.eq("%s intact pieces with a collider and no mesh" % map_id, r["no_mesh"], 0)
	for id in pieces.ids():
		pieces.on_blast(_v3(_row(rows, id)["at"]), 0.5, "test", 1, 5)
	await physics_frame
	var after := cover_read(pieces, rows)
	t.eq("%s pieces left intact after breaking all" % map_id, pieces.intact_count(), 0)
	t.eq("%s shattered pieces still on a layer or with a live shape" % map_id, after["live_after"], 0)
	print("DESTRUCT %s cover hard %d off_cover %d no_mesh %d live_after_shatter %d" % [map_id, r["hard"], r["off_cover"], r["no_mesh"], after["live_after"]])
	pieces.teardown()
	pieces.queue_free()


# {hard, off_cover, no_mesh, live_after}: intact pieces COVER_M or taller, those whose body misses the shell's cover
# mask, intact pieces with a collider and no shown mesh, shattered pieces whose body keeps a layer or a live shape.
static func cover_read(pieces, rows: Array) -> Dictionary:
	var out := {"hard": 0, "off_cover": 0, "no_mesh": 0, "live_after": 0}
	for id in pieces.ids():
		var body: StaticBody3D = pieces.body_of(id)
		var tall := float(_row(rows, id)["size"][1]) >= COVER_M
		if pieces.state_of(id) == "intact":
			if tall:
				out["hard"] += 1
				if body == null or (body.collision_layer & Projectile.COVER_MASK) == 0:
					out["off_cover"] += 1
			var mesh := pieces.get_node_or_null("Intact_" + id) as MeshInstance3D
			if body != null and (mesh == null or not mesh.visible or mesh.mesh == null):
				out["no_mesh"] += 1
		else:
			var live := body != null and is_instance_valid(body) and body.collision_layer != 0
			for shape in (body.find_children("*", "CollisionShape3D", true, false) if body != null else []):
				if not (shape as CollisionShape3D).disabled:
					live = true
			if live:
				out["live_after"] += 1
	return out


# ---- loot: budget, cap, isolation ---------------------------------------------------------------------------

# The most a stage's rows can pay: tier 1 counts its whole roll, every other tier its table row.
static func budget(rows: Array) -> Dictionary:
	var scrap := 0
	var cogs := 0
	for row: Dictionary in rows:
		var loot: Array = Destructibles.LOOT[int(row["tier"])]
		scrap += int(loot[0])
		cogs += int(loot[1])
	return {"scrap": scrap, "cogs": cogs}


class ScrapStub extends RefCounted:
	var scrap := 0
	var cogs := 0
	var shared: RandomNumberGenerator = null
	var from_shared := false

	func drop(_at: Vector3, amount: int, rng: RandomNumberGenerator) -> void:
		scrap += amount
		var stream := shared if from_shared else rng
		for i in amount:
			stream.randf()

	func drop_cogs(_at: Vector3, amount: int) -> void:
		cogs += amount


func _loot(map_id: String, w: Dictionary, rows: Array) -> void:
	var b := budget(rows)
	t.check("%s budget scrap at most %d" % [map_id, BUDGET_SCRAP], b["scrap"] <= BUDGET_SCRAP, "%d" % b["scrap"])
	t.check("%s budget cogs at most %d" % [map_id, BUDGET_COGS], b["cogs"] <= BUDGET_COGS, "%d" % b["cogs"])
	var shared := RandomNumberGenerator.new()
	shared.seed = 4242
	var expect_shared := RandomNumberGenerator.new()
	expect_shared.seed = 4242
	var paid := _break_all(w, rows, shared, false)
	t.check("%s breaking all pays at most the cap" % map_id, paid["scrap"] <= Destructibles.SCRAP_CAP and paid["cogs"] <= Destructibles.COG_CAP, str(paid))
	t.check("%s breaking all pays at most the budget" % map_id, paid["scrap"] <= b["scrap"] and paid["cogs"] <= b["cogs"], str(paid))
	t.eq("%s the next panel draw is unchanged by every break" % map_id, Panels.draw(shared, "sable"), Panels.draw(expect_shared, "sable"))
	t.eq("%s the shared loot stream is untouched by every break" % map_id, shared.randi(), expect_shared.randi())
	print("DESTRUCT %s loot budget scrap %d cogs %d paid scrap %d cogs %d" % [map_id, b["scrap"], b["cogs"], paid["scrap"], paid["cogs"]])
	# Planted: the same breaks drawing from the shared stream move it.
	var planted := RandomNumberGenerator.new()
	planted.seed = 4242
	var control := RandomNumberGenerator.new()
	control.seed = 4242
	var planted_paid := _break_all(w, rows, planted, true)
	if planted_paid["scrap"] > 0:
		t.check("%s planted: drops from the shared stream move it" % map_id, planted.randi() != control.randi())


static func _break_all(w: Dictionary, rows: Array, shared: RandomNumberGenerator, from_shared: bool) -> Dictionary:
	var stub := ScrapStub.new()
	stub.shared = shared
	stub.from_shared = from_shared
	var pieces := Destructibles.new()
	pieces.build({"destructible_rows": rows}, {"owned_ids": w["owned"], "no_visuals": true, "scrap": stub,
		"run_seed": 2860, "run_id": "w1", "stage": int(w["stage"]), "enemies": func() -> Array: return []})
	for id in pieces.ids():
		pieces.on_blast(_v3(_row(rows, id)["at"]), 0.5, "test", 1, 5)
	var out := {"scrap": stub.scrap, "cogs": stub.cogs}
	pieces.teardown()
	pieces.free()
	return out


# ---- Test G: heft classes and the economy bound -------------------------------------------------------------

# {class -> runs} of the class held at the end of world 1, over every committed economy arm, plus the median and the
# per-stage median cogs (cogs earned over world 1 halved).
static func heft_histogram() -> Dictionary:
	var hist := {}
	var classes: Array = []
	var cogs: Array = []
	for arm in ECONOMY_ARMS:
		var path := ProjectSettings.globalize_path("res://").path_join(ECONOMY % arm).simplify_path()
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		if not parsed is Array:
			continue
		for run: Dictionary in parsed:
			if int(run.get("stage_reached", 0)) < 3:
				continue
			var k := int(run.get("heft_end", 0))
			hist[k] = int(hist.get(k, 0)) + 1
			classes.append(k)
			cogs.append(float(run.get("cogs_earned", 0.0)) * 0.5)
	classes.sort()
	cogs.sort()
	return {"hist": hist, "runs": classes.size(), "median": classes[classes.size() / 2] if not classes.is_empty() else 0,
		"max": classes.max() if not classes.is_empty() else 0, "stage_cogs": cogs[cogs.size() / 2] if not cogs.is_empty() else 0.0}


# Whether a stage arm adding `scrap` and `cogs` stays inside audit noise: at most HEFT_STEP heft, under 16% of the
# smallest class interval, and at most COG_SHARE of a stage's median cogs.
static func economy_ok(scrap: int, cogs: int, stage_cogs: float) -> bool:
	var heft := scrap * RunState.HEFT_PER_MASS
	var interval := float(RunState.HEFT_CLASS_AT[1]) - float(RunState.HEFT_CLASS_AT[0])
	return heft <= HEFT_STEP and heft < 0.16 * interval and stage_cogs > 0.0 and cogs <= COG_SHARE * stage_cogs


func _test_g(stage_rows: Dictionary) -> void:
	var h := heft_histogram()
	print("DESTRUCT world1 heft_class_at_world_end %s runs %d median %d max %d stage_cogs %.0f" % [str(h["hist"]), h["runs"], h["median"], h["max"], h["stage_cogs"]])
	t.check("economy audit runs read", int(h["runs"]) > 0, "%d" % h["runs"])
	var tier5 := false
	for map_id in stage_rows:
		for row: Dictionary in stage_rows[map_id]:
			tier5 = tier5 or int(row["tier"]) >= 5
	t.check("tier 5 ships only when class V is the world-end median", not tier5 or int(h["median"]) >= 5, "median %d" % h["median"])
	for map_id in stage_rows:
		var b := budget(stage_rows[map_id])
		var heft := float(b["scrap"]) * RunState.HEFT_PER_MASS
		print("DESTRUCT %s economy scrap %d heft %.3f cogs %d share %.3f" % [map_id, b["scrap"], heft, b["cogs"], float(b["cogs"]) / maxf(float(h["stage_cogs"]), 1.0)])
		t.check("%s economy inside audit noise" % map_id, economy_ok(b["scrap"], b["cogs"], float(h["stage_cogs"])))
	t.check("cap arm (35 scrap, 20 cogs) inside audit noise", economy_ok(Destructibles.SCRAP_CAP, Destructibles.COG_CAP, float(h["stage_cogs"])))
	t.check("planted: an uncapped 100-scrap arm fails the bound", not economy_ok(100, 20, float(h["stage_cogs"])))


# ---- planted controls ---------------------------------------------------------------------------------------

func _planted(w: Dictionary) -> void:
	var rows: Array = w["park"].get("destructible_rows", [])
	if rows.is_empty():
		t.check("planted controls need dam rows", false)
		return
	var good: Dictionary = (rows[0] as Dictionary).duplicate(true)
	t.eq("planted: the first dam row passes as placed", placement_errors(good, w), [] as Array[String])
	# On a required route: the drop-in's spawn sits on the first route leg.
	var spawn: Array = w["park"]["spawn"]["at"]
	var on_route := _moved(w, good, Vector2(float(spawn[0]) + 30.0, float(spawn[1]) + 30.0))
	t.check("planted: a row on a route lane fails", _has(placement_errors(on_route, w), "route"))
	# On a forbidden row: the dam's gate_piers anchor field.
	var piers := _moved(w, good, Vector2(0.0, 605.0))
	t.check("planted: a row on the gate piers fails", _has(placement_errors(piers, w), "row") or _has(placement_errors(piers, w), "keepout"))
	var guarded := good.duplicate(true)
	guarded["society"] = "hohokam"
	t.check("planted: a guarded-society row is refused", _has(placement_errors(guarded, w), "refused"))
	var ridden := good.duplicate(true)
	ridden["element"] = "kicker"
	t.check("planted: a ridden-element row is refused", _has(placement_errors(ridden, w), "refused"))
	var floating := good.duplicate(true)
	floating["at"] = [float(good["at"][0]), float(good["at"][1]) + 0.5, float(good["at"][2])]
	t.check("planted: a floating row fails the seat", _has(placement_errors(floating, w), "seat"))
	var buried := good.duplicate(true)
	buried["at"] = [float(good["at"][0]), float(good["at"][1]) - 0.5, float(good["at"][2])]
	t.check("planted: a buried row fails the seat", _has(placement_errors(buried, w), "seat"))
	# A ring of four walls round the drop-in: the shelf route cannot leave it.
	var ring: Array = rows.duplicate(true)
	var c := Vector2(float(spawn[0]), float(spawn[1]))
	for k in 4:
		var dir := Vector2.from_angle(k * TAU / 4.0)
		var wall := {"id": "planted_ring_%d" % k, "tier": 3, "size": [60.0, 3.0, 2.0],
			"yaw_deg": rad_to_deg(-dir.angle()) + 90.0}
		var p := c + dir * 25.0
		wall["at"] = [p.x, ground_y(w, p) + 1.5, p.y]
		ring.append(wall)
	var r := route_breaks(w, ring)
	t.check("planted: a ring of pieces round the drop-in breaks the route walk", not (r.get("solid", []) as Array).is_empty(), "%d breaks" % (r.get("solid", []) as Array).size())
	# T8 planted: an intact tall piece off the cover layer.
	var tall: Array = rows.filter(func(row): return float(row["size"][1]) >= COVER_M)
	if not tall.is_empty():
		var pieces := Destructibles.new()
		pieces.build({"destructible_rows": tall}, {"root": root, "owned_ids": w["owned"], "no_visuals": false})
		pieces.finish_build()
		var id: String = pieces.ids()[0]
		pieces.body_of(id).collision_layer = 1 << 4
		t.check("planted: an intact tall piece off layer 1 fails the cover read", int(cover_read(pieces, tall)["off_cover"]) == 1)
		# T10 planted: a body left behind with no mesh.
		pieces.get_node("Intact_" + id).visible = false
		t.check("planted: a collider with its mesh hidden fails the invisible-wall read", int(cover_read(pieces, tall)["no_mesh"]) >= 1)
		pieces.teardown()
		pieces.queue_free()


static func _moved(w: Dictionary, row: Dictionary, p: Vector2) -> Dictionary:
	var out := row.duplicate(true)
	out["at"] = [p.x, ground_y(w, p) + float(row["size"][1]) * 0.5, p.y]
	return out


static func _has(errors: Array[String], rule: String) -> bool:
	for e in errors:
		if e.begins_with(rule + ":"):
			return true
	return false


static func _row(rows: Array, id: String) -> Dictionary:
	for row: Dictionary in rows:
		if String(row["id"]) == id:
			return row
	return {}


static func _v3(v: Variant) -> Vector3:
	if v is Vector3:
		return v
	return Vector3(float(v[0]), float(v[1]), float(v[2]))


# ---- T11: the snag roll (its own mode: --snag=<park map>) ------------------------------------------------------

func _snag(map_id: String) -> void:
	var stage := 0
	for row in ParkDefs.DEFS:
		if String(row.get("map", "")) == map_id:
			stage = int(row["stage"])
	if not t.check("%s is a park table map" % map_id, stage > 0):
		quit(t.verdict())
		return
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	game.ground_behind_menu = false
	root.add_child(game)
	while game.flow == null:
		await process_frame
	game.run.run_seed_override = 1
	game.ctx.calm = true
	var source := Intent.Scripted.new()
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(0)
	if stage != 1:
		game.flow.enter_stage(stage, Vector3.ZERO, false)
	var terrain = game.ctx.terrain
	var waited := 0
	while waited < 3000 and not (terrain.rows_ready(stage) and terrain.is_ready(stage) and game.flow.state_name() == "stage"):
		await process_frame
		waited += 1
	for i in 40:
		await physics_frame
	var pieces = game.ctx.destructibles
	if not t.check("%s hosts its destructibles" % map_id, pieces != null and is_instance_valid(pieces) and pieces.ids().size() > 0):
		quit(t.verdict())
		return
	t.eq("%s ball heft class" % map_id, game.run.heft_class(), 1)
	var probe = Probe.new(self, game, source)
	var list := snag_pieces(pieces)
	var intact := await _roll_all(probe, list)
	for id in pieces.ids():
		pieces.on_blast(pieces.bounds_of(id).get_center(), 0.5, "test", 1, 5)
	for i in 4:
		await physics_frame
	t.eq("%s pieces intact after breaking all" % map_id, pieces.intact_count(), 0)
	var gone := await _roll_all(probe, list)
	var other: Array = intact["snags"].filter(func(row): return String(row.get("class", "")) != "piece")
	var own: Array = intact["snags"].filter(func(row): return String(row.get("class", "")) == "piece")
	print("DESTRUCT %s snag intact lanes %d snags_other %d snags_on_piece %d broken_in_roll %d | shattered lanes %d snags %d" % [map_id,
		intact["lanes"], other.size(), own.size(), intact["broke"], gone["lanes"], (gone["snags"] as Array).size()])
	for row in other + (gone["snags"] as Array):
		print("DESTRUCT %s snag %s" % [map_id, JSON.stringify(row)])
	t.check("%s lanes rolled with the pieces standing" % map_id, int(intact["lanes"]) > 0, "%d" % intact["lanes"])
	t.eq("%s snags on anything but a piece while they stand" % map_id, other.size(), 0)
	t.eq("%s snags once every piece is broken" % map_id, (gone["snags"] as Array).size(), 0)
	quit(t.verdict())


# Each piece as snag_probe.gd reads one: {path, aabb (in its own yaw frame), yaw}, from the built body.
static func snag_pieces(pieces) -> Array:
	var out := []
	for id in pieces.ids():
		var body: StaticBody3D = pieces.body_of(id)
		var yaw := body.global_transform.basis.get_euler().y
		var shape := body.get_child(0) as CollisionShape3D
		var box: AABB = Transform3D(Basis(Vector3.UP, -yaw), Vector3.ZERO) * body.global_transform * shape.shape.get_debug_mesh().get_aabb()
		out.append({"path": String(body.get_path()), "aabb": box, "yaw": yaw, "id": id})
	return out


func _roll_all(probe, list: Array) -> Dictionary:
	var out := {"lanes": 0, "snags": [], "broke": 0}
	for piece in list:
		var before: int = probe._game.ctx.destructibles.intact_count()
		for lane in probe.lanes(piece):
			var row: Dictionary = await probe.roll(piece, lane)
			if row.has("skipped"):
				continue
			out["lanes"] += 1
			if row.has("piece"):
				row["id"] = piece["id"]
				(out["snags"] as Array).append(row)
		out["broke"] += before - int(probe._game.ctx.destructibles.intact_count())
	return out
