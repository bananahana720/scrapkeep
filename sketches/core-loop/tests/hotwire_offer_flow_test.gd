extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Parts := preload("res://src/build/parts.gd")
const HotwireRules := preload("res://src/build/hotwire_rules.gd")
const HotwireChoice := preload("res://src/ui/hotwire_choice.gd")

# Unit HW1: the hot-wired Fit / Recycle offer after Warden I and Spark Tread (BUILD-SYSTEMS.md,
# Two hot-wired parts, H2), on the real Game.
#   - The offer opens once, on the first beacon_unsealed of the run, not on Warden II.
#   - Recycle pays the stated cogs once; a second Recycle and a later Fit do nothing.
#   - Fit adds a striped gate holding the part and changes run.parts only when that gate is
#     taken; a second Fit does nothing.
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
	build.hotwire_offered.connect(func(_id: String, _cogs: int): _offers += 1)
	_check("nothing before a warden", build.hotwire_pending()["state"] == "" and _offers == 0,
		"state \"%s\", offers %d" % [build.hotwire_pending()["state"], _offers])
	_game.events.beacon_unsealed.emit(1)
	var pending: Dictionary = build.hotwire_pending()
	_check("offer after warden I", _offers == 1 and pending["state"] == "open" and pending["part_id"] == "riveted_shell",
		"offers %d, %s" % [_offers, pending])
	_game.events.beacon_unsealed.emit(2)
	_check("none after warden II", _offers == 1, "offers %d after the second warden" % _offers)
	var price: int = Parts.hotwire_recycle("riveted_shell")
	_check("stated price", price == 20 and HotwireChoice.resolve("riveted_shell")["recycle"] == price
		and Parts.hotwire_recycle("spark_tread") == 30,
		"shell %d (choice shows %d), tread %d" % [price, HotwireChoice.resolve("riveted_shell")["recycle"], Parts.hotwire_recycle("spark_tread")])
	var cogs_before: int = run.cogs
	var paid: int = build.hotwire_recycle()
	_check("recycle pays once", paid == price and run.cogs == cogs_before + price,
		"paid %d, cogs %d -> %d" % [paid, cogs_before, run.cogs])
	var again: int = build.hotwire_recycle()
	var fit_after: bool = build.hotwire_fit()
	_check("second recycle nothing", again == 0 and not fit_after and run.cogs == cogs_before + price,
		"second recycle %d, fit after recycle %s, cogs %d" % [again, fit_after, run.cogs])
	# A fresh run: the offer comes again, and this time it is fitted.
	build._on_run_started("")
	_game.events.beacon_unsealed.emit(1)
	_check("new run offers again", _offers == 2 and build.hotwire_pending()["state"] == "open", "offers %d" % _offers)
	build._on_flow_changed("gates")
	var rolled: Array = build.gates.offers.map(func(o): return o["part_id"])
	var parts_before: Array = run.parts.duplicate()
	_check("gates without fit", not "riveted_shell" in rolled and rolled.size() == 2, "rolled %s" % [rolled])
	var cogs_fit: int = run.cogs
	var fitted: bool = build.hotwire_fit()
	var offered: Array = build.gates.offers.map(func(o): return o["part_id"])
	var striped: Array = build.gates.offers.filter(func(o): return o["hotwired"]).map(func(o): return o["part_id"])
	_check("fit holds the offer", fitted and offered == rolled + ["riveted_shell"] and striped == ["riveted_shell"]
		and run.parts == parts_before and run.cogs == cogs_fit,
		"gates %s, striped %s, parts unchanged %s, cogs %d" % [offered, striped, run.parts == parts_before, run.cogs])
	_check("second fit nothing", not build.hotwire_fit() and build.hotwire_recycle() == 0 and run.cogs == cogs_fit,
		"second fit and a recycle after fit change nothing")
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


# Wave 6 fix: a Recycle taken after the stage checkpoint pays cogs the retry rolls back, so the
# offer rolls back with them. The checkpoint holds the offer pending; a retry after Recycle puts
# the cogs and the open offer back and the choice can be made again (and pays once).
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
	game.events.beacon_unsealed.emit(1)
	run.snapshot(Vector3.ZERO, Vector3.ZERO, 0.0)
	var cogs_snap: int = run.cogs
	var paid: int = build.hotwire_recycle()
	_check("recycle paid before the retry", paid > 0 and run.cogs == cogs_snap + paid and build.hotwire_pending()["state"] == "recycle",
		"paid %d, cogs %d, state %s" % [paid, run.cogs, build.hotwire_pending()["state"]])
	game.flow.retry_stage()
	for i in 3:
		await process_frame
	var pending: Dictionary = build.hotwire_pending()
	_check("retry returns the cogs and the pending offer", run.cogs == cogs_snap and pending["state"] == "open" and pending["part_id"] == "riveted_shell"
		and build._hotwire_spent and run.extra["hotwire"]["state"] == "open",
		"cogs %d against snapshot %d, offer %s" % [run.cogs, cogs_snap, pending])
	var again: int = build.hotwire_recycle()
	_check("the choice pays once after the retry", again == paid and run.cogs == cogs_snap + paid, "paid %d, cogs %d" % [again, run.cogs])
	_resume_checks.call_deferred()


# 2026-10-04: a resolved Recycle survives Continue. resume_run emits run_started, which
# clears the offer's fields; the saved ones come back so Warden I does not offer twice.
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
	var paid: int = first.build.hotwire_recycle()
	first.flow.enter_stage(2, Vector3(0.0, 0.0, 14.0), false)
	var cogs_saved: int = first.run.cogs
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
	second.build.hotwire_offered.connect(func(_id: String, _cogs: int): offers[0] += 1)
	var resumed: bool = second.flow.resume_run()
	for i in 3:
		await process_frame
	var pending: Dictionary = second.build.hotwire_pending()
	second.events.beacon_unsealed.emit(1)
	second.events.beacon_unsealed.emit(2)
	_check("recycle survives continue", paid > 0 and resumed and offers[0] == 0 and pending["state"] == "recycle"
		and second.build.hotwire_pending()["state"] == "recycle" and second.run.cogs == cogs_saved,
		"paid %d, resumed %s, offers after resume %d, state %s, cogs %d against saved %d" % [paid, resumed, offers[0], pending["state"], second.run.cogs, cogs_saved])
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
				_phase = "gates"
				_clock = 0.0
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
				_phase = "resume"
				_retry_checks.call_deferred()
				return false
	return false
