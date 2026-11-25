extends RefCounted


const SKEE_STAT := "camp_skee_best"
const GHOST_HZ := 10
const GHOST_MAX_SAMPLES := 1200

var profile
var _mem := {}


func _init(profile_ref = null) -> void:
	profile = profile_ref


func _doc() -> Dictionary:
	if profile != null and profile.has_method("camp"):
		return profile.camp()
	return _mem.duplicate(true)


func _store(doc: Dictionary) -> void:
	if profile != null and profile.has_method("set_camp"):
		profile.set_camp(doc)
		if profile.can_save and not profile.save():
			push_warning("camp: record not saved: %s" % profile.last_error)
	else:
		_mem = doc.duplicate(true)


func skee_best() -> int:
	var best := int(_doc().get("skee_best", 0))
	if profile != null and profile.has_method("stat"):
		best = maxi(best, int(profile.stat(SKEE_STAT)))
	return best


func submit_skee(score: int) -> bool:
	if score <= skee_best():
		return false
	var doc := _doc()
	doc["skee_best"] = score
	if profile != null and not profile.has_method("set_camp") and profile.has_method("set_stat"):
		profile.set_stat(SKEE_STAT, float(score))
		if profile.can_save and not profile.save():
			push_warning("camp: record not saved: %s" % profile.last_error)
	else:
		_store(doc)
	return true


func ring_best(pilot: String) -> int:
	var ring = _doc().get("ring", {})
	return int(ring.get(pilot, 0)) if ring is Dictionary else 0


func submit_ring(pilot: String, count: int) -> bool:
	if count <= ring_best(pilot):
		return false
	var doc := _doc()
	var ring = doc.get("ring", {})
	if not ring is Dictionary:
		ring = {}
	ring[pilot] = count
	doc["ring"] = ring
	_store(doc)
	return true


func trial_best_ms() -> int:
	return int(_doc().get("trial", {}).get("best_ms", 0))


func submit_trial(ms: int, points: PackedVector3Array) -> bool:
	var best := trial_best_ms()
	if ms <= 0 or (best > 0 and ms >= best):
		return false
	var doc := _doc()
	var trial := {"best_ms": ms}
	var ghost := encode_ghost(points)
	if not ghost.is_empty():
		trial["ghost"] = ghost
	doc["trial"] = trial
	_store(doc)
	return true


func ghost() -> PackedVector3Array:
	return decode_ghost(_doc().get("trial", {}).get("ghost", {}))


static func encode_ghost(points: PackedVector3Array) -> Dictionary:
	if points.size() < 2 or points.size() > GHOST_MAX_SAMPLES:
		return {}
	var first := _cm(points[0])
	var deltas := PackedStringArray()
	var prev := first
	for i in range(1, points.size()):
		var cur := _cm(points[i])
		deltas.append(str(cur.x - prev.x))
		deltas.append(str(cur.y - prev.y))
		deltas.append(str(cur.z - prev.z))
		prev = cur
	return {"hz": GHOST_HZ, "p0": [first.x, first.y, first.z], "d": ",".join(deltas)}


static func decode_ghost(doc) -> PackedVector3Array:
	var out := PackedVector3Array()
	if typeof(doc) != TYPE_DICTIONARY or not doc.has("p0") or not doc.has("d"):
		return out
	var p0 = doc["p0"]
	if typeof(p0) != TYPE_ARRAY or p0.size() != 3 or typeof(doc["d"]) != TYPE_STRING:
		return out
	for v in p0:
		if not (v is int or v is float):
			return out
	var d: PackedStringArray = String(doc["d"]).split(",", false)
	if d.size() % 3 != 0:
		return out
	if d.size() / 3 + 1 > GHOST_MAX_SAMPLES:
		return out
	var cur := Vector3i(int(p0[0]), int(p0[1]), int(p0[2]))
	out.append(Vector3(cur) * 0.01)
	for i in range(0, d.size(), 3):
		cur += Vector3i(d[i].to_int(), d[i + 1].to_int(), d[i + 2].to_int())
		out.append(Vector3(cur) * 0.01)
	return out


static func _cm(v: Vector3) -> Vector3i:
	return Vector3i(roundi(v.x * 100.0), roundi(v.y * 100.0), roundi(v.z * 100.0))
