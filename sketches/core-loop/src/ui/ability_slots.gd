extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
const Bindings := preload("res://src/core/bindings.gd")
const Glyphs := preload("res://src/ui/glyphs.gd")
const Icons := preload("res://src/ui/icons.gd")

# The ability bar's one input (CONTRACTS, Ability slots): an ordered array of slot
# records in the bar's order (design-v3/SKILL-BAR.md section 5): the numbered slots 1, 2
# and 3 (weapon, special, line skill), then the chips (movement on Shift, smash on Ctrl).
# The ball's ability state publishes them (player.abilities.slots(), W3) in its own SLOTS
# order; this puts them in the bar's and names the icon and key the way the Icons contract
# does: an icon that names no picture becomes ab_<pilot>_<role>, the pilot being the class
# row's display name, a numbered slot's key is the key its select action holds (key_1 until
# rebound), and a key label (Shift) becomes its key glyph id (key_shift).

const FIELDS := ["id", "icon", "key", "cooldown_frac", "charges", "max_charges", "state"]
const STATES := ["ready", "cooling", "active", "unavailable"]
const ROLES := {"weapon": "weapon", "movement": "move", "special": "special", "smash": "smash", "line": "line",
	"ultimate": "ult"}

var _warned := false


func slots(game) -> Array:
	var abilities = game.player.get("abilities") if game.player != null else null
	if abilities == null or not abilities.has_method("slots"):
		return []
	var by_slot := {}
	var rest := []
	for record in abilities.slots():
		var entry := normalized(record, game.run.class_def)
		if entry.has("slot"):
			by_slot[entry["slot"]] = entry
		else:
			rest.append(entry)
	var out := []
	for name in AbilityState.BAR + AbilityState.CHIPS:
		if by_slot.has(name):
			out.append(by_slot[name])
	out.append_array(rest)
	var rack = game.combat.get("actives") if game.get("combat") != null else null
	if rack != null:
		var record: Dictionary = rack.slot_record()
		if not record.is_empty():
			# The cap the active's verb shows now: F on the keyboard, D-pad down on the pad.
			record["key"] = Glyphs.of("active")
			out.append(record)
	if valid(out):
		return out
	if not _warned:
		_warned = true
		push_warning("ability_slots: the published slots are malformed; the bar stays empty")
	return []


static func normalized(record: Dictionary, def) -> Dictionary:
	var out := record.duplicate()
	var icon := String(out.get("icon", ""))
	if not (Icons.has(icon) or Icons.EXTRA.has(icon)):
		out["icon"] = "ab_%s_%s" % [pilot_of(def), ROLES.get(out.get("slot", ""), "weapon")]
	var number := int(out.get("number", 0))
	if number >= 1 and number <= Bindings.SELECT_ACTIONS.size():
		out["key"] = Glyphs.of_action(Bindings.SELECT_ACTIONS[number - 1], "key_%d" % number)
	var key := String(out.get("key", ""))
	if not (key.begins_with("key_") or key.begins_with("pad_")):
		out["key"] = "key_" + key.to_lower()
	out["gauge"] = float(out.get("gauge", 0.0))
	if out.has("charge_frac"):
		out["charge_frac"] = clampf(float(out["charge_frac"]), 0.0, 1.0)
	return out


# Q's record for the HUD: {id, icon, key, fill, state} off player.abilities.ultimate(), the
# fill 0 to 1 and the state charging, ready or active. This is the HUD's one door to the
# ultimate meter. B3 (src/core/ultimate_meter.gd) fills player.abilities.meter; until it lands,
# or with no player, the record reads empty and charging at 0, so the HUD draws an empty arc
# and no Q.
static func ultimate_of(game) -> Dictionary:
	var empty := {"id": "", "icon": "", "key": Glyphs.of("ultimate"), "fill": 0.0, "state": "charging"}
	var player = game.get("player") if game != null else null
	var abilities = player.get("abilities") if player != null else null
	if abilities == null or not abilities.has_method("ultimate"):
		return empty
	var record: Dictionary = abilities.ultimate()
	var out := empty.duplicate()
	out.merge(record, true)
	out["fill"] = clampf(float(out.get("fill", 0.0)), 0.0, 1.0)
	out["key"] = Glyphs.of("ultimate")
	return out


# The meter's fill, 0 to 1: 0.0 while no ultimate meter exists yet (B3's seam).
static func meter_fill(game) -> float:
	return float(ultimate_of(game)["fill"])


# The pilot's name in icon ids: sable, rivet, kest.
static func pilot_of(def) -> String:
	return String(def.display_name).to_lower() if def != null else ""


static func slot(id: String, icon: String, key: String, cooldown_frac: float, charges: int, max_charges: int, state: String) -> Dictionary:
	return {"id": id, "icon": icon, "key": key, "cooldown_frac": clampf(cooldown_frac, 0.0, 1.0),
		"charges": charges, "max_charges": max_charges, "state": state, "gauge": 0.0}


# The charging hold's fill, 0 to 1, for the reticle ring: the fullest gauge on the bar.
static func gauge_of(list: Array) -> float:
	var best := 0.0
	for entry in list:
		best = maxf(best, float(entry.get("gauge", 0.0)))
	return best


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
	var charge_frac_ok := true
	if entry.has("charge_frac"):
		var cf = entry["charge_frac"]
		charge_frac_ok = (cf is float or cf is int) and cf >= 0.0 and cf <= 1.0
	return entry["id"] is String and entry["id"] != "" and entry["icon"] is String and entry["key"] is String \
		and (frac is float or frac is int) and frac >= 0.0 and frac <= 1.0 and charge_frac_ok \
		and entry["charges"] is int and entry["max_charges"] is int and entry["max_charges"] >= 1 \
		and entry["charges"] >= 0 and entry["charges"] <= entry["max_charges"] and entry["state"] in STATES
