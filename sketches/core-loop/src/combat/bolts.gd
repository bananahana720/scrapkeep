extends Node3D

# Every live player projectile, as data, drawn with one MultiMesh. Combat fires bolts
# in here and steps them once per physics tick; a hit is reported back through
# `on_hit`, which resolves it once through the spawner's strike (TADR-008).
#
# The visual-clarity rules (principle 4) live here:
# - At most MAX_LIVE bolts exist. A new bolt past the cap retires the oldest, which is
#   the one furthest out and least likely to matter, so held fire never stalls.
# - The more bolts are live, the fainter each one draws (crowd_alpha), so a stacked
#   spiral-and-cross build thickens into a haze, never a wall.
# - Bolts draw at PRIORITY, below every enemy telegraph (Telegraph.PRIORITY), and never
#   in HAZARD, the colour telegraphs own.

const Density := preload("res://src/presentation/density.gd")
const ShotBits := preload("res://src/build/shot_bits.gd")

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

# Called as on_hit.call(bolt: Dictionary, enemy: Node3D, point: Vector3, part: String);
# part is a weak point id from enemy.weak_points(), or "" for the body.
var on_hit: Callable
# Called as on_shell.call(bolt: Dictionary, shell: Node3D) when a bolt reaches a shell in flight.
var on_shell: Callable
# Called as on_stop.call(point: Vector3, color: Color) when a bolt hits the world.
var on_stop: Callable
var peak_live := 0
var retired := 0
var fired := 0

var _bolts: Array = []
var _multimesh: MultiMesh


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
	# The tints are the palette's sRGB values, written by code: without this the PC's renderer read
	# them as linear light and drew every bolt a pale cream (sight's colour probe, 10 Nov 2026: the
	# bolts were most of what the switch moved, cream 190,184,157 to 176,162,113), a pale burst
	# that hid three kinds' deaths on the PC reel. The cloud's renderer ignores the switch.
	mat.vertex_color_is_srgb = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = PRIORITY
	view.material_override = mat
	# The pool is drawn in world space from the bolt records; it never moves itself.
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
	_multimesh.visible_instance_count = 0


# bolt needs: origin, dir, speed, max_dist, damage, kind, weapon_id, radius, knock,
# chain_jumps, chain_range, chain_falloff, color, wave_amp, wave_hz, phase; bits, the
# shot's ShotBits set, is optional and defaults to the empty set, and so is spent, the bits
# already used up (the pierce bit after its one pass).
func fire(bolt: Dictionary) -> void:
	if not bolt.has("bits"):
		bolt["bits"] = 0
	if not bolt.has("spent"):
		bolt["spent"] = 0
	if _bolts.size() >= MAX_LIVE:
		_bolts.pop_front()
		retired += 1
	var dir: Vector3 = bolt["dir"]
	var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
	bolt["right"] = dir.cross(up_hint).normalized()
	bolt["up"] = (bolt["right"] as Vector3).cross(dir).normalized()
	bolt["travelled"] = 0.0
	bolt["age"] = 0.0
	bolt["shown"] = bolt["origin"]
	bolt["pierce"] = int(bolt.get("pierce", 0))
	bolt["exclude"] = []
	_bolts.append(bolt)
	fired += 1
	peak_live = maxi(peak_live, _bolts.size())


# A child bolt (a split, a chain jump) from its parent: the parent's record with the
# overrides applied and its flight restarted, and always the parent's ShotBits set and the
# bits it has spent, so a child can neither gain a bit nor use one twice (SI4).
static func child(parent: Dictionary, overrides: Dictionary) -> Dictionary:
	var out := parent.duplicate()
	for key in ["travelled", "age", "shown", "right", "up", "exclude"]:
		out.erase(key)
	for key in overrides:
		out[key] = overrides[key]
	out["bits"] = ShotBits.union(0, int(parent.get("bits", 0)))
	out["spent"] = ShotBits.union(0, int(parent.get("spent", 0)))
	return out


# How many more machines the bolt passes through: its pattern pierce plus one while it holds
# the pierce bit unspent (ABILITY-MUTATIONS.md B3), so the two add.
static func passes_left(bolt: Dictionary) -> int:
	return int(bolt.get("pierce", 0)) + (1 if _pierce_bit_ready(bolt) else 0)


static func _pierce_bit_ready(bolt: Dictionary) -> bool:
	var pierce := ShotBits.bit("pierce")
	return ShotBits.has(int(bolt.get("bits", 0)), pierce) and not ShotBits.has(int(bolt.get("spent", 0)), pierce)


func step(delta: float, space: PhysicsDirectSpaceState3D, enemies: Array, shells: Array = []) -> void:
	var survivors: Array = []
	# The enemies' reach, built once and rebuilt after any hit callback (which can kill or move one).
	var snapshot: Array = []
	var fresh := false
	for bolt in _bolts:
		if not fresh:
			snapshot = _snapshot(enemies)
			fresh = true
		var from: Vector3 = bolt["shown"]
		bolt["age"] += delta
		bolt["travelled"] = minf(bolt["travelled"] + bolt["speed"] * delta, bolt["max_dist"])
		var to := _position(bolt)
		var end := to
		var blocked := false
		if from.distance_squared_to(to) > 0.000001:
			var wall := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, WORLD_MASK))
			if not wall.is_empty():
				end = wall["position"]
				blocked = true
		var target := _first_enemy(from, end, bolt["radius"], snapshot, bolt["exclude"])
		var shell := _first_shell(from, end, bolt["radius"], shells)
		if not shell.is_empty() and (target.is_empty() or shell["along"] < target["along"]):
			fresh = false
			if on_shell.is_valid() and on_shell.call(bolt, shell["shell"]):
				continue
		var stopped := false
		while not target.is_empty():
			fresh = false
			var hit_id: int = target["enemy"].get_instance_id()
			if on_hit.is_valid():
				on_hit.call(bolt, target["enemy"], target["point"], target["part"])
			# A piercing bolt passes through: it keeps its line and corkscrew phase and
			# looks for the next machine further along the same segment. The pattern's
			# pierce goes first, then the pierce bit's one pass, which it then spends.
			if bolt["pierce"] > 0:
				bolt["pierce"] -= 1
			elif _pierce_bit_ready(bolt):
				bolt["spent"] = ShotBits.union(int(bolt["spent"]), ShotBits.bit("pierce"))
			else:
				stopped = true
				break
			(bolt["exclude"] as Array).append(hit_id)
			snapshot = _snapshot(enemies)
			fresh = true
			target = _first_enemy(from, end, bolt["radius"], snapshot, bolt["exclude"])
		if stopped:
			continue
		if blocked:
			fresh = false
			if on_stop.is_valid():
				on_stop.call(end, bolt["color"])
			continue
		if bolt["travelled"] >= bolt["max_dist"]:
			continue
		bolt["shown"] = to
		survivors.append(bolt)
	_bolts = survivors


# Where the bolt is now: along its line, plus the corkscrew for a waving bolt. The
# corkscrew ramps in over the first metres so every bolt leaves the muzzle on its line.
func _position(bolt: Dictionary) -> Vector3:
	var along: Vector3 = bolt["origin"] + (bolt["dir"] as Vector3) * bolt["travelled"]
	var amp: float = bolt["wave_amp"]
	if amp <= 0.0:
		return along
	var ramp := clampf(bolt["travelled"] / WAVE_RAMP, 0.0, 1.0)
	var angle: float = TAU * bolt["wave_hz"] * bolt["age"] + bolt["phase"]
	return along + ((bolt["right"] as Vector3) * cos(angle) + (bolt["up"] as Vector3) * sin(angle)) * amp * ramp


# The first enemy the segment passes within reach of, measured against each enemy's
# weak-point spheres first and then its upright capsule (its axis, widened by its
# radius and the bolt's). A weak point wins a tie with the body it sits on.
func _first_enemy(from: Vector3, to: Vector3, bolt_radius: float, snapshot: Array, exclude := []) -> Dictionary:
	var best := {}
	var best_along := INF
	var span := from.distance_to(to)
	for entry in snapshot:
		var enemy = entry["enemy"]
		if not exclude.is_empty() and enemy.get_instance_id() in exclude:
			continue
		for weak in entry["weak"]:
			var at: Vector3 = weak["at"]
			var near := Geometry3D.get_closest_point_to_segment(at, from, to)
			if near.distance_to(at) <= weak["radius"] + bolt_radius:
				var weak_along := from.distance_to(near) - 0.01
				if weak_along < best_along:
					best_along = weak_along
					best = {"enemy": enemy, "point": near, "part": weak["id"], "along": weak_along}
		var centre: Vector3 = entry["centre"]
		var inner: float = entry["inner"]
		var reach: float = entry["radius"] + bolt_radius
		if centre.distance_to(from) > span + reach + inner + 0.5:
			continue
		var points := Geometry3D.get_closest_points_between_segments(from, to,
			centre - Vector3.UP * inner, centre + Vector3.UP * inner)
		if points[0].distance_to(points[1]) > reach:
			continue
		var along := from.distance_to(points[0])
		if along < best_along:
			best_along = along
			best = {"enemy": enemy, "point": points[0], "part": "", "along": along}
	return best


# What _first_enemy reads of each live enemy, read once for a run of bolts.
func _snapshot(enemies: Array) -> Array:
	var out: Array = []
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.is_dead():
			continue
		out.append({"enemy": enemy, "weak": enemy.weak_points(), "centre": enemy.global_position,
			"inner": maxf(0.0, enemy.half_height - enemy.radius), "radius": enemy.radius})
	return out


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


static func drawn_width(bolt: Dictionary) -> float:
	return WIDTH * float(bolt.get("width_scale", 1.0))


func _process(_delta: float) -> void:
	var count := _bolts.size()
	_multimesh.visible_instance_count = count
	if count == 0:
		return
	var alpha := crowd_alpha(count)
	var tail := Density.SHED_STREAK_SCALE if Density.live().sheds("bolt_tails") else 1.0
	for i in count:
		var bolt: Dictionary = _bolts[i]
		var dir: Vector3 = bolt["dir"]
		var streak := minf(maxf(MIN_STREAK, bolt["speed"] * STREAK_SECONDS), maxf(0.2, bolt["travelled"])) * tail
		var up_hint := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.98 else Vector3.FORWARD
		var w := drawn_width(bolt)
		var basis := Basis.looking_at(dir, up_hint) * Basis.from_scale(Vector3(w, w, streak))
		var head: Vector3 = bolt["shown"]
		_multimesh.set_instance_transform(i, Transform3D(basis, head - dir * streak * 0.5))
		var tint: Color = bolt["color"]
		_multimesh.set_instance_color(i, Color(tint, alpha))
