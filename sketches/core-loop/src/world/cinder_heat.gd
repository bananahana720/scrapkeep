extends RefCounted


const GRACE_S := 1.5
const GLOW_FROM_S := 0.6
const BURN_HP_PER_S := 4.0
const TICK_S := 0.5
const FLOOR_HP := 1.0
const SOURCE := "cinder_floor"
const GLOW_FACT := "cinder_glow"
const BURN_FACT := "cinder_burn"
const COOL_FACT := "cinder_cooled"

var dwell := 0.0
var burned := 0.0
var _pulse := 0.0
var _glowing := false


func reset() -> void:
	dwell = 0.0
	_pulse = 0.0
	_glowing = false


func struck() -> void:
	reset()


func step(delta: float, on_cinder: bool, hp: float) -> Dictionary:
	var out := {"glow": 0.0, "damage": 0.0, "fact": ""}
	if not on_cinder:
		if _glowing:
			out["fact"] = COOL_FACT
		reset()
		return out
	dwell += delta
	out["glow"] = clampf((dwell - GLOW_FROM_S) / maxf(GRACE_S - GLOW_FROM_S, 0.001), 0.0, 1.0)
	if dwell >= GLOW_FROM_S and not _glowing:
		_glowing = true
		out["fact"] = GLOW_FACT
	if dwell < GRACE_S:
		return out
	if _pulse == 0.0:
		out["fact"] = BURN_FACT
	_pulse += delta
	if _pulse >= TICK_S:
		_pulse -= TICK_S
		var amount := minf(BURN_HP_PER_S * TICK_S, maxf(0.0, hp - FLOOR_HP))
		out["damage"] = amount
		burned += amount
	return out
