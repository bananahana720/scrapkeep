extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Augments := preload("res://src/movement/augments.gd")

# Kest's blink passes through enemies but never lands inside a solid one (line-rider red team,
# w20 e646632d: a blink into Brindle's hull depenetrated the ball down through the bowl floor
# and the arena rescue put it on the ring for free). Real Game, real Kest, real Shift press at
# the stage 1 spawn, 6 m up so no ground shortens the reach, three blinks along the same aim
# (each read from the blink_used fact's landing, before the ball moves on):
#   open     nothing in the way: the blink's full reach;
#   through  a 1 m solid enemy-layer slab across the middle of the path: still the full reach;
#   inside   a solid enemy-layer block over the landing: the ball lands short of its near face,
#            clear of it;
#   enemy    the same block as a CharacterBody3D, the body every enemy proper is (enemy.gd): the
#            blink lands on it as before, its full reach.
# The slabs are AnimatableBody3D on layer 3, the body Brindle's parts are (boss_target.gd).

const SETTLE := 3
const MOVE := 4

var _game
var _player
var _source := Intent.Scripted.new()
var _failures := 0
var _booted := false
var _cases := ["open", "through", "inside", "enemy"]
var _case := 0
var _ticks := 0
var _from := Vector3.ZERO
var _block: PhysicsBody3D
var _moved := {}
var _dir := Vector3.ZERO
var _landed := Vector3.INF


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
		_player = _game.player
		_game.events.blink_used.connect(func(_f: Vector3, to: Vector3): _landed = to)
		return false
	if _case >= _cases.size():
		_finish()
		return true
	_ticks += 1
	if _ticks == 1:
		_begin(_cases[_case])
	elif _ticks == SETTLE:
		_player.reset_to(_player.ball_position())
		_from = _player.ball_position()
		_source.press = {"movement_pressed": true}
	elif _ticks == SETTLE + MOVE:
		_source.press = {}
		_end(_cases[_case])
		_case += 1
		_ticks = 0
	return false


func _begin(name: String) -> void:
	var def: Resource = ClassDef.by_id("demolitions_caster")
	_game.run.class_def = def
	_player.fit_class(def)
	for enemy in _game.get_tree().get_nodes_in_group("enemy"):
		enemy.remove_from_group("enemy")
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.queue_free()
	if is_instance_valid(_block):
		_block.free()
	_source.hold = {}
	_source.press = {}
	var at: Vector3 = _game.ctx.terrain.spawn_point(1) + Vector3.UP * 6.0
	_landed = Vector3.INF
	_player.reset_to(at)
	_player.body().global_position = at
	_player.drive_basis = Basis.IDENTITY
	_game.camera.snap(Vector3(0.0, 0.0, -1.0))
	_game.camera.pitch = 0.0
	if name == "through":
		_block = _slab(at, 4.0, 1.0)
	elif name == "inside":
		_block = _slab(at, 8.0, 6.0)
	elif name == "enemy":
		_block = _slab(at, 8.0, 6.0, CharacterBody3D.new())


# A solid enemy-layer block across the aim, centred `ahead` metres along it and `depth` deep: a boss part's
# AnimatableBody3D, or the CharacterBody3D every enemy proper is (enemy.gd).
func _slab(at: Vector3, ahead: float, depth: float, body: PhysicsBody3D = null) -> PhysicsBody3D:
	if body == null:
		body = AnimatableBody3D.new()
		body.sync_to_physics = false
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(3, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(12.0, 12.0, depth)
	shape.shape = box
	body.add_child(shape)
	_game.add_child(body)
	body.global_position = at + _dir * ahead
	body.look_at(body.global_position + _dir, Vector3.UP)
	return body


func _end(name: String) -> void:
	var to: Vector3 = _landed
	if to == Vector3.INF:
		_check("%s blink fired" % name, false, "no blink_used fact")
		return
	var flat := Vector3(to.x - _from.x, 0.0, to.z - _from.z)
	_moved[name] = flat.length()
	if name == "open":
		_dir = flat.normalized()
	print("%s: from %s to %s, moved %.2f m" % [name, _from, to, _moved[name]])
	if name == "inside":
		_check("inside lands clear of the block", _clear(to), "landing %s, block near face 5 m out" % to)


func _clear(at: Vector3) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, at)
	query.collision_mask = 4
	return _block.get_world_3d().direct_space_state.intersect_shape(query, 4).is_empty()


func _finish() -> void:
	var reach: float = _moved.get("open", 0.0)
	_check("open blink moves its full reach", absf(reach - Augments.BLINK_DISTANCE) < 0.3, "open blink moved %.2f m" % reach)
	_check("through passes a slab", absf(_moved.get("through", 0.0) - reach) < 0.05,
		"through moved %.2f m, open %.2f m" % [_moved.get("through", 0.0), reach])
	# The block's near face is 5 m out; the ball (radius about 0.9) stops short of it, within one
	# back-off step of touching.
	var inside: float = _moved.get("inside", 99.0)
	_check("inside lands short of the block", inside < 5.0 - 0.8 and inside > 5.0 - 0.9 - 0.6,
		"inside moved %.2f m (near face at 5.0 m)" % inside)
	_check("an enemy body over the landing is landed on as before", absf(_moved.get("enemy", 0.0) - reach) < 0.05,
		"enemy moved %.2f m, open %.2f m" % [_moved.get("enemy", 0.0), reach])
	print("kest_blink_solid_enemy_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	quit(0 if _failures == 0 else 1)
