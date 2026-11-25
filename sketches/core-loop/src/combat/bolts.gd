extends Node3D

const Density := preload("res://src/presentation/density.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")
const Palette := preload("res://src/core/palette.gd")

const MAX_LIVE := 64
const PRIORITY := 0
const WORLD_MASK := 1
const WIDTH := 0.16
const STREAK_SECONDS := 0.018
const MIN_STREAK := 0.8
const ALPHA_FULL := 0.9
const ALPHA_CROWDED := 0.4
const CROWD_START := 16
const WAVE_RAMP := 6.0
const MULTI_BIT_WIDTH := 1.15
const DRAW_MERGE_M := 4.0
const RIVET_MUZZLE_SIDE_M := 1.26
const SPLIT_ANGLE_DEG := 18.0
const SPLIT_DAMAGE := 0.5
const SPLIT_REACH := 12.0
const BOUNCE_LIFT := 0.05
const MAX_EXTRA_BOUNCES := 2
const RICOCHET_HOME_REACH := 26.0
const RICOCHET_HOME_TURN := 0.75
const BOOMERANG_PAUSE_S := 0.15
const BOOMERANG_MAX_DAMAGE_MULT := 2.0
const BOOMERANG_MAX_WIDTH_MULT := 2.25
const BOOMERANG_RETURN_PIERCE := 4
const RAILGUN_MAX_BOOSTS := 2

var on_hit: Callable
var on_shell: Callable
var on_stop: Callable
var on_bounce: Callable
var on_flight: Callable
var peak_live := 0
var retired := 0
var fired := 0

var _bolts: Array = []
var _multimesh: MultiMesh
var _rivet_muzzle_shot := 0


func setup() -> void:
	name = "Bolts"
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = MAX_LIVE
	_multimesh.visible_instance_count = 0
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_multimesh.mesh = box
	var view := MultiMeshInstance3D.new()
	view.multimesh = _multimesh
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


static func crowd_alpha(live_count: int) -> float:
	if live_count <= CROWD_START:
		return ALPHA_FULL
	var t := clampf(float(live_count - CROWD_START) / float(MAX_LIVE - CROWD_START), 0.0, 1.0)
	return lerpf(ALPHA_FULL, ALPHA_CROWDED, t)


func live() -> int:
	return _bolts.size()


func clear() -> void:
	_bolts.clear()
	_rivet_muzzle_shot = 0
	if _multimesh != null:
		_multimesh.visible_instance_count = 0


func fire(bolt: Dictionary) -> void:
	if not bolt.has("bits"):
		bolt["bits"] = 0
	if not bolt.has("spent"):
		bolt["spent"] = 0
	if _bolts.size() >= MAX_LIVE:
		_bolts.pop_front()
		retired += 1
	var dir: Vector3 = bolt["dir"]
	if dir.length_squared() < 1e-6:
		dir = Vector3.FORWARD
		bolt["dir"] = dir
	var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	bolt["right"] = dir.cross(up_hint).normalized()
	bolt["up"] = (bolt["right"] as Vector3).cross(dir).normalized()
	bolt["draw_offset"] = _initial_draw_offset(bolt)
	bolt["travelled"] = 0.0
	bolt["age"] = 0.0
	bolt["shown"] = bolt["origin"]
	bolt["pierce"] = int(bolt.get("pierce", 0))
	bolt["exclude"] = (bolt.get("exclude", []) as Array).duplicate()
	bolt["acts"] = 0
	_bolts.append(bolt)
	fired += 1
	peak_live = maxi(peak_live, _bolts.size())


func _initial_draw_offset(bolt: Dictionary) -> Vector3:
	if bolt.has("draw_origin"):
		var off: Vector3 = (bolt["draw_origin"] as Vector3) - (bolt["origin"] as Vector3)
		return off if off.is_finite() else Vector3.ZERO
	if bolt.has("draw_offset"):
		var off: Vector3 = bolt["draw_offset"]
		return off if off.is_finite() else Vector3.ZERO
	if String(bolt.get("weapon_id", "")) == "rapid_laser" and String(bolt.get("source", "weapon")) == "weapon":
		var side := -1.0 if (_rivet_muzzle_shot % 2) == 0 else 1.0
		_rivet_muzzle_shot += 1
		return (bolt["right"] as Vector3) * (side * RIVET_MUZZLE_SIDE_M)
	return Vector3.ZERO


static func child(parent: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := parent.duplicate()
	for key in ["travelled", "age", "shown", "right", "up", "exclude", "draw_origin", "draw_offset", "bounces", "ricochet_curved",
			"boomerang", "boomerang_pause", "boomerang_returned", "boomerang_pause_s", "boomerang_damage_mult", "boomerang_width_mult", "whiplash_pull",
			"railgun_ricochet", "railgun_speed_mult", "railgun_damage_mult", "railgun_max_stacks", "railgun_boosts", "railgun_boosted_last"]:
		out.erase(key)
	for key in overrides:
		out[key] = overrides[key]
	if not overrides.has("draw_origin") and not overrides.has("draw_offset"):
		out["draw_offset"] = Vector3.ZERO
	out["bits"] = ShotBits.union(0, int(parent.get("bits", 0)))
	out["spent"] = ShotBits.union(0, int(parent.get("spent", 0)))
	if out.has("extra_bounces"):
		out["extra_bounces"] = clampi(int(out["extra_bounces"]), 0, MAX_EXTRA_BOUNCES)
	return out


static func passes_left(bolt: Dictionary) -> int:
	return int(bolt.get("pierce", 0)) + (1 if _pierce_bit_ready(bolt) else 0)


static func _pierce_bit_ready(bolt: Dictionary) -> bool:
	return bit_ready(bolt, "pierce")


static func bit_ready(bolt: Dictionary, bit_name: String) -> bool:
	var b := ShotBits.bit(bit_name)
	return ShotBits.has(int(bolt.get("bits", 0)), b) and not ShotBits.has(int(bolt.get("spent", 0)), b)


static func split_spent(parent_spent: int) -> int:
	var spent := ShotBits.union(parent_spent, ShotBits.bit("split") | ShotBits.bit("pull"))
	return ShotBits.without(spent, ShotBits.bit("pierce"))


static func split_children(parent: Dictionary, point: Vector3, struck_id: int, used_dist := -1.0) -> Array:
	if not bit_ready(parent, "split"):
		return []
	var used := used_dist if used_dist >= 0.0 else float(parent.get("travelled", 0.0))
	var left := clampf(float(parent["max_dist"]) - used, 0.0, SPLIT_REACH)
	if left <= 0.05:
		return []
	var dir: Vector3 = parent["dir"]
	var axis: Vector3 = parent.get("up", Vector3.UP)
	var exclude: Array = (parent.get("exclude", []) as Array).duplicate()
	exclude.append(struck_id)
	var angle := deg_to_rad(float(parent.get("split_angle_deg", SPLIT_ANGLE_DEG)))
	var split_knock := float(parent.get("split_knock", 0.0))
	var out: Array = []
	for side in [-1.0, 1.0]:
		var kid := child(parent, {"origin": point, "dir": dir.rotated(axis, angle * side).normalized(),
			"max_dist": left, "damage": float(parent["damage"]) * SPLIT_DAMAGE, "pierce": 0})
		kid.erase("hoar")
		kid.erase("hoar_spared")
		kid["spent"] = split_spent(int(parent.get("spent", 0)))
		kid["exclude"] = exclude.duplicate()
		if split_knock > 0.0:
			kid["knock"] = maxf(float(kid.get("knock", 0.0)), split_knock)
		out.append(kid)
	return out


static func tint(bolt: Dictionary) -> Color:
	var held := ShotBits.names(int(bolt.get("bits", 0)))
	return ShotBits.TABLE[held[0]]["color"] if not held.is_empty() else bolt["color"]


static func width(bolt: Dictionary) -> float:
	return WIDTH * float(bolt.get("width_scale", 1.0)) * (MULTI_BIT_WIDTH if ShotBits.count(int(bolt.get("bits", 0))) >= 2 else 1.0)


static func drawn_width(bolt: Dictionary) -> float:
	return width(bolt)


func step(delta: float, space: PhysicsDirectSpaceState3D, enemies: Array, shells: Array = []) -> void:
	if _bolts.is_empty():
		return
	var survivors: Array = []
	var spawned: Array = []
	var snapshot: Array = _snapshot(enemies)
	for bolt in _bolts:
		if float(bolt.get("boomerang_pause", 0.0)) > 0.0:
			bolt["age"] += delta
			bolt["boomerang_pause"] = maxf(0.0, float(bolt["boomerang_pause"]) - delta)
			if float(bolt["boomerang_pause"]) <= 0.0:
				_flip_boomerang(bolt)
			survivors.append(bolt)
			continue
		var from: Vector3 = bolt["shown"]
		var before: float = bolt["travelled"]
		bolt["age"] += delta
		bolt["travelled"] = minf(bolt["travelled"] + bolt["speed"] * delta, bolt["max_dist"])
		var to := _position(bolt)
		var end := to
		var blocked := false
		var normal := Vector3.ZERO
		if from.distance_squared_to(to) > 0.000001:
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK))
			if not wall.is_empty():
				end = wall["position"]
				normal = wall.get("normal", Vector3.ZERO)
				blocked = true
		var target := _first_enemy(from, end, bolt["radius"], snapshot, bolt["exclude"])
		var shell := _first_shell(from, end, bolt["radius"], shells)
		if not shell.is_empty() and (target.is_empty() or shell["along"] < target["along"]):
			if on_shell.is_valid() and on_shell.call(bolt, shell["shell"]):
				continue
		var stopped := false
		var flown := end
		while not target.is_empty():
			var hit_id: int = target["enemy"].get_instance_id()
			var acts := 0
			var hit_used := before + from.distance_to(target["point"])
			if int(bolt["pierce"]) < 1 and _pierce_bit_ready(bolt):
				acts = ShotBits.union(acts, ShotBits.bit("pierce"))
			if bit_ready(bolt, "split") and float(bolt["max_dist"]) - hit_used > 0.05:
				acts = ShotBits.union(acts, ShotBits.bit("split"))
			bolt["acts"] = acts
			if on_hit.is_valid():
				on_hit.call(bolt, target["enemy"], target["point"], target["part"])
			bolt["acts"] = 0
			_refresh_entry(target["entry"])
			if ShotBits.has(acts, ShotBits.bit("split")):
				spawned.append_array(split_children(bolt, target["point"], hit_id, hit_used))
				bolt["spent"] = ShotBits.union(int(bolt["spent"]), ShotBits.bit("split"))
			if bolt["pierce"] > 0:
				bolt["pierce"] -= 1
			elif _pierce_bit_ready(bolt):
				bolt["spent"] = ShotBits.union(int(bolt["spent"]), ShotBits.bit("pierce"))
			else:
				stopped = true
				flown = target["point"]
				break
			(bolt["exclude"] as Array).append(hit_id)
			target = _first_enemy(from, end, bolt["radius"], snapshot, bolt["exclude"])
		if on_flight.is_valid():
			on_flight.call(bolt, from, flown)
		if stopped:
			continue
		if blocked:
			if _glance(bolt, end, normal, before + from.distance_to(end), snapshot):
				survivors.append(bolt)
				continue
			if on_stop.is_valid():
				on_stop.call(end, bolt["color"])
			continue
		if bolt["travelled"] >= bolt["max_dist"]:
			if bool(bolt.get("boomerang", false)) and not bool(bolt.get("boomerang_returned", false)):
				bolt["shown"] = to
				bolt["boomerang_pause"] = maxf(0.01, float(bolt.get("boomerang_pause_s", BOOMERANG_PAUSE_S)))
				survivors.append(bolt)
			continue
		bolt["shown"] = to
		survivors.append(bolt)
	_bolts = survivors
	for kid in spawned:
		fire(kid)


func _glance(bolt: Dictionary, at: Vector3, normal: Vector3, used: float, snapshot: Array = []) -> bool:
	var left := float(bolt["max_dist"]) - used
	var bounce_ready := bit_ready(bolt, "bounce")
	var extra := clampi(int(bolt.get("extra_bounces", 0)), 0, MAX_EXTRA_BOUNCES)
	if (not bounce_ready and extra <= 0) or normal.length_squared() < 0.0001 or left <= 0.0:
		return false
	var n := normal.normalized()
	var dir: Vector3 = (bolt["dir"] as Vector3).bounce(n).normalized()
	if bounce_ready:
		bolt["spent"] = ShotBits.union(int(bolt["spent"]), ShotBits.bit("bounce"))
	else:
		bolt["extra_bounces"] = extra - 1
	var lift_origin := at + n * BOUNCE_LIFT
	if bool(bolt.get("ricochet_home", false)) and not snapshot.is_empty():
		var curved := _ricochet_curve(dir, lift_origin, snapshot, bolt.get("exclude", []),
			float(bolt.get("ricochet_home_reach", RICOCHET_HOME_REACH)),
			float(bolt.get("ricochet_home_turn", RICOCHET_HOME_TURN)))
		if not curved.is_equal_approx(dir):
			dir = curved
			bolt["ricochet_curved"] = true
	bolt["bounces"] = int(bolt.get("bounces", 0)) + 1
	bolt["origin"] = lift_origin
	bolt["dir"] = dir
	bolt["max_dist"] = left
	bolt["travelled"] = 0.0
	bolt["shown"] = bolt["origin"]
	bolt.erase("draw_origin")
	bolt["draw_offset"] = Vector3.ZERO
	var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	bolt["right"] = dir.cross(up_hint).normalized()
	bolt["up"] = (bolt["right"] as Vector3).cross(dir).normalized()
	if bool(bolt.get("railgun_ricochet", false)):
		var max_boosts := clampi(int(bolt.get("railgun_max_stacks", RAILGUN_MAX_BOOSTS)), 1, RAILGUN_MAX_BOOSTS)
		var boosts := int(bolt.get("railgun_boosts", 0))
		if boosts < max_boosts:
			bolt["railgun_boosts"] = boosts + 1
			bolt["speed"] = float(bolt["speed"]) * float(bolt.get("railgun_speed_mult", 1.40))
			bolt["damage"] = float(bolt["damage"]) * float(bolt.get("railgun_damage_mult", 1.35))
			bolt["color"] = Palette.LEDGER
			bolt["railgun_boosted_last"] = true
		else:
			bolt["railgun_boosted_last"] = false
	if on_bounce.is_valid():
		on_bounce.call(bolt, at)
	return true


func _flip_boomerang(bolt: Dictionary) -> void:
	var back_dir: Vector3 = -(bolt["dir"] as Vector3)
	if back_dir.length_squared() < 1e-6:
		back_dir = Vector3.BACK
	else:
		back_dir = back_dir.normalized()
	var dmg_mult := clampf(float(bolt.get("boomerang_damage_mult", 1.0)), 1.0, BOOMERANG_MAX_DAMAGE_MULT)
	var wid_mult := clampf(float(bolt.get("boomerang_width_mult", 1.0)), 1.0, BOOMERANG_MAX_WIDTH_MULT)
	bolt["boomerang"] = false
	bolt["boomerang_returned"] = true
	bolt["boomerang_pause"] = 0.0
	bolt["dir"] = back_dir
	bolt["origin"] = bolt["shown"]
	bolt["travelled"] = 0.0
	bolt["exclude"] = []
	bolt["damage"] = float(bolt["damage"]) * dmg_mult
	bolt["width_scale"] = float(bolt.get("width_scale", 1.0)) * wid_mult
	bolt["radius"] = float(bolt["radius"]) * wid_mult
	bolt["source"] = "item_proc"
	bolt["bits"] = 0
	bolt["spent"] = 0
	bolt["chain_jumps"] = 0
	bolt["extra_bounces"] = 0
	bolt["railgun_ricochet"] = false
	bolt["railgun_boosts"] = 0
	bolt["railgun_boosted_last"] = false
	bolt["ricochet_home"] = false
	bolt["sixth_hot"] = false
	bolt["pierce"] = maxi(int(bolt.get("pierce", 0)), BOOMERANG_RETURN_PIERCE)
	bolt["wave_amp"] = 0.0
	bolt.erase("draw_origin")
	bolt["draw_offset"] = Vector3.ZERO
	var up_hint := Vector3.UP if absf(back_dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	bolt["right"] = back_dir.cross(up_hint).normalized()
	bolt["up"] = (bolt["right"] as Vector3).cross(back_dir).normalized()


static func _ricochet_curve(reflected: Vector3, origin: Vector3, snapshot: Array, exclude: Array,
		reach: float, turn: float) -> Vector3:
	var best_dir := Vector3.ZERO
	var best_d2 := reach * reach
	for entry in snapshot:
		if entry["dead"]:
			continue
		var enemy = entry["enemy"]
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		if not exclude.is_empty() and int(entry["id"]) in exclude:
			continue
		var to: Vector3 = (entry["centre"] as Vector3) - origin
		var d2 := to.length_squared()
		if d2 > 0.0001 and d2 < best_d2:
			best_d2 = d2
			best_dir = to.normalized()
	if best_dir == Vector3.ZERO:
		return reflected
	var mixed := reflected.lerp(best_dir, clampf(turn, 0.0, 1.0))
	return mixed.normalized() if mixed.length_squared() > 0.0001 else best_dir


func _position(bolt: Dictionary) -> Vector3:
	var along: Vector3 = bolt["origin"] + (bolt["dir"] as Vector3) * bolt["travelled"]
	var amp: float = bolt["wave_amp"]
	if amp <= 0.0:
		return along
	var ramp := clampf(bolt["travelled"] / WAVE_RAMP, 0.0, 1.0)
	var angle: float = TAU * bolt["wave_hz"] * bolt["age"] + bolt["phase"]
	return along + ((bolt["right"] as Vector3) * cos(angle) + (bolt["up"] as Vector3) * sin(angle)) * amp * ramp


func _first_enemy(from: Vector3, to: Vector3, bolt_radius: float, snapshot: Array, exclude := []) -> Dictionary:
	var best := {}
	var best_along := INF
	var span := from.distance_to(to)
	for entry in snapshot:
		if entry["dead"]:
			continue
		var enemy = entry["enemy"]
		if not is_instance_valid(enemy) or enemy.is_dead():
			entry["dead"] = true
			continue
		if not exclude.is_empty() and int(entry["id"]) in exclude:
			continue
		var centre: Vector3 = entry["centre"]
		if enemy.global_position.distance_squared_to(centre) > 0.0001:
			_refresh_entry(entry)
			if entry["dead"]:
				continue
			centre = entry["centre"]
		var bound_reach: float = float(entry["bound"]) + bolt_radius + span
		if centre.distance_squared_to(from) > bound_reach * bound_reach:
			continue
		for weak in entry["weak"]:
			var at: Vector3 = weak["at"]
			var near := Geometry3D.get_closest_point_to_segment(at, from, to)
			if near.distance_to(at) <= weak["radius"] + bolt_radius:
				var weak_along := from.distance_to(near) - 0.01
				if weak_along < best_along:
					best_along = weak_along
					best = {"enemy": enemy, "entry": entry, "point": near, "part": weak["id"], "along": weak_along}
		var inner: float = entry["inner"]
		var reach: float = entry["radius"] + bolt_radius
		var cap_reach := span + reach + inner + 0.5
		if centre.distance_squared_to(from) > cap_reach * cap_reach:
			continue
		var points := Geometry3D.get_closest_points_between_segments(from, to,
			centre - Vector3.UP * inner, centre + Vector3.UP * inner)
		if points[0].distance_to(points[1]) > reach:
			continue
		var along := from.distance_to(points[0])
		if along < best_along:
			best_along = along
			best = {"enemy": enemy, "entry": entry, "point": points[0], "part": "", "along": along}
	return best


func _snapshot(enemies: Array) -> Array:
	var out: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		var entry := {"enemy": enemy, "id": enemy.get_instance_id(), "dead": false}
		_refresh_entry(entry)
		if not entry["dead"]:
			out.append(entry)
	return out


func _refresh_entry(entry: Dictionary) -> void:
	var enemy = entry["enemy"]
	if not is_instance_valid(enemy) or enemy.is_dead():
		entry["dead"] = true
		return
	var centre: Vector3 = enemy.global_position
	var inner: float = maxf(0.0, enemy.half_height - enemy.radius)
	var weak_list: Array = enemy.weak_points()
	var bound: float = enemy.radius + inner + 0.5
	for weak in weak_list:
		var w_at: Vector3 = weak["at"]
		bound = maxf(bound, centre.distance_to(w_at) + float(weak["radius"]) + 0.5)
	entry["weak"] = weak_list
	entry["centre"] = centre
	entry["inner"] = inner
	entry["radius"] = enemy.radius
	entry["bound"] = bound


func _first_shell(from: Vector3, to: Vector3, bolt_radius: float, shells: Array) -> Dictionary:
	var best := {}
	var best_along := INF
	for shell in shells:
		if not is_instance_valid(shell) or shell.returned:
			continue
		var at: Vector3 = shell.global_position
		var near := Geometry3D.get_closest_point_to_segment(at, from, to)
		if near.distance_to(at) <= shell.HIT_RADIUS + bolt_radius:
			var along := from.distance_to(near)
			if along < best_along:
				best_along = along
				best = {"shell": shell, "along": along}
	return best


func _process(_delta: float) -> void:
	var count := _bolts.size()
	_multimesh.visible_instance_count = count
	if count == 0:
		return
	var alpha := crowd_alpha(count)
	var tail := Density.SHED_STREAK_SCALE if Density.live().sheds("bolt_tails") else 1.0
	for i in count:
		var drawn := instance(_bolts[i], alpha, tail)
		_multimesh.set_instance_transform(i, drawn[0])
		_multimesh.set_instance_color(i, drawn[1])


static func _draw_offset(bolt: Dictionary) -> Vector3:
	if bolt.has("draw_offset"):
		var off: Vector3 = bolt["draw_offset"]
		return off if off.is_finite() else Vector3.ZERO
	if bolt.has("draw_origin") and bolt.has("origin"):
		var off: Vector3 = (bolt["draw_origin"] as Vector3) - (bolt["origin"] as Vector3)
		return off if off.is_finite() else Vector3.ZERO
	return Vector3.ZERO


static func _merge_weight(travelled: float) -> float:
	var t := clampf(travelled / DRAW_MERGE_M, 0.0, 1.0)
	return 1.0 - t * t * (3.0 - 2.0 * t)


static func drawn_position(bolt: Dictionary) -> Vector3:
	var head: Vector3 = bolt.get("shown", bolt.get("origin", Vector3.ZERO))
	var offset := _draw_offset(bolt)
	if offset.length_squared() <= 1e-12:
		return head
	var travelled := float(bolt.get("travelled", 0.0))
	if travelled >= DRAW_MERGE_M:
		return head
	return head + offset * _merge_weight(travelled)


static func instance(bolt: Dictionary, alpha: float, tail := 1.0) -> Array:
	var dir: Vector3 = bolt["dir"]
	if dir.length_squared() < 1e-6:
		dir = Vector3.FORWARD
	else:
		dir = dir.normalized()
	var travelled := float(bolt.get("travelled", 0.0))
	var streak := minf(maxf(MIN_STREAK, float(bolt["speed"]) * STREAK_SECONDS), maxf(0.2, travelled)) * tail
	var offset := _draw_offset(bolt)
	var vis_dir := dir
	var head: Vector3 = bolt["shown"]
	if offset.length_squared() > 1e-12 and travelled < DRAW_MERGE_M:
		var t := clampf(travelled / DRAW_MERGE_M, 0.0, 1.0)
		head = head + offset * _merge_weight(travelled)
		var dw_dd := -6.0 * t * (1.0 - t) / DRAW_MERGE_M
		var tilt_scale := clampf(travelled / maxf(streak, 0.001), 0.0, 1.0)
		var tangent := dir + offset * (dw_dd * tilt_scale)
		if tangent.length_squared() > 1e-6 and tangent.dot(dir) > 0.1:
			vis_dir = tangent.normalized()
	var up_hint := Vector3.UP if absf(vis_dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	var side := width(bolt)
	var basis := Basis.looking_at(vis_dir, up_hint) * Basis.from_scale(Vector3(side, side, streak))
	return [Transform3D(basis, head - vis_dir * streak * 0.5), Color(tint(bolt), alpha)]
