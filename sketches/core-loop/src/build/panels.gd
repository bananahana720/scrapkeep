extends RefCounted

const Nemesis := preload("res://src/combat/nemesis.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# Grey panels (IL-01; DECISIONS section 6 "The item ladder", Andrew 23 Oct 19:28Z): the
# ladder's bottom rung. Every kill can drop a stamped fleet plate that bolts onto the gyro
# sphere and adds one flat stat. This file is the one table: the twelve panel rows, the
# overflow row per pilot and the drop row. Retuning a panel or a drop is one number here.
#
# Panels are mass, not parts (the ladder page, "Rejected": a part adds 0.2 heft, so 55
# panels as parts would jump past class V). They live in run.panels, never in run.parts, so
# maker sets, the shop's kit share, offer weights and the parts digest never see them.
#
# Isaac as the baseline (Andrew 23 Oct 19:33Z; numbers from the Isaac wiki and modding docs,
# never decompiled code), and what this table did with each:
# - Damage = 3.5 x sqrt(1 + 1.2 x ups): each up gives less than the last. REJECTED for grey:
#   panels stay linear, so the sixtieth louvre feels like the first (Dead Cells' offence
#   rule). The diminishing curve is kept for chance effects (items.gd "hyperbolic").
# - Tears: delay = 16 - 6 x sqrt(1.3 x T + 1), capped at 5 tears a second; only rare
#   multipliers pass the cap. KEPT as a hard cap (Pattern.MAX_RATE) but TWISTED: a louvre
#   past the cap is not wasted, it converts into the pilot's signature stat (OVERFLOW).
# - Cooldowns written as recovery rates so stacks never reach zero (Isaac's tears lesson).
#   KEPT: Ratchet Collar and Cell Bracket add rate, which divides the wait.
# - Percent ups add into one sum, then multiply (Risk of Rain 2's linear items, the ladder
#   page): 5 louvres are +25%, not 1.05^5. KEPT.
# - Pools: Isaac draws from per-room pools at weight 1. TWISTED: a stat leans LEAN toward
#   the pilot's nemesis answers (the 17 Oct "still luck" matchup ruling), never a guarantee.
# - Isaac's floors toughen on a fixed schedule whatever you hold. KEPT: panels never touch
#   enemy health or damage (director honesty); a strong build only meets more crowd that
#   pays, through heft class.

# id: one stamped plate. stat: what it moves. step: per panel. kind:
#   pct    a tuning mod key; steps add into one sum, then multiply (sheet.mods)
#   add    a flat amount in its unit, through tuning.add (metres for area_radius)
#   punch  flat damage per weapon hit and ball contact (sheet.panel_punch, read by combat.gd)
#   hp     flat max health (sheet.max_hp_bonus)
# silhouette: the kit plate panel_shell.gd draws (assets/models/item_panels/panel_<silhouette>.glb).
# sound: the pickup voice, ratchet for every grey (the ladder page: "grey is a short ratchet
# tick"). answers: Nemesis axes the stat answers, for the drop lean. words: the build read's
# plain-words stat and the pickup pop's noun.
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

# Mass-equivalent heft per panel: a panel weighs what PANEL_MASS scrap weighs, in both scrap
# modes, and a hit never knocks it off. 6 makes 55 panels (the crown target) 0.73 heft, about
# half a class at the top, so heft class rises with panels and the +2 crowd per class follows
# without jumping a class on a lucky streak. A start value pinned by panels_stack_test.
const PANEL_MASS := 6.0

# Overflow (the ladder page): where a stat meets a real cap, each further panel of it becomes
# one panel of the pilot's signature stat. Fire rate is the only real cap (Pattern.MAX_RATE);
# every other stat is linear and uncapped, and cooldowns are rates. One row per pilot.
const OVERFLOW := {
	"pylon_engineer": "winch_drum", # Sable: reel
	"runner_gunner": "punch_rivet", # Rivet: punch
	"demolitions_caster": "splash_skirt", # Kest: radius
	"tarn": "ram_bumper", # Tarn, the claw bruiser: ram
	"tally": "dunk_tank", # Tally, the stamp slam: stored dunk
	"remembered_cannon": "range_sight", # Cannon: lane reach
}
const OVERFLOW_DEFAULT := "hull_tile"

# The kill-drop row (IL-01 card section 3). chance: an ordinary kill. pity: added per dry kill,
# reset on a drop. elite: an elite-pack kill. rib: kills in an off-spine dead end. jackpot: a
# reel impact or dunk kill. lean: the nemesis-answer weight against 1.0.
const DROP := {"chance": 0.07, "pity": 0.015, "elite": 1.0, "rib": 2.5, "jackpot": 2.0, "lean": 1.5}
# Per-world chance and pity over the row. World 1 gives 0 to 20 kills a stage (recorded bot
# streams, tests/fixtures/panels_w1_kills.json), so the card's 7% left about two panels a
# stage; tuned there by tests/panels_drop_sim_test.gd. Worlds 2 and 3 carry explicit card-row
# entries until their bands are tuned, and drop_row() falls back to DROP for any other world.
# 2026-10-24 Spillway roster (more packs, more kills): 0.32 and 0.06 on sixteen runs at bba75851; was 0.4, 0.08.
const DROP_BY_WORLD := {
	1: {"chance": 0.32, "pity": 0.06},
	2: {"chance": DROP["chance"], "pity": DROP["pity"]},
	3: {"chance": DROP["chance"], "pity": DROP["pity"]},
}
# Rib caches (coordinator ruling 23 Oct, "exploring pays"): panels waiting at the end of this
# many off-route dead ends a stage, each with a tall column and a chime heard from the route.
const RIB_CACHES := 3
# Kinds that never drop a panel: set pieces pay their own way.
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


# Louvres that still raise fire rate for a weapon of `rate` shots a second already scaled by
# `rate_mod` from parts: the count whose summed step first reaches the cap (it counts, even
# when it overshoots); the louvres after it overflow.
static func louvre_room(rate: float, rate_mod: float) -> int:
	if rate <= 0.0 or rate_mod <= 0.0:
		return 0
	var need: float = Pattern.MAX_RATE / (rate * rate_mod) - 1.0
	if need <= 0.0:
		return 0
	return ceili(need / float(ROWS["vent_louvre"]["step"]) - 0.000001)


# The held counts after overflow: louvres past `room` move to the pilot's signature row.
# Returns {counts, converted}. room < 0 means no cap applies.
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


# Folds effective counts into a sheet (build_sheet.gd): pct rows multiply one summed step
# into sheet.mods, add rows into sheet.adds, punch and hp rows into their flat fields.
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


# The weapon rate the overflow reads for a pilot and part list (the same transform combat
# builds its patterns with, before the tree's pattern ops).
static func weapon_rate(weapon_id: String, held_parts: Array) -> float:
	if weapon_id == "" or not Weapons.BASE.has(weapon_id):
		return 0.0
	return float(Weapons.base(weapon_id).transformed(held_parts).rate)


# One stat drawn for a drop: every row weighs 1.0, a row answering the pilot's nemesis axis
# weighs DROP.lean. One rng draw per call.
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


# A panel stack's amount in its unit: "+25%", "+1.05 m", "+3 per hit", "+15".
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


# The plain-words build read line: "Fire rate +25%: 5 louvres".
static func stat_line(id: String, n: int) -> String:
	var r := row(id)
	if r.is_empty() or n <= 0:
		return ""
	return "%s %s: %d %s%s" % [r["words"], amount_text(id, n), n, r["noun"], "" if n == 1 else "s"]


# The pickup pop: "LOUVRE +5% FIRE RATE".
static func pop_text(id: String) -> String:
	var r := row(id)
	if r.is_empty():
		return ""
	return ("%s %s %s" % [r["noun"], amount_text(id, 1), r["words"]]).to_upper()


# The kill-drop roller: one per run, its pity counter carried across stages.
class Dropper:
	var dry := 0
	var scale := 1.0
	var world := 1

	func reset() -> void:
		dry = 0

	# The chance this kill drops: elite is certain, an ordinary kill is the base plus pity,
	# scaled by the rib and jackpot multipliers and the debug drawer's scale.
	func chance(elite: bool, rib: float, jackpot: bool) -> float:
		if elite:
			return clampf(float(DROP["elite"]) * scale, 0.0, 1.0)
		var row: Dictionary = DROP_BY_WORLD.get(world, DROP)
		var p: float = (float(row["chance"]) + float(row["pity"]) * dry) * rib * (float(DROP["jackpot"]) if jackpot else 1.0)
		return clampf(p * scale, 0.0, 1.0)

	# One kill, one draw from rng. True when it drops; pity resets on a drop.
	func roll(rng: RandomNumberGenerator, elite: bool, rib: float, jackpot: bool) -> bool:
		var p := chance(elite, rib, jackpot)
		var hit := rng.randf() < p
		dry = 0 if hit else dry + 1
		return hit
