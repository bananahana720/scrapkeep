extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Intent := preload("res://src/movement/intent.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
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


# PILOT-CADENCE.md §1 (Ruling ek, E1-06, E2-01, E2-02): numerical cadence simulation and DPS ceilings.
const SIM_DT := 0.001
const SIM_CYCLES := 20
const TALLY_BURST_KEY := "ledger_reader_burst_1s"
const CEILINGS := {
	Weapons.RAPID_LASER: 75.0,
	Weapons.ARC_CASTER: 80.0,
	Weapons.PYLON_TURRET: 80.0,
	Weapons.STICKY_CHARGE: 44.0,
	Weapons.CLAW_SWEEP: 80.0,
	Weapons.LEDGER_READER: 30.0,
	TALLY_BURST_KEY: 80.0,
	Weapons.CANNON_LANE: 50.0,
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
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0)) * float(s.get("spark_count", 1))
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
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0)) * float(s.get("spark_count", 1))
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
					var throw_dmg := float(pattern.damage) * float(maxi(int(pattern.count), 1))
					live_charges.append({"token": int(s["token"]), "dmg": throw_dmg, "counted": throws >= 2, "snapped": false})
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
				total_dmg += float(pattern.damage) * float(s.get("damage_mult", 1.0)) * float(s.get("spark_count", 1))
		for s in shots:
			if int(s.get("beat", 0)) == 1:
				cycles += 1
	return total_dmg / maxf(total_t, 0.0001)


static func _tarn_max(pattern: Resource) -> float:
	var best := 0.0
	for spd in [0.0, 14.0, 30.0, 50.0]:
		var at := 0.0
		while at <= 0.75:
			best = maxf(best, _simulate_tarn(pattern, false, spd, at))
			at += 0.05
	return best


# Tally stamp simulation (PILOT-CADENCE.md §3.5): fractional pressure (cap 3.0, continuous 0.5/s
# refill, 1e-4 spend tolerance). Returns {sustained, burst_1s} where burst_1s counts both ends
# of any 1.0 s closed span [t, t + 1.0].
static func _simulate_tally(pattern: Resource, mode: String, press_at := -1.0, start_pressure := 3.0) -> Dictionary:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
	var pressure := start_pressure
	var max_p := 3.0
	var refill_per_s := 1.0 / Weapons.PRESSURE_ROLL_S
	var cost: float = maxf(float(pattern.cast_cost), Pattern.MIN_CAST_COST)
	var hits: Array = [] # [[time_s, dmg]]
	var t_now := 0.0
	var sim_s := 35.0
	var mash_clock := 0.0
	var mash_step := 0.05
	var pressed_win := false
	var waiting_refill := false
	var step_count := int(round(sim_s / SIM_DT))
	for _step in step_count:
		pressure = minf(max_p, pressure + refill_per_s * SIM_DT)
		var snap: Dictionary = drv.state_snapshot()
		var win := String(snap["window"])
		var intent := Intent.new()
		if mode == "careless":
			if mash_clock <= 0.0 and pressure + AbilityState.PRESSURE_EPS >= cost:
				intent.fire_pressed = true
				mash_clock += mash_step
			mash_clock -= SIM_DT
		elif mode == "chain_open" or mode == "chain_close":
			if waiting_refill:
				if pressure + AbilityState.PRESSURE_EPS >= max_p:
					waiting_refill = false
			if not waiting_refill:
				if win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN:
					var target_t: float = float(pattern.window_s.x) if mode == "chain_open" else float(pattern.window_s.y) - SIM_DT
					if float(snap["window_t"]) + SIM_DT * 1.1 >= target_t:
						if pressure + AbilityState.PRESSURE_EPS >= cost:
							intent.fire_pressed = true
						else:
							waiting_refill = true
				elif bool(snap["ready"]) and pressure + AbilityState.PRESSURE_EPS >= cost:
					intent.fire_pressed = true
		elif mode == "max_burst":
			if win == WeaponDriver.WINDOW_OPEN:
				if pressure + AbilityState.PRESSURE_EPS >= cost:
					intent.fire_pressed = true
			elif win == WeaponDriver.WINDOW_IDLE and bool(snap["ready"]) and pressure + AbilityState.PRESSURE_EPS >= cost:
				intent.fire_pressed = true
		elif press_at >= 0.0:
			if win == WeaponDriver.WINDOW_WAITING or win == WeaponDriver.WINDOW_OPEN:
				if not pressed_win and float(snap["window_t"]) + SIM_DT * 0.5 >= press_at \
						and pressure + AbilityState.PRESSURE_EPS >= cost:
					intent.fire_pressed = true
					pressed_win = true
			elif bool(snap["ready"]) and pressure + AbilityState.PRESSURE_EPS >= cost:
				intent.fire_pressed = true
				pressed_win = false
		var shots: Array = drv.step(SIM_DT, intent, Weapons.LEDGER_READER, pattern, 0.0,
			{"managed_commit": true, "slot_ready": pressure + AbilityState.PRESSURE_EPS >= cost})
		for s in shots:
			var scost: float = maxf(float(s["cast_cost"]), Pattern.MIN_CAST_COST)
			if pressure + AbilityState.PRESSURE_EPS < scost:
				continue
			pressure = maxf(0.0, pressure - scost)
			var is_paid: bool = bool(s["paid"])
			drv.commit_stamp(is_paid, 1.0)
			if is_paid:
				var ref: float = clampf(float(s["refund"]), 0.0, scost)
				pressure = minf(max_p, pressure + ref)
			var dmg: float = float(pattern.damage) * float(s["damage_mult"])
			if float(s.get("streak_bonus", 0.0)) > 0.0:
				dmg += float(s["streak_bonus"])
				if float(s.get("streak_cap", 0.0)) > 0.0:
					dmg = minf(dmg, float(s["streak_cap"]))
			hits.append([t_now, dmg])
			pressed_win = false
		t_now += SIM_DT
	# Sustained DPS over steady-state tail (skip first 7.0 s so initial full bar does not bias upward).
	var tail_start := 7.0
	var tail_dmg := 0.0
	for h in hits:
		if float(h[0]) >= tail_start:
			tail_dmg += float(h[1])
	var sustained := tail_dmg / maxf(sim_s - tail_start, 0.001)
	# Most damage in any closed 1.0 s span [t_i, t_i + 1.0] (both endpoints included, §3.5).
	var best_1s := 0.0
	for i in hits.size():
		var t0: float = float(hits[i][0])
		var span_dmg := 0.0
		for j in range(i, hits.size()):
			if float(hits[j][0]) <= t0 + 1.0 + 0.0005:
				span_dmg += float(hits[j][1])
			else:
				break
		best_1s = maxf(best_1s, span_dmg)
	return {"sustained": sustained, "burst_1s": best_1s}


# Cannon lock simulation (PILOT-CADENCE.md §3.6): release at `release_at` seconds of hold.
static func _simulate_cannon(pattern: Resource, release_at: float) -> float:
	var drv := WeaponDriver.new()
	drv.reset(pattern)
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
		var ended := false
		if holding:
			if float(snap["hold"]) + SIM_DT * 0.5 >= release_at:
				intent.fire_released = true
				holding = false
				ended = true
			else:
				intent.fire_held = true
		elif bool(snap["ready"]):
			intent.fire_pressed = true
			if release_at <= SIM_DT * 0.5:
				ended = true
			else:
				intent.fire_held = true
				holding = true
		var shots: Array = drv.step(SIM_DT, intent, Weapons.CANNON_LANE, pattern, float(pattern.rate))
		if cycles >= 2:
			total_t += SIM_DT
			for s in shots:
				total_dmg += float(s["damage"])
		if ended:
			cycles += 1
	return total_dmg / maxf(total_t, 0.0001)


static func _cannon_max(pattern: Resource) -> float:
	var best := 0.0
	var at := 0.0
	while at <= 0.80:
		best = maxf(best, _simulate_cannon(pattern, at))
		at += 0.02
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

	var tally_pat: Resource = Weapons.base(Weapons.LEDGER_READER)
	var tally_careless := _simulate_tally(tally_pat, "careless")
	var tally_open := _simulate_tally(tally_pat, "chain_open")
	var tally_close := _simulate_tally(tally_pat, "chain_close")
	var tally_base_dps := WeaponDriver.base_dps(tally_pat)
	var tally_net_cost: float = maxf(float(tally_pat.cast_cost) - minf(float(tally_pat.refund), float(tally_pat.cast_cost)), 0.0001)
	var tally_max_sustained: float = (float(tally_pat.damage) * float(tally_pat.window_mult)) * (1.0 / Weapons.PRESSURE_ROLL_S) / tally_net_cost
	var tally_max_burst: float = float(tally_open["burst_1s"])
	print("CADENCE_ENVELOPE  tally  careless=%.2f (1s=%.1f)  skilled_open=%.2f  skilled_close=%.2f  max_sust=%.2f  max_1s=%.1f  base_dps=%.2f  ceilings=%.0f/%.0f" % [
		float(tally_careless["sustained"]), float(tally_careless["burst_1s"]),
		float(tally_open["sustained"]), float(tally_close["sustained"]),
		tally_max_sustained, tally_max_burst, tally_base_dps,
		CEILINGS[Weapons.LEDGER_READER], CEILINGS[TALLY_BURST_KEY]])
	t.near("Tally careless sustained DPS matches PILOT-CADENCE 11.0", float(tally_careless["sustained"]), 11.0, 0.8)
	t.near("Tally base_dps matches careless sustained 11.0", tally_base_dps, 11.0, 0.05)
	t.near("Tally careless 1s burst matches PILOT-CADENCE 66.0", float(tally_careless["burst_1s"]), 66.0, 0.2)
	t.near("Tally skilled chain (window open) sits near PILOT-CADENCE 22.0", float(tally_open["sustained"]), 22.0, 1.4)
	t.near("Tally skilled chain (window close) sits near PILOT-CADENCE 23.0", float(tally_close["sustained"]), 23.0, 1.4)
	t.near("Tally most by arithmetic sustained matches PILOT-CADENCE 26.4", tally_max_sustained, 26.4, 0.05)
	t.near("Tally most in any 1s (both endpoints) matches PILOT-CADENCE 79.2", tally_max_burst, 79.2, 0.2)
	t.check("Tally sustained and 1s burst sit within ceilings 30 and 80",
		ceiling_passes(Weapons.LEDGER_READER, float(tally_careless["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, float(tally_open["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, tally_max_sustained)
		and ceiling_passes(TALLY_BURST_KEY, float(tally_careless["burst_1s"]))
		and ceiling_passes(TALLY_BURST_KEY, tally_max_burst),
		"sust=%.2f burst=%.1f" % [tally_max_sustained, tally_max_burst])
	# Direct invariant test: Tally refund can NEVER exceed spend (Pattern clamp + runtime).
	var bad_refund_pat: Resource = tally_pat.copy()
	bad_refund_pat.cast_cost = 0.5
	bad_refund_pat.refund = 1.5
	bad_refund_pat._clamp()
	t.check("Tally refund <= cast_cost holds on Pattern clamp and base row",
		float(tally_pat.refund) <= float(tally_pat.cast_cost)
		and float(bad_refund_pat.refund) <= float(bad_refund_pat.cast_cost),
		"base=%.2f/%.2f clamped=%.2f/%.2f" % [tally_pat.refund, tally_pat.cast_cost, bad_refund_pat.refund, bad_refund_pat.cast_cost])

	var cannon_pat: Resource = Weapons.base(Weapons.CANNON_LANE)
	var cannon_careless := _simulate_cannon(cannon_pat, 0.0)
	var cannon_late := _simulate_cannon(cannon_pat, 0.60)
	var cannon_skilled := _simulate_cannon(cannon_pat, 0.30)
	var cannon_last_frame := _simulate_cannon(cannon_pat, 0.46)
	var cannon_base_dps := WeaponDriver.base_dps(cannon_pat)
	print("CADENCE_ENVELOPE  cannon  careless=%.2f  late=%.2f  skilled=%.2f  last_frame=%.2f  base_dps=%.2f  ceiling=%.0f" % [
		cannon_careless, cannon_late, cannon_skilled, cannon_last_frame, cannon_base_dps, CEILINGS[Weapons.CANNON_LANE]])
	t.near("Cannon careless Pulse tapping matches PILOT-CADENCE 22.9", cannon_careless, 16.0 / 0.70, 0.6)
	t.near("Cannon careless late Barrage matches PILOT-CADENCE 20.0", cannon_late, 26.0 / 1.30, 0.6)
	t.near("Cannon base_dps matches careless 22.86", cannon_base_dps, 16.0 / 0.70, 0.05)
	t.near("Cannon skilled Rail matches PILOT-CADENCE 42.0", cannon_skilled, 42.0, 0.7)
	t.near("Cannon last-frame Rail matches PILOT-CADENCE 36.2", cannon_last_frame, 42.0 / 1.16, 0.7)
	t.check("Cannon sits within ceiling 50",
		ceiling_passes(Weapons.CANNON_LANE, cannon_careless) and ceiling_passes(Weapons.CANNON_LANE, cannon_skilled),
		"careless=%.2f skilled=%.2f" % [cannon_careless, cannon_skilled])

	# Most by arithmetic (PILOT-CADENCE.md section 1): the best of every reload/snap/beat/lock timing
	# and every release fraction at every speed tier. Rivet 62.6; Sable 70.0; mounted Sable 75.0;
	# Kest 36.7; Tarn 78.4; Tally 26.4 sustained / 79.2 in 1s; Cannon 42.0.
	var rivet_max := _rivet_max(rivet_pat)
	var sable_max := _sable_max(Weapons.ARC_CASTER, sable_pat)
	var turret_max := _sable_max(Weapons.PYLON_TURRET, turret_pat)
	var kest_max := _kest_max(kest_pat)
	var tarn_max := _tarn_max(tarn_pat)
	var cannon_max := _cannon_max(cannon_pat)
	print("CADENCE_ENVELOPE  most by arithmetic  rivet=%.2f  sable=%.2f  pylon_turret=%.2f  kest=%.2f  tarn=%.2f  tally=%.2f/%.1f  cannon=%.2f" % [
		rivet_max, sable_max, turret_max, kest_max, tarn_max, tally_max_sustained, tally_max_burst, cannon_max])
	t.near("Rivet most by arithmetic matches PILOT-CADENCE 62.6", rivet_max, 62.61, 0.8)
	t.near("Sable most by arithmetic matches PILOT-CADENCE 70.0", sable_max, 70.0, 0.8)
	t.near("Sable mounted most by arithmetic matches PILOT-CADENCE 75.0", turret_max, 75.0, 0.8)
	t.near("Kest most by arithmetic matches PILOT-CADENCE 36.7", kest_max, 22.0 / 0.60, 0.9)
	t.near("Tarn most by arithmetic matches PILOT-CADENCE 78.4", tarn_max, 78.4, 0.9)
	t.near("Cannon most by arithmetic matches PILOT-CADENCE 42.0", cannon_max, 42.0, 0.7)
	t.check("Rivet most by arithmetic sits within ceiling 75", ceiling_passes(Weapons.RAPID_LASER, rivet_max), "%.2f" % rivet_max)
	t.check("Sable most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.ARC_CASTER, sable_max), "%.2f" % sable_max)
	t.check("Sable mounted most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.PYLON_TURRET, turret_max), "%.2f" % turret_max)
	t.check("Kest most by arithmetic sits within ceiling 44", ceiling_passes(Weapons.STICKY_CHARGE, kest_max), "%.2f" % kest_max)
	t.check("Tarn most by arithmetic sits within ceiling 80", ceiling_passes(Weapons.CLAW_SWEEP, tarn_max), "%.2f" % tarn_max)
	t.check("Cannon most by arithmetic sits within ceiling 50", ceiling_passes(Weapons.CANNON_LANE, cannon_max), "%.2f" % cannon_max)

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
	var over_tally_pat: Resource = tally_pat.copy()
	over_tally_pat.damage = 32.0
	var over_tally_sim := _simulate_tally(over_tally_pat, "chain_open")
	t.check("planted over-ceiling Tally sustained & 1s burst BOTH FAIL ceiling checks",
		float(over_tally_sim["sustained"]) > CEILINGS[Weapons.LEDGER_READER]
		and not ceiling_passes(Weapons.LEDGER_READER, float(over_tally_sim["sustained"]))
		and float(over_tally_sim["burst_1s"]) > CEILINGS[TALLY_BURST_KEY]
		and not ceiling_passes(TALLY_BURST_KEY, float(over_tally_sim["burst_1s"])),
		"planted sust=%.2f burst=%.1f" % [float(over_tally_sim["sustained"]), float(over_tally_sim["burst_1s"])])
	var over_cannon_pat: Resource = cannon_pat.copy()
	over_cannon_pat.lock_rail_damage = 56.0
	var over_cannon_dps := _simulate_cannon(over_cannon_pat, 0.30)
	t.check("planted over-ceiling Cannon figure FAILS ceiling check",
		over_cannon_dps > CEILINGS[Weapons.CANNON_LANE] and not ceiling_passes(Weapons.CANNON_LANE, over_cannon_dps),
		"planted=%.2f ceiling=%.0f" % [over_cannon_dps, CEILINGS[Weapons.CANNON_LANE]])
	t.check("synthetic scalar above ceiling FAILS ceiling check",
		not ceiling_passes(Weapons.RAPID_LASER, 75.1) and not ceiling_passes(Weapons.ARC_CASTER, 80.1)
		and not ceiling_passes(Weapons.PYLON_TURRET, 80.1)
		and not ceiling_passes(Weapons.STICKY_CHARGE, 44.1)
		and not ceiling_passes(Weapons.CLAW_SWEEP, 80.1)
		and not ceiling_passes(Weapons.LEDGER_READER, 30.1)
		and not ceiling_passes(TALLY_BURST_KEY, 80.1)
		and not ceiling_passes(Weapons.CANNON_LANE, 50.1), "")

	_check_depth1_keystone_envelopes(t)


static func _keystone_pattern(t, class_id: String, node_id: String, weapon_id: String) -> Resource:
	var tree := UpgradeTree.new()
	tree.world_one = true
	tree.max_depth = UpgradeTree.WORLD_ONE_DEPTHS
	tree.reset(class_id)
	tree.open_checkpoint()
	var picked := tree.pick(node_id)
	t.check("Depth-1 keystone %s is pickable on %s" % [node_id, class_id], picked, "offered %s" % [tree.offered(class_id, 1).map(func(n): return n["id"])])
	var pat: Resource = Weapons.base(weapon_id).copy()
	for op in tree.pattern_ops(weapon_id):
		pat._apply(op)
	pat._clamp()
	return pat


# PILOT-CADENCE.md §6.1 (E2-09): all 12 Depth-1 keystones (14 rows including mounted Sable) stay
# strictly under their pilot ceilings and match the documented careless / skilled / max targets.
func _check_depth1_keystone_envelopes(t) -> void:
	# 1-2. Rivet: Fan the Hammer & Big Iron (ceiling 75).
	var fan_pat := _keystone_pattern(t, "runner_gunner", "r_fan_hammer", Weapons.RAPID_LASER)
	var fan_careless := _simulate_rivet(fan_pat, false)
	var fan_skilled := _simulate_rivet(fan_pat, true)
	var fan_max := _rivet_max(fan_pat)
	print("KEYSTONE_ENVELOPE  r_fan_hammer  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		fan_careless, fan_skilled, fan_max, CEILINGS[Weapons.RAPID_LASER]])
	t.near("r_fan_hammer careless matches 35.1", fan_careless, 35.12, 0.8)
	t.near("r_fan_hammer skilled matches 58.4", fan_skilled, 58.38, 0.9)
	t.check("r_fan_hammer sits within Rivet ceiling 75",
		ceiling_passes(Weapons.RAPID_LASER, fan_careless) and ceiling_passes(Weapons.RAPID_LASER, fan_max),
		"careless=%.2f max=%.2f" % [fan_careless, fan_max])

	var iron_pat := _keystone_pattern(t, "runner_gunner", "r_big_iron", Weapons.RAPID_LASER)
	var iron_careless := _simulate_rivet(iron_pat, false)
	var iron_skilled := _simulate_rivet(iron_pat, true)
	var iron_max := _rivet_max(iron_pat)
	print("KEYSTONE_ENVELOPE  r_big_iron  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		iron_careless, iron_skilled, iron_max, CEILINGS[Weapons.RAPID_LASER]])
	t.near("r_big_iron careless matches 37.2", iron_careless, 37.16, 0.8)
	t.near("r_big_iron skilled matches 70.5", iron_skilled, 70.53, 1.0)
	t.check("r_big_iron sits within Rivet ceiling 75",
		ceiling_passes(Weapons.RAPID_LASER, iron_careless) and ceiling_passes(Weapons.RAPID_LASER, iron_max),
		"careless=%.2f max=%.2f" % [iron_careless, iron_max])

	# 3-4. Sable: Static Flutter & Rail Lance (ball + mounted, ceiling 80).
	var flt_pat := _keystone_pattern(t, "pylon_engineer", "s_static_flutter", Weapons.ARC_CASTER)
	var flt_careless := _simulate_sable(Weapons.ARC_CASTER, flt_pat, "careless", SpeedTier.CRUISE)
	var flt_blazing := _simulate_sable(Weapons.ARC_CASTER, flt_pat, "skilled", SpeedTier.BLAZING)
	var flt_max := _sable_max(Weapons.ARC_CASTER, flt_pat)
	print("KEYSTONE_ENVELOPE  s_static_flutter  careless=%.2f  blazing=%.2f  max=%.2f  ceiling=%.0f" % [
		flt_careless, flt_blazing, flt_max, CEILINGS[Weapons.ARC_CASTER]])
	t.near("s_static_flutter careless matches 30.0", flt_careless, 30.0, 0.8)
	t.near("s_static_flutter blazing matches 68.8", flt_blazing, 68.75, 1.2)
	t.check("s_static_flutter sits within Sable ceiling 80",
		ceiling_passes(Weapons.ARC_CASTER, flt_careless) and ceiling_passes(Weapons.ARC_CASTER, flt_max),
		"careless=%.2f max=%.2f" % [flt_careless, flt_max])

	var flt_m_pat := _keystone_pattern(t, "pylon_engineer", "s_static_flutter", Weapons.PYLON_TURRET)
	var flt_m_careless := _simulate_sable(Weapons.PYLON_TURRET, flt_m_pat, "careless", SpeedTier.WALK)
	var flt_m_blazing := _simulate_sable(Weapons.PYLON_TURRET, flt_m_pat, "skilled", SpeedTier.BLAZING)
	var flt_m_walk := _simulate_sable(Weapons.PYLON_TURRET, flt_m_pat, "skilled", SpeedTier.WALK)
	var flt_m_max := _sable_max(Weapons.PYLON_TURRET, flt_m_pat)
	print("KEYSTONE_ENVELOPE  s_static_flutter_mounted  careless=%.2f  blazing=%.2f  after3s=%.2f  max=%.2f  ceiling=%.0f" % [
		flt_m_careless, flt_m_blazing, flt_m_walk, flt_m_max, CEILINGS[Weapons.PYLON_TURRET]])
	t.near("s_static_flutter mounted blazing matches 75.0", flt_m_blazing, 75.0, 1.4)
	t.near("s_static_flutter mounted after 3s matches 52.9", flt_m_walk, 52.94, 1.2)
	t.check("s_static_flutter mounted sits within Sable ceiling 80",
		ceiling_passes(Weapons.PYLON_TURRET, flt_m_careless) and ceiling_passes(Weapons.PYLON_TURRET, flt_m_max),
		"careless=%.2f max=%.2f" % [flt_m_careless, flt_m_max])

	var lance_pat := _keystone_pattern(t, "pylon_engineer", "s_rail_lance", Weapons.ARC_CASTER)
	var lance_careless := _simulate_sable(Weapons.ARC_CASTER, lance_pat, "careless", SpeedTier.CRUISE)
	var lance_blazing := _simulate_sable(Weapons.ARC_CASTER, lance_pat, "skilled", SpeedTier.BLAZING)
	var lance_max := _sable_max(Weapons.ARC_CASTER, lance_pat)
	print("KEYSTONE_ENVELOPE  s_rail_lance  careless=%.2f  blazing=%.2f  max=%.2f  ceiling=%.0f" % [
		lance_careless, lance_blazing, lance_max, CEILINGS[Weapons.ARC_CASTER]])
	t.near("s_rail_lance careless matches 26.7", lance_careless, 26.67, 0.8)
	t.near("s_rail_lance blazing matches 64.1", lance_blazing, 64.10, 1.0)
	t.check("s_rail_lance sits within Sable ceiling 80",
		ceiling_passes(Weapons.ARC_CASTER, lance_careless) and ceiling_passes(Weapons.ARC_CASTER, lance_max),
		"careless=%.2f max=%.2f" % [lance_careless, lance_max])

	var lance_m_pat := _keystone_pattern(t, "pylon_engineer", "s_rail_lance", Weapons.PYLON_TURRET)
	var lance_m_careless := _simulate_sable(Weapons.PYLON_TURRET, lance_m_pat, "careless", SpeedTier.WALK)
	var lance_m_blazing := _simulate_sable(Weapons.PYLON_TURRET, lance_m_pat, "skilled", SpeedTier.BLAZING)
	var lance_m_walk := _simulate_sable(Weapons.PYLON_TURRET, lance_m_pat, "skilled", SpeedTier.WALK)
	var lance_m_max := _sable_max(Weapons.PYLON_TURRET, lance_m_pat)
	print("KEYSTONE_ENVELOPE  s_rail_lance_mounted  careless=%.2f  blazing=%.2f  after3s=%.2f  max=%.2f  ceiling=%.0f" % [
		lance_m_careless, lance_m_blazing, lance_m_walk, lance_m_max, CEILINGS[Weapons.PYLON_TURRET]])
	t.near("s_rail_lance mounted blazing matches 69.2", lance_m_blazing, 69.23, 1.0)
	t.near("s_rail_lance mounted after 3s matches 42.2", lance_m_walk, 42.19, 1.0)
	t.check("s_rail_lance mounted sits within Sable ceiling 80",
		ceiling_passes(Weapons.PYLON_TURRET, lance_m_careless) and ceiling_passes(Weapons.PYLON_TURRET, lance_m_max),
		"careless=%.2f max=%.2f" % [lance_m_careless, lance_m_max])

	# 5-6. Kest: Cluster & Keg (ceiling 44).
	var clus_pat := _keystone_pattern(t, "demolitions_caster", "k_cluster", Weapons.STICKY_CHARGE)
	var clus_careless := _simulate_kest(clus_pat, false)
	var clus_skilled := _simulate_kest(clus_pat, true)
	var clus_max := _kest_max(clus_pat)
	print("KEYSTONE_ENVELOPE  k_cluster  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		clus_careless, clus_skilled, clus_max, CEILINGS[Weapons.STICKY_CHARGE]])
	t.near("k_cluster careless matches 19.3", clus_careless, 19.25, 0.8)
	t.near("k_cluster skilled matches 38.5", clus_skilled, 38.50, 1.0)
	t.check("k_cluster sits within Kest ceiling 44",
		ceiling_passes(Weapons.STICKY_CHARGE, clus_careless) and ceiling_passes(Weapons.STICKY_CHARGE, clus_max),
		"careless=%.2f max=%.2f" % [clus_careless, clus_max])

	var keg_pat := _keystone_pattern(t, "demolitions_caster", "k_keg", Weapons.STICKY_CHARGE)
	var keg_careless := _simulate_kest(keg_pat, false)
	var keg_skilled := _simulate_kest(keg_pat, true)
	var keg_max := _kest_max(keg_pat)
	print("KEYSTONE_ENVELOPE  k_keg  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		keg_careless, keg_skilled, keg_max, CEILINGS[Weapons.STICKY_CHARGE]])
	t.near("k_keg careless matches 17.1", keg_careless, 17.14, 0.8)
	t.near("k_keg skilled matches 34.3", keg_skilled, 34.29, 1.0)
	t.check("k_keg sits within Kest ceiling 44",
		ceiling_passes(Weapons.STICKY_CHARGE, keg_careless) and ceiling_passes(Weapons.STICKY_CHARGE, keg_max),
		"careless=%.2f max=%.2f" % [keg_careless, keg_max])

	# 7-8. Tarn: Saw Flurry & Guillotine (ceiling 80).
	var saw_pat := _keystone_pattern(t, "tarn", "t_saw_flurry", Weapons.CLAW_SWEEP)
	var saw_careless := _simulate_tarn(saw_pat, false, 14.0)
	var saw_cruise := _simulate_tarn(saw_pat, true, 14.0)
	var saw_cap30 := _simulate_tarn(saw_pat, true, 30.0)
	var saw_max := _tarn_max(saw_pat)
	print("KEYSTONE_ENVELOPE  t_saw_flurry  careless=%.2f  cruise=%.2f  cap30=%.2f  max=%.2f  ceiling=%.0f" % [
		saw_careless, saw_cruise, saw_cap30, saw_max, CEILINGS[Weapons.CLAW_SWEEP]])
	t.near("t_saw_flurry careless matches 40.0", saw_careless, 40.0, 1.0)
	t.near("t_saw_flurry skilled cruise matches 66.7", saw_cruise, 66.67, 1.2)
	t.near("t_saw_flurry skilled 30 m/s matches 72.6", saw_cap30, 72.59, 1.2)
	t.check("t_saw_flurry sits within Tarn ceiling 80",
		ceiling_passes(Weapons.CLAW_SWEEP, saw_careless) and ceiling_passes(Weapons.CLAW_SWEEP, saw_max),
		"careless=%.2f max=%.2f" % [saw_careless, saw_max])

	var guil_pat := _keystone_pattern(t, "tarn", "t_guillotine", Weapons.CLAW_SWEEP)
	var guil_careless := _simulate_tarn(guil_pat, false, 14.0)
	var guil_cruise := _simulate_tarn(guil_pat, true, 14.0)
	var guil_cap30 := _simulate_tarn(guil_pat, true, 30.0)
	var guil_max := _tarn_max(guil_pat)
	print("KEYSTONE_ENVELOPE  t_guillotine  careless=%.2f  cruise=%.2f  cap30=%.2f  max=%.2f  ceiling=%.0f" % [
		guil_careless, guil_cruise, guil_cap30, guil_max, CEILINGS[Weapons.CLAW_SWEEP]])
	t.near("t_guillotine careless matches 30.8", guil_careless, 30.77, 1.0)
	t.near("t_guillotine skilled cruise matches 69.5", guil_cruise, 69.50, 1.2)
	t.near("t_guillotine skilled 30 m/s matches 77.5", guil_cap30, 77.50, 1.2)
	t.check("t_guillotine sits within Tarn ceiling 80",
		ceiling_passes(Weapons.CLAW_SWEEP, guil_careless) and ceiling_passes(Weapons.CLAW_SWEEP, guil_max),
		"careless=%.2f max=%.2f" % [guil_careless, guil_max])

	# 9-10. Tally: Petty Cash & Compound Interest (ceilings 30 sustained / 80 1s burst).
	var petty_pat := _keystone_pattern(t, "tally", "tl_petty_cash", Weapons.LEDGER_READER)
	var petty_careless := _simulate_tally(petty_pat, "careless")
	var petty_open := _simulate_tally(petty_pat, "chain_open")
	var petty_close := _simulate_tally(petty_pat, "chain_close")
	var petty_net: float = maxf(float(petty_pat.cast_cost) - minf(float(petty_pat.refund), float(petty_pat.cast_cost)), 0.0001)
	var petty_max_sust: float = (float(petty_pat.damage) * float(petty_pat.window_mult)) * (1.0 / Weapons.PRESSURE_ROLL_S) / petty_net
	var petty_burst: float = float(petty_open["burst_1s"])
	print("KEYSTONE_ENVELOPE  tl_petty_cash  careless=%.2f  open=%.2f  close=%.2f  max_sust=%.2f  burst_1s=%.1f  ceilings=%.0f/%.0f" % [
		float(petty_careless["sustained"]), float(petty_open["sustained"]), float(petty_close["sustained"]),
		petty_max_sust, petty_burst, CEILINGS[Weapons.LEDGER_READER], CEILINGS[TALLY_BURST_KEY]])
	t.near("tl_petty_cash careless sustained matches 11.0", float(petty_careless["sustained"]), 11.0, 0.9)
	t.near("tl_petty_cash max sustained matches 26.4", petty_max_sust, 26.4, 0.1)
	t.near("tl_petty_cash 1s burst matches 66.0", petty_burst, 66.0, 0.3)
	t.check("tl_petty_cash sits within Tally ceilings 30 / 80",
		ceiling_passes(Weapons.LEDGER_READER, float(petty_careless["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, float(petty_open["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, petty_max_sust)
		and ceiling_passes(TALLY_BURST_KEY, petty_burst),
		"sust=%.2f burst=%.1f" % [petty_max_sust, petty_burst])

	var comp_pat := _keystone_pattern(t, "tally", "tl_compound_interest", Weapons.LEDGER_READER)
	var comp_careless := _simulate_tally(comp_pat, "careless")
	var comp_open := _simulate_tally(comp_pat, "chain_open")
	var comp_close := _simulate_tally(comp_pat, "chain_close")
	var comp_net: float = maxf(float(comp_pat.cast_cost) - minf(float(comp_pat.refund), float(comp_pat.cast_cost)), 0.0001)
	var comp_max_sust: float = float(comp_pat.stamp_streak_cap) * (1.0 / Weapons.PRESSURE_ROLL_S) / comp_net
	var comp_burst: float = float(comp_open["burst_1s"])
	print("KEYSTONE_ENVELOPE  tl_compound_interest  careless=%.2f  open=%.2f  close=%.2f  max_sust=%.2f  burst_1s=%.1f  ceilings=%.0f/%.0f" % [
		float(comp_careless["sustained"]), float(comp_open["sustained"]), float(comp_close["sustained"]),
		comp_max_sust, comp_burst, CEILINGS[Weapons.LEDGER_READER], CEILINGS[TALLY_BURST_KEY]])
	t.near("tl_compound_interest careless sustained matches 11.0", float(comp_careless["sustained"]), 11.0, 0.9)
	t.near("tl_compound_interest max sustained matches 25.3", comp_max_sust, 25.33, 0.1)
	t.near("tl_compound_interest 1s burst matches 76.0", comp_burst, 76.0, 0.3)
	t.check("tl_compound_interest sits within Tally ceilings 30 / 80",
		ceiling_passes(Weapons.LEDGER_READER, float(comp_careless["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, float(comp_open["sustained"]))
		and ceiling_passes(Weapons.LEDGER_READER, comp_max_sust)
		and ceiling_passes(TALLY_BURST_KEY, comp_burst),
		"sust=%.2f burst=%.1f" % [comp_max_sust, comp_burst])

	# 11-12. Cannon: Snap Battery & Siege Rail (ceiling 50).
	var snap_pat := _keystone_pattern(t, "remembered_cannon", "c_snap_battery", Weapons.CANNON_LANE)
	var snap_careless := _simulate_cannon(snap_pat, 0.0)
	var snap_skilled := _simulate_cannon(snap_pat, 0.15)
	var snap_max := _cannon_max(snap_pat)
	print("KEYSTONE_ENVELOPE  c_snap_battery  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		snap_careless, snap_skilled, snap_max, CEILINGS[Weapons.CANNON_LANE]])
	t.near("c_snap_battery careless matches 22.5", snap_careless, 22.5, 0.8)
	t.near("c_snap_battery skilled matches 47.3", snap_skilled, 47.27, 1.0)
	t.check("c_snap_battery sits within Cannon ceiling 50",
		ceiling_passes(Weapons.CANNON_LANE, snap_careless) and ceiling_passes(Weapons.CANNON_LANE, snap_max),
		"careless=%.2f max=%.2f" % [snap_careless, snap_max])

	var siege_pat := _keystone_pattern(t, "remembered_cannon", "c_siege_rail", Weapons.CANNON_LANE)
	var siege_careless := _simulate_cannon(siege_pat, 0.0)
	var siege_skilled := _simulate_cannon(siege_pat, 0.60)
	var siege_max := _cannon_max(siege_pat)
	print("KEYSTONE_ENVELOPE  c_siege_rail  careless=%.2f  skilled=%.2f  max=%.2f  ceiling=%.0f" % [
		siege_careless, siege_skilled, siege_max, CEILINGS[Weapons.CANNON_LANE]])
	t.near("c_siege_rail careless matches 16.0", siege_careless, 16.0, 0.8)
	t.near("c_siege_rail skilled matches 41.3", siege_skilled, 41.25, 1.0)
	t.check("c_siege_rail sits within Cannon ceiling 50",
		ceiling_passes(Weapons.CANNON_LANE, siege_careless) and ceiling_passes(Weapons.CANNON_LANE, siege_max),
		"careless=%.2f max=%.2f" % [siege_careless, siege_max])
