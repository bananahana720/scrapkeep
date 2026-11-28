extends "res://src/combat/counter.gd"

const RubbleFall := preload("res://src/world/events/rubble_fall.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const DamageDoor := preload("res://src/combat/damage_door.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const SpeedTier := preload("res://src/core/speed_tier.gd")

const HP := 60.0
const BODY_PATH := "res://assets/models/world_two/enemy_prop_crew.glb"
const ROOF_RADIUS := 3.3
const ROOF_HEIGHT := 3.3
const CANOPY_CENTRE := Vector3(0.0, 0.0, -1.3)
const ROOF_WARN := 1.0
const ROOF_DAMAGE := 120.0
const ROOF_BALL_DAMAGE := 12.0
const ROOF_SHOVE := Vector3(0.0, 4.0, 0.0)
const GATHER_M := 22.0
const SETTLE_M := 2.5
const WALK := 3.4
const PROP_OFFSET := Vector3(0.75, 0.0, 0.35)

const JACK_RANGE := 11.0
const JACK_RADIUS := 5.5
const JACK_WARN := 0.85
const JACK_LIVE := 0.30
const JACK_REST := 3.5
const JACK_DAMAGE := 9.0
const JACK_POP := 6.0
const JACK_SHOVE := 4.0
const STALL_TRIGGER_S := 0.35
const WALL_RAM_COLLAPSE_MULT := 2.0
const WALL_RAM_RADIUS_MULT := 1.35

static var _shared := {}

var prop_up := true
var drops := 0
var jack_hammers := 0
var wall_ram_collapses := 0
var last_collapse_mult := 1.0
var jack_primed := false
var last_fall: Node3D
var _threat := 1.0
var _stall_s := 0.0
var _prop: Node3D
var _roof: Node3D
var _prop_from_glb := false


func _configure(threat: float) -> void:
	_threat = threat
	_set_health(HP * threat)
	scrap_value = 5
	weight = 1.3
	walk_speed = WALK
	keep_near = 6.0
	keep_far = 16.0
	attack_range = 0.0
	warn_seconds = ROOF_WARN
	interruptible = false


func _build_tool() -> void:
	var presence := FoleyAudio.player("prop_crew_presence", self)
	if presence != null:
		presence.autoplay = true
	var parts := _parts()
	if not parts.is_empty():
		_build_body(parts)
		return
	_prop = _cylinder(0.22, ROOF_HEIGHT, Palette.SANDSTONE, PROP_OFFSET + Vector3(0.0, ROOF_HEIGHT * 0.5 - CREW_HALF, 0.0))
	_roof = _build_roof()
	add_child(_roof)


func _build_body(parts: Dictionary) -> void:
	_crew.free()
	_crew = null
	_base_color = Color.WHITE
	_material.albedo_color = _base_color
	_material.vertex_color_use_as_albedo = true
	var centre: Vector3 = parts.sockets.get("canopy_centre", CANOPY_CENTRE - Vector3(0.0, CREW_HALF, 0.0))
	_roof = Node3D.new()
	_roof.name = "ShoredRoof"
	_roof.position = Vector3(centre.x, centre.y + ROOF_HEIGHT, centre.z)
	add_child(_roof)
	for part in parts.meshes:
		var mi := MeshInstance3D.new()
		mi.name = part.name
		mi.mesh = part.mesh
		mi.transform = part.xform
		if part.flash >= 0:
			mi.set_surface_override_material(part.flash, _material)
		if part.name == "PropCanopy":
			mi.transform.origin -= _roof.position
			_roof.add_child(mi)
			continue
		_visual_parent().add_child(mi)
		if part.name == "PropShore":
			_prop = mi
			_prop_from_glb = true


static func _parts() -> Dictionary:
	if not _shared.is_empty() or not ResourceLoader.exists(BODY_PATH):
		return _shared
	var packed := load(BODY_PATH) as PackedScene
	if packed == null:
		return _shared
	var scene := packed.instantiate()
	var meshes := []
	var sockets := {}
	for node in scene.find_children("*", "Node3D", true, false):
		var at: Transform3D = _local_to(scene, node)
		if node is MeshInstance3D:
			var mesh: Mesh = node.mesh.duplicate()
			var flash := -1
			for i in mesh.get_surface_count():
				var surface_material := mesh.surface_get_material(i)
				var slot := surface_material.resource_name if surface_material != null else ""
				if slot == "fleet_paint":
					flash = i
				var painted := PaletteMaterials.solid(Color.WHITE)
				painted.vertex_color_use_as_albedo = true
				painted.metallic = 0.45 if slot == "working_tool" else 0.0
				painted.roughness = 0.5 if slot == "working_tool" else (0.9 if slot == "part_state" else 0.82)
				mesh.surface_set_material(i, painted)
			meshes.append({"name": String(node.name), "mesh": mesh, "xform": at, "flash": flash})
		elif String(node.name) in ["canopy_centre", "prop_hit", "crew_head"]:
			sockets[String(node.name)] = at.origin
	scene.free()
	_shared = {"meshes": meshes, "sockets": sockets}
	return _shared


static func _local_to(root_node: Node, node: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var walk: Node = node
	while walk != null and walk != root_node:
		if walk is Node3D:
			xf = walk.transform * xf
		walk = walk.get_parent()
	return xf


func _build_roof() -> Node3D:
	var roof := Node3D.new()
	roof.name = "ShoredRoof"
	roof.position = CANOPY_CENTRE + Vector3(0.0, ROOF_HEIGHT - CREW_HALF, 0.0)
	var span := ROOF_RADIUS * 1.6
	for side in [-1.0, 1.0]:
		_box(Vector3(span, 0.3, 0.4), Palette.SANDSTONE.darkened(0.2), Vector3(0.0, 0.0, side * span * 0.5), 0.0, roof)
		_box(Vector3(0.4, 0.3, span), Palette.SANDSTONE.darkened(0.2), Vector3(side * span * 0.5, 0.0, 0.0), 0.0, roof)
	_box(Vector3(span * 0.7, 0.12, span * 0.7), Palette.SLATE.darkened(0.35), Vector3(0.0, 0.18, 0.0), 0.0, roof)
	for i in 3:
		_box(Vector3(span * 0.6, 0.02, 0.08), Palette.HAZARD, Vector3(0.0, 0.25, (i - 1) * span * 0.2), 0.6, roof)
	return roof


func _wants_attack(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not FloorRule.on_floor(player.state) or player.speed_tier() >= SpeedTier.CRUISE:
		return false
	if to_ball.length() > JACK_RANGE:
		return false
	return jack_primed or _stall_s >= STALL_TRIGGER_S


func _commit(_to_ball: Vector3) -> Node3D:
	jack_primed = false
	_stall_s = 0.0
	warn_seconds = JACK_WARN
	live_seconds = JACK_LIVE
	rest_seconds = JACK_REST
	return _commit_ring(Threat.Type.INSTANT, global_position, JACK_RADIUS, 2.5)


func _go_live() -> void:
	jack_hammers += 1
	var ring := telegraph()
	if ring == null:
		return
	var player = _player()
	var ball := _real_ball()
	if player == null or not FloorRule.on_floor(player.state) or player.speed_tier() >= SpeedTier.CRUISE:
		return
	if ring.contains(ball):
		var out: Vector3 = ball - ring.center
		out.y = 0.0
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(JACK_DAMAGE, dir * JACK_SHOVE + Vector3.UP * JACK_POP)


func _on_end() -> void:
	warn_seconds = ROOF_WARN


func _roam(to_ball: Vector3) -> Vector3:
	var dt := get_physics_process_delta_time()
	var player = _player()
	if player != null and FloorRule.on_floor(player.state) and player.speed_tier() < SpeedTier.CRUISE and to_ball.length() <= JACK_RANGE:
		_stall_s += dt
	else:
		_stall_s = maxf(0.0, _stall_s - dt * 2.0)
	if not prop_up:
		return super._roam(to_ball)
	var mates := pack_centre()
	if mates == Vector3.INF:
		return super._roam(to_ball)
	var to := mates - roof_centre()
	to.y = 0.0
	if to.length() <= SETTLE_M:
		return Vector3.ZERO
	return to.normalized() * walk_speed


func pack_centre() -> Vector3:
	if not is_inside_tree():
		return Vector3.INF
	var sum := Vector3.ZERO
	var count := 0
	for enemy in get_tree().get_nodes_in_group(GROUP):
		if enemy == self or DamageDoor.dead(enemy):
			continue
		if String(enemy.get("kind")) == kind:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= GATHER_M:
			sum += enemy.global_position
			count += 1
	return sum / count if count > 0 else Vector3.INF


func roof_centre() -> Vector3:
	return _roof.global_position if _roof != null and _roof.is_inside_tree() else global_position


func _is_wall_ram(kind_hit: String) -> bool:
	if kind_hit != "ram":
		return false
	if phase == Phase.WARN or phase == Phase.LIVE:
		return true
	var player = _player()
	if player == null:
		return false
	if not FloorRule.on_floor(player.state):
		return true
	return player.speed_tier() >= SpeedTier.FAST


func on_struck(kind_hit: String, _part: String, _result: Dictionary) -> void:
	if kind_hit in ["ram", "stomp", "slam"]:
		var mult := WALL_RAM_COLLAPSE_MULT if _is_wall_ram(kind_hit) else 1.0
		if phase == Phase.WARN or phase == Phase.LIVE:
			_end()
		knock_prop(mult)


func knock_prop(collapse_mult := 1.0) -> Node3D:
	if not prop_up or world_root == null or not is_instance_valid(_roof):
		return null
	prop_up = false
	drops += 1
	last_collapse_mult = maxf(1.0, collapse_mult)
	if last_collapse_mult > 1.0:
		wall_ram_collapses += 1
	var at := roof_centre()
	var ground_y: float = terrain.height(at.x, at.z) if terrain != null else at.y - ROOF_HEIGHT
	var slab := _roof
	var turn := slab.global_basis if slab.is_inside_tree() else Basis.IDENTITY
	slab.get_parent().remove_child(slab)
	slab.position = at
	slab.basis = turn
	if _prop != null:
		if _prop_from_glb:
			_prop.rotation.x = PI * 0.4
		else:
			_prop.rotation.z = PI * 0.4
	var fall = RubbleFall.new()
	var ball_hit := Callable()
	if fleet != null and fleet.combat != null:
		ball_hit = Callable(fleet.combat, "_on_player_hit").bind(ROOF_BALL_DAMAGE, ROOF_SHOVE, kind)
	var fall_key := "prop_roof_%d" % get_instance_id()
	var drop_radius := ROOF_RADIUS * (WALL_RAM_RADIUS_MULT if last_collapse_mult > 1.0 else 1.0)
	fall.configure(fall_key, Vector3(at.x, ground_y, at.z), drop_radius, ROOF_WARN,
		terrain,
		_player(), ball_hit, ROOF_DAMAGE * _threat * last_collapse_mult, slab)
	fall.voice = Roster.voiced(String(Roster.faction(faction)["voice"]), _motif())
	fall.tag = String(row.get("tag", ""))
	fall.on_crush = _crush_discovery(fleet)
	fall.warn_sound = "prop_crew_strain"
	fall.land_sound = "prop_crew_collapse"
	fall.land_lead = FoleyAudio.COLLAPSE_LAND
	fall.spare_id = get_instance_id()
	world_root.add_child(fall)
	slab.global_position = at
	last_fall = fall
	_roof = null
	return fall


static func _crush_discovery(fleet_ref) -> Callable:
	return func(at: Vector3) -> void:
		if fleet_ref != null and is_instance_valid(fleet_ref):
			fleet_ref.discover("roof_drop", at)
