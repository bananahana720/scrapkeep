extends RefCounted

const Augments := preload("res://src/movement/augments.gd")

# The ability bar's one input (CONTRACTS, Ability slots): an ordered array of slot
# records in the bar's order: weapon (LMB), class movement (RMB), special (F) and smash
# (Ctrl), as VISUAL-LANGUAGE.md section 7 lays the bar out. When the combat module
# publishes ability_slots() the bar reads that; until it does, this adapter builds the
# same records from today's state (the special's cooldown, dash_ready, glide, the
# grapple, the mount), so the bar never learns where a fact came from.

const FIELDS := ["id", "icon", "key", "cooldown_frac", "charges", "max_charges", "state"]
const STATES := ["ready", "cooling", "active", "unavailable"]
# Today's movement ability per class; a class the table does not name glides.
const CLASS_MOVEMENT := {"pylon_engineer": "grapple", "runner_gunner": "dash"}
# The pilot each class id wears (its cls_ emblem and ab_ icons) until the class row
# carries a pilot field of its own.
const PILOTS := {"pylon_engineer": "sable", "runner_gunner": "rivet", "demolitions_caster": "kest"}

var _special_total := 0.0
var _warned := false


func slots(game) -> Array:
	var combat = game.combat
	if combat != null and combat.has_method("ability_slots"):
		var published: Array = combat.ability_slots()
		if valid(published):
			return published
		if not _warned:
			_warned = true
			push_warning("ability_slots: the published slots are malformed; showing the adapter's")
	return adapt(game)


static func slot(id: String, icon: String, key: String, cooldown_frac: float, charges: int, max_charges: int, state: String) -> Dictionary:
	return {"id": id, "icon": icon, "key": key, "cooldown_frac": clampf(cooldown_frac, 0.0, 1.0),
		"charges": charges, "max_charges": max_charges, "state": state}


static func pilot_of(def) -> String:
	if def == null:
		return ""
	var own = def.get("pilot")
	if own is String and own != "":
		return own
	return PILOTS.get(def.id, def.id)


static func valid(list: Array) -> bool:
	if list.is_empty():
		return false
	for entry in list:
		if not valid_slot(entry):
			return false
	return true


static func valid_slot(entry) -> bool:
	if not entry is Dictionary:
		return false
	for field in FIELDS:
		if not (entry as Dictionary).has(field):
			return false
	var frac = entry["cooldown_frac"]
	return entry["id"] is String and entry["id"] != "" and entry["icon"] is String and entry["key"] is String \
		and (frac is float or frac is int) and frac >= 0.0 and frac <= 1.0 \
		and entry["charges"] is int and entry["max_charges"] is int and entry["max_charges"] >= 1 \
		and entry["charges"] >= 0 and entry["charges"] <= entry["max_charges"] and entry["state"] in STATES


func adapt(game) -> Array:
	var def = game.run.class_def
	if def == null:
		return []
	var player = game.player
	var kit = player.kit
	var state = player.state
	var pilot := pilot_of(def)
	return [
		_weapon(def, pilot, player),
		_movement(CLASS_MOVEMENT.get(def.id, "glide"), pilot, game.tuning, kit, state),
		_special(def, pilot, game.combat, kit),
		_smash(pilot, kit, state),
	]


static func _weapon(def, pilot: String, player) -> Dictionary:
	var firing: bool = player.intent != null and player.intent.fire_held
	return slot(def.weapon_id, "ab_%s_weapon" % pilot, "key_lmb", 0.0, 1, 1, "active" if firing else "ready")


# The special's cooldown is combat's; its full length is learned from the largest value
# seen since it last reached zero, so no combat constant leaks into the UI.
func _special(def, pilot: String, combat, kit) -> Dictionary:
	var left := 0.0
	var live := false
	if combat != null:
		var cd = combat.get("_special_cooldown")
		left = float(cd) if cd != null else 0.0
		var overdrive = combat.get("_overdrive")
		live = overdrive != null and float(overdrive) > 0.0
	if left <= 0.0:
		_special_total = 0.0
	else:
		_special_total = maxf(_special_total, left)
	if def.id == "pylon_engineer":
		live = kit.mounted
	var frac := left / _special_total if _special_total > 0.0 else 0.0
	var shown := "active" if live else ("cooling" if left > 0.0 else "ready")
	return slot(def.special_id, "ab_%s_special" % pilot, "key_f", frac, 0 if left > 0.0 else 1, 1, shown)


static func _movement(id: String, pilot: String, tuning, kit, state) -> Dictionary:
	var icon := "ab_%s_move" % pilot
	match id:
		"grapple":
			var aim: Dictionary = kit.aim
			var shown := "active" if kit.hooked else ("ready" if aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE else "unavailable")
			return slot("grapple", icon, "key_rmb", 0.0, 1, 1, shown)
		"dash":
			var split: bool = tuning.on("split_dash_cooldown")
			var left: float = kit.dash_cooldown if split else state.boost_cooldown
			var total: float = maxf(0.001, tuning.boost_cooldown())
			var shown := "ready"
			if left > 0.0:
				shown = "cooling"
			elif not state.grounded and not kit.dash_ready:
				shown = "unavailable"
			return slot("dash", icon, "key_shift", left / total, 0 if shown != "ready" else 1, 1, shown)
	var gliding: bool = kit.gliding
	var can_glide: bool = not state.grounded and state.air_actions <= 0
	return slot("glide", "ab_%s_glide" % pilot, "key_space", 0.0, 1, 1, "active" if gliding else ("ready" if can_glide else "unavailable"))


# Ctrl slams only in the air; on the ground it brakes, so the slot reads unavailable.
static func _smash(pilot: String, kit, state) -> Dictionary:
	var shown := "active" if kit.slamming else ("unavailable" if state.grounded else "ready")
	return slot("smash", "ab_%s_smash" % pilot, "key_ctrl", 0.0, 1, 1, shown)
