extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")

# K5 Smoke Trail inversion (--hotwire-shell=on --world-one-builds=on, BUILD-SYSTEMS.md K5 row):
# Riveted Shell's air-control factor is x0.75, and x1.25 while Kest glides with the world-one
# Smoke Trail taken. The glide edge is polled from kit.gliding in Build's physics step (no end
# signal exists), so the mod follows within STEP_TICKS physics ticks. The glide is driven through
# the real player tick: a jump press spends the air jump, then a held jump while falling makes
# augments._glide set kit.gliding; nothing here sets kit.gliding true (_setup only clears it to
# false between scenarios, which the next tick overwrites anyway). Fixture: state.air_actions
# is set to 1 before the press (the lifted ball never touched ground), the press spends it.
# K5 with S4 or R6 cannot co-occur through UpgradeTree.pick; overlaps are forced fixtures, and
# the highest active factor wins (a code choice from the R6 entry).
# Evidence limit: a fixture on the real Game; how the steering feels is unjudged.

const CLASS_ID := "demolitions_caster"
const STEP_TICKS := 2
const TRACE_TICKS := 90

var _failures := 0
var _game
var _player


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _ticks(n: int) -> void:
	for i in n:
		await physics_frame


func _ratio() -> float:
	return _game.tuning.f("air_control") / _game.tuning.base("air_control")


func _is(v: float) -> bool:
	return is_equal_approx(_ratio(), v) and is_equal_approx(_game.build.shell_air_factor(), v)


func _fmt() -> String:
	return "ratio %.3f, factor %.2f, gliding %s" % [_ratio(), _game.build.shell_air_factor(), _player.kit.gliding]


func _setup(picks: Array, world_one: bool, shell: bool) -> void:
	_game.tuning.set_option("world_one_builds", "on" if world_one else "off")
	_game.tuning.set_option("hotwire_shell", "on" if shell else "off")
	var tree = _player.tree
	for round in 2:
		tree.reset(CLASS_ID)
		tree.max_depth = 2 if world_one else 4
		tree.world_one = world_one
		for id in picks:
			tree.open_checkpoint()
			tree.pick(id)
		if round == 0:
			_player.fit_class(ClassDef.by_id(CLASS_ID))
	_release()
	_player.kit.gliding = false
	_game.run.parts.clear()
	_lift()
	_game.build.recompute()


func _lift() -> void:
	var body = _player.body()
	body.global_position = _player.ball_position() + Vector3(0.0, 30.0, 0.0)
	body.linear_velocity = Vector3.ZERO
	_player.state.air_actions = 1


# Real input: press jump (spends the air jump), keep it held; the ball rises, then falls and glides.
func _glide_input(extra := {}) -> void:
	_player.source.hold = {"jump_held": true}
	_player.source.hold.merge(extra)
	_player.source.press = {"jump_pressed": true}


func _release() -> void:
	_player.source.hold = {}
	_player.source.press = {}


# Ticks until kit.gliding, at most 200. Returns the count, -1 if it never glided.
func _to_glide(extra := {}) -> int:
	_glide_input(extra)
	for i in 200:
		await physics_frame
		if _player.kit.gliding:
			return i + 1
	return -1


# Kest has no sprint. The fixture gives the kit the SPRINT augment in place of BLINK (which
# would take the same RMB press), a slot duration and a movement charge; the sprint itself
# still starts from the real movement press through augments._sprint.
func _sprint_fixture(on: bool) -> void:
	var kit = _player.kit
	kit.set_on(Augments.SPRINT, on)
	kit.set_on(Augments.BLINK, not on)
	var slot = kit.abilities.slot(AbilityState.MOVEMENT)
	slot.duration = 5.0 if on else 0.0
	if on:
		_player.abilities.grant(AbilityState.MOVEMENT)


func _vault() -> void:
	_game.events.vault_kicked.emit(_player.ball_position(), 20.0)


# Per-tick vertical velocity from the jump press for TRACE_TICKS, plus the tick gliding began.
func _trace() -> Dictionary:
	_lift()
	_glide_input()
	var vy: Array = []
	var start := -1
	for i in TRACE_TICKS:
		await physics_frame
		vy.append(_player.body().linear_velocity.y)
		if start < 0 and _player.kit.gliding:
			start = i
	return {"vy": vy, "start": start, "final": vy.back(), "glide_ticks": vy.size() - start if start >= 0 else 0}


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if absf(a[i] - b[i]) > 0.0001:
			return false
	return true


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_player = _game.player
	_player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.class_def = ClassDef.by_id(CLASS_ID)
	_player.fit_class(ClassDef.by_id(CLASS_ID))
	await _ticks(30)
	var build = _game.build
	# Re-pinned 2026-11-24 (E2-09, PILOT-CADENCE §6.2): K5 sits under Keg in World 1; sibling is Ghost.
	var k5 := ["k_keg", "k_smoke_trail"]

	_setup(k5, true, true)
	await _ticks(STEP_TICKS)
	_check("Kest kit glides", _player.kit.on(Augments.GLIDE) and build._smoke_trail_k5() and _game.flow.in_play(),
		"glide on %s, K5 %s, in play %s" % [_player.kit.on(Augments.GLIDE), build._smoke_trail_k5(), _game.flow.in_play()])
	_check("before glide x0.75", _is(0.75) and not _player.kit.gliding and not _player.state.grounded, "%s, grounded %s" % [_fmt(), _player.state.grounded])
	var n: int = await _to_glide()
	await _ticks(STEP_TICKS)
	_check("real input glides", n > 0 and _player.kit.gliding and _player.state.air_actions <= 0, "glided after %d ticks, air_actions %d" % [n, _player.state.air_actions])
	_check("gliding x1.25", _is(1.25), _fmt())
	await _ticks(10)
	_check("still x1.25 mid glide", _player.kit.gliding and _is(1.25), _fmt())

	# Recompute during the glide keeps the flip and stacks with a part's mod.
	_game.run.parts.append("slipstream")
	build.recompute()
	var part_mod: float = build.sheet.mod("air_control")
	_check("recompute during glide", _player.kit.gliding and is_equal_approx(_ratio(), part_mod * 1.25) and part_mod > 1.0,
		"ratio %.4f, part x%.2f, expected %.4f" % [_ratio(), part_mod, part_mod * 1.25])
	_release()
	await _ticks(STEP_TICKS)
	_check("after glide x0.75 (part)", not _player.kit.gliding and is_equal_approx(_ratio(), part_mod * 0.75), "%s, expected %.4f" % [_fmt(), part_mod * 0.75])
	_game.run.parts.clear()
	build.recompute()

	# The cloak on glide is combat's; confirm it holds with the shell on.
	_setup(k5, true, true)
	await _to_glide()
	await _ticks(STEP_TICKS)
	_check("glide keeps the cloak", _player.kit.gliding and _player.kit.cloaked, "gliding %s, cloaked %s" % [_player.kit.gliding, _player.kit.cloaked])
	_release()

	# Control path (Ghost under Keg): no change through a glide.
	_setup(["k_keg", "k_ghost"], true, true)
	var n6: int = await _to_glide()
	await _ticks(STEP_TICKS)
	_check("K6 path stays x0.75", n6 > 0 and _player.kit.gliding and _is(0.75) and not build._smoke_trail_k5(), "%s, K5 %s" % [_fmt(), build._smoke_trail_k5()])
	_release()
	await _ticks(STEP_TICKS)
	_check("K6 path after glide x0.75", _is(0.75), _fmt())

	# No shell: 1.0 throughout.
	_setup(k5, true, false)
	await _ticks(STEP_TICKS)
	var before := _is(1.0)
	var ns: int = await _to_glide()
	await _ticks(STEP_TICKS)
	_check("no shell stays x1.0", before and ns > 0 and _player.kit.gliding and _is(1.0), "before %s, %s" % [before, _fmt()])
	_release()
	await _ticks(STEP_TICKS)
	_check("no shell after glide x1.0", _is(1.0), _fmt())

	# World-one profile off: K5 taken (base tree under k_ghost), stays x0.75.
	_setup(["k_ghost", "k_smoke_trail"], false, true)
	var nw: int = await _to_glide()
	await _ticks(STEP_TICKS)
	_check("world-one off stays x0.75", nw > 0 and _player.kit.gliding and _is(0.75) and not build._smoke_trail_k5(),
		"%s, picks %s, world_one %s" % [_fmt(), _player.tree.picks, _player.tree.world_one])
	_release()

	# K5 with S4: highest wins in both orders (forced fixture).
	_setup(k5, true, true)
	_player.tree.picks.append("s_face_runner")
	build.recompute()
	_check("forced K5+S4 fixture", build._face_runner_s4() and build._smoke_trail_k5(), "S4 %s, K5 %s" % [build._face_runner_s4(), build._smoke_trail_k5()])
	await _to_glide()
	await _ticks(STEP_TICKS)
	var glide_only: bool = _player.kit.gliding and _is(1.25)
	_vault()
	await _ticks(1)
	_check("K5+S4 glide then vault: 1.25", glide_only and _player.kit.gliding and _is(1.25), "glide alone x1.25 %s, %s" % [glide_only, _fmt()])
	_release()
	await _ticks(STEP_TICKS)
	_check("K5+S4 glide ended in window: 1.25", not _player.kit.gliding and _is(1.25), _fmt())
	await _ticks(roundi(2.2 * Engine.physics_ticks_per_second))
	_check("K5+S4 window closed: 0.75", _is(0.75), _fmt())
	_setup(k5, true, true)
	_player.tree.picks.append("s_face_runner")
	build.recompute()
	_vault()
	await _ticks(STEP_TICKS)
	var vault_only := _is(1.25)
	await _to_glide()
	await _ticks(STEP_TICKS)
	_check("K5+S4 vault then glide: 1.25", vault_only and _player.kit.gliding and _is(1.25), "vault alone x1.25 %s, %s" % [vault_only, _fmt()])
	_release()
	await _ticks(roundi(2.2 * Engine.physics_ticks_per_second))
	_check("K5+S4 all over: 0.75", not _player.kit.gliding and _is(0.75), _fmt())

	# K5 with R6: forced fixture. Kest has no sprint, so the SPRINT augment is switched on and
	# the sprint is driven by the real movement press; the factor must stay 1.25 (max), not drop to 1.0.
	_setup(k5, true, true)
	_player.tree.picks.append("r_second_wind")
	build.recompute()
	_sprint_fixture(true)
	_check("forced K5+R6 fixture", build._second_wind_r6() and build._smoke_trail_k5(), "R6 %s, K5 %s" % [build._second_wind_r6(), build._smoke_trail_k5()])
	await _to_glide()
	await _ticks(STEP_TICKS)
	_player.source.hold = {"jump_held": true, "movement_held": true}
	_player.source.press = {"movement_pressed": true}
	await _ticks(STEP_TICKS + 1)
	var both: bool = _player.kit.gliding and _player.kit.sprinting
	_check("K5+R6 glide then sprint: 1.25", both and _is(1.25), "both active %s, %s, sprinting %s" % [both, _fmt(), _player.kit.sprinting])
	_release()
	_sprint_fixture(false)
	await _ticks(STEP_TICKS + 2)
	_setup(k5, true, true)
	_player.tree.picks.append("r_second_wind")
	build.recompute()
	_sprint_fixture(true)
	_player.source.hold = {"movement_held": true}
	_player.source.press = {"movement_pressed": true}
	await _ticks(STEP_TICKS + 1)
	var sprint_only: bool = _player.kit.sprinting and not _player.kit.gliding and _is(1.0)
	await _to_glide({"movement_held": true})
	await _ticks(STEP_TICKS)
	var both2: bool = _player.kit.gliding and _player.kit.sprinting
	_check("K5+R6 sprint then glide: 1.25", sprint_only and both2 and _is(1.25), "sprint alone x1.0 %s, both %s, %s" % [sprint_only, both2, _fmt()])
	_release()
	_sprint_fixture(false)

	# Glide lift, duration and fall speed against base, same height, same input.
	_setup(k5, true, true)
	var with_k5: Dictionary = await _trace()
	_release()
	_setup(k5, true, false)
	var no_shell: Dictionary = await _trace()
	_release()
	_setup(["k_keg", "k_ghost"], true, true)
	var no_k5: Dictionary = await _trace()
	_release()
	_check("glide happened in trace", with_k5["start"] > 0 and with_k5["glide_ticks"] > 30, "starts tick %d, %d gliding ticks" % [with_k5["start"], with_k5["glide_ticks"]])
	_check("K5+shell glide equals no-shell glide", _same(with_k5["vy"], no_shell["vy"]) and with_k5["start"] == no_shell["start"] and with_k5["glide_ticks"] == no_shell["glide_ticks"],
		"start %d/%d, ticks %d/%d, final vy %.4f/%.4f" % [with_k5["start"], no_shell["start"], with_k5["glide_ticks"], no_shell["glide_ticks"], with_k5["final"], no_shell["final"]])
	_check("K5+shell glide equals no-K5 glide", _same(with_k5["vy"], no_k5["vy"]) and with_k5["start"] == no_k5["start"] and with_k5["glide_ticks"] == no_k5["glide_ticks"],
		"start %d/%d, ticks %d/%d, final vy %.4f/%.4f" % [with_k5["start"], no_k5["start"], with_k5["glide_ticks"], no_k5["glide_ticks"], with_k5["final"], no_k5["final"]])
	print("glide sample v.y (tick: K5+shell / no shell / no K5): ", [10, 30, 60, 89].map(func(i): return "%d: %.4f / %.4f / %.4f" % [i, with_k5["vy"][i], no_shell["vy"][i], no_k5["vy"][i]]))

	print("hotwire_k5_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
