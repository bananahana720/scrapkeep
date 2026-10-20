extends SceneTree

# A spawned enemy's body enters the physics space where it stands (combat.gd spawn_enemy).
# Jolt reads a kinematic body moved after it entered as a velocity over the next step, so an
# enemy entered at the world origin and then moved to its spawn point pushed whatever stood at
# the origin along that move: item_fuzz seed 2751 had a miniboss spawned 24 m ahead shove a
# ball rolling there out at 500 m/s (243.9 m/s planar, against the 60 m/s ceiling).
# Every kind the spawner makes, the vault and the Warden (which settle themselves in setup)
# included, is on the physics server where its node stands the moment spawn_enemy returns.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

const BASE_KINDS := ["chaser", "lobber", "miniboss", "vault", "warden"]
const FAR := Vector3(37.0, 0.0, -41.0)

var _t := T.new("spawn_physics_place_test")
var _game
var _ticks := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	if _ticks == 1:
		var ctx = _game.ctx
		ctx.calm = true
		_game.player.source = Intent.Scripted.new()
		_game.flow.press_start()
		_game.flow.choose_class(0)
		_game.run.set_max_hp(99999.0)
		return false
	if _ticks < 12:
		return false
	_check_kinds()
	var code := _t.verdict()
	print("spawn_physics_place_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)
	return true


func _check_kinds() -> void:
	var ctx = _game.ctx
	var kinds: Array = BASE_KINDS.duplicate()
	for kind in ctx.spawner.fleet.SCRIPTS:
		if not kind in kinds:
			kinds.append(kind)
	var bodies := 0
	var misplaced: Array = []
	for kind in kinds:
		var at: Vector3 = ctx.terrain.drop_point(FAR.x, FAR.z, 2.4)
		var enemy: Node3D = ctx.spawner.spawn_enemy(kind, at)
		if not enemy is CollisionObject3D:
			enemy.queue_free()
			continue
		bodies += 1
		var node: Vector3 = enemy.global_position
		var server: Vector3 = PhysicsServer3D.body_get_state((enemy as CollisionObject3D).get_rid(),
			PhysicsServer3D.BODY_STATE_TRANSFORM).origin
		if server.distance_to(node) > 0.01:
			misplaced.append("%s node %s server %s" % [kind, node, server])
		enemy.queue_free()
	_t.check("every spawned body is on the physics server where its node stands", bodies >= BASE_KINDS.size() and misplaced.is_empty(),
		"%d bodies of %d kinds; misplaced %s" % [bodies, kinds.size(), misplaced])

