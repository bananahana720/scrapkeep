extends SceneTree

const Measurement := preload("res://tools/pattern_dps.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Combat := preload("res://src/combat/combat.gd")
const Parts := preload("res://src/build/parts.gd")
const PartDef := preload("res://src/build/part_def.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Synergies := preload("res://src/build/synergies.gd")
const Elements := preload("res://src/build/elements.gd")
const ElementField := preload("res://src/build/element_field.gd")
const Augments := preload("res://src/movement/augments.gd")
const Dunk := preload("res://src/combat/dunk.gd")
const Destructibles := preload("res://src/world/destructibles.gd")

# The three verb evolutions (design-v3/ABILITY-MUTATIONS.md section 7 D, W45-B2 unit U8) in the
# running game: real builds through run.add_part, real weapon records from combat._fire, real
# flights through Bolts.step and combat's hit and flight seams, the real element field, the real
# slam fact on the bus, combat's own clock and the real destructibles module. Each rule has a
# planted failing control.
#
# (a) data: seven evolutions, the three new pairs and their tricks, weight 0, outside the pools,
#     no shared ingredient (planted: a shared or unknown one is refused), "bits": [] keeps each verb
#     row from adding a shot bit (planted: the same row without it adds one), card verb at most 6
#     words and text at most 8, ending on the trick's name (planted: a nine-word text fails).
# (b) Grapeshot Press: a weapon record carries the tight split; a flown bolt throws two children at
#     +/- 8 deg (18 without the evolution, and for a proc bolt) knocking at least 0.5 x the slam's
#     knock, never below the shot's own; the machine a child hits is shoved that hard; the family
#     stays three bolts.
# (c) Hoar Barrel: a piercing weapon shot (pierce bit or helix drill's pattern pierce) frosts a 2 m
#     patch round each machine it hits, drawn on dry ground; over water the patch's slab is spared by
#     the same shot (planted: a shot that forgets it bursts it); a shot crossing a slab with no
#     machine on it bursts it into a 28 deg, 7 m forward cone striking 20 x the shatter dial as
#     item_proc, once, on the machine ahead and none beside or behind; the slab under the ball
#     stays (planted: the same call without the ball bursts it); a non-piercing shot and a proc
#     bolt do nothing.
# (d) Fault Hammer: a slam commits a ring in the pilot's colour at once, nothing lands at 0.30 s,
#     one aftershock at 0.45 s deals exactly half the slam's own damage at that spot as item_proc
#     (not scaled by heft twice), spends no dunk, never repeats, shatters every slab in the ring,
#     breaks a heft + 1 piece and leaves a heft + 2 piece; a retry cancels a waiting one; planted:
#     one ingredient queues none.
# Evidence limit: rules and state in a headless run, not the look, the sound or the feel.

const DT := 1.0 / 90.0
const EXPECTED_REPORTS := 35
const BALL := Measurement.BALL
# Sites well apart, each a straight shot down -z from its own origin.
const GRAPE_SITE := Vector3(60.0, 0.0, 0.0)
const DRY_SITE := Vector3(120.0, 0.0, 0.0)
const WET_SITE := Vector3(180.0, 0.0, 0.0)
const CROSS_SITE := Vector3(240.0, 0.0, 0.0)
const FAULT_SITE := Vector3(320.0, 0.0, 0.0)
const SITE_POOL := 40.0
# Water sits one metre under a site's line, where the ball's underside would be.
const WATER_DROP := 1.0
const PILOT_HEFT := 2.0

var _game
var _started := false
var _done := false
var _failures := 0
var _reports := 0
# Pools of water the field reads: {centre, radius}.
var _pools: Array = []


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
		_field().register_material("water", _water)
		return false
	_done = true
	_check_data()
	_check_grapeshot()
	_check_hoar_dry()
	_check_hoar_wet()
	_check_hoar_crossing()
	_check_hoar_gates()
	_check_hoar_under_ball()
	_check_fault()
	_check_fault_ice_and_props()
	_check_fault_reset_and_control()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("w45_evolutions_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


# --- harness ---------------------------------------------------------------------------

func _combat():
	return _game.ctx.spawner


func _build():
	return _game.ctx.build


func _field():
	return _game.ctx.build.field


func _water(point: Vector3) -> Dictionary:
	for pool in _pools:
		var c: Vector3 = pool["centre"]
		if Vector2(point.x - c.x, point.z - c.z).length() <= float(pool["radius"]):
			return {"surface_y": c.y}
	return {}


func _flood(site: Vector3) -> Vector3:
	var surface := BALL + site - Vector3.UP * WATER_DROP
	_pools.append({"centre": surface, "radius": SITE_POOL})
	return surface


# A fresh build of exactly these parts, added one at a time the way a run gains them, so an
# evolution is granted by the build itself.
func _hold(parts: Array, live_mask := ShotBits.ALL) -> void:
	_game.tuning.set_value("shot_bits_live", live_mask)
	_game.run.parts.clear()
	_build().recompute()
	for id in parts:
		_game.run.add_part(id, "test")
	_build().recompute()


func _dummy(at: Vector3) -> Node3D:
	return Measurement._dummy(_game, at)


func _free(targets: Array) -> void:
	for t in targets:
		if is_instance_valid(t):
			t.remove_from_group("enemy")
			t.free()
	_combat().bolts.clear()


func _dealt(t: Node3D) -> float:
	return t.max_hp - t.hp


func _knock(t: Node3D) -> float:
	var k: Vector3 = t.get("_knock")
	return Vector2(k.x, k.z).length() * float(t.weight)


func _item_proc() -> float:
	return float(_combat().delivered_damage()["by_source"].get("item_proc", 0.0))


# One weapon record exactly as combat builds it for this press (the centre of the layout).
func _pressed(source := "weapon") -> Dictionary:
	var combat = _combat()
	combat.bolts.clear()
	combat._fire(combat.active_weapon(), source)
	var made: Array = combat.bolts.get("_bolts").duplicate()
	combat.bolts.clear()
	var pick: Dictionary = made[0]
	for bolt in made:
		if float(bolt["wave_amp"]) <= 0.0:
			pick = bolt
	return pick.duplicate()


# The record re-aimed down -z from `origin`, its flight state reset by fire().
func _aimed(record: Dictionary, origin: Vector3, reach := 30.0) -> Dictionary:
	var out := record.duplicate()
	for key in ["travelled", "age", "shown", "right", "up", "exclude", "acts", "pulled"]:
		out.erase(key)
	out["origin"] = origin
	out["dir"] = Vector3.FORWARD
	out["max_dist"] = reach
	out["wave_amp"] = 0.0
	out["spent"] = 0
	out["pierce"] = int(_combat().pattern(_combat().active_weapon()).pierce)
	if out.has("hoar_spared"):
		out["hoar_spared"] = []
	return out


func _step(targets: Array, ticks := 240) -> void:
	var bolts = _combat().bolts
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for tick in ticks:
		if bolts.live() < 1:
			return
		bolts.step(DT, space, targets)


func _tick_combat(seconds: float) -> void:
	for i in roundi(seconds / DT):
		_combat()._physics_process(DT)


func _words(text: String) -> int:
	return text.strip_edges().split(" ", false).size()


# --- (a) data ---------------------------------------------------------------------------

func _check_data() -> void:
	var want := {
		"grapeshot_press": [["cross_split", "pin_setter"], "shrapnel_bloom", "redjaw"],
		"hoar_barrel": [["frost_barb", "rime_rounds"], "shatter_crew", "spillway_works"],
		"fault_hammer": [["echo_locator", "brace_frame"], "thermal_shock", "waking"],
	}
	var wrong: Array = []
	for into in want:
		if Synergies.EVOLUTIONS.get(into, []) != want[into][0] or Synergies.evolution_of(into) != want[into][1] \
				or Synergies.ROWS[Synergies.evolution_of(into)]["maker"] != want[into][2] \
				or not want[into][0].all(func(id): return Parts.row(id).get("maker", "") == want[into][2]):
			wrong.append(into)
	_report("seven evolutions, three new pairs", Synergies.EVOLUTIONS.size() == 7 and Parts.EVOLVED.size() == 7 and wrong.is_empty(),
		"%d evolutions, %d evolved rows, wrong %s" % [Synergies.EVOLUTIONS.size(), Parts.EVOLVED.size(), wrong])
	var pooled: Array = []
	for cls in ["sable", "rivet", "kest"]:
		for id in Parts.offer_pool(cls, ItemGen.RARITIES):
			if id in Parts.VERB_EVOLVED:
				pooled.append(id)
	_report("weight 0, never offered", ItemGen.RARITY["evolved"]["weight"] == 0.0 and pooled.is_empty()
		and Parts.VERB_EVOLVED.all(func(id): return Parts.def(id).rarity == "evolved" and not id in Parts.ids()),
		"evolved weight %s, pooled %s" % [ItemGen.RARITY["evolved"]["weight"], pooled])
	var known := func(part_id: String) -> bool: return Parts.has(part_id)
	var planted := Synergies.EVOLUTIONS.duplicate()
	planted["planted"] = ["pin_setter", "no_such_part"]
	var from := Synergies.EVOLVED_FROM.duplicate()
	from["planted"] = "shrapnel_bloom"
	var refused: Array = Synergies.evolution_problems(planted, from, known)
	_report("no shared ingredient", Synergies.evolution_problems(Synergies.EVOLUTIONS, Synergies.EVOLVED_FROM, known).is_empty()
		and refused.size() == 2, "live table clean; planted pair sharing pin_setter with an unknown part refused %s" % [refused])
	# Shot bits: each verb row adds none, so holding it alone carries none and adding it to its
	# ingredients changes nothing. Planted: the same row without "bits": [] adds its tag bits.
	var added: Array = []
	for into in Parts.VERB_EVOLVED:
		_hold([into])
		var alone: int = _build().shot_bits()
		_hold(Synergies.EVOLUTIONS[into])
		var with_it: int = _build().shot_bits()
		var pair: Array = Synergies.EVOLUTIONS[into].duplicate()
		_game.run.parts.assign(pair)
		_build().recompute()
		var without: int = _build().shot_bits()
		if alone != 0 or with_it != without or int(Parts.def(into).bits) != 0:
			added.append([into, ShotBits.names(alone), ShotBits.names(with_it), ShotBits.names(without)])
	var bare := Parts.EVOLVED["fault_hammer"].duplicate()
	bare.erase("bits")
	var planted_bits: int = PartDef.from_row("planted", bare).bits
	_report("verb rows add no shot bit", added.is_empty() and planted_bits != 0,
		"problems %s; planted fault_hammer row without \"bits\": [] carries %s" % [added, ShotBits.names(planted_bits)])
	var long_cards: Array = []
	for into in Parts.VERB_EVOLVED:
		var d: Resource = Parts.def(into)
		if not _card_ok(d.verb, d.text, String(Synergies.ROWS[Synergies.evolution_of(into)]["name"])):
			long_cards.append([into, d.verb, d.text])
	var nine := "Splits fly tight and knock machines back. From Shrapnel Bloom."
	_report("card words", long_cards.is_empty() and not _card_ok("Splits fly tight", nine, "Shrapnel Bloom")
		and not _card_ok("Splits fly tight", "Tight splits knock machines... From Shrapnel Bloom.", "Shrapnel Bloom"),
		"verb at most 6 words, text at most 8 ending on its trick, no ellipsis; over %s; planted nine-word and clipped texts refused" % [long_cards])


func _card_ok(verb: String, text: String, trick: String) -> bool:
	return _words(verb) <= 6 and _words(text) <= 8 and text.ends_with("From %s." % trick) and not "..." in verb + text \
		and not "…" in verb + text


# --- (b) Grapeshot Press ----------------------------------------------------------------

func _check_grapeshot() -> void:
	var p: Resource = _combat().pattern(_combat().active_weapon())
	_hold(["cross_split", "pin_setter"])
	var held_grape: bool = "grapeshot_press" in _game.run.parts
	var stamped := _pressed()
	var proc := _pressed("item_proc")
	var slam_share := Augments.SLAM_KNOCK * Combat.GRAPESHOT_KNOCK_SHARE
	_report("grapeshot stamps the weapon press", held_grape and float(stamped.get("split_angle_deg", -1.0)) == Combat.GRAPESHOT_ANGLE_DEG
		and float(stamped.get("split_knock", -1.0)) == maxf(float(p.knock), slam_share) and not proc.has("split_angle_deg"),
		"granted %s; press angle %s knock %s (shot knock %.1f, slam share %.1f); proc record keys %s" % [held_grape,
			stamped.get("split_angle_deg"), stamped.get("split_knock"), p.knock, slam_share, proc.has("split_angle_deg")])
	var grape := _split_flight(stamped, GRAPE_SITE)
	_hold(["cross_split", "hairline_fracture"])
	var plain_record := _pressed()
	var plain := _split_flight(plain_record, GRAPE_SITE + Vector3(0.0, 0.0, 120.0))
	_report("children fly at +/- 8 deg", _angles_are(grape["angles"], Combat.GRAPESHOT_ANGLE_DEG),
		"grapeshot children %s deg off the parent's line" % [grape["angles"]])
	_report("planted control: without the evolution, +/- 18 deg", _angles_are(plain["angles"], Bolts.SPLIT_ANGLE_DEG)
		and not plain_record.has("split_angle_deg") and not "grapeshot_press" in _game.run.parts,
		"cross split + hairline fracture (both Redjaw, no evolution) children %s deg" % [plain["angles"]])
	_report("children knock 0.5 x the slam's knock", grape["kid_knock"].all(func(k): return is_equal_approx(float(k), slam_share))
		and slam_share > float(p.knock) and plain["kid_knock"].all(func(k): return is_equal_approx(float(k), float(p.knock))),
		"grapeshot kid knock %s, plain kid knock %s, shot knock %.1f" % [grape["kid_knock"], plain["kid_knock"], p.knock])
	_report("the struck machine is shoved that hard", grape["struck_knock"].size() == 2 and plain["struck_knock"].size() == 2
		and grape["struck_knock"].all(func(k): return float(k) > float(plain["struck_knock"].max()) * 3.0),
		"machines on the children's lines shoved %s with grapeshot, %s without" % [grape["struck_knock"], plain["struck_knock"]])
	_report("family stays three bolts", grape["fired"] == 3 and plain["fired"] == 3 and grape["kids_spent_split"],
		"grapeshot flight fired %d, plain %d; children hold split spent %s" % [grape["fired"], plain["fired"], grape["kids_spent_split"]])
	var loud := {"dir": Vector3.FORWARD, "max_dist": 30.0, "damage": 10.0, "bits": ShotBits.bit("split"), "spent": 0, "knock": 20.0,
		"split_knock": 13.0, "split_angle_deg": 8.0}
	var kids: Array = Bolts.split_children(loud, Vector3.ZERO, 1, 0.0)
	_report("never below the shot's own knock", kids.size() == 2 and kids.all(func(k): return float(k["knock"]) == 20.0),
		"a 20-knock shot's children knock %s" % [kids.map(func(k): return k["knock"])])


# One record down -z at a machine 4 m out; the children it throws are read straight off the
# flight, then a machine is set on each child's own line 10 m on and the flight runs out.
func _split_flight(record: Dictionary, site: Vector3) -> Dictionary:
	var bolts = _combat().bolts
	var origin := BALL + site
	var first := _dummy(origin + Vector3.FORWARD * 4.0)
	var targets: Array = [first]
	var fired_before: int = bolts.fired
	bolts.fire(_aimed(record, origin))
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	var kids: Array = []
	for tick in 240:
		bolts.step(DT, space, targets)
		kids = (bolts.get("_bolts") as Array).filter(func(b): return (b["origin"] as Vector3).distance_to(origin) > 0.5)
		if not kids.is_empty():
			break
	var angles: Array = kids.map(func(k): return snappedf(rad_to_deg((k["dir"] as Vector3).angle_to(Vector3.FORWARD)), 0.01))
	var kid_knock: Array = kids.map(func(k): return float(k["knock"]))
	var spent_split: bool = not kids.is_empty() and kids.all(func(k): return ShotBits.has(int(k["spent"]), ShotBits.bit("split")))
	var line_targets: Array = []
	for kid in kids:
		line_targets.append(_dummy((kid["origin"] as Vector3) + (kid["dir"] as Vector3) * 10.0))
	targets.append_array(line_targets)
	_step(targets)
	var out := {"angles": angles, "kid_knock": kid_knock, "kids_spent_split": spent_split, "fired": bolts.fired - fired_before,
		"struck_knock": line_targets.map(func(t): return snappedf(_knock(t), 0.01))}
	_free(targets)
	return out


func _angles_are(angles: Array, deg: float) -> bool:
	return angles.size() == 2 and angles.all(func(a): return absf(float(a) - deg) < 0.05)


# --- (c) Hoar Barrel ----------------------------------------------------------------------

func _hoar_record() -> Dictionary:
	_hold(["frost_barb", "rime_rounds"])
	return _pressed()


func _check_hoar_dry() -> void:
	var record := _hoar_record()
	_report("hoar marks a piercing weapon press", "hoar_barrel" in _game.run.parts and bool(record.get("hoar", false))
		and ShotBits.has(int(record["bits"]), ShotBits.bit("pierce")), "granted %s, marked %s, bits %s" % ["hoar_barrel" in _game.run.parts,
			record.get("hoar", false), ShotBits.names(int(record["bits"]))])
	var field = _field()
	var origin := BALL + DRY_SITE
	var hit := _dummy(origin + Vector3.FORWARD * 4.0)
	var near := _dummy(origin + Vector3.FORWARD * 4.0 + Vector3.RIGHT * 1.8)
	var far := _dummy(origin + Vector3.FORWARD * 4.0 + Vector3.RIGHT * 3.2)
	var slabs_before: int = field.slab_count()
	var rings_before := _rings(2.0)
	_combat().bolts.fire(_aimed(record, origin))
	_step([hit, near, far])
	_report("dry ground: a 2 m frost patch, drawn", field.status_of(hit) == "frost" and field.status_of(near) == "frost"
		and field.status_of(far) == "" and _rings(2.0) > rings_before and field.slab_count() == slabs_before and _dealt(near) == 0.0,
		"struck %s, 1.8 m %s, 3.2 m '%s'; 2 m frost rings %d to %d; slabs %d to %d" % [field.status_of(hit), field.status_of(near),
			field.status_of(far), rings_before, _rings(2.0), slabs_before, field.slab_count()])
	_free([hit, near, far])


# Frost rings of this radius the field is drawing now.
func _rings(radius: float) -> int:
	return (_field().get("_puffs") as Array).filter(func(fx): return is_equal_approx(float(fx.get("grow", 0.0)), radius)).size()


func _check_hoar_wet() -> void:
	var record := _hoar_record()
	var field = _field()
	field.clear()
	_flood(WET_SITE)
	var origin := BALL + WET_SITE
	var made := _wet_run(record, origin, false)
	_report("over water the patch freezes and is spared", made["slabs"] == 1 and made["status"] == "frost" and made["burst"] == 0.0,
		"slabs after the shot %d, struck machine %s, item_proc dealt %.1f" % [made["slabs"], made["status"], made["burst"]])
	field.clear()
	var forgot := _wet_run(record, origin, true)
	_report("planted control: a shot that forgets its own slab bursts it", forgot["slabs"] == 0 and forgot["burst"] > 0.0,
		"slabs after the forgetful shot %d, item_proc dealt %.1f" % [forgot["slabs"], forgot["burst"]])
	field.clear()
	_pools.clear()


# A shot through a machine over water; `forget` empties the shot's spared list after each hit.
func _wet_run(record: Dictionary, origin: Vector3, forget: bool) -> Dictionary:
	var hit := _dummy(origin + Vector3.FORWARD * 6.0)
	var ahead := _dummy(origin + Vector3.FORWARD * 9.0 + Vector3.RIGHT * 1.6)
	var bolts = _combat().bolts
	var on_hit: Callable = bolts.on_hit
	if forget:
		bolts.on_hit = func(bolt: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
			on_hit.call(bolt, enemy, point, part)
			bolt["hoar_spared"] = []
	var before := _item_proc()
	bolts.fire(_aimed(record, origin))
	_step([hit, ahead])
	bolts.on_hit = on_hit
	var out := {"slabs": _field().slab_count(), "status": _field().status_of(hit), "burst": _item_proc() - before}
	_free([hit, ahead])
	return out


func _check_hoar_crossing() -> void:
	var record := _hoar_record()
	var field = _field()
	field.clear()
	var surface := _flood(CROSS_SITE)
	var origin := BALL + CROSS_SITE
	var centre := Vector3(origin.x, surface.y, origin.z) + Vector3.FORWARD * 8.0
	field.apply("frost", centre, "test")
	var placed: int = field.slab_count()
	var ahead := _dummy(origin + Vector3.FORWARD * 13.0 + Vector3.RIGHT * 1.6)
	var beside := _dummy(origin + Vector3.FORWARD * 8.0 + Vector3.RIGHT * 5.0)
	var behind := _dummy(origin + Vector3.FORWARD * 5.5 + Vector3.LEFT * 2.0)
	var scale: float = field.shatter_scale
	var want: float = float(Elements.ROWS["kinetic:ice"]["damage"]) * scale
	var before := _item_proc()
	var synergy_before := float(_combat().delivered_damage()["by_action"].get("synergy", 0.0))
	var cones: Array = []
	var heard := func(c: Dictionary) -> void: cones.append(c)
	field.shard_cone.connect(heard)
	_combat().bolts.fire(_aimed(record, origin))
	_step([ahead, beside, behind])
	field.shard_cone.disconnect(heard)
	var drawn: Node3D = cones[0]["node"] if not cones.is_empty() else null
	var cone_at: Vector3 = drawn.global_position if drawn != null else Vector3.INF
	_report("a crossed slab bursts with no machine on it", placed == 1 and field.slab_count() == 0 and cones.size() == 1
		and Vector2(cone_at.x - centre.x, cone_at.z - centre.z).length() < 0.01 and drawn.get_parent() == field
		and (cones[0]["struck"] as Array) == [ahead],
		"slabs %d to %d; cones %d drawn at %s (slab centre %s), struck %s" % [placed, field.slab_count(), cones.size(), cone_at, centre,
			(cones[0]["struck"] as Array).size() if not cones.is_empty() else -1])
	_report("the cone strikes 20 x the shatter dial ahead, as item_proc", is_equal_approx(_dealt(ahead), want)
		and is_equal_approx(_item_proc() - before, want) and scale == float(Synergies.ROWS["shatter_crew"]["dials"]["shatter_damage"])
		and is_equal_approx(float(_combat().delivered_damage()["by_action"].get("synergy", 0.0)) - synergy_before, want),
		"ahead took %.2f of %.2f (dial %.2f); item_proc ledger +%.2f" % [_dealt(ahead), want, scale, _item_proc() - before])
	_report("nothing beside or behind the cone", _dealt(beside) == 0.0 and _dealt(behind) == 0.0 and field.status_of(ahead) == "",
		"beside %.2f, behind %.2f; the shard strike left status '%s' (no arc, so no lock)" % [_dealt(beside), _dealt(behind), field.status_of(ahead)])
	var cone: Dictionary = cones[0] if not cones.is_empty() else {"at": Vector3.INF, "dir": Vector3.FORWARD, "length": 0.0, "half_angle": 0.0}
	# The wedge drawn down -z: as deep as the cone is long, as wide as its two edges at the tip.
	var box: AABB = (drawn.mesh as Mesh).get_aabb() if drawn != null else AABB()
	var width: float = 2.0 * ElementField.SHARD_CONE_LENGTH * sin(deg_to_rad(ElementField.SHARD_CONE_DEG))
	_report("the drawn cone is the struck cone", ElementField.in_shard_cone(cone, ahead.global_position)
		and not ElementField.in_shard_cone(cone, beside.global_position) and not ElementField.in_shard_cone(cone, behind.global_position)
		and is_equal_approx(box.size.z, ElementField.SHARD_CONE_LENGTH) and absf(box.size.x - width) < 0.01 and box.end.z <= 0.001,
		"ahead in %s, beside in %s, behind in %s; drawn wedge %.2f m deep, %.2f m wide (cone %.1f m, %.2f m at the tip)" % [
			ElementField.in_shard_cone(cone, ahead.global_position), ElementField.in_shard_cone(cone, beside.global_position),
			ElementField.in_shard_cone(cone, behind.global_position), box.size.z, box.size.x, ElementField.SHARD_CONE_LENGTH, width])
	_free([ahead, beside, behind])
	field.clear()


# A non-piercing weapon shot under a live Hoar Barrel (the pierce bit masked off) and a proc bolt
# do nothing; helix drill's pattern pierce alone marks the shot.
func _check_hoar_gates() -> void:
	var field = _field()
	field.clear()
	var origin := BALL + CROSS_SITE + Vector3(0.0, 0.0, 80.0)
	var surface := _flood(CROSS_SITE + Vector3(0.0, 0.0, 80.0))
	_hold(["frost_barb", "rime_rounds"], ShotBits.without(ShotBits.ALL, ShotBits.bit("pierce")))
	var unpierced := _pressed()
	var proc := _pressed("item_proc")
	var ran: Array = []
	for record in [unpierced, proc]:
		field.clear()
		field.apply("frost", surface + Vector3.FORWARD * 8.0, "test")
		# The shot flies over the slab with nothing in its way, then stops on a machine past it.
		var hit := _dummy(origin + Vector3.FORWARD * 14.0)
		var ahead := _dummy(origin + Vector3.FORWARD * 13.0 + Vector3.RIGHT * 1.6)
		_combat().bolts.fire(_aimed(record, origin))
		_step([hit, ahead])
		ran.append({"slabs": field.slab_count(), "status": field.status_of(hit), "hit": _dealt(hit) > 0.0, "ahead": _dealt(ahead)})
		_free([hit, ahead])
	_report("a non-piercing shot and a proc bolt do nothing", "hoar_barrel" in _game.run.parts and not unpierced.has("hoar")
		and not proc.has("hoar") and ran.all(func(r): return r["slabs"] == 1 and r["status"] == "" and r["hit"] and r["ahead"] == 0.0),
		"marked %s / %s; runs (slab crossed, machine past it struck) %s" % [unpierced.has("hoar"), proc.has("hoar"), ran])
	_hold(["frost_barb", "rime_rounds", "helix_drill"], ShotBits.without(ShotBits.ALL, ShotBits.bit("pierce")))
	var drilled := _pressed()
	_hold(["frost_barb", "helix_drill"])
	var no_evolution := _pressed()
	_report("helix drill's pattern pierce marks the shot", bool(drilled.get("hoar", false)) and int(drilled["pierce"]) > 0
		and not ShotBits.has(int(drilled["bits"]), ShotBits.bit("pierce")) and not no_evolution.has("hoar"),
		"pierce bit off, helix pierce %d: marked %s; without the evolution marked %s" % [int(drilled["pierce"]), drilled.get("hoar", false),
			no_evolution.has("hoar")])
	field.clear()


func _check_hoar_under_ball() -> void:
	var record := _hoar_record()
	var field = _field()
	field.clear()
	_pools.clear()
	var surface := _flood(Vector3.ZERO)
	field.apply("frost", Vector3(BALL.x, surface.y, BALL.z), "test")
	var under: Dictionary = field.slabs()[0] if field.slab_count() > 0 else {}
	field.apply("frost", Vector3(BALL.x, surface.y, BALL.z) + Vector3.FORWARD * 10.0, "test")
	var muzzle := BALL + Vector3.FORWARD * Combat.MUZZLE
	_combat().bolts.fire(_aimed(record, muzzle, 20.0))
	_step([])
	var kept: bool = field.slabs().has(under)
	_report("the slab under the ball stays, the one ahead bursts", not under.is_empty() and kept and field.slab_count() == 1
		and ElementField.stands_on(under, _game.player.ball_position(), 1.0),
		"under the ball kept %s, slabs left %d" % [kept, field.slab_count()])
	var burst: Dictionary = field.detonate_crossed_slabs(muzzle, muzzle + Vector3.FORWARD * 3.0, Vector3.FORWARD, BALL + Vector3(0.0, 0.0, 500.0), 1.0)
	_report("planted control: the same crossing without the ball bursts it", int(burst["detonated"]) == 1 and field.slab_count() == 0,
		"detonated %d, slabs left %d" % [int(burst["detonated"]), field.slab_count()])
	field.clear()
	_pools.clear()


# --- (d) Fault Hammer ----------------------------------------------------------------------

func _slam(at: Vector3, strength := 1.0) -> void:
	_game.ctx.events.slammed.emit(at, strength, 1.0)


func _check_fault() -> void:
	var combat = _combat()
	combat.heft_override = PILOT_HEFT
	_hold(["echo_locator", "brace_frame"])
	var at := BALL + FAULT_SITE
	var radius: float = _game.player.slam_radius()
	var inner := _dummy(at + Vector3.RIGHT * 2.0)
	var outer := _dummy(at + Vector3.RIGHT * 6.0)
	var out := _dummy(at + Vector3.RIGHT * (radius + 1.5))
	var reference := _dummy(at + Vector3.LEFT * 2.0 + Vector3.FORWARD * 30.0)
	# A stored dunk charge the aftershock must leave for the next reel.
	var dunk = _game.player.dunk
	dunk.store(40.0, "test", "test", Color.WHITE)
	var dunk_before := [dunk.stored_count, dunk.spent_count, dunk.held()]
	var slam_ledger := float(combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0))
	var before := _item_proc()
	_slam(at)
	var shape: Dictionary = _game.player.indicator.shapes.get(Combat.FAULT_LAYER, {})
	_report("the ring is committed and drawn at the landing", "fault_hammer" in _game.run.parts and combat.get("_aftershocks").size() == 1
		and shape.get("kind", "") == "ring" and (shape.get("centre", Vector3.INF) as Vector3).distance_to(at) < 0.001
		and is_equal_approx(float(shape.get("radius", 0.0)), radius) and shape.get("color") == _game.player.class_color(),
		"granted %s, waiting %d, drawn %s r %.2f in %s (pilot %s)" % ["fault_hammer" in _game.run.parts, combat.get("_aftershocks").size(),
			shape.get("kind", "none"), float(shape.get("radius", 0.0)), shape.get("color"), _game.player.class_color()])
	_tick_combat(0.30)
	_report("nothing lands at 0.30 s", _dealt(inner) == 0.0 and _dealt(outer) == 0.0 and combat.get("_aftershocks").size() == 1
		and float(_game.player.indicator.shapes.get(Combat.FAULT_LAYER, {}).get("fill", 0.0)) > 0.5,
		"inner %.2f, outer %.2f, waiting %d, sweep %.2f" % [_dealt(inner), _dealt(outer), combat.get("_aftershocks").size(),
			float(_game.player.indicator.shapes.get(Combat.FAULT_LAYER, {}).get("fill", 0.0))])
	_tick_combat(0.16)
	var first := [_dealt(inner), _dealt(outer), _dealt(out)]
	# The slam's own damage at each spot, struck through the real slam path on a stand-in.
	var half := func(dist: float) -> float:
		var hp: float = reference.hp
		combat.strike(reference, "slam", Augments.SLAM_KNOCK * (1.0 - dist / radius))
		var slam_hit: float = hp - reference.hp
		return slam_hit * Combat.FAULT_DAMAGE
	var inner_want: float = half.call(2.0)
	var outer_want: float = half.call(6.0)
	var by_formula: float = Dunk.slam_damage(Augments.SLAM_KNOCK, Combat.STRIKE_DAMAGE["slam"], PILOT_HEFT) * Combat.FAULT_DAMAGE * (1.0 - 2.0 / radius)
	_report("one aftershock at 0.45 s at half the slam's damage", is_equal_approx(first[0], inner_want) and is_equal_approx(first[1], outer_want)
		and first[2] == 0.0 and is_equal_approx(first[0], by_formula) and combat.get("_aftershocks").is_empty()
		and not _game.player.indicator.shapes.has(Combat.FAULT_LAYER),
		"inner %.3f (slam %.3f / 2), outer %.3f (want %.3f), outside the ring %.2f; formula %.3f" % [first[0], inner_want * 2.0,
			first[1], outer_want, first[2], by_formula])
	var double_scaled: float = by_formula * 1.2 * PILOT_HEFT
	_report("planted control: heft once, not twice", not is_equal_approx(first[0], double_scaled) and PILOT_HEFT > 1.0,
		"heft %.1f: a double-scaled hit would deal %.3f, dealt %.3f" % [PILOT_HEFT, double_scaled, first[0]])
	var reference_slams: float = (inner_want + outer_want) * 2.0
	_report("item_proc, no slam fact, no dunk", is_equal_approx(_item_proc() - before, first[0] + first[1])
		and is_equal_approx(float(combat.delivered_damage()["by_source"].get("drop_or_slam", 0.0)) - reference_slams, slam_ledger)
		and dunk_before[2] and [dunk.stored_count, dunk.spent_count, dunk.held()] == dunk_before and int(combat.get("_warden_slam_hits")) == 0,
		"item_proc +%.3f; drop_or_slam moved only by the stand-in's two reference slams; dunk %s to %s" % [_item_proc() - before,
			dunk_before, [dunk.stored_count, dunk.spent_count, dunk.held()]])
	_tick_combat(1.0)
	_report("it never repeats", _dealt(inner) == first[0] and _dealt(outer) == first[1],
		"a second later inner %.3f, outer %.3f" % [_dealt(inner), _dealt(outer)])
	_free([inner, outer, out, reference])
	combat.heft_override = -1.0


func _check_fault_ice_and_props() -> void:
	var combat = _combat()
	var field = _field()
	field.clear()
	_pools.clear()
	_hold(["echo_locator", "brace_frame"])
	var at := BALL + FAULT_SITE + Vector3(0.0, 0.0, 80.0)
	var surface := _flood(FAULT_SITE + Vector3(0.0, 0.0, 80.0))
	var radius: float = _game.player.slam_radius()
	var on_water := Vector3(at.x, surface.y, at.z)
	field.apply("frost", on_water + Vector3.RIGHT * 6.5, "test")
	field.apply("frost", on_water + Vector3.LEFT * 6.5, "test")
	field.apply("frost", on_water + Vector3.FORWARD * (radius + 6.0), "test")
	var placed: int = field.slab_count()
	var machine := _dummy(at + Vector3.BACK * 3.0)
	var scale: float = field.shatter_scale
	var heft_class: int = _game.run.heft_class()
	var spy := Destructibles.new()
	spy.build({"destructible_rows": [_piece("near_tier", heft_class + 1, at + Vector3.FORWARD * 4.0),
		_piece("heavy_tier", heft_class + 2, at + Vector3.BACK * 6.0 + Vector3.RIGHT * 4.0)]},
		{"ctx": _game.ctx, "root": _game.ctx.root, "no_visuals": true})
	spy.finish_build()
	_game.ctx.destructibles = spy
	_slam(at)
	_tick_combat(0.30)
	var early := [field.slab_count(), spy.state_of("near_tier"), spy.state_of("heavy_tier"), _dealt(machine)]
	_tick_combat(0.16)
	var aftershock: float = Combat.fault_damage(1.0, combat.heft()) * (1.0 - 3.0 / radius)
	var shard: float = float(Elements.ROWS["kinetic:ice"]["damage"]) * scale
	_report("both slabs in the ring shatter, the one outside stays", placed == 3 and early[0] == 3 and field.slab_count() == 1
		and (field.slabs()[0]["at"] as Vector3).distance_to(on_water + Vector3.FORWARD * (radius + 6.0)) < 0.5,
		"slabs %d, at 0.30 s %d, after %d" % [placed, early[0], field.slab_count()])
	_report("the shatter strikes 20 x the dial once", is_equal_approx(_dealt(machine), aftershock + shard) and early[3] == 0.0,
		"machine took %.3f = aftershock %.3f + shatter %.3f (dial %.2f)" % [_dealt(machine), aftershock, shard, scale])
	_report("a heft + 1 piece breaks, a heft + 2 piece stays", early[1] == "intact" and early[2] == "intact"
		and spy.state_of("near_tier") == "shattered" and spy.state_of("heavy_tier") == "intact",
		"class %d: tier %d %s to %s, tier %d %s to %s" % [heft_class, heft_class + 1, early[1], spy.state_of("near_tier"),
			heft_class + 2, early[2], spy.state_of("heavy_tier")])
	_game.ctx.destructibles = null
	spy.teardown()
	spy.free()
	_free([machine])
	field.clear()
	_pools.clear()


func _piece(id: String, tier: int, at: Vector3) -> Dictionary:
	return {"id": id, "tier": tier, "at": [at.x, at.y, at.z], "size": [1.0, 2.0, 1.0], "yaw_deg": 0.0}


func _check_fault_reset_and_control() -> void:
	var combat = _combat()
	_hold(["echo_locator", "brace_frame"])
	var at := BALL + FAULT_SITE + Vector3(0.0, 0.0, 160.0)
	_slam(at)
	_tick_combat(0.2)
	var waiting: int = combat.get("_aftershocks").size()
	combat._start_attempt()
	var machine := _dummy(at + Vector3.RIGHT * 2.0)
	_tick_combat(0.6)
	_report("a retry cancels a waiting aftershock", waiting == 1 and combat.get("_aftershocks").is_empty() and _dealt(machine) == 0.0
		and not _game.player.indicator.shapes.has(Combat.FAULT_LAYER), "waiting %d before the retry; after it the machine took %.2f" % [waiting,
			_dealt(machine)])
	_hold(["echo_locator"])
	_slam(at)
	_tick_combat(0.6)
	_report("planted control: one ingredient queues none", not "fault_hammer" in _game.run.parts and combat.get("_aftershocks").is_empty()
		and _dealt(machine) == 0.0, "holding %s: waiting %d, machine %.2f" % [_game.run.parts, combat.get("_aftershocks").size(), _dealt(machine)])
	_free([machine])
