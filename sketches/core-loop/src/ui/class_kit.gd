extends RefCounted

const AbilityState := preload("res://src/core/ability_state.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const Bindings := preload("res://src/core/bindings.gd")
const MetaOptions := preload("res://src/core/meta_options.gd")
const Relics := preload("res://src/build/relics.gd")


const WORDS := {
	"arc_caster": "arc caster",
	"arc_ring": "voltaic ring",
	"grapple": "harpoon",
	"detonation_gauge": "arc discharge",
	"halo_discharge": "halo discharge",
	"arc_slam": "arc slam",
	"crater_slam": "crater slam",
	"rapid_laser": "rapid laser",
	"fan_burst": "fan burst",
	"overdrive_sprint": "overdrive sprint",
	"overdrive_blast": "overdrive blast",
	"point_blank": "point blank",
	"shockwave_skid": "shockwave skid",
	"auger_slam": "auger slam",
	"sticky_charge": "sticky charges",
	"sticky_rain": "sticky rain",
	"smoke_blink": "smoke blink",
	"detonation_line": "detonation line",
	"snare_detonate": "snare detonate",
	"demo_slam": "demo slam",
	"thermite_slam": "thermite slam",
	"claw_sweep": "claw sweep",
	"claw_rake": "claw rake",
	"claw_pull": "claw pull",
	"clamp": "claw clamp",
	"rend_slam": "rend slam",
	"rend_drag": "rend drag",
	"ledger_reader": "wire-tap spike",
	"ledger_echo": "tape echo",
	"flywheel_surge": "tape-reel surge",
	"plate_return": "hostile audit",
	"stamp_slam": "card-punch slam",
	"stamp_ink": "ink punch",
	"gather_plate": "dispatch beacon",
	"link_clips": "jumper splice",
	"link_double": "double splice",
	"balance_due": "wire-tap spike",
	"cannon_lane": "cannon lane",
	"cannon_lane_walk": "walking lane",
	"cannon_recoil": "recoil split",
	"cannon_plate": "cannon plate",
	"cannon_mortar": "siege mortar",
	"cannon_rush": "rush ring",
	"cannon_rush_wake": "rush wake",
	"line_reel": "line reel",
	"ult_default": "ultimate",
	"harpoon": "harpoon line",
	"boost": "boost",
	"bank_shot": "bank shot", "bank_arc": "bank arc", "cable_run": "cable run", "ball_lightning": "ball lightning", "outpost": "outpost",
	"tradeoff_pylon_engineer": "Strong anchors, needs a surface.",
	"line_drive": "line drive", "rail_vault": "rail vault", "foundry_cutter": "foundry cutter", "prism_cutter": "prism cutter", "juggernaut_drive": "juggernaut drive",
	"tradeoff_runner_gunner": "Ignores knockback, still takes damage.",
	"cable_charge": "cable charge", "cable_cluster": "cable cluster", "windhover": "hovering mortar",
	"air_raid": "air raid", "minelayer": "minelayer",
	"tradeoff_demolitions_caster": "Delayed blasts, needs fuse timing.",
	"claw_drag": "claw drag", "claw_whirl": "claw whirl", "redjaw_rend": "redjaw rend", "rake_run": "rake run", "vice_leap": "vice leap",
	"tradeoff_tarn": "Heavy claws, must fight close.",
	"plate_audit": "audit trail", "plate_flywheel": "flywheel throw",
	"tradeoff_tally": "Big payoff, must keep rolling.",
	"cannon_lane_charge": "lane charge",
	"cannon_fire_mission": "fire mission",
	"cannon_creeping_barrage": "creeping barrage",
	"cannon_plate_mortar": "plate mortar",
	"tradeoff_remembered_cannon": "Long lanes, needs machines lined up.",
}

const EXTRAS := {
	"vault": {"verb": "jump", "icon": "ab_sable_vault", "words": "vault kick", "card": true},
	"glide": {"verb": "jump", "icon": "ab_kest_glide", "words": "glide, rocket", "card": true},
	"pylon": {"verb": "interact", "icon": "ab_sable_mount", "words": "wall mount", "card": false},
}
const SLOT_VERBS := {"weapon": "select", "special": "select", "smash": "haul", "line": "select", "ultimate": "ultimate"}
const BAR_ROW := ["weapon", "special", "line", "ultimate"]

const FANTASY := {
	"pylon_engineer": "Plant a beachhead, launch like a cannonball.",
	"runner_gunner": "Sprint through anything. Fire as you go.",
	"demolitions_caster": "Vanish in smoke. Light the line.",
	"tarn": "Claw in close. Clamp, then rend.",
	"tally": "Tap the circuit. Pull the pack. Discharge.",
	"remembered_cannon": "The Mind's guns. Call the shot.",
}

const DIFFICULTY := {"pylon_engineer": 3, "runner_gunner": 1, "demolitions_caster": 2, "tarn": 2, "tally": 3,
	"remembered_cannon": 3}
const DIFFICULTY_MAX := 3


static func keys(def) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if def == null:
		return out
	for slot in BAR_ROW:
		var ability := String(def.get("%s_id" % slot))
		var key := "key_%d" % AbilityState.NUMBER[slot] if AbilityState.NUMBER.has(slot) else Bindings.glyph(slot_verb(slot, def))
		out.append(_record(def, slot, ability, key, "bar"))
	var movement_id := String(def.movement_id)
	var movement: Dictionary = AbilityState.ABILITIES.get(movement_id, {})
	var grapple: bool = "grapple" in movement.get("augments", [])
	if grapple:
		out.append(_record(def, AbilityState.MOVEMENT, movement_id, Bindings.glyph("harpoon"), "chip"))
		out.append(_shared(def, "boost", "chip"))
	else:
		out.append(_shared(def, "harpoon", "chip"))
		out.append(_record(def, AbilityState.MOVEMENT, movement_id, Bindings.glyph("boost"), "chip"))
	out.append(_record(def, AbilityState.SMASH, String(def.smash_id), Bindings.glyph("haul"), "chip"))
	for grant in movement.get("augments", []):
		if EXTRAS.has(grant):
			var extra: Dictionary = EXTRAS[grant]
			out.append({"slot": "extra", "ability": grant, "icon": extra["icon"], "key": Bindings.glyph(extra["verb"]),
				"words": extra["words"], "card": extra["card"], "row": "extra"})
	return out


static func _record(def, slot: String, ability: String, key: String, row_name: String) -> Dictionary:
	var row: Dictionary = AbilityState.ABILITIES.get(ability, {})
	return {"slot": slot, "ability": ability,
		"icon": row.get("icon", "ab_%s_%s" % [AbilitySlots.pilot_of(def), AbilitySlots.ROLES.get(slot, slot)]),
		"key": key, "words": WORDS.get(ability, ability.replace("_", " ")), "card": true, "row": row_name}


static func _shared(_def, verb: String, row_name: String) -> Dictionary:
	return {"slot": verb, "ability": verb, "icon": Bindings.icon(verb), "key": Bindings.glyph(verb),
		"words": WORDS.get(verb, verb), "card": true, "row": row_name}


static func slot_verb(slot: String, def) -> String:
	if slot != AbilityState.MOVEMENT:
		return SLOT_VERBS[slot]
	var movement: Dictionary = AbilityState.ABILITIES.get(String(def.movement_id), {})
	return "harpoon" if "grapple" in movement.get("augments", []) else "boost"


static func card_keys(def) -> Array[Dictionary]:
	return keys(def).filter(func(k): return k["card"])


static func card_keys_for(def, profile = null, sitting := false) -> Array[Dictionary]:
	var base := card_keys(def)
	if def == null or profile == null:
		return base
	var equipped := MetaOptions.equipped_alt_loadouts(profile, String(def.id), false, sitting)
	if equipped.is_empty():
		return base
	var out: Array[Dictionary] = []
	for rec in base:
		var copy := rec.duplicate(true)
		var slot := String(copy.get("slot", ""))
		if equipped.has(slot):
			var alt_id := String(equipped[slot])
			var alt := MetaOptions.alt_loadout(alt_id)
			var relic := Relics.row(String(alt.get("relic", "")))
			var swap_id := String(relic.get("swap", ""))
			if swap_id != "":
				var ab: Dictionary = AbilityState.ABILITIES.get(swap_id, {})
				copy["ability"] = swap_id
				if ab.has("icon"):
					copy["icon"] = String(ab["icon"])
				copy["words"] = WORDS.get(swap_id, String(alt.get("name", swap_id.replace("_", " "))))
				copy["swapped"] = true
				copy["alt_id"] = alt_id
				copy["alt_name"] = String(alt.get("name", ""))
		out.append(copy)
	return out


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
	var species := String(def.species)
	return species.left(1).to_upper() + species.substr(1) if species != "" else String(def.role)


static func tradeoff(def) -> String:
	return WORDS.get("tradeoff_" + String(def.id), "") if def != null else ""
