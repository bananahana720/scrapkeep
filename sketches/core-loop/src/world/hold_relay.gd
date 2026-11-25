extends RefCounted

const Parts := preload("res://src/build/parts.gd")
const Cards := preload("res://src/world/director_cards.gd")


const RULE := {"T": 18.0, "s": 1.0, "discharge": 0.0, "radius": 24.0, "radius_floor": 3.0, "follower": 0.0}
const WINDOW := 60.0
const REACH_UP := 14.0
const CONVERGENCE_ID := "relay_convergence"

var id := "hold_the_relay"
var rule: Dictionary = RULE.duplicate()
var ring := Vector2.ZERO
var ring_radius: float = RULE["radius"]
var relay := Vector2.ZERO
var held := 0.0
var elapsed := 0.0
var inside := false
var miniboss_at := 0.35
var share := 1.0
var stakes := 0
var _relay_y := 0.0
var _charging := false


func _init(site: Dictionary, relay_y: float) -> void:
	relay = site["relay"]
	ring = site["ring"]
	_relay_y = relay_y


func begin() -> void:
	held = 0.0
	elapsed = 0.0
	_charging = true


func charging() -> bool:
	return _charging


func set_stakes(k: int) -> bool:
	if _charging:
		return false
	stakes = clampi(k, 0, Cards.RELAY_STAKE_MAX)
	return true


func stake_up() -> bool:
	return set_stakes((stakes + 1) % (Cards.RELAY_STAKE_MAX + 1))


func pack_credit(base: float) -> float:
	return Cards.staked(base, stakes)


func miniboss_credit(base: float) -> float:
	return Cards.staked(base, stakes)


func rewards() -> int:
	return 1 + stakes


func stake_line() -> String:
	if stakes == 0:
		return "No stake. 1 part roll."
	return "Stake x%d: fight x%d, %d part rolls." % [stakes, 1 + stakes, rewards()]


func set_occupancy(inside_count: int, living_count: int) -> void:
	share = clampf(float(inside_count) / float(maxi(1, living_count)), 0.0, 1.0)


func step(delta: float, ball: Vector3, _velocity: Vector3) -> String:
	elapsed += delta
	ring_radius = maxf(float(rule["radius_floor"]), float(rule["radius"]) * (1.0 - float(rule["follower"]) * progress()))
	inside = Vector2(ball.x, ball.z).distance_to(relay) <= ring_radius and ball.y < _relay_y + REACH_UP
	if inside:
		held += delta * pow(share, float(rule["s"]))
		if held >= float(rule["T"]):
			_charging = false
			return "won"
	elif float(rule["discharge"]) > 0.0:
		held = maxf(0.0, held - float(rule["discharge"]) * delta)
	if elapsed >= WINDOW:
		_charging = false
		return "lost"
	return ""


static func tuned(count: int) -> Dictionary:
	var row: Dictionary = Parts.CATALOGUE[CONVERGENCE_ID]
	var c := clampi(count, 0, int(row["cap"]))
	var numbers: Dictionary = row["relay"]
	var radius: float = RULE["radius"]
	if c > 0:
		radius = float(RULE["radius"]) / (float(numbers["radius_div"]) * c)
	return {"T": float(RULE["T"]) / (1.0 + float(numbers["charge_per"]) * c), "radius": radius}


func tune(count: int) -> void:
	var t := tuned(count)
	rule["T"] = t["T"]
	rule["radius"] = t["radius"]


func push(_ball: Vector3, _velocity: Vector3) -> Vector3:
	return Vector3.ZERO


func progress() -> float:
	return clampf(held / float(rule["T"]), 0.0, 1.0)


func spike() -> bool:
	return true


func status() -> String:
	var line := "Relay %d%%. %d s left." % [int(progress() * 100.0), int(ceil(WINDOW - elapsed))]
	if stakes > 0:
		line += " Stake x%d." % stakes
	return line if inside else line + " Back in the ring!"


func miniboss_zone() -> Array:
	return [relay, Vector2(float(rule["radius"]) + 8.0, float(rule["radius"]) + 22.0)]


func take_facts() -> Array:
	return []
