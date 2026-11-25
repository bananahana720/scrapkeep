extends RefCounted


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


func zones() -> Array:
	return zone_table


func crossings() -> Array:
	return crossing_table


func zone_count() -> int:
	return zone_table.size()


func zone_of(node: int) -> int:
	return node_zone[node] if node < node_zone.size() else -1


func zone_named(zone_name: String) -> int:
	for z in zone_table:
		if z["name"] == zone_name:
			return z["id"]
	return -1


func zone_nodes(zone: int) -> PackedInt32Array:
	if _members.is_empty():
		for k in zone_table.size():
			_members.append(PackedInt32Array())
		for n in node_zone.size():
			if node_zone[n] >= 0:
				_members[node_zone[n]].append(n)
	return _members[zone]


func zone_door_nodes(zone: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n in zone_nodes(zone):
		if node_flags[n] & DOOR_OK != 0:
			out.append(n)
	return out


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


static func lattice_index(x: float, z: float) -> int:
	var i := clampi(roundi((x + HALF_M) / STEP_M), 0, SIDE - 1)
	var j := clampi(roundi((z + HALF_M) / STEP_M), 0, SIDE - 1)
	return j * SIDE + i


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


static func route_sequence(route: Dictionary) -> PackedStringArray:
	var seq := PackedStringArray()
	for id in [route["from"]] + Array(route["via"]) + [route["to"]]:
		if seq.is_empty() or seq[seq.size() - 1] != String(id):
			seq.append(String(id))
	return seq


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


func inside_nodes(f: Dictionary) -> PackedInt32Array:
	var box := Stamps.bounds(f)
	var out := PackedInt32Array()
	for o in box_nodes(Vector2(box[0], box[1]), Vector2(box[2], box[3])):
		if Stamps.inside(f, px[o], pz[o]):
			out.append(o)
	return out


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
