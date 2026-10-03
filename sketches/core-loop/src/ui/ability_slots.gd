extends RefCounted

const Icons := preload("res://src/ui/icons.gd")

# The ability bar's one input (CONTRACTS, Ability slots): an ordered array of slot
# records in the bar's order, weapon (LMB), movement (RMB), special (F) and smash
# (Ctrl). The ball's ability state publishes them (player.abilities.slots(), W3). This
# reads that and names the icon and key the way the Icons contract does: an icon that
# is not an Icons id becomes ab_<pilot>_<role>, the pilot being the class row's
# display name, and a key label (LMB, F) becomes its key glyph id (key_lmb, key_f).

const FIELDS := ["id", "icon", "key", "cooldown_frac", "charges", "max_charges", "state"]
const STATES := ["ready", "cooling", "active", "unavailable"]
const ROLES := {"weapon": "weapon", "movement": "move", "special": "special", "smash": "smash"}

var _warned := false


func slots(game) -> Array:
	var abilities = game.player.get("abilities") if game.player != null else null
	if abilities == null or not abilities.has_method("slots"):
		return []
	var out := []
	for record in abilities.slots():
		out.append(normalized(record, game.run.class_def))
	if valid(out):
		return out
	if not _warned:
		_warned = true
		push_warning("ability_slots: the published slots are malformed; the bar stays empty")
	return []


static func normalized(record: Dictionary, def) -> Dictionary:
	var out := record.duplicate()
	if not Icons.has(String(out.get("icon", ""))):
		out["icon"] = "ab_%s_%s" % [pilot_of(def), ROLES.get(out.get("slot", ""), "weapon")]
	var key := String(out.get("key", ""))
	if not (key.begins_with("key_") or key.begins_with("pad_")):
		out["key"] = "key_" + key.to_lower()
	out["gauge"] = float(out.get("gauge", 0.0))
	return out


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
	return entry["id"] is String and entry["id"] != "" and entry["icon"] is String and entry["key"] is String \
		and (frac is float or frac is int) and frac >= 0.0 and frac <= 1.0 \
		and entry["charges"] is int and entry["max_charges"] is int and entry["max_charges"] >= 1 \
		and entry["charges"] >= 0 and entry["charges"] <= entry["max_charges"] and entry["state"] in STATES
