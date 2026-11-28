extends SceneTree

const WearTrail := preload("res://src/combat/wear_trail.gd")
const Effects := preload("res://src/combat/effects.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")
const T := preload("res://tests/support/t.gd")

# Run and Gun's wear trail obeys Reduce flashes (red team, wave 16 close, WEAR-TRAIL.md). It sits
# outside src/combat/actives, so active_flashes_test never reads it. A bare trail with one patch
# runs its LIFE at 60 Hz, off then on, and the alpha combat.effects would draw each ring and arc
# at is read through the drawer's own functions. Off: the pulse runs every PULSE and peaks above
# the information share. On: no mark draws above INFO_SHARE of full and the pulse is no faster
# than FlashGuard's 3 Hz. Evidence limit: drawn vertex alpha in a headless run, not a capture.

const TICK := 1.0 / 60.0
const EPS := 0.001


class Ctx:
	var run = null


class LiveTrail:
	extends "res://src/combat/wear_trail.gd"

	func active() -> bool:
		return true


var _t := T.new("wear_trail_flashes_test")


func _initialize() -> void:
	var off := _patch_life(false)
	var on := _patch_life(true)
	FlashGuard.on = false
	_t.check("01 off: the pulse runs every PULSE and peaks above the information share",
		off["rings"] >= int(WearTrail.LIFE / WearTrail.PULSE) and off["peak"] > FlashGuard.INFO_SHARE + EPS, str(off))
	_t.check("02 on: no ring or arc draws above the information share", on["peak"] <= FlashGuard.INFO_SHARE + EPS, str(on))
	_t.check("03 on: the pulse is no faster than 3 Hz", on["gap"] >= FlashGuard.MIN_PERIOD - TICK - EPS, str(on))
	quit(_t.verdict())


# One patch over its whole life: rings drawn, the brightest mark and the shortest gap between rings.
func _patch_life(reduce: bool) -> Dictionary:
	FlashGuard.on = reduce
	var fx := Effects.new()
	var trail := LiveTrail.new()
	trail.setup(Ctx.new(), fx, func(at: Vector3) -> Vector3: return at)
	trail.patches.append({"at": Vector3.ZERO, "age": 0.0, "pulse": 0.0})
	var times := []
	var clock := 0.0
	while not trail.patches.is_empty() or clock == 0.0:
		var before: int = fx._rings.size()
		trail.step(TICK, [])
		clock += TICK
		if fx._rings.size() > before:
			times.append(clock)
	trail._effects.arc(Vector3.ZERO, Vector3.ONE, trail._tone(1.0))
	var peak := 0.0
	for entry in fx._rings:
		entry["life"] = Effects.RING_LIFE
		peak = maxf(peak, Effects.ring_alpha(entry))
	for entry in fx._arcs:
		peak = maxf(peak, Effects.arc_alpha(entry))
	var gap := INF
	for i in range(1, times.size()):
		gap = minf(gap, times[i] - times[i - 1])
	fx.free()
	return {"rings": times.size(), "peak": snappedf(peak, 0.001), "gap": snappedf(gap, 0.001)}
