extends SceneTree

const Panels := preload("res://src/build/panels.gd")
const PanelShell := preload("res://src/build/panel_shell.gd")
const BuildSheet := preload("res://src/build/build_sheet.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const RunState := preload("res://src/core/run_state.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const T := preload("res://tests/support/t.gd")

# IL-01 stack sweep: every grey panel at 1 to 60 copies, through the real fold and tuning.
# 1. Each stat is linear and monotonic: every copy adds exactly its row's step.
# 2. Overflow: louvres past the fire-rate cap convert one for one into the pilot's signature
#    stat, every pilot has a row, and the capped rate never passes Pattern.MAX_RATE.
# 3. No cooldown reaches zero: the harpoon rewind and the active recharge stay finite.
# 4. Heft: a panel weighs PANEL_MASS of scrap in both scrap modes, never 0.2 per part.
# 5. On the ball: the drawn plates stay inside the hardware envelope at every stack.
# The table it prints is the sweep's record (stat at 1, 10, 30 and 60 copies).
# smoke: solo timeout=90s

const MAX_COPIES := 60
const SLIDER_STATS := ["cruise", "reel_speed", "rope_range"]

var _t := T.new("panels_stack_test")


func _initialize() -> void:
	_sweep()
	_overflow()
	_cooldowns()
	_heft()
	_envelope()
	_words()
	quit(_t.verdict())


static func _value(id: String, n: int) -> float:
	var row: Dictionary = Panels.ROWS[id]
	var sheet = BuildSheet.new()
	var counts := {}
	counts[id] = n
	Panels.fold(sheet, counts)
	var tuning = Tuning.new()
	sheet.apply(tuning, null)
	match String(row["kind"]):
		"pct":
			return tuning.mod(row["stat"])
		"add":
			return tuning.add(row["stat"])
		"punch":
			return sheet.punch
	return sheet.max_hp_bonus


func _sweep() -> void:
	for id in Panels.ROWS:
		var row: Dictionary = Panels.ROWS[id]
		var step: float = row["step"]
		var base := _value(id, 0)
		var linear := true
		var worst := 0.0
		var previous := base
		for n in range(1, MAX_COPIES + 1):
			var v := _value(id, n)
			var want := base + step * n
			worst = maxf(worst, absf(v - want))
			linear = linear and v > previous and absf(v - want) < 0.00001
			previous = v
		_t.check("linear %s" % id, linear, "%s %s per copy, worst error %.6f; at 1/10/30/60: %.3f %.3f %.3f %.3f" % [
			row["stat"], step, worst, _value(id, 1), _value(id, 10), _value(id, 30), _value(id, 60)])
		if row["stat"] in SLIDER_STATS:
			var tuning = Tuning.new()
			var sheet = BuildSheet.new()
			Panels.fold(sheet, {id: 10})
			sheet.apply(tuning, null)
			_t.near("%s reads through tuning.f" % id, tuning.f(row["stat"]), tuning.base(row["stat"]) * (1.0 + step * 10.0), 0.0001)


func _overflow() -> void:
	for def in ClassDef.all():
		_t.check("overflow row %s" % def.id, Panels.OVERFLOW.has(def.id), "signature %s" % Panels.overflow_of(def.id))
	for class_id in Panels.OVERFLOW:
		_t.check("overflow target %s is a panel" % class_id, Panels.ROWS.has(Panels.OVERFLOW[class_id]), Panels.OVERFLOW[class_id])
	# Rivet's rapid laser: 12 shots a second, so the 14th louvre reaches the 20 cap.
	var rate := Panels.weapon_rate("rapid_laser", [])
	var room := Panels.louvre_room(rate, 1.0)
	_t.eq("rapid laser louvre room", room, 14)
	var eff: Dictionary = Panels.effective({"vent_louvre": MAX_COPIES}, "runner_gunner", room)
	_t.eq("louvres kept at the cap", int(eff["counts"]["vent_louvre"]), 14)
	_t.eq("louvres converted to punch", int(eff["counts"].get("punch_rivet", 0)), MAX_COPIES - 14)
	_t.eq("converted count", int(eff["converted"]), MAX_COPIES - 14)
	var capped := minf(rate * (1.0 + 0.05 * 14), Pattern.MAX_RATE)
	_t.near("fire rate holds at the cap", capped, Pattern.MAX_RATE, 0.0001)
	var below: Dictionary = Panels.effective({"vent_louvre": 13}, "runner_gunner", room)
	_t.eq("no conversion below the cap", int(below["converted"]), 0)
	# A part list already at the cap converts every louvre; no cap (room -1) converts none.
	_t.eq("room at the cap", Panels.louvre_room(rate, 2.0), 0)
	_t.eq("no cap converts none", int(Panels.effective({"vent_louvre": 60}, "tally", -1)["converted"]), 0)
	for def in ClassDef.all():
		var r := Panels.weapon_rate(def.weapon_id, [])
		var k := Panels.louvre_room(r, 1.0)
		var e: Dictionary = Panels.effective({"vent_louvre": MAX_COPIES}, def.id, k)
		var total := 0
		for id in e["counts"]:
			total += int(e["counts"][id])
		_t.check("overflow keeps every panel %s" % def.id, total == MAX_COPIES and minf(r * (1.0 + 0.05 * int(e["counts"]["vent_louvre"])), Pattern.MAX_RATE) <= Pattern.MAX_RATE,
			"%s at %.1f/s: room %d, converted %d to %s" % [def.weapon_id, r, k, int(e["converted"]), Panels.overflow_of(def.id)])


func _cooldowns() -> void:
	var tuning = Tuning.new()
	var sheet = BuildSheet.new()
	Panels.fold(sheet, {"ratchet_collar": MAX_COPIES, "cell_bracket": MAX_COPIES})
	sheet.apply(tuning, null)
	var rewind: float = tuning.harpoon_rewind()
	_t.check("harpoon rewind never zero", rewind > 0.0 and is_finite(rewind),
		"%.3f s at %d collars (base %.2f s)" % [rewind, MAX_COPIES, tuning.f("harpoon_rewind")])
	_t.near("rewind divides by the recovery rate", rewind, tuning.f("harpoon_rewind") / (1.0 + 0.06 * MAX_COPIES), 0.00001)
	var recharge: float = tuning.mod("active_recharge")
	_t.check("active recharge rate finite", recharge > 1.0 and is_finite(recharge), "x%.2f at %d brackets" % [recharge, MAX_COPIES])


func _heft() -> void:
	for armor in [false, true]:
		var run = RunState.new(null, 1)
		run.armor_mode = armor
		var before: float = run.heft()
		for i in 55:
			run.panels.append(Panels.ROWS.keys()[i % Panels.ROWS.size()])
		var gain: float = run.heft() - before
		_t.near("heft per 55 panels (armour %s)" % armor, gain, 55.0 * Panels.PANEL_MASS * RunState.HEFT_PER_MASS, 0.000001)
		_t.check("panels are not parts (armour %s)" % armor, run.parts.is_empty(), "%d parts" % run.parts.size())
	_t.eq("panel mass pin", Panels.PANEL_MASS, 6.0)


func _envelope() -> void:
	var worst := 0.0
	for held in [1, 10, 32, 33, 64, 65, 70, 128, 300]:
		worst = maxf(worst, PanelShell.extent(held))
	_t.check("plates inside the envelope", worst <= 1.0 + PanelShell.MAX_OVERHANG + 0.0001,
		"furthest plate %.2f m from centre, envelope %.2f m; drawn at 300 held: %d" % [worst, 1.0 + PanelShell.MAX_OVERHANG, PanelShell.drawn_count(300)])
	_t.check("draw budget", PanelShell.drawn_count(300) <= PanelShell.DRAW_BUDGET, "budget %d" % PanelShell.DRAW_BUDGET)
	_t.eq("32 geodesic sockets", PanelShell.sockets().size(), 32)
	var tallest := 0.0
	var widest := 0.0
	for id in Panels.ROWS:
		var box: AABB = PanelShell.plate_mesh(Panels.ROWS[id]["silhouette"]).get_aabb()
		tallest = maxf(tallest, box.end.y)
		widest = maxf(widest, maxf(box.size.x, box.size.z))
	_t.check("every plate under PLATE_HEIGHT", tallest <= PanelShell.PLATE_HEIGHT + 0.0001, "tallest %.3f m, widest %.3f m" % [tallest, widest])


func _words() -> void:
	_t.eq("stat line", Panels.stat_line("vent_louvre", 5), "Fire rate +25%: 5 louvres")
	_t.eq("stat line flat", Panels.stat_line("splash_skirt", 2), "Slam and burst radius +0.70 m: 2 skirts")
	_t.eq("pop text", Panels.pop_text("hull_tile"), "TILE +5 MAX HULL")
	var silhouettes := Panels.ROWS.values().map(func(r): return r["silhouette"])
	_t.check("art pending names real silhouettes", Panels.PANEL_ART_PENDING.all(func(s): return s in silhouettes), str(Panels.PANEL_ART_PENDING))
