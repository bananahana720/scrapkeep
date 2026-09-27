extends RefCounted

# One object owns the run: class, stage, health, scrap, parts and the counters the
# summary prints. Modules change it only through the mutators below, and each mutator
# publishes its fact on the bus after the change is made, so the HUD and the numbers
# here cannot disagree. Flow alone calls begin(), snapshot() and restore().

const MAX_HP := 100.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 6.0
# Heft is the growth number (DEMO-SPEC): scrap rolled up becomes mass, parts add more.
# It scales punch and never touches handling. Classes I to V start at these values.
const HEFT_PER_MASS := 1.0 / 150.0
const HEFT_PER_PART := 0.2
const HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]
# Bonus cores past this many add nothing more to the gate tier.
const CORE_TIER_CAP := 2

var events
var class_def: Resource
var stage := 1
var max_hp := MAX_HP
var hp := MAX_HP
var scrap := 0
# Mass is separate from the scrap wallet: spending compacts scrap into a part and keeps
# the mass; only lose_scrap (a crane theft) takes mass away.
var mass := 0.0
# Bonus cores from events and vaults this stage; each one overcharges the beacon.
var bonus_cores := 0
var run_id := ""
var parts: Array[String] = []
var kills := 0
var events_won: Array[String] = []
var run_time := 0.0
var stage_time := 0.0
var since_damage := 99.0
var retries := 0
var over := false
# Seam faults the run log should carry, such as a Warden that vanished unbroken.
var anomalies: Array[Dictionary] = []

var _snapshot := {}
var _heft_class := 1
# The first stage-start snapshot of each stage in this run, kept for a replay of that
# stage (the boss death screen's T replays stage 3).
var _stage_starts := {}


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]


func _init(events_ref = null) -> void:
	events = events_ref


func begin(chosen_class: Resource) -> void:
	class_def = chosen_class
	stage = 1
	max_hp = MAX_HP
	hp = MAX_HP
	scrap = 0
	mass = 0.0
	bonus_cores = 0
	_heft_class = 1
	_stage_starts = {}
	run_id = "%d-%06d" % [int(Time.get_unix_time_from_system()), randi() % 1000000]
	parts.clear()
	kills = 0
	events_won.clear()
	run_time = 0.0
	stage_time = 0.0
	since_damage = 99.0
	retries = 0
	over = false
	anomalies.clear()
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
	mass += amount
	events.scrap_collected.emit(amount, at, scrap)
	_publish_heft_class()


# A theft: mass drops by the amount (not below zero) and the wallet by what it holds.
# Returns the mass actually taken, which a spill trail can pay back through add_scrap.
func lose_scrap(amount: int, at: Vector3, cause: String) -> int:
	if amount <= 0:
		return 0
	var taken := int(minf(float(amount), mass))
	mass = maxf(0.0, mass - amount)
	scrap -= mini(amount, scrap)
	events.scrap_lost.emit(taken, at, scrap, cause)
	_publish_heft_class()
	return taken


func heft() -> float:
	return 1.0 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size()


func heft_class() -> int:
	var h := heft()
	var result := 1
	for i in HEFT_CLASS_AT.size():
		if h >= HEFT_CLASS_AT[i]:
			result = i + 1
	return result


# 0 to 1 across the current class toward the next; 1 at the top class.
func heft_progress() -> float:
	var c := heft_class()
	if c >= HEFT_CLASS_AT.size():
		return 1.0
	var low: float = HEFT_CLASS_AT[c - 1]
	var high: float = HEFT_CLASS_AT[c]
	return clampf((heft() - low) / (high - low), 0.0, 1.0)


# A rise and a drop are different facts with different sounds, so each has its own
# signal: heft_class_changed only ever means the class went up.
func _publish_heft_class() -> void:
	var c := heft_class()
	if c == _heft_class:
		return
	var rose := c > _heft_class
	_heft_class = c
	if rose:
		events.heft_class_changed.emit(c, heft())
	else:
		events.heft_class_dropped.emit(c, heft())


# Events and vaults grant bonus cores; each one overcharges this stage's beacon.
func add_core(source: String, at: Vector3) -> void:
	bonus_cores += 1
	events.core_gained.emit(source, at, bonus_cores)


# The gate tier bonus the cores buy: 0, 1 or 2 (two or more cores).
func gate_tier_bonus() -> int:
	return mini(bonus_cores, CORE_TIER_CAP)


# Build spends scrap at fabricators; a failed spend changes nothing.
func spend_scrap(amount: int) -> bool:
	if amount < 0 or scrap < amount:
		return false
	scrap -= amount
	return true


func add_part(part_id: String, source: String) -> void:
	parts.append(part_id)
	events.part_gained.emit(part_id, source)
	_publish_heft_class()


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


func note_anomaly(kind: String) -> void:
	anomalies.append({"stage": stage, "kind": kind, "ticks": int(round(stage_time * Engine.physics_ticks_per_second))})


func record_milestone(event_id: String) -> void:
	events_won.append(event_id)
	events.milestone_won.emit(event_id)


# Flow calls this as a stage begins (not on a retry): cores are stage-scoped.
func enter_stage(index: int) -> void:
	stage = index
	bonus_cores = 0


# The stage-start checkpoint: everything a retry puts back, including where and how
# fast the ball entered, so a retry drops you in with the launch's speed.
func snapshot(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	stage_time = 0.0
	_snapshot = {
		"stage": stage,
		"max_hp": max_hp,
		"hp": hp,
		"scrap": scrap,
		"mass": mass,
		"bonus_cores": bonus_cores,
		"parts": parts.duplicate(),
		"kills": kills,
		"events_won": events_won.duplicate(),
		"entry_position": entry_position,
		"entry_velocity": entry_velocity,
		"camera_yaw": camera_yaw,
	}
	if not _stage_starts.has(stage):
		_stage_starts[stage] = _snapshot.duplicate(true)


# Flow takes the snapshot before stage_entered and fills in the entry pose once the
# ball is placed; the kept stage start gets the same pose.
func set_snapshot_entry(entry_position: Vector3, entry_velocity: Vector3, camera_yaw: float) -> void:
	for record in [_snapshot, _stage_starts.get(stage, {})]:
		if record.is_empty() or record["stage"] != stage:
			continue
		if record == _snapshot or record["entry_position"] == Vector3.ZERO:
			record["entry_position"] = entry_position
			record["entry_velocity"] = entry_velocity
			record["camera_yaw"] = camera_yaw


func has_stage_start(index: int) -> bool:
	return _stage_starts.has(index)


# Makes a kept stage start the live checkpoint, so the next restore() replays it.
func use_stage_start(index: int) -> bool:
	if not _stage_starts.has(index):
		return false
	_snapshot = (_stage_starts[index] as Dictionary).duplicate(true)
	return true


func has_snapshot() -> bool:
	return not _snapshot.is_empty()


func snapshot_value(key: String):
	return _snapshot.get(key)


func restore() -> void:
	stage = _snapshot["stage"]
	max_hp = _snapshot["max_hp"]
	hp = _snapshot["hp"]
	scrap = _snapshot["scrap"]
	mass = _snapshot["mass"]
	bonus_cores = _snapshot["bonus_cores"]
	parts.assign(_snapshot["parts"])
	kills = _snapshot["kills"]
	events_won.assign(_snapshot["events_won"])
	stage_time = 0.0
	since_damage = 99.0
	retries += 1
	over = false
	# A restore is a rewind, not growth: the class follows silently, with no stinger.
	_heft_class = heft_class()


func summary() -> Dictionary:
	return {
		"class": class_def.display_name if class_def != null else "",
		"stages": stage,
		"scrap": scrap,
		"mass": mass,
		"heft": heft(),
		"parts": parts.duplicate(),
		"kills": kills,
		"events_won": events_won.size(),
		"time": run_time,
		"retries": retries,
	}
