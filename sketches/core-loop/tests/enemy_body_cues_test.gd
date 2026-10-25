extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const T := preload("res://tests/support/t.gd")

# Unit BC: the chaser, lobber and deflector show on their body the moment your verb works
# (design-v3/LEGIBILITY.md section 6). For each kind the cue is on only in its window, off at
# rest and outside it, and wears its STATE_ROWS colour. BC_DISABLE_CUE=chaser|lobber|deflector
# turns that kind's cue off through its own seam, which is how the red run is shown.

# A ball that answers what the shell asks of its target.
class Ball extends RefCounted:
	var at := Vector3.ZERO
	var heading := Vector3.ZERO
	var tier := 1

	func ball_position() -> Vector3:
		return at

	func planar_velocity() -> Vector3:
		return Vector3(heading.x, 0.0, heading.z)

	func speed_tier() -> int:
		return tier


var _game
var _t := T.new("enemy_body_cues_test")
var _off := ""


func _initialize() -> void:
	_off = OS.get_environment("BC_DISABLE_CUE")
	_run.call_deferred()


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.ctx.rng.seed = 11
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.run.set_max_hp(99999.0)
	_game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _same(a: Color, b: Color) -> bool:
	return is_equal_approx(a.r, b.r) and is_equal_approx(a.g, b.g) and is_equal_approx(a.b, b.b)


# The chaser's back: emission on in the wind-up (will_break) and for a moment after a broken
# one (interrupted), never at rest, in the lunge or in recovery.
func _chaser() -> void:
	var enemy = _game.combat.spawn_enemy("chaser", _game.ctx.terrain.drop_point(-100.0, -90.0, 1.6))
	enemy.hp = 100000.0
	enemy.body_cue_enabled = _off != "chaser"
	enemy.set_physics_process(false)
	var mat: StandardMaterial3D = enemy._material
	enemy._cue_step(0.0)
	_t.check("BC-1 chaser at rest is dark", not mat.emission_enabled and enemy.cue_state() == "", "state '%s'" % enemy.cue_state())
	enemy._begin_windup(Vector3.FORWARD)
	enemy._cue_step(0.016)
	var want := EventKinds.state_color("will_break")
	_t.check("BC-1 chaser wind-up wears will_break", mat.emission_enabled and _same(mat.emission, want),
		"emission %s, row colour %s" % [mat.emission, want])
	var low := mat.emission_energy_multiplier
	var swung := false
	for i in 30:
		enemy._cue_step(0.016)
		swung = swung or not is_equal_approx(mat.emission_energy_multiplier, low)
	_t.check("BC-1 chaser cue pulses as the row says", swung == (String(EventKinds.state_row("will_break")["motion"]) == "pulse"),
		"row motion %s, swung %s" % [EventKinds.state_row("will_break")["motion"], swung])
	enemy._end_attack(enemy.State.RECOVER)
	enemy._cue_step(0.016)
	_t.check("BC-1 chaser recovery is dark again", not mat.emission_enabled, "emission_enabled %s" % mat.emission_enabled)
	# A knock at INTERRUPT during the wind-up breaks it: the interrupted row, then a flip.
	enemy.state = enemy.State.CHASE
	enemy._rest = 0.0
	enemy._begin_windup(Vector3.FORWARD)
	enemy._knock = Vector3(enemy.INTERRUPT + 2.0, 0.0, 0.0)
	enemy._physics_process(0.016)
	var row := EventKinds.state_row("interrupted")
	var want_i := EventKinds.state_color("interrupted")
	_t.check("BC-1 chaser break wears interrupted", enemy.state == enemy.State.RECOVER and mat.emission_enabled and _same(mat.emission, want_i),
		"state %s, emission %s, row colour %s, row shape %s" % [enemy.state_name(), mat.emission, want_i, row["shape"]])
	_t.check("BC-1 chaser break flips as a reaction", not enemy._react_row.is_empty() and enemy._react_row == EventKinds.REACTIONS["launch"],
		"reaction row %s" % [enemy._react_row])
	enemy._cue_step(enemy.INTERRUPT_SHOWN + 0.1)
	_t.check("BC-1 chaser interrupted cue ends", not mat.emission_enabled, "emission_enabled %s" % mat.emission_enabled)
	# A wind-up that ends without a hit (the lunge) shows no interrupted cue.
	enemy._clock = 0.0
	enemy.state = enemy.State.LUNGE
	enemy._cue_step(0.016)
	_t.check("BC-1 chaser lunge is dark", not mat.emission_enabled and enemy.cue_state() == "", "state '%s'" % enemy.cue_state())
	enemy.free()


# The shell: rim on while the ball could reach the landing point before the shell lands.
func _lobber() -> void:
	var ball := Ball.new()
	var shell := Projectile.new()
	_game.ctx.root.add_child(shell)
	var from: Vector3 = _game.ctx.terrain.drop_point(0.0, -150.0, 3.0)
	var to: Vector3 = _game.ctx.terrain.drop_point(40.0, -150.0, 0.0)
	shell.setup(ball, _game.ctx.terrain, _game.ctx.root, Callable(_game.ctx.flow, "in_play"), from, to, 1.9)
	shell.set_physics_process(false)
	shell.rim_cue_enabled = _off != "lobber"
	# A second shot shares the shell's sphere, glow and rim quad but keeps its own rim
	# material, because the rim pulses per shot.
	var twin := Projectile.new()
	_game.ctx.root.add_child(twin)
	twin.setup(ball, _game.ctx.terrain, _game.ctx.root, Callable(_game.ctx.flow, "in_play"), from, to, 1.9)
	twin.set_physics_process(false)
	var body_a: MeshInstance3D = shell.get_child(0)
	var body_b: MeshInstance3D = twin.get_child(0)
	_t.check("BC-2 lobber shots share one shell mesh, glow and rim quad",
		body_a.mesh == body_b.mesh and body_a.material_override == body_b.material_override and shell._rim.mesh == twin._rim.mesh,
		"mesh %s, glow %s, rim quad %s" % [body_a.mesh == body_b.mesh, body_a.material_override == body_b.material_override, shell._rim.mesh == twin._rim.mesh])
	_t.check("BC-2 each lobber shot keeps its own rim material", shell._rim.material_override != twin._rim.material_override,
		"rim materials %s / %s" % [shell._rim.material_override, twin._rim.material_override])
	twin.free()
	# Same shell, two balls: 10 m off the landing point at 10 m/s (1.0 s, inside the 1.9 s
	# flight) and 40 m off at 10 m/s (4.0 s, too late).
	ball.heading = Vector3(10.0, 0.0, 0.0)
	ball.at = to + Vector3(-40.0, 0.0, 0.0)
	shell._step_rim(0.016)
	var late: bool = shell.rim_visible() or shell.pings != 0
	var late_ratio := Vector2(ball.at.x - to.x, ball.at.z - to.z).length() / 10.0
	ball.at = to + Vector3(-10.0, 0.0, 0.0)
	ball.tier = 0
	shell._step_rim(0.016)
	_t.check("BC-2 rim stays off below cruise, where a ball cannot bat", not shell.rim_visible() and shell.pings == 0,
		"tier walk, rim %s, pings %d" % [shell.rim_visible(), shell.pings])
	ball.tier = 1
	var early_ratio := Vector2(ball.at.x - to.x, ball.at.z - to.z).length() / 10.0
	shell._step_rim(0.016)
	var want := EventKinds.state_color("will_break")
	_t.check("BC-2 rim lights for the ball that can reach in time", shell.rim_visible() and _same(shell.rim_color(), want),
		"%.2f s to the landing point against %.2f s of flight left; rim %s, row colour %s" % [early_ratio, shell.flight - shell._age, shell.rim_visible(), want])
	_t.check("BC-2 rim stays off for the ball that cannot", not late,
		"%.2f s to the landing point against %.2f s of flight left; rim lit %s, pings %d" % [late_ratio, shell.flight - shell._age, late, 0])
	_t.check("BC-2 one rising ping when the rim first lights", shell.pings == 1, "pings %d, sound %s" % [shell.pings, shell.RIM_PING])
	ball.at = to + Vector3(-40.0, 0.0, 0.0)
	shell._step_rim(0.016)
	_t.check("BC-1 lobber rim off again once the ball falls behind", not shell.rim_visible(), "rim %s" % shell.rim_visible())
	ball.at = to + Vector3(-10.0, 0.0, 0.0)
	shell._step_rim(0.016)
	_t.check("BC-1 lobber ping sounds once per shell", shell.pings == 1, "pings %d" % shell.pings)
	ball.heading = Vector3.ZERO
	shell._step_rim(0.016)
	_t.check("BC-1 lobber rim off for a ball at rest", not shell.rim_visible(), "rim %s" % shell.rim_visible())
	ball.heading = Vector3(10.0, 0.0, 0.0)
	shell._age = shell.flight
	shell._step_rim(0.016)
	_t.check("BC-1 lobber rim off once the shell has landed", not shell.rim_visible(), "rim %s" % shell.rim_visible())
	shell.free()


func _deflector() -> void:
	var base: Vector3 = _game.ctx.terrain.spawn_point(1)
	var at: Vector3 = _game.ctx.terrain.drop_point(base.x + 10.0, base.z, 1.1)
	var enemy = _game.combat.spawn_enemy("deflector", at)
	enemy.hp = 100000.0
	enemy.set_physics_process(false)
	enemy.body_cue_enabled = _off != "deflector"
	enemy._pose()
	_t.check("BC-1 deflector at rest is dark", not enemy.rim_visible() and enemy.vault_anchor() == Vector3.INF, "rim %s" % enemy.rim_visible())
	enemy.phase = enemy.Phase.LIVE
	enemy._pose()
	_t.check("BC-1 deflector live but not yet rebounded is dark", not enemy.rim_visible(), "rim %s" % enemy.rim_visible())
	enemy._rebound_v = Vector3(8.0, 0.0, 0.0)
	enemy._window = enemy.VAULT_WINDOW
	enemy._pose()
	var want := EventKinds.state_color("will_break")
	_t.check("BC-1 deflector vault window wears will_break", enemy.rim_visible() and _same(enemy.vault_rim_color(), want),
		"rim %s, colour %s, row colour %s" % [enemy.rim_visible(), enemy.vault_rim_color(), want])
	# The jump prompt: on the dish in the window, at the ball after it.
	var glyphs = _game.hud.key_glyphs
	var ball: Vector3 = _game.player.ball_position()
	var ready := {"harpoon": false, "haul": false, "boost": false, "interact": false, "jump": false}
	var view := {"ready": ready, "jump_possible": true, "line": "", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": ball, "haul": ball, "boost": ball, "interact": ball, "jump": ball}}
	glyphs.new_run()
	glyphs.step(0.016, view)
	var dish: Vector3 = enemy._wall.global_position
	var near_dish: bool = glyphs.prompt_point("jump").is_equal_approx(dish) and "jump" in glyphs.shown_verbs()
	_t.check("BC-3 jump prompt sits on the dish in the window", near_dish,
		"prompt at %s, dish %s, ball %s, shown %s" % [glyphs.prompt_point("jump"), dish, ball, glyphs.shown_verbs()])
	_t.check("BC-3 a vault-only tick spends none of the jump prompt's allowance", is_zero_approx(glyphs._free["jump"]),
		"free %.3f" % glyphs._free["jump"])
	view["jump_possible"] = false
	glyphs.new_run()
	glyphs.step(0.016, view)
	_t.check("BC-3 no jump prompt in the window when a jump would not fire", "jump" not in glyphs.shown_verbs(),
		"shown %s" % [glyphs.shown_verbs()])
	enemy._window = 0.0
	enemy._pose()
	glyphs.step(0.016, view)
	_t.check("BC-1 deflector rim off after the window", not enemy.rim_visible(), "rim %s" % enemy.rim_visible())
	_t.check("BC-3 jump prompt is back at the ball after the window", glyphs.prompt_point("jump").is_equal_approx(ball) and "jump" not in glyphs.shown_verbs(),
		"prompt at %s, ball %s, shown %s" % [glyphs.prompt_point("jump"), ball, glyphs.shown_verbs()])
	enemy._rebound_v = Vector3.ZERO
	enemy.phase = enemy.Phase.ROAM
	enemy._pose()
	_t.check("BC-1 deflector dark again at rest", not enemy.rim_visible(), "rim %s" % enemy.rim_visible())
	enemy.free()


func _run() -> void:
	await _boot()
	_chaser()
	_lobber()
	_deflector()
	quit(_t.verdict())
