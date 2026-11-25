extends Node3D

const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Weapons := preload("res://src/combat/weapons.gd")

# W47-H1 hero-baseline world-space VFX helper owned by Vfx (zero static mutable state):
#   - Sable: mint (Palette.ARC) Kinetic Orbit Pylon tether ring
#   - Rivet: superheated copper/amber (Palette.COPPER / Palette.AMBER) 6th hot-round tracer & ricochet glint
#   - Kest:  visible amber (Palette.AMBER #E5A044) sightline fuse-spark trace along unobstructed canyon walls,
#            revealing direct line-of-sight weak points and cracked destructible seams (ZERO through-rock radar).
# Strictly obeys B6 colour law: NEVER draws Palette.HAZARD (#FF5A3C).

const PRIORITY := 1
const WORLD_MASK := 1
const TRACER_LIFE := 0.24
const TRACER_CAP := 12
const RING_SEGMENTS := 36
const SEAM_SEGMENTS := 12
const OCCLUDE_EPS := 0.45
const SURFACE_LIFT := 0.14
const TRACE_FOV_HALF_DEG := 38.0
const TRACE_WALL_STEP := 2.5

var _mesh: ImmediateMesh
var _tracers: Array = []
var _pylon_ring := {}
var _kest_trace := {}
var _clock := 0.0


func setup() -> void:
	name = "HeroFx"
	_mesh = ImmediateMesh.new()
	var view := MeshInstance3D.new()
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = PRIORITY
	view.material_override = mat
	view.top_level = true
	add_child(view)
	set_process(false)


func clear() -> void:
	_tracers.clear()
	_pylon_ring = {}
	_kest_trace = {}
	if _mesh != null:
		_mesh.clear_surfaces()
	set_process(false)


# Rivet's active-reloaded 6th hot round copper/amber tracer (optional ricochet elbow segment).
func add_rivet_hot_tracer(from: Vector3, to: Vector3, ricochet_to := Vector3.INF) -> void:
	if _tracers.size() >= TRACER_CAP:
		_tracers.pop_front()
	_tracers.append({
		"from": from,
		"to": to,
		"ricochet_to": ricochet_to,
		"life": TRACER_LIFE,
		"span": TRACER_LIFE,
		"color": Palette.COPPER,
		"accent": Palette.AMBER,
	})
	set_process(true)


# Sable's Kinetic Orbit Pylon mint tether ring (Palette.ARC #8BF0D3).
func set_sable_pylon_ring(at: Vector3, radius: float, overcharged: bool, active := true) -> void:
	if not active or radius <= 0.05:
		_pylon_ring = {}
		_update_processing()
		return
	_pylon_ring = {
		"at": at,
		"radius": radius,
		"overcharged": overcharged,
		"color": Palette.ARC,
	}
	set_process(true)


# Kest's unobstructed sightline amber fuse-spark trace (Palette.AMBER #E5A044).
func set_kest_fuse_trace(scan: Dictionary) -> void:
	if scan.is_empty():
		_kest_trace = {}
		_update_processing()
		return
	var walls: Array = scan.get("wall_traces", [])
	var weaks: Array = scan.get("weak_points", [])
	var seams: Array = scan.get("destructible_seams", [])
	if walls.is_empty() and weaks.is_empty() and seams.is_empty():
		_kest_trace = {}
		_update_processing()
		return
	_kest_trace = {
		"wall_traces": walls,
		"weak_points": weaks,
		"destructible_seams": seams,
		"color": Palette.AMBER,
	}
	set_process(true)


func clear_kest_fuse_trace() -> void:
	_kest_trace = {}
	_update_processing()


func snapshot() -> Dictionary:
	return {
		"tracers": _tracers.size(),
		"pylon_ring": _pylon_ring.duplicate(),
		"kest_trace_walls": (_kest_trace.get("wall_traces", []) as Array).size(),
		"kest_trace_weaks": (_kest_trace.get("weak_points", []) as Array).size(),
		"kest_trace_seams": (_kest_trace.get("destructible_seams", []) as Array).size(),
	}


# Direct line-of-sight scan for Kest's visible amber fuse-spark trace.
# Strictly raycasts WORLD_MASK from `eye` to every canyon surface, enemy weak point, and intact
# Heft Destructible seam. Anything occluded by canyon rock/walls is strictly skipped (ZERO wall-hack).
static func scan_kest_sightline(space: PhysicsDirectSpaceState3D, eye: Vector3, forward: Vector3,
		enemies: Array, destructibles = null, max_range := Weapons.KEST_FUSE_TRACE_RANGE) -> Dictionary:
	var result := {
		"wall_traces": [],
		"weak_points": [],
		"destructible_seams": [],
		"occluded_skipped": 0,
		"color": Palette.AMBER,
	}
	if space == null:
		return result
	var fwd := forward.normalized() if forward.length_squared() > 0.0001 else Vector3.FORWARD
	var up_hint := Vector3.UP if absf(fwd.dot(Vector3.UP)) < 0.96 else Vector3.FORWARD
	var right := fwd.cross(up_hint).normalized()
	var up := right.cross(fwd).normalized()

	# 1. Surface-running amber fuse-spark trace along canyon/wall faces Kest directly sees.
	var wall_hits: Array = []
	var ray_count := maxi(3, Weapons.KEST_FUSE_TRACE_RAYS)
	var half_rad := deg_to_rad(TRACE_FOV_HALF_DEG)
	for i in ray_count:
		var u := (float(i) / float(ray_count - 1)) * 2.0 - 1.0
		var yaw_ang := u * half_rad
		var pitch_ang := -0.08 + 0.04 * absf(u)
		var dir := (fwd * cos(yaw_ang) + right * sin(yaw_ang) + up * pitch_ang).normalized()
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, eye + dir * max_range, WORLD_MASK))
		if hit.is_empty():
			continue
		var pt: Vector3 = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * SURFACE_LIFT
		wall_hits.append({"at": pt, "normal": hit["normal"], "dist": eye.distance_to(hit["position"])})
	for i in range(wall_hits.size() - 1):
		var a: Vector3 = wall_hits[i]["at"]
		var b: Vector3 = wall_hits[i + 1]["at"]
		var span := a.distance_to(b)
		if span >= 0.25 and span <= 16.0:
			# Verify midpoint stays near visible sightline (not bridging across a chasm behind cover).
			var mid := a.lerp(b, 0.5)
			if _has_line_of_sight(space, eye, mid, null):
				(result["wall_traces"] as Array).append({"from": a, "to": b, "color": Palette.AMBER})

	# 2. Direct line-of-sight enemy weak points (or unobstructed crown/hull spot on ordinary
	# machines with no separate weak_points()) — STRICTLY zero through-rock reveal.
	for enemy in enemies:
		if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
			continue
		var weaks: Array = enemy.weak_points() if enemy.has_method("weak_points") else []
		if weaks.is_empty():
			var hh: float = float(enemy.get("half_height")) if enemy.get("half_height") != null else 1.0
			var rad: float = float(enemy.get("radius")) if enemy.get("radius") != null else 0.7
			weaks = [{"id": "hull", "at": enemy.global_position + Vector3.UP * maxf(0.6, hh * 0.7), "radius": rad * 0.6}]
		for w in weaks:
			var at: Vector3 = w["at"]
			var dist := eye.distance_to(at)
			if dist > max_range or dist < 0.1:
				continue
			if not _has_line_of_sight(space, eye, at, null):
				result["occluded_skipped"] = int(result["occluded_skipped"]) + 1
				continue
			var entry := {
				"enemy_id": enemy.get_instance_id(),
				"part": String(w.get("id", "weak")),
				"at": at,
				"radius": float(w.get("radius", 0.5)),
				"color": Palette.AMBER,
			}
			(result["weak_points"] as Array).append(entry)
			var wall_anchor := _nearest_surface_anchor(wall_hits, at, 14.0)
			if wall_anchor != Vector3.INF:
				(result["wall_traces"] as Array).append({"from": wall_anchor, "to": at, "color": Palette.AMBER})

	# 3. Direct line-of-sight intact cracked destructible seams ONLY (zero through-rock reveal).
	if destructibles != null and is_instance_valid(destructibles) and destructibles.has_method("ids"):
		for id in destructibles.ids():
			if destructibles.state_of(id) != "intact":
				continue
			var bounds: AABB = destructibles.bounds_of(id)
			var centre := bounds.get_center()
			var dist := eye.distance_to(centre)
			if dist > max_range or dist < 0.1:
				continue
			var own_body = destructibles.body_of(id)
			if not _has_line_of_sight(space, eye, centre, own_body):
				result["occluded_skipped"] = int(result["occluded_skipped"]) + 1
				continue
			var seam_at := centre
			var toward := (centre - eye).normalized()
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, centre + toward * 0.5, WORLD_MASK))
			if not hit.is_empty() and hit.get("collider") == own_body:
				seam_at = (hit["position"] as Vector3) + (hit["normal"] as Vector3) * SURFACE_LIFT
			(result["destructible_seams"] as Array).append({
				"id": String(id),
				"tier": int(destructibles.tier_of(id)),
				"at": seam_at,
				"bounds": bounds,
				"color": Palette.AMBER,
			})
			var wall_anchor := _nearest_surface_anchor(wall_hits, seam_at, 14.0)
			if wall_anchor != Vector3.INF:
				(result["wall_traces"] as Array).append({"from": wall_anchor, "to": seam_at, "color": Palette.AMBER})

	return result


static func _has_line_of_sight(space: PhysicsDirectSpaceState3D, eye: Vector3, target: Vector3, allow_collider = null) -> bool:
	var dist := eye.distance_to(target)
	if dist <= 0.15:
		return true
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, target, WORLD_MASK))
	if hit.is_empty():
		return true
	if allow_collider != null and hit.get("collider") == allow_collider:
		return true
	return eye.distance_to(hit["position"]) >= dist - OCCLUDE_EPS


static func _nearest_surface_anchor(wall_hits: Array, at: Vector3, max_span: float) -> Vector3:
	var best := Vector3.INF
	var best_d := max_span
	for h in wall_hits:
		var pt: Vector3 = h["at"]
		var d := pt.distance_to(at)
		if d < best_d and d > 0.2:
			best_d = d
			best = pt
	return best


func _update_processing() -> void:
	var active := not _tracers.is_empty() or not _pylon_ring.is_empty() or not _kest_trace.is_empty()
	if not active and _mesh != null:
		_mesh.clear_surfaces()
	set_process(active)


func _process(delta: float) -> void:
	_clock += delta
	if _mesh == null:
		return
	_mesh.clear_surfaces()
	if not _tracers.is_empty():
		var kept: Array = []
		for t in _tracers:
			t["life"] = float(t["life"]) - delta
			if float(t["life"]) > 0.0:
				kept.append(t)
		_tracers = kept
	if _tracers.is_empty() and _pylon_ring.is_empty() and _kest_trace.is_empty():
		set_process(false)
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for t in _tracers:
		_draw_tracer(t)
	if not _pylon_ring.is_empty():
		_draw_pylon_ring(_pylon_ring)
	if not _kest_trace.is_empty():
		_draw_kest_trace(_kest_trace)
	_mesh.surface_end()


func _line(a: Vector3, b: Vector3, color: Color) -> void:
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(a)
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(b)


func _draw_tracer(t: Dictionary) -> void:
	var frac := clampf(float(t["life"]) / maxf(0.001, float(t["span"])), 0.0, 1.0)
	var alpha := FlashGuard.info(0.95 * frac)
	var copper := Color(Palette.COPPER, alpha)
	var amber := Color(Palette.AMBER, alpha)
	var a: Vector3 = t["from"]
	var b: Vector3 = t["to"]
	_line(a, b, copper)
	_line(a + Vector3.UP * 0.08, b + Vector3.UP * 0.08, amber)
	var ric: Vector3 = t["ricochet_to"]
	if ric.is_finite():
		_line(b, ric, amber)
		_line(b + Vector3.UP * 0.07, ric + Vector3.UP * 0.07, copper)
		var star := 0.55 * frac + 0.15
		_line(b - Vector3.RIGHT * star, b + Vector3.RIGHT * star, amber)
		_line(b - Vector3.UP * star, b + Vector3.UP * star, amber)
		_line(b - Vector3.BACK * star, b + Vector3.BACK * star, amber)


func _draw_pylon_ring(entry: Dictionary) -> void:
	var at: Vector3 = entry["at"] + Vector3.UP * 0.35
	var radius := float(entry["radius"])
	var overcharged := bool(entry.get("overcharged", false))
	var pulse := 0.78 + 0.18 * sin(_clock * (10.0 if overcharged else 3.5))
	var alpha := FlashGuard.info((0.82 if overcharged else 0.42) * pulse)
	var color := Color(Palette.ARC, alpha)
	var prev := at + Vector3(radius, 0.0, 0.0)
	for i in range(1, RING_SEGMENTS + 1):
		var ang := TAU * float(i) / float(RING_SEGMENTS)
		var pt := at + Vector3(cos(ang) * radius, 0.0, sin(ang) * radius)
		_line(prev, pt, color)
		prev = pt
	if overcharged:
		var inner := radius * 0.86
		var prev_in := at + Vector3(inner, 0.0, 0.0)
		var inner_col := Color(Palette.ARC, alpha * 0.7)
		for i in range(1, RING_SEGMENTS + 1):
			var ang := TAU * float(i) / float(RING_SEGMENTS)
			var pt := at + Vector3(cos(ang) * inner, 0.0, sin(ang) * inner)
			_line(prev_in, pt, inner_col)
			prev_in = pt


func _draw_kest_trace(trace: Dictionary) -> void:
	var flicker := 0.75 + 0.25 * sin(_clock * 14.0)
	var alpha := FlashGuard.info(0.85 * flicker)
	var amber := Color(Palette.AMBER, alpha)
	var spark_col := Color(Palette.SAND, alpha)
	for seg in trace.get("wall_traces", []):
		var a: Vector3 = seg["from"]
		var b: Vector3 = seg["to"]
		_line(a, b, amber)
		var travel := fposmod(_clock * 2.2, 1.0)
		var bead := a.lerp(b, travel)
		_line(bead - Vector3.UP * 0.16, bead + Vector3.UP * 0.16, spark_col)
	for w in trace.get("weak_points", []):
		var at: Vector3 = w["at"]
		var r := maxf(0.45, float(w.get("radius", 0.5)) * 1.15)
		_draw_amber_diamond(at, r, amber)
	for s in trace.get("destructible_seams", []):
		var at: Vector3 = s["at"]
		var bounds: AABB = s.get("bounds", AABB(at - Vector3.ONE, Vector3.ONE * 2.0))
		var half_h := clampf(bounds.size.y * 0.4, 0.6, 2.4)
		_line(at - Vector3.UP * half_h, at + Vector3.UP * half_h, amber)
		_draw_amber_diamond(at, 0.75, spark_col)


func _draw_amber_diamond(at: Vector3, r: float, color: Color) -> void:
	var top := at + Vector3.UP * r
	var bot := at - Vector3.UP * r
	var l := at - Vector3.RIGHT * r
	var rt := at + Vector3.RIGHT * r
	var f := at - Vector3.BACK * r
	var bk := at + Vector3.BACK * r
	_line(top, l, color)
	_line(top, rt, color)
	_line(bot, l, color)
	_line(bot, rt, color)
	_line(top, f, color)
	_line(top, bk, color)
	_line(bot, f, color)
	_line(bot, bk, color)
