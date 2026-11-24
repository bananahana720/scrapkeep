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


# PILOT-CADENCE.md §1 (Ruling ek, E1-06 & E2-01): numerical cadence simulation and DPS ceilings.
const SIM_DT := 0.001
const SIM_CYCLES := 20
const CEILINGS := {
	Weapons.RAPID_LASER: 75.0,
	Weapons.ARC_CASTER: 80.0,
	Weapons.PYLON_TURRET: 80.0,
	Weapons.STICKY_CHARGE: 44.0,
	Weapons.CLAW_SWEEP: 80.0,
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


# Rivet with one reload press at `press_at` seconds into every reload and every other press at
# the floor: the sweep over `press_at` is the arithmetic bound on any press timing (section 3.1).
static func _simulate_rivet_press_at(pattern: Resource, press_at: float) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var total_dmg := 0.0
	var total_t := 0.0
	var reloads := 0
	var was_reloading := false
	var pressed_this_reload := false
	var step_idx := 0
	while reloads < 8 and step_idx < 60000:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		if bool(snap["reloading"]):
			if not pressed_this_reload and float(snap["reload_t"]) + SIM_DT * 0.5 >= press_at:
				intent.fire_pressed = true
				pressed_this_reload = true
		elif bool(snap["ready"]):
			intent.fire_pressed = true
		var shots: Array = drv.step(SIM_DT, intent, Weapons.RAPID_LASER, pattern, float(pattern.rate), {"rate_mult": 1.0})
		if reloads >= 2:
			total_t += SIM_DT
			for s in shots:
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0))
		var now_reloading := bool(drv.state_snapshot()["reloading"])
		if not was_reloading and now_reloading:
			reloads += 1
			pressed_this_reload = false
		was_reloading = now_reloading
	return total_dmg / maxf(total_t, 0.0001)


# Sable pressing on ready and letting go at charge fraction `release_at` (1.0 holds to full;
# below charge_min the release fires no bolt): the sweep is the bound over every release.
static func _simulate_sable_release_at(weapon_id: String, pattern: Resource, release_at: float, tier: int) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var charge_rate := WeaponDriver.charge_rate_for_tier(tier)
	var total_dmg := 0.0
	var total_t := 0.0
	var cycles := 0
	var holding := false
	var step_idx := 0
	while cycles < 12 and step_idx < 60000:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		var cycle_end := false
		if holding:
			var at := float(snap["charge"])
			if at + 0.00001 >= release_at or (not bool(snap["charging"]) and float(snap["hold"]) > 2.0):
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


static func _rivet_max(pattern: Resource) -> float:
	var best := 0.0
	var at := 0.0
	while at <= float(pattern.reload_s) + 0.001:
		best = maxf(best, _simulate_rivet_press_at(pattern, at))
		at += 0.02
	return best


static func _sable_max(weapon_id: String, pattern: Resource) -> float:
	var best := 0.0
	for tier in [SpeedTier.WALK, SpeedTier.CRUISE, SpeedTier.FAST, SpeedTier.BLAZING]:
		for i in 16:
			best = maxf(best, _simulate_sable_release_at(weapon_id, pattern, 0.25 + 0.05 * i, tier))
	return best


# Kest cook-and-snap simulation (PILOT-CADENCE §3.3): careless throws every floor (no snap),
# skilled throws every floor and snaps on the window's first frame for 2x damage.
static func _simulate_kest(pattern: Resource, skilled: bool, press_at := -1.0, hold_s := 0.0) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var total_dmg := 0.0
	var total_t := 0.0
	var throws := 0
	var live_charges: Array = [] # [{token, dmg, snapped}]
	var pressed_window := false
	var holding := false
	var hold_elapsed := 0.0
	var step_idx := 0
	var max_steps := 120000
	while throws < SIM_CYCLES and step_idx < max_steps:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		if holding:
			hold_elapsed += SIM_DT
			if hold_elapsed >= hold_s:
				intent.fire_released = true
				holding = false
			else:
				intent.fire_held = true
		elif bool(snap["ready"]):
			intent.fire_pressed = true
			if hold_s > 0.0:
				intent.fire_held = true
				holding = true
				hold_elapsed = 0.0
			pressed_window = false
		elif not pressed_window:
			var win := String(snap["window"])
			if press_at >= 0.0:
				if (win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN) \
						and float(snap["window_t"]) + SIM_DT * 0.5 >= press_at:
					intent.fire_pressed = true
					pressed_window = true
			elif skilled and bool(snap["window_open"]):
				intent.fire_pressed = true
				pressed_window = true
		var shots: Array = drv.step(SIM_DT, intent, Weapons.STICKY_CHARGE, pattern, float(pattern.rate))
		if throws >= 2:
			total_t += SIM_DT
		for s in shots:
			if String(s["kind"]) == WeaponDriver.SHOT_THROW:
				throws += 1
				if throws < SIM_CYCLES:
					live_charges.append({"token": int(s["token"]), "dmg": float(pattern.damage), "counted": throws >= 2, "snapped": false})
			elif String(s["kind"]) == WeaponDriver.SHOT_SNAP:
				var tok := int(s["token"])
				for c in live_charges:
					if int(c["token"]) == tok and not bool(c["snapped"]):
						c["snapped"] = true
						if bool(c["counted"]):
							total_dmg += float(c["dmg"]) * float(s["damage_mult"])
		# Plain detonation for any unsnapped charge once its window closes (or next throw begins).
		if throws >= 2:
			var keep: Array = []
			for c in live_charges:
				if bool(c["snapped"]):
					continue
				if int(c["token"]) < int(drv.state_snapshot()["snap_token"]) \
						or String(drv.state_snapshot()["window"]) == WeaponDriver.WINDOW_SPENT:
					if bool(c["counted"]):
						total_dmg += float(c["dmg"])
				else:
					keep.append(c)
			live_charges = keep
	for c in live_charges:
		if not bool(c["snapped"]) and bool(c["counted"]):
			total_dmg += float(c["dmg"])
	return total_dmg / maxf(total_t, 0.0001)


static func _kest_max(pattern: Resource) -> float:
	var best := 0.0
	for hold_s in [0.0, 0.15, 0.30]:
		var at := 0.0
		while at <= float(pattern.floor_s) + 0.001:
			best = maxf(best, _simulate_kest(pattern, false, at, hold_s))
			at += 0.05
	return best


# Tarn three-beat simulation (PILOT-CADENCE §3.4): careless mashes every 0.05 s (beats 1 & 2,
# spending the beat-3 window); skilled presses beats 1, 2, then 3 on the window's first frame.
static func _simulate_tarn(pattern: Resource, skilled: bool, speed_mps := 14.0, press_at := -1.0) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var total_dmg := 0.0
	var total_t := 0.0
	var cycles := 0
	var mash_clock := 0.0
	var mash_step := 0.05
	var pressed_b2_win := false
	var step_idx := 0
	var max_steps := 120000
	while cycles < SIM_CYCLES and step_idx < max_steps:
		step_idx += 1
		var snap: Dictionary = drv.state_snapshot()
		var intent := Intent.new()
		var beat := int(snap["beat"])
		if press_at >= 0.0:
			if beat == 2:
				if not pressed_b2_win and float(snap["window_t"]) + SIM_DT * 0.5 >= press_at:
					intent.fire_pressed = true
					pressed_b2_win = true
			elif bool(snap["ready"]):
				intent.fire_pressed = true
				pressed_b2_win = false
		elif skilled:
			if beat == 2:
				if bool(snap["window_open"]):
					intent.fire_pressed = true
			elif bool(snap["ready"]):
				intent.fire_pressed = true
		else:
			if mash_clock <= 0.0:
				intent.fire_pressed = true
				mash_clock += mash_step
			mash_clock -= SIM_DT
		var shots: Array = drv.step(SIM_DT, intent, Weapons.CLAW_SWEEP, pattern, float(pattern.rate),
			{"rate_mult": 1.0, "planar_speed": speed_mps})
		if cycles >= 2:
			total_t += SIM_DT
			for s in shots:
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0))
		for s in shots:
			if int(s.get("beat", 0)) == 1:
				cycles += 1
	return total_dmg / maxf(total_t, 0.0001)


static func _tarn_max(pattern: Resource) -> float:
	var best := 0.0
	for spd in [0.0, 14.0, 30.0, 50.0]:
		var at := 0.0
		while at <= 0.65:
			best = maxf(best, _simulate_tarn(pattern, false, spd, at))
			at += 0.05
	return best


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

	var kest_pat: Resource = Weapons.base(Weapons.STICKY_CHARGE)
	var kest_careless := _simulate_kest(kest_pat, false)
	var kest_skilled := _simulate_kest(kest_pat, true)
	var kest_base_dps := WeaponDriver.base_dps(kest_pat)
	print("CADENCE_ENVELOPE  kest  careless=%.2f  skilled=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		kest_careless, kest_skilled, kest_base_dps, CEILINGS[Weapons.STICKY_CHARGE]])
	t.near("Kest careless simulated DPS matches PILOT-CADENCE 18.3", kest_careless, 11.0 / 0.60, 0.7)
	t.near("Kest base_dps matches careless 18.3", kest_base_dps, 11.0 / 0.60, 0.05)
	t.near("Kest skilled simulated DPS matches PILOT-CADENCE 36.7", kest_skilled, 22.0 / 0.60, 0.9)
	t.check("Kest sits within ceiling 44",
		ceiling_passes(Weapons.STICKY_CHARGE, kest_careless) and ceiling_passes(Weapons.STICKY_CHARGE, kest_skilled),
		"careless=%.2f skilled=%.2f" % [kest_careless, kest_skilled])

	var tarn_pat: Resource = Weapons.base(Weapons.CLAW_SWEEP)
	var tarn_careless := _simulate_tarn(tarn_pat, false, 14.0)
	var tarn_still := _simulate_tarn(tarn_pat, true, 0.0)
	var tarn_cruise := _simulate_tarn(tarn_pat, true, 14.0)
	var tarn_cap30 := _simulate_tarn(tarn_pat, true, 30.0)
	var tarn_cap50 := _simulate_tarn(tarn_pat, true, 50.0)
	var tarn_base_dps := WeaponDriver.base_dps(tarn_pat)
	print("CADENCE_ENVELOPE  tarn  careless=%.2f  still=%.2f  cruise=%.2f  cap30=%.2f  cap50=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		tarn_careless, tarn_still, tarn_cruise, tarn_cap30, tarn_cap50, tarn_base_dps, CEILINGS[Weapons.CLAW_SWEEP]])
	t.near("Tarn careless simulated DPS matches PILOT-CADENCE 40.0", tarn_careless, 40.0, 0.8)
	t.near("Tarn base_dps matches careless 40.0", tarn_base_dps, 40.0, 0.05)
	t.near("Tarn skilled standstill matches PILOT-CADENCE 66.4", tarn_still, 66.4, 0.9)
	t.near("Tarn skilled cruise matches PILOT-CADENCE 72.0", tarn_cruise, 72.0, 0.9)
	t.near("Tarn skilled 30 m/s cap matches PILOT-CADENCE 78.4", tarn_cap30, 78.4, 0.9)
	t.near("Tarn speed bonus caps at 30 m/s (50 m/s equals 30 m/s)", tarn_cap50, tarn_cap30, 0.05)
	t.check("Tarn sits within ceiling 80",
		ceiling_passes(Weapons.CLAW_SWEEP, tarn_careless) and ceiling_passes(Weapons.CLAW_SWEEP, tarn_cap30),
		"careless=%.2f cap30=%.2f" % [tarn_careless, tarn_cap30])

	# Most by arithmetic (PILOT-CADENCE.md section 1): the best of every reload/snap/beat press time
	# and every release fraction at every speed tier. Rivet 62.6; Sable 70.0; mounted Sable 75.0;
	# Kest 36.7; Tarn 78.4.
	var rivet_max := _rivet_max(rivet_pat)
	var sable_max := _sable_max(Weapons.ARC_CASTER, sable_pat)
	var turret_max := _sable_max(Weapons.PYLON_TURRET, turret_pat)
	var kest_max := _kest_max(kest_pat)
	var tarn_max := _tarn_max(tarn_pat)
	print("CADENCE_ENVELOPE  most by arithmetic  rivet=%.2f  sable=%.2f  pylon_turret=%.2f  kest=%.2f  tarn=%.2f" % [
		rivet_max, sable_max, turret_max, kest_max, tarn_max])
	t.near("Rivet most by arithmetic matches PILOT-CADENCE 62.6", rivet_max, 62.61, 0.8)
	t.near("Sable most by arithmetic matches PILOT-CADENCE 70.0", sable_max, 70.0, 0.8)
	t.near("Sable mounted most by arithmetic matches PILOT-CADENCE 75.0", turret_max, 75.0, 0.8)
	t.near("Kest most by arithmetic matches PILOT-CADENCE 36.7", kest_max, 22.0 / 0.60, 0.9)
	t.near("Tarn most by arithmetic matches PILOT-CADENCE 78.4", tarn_max, 78.4, 0.9)
	t.check("Rivet most by arithmetic sits within ceiling 75", ceiling_passes(Weapons.RAPID_LASER, rivet_max), "%.2f" % rivet_max)
	t.check("Sable most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.ARC_CASTER, sable_max), "%.2f" % sable_max)
	t.check("Sable mounted most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.PYLON_TURRET, turret_max), "%.2f" % turret_max)
	t.check("Kest most by arithmetic sits within ceiling 44", ceiling_passes(Weapons.STICKY_CHARGE, kest_max), "%.2f" % kest_max)
	t.check("Tarn most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.CLAW_SWEEP, tarn_max), "%.2f" % tarn_max)

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
	var over_kest_pat: Resource = kest_pat.copy()
	over_kest_pat.damage = 14.0
	var over_kest_dps := _simulate_kest(over_kest_pat, true)
	t.check("planted over-ceiling Kest figure FAILS ceiling check",
		over_kest_dps > CEILINGS[Weapons.STICKY_CHARGE] and not ceiling_passes(Weapons.STICKY_CHARGE, over_kest_dps),
		"planted=%.2f ceiling=%.0f" % [over_kest_dps, CEILINGS[Weapons.STICKY_CHARGE]])
	var over_tarn_pat: Resource = tarn_pat.copy()
	over_tarn_pat.damage = 20.0
	var over_tarn_dps := _simulate_tarn(over_tarn_pat, true, 30.0)
	t.check("planted over-ceiling Tarn figure FAILS ceiling check",
		over_tarn_dps > CEILINGS[Weapons.CLAW_SWEEP] and not ceiling_passes(Weapons.CLAW_SWEEP, over_tarn_dps),
		"planted=%.2f ceiling=%.0f" % [over_tarn_dps, CEILINGS[Weapons.CLAW_SWEEP]])
	t.check("synthetic scalar above ceiling FAILS ceiling check",
		not ceiling_passes(Weapons.RAPID_LASER, 75.1) and not ceiling_passes(Weapons.ARC_CASTER, 80.1)
		and not ceiling_passes(Weapons.PYLON_TURRET, 80.1)
		and not ceiling_passes(Weapons.STICKY_CHARGE, 44.1)
		and not ceiling_passes(Weapons.CLAW_SWEEP, 80.1), "")
