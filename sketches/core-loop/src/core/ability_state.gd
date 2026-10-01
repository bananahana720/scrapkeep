extends RefCounted

# Every class ability's charges, cooldown and gauge, in the four slots the ability bar
# shows (DESIGN-V2 sections 4 and 5). Movement and combat both spend from here, and
# slots() publishes the bar in W1's ability-slot shape, so the HUD, the rules and the
# tests read one record.

const WEAPON := "weapon"
const MOVEMENT := "movement"
const SPECIAL := "special"
const SMASH := "smash"
const SLOTS := [WEAPON, MOVEMENT, SPECIAL, SMASH]
const KEYS := {WEAPON: "LMB", MOVEMENT: "RMB", SPECIAL: "F", SMASH: "Ctrl"}

const READY := "ready"
const COOLING := "cooling"
const ACTIVE := "active"
const UNAVAILABLE := "unavailable"

# No modifier may drive a cooldown below this (DESIGN-V2 section 6, risk 4).
const COOLDOWN_FLOOR := 0.4
# A skill shot draws exactly its committed geometry; the hit test forgives a hull this
# share beyond the drawn edge, so what you see is never bigger than what can hit.
const FORGIVENESS := 0.18

# One row per ability id; the class row names which id fills each slot, and an upgrade
# swaps a slot to a variant row. The rest of the game dispatches on a row's
# capabilities, never on its id, so a variant is one row here plus, when it plays
# differently, one entry in the owning dispatch table (combat's _specials, the ball's
# SMASHES). icon is the canonical id in assets/icons (VISUAL-LANGUAGE section 5).
# cooldown is per charge. charge_max > 0 makes the slot a hold-gauge-release shot.
# duration is how long an active ability runs on one charge.
#   weapon    pattern (the Pattern it fires, default its id), mounted (the weapon it
#             becomes on a pylon), lob (how many sticky charges one throw scatters)
#   movement  augments (the movement kit it fits), rocket, cloak (Kest's passives)
#   special   plant_discharge (planting a pylon fires it free)
#   smash     flavour (arc, skid or demo landing), spends_special
const ABILITIES := {
	"arc_caster": {"icon": "ab_sable_weapon", "cooldown": 0.0, "mounted": "pylon_turret"},
	"grapple": {"icon": "ab_sable_move", "cooldown": 0.0, "augments": ["grapple", "pylon", "vault"]},
	"detonation_gauge": {"icon": "ab_sable_special", "cooldown": 5.0, "charge_max": 1.0, "plant_discharge": true},
	"arc_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc"},
	"crater_slam": {"icon": "ab_sable_smash", "cooldown": 0.0, "flavour": "arc", "spends_special": true},
	"rapid_laser": {"icon": "ab_rivet_weapon", "cooldown": 0.0},
	"overdrive_sprint": {"icon": "ab_rivet_move", "cooldown": 5.0, "duration": 2.0, "augments": ["sprint"]},
	"overdrive_blast": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"point_blank": {"icon": "ab_rivet_special", "cooldown": 6.0, "charge_max": 1.0},
	"shockwave_skid": {"icon": "ab_rivet_smash", "cooldown": 0.0, "flavour": "skid"},
	"sticky_charge": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 1},
	"sticky_rain": {"icon": "ab_kest_weapon", "cooldown": 0.6, "charge_max": 0.6, "lob": 3, "pattern": "sticky_charge"},
	"smoke_blink": {"icon": "ab_kest_move", "cooldown": 4.0, "augments": ["blink", "glide"], "rocket": true, "cloak": true},
	"detonation_line": {"icon": "ab_kest_special", "cooldown": 6.0, "charge_max": 0.8},
	"demo_slam": {"icon": "ab_kest_smash", "cooldown": 0.0, "flavour": "demo"},
}
const ICON_DIR := "res://assets/icons/"


# The one hold-gauge-release rule. Hold fills the gauge linearly over charge_max; the
# key coming up fires at the fraction reached, and a gauge held full fires by itself
# GRACE seconds later. Cancelling leaves nothing spent and nothing fired.
class Gauge:
	extends RefCounted

	const GRACE := 0.5

	var charge_max := 1.0
	var charging := false
	var held := 0.0
	# The fraction the last shot left at, and whether the grace fired it.
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

	# One tick of the key. True on the tick the shot goes. Only ticks with the key down
	# fill the gauge, so a tap fires at exactly the floor.
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

	# True when there was a charge to drop.
	func cancel() -> bool:
		var was := charging
		charging = false
		held = 0.0
		return was

	# A shot's size from a floor, so a tap still does something.
	static func scaled(f: float, floor_value: float, full_value: float) -> float:
		return lerpf(floor_value, full_value, clampf(f, 0.0, 1.0))


class Slot:
	extends RefCounted

	var id := ""
	var icon := ""
	var cooldown := 0.0
	var cooldown_scale := 1.0
	var duration := 0.0
	var max_charges := 1
	var charges := 1
	# Seconds into the charge now recharging.
	var recharge := 0.0
	var active := false
	var available := true
	var gauge: Gauge = null
	# What the item layer (item_effects.apply_abilities) last added on top: extra charges
	# and its cooldown multiplier. Upgrade-tree picks add to the same cap and scale, so
	# items re-apply as a delta and never overwrite a pick.
	var item_charges := 0
	var item_scale := 1.0


# The key the movement slot shows: RMB, or under --harpoon Shift or C for a pilot whose
# movement is not the rope (player_ball sets it).
var movement_key := KEYS[MOVEMENT]
var _slots := {}


func _init() -> void:
	for name in SLOTS:
		_slots[name] = Slot.new()


# Fills the four slots from a class row. Charges start full; a stage entry refills them.
func fit(def) -> void:
	var ids := {WEAPON: "", MOVEMENT: "", SPECIAL: "", SMASH: ""}
	if def != null:
		ids = {WEAPON: def.weapon_id, MOVEMENT: def.movement_id, SPECIAL: def.special_id, SMASH: def.smash_id}
	for name in SLOTS:
		_slots[name] = Slot.new()
		swap(name, ids[name])


# Puts ability `id` in a slot, full, with its row's cooldown, duration and gauge. The
# slot's stockpile cap and cooldown scale stay: items and picks raise the slot, not the
# ability in it, so an upgrade swap never drops a charge upgrade bought earlier.
func swap(name: String, id: String) -> void:
	var row: Dictionary = ABILITIES.get(id, {})
	var old: Slot = _slots[name]
	var s := Slot.new()
	s.max_charges = old.max_charges
	s.charges = old.max_charges
	s.cooldown_scale = old.cooldown_scale
	s.item_charges = old.item_charges
	s.item_scale = old.item_scale
	s.id = id
	s.icon = row.get("icon", "")
	s.cooldown = row.get("cooldown", 0.0)
	s.duration = row.get("duration", 0.0)
	var charge_max: float = row.get("charge_max", 0.0)
	if charge_max > 0.0:
		s.gauge = Gauge.new(charge_max)
	_slots[name] = s


# A capability of the ability in a slot (see ABILITIES), or `fallback`.
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


func ready(name: String) -> bool:
	var s: Slot = _slots[name]
	return s.available and s.charges > 0


func spend(name: String) -> bool:
	if not ready(name):
		return false
	(_slots[name] as Slot).charges -= 1
	return true


# The stomp and rebound refresh: one charge back, never past the cap.
func grant(name: String, count := 1) -> void:
	var s: Slot = _slots[name]
	s.charges = mini(s.max_charges, s.charges + count)
	if s.charges == s.max_charges:
		s.recharge = 0.0


# Moves the recharging charge along by this many seconds (the skid's refund).
func refund(name: String, seconds: float) -> void:
	_recharge(_slots[name], seconds)


func refill() -> void:
	for name in SLOTS:
		var s: Slot = _slots[name]
		s.charges = s.max_charges
		s.recharge = 0.0
		s.active = false
		if s.gauge != null:
			s.gauge.cancel()


# Items raise charges; charges above the new cap are dropped, never kept.
func set_max_charges(name: String, count: int) -> void:
	var s: Slot = _slots[name]
	s.max_charges = maxi(1, count)
	s.charges = mini(s.charges, s.max_charges)


func set_cooldown_scale(name: String, scale: float) -> void:
	(_slots[name] as Slot).cooldown_scale = maxf(0.0, scale)


func tick(delta: float) -> void:
	for name in SLOTS:
		_recharge(_slots[name], delta)


# One charge at a time: time only ever fills the charge now recharging.
func _recharge(s: Slot, seconds: float) -> void:
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
	if s.charges >= s.max_charges:
		s.recharge = 0.0


func charging() -> bool:
	for name in SLOTS:
		var g: Gauge = (_slots[name] as Slot).gauge
		if g != null and g.charging:
			return true
	return false


# Drops every charging gauge; returns the ability ids that were charging.
func cancel_gauges() -> Array:
	var dropped := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		if s.gauge != null and s.gauge.cancel():
			dropped.append(s.id)
	return dropped


func state_of(name: String) -> String:
	var s: Slot = _slots[name]
	if not s.available:
		return UNAVAILABLE
	if s.active or (s.gauge != null and s.gauge.charging):
		return ACTIVE
	return READY if s.charges > 0 else COOLING


# W1's Ability slots contract: one record per slot, in bar order. cooldown_frac is the
# share of the recharging charge still to go, 0 when every charge is in.
func slots() -> Array:
	var out := []
	for name in SLOTS:
		var s: Slot = _slots[name]
		var cd := floored(s.cooldown, s.cooldown_scale)
		var frac := 0.0
		if s.charges < s.max_charges and cd > 0.0:
			frac = clampf(1.0 - s.recharge / cd, 0.0, 1.0)
		out.append({"slot": name, "id": s.id, "icon": s.icon, "key": movement_key if name == MOVEMENT else KEYS[name], "cooldown_frac": frac,
			"charges": s.charges, "max_charges": s.max_charges, "state": state_of(name),
			"gauge": s.gauge.fraction() if s.gauge != null else 0.0})
	return out
