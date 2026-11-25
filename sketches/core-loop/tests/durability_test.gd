extends SceneTree

const Game := preload("res://src/game.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const RunState := preload("res://src/core/run_state.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const Intent := preload("res://src/movement/intent.gd")

# The durability prototype (scrap as armour, DESIGN-NOTES): one damage order (mitigation,
# then scrap, then hull), the 75/25 spill in at most 6 clusters, recovered scrap that is
# not a fresh pickup, wear that is capped and grounded-only, class hysteresis, a restart
# that restores every new piece of state, and a flag-off game equal to the base.

var _failures := 0
var _game
var _phase := "boot"
var _ticks := 0
var _nodes: Array[Node] = []


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run(armor: bool, wear := false) -> RunState:
	var events := GameEvents.new()
	_nodes.append(events)
	var run := RunState.new(events)
	run.begin(load("res://src/core/class_def.gd").by_id("pylon_engineer"))
	run.armor_mode = armor
	run.wear_on = wear
	return run


func _initialize() -> void:
	_unit_checks()
	var t := Tuning.new()
	_check("flag defaults", t.armor() and t.wear_on() and t.base("route_seed") == 0.0 and t.base("start_mass") == 0.0,
		"scrap_mode %s, wear %s" % [t.option("scrap_mode"), t.option("wear")])
	var applied := t.apply_args(PackedStringArray(["--scrap=armor", "--wear=on", "--route-seed=7", "--start-mass=200", "--scrap=bogus"]))
	_check("flag parse", t.armor() and t.wear_on() and t.base("route_seed") == 7.0 and t.base("start_mass") == 200.0 and applied.size() == 4,
		"applied %s; an unknown value is refused" % [applied])
	var off := Tuning.new()
	off.apply_args(PackedStringArray(["--scrap=off", "--wear=on"]))
	_check("wear needs armour", not off.wear_on(), "--wear=on without armour does not wear")
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _unit_checks() -> void:
	# Damage order: a 12-damage hit on 100 scrap takes all 100 and 2 hull.
	var run := _run(true)
	run.grant_start_mass(100.0)
	var spills := []
	run.armor_hit.connect(func(removed: float, spill: int, _s: String): spills.append([removed, spill]))
	var hits := []
	run.events.player_hit.connect(func(a: float, _s: String): hits.append(a))
	run.damage(12.0, "t")
	_check("damage order", run.mass == 0.0 and is_equal_approx(run.hp, 98.0) and hits == [12.0] and is_equal_approx(run.metrics["hull_damage"], 2.0),
		"12 on 100 scrap: mass %.0f, hp %.1f, hit event %s (the whole hit), hull damage %.0f" % [run.mass, run.hp, hits, run.metrics["hull_damage"]])
	_check("75/25 split", spills == [[100.0, 75]] and is_equal_approx(run.metrics["destroyed"], 25.0) and is_equal_approx(run.metrics["hit_loss"], 100.0),
		"spill %s, destroyed %.0f" % [spills, run.metrics["destroyed"]])
	# A hit the scrap fully absorbs never touches the hull, but it is still a hit: player_hit
	# fires with the hit's size, so items, near-miss, the sound and the flash all hear it.
	var soft := _run(true)
	soft.grant_start_mass(100.0)
	var soft_hits := []
	soft.events.player_hit.connect(func(a: float, _s: String): soft_hits.append(a))
	soft.damage(4.0, "t")
	_check("absorbed hit", soft.mass == 60.0 and soft.hp == 100.0 and soft_hits == [4.0] and soft.metrics["hull_damage"] == 0.0,
		"4 on 100 scrap: mass %.0f, hp %.0f, hit events %s, hull damage %.0f" % [soft.mass, soft.hp, soft_hits, soft.metrics["hull_damage"]])
	# A deflect plate glances a hit off inside the order: scrap untouched, the hit still heard.
	var glance := _run(true)
	glance.grant_start_mass(100.0)
	glance.deflect_hook = func(_source: String) -> bool: return true
	var glance_hits := []
	glance.events.player_hit.connect(func(a: float, _s: String): glance_hits.append(a))
	glance.damage(12.0, "t")
	var no_glance := _run(true)
	no_glance.grant_start_mass(100.0)
	no_glance.deflect_hook = func(_source: String) -> bool: return false
	no_glance.damage(12.0, "t")
	_check("deflect before scrap", glance.mass == 100.0 and glance.hp == 100.0 and glance_hits == [12.0]
			and no_glance.mass == 0.0 and glance.metrics["hit_loss"] == 0.0,
		"glanced 12: mass %.0f (want 100), hit events %s; no glance: mass %.0f (want 0)" % [glance.mass, glance_hits, no_glance.mass])
	# A ward holds the hull at its floor once, in the same order (a lethal hit does not kill).
	var ward := _run(true)
	ward.hp = 30.0
	var ward_used := [false]
	ward.ward_hook = func(after: float) -> float:
		if ward_used[0] or after >= 20.0:
			return after
		ward_used[0] = true
		return 20.0
	ward.damage(50.0, "t")
	var held: float = ward.hp
	ward.damage(50.0, "t")
	_check("ward inside the order", held == 20.0 and not ward.alive(),
		"lethal hit held hull at %.0f, the second hit (ward spent) leaves hp %.0f" % [held, ward.hp])
	# Mitigation runs first: half of 12 is 6, all of it absorbed by 100 scrap.
	var mit := _run(true)
	mit.grant_start_mass(100.0)
	mit.mitigation = 0.5
	mit.damage(12.0, "t")
	_check("mitigation first", mit.mass == 40.0 and mit.hp == 100.0, "12 at 50%% reduction on 100 scrap: mass %.0f, hp %.0f" % [mit.mass, mit.hp])
	# A brace window joins the passive reduction before the scrap layer, per source.
	var brace := _run(true)
	brace.grant_start_mass(100.0)
	brace.mitigation = 0.5
	brace.brace_hook = func(source: String) -> float: return 0.5 if source == "spike" else 0.0
	brace.damage(16.0, "spike")
	var other := _run(true)
	other.grant_start_mass(100.0)
	other.brace_hook = brace.brace_hook
	other.damage(16.0, "saw")
	_check("brace before scrap", brace.mass == 60.0 and brace.hp == 100.0 and other.mass == 0.0,
		"16 at 50%% passive + 50%% brace: mass %.0f (want 60); other source: mass %.0f (want 0)" % [brace.mass, other.mass])
	# The spiral is observable: drops are counted apart from rises, and heft is logged per hit.
	var spiral := _run(true)
	spiral.grant_start_mass(400.0)
	spiral.damage(40.0, "t")
	_check("spiral metrics", spiral.metrics["class_drops"] >= 1 and spiral.metrics["heft_at_hits"].size() == 1
			and spiral.metrics["min_heft"] > 0.0 and spiral.metrics["min_heft"] == spiral.heft(),
		"drops %d, heft at hits %s, min heft %.2f" % [spiral.metrics["class_drops"], spiral.metrics["heft_at_hits"], spiral.metrics["min_heft"]])
	# Hull regeneration never regenerates scrap; wear and hits never touch the hull.
	var regen := _run(true, true)
	regen.grant_start_mass(100.0)
	regen.damage(25.0, "t")
	regen.since_damage = 99.0
	regen.advance(4.0)
	var mass_after_regen := regen.mass
	regen.hp = 50.0
	regen.wear_step(10.0, 14.0, 14.0, true)
	_check("regen and wear split", mass_after_regen == 0.0 and regen.hp == 50.0 and regen.metrics["wear_loss"] == 0.0,
		"regen left mass %.0f; wear on empty mass left hp %.0f" % [mass_after_regen, regen.hp])
	# Flag off: the base game on the same inputs.
	var base := _run(false)
	base.grant_start_mass(100.0)
	base.add_part("boost_coil", "t")
	base.mitigation = 0.9
	var base_hits := []
	base.events.player_hit.connect(func(a: float, _s: String): base_hits.append(a))
	base.damage(12.0, "t")
	base.wear_on = true
	base.wear_step(60.0, 14.0, 14.0, true)
	var expect_heft := 1.0 + 100.0 / 450.0 + 0.2
	_check("flag off equals base", is_equal_approx(base.hp, 88.0) and base.mass == 100.0 and base_hits == [12.0]
			and is_equal_approx(base.heft(), expect_heft) and base.metrics["wear_loss"] == 0.0,
		"hp %.0f, mass %.0f, hull hits %s, heft %.4f (parts count 0.2 each)" % [base.hp, base.mass, base_hits, base.heft()])
	# Wear: 30 a minute at cruise, scaled below, capped above, zero when inactive.
	var cruise := RunState.wear_rate(14.0, 14.0) * 60.0
	var slow := RunState.wear_rate(7.0, 14.0) * 60.0
	var fast := RunState.wear_rate(56.0, 14.0) * 60.0
	_check("wear rate", is_equal_approx(cruise, 30.0) and is_equal_approx(slow, 15.0) and is_equal_approx(fast, 30.0),
		"per minute: cruise %.1f, half cruise %.1f, 4x cruise %.1f" % [cruise, slow, fast])
	var worn := _run(true, true)
	worn.grant_start_mass(500.0)
	for i in 3600:
		worn.wear_step(1.0 / 60.0, 14.0, 14.0, true)
	var idle := _run(true, true)
	idle.grant_start_mass(500.0)
	for i in 3600:
		idle.wear_step(1.0 / 60.0, 14.0, 14.0, false)
	var fast_run := _run(true, true)
	fast_run.grant_start_mass(500.0)
	for i in 3600:
		fast_run.wear_step(1.0 / 60.0, 60.0, 14.0, true)
	_check("wear over a minute", absf(worn.metrics["wear_loss"] - 30.0) <= 1.0 and idle.mass == 500.0 and absf(fast_run.metrics["wear_loss"] - 30.0) <= 1.0 and worn.hp == worn.base_max_hp(),
		"cruise lost %.0f, inactive lost %.0f, 4x cruise lost %.0f, hull %.0f" % [worn.metrics["wear_loss"], 500.0 - idle.mass, fast_run.metrics["wear_loss"], worn.hp])
	# Class hysteresis: mass 225 is heft 1.5 (class II). Wear drains across it with no flicker.
	var h := _run(true, true)
	h.grant_start_mass(230.0)
	var drops := []
	var rises := []
	h.events.heft_class_dropped.connect(func(c: int, _h: float): drops.append(c))
	h.events.heft_class_changed.connect(func(c: int, _h: float): rises.append(c))
	h.mass = 228.0
	for i in 8:
		h.mass -= 1.0
		h._publish_heft_class()
	var held_at_220 := h.heft_class()
	for i in 12:
		h.mass -= 1.0
		h._publish_heft_class()
	var fell_at := h.mass
	for i in 6:
		h.recover_mass(1)
	var after_small := h.heft_class()
	h.recover_mass(20)
	_check("class hysteresis", held_at_220 == 2 and drops == [1] and fell_at == 208.0 and rises == [2] and after_small == 1,
		"class II held to mass 220, dropped once (drops %s) by mass %.0f, rose again only past 225 (rises %s)" % [drops, fell_at, rises])
	var flicker := _run(true, true)
	flicker.grant_start_mass(226.0)
	var changes_before: int = flicker.metrics["class_changes"]
	for i in 20:
		flicker.mass = 224.0 if i % 2 == 0 else 226.0
		flicker._publish_heft_class()
	_check("no flicker", flicker.metrics["class_changes"] == changes_before and flicker.heft_class() == 2,
		"224/226 around the threshold: %d class changes" % [int(flicker.metrics["class_changes"]) - changes_before])
	# Spill clusters: at most 6, value conserved, laid ahead of or beside the line.
	var field := ScrapField.new()
	root.add_child(field)
	field.setup()
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	field.drop_recovery(null, Vector3.ZERO, Vector3(0, 0, -1), 75, 6, rng)
	var ahead_ok := true
	for item in field._items:
		if item.position.z > -2.0:
			ahead_ok = false
	_check("spill clusters", field.recovery_count() == 6 and field.recovery_value() == 75 and ahead_ok,
		"75 spilled as %d clusters worth %d, all ahead of the ball %s" % [field.recovery_count(), field.recovery_value(), ahead_ok])
	field.clear()
	field.drop_recovery(null, Vector3.ZERO, Vector3(0, 0, -1), 3, 6, rng)
	_check("small spill", field.recovery_count() == 3 and field.recovery_value() == 3, "3 spilled as %d clusters" % field.recovery_count())
	field.clear()
	field.drop_recovery(null, Vector3.ZERO, Vector3(0, 0, -1), 5000, 999, rng)
	_check("cluster cap", field.recovery_count() == 6 and field.recovery_value() == 5000, "5000 asked as 999 clusters: %d clusters worth %d" % [field.recovery_count(), field.recovery_value()])
	field.free()
	for node in _nodes:
		node.free()
	_nodes.clear()


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.tuning.apply_args(PackedStringArray(["--scrap=armor", "--wear=on", "--route-seed=7", "--start-mass=300"]))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "armor"
			_ticks = 0
		"armor":
			if _ticks < 30:
				return false
			_armor_game_checks()
			_game.free()
			_game = Game.new()
			_game.test_mode = true
			root.add_child(_game)
			_phase = "off_boot"
			_ticks = 0
		"off_boot":
			if _ticks < 2:
				return false
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.tuning.apply_args(PackedStringArray(["--scrap=off", "--wear=off"]))
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "off"
			_ticks = 0
		"off":
			if _ticks < 30:
				return false
			_off_game_checks()
			print("durability_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
			_game.free()
			quit(0 if _failures == 0 else 1)
			return true
	return false


func _armor_game_checks() -> void:
	var run = _game.run
	var build = _game.build
	_check("route start", run.armor_mode and run.wear_on and run.mass == 300.0 and run.scrap == 0 and run.snapshot_value("mass") == 300.0,
		"mass %.0f, wallet %d, checkpoint mass %s" % [run.mass, run.scrap, run.snapshot_value("mass")])
	# Recovered scrap restores mass but is not a fresh pickup.
	var collected := [0]
	_game.events.scrap_collected.connect(func(_a, _b, _c): collected[0] += 1)
	var passes_before: int = build.bus.passes
	var ball: Vector3 = _game.player.ball_position()
	build.scrap.drop_recovery(null, ball, Vector3(0, 0, 1), 4, 1, _game.ctx.rng)
	for item in build.scrap._items:
		item.global_position = ball
	var mass_before: float = run.mass
	build.scrap.step(ball, 0.0, 0.02)
	build._step_armor(ball, 0.02)
	build._post(build.Triggers.Kind.ON_PICKUP, "control", 1.0, ball)
	_check("recovered is not fresh", run.mass == mass_before + 4.0 and collected[0] == 0 and run.scrap == 0 and run.metrics["recovered"] == 4.0,
		"cluster of 4: mass %.0f -> %.0f, scrap_collected %d, wallet %d" % [mass_before, run.mass, collected[0], run.scrap])
	build.bus.pending.clear()
	build.scrap.drop(ball, 1, _game.ctx.rng)
	for item in build.scrap._items:
		item.global_position = ball
	for at in build.scrap.step(ball, 0.0, 0.02):
		run.add_scrap(1, at)
		build._post(build.Triggers.Kind.ON_PICKUP, "scrap", 1.0, at)
	_check("fresh is a pickup", collected[0] == 1 and run.scrap == 1 and build.bus.pending.size() == 1,
		"control: a fresh piece fires scrap_collected %d and %d pickup commitment" % [collected[0], build.bus.pending.size()])
	build.bus.pending.clear()
	# A hit spills clusters into the field and the HUD's armour gauge flashes.
	var spill_from: float = run.mass
	run.damage(10.0, "test")
	_check("hit spills", build.scrap.recovery_count() >= 1 and build.scrap.recovery_count() <= 6 and run.mass < spill_from
			and build.scrap.recovery_value() == int(round((spill_from - run.mass) * 0.75)) and run.hp == run.base_max_hp(),
		"mass %.0f -> %.0f, %d clusters worth %d, hull %.0f" % [spill_from, run.mass, build.scrap.recovery_count(), build.scrap.recovery_value(), run.hp])
	# Mass lost to the hit above must not lower the hull ceiling at the next recompute.
	_check("hud armour readout", _game.hud._armor.visible and _game.hud._armor_flash > 0.0 and _game.hud._armor.label == ""
			and _game.hud._armor.fraction > 0.0,
		"armour gauge visible %s, flash %.2f, bar %.2f, no number (label \"%s\")" % [_game.hud._armor.visible, _game.hud._armor_flash,
			_game.hud._armor.fraction, _game.hud._armor.label])
	# Wear runs only in grounded stage play: not in flight, not paused.
	var flow = _game.flow
	_game.player.state.grounded = true
	_game.player.state.velocity = Vector3(0, 0, -14)
	var wear_before: float = run.metrics["wear_loss"]
	var stage_state: int = flow.state
	flow.state = flow.LAUNCH
	build._step_armor(ball, 120.0)
	var in_flight: float = run.metrics["wear_loss"] - wear_before
	flow.state = stage_state
	_game.player.state.grounded = false
	build._step_armor(ball, 120.0)
	var airborne: float = run.metrics["wear_loss"] - wear_before
	_game.player.state.grounded = true
	build._step_armor(ball, 120.0)
	var grounded_loss: float = run.metrics["wear_loss"] - wear_before
	_check("wear grounded only", in_flight == 0.0 and airborne == 0.0 and absf(grounded_loss - 60.0) <= 1.0,
		"120 s in flight lost %.0f, airborne %.0f, grounded at cruise %.0f" % [in_flight, airborne, grounded_loss])
	# Restart restores mass, class, wear and hull, and clears the live spill.
	var snap := {"mass": run.snapshot_value("mass"), "hp": run.snapshot_value("hp"), "heft_class": run.snapshot_value("heft_class"),
		"wear_accum": run.snapshot_value("wear_accum")}
	run.mass = 90.0
	run.hp = 40.0
	run._wear_accum = 0.7
	run._heft_class = 1
	var hit_loss_before: float = run.metrics["hit_loss"]
	flow.retry_stage()
	_check("restart restores state", run.mass == snap["mass"] and run.hp == snap["hp"] and run._heft_class == snap["heft_class"]
			and run._wear_accum == snap["wear_accum"] and build.scrap.recovery_count() == 0 and run.metrics["hit_loss"] == hit_loss_before,
		"mass %.0f/%.0f, hp %.0f/%.0f, class %d/%d, wear %.2f/%.2f, live spills %d, metrics kept"
			% [run.mass, snap["mass"], run.hp, snap["hp"], run._heft_class, snap["heft_class"], run._wear_accum, snap["wear_accum"], build.scrap.recovery_count()])
	# With Scrap Armor held, the ceiling ratchets up with mass but never falls with it.
	run.add_part("scrap_armor", "test")
	var max_held: float = run.max_hp
	run.mass = 2000.0
	build.recompute()
	var max_high: float = run.max_hp
	run.mass = 0.0
	build.recompute()
	_check("hull ceiling holds", max_high > max_held and run.max_hp == max_high,
		"Scrap Armor max hp %.0f -> %.0f at 2000 mass -> %.0f at 0 mass" % [max_held, max_high, run.max_hp])
	var heft_from_scrap: bool = is_equal_approx(run.heft(), 1.0 + run.mass / 450.0)
	run.add_part("boost_coil", "test")
	_check("armour heft is scrap alone", heft_from_scrap and is_equal_approx(run.heft(), 1.0 + run.mass / 450.0),
		"a part adds no heft in armour mode: heft %.4f" % run.heft())
	# The run log carries the metrics in armour mode.
	run.damage(5.0, "test")
	_game.run_log._write("lost")
	var line := _last_line(_game.run_log.storage_dir.path_join("runs.ndjson"))
	var parsed = JSON.parse_string(line) if line != "" else null
	_check("run log metrics", parsed != null and parsed.has("durability") and parsed["durability"].has("wear_loss") and parsed["durability"].has("reverse_seconds"),
		"durability keys %s" % [parsed["durability"].keys() if parsed != null and parsed.has("durability") else "missing"])
	_item_and_arena_checks()


func _item_and_arena_checks() -> void:
	var run = _game.run
	var build = _game.build
	var flow = _game.flow
	var ball: Vector3 = _game.player.ball_position()
	run.grant_start_mass(500.0)
	run.hp = run.max_hp
	# An armour-only hit fires the hit event and posts ON_DAMAGE_TAKEN to the items; the
	# hull is untouched.
	var heard := []
	_game.events.player_hit.connect(func(a: float, _s: String): heard.append(a))
	build.bus.pending.clear()
	var hull_before: float = run.hp
	var hull_metric: float = run.metrics["hull_damage"]
	run.damage(3.0, "test")
	var posted := false
	for c in build.bus.pending:
		if c.kind == build.Triggers.Kind.ON_DAMAGE_TAKEN:
			posted = true
	_check("armour-only hit is a hit", heard == [3.0] and posted and run.hp == hull_before and run.metrics["hull_damage"] == hull_metric,
		"3 on 500 scrap: player_hit %s, ON_DAMAGE_TAKEN posted %s, hull %.0f -> %.0f" % [heard, posted, hull_before, run.hp])
	build.bus.pending.clear()
	# The real deflect item resolves inside run.damage: some hits glance and cost no scrap.
	run.add_part("deflect_plate", "test")
	run.add_part("deflect_plate", "test")
	run.add_part("deflect_plate", "test")
	build.recompute()
	var glanced := 0
	var mass_free := true
	for i in 200:
		var before: float = run.mass
		run.damage(1.0, "test")
		if run.mass == before:
			glanced += 1
		else:
			run.mass = before
	_check("deflect item in the order", glanced >= 1 and glanced < 200 and build.effects.procs.get("deflect_plate", 0) == glanced,
		"200 hits of 1 with three plates: %d glanced (proc count %s), scrap untouched on each" % [glanced, build.effects.procs.get("deflect_plate", 0)])
	# The real ward holds the hull once inside run.damage, and the item's own after-the-fact
	# resolve does not stack a second heal.
	run.add_part("warden_ward", "test")
	build.recompute()
	run.mass = 0.0
	run.hp = 30.0
	run.damage(50.0, "test")
	var ward_hp: float = run.hp
	_check("ward item in the order", is_equal_approx(ward_hp, run.max_hp * 0.2) and run.alive(),
		"lethal hit at 30 hull, ward held it at %.1f (floor %.1f)" % [ward_hp, run.max_hp * 0.2])
	# The boss arena has no scrap field: a hit there drops no cluster that could never be
	# collected; the spill is destroyed and logged.
	run.parts.erase("deflect_plate")
	run.parts.erase("deflect_plate")
	run.parts.erase("deflect_plate")
	build.recompute()
	run.hp = run.max_hp
	run.grant_start_mass(200.0)
	var saved_state: int = flow.state
	flow.state = flow.BOSS
	build.scrap.clear()
	var destroyed_before: float = run.metrics["destroyed"]
	var arena_before: float = run.metrics["arena_destroyed"]
	var mass_pre: float = run.mass
	run.damage(10.0, "brindle_charge")
	var lost: float = mass_pre - run.mass
	flow.state = saved_state
	_check("no uncollectable spill in the arena", lost > 0.0 and build.scrap.recovery_count() == 0
			and is_equal_approx(run.metrics["destroyed"] - destroyed_before, lost) and is_equal_approx(run.metrics["arena_destroyed"] - arena_before, round(lost * 0.75)),
		"arena hit took %.0f scrap: %d clusters left, destroyed +%.0f, arena spill destroyed +%.0f" % [lost, build.scrap.recovery_count(), run.metrics["destroyed"] - destroyed_before, run.metrics["arena_destroyed"] - arena_before])


func _off_game_checks() -> void:
	var run = _game.run
	var hud = _game.hud
	run.add_part("boost_coil", "test")
	run.add_scrap(90, Vector3.ZERO)
	var hp_before: float = run.hp
	run.damage(12.0, "test")
	var mass_before: float = run.mass
	_check("off: damage path", not run.armor_mode and is_equal_approx(run.hp, hp_before - 12.0) and run.mass == mass_before and _game.build.scrap.recovery_count() == 0,
		"12 damage: hp %.0f -> %.0f, mass %.0f untouched, no spill" % [hp_before, run.hp, run.mass])
	_check("off: heft", is_equal_approx(run.heft(), 1.0 + run.mass / 450.0 + 0.2), "heft %.4f counts the part" % run.heft())
	var bottom: Array = hud.piece_rects()["bottom"]
	_check("off: hud", not hud._armor.visible and bottom.size() == 5 and not bottom.has(hud._rect_of(hud._armor)),
		"armour gauge hidden and unlisted, %d bottom pieces (ability bar, health, speed, cog wallet, chain counter)" % bottom.size())
	_game.build._step_armor(_game.player.ball_position(), 60.0)
	_game.run_log._write("lost")
	var line := _last_line(_game.run_log.storage_dir.path_join("runs.ndjson"))
	var parsed = JSON.parse_string(line) if line != "" else null
	_check("off: run log", parsed != null and not parsed.has("durability"), "no durability block in a flag-off line")


func _last_line(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var last := ""
	while not f.eof_reached():
		var l := f.get_line()
		if l != "":
			last = l
	return last
