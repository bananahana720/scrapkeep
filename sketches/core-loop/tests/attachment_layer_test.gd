extends SceneTree

const Attachments := preload("res://src/build/attachments.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

# SQ11 Weapon-local attachment layer (W13-INTEGRATION-3.md, unit SQ11;
# comps/roboquest/weapons-and-affixes.md:95, the lab measure). Each pilot's one weapon takes
# attachments as a weapon-local layer beside the player-global parts; an attachment tier sets
# the count and the top tier adds a second fire mode, shown before equipping. BIBLE.md:552:
# the effective result is rebuilt from current selections, so removing equipment stops its
# contribution and repeated swaps add nothing by accident.
#
# DPS on a fixed dummy mirrors combat's weapon path: per-hit damage is pattern.damage times
# tuning weapon_damage (combat.gd _damage_mod), rate is pattern.rate times tuning weapon_rate
# clamped at Pattern.MAX_RATE (combat.gd _rate), times bolts per volley. The global perks are
# real catalogue parts folded through BuildSheet, the same sheet combat's tuning reads.
#
# Check count: 8 per pilot weapon (6 weapons), 10 shared checks and the count check = 59. Any other count fails.

const SAMPLES := 1000
const SEED := 1101
const SHARE_SPREAD_MAX := 0.15 # comps/roboquest/weapons-and-affixes.md:95 (d), a start value
const WEAPON_IDS := ["arc_caster", "rapid_laser", "sticky_charge", "claw_sweep", "ledger_reader", "cannon_lane"]
const DAMAGE_PERK := "slag_rounds" # parts.gd: weapon_damage x1.25 (flat punch never reaches a bolt)
const RATE_PERK := "double_feed" # parts.gd: weapon_rate x1.25
const PER_WEAPON_CHECKS := 8
const SHARED_CHECKS := 11 # ten shared checks plus the count check itself
const EXPECTED_CHECKS := PER_WEAPON_CHECKS * 6 + SHARED_CHECKS


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	return float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


static func _volley(p: Resource) -> float:
	return float(p.count) if p.arms <= 1 else 1.0 + float(p.arms) * float(p.count)


# Damage per second on a fixed dummy: mods is the sheet's tuning mods, flat a per-hit add
# used only by the control below.
static func _dps(p: Resource, mods: Dictionary, flat := 0.0) -> float:
	var damage: float = (p.damage + flat) * float(mods.get("weapon_damage", 1.0))
	var rate := minf(p.rate * float(mods.get("weapon_rate", 1.0)), Pattern.MAX_RATE)
	return damage * rate * _volley(p)


static func _same_pattern(a: Resource, b: Resource) -> bool:
	for key in Pattern.FIELDS:
		if a.get(key) != b.get(key):
			return false
	return true


static func _spread(medians: Array) -> float:
	var lo: float = medians.min()
	var hi: float = medians.max()
	return INF if lo <= 0.0 else (hi - lo) / lo


func _initialize() -> void:
	var t := T.new("attachment_layer_test")
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var damage_mods: Dictionary = BuildSheet.from_parts([DAMAGE_PERK]).mods
	var rate_mods: Dictionary = BuildSheet.from_parts([RATE_PERK]).mods
	var damage_medians: Array = []
	var rate_medians: Array = []
	var flat_medians: Array = []
	var pilot_weapons: Array = ClassDef.all().map(func(d): return String(d.weapon_id))

	print("ATTACH  weapon  samples  tier counts I/II/III/IV  attachments 0/1/2/3  median DPS  +damage perk  +rate perk")
	for wid in WEAPON_IDS:
		var base: Resource = Weapons.base(wid)
		var in_tier_range := true
		var in_count_range := true
		var top_has_mode := true
		var tiers := [0, 0, 0, 0]
		var counts := [0, 0, 0, 0]
		var dps_values: Array = []
		var damage_shares: Array = []
		var rate_shares: Array = []
		var flat_shares: Array = []
		for i in SAMPLES:
			var tier := rng.randi_range(1, Attachments.TOP_TIER)
			var loadout: Dictionary = Attachments.roll(wid, tier, rng)
			var n: int = loadout["attachments"].size()
			var limits: Array = Attachments.TIER_COUNT[tier]
			tiers[tier - 1] += 1
			if n >= 0 and n < counts.size():
				counts[n] += 1
			in_tier_range = in_tier_range and n >= int(limits[0]) and n <= int(limits[1])
			in_count_range = in_count_range and n >= Attachments.MIN_COUNT and n <= Attachments.MAX_COUNT
			if tier == Attachments.TOP_TIER:
				top_has_mode = top_has_mode and not Attachments.second_mode(loadout).is_empty() \
					and Weapons.second_mode(wid, loadout) != null
			elif Weapons.second_mode(wid, loadout) != null:
				top_has_mode = false
			var p: Resource = Weapons.base(wid, loadout)
			var bare := _dps(p, {})
			dps_values.append(bare)
			damage_shares.append(_dps(p, damage_mods) / bare - 1.0)
			rate_shares.append(_dps(p, rate_mods) / bare - 1.0)
			flat_shares.append(_dps(p, {}, 4.0) / bare - 1.0)
		damage_medians.append(_median(damage_shares))
		rate_medians.append(_median(rate_shares))
		flat_medians.append(_median(flat_shares))
		print("ATTACH  %s  %d  %s  %s  %.2f  +%.2f%%  +%.2f%%" % [wid, SAMPLES, "/".join(tiers.map(str)),
			"/".join(counts.map(str)), _median(dps_values), 100.0 * damage_medians[-1], 100.0 * rate_medians[-1]])
		t.check("%s: every sampled tier rolls a count inside its declared range" % wid, in_tier_range, str(counts))
		t.check("%s: no count outside %d to %d" % [wid, Attachments.MIN_COUNT, Attachments.MAX_COUNT], in_count_range, str(counts))
		t.check("%s: the top tier always carries its second mode, lower tiers never" % wid, top_has_mode, "")

		# Shown before equipping: the tier preview names the second mode from data alone.
		var mode: Dictionary = Attachments.SECOND_MODES.get(wid, {})
		var top_words: String = BuildReadout.preview_tier(wid, Attachments.TOP_TIER)
		t.check("%s: the top-tier preview names its second mode before equipping" % wid,
			not mode.is_empty() and top_words.contains(String(mode.get("name", "?"))) and top_words.contains("Second mode"), top_words.replace("\n", " / "))
		var low_ok := true
		for tier in range(1, Attachments.TOP_TIER):
			low_ok = low_ok and not BuildReadout.preview_tier(wid, tier).contains("Second mode")
		t.check("%s: lower-tier previews show no second mode" % wid, low_ok, "")

		# Removal is exact: random equip and unequip runs, each removal compared with a fresh
		# rebuild from the remaining list, field by field and in DPS.
		var exact := true
		var detail := ""
		for run in 200:
			var loadout: Dictionary = Attachments.empty(wid, Attachments.TOP_TIER)
			var fits: Array = Attachments.fitting(wid)
			for step in 6:
				var pick: String = fits[rng.randi_range(0, fits.size() - 1)]
				if pick in loadout["attachments"]:
					loadout = Attachments.unequip(loadout, pick)
					var fresh := Attachments.empty(wid, Attachments.TOP_TIER)
					for id in loadout["attachments"]:
						fresh = Attachments.equip(fresh, id)
					var a: Resource = Weapons.base(wid, loadout)
					var b: Resource = Weapons.base(wid, fresh)
					if not _same_pattern(a, b) or _dps(a, {}) != _dps(b, {}):
						exact = false
						detail = "run %d step %d" % [run, step]
				else:
					loadout = Attachments.equip(loadout, pick)
		t.check("%s: removing an attachment equals a fresh rebuild, exactly" % wid, exact, detail)

		var full: Dictionary = Attachments.empty(wid, Attachments.TOP_TIER)
		for id in Attachments.fitting(wid).slice(0, Attachments.MAX_COUNT):
			full = Attachments.equip(full, id)
		var stripped := full
		for id in full["attachments"]:
			stripped = Attachments.unequip(stripped, id)
		var back: Resource = Weapons.base(wid, stripped)
		t.check("%s: stripping every attachment returns base DPS exactly" % wid,
			full["attachments"].size() == Attachments.MAX_COUNT and _same_pattern(back, base) and _dps(back, {}) == _dps(base, {}),
			"%s vs %s" % [_dps(back, {}), _dps(base, {})])

		var low: Dictionary = Attachments.empty(wid, 2)
		var fits_all: Array = Attachments.fitting(wid)
		for id in fits_all.slice(0, 3):
			low = Attachments.equip(low, id)
		t.check("%s: a tier II weapon refuses attachments past its count" % wid,
			low["attachments"].size() == int(Attachments.TIER_COUNT[2][1]), str(low["attachments"]))

	var damage_spread := _spread(damage_medians)
	var rate_spread := _spread(rate_medians)
	var flat_spread := _spread(flat_medians)
	print("ATTACH  damage perk %s: median DPS share per weapon %s, spread %.4f (max %.2f)" % [DAMAGE_PERK,
		damage_medians.map(func(v): return "%.4f" % v), damage_spread, SHARE_SPREAD_MAX])
	print("ATTACH  rate perk %s: median DPS share per weapon %s, spread %.4f (max %.2f)" % [RATE_PERK,
		rate_medians.map(func(v): return "%.4f" % v), rate_spread, SHARE_SPREAD_MAX])
	print("ATTACH  control, flat +4 per hit: median DPS share per weapon %s, spread %.4f" % [
		flat_medians.map(func(v): return "%.4f" % v), flat_spread])
	t.check("damage perk changes DPS by a share within %.0f%% across weapons" % (100.0 * SHARE_SPREAD_MAX),
		damage_spread <= SHARE_SPREAD_MAX, "%.4f" % damage_spread)
	t.check("rate perk changes DPS by a share within %.0f%% across weapons" % (100.0 * SHARE_SPREAD_MAX),
		rate_spread <= SHARE_SPREAD_MAX, "%.4f" % rate_spread)
	t.check("control: a flat per-hit perk breaks the %.0f%% band, so the check can fail" % (100.0 * SHARE_SPREAD_MAX),
		flat_spread > SHARE_SPREAD_MAX, "%.4f" % flat_spread)

	var rows_ok := true
	var row_detail := ""
	for id in Attachments.ROWS:
		var row: Dictionary = Attachments.ROWS[id]
		for field in row["mods"]:
			var v = row["mods"][field]
			if not field in Pattern.FIELDS or not (v is float) or v <= 0.0:
				rows_ok = false
				row_detail = "%s.%s" % [id, field]
		for w in row["fits"]:
			if not w in WEAPON_IDS:
				rows_ok = false
				row_detail = "%s fits %s" % [id, w]
	t.check("every attachment multiplies Pattern fields by a positive factor and fits pilot weapons", rows_ok, row_detail)
	var enough := true
	for wid in WEAPON_IDS:
		enough = enough and Attachments.fitting(wid).size() >= Attachments.MAX_COUNT
	t.check("every pilot weapon has at least %d fitting attachments" % Attachments.MAX_COUNT, enough, "")
	var modes_ok := true
	for wid in pilot_weapons:
		modes_ok = modes_ok and Attachments.SECOND_MODES.has(wid)
	t.check("every pilot weapon has a second mode row", modes_ok and pilot_weapons.size() == 6, str(pilot_weapons))
	var no_price := true
	for table in [Attachments.ROWS, Attachments.SECOND_MODES, Attachments.TIER_COUNT]:
		for key in table:
			var row = table[key]
			if row is Dictionary:
				for field in row:
					if String(field) in ["price", "cost", "cogs", "color", "colour", "tint"]:
						no_price = false
	t.check("no price and no tier colour in the attachment tables", no_price, "")
	var untouched := true
	for wid in Weapons.ALL:
		untouched = untouched and _same_pattern(Weapons.base(wid), Pattern.make(Weapons.BASE[wid]))
	t.check("a weapon without attachments reads its BASE row unchanged", untouched, "")
	var foreign: Dictionary = Attachments.equip(Attachments.empty("claw_sweep", Attachments.TOP_TIER), Attachments.fitting("claw_sweep")[0])
	t.check("another weapon's loadout never changes this weapon", _same_pattern(Weapons.base("rapid_laser", foreign), Weapons.base("rapid_laser"))
		and Weapons.second_mode("rapid_laser", foreign) == null, "")

	var shown: Dictionary = Attachments.empty("rapid_laser", Attachments.TOP_TIER)
	for id in Attachments.fitting("rapid_laser").slice(0, 2):
		shown = Attachments.equip(shown, id)
	var words: String = BuildReadout.describe_attachments(shown)
	var named := true
	for id in shown["attachments"]:
		named = named and words.contains(String(Attachments.ROWS[id]["name"]))
	t.check("the build readout shows count, attachment names and second mode for an equipped weapon",
		named and words.contains("Rapid Laser: 2 of 3 attachments") and words.contains(String(Attachments.SECOND_MODES["rapid_laser"]["name"])), words.replace("\n", " / "))

	var count_ok := t.checks + 1 == EXPECTED_CHECKS
	t.check("expected check count", count_ok, "%d / EXPECTED_CHECKS=%d" % [t.checks + 1, EXPECTED_CHECKS])
	quit(t.verdict())
