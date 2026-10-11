extends SceneTree

const AbilityState := preload("res://src/core/ability_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
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
			var radius := "%s m" % String.num(row["bolt_radius"])
			t.check("%s envelope cell quotes the code's bolt radius %s" % [p, radius], cell.contains(radius), cell.substr(0, 80))
	quit(t.verdict())
