extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Intent := preload("res://src/movement/intent.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const WeaponDriver := preload("res://src/combat/weapon_driver.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const T := preload("res://tests/support/t.gd")

# SQ10 Pilot weapon envelope (W13-INTEGRATION-3.md, unit sq10-weapon-envelope). Each pilot
# weapon is stated as an envelope of shown numbers: clip, reload and spread. The Roboquest
# note (comps/roboquest/weapons-and-affixes.md, lines 7, 42 and 79) measured the targets:
# reload barely moves between categories (category medians 1.35 to 1.55 s, 1.15x) while clip
# (5x) and spread cap (3x) separate them. Scrapkeep's mapping, one weapon per pilot, each
# its own category:
#   clip   -> the weapon slot's charges (AbilityState WEAPON max_charges; Tally's pressure)
#   reload -> the weapon slot's recharge seconds per charge (cooldown_of; Tally's rolling
#             refill, Weapons.PRESSURE_ROLL_S, because time never refills pressure)
#   spread -> the bolt radius (shown) and the aim cone: the pattern's spread_deg, and the
#             full angle one bolt covers at the weapon's range, 2 atan(bolt_radius / range)
#
# Reports now. The three target checks are asserted only once PC-PACK flips GATE_ENVELOPE;
# until then the test asserts the structure (rows exist, numbers finite, PILOTS.md carries
# an Envelope cell per pilot that quotes the code's bolt radius) and fails loud on that.

# Start values from the note, in one place (comps/roboquest/weapons-and-affixes.md:79, :95).
const RELOAD_MAX_RATIO := 1.2
const SPREAD_MIN_RATIO := 3.0
const CLIP_MIN_RATIO := 3.0
const GATE_ENVELOPE := false # PC-PACK flips this to true.
const PILOTS := ["Sable", "Rivet", "Kest", "Tarn", "Tally", "The Cannon"]
const WEAPON_IDS := ["arc_caster", "rapid_laser", "sticky_charge", "claw_sweep", "ledger_reader", "cannon_lane"]


static func _median(values: Array) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return 0.0
	return float(sorted[n / 2]) if n % 2 == 1 else (float(sorted[n / 2 - 1]) + float(sorted[n / 2])) / 2.0


# max over min, or INF when the smallest is zero and the largest is not; 1.0 when all zero.
static func _ratio(values: Array) -> float:
	var lo: float = values.min()
	var hi: float = values.max()
	if hi <= 0.0:
		return 1.0
	return INF if lo <= 0.0 else hi / lo


func _rows() -> Array:
	var rows: Array = []
	for def in ClassDef.all():
		var wid: String = def.weapon_id
		if not Weapons.BASE.has(wid):
			continue
		var a := AbilityState.new()
		a.fit(def)
		var p: Resource = Weapons.base(wid)
		var pressure: bool = AbilityState.ABILITIES.get(wid, {}).has("pressure")
		var reload: float = Weapons.PRESSURE_ROLL_S if pressure else a.cooldown_of(AbilityState.WEAPON)
		var cone := rad_to_deg(2.0 * atan(p.bolt_radius / p.range_m))
		rows.append({"pilot": String(def.display_name), "weapon": wid,
			"clip": float(a.slot(AbilityState.WEAPON).max_charges), "reload": reload,
			"bolt_radius": float(p.bolt_radius), "spread_deg": float(p.spread_deg), "cone_deg": cone,
			"rate": float(p.rate), "range_m": float(p.range_m), "pressure": pressure})
	return rows


func _initialize() -> void:
	var t := T.new("weapon_envelope_test")
	var rows := _rows()
	t.eq("one envelope row per pilot weapon", rows.size(), 6)
	var seen := {}
	for r in rows:
		seen[r["weapon"]] = true
	for wid in WEAPON_IDS:
		t.check("weapon %s has an envelope row" % wid, seen.has(wid), "")
	if rows.size() != 6:
		quit(t.verdict())
		return

	print("")
	print("ENVELOPE  pilot  weapon  clip(charges)  reload(s/charge)  bolt radius(m)  spread_deg  aim cone(deg, at range)  rate/s  range(m)")
	for r in rows:
		for k in ["clip", "reload", "bolt_radius", "spread_deg", "cone_deg", "rate", "range_m"]:
			t.check("%s %s is finite" % [r["weapon"], k], is_finite(r[k]), str(r[k]))
		t.check("%s clip is at least one charge" % r["weapon"], r["clip"] >= 1.0, str(r["clip"]))
		t.check("%s reload is not negative" % r["weapon"], r["reload"] >= 0.0, str(r["reload"]))
		t.check("%s bolt radius is positive" % r["weapon"], r["bolt_radius"] > 0.0, str(r["bolt_radius"]))
		t.check("%s aim cone is positive" % r["weapon"], r["cone_deg"] > 0.0, str(r["cone_deg"]))
		print("ENVELOPE  %s  %s  %s  %s  %s  %s  %.2f  %s  %s" % [r["pilot"], r["weapon"], r["clip"],
			r["reload"], r["bolt_radius"], r["spread_deg"], r["cone_deg"], r["rate"], r["range_m"]])

	var clips: Array = rows.map(func(r): return r["clip"])
	var reloads: Array = rows.map(func(r): return r["reload"])
	var spreads: Array = rows.map(func(r): return r["bolt_radius"])
	var cones: Array = rows.map(func(r): return r["cone_deg"])
	var reload_ratio := _ratio(reloads)
	var spread_ratio := _ratio(spreads)
	var clip_ratio := _ratio(clips)
	var reload_ok := reload_ratio <= RELOAD_MAX_RATIO
	var clip_ok := clip_ratio >= CLIP_MIN_RATIO
	var spread_ok := spread_ratio >= SPREAD_MIN_RATIO
	print("ENVELOPE  medians: clip %s, reload %s s, bolt radius %s m, aim cone %.2f deg" % [
		_median(clips), _median(reloads), _median(spreads), _median(cones)])
	print("ENVELOPE  reload medians within %sx: %s (max/min %s)" % [RELOAD_MAX_RATIO,
		"YES" if reload_ok else "NO", "inf, a zero reload" if is_inf(reload_ratio) else "%.2fx" % reload_ratio])
	print("ENVELOPE  clip medians span at least %sx: %s (max/min %s)" % [CLIP_MIN_RATIO,
		"YES" if clip_ok else "NO", "inf" if is_inf(clip_ratio) else "%.2fx" % clip_ratio])
	print("ENVELOPE  spread (bolt radius) medians span at least %sx: %s (max/min %s)" % [SPREAD_MIN_RATIO,
		"YES" if spread_ok else "NO", "inf" if is_inf(spread_ratio) else "%.2fx" % spread_ratio])
	if GATE_ENVELOPE:
		t.check("reload medians within %sx" % RELOAD_MAX_RATIO, reload_ok, str(reload_ratio))
		t.check("clip medians span at least %sx" % CLIP_MIN_RATIO, clip_ok, str(clip_ratio))
		t.check("spread medians span at least %sx" % SPREAD_MIN_RATIO, spread_ok, str(spread_ratio))

	# PILOTS.md carries the same table: an Envelope column in the roster, one cell per pilot,
	# stating clip, reload and spread and quoting the bolt radius the code holds.
	var text := FileAccess.get_file_as_string("res://design-v3/PILOTS.md")
	t.check("PILOTS.md is readable", text.length() > 0, "")
	var header := ""
	var rows_md: Dictionary = {}
	for line in text.split("\n"):
		if line.begins_with("| Pilot |") and header == "":
			header = line
		for p in PILOTS:
			if line.begins_with("| **%s**" % p) and not rows_md.has(p):
				rows_md[p] = line
	t.check("roster table has an Envelope column", header.contains("| Envelope "), header.substr(0, 40))
	t.eq("roster table has six pilot rows", rows_md.size(), 6)
	var col := -1
	var head_cells := header.split("|")
	for i in head_cells.size():
		if head_cells[i].strip_edges().begins_with("Envelope"):
			col = i
	var by_pilot := {}
	for r in rows:
		by_pilot[r["pilot"]] = r
	for p in rows_md:
		var cells: PackedStringArray = (rows_md[p] as String).split("|")
		var cell := cells[col].strip_edges() if col > 0 and col < cells.size() else ""
		t.check("%s envelope cell is filled" % p, cell != "", cell.substr(0, 50))
		for word in ["clip", "reload", "spread"]:
			t.check("%s envelope cell states %s" % [p, word], cell.contains(word), cell.substr(0, 50))
		var row: Dictionary = by_pilot.get(p.trim_prefix("The "), {})
		if row.is_empty():
			t.check("%s has a code row to quote" % p, false, "display_name differs from the roster name")
		else:
			var r: float = row["bolt_radius"]
			var radius := "%s m" % (str(int(r)) if r == floorf(r) else String.num(r))
			t.check("%s envelope cell quotes the code's bolt radius %s" % [p, radius], cell.contains(radius), cell.substr(0, 80))

	_check_cadence_envelopes(t)
	quit(t.verdict())


# PILOT-CADENCE.md §1 (Ruling ek, E1-06): numerical cadence simulation and DPS ceilings.
const SIM_DT := 0.001
const SIM_CYCLES := 20
const CEILINGS := {
	Weapons.RAPID_LASER: 75.0,
	Weapons.ARC_CASTER: 80.0,
	Weapons.PYLON_TURRET: 80.0,
}


static func ceiling_passes(weapon_id: String, dps: float) -> bool:
	return is_finite(dps) and dps <= float(CEILINGS.get(weapon_id, 0.0))


static func _simulate_rivet(pattern: Resource, skilled: bool, rate_mult := 1.0, sprinting := false) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var total_dmg := 0.0
	var total_t := 0.0
	var reloads := 0
	var was_reloading := false
	var mash_clock := 0.0
	var mash_step := 0.05
	var max_steps := 120000
	var step_idx := 0
	while reloads < SIM_CYCLES and step_idx < max_steps:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		if sprinting:
			intent.fire_held = true
			if not bool(snap["held"]):
				intent.fire_pressed = true
			if bool(snap["reloading"]) and skilled and bool(snap["window_open"]):
				intent.fire_pressed = true
		elif skilled:
			if bool(snap["reloading"]):
				if bool(snap["window_open"]):
					intent.fire_pressed = true
			elif bool(snap["ready"]):
				intent.fire_pressed = true
		else:
			if mash_clock <= 0.0:
				intent.fire_pressed = true
				mash_clock += mash_step
			mash_clock -= SIM_DT
		var shots: Array = drv.step(SIM_DT, intent, Weapons.RAPID_LASER, pattern, float(pattern.rate) * rate_mult,
			{"rate_mult": rate_mult, "sprinting": sprinting})
		if reloads >= 2:
			total_t += SIM_DT
			for s in shots:
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0))
		var now_reloading := bool(drv.state_snapshot()["reloading"])
		if not was_reloading and now_reloading:
			reloads += 1
		was_reloading = now_reloading
	return total_dmg / maxf(total_t, 0.0001)


static func _simulate_sable(weapon_id: String, pattern: Resource, mode: String, tier: int = SpeedTier.CRUISE) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var charge_rate := WeaponDriver.charge_rate_for_tier(tier)
	var total_dmg := 0.0
	var total_t := 0.0
	var cycles := 0
	var holding := false
	var max_steps := 120000
	var step_idx := 0
	while cycles < SIM_CYCLES and step_idx < max_steps:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		var cycle_end := false
		if mode == "careless":
			if bool(snap["ready"]):
				intent.fire_pressed = true
				cycle_end = true
		else:
			if holding:
				if float(snap["charge"]) >= 0.9999:
					intent.fire_released = true
					holding = false
					cycle_end = true
				else:
					intent.fire_held = true
			elif bool(snap["ready"]):
				intent.fire_pressed = true
				intent.fire_held = true
				holding = true
		var shots: Array = drv.step(SIM_DT, intent, weapon_id, pattern, float(pattern.rate),
			{"rate_mult": 1.0, "charge_rate": charge_rate})
		if cycles >= 2:
			total_t += SIM_DT
			for s in shots:
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0))
		if cycle_end:
			cycles += 1
	return total_dmg / maxf(total_t, 0.0001)


func _check_cadence_envelopes(t) -> void:
	var rivet_pat: Resource = Weapons.base(Weapons.RAPID_LASER)
	var rivet_careless := _simulate_rivet(rivet_pat, false)
	var rivet_skilled := _simulate_rivet(rivet_pat, true)
	var rivet_fan := _simulate_rivet(rivet_pat, true, 1.0, true)
	var rivet_base_dps := WeaponDriver.base_dps(rivet_pat)
	print("CADENCE_ENVELOPE  rivet  careless=%.2f  skilled=%.2f  fan=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		rivet_careless, rivet_skilled, rivet_fan, rivet_base_dps, CEILINGS[Weapons.RAPID_LASER]])
	t.near("Rivet careless simulated DPS matches PILOT-CADENCE 36.9", rivet_careless, 36.92, 0.6)
	t.near("Rivet base_dps matches careless 36.9", rivet_base_dps, 72.0 / 1.95, 0.05)
	t.near("Rivet skilled simulated DPS matches PILOT-CADENCE 62.6", rivet_skilled, 62.61, 0.6)
	t.check("Rivet sprint fan stays under ceiling and never beats skilled", rivet_fan <= rivet_skilled and ceiling_passes(Weapons.RAPID_LASER, rivet_fan),
		"fan=%.2f skilled=%.2f" % [rivet_fan, rivet_skilled])
	t.check("Rivet careless and skilled sit within ceiling 75",
		ceiling_passes(Weapons.RAPID_LASER, rivet_careless) and ceiling_passes(Weapons.RAPID_LASER, rivet_skilled),
		"careless=%.2f skilled=%.2f" % [rivet_careless, rivet_skilled])

	var sable_pat: Resource = Weapons.base(Weapons.ARC_CASTER)
	var sable_careless := _simulate_sable(Weapons.ARC_CASTER, sable_pat, "careless", SpeedTier.CRUISE)
	var sable_cruise := _simulate_sable(Weapons.ARC_CASTER, sable_pat, "skilled", SpeedTier.CRUISE)
	var sable_fast := _simulate_sable(Weapons.ARC_CASTER, sable_pat, "skilled", SpeedTier.FAST)
	var sable_blazing := _simulate_sable(Weapons.ARC_CASTER, sable_pat, "skilled", SpeedTier.BLAZING)
	var sable_base_dps := WeaponDriver.base_dps(sable_pat)
	print("CADENCE_ENVELOPE  sable  careless=%.2f  cruise=%.2f  fast=%.2f  blazing=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		sable_careless, sable_cruise, sable_fast, sable_blazing, sable_base_dps, CEILINGS[Weapons.ARC_CASTER]])
	t.near("Sable unmounted careless simulated DPS matches PILOT-CADENCE 26.7", sable_careless, 26.67, 0.6)
	t.near("Sable unmounted base_dps matches careless 26.7", sable_base_dps, 8.0 / 0.30, 0.05)
	t.near("Sable unmounted skilled cruise matches PILOT-CADENCE 45.7", sable_cruise, 45.65, 0.7)
	t.near("Sable unmounted skilled fast matches PILOT-CADENCE 59.4", sable_fast, 59.43, 0.8)
	t.near("Sable unmounted skilled blazing matches PILOT-CADENCE 70.0", sable_blazing, 70.0, 0.8)
	t.check("Sable unmounted sits within ceiling 80",
		ceiling_passes(Weapons.ARC_CASTER, sable_careless) and ceiling_passes(Weapons.ARC_CASTER, sable_blazing),
		"careless=%.2f blazing=%.2f" % [sable_careless, sable_blazing])

	var turret_pat: Resource = Weapons.base(Weapons.PYLON_TURRET)
	var turret_careless := _simulate_sable(Weapons.PYLON_TURRET, turret_pat, "careless", SpeedTier.WALK)
	var turret_walk := _simulate_sable(Weapons.PYLON_TURRET, turret_pat, "skilled", SpeedTier.WALK)
	var turret_blazing := _simulate_sable(Weapons.PYLON_TURRET, turret_pat, "skilled", SpeedTier.BLAZING)
	var turret_base_dps := WeaponDriver.base_dps(turret_pat)
	print("CADENCE_ENVELOPE  pylon_turret  careless=%.2f  after3s=%.2f  blazing3s=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		turret_careless, turret_walk, turret_blazing, turret_base_dps, CEILINGS[Weapons.PYLON_TURRET]])
	t.near("Sable mounted careless simulated DPS matches PILOT-CADENCE 30.0", turret_careless, 30.0, 0.6)
	t.near("Sable mounted base_dps matches careless 30.0", turret_base_dps, 9.0 / 0.30, 0.05)
	t.near("Sable mounted skilled after 3 s matches PILOT-CADENCE 48.9", turret_walk, 48.91, 0.7)
	t.near("Sable mounted skilled blazing 3 s matches PILOT-CADENCE 75.0", turret_blazing, 75.0, 0.8)
	t.check("Sable mounted sits within ceiling 80",
		ceiling_passes(Weapons.PYLON_TURRET, turret_careless) and ceiling_passes(Weapons.PYLON_TURRET, turret_blazing),
		"careless=%.2f blazing=%.2f" % [turret_careless, turret_blazing])

	# Planted over-ceiling failure test (PILOT-CADENCE.md §1): proves the ceiling gate bites.
	var over_rivet_pat: Resource = rivet_pat.copy()
	over_rivet_pat.damage = 16.0
	var over_rivet_dps := _simulate_rivet(over_rivet_pat, true)
	t.check("planted over-ceiling Rivet figure FAILS ceiling check",
		over_rivet_dps > CEILINGS[Weapons.RAPID_LASER] and not ceiling_passes(Weapons.RAPID_LASER, over_rivet_dps),
		"planted=%.2f ceiling=%.0f" % [over_rivet_dps, CEILINGS[Weapons.RAPID_LASER]])
	var over_sable_pat: Resource = sable_pat.copy()
	over_sable_pat.damage = 14.0
	var over_sable_dps := _simulate_sable(Weapons.ARC_CASTER, over_sable_pat, "skilled", SpeedTier.BLAZING)
	t.check("planted over-ceiling Sable figure FAILS ceiling check",
		over_sable_dps > CEILINGS[Weapons.ARC_CASTER] and not ceiling_passes(Weapons.ARC_CASTER, over_sable_dps),
		"planted=%.2f ceiling=%.0f" % [over_sable_dps, CEILINGS[Weapons.ARC_CASTER]])
	t.check("synthetic scalar above ceiling FAILS ceiling check",
		not ceiling_passes(Weapons.RAPID_LASER, 75.1) and not ceiling_passes(Weapons.ARC_CASTER, 80.1)
		and not ceiling_passes(Weapons.PYLON_TURRET, 80.1), "")
