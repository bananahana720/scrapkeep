extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Weapons := preload("res://src/combat/weapons.gd")
const Augments := preload("res://src/movement/augments.gd")

# Mass-K of the world-one build systems (BUILD-SYSTEMS.md): under --world-one-builds=on a
# thrown or slammed charge's blast radius is multiplied by 1 + 0.25q, q = clamp(mass / 990, 0, 1),
# committed once when the charge is made. At mass 0, 450 and 990 the same throw and slam commit
# r, about 1.114r and 1.25r; the aim ring and the blast's hit test read that same number; blast
# damage, blink distance and glide speed do not change; a charge committed small stays small
# when mass later grows; flag off, radii equal base.
#
# Evidence limit: the throw, the slam and the blink run through the real Game; the glide is
# the real Augments._glide on stand-in state. Nothing here says a wider blast is fun to place.

const MASSES := [0.0, 450.0, 990.0]
const LANDING := Vector3(6.0, 0.0, 6.0)

class Kit:
	var gliding := false
	var slamming := false
	func on(_key: String) -> bool:
		return true

class Body:
	var linear_velocity := Vector3.ZERO

class Held:
	var jump_held := true

class Grounded:
	var grounded := false
	var air_actions := 0

var _game
var _combat
var _player
var _source := Intent.Scripted.new()
var _failures := 0
var _booted := false
var _ticks := 0
var _step := 0
var _rec := {}
var _struck: Array = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	if not _booted:
		_booted = true
		_game.ctx.calm = true
		_game.player.source = _source
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_combat = _game.combat
		_player = _game.player
		_game.events.enemy_struck.connect(func(enemy: Node3D, kind: String, _force: float): _struck.append([enemy, kind]))
		return false
	# Steps 0..2: the blink at each mass, one tick to arm, three to move. Then the rest at once.
	if _step < MASSES.size():
		if _ticks == 0:
			_blink_begin(MASSES[_step])
		_ticks += 1
		if _ticks >= 4:
			_blink_end(MASSES[_step])
			_step += 1
			_ticks = 0
		return false
	_radii(true)
	_hit_tests()
	_late_mass()
	_glide()
	_radii(false)
	_blink_check()
	print("world_one_mass_k_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
	return true


func _kest() -> void:
	var def: Resource = ClassDef.by_id("demolitions_caster")
	_game.run.class_def = def
	_player.fit_class(def)
	_clear_enemies()
	_combat.sticky.clear()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1)
	_player.reset_to(at)
	_player.body().global_position = at
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0


func _clear_enemies() -> void:
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()


func _flag(on: bool) -> void:
	_game.ctx.tuning.set_option("world_one_builds", "on" if on else "off")


func _throw(mass: float) -> Dictionary:
	_game.run.mass = mass
	_combat.sticky.clear()
	_combat.cloak_left = 0.0
	_combat._throw_sticky(LANDING)
	return _combat.sticky.live()[0]


func _slam(mass: float) -> Array:
	_game.run.mass = mass
	_combat.sticky.clear()
	_game.events.demo_slammed.emit(_player.ball_position() + Vector3.DOWN * 0.9)
	return _combat.sticky.live(true).duplicate()


func _ring(mass: float) -> float:
	_game.run.mass = mass
	_combat._draw_throw({"point": LANDING, "blocked": false})
	return float(_player.indicator.last_shape["landing"]["radius"])


func _radii(on: bool) -> void:
	_kest()
	_flag(on)
	var base_throw := 0.0
	var base_slam := 0.0
	var label := "on" if on else "off"
	var throws: Array = []
	var slams: Array = []
	for m in MASSES:
		var t: Dictionary = _throw(m)
		var s: Array = _slam(m)
		throws.append(float(t["radius"]))
		slams.append(float(s[0]["radius"]))
		if m == 0.0:
			base_throw = float(t["radius"])
			base_slam = float(s[0]["radius"])
		var want := 1.0 + 0.25 * clampf(m / 990.0, 0.0, 1.0) if on else 1.0
		_check("throw radius %s m%d" % [label, int(m)], is_equal_approx(float(t["radius"]), base_throw * want),
			"committed %.4f, want %.4f x %.4f" % [float(t["radius"]), base_throw, want])
		_check("slam radius %s m%d" % [label, int(m)], is_equal_approx(float(s[0]["radius"]), base_slam * want),
			"every slam charge committed %.4f, want %.4f x %.4f" % [float(s[0]["radius"]), base_slam, want])
		_check("ring is the committed radius %s m%d" % [label, int(m)], is_equal_approx(_ring(m), float(t["radius"])),
			"aim ring %.4f, committed throw %.4f" % [_ring(m), float(t["radius"])])
		_check("last_shot radius %s m%d" % [label, int(m)], is_equal_approx(float(_combat.last_shot["radius"]), float(t["radius"])),
			"last_shot %.4f" % float(_combat.last_shot["radius"]))
	if on:
		_check("about 1.114r and 1.25r", is_equal_approx(throws[1] / throws[0], 1.0 + 0.25 * 450.0 / 990.0) and is_equal_approx(throws[2] / throws[0], 1.25)
			and is_equal_approx(slams[1] / slams[0], 1.0 + 0.25 * 450.0 / 990.0) and is_equal_approx(slams[2] / slams[0], 1.25),
			"throw x%.4f x%.4f, slam x%.4f x%.4f" % [throws[1] / throws[0], throws[2] / throws[0], slams[1] / slams[0], slams[2] / slams[0]])
	else:
		_check("flag off equals base", throws[0] == throws[1] and throws[1] == throws[2] and slams[0] == slams[1] and slams[1] == slams[2]
			and is_equal_approx(throws[0], _combat._lob_pattern().bolt_radius) and is_equal_approx(slams[0], Weapons.MINI_RADIUS),
			"throw %s slam %s, base %.2f and %.2f" % [throws, slams, _combat._lob_pattern().bolt_radius, Weapons.MINI_RADIUS])


# The blast's hit test reads the committed radius: one chaser just inside and one just outside
# its reach (radius x forgiveness plus the hull), at each mass, and the damage equals across them.
func _hit_tests() -> void:
	_kest()
	_flag(true)
	var damages: Array = []
	for m in MASSES:
		var charge: Dictionary = _throw(m)
		damages.append(float(charge["damage"]))
		var slam_charges: Array = _slam(m)
		damages.append(float(slam_charges[0]["damage"]))
		_check("throw hit test m%d" % int(m), _reaches(charge), "hit inside %.3f x forgiveness, none outside" % float(charge["radius"]))
		_check("slam hit test m%d" % int(m), _reaches(slam_charges[0]), "hit inside %.3f x forgiveness, none outside" % float(slam_charges[0]["radius"]))
	_check("blast damage equal", damages[0] == damages[2] and damages[2] == damages[4] and damages[1] == damages[3] and damages[3] == damages[5],
		"throw %.2f/%.2f/%.2f, slam %.2f/%.2f/%.2f" % [damages[0], damages[2], damages[4], damages[1], damages[3], damages[5]])


func _reaches(charge: Dictionary) -> bool:
	_clear_enemies()
	var probe: Node3D = _combat.spawn_enemy("chaser", Vector3(300.0, 20.0, 300.0))
	var hull: float = _combat.hull_radius(probe)
	var reach: float = float(charge["radius"]) * (1.0 + AbilityState.FORGIVENESS) + hull
	var centre: Vector3 = probe.global_position
	var hits := []
	for offset in [reach - 0.05, reach + 0.05]:
		_struck.clear()
		var shot: Dictionary = charge.duplicate()
		shot["pos"] = centre - Vector3(offset, 0.0, 0.0)
		_combat._detonate(shot)
		hits.append(_struck.any(func(s): return s[0] == probe and s[1] == "sticky"))
	_clear_enemies()
	return hits[0] and not hits[1]


func _late_mass() -> void:
	_kest()
	_flag(true)
	var small: Dictionary = _throw(0.0)
	var mini: Array = _slam(0.0)
	var before := [float(small["radius"]), float(mini[0]["radius"])]
	_game.run.mass = 990.0
	_combat._physics_process(0.016)
	_check("charge stays small", is_equal_approx(float(small["radius"]), before[0]) and is_equal_approx(float(mini[0]["radius"]), before[1]),
		"committed at mass 0 (%.3f, %.3f), still %.3f and %.3f at mass 990" % [before[0], before[1], float(small["radius"]), float(mini[0]["radius"])])


func _glide() -> void:
	_flag(true)
	var speeds: Array = []
	for m in MASSES:
		_game.run.mass = m
		var kit := Kit.new()
		var body := Body.new()
		body.linear_velocity = Vector3(0.0, -12.0, -9.0)
		Augments._glide(kit, Grounded.new(), _player.tuning, Held.new(), Basis.IDENTITY, body, 0.016)
		speeds.append(body.linear_velocity)
	_check("glide speed equal", speeds[0].is_equal_approx(speeds[1]) and speeds[1].is_equal_approx(speeds[2]) and speeds[0].length() > 0.0,
		"glide velocity %s / %s / %s at mass 0 / 450 / 990" % [speeds[0], speeds[1], speeds[2]])


func _blink_begin(m: float) -> void:
	_kest()
	_flag(true)
	_game.run.mass = m
	_player.drive_basis = Basis.IDENTITY
	_rec["from%d" % int(m)] = _player.ball_position()
	_source.press = {"movement_pressed": true}


func _blink_end(m: float) -> void:
	_source.press = {}
	_rec["moved%d" % int(m)] = (_player.ball_position() - _rec["from%d" % int(m)]).length()


func _blink_check() -> void:
	var a: float = _rec["moved0"]
	var b: float = _rec["moved450"]
	var c: float = _rec["moved990"]
	_check("blink distance equal", a > 1.0 and absf(a - b) < 0.05 and absf(b - c) < 0.05,
		"blink moved %.3f / %.3f / %.3f m at mass 0 / 450 / 990" % [a, b, c])
