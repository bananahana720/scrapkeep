extends "res://src/combat/counter.gd"

const IslandEdge := preload("res://src/combat/island_edge.gd")
const RosterHighdraft := preload("res://src/combat/roster_highdraft.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const HP := 70.0
const RIM_DROP := 4.0
const FIND_REACH := 30.0
const GAP_SPAN := 50.0
const GAP_RISE := 4.0
const NET_WIDTH := 14.0
const NET_BELOW := 9.0
const NET_ABOVE := 7.0
const NET_FLOOR := 1.2
const FLAT_TOP := 8.0
const TEAR_SPEED := 22.0
const SLING_KEEP := 0.8
const SLING_LIFT := 4.0
const DEEP_GAP := 16.0
const STACK_GAP := 6.0
const POST_HEIGHT := 4.0
const POST_FALL := 3.0
const PRIMARY_WARN := 1.0
const PRIMARY_LIVE := 3.5
const SHOCK_WARN := 0.85
const SHOCK_LIVE := 3.5
const SHOCK_DAMAGE := 6.0
const ELECTRIC_AURA_SECONDS := 3.0
const ELECTRIC_AURA_RADIUS := 5.5
const ELECTRIC_AURA_DAMAGE := 18.0
const ELECTRIC_AURA_KICK := 4.0
const CRACKLE_RATE := 5.0
const CRACKLE_RATE_GAIN := 15.0
const CRACKLE_SHAKE := 0.08


class ElectricAura extends Node3D:
	var player
	var left := 3.0
	var radius := 5.5
	var damage := 18.0
	var zaps := 0
	var _struck := {}
	var _ring: MeshInstance3D

	func setup(player_ref, duration: float, aura_radius: float, aura_damage: float) -> void:
		name = "ShockNetElectricAura"
		player = player_ref
		left = duration
		radius = aura_radius
		damage = aura_damage
		var craft := preload("res://src/presentation/world23_chunk_craft.gd")
		_ring = MeshInstance3D.new()
		_ring.mesh = craft.get_gap_net_aura_mesh(1.52)
		_ring.material_override = craft.build_electric_aura_material(Palette.ICE)
		_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ring)
		if player != null and is_instance_valid(player):
			player.set_meta("electric_aura_active", true)
			player.set_meta("electric_aura_left", left)
			global_position = player.ball_position()

	func _physics_process(delta: float) -> void:
		if player == null or not is_instance_valid(player):
			queue_free()
			return
		left -= delta
		var ball: Vector3 = player.ball_position()
		global_position = ball
		if _ring != null:
			_ring.rotate_y(delta * 5.0)
		if left <= 0.0:
			player.set_meta("electric_aura_active", false)
			player.set_meta("electric_aura_left", 0.0)
			queue_free()
			return
		player.set_meta("electric_aura_active", true)
		player.set_meta("electric_aura_left", left)
		if not is_inside_tree():
			return
		for enemy in get_tree().get_nodes_in_group(GROUP):
			if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
				continue
			var id := enemy.get_instance_id()
			if _struck.has(id):
				continue
			if enemy.global_position.distance_to(ball) <= radius:
				_struck[id] = true
				zaps += 1
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage)
				if enemy.has_method("knock"):
					var away: Vector3 = enemy.global_position - ball
					away.y = 0.0
					enemy.knock((away.normalized() if away.length() > 0.1 else Vector3.FORWARD) + Vector3.UP * 0.25, 10.0)

	func _exit_tree() -> void:
		if player != null and is_instance_valid(player):
			player.set_meta("electric_aura_active", false)
			player.set_meta("electric_aura_left", 0.0)

var slung := 0
var torn := 0
var crossings := 0
var shock_nets := 0
var shock_rips := 0
var shock_layer_active := false
var next_attack := ""
var last_shock_rip := {}
var nets: Array = []
var post_b := Vector3.INF
var gap_length := 0.0

var _strung := false
var _post_y := INF
var _mat_live: StandardMaterial3D
var _mat_slack: StandardMaterial3D
var _crackling := false
var _shock_attack := false
var _shock_extra: Dictionary = {}
static var _shared: Array = []


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	scrap_value = 5
	weight = 1.6
	walk_speed = 0.0
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	rest_seconds = 2.0
	first_rest = 0.8
	attack_range = 34.0
	interruptible = false


func _build_tool() -> void:
	_mat_live = Palette.unshaded(Color(Palette.HAZARD, 0.55))
	_mat_slack = Palette.unshaded(Color(Palette.SAND, 0.18))
	var parts := _parts()
	if not parts.is_empty():
		_crew.free()
		_crew = null
		_base_color = Color.WHITE
		_material.albedo_color = _base_color
		_material.vertex_color_use_as_albedo = true
		for part in parts:
			if part.name == "GapNetSpan":
				continue
			var mi := MeshInstance3D.new()
			mi.name = part.name
			mi.mesh = part.mesh
			mi.transform = part.xform
			if part.flash >= 0:
				mi.set_surface_override_material(part.flash, _material)
			_visual_parent().add_child(mi)
		return
	var fallback_post := MeshInstance3D.new()
	fallback_post.name = "GapNetPostFallback"
	fallback_post.mesh = preload("res://src/presentation/world23_chunk_craft.gd").get_gap_net_post_mesh(POST_HEIGHT)
	fallback_post.position = Vector3(0.0, POST_HEIGHT * 0.5 - CREW_HALF, -CREW_RADIUS - 0.3)
	_visual_parent().add_child(fallback_post)


func _physics_process(delta: float) -> void:
	if not _strung and terrain != null and world_root != null:
		_string()
	super(delta)
	if _dead:
		return
	if global_position.y < _post_y - POST_FALL:
		last_damage_source = "ring_out"
		_die()
		return
	if phase != Phase.LIVE:
		_track_sides()


func _string() -> void:
	_strung = true
	_post_y = global_position.y
	var level: float = terrain.height(global_position.x, global_position.z)
	for rim in IslandEdge.rims(terrain, global_position, FIND_REACH, RIM_DROP):
		var far := IslandEdge.far_rim(terrain, rim["at"], rim["dir"], GAP_SPAN, (rim["at"] as Vector3).y, GAP_RISE)
		if far != Vector3.INF:
			var near: Vector3 = rim["at"]
			var dir: Vector3 = rim["dir"]
			post_b = far
			gap_length = Vector2(far.x - near.x, far.z - near.z).length()
			global_position = near - dir * 1.0 + Vector3.UP * 0.2
			_post_y = near.y
			var top := maxf(near.y, far.y)
			var mid := near.lerp(far, 0.5)
			var count := 2 if RosterHighdraft.grown(self) and gap_length >= DEEP_GAP else 1
			for i in count:
				var at := mid + dir * STACK_GAP * (float(i) - (count - 1) * 0.5)
				_hang(Vector3(at.x, top, at.z), dir, top - NET_BELOW, top + NET_ABOVE)
			_build_post_b()
			return
	var facing := -global_transform.basis.z
	facing.y = 0.0
	facing = facing.normalized() if facing.length() > 0.01 else Vector3.FORWARD
	var center := global_position + facing * 3.0
	_hang(Vector3(center.x, level, center.z), facing, level + NET_FLOOR, level + FLAT_TOP)


func _hang(center: Vector3, normal: Vector3, low: float, high: float) -> void:
	var side := normal.cross(Vector3.UP).normalized()
	var mesh := Node3D.new()
	mesh.top_level = true
	add_child(mesh)
	mesh.global_transform = Transform3D(Basis(side, Vector3.UP, normal), Vector3(center.x, low, center.z))
	var tile := _span()
	if tile.is_empty():
		var flat := MeshInstance3D.new()
		flat.mesh = preload("res://src/presentation/world23_chunk_craft.gd").get_gap_net_panel_mesh(NET_WIDTH, high - low)
		flat.position = Vector3(0.0, (high - low) * 0.5, 0.0)
		mesh.add_child(flat)
	else:
		var span_box: AABB = tile["mesh"].get_aabb()
		var stretch := (high - low) / span_box.size.y
		var count := ceili(NET_WIDTH / span_box.size.x)
		for i in count:
			var piece := MeshInstance3D.new()
			piece.mesh = tile["mesh"]
			piece.transform = Transform3D(Basis.from_scale(Vector3(1.0, stretch, 1.0)),
				Vector3(-NET_WIDTH * 0.5 + span_box.size.x * i - span_box.position.x, -span_box.position.y * stretch, 0.0))
			mesh.add_child(piece)
	nets.append({"center": center, "normal": normal, "side": side, "low": low, "high": high, "live": true,
		"last": 0.0, "mesh": mesh, "origin": mesh.global_position})
	_tint(mesh, _mat_slack)


func _build_post_b() -> void:
	var post := MeshInstance3D.new()
	post.name = "GapNetPostB"
	post.mesh = preload("res://src/presentation/world23_chunk_craft.gd").get_gap_net_post_mesh(POST_HEIGHT)
	post.top_level = true
	add_child(post)
	post.global_position = post_b + Vector3.UP * POST_HEIGHT * 0.5


func _wants_attack(to_ball: Vector3) -> bool:
	return _live_nets() > 0 and _nearest_net_distance() <= attack_range


func _use_shock_net() -> bool:
	if next_attack == "shock_net":
		return true
	if next_attack == "single":
		return false
	return warned % 2 == 1


func _commit(_to_ball: Vector3) -> Node3D:
	var net := _nearest_net()
	if net.is_empty():
		return null
	var is_shock := _use_shock_net()
	_shock_attack = is_shock
	next_attack = ""
	if is_shock:
		warn_seconds = SHOCK_WARN
		live_seconds = SHOCK_LIVE
		shock_layer_active = true
		shock_nets += 1
		_deploy_shock_layer(net)
	else:
		warn_seconds = PRIMARY_WARN
		live_seconds = PRIMARY_LIVE
		shock_layer_active = false
	var from: Vector3 = net["center"] - (net["side"] as Vector3) * NET_WIDTH * 0.5
	return _commit_lane(Threat.Type.LANE, from, net["side"], NET_WIDTH, 1.2)


func _deploy_shock_layer(base_net: Dictionary) -> void:
	_clear_shock_layer()
	if nets.size() >= 2:
		return
	var offset: Vector3 = (base_net["normal"] as Vector3) * (STACK_GAP * 0.5)
	_hang((base_net["center"] as Vector3) + offset, base_net["normal"], float(base_net["low"]), float(base_net["high"]))
	_shock_extra = nets[-1]
	_shock_extra["shock_temp"] = true


func _clear_shock_layer() -> void:
	if _shock_extra.is_empty():
		return
	if is_instance_valid(_shock_extra.get("mesh")):
		(_shock_extra["mesh"] as Node).queue_free()
	nets.erase(_shock_extra)
	_shock_extra = {}


func _go_live() -> void:
	_track_sides()
	_paint(true)


func _live(_delta: float) -> bool:
	var player = _player()
	if player == null:
		return false
	var ball := _real_ball()
	for net in nets:
		if not net["live"]:
			continue
		var s := _side_of(net, ball)
		var crossed: bool = float(net["last"]) != 0.0 and signf(s) != signf(float(net["last"]))
		net["last"] = s
		if not crossed or player.state.grounded or not _in_band(net, ball):
			continue
		crossings += 1
		var v: Vector3 = player.state.velocity
		var blazing: bool = player.speed_tier() >= SpeedTier.BLAZING or v.length() >= TEAR_SPEED
		if blazing:
			if _shock_attack and player.speed_tier() >= SpeedTier.BLAZING:
				_grant_electric_aura(player, net)
				_tear_all_shock()
				return false
			_tear(net)
			continue
		var n: Vector3 = net["normal"]
		var out: Vector3 = v - n * v.dot(n) * (1.0 + SLING_KEEP)
		out.y = maxf(out.y, SLING_LIFT)
		player.set_velocity_now(out, "netted")
		net["last"] = _side_of(net, ball - n * signf(s) * 0.6)
		slung += 1
		if _shock_attack and player.speed_tier() < SpeedTier.CRUISE:
			hit_player.emit(SHOCK_DAMAGE, Vector3.ZERO)
		if fleet != null:
			fleet.discover("gap_sling", ball)
	return _live_nets() > 0


func _grant_electric_aura(player, net: Dictionary) -> void:
	shock_rips += 1
	var heading: Vector3 = player.planar_velocity()
	heading = heading.normalized() if heading.length() > 0.1 else (net["normal"] as Vector3)
	if player.has_method("set_velocity_now"):
		player.set_velocity_now(player.state.velocity + heading * ELECTRIC_AURA_KICK, "shock_rip")
	var aura := ElectricAura.new()
	if world_root != null:
		world_root.add_child(aura)
	else:
		player.add_child(aura)
	aura.setup(player, ELECTRIC_AURA_SECONDS, ELECTRIC_AURA_RADIUS, ELECTRIC_AURA_DAMAGE)
	last_shock_rip = {"at": player.ball_position(), "duration": ELECTRIC_AURA_SECONDS, "aura": aura, "frame": Engine.get_physics_frames()}
	if fleet != null:
		fleet.discover("gap_sling", player.ball_position())


func _tear_all_shock() -> void:
	for net in nets:
		if net["live"]:
			net["live"] = false
			torn += 1
			if is_instance_valid(net["mesh"]):
				net["mesh"].visible = false
	last_damage_source = "tear"
	_die()


func _on_end() -> void:
	_shock_attack = false
	shock_layer_active = false
	warn_seconds = PRIMARY_WARN
	live_seconds = PRIMARY_LIVE
	_clear_shock_layer()
	_paint(false)


func _pose() -> void:
	var charging := phase == Phase.WARN and not is_dead()
	if not charging:
		if _crackling:
			_crackling = false
			_settle()
		return
	_crackling = true
	var t := clampf(_warn_progress(), 0.0, 1.0)
	var beat := fmod(_t * FlashGuard.rate(CRACKLE_RATE + CRACKLE_RATE_GAIN * t), 1.0)
	var lit := beat < 0.2 + 0.5 * t
	var shake := sin(_t * 70.0) * CRACKLE_SHAKE * t * Comfort.motion_scale()
	for net in nets:
		if not net["live"] or not is_instance_valid(net["mesh"]):
			continue
		_tint(net["mesh"], _mat_live if lit else _mat_slack)
		net["mesh"].global_position = (net["origin"] as Vector3) + (net["normal"] as Vector3) * shake


func _settle() -> void:
	for net in nets:
		if is_instance_valid(net["mesh"]):
			net["mesh"].global_position = net["origin"]


func _tear(net: Dictionary) -> void:
	net["live"] = false
	torn += 1
	if is_instance_valid(net["mesh"]):
		net["mesh"].visible = false
	if _live_nets() == 0:
		last_damage_source = "tear"
		_die()


func _paint(live_now: bool) -> void:
	for net in nets:
		if net["live"] and is_instance_valid(net["mesh"]):
			_tint(net["mesh"], _mat_live if live_now else _mat_slack)


func _tint(mesh: Node3D, material: Material) -> void:
	for piece in mesh.get_children():
		(piece as MeshInstance3D).material_override = material


func _side_of(net: Dictionary, at: Vector3) -> float:
	return (at - (net["center"] as Vector3)).dot(net["normal"])


func _in_band(net: Dictionary, at: Vector3) -> bool:
	var lateral := absf((at - (net["center"] as Vector3)).dot(net["side"]))
	return lateral <= NET_WIDTH * 0.5 and at.y >= float(net["low"]) and at.y <= float(net["high"])


func _track_sides() -> void:
	if target == null:
		return
	var ball := _real_ball()
	for net in nets:
		net["last"] = _side_of(net, ball)


func _live_nets() -> int:
	var count := 0
	for net in nets:
		if net["live"]:
			count += 1
	return count


func _nearest_net() -> Dictionary:
	var best := {}
	var best_d := INF
	var ball := _ball()
	for net in nets:
		if not net["live"]:
			continue
		var d := ball.distance_to(net["center"])
		if d < best_d:
			best_d = d
			best = net
	return best


func _nearest_net_distance() -> float:
	var net := _nearest_net()
	return INF if net.is_empty() else _ball().distance_to(net["center"])


static func _span() -> Dictionary:
	for part in _parts():
		if part.name == "GapNetSpan":
			return part
	return {}


static func _parts() -> Array:
	if _shared.is_empty():
		_shared = EnemyCasting.parts("res://assets/models/world_three/enemy_gap_net_curtain.glb", "gap_net")
	return _shared


func _roam(_to_ball: Vector3) -> Vector3:
	return Vector3.ZERO
