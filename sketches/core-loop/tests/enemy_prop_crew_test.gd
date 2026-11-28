extends SceneTree

# The prop crew (roster_dig.gd, design-v3/WORLD-ROSTERS.md) in the real game:
# - the roster builds it and it never attacks on its own;
# - it walks to the middle of its pack, not to the ball;
# - a bolt leaves the prop standing; a ram knocks it out and the roof comes down one
#   committed INSTANT disc later, crushing its pack and the crew if it is still under;
#   the first crush reveals its codex entry;
# - the roof hits a ball on the floor under it, through combat's player-hit path;
# - a ram that kills the crew outright still brings the roof down on its pack.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const WarningGap := preload("res://src/world/events/warning_gap.gd")
const T := preload("res://tests/support/t.gd")

var game
var t := T.new("enemy_prop_crew_test")
var ball := Vector3.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _seconds(seconds: float) -> void:
	await _frames(int(seconds * Engine.physics_ticks_per_second))


func _boot() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.ctx.calm = true
	game.ctx.rng.seed = 23
	game.player.source = Intent.Scripted.new()
	game.flow.press_start()
	game.flow.choose_class(0)
	game.run.set_max_hp(99999.0)
	game.presentation.juice.hit_stop_sink = func(_seconds: float): pass
	await _frames(3)
	_clear()
	var spawn: Vector3 = game.ctx.terrain.spawn_point(1)
	ball = game.ctx.terrain.drop_point(spawn.x, spawn.z, 1.05)
	game.player.reset_to(ball)


func _clear() -> void:
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _at(offset: Vector3) -> Vector3:
	var at := ball + offset
	at.y = game.ctx.terrain.height(at.x, at.z) + 1.5
	return at


func _spawn(kind: String, offset: Vector3):
	var enemy = game.combat.spawn_enemy(kind, _at(offset))
	if "_rest" in enemy:
		enemy._rest = 1000.0
	return enemy


func _ram(enemy, force := 30.0) -> void:
	game.combat.deal_hit(enemy, "ram", force, Vector3.RIGHT, 0.0, "", "", "ram")


func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _run() -> void:
	await _boot()
	t.check("the roster builds the prop crew", game.combat.fleet.makes("prop_crew"))

	# It walks to its pack, never at the ball.
	var crew = _spawn("prop_crew", Vector3(30.0, 0.0, 0.0))
	var mates := [_spawn("drill_crew", Vector3(42.0, 0.0, 8.0)), _spawn("drill_crew", Vector3(44.0, 0.0, -6.0))]
	await _frames(2)
	for mate in mates:
		mate.set_physics_process(false)
	var centre: Vector3 = crew.pack_centre()
	var start: float = _flat(crew.global_position).distance_to(_flat(centre))
	await _seconds(3.0)
	var later: float = _flat(crew.global_position).distance_to(_flat(crew.pack_centre()))
	t.check("the crew walks to the middle of its pack", later < start - 3.0, "%.1f m to %.1f m" % [start, later])
	t.eq("the crew never warns on its own", crew.warned, 0)
	t.check("the prop stands", crew.prop_up)

	# A bolt leaves the prop; a ram knocks it out and the roof falls.
	crew.on_struck("bolt", "", {})
	t.check("a bolt leaves the prop standing", crew.prop_up)
	for i in mates.size():
		mates[i].global_position = _at(crew.roof_centre() - ball + Vector3(2.0 * (i * 2 - 1), 0.0, 1.0))
	var roof: Vector3 = crew.roof_centre()
	root.remove_meta(WarningGap.LAST_META)
	_ram(crew)
	t.check("a ram knocks the prop out", not crew.prop_up)
	var fall = crew.last_fall
	t.check("the roof is falling", is_instance_valid(fall))
	await _frames(2)
	if is_instance_valid(fall):
		t.check("the roof commits one INSTANT disc", fall.committed() and fall.hazard.type == Threat.Type.INSTANT)
		t.near("the disc is the roof's size", fall.hazard.r_out, crew.ROOF_RADIUS)
		t.check("the disc sits under the roof", _flat(fall.hazard.centre).distance_to(_flat(roof)) < 0.5)
	t.check("the pack is whole during the warning", mates.all(func(m): return is_instance_valid(m) and not m.is_dead()))
	await _seconds(1.4)
	var crushed := mates.filter(func(m): return not is_instance_valid(m) or m.is_dead())
	t.eq("the roof crushes the pack under it", crushed.size(), mates.size())
	var clear: bool = is_instance_valid(crew) and _flat(crew.global_position).distance_to(_flat(roof)) > crew.ROOF_RADIUS
	t.check("the roof takes the crew too, unless the ram threw it clear", not is_instance_valid(crew) or crew.is_dead() or clear)
	t.check("crushing the pack reveals Bring Down the Roof", game.ctx.codex.known("roof_drop"))
	_clear()
	await _frames(2)

	# The ball on the floor under the roof is hit; through combat, so it scales like any enemy hit.
	game.player.reset_to(ball)
	await _seconds(1.0)
	crew = _spawn("prop_crew", Vector3(8.0, 0.0, 0.0))
	await _frames(2)
	crew.set_physics_process(false)
	var here: Vector3 = game.player.ball_position()
	crew.global_position += Vector3(here.x, 0.0, here.z) - Vector3(crew.roof_centre().x, 0.0, crew.roof_centre().z)
	var hp: float = game.run.hp
	t.check("the ball sits on the floor", game.player.state.grounded)
	root.remove_meta(WarningGap.LAST_META)
	var fall_on_ball = crew.knock_prop()
	var hit := []
	fall_on_ball.landed.connect(func(_crushed: Array, hit_ball: bool): hit.append(hit_ball))
	await _seconds(1.4)
	t.check("the roof hits a ball on the floor under it", hit == [true] and game.run.hp < hp, "hit %s, hp %.1f to %.1f" % [hit, hp, game.run.hp])
	_clear()
	await _frames(2)

	# A ram that kills the crew outright still brings the roof down.
	crew = _spawn("prop_crew", Vector3(30.0, 0.0, 0.0))
	var mate = _spawn("burrower", Vector3(31.5, 0.0, 1.0))
	await _frames(2)
	mate.set_physics_process(false)
	mate.global_position = _at(crew.roof_centre() - ball + Vector3(1.0, 0.0, 1.0))
	crew._set_health(1.0)
	root.remove_meta(WarningGap.LAST_META)
	_ram(crew)
	t.check("the ram kills the crew", not is_instance_valid(crew) or crew.is_dead())
	await _seconds(1.4)
	t.check("the roof still lands on its pack", not is_instance_valid(mate) or mate.is_dead())
	_clear()
	quit(t.verdict())
