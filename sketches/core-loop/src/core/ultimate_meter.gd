extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")

# The ultimate meter (design-v3/SKILL-BAR.md section 4), pure rules like chain.gd. Points come
# from play by source; the cap is 100 with the overflow lost; there is no decay and taking
# damage drains nothing. Weapon hits pay slowly: never more than WEAPON_RATE_CAP points a
# second over time (a budget that refills at that rate, holding at most WEAPON_BURST), and near
# misses the same way under NEAR_MISS_RATE_CAP and NEAR_MISS_BURST, so the hold-fire camper,
# who dodges a lot and chains nothing, is the slowest road. Only src/combat/ultimate.gd writes
# it; the HUD and bots read it through AbilityState.ultimate().

const CAP := 100.0
# Points per unit of each source. A per-second source (fast, blazing) is added by tick().
# A reel hit is a hull hit on a boss held in his reel (boss.gd, W1-61): Brindle's hits per reel
# are capped (boss_rules.gd REEL_HITS), so a full reel pays at most REEL_HITS times this.
const WEIGHTS := {
	"weapon": 0.25, "contact": 2.0, "smash": 5.0, "chain_link": 2.0, "near_miss": 4.0,
	"kill": 1.0, "stagger": 8.0, "shatter": 12.0, "fast": 0.5, "blazing": 1.2, "reel": 6.0,
}
const WEAPON_RATE_CAP := 0.4
# The most weapon points that can wait in the budget: two fresh hits, then the rate holds.
const WEAPON_BURST := 0.5
# 2026-10-11 (w13 B3b): near misses pay at most 0.05 points a second over time, holding one near
# miss (4.0). B4's camper filled in a median 41.1 s, 69 to 95 of its first 100 points from near misses.
const NEAR_MISS_RATE_CAP := 0.05
const NEAR_MISS_BURST := 4.0
# 2026-10-11 (PC-TARN ruling 2): contact budget from 32 round-2 pacing records;
# 0.14 points/s holding one contact predicts Tarn camper 228.09 s, completionist 88.12 s.
const CONTACT_RATE_CAP := 0.14
const CONTACT_BURST := 2.0
# 2026-10-11 (w13 B3b): a chain link on one enemy pays at most once per this many seconds.
const CHAIN_LINK_GAP := 1.0
# The rate-limited sources: [points per second the budget refills, the most it holds].
const RATE_LIMITS := {
	"weapon": [WEAPON_RATE_CAP, WEAPON_BURST],
	"near_miss": [NEAR_MISS_RATE_CAP, NEAR_MISS_BURST],
	"contact": [CONTACT_RATE_CAP, CONTACT_BURST],
}

var value := 0.0
# Points actually paid, by source, this run.
var sources := {}
# True while a set piece rides: nothing fills the meter.
var locked := false
var _entry := 0.0
# Points each rate-limited source may still pay now.
var _budgets := {}
# Meter time (tick's delta summed) and the meter time each enemy's last paid link came at.
var _clock := 0.0
var _linked_at := {}


func _init() -> void:
	_fill_budgets()


func _fill_budgets() -> void:
	for source in RATE_LIMITS:
		_budgets[source] = float(RATE_LIMITS[source][1])


# Adds a source's weight times amount and returns the points actually paid (0 when locked,
# full, unknown, or a rate-limited source past its limit).
func add(source: String, amount := 1.0) -> float:
	if locked or not WEIGHTS.has(source) or amount <= 0.0:
		return 0.0
	var points: float = float(WEIGHTS[source]) * amount
	if _budgets.has(source):
		points = minf(points, float(_budgets[source]))
		_budgets[source] = float(_budgets[source]) - points
	var paid := clampf(points, 0.0, CAP - value)
	if paid <= 0.0:
		return 0.0
	value += paid
	sources[source] = float(sources.get(source, 0.0)) + paid
	return paid


# A harpoon link on an enemy at this combo. 2026-10-11 (w13 B3b): a link beyond the first pays
# once per enemy per CHAIN_LINK_GAP of meter time. Tally's bot bites one boss about 13 times a
# second inside one chain and earned up to 2719 link points a run. With pay false the link is
# only counted (out of play).
func chain_link(enemy_id: int, combo: int, pay := true) -> float:
	if combo <= 1:
		return 0.0
	if _clock - float(_linked_at.get(enemy_id, -INF)) < CHAIN_LINK_GAP:
		return 0.0
	_linked_at[enemy_id] = _clock
	return add("chain_link") if pay else 0.0


# Time passes: the rate budgets refill, and speed pays by tier.
func tick(delta: float, speed_tier: int) -> void:
	_clock += delta
	for source in RATE_LIMITS:
		var limit: Array = RATE_LIMITS[source]
		_budgets[source] = minf(float(limit[1]), float(_budgets[source]) + float(limit[0]) * delta)
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
	_clock = 0.0
	_linked_at = {}
	_fill_budgets()
