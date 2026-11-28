extends SceneTree

# The Foreman, Dispatcher and Splitter seat their glb's own scene (skeleton, skinned meshes,
# AnimationPlayer) under the pivot with a SpecialRig, so the authored loop and tell reach the
# screen: the loop plays on spawn, special_tell("tell") starts the tell clip on the frame it
# fires (sim emits, rig listens), the collider and sockets are unmoved, and reduced motion
# still stills the loop. A headless run without the idle opt-in copies meshes, as before.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const T := preload("res://tests/support/t.gd")
const Comfort := preload("res://src/core/comfort.gd")
const KINDS := {"foreman": "idle", "dispatcher": "idle", "splitter": "crawl"}

var game
var t := T.new("special_rig_wiring_test")


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
	await _frames(3)
	for enemy in get_nodes_in_group("enemy"):
		enemy.free()


func _spawn(kind: String, index: int):
	var enemy = game.combat.spawn_enemy(kind, Vector3(-100.0 + 14.0 * index, 38.0, -90.0))
	enemy.hp = 100000.0
	return enemy


func _shapes(enemy) -> Array:
	var out: Array = []
	for child in enemy.get_children():
		if child is CollisionShape3D:
			out.append(child.transform)
	return out


func _run() -> void:
	await _boot()
	# Without the idle opt-in a headless run draws nothing: meshes are copied, no rig is seated.
	var plain = _spawn("foreman", 5)
	t.check("headless without the idle copies meshes, no rig", plain.get_node_or_null("SpecialRig") == null
		and plain.find_children("*", "Skeleton3D", true, false).is_empty())
	plain.free()
	EnemyMotion.headless_idle = true
	var index := 0
	for kind in KINDS:
		var enemy = _spawn(kind, index)
		index += 1
		var shapes: Array = _shapes(enemy)
		var rig = enemy.get_node_or_null("SpecialRig")
		t.check(kind + " seats a SpecialRig", rig != null)
		if rig == null:
			enemy.free()
			continue
		var skeletons: Array = enemy.find_children("*", "Skeleton3D", true, false)
		t.check(kind + " skins its meshes on the glb's skeleton", skeletons.size() == 1
			and not skeletons[0].get_children().is_empty()
			and skeletons[0].find_children("*", "MeshInstance3D", true, false).all(func(m): return (m as MeshInstance3D).skin != null))
		t.eq(kind + " plays its loop on spawn", String(rig.player.current_animation), KINDS[kind])
		t.check(kind + " keeps its collider", not shapes.is_empty() and _shapes(enemy) == shapes)
		await _frames(10)
		t.check(kind + " loop advances", rig.player.current_animation_position > 0.0)
		enemy.emit_signal("special_tell", "tell")
		t.eq(kind + " tell clip starts on the signal's frame", String(rig.player.current_animation), "tell")
		t.near(kind + " tell is at age 0", rig.player.current_animation_position, 0.0, 0.0001)
		enemy.free()
	# Reduced motion stills the loop and eases the pose home rather than snapping it.
	Comfort.reduced_motion = true
	var calm = _spawn("dispatcher", 6)
	var calm_rig = calm.get_node("SpecialRig")
	t.check("reduced motion starts no loop", not calm_rig.player.is_playing())
	await _frames(20)
	t.check("reduced motion holds the body at rest", not calm_rig.player.is_playing())
	calm.free()
	Comfort.reduced_motion = false
	EnemyMotion.headless_idle = false
	quit(t.verdict())
