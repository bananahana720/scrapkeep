extends SceneTree

const T := preload("res://tests/support/t.gd")
const Graph := preload("res://src/world/park/park_graph.gd")
const LAYERS := 24

var t := T.new("park_graph_precision_test")


class CountedGraph:
	extends "res://src/world/park/park_graph.gd"
	var pops := 0
	var limit := 0
	var exhausted := false

	func _pop() -> void:
		super._pop()
		pops += 1
		if pops > limit:
			exhausted = true
			_hn.clear()
			_hd.clear()
			off.fill(0)
			roff.fill(0)


func _initialize() -> void:
	var edge := PackedFloat32Array([0.1])[0]
	var exact := 1.0 + edge
	t.check("fixture crosses float32 rounding", exact < _f32(exact))
	for backwards in [false, true]:
		var g := _graph()
		var source := g.node_count() - 1 if backwards else 0
		var want := _reference(g, source, backwards)
		var got := g.search(PackedInt32Array([source]), backwards)
		t.check("search bounded reverse=%s" % backwards, not g.exhausted,
			"%d pops, limit %d" % [g.pops, g.limit])
		t.eq("search distances reverse=%s" % backwards, got, want["dist"])
	var g := _graph()
	var want := _reference(g, 0, false)
	var got := g.search_prev(0)
	t.check("search_prev bounded", not g.exhausted, "%d pops, limit %d" % [g.pops, g.limit])
	t.eq("search_prev distances", got["dist"], want["dist"])
	t.eq("search_prev lower-index ties", got["prev"], want["prev"])
	quit(t.verdict())


func _graph() -> CountedGraph:
	var g := CountedGraph.new()
	g.px.resize(1 + 2 * LAYERS)
	g.off.append(0)
	for a in g.node_count():
		var layer := -1 if a == 0 else (a - 1) / 2
		if layer + 1 < LAYERS:
			# Higher-index parent is inserted first; predecessor ties must still prefer lower.
			for b in [2 + 2 * (layer + 1), 1 + 2 * (layer + 1)]:
				g.to.append(b)
				g.length.append(1.0 if a == 0 else 0.1)
		g.off.append(g.to.size())
	g.reverse()
	g.limit = 4 * g.edge_count()
	return g


func _reference(g, source: int, backwards: bool) -> Dictionary:
	var dist := PackedFloat32Array()
	dist.resize(g.node_count())
	dist.fill(INF)
	dist[source] = 0.0
	var prev := PackedInt32Array()
	prev.resize(g.node_count())
	prev.fill(-1)
	var settled := PackedByteArray()
	settled.resize(g.node_count())
	var offsets: PackedInt32Array = g.roff if backwards else g.off
	var targets: PackedInt32Array = g.rto if backwards else g.to
	var lengths: PackedFloat32Array = g.rlength if backwards else g.length
	for step in g.node_count():
		var a := -1
		for n in g.node_count():
			if settled[n] == 0 and dist[n] < INF and (a < 0 or dist[n] < dist[a]):
				a = n
		if a < 0:
			break
		settled[a] = 1
		for e in range(offsets[a], offsets[a + 1]):
			var b := targets[e]
			var candidate := _f32(dist[a] + lengths[e])
			if candidate < dist[b] or (candidate == dist[b] and a < prev[b]):
				dist[b] = candidate
				prev[b] = a
	return {"dist": dist, "prev": prev}


func _f32(value: float) -> float:
	return PackedFloat32Array([value])[0]
