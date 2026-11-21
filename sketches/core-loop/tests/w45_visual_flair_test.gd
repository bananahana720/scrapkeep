extends SceneTree

const Measurement := preload("res://tools/pattern_dps.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Combat := preload("res://src/combat/combat.gd")
const Effects := preload("res://src/combat/effects.gd")
const Density := preload("res://src/presentation/density.gd")
const Palette := preload("res://src/core/palette.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# W45 polish unit P4: each shot bit's own shape where it acts, and the verb evolutions' payoffs, in
# the running game. Real bolts fly through Bolts.step into combat's hit and glance seams, real
# builds grant Grapeshot Press, Hoar Barrel and Fault Hammer through run.add_part, and the slam
# fact goes on the real bus. Every shape is read off Effects.flair_lines, the function the draw
# uses, so what is checked is what is drawn.
#
# 1-5  each bit draws its own shape in its own ShotBits.TABLE colour: pierce a streak and chevron
#      along the line, bounce a V (one arm back the way it came, one out the way it left), split
#      two forks at +/- 18 deg, pull an arrow from the hit to the ball, heat rising embers and no
#      ring of its own (combat's heat ring still draws once).
# 6    a multi-bit hit draws one shape, the first acting bit in ShotBits.NAMES order.
# 7    planted: a bare bolt (bits 0) draws no bit shape, only its spark.
# 8    planted: a pull bolt on a machine heavier than the pilot draws no pull arrow.
# 9    Grapeshot Press: the split fork narrows to +/- 8 deg and pops a brighter brass flash; a
#      plain split stays at +/- 18 deg with no pop.
# 10-11 Hoar Barrel: a piercing weapon hit lands an ice crystal at the frost radius; planted: a
#      piercing shot without the evolution lands none.
# 12-13 Fault Hammer: the aftershock runs two rings out, the pilot's colour inside a slate rim that
#      lands on the committed radius; planted: without the evolution no aftershock ring.
# 14   100 rapid bit tells hold the list at Effects.FLAIR_CAP, newest kept.
# 15   the density governor thins a bit shape in a crowd and leaves a payoff alone.
# 16   no flair line seen in this run is drawn in Palette.HAZARD.
# 17   effects.gd names no HAZARD and makes no words (no Label3D).
# Evidence limit: drawn line geometry and colour in a headless run, not a rendered capture, the
# sound or the feel at Andrew's screen.

const DT := 1.0 / 90.0
const EXPECTED_REPORTS := 17
const BALL := Measurement.BALL
const PILOT_HEFT := 2.0
const LIGHT := "chaser"
const HEAVY := "plated_brute"
# Sites well apart, each a straight shot down -z from its own origin.
const PIERCE_SITE := Vector3(40.0, 0.0, 0.0)
const SPLIT_SITE := Vector3(80.0, 0.0, 0.0)
const PULL_SITE := Vector3(120.0, 0.0, 0.0)
const HEAT_SITE := Vector3(160.0, 0.0, 0.0)
const MIXED_SITE := Vector3(200.0, 0.0, 0.0)
const CONTROL_SITE := Vector3(240.0, 0.0, 0.0)
const GRAPE_SITE := Vector3(280.0, 0.0, 0.0)
const HOAR_SITE := Vector3(320.0, 0.0, 0.0)
const FAULT_SITE := Vector3(360.0, 0.0, 0.0)
const WALL_SITE := Vector3(400.0, 0.0, 0.0)
const WALL_GAP := 6.0
const GLANCE_DEG := 30.0
const SETTLE_FRAMES := 3
const ANGLE_EPS := 0.5

var _game
var _started := false
var _frames := 0
var _done := false
var _failures := 0
var _reports := 0
var _wall: StaticBody3D
# Every colour a flair line was read in during the run.
var _seen: Array = []


func _initialize() -> void:
	_game = Measurement.MeasurementGame.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	_reports += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game == null or _game.flow == null or _done:
		return false
	if not _started:
		_started = true
		Measurement.prepare(_game)
		Density.live().reset()
		_build_wall()
		return false
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	_done = true
	_combat().heft_override = PILOT_HEFT
	_check_pierce()
	_check_bounce()
	_check_split()
	_check_pull()
	_check_heat()
	_check_mixed()
	_check_bare_control()
	_check_heavy_control()
	_check_grapeshot()
	_check_hoar()
	_check_fault()
	_check_cap()
	_check_density()
	_check_never_hazard()
	_check_source()
	Density.live().reset()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("w45_visual_flair_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if is_instance_valid(_wall):
		_wall.free()
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


# --- harness ---------------------------------------------------------------------------

func _combat():
	return _game.ctx.spawner


func _effects():
	return _combat().effects


func _build():
	return _game.ctx.build


# One wall square across the -z line at WALL_SITE, on the layer the bolts' ray reads. It hangs
# off the tree root so the disabled game does not take it out of the physics space.
func _build_wall() -> void:
	_wall = StaticBody3D.new()
	_wall.collision_layer = Bolts.WORLD_MASK
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(60.0, 8.0, 0.4)
	shape.shape = box
	_wall.add_child(shape)
	root.add_child(_wall)
	_wall.global_position = BALL + WALL_SITE + Vector3.FORWARD * WALL_GAP


func _hold(parts: Array) -> void:
	_game.tuning.set_value("shot_bits_live", ShotBits.ALL)
	_game.run.parts.clear()
	_build().recompute()
	for id in parts:
		_game.run.add_part(id, "test")
	_build().recompute()


func _record(at: Vector3, dir: Vector3, bits: int) -> Dictionary:
	var p: Resource = _combat().pattern(Weapons.RAPID_LASER)
	return {"origin": at, "dir": dir.normalized(), "speed": p.speed, "max_dist": 40.0, "damage": 10.0,
		"kind": Weapons.strike_kind(Weapons.RAPID_LASER), "weapon_id": Weapons.RAPID_LASER, "radius": p.bolt_radius,
		"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.0, "color": Color.WHITE,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 0, "source": "weapon", "bits": bits}


# One weapon record exactly as combat builds it for this press (the centre of the layout).
func _pressed() -> Dictionary:
	var combat = _combat()
	combat.bolts.clear()
	combat._fire(combat.active_weapon(), "weapon")
	var made: Array = combat.bolts.get("_bolts").duplicate()
	combat.bolts.clear()
	var pick: Dictionary = made[0]
	for bolt in made:
		if float(bolt["wave_amp"]) <= 0.0:
			pick = bolt
	return pick.duplicate()


# The record re-aimed down -z from `origin`, its flight state reset by fire().
func _aimed(record: Dictionary, origin: Vector3) -> Dictionary:
	var out := record.duplicate()
	for key in ["travelled", "age", "shown", "right", "up", "exclude", "acts", "pulled"]:
		out.erase(key)
	out["origin"] = origin
	out["dir"] = Vector3.FORWARD
	out["max_dist"] = 30.0
	out["wave_amp"] = 0.0
	out["spent"] = 0
	out["pierce"] = 0
	if out.has("hoar_spared"):
		out["hoar_spared"] = []
	return out


func _dummy(at: Vector3, kind := LIGHT) -> Node3D:
	var target: Node3D = Measurement._dummy(_game, at)
	target.kind = kind
	return target


func _free(targets: Array) -> void:
	for t in targets:
		if is_instance_valid(t):
			t.remove_from_group("enemy")
			t.free()
	_combat().bolts.clear()


# Fly one bolt (and whatever it throws) among targets until none is left in the air.
func _fly(bolt: Dictionary, targets: Array) -> void:
	var bolts = _combat().bolts
	bolts.fire(bolt)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for tick in 600:
		if bolts.live() < 1:
			return
		bolts.step(DT, space, targets)


func _tick_combat(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_combat()._physics_process(DT)


# The live flair marks of these kinds, their colours noted for the HAZARD sweep.
func _marks(kinds: Array) -> Array:
	var out: Array = []
	for entry in _effects().get("_flair"):
		if String(entry["kind"]) in kinds:
			out.append(entry)
			for seg in Effects.flair_lines(entry):
				_seen.append(seg[2])
	return out


func _bit_marks() -> Array:
	return _marks(ShotBits.NAMES)


func _seg_dir(seg: Array) -> Vector3:
	return ((seg[1] as Vector3) - (seg[0] as Vector3)).normalized()


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _all_colour(lines: Array, color: Color) -> bool:
	return not lines.is_empty() and lines.all(func(seg): return seg[2] == color)


func _kinds(marks: Array) -> Array:
	return marks.map(func(m): return String(m["kind"]))


# Fly one bolt of these bits into one machine down -z from `site`; the bit marks it left.
func _one_hit(site: Vector3, bits: int, kind := LIGHT) -> Dictionary:
	_effects().clear()
	var origin := BALL + site
	var target := _dummy(origin + Vector3.FORWARD * 5.0, kind)
	var at := target.global_position
	_fly(_record(origin, Vector3.FORWARD, bits), [target])
	var out := {"marks": _bit_marks(), "target_at": at, "dealt": target.max_hp - target.hp,
		"sparks": (_effects().get("_sparks") as Array).size(), "rings": (_effects().get("_rings") as Array).duplicate()}
	_free([target])
	return out


# --- 1-5 each bit's own shape --------------------------------------------------------------

func _check_pierce() -> void:
	var hit := _one_hit(PIERCE_SITE, ShotBits.bit("pierce"))
	var marks: Array = hit["marks"]
	var ok: bool = marks.size() == 1 and marks[0]["kind"] == "pierce"
	var detail := "marks %s" % [_kinds(marks)]
	if ok:
		var lines := Effects.flair_lines(marks[0])
		var streak := _seg_dir(lines[0])
		ok = _all_colour(lines, ShotBits.TABLE["pierce"]["color"]) and streak.dot(Vector3.FORWARD) > 0.999 and lines.size() == 6
		detail = "one pierce mark, %d lines in %s, streak %s along the shot" % [lines.size(), lines[0][2], streak]
	_report("pierce: a streak and chevron along the line, in ledger", ok, detail)


func _check_bounce() -> void:
	_effects().clear()
	var incoming := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(GLANCE_DEG))
	var outgoing := incoming.bounce(Vector3.BACK)
	_fly(_record(BALL + WALL_SITE, incoming, ShotBits.bit("bounce")), [])
	var marks := _bit_marks()
	var ok: bool = marks.size() == 1 and marks[0]["kind"] == "bounce"
	var detail := "marks %s" % [_kinds(marks)]
	if ok:
		var lines := Effects.flair_lines(marks[0])
		var came := _seg_dir(lines[0])
		var left := _seg_dir(lines[1])
		var wall_z: float = (BALL + WALL_SITE + Vector3.FORWARD * WALL_GAP).z
		ok = _all_colour(lines, ShotBits.TABLE["bounce"]["color"]) and came.dot(-incoming) > 0.999 and left.dot(outgoing) > 0.999 \
			and absf((marks[0]["at"] as Vector3).z - wall_z) < 0.5
		detail = "V at the wall (z %.2f, wall %.2f): back arm %s (want %s), out arm %s (want %s), colour %s" % [
			(marks[0]["at"] as Vector3).z, wall_z, came, -incoming, left, outgoing, lines[0][2]]
	_report("bounce: a V on the wall, in arc", ok, detail)
	_combat().bolts.clear()


# The two fork lines' angles off the shot's line, signed by side.
func _fork_angles(entry: Dictionary) -> Array:
	var lines := Effects.flair_lines(entry)
	var dir: Vector3 = (entry["dir"] as Vector3).normalized()
	var out: Array = []
	for i in [1, 2]:
		var d := _seg_dir(lines[i])
		out.append(rad_to_deg(d.angle_to(dir)) * signf(dir.cross(d).y))
	return out


func _check_split() -> void:
	var hit := _one_hit(SPLIT_SITE, ShotBits.bit("split"))
	var marks: Array = hit["marks"]
	var ok: bool = marks.size() == 1 and marks[0]["kind"] == "split"
	var detail := "marks %s" % [_kinds(marks)]
	if ok:
		var angles := _fork_angles(marks[0])
		var lines := Effects.flair_lines(marks[0])
		ok = _all_colour(lines, ShotBits.TABLE["split"]["color"]) and lines.size() == 3 \
			and absf(absf(angles[0]) - Bolts.SPLIT_ANGLE_DEG) < ANGLE_EPS and absf(absf(angles[1]) - Bolts.SPLIT_ANGLE_DEG) < ANGLE_EPS \
			and signf(angles[0]) != signf(angles[1])
		detail = "one split mark, forks at %.1f and %.1f deg, %d lines in %s" % [angles[0], angles[1], lines.size(), lines[0][2]]
	_report("split: two forks at +/- 18 deg, in brass", ok, detail)


func _check_pull() -> void:
	var hit := _one_hit(PULL_SITE, ShotBits.bit("pull"))
	var marks: Array = hit["marks"]
	var ok: bool = marks.size() == 1 and marks[0]["kind"] == "pull"
	var detail := "marks %s" % [_kinds(marks)]
	if ok:
		var lines := Effects.flair_lines(marks[0])
		var tether := _seg_dir(lines[0])
		var want := _flat(_game.player.ball_position() - (marks[0]["at"] as Vector3)).normalized()
		var head: Vector3 = lines[0][1]
		ok = _all_colour(lines, ShotBits.TABLE["pull"]["color"]) and tether.dot(want) > 0.999 and tether.dot(Vector3.BACK) < 0.9 \
			and _flat(head - (marks[0]["at"] as Vector3)).length() > 0.5
		detail = "tether %s, to the ball %s (not back along the shot %s), colour %s" % [tether, want, Vector3.BACK, lines[0][2]]
	_report("pull: an arrow from the hit to the ball, in slate", ok, detail)


func _check_heat() -> void:
	var hit := _one_hit(HEAT_SITE, ShotBits.bit("heat"))
	var marks: Array = hit["marks"]
	var heat_color: Color = ShotBits.TABLE["heat"]["color"]
	var heat_rings: int = (hit["rings"] as Array).filter(func(r): return r["color"] == heat_color).size()
	var ok: bool = marks.size() == 1 and marks[0]["kind"] == "heat"
	var detail := "marks %s, heat rings %d" % [_kinds(marks), heat_rings]
	if ok:
		var lines := Effects.flair_lines(marks[0])
		var rising := lines.all(func(seg): return (seg[1] as Vector3).y > (seg[0] as Vector3).y)
		ok = _all_colour(lines, heat_color) and lines.size() == 6 and rising and heat_rings == 1
		detail = "%d ember lines, all rising %s, in %s; combat's own heat ring drawn %d time(s)" % [lines.size(), rising, lines[0][2], heat_rings]
	_report("heat: rising embers, no second ring, in copper", ok, detail)


# --- 6-8 one tell per hit, and the controls --------------------------------------------------

func _check_mixed() -> void:
	var three := _one_hit(MIXED_SITE, ShotBits.bit("pierce") | ShotBits.bit("split") | ShotBits.bit("heat"))
	var two := _one_hit(MIXED_SITE + Vector3(0.0, 0.0, 60.0), ShotBits.bit("pull") | ShotBits.bit("heat"))
	_report("a multi-bit hit draws one shape, the first in NAMES order",
		_kinds(three["marks"]) == ["pierce"] and _kinds(two["marks"]) == ["pull"],
		"pierce+split+heat -> %s; pull+heat -> %s" % [_kinds(three["marks"]), _kinds(two["marks"])])


func _check_bare_control() -> void:
	var hit := _one_hit(CONTROL_SITE, 0)
	_report("planted control: a bare bolt draws no bit shape", (hit["marks"] as Array).is_empty() and int(hit["sparks"]) > 0
		and float(hit["dealt"]) > 0.0, "bits 0: marks %s, sparks %d, dealt %.1f" % [_kinds(hit["marks"]), hit["sparks"], hit["dealt"]])


func _check_heavy_control() -> void:
	var light := _one_hit(CONTROL_SITE + Vector3(0.0, 0.0, 60.0), ShotBits.bit("pull"), LIGHT)
	var heavy := _one_hit(CONTROL_SITE + Vector3(0.0, 0.0, 120.0), ShotBits.bit("pull"), HEAVY)
	_report("planted control: a machine that holds draws no pull arrow",
		_kinds(light["marks"]) == ["pull"] and (heavy["marks"] as Array).is_empty() and float(heavy["dealt"]) > 0.0,
		"pilot heft %.1f: %s -> %s, %s -> %s (dealt %.1f)" % [PILOT_HEFT, LIGHT, _kinds(light["marks"]), HEAVY, _kinds(heavy["marks"]), heavy["dealt"]])


# --- 9 Grapeshot Press ------------------------------------------------------------------------

func _split_mark(parts: Array, site: Vector3) -> Dictionary:
	_hold(parts)
	var record := _aimed(_pressed(), BALL + site)
	# The press's own bits, set aside to split alone so split is the first acting bit.
	record["bits"] = ShotBits.bit("split")
	_effects().clear()
	var target := _dummy(BALL + site + Vector3.FORWARD * 5.0)
	_fly(record, [target])
	var marks := _bit_marks()
	_free([target])
	return {"granted": parts, "angle": record.get("split_angle_deg", Bolts.SPLIT_ANGLE_DEG),
		"mark": marks[0] if marks.size() == 1 and marks[0]["kind"] == "split" else {}}


func _check_grapeshot() -> void:
	var grape := _split_mark(["cross_split", "pin_setter"], GRAPE_SITE)
	var held_grape: bool = "grapeshot_press" in _game.run.parts
	var plain := _split_mark(["cross_split", "hairline_fracture"], GRAPE_SITE + Vector3(0.0, 0.0, 60.0))
	var ok: bool = held_grape and not (grape["mark"] as Dictionary).is_empty() and not (plain["mark"] as Dictionary).is_empty()
	var detail := "granted %s, grape mark %s, plain mark %s" % [held_grape, not (grape["mark"] as Dictionary).is_empty(),
		not (plain["mark"] as Dictionary).is_empty()]
	if ok:
		var tight := _fork_angles(grape["mark"])
		var wide := _fork_angles(plain["mark"])
		var brass: Color = ShotBits.TABLE["split"]["color"]
		var grape_lines := Effects.flair_lines(grape["mark"])
		var pops: Array = grape_lines.filter(func(seg): return seg[2] != brass)
		var brighter := func(seg) -> bool: return (seg[2] as Color).get_luminance() > brass.get_luminance() and seg[2] != Palette.HAZARD
		var pop_brighter := not pops.is_empty() and pops.all(brighter)
		var plain_pops := Effects.flair_lines(plain["mark"]).filter(func(seg): return seg[2] != brass).size()
		ok = absf(absf(tight[0]) - Combat.GRAPESHOT_ANGLE_DEG) < ANGLE_EPS and absf(absf(tight[1]) - Combat.GRAPESHOT_ANGLE_DEG) < ANGLE_EPS \
			and absf(absf(wide[0]) - Bolts.SPLIT_ANGLE_DEG) < ANGLE_EPS and absf(absf(wide[1]) - Bolts.SPLIT_ANGLE_DEG) < ANGLE_EPS \
			and pop_brighter and pops.size() == 8 and plain_pops == 0
		detail = "grapeshot forks %.1f / %.1f deg with %d brighter pop lines; plain forks %.1f / %.1f deg with %d" % [
			tight[0], tight[1], pops.size(), wide[0], wide[1], plain_pops]
	_report("grapeshot press narrows the fork to +/- 8 deg and pops", ok, detail)


# --- 10-11 Hoar Barrel ------------------------------------------------------------------------

func _frost_after(record: Dictionary, site: Vector3) -> Dictionary:
	_effects().clear()
	var target := _dummy(BALL + site + Vector3.FORWARD * 5.0)
	var at := target.global_position
	_fly(_aimed(record, BALL + site), [target])
	var frost := _marks(["frost"])
	_free([target])
	return {"frost": frost, "at": at, "bits": _kinds(_bit_marks())}


func _check_hoar() -> void:
	_hold(["frost_barb", "rime_rounds"])
	var marked := _pressed()
	var hoar := _frost_after(marked, HOAR_SITE)
	var frost: Array = hoar["frost"]
	var ok: bool = "hoar_barrel" in _game.run.parts and bool(marked.get("hoar", false)) and frost.size() == 1
	var detail := "granted %s, marked %s, crystals %d" % ["hoar_barrel" in _game.run.parts, marked.get("hoar", false), frost.size()]
	if ok:
		var lines := Effects.flair_lines(frost[0])
		var centre: Vector3 = (frost[0]["at"] as Vector3) + Vector3.UP * 0.4
		var corner := _flat((lines[0][0] as Vector3) - centre).length()
		ok = _all_colour(lines, Palette.ICE) and is_equal_approx(float(frost[0]["radius"]), Combat.HOAR_FROST_RADIUS) \
			and absf(corner - Combat.HOAR_FROST_RADIUS) < 0.01 and _flat((frost[0]["at"] as Vector3) - (hoar["at"] as Vector3)).length() < 0.01 \
			and lines.size() == 2 * Effects.FROST_POINTS
		detail = "one ice crystal on the struck machine, corners at %.2f m (frost %.1f m), %d lines in %s; bit marks %s" % [
			corner, Combat.HOAR_FROST_RADIUS, lines.size(), lines[0][2], hoar["bits"]]
	_report("hoar barrel lands an ice crystal at the frost radius", ok, detail)
	_hold([])
	var plain := _record(BALL + HOAR_SITE, Vector3.FORWARD, ShotBits.bit("pierce"))
	var bare := _frost_after(plain, HOAR_SITE + Vector3(0.0, 0.0, 60.0))
	_report("planted control: a piercing shot without hoar lands no crystal", (bare["frost"] as Array).is_empty() and bare["bits"] == ["pierce"],
		"crystals %d, bit marks %s" % [(bare["frost"] as Array).size(), bare["bits"]])


# --- 12-13 Fault Hammer -----------------------------------------------------------------------

func _quakes_after_slam(parts: Array, at: Vector3) -> Array:
	_hold(parts)
	_effects().clear()
	_game.ctx.events.slammed.emit(at, 1.0, 1.0)
	_tick_combat(Combat.FAULT_DELAY + 0.05)
	return _marks(["quake"])


func _check_fault() -> void:
	var at := BALL + FAULT_SITE
	var quakes := _quakes_after_slam(["echo_locator", "brace_frame"], at)
	var radius: float = _game.player.slam_radius()
	var pilot: Color = _game.player.class_color()
	var ok: bool = "fault_hammer" in _game.run.parts and quakes.size() == 1
	var detail := "granted %s, quakes %d" % ["fault_hammer" in _game.run.parts, quakes.size()]
	if ok:
		var landed: Dictionary = quakes[0].duplicate()
		landed["life"] = 0.0
		var lines := Effects.flair_lines(landed)
		var reach := 0.0
		var inner := INF
		for seg in lines:
			var r := _flat((seg[0] as Vector3) - at).length()
			if seg[2] == Palette.SLATE:
				reach = maxf(reach, r)
			elif seg[2] == pilot:
				inner = minf(inner, r)
		var colours: Array = []
		for seg in lines:
			if not seg[2] in colours:
				colours.append(seg[2])
		ok = is_equal_approx(float(quakes[0]["radius"]), radius) and absf(reach - radius) < 0.01 and inner < reach \
			and colours.size() == 2 and pilot in colours and Palette.SLATE in colours
		detail = "committed radius %.2f; landed slate rim at %.2f, pilot ring (%s) inside at %.2f; colours %s" % [
			radius, reach, pilot, inner, colours]
	_report("fault hammer runs a double ring out to the committed radius", ok, detail)
	var control := _quakes_after_slam([], at + Vector3(0.0, 0.0, 60.0))
	_report("planted control: no fault hammer, no aftershock ring", control.is_empty() and not "fault_hammer" in _game.run.parts,
		"quakes %d" % control.size())


# --- 14-17 caps, density, colour, words -------------------------------------------------------

func _check_cap() -> void:
	_effects().clear()
	var combat = _combat()
	for i in 100:
		var name: String = ShotBits.NAMES[i % ShotBits.NAMES.size()]
		var bolt := _record(BALL + Vector3(0.0, 0.0, float(i)), Vector3.FORWARD, ShotBits.bit(name))
		combat._bit_tell(ShotBits.bit(name), bolt, BALL + Vector3(0.0, 0.0, float(i)))
	var flair: Array = _effects().get("_flair")
	var newest: Vector3 = flair[flair.size() - 1]["at"] if not flair.is_empty() else Vector3.INF
	var lines := 0
	for entry in flair:
		lines += Effects.flair_lines(entry).size()
	_report("100 rapid bit tells stay within the cap", flair.size() == Effects.FLAIR_CAP and newest.is_equal_approx(BALL + Vector3(0.0, 0.0, 99.0)),
		"%d marks held (cap %d), newest at z %+.0f, %d lines drawn" % [flair.size(), Effects.FLAIR_CAP, newest.z - BALL.z, lines])
	_effects().clear()


func _check_density() -> void:
	_effects().clear()
	Density.live().force(0.9)
	var band: Dictionary = Density.live().band()
	_effects().bit_hit("pierce", BALL, Vector3.FORWARD)
	_effects().shockwave(BALL, 6.0, _game.player.class_color())
	var flair: Array = _effects().get("_flair")
	Density.live().reset()
	var bit: Dictionary = flair[0]
	var payoff: Dictionary = flair[1]
	_report("the governor thins a bit shape in a crowd, not a payoff",
		is_equal_approx(float(bit["shade"]), float(band["alpha"])) and is_equal_approx(float(bit["span"]), Effects.BIT_LIFE * float(band["lifetime"]))
		and is_equal_approx(float(bit["size"]), float(band["size"])) and is_equal_approx(float(payoff["shade"]), 1.0)
		and is_equal_approx(float(payoff["span"]), Effects.PAYOFF_LIFE),
		"density 0.9: bit alpha %.2f life %.3f size %.2f; payoff alpha %.2f life %.2f" % [bit["shade"], bit["span"], bit["size"],
			payoff["shade"], payoff["span"]])
	_effects().clear()


func _check_never_hazard() -> void:
	var hazard := _seen.filter(func(c): return c == Palette.HAZARD).size()
	_report("no flair line is drawn in hazard", hazard == 0 and _seen.size() > 50, "%d lines read, %d in hazard" % [_seen.size(), hazard])


func _check_source() -> void:
	var text := FileAccess.get_file_as_string("res://src/combat/effects.gd")
	_report("effects.gd names no hazard and makes no words", not text.is_empty() and not "HAZARD" in text and not "Label3D" in text
		and not "Label" in text, "%d characters scanned" % text.length())
