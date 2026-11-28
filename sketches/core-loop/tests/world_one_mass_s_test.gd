extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Augments := preload("res://src/movement/augments.gd")
const Items := preload("res://src/build/items.gd")

# Mass-S of the world-one build systems (BUILD-SYSTEMS.md): under --world-one-builds=on,
# Sable's slingshot, vault kick and Coil Hook release add up to 8 m/s scaled by
# q = clamp(mass / 990, 0, 1), granted once per second from one shared budget. Incoming
# speed is kept, 45 m/s bounds generated launch speed only, and steering does not read mass.
# Flag off, every launch matches base.
#
# Evidence limit: the rules run on a stand-in body against a real wall in the real physics
# space, the hook release on the real player; steering is compared over a scripted airborne
# run. Nothing here says the larger launch feels good.

const EPS := 0.001
const RUN := Vector3(5000.0, 60.0, 0.0)
const TICKS := 45

var _game
var _wall: StaticBody3D
var _frames := 0
var _failures := 0
var _steer_phase := 0
var _steer_ticks := 0
var _steer_results := {}
var _done_static := false


class Body:
	extends RefCounted
	var transform := Transform3D.IDENTITY
	var linear_velocity := Vector3.ZERO
	var angular_velocity := Vector3.ZERO
	var step := 1.0 / 60.0
	var space: PhysicsDirectSpaceState3D

	func get_space_state() -> PhysicsDirectSpaceState3D:
		return space


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_wall = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 40.0, 40.0)
	shape.shape = box
	_wall.add_child(shape)
	_wall.collision_layer = 1
	_wall.position = RUN + Vector3(2.0, 0.0, 0.0)
	root.add_child(_wall)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_frames += 1
	if _frames == 1:
		_game.ctx.calm = true
		_game.flow.press_start()
		_game.flow.choose_class(0)
	if _frames < 8:
		return false
	if not _done_static:
		_done_static = true
		_game.player.source = Intent.Scripted.new()
		_static_checks()
		_steer_phase = 1
		_start_steer(0.0)
		return false
	_steer_tick()
	return false


func _finish() -> void:
	print("world_one_mass_s_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)


# Set the run up: flag, whether the picks grant the verb, and the mass the ball carries.
func _arm(flag: bool, verb: bool, mass: float) -> void:
	var p = _game.player
	_game.ctx.tuning.set_option("world_one_builds", "on" if flag else "off")
	_game.ctx.tuning.set_option("scrap_mode", "off")
	p.tree._knobs["mass_launch"] = verb
	p.tree._knobs["grapple_fling"] = 10.0
	p.heft_of = func(): return 1.0 + mass / 450.0
	p.mass_of = func() -> float: return mass
	p._read_mass()
	p.kit.mass_gap = 0.0
	p.kit.vault_faces.clear()


func _body(velocity: Vector3) -> Body:
	var b := Body.new()
	b.space = root.world_3d.direct_space_state
	b.transform = Transform3D(Basis.IDENTITY, RUN)
	b.linear_velocity = velocity
	return b


func _vault(incoming: float) -> float:
	var p = _game.player
	p.kit.vault_faces.clear()
	p.kit.set_on(Augments.VAULT, true)
	p.kit.hooked = false
	p.state.grounded = false
	p.state.jump_buffer = 1.0
	var b := _body(Vector3(0, 0, -incoming))
	Augments._vault(p.kit, p.state, _game.ctx.tuning, Basis.IDENTITY, b)
	return b.linear_velocity.length()


func _sling(banked: float) -> float:
	var p = _game.player
	var k = p.kit
	k.set_on(Augments.PYLON, true)
	k.mounted = true
	k.mount_normal = Vector3(-1, 0, 0)
	k.mount_point = RUN
	k.mount_banked = banked
	k.slingshot.begin()
	p.state.jump_buffer = 0.0
	var intent := Intent.new()
	Augments._mount(k, p.state, _game.ctx.tuning, intent, Basis.IDENTITY, _body(Vector3.ZERO), 1.0 / 60.0)
	k.mounted = false
	return k.dismount_velocity.length()


func _fling(speed: float) -> float:
	var p = _game.player
	p.kit.hooked = true
	p.state.velocity = Vector3(0, 0, -speed)
	p._fling()
	p.kit.hooked = false
	return p.state.velocity.length()


# The three launches, each with the shared budget freshly available.
func _launches(incoming: float, banked: float, swing: float) -> Array:
	var k = _game.player.kit
	var out := [_vault(incoming)]
	k.mass_gap = 0.0
	out.append(_sling(banked))
	k.mass_gap = 0.0
	out.append(_fling(swing))
	k.mass_gap = 0.0
	return out


func _near(a: float, b: float) -> bool:
	return absf(a - b) < EPS


func _static_checks() -> void:
	var kit = _game.player.kit
	var tuning = _game.ctx.tuning
	# Base: the same launches, flag off. Vault 20 in -> 36; swing 20 + 10.
	_game.ctx.run.mass = 612.0
	var wired: bool = _game.player.mass_of.is_valid() and is_equal_approx(float(_game.player.mass_of.call()), 612.0)
	_check("combat wires mass_of to the run's scrap mass", wired, "mass_of valid %s" % _game.player.mass_of.is_valid())
	var strikes: Dictionary = _game.player.strike_damage
	_check("combat wires enemy_heft_of and strike_damage into the ball",
		_game.player.enemy_heft_of.is_valid() and strikes.get("slam", []).size() >= 2 and strikes.has("stomp"),
		"enemy_heft_of valid %s, strike keys %s" % [_game.player.enemy_heft_of.is_valid(), strikes.keys()])
	_game.ctx.run.mass = 0.0
	_arm(false, true, 990.0)
	var base := _launches(20.0, 30.0, 20.0)
	_check("the run is Sable's", _game.player.kit.movement_id == "grapple" and _game.player.tree.class_id == "pylon_engineer",
		"movement %s, tree %s" % [_game.player.kit.movement_id, _game.player.tree.class_id])
	_check("flag off is base", not kit.mass_on and kit.mass_q == 0.0 and _near(base[0], 36.0) and _near(base[2], 30.0),
		"flag off, verb picked, mass 990: mass_on %s, vault %.3f, slingshot %.3f, hook %.3f" % [kit.mass_on, base[0], base[1], base[2]])
	_arm(true, false, 990.0)
	var no_verb := _launches(20.0, 30.0, 20.0)
	_check("verb not picked is base", _near(no_verb[0], base[0]) and _near(no_verb[1], base[1]) and _near(no_verb[2], base[2]),
		"flag on, no depth-1 pick, mass 990: %s against base %s" % [no_verb, base])
	# Heft counts held parts too; the verb reads scrap mass alone, so parts and no scrap add nothing.
	_arm(true, true, 0.0)
	_game.player.heft_of = func(): return 2.0
	_game.player._read_mass()
	var parts_only := _launches(20.0, 30.0, 20.0)
	_check("parts are not mass", kit.mass_q == 0.0 and _near(parts_only[0], base[0]) and _near(parts_only[1], base[1]) and _near(parts_only[2], base[2]),
		"heft 2.0 from parts, mass 0: q %.3f, launches %s against base %s" % [kit.mass_q, parts_only, base])
	# Flag on: three masses, same input and approach.
	var results := {}
	for mass in [0.0, 450.0, 990.0]:
		_arm(true, true, mass)
		var r := _launches(20.0, 30.0, 20.0)
		results[mass] = r
		var want := 8.0 * clampf(mass / 990.0, 0.0, 1.0)
		_check("bonus at mass %d" % int(mass), _near(r[0] - base[0], want) and _near(r[1] - base[1], want) and _near(r[2] - base[2], want),
			"vault +%.3f, slingshot +%.3f, Coil Hook +%.3f (want +%.3f each)" % [r[0] - base[0], r[1] - base[1], r[2] - base[2], want])
	_check("bonus rises with mass", results[0.0][0] < results[450.0][0] and results[450.0][0] < results[990.0][0],
		"vault %.3f < %.3f < %.3f" % [results[0.0][0], results[450.0][0], results[990.0][0]])
	_arm(true, true, 3000.0)
	var sat := _vault(20.0)
	_check("q saturates at 990", _near(sat - base[0], 8.0), "mass 3000 vault +%.3f" % (sat - base[0]))
	# Sampling mass never spends it: the run's mass is the same after reading and launching.
	_arm(true, true, 990.0)
	_game.ctx.run.mass = 990.0
	_game.player.mass_of = func() -> float: return _game.ctx.run.mass
	for i in 5:
		_game.player._read_mass()
	_vault(20.0)
	_check("sampling spends nothing", _near(_game.ctx.run.mass, 990.0) and _near(kit.mass_q, clampf((_game.ctx.run.heft() - 1.0) * 450.0 / 990.0, 0.0, 1.0)),
		"run.mass %.1f after five reads and a launch, q %.3f" % [_game.ctx.run.mass, kit.mass_q])
	_game.ctx.run.mass = 0.0
	# One shared budget.
	_arm(true, true, 990.0)
	var v1 := _vault(20.0)
	var v2 := _vault(20.0)
	var s2 := _sling(30.0)
	var f2 := _fling(20.0)
	_check("budget once per second", _near(v1 - base[0], 8.0) and _near(v2, base[0]) and _near(s2, base[1]) and _near(f2, base[2]),
		"vault +%.3f, then vault %.3f, slingshot %.3f, hook %.3f inside the second (base %.3f %.3f %.3f)" % [v1 - base[0], v2, s2, f2, base[0], base[1], base[2]])
	kit.tick_timers(0.5)
	var half := _vault(20.0)
	kit.tick_timers(0.5)
	var full := _vault(20.0)
	_check("budget returns after 1 s", _near(half, base[0]) and _near(full - base[0], 8.0),
		"after 0.5 s vault %.3f (base), after 1.0 s vault +%.3f" % [half, full - base[0]])
	_arm(true, true, 990.0)
	var a := _sling(30.0)
	kit.tick_timers(1.0)
	var c := _fling(20.0)
	kit.tick_timers(1.0)
	var d := _vault(20.0)
	_check("each launch takes it in turn", _near(a - base[1], 8.0) and _near(c - base[2], 8.0) and _near(d - base[0], 8.0),
		"slingshot +%.3f, hook +%.3f, vault +%.3f, a second apart" % [a - base[1], c - base[2], d - base[0]])
	# 45 m/s: incoming above it is kept, nothing is added, the budget stays whole.
	_arm(true, true, 990.0)
	var high_v := _vault(50.0)
	_check("vault above ceiling kept", _near(high_v, 50.0) and kit.mass_gap == 0.0, "incoming 50.0 -> %.3f, budget cooling %.2f s" % [high_v, kit.mass_gap])
	var high_s := _sling(60.0)
	var base_s: float = 60.0 * tuning.f("slingshot_keep") + tuning.f("slingshot_boost")
	_check("slingshot above ceiling adds nothing", _near(high_s, base_s) and kit.mass_gap == 0.0, "banked 60 -> %.3f (base %.3f)" % [high_s, base_s])
	var high_f := _fling(46.0)
	_check("hook above ceiling adds nothing", _near(high_f, 56.0) and kit.mass_gap == 0.0, "swing 46 + fling 10 -> %.3f" % high_f)
	_arm(false, true, 990.0)
	_check("flag off vault keeps base cap", _near(_vault(50.0), 45.0), "flag off incoming 50 -> 45 as base")
	_arm(true, true, 990.0)
	var near_v := _vault(24.0)
	_check("bonus stops at the ceiling", _near(near_v, 45.0), "incoming 24 -> exit 43.2 plus room 1.8 -> %.3f" % near_v)
	# Pylon Capacitor's mods raise the slingshot; the bonus resolves with them once.
	var boost0: float = tuning.f("slingshot_boost")
	var keep0: float = tuning.f("slingshot_keep")
	tuning.set_value("slingshot_boost", boost0 * 1.5)
	tuning.set_value("slingshot_keep", keep0 * 1.1)
	_arm(true, true, 990.0)
	var cap_on := _sling(35.0)
	_arm(false, true, 990.0)
	var cap_off := _sling(35.0)
	_check("Pylon Capacitor stacks once", cap_on <= Augments.LAUNCH_CEILING + EPS and cap_on > cap_off and _near(cap_on, minf(45.0, cap_off + 8.0)),
		"banked 35: capacitor alone %.3f, with mass %.3f (ceiling 45, not %.3f)" % [cap_off, cap_on, cap_off + 8.0])
	tuning.set_value("slingshot_boost", boost0)
	tuning.set_value("slingshot_keep", keep0)
	# Long Lane and Spring Hull are item surges that already decline at the same ceiling.
	var lane: Dictionary = Items.TABLE["long_lane"]["effect"]
	var hull: Dictionary = Items.TABLE["spring_hull"]["effect"]
	_check("Long Lane and Spring Hull share the ceiling", _near(float(lane["max_speed"]), Augments.LAUNCH_CEILING) and _near(float(hull["max_speed"]), Augments.LAUNCH_CEILING),
		"item surge caps %.0f and %.0f, launch ceiling %.0f" % [lane["max_speed"], hull["max_speed"], Augments.LAUNCH_CEILING])


func _start_steer(mass: float) -> void:
	_arm(true, true, mass)
	var p = _game.player
	p._rigid.teleport(Vector3(0.0, 400.0, 0.0), Vector3.ZERO)
	p.source.hold = {"move": Vector2(1.0, 1.0)}
	_steer_ticks = 0


func _steer_tick() -> void:
	_steer_ticks += 1
	if _steer_ticks < TICKS:
		return
	_steer_results[_steer_phase] = _game.player.state.velocity
	if _steer_phase == 1:
		_steer_phase = 2
		_start_steer(990.0)
		return
	var v0: Vector3 = _steer_results[1]
	var v1: Vector3 = _steer_results[2]
	_check("steering identical across mass", v0.length() > 0.5 and v0.distance_to(v1) < 0.01,
		"%d ticks of the same input in the air: velocity %s at mass 0, %s at mass 990" % [TICKS, v0, v1])
	_finish()
