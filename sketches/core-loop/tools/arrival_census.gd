extends RefCounted

# Headless witness of the crew's body origin through the rider's lens. The drawn
# footprint at a mouth is a separate look-harness measurement. World geometry
# is layer 1; the ball and other moving crews use different layers.
const WindupRows := preload("res://src/presentation/windup_rows.gd")

var _active := {}
var _rows: Array[Dictionary] = []


func spawned(body: Node3D, kind: String) -> void:
	# These two anchored set pieces also pass through spawn_enemy.
	if kind in ["warden", "vault"]:
		return
	var row := {"kind": kind, "seen": false, "pop_in": false, "warned": false,
		"seen_before_warning_s": 0.0}
	_rows.append(row)
	var id := body.get_instance_id()
	_active[id] = {"ref": weakref(body), "row": row, "was_visible": false}
	if body.has_signal("attack_phase"):
		body.connect("attack_phase", _phase.bind(row))
	if body.has_signal("special_tell"):
		body.connect("special_tell", func(moment: String):
			if moment == "tell":
				row.warned = true)


func _phase(fact: Dictionary, row: Dictionary) -> void:
	if fact.get("phase") == "windup":
		row.warned = true


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
		var point := body.global_position
		var visible := body.is_visible_in_tree() and cam.is_position_in_frustum(point)
		if visible:
			var ray := PhysicsRayQueryParameters3D.create(cam.global_position, point, 1)
			ray.hit_from_inside = true
			visible = cam.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		track.was_visible = visible
		if visible and not row.seen:
			row.seen = true
			row.pop_in = body.get_meta("arrival_state", "live") == "live"


func reading() -> Dictionary:
	var out := {"crews": _rows.size(), "seen": 0, "pop_ins": 0, "warnings": 0,
		"early_warnings": 0, "seen_before_warning_s": null}
	for row in _rows:
		out.seen += int(row.seen)
		out.pop_ins += int(row.pop_in)
		if row.warned:
			out.warnings += 1
			var lead := float(row.seen_before_warning_s)
			if lead + 0.000001 < 0.6:
				out.early_warnings += 1
			if out.seen_before_warning_s == null or lead < out.seen_before_warning_s:
				out.seen_before_warning_s = lead
	return out
