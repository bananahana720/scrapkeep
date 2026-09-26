extends RefCounted

# One object owns the run: class, stage, health, scrap, parts and the counters the
# summary prints. Modules change it only through the mutators below, and each mutator
# publishes its fact on the bus after the change is made, so the HUD and the numbers
# here cannot disagree. Flow alone calls begin(), snapshot() and restore().

const MAX_HP := 100.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 6.0

var events
var class_def: Resource
var stage := 1
var max_hp := MAX_HP
var hp := MAX_HP
var scrap := 0
var parts: Array[String] = []
var kills := 0
var events_won: Array[String] = []
var run_time := 0.0
var stage_time := 0.0
var since_damage := 99.0
var retries := 0
var over := false

var _snapshot := {}


func _init(events_ref = null) -> void:
	events = events_ref


func begin(chosen_class: Resource) -> void:
	class_def = chosen_class
	stage = 1
	max_hp = MAX_HP
	hp = MAX_HP
	scrap = 0
	parts.clear()
	kills = 0
	events_won.clear()
	run_time = 0.0
	stage_time = 0.0
	since_damage = 99.0
	retries = 0
	over = false
	_snapshot = {}


func alive() -> bool:
	return hp > 0.0 and not over


func class_id() -> String:
	return class_def.id if class_def != null else ""


func advance(delta: float) -> void:
	if not alive():
		return
	run_time += delta
	stage_time += delta
	since_damage += delta
	if since_damage > REGEN_DELAY and hp < max_hp:
		hp = minf(max_hp, hp + REGEN_RATE * delta)


func add_scrap(amount: int, at: Vector3) -> void:
	if amount <= 0 or not alive():
		return
	scrap += amount
	events.scrap_collected.emit(amount, at, scrap)


# Build spends scrap at fabricators; a failed spend changes nothing.
func spend_scrap(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	return true


func add_part(part_id: String, source: String) -> void:
	parts.append(part_id)
	events.part_gained.emit(part_id, source)


func part_count(part_id: String) -> int:
	return parts.count(part_id)


# Build owns what parts do; a max-health part routes through here so a restore can
# put the old ceiling back.
func set_max_hp(value: float) -> void:
	var gained := maxf(0.0, value - max_hp)
	max_hp = maxf(1.0, value)
	hp = minf(max_hp, hp + gained)


func heal(amount: float) -> void:
	if alive():
		hp = minf(max_hp, hp + amount)


func damage(amount: float, source: String) -> void:
	if not alive() or amount <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	since_damage = 0.0
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func record_kill(kind: String, at: Vector3, scrap_value: int) -> void:
	kills += 1
	events.enemy_killed.emit(kind, at, scrap_value)


func record_milestone(event_id: String) -> void:
	events_won.append(event_id)
	events.milestone_won.emit(event_id)


# The stage-start checkpoint: everything a retry puts back, including where and how
# fast the ball entered, so a retry drops you in with the launch's speed.
func snapshot(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	stage_time = 0.0
	_snapshot = {
		"stage": stage,
		"max_hp": max_hp,
		"hp": hp,
		"scrap": scrap,
		"parts": parts.duplicate(),
		"kills": kills,
		"events_won": events_won.duplicate(),
		"entry_position": entry_position,
		"entry_velocity": entry_velocity,
		"camera_yaw": camera_yaw,
	}


func has_snapshot() -> bool:
	return not _snapshot.is_empty()


func snapshot_value(key: String):
	return _snapshot.get(key)


func restore() -> void:
	stage = _snapshot["stage"]
	max_hp = _snapshot["max_hp"]
	hp = _snapshot["hp"]
	scrap = _snapshot["scrap"]
	parts.assign(_snapshot["parts"])
	kills = _snapshot["kills"]
	events_won.assign(_snapshot["events_won"])
	stage_time = 0.0
	since_damage = 99.0
	retries += 1
	over = false


func summary() -> Dictionary:
	return {
		"class": class_def.display_name if class_def != null else "",
		"stages": stage,
		"scrap": scrap,
		"parts": parts.duplicate(),
		"kills": kills,
		"events_won": events_won.size(),
		"time": run_time,
		"retries": retries,
	}
