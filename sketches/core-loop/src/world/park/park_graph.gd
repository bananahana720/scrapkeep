extends RefCounted

# The stage graph (design-v3/PARK.md 2.11, K-UNITS KB8): the stage's one measured space. Built
# by tools/park_graph.gd from the park file and its bake, read here from graph.bin. Every
# system that asks "how far along the stage" asks this graph: the spawn and pocket checks
# (2.12), the director's home arrivals (a home is ahead when its site's d_landmark is smaller
# than the ball's), the traversal tool's progress_m.
#
# Nodes. The ground lattice comes first: one node per 8 m on the bake's 2 m grid (every fourth
# vertex), 201 by 201, row-major (z, then x), node (I, J) at x = -800 + 8 I, z = -800 + 8 J, at
# the ground height, or on a hole cell at the under.bin floor. Then the decks: for each park row
# whose y is not null, in file order, its own lattice of 8 m steps along and across its yaw,
# centred on its footprint, at that y. node_row(n) names the deck row, "" for the ground.
#
# Edges are directed, kept as CSR in both directions, each with its length in path metres and
# the park or contraption row id of a ride edge ("" for ground). d_landmark and d_spawn are the
# two distance fields the tool stores, INF where no path reaches.
#
# Flags are this graph's own bits; none are copied from any game (research/comps/
# pocket-placement.md:58).
#
# Zones (SQ13, version 2). The stage is also cut into landform zones, the coarse grain beside the
# 8 m nodes (research/comps/pocket-placement.md:49: zones decide the story of the stage, nodes
# decide the physics). Every node belongs to exactly one zone: zone_of(n), never -1 in a version 2
# file. A zone is one connected piece of one landform: a park row's footprint (the smallest
# footprint wins where rows overlap), a deck row's lattice, or the open ground between landforms
# (one zone per connected piece, so a wall across the plain makes two). Anchor_field rows are
# furniture and the one background row that covers most of the square is the open ground; neither
# makes a zone of its own. A piece under ZONE_FRAGMENT_NODES that is not the largest of its
# landform joins the zone it shares most edges with. tools/park_graph.gd bakes the zones and their
# crossings into graph.bin; zones(), crossings() and anchors() read them.
#
# A crossing joins two zones in one move: `walk` is a ground boundary walkable both ways (at
# least ZONE_MIN_LINKS node links each way), `ride` is one ride edge row (a kicker, a cable, a
# lift) from one zone to the other, `drop` is a ground boundary walkable one way only (a ledge
# edge, at least ZONE_MIN_LINKS links), from the higher zone to the lower. A zone's entrances are
# the zones that reach it in one move (walk either way, ride in, drop in); a way out is not an
# entrance. `degree` is the entrance count. An anchor is a zone of degree 1: one way in, the
# analog of a dead end (comps pocket-placement.md step 3).
#
# Zone record (zones()): id, name, kind (landform, deck, under, open), row ("" for open), nodes,
# cx and cz (mean position, 0.1 m), line (holds a line node), warden (holds a warden-ring node),
# door_ok (door_ok node count), d_spawn and d_landmark (the least path metres over the zone's
# nodes, the entry cost; -1 when unreachable), degree, entrances and exits (zone ids, ascending),
# openings (walk plus ride crossings touching the zone: the gaps a filler could close), drops
# (drop crossings touching it).
# Crossing record (crossings()): a, b, kind, row ("" unless ride), links; a ride and a drop run
# from a to b, a walk is listed with a < b.
# Anchor record (anchors()): zone, name, cost (the zone's d_spawn), d_landmark, on_route (the zone
# holds a line or warden node), viable (door_nodes at least ANCHOR_MIN_DOOR_NODES), door_nodes,
# rank (1 for the costliest viable off-route anchor, 0 for an anchor that is on the route or has
# too few door nodes).

const Stamps := preload("res://src/world/park/park_stamps.gd")

const SCHEMA := "scrapkeep-park-graph/1"
const MAGIC := "SKPG"
const VERSION := 2
const MIN_VERSION := 1

const HALF_M := 800.0
const STEP_M := 8.0
const LATTICE := 4
const SIDE := 201

const OPEN := 1
const LINE := 2
const GUARDED := 4
const WARDEN := 8
const DOOR_OK := 16
const SIGHT_OK := 32
const UNDER := 64
const DECK := 128
# Zones (SQ13), start values.
const ZONE_MIN_LINKS := 2
const ZONE_BACKGROUND_SHARE := 0.5
const ZONE_FRAGMENT_NODES := 16
const ANCHOR_MIN_DOOR_NODES := 16
const FLAG_NAMES := {OPEN: "open", LINE: "line", GUARDED: "guarded", WARDEN: "warden",
	DOOR_OK: "door_ok", SIGHT_OK: "sight_ok", UNDER: "under", DECK: "deck"}

var px := PackedFloat32Array()
var py := PackedFloat32Array()
var pz := PackedFloat32Array()
var node_flags := PackedInt32Array()
var node_rows := PackedInt32Array()
var names := PackedStringArray()
var off := PackedInt32Array()
var to := PackedInt32Array()
var length := PackedFloat32Array()
var ride := PackedInt32Array()
var roff := PackedInt32Array()
var rto := PackedInt32Array()
var rlength := PackedFloat32Array()
var d_land := PackedFloat32Array()
var d_from := PackedFloat32Array()
var spawn_node := -1
var beacon_node := -1
var node_zone := PackedInt32Array()
var zone_table := []
var crossing_table := []
var _members := []
# The search heap, (distance, node) pairs, ordered by distance then node.
var _hd := PackedFloat32Array()
var _hn := PackedInt32Array()


static func read(path: String):
	var file := FileAccess.open_compressed(path, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if file == null:
		return null
	var bytes := PackedByteArray()
	while not file.eof_reached():
		var chunk := file.get_buffer(1 << 20)
		if chunk.is_empty():
			break
		bytes.append_array(chunk)
	file.close()
	return from_bytes(bytes)


static func from_bytes(bytes: PackedByteArray):
	var s := StreamPeerBuffer.new()
	s.data_array = bytes
	if bytes.size() < 24 or s.get_data(4)[1].get_string_from_ascii() != MAGIC:
		return null
	var version := s.get_u32()
	if version < MIN_VERSION or version > VERSION:
		return null
	var g = new()
	var nodes := s.get_u32()
	var edges := s.get_u32()
	var name_count := s.get_u32()
	g.spawn_node = s.get_32()
	g.beacon_node = s.get_32()
	for k in name_count:
		g.names.append(s.get_data(s.get_u32())[1].get_string_from_utf8())
	g.px = _floats(s, nodes)
	g.py = _floats(s, nodes)
	g.pz = _floats(s, nodes)
	g.node_flags = _ints(s, nodes)
	g.node_rows = _ints(s, nodes)
	g.d_land = _floats(s, nodes)
	g.d_from = _floats(s, nodes)
	g.off = _ints(s, nodes + 1)
	g.to = _ints(s, edges)
	g.length = _floats(s, edges)
	g.ride = _ints(s, edges)
	if g.off[nodes] != edges:
		return null
	if version >= 2:
		g.node_zone = _ints(s, nodes)
		var blob: String = s.get_data(s.get_u32())[1].get_string_from_utf8()
		var parsed = JSON.parse_string(blob)
		if not parsed is Dictionary:
			return null
		g.zone_table = _normalize_zones(parsed.get("zones", []))
		g.crossing_table = _normalize_crossings(parsed.get("crossings", []))
	g.reverse()
	return g


func to_bytes() -> PackedByteArray:
	var s := StreamPeerBuffer.new()
	s.big_endian = false
	s.put_data(MAGIC.to_ascii_buffer())
	s.put_u32(VERSION)
	s.put_u32(px.size())
	s.put_u32(to.size())
	s.put_u32(names.size())
	s.put_32(spawn_node)
	s.put_32(beacon_node)
	for name in names:
		var b := name.to_utf8_buffer()
		s.put_u32(b.size())
		s.put_data(b)
	s.put_data(px.to_byte_array())
	s.put_data(py.to_byte_array())
	s.put_data(pz.to_byte_array())
	s.put_data(node_flags.to_byte_array())
	s.put_data(node_rows.to_byte_array())
	s.put_data(d_land.to_byte_array())
	s.put_data(d_from.to_byte_array())
	s.put_data(off.to_byte_array())
	s.put_data(to.to_byte_array())
	s.put_data(length.to_byte_array())
	s.put_data(ride.to_byte_array())
	s.put_data(node_zone.to_byte_array())
	var blob := JSON.stringify({"zones": zone_table, "crossings": crossing_table}, "", true).to_utf8_buffer()
	s.put_u32(blob.size())
	s.put_data(blob)
	return s.data_array


# JSON reads every number as a float: the zone tables hold ints, restored here.
static func _normalize_zones(raw: Array) -> Array:
	var out := []
	for z in raw:
		var r: Dictionary = z.duplicate()
		for key in ["id", "nodes", "door_ok", "degree", "openings", "drops"]:
			r[key] = int(r[key])
		for key in ["entrances", "exits"]:
			var ids := []
			for k in r[key]:
				ids.append(int(k))
			r[key] = ids
		out.append(r)
	return out


static func _normalize_crossings(raw: Array) -> Array:
	var out := []
	for c in raw:
		var r: Dictionary = c.duplicate()
		for key in ["a", "b", "links"]:
			r[key] = int(r[key])
		out.append(r)
	return out


static func _floats(s: StreamPeerBuffer, n: int) -> PackedFloat32Array:
	return s.get_data(4 * n)[1].to_float32_array()


static func _ints(s: StreamPeerBuffer, n: int) -> PackedInt32Array:
	return s.get_data(4 * n)[1].to_int32_array()


# Builds the reverse CSR from the forward one (stable: sources in node order).
func reverse() -> void:
	var n := px.size()
	roff = PackedInt32Array()
	roff.resize(n + 1)
	for e in to.size():
		roff[to[e] + 1] += 1
	for k in n:
		roff[k + 1] += roff[k]
	var fill := roff.slice(0, n)
	rto = PackedInt32Array()
	rto.resize(to.size())
	rlength = PackedFloat32Array()
	rlength.resize(to.size())
	for a in n:
		for e in range(off[a], off[a + 1]):
			var b := to[e]
			rto[fill[b]] = a
			rlength[fill[b]] = length[e]
			fill[b] += 1


func node_count() -> int:
	return px.size()


func edge_count() -> int:
	return to.size()


func position(node: int) -> Vector3:
	return Vector3(px[node], py[node], pz[node])


func flags(node: int) -> int:
	return node_flags[node]


func node_row(node: int) -> String:
	return "" if node_rows[node] < 0 else names[node_rows[node]]


func flag_names(node: int) -> PackedStringArray:
	var out := PackedStringArray()
	for bit in [OPEN, LINE, GUARDED, WARDEN, DOOR_OK, SIGHT_OK, UNDER, DECK]:
		if node_flags[node] & bit != 0:
			out.append(FLAG_NAMES[bit])
	return out


# --- Zones (SQ13) ---

func zones() -> Array:
	return zone_table


func crossings() -> Array:
	return crossing_table


func zone_count() -> int:
	return zone_table.size()


# The zone of a node, -1 when the file has no zones (a version 1 graph).
func zone_of(node: int) -> int:
	return node_zone[node] if node < node_zone.size() else -1


# The id of the zone with this name, -1 for none.
func zone_named(zone_name: String) -> int:
	for z in zone_table:
		if z["name"] == zone_name:
			return z["id"]
	return -1


# The nodes of a zone in node order.
func zone_nodes(zone: int) -> PackedInt32Array:
	if _members.is_empty():
		for k in zone_table.size():
			_members.append(PackedInt32Array())
		for n in node_zone.size():
			if node_zone[n] >= 0:
				_members[node_zone[n]].append(n)
	return _members[zone]


# The door_ok nodes of a zone, in node order.
func zone_door_nodes(zone: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in zone_nodes(zone):
		if node_flags[n] & DOOR_OK != 0:
			out.append(n)
	return out


# Every zone of degree 1 that the spawn reaches, the costliest (greatest d_spawn) first, ties to
# the lower zone id. rank counts the off-route anchors with a door_ok node from 1; an anchor on
# the route or without a door has rank 0.
func anchors() -> Array:
	var out := []
	for z in zone_table:
		if z["degree"] != 1 or z["d_spawn"] < 0.0:
			continue
		out.append({"zone": z["id"], "name": z["name"], "cost": z["d_spawn"], "d_landmark": z["d_landmark"],
			"on_route": z["line"] or z["warden"], "viable": z["door_ok"] >= ANCHOR_MIN_DOOR_NODES, "door_nodes": z["door_ok"], "rank": 0})
	out.sort_custom(func(a, b): return a["cost"] > b["cost"] or (a["cost"] == b["cost"] and a["zone"] < b["zone"]))
	var rank := 0
	for a in out:
		if not a["on_route"] and a["viable"]:
			rank += 1
			a["rank"] = rank
	return out


# The ground lattice index under (x, z), clamped to the square.
static func lattice_index(x: float, z: float) -> int:
	var i := clampi(roundi((x + HALF_M) / STEP_M), 0, SIDE - 1)
	var j := clampi(roundi((z + HALF_M) / STEP_M), 0, SIDE - 1)
	return j * SIDE + i


# A Vector2 is a point on the ground plane: the ground (or tunnel floor) node under it. A
# Vector3 is a point in space: the nearest node of any kind, decks included.
func nearest(at) -> int:
	if at is Vector2:
		return lattice_index(at.x, at.y)
	var p: Vector3 = at
	var best := lattice_index(p.x, p.z)
	var best_d := p.distance_squared_to(position(best))
	for n in range(SIDE * SIDE, px.size()):
		var d := p.distance_squared_to(Vector3(px[n], py[n], pz[n]))
		if d < best_d:
			best_d = d
			best = n
	# Ground nodes round the lattice point under p can be nearer in 3D on a slope.
	var c := lattice_index(p.x, p.z)
	var ci := c % SIDE
	var cj := c / SIDE
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var i := ci + di
			var j := cj + dj
			if i < 0 or j < 0 or i >= SIDE or j >= SIDE:
				continue
			var n := j * SIDE + i
			var d := p.distance_squared_to(position(n))
			if d < best_d or (d == best_d and n < best):
				best_d = d
				best = n
	return best


# The node of `nodes` nearest p in 3D; ties go to the lower index. -1 for an empty set.
func nearest_in(nodes: PackedInt32Array, p: Vector3) -> int:
	var best := -1
	var best_d := INF
	for n in nodes:
		var d := p.distance_squared_to(position(n))
		if d < best_d or (d == best_d and n < best):
			best_d = d
			best = n
	return best


func _node(at) -> int:
	if at is int:
		return at
	return nearest(at)


func path_m(a, b) -> float:
	var src := _node(a)
	var dst := _node(b)
	var dist := search(PackedInt32Array([src]), false, INF, dst)
	return dist[dst]


func d_landmark(at) -> float:
	return d_land[_node(at)]


func d_spawn(at) -> float:
	return d_from[_node(at)]


func d_landmark_node(node: int) -> float:
	return d_land[node]


func d_spawn_node(node: int) -> float:
	return d_from[node]


# Dijkstra from every source at 0. reverse walks edges backwards, so the result is the distance
# TO the sources. Stops past cutoff, or once stop_at is settled. Ties settle the lower node
# first, so the result never depends on insertion order.
func search(sources: PackedInt32Array, reverse := false, cutoff := INF, stop_at := -1) -> PackedFloat32Array:
	var n := px.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	_hd = PackedFloat32Array()
	_hn = PackedInt32Array()
	for s in sources:
		if dist[s] > 0.0:
			dist[s] = 0.0
			_push(0.0, s)
	var o := roff if reverse else off
	var e_to := rto if reverse else to
	var e_len := rlength if reverse else length
	var rounded := PackedFloat32Array([0.0])
	while not _hn.is_empty():
		var d := _hd[0]
		var a := _hn[0]
		_pop()
		if d > dist[a]:
			continue
		if a == stop_at or d > cutoff:
			break
		for e in range(o[a], o[a + 1]):
			var b := e_to[e]
			rounded[0] = d + e_len[e]
			var nd := rounded[0]
			if nd < dist[b]:
				dist[b] = nd
				_push(nd, b)
	if cutoff < INF:
		for k in n:
			if dist[k] > cutoff:
				dist[k] = INF
	return dist


# Dijkstra that also keeps each node's predecessor, for the line path.
func search_prev(source: int) -> Dictionary:
	var n := px.size()
	var dist := PackedFloat32Array()
	dist.resize(n)
	dist.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	_hd = PackedFloat32Array()
	_hn = PackedInt32Array()
	dist[source] = 0.0
	_push(0.0, source)
	var rounded := PackedFloat32Array([0.0])
	while not _hn.is_empty():
		var d := _hd[0]
		var a := _hn[0]
		_pop()
		if d > dist[a]:
			continue
		for e in range(off[a], off[a + 1]):
			var b := to[e]
			rounded[0] = d + length[e]
			var nd := rounded[0]
			if nd < dist[b] or (nd == dist[b] and a < prev[b]):
				dist[b] = nd
				prev[b] = a
				_push(nd, b)
	return {"dist": dist, "prev": prev}


# Every node reachable from the sources, one byte per node.
func reach(sources: PackedInt32Array) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(px.size())
	var stack := PackedInt32Array()
	for s in sources:
		if seen[s] == 0:
			seen[s] = 1
			stack.append(s)
	while not stack.is_empty():
		var a := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		for e in range(off[a], off[a + 1]):
			var b := to[e]
			if seen[b] == 0:
				seen[b] = 1
				stack.append(b)
	return seen


static func _less(da: float, na: int, db: float, nb: int) -> bool:
	return da < db or (da == db and na < nb)


func _push(d: float, node: int) -> void:
	_hd.append(d)
	_hn.append(node)
	var k := _hd.size() - 1
	while k > 0:
		var p := (k - 1) >> 1
		if not _less(_hd[k], _hn[k], _hd[p], _hn[p]):
			break
		var td := _hd[k]
		_hd[k] = _hd[p]
		_hd[p] = td
		var tn := _hn[k]
		_hn[k] = _hn[p]
		_hn[p] = tn
		k = p


func _pop() -> void:
	var last := _hd.size() - 1
	_hd[0] = _hd[last]
	_hn[0] = _hn[last]
	_hd.resize(last)
	_hn.resize(last)
	var k := 0
	while true:
		var l := 2 * k + 1
		if l >= last:
			break
		var m := l
		if l + 1 < last and _less(_hd[l + 1], _hn[l + 1], _hd[l], _hn[l]):
			m = l + 1
		if not _less(_hd[m], _hn[m], _hd[k], _hn[k]):
			break
		var td := _hd[k]
		_hd[k] = _hd[m]
		_hd[m] = td
		var tn := _hn[k]
		_hn[k] = _hn[m]
		_hn[m] = tn
		k = m


# --- Footprints: which nodes stand for a park row, a disc or a box. ---

# A route as the place ids it passes: from, the via rows, to, with repeats collapsed.
static func route_sequence(route: Dictionary) -> PackedStringArray:
	var seq := PackedStringArray()
	for id in [route["from"]] + Array(route["via"]) + [route["to"]]:
		if seq.is_empty() or seq[seq.size() - 1] != String(id):
			seq.append(String(id))
	return seq


# Ground lattice nodes in the axis-aligned box lo..hi.
func box_nodes(lo: Vector2, hi: Vector2) -> PackedInt32Array:
	var out := PackedInt32Array()
	if lo.x > HALF_M or lo.y > HALF_M or hi.x < -HALF_M or hi.y < -HALF_M:
		return out
	var i0 := clampi(ceili((lo.x + HALF_M) / STEP_M), 0, SIDE - 1)
	var i1 := clampi(floori((hi.x + HALF_M) / STEP_M), 0, SIDE - 1)
	var j0 := clampi(ceili((lo.y + HALF_M) / STEP_M), 0, SIDE - 1)
	var j1 := clampi(floori((hi.y + HALF_M) / STEP_M), 0, SIDE - 1)
	for j in range(j0, j1 + 1):
		for i in range(i0, i1 + 1):
			out.append(j * SIDE + i)
	return out


# Ground lattice nodes within radius of p, and always the one under p, in node order.
func disc_nodes(p: Vector2, radius: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	for o in box_nodes(p - Vector2(radius, radius), p + Vector2(radius, radius)):
		if Vector2(px[o], pz[o]).distance_to(p) <= radius:
			out.append(o)
	var below := lattice_index(p.x, p.y)
	if not out.has(below):
		out.append(below)
	out.sort()
	return out


# Ground lattice nodes inside a park_stamps.gd frame's footprint.
func inside_nodes(f: Dictionary) -> PackedInt32Array:
	var box := Stamps.bounds(f)
	var out := PackedInt32Array()
	for o in box_nodes(Vector2(box[0], box[1]), Vector2(box[2], box[3])):
		if Stamps.inside(f, px[o], pz[o]):
			out.append(o)
	return out


# A park row's nodes: its deck (count nodes from start) when it has y, else the ground lattice
# nodes inside its footprint, else the node under its centre.
func footprint_nodes(row: Dictionary, start: int, count: int) -> PackedInt32Array:
	if row["y"] != null:
		var deck := PackedInt32Array()
		for o in range(start, start + count):
			deck.append(o)
		return deck
	var out := inside_nodes(Stamps.frame(row))
	if out.is_empty():
		out.append(lattice_index(float(row["at"][0]), float(row["at"][1])))
	return out


# The node a point on a site row stands on: the site's deck when it has y, else the ground.
func site_node(park: Dictionary, row_index: Dictionary, deck_start: PackedInt32Array, deck_count: PackedInt32Array, p: Vector2, site: String) -> int:
	if row_index.has(site):
		var k: int = row_index[site]
		var row: Dictionary = park["park_rows"][k]
		if row["y"] != null and deck_count[k] > 0:
			var deck := PackedInt32Array()
			for o in range(deck_start[k], deck_start[k] + deck_count[k]):
				deck.append(o)
			return nearest_in(deck, Vector3(p.x, float(row["y"]), p.y))
	return lattice_index(p.x, p.y)
