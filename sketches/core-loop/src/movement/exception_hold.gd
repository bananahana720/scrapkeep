extends RefCounted

# Bodies are tracked here and checked with is_instance_valid, never read back from the physics
# server: get_collision_exceptions() errors once an excepted body has been freed.

const MARGIN := 0.25
const FALLBACK := 1.5

var _ball: RigidBody3D
var _radius: float
# instance id -> {"body", "rid"}: the RID ends an exception whose body has been freed, which the
# physics server would otherwise keep.
var _held := {}
var _pending := {}
var _query: PhysicsShapeQueryParameters3D


func _init(ball: RigidBody3D, radius: float) -> void:
	_ball = ball
	_radius = radius


func hold(body: PhysicsBody3D) -> void:
	_purge()
	var id := body.get_instance_id()
	_pending.erase(id)
	if not _held.has(id):
		_ball.add_collision_exception_with(body)
		_held[id] = {"body": body, "rid": body.get_rid()}


func release(body) -> void:
	_purge()
	if not is_instance_valid(body):
		return
	var id: int = body.get_instance_id()
	if not _held.has(id):
		return
	if clear_of(body):
		_end(id)
	elif not _pending.has(id):
		_pending[id] = 0.0


func holding(body) -> bool:
	return is_instance_valid(body) and _held.has(body.get_instance_id())


func releasing(body) -> bool:
	return is_instance_valid(body) and _pending.has(body.get_instance_id())


func step(delta: float) -> void:
	_purge()
	for id in _pending.keys():
		var body = _held[id]["body"]
		_pending[id] += delta
		if clear_of(body):
			_end(id)
		elif _pending[id] >= FALLBACK:
			_set_beside(body)
			_end(id)


func _purge() -> void:
	for id in _held.keys():
		if not is_instance_valid(_held[id]["body"]):
			_end(id)


func _end(id: int) -> void:
	var entry: Dictionary = _held[id]
	_held.erase(id)
	_pending.erase(id)
	if is_instance_valid(_ball):
		PhysicsServer3D.body_remove_collision_exception(_ball.get_rid(), entry["rid"])


func _shapes(body: Node) -> Array:
	var out: Array = []
	var body_3d := body as CollisionObject3D
	if body_3d == null:
		return out
	for owner_id in body_3d.get_shape_owners():
		if body_3d.is_shape_owner_disabled(owner_id):
			continue
		var at := body_3d.global_transform * body_3d.shape_owner_get_transform(owner_id)
		for i in body_3d.shape_owner_get_shape_count(owner_id):
			var shape := body_3d.shape_owner_get_shape(owner_id, i)
			if shape != null:
				out.append({"shape": shape, "global_transform": at, "owner": owner_id})
	return out


func clear_of(body: PhysicsBody3D) -> bool:
	var at := _ball.global_position
	for node in _shapes(body):
		var shape = node.shape
		var centre: Vector3 = node.global_transform.origin
		if shape is CylinderShape3D or shape is CapsuleShape3D:
			var flat: float = Vector2(at.x - centre.x, at.z - centre.z).length()
			var above: float = absf(at.y - centre.y) - float(shape.get("height")) * 0.5
			if flat <= shape.radius + _radius + MARGIN and above <= _radius + MARGIN:
				return false
		elif shape is SphereShape3D:
			if at.distance_to(centre) <= shape.radius + _radius + MARGIN:
				return false
		elif _overlaps(body, node):
			return false
	return true


func _overlaps(body: PhysicsBody3D, node: Dictionary) -> bool:
	if not _ball.is_inside_tree():
		return false
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = _radius + MARGIN
		_query.shape = sphere
	_query.transform = Transform3D(Basis.IDENTITY, _ball.global_position)
	_query.collision_mask = body.collision_layer
	_query.exclude = [_ball.get_rid()]
	for hit in _ball.get_world_3d().direct_space_state.intersect_shape(_query, 16):
		if hit["collider"] == body and body.shape_find_owner(int(hit["shape"])) == node.owner:
			return true
	return false


func _set_beside(body: PhysicsBody3D) -> void:
	var at := _ball.global_position
	var reach := 0.0
	var centre: Vector3 = body.global_position
	for node in _shapes(body):
		var shape = node.shape
		if shape is CylinderShape3D or shape is CapsuleShape3D or shape is SphereShape3D:
			reach = maxf(reach, shape.radius)
		else:
			var box: AABB = shape.get_debug_mesh().get_aabb()
			reach = maxf(reach, Vector2(box.size.x, box.size.z).length() * 0.5)
		centre = node.global_transform.origin
	var out := Vector3(at.x - centre.x, 0.0, at.z - centre.z)
	if out.length() < 0.05:
		var v := _ball.linear_velocity
		out = Vector3(-v.x, 0.0, -v.z) if Vector2(v.x, v.z).length() > 0.1 else Vector3.BACK
	out = out.normalized() * (reach + _radius + MARGIN)
	var spot := Vector3(centre.x + out.x, at.y, centre.z + out.z)
	_ball.teleport(spot, _ball.linear_velocity)
