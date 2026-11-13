extends RefCounted

# The harpoon chain (design-v3/HOOK-CHAIN.md): a run of bites with no ground contact between
# them. A bite on an enemy is a link (+1 combo); a bite on a surface is a pivot (+0) that keeps
# the chain alive, and two pivots with no enemy between them end it. A smash landing on a
# chained enemy pays the combo as a damage multiplier. The player owns the one instance and is
# the only writer; the HUD, the body, the sound, the run log and the codex read it.
#
# Pure state: every mutator returns the events it caused as [{id, cause}] and the player
# publishes them, so the rule is testable without a scene.

const LINK := "chain_link"
const PIVOT := "chain_pivot"
const END := "chain_end"
const MISS := "chain_miss"

# The multiplier a combo pays: 1 + PER_LINK for each link beyond the first, counted up to
# COMBO_CAP links. A combo of 1 pays x1.0, exactly the game without a chain.
const PER_LINK := 0.3
const COMBO_CAP := 6
# The scrap a paid chain bursts out at its landing, by combo (W1-74): nothing below 3, then a
# step per link up to COMBO_CAP. A combo of 3 pays about one kill; a full chain about three.
const BURST := {}
# A let-go keeps the chain this long, counted in airtime.
const GRACE := 0.8
# A dry fire locks the harpoon this long.
const MISS_COOLDOWN := 0.6

var combo := 0
var links := 0
var pivots := 0
var grace_left := 0.0
# The harpoon is refused while this runs.
var miss_left := 0.0
# Every chain that ended this run: {links, pivots, combo, paid, cause}.
var finished: Array = []
var best_combo := 0
var misses := 0

var _active := false
var _pivot_run := 0
# True once the ball has left the ground since the last link; ground contact ends the
# chain only then, so a bite fired from the floor does not end its own chain.
var _airborne := false


func active() -> bool:
	return _active


# Damage and knock multiplier for a smash landing now.
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


# The line ended without a landing: the chain waits GRACE seconds of airtime for the next bite.
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


# A press the harpoon could not answer: ends the chain and costs the cooldown.
func dry_fire() -> Array:
	var out: Array = []
	miss_left = MISS_COOLDOWN
	misses += 1
	if _active:
		out.append_array(_end("dry_fire", false))
	out.append({"id": MISS, "cause": ""})
	return out


# A smash landed: the multiplier it pays, and the chain ends paid.
func pay() -> Dictionary:
	var mult := multiplier()
	var events := _end("paid", true) if _active else []
	return {"mult": mult, "events": events}


# The combo the last paid chain ended at (a smash's landing), or 0 when the last end was unpaid.
func last_paid_combo() -> int:
	if finished.is_empty() or not finished.back().get("paid", false):
		return 0
	return int(finished.back().get("combo", 0))


# The scrap the last end pays as a burst: 0 unless it was paid at a combo of 3 or more.
func last_burst() -> int:
	return int(BURST.get(mini(last_paid_combo(), COMBO_CAP), 0))


# A new run starts clean.
func reset() -> void:
	combo = 0
	links = 0
	pivots = 0
	grace_left = 0.0
	miss_left = 0.0
	finished.clear()
	best_combo = 0
	misses = 0
	_active = false
	_pivot_run = 0
	_airborne = false


# A respawn drops a standing chain without a record.
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
