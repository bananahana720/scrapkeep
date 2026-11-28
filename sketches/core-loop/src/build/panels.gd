extends RefCounted

const Nemesis := preload("res://src/combat/nemesis.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")


const ROWS := {
	"vent_louvre": {"name": "Vent Louvre", "stat": "weapon_rate", "kind": "pct", "step": 0.05, "silhouette": "louvre",
		"sound": "panel_ratchet", "answers": ["spread"], "words": "Fire rate", "noun": "louvre"},
	"punch_rivet": {"name": "Punch Rivet", "stat": "punch", "kind": "punch", "step": 1.0, "silhouette": "rivet",
		"sound": "panel_ratchet", "answers": ["plating"], "words": "Punch", "noun": "rivet"},
	"splash_skirt": {"name": "Splash Skirt", "stat": "area_radius", "kind": "add", "step": 0.35, "silhouette": "skirt",
		"sound": "panel_ratchet", "answers": ["spread"], "words": "Slam and burst radius", "noun": "skirt"},
	"range_sight": {"name": "Range Sight", "stat": "weapon_range", "kind": "pct", "step": 0.04, "silhouette": "sight",
		"sound": "panel_ratchet", "answers": ["range"], "words": "Weapon range", "noun": "sight"},
	"fin_plate": {"name": "Fin Plate", "stat": "cruise", "kind": "pct", "step": 0.03, "silhouette": "fin",
		"sound": "panel_ratchet", "answers": ["fuse"], "words": "Cruise speed", "noun": "fin"},
	"winch_drum": {"name": "Winch Drum", "stat": "reel_speed", "kind": "pct", "step": 0.06, "silhouette": "drum",
		"sound": "panel_ratchet", "answers": ["air"], "words": "Reel speed", "noun": "drum"},
	"ratchet_collar": {"name": "Ratchet Collar", "stat": "harpoon_recovery", "kind": "pct", "step": 0.06, "silhouette": "collar",
		"sound": "panel_ratchet", "answers": ["cc"], "words": "Harpoon recovery", "noun": "collar"},
	"rope_spool": {"name": "Rope Spool", "stat": "rope_range", "kind": "pct", "step": 0.05, "silhouette": "spool",
		"sound": "panel_ratchet", "answers": ["range", "air"], "words": "Rope range", "noun": "spool"},
	"dunk_tank": {"name": "Dunk Tank", "stat": "dunk_store", "kind": "pct", "step": 0.06, "silhouette": "tank",
		"sound": "panel_ratchet", "answers": [], "words": "Stored dunk damage", "noun": "tank"},
	"ram_bumper": {"name": "Ram Bumper", "stat": "ram_force", "kind": "pct", "step": 0.05, "silhouette": "bumper",
		"sound": "panel_ratchet", "answers": ["plating"], "words": "Ram force", "noun": "bumper"},
	"hull_tile": {"name": "Hull Tile", "stat": "max_hp_bonus", "kind": "hp", "step": 5.0, "silhouette": "tile",
		"sound": "panel_ratchet", "answers": ["cc"], "words": "Max hull", "noun": "tile"},
	"cell_bracket": {"name": "Cell Bracket", "stat": "active_recharge", "kind": "pct", "step": 0.04, "silhouette": "bracket",
		"sound": "panel_ratchet", "answers": [], "words": "Active recharge", "noun": "bracket"},
}

const PANEL_MASS := 6.0

const OVERFLOW := {
	"pylon_engineer": "winch_drum",
	"runner_gunner": "punch_rivet",
	"demolitions_caster": "splash_skirt",
	"tarn": "ram_bumper",
	"tally": "dunk_tank",
	"remembered_cannon": "range_sight",
}
const OVERFLOW_DEFAULT := "hull_tile"

const DROP := {"chance": 0.07, "pity": 0.015, "elite": 1.0, "rib": 2.5, "jackpot": 2.0, "lean": 1.5}
const DROP_BY_WORLD := {
	1: {"chance": 0.32, "pity": 0.06},
	2: {"chance": DROP["chance"], "pity": DROP["pity"]},
	3: {"chance": DROP["chance"], "pity": DROP["pity"]},
}
const RIB_CACHES := 3
const NO_DROP_KINDS := ["warden", "vault", "brindle", "waking", "mind"]


static func drop_row(world: int) -> Dictionary:
	return DROP_BY_WORLD.get(world, DROP)


static func ids() -> Array:
	return ROWS.keys()


static func row(id: String) -> Dictionary:
	return ROWS.get(id, {})


static func counts(held: Array) -> Dictionary:
	var out := {}
	for id in held:
		out[id] = int(out.get(id, 0)) + 1
	return out


static func overflow_of(class_id: String) -> String:
	return OVERFLOW.get(class_id, OVERFLOW_DEFAULT)


static func louvre_room(rate: float, rate_mod: float) -> int:
	if rate <= 0.0 or rate_mod <= 0.0:
		return 0
	var need: float = Pattern.MAX_RATE / (rate * rate_mod) - 1.0
	if need <= 0.0:
		return 0
	return ceili(need / float(ROWS["vent_louvre"]["step"]) - 0.000001)


static func effective(held_counts: Dictionary, class_id: String, room: int) -> Dictionary:
	var out := held_counts.duplicate()
	var converted := 0
	var louvres := int(out.get("vent_louvre", 0))
	if room >= 0 and louvres > room:
		converted = louvres - room
		out["vent_louvre"] = room
		var to := overflow_of(class_id)
		out[to] = int(out.get(to, 0)) + converted
	return {"counts": out, "converted": converted}


static func fold(sheet, effective_counts: Dictionary) -> void:
	for id in ROWS:
		var n := int(effective_counts.get(id, 0))
		if n <= 0:
			continue
		var r: Dictionary = ROWS[id]
		var amount: float = float(r["step"]) * n
		match String(r["kind"]):
			"pct":
				sheet.mods[r["stat"]] = sheet.mods.get(r["stat"], 1.0) * (1.0 + amount)
			"add":
				sheet.adds[r["stat"]] = sheet.adds.get(r["stat"], 0.0) + amount
			"punch":
				sheet.punch += amount
				sheet.panel_punch += amount
			"hp":
				sheet.max_hp_bonus += amount


static func weapon_rate(weapon_id: String, held_parts: Array) -> float:
	if weapon_id == "" or not Weapons.BASE.has(weapon_id):
		return 0.0
	return float(Weapons.base(weapon_id).transformed(held_parts).rate)


static func draw(rng: RandomNumberGenerator, class_id: String) -> String:
	var total := 0.0
	var weights := []
	for id in ROWS:
		var w: float = DROP["lean"] if Nemesis.answers(class_id, ROWS[id]["answers"]) else 1.0
		weights.append(w)
		total += w
	var roll := rng.randf() * total
	var i := 0
	for id in ROWS:
		roll -= float(weights[i])
		if roll < 0.0:
			return id
		i += 1
	return ROWS.keys().back()


static func amount_text(id: String, n: int) -> String:
	var r := row(id)
	if r.is_empty():
		return ""
	var amount: float = float(r["step"]) * n
	match String(r["kind"]):
		"pct":
			return "+%d%%" % roundi(amount * 100.0)
		"add":
			return "+%.2f m" % amount
		"punch":
			return "+%d per hit" % roundi(amount)
	return "+%d" % roundi(amount)


static func stat_line(id: String, n: int) -> String:
	var r := row(id)
	if r.is_empty() or n <= 0:
		return ""
	return "%s %s: %d %s%s" % [r["words"], amount_text(id, n), n, r["noun"], "" if n == 1 else "s"]


static func pop_text(id: String) -> String:
	var r := row(id)
	if r.is_empty():
		return ""
	return ("%s %s %s" % [r["noun"], amount_text(id, 1), r["words"]]).to_upper()


class Dropper:
	var dry := 0
	var scale := 1.0
	var world := 1

	func reset() -> void:
		dry = 0

	func chance(elite: bool, rib: float, jackpot: bool) -> float:
		if elite:
			return clampf(float(DROP["elite"]) * scale, 0.0, 1.0)
		var row: Dictionary = DROP_BY_WORLD.get(world, DROP)
		var p: float = (float(row["chance"]) + float(row["pity"]) * dry) * rib * (float(DROP["jackpot"]) if jackpot else 1.0)
		return clampf(p * scale, 0.0, 1.0)

	func roll(rng: RandomNumberGenerator, elite: bool, rib: float, jackpot: bool) -> bool:
		var p := chance(elite, rib, jackpot)
		var hit := rng.randf() < p
		dry = 0 if hit else dry + 1
		return hit
