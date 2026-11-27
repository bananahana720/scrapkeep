extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

var game
var t := T.new("enemy_line_cutter_test")
var ball := Vector3.ZERO
var facts := []


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
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
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)
	game.player.set_frozen(true)


func _spawn():
	var at := Vector3(ball.x + 9.0, 0.0, ball.z + 3.0)
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	var unit = game.combat.spawn_enemy("line_cutter", at)
	unit.hp = 100000.0
	unit._rest = 0.1
	facts.clear()
	unit.attack_phase.connect(func(fact: Dictionary): facts.append(fact))
	return unit


# Drive one throw by hand: commit, hold the ball in the ring, set the line state, and step until
# the unit is back to roaming. The line flags are set again each frame so the frozen player's tick
# cannot clear them before the landing.
func _throw(unit, hooked: bool, gliding: bool, interrupt := false, height := 0.0) -> void:
	unit._rest = 99.0
	unit.next_attack = "line"
	unit.phase = unit.Phase.ROAM
	unit._warn(unit._flat_to_ball())
	if interrupt:
		await physics_frame
		unit.knock(Vector3.RIGHT, 20.0)
	for frame in 300:
		game.player.reset_to(ball + Vector3.UP * height)
		game.player.set_velocity_now(Vector3.ZERO)
		game.player.kit.hooked = hooked
		game.player.kit.gliding = gliding
		await physics_frame
		if unit.phase == unit.Phase.ROAM:
			break


func _run() -> void:
	await _boot()
	var unit = _spawn()
	unit.set_physics_process(false)
	unit.set_physics_process(true)
	var kit = game.player.kit
	game.player.set_frozen(true)
	kit.hooked = true
	var stuck := false
	await physics_frame
	stuck = kit.hooked
	t.check("line fake without a drive", stuck, "kit.hooked stays true across a frozen tick: %s" % stuck)
	unit._rest = 99.0
	unit._warn(unit._flat_to_ball())
	var open: Dictionary = facts[0] if not facts.is_empty() else {}
	var tele = unit.telegraph()
	t.check("E22 windup PROJECTILE", open.get("row", "") == "E22" and open.get("phase", "") == "windup" and tele != null and tele.type == Threat.Type.PROJECTILE,
		"first fact %s" % [open.get("row", ""), ])
	unit._clear_telegraph()
	unit._facts_end(true)
	unit.phase = unit.Phase.ROAM
	facts.clear()
	kit.line_end = ""

	# A cut costs you only over a gap (design-v3/WORLD-ROSTERS.md): at ground height it grazes.
	await _throw(unit, true, false)
	t.check("over ground it only grazes", unit.throws == 1 and unit.cuts == 0 and unit.grazed == 1 and kit.hooked,
		"throws %d cuts %d grazed %d hooked %s" % [unit.throws, unit.cuts, unit.grazed, kit.hooked])

	unit.throws = 0
	await _throw(unit, true, false, false, unit.GAP_HEIGHT + 2.0)
	t.check("landing cuts once", unit.throws == 1 and unit.cuts == 1 and not kit.hooked and kit.line_end == "line_cutter",
		"throws %d cuts %d hooked %s line_end '%s'" % [unit.throws, unit.cuts, kit.hooked, kit.line_end])

	await _throw(unit, true, true)
	t.check("glide dodges", unit.throws == 2 and unit.cuts == 1 and unit.dodged == 1 and kit.hooked,
		"throws %d cuts %d dodged %d hooked %s" % [unit.throws, unit.cuts, unit.dodged, kit.hooked])

	var before: int = unit.throws
	facts.clear()
	await _throw(unit, true, false, true)
	var last: Dictionary = facts[facts.size() - 1] if not facts.is_empty() else {}
	t.check("knock breaks the wind-up", unit.phase == unit.Phase.ROAM and unit.throws == before and last.get("phase", "") == "cancelled",
		"phase %d throws %d last fact '%s'" % [unit.phase, unit.throws, last.get("phase", "")])
	game.free()
	quit(t.verdict())
