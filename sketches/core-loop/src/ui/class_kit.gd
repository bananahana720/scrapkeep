extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")

# What a pilot offers, read off its class row: the ability id in each slot names the
# icon (ability_state.gd), the slot names the key, and the movement row's augments name
# the extra keys. The class card and the controls diagram both read this, so a pilot's
# keys look and read the same on the pick and on the Tab page. Only the words, the
# fantasy line and the difficulty are written here; colour and shape stay on the row.

# Two words per ability, so one table serves the card (2 to 3 words) and the diagram
# (1 to 2 words).
const WORDS := {
	"arc_caster": "arc caster",
	"grapple": "grapple hook",
	"detonation_gauge": "arc discharge",
	"arc_slam": "arc slam",
	"crater_slam": "crater slam",
	"rapid_laser": "rapid laser",
	"overdrive_sprint": "overdrive sprint",
	"overdrive_blast": "overdrive blast",
	"point_blank": "point blank",
	"shockwave_skid": "shockwave skid",
	"sticky_charge": "sticky charges",
	"sticky_rain": "sticky rain",
	"smoke_blink": "smoke blink",
	"detonation_line": "detonation line",
	"demo_slam": "demo slam",
}

# Keys a movement kit adds, by the augment or flag that grants them. `card` marks the
# Space extras the class card shows beside the four slots.
const EXTRAS := {
	"vault": {"key": "key_space", "icon": "ab_sable_vault", "words": "vault kick", "card": true},
	"glide": {"key": "key_space", "icon": "ab_kest_glide", "words": "glide + rocket", "card": true},
	"pylon": {"key": "key_e", "icon": "ab_sable_mount", "words": "wall mount", "card": false},
	"grapple": {"key": "key_q", "icon": "ab_sable_move", "words": "winch", "card": false},
}

# DESIGN-V2 section 2's Fantasy row, cut to fit a card.
const FANTASY := {
	"pylon_engineer": "Plant a beachhead, launch like a cannonball.",
	"runner_gunner": "Unstoppable sprinter. Crowd control is fuel.",
	"demolitions_caster": "Vanish in smoke. Drop a line of fire.",
}

# 1 to 3: how many things the pilot juggles. Rivet holds sprint and fires; Kest times
# charges against a detonation line; Sable hooks, plants, mounts and slingshots.
const DIFFICULTY := {"pylon_engineer": 3, "runner_gunner": 1, "demolitions_caster": 2}
const DIFFICULTY_MAX := 3


# One record per key the pilot owns, slots first in the bar's order, then extras:
# {slot, ability, icon, key, words, card}.
static func keys(def) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null:
		return out
	for slot in AbilityState.SLOTS:
		var ability := String(def.get("%s_id" % slot))
		var row: Dictionary = AbilityState.ABILITIES.get(ability, {})
		out.append({"slot": slot, "ability": ability,
			"icon": row.get("icon", "ab_%s_%s" % [AbilitySlots.pilot_of(def), AbilitySlots.ROLES[slot]]),
			"key": "key_" + String(AbilityState.KEYS[slot]).to_lower(),
			"words": WORDS.get(ability, ability.replace("_", " ")), "card": true})
	var movement: Dictionary = AbilityState.ABILITIES.get(String(def.movement_id), {})
	for grant in movement.get("augments", []):
		if EXTRAS.has(grant):
			var extra: Dictionary = EXTRAS[grant]
			out.append({"slot": "extra", "ability": grant, "icon": extra["icon"], "key": extra["key"],
				"words": extra["words"], "card": extra["card"]})
	return out


static func card_keys(def) -> Array[Dictionary]:
	return keys(def).filter(func(k): return k["card"])


static func by_key(def) -> Dictionary:
	var out := {}
	for record in keys(def):
		out[record["key"]] = record
	return out


static func fantasy(def) -> String:
	if def == null:
		return ""
	if FANTASY.has(def.id):
		return FANTASY[def.id]
	var pitch: String = def.pitch
	var stop := pitch.find(". ")
	return pitch.left(stop + 1) if stop >= 0 else pitch


static func difficulty(def) -> int:
	return DIFFICULTY.get(def.id, 2) if def != null else 0


static func role_line(def) -> String:
	return "%s · %s" % [def.role, def.species] if def.species != "" else String(def.role)
