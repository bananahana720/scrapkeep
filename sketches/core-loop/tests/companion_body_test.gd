extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Body := preload("res://src/presentation/companion_body.gd")
const T := preload("res://tests/support/t.gd")

# SPIL-9's body: the game builds the real assembled GLB for the seated pair (not the plain
# hull), keeps a fallback when the model is missing, follows the ball, and plays each
# module's beat from combat state without changing any of that state.

class FakeCombat extends RefCounted:
	var primed_ids := {}
	var staggered_ids := {}
	var armed := false

	func primed(enemy) -> bool:
		return primed_ids.has(enemy.get_instance_id())

	func primer_expired(_enemy_id: int) -> bool:
		return false

	func prow_staggered(enemy) -> bool:
		return staggered_ids.has(enemy.get_instance_id())

	func spring_armed() -> bool:
		return armed

var _t := T.new("companion_body_test")
var _game


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _doc(seated: Array) -> Dictionary:
	var m := Companion.new()
	for id in seated:
		m.acquire(id)
	m.assemble(seated)
	return m.to_dict()


func _meshes(node: Node) -> Array:
	var out: Array = []
	if node is MeshInstance3D and node.mesh != null:
		out.append(node)
	for c in node.get_children():
		out.append_array(_meshes(c))
	return out


# True when the body shows a mesh that is the mesh of the GLB at `path`.
func _shows_glb(body: Node, path: String) -> bool:
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	var source := packed.instantiate()
	var want := _meshes(source)
	var found := false
	for shown in _meshes(body):
		if shown.mesh is BoxMesh or shown.mesh is CapsuleMesh:
			source.free()
			return false
		for m in want:
			if shown.mesh == m.mesh:
				found = true
	source.free()
	return found


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(20)
	var body = _game.presentation.get_node_or_null("CompanionBody")
	_t.check("body node exists", body != null, "presentation owns CompanionBody")
	if body == null:
		quit(_t.verdict())
		return

	_game.run.companion = {}
	await _frames(3)
	_t.check("no seats, no body", not body.visible and body.get_child_count() == 0, "empty companion draws nothing")

	# Every legal pair resolves to a model file, in both socket orders.
	var missing := 0
	var ids := ["primer_coil", "primer_mesh", "ram_prow", "ram_spring", "escape_vent", "escape_rail"]
	for a in ids:
		for b in ids:
			if Companion.family_of(a) != Companion.family_of(b):
				if not ResourceLoader.exists(Body.model_path([a, b])):
					missing += 1
	_t.eq("all 24 ordered pairs have a model", missing, 0)

	_game.run.companion = _doc(["primer_coil", "ram_prow"])
	await _frames(4)
	var path: String = Body.model_path(["primer_coil", "ram_prow"])
	_t.check("real model built", body.is_real() and body.visible, "is_real %s" % str(body.is_real()))
	_t.check("shows the GLB mesh", _shows_glb(body, path), path)
	var anim: Array = body.find_children("*", "AnimationPlayer", true, false)
	_t.check("clips present", not anim.is_empty() and anim[0].has_animation("idle") and anim[0].has_animation("primer_set"), "idle and primer_set")

	# Follows the ball.
	var ball: Vector3 = _game.player.shown_position()
	_t.check("hovers beside the ball", body.global_position.distance_to(ball) < 4.0, "distance %.2f" % body.global_position.distance_to(ball))
	_game.player.body().global_position = ball + Vector3(30.0, 0.0, 0.0)
	await _frames(90)
	var moved: Vector3 = _game.player.shown_position()
	_t.check("keeps up with the ball", body.global_position.distance_to(moved) < 4.0, "distance %.2f" % body.global_position.distance_to(moved))

	# Beats follow combat state.
	var enemy := Node3D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	var fake := FakeCombat.new()
	body.combat = fake
	await _frames(2)
	fake.primed_ids[enemy.get_instance_id()] = true
	await _frames(2)
	_t.eq("primer prime plays primer_set", String(anim[0].current_animation), "primer_set")
	await _frames(40)
	fake.primed_ids.clear()
	await _frames(2)
	_t.eq("prime spent plays primer_consume", String(anim[0].current_animation), "primer_consume")
	await _frames(40)
	fake.staggered_ids[enemy.get_instance_id()] = true
	await _frames(2)
	_t.eq("landed ram plays prow_response", String(anim[0].current_animation), "prow_response")
	await _frames(60)
	_t.check("settles back to idle or follow", ["idle", "follow"].has(String(anim[0].current_animation)), String(anim[0].current_animation))

	_game.run.companion = _doc(["ram_spring", "escape_vent"])
	await _frames(4)
	var spring_path: String = Body.model_path(["ram_spring", "escape_vent"])
	_t.check("spring pair builds its own model", _shows_glb(body, spring_path), spring_path)
	anim = body.find_children("*", "AnimationPlayer", true, false)
	fake.armed = true
	await _frames(2)
	_t.eq("positive ram plays spring_arm", String(anim[0].current_animation), "spring_arm")
	await _frames(40)
	fake.armed = false
	await _frames(2)
	_t.eq("boost spent plays spring_spend", String(anim[0].current_animation), "spring_spend")

	_t.eq("capture hook seats a pair", body.seat_for_capture("primer_coil", "escape_rail"), "")
	await _frames(4)
	_t.check("capture hook shows the real body", body.is_real() and _shows_glb(body, Body.model_path(["primer_coil", "escape_rail"])), "primer_coil__escape_rail")

	# Missing model: the plain hull still shows.
	body.model_dir = "res://assets/models/companion/__missing__/"
	_game.run.companion = _doc(["primer_mesh", "escape_rail"])
	await _frames(4)
	_t.check("missing model keeps a fallback", not body.is_real() and body.visible and body.get_child_count() == 1 and _meshes(body)[0].mesh is BoxMesh, "box hull shown")
	_t.check("fallback is not the GLB", not _shows_glb(body, Body.model_path(["primer_mesh", "escape_rail"])), "box hull")

	enemy.free()
	_game.free()
	quit(_t.verdict())
