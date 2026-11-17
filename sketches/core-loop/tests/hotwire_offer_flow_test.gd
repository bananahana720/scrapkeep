extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")

# Unit HW1, after the fold (systems audit pass D): a hot-wired part is a rare part the first
# Warden of each world puts up at the gates, and Spark Tread (BUILD-SYSTEMS.md, H2), on the real Game.
#   - Warden I puts the part up as a striped rare gate beside the pair, once per world, with no
#     Fit / Recycle screen (retired with its signals); Warden II adds nothing.
#   - run.parts changes only when the striped gate is taken; it waits at the gates until then.
#   - World one holds one hot-wired part; world two puts up a second.
#   - A retry rewinds a Warden break taken after the checkpoint; a save that still holds an
#     offer waiting on the old screen ("open") resumes with the part at the gates.
#   - Spark Tread: one activation per eligible attack after a 3 s recovery (both targets of
#     one attack share it), none inside the window, none at zero mass or below half cruise;
#     the bonus lands as 75% of the attack's punch in the next physics step.
#   - Wear: the same grounded cruise through build's wear path takes twice the mass fitted.
# Evidence limit: the Warden break is the beacon_unsealed fact flow emits, not a real kill; the
# struck facts are emitted on the bus at a dummy target; the ball speed is set on its state.


class Dummy:
	extends Node3D
	var hp := 100000.0
	var kind := "lobber"
	var taken: Array = []

	func take_damage(amount: float) -> float:
		taken.append(amount)
		hp -= amount
		return amount

var _failures := 0
# Sim seconds since the first activation, summed from the physics delta.
var _clock := 0.0
var _done := {}
var _game
var _ticks := 0
var _phase := "boot"
var _offers := 0
var _a: Dummy
var _b: Dummy


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _speed(share: float) -> void:
	_game.player.state.velocity = Vector3(_game.tuning.f("cruise") * share, 0.0, 0.0)


func _offer_checks() -> void:
	var build = _game.build
	var run = _game.ctx.run
	_check("nothing before a warden", build.hotwire_pending()["state"] == "" and build._hotwire_gate_ids().is_empty(),
		"state \"%s\"" % build.hotwire_pending()["state"])
	build._on_flow_changed("gates")
	var rolled: Array = build.gates.offers.map(func(o): return o["part_id"])
	build.gates.close()
	var parts_before: Array = run.parts.duplicate()
	var cogs_before: int = run.cogs
	_game.events.beacon_unsealed.emit(1)
	_check("warden I puts the part at the gates", _offers == 0 and build.hotwire_pending()["state"] == "fit"
		and build._hotwire_gate_ids() == ["riveted_shell"], "screen offers %d, %s" % [_offers, build.hotwire_pending()])
	_game.events.beacon_unsealed.emit(2)
	_check("nothing new after warden II", build._hotwire_gate_ids() == ["riveted_shell"], "gates %s" % [build._hotwire_gate_ids()])
	_check("a rare part on the ladder", Parts.has("riveted_shell") and Parts.rung_of("riveted_shell") == 1
		and Parts.def("riveted_shell").verb == HotwireRules.fill(Parts.hotwired("riveted_shell")["label"])
		and not "riveted_shell" in Parts.ids(), "rung %d, verb '%s'" % [Parts.rung_of("riveted_shell"), Parts.def("riveted_shell").verb])
	build._on_flow_changed("gates")
	var offered: Array = build.gates.offers.map(func(o): return o["part_id"])
	var striped: Array = build.gates.offers.filter(func(o): return o["hotwired"]).map(func(o): return o["part_id"])
	var shell: Array = build.gates.offers.filter(func(o): return o["part_id"] == "riveted_shell")
	_check("the gates hold it beside the pair", offered == rolled + ["riveted_shell"] and striped == ["riveted_shell"]
		and shell.size() == 1 and shell[0]["rarity"] == "rare" and run.parts == parts_before and run.cogs == cogs_before,
		"gates %s, striped %s, parts unchanged %s, cogs %d" % [offered, striped, run.parts == parts_before, run.cogs])
	# Gates already standing when the Warden breaks are put up again with it.
	build._on_run_started("")
	build._on_flow_changed("gates")
	_game.events.beacon_unsealed.emit(1)
	var reopened: Array = build.gates.offers.map(func(o): return o["part_id"])
	_check("standing gates gain it", reopened.size() == 3 and reopened[-1] == "riveted_shell", "gates %s" % [reopened])
	_check("the old screen is gone", not build.has_signal("hotwire_offered") and not build.has_method("hotwire_fit"), "build still has the Fit / Recycle hooks")
	# Closed until the end: taking a gate launches the ball, which the tread checks must not see.
	build.gates.close()


# Rolling through the striped gate is the normal gate path: run.add_part(id, "gate").
func _take_checks() -> void:
	var build = _game.build
	var run = _game.ctx.run
	var before: int = run.parts.count("riveted_shell")
	build.gates.chosen.emit("riveted_shell")
	_check("taken through the gate", before == 0 and run.parts.count("riveted_shell") == 1 and build._hotwire_gate_ids().is_empty(),
		"riveted_shell held %d -> %d, parts %s" % [before, run.parts.count("riveted_shell"), run.parts])


func _world_checks() -> void:
	var build = _game.build
	var run = _game.ctx.run
	run.parts.erase("spark_tread")
	_check("world-one fixture holds one hot-wired part", run.world == 1 and run.parts.has("riveted_shell")
		and not run.parts.has("spark_tread"), "world %d, parts %s" % [run.world, run.parts])
	_game.events.beacon_unsealed.emit(1)
	_check("world one cannot put up a second hot-wired part", build._hotwire_gate_ids().is_empty(), "gates %s" % [build._hotwire_gate_ids()])
	run.world = 2
	_game.events.beacon_unsealed.emit(1)
	_check("world two puts up a second hot-wired part", build._hotwire_gate_ids() == ["spark_tread"]
		and not run.parts.has("spark_tread"), "world %d, gates %s, parts %s" % [run.world, build._hotwire_gate_ids(), run.parts])
	build.gates.chosen.emit("spark_tread")
	_check("world two takes both hot-wired parts through gates", run.parts.count("riveted_shell") == 1
		and run.parts.count("spark_tread") == 1 and build._hotwire_gate_ids().is_empty(), "parts %s" % [run.parts])
	build._on_run_started("")
	build._hotwire_restore()
	_game.events.beacon_unsealed.emit(1)
	_check("world-two spent offer survives restore", build.hotwire_pending()["state"] == "fit"
		and build._hotwire_gate_ids().is_empty(), "pending %s" % [build.hotwire_pending()])
	_check("the old screen never opened", not _game.hud.has_method("hotwire_screen") and _game.hud.get("hotwire_screen") == null, "the HUD still holds a hot-wire screen")


func _tread_setup() -> void:
	var build = _game.build
	var run = _game.ctx.run
	_check("tread not fitted", not build.tread_fitted(), "no spark_tread held")
	run.add_part("spark_tread", "test")
	run.grant_start_mass(200.0)
	_check("tread fitted", build.tread_fitted(), "spark_tread held, flag %s" % _game.tuning.option("hotwire_tread"))
	_a = Dummy.new()
	_b = Dummy.new()
	_game.ctx.root.add_child(_a)
	_game.ctx.root.add_child(_b)


func _wear_checks() -> void:
	var build = _game.build
	var run = _game.ctx.run
	var losses: Array = []
	for fitted in [false, true]:
		if not fitted:
			run.parts.erase("spark_tread")
		else:
			run.parts.append("spark_tread")
		run.grant_start_mass(200.0)
		var before: float = run.metrics["wear_loss"]
		var step := 1.0 / Engine.physics_ticks_per_second
		for i in roundi(10.0 / step):
			_speed(1.0)
			_game.player.state.grounded = true
			build._step_armor(_game.player.ball_position(), step)
		losses.append(run.metrics["wear_loss"] - before)
	_check("double wear", losses[0] >= 4.0 and absf(losses[1] - 2.0 * losses[0]) <= 1.0,
		"10 s grounded at cruise: wear %.0f unfitted, %.0f fitted" % [losses[0], losses[1]])


# A Warden break after the checkpoint is rewound by a retry with the rest of the stage: the
# part leaves the gates, and the next Warden I puts it up again.
func _retry_checks() -> void:
	_game.free()
	var game := Game.new()
	game.test_mode = true
	root.add_child(game)
	_game = game
	await process_frame
	game.ctx.calm = true
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	for i in 5:
		await process_frame
	var build = game.build
	var run = game.run
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	game.events.beacon_unsealed.emit(1)
	_check("at the gates before the retry", build._hotwire_gate_ids() == ["riveted_shell"], "gates %s" % [build._hotwire_gate_ids()])
	game.flow.retry_stage()
	for i in 3:
		await process_frame
	_check("retry rewinds the warden's offer", build._hotwire_gate_ids().is_empty() and not build._hotwire_spent,
		"pending %s" % [build.hotwire_pending()])
	game.events.beacon_unsealed.emit(1)
	_check("warden I puts it up again", build._hotwire_gate_ids() == ["riveted_shell"], "gates %s" % [build._hotwire_gate_ids()])
	_resume_checks.call_deferred()


# A save carries the offer through Continue. resume_run emits run_started, which clears the
# offer's fields; the saved ones come back. A save from before the fold that holds an offer
# still waiting on the old Fit / Recycle screen ("open") resumes with the part at the gates.
func _resume_checks() -> void:
	var dir := "user://hotwire_offer_flow_test/"
	DirAccess.make_dir_recursive_absolute(dir)
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	_game.free()
	var first := Game.new()
	first.test_mode = true
	first.run_store_path = dir + "run.json"
	root.add_child(first)
	_game = first
	await process_frame
	first.ctx.calm = true
	first.player.source = Intent.Scripted.new()
	first.flow.press_start()
	first.flow.choose_class(0)
	for i in 5:
		await process_frame
	first.events.beacon_unsealed.emit(1)
	# Write the offer the way a save from before the fold held it: waiting on the screen.
	first.build._hotwire_state = "open"
	first.build._hotwire_save()
	first.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	first.free()
	var second := Game.new()
	second.test_mode = true
	second.run_store_path = dir + "run.json"
	root.add_child(second)
	_game = second
	await process_frame
	second.ctx.calm = true
	second.player.source = Intent.Scripted.new()
	var offers := [0]
	var resumed: bool = second.flow.resume_run()
	for i in 3:
		await process_frame
	var pending: Dictionary = second.build.hotwire_pending()
	second.events.beacon_unsealed.emit(1)
	second.events.beacon_unsealed.emit(2)
	_check("an old open offer resumes at the gates", resumed and offers[0] == 0 and pending["state"] == "fit"
		and second.build._hotwire_gate_ids() == ["riveted_shell"] and second.run.extra["hotwire"]["state"] == "fit",
		"resumed %s, screen offers %d, state %s, gates %s" % [resumed, offers[0], pending["state"], second.build._hotwire_gate_ids()])
	second.free()
	for name in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + name)
	print("hotwire_offer_flow_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _physics_process(delta: float) -> bool:
	if _phase == "resume" or _game.flow == null:
		return false
	_ticks += 1
	_clock += delta
	match _phase:
		"boot":
			_game.ctx.calm = true
			_game.player.source = Intent.Scripted.new()
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_phase = "settle"
			_ticks = 0
		"settle":
			if _ticks < 30:
				return false
			_offer_checks()
			_tread_setup()
			_speed(1.0)
			_game.events.enemy_struck.emit(_a, "ram", 10.0)
			_game.events.enemy_struck.emit(_b, "ram", 10.0)
			_check("first attack fires", _game.build.tread_fires == 1, "fires %d after a two-target ram" % _game.build.tread_fires)
			_phase = "landed"
			_clock = 0.0
		"landed":
			var punch: float = _game.ctx.spawner.punch_of("ram", 10.0)
			var want := punch * HotwireRules.BONUS
			var a_ok: bool = _a.taken.size() == 1 and is_equal_approx(_a.taken[0], want)
			var b_ok: bool = _b.taken.size() == 1 and is_equal_approx(_b.taken[0], want)
			_check("bonus lands on both", a_ok and b_ok, "want %.2f; a %s, b %s" % [want, _a.taken, _b.taken])
			_phase = "window"
			_ticks = 0
		"window":
			# 0.5 s and 2.8 s into the recovery: no new activation; 3.2 s: the next one.
			for at in [0.5, 2.8]:
				if _clock >= at and not _done.has(at):
					_done[at] = true
					_speed(1.0)
					_game.events.enemy_struck.emit(_a, "ram", 10.0)
					_check("none in window", _game.build.tread_fires == 1, "fires %d at %.2f s" % [_game.build.tread_fires, _clock])
			if _clock >= 3.2:
				_speed(1.0)
				_game.events.enemy_struck.emit(_a, "ram", 10.0)
				_check("fires after recovery", _game.build.tread_fires == 2, "fires %d at %.2f s" % [_game.build.tread_fires, _clock])
				# A target the same attack kills is freed before the bonus resolves in the next physics step:
				# the step must skip it (a freed object passed on is a script error, which fails the run) and
				# still pay the live target.
				var gone := Dummy.new()
				_game.ctx.root.add_child(gone)
				_game.events.enemy_struck.emit(gone, "ram", 10.0)
				gone.free()
				_phase = "freed"
				_clock = 0.0
		"freed":
			_check("the bonus skips a freed target and pays the live one", _a.taken.size() == 2, "a took %d" % _a.taken.size())
			_phase = "gates"
		"gates":
			# Recovery spent again; a slow ball and then a massless one take nothing.
			if _clock >= 3.2:
				_speed(0.4)
				_game.events.enemy_struck.emit(_a, "ram", 10.0)
				_check("not below half cruise", _game.build.tread_fires == 2, "fires %d at 0.4 cruise" % _game.build.tread_fires)
				_game.ctx.run.mass = 0.0
				_speed(1.0)
				_game.events.enemy_struck.emit(_a, "slam", 10.0)
				_check("off at zero mass", _game.build.tread_fires == 2, "fires %d at mass 0" % _game.build.tread_fires)
				_wear_checks()
				_take_checks()
				_world_checks()
				_phase = "resume"
				_retry_checks.call_deferred()
				return false
	return false
