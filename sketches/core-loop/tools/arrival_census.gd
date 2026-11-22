extends RefCounted

# Headless witness of the crew's collider through the rider's lens. The drawn
# footprint at a mouth is a separate look-harness measurement. World geometry
# is layer 1; the ball and other moving crews use different layers.
const Chaser := preload("res://src/combat/chaser.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")

var _active := {}
var _rows := {}


func spawned(body: Node3D, kind: String, stage := 1) -> void:
	# These two anchored set pieces also pass through spawn_enemy.
	if kind in ["warden", "vault"]:
		return
	var row := {"kind": kind, "stage": stage, "ref": weakref(body), "died": false, "seen": false, "pop_in": false, "warned": false,
		"seen_before_warning_s": 0.0}
	var id := body.get_instance_id()
	_rows[id] = row
	_active[id] = {"ref": row.ref, "row": row, "was_visible": false, "points": _points(body)}
	# A death can free the body between two samples.
	if body.has_signal("died"):
		body.connect("died", func(_at: Vector3, _scrap: int): row.died = true, CONNECT_ONE_SHOT)
	if body.has_signal("attack_phase"):
		body.connect("attack_phase", _phase.bind(row))
	if body.has_signal("special_tell"):
		body.connect("special_tell", func(moment: String):
			if moment == "tell":
				row.warned = true)


func _phase(fact: Dictionary, row: Dictionary) -> void:
	if fact.get("phase") == "windup":
		row.warned = true


# Cache body-local samples from the actual shapes at spawn. The centre and
# six face centres capture a shoulder or crown emerging before the origin.
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


# Call once per physics tick. An interval is credited only after the body
# was actually visible. A warning before its first visible tick keeps zero.
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
		if not row.warned and not _enough_lead(lead):
			out.short_unwarned += 1
		if row.warned:
			out.warnings += 1
			if not _enough_lead(lead):
				out.early_warnings += 1
			if out.seen_before_warning_s == null or lead < out.seen_before_warning_s:
				out.seen_before_warning_s = lead
	# The same coverage rule applies to a whole ride and an individual yard wave.
	out["crew_coverage_complete"] = out.crews > 0 and out.seen == out.crews and out.short_unwarned == 0
	return out


static func _enough_lead(seconds: float) -> bool:
	return seconds + 0.000001 >= Chaser.WINDUP


func _observation(row: Dictionary) -> String:
	if not row.seen:
		return "unseen"
	if row.warned:
		return "warned" if _enough_lead(row.seen_before_warning_s) else "early_warning"
	return "lead_observed" if _enough_lead(row.seen_before_warning_s) else "short_unwarned"


# Keep one entry per spawn in spawn order, including crews already freed. The
# way a crew left the ride never excuses a missing first sighting or warning lead.
func ordinary_reading(ending: String) -> Dictionary:
	var out := reading()
	var members := []
	for row: Dictionary in _rows.values():
		var body: Node3D = row.ref.get_ref()
		var fate := "present_at_end"
		if row.died:
			fate = "died"
		elif body == null or not body.is_inside_tree() or body.is_queued_for_deletion():
			fate = "removed"
		members.append({"spawn": members.size() + 1, "stage": row.stage, "kind": row.kind,
			"fate": fate, "observation": _observation(row), "warned": row.warned,
			"seen_before_warning_s": row.seen_before_warning_s, "pop_in": row.pop_in})
	out["members"] = members
	out["ending"] = ending
	return out
