extends SceneTree
# Natural stands (park_recipes.gd NATURAL_STANDS): a hoodoo field or saguaro stand at least ANCHOR_STAND_MIN_M across
# draws its posts off the 20 m lattice, so from above it reads as a stand, not rows (4080 park stills, acb55972).
# (a) every park keeps its post count, the moves aside; (b) most of the dam's stand posts leave their lattice spot;
# (c) no two lattice posts of a stand stand closer than ANCHOR_STAND_GAP_M (lanes left out, so every post is a
# lattice post); (d) no 10 m point of a stand field (outside other rows' footprints and outside a post) that the
# lattice kept within REACH_M of a post centre (so its face too stands inside the 40 m aim band) is left beyond it; (e) a field narrower than
# ANCHOR_STAND_MIN_M, and every field of another landform, keeps its lattice. Evidence limit: placement data only.

const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const T := preload("res://tests/support/t.gd")

const PARKS := ["dam", "flume", "pit", "sinkhole", "islands", "crown"]
const LATTICE_M := 10.0
# A post centre within 40 m puts the post's face (any of its hull or box points facing the probe) within 40 m too.
const REACH_M := 40.0
const MOVED_SHARE := 0.7
const CELL_M := REACH_M

var _t := T.new("park_anchor_stand_test")


func _initialize() -> void:
	call_deferred("_run")


func _park(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_%s.json" % name))


func _is_stand(row: Dictionary) -> bool:
	var size: Array = row["size"]
	return ParkRecipes.NATURAL_STANDS.has(String(row.get("landform", ""))) and minf(float(size[0]), float(size[2])) >= ParkRecipes.ANCHOR_STAND_MIN_M


func _lattice(row: Dictionary, zones: Array) -> PackedVector2Array:
	var flat := row.duplicate()
	flat["landform"] = "none"
	return ParkRecipes.anchor_posts(flat, zones)


func _run() -> void:
	for name: String in PARKS:
		var park := _park(name)
		var zones := ParkRecipes.clear_zones(park)
		var lanes_off := zones.filter(func(z: Dictionary) -> bool: return not z.has("a"))
		var counts := [0, 0]
		var still: Array[String] = []
		var tight: Array[String] = []
		var moved := 0
		var stand_posts := 0
		var all_posts := PackedVector2Array()
		var all_grid := PackedVector2Array()
		var stands: Array = []
		for row: Dictionary in ParkRecipes.placed_rows(park):
			if not ParkRecipes.is_anchor_field(row):
				continue
			var posts := ParkRecipes.anchor_posts(row, zones)
			var grid := _lattice(row, zones)
			counts[0] += posts.size()
			counts[1] += grid.size()
			all_posts.append_array(posts)
			all_grid.append_array(grid)
			if not _is_stand(row):
				if posts != grid:
					still.append(String(row["id"]))
				continue
			for k in mini(posts.size(), grid.size()):
				stand_posts += 1
				if posts[k].distance_to(grid[k]) >= 1.0:
					moved += 1
			var open := ParkRecipes.anchor_posts(row, lanes_off)
			for i in open.size():
				for j in range(i + 1, open.size()):
					if open[i].distance_to(open[j]) < ParkRecipes.ANCHOR_STAND_GAP_M - 0.001:
						tight.append("%s %s %s" % [row["id"], open[i], open[j]])
			stands.append(row)
		_t.eq("(a) %s keeps its post count" % name, counts[0], counts[1])
		_t.check("(e) %s: other fields keep the lattice" % name, still.is_empty(), str(still))
		_t.check("(c) %s: stand posts keep %.0f m apart" % [name, ParkRecipes.ANCHOR_STAND_GAP_M], tight.is_empty(), str(tight.slice(0, 4)))
		print("park_anchor_stand_test: %s %d posts, %d in stands, %d moved" % [name, counts[0], stand_posts, moved])
		if name == "dam":
			_t.check("(b) dam: most stand posts leave the lattice", stand_posts > 0 and float(moved) / float(stand_posts) >= MOVED_SHARE, "%d of %d" % [moved, stand_posts])
		if not stands.is_empty():
			var lost := _lost_reach(stands, _cells(all_posts), _cells(all_grid), lanes_off)
			_t.check("(d) %s: no stand point the lattice kept within %.0f m of a post centre is left beyond it" % [name, REACH_M], lost[0] == 0,
				"%d of %d points, worst %.1f m at %s" % [lost[0], lost[1], lost[2], lost[3]])
			print("park_anchor_stand_test: %s reach judged %d points, %d lost, worst moved %.1f m" % [name, lost[1], lost[0], lost[2]])
	# (e) the boundary: a planted hoodoo field exactly ANCHOR_STAND_MIN_M across moves, a hair under it keeps its lattice.
	var planted := {"id": "planted_stand", "element": "anchor_field", "landform": "hoodoo_field", "at": [0, 0], "size": [ParkRecipes.ANCHOR_STAND_MIN_M, 2, ParkRecipes.ANCHOR_STAND_MIN_M], "yaw_deg": 0, "recipe": "anchor_hoodoo"}
	var at_min := ParkRecipes.anchor_posts(planted)
	_t.check("(e) a stand exactly %.0f m across moves" % ParkRecipes.ANCHOR_STAND_MIN_M, at_min != _lattice(planted, []), str(at_min))
	var under := planted.merged({"size": [ParkRecipes.ANCHOR_STAND_MIN_M - 0.1, 2, ParkRecipes.ANCHOR_STAND_MIN_M]}, true)
	_t.check("(e) a stand under %.0f m keeps its lattice" % ParkRecipes.ANCHOR_STAND_MIN_M, ParkRecipes.anchor_posts(under) == _lattice(under, []))
	quit(_t.verdict())


# Posts by CELL_M cell.
func _cells(posts: PackedVector2Array) -> Dictionary:
	var out := {}
	for q: Vector2 in posts:
		var c := Vector2i(floori(q.x / CELL_M), floori(q.y / CELL_M))
		if not out.has(c):
			out[c] = PackedVector2Array()
		out[c].append(q)
	return out


# The nearest post centre to p within CELL_M (INF beyond).
func _nearest(cells: Dictionary, p: Vector2) -> float:
	var c := Vector2i(floori(p.x / CELL_M), floori(p.y / CELL_M))
	var best := INF
	for dj in range(-1, 2):
		for di in range(-1, 2):
			for q: Vector2 in cells.get(c + Vector2i(di, dj), PackedVector2Array()):
				best = minf(best, q.distance_to(p))
	return best


# [points lost, points judged, worst moved distance, worst point] over every 10 m point of the stands: a point inside
# another row's footprint or its run-out is that row's to anchor and a point inside a post is no floor
# (park_place_test's judged set); a point is lost when the lattice kept it within REACH_M and the moved posts do not.
func _lost_reach(stands: Array, moved: Dictionary, grid: Dictionary, footprints: Array) -> Array:
	var lost := 0
	var judged := 0
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for row: Dictionary in stands:
		var size: Array = row["size"]
		var yaw := deg_to_rad(float(row.get("yaw_deg", 0.0)))
		var along := Vector2(sin(yaw), cos(yaw))
		var across := Vector2(cos(yaw), -sin(yaw))
		var at := Vector2(float(row["at"][0]), float(row["at"][1]))
		var u := -float(size[0]) * 0.5
		while u <= float(size[0]) * 0.5 + 0.001:
			var v := -float(size[2]) * 0.5
			while v <= float(size[2]) * 0.5 + 0.001:
				var p := at + along * u + across * v
				v += LATTICE_M
				if ParkRecipes.in_clear(footprints, p, ParkRecipes.ANCHOR_RUNOUT_M, ParkRecipes.ANCHOR_SIDE_M):
					continue
				var now := _nearest(moved, p)
				if now < ParkRecipes.ANCHOR_POST_M * 0.5 or _nearest(grid, p) > REACH_M:
					continue
				judged += 1
				if now > REACH_M:
					lost += 1
				if now > worst and now < INF:
					worst = now
					worst_at = p
			u += LATTICE_M
	return [lost, judged, worst, worst_at]
