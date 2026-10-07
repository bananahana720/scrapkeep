extends SceneTree

const View := preload("res://src/presentation/cosmetic_presentation.gd")
const Events := preload("res://src/core/game_events.gd")
const T := preload("res://tests/support/t.gd")
var _t := T.new("cosmetic_trail_allocation_test")

class CountingView extends View:
	var previous: Array[Vector3]
	var buffers := 0
	func _threat_points() -> Array[Vector3]:
		var points := super._threat_points()
		if not is_same(previous, points):
			buffers += 1
		previous = points
		return points

class Player extends Node3D:
	var state := {"grounded": true}
	func planar_velocity() -> Vector3:
		return Vector3(0, 0, -2)
	func shown_position() -> Vector3:
		return Vector3(0, 1, 0)

class Flow extends RefCounted:
	func in_play() -> bool:
		return true

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var player := Player.new()
	root.add_child(player)
	var view := CountingView.new()
	root.add_child(view)
	view.set_process(false)
	var events := Events.new()
	root.add_child(events)
	view.setup({"player": player, "flow": Flow.new(), "events": events}, null)
	var enemies := []
	for i in 24:
		var enemy := Node3D.new()
		enemy.add_to_group("enemy")
		root.add_child(enemy)
		enemy.position = Vector3(100 + i, 0, 0)
		enemies.append(enemy)
	await process_frame
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	mesh.mesh = QuadMesh.new()
	node.add_child(mesh)
	var packed := PackedScene.new()
	mesh.owner = node
	packed.pack(node)
	node.free()
	var row := {"asset": "test_trail", "resource": packed}
	for i in 90:
		view._step_trail(1.0 / 90.0, row)
	_t.eq("90 rendered frames use one threat buffer", view.buffers, 1)
	_t.check("live trail retains its card pool", view._cards.size() > 0 and view.trail.get_child_count() <= View.TRAIL_LIMIT)
	enemies[0].position = Vector3(0, 0, 0)
	view._step_trail(0.001, row)
	_t.check("moving enemy hides nearby trail cards", view._cards[0]["meshes"][0].transparency == 1.0)
	enemies[0].remove_from_group("enemy")
	view._step_trail(0.001, row)
	_t.check("leaving enemy group restores trail visibility", view._cards[0]["meshes"][0].transparency < 1.0)
	for enemy in enemies:
		enemy.free()
	view._step_trail(0.001, row)
	_t.eq("freed enemies leave no threat positions", view._threat_points().size(), 0)
	var spawned := Node3D.new()
	root.add_child(spawned)
	spawned.add_to_group("enemy")
	events.enemy_spawned.emit(spawned, "chaser")
	_t.eq("spawn event registers threats immediately", view._threat_points().size(), 1)
	var boss_target := Node3D.new()
	root.add_child(boss_target)
	boss_target.add_to_group("enemy")
	await process_frame
	_t.eq("boss target setup registers without a spawn event", view._threat_points().size(), 2)
	spawned.free()
	boss_target.free()
	events.free()
	view.free()
	player.free()
	quit(_t.verdict())
