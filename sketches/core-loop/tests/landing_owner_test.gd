extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Palette := preload("res://src/core/palette.gd")
const T := preload("res://tests/support/t.gd")

# FX-05 follow-ups: the attacks whose hit comes at a moment their warning never reaches still
# leave the landing (Telegraph.land()), and the mag trapper's discs take the release flash.
# - land() draws a landing at any progress, once per call, and nothing for a mark that is not
#   hostile; set_progress still lands once.
# - In a live game a bola thrower's and a line cutter's throw each leave a landing as the
#   bola or disc arrives, and a jolt layer's held field leaves one per pulse.
# - The mag trapper's discs go HAZARD with its body on the strike and settle to white after.
# Evidence limit: node counts and material state in a headless run, not a rendered still.

class FlatGround:
	func height(_x: float, _z: float) -> float:
		return 0.0


var game
var t := T.new("landing_owner_test")
var ball := Vector3.ZERO
var _flashes := 0


func _initialize() -> void:
	_run.call_deferred()


func _ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 11
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _ticks(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)
	game.player.set_frozen(true)
	game.ctx.root.child_entered_tree.connect(func(node: Node):
		if node is Threat.Flash:
			_flashes += 1)


func _run() -> void:
	_check_land()
	await _boot()
	for kind in ["bola_thrower", "line_cutter"]:
		var landed := await _attack(kind, 600, func(unit): return unit.phase == unit.Phase.ROAM and _flashes > 0)
		t.check("%s lands" % kind, landed >= 1, "%d landings from one throw" % landed)
	var pulses := await _attack("jolt_layer", 900, func(unit): return unit.field != null and unit.field.pulses >= 2)
	t.check("jolt layer lands per pulse", pulses >= 2, "%d landings from two pulses" % pulses)
	await _mag_discs()
	game.free()
	quit(t.verdict())


func _check_land() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ring: Node3D = Telegraph.ring(world, FlatGround.new(), Threat.Type.INSTANT, Vector3.ZERO, 4.0)
	ring.set_progress(0.4)
	var before := world.get_child_count()
	ring.land()
	ring.land()
	t.check("land at any progress", world.get_child_count() == before + 2, "two calls at 40 percent, %d landings" % (world.get_child_count() - before))
	var field: Node3D = Telegraph.ring(world, FlatGround.new(), Threat.Type.INSTANT, Vector3(30.0, 0.0, 0.0), 4.0, 3.5, Palette.SAND)
	before = world.get_child_count()
	field.land()
	t.check("harmless never lands", world.get_child_count() == before, "a bone field")
	world.free()


# One unit of `kind` beside the ball, its attack started by hand and run until done(unit) or
# `limit` ticks; returns how many landings appeared meanwhile.
func _attack(kind: String, limit: int, done: Callable) -> int:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	await _ticks(2)
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	var unit = game.combat.spawn_enemy(kind, at)
	unit.hp = 100000.0
	unit._rest = 99.0
	unit.phase = unit.Phase.ROAM
	_flashes = 0
	unit._warn(unit._flat_to_ball())
	for i in limit:
		game.player.reset_to(ball)
		game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame
		if not is_instance_valid(unit) or done.call(unit):
			break
	var seen := _flashes
	if is_instance_valid(unit):
		unit.free()
	return seen


func _mag_discs() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	var unit = game.combat.spawn_enemy("mag_trapper", at)
	unit.set_physics_process(false)
	await _ticks(1)
	unit._atk = {"instance": 99, "row": "E05", "phase": unit.PHASE_WINDUP, "managed": false, "tele": null, "geometry": {}, "progress": 1.0}
	unit._facts_phase(unit.PHASE_STRIKE)
	unit._update_flash(1.0 / 90.0)
	var disc: StandardMaterial3D = unit._disc_material
	var lit := disc != null and disc.emission == Palette.HAZARD and disc.albedo_color.is_equal_approx(Color.WHITE.lerp(Palette.HAZARD, unit.STRIKE_TINT))
	for i in unit.STRIKE_FRAMES + 2:
		unit._update_flash(1.0 / 90.0)
	var rest := disc != null and disc.albedo_color.is_equal_approx(Color.WHITE) and not disc.emission_enabled
	t.check("mag trapper discs flash", lit and rest, "HAZARD on the strike %s, plain white after %s" % [lit, rest])
	unit.free()
