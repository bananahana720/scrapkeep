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
const Grip := preload("res://src/movement/grip.gd")
const Palette := preload("res://src/core/palette.gd")

# Shot bits in live combat (design-v3/ABILITY-MUTATIONS.md B1 to B4, units U1 and U2): the
# build's held parts make the shot's bits, a player's own weapon press carries them, a proc
# volley and a weapon that fires no bolts carry none, and all five bits (pierce, bounce,
# split, pull and heat) do what their TABLE rule says. Each check has a planted failing control.
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
# Unit U2 (bounce, split, pull, the tells and the pair rows), against real walls:
# (g) bounce: the first wall reflects the bolt about its normal with the range it has left,
#     the second wall stops it; planted: a bounce that never spends glances twice.
# (h) bounce+pull+heat: the glance pulls and heats nothing, the body hit after it does both;
#     planted: a glance treated as a hit on the machine behind the wall reaches it.
# (i) split: two children at +/- SPLIT_ANGLE_DEG, half damage, never splitting again, so a
#     family is three bolts; planted: children that clear split from spent breed past three.
# (j) pierce+split: the children inherit spent minus pierce, so each pierces one machine.
# (k) pull: lighter comes, heavier holds, the ball never moves; pierce+pull pulls each
#     machine once, the first hardest; split+pull children pull nothing; planted: a rule that
#     ignores heft, and children whose spent omits pull.
# (l) tells: the bolt draws in its first bit's TABLE colour in NAMES order (never HAZARD) and
#     MULTI_BIT_WIDTH wider with two or three bits; a hit plays one bit sound, in NAMES order;
#     planted: the weapon colour on a bit bolt, and a tell that plays every acting bit.

const DT := 1.0 / 90.0
const RANDOM_BUILDS := 60
const BUILD_SIZE := 6
const SEED := 45
# The runtime aborts a check function on a script error without failing the run, so every
# check must report: fewer than this many verdicts is itself a failure.
const EXPECTED_REPORTS := 45
# The pilot heft the pull checks hold (combat.heft_override): a chaser (crawler, 1.4) is
# lighter, a plated brute (heavy, 4.0) heavier.
const PILOT_HEFT := 2.0
const LIGHT := "chaser"
const HEAVY := "plated_brute"
# Where the U2 checks stand, clear of each other and of the pierce line at x = 0.
const WALL_SITE := Vector3(40.0, 0.0, 0.0)
const OPEN_SITE := Vector3(80.0, 0.0, 0.0)
const WALL_GAP := 6.0
const GLANCE_DEG := 30.0
const SETTLE_FRAMES := 3

var _game
var _started := false
var _frames := 0
var _done := false
var _walls: Array = []
var _failures := 0
var _reports := 0
var _pierce := ShotBits.bit("pierce")
var _heat := ShotBits.bit("heat")
var _bounce := ShotBits.bit("bounce")
var _split := ShotBits.bit("split")
var _pull := ShotBits.bit("pull")


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
		_build_walls()
		return false
	# The walls join the physics space on a step; the bounce checks wait for it.
	_frames += 1
	if _frames < SETTLE_FRAMES:
		return false
	_done = true
	_check_default_mask()
	_check_build_matches_shot()
	_check_drop_and_readout()
	_check_carry()
	_check_no_bolt_weapons()
	_check_pierce()
	_check_heat_rule()
	_check_heat_live()
	_check_retry()
	_check_bounce()
	_check_glance_gates()
	_check_split()
	_check_family_bound()
	_check_pierce_split()
	_check_pull()
	_check_pull_pairs()
	_check_tint()
	_check_hit_tell()
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
	_report("default live mask", _same(mask, ShotBits.ALL), "shot_bits_live opens at %d: %s" % [mask, ShotBits.names(mask)])


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
	var kept: Array = ShotBits.names(_build().shot_bits())
	view.show_build(_game.run.parts, {}, _build().dropped_shot_bits(), kept)
	var chips: Array = view.find_children("Bit_*", "Control", true, false)
	var struck: Array = chips.filter(func(c): return c.struck)
	var whole: Array = chips.filter(func(c): return not c.struck)
	var drawn: bool = struck.size() == 1 and struck[0].name == "Bit_pull" and struck[0].color() == ShotBits.TABLE["pull"]["color"] \
		and whole.map(func(c): return String(c.name).trim_prefix("Bit_")) == ["pierce", "bounce", "heat"] \
		and whole.all(func(c): return c.color() == ShotBits.TABLE[c.bit]["color"]) and chips[chips.size() - 1] == struck[0]
	var words: String = view.visible_text().to_lower()
	_report("readout: kept chips, then the struck one", drawn and not "dropped" in words and not "pull" in words,
		"%d chip(s) %s, struck %s; the popup's words name it: %s" % [chips.size(), chips.map(func(c): return c.name),
			struck.map(func(c): return c.name), "pull" in words])
	var clean := BuildReadout.new()
	root.add_child(clean)
	_hold(["chain_arc", "hot_rivets"], ShotBits.ALL)
	clean.show_build(_game.run.parts, {}, _build().dropped_shot_bits(), ShotBits.names(_build().shot_bits()))
	var clean_chips: Array = clean.find_children("Bit_*", "Control", true, false)
	_report("planted control: no drop, no struck chip", clean_chips.size() == 3 and clean_chips.all(func(c): return not c.struck),
		"a build with nothing dropped draws %d whole chip(s) and no struck one" % clean_chips.size())
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
	for id in ["cannon_lane", "cannon_lane_walk", "sticky_charge", "sticky_rain", "ledger_reader"]:
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


# --- Unit U2: bounce, split, pull, tells and the pair rows -----------------------------

# Two long walls facing each other across WALL_SITE, WALL_GAP ahead and behind, on the world
# layer the bolts' ray reads (Bolts.WORLD_MASK). They hang off the tree root so the disabled
# game does not take them out of the physics space.
func _build_walls() -> void:
	var at: Vector3 = Measurement.BALL + WALL_SITE
	for side in [Vector3.FORWARD, Vector3.BACK]:
		var wall := StaticBody3D.new()
		wall.collision_layer = Bolts.WORLD_MASK
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(60.0, 8.0, 0.4)
		shape.shape = box
		wall.add_child(shape)
		root.add_child(wall)
		wall.global_position = at + side * WALL_GAP
		_walls.append(wall)


func _record(at: Vector3, dir: Vector3, bits: int, damage := 10.0) -> Dictionary:
	var p: Resource = _combat().pattern(Weapons.RAPID_LASER)
	return {"origin": at, "dir": dir.normalized(), "speed": p.speed, "max_dist": 40.0, "damage": damage,
		"kind": Weapons.strike_kind(Weapons.RAPID_LASER), "weapon_id": Weapons.RAPID_LASER, "radius": p.bolt_radius,
		"knock": 0.0, "chain_jumps": 0, "chain_range": 0.0, "chain_falloff": 0.0, "color": Color.WHITE,
		"wave_amp": 0.0, "wave_hz": 0.0, "phase": 0.0, "pierce": 0, "source": "weapon", "bits": bits}


# Fly one bolt (and whatever it throws) among targets until none is left in the air.
func _fly(bolt: Dictionary, targets: Array) -> void:
	var bolts = _combat().bolts
	bolts.fire(bolt)
	var space: PhysicsDirectSpaceState3D = _game.get_world_3d().direct_space_state
	for tick in 600:
		if bolts.live() < 1:
			return
		bolts.step(DT, space, targets)


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


func _dealt(t: Node3D) -> float:
	return t.max_hp - t.hp


func _planar_knock(t: Node3D) -> Vector3:
	var k: Vector3 = t.get("_knock")
	return Vector3(k.x, 0.0, k.z)


# Whether the machine's knock points at the ball, and how hard.
func _pulled_toward_ball(t: Node3D) -> bool:
	var toward: Vector3 = _game.player.ball_position() - t.global_position
	toward.y = 0.0
	var k := _planar_knock(t)
	return k.length() > 0.01 and k.normalized().dot(toward.normalized()) > 0.99


func _glance_dir() -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, -deg_to_rad(GLANCE_DEG))


# (g) Bounce off the first wall, stop at the second.
func _check_bounce() -> void:
	var real := _bounce_run(false)
	var normal := Vector3.BACK
	var want_dir := _glance_dir().bounce(normal)
	var glances: Array = real["glances"]
	var g: Dictionary = glances[0] if not glances.is_empty() else {}
	var ok: bool = glances.size() == 1 and real["stops"] == 1 and g["dir"].is_equal_approx(want_dir) \
		and absf(float(g["max_dist"]) - (40.0 - float(g["used"]))) < 0.2 and ShotBits.has(int(g["spent"]), _bounce)
	_report("bounce reflects once, then stops", ok, "%d glance(s) %s, %d stop(s); want dir %s and range 40 - used" % [glances.size(),
		glances.map(func(x): return [x["dir"], snappedf(x["max_dist"], 0.01), snappedf(x["used"], 0.01)]), real["stops"], want_dir])
	var planted := _bounce_run(true)
	_report("planted control: a bounce that never spends", planted["glances"].size() > 1,
		"refunding bounce after each glance glances %d times" % planted["glances"].size())


func _bounce_run(refund: bool) -> Dictionary:
	var bolts = _combat().bolts
	var at: Vector3 = Measurement.BALL + WALL_SITE
	var glances: Array = []
	var stops := [0]
	var on_bounce: Callable = bolts.on_bounce
	var on_stop: Callable = bolts.on_stop
	bolts.on_bounce = func(bolt: Dictionary, point: Vector3) -> void:
		glances.append({"dir": bolt["dir"], "max_dist": bolt["max_dist"], "spent": bolt["spent"],
			"used": at.distance_to(point)})
		on_bounce.call(bolt, point)
		if refund:
			bolt["spent"] = ShotBits.without(int(bolt["spent"]), _bounce)
	bolts.on_stop = func(point: Vector3, color: Color) -> void:
		stops[0] += 1
		on_stop.call(point, color)
	_fly(_record(at, _glance_dir(), _bounce), [])
	bolts.on_bounce = on_bounce
	bolts.on_stop = on_stop
	bolts.clear()
	return {"glances": glances, "stops": stops[0]}


# (h) The pair rows bounce+pull and bounce+heat: the glance is not a hit.
func _check_glance_gates() -> void:
	var real := _glance_run(false)
	_report("glance pulls and heats nothing; the body hit does both", real["hits"] == 1 and real["glances"] == 1
		and not real["behind_heated"] and not real["behind_pulled"] and real["body_heated"] and real["body_pulled"], str(real))
	var planted := _glance_run(true)
	_report("planted control: a glance treated as a hit", planted["behind_heated"] or planted["behind_pulled"], str(planted))


func _glance_run(as_hit: bool) -> Dictionary:
	var combat = _combat()
	var bolts = combat.bolts
	var heft: float = combat.heft_override
	combat.heft_override = PILOT_HEFT
	var at: Vector3 = Measurement.BALL + WALL_SITE
	var dir := _glance_dir()
	var wall_z := -WALL_GAP + 0.2
	var glance_at: Vector3 = at + dir * (absf(wall_z) / absf(dir.z))
	var out_dir := dir.bounce(Vector3.BACK)
	var body := _dummy(glance_at + out_dir * 4.0)
	var behind := _dummy(glance_at + Vector3.FORWARD * 1.5)
	var hits := [0]
	var glances := [0]
	var on_hit: Callable = bolts.on_hit
	var on_bounce: Callable = bolts.on_bounce
	bolts.on_hit = func(bolt: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
		hits[0] += 1
		on_hit.call(bolt, enemy, point, part)
	bolts.on_bounce = func(bolt: Dictionary, point: Vector3) -> void:
		glances[0] += 1
		on_bounce.call(bolt, point)
		if as_hit:
			on_hit.call(bolt, behind, behind.global_position, "")
	_fly(_record(at, dir, _bounce | _pull | _heat), [body, behind])
	bolts.on_hit = on_hit
	bolts.on_bounce = on_bounce
	combat.heft_override = heft
	var out := {"hits": hits[0], "glances": glances[0], "body_heated": combat.heated(body), "body_pulled": _pulled_toward_ball(body),
		"behind_heated": combat.heated(behind), "behind_pulled": _planar_knock(behind).length() > 0.01}
	_free([body, behind])
	return out


# (i) Split: two children at +/- the angle, half damage, and they never split again.
func _check_split() -> void:
	var r := _split_run(_split)
	var half := [r["left"], r["right"]].all(func(d): return is_equal_approx(float(d), float(r["first"]) * Bolts.SPLIT_DAMAGE))
	var far := _record(Vector3.ZERO, Vector3.FORWARD, _split)
	far["max_dist"] = 85.0
	far["travelled"] = 5.0
	var near := far.duplicate()
	near["travelled"] = 80.0
	var reach: Array = Bolts.split_children(far, Vector3.ZERO, 1).map(func(k): return k["max_dist"]) \
		+ Bolts.split_children(near, Vector3.ZERO, 1).map(func(k): return k["max_dist"])
	_report("split throws two half-damage children at +/- %.0f deg" % Bolts.SPLIT_ANGLE_DEG,
		r["fired"] == 3 and half and r["first"] > 0.0 and not r["beyond"] and reach == [Bolts.SPLIT_REACH, Bolts.SPLIT_REACH, 5.0, 5.0],
		"%s; children fly %s m (the rest of the range, at most %.0f)" % [r, reach, Bolts.SPLIT_REACH])
	# Hit-point remaining range: a short claw bolt (5 m) hitting at 2 m gives children 3 m even
	# if the step already advanced travelled to 5 m; a hit at the very end emits no zero-range kids.
	var short := _record(Vector3.ZERO, Vector3.FORWARD, _split)
	short["max_dist"] = 5.0
	short["travelled"] = 5.0
	var at_hit: Array = Bolts.split_children(short, Vector3.FORWARD * 2.0, 1, 2.0).map(func(k): return k["max_dist"])
	var at_tip: Array = Bolts.split_children(short, Vector3.FORWARD * 5.0, 1, 5.0)
	_report("split measures remaining range at the hit point and skips zero-range tips",
		at_hit == [3.0, 3.0] and at_tip.is_empty(), "at 2 m of 5 m: %s; at tip: %d kid(s)" % [at_hit, at_tip.size()])


# One split bolt down x = OPEN_SITE at a machine, three machines down each child's line and
# two down the parent's, spaced past a machine's reach (radius 1) from the other lines.
func _split_run(bits: int, clear_pull := false) -> Dictionary:
	var combat = _combat()
	var bolts = combat.bolts
	var heft: float = combat.heft_override
	combat.heft_override = PILOT_HEFT
	var at: Vector3 = Measurement.BALL + OPEN_SITE
	var first_at: Vector3 = at + Vector3.FORWARD * 4.0
	var first := _dummy(first_at)
	var lines: Array = []
	for side in [-1.0, 1.0]:
		var d := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(Bolts.SPLIT_ANGLE_DEG) * side)
		lines.append([_dummy(first_at + d * 5.0), _dummy(first_at + d * 9.0), _dummy(first_at + d * 13.0)])
	var parent_line := [_dummy(first_at + Vector3.FORWARD * 7.0), _dummy(first_at + Vector3.FORWARD * 11.0)]
	var on_hit: Callable = bolts.on_hit
	if clear_pull:
		bolts.on_hit = func(bolt: Dictionary, enemy: Node3D, point: Vector3, part: String) -> void:
			bolt["spent"] = ShotBits.without(int(bolt["spent"]), _pull)
			on_hit.call(bolt, enemy, point, part)
	var fired_before: int = bolts.fired
	var all: Array = [first] + lines[0] + lines[1] + parent_line
	_fly(_record(at, Vector3.FORWARD, bits), all)
	bolts.on_hit = on_hit
	combat.heft_override = heft
	var hit_on := func(row: Array) -> Array: return row.map(func(t): return _dealt(t) > 0.0)
	var out := {"fired": bolts.fired - fired_before, "first": _dealt(first), "left": _dealt(lines[0][0]), "right": _dealt(lines[1][0]),
		"left_line": hit_on.call(lines[0]), "right_line": hit_on.call(lines[1]), "parent_line": hit_on.call(parent_line),
		"beyond": _dealt(lines[0][1]) > 0.0 or _dealt(lines[1][1]) > 0.0 or _dealt(parent_line[0]) > 0.0,
		"first_pulled": _pulled_toward_ball(first),
		"children_pulled": [lines[0][0], lines[1][0]].map(func(t): return _planar_knock(t).length() > 0.01)}
	_free(all)
	return out


# (i) The family bound on the rule itself: every bolt a split makes is split again as if it
# struck a machine, until nothing new is thrown or 64 bolts exist.
func _check_family_bound() -> void:
	var real := _family(false)
	var planted := _family(true)
	_report("a split family is three bolts", real == 3, "one split bolt grows to %d bolts" % real)
	_report("planted control: children that clear split", planted > 3,
		"children that drop split from spent grow to %d bolts" % planted)


func _family(clear_split: bool) -> int:
	var parent := _record(Vector3.ZERO, Vector3.FORWARD, _split | _pierce)
	parent["spent"] = 0
	var open := [parent]
	var total := 1
	while not open.is_empty() and total < Bolts.MAX_LIVE:
		var next: Array = []
		for bolt in open:
			for kid in Bolts.split_children(bolt, Vector3.FORWARD, 1):
				if clear_split:
					kid["spent"] = ShotBits.without(int(kid["spent"]), _split)
				next.append(kid)
		total += next.size()
		open = next
	return total


# (j) pierce+split: the parent passes its first machine, each child pierces one machine and
# stops at the next, and nobody splits twice.
func _check_pierce_split() -> void:
	var r := _split_run(_pierce | _split)
	var want := [true, true, false]
	var spent := Bolts.split_spent(_pierce | _split)
	_report("pierce+split children pierce once and never split", r["fired"] == 3 and r["left_line"] == want
		and r["right_line"] == want and r["parent_line"] == [true, false]
		and not ShotBits.has(spent, _pierce) and ShotBits.has(spent, _split) and ShotBits.has(spent, _pull), str(r))


# (k) Pull on its own rule and through the live hit.
func _check_pull() -> void:
	var real := func(pilot: float, body: float, nth: int) -> float: return Combat.pull_force(pilot, body, nth)
	var planted := func(_pilot: float, _body: float, nth: int) -> float: return Combat.PULL_KNOCK * pow(Combat.PULL_FALLOFF, nth)
	_report("pull rule: lighter comes, heavier holds", _pull_problems(real).is_empty(), str(_pull_problems(real)))
	_report("planted control: a pull that ignores heft", not _pull_problems(planted).is_empty(), str(_pull_problems(planted)))
	var combat = _combat()
	var heft: float = combat.heft_override
	combat.heft_override = PILOT_HEFT
	var light := _dummy(Measurement.BALL + Vector3.FORWARD * 5.0 + Vector3.RIGHT * 2.0)
	var heavy := _dummy(Measurement.BALL + Vector3.FORWARD * 6.0 - Vector3.RIGHT * 2.0, HEAVY)
	var ball_before: Vector3 = _game.player.ball_position()
	var velocity_before: Vector3 = _game.player.state.velocity
	for t in [light, heavy]:
		combat._on_bolt_hit(_record(Measurement.BALL, Vector3.FORWARD, _pull), t, t.global_position, "")
	combat.heft_override = heft
	var still: bool = _game.player.ball_position() == ball_before and _game.player.state.velocity == velocity_before
	_report("pull: the lighter machine comes, the heavier holds, the ball stays", _pulled_toward_ball(light)
		and _planar_knock(heavy).length() < 0.001 and still, "heft %.1f vs light %.2f knock %s, heavy %.2f knock %s; ball still %s" % [
			PILOT_HEFT, Grip.heft_of(light), _planar_knock(light), Grip.heft_of(heavy), _planar_knock(heavy), still])
	_free([light, heavy])


func _pull_problems(rule: Callable) -> Array:
	var out: Array = []
	if float(rule.call(PILOT_HEFT, 1.4, 0)) <= 0.0:
		out.append("a lighter machine stays")
	if float(rule.call(PILOT_HEFT, 4.0, 0)) > 0.0:
		out.append("a heavier machine comes")
	if float(rule.call(PILOT_HEFT, INF, 0)) > 0.0:
		out.append("a machine with no heft comes")
	if not float(rule.call(PILOT_HEFT, 1.4, 1)) < float(rule.call(PILOT_HEFT, 1.4, 0)):
		out.append("the second pierced machine comes as hard as the first")
	return out


# (k) The pull pair rows: pierce+pull and split+pull.
func _check_pull_pairs() -> void:
	var combat = _combat()
	var heft: float = combat.heft_override
	combat.heft_override = PILOT_HEFT
	var at: Vector3 = Measurement.BALL + OPEN_SITE + Vector3.BACK * 20.0
	var row := [_dummy(at + Vector3.FORWARD * 4.0), _dummy(at + Vector3.FORWARD * 7.0), _dummy(at + Vector3.FORWARD * 10.0)]
	_fly(_record(at, Vector3.FORWARD, _pierce | _pull), row)
	combat.heft_override = heft
	var knocks: Array = row.map(func(t): return snappedf(_planar_knock(t).length(), 0.001))
	_report("pierce+pull pulls each pierced machine once, the first hardest", _pulled_toward_ball(row[0]) and _pulled_toward_ball(row[1])
		and knocks[0] > knocks[1] and knocks[2] < 0.001, "knock per machine %s" % [knocks])
	_free(row)
	# Real weapon knock (Arc Caster 5.0, Tarn's claw 8.0): pull replaces the weapon's away-shove
	# so both the first and second pierced machines still come toward the ball.
	var real_knock_ok := true
	var real_knock_detail: Array = []
	for weapon_knock in [5.0, 8.0]:
		combat.heft_override = PILOT_HEFT
		var pair := [_dummy(at + Vector3.FORWARD * 4.0), _dummy(at + Vector3.FORWARD * 7.0)]
		var b := _record(at, Vector3.FORWARD, _pierce | _pull)
		b["knock"] = weapon_knock
		_fly(b, pair)
		combat.heft_override = heft
		var p0 := _pulled_toward_ball(pair[0])
		var p1 := _pulled_toward_ball(pair[1])
		real_knock_ok = real_knock_ok and p0 and p1
		real_knock_detail.append([weapon_knock, p0, p1])
		_free(pair)
	_report("pull beats weapon away-knock on both pierced machines (arc 5, claw 8)", real_knock_ok, str(real_knock_detail))
	# Planted control: shoving away with claw knock 8 before calling enemy.knock toward the ball
	# loses the pull on the second pierced machine because Enemy.knock keeps the stronger shove.
	var naive := _dummy(at + Vector3.FORWARD * 7.0)
	naive.knock(Vector3.FORWARD, 8.0)
	var toward_naive: Vector3 = _game.player.ball_position() - naive.global_position
	toward_naive.y = 0.0
	naive.knock(toward_naive.normalized(), Combat.pull_force(PILOT_HEFT, Grip.heft_of(naive), 1))
	_report("planted control: applying weapon knock 8 before pull beats the second pull", not _pulled_toward_ball(naive),
		"knock %s" % [_planar_knock(naive)])
	_free([naive])
	var real := _split_run(_split | _pull)
	_report("split+pull: the first hit pulls, the children do not", real["first_pulled"] and real["children_pulled"] == [false, false]
		and real["left"] > 0.0 and real["right"] > 0.0, str(real))
	var planted := _split_run(_split | _pull, true)
	_report("planted control: children whose spent omits pull", planted["children_pulled"].has(true), str(planted))


# (l) The bolt's colour and width, on the rule and in the drawn MultiMesh.
func _check_tint() -> void:
	var wrong := _tint_problems(func(bolt: Dictionary) -> Color: return Bolts.tint(bolt))
	var plain := {"bits": 0, "color": Color.WHITE}
	var plain_ok := Bolts.tint(plain) == Color.WHITE and is_equal_approx(Bolts.width(plain), Bolts.WIDTH)
	_report("bolt colour follows NAMES order, never HAZARD; 2-3 bits draw wider", wrong.is_empty() and plain_ok,
		"%d of 31 sets wrong %s; a bare bolt keeps its weapon colour: %s" % [wrong.size(), wrong.slice(0, 3), plain_ok])
	var bolts = _combat().bolts
	bolts.clear()
	var at: Vector3 = Measurement.BALL + OPEN_SITE + Vector3.BACK * 40.0
	bolts.fire(_record(at, Vector3.FORWARD, 0))
	bolts.fire(_record(at + Vector3.RIGHT, Vector3.FORWARD, _heat | _split))
	bolts.fire(_record(at + Vector3.RIGHT * 2.0, Vector3.FORWARD, _pull | _heat | _bounce))
	# The headless renderer keeps no MultiMesh instance data, so read what _process writes.
	var drawn: Array = []
	for bolt in bolts.get("_bolts"):
		var row: Array = Bolts.instance(bolt, 1.0)
		var c: Color = row[1]
		drawn.append([Color(c.r, c.g, c.b), snappedf((row[0] as Transform3D).basis.x.length(), 0.0001)])
	bolts.clear()
	var want_drawn := [[Color.WHITE, Bolts.WIDTH], [ShotBits.TABLE["split"]["color"], Bolts.WIDTH * Bolts.MULTI_BIT_WIDTH],
		[ShotBits.TABLE["bounce"]["color"], Bolts.WIDTH * Bolts.MULTI_BIT_WIDTH]]
	var drawn_ok := true
	for i in 3:
		drawn_ok = drawn_ok and (drawn[i][0] as Color).is_equal_approx(want_drawn[i][0]) and is_equal_approx(drawn[i][1], want_drawn[i][1])
	_report("the drawn instance carries the tint and the width", drawn_ok, "drawn %s, want %s" % [drawn, want_drawn])
	var planted := _tint_problems(func(bolt: Dictionary) -> Color: return bolt["color"])
	_report("planted control: the weapon colour on a bit bolt", planted.size() == ShotBits.ALL,
		"a tint that ignores the bits gets %d of 31 sets wrong" % planted.size())


# The sets 1 to 31 a tint rule draws wrong (not the first bit's colour, or HAZARD), or at the
# wrong width.
func _tint_problems(tint_rule: Callable) -> Array:
	var wrong: Array = []
	for mask in range(1, ShotBits.ALL + 1):
		var bolt := {"bits": mask, "color": Color.WHITE}
		var want: Color = ShotBits.TABLE[ShotBits.names(mask)[0]]["color"]
		var tint: Color = tint_rule.call(bolt)
		var w := Bolts.width(bolt)
		var want_w := Bolts.WIDTH * (Bolts.MULTI_BIT_WIDTH if ShotBits.count(mask) >= 2 else 1.0)
		if tint != want or tint == Palette.HAZARD or not is_equal_approx(w, want_w):
			wrong.append([ShotBits.names(mask), tint, w])
	return wrong


# (l) One bit sound a hit, the first acting bit in NAMES order, read off its TABLE row.
func _check_hit_tell() -> void:
	var cases := [[_pierce | _split | _heat, "breach_crack"], [_split | _pull, "scrap_rip"], [_pull | _heat, "line_zip"],
		[_heat, "wear_sputter"], [_bounce, "shell_spring"], [0, ""]]
	var wrong: Array = cases.filter(func(c): return Combat.hit_tell(int(c[0])) != String(c[1]))
	_report("hit tell is the first acting bit's sound", wrong.is_empty(), "wrong %s" % [wrong])
	var audio = _game.presentation.audio if _game.get("presentation") != null else null
	var logged := -1
	var sounds: Array = []
	if audio != null:
		var before: int = audio.cue_log.size()
		var combat = _combat()
		var t := _dummy(Measurement.BALL + OPEN_SITE + Vector3.BACK * 60.0)
		var bolt := _record(Measurement.BALL, Vector3.FORWARD, _pierce | _split | _heat)
		bolt["acts"] = _pierce | _split
		combat._on_bolt_hit(bolt, t, t.global_position, "")
		_free([t])
		var shots: Array = audio.cue_log.slice(before).filter(func(row): return String(row[0]).begins_with("shot_"))
		logged = shots.size()
		sounds = shots.map(func(row): return row[1])
	_report("a pierce+split+heat hit plays one sound, the pierce crack", logged == 1 and sounds == ["breach_crack"],
		"%d bit sound(s) %s" % [logged, sounds])
	var every := ShotBits.tells(_pierce | _split | _heat).map(func(row): return row["sound"])
	_report("planted control: a tell that plays every acting bit", every.size() > 1,
		"playing each acting bit stacks %d sounds %s" % [every.size(), every])
