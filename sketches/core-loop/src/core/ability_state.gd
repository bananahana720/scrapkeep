extends RefCounted


const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/core/glyphs.gd")
const Palette := preload("res://src/core/palette.gd")
const BuffLedger := preload("res://src/core/buff_ledger.gd")

const WEAPON := "weapon"
const MOVEMENT := "movement"
const SPECIAL := "special"
const SMASH := "smash"
const LINE := "line"
const SLOTS := [WEAPON, MOVEMENT, SPECIAL, SMASH, LINE]
const BAR := [WEAPON, SPECIAL, LINE]
const CHIPS := [MOVEMENT, SMASH]
const NUMBER := {WEAPON: 1, SPECIAL: 2, LINE: 3}
const ULTIMATE := "ultimate"
const SWAPPABLE := SLOTS + [ULTIMATE]
const SELECT_TIMEOUT := 3.0
static var KEYS := {WEAPON: "1", MOVEMENT: Bindings.label("boost"),
	SPECIAL: "2", SMASH: Bindings.label("haul"), LINE: "3"}

const READY := "ready"
const COOLING := "cooling"
const ACTIVE := "active"
const UNAVAILABLE := "unavailable"
const JAMMED := "jammed"

const COOLDOWN_FLOOR := 0.4
const HIT_LANDED := "hit_landed"
const DAMAGE_TAKEN := "damage_taken"
const REFUNDS := {
	HIT_LANDED: {"seconds": 1.0},
	DAMAGE_TAKEN: {"seconds": 2.0},
}
const REFUND_MIN := 1.0
const REFUND_MAX := 2.0
const REFUND_CYCLE_SHARE := 0.5
const STAGE_REFUND_CAP := 20.0
const REFUND_SLOTS := [MOVEMENT, LINE]
const REFUND_KIND := "cooldown_refunded"
const PRIORITY := 1
const IDLE_PRIORITY := -1
const MIN_ATTACK_SPEED := 0.05
const RUN_EPSILON := 0.000001
const PRESSURE_EPS := 0.0001
const FORGIVENESS := 0.18
const SILENCED := [SPECIAL, LINE]
const VARIANT_CAST := 0.5
const UNSTARTED := ""

const ABILITIES := {
	"arc_caster": {"icon": "ab_sable_weapon", "cooldown": 0.0, "mounted": "pylon_turret"},
	"arc_ring": {"icon": "ab_sable_weapon", "cooldown": 0.0, "mounted": "pylon_turret", "pattern": "arc_caster", "mutation": "arc_ring"},
	"grapple": {"icon": "ab_sable_move", "cooldown": 0.0, "augments": ["grapple", "pylon", "vault"]},
	"detonation_gauge": {"icon": "ab_sable_special", "cooldown": 5.0, "charge_max": 1.0, "plant_discharge": true},
	"halo_discharge": {"icon": "ab_sable_special", "cooldown": 5.0, "charge_max": 1.0, "plant_discharge": true, "mutation": "halo_discharge"},
	"arc_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc"},
	"crater_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc", "spends_special": true},
	"rapid_laser": {"icon": "ab_rivet_weapon", "cooldown": 0.0},
	"fan_burst": {"icon": "ab_rivet_weapon", "cooldown": 0.0, "pattern": "rapid_laser", "mutation": "fan_burst"},
	"overdrive_sprint": {"icon": "ab_rivet_move", "cooldown": 5.0, "duration": 2.0, "augments": ["sprint"]},
	"overdrive_blast": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"point_blank": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"shockwave_skid": {"icon": "ab_rivet_smash", "cooldown": 0.0, "flavour": "skid"},
	"auger_slam": {"icon": "ab_rivet_smash", "cooldown": 0.0, "flavour": "skid", "mutation": "auger_slam"},
	"sticky_charge": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 1, "bolts": false},
	"sticky_rain": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 3, "pattern": "sticky_charge", "bolts": false},
	"smoke_blink": {"icon": "ab_kest_move", "cooldown": 4.0, "augments": ["blink", "glide"], "rocket": true, "cloak": true},
	"detonation_line": {"icon": "ab_kest_special", "cooldown": 6.0, "charge_max": 0.8},
	"snare_detonate": {"icon": "ab_kest_special", "cooldown": 6.0, "charge_max": 0.8, "mutation": "snare_detonate"},
	"demo_slam": {"icon": "ab_kest_smash", "cooldown": 0.0, "flavour": "demo"},
	"thermite_slam": {"icon": "ab_kest_smash", "cooldown": 0.0, "flavour": "demo", "mutation": "thermite_slam"},
	"claw_sweep": {"icon": "ab_tarn_weapon", "cooldown": 0.0},
	"claw_rake": {"icon": "ab_tarn_weapon", "cooldown": 0.0, "pattern": "claw_sweep", "mutation": "claw_rake"},
	"claw_pull": {"icon": "ab_tarn_move", "cooldown": 3.0, "augments": ["claw_pull"]},
	"clamp": {"icon": "ab_tarn_special", "cooldown": 6.0, "charge_max": 0.8},
	"rend_slam": {"icon": "ab_tarn_smash", "cooldown": 0.0, "flavour": "rend"},
	"rend_drag": {"icon": "ab_tarn_smash", "cooldown": 0.0, "flavour": "rend", "mutation": "rend_drag"},
	"flywheel_surge": {"icon": "ab_tally_move", "cooldown": 4.0, "augments": ["surge"]},
	"stamp_slam": {"icon": "ab_tally_smash", "cooldown": 0.0, "flavour": "stamp"},
	"stamp_ink": {"icon": "ab_tally_smash", "cooldown": 0.0, "flavour": "stamp", "mutation": "stamp_ink"},
	"cannon_lane": {"icon": "ab_cannon_weapon", "cooldown": 0.0, "family": "lane", "bolts": false},
	"cannon_lane_walk": {"icon": "ab_cannon_weapon", "cooldown": 0.0, "family": "lane", "pattern": "cannon_lane", "mutation": "cannon_lane_walk", "bolts": false},
	"cannon_recoil": {"icon": "ab_cannon_move", "cooldown": 3.5, "augments": ["recoil"], "family": "split_lane"},
	"cannon_plate": {"icon": "ab_cannon_special", "cooldown": 6.0, "charge_max": 0.8, "family": "plate"},
	"cannon_mortar": {"icon": "ab_cannon_special", "cooldown": 6.0, "charge_max": 0.8, "family": "plate", "mutation": "cannon_mortar"},
	"cannon_rush": {"icon": "ab_cannon_smash", "cooldown": 0.0, "flavour": "rush", "family": "rush"},
	"cannon_rush_wake": {"icon": "ab_cannon_smash", "cooldown": 0.0, "flavour": "rush", "family": "rush", "mutation": "cannon_rush_wake"},
	"line_reel": {"icon": "ab_sable_reel", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"ult_default": {"icon": "ab_sable_reel", "cooldown": 0.0, "paths": ["line", "arc"], "beats": 0},
	"bank_shot": {"icon": "ab_sable_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"bank_arc": {"icon": "ab_sable_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "mutation": "bank_arc"},
	"cable_run": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"ball_lightning": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["arc"], "variant_of": "cable_run", "cast": VARIANT_CAST},
	"outpost": {"icon": "ab_sable_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "cable_run", "cast": VARIANT_CAST},
	"line_drive": {"icon": "ab_rivet_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"rail_vault": {"icon": "ab_rivet_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "mutation": "rail_vault"},
	"foundry_cutter": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"prism_cutter": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter", "cast": VARIANT_CAST},
	"juggernaut_drive": {"icon": "ab_rivet_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "foundry_cutter", "cast": VARIANT_CAST},
	"cable_charge": {"icon": "ab_kest_line", "cooldown": 14.0, "line": true, "load_seconds": 4.0},
	"cable_cluster": {"icon": "ab_kest_line", "cooldown": 14.0, "line": true, "load_seconds": 4.0, "mutation": "cable_cluster"},
	"windhover": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "hold_beats": 2},
	"air_raid": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "variant_of": "windhover", "cast": VARIANT_CAST},
	"minelayer": {"icon": "ab_kest_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "windhover", "cast": VARIANT_CAST},
	"claw_drag": {"icon": "ab_tarn_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"claw_whirl": {"icon": "ab_tarn_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "mutation": "claw_whirl"},
	"redjaw_rend": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"rake_run": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "redjaw_rend", "cast": VARIANT_CAST, "plant": true},
	"vice_leap": {"icon": "ab_tarn_ult", "cooldown": 0.0, "paths": ["arc", "line", "rail"], "variant_of": "redjaw_rend", "cast": VARIANT_CAST, "plant": true},
	"ledger_reader": {"icon": "ab_tally_weapon", "cooldown": 0.0, "cards": ["balance_due"], "pressure": 3, "bolts": false},
	"ledger_echo": {"icon": "ab_tally_weapon", "cooldown": 0.0, "cards": ["balance_due"], "pressure": 3, "bolts": false, "pattern": "ledger_reader", "mutation": "ledger_echo"},
	"gather_plate": {"icon": "ab_tally_gather", "cooldown": 6.0, "cast": 0.3},
	"link_clips": {"icon": "ab_tally_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0},
	"link_double": {"icon": "ab_tally_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "mutation": "link_double"},
	"plate_return": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"]},
	"plate_audit": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["line", "rail", "arc"], "variant_of": "plate_return", "cast": VARIANT_CAST},
	"plate_flywheel": {"icon": "ab_tally_ult", "cooldown": 0.0, "paths": ["arc", "rail", "line"], "variant_of": "plate_return", "cast": VARIANT_CAST},
	"cannon_lane_charge": {"icon": "ab_cannon_line", "cooldown": 8.0, "line": true, "load_seconds": 4.0, "family": "lane"},
	"cannon_fire_mission": {"icon": "ab_cannon_ult", "paths": ["arc", "line", "rail"], "beats": 0},
	"cannon_creeping_barrage": {"icon": "ab_cannon_ult", "paths": ["line", "rail", "arc"], "beats": 0, "variant_of": "cannon_fire_mission", "cast": VARIANT_CAST, "plant": true},
	"cannon_plate_mortar": {"icon": "ab_cannon_ult", "paths": ["arc"], "beats": 6, "variant_of": "cannon_fire_mission", "cast": VARIANT_CAST, "plant": true},
}
const ICON_DIR := "res://assets/icons/"


class Gauge:
	extends RefCounted

	const GRACE := 0.5

	var charge_max := 1.0
	var charging := false
	var held := 0.0
	var fired_fraction := 0.0
	var auto := false

	func _init(seconds := 1.0) -> void:
		charge_max = maxf(0.05, seconds)

	func begin() -> void:
		charging = true
		held = 0.0
		auto = false

	func fraction() -> float:
		return clampf(held / charge_max, 0.0, 1.0) if charging else 0.0

	func step(delta: float, key_held: bool) -> bool:
		if not charging:
			return false
		if key_held:
			held += delta
			if held < charge_max + GRACE:
				return false
		fired_fraction = clampf(held / charge_max, 0.0, 1.0)
		auto = key_held
		charging = false
		held = 0.0
		return true

	func cancel() -> bool:
		var was := charging
		charging = false
		held = 0.0
		return was

	static func scaled(f: float, floor_value: float, full_value: float) -> float:
		return lerpf(floor_value, full_value, clampf(f, 0.0, 1.0))


class Slot:
	extends RefCounted

	var id := ""
	var icon := ""
	var cooldown := 0.0
	var cooldown_scale := 1.0
	var base_duration := 0.0
	var duration := 0.0
	var priority := PRIORITY
	var cancels_sprint := false
	var max_charges := 1
	var _charges := 1
	var is_pressure := false
	var pressure_val := 1.0
	var charges: int:
		get:
			if is_pressure:
				return clampi(int(floor(pressure_val + PRESSURE_EPS)), 0, max_charges)
			return _charges
		set(value):
			_charges = value
			if is_pressure:
				pressure_val = clampf(float(value), 0.0, float(max_charges))
	var recharge := 0.0
	var active := false
	var available := true
	var gauge: Gauge = null
	var item_charges := 0
	var item_scale := 1.0
	var pressure_bonus := 0
	var cycle_refunded := 0.0
	var cast := 0.0

	func clamp_to_max() -> void:
		if is_pressure:
			pressure_val = minf(pressure_val, float(max_charges))
		_charges = mini(_charges, max_charges)


var movement_key: String = KEYS[MOVEMENT]
var _slots := {}
var selected := WEAPON
var _select_held := 0.0
var ultimate_id := ""
var meter = null
var stage_refunded := 0.0
var _refunds := []
var attack_speed := 1.0
var running := ""
var running_left := 0.0
var state_changes := 0
var sprint_cancels := 0
var _requests := []
var _sprint_cancel := false
var casting := UNSTARTED
var cast_left := 0.0
var _cast_done := UNSTARTED
var _swap_dropped := ""
var jam_left := 0.0
var jams := 0
var _buffs = null
var _running_buff_id := ""


func _init() -> void:
	for name in SLOTS:
		_slots[name] = Slot.new()


func bind_buffs(ledger) -> void:
	if _buffs == ledger:
		return
	_clear_running_buff()
	_buffs = ledger


func fit(def) -> void:
	var ids := {WEAPON: "", MOVEMENT: "", SPECIAL: "", SMASH: "", LINE: ""}
	ultimate_id = ""
	if def != null:
		ids = {WEAPON: def.weapon_id, MOVEMENT: def.movement_id, SPECIAL: def.special_id, SMASH: def.smash_id,
			LINE: def.line_id}
		ultimate_id = def.ultimate_id
	for name in SLOTS:
		_slots[name] = Slot.new()
		swap(name, ids[name])
	selected = WEAPON
	_select_held = 0.0


func swap(name: String, id: String) -> void:
	var row: Dictionary = ABILITIES.get(id, {})
	var old: Slot = _slots[name]
	if casting == name and old.id != id:
		_swap_dropped = cancel_cast()
	var s := Slot.new()
	s.max_charges = maxi(1, old.max_charges - old.pressure_bonus)
	s.charges = s.max_charges
	s.cooldown_scale = old.cooldown_scale
	s.item_charges = old.item_charges
	s.item_scale = old.item_scale
	s.id = id
	s.icon = row.get("icon", "")
	s.cooldown = row.get("cooldown", 0.0)
	s.base_duration = row.get("duration", 0.0)
	s.duration = s.base_duration / attack_speed
	s.priority = priority_of(id)
	s.cancels_sprint = cancels_sprint_of(id)
	s.cast = maxf(0.0, float(row.get("cast", 0.0)))
	var charge_max: float = row.get("charge_max", 0.0)
	if charge_max > 0.0:
		s.gauge = Gauge.new(charge_max)
	if row.has("pressure"):
		var own: int = s.max_charges
		s.max_charges = maxi(old.max_charges, int(row["pressure"]))
		s.pressure_bonus = s.max_charges - own
		s.is_pressure = true
		s.charges = s.max_charges
	_slots[name] = s


func take_swap_dropped() -> String:
	var id := _swap_dropped
	_swap_dropped = ""
	return id


func cap(name: String, key: String, fallback = null):
	return ABILITIES.get((_slots[name] as Slot).id, {}).get(key, fallback)


func slot(name: String) -> Slot:
	return _slots[name]


func id_of(name: String) -> String:
	return (_slots[name] as Slot).id


func gauge(name: String) -> Gauge:
	return (_slots[name] as Slot).gauge


static func floored(base: float, scale: float) -> float:
	if base <= 0.0:
		return 0.0
	return maxf(COOLDOWN_FLOOR, base * scale)


func cooldown_of(name: String) -> float:
	var s: Slot = _slots[name]
	return floored(s.cooldown, s.cooldown_scale)


func pool_of(name: String) -> String:
	var pool := String(cap(name, "pool", ""))
	return pool if pool != "" and pool != name and _slots.has(pool) else name


func pressure_of(name: String) -> float:
	var payer: Slot = _slots[pool_of(name)]
	return payer.pressure_val if payer.is_pressure else float(payer.charges)


func ready(name: String, cost := 1.0) -> bool:
	var s: Slot = _slots[name]
	var payer: Slot = _slots[pool_of(name)]
	if payer.is_pressure:
		return s.available and payer.pressure_val + PRESSURE_EPS >= cost and not silenced(name)
	return s.available and payer.charges > 0 and not silenced(name)


func spend(name: String, cost := 1.0) -> bool:
	if not ready(name, cost):
		return false
	var payer: Slot = _slots[pool_of(name)]
	if payer.is_pressure:
		payer.pressure_val = maxf(0.0, payer.pressure_val - maxf(cost, 0.0))
		if payer.pressure_val <= PRESSURE_EPS:
			payer.pressure_val = 0.0
		return true
	payer.charges -= 1
	return true


func grant(name: String, count := 1) -> void:
	if count <= 0:
		return
	var s: Slot = _slots[name]
	if s.is_pressure:
		grant_amount(name, float(count))
		return
	s.charges = mini(s.max_charges, s.charges + count)
	if s.charges == s.max_charges:
		s.recharge = 0.0
		s.cycle_refunded = 0.0


func grant_amount(name: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var s: Slot = _slots[name]
	if not s.is_pressure:
		grant(name, int(floor(amount)))
		return
	s.pressure_val = minf(float(s.max_charges), s.pressure_val + amount)
	if s.pressure_val + PRESSURE_EPS >= float(s.max_charges):
		s.pressure_val = float(s.max_charges)
		s.recharge = 0.0
		s.cycle_refunded = 0.0


func refund(name: String, seconds: float) -> void:
	_recharge(_slots[name], seconds)


func refund_slot() -> String:
	for name in REFUND_SLOTS:
		if cooldown_of(name) > 0.0 and not ABILITIES.get(id_of(name), {}).has("pressure"):
			return name
	return ""


func combat_refund(source: String) -> float:
	var row: Dictionary = REFUNDS.get(source, {})
	var name := refund_slot()
	if row.is_empty() or name == "":
		return 0.0
	var s: Slot = _slots[name]
	if s.charges >= s.max_charges:
		return 0.0
	var cd := cooldown_of(name)
	var grant: float = minf(float(row["seconds"]), REFUND_MAX)
	grant = minf(grant, cd * REFUND_CYCLE_SHARE - s.cycle_refunded)
	grant = minf(grant, STAGE_REFUND_CAP - stage_refunded)
	if grant < REFUND_MIN:
		return 0.0
	var before := s.charges
	s.cycle_refunded += grant
	stage_refunded += grant
	refund(name, grant)
	if s.charges > before:
		s.cycle_refunded = minf(s.recharge, grant) if s.charges < s.max_charges else 0.0
	_refunds.append({"kind": REFUND_KIND, "slot": name, "id": s.id, "source": source, "seconds": grant})
	return grant


func drain_refunds() -> Array:
	var out := _refunds
	_refunds = []
	return out


func refill() -> void:
	stage_refunded = 0.0
	casting = UNSTARTED
	cast_left = 0.0
	_cast_done = UNSTARTED
	_swap_dropped = ""
	jam_left = 0.0
	running = ""
	running_left = 0.0
	_clear_running_buff()
	_requests = []
	_sprint_cancel = false
	for name in SLOTS:
		var s: Slot = _slots[name]
		s.charges = s.max_charges
		s.recharge = 0.0
		s.cycle_refunded = 0.0
		s.active = false
		if s.gauge != null:
			s.gauge.cancel()


func set_max_charges(name: String, count: int) -> void:
	var s: Slot = _slots[name]
	s.max_charges = maxi(1, count)
	s.clamp_to_max()


func set_cooldown_scale(name: String, scale: float) -> void:
	(_slots[name] as Slot).cooldown_scale = maxf(0.0, scale)


func tick(delta: float) -> void:
	if _buffs != null:
		_buffs.step(delta)
	_resolve(delta)
	_tick_cast(delta)
	jam_left = maxf(0.0, jam_left - delta)
	for name in SLOTS:
		_recharge(_slots[name], delta)


static func priority_of(id: String) -> int:
	return int(ABILITIES.get(id, {}).get("priority", PRIORITY))


static func cancels_sprint_of(id: String) -> bool:
	return bool(ABILITIES.get(id, {}).get("cancels_sprint", false))


static func strongest(current: int, priorities: Array) -> int:
	var win := -1
	for i in priorities.size():
		if int(priorities[i]) > current and (win < 0 or int(priorities[i]) > int(priorities[win])):
			win = i
	return win


func set_attack_speed(speed: float) -> void:
	attack_speed = maxf(MIN_ATTACK_SPEED, speed)
	for name in SLOTS:
		var s: Slot = _slots[name]
		s.duration = s.base_duration / attack_speed


func duration_of(name: String) -> float:
	return (_slots[name] as Slot).base_duration / attack_speed


func running_priority() -> int:
	return IDLE_PRIORITY if running == "" else (_slots[running] as Slot).priority


func request(name: String) -> void:
	if _slots.has(name):
		_requests.append(name)


func take_sprint_cancel() -> bool:
	var was := _sprint_cancel
	_sprint_cancel = false
	return was


func _resolve(delta: float) -> void:
	if _requests.is_empty() and running == "":
		return
	var names := []
	var priorities := []
	for name in _requests:
		if ready(name):
			names.append(name)
			priorities.append((_slots[name] as Slot).priority)
	_requests = []
	var win := strongest(running_priority(), priorities)
	if win >= 0:
		var name: String = names[win]
		spend(name)
		running = name
		running_left = duration_of(name)
		state_changes += 1
		if (_slots[name] as Slot).cancels_sprint:
			_sprint_cancel = true
			sprint_cancels += 1
		_post_running_buff()
		return
	if running != "":
		running_left -= delta
		if running_left <= RUN_EPSILON:
			running = ""
			running_left = 0.0
			state_changes += 1
			_clear_running_buff()


func _post_running_buff() -> void:
	if _buffs == null:
		return
	var s: Slot = _slots.get(running)
	if s == null or running_left <= RUN_EPSILON:
		_clear_running_buff()
		return
	var buff_id := "ability_" + s.id
	if _running_buff_id != "" and _running_buff_id != buff_id:
		_buffs.clear_id(_running_buff_id)
	_running_buff_id = buff_id
	_buffs.post(buff_id, {
		"icon": s.icon,
		"tone": Palette.AMBER,
		"duration_s": running_left,
		"kind": BuffLedger.KIND_TIMER,
		"stacks": 1,
		"max_stacks": 1,
	})


func _clear_running_buff() -> void:
	if _buffs != null and _running_buff_id != "":
		_buffs.clear_id(_running_buff_id)
	_running_buff_id = ""


func _recharge(s: Slot, seconds: float) -> void:
	if ABILITIES.get(s.id, {}).has("pressure"):
		s.recharge = 0.0
		return
	if s.charges >= s.max_charges:
		s.recharge = 0.0
		return
	var cd := floored(s.cooldown, s.cooldown_scale)
	if cd <= 0.0:
		s.charges = s.max_charges
		s.recharge = 0.0
		return
	s.recharge += seconds
	while s.recharge >= cd and s.charges < s.max_charges:
		s.recharge -= cd
		s.charges += 1
		s.cycle_refunded = 0.0
	if s.charges >= s.max_charges:
		s.recharge = 0.0


func charging() -> bool:
	if casting != UNSTARTED:
		return true
	for name in SLOTS:
		var g: Gauge = (_slots[name] as Slot).gauge
		if g != null and g.charging:
			return true
	return false


func cancel_gauges() -> Array:
	var dropped := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		if s.gauge != null and s.gauge.cancel():
			dropped.append(s.id)
	var cast := cancel_cast()
	if cast != UNSTARTED:
		dropped.append(cast)
	return dropped


func cast_of(name: String) -> float:
	return (_slots[name] as Slot).cast


func begin_cast(name: String) -> bool:
	if casting != UNSTARTED or cast_of(name) <= 0.0 or not ready(name):
		return false
	casting = name
	cast_left = cast_of(name)
	return true


func cast_fraction() -> float:
	if casting == UNSTARTED:
		return 0.0
	return clampf(1.0 - cast_left / maxf(0.001, cast_of(casting)), 0.0, 1.0)


func cancel_cast() -> String:
	if casting == UNSTARTED:
		return UNSTARTED
	var id := id_of(casting)
	casting = UNSTARTED
	cast_left = 0.0
	return id


func take_cast_done() -> String:
	var done := _cast_done
	_cast_done = UNSTARTED
	return done


func _tick_cast(delta: float) -> void:
	if casting == UNSTARTED:
		return
	cast_left -= delta
	if cast_left <= RUN_EPSILON:
		_cast_done = casting
		casting = UNSTARTED
		cast_left = 0.0


func jam(seconds: float) -> void:
	jam_left = maxf(jam_left, seconds)
	jams += 1


func jammed() -> bool:
	return jam_left > 0.0


func silenced(name: String) -> bool:
	return jam_left > 0.0 and name in SILENCED


func state_of(name: String) -> String:
	var s: Slot = _slots[name]
	if not s.available or silenced(name):
		return UNAVAILABLE
	if s.active or (s.gauge != null and s.gauge.charging) or casting == name:
		return ACTIVE
	return READY if (_slots[pool_of(name)] as Slot).charges > 0 else COOLING


func select(name: String) -> String:
	if not name in BAR or not _slots.has(name):
		return UNAVAILABLE
	var s: Slot = _slots[name]
	if s.id == "" or not s.available:
		return UNAVAILABLE
	if silenced(name):
		return JAMMED
	if name != WEAPON and not ready(name):
		return COOLING
	selected = name
	_select_held = 0.0
	return ""


func snap_back(_reason := "") -> bool:
	_select_held = 0.0
	if selected == WEAPON:
		return false
	selected = WEAPON
	return true


func tick_selection(delta: float, charging: bool) -> bool:
	if selected == WEAPON or charging:
		return false
	_select_held += delta
	return _select_held >= SELECT_TIMEOUT


func select_left() -> float:
	if selected == WEAPON:
		return 0.0
	return clampf(1.0 - _select_held / SELECT_TIMEOUT, 0.0, 1.0)


func ultimate() -> Dictionary:
	var fill := 0.0
	var state := "charging"
	if meter != null:
		fill = float(meter.fraction())
		if meter.get("locked") == true:
			state = ACTIVE
		elif meter.full():
			state = READY
	return {"id": ultimate_id, "icon": String(ABILITIES.get(ultimate_id, {}).get("icon", "")),
		"key": Bindings.label("ultimate"), "fill": fill, "state": state}


func slot_key(name: String) -> String:
	var label: String = movement_key if name == MOVEMENT else KEYS[name]
	for verb in Bindings.VERBS:
		if Bindings.label(verb) == label:
			var glyph := Glyphs.of(verb)
			return label if glyph == Bindings.glyph(verb) else glyph
	return label


func slots() -> Array:
	var out := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		var cd := floored(s.cooldown, s.cooldown_scale)
		var frac := 0.0
		if s.charges < s.max_charges and cd > 0.0:
			frac = clampf(1.0 - s.recharge / cd, 0.0, 1.0)
		var full_charges := s.charges
		var charge_frac := 0.0
		if s.is_pressure and full_charges < s.max_charges:
			charge_frac = clampf(s.pressure_val - float(full_charges), 0.0, 1.0)
		var record := {"slot": name, "id": s.id, "icon": s.icon, "key": slot_key(name), "cooldown_frac": frac,
			"charges": full_charges, "max_charges": s.max_charges, "state": state_of(name),
			"gauge": s.gauge.fraction() if s.gauge != null else (cast_fraction() if name == casting else 0.0),
			"number": int(NUMBER.get(name, 0)), "group": "bar" if name in BAR else "chip",
			"selected": name == selected, "select_left": select_left() if name == selected else 0.0,
			"pool": pool_of(name), "refill": "contact" if ABILITIES.get(id_of(pool_of(name)), {}).has("pressure") else "time"}
		if s.is_pressure:
			record["charge_frac"] = charge_frac
		out.append(record)
	return out
