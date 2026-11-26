extends RefCounted

const WindupRows := preload("res://src/presentation/windup_rows.gd")

var _active := {}
var _rows := {}


func spawned(body: Node3D, kind: String) -> void:
	if kind in ["warden", "vault"]:
		return
	var row := {"kind": kind, "seen": false, "pop_in": false, "warned": false,
		"seen_before_warning_s": 0.0}
	var id := body.get_instance_id()
	_rows[id] = row
	_active[id] = {"ref": weakref(body), "row": row, "was_visible": false, "points": _points(body)}
	if body.has_signal("attack_phase"):
		body.connect("attack_phase", _phase.bind(row))
	if body.has_signal("special_tell"):
		body.connect("special_tell", func(moment: String):
			if moment == "tell":
				row.warned = true)


func _phase(fact: Dictionary, row: Dictionary) -> void:
	if fact.get("phase") == "windup":
		row.warned = true


func _points(body: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	if body is CollisionObject3D:
		for owner in body.get_shape_owners():
			var transform: Transform3D = body.shape_owner_get_transform(owner)
			for index in body.shape_owner_get_shape_count(owner):
				var mesh: Mesh = body.shape_owner_get_shape(owner, index).get_debug_mesh()
				if mesh == null:
					continue
				var box := mesh.get_aabb()
				var centre := box.get_center()
				points.append(transform * centre)
				for axis in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
					var offset: Vector3 = axis * box.size * 0.5
					points.append(transform * (centre - offset))
					points.append(transform * (centre + offset))
	if points.is_empty():
		points.append(Vector3.ZERO)
	return points


func _visible(cam: Camera3D, body: Node3D, points: PackedVector3Array) -> bool:
	if not body.is_visible_in_tree():
		return false
	for local in points:
		var point := body.to_global(local)
		if cam.is_position_in_frustum(point):
			var ray := PhysicsRayQueryParameters3D.create(cam.global_position, point, 1)
			ray.hit_from_inside = true
			if cam.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
				return true
	return false


func sample(cam: Camera3D, delta: float) -> void:
	for id in _active.keys():
		var track: Dictionary = _active[id]
		var body: Node3D = track.ref.get_ref()
		if body == null or not body.is_inside_tree() or body.is_queued_for_deletion() or (body.has_method("is_dead") and body.is_dead()):
			_active.erase(id)
			continue
		var row: Dictionary = track.row
		if row.seen and row.warned:
			_active.erase(id)
			continue
		if track.was_visible and not row.warned:
			row.seen_before_warning_s += delta
		if row.kind == "swarm_remnant" and not WindupRows.state_facts(body).is_empty():
			row.warned = true
		var visible := _visible(cam, body, track.points)
		track.was_visible = visible
		if visible and not row.seen:
			row.seen = true
			row.pop_in = body.get_meta("arrival_state", "live") == "live"


func reading(ids = null) -> Dictionary:
	var out := {"crews": 0, "seen": 0, "pop_ins": 0, "warnings": 0,
		"early_warnings": 0, "short_unwarned": 0, "seen_before_warning_s": null}
	for id in (_rows.keys() if ids == null else ids):
		if not _rows.has(id):
			continue
		var row: Dictionary = _rows[id]
		out.crews += 1
		out.seen += int(row.seen)
		out.pop_ins += int(row.pop_in)
		var lead := float(row.seen_before_warning_s)
		if not row.warned and lead + 0.000001 < 0.6:
			out.short_unwarned += 1
		if row.warned:
			out.warnings += 1
			if lead + 0.000001 < 0.6:
				out.early_warnings += 1
			if out.seen_before_warning_s == null or lead < out.seen_before_warning_s:
				out.seen_before_warning_s = lead
	return out
