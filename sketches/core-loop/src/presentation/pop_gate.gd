extends RefCounted

const Density := preload("res://src/presentation/density.gd")

var ring := PackedFloat64Array([-1.0e9, -1.0e9, -1.0e9])
var oldest := 0
var pending: Array = []
const EMITTED_KEEP := 64
var emitted: Array = []

func add(clock: float, at: Vector3, reach: float) -> void:
	var nearest: Dictionary = {}
	var best := INF
	for cluster in pending:
		var d: float = (cluster["sum"] / cluster["n"]).distance_to(at)
		if d < best:
			best = d
			nearest = cluster
	if not nearest.is_empty() and (best <= reach or pending.size() >= Density.KILL_POPS_PER_WINDOW):
		nearest["sum"] += at
		nearest["n"] += 1
		return
	pending.append({"sum": at, "n": 1, "since": clock})

func ready(clock: float, wait: float) -> Array:
	var out: Array = []
	while not pending.is_empty() and clock - ring[oldest] >= Density.KILL_POP_WINDOW \
			and clock - float(pending[0]["since"]) >= wait:
		var cluster: Dictionary = pending.pop_front()
		ring[oldest] = clock
		oldest = (oldest + 1) % ring.size()
		cluster["at"] = cluster["sum"] / cluster["n"]
		cluster["scale"] = Density.pop_scale(cluster["n"])
		emitted.append([clock, cluster["n"], cluster["scale"]])
		if emitted.size() > EMITTED_KEEP:
			emitted.pop_front()
		out.append(cluster)
	return out

func clear() -> void:
	pending.clear()
	emitted.clear()
	ring = PackedFloat64Array([-1.0e9, -1.0e9, -1.0e9])
	oldest = 0
