extends RefCounted

const LINK := "chain_link"
const PIVOT := "chain_pivot"
const END := "chain_end"
const MISS := "chain_miss"
const MAX_CHAINS_PER_PILOT := 1

const PER_LINK := 0.3
const COMBO_CAP := 6
const BURST := {3: 4, 4: 6, 5: 9, 6: 12}
const GRACE := 0.8
const MISS_COOLDOWN := 0.6

var combo := 0
var links := 0
var pivots := 0
var grace_left := 0.0
var miss_left := 0.0
var finished: Array = []
var best_combo := 0
var misses := 0
var mutations := {}

var _active := false
var _pivot_run := 0
var _airborne := false


func active() -> bool:
	return _active


func set_mutations(slots: Dictionary) -> void:
	mutations.clear()
	for slot in ["head", "line", "drive"]:
		if not slots.has(slot):
			continue
		var v: Variant = slots[slot]
		var mut_id := String(v["id"]) if v is Dictionary else String(v)
		if mut_id != "":
			mutations[slot] = mut_id


func active_mutations() -> Dictionary:
	return mutations.duplicate()


func snapshot() -> Dictionary:
	return {
		"active": _active,
		"combo": combo,
		"links": links,
		"pivots": pivots,
		"multiplier": multiplier(),
		"grace_left": grace_left,
		"miss_left": miss_left,
		"mutations": mutations.duplicate(),
	}


func multiplier() -> float:
	return 1.0 + PER_LINK * maxf(0.0, minf(float(combo), float(COMBO_CAP)) - 1.0)


func link(on_enemy: bool, grounded: bool) -> Array:
	var out: Array = []
	grace_left = 0.0
	if on_enemy:
		_active = true
		combo += 1
		links += 1
		_pivot_run = 0
		_airborne = not grounded
		best_combo = maxi(best_combo, combo)
		out.append({"id": LINK, "cause": ""})
		return out
	if _active and _pivot_run >= 1:
		out.append_array(_end("double_pivot", false))
		return out
	_active = true
	pivots += 1
	_pivot_run += 1
	_airborne = not grounded
	out.append({"id": PIVOT, "cause": ""})
	return out


func let_go() -> void:
	if _active:
		grace_left = GRACE


func tick(delta: float, grounded: bool, hooked: bool) -> Array:
	miss_left = maxf(0.0, miss_left - delta)
	if not _active:
		return []
	if grounded:
		if _airborne:
			return _end("ground", false)
		return []
	_airborne = true
	if not hooked and grace_left > 0.0:
		grace_left = maxf(0.0, grace_left - delta)
		if grace_left <= 0.0:
			return _end("grace", false)
	return []


func dry_fire() -> Array:
	var out: Array = []
	miss_left = MISS_COOLDOWN
	misses += 1
	if _active:
		out.append_array(_end("dry_fire", false))
	out.append({"id": MISS, "cause": ""})
	return out


func pay() -> Dictionary:
	var mult := multiplier()
	var events := _end("paid", true) if _active else []
	return {"mult": mult, "events": events}


func last_paid_combo() -> int:
	if finished.is_empty() or not finished.back().get("paid", false):
		return 0
	return int(finished.back().get("combo", 0))


func last_burst() -> int:
	return int(BURST.get(mini(last_paid_combo(), COMBO_CAP), 0))


func reset() -> void:
	combo = 0
	links = 0
	pivots = 0
	grace_left = 0.0
	miss_left = 0.0
	finished.clear()
	best_combo = 0
	misses = 0
	mutations.clear()
	_active = false
	_pivot_run = 0
	_airborne = false


func clear_active() -> void:
	combo = 0
	links = 0
	pivots = 0
	grace_left = 0.0
	miss_left = 0.0
	_active = false
	_pivot_run = 0
	_airborne = false


func _end(cause: String, paid: bool) -> Array:
	finished.append({"links": links, "pivots": pivots, "combo": combo, "paid": paid, "cause": cause})
	combo = 0
	links = 0
	pivots = 0
	grace_left = 0.0
	_active = false
	_pivot_run = 0
	_airborne = false
	return [{"id": END, "cause": cause}]
