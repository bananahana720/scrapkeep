extends SceneTree

const Measurement := preload("res://tools/pattern_dps.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Bolts := preload("res://src/combat/bolts.gd")
const Combat := preload("res://src/combat/combat.gd")
const Parts := preload("res://src/build/parts.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const BuildReadout := preload("res://src/ui/build_readout.gd")
const Enemy := preload("res://src/combat/enemy.gd")

# Shot bits in live combat (design-v3/ABILITY-MUTATIONS.md B1 to B4, unit U1): the build's
# held parts make the shot's bits, a player's own weapon press carries them, a proc volley
# and a weapon that fires no bolts carry none, and the two live bits (pierce and heat) do
# what their TABLE rule says. Each check has a planted failing control.
#
# (a) Build.shot_bits() is ShotBits.shot() over the held masks, under the live mask, for
#     random builds; a retry that restores the part list restores the bits.
# (b) a four-bit build drops the fourth bit in held order, and the build readout strikes it
#     out as a chip with no words.
# (c) a weapon press carries the bits, a child copies bits and spent, a proc volley (tree
#     volley, Kick Shot) carries 0; planted: a record with no bits fails the carry check.
# (d) the cannon lane, the sticky charge and rain, and Tally's cards fire no bolts and get 0.
# (e) pierce: one extra machine, then a stop; it adds to a pattern pierce (helix drill);
#     planted: a pierce that never spends passes the second machine.
# (f) heat: the first hit lights, a second inside the glow adds 15% once, a third inside the
#     same window adds nothing, and the bonus returns after the window; planted: a rule with
#     no cooldown bonuses the third hit.

const DT := 1.0 / 90.0
const RANDOM_BUILDS := 60
const BUILD_SIZE := 6
const SEED := 45
# The runtime aborts a check function on a script error without failing the run, so every
# check must report: fewer than this many verdicts is itself a failure.
const EXPECTED_REPORTS := 22

var _game
var _started := false
var _failures := 0
var _reports := 0
var _pierce := ShotBits.bit("pierce")
var _heat := ShotBits.bit("heat")


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
	if _game == null or _game.flow == null or _started:
		return false
	_started = true
	Measurement.prepare(_game)
	_check_default_mask()
	_check_build_matches_shot()
	_check_drop_and_readout()
	_check_carry()
	_check_no_bolt_weapons()
	_check_pierce()
	_check_heat_rule()
	_check_heat_live()
	_check_retry()
	if _reports != EXPECTED_REPORTS:
		_failures += 1
		print("FAIL report count: %d of %d checks reported (a check died mid-way)" % [_reports, EXPECTED_REPORTS])
	print("shot_bits_live_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _build():
	return _game.ctx.build


func _combat():
	return _game.ctx.spawner


func _hold(parts: Array, live_mask: int) -> void:
	_game.tuning.set_value("shot_bits_live", live_mask)
	_game.run.parts.assign(parts)
	_build().recompute()


func _masks(parts: Array) -> Array:
	var out: Array = []
	for id in parts:
		var d: Resource = Parts.def(id)
		if d != null:
			out.append(int(d.bits))
	return out


func _live_masks(parts: Array, live_mask: int) -> Array:
	return _masks(parts).map(func(mask: int) -> int: return ShotBits.live(mask, live_mask))


func _same(a: int, b: int) -> bool:
	return ShotBits.count(ShotBits.without(a, b)) + ShotBits.count(ShotBits.without(b, a)) < 1


func _check_default_mask() -> void:
	var fresh = load("res://src/movement/tuning.gd").new()
	var mask := int(fresh.f("shot_bits_live"))
	_report("default live mask", _same(mask, _pierce | _heat), "shot_bits_live opens at %d: %s" % [mask, ShotBits.names(mask)])


# (a) Random builds through the live build, at the full mask and the default one.
func _check_build_matches_shot() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var ids: Array = Parts.ids().filter(func(id): return Parts.def(id) != null)
	var wrong: Array = []
	var three := 0
	for i in RANDOM_BUILDS:
		var parts: Array = []
		for j in BUILD_SIZE:
			parts.append(ids[rng.randi_range(0, ids.size() - 1)])
		for live_mask in [ShotBits.ALL, _pierce | _heat]:
			_hold(parts, live_mask)
			var want: Dictionary = ShotBits.shot(_live_masks(parts, live_mask))
			var got: int = _build().shot_bits()
			if not _same(got, int(want["bits"])) or _build().dropped_shot_bits() != ShotBits.names(int(want["dropped"])):
				wrong.append([parts, live_mask, got, want])
			if live_mask == ShotBits.ALL and ShotBits.count(got) == ShotBits.MAX_SHOT_BITS:
				three += 1
	_report("build equals shot", wrong.is_empty() and three > 0,
		"%d random builds x 2 masks, %d mismatches %s; %d reach three bits" % [RANDOM_BUILDS, wrong.size(), wrong.slice(0, 2), three])
	_hold(["chain_arc", "hot_rivets", "long_barrel"], _pierce | _heat)
	var bits: int = _build().shot_bits()
	_report("live mask filters", _same(bits, _pierce | _heat) and _build().dropped_shot_bits().is_empty(),
		"bounce+heat, pierce, pull under the default mask carry %s and drop %s" % [ShotBits.names(bits), _build().dropped_shot_bits()])


# (b) The fourth bit drops in held order and the readout draws it struck through.
func _check_drop_and_readout() -> void:
	var held := ["chain_arc", "hot_rivets", "long_barrel"]
	_hold(held, ShotBits.ALL)
	var dropped: Array = _build().dropped_shot_bits()
	var bits: int = _build().shot_bits()
	_report("fourth bit drops", dropped == ["pull"] and _same(bits, ShotBits.bit("bounce") | _heat | _pierce),
		"held %s carry %s and drop %s" % [held, ShotBits.names(bits), dropped])
	_hold(["long_barrel", "chain_arc", "hot_rivets"], ShotBits.ALL)
	_report("held order decides", _build().dropped_shot_bits() == ["pierce"],
		"pull held first keeps pull and drops %s" % [_build().dropped_shot_bits()])
	_hold(held, ShotBits.ALL)
	var view := BuildReadout.new()
	root.add_child(view)
	view.show_build(_game.run.parts, {}, _build().dropped_shot_bits())
	var chips: Array = view.find_children("Bit_*", "Control", true, false)
	var struck: bool = chips.size() == 1 and chips[0].name == "Bit_pull" and chips[0].struck \
		and chips[0].color() == ShotBits.TABLE["pull"]["color"]
	var words: String = view.visible_text().to_lower()
	_report("readout strikes the chip", struck and not "dropped" in words and not "pull" in words,
		"%d chip(s) %s; the popup's words name it: %s" % [chips.size(), chips.map(func(c): return c.name), "pull" in words])
	var clean := BuildReadout.new()
	root.add_child(clean)
	clean.show_build(_game.run.parts, {}, [])
	_report("planted control: no drop, no chip", clean.find_children("Bit_*", "Control", true, false).is_empty(),
		"a build with nothing dropped draws no struck chip")
	view.free()
	clean.free()


# (c) The weapon press carries the bits; procs carry none; children copy bits and spent.
func _check_carry() -> void:
	var combat = _combat()
	var weapon: String = combat.active_weapon()
	_hold(["hot_rivets", "arc_coil"], ShotBits.ALL)
	var want: int = _build().shot_bits()
	combat.bolts.clear()
	combat._fire(weapon, "weapon")
	var pressed: Array = combat.bolts.get("_bolts").duplicate()
	combat.bolts.clear()
	combat._fire(weapon, "item_proc")
	var proc: Array = combat.bolts.get("_bolts").duplicate()
	combat.bolts.clear()
	combat._proc_volley(1.0)
	var volley: Array = combat.bolts.get("_bolts").duplicate()
	combat.bolts.clear()
	_report("weapon press carries the bits", _carry_problems(pressed, want).is_empty() and _same(want, _pierce | _heat),
		"%s fires %d bolt(s) carrying %s" % [weapon, pressed.size(), pressed.map(func(b): return ShotBits.names(int(b.get("bits", 0))))])
	_report("procs carry none", _carry_problems(proc, 0).is_empty() and _carry_problems(volley, 0).is_empty(),
		"item_proc fire %d bolt(s), tree volley / Kick Shot %d bolt(s), bits %s" % [proc.size(), volley.size(),
			(proc + volley).map(func(b): return int(b.get("bits", -1)))])
	var planted := [{"source": "weapon"}]
	_report("planted control: a record with no bits", not _carry_problems(planted, want).is_empty(),
		"a bolts.fire that omits bits fails the carry check: %s" % [_carry_problems(planted, want)])
	var parent := {"origin": Vector3.ZERO, "dir": Vector3.FORWARD, "bits": _pierce | _heat, "spent": _pierce, "travelled": 2.0}
	var child: Dictionary = Bolts.child(parent, {"dir": Vector3.RIGHT, "bits": 0, "spent": 0})
	_report("child copies bits and spent", _same(int(child["bits"]), _pierce | _heat) and _same(int(child["spent"]), _pierce)
		and Bolts.passes_left(child) == 0, "child carries %s, spent %s, passes left %d" % [ShotBits.names(child["bits"]),
			ShotBits.names(child["spent"]), Bolts.passes_left(child)])


func _carry_problems(records: Array, want: int) -> Array:
	var out: Array = []
	if records.is_empty():
		out.append("no bolts")
	for bolt in records:
		if not bolt.has("bits"):
			out.append("no bits")
		elif not _same(int(bolt["bits"]), want):
			out.append("bits %s" % [ShotBits.names(int(bolt["bits"]))])
	return out


# (d) A weapon that fires no bolts gives no bits, whatever is held.
func _check_no_bolt_weapons() -> void:
	var abilities = _game.player.abilities
	var base: String = abilities.id_of(AbilityState.WEAPON)
	_hold(["hot_rivets", "arc_coil"], ShotBits.ALL)
	var got := {}
	for id in ["cannon_lane", "sticky_charge", "sticky_rain", "ledger_reader"]:
		abilities.swap(AbilityState.WEAPON, id)
		got[id] = [_build().shot_bits(), _build().dropped_shot_bits().size()]
	abilities.swap(AbilityState.WEAPON, "claw_sweep")
	var claw: int = _build().shot_bits()
	abilities.swap(AbilityState.WEAPON, base)
	var zero := got.values().all(func(v): return int(v[0]) < 1 and int(v[1]) < 1)
	_report("no-bolt weapons get none", zero and _same(_build().shot_bits(), _pierce | _heat),
		"%s; back on %s the bits return" % [got, base])
	_report("planted control: a bolt weapon keeps them", _same(claw, _pierce | _heat),
		"Tarn's claw (no bolts key) carries %s" % [ShotBits.names(claw)])


# (e) Pierce in Bolts.step, through four machines in a row on the bolt's line.
func _check_pierce() -> void:
	var plain := _run_line(0, 0, false)
	var bit := _run_line(_pierce, 0, false)
	var drill := _run_line(_pierce, 1, false)
	var pattern_only := _run_line(0, 1, false)
	_report("bare bolt stops at the first", plain == [true, false, false, false], "hit %s" % [plain])
	_report("pierce passes one, then stops", bit == [true, true, false, false], "hit %s" % [bit])
	_report("pierce adds to helix drill", drill == [true, true, true, false] and pattern_only == [true, true, false, false],
		"pattern pierce 1 + bit hits %s; pattern alone %s" % [drill, pattern_only])
	var never_spent := _run_line(_pierce, 0, true)
	_report("planted control: a pierce that never spends", never_spent != [true, true, false, false],
		"refunding the pierce bit after each hit hits %s, past the second machine" % [never_spent])


# One bolt down a line of four machines: which were hit. refund clears spent after each hit.
func _run_line(bits: int, pierce: int, refund: bool) -> Array:
	var combat = _combat()
	combat.bolts.clear()
	var at: Vector3 = Measurement.BALL
	var targets: Array = []
	for i in 4:
		targets.append(Measurement._dummy(_game, at + Vector3.FORWARD * (4.0 + 3.0 * i)))
	var p: Resource = combat.pattern(Weapons.RAPID_LASER)
	var on_hit: Callable = combat.bolts.on_hit
	if refund:
		combat.bolts.on_hit = func(bolt: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
			on_hit.call(bolt, enemy, point, part)
			bolt["spent"] = 0
	combat.bolts.fire({"origin": at, "dir": Vector3.FORWARD, "speed": p.speed, "max_dist": 20.0, "damage": 10.0,
		"kind": Weapons.strike_kind(Weapons.RAPID_LASER), "weapon_id": Weapons.RAPID_LASER, "radius": p.bolt_radius,
		"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.0, "color": Color.WHITE,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": pierce, "source": "weapon", "bits": bits})
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for tick in 120:
		combat.bolts.step(DT, space, targets)
	combat.bolts.on_hit = on_hit
	var hit: Array = targets.map(func(t): return t.hp < t.max_hp)
	for t in targets:
		t.remove_from_group("enemy")
		t.free()
	combat.bolts.clear()
	return hit


# (f) The heat rule on its own state, against the planted rule with no cooldown.
func _check_heat_rule() -> void:
	var real := func(state: Dictionary, id: int, now: float) -> Dictionary: return Combat.heat_hit(state, id, now)
	var planted := func(state: Dictionary, id: int, now: float) -> Dictionary:
		var glowing := float(state.get(id, -INF)) > now
		state[id] = now + Combat.HEAT_GLOW
		return {"mult": Combat.HEAT_BONUS if glowing else 1.0, "lit": not glowing, "bonus": glowing}
	var problems := _heat_problems(real)
	_report("heat rule", problems.is_empty(), "glow %.1f s, bonus x%.2f: %s" % [Combat.HEAT_GLOW, Combat.HEAT_BONUS,
		"lights, bonuses once a window, returns after it" if problems.is_empty() else str(problems)])
	_report("planted control: heat with no cooldown", not _heat_problems(planted).is_empty(), str(_heat_problems(planted)))


func _heat_problems(rule: Callable) -> Array:
	var out: Array = []
	var state := {}
	var steps := [[0.0, 1.0, "first hit lights"], [0.5, Combat.HEAT_BONUS, "second inside the glow"],
		[1.0, 1.0, "third in the same window"], [1.9, 1.0, "fourth in the same window"],
		[2.6, Combat.HEAT_BONUS, "next window, still glowing"], [9.0, 1.0, "glow lapsed: lights again"]]
	for row in steps:
		var hit: Dictionary = rule.call(state, 7, float(row[0]))
		if not is_equal_approx(float(hit["mult"]), float(row[1])):
			out.append("%s at %.1f s gave x%.2f" % [row[2], row[0], hit["mult"]])
	var other: Dictionary = rule.call(state, 8, 9.1)
	if not is_equal_approx(float(other["mult"]), 1.0):
		out.append("a second machine shares the first's glow")
	return out


# (f) Heat through the live hit: the first hit lights, the second deals 15% more, the third not.
func _check_heat_live() -> void:
	var combat = _combat()
	var target: Node3D = Measurement._dummy(_game, Measurement.BALL + Vector3.FORWARD * 5.0)
	var bolt := {"color": Color.WHITE, "damage": 10.0, "kind": Weapons.strike_kind(Weapons.RAPID_LASER), "dir": Vector3.FORWARD,
		"knock": 0.0, "chain_jumps": 0, "source": "weapon", "bits": _heat}
	var dealt: Array = []
	var lit: Array = []
	for i in 3:
		var before: float = target.hp
		combat._on_bolt_hit(bolt, target, target.global_position, "")
		dealt.append(before - target.hp)
		lit.append(combat.heated(target))
	var cold: Node3D = Measurement._dummy(_game, Measurement.BALL + Vector3.FORWARD * 8.0)
	var plain := bolt.duplicate()
	plain["bits"] = 0
	var cold_dealt: Array = []
	for i in 2:
		var before: float = cold.hp
		combat._on_bolt_hit(plain, cold, cold.global_position, "")
		cold_dealt.append(before - cold.hp)
	var ratio: float = dealt[1] / maxf(dealt[0], 0.0001)
	_report("heat lights, then adds 15% once", lit.all(func(v): return v) and is_equal_approx(ratio, Combat.HEAT_BONUS)
		and is_equal_approx(dealt[2], dealt[0]), "dealt %s (x%.3f on the second), glowing %s" % [dealt, ratio, lit])
	_report("planted control: an unheated bolt", not combat.heated(cold) and is_equal_approx(cold_dealt[0], cold_dealt[1])
		and is_equal_approx(cold_dealt[0], dealt[0]), "dealt %s and lit nothing" % [cold_dealt])
	for t in [target, cold]:
		t.remove_from_group("enemy")
		t.free()


# (a) A retry that restores the part list restores the bits.
func _check_retry() -> void:
	var run = _game.run
	_hold(["hot_rivets", "arc_coil"], _pierce | _heat)
	var kept: int = _build().shot_bits()
	run.snapshot(Measurement.BALL, Vector3.ZERO, 0.0)
	_hold(["arc_coil"], _pierce | _heat)
	var changed: int = _build().shot_bits()
	_game.process_mode = Node.PROCESS_MODE_INHERIT
	_game.flow.retry_stage()
	var back: int = _build().shot_bits()
	_report("retry restores the bits", _same(back, kept) and not _same(changed, kept),
		"held %s before, %s after the change, %s after the retry (parts %s)" % [ShotBits.names(kept), ShotBits.names(changed),
			ShotBits.names(back), run.parts])
