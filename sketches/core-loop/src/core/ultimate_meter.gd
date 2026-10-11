extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The ultimate meter (design-v3/SKILL-BAR.md section 4), pure rules like chain.gd. Points come
# from play by source; the cap is 100 with the overflow lost; there is no decay and taking
# damage drains nothing. Weapon hits pay slowly: never more than WEAPON_RATE_CAP points a
# second over time (a budget that refills at that rate, holding at most WEAPON_BURST), so the
# hold-fire camper is the slowest road. Only src/combat/ultimate.gd writes it; the HUD and bots
# read it through AbilityState.ultimate().

const CAP := 100.0
# Points per unit of each source. A per-second source (fast, blazing) is added by tick().
const WEIGHTS := {
	"weapon": 0.25, "contact": 2.0, "smash": 5.0, "chain_link": 2.0, "near_miss": 4.0,
	"kill": 1.0, "stagger": 8.0, "shatter": 12.0, "fast": 0.5, "blazing": 1.2,
}
const WEAPON_RATE_CAP := 0.4
# The most weapon points that can wait in the budget: two fresh hits, then the rate holds.
const WEAPON_BURST := 0.5

var value := 0.0
# Points actually paid, by source, this run.
var sources := {}
# True while a set piece rides: nothing fills the meter.
var locked := false
var _entry := 0.0
var _weapon_budget := WEAPON_BURST


# Adds a source's weight times amount and returns the points actually paid (0 when locked,
# full, unknown, or a weapon hit past the rate limit).
func add(source: String, amount := 1.0) -> float:
	if locked or not WEIGHTS.has(source) or amount <= 0.0:
		return 0.0
	var points: float = float(WEIGHTS[source]) * amount
	if source == "weapon":
		points = minf(points, _weapon_budget)
		_weapon_budget -= points
	var paid := clampf(points, 0.0, CAP - value)
	if paid <= 0.0:
		return 0.0
	value += paid
	sources[source] = float(sources.get(source, 0.0)) + paid
	return paid


# Time passes: the weapon budget refills, and speed pays by tier.
func tick(delta: float, speed_tier: int) -> void:
	_weapon_budget = minf(WEAPON_BURST, _weapon_budget + WEAPON_RATE_CAP * delta)
	if speed_tier >= SpeedTier.BLAZING:
		add("blazing", delta)
	elif speed_tier == SpeedTier.FAST:
		add("fast", delta)


func full() -> bool:
	return value >= CAP


func fraction() -> float:
	return clampf(value / CAP, 0.0, 1.0)


# Empties a full meter. False, and nothing spent, below full.
func spend() -> bool:
	if not full():
		return false
	value = 0.0
	return true


func refund(points: float) -> void:
	value = clampf(value + points, 0.0, CAP)


# The value a retry of this stage starts from.
func mark_entry() -> void:
	_entry = value


func restore_entry() -> void:
	value = _entry
	locked = false


# A new run starts empty (the slot is on the bar from the drop, the first one is earned).
func reset() -> void:
	value = 0.0
	sources = {}
	locked = false
	_entry = 0.0
	_weapon_budget = WEAPON_BURST
