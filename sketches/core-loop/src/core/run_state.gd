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
const HEFT_PER_MASS := 1.0 / 450.0
const HEFT_PER_PART := 0.2
const HEFT_CLASS_AT := [1.0, 1.5, 2.2, 3.2, 4.6]
# Bonus cores past this many add nothing more to the gate tier.
const CORE_TIER_CAP := 2
# Scrap as armour (the durability prototype, tuning `scrap_mode`): mass is a temporary
# health layer over the hull. SCRAP_PER_HP scrap absorbs one HP; of the scrap a hit
# removes, SPILL_SHARE spills as at most SPILL_CLUSTERS recovery clusters and the rest
# is destroyed. Wear (tuning `wear`) is WEAR_PER_MINUTE scrap a minute at cruise.
const SCRAP_PER_HP := 10.0
const SPILL_SHARE := 0.75
const SPILL_CLUSTERS := 6
const WEAR_PER_MINUTE := 30.0
# A class falls only this share of the preceding class interval below its threshold.
const CLASS_HYSTERESIS := 0.05

# A hit that reached the scrap: how much it removed, how much of that spills, and the
# source. player_hit still fires for every hit, armour-only included, with the whole hit.
signal armor_hit(removed: float, spill: int, source: String)
# Rolling wear took `removed` whole units of mass (wear_step only, --wear=on). Read-only; Rivet's
# Run and Gun trail reads it (world_one_rtree_test).
signal wear_taken(removed: float)

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

# The prototype's switches; build sets them from the tuning flags. Off is the base game.
var armor_mode := false
# Scrap one absorbed HP costs. Build resolves it on each recompute (Riveted Shell halves it);
# nothing else writes it, and the damage order below is the only reader.
var scrap_per_hp := SCRAP_PER_HP
var wear_on := false
# The share of a hit the passive damage reduction removes first (build sets it each
# tick in armour mode, where the reduction runs before the scrap).
var mitigation := 0.0
# Optional Callable(source) -> share: the brace window's extra reduction for a hit's
# source. It joins the passive reduction before the scrap layer (the damage order).
var brace_hook := Callable()
# Deflect plates: returns true when this hit glances off. A ward: given the hull left after
# overflow, returns the hull to hold instead. Both run inside the one damage order.
var deflect_hook := Callable()
var ward_hook := Callable()
# Whole wear units owed but not yet taken from the mass.
var _wear_accum := 0.0
# The armour metrics the run log carries; a retry adds to them, they are never restored.
var metrics := {}

var _snapshot := {}
var _heft_class := 1
# The first stage-start snapshot of each stage in this run, kept for a replay of that
# stage (the boss death screen's T replays stage 3).
var _stage_starts := {}


static func roman(n: int) -> String:
	return ["0", "I", "II", "III", "IV", "V", "VI"][clampi(n, 0, 6)]


func _init(events_ref = null) -> void:
	events = events_ref
	reset_metrics()


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
	_wear_accum = 0.0
	reset_metrics()


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
	metrics["fresh"] += amount
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


func reset_metrics() -> void:
	metrics = {"fresh": 0.0, "hit_loss": 0.0, "wear_loss": 0.0, "recovered": 0.0, "destroyed": 0.0,
		"expired": 0.0, "hull_damage": 0.0, "class_changes": 0, "class_drops": 0, "min_heft": -1.0, "heft_at_hits": [], "reverse_seconds": 0.0, "arena_destroyed": 0.0}


# Heft in armour mode comes from scrap alone; the base formula is untouched otherwise.
func heft() -> float:
	if armor_mode:
		return 1.0 + mass * HEFT_PER_MASS
	return 1.0 + mass * HEFT_PER_MASS + HEFT_PER_PART * parts.size()


# The class heft reaches with no memory: the highest threshold it has crossed.
func raw_heft_class(h: float) -> int:
	var result := 1
	for i in HEFT_CLASS_AT.size():
		if h >= HEFT_CLASS_AT[i]:
			result = i + 1
	return result


# Armour mode adds hysteresis: a class is held until heft is CLASS_HYSTERESIS of the
# interval below it under its threshold, so wear draining across a threshold cannot
# flicker the class. It only rises at the threshold itself.
func heft_class() -> int:
	var h := heft()
	var raw := raw_heft_class(h)
	if not armor_mode:
		return raw
	var held := clampi(_heft_class, 1, HEFT_CLASS_AT.size())
	if raw >= held:
		return raw
	while held > raw and held > 1:
		var below: float = HEFT_CLASS_AT[held - 1]
		var interval: float = HEFT_CLASS_AT[held - 1] - HEFT_CLASS_AT[held - 2]
		if h >= below - CLASS_HYSTERESIS * interval:
			break
		held -= 1
	return maxi(held, raw)


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
	metrics["class_changes"] += 1
	if not rose:
		metrics["class_drops"] += 1
	if rose:
		events.heft_class_changed.emit(c, heft())
	else:
		events.heft_class_dropped.emit(c, heft())


# Events and vaults grant bonus cores; each one overcharges this stage's beacon.
func add_core(source: String, at: Vector3) -> void:
	bonus_cores += 1
	events.core_gained.emit(source, at, bonus_cores)


# A lost risk bet burns this stage's cores (world/bet_crate.gd); its bet_resolved fact
# reports the loss. Returns how many burned.
func burn_cores() -> int:
	var burned := bonus_cores
	bonus_cores = 0
	return burned


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


# Armour mode resolves every hit in one order: mitigation, then the scrap layer, then
# the hull. The scrap layer takes what it can (SCRAP_PER_HP scrap per HP), SPILL_SHARE of
# the scrap removed spills as recovery clusters and the rest is destroyed.
func damage(amount: float, source: String) -> void:
	if not alive() or amount <= 0.0:
		return
	if armor_mode:
		_damage_armored(amount, source)
		return
	hp = maxf(0.0, hp - amount)
	since_damage = 0.0
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


func _damage_armored(amount: float, source: String) -> void:
	var share := clampf(mitigation, 0.0, 1.0)
	if brace_hook.is_valid():
		var brace: float = clampf(float(brace_hook.call(source)), 0.0, 1.0)
		share = 1.0 - (1.0 - share) * (1.0 - brace)
	# A glancing plate turns the hit aside before the scrap sees it, but the hit still
	# happened: every listener hears it (items, near-miss, the hurt sound and flash).
	var deflected: bool = deflect_hook.is_valid() and bool(deflect_hook.call(source))
	var left := 0.0 if deflected else amount * (1.0 - share)
	since_damage = 0.0
	if left <= 0.0:
		events.player_hit.emit(amount, source)
		return
	var absorbed := minf(left, mass / scrap_per_hp)
	var removed := absorbed * scrap_per_hp
	var overflow := left - absorbed
	if removed > 0.0:
		mass = maxf(0.0, mass - removed)
		var spill := int(round(removed * SPILL_SHARE))
		metrics["hit_loss"] += removed
		metrics["destroyed"] += removed - spill
		_publish_heft_class()
		# The spiral is observable: heft after each hit, and the lowest heft reached.
		metrics["min_heft"] = heft() if metrics["min_heft"] < 0.0 else minf(metrics["min_heft"], heft())
		if metrics["heft_at_hits"].size() < 200:
			metrics["heft_at_hits"].append(snappedf(heft(), 0.01))
		armor_hit.emit(removed, spill, source)
	if overflow > 0.0:
		var after := maxf(0.0, hp - overflow)
		# A ward holds the hull at its floor, once, inside the same order.
		if ward_hook.is_valid():
			after = maxf(after, float(ward_hook.call(after)))
		metrics["hull_damage"] += hp - after
		hp = after
	events.player_hit.emit(amount, source)
	if hp <= 0.0:
		events.player_died.emit()


# Spilled scrap picked back up: mass returns, but it is not a fresh pickup, so no
# scrap_collected, no wallet, no procs and no discovery.
func recover_mass(amount: int) -> void:
	if amount <= 0 or not alive():
		return
	mass += amount
	metrics["recovered"] += amount
	_publish_heft_class()


# A spill cluster that timed out unreached: its value is gone for good.
func note_spill_expired(amount: int) -> void:
	metrics["expired"] += amount


# The wear rate in scrap a second: WEAR_PER_MINUTE at cruise, scaled down below it and
# capped above it, so a faster ball pays no more than a cruising one.
static func wear_rate(speed: float, cruise: float) -> float:
	if cruise <= 0.0:
		return 0.0
	return WEAR_PER_MINUTE / 60.0 * clampf(speed / cruise, 0.0, 1.0)


# Rolling friction takes whole units of mass, and accrues only while a whole unit is left to
# take, so a fractional remainder never banks debt for the next pickup. `active` is false while paused, in the bay
# and in authored transfers or flights; wear never touches the hull and makes no event.
func wear_step(delta: float, speed: float, cruise: float, active: bool) -> void:
	if not armor_mode or not wear_on or not active or not alive() or delta <= 0.0 or mass < 1.0:
		return
	_wear_accum += wear_rate(speed, cruise) * delta
	var whole := minf(floorf(_wear_accum), mass)
	if whole < 1.0:
		return
	_wear_accum -= whole
	mass -= whole
	metrics["wear_loss"] += whole
	_publish_heft_class()
	wear_taken.emit(whole)


# The fixed route's opening mass (tuning `start_mass`): mass only, no wallet, no procs.
func grant_start_mass(amount: float) -> void:
	mass = maxf(0.0, amount)
	_heft_class = raw_heft_class(heft())


# True only while enemy_killed is emitting for a kill a wear spark landed: the item and tree
# consumers skip it, the bookkeeping ones do not.
var last_kill_from_spark := false


func record_kill(kind: String, at: Vector3, scrap_value: int, source := "") -> void:
	kills += 1
	last_kill_from_spark = source == "spark"
	events.enemy_killed.emit(kind, at, scrap_value)
	last_kill_from_spark = false


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
		"heft_class": _heft_class,
		"wear_accum": _wear_accum,
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
	# Armour mode puts back the class held at the checkpoint, hysteresis and all.
	if armor_mode:
		_heft_class = int(_snapshot.get("heft_class", raw_heft_class(heft())))
		_wear_accum = float(_snapshot.get("wear_accum", 0.0))
	else:
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
