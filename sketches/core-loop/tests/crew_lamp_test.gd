extends SceneTree

# A crew's eye (W1-83, CrewLamp): every job head carries one lamp on its own part, facing the way
# the crew faces and standing on the head's front, not buried in it; it brightens with the warning
# exactly as the telegraph fills, holds through the live phase, fades after, and goes dark at death.
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const CrewLamp := preload("res://src/presentation/crew_lamp.gd")
const T := preload("res://tests/support/t.gd")

# How far in front of the lens the head may still stand (the bola's lantern bars are 0.03 m out).
const BURIED := 0.06

var _game
var _t := T.new("crew_lamp_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _boot()
	var ball: Vector3 = _game.player.ball_position()
	for kind in CrewLamp.ROWS:
		await _seated(kind, ball + Vector3(14.0, 1.6, 0.0))
	await _one_draw(ball)
	await _follows_warning(ball)
	quit(_t.verdict())


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
	for i in 3:
		await physics_frame
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _seated(kind: String, at: Vector3) -> void:
	var enemy = _game.combat.spawn_enemy(kind, at)
	await physics_frame
	var lamp: Node3D = enemy._eye
	_t.check(kind + " has a lamp", lamp != null)
	if lamp == null:
		enemy.free()
		return
	var pivot: Node3D = enemy.reaction_pivot
	var row: Dictionary = CrewLamp.ROWS[kind]
	_t.check(kind + " lamp rides its head part", lamp.get_parent() == pivot.get_node(NodePath(String(row.part))))
	var in_pivot: Transform3D = pivot.global_transform.affine_inverse() * lamp.global_transform
	_t.check(kind + " lamp sits at its row point", in_pivot.origin.distance_to(row.at) < 0.01, str(in_pivot.origin))
	_t.check(kind + " lamp faces the crew's front", in_pivot.basis.z.normalized().dot(Vector3.BACK) > 0.99)
	# The head stands no more than BURIED in front of the lens along its line of sight. Tools may
	# (the deflector's dish is its read from the front); the head may not.
	var front := -INF
	var view := lamp.get_parent() as MeshInstance3D
	var x: Transform3D = pivot.global_transform.affine_inverse() * view.global_transform
	var hit := view.mesh.generate_triangle_mesh().intersect_ray(x.affine_inverse() * (row.at + Vector3(0, 0, 3.0)), x.basis.inverse() * Vector3.FORWARD)
	if not hit.is_empty():
		front = (x * (hit["position"] as Vector3)).z
	var gap: float = front - (row.at as Vector3).z
	_t.check(kind + " lamp is not buried in the head", front > -INF and gap <= BURIED and gap >= -0.2, "front %.2f lamp %.2f" % [front, (row.at as Vector3).z])
	enemy.free()
	await physics_frame


# Every eye in the world is one instance of one MultiMesh: the lamps add one draw in all, and an
# instance leaves with its crew.
func _one_draw(ball: Vector3) -> void:
	var crews := []
	for i in 4:
		crews.append(_game.combat.spawn_enemy(["hooker", "swatter", "netcaster", "mag_trapper"][i], ball + Vector3(12.0 + 4.0 * i, 1.6, 6.0)))
	await process_frame
	var fields: Array = root.find_children(CrewLamp.FIELD, "MultiMeshInstance3D", true, false)
	_t.check("one lamp field in the world", fields.size() == 1, str(fields.size()))
	if fields.size() != 1:
		return
	var field: MultiMeshInstance3D = fields[0]
	_t.check("the field draws one instance per crew", field.multimesh.visible_instance_count == 4 and field.lamps() == 4, str(field.multimesh.visible_instance_count))
	var eye: Node3D = crews[1]._eye
	var drawn: Transform3D = field.global_transform * field.place(eye)
	_t.check("an instance stands at its lamp", drawn.origin.distance_to(eye.global_position) < 0.001)
	_t.check("an instance faces the lamp's way", drawn.basis.y.normalized().dot(eye.global_basis.z.normalized()) > 0.99)
	for crew in crews:
		crew.free()
	await process_frame
	_t.check("the instances leave with their crews", field.multimesh.visible_instance_count == 0)


func _follows_warning(ball: Vector3) -> void:
	var enemy = _game.combat.spawn_enemy("hooker", ball + Vector3(10.0, 1.6, 0.0))
	enemy.hp = 100000.0
	enemy._rest = 0.0
	var lamp: Node3D = enemy._eye
	var rest: float = -1.0
	var rising := true
	var followed := true
	var last := -1.0
	var warned := false
	var lived := false
	for i in 600:
		await physics_frame
		if enemy.phase == enemy.Phase.ROAM and not warned and rest < 0.0 and i > 5:
			rest = lamp.energy()
		if enemy.phase == enemy.Phase.WARN:
			warned = true
			followed = followed and absf(lamp.warmth - clampf(enemy._warn_progress(), 0.0, 1.0)) < 0.001
			rising = rising and lamp.energy() >= last
			last = lamp.energy()
		elif enemy.phase == enemy.Phase.LIVE:
			lived = true
			followed = followed and lamp.warmth == 1.0
		elif lived:
			break
	_t.check("the hooker warned and went live", warned and lived)
	_t.check("the lamp's warmth is the warning's progress, and full while live", followed)
	_t.check("the lamp only brightens through the warning", rising)
	_t.check("the lamp is brighter at the strike than at rest", lamp.energy() > rest and rest > 0.0, "rest %.2f now %.2f" % [rest, lamp.energy()])
	for i in 30:
		await physics_frame
	_t.check("the lamp fades back after the attack", lamp.warmth < 0.2, str(lamp.warmth))
	enemy.hp = 1.0
	enemy.take_damage(10.0)
	_t.check("the lamp goes dark at death", lamp.energy() == 0.0 and lamp.tint() == 0.0)
	await physics_frame
