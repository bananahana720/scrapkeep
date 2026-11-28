extends RefCounted

const SpeedTier := preload("res://src/core/speed_tier.gd")


const CAP := 100.0
const WEIGHTS := {
	"weapon": 0.25, "contact": 2.0, "smash": 5.0, "chain_link": 2.0, "near_miss": 4.0,
	"kill": 1.0, "stagger": 8.0, "shatter": 12.0, "fast": 0.5, "blazing": 1.2, "reel": 6.0,
}
const WEAPON_RATE_CAP := 0.4
const WEAPON_BURST := 0.5
const NEAR_MISS_RATE_CAP := 0.05
const NEAR_MISS_BURST := 4.0
const CONTACT_RATE_CAP := 0.14
const CONTACT_BURST := 2.0
const CHAIN_LINK_GAP := 1.0
const RATE_LIMITS := {
	"weapon": [WEAPON_RATE_CAP, WEAPON_BURST],
	"near_miss": [NEAR_MISS_RATE_CAP, NEAR_MISS_BURST],
	"contact": [CONTACT_RATE_CAP, CONTACT_BURST],
}

var value := 0.0
var sources := {}
var locked := false
var _entry := 0.0
var _budgets := {}
var _clock := 0.0
var _linked_at := {}


func _init() -> void:
	_fill_budgets()


func _fill_budgets() -> void:
	for source in RATE_LIMITS:
		_budgets[source] = float(RATE_LIMITS[source][1])


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


func chain_link(enemy_id: int, combo: int, pay := true) -> float:
	if combo <= 1:
		return 0.0
	if _clock - float(_linked_at.get(enemy_id, -INF)) < CHAIN_LINK_GAP:
		return 0.0
	_linked_at[enemy_id] = _clock
	return add("chain_link") if pay else 0.0


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


func spend() -> bool:
	if not full():
		return false
	value = 0.0
	return true


func refund(points: float) -> void:
	value = clampf(value + points, 0.0, CAP)


func mark_entry() -> void:
	_entry = value


func restore_entry() -> void:
	value = _entry
	locked = false


func reset() -> void:
	value = 0.0
	sources = {}
	locked = false
	_entry = 0.0
	_clock = 0.0
	_linked_at = {}
	_fill_budgets()
