extends RefCounted

const WINDOW := 3.0
const MIN_DAMAGE := 0.5

var charge := {}
var clock := 0.0
var stored_count := 0
var spent_count := 0
var expired_count := 0

signal stored(record: Dictionary)
signal spent(record: Dictionary, enemy: Node3D)
signal expired(record: Dictionary, cause: String)


static func slam_damage(force: float, row: Array, heft: float) -> float:
	return (float(row[0]) + force * float(row[1])) * heft


func held() -> bool:
	return not charge.is_empty()


func left() -> float:
	return maxf(0.0, float(charge["until"]) - clock) if held() else 0.0


func store(damage: float, flavour: String, pilot: String, color: Color) -> bool:
	if damage < MIN_DAMAGE:
		return false
	if held():
		expired.emit(charge, "replaced")
		expired_count += 1
	charge = {"damage": damage, "flavour": flavour, "pilot": pilot, "color": color, "t": clock,
		"until": clock + WINDOW}
	stored_count += 1
	stored.emit(charge)
	return true


static func is_reel_impact(kind: String, smash: bool, hooked: bool, winching: bool) -> bool:
	return kind in ["stomp", "ram", "slam"] and (smash or (hooked and winching))


func peek() -> float:
	_expire_if_due()
	return float(charge["damage"]) if held() else 0.0


func spend(enemy: Node3D) -> float:
	_expire_if_due()
	if not held():
		return 0.0
	var record := charge
	charge = {}
	spent_count += 1
	spent.emit(record, enemy)
	return float(record["damage"])


func tick(delta: float) -> void:
	clock += delta
	_expire_if_due()


func clear(cause := "reset") -> void:
	if held():
		var record := charge
		charge = {}
		expired_count += 1
		expired.emit(record, cause)


func _expire_if_due() -> void:
	if held() and clock >= float(charge["until"]):
		clear("timeout")
