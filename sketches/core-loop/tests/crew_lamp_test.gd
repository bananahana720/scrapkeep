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
	await _follows_warning()
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
	# A crew leaving from the middle hands its slot to the last; the others stay on their lamps.
	crews[1].free()
	crews.remove_at(1)
	await process_frame
	var placed := true
	for crew in crews:
		placed = placed and (field.global_transform * field.place(crew._eye)).origin.distance_to(crew._eye.global_position) < 0.001 and field._lamps.has(crew._eye)
	_t.check("a crew leaving from the middle keeps the others on their lamps", placed and field.lamps() == 3)
	# A full field grows instead of leaving a crew without its eye.
	var room: int = field.multimesh.instance_count
	var crowd := []
	for i in room:
		crowd.append(_game.combat.spawn_enemy("hooker", ball + Vector3(12.0 + float(i % 8) * 3.0, 1.6, -8.0 - float(i / 8) * 3.0)))
	await process_frame
	_t.check("a full field grows to take every lamp", field.lamps() == room + 3 and field.multimesh.instance_count >= room + 3, "%d lamps, room %d" % [field.lamps(), field.multimesh.instance_count])
	_t.check("the field runs while the tree is paused (stills)", field.process_mode == Node.PROCESS_MODE_ALWAYS)
	for crew in crews + crowd:
		crew.free()
	await process_frame
	_t.check("the instances leave with their crews", field.multimesh.visible_instance_count == 0)


func _follows_warning() -> void:
	# The bola thrower's telegraph stays open all wind-up (its _warn_progress is 0); its lamp still
	# follows the wind-up's own clock.
	for kind in ["hooker", "bola_thrower"]:
		await _warns(kind, _game.player.ball_position())


func _warns(kind: String, ball: Vector3) -> void:
	var enemy = _game.combat.spawn_enemy(kind, ball + Vector3(10.0, 1.6, 0.0))
	enemy.hp = 100000.0
	enemy._rest = 0.0
	var lamp: Node3D = enemy._eye
	var rest: float = -1.0
	var rest_danger: float = -1.0
	var rising := true
	var followed := true
	var last := -1.0
	var warned := false
	var lived := false
	for i in 900:
		await physics_frame
		if enemy.phase == enemy.Phase.ROAM and not warned and rest < 0.0 and i > 5:
			rest = lamp.energy()
			rest_danger = lamp.danger()
		if enemy.phase == enemy.Phase.WARN:
			warned = true
			followed = followed and absf(lamp.warmth - clampf(enemy._t / enemy.warn_seconds, 0.0, 1.0)) < 0.001
			rising = rising and lamp.energy() >= last
			last = lamp.energy()
		elif enemy.phase == enemy.Phase.LIVE:
			lived = true
			followed = followed and lamp.warmth == 1.0 and lamp.danger() == 1.0 and is_equal_approx(lamp.swell(), CrewLamp.SWELL)
		elif lived:
			break
	_t.check(kind + " warned and went live", warned and lived)
	_t.check(kind + " lamp's warmth is the wind-up's run, and full, swollen and in the danger colour while live", followed)
	_t.check(kind + " lamp only brightens through the wind-up", rising and last > rest)
	_t.check(kind + " lamp rests in its own colour, not the danger colour", rest_danger == 0.0 and rest > 0.0, "rest %.2f" % rest)
	for i in 30:
		await physics_frame
	_t.check(kind + " lamp fades back after the attack", lamp.warmth < 0.2, str(lamp.warmth))
	enemy.hp = 1.0
	enemy.take_damage(10.0)
	_t.check(kind + " lamp goes dark at death", lamp.energy() == 0.0 and lamp.tint() == 0.0)
	await physics_frame
