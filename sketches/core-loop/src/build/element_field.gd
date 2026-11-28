extends Node3D

const Elements := preload("res://src/build/elements.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const ICE_BLINK_HZ := 28.0 / TAU


signal resolved(result: Dictionary)
signal fused(result: Dictionary)
signal extended_fused(result: Dictionary)
signal shard_cone(cone: Dictionary)

const FROST := Color("e9f8ff")
const HEAT := Color("ff7a29")
const STEAM := Color("e8edf2")
const ELEMENT_COLOURS := {"arc": Palette.ARC, "frost": FROST, "kinetic": Palette.COPPER, "heat": HEAT}
const REACH := 4.5
const MAX_SLABS := 64
const MAX_ZONES := 6
const MAX_STEAM_CLOUDS := 6
const MAX_PUFFS := 40
const MAX_SHARDS := 64
const BALL_CLEARANCE := 0.06
const SHARDS_PER_SLAB := 8
const SHARD_SECONDS := 0.45
const PUFF_SECONDS := 0.4
const MAX_ZAPS := 12
const ZAP_SECONDS := 0.12
const SHARD_CONE_LENGTH := 7.0
const SHARD_CONE_DEG := 28.0
const CROSS_HEIGHT := 2.5
const CONE_HEIGHT := 3.0
const STAND_GAP := 1.0
const EVOLUTION_STRIKE := "synergy"

var ctx
var shatter_scale := 1.0

var _providers := {}
var _slabs: Array[Dictionary] = []
var _zones: Array[Dictionary] = []
var _steam_clouds: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _zaps: Array[Dictionary] = []
var _shard_mesh: BoxMesh
var _puff_mesh: SphereMesh
var _shard_material: StandardMaterial3D
var _puff_material: StandardMaterial3D
var _cone_meshes: Dictionary = {}
var _ring_mesh: TorusMesh
var _unshaded_cache: Dictionary = {}
var _flicker := 0.0
var _clock := 0.0
var _statuses := {}
var _fusions: Array[Dictionary] = []
var _held := {}
var _preview_mesh: ArrayMesh
var _next_slab := 0


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	_shard_mesh = BoxMesh.new()
	_shard_mesh.size = Vector3(0.35, 0.35, 0.9)
	_shard_material = PaletteMaterials.solid(Palette.ICE, 2.2)
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.45
	_puff_mesh.height = 0.9
	_puff_material = PaletteMaterials.unshaded(Color(FROST.r, FROST.g, FROST.b, 0.7))
	if ctx != null and ctx.events != null:
		ctx.events.enemy_struck.connect(_on_enemy_struck)


func register_material(material_id: String, provider: Callable) -> void:
	var list: Array = _providers.get(material_id, [])
	list.append(provider)
	_providers[material_id] = list


func clear_providers() -> void:
	_providers.clear()


func clear() -> void:
	for slab in _slabs:
		if is_instance_valid(slab["body"]):
			slab["body"].queue_free()
	_slabs.clear()
	for zone in _zones:
		if is_instance_valid(zone["node"]):
			zone["node"].queue_free()
	_zones.clear()
	for cloud in _steam_clouds:
		if is_instance_valid(cloud["node"]):
			cloud["node"].queue_free()
	_steam_clouds.clear()
	for list in [_shards, _puffs, _zaps]:
		for fx in list:
			if is_instance_valid(fx["node"]):
				fx["node"].queue_free()
		list.clear()
	_statuses.clear()
	for fusion in _fusions:
		if is_instance_valid(fusion["preview"]):
			fusion["preview"].queue_free()
	_fusions.clear()
	for id in _held.keys():
		_release(id)


func slab_count() -> int:
	return _slabs.size()


func zone_count() -> int:
	return _zones.size()


func steam_cloud_count() -> int:
	return _steam_clouds.size()


func steam_clouds() -> Array[Dictionary]:
	return _steam_clouds


func slabs() -> Array[Dictionary]:
	return _slabs


func material_at(point: Vector3, reach := REACH) -> Dictionary:
	for slab in _slabs:
		var at: Vector3 = slab["at"]
		if Vector2(point.x - at.x, point.z - at.z).length() <= slab["radius"] \
				and point.y <= slab["top"] + reach and point.y >= slab["top"] - slab["thickness"] - 1.0:
			return {"material": "ice", "surface_y": slab["top"], "slab": slab}
	for material_id in _providers:
		for provider in _providers[material_id]:
			if not (provider as Callable).is_valid():
				continue
			var hit: Dictionary = provider.call(point)
			if hit.has("surface_y") and point.y <= float(hit["surface_y"]) + reach:
				return {"material": material_id, "surface_y": float(hit["surface_y"])}
	if ctx != null and ctx.terrain != null and ctx.terrain.has_method("material_at"):
		var found: Dictionary = ctx.terrain.material_at(point)
		if found.has("material") and found.has("surface_y") and point.y <= float(found["surface_y"]) + reach:
			return {"material": String(found["material"]), "surface_y": float(found["surface_y"])}
	return {}


func apply(element_id: String, at: Vector3, source := "") -> Dictionary:
	if element_id in Elements.TOUCH_ELEMENTS_W50:
		_touch_near(element_id, at, Elements.TOUCH_RADIUS)
	return _resolve(element_id, at, source)


func _steam_cloud_at(point: Vector3, reach := REACH) -> int:
	var best := -1
	var best_dist := INF
	for i in _steam_clouds.size():
		var cloud: Dictionary = _steam_clouds[i]
		var at: Vector3 = cloud["at"]
		var d := Vector2(point.x - at.x, point.z - at.z).length()
		if d <= float(cloud["radius"]) and point.y >= at.y - 2.0 and point.y <= at.y + reach + 4.0 and d < best_dist:
			best = i
			best_dist = d
	return best


func _remove_steam_cloud(index: int) -> Dictionary:
	var cloud: Dictionary = _steam_clouds[index]
	_steam_clouds.remove_at(index)
	if is_instance_valid(cloud["node"]):
		cloud["node"].queue_free()
	return cloud


func _resolve(element_id: String, at: Vector3, source: String) -> Dictionary:
	var cloud_idx := _steam_cloud_at(at)
	if cloud_idx >= 0:
		var steam_row := Elements.resolve(element_id, "steam")
		if not steam_row.is_empty():
			var cloud_at: Vector3 = _steam_clouds[cloud_idx]["at"]
			var steam_result := {
				"element": element_id,
				"material": "steam",
				"behaviour": steam_row["behaviour"],
				"key": Elements.key(element_id, "steam"),
				"at": cloud_at,
				"source": source,
			}
			match steam_row["behaviour"]:
				"storm_pulse":
					_storm_pulse(cloud_idx, steam_row, steam_result)
				"flash_condense":
					_flash_condense(cloud_idx, steam_row, steam_result)
			resolved.emit(steam_result)
			return steam_result
	var hit := material_at(at)
	if hit.is_empty():
		return {}
	var row := Elements.resolve(element_id, hit["material"])
	if row.is_empty():
		return {}
	var result := {
		"element": element_id,
		"material": hit["material"],
		"behaviour": row["behaviour"],
		"key": Elements.key(element_id, hit["material"]),
		"at": Vector3(at.x, hit["surface_y"], at.z),
		"source": source,
	}
	match row["behaviour"]:
		"create_surface":
			_create_surface(Elements.SURFACES[row["surface"]], result)
		"electrify":
			_electrify(row, result)
		"shatter":
			_shatter(row, result)
		"steam_cloud":
			_steam_cloud(row, result)
		"flash_melt":
			_flash_melt(row, result)
	resolved.emit(result)
	return result


func _create_surface(surface: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	var radius: float = surface["radius"]
	var thickness: float = surface["thickness"]
	var top: float = at.y
	if ctx != null and ctx.player != null:
		var ball: Vector3 = ctx.player.ball_position()
		var bottom := ball.y - Tuning.RADIUS
		if Vector2(ball.x - at.x, ball.z - at.z).length() < radius + Tuning.RADIUS and bottom < top + BALL_CLEARANCE and bottom > top - thickness - 2.0 * Tuning.RADIUS:
			top = bottom - BALL_CLEARANCE
	while _slabs.size() >= MAX_SLABS:
		_remove_slab(0, false)
	var body := StaticBody3D.new()
	body.name = "Ice"
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(1, true)
	body.add_to_group("created_surface")
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = thickness
	shape.shape = cylinder
	body.add_child(shape)
	var mesh := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius
	disc.bottom_radius = radius
	disc.height = thickness
	disc.radial_segments = 6
	mesh.mesh = disc
	var mat := PaletteMaterials.solid(Palette.ICE, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(Palette.ICE.r, Palette.ICE.g, Palette.ICE.b, 0.85)
	mat.roughness = 0.15
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	body.global_position = Vector3(at.x, top - thickness * 0.5, at.z)
	result["top"] = top
	result["body"] = body
	_next_slab += 1
	var slab := {
		"id": _next_slab, "body": body, "material": mat, "at": Vector3(at.x, top, at.z), "top": top,
		"radius": radius, "thickness": thickness, "left": surface["seconds"], "fade": surface["fade"],
	}
	_slabs.append(slab)
	result["slab"] = slab


func _electrify(row: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	for zone in _zones:
		if (zone["at"] as Vector3).distance_to(at) < row["radius"] * 0.5:
			zone["left"] = row["seconds"]
			result["zone"] = zone
			return
	while _zones.size() >= MAX_ZONES:
		var old: Dictionary = _zones.pop_front()
		if is_instance_valid(old["node"]):
			old["node"].queue_free()
	var node := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = row["radius"]
	disc.bottom_radius = row["radius"]
	disc.height = 0.1
	disc.radial_segments = 12
	node.mesh = disc
	node.material_override = PaletteMaterials.unshaded(Color(Palette.ARC.r, Palette.ARC.g, Palette.ARC.b, 0.45))
	add_child(node)
	node.global_position = at + Vector3.UP * 0.08
	var zone := {
		"at": at, "surface_y": at.y, "radius": row["radius"], "left": row["seconds"],
		"interval": row["interval"], "clock": 0.0, "damage": row["damage"], "node": node, "hits": 0,
	}
	_zones.append(zone)
	result["zone"] = zone


func _shatter(row: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	var shattered: Array[Vector3] = []
	var i := _slabs.size() - 1
	while i >= 0:
		var slab_at: Vector3 = _slabs[i]["at"]
		if Vector2(slab_at.x - at.x, slab_at.z - at.z).length() <= row["radius"]:
			shattered.append(slab_at)
			_remove_slab(i, true)
		i -= 1
	var struck := 0
	if ctx != null and ctx.spawner != null and not shattered.is_empty():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			for spot in shattered:
				if (enemy as Node3D).global_position.distance_to(spot) <= row["radius"]:
					ctx.spawner.strike(enemy, "arc", row["damage"] * shatter_scale)
					struck += 1
					break
	result["shattered"] = shattered.size()
	result["struck"] = struck


func _steam_cloud(row: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	var radius: float = float(row["radius"])
	var seconds: float = float(row["seconds"])
	var updraft: float = float(row["updraft"])
	var damage: float = float(row["damage"])
	while _steam_clouds.size() >= MAX_STEAM_CLOUDS:
		_remove_steam_cloud(0)
	var node := MeshInstance3D.new()
	node.name = "SteamCloud"
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 0.25
	cyl.radial_segments = 16
	node.mesh = cyl
	node.material_override = _unshaded_material(Color(STEAM.r, STEAM.g, STEAM.b, 0.45))
	add_child(node)
	node.global_position = at + Vector3.UP * 0.2
	flash_ring(at + Vector3.UP * 0.12, radius, HEAT.lerp(STEAM, 0.5))
	var struck := 0
	if is_inside_tree():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			var p: Vector3 = (enemy as Node3D).global_position
			if Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) <= REACH + 1.5:
				if _evolution_strike(enemy, damage, "item_proc"):
					struck += 1
	var cloud := {
		"at": at, "radius": radius, "left": seconds, "updraft": updraft,
		"node": node, "lifts": 0,
	}
	_steam_clouds.append(cloud)
	result["cloud"] = cloud
	result["radius"] = radius
	result["updraft"] = updraft
	result["struck"] = struck
	result["source"] = "item_proc"


func _storm_pulse(cloud_idx: int, row: Dictionary, result: Dictionary) -> void:
	var cloud := _remove_steam_cloud(cloud_idx)
	var at: Vector3 = cloud["at"]
	var radius: float = float(cloud["radius"])
	var damage: float = float(row["damage"])
	flash_ring(at + Vector3.UP * 0.25, radius, Palette.ARC.lerp(STEAM, 0.35))
	var struck := 0
	if is_inside_tree():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			var node := enemy as Node3D
			if not is_instance_valid(node) or (node.has_method("is_dead") and node.is_dead()):
				continue
			var p: Vector3 = node.global_position
			if Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) <= REACH + 4.0:
				if _evolution_strike(node, damage, "item_proc"):
					struck += 1
				zap_line(at + Vector3.UP * 0.6, p + Vector3.UP * 0.6)
				touch(node, "arc")
	result["radius"] = radius
	result["struck"] = struck
	result["discharged"] = true
	result["source"] = "item_proc"


func _flash_condense(cloud_idx: int, row: Dictionary, result: Dictionary) -> void:
	var cloud := _remove_steam_cloud(cloud_idx)
	var at: Vector3 = cloud["at"]
	var radius: float = float(cloud["radius"])
	var damage: float = float(row["damage"])
	_create_surface(Elements.SURFACES[row["surface"]], result)
	flash_ring(at + Vector3.UP * 0.15, radius, FROST.lerp(Palette.ICE, 0.5))
	puff(at + Vector3.UP * 0.3)
	var struck := 0
	if is_inside_tree():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			var node := enemy as Node3D
			if not is_instance_valid(node) or (node.has_method("is_dead") and node.is_dead()):
				continue
			var p: Vector3 = node.global_position
			if Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) <= REACH + 4.0:
				if _evolution_strike(node, damage, "item_proc"):
					struck += 1
				touch(node, "frost")
	result["radius"] = radius
	result["struck"] = struck
	result["condensed"] = true
	result["source"] = "item_proc"


func _flash_melt(row: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	var radius: float = float(row["radius"])
	var damage: float = float(row["damage"]) * shatter_scale
	var melted: Array[Vector3] = []
	var i := _slabs.size() - 1
	while i >= 0:
		var slab_at: Vector3 = _slabs[i]["at"]
		if Vector2(slab_at.x - at.x, slab_at.z - at.z).length() <= radius:
			melted.append(slab_at)
			_remove_slab(i, true)
		i -= 1
	flash_ring(at + Vector3.UP * 0.12, radius, HEAT.lerp(Palette.ICE, 0.5))
	var struck := 0
	if not melted.is_empty():
		for enemy in get_tree().get_nodes_in_group("enemy"):
			var p: Vector3 = (enemy as Node3D).global_position
			if Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) <= REACH + 1.5:
				if _evolution_strike(enemy, damage, "item_proc"):
					struck += 1
	result["melted"] = melted.size()
	result["radius"] = radius
	result["struck"] = struck
	result["source"] = "item_proc"


func _remove_slab(index: int, burst: bool) -> void:
	var slab: Dictionary = _slabs[index]
	_slabs.remove_at(index)
	if burst:
		_burst(slab["at"])
	if is_instance_valid(slab["body"]):
		slab["body"].queue_free()


func shard_burst(at: Vector3) -> void:
	_burst(at)


func frost_patch(at: Vector3, radius := 2.0, source := "item_proc") -> Dictionary:
	flash_ring(at + Vector3.UP * 0.08, radius, FROST)
	puff(at)
	_touch_near("frost", at, radius)
	var result := _resolve("frost", at, source)
	return result.get("slab", {})


func shatter_slabs_in_ring(at: Vector3, radius: float, source := "item_proc") -> Dictionary:
	var shattered := 0
	var i := _slabs.size() - 1
	while i >= 0:
		var slab: Dictionary = _slabs[i]
		var slab_at: Vector3 = slab["at"]
		if Vector2(slab_at.x - at.x, slab_at.z - at.z).length() <= radius and absf(slab_at.y - at.y) <= REACH:
			_remove_slab(i, true)
			shattered += 1
		i -= 1
	var struck := 0
	if shattered > 0:
		for enemy in get_tree().get_nodes_in_group("enemy"):
			if (enemy as Node3D).global_position.distance_to(at) <= radius and _evolution_strike(enemy, shatter_damage(), source):
				struck += 1
	return {"shattered": shattered, "struck": struck}


func detonate_crossed_slabs(from: Vector3, to: Vector3, dir: Vector3, exclude_at: Vector3, exclude_radius: float,
		source := "item_proc", spare: Array = []) -> Dictionary:
	var min_x := minf(from.x, to.x)
	var max_x := maxf(from.x, to.x)
	var min_z := minf(from.z, to.z)
	var max_z := maxf(from.z, to.z)
	var spots: Array[Vector3] = []
	var i := _slabs.size() - 1
	while i >= 0:
		var slab: Dictionary = _slabs[i]
		var at: Vector3 = slab["at"]
		var r: float = float(slab["radius"])
		if at.x + r >= min_x and at.x - r <= max_x and at.z + r >= min_z and at.z - r <= max_z \
				and not int(slab["id"]) in spare and crosses(slab, from, to) and not stands_on(slab, exclude_at, exclude_radius):
			spots.append(at)
			_remove_slab(i, false)
		i -= 1
	var cones: Array = []
	for spot in spots:
		cones.append(_shard_cone(spot, dir, source))
	return {"detonated": cones.size(), "cones": cones}


func shatter_damage() -> float:
	return float(Elements.ROWS["kinetic:ice"]["damage"]) * shatter_scale


static func crosses(slab: Dictionary, from: Vector3, to: Vector3) -> bool:
	var centre: Vector3 = slab["at"]
	var r: float = float(slab["radius"])
	if centre.x + r < minf(from.x, to.x) or centre.x - r > maxf(from.x, to.x) \
			or centre.z + r < minf(from.z, to.z) or centre.z - r > maxf(from.z, to.z):
		return false
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var c := Vector2(centre.x, centre.z)
	var near := Geometry2D.get_closest_point_to_segment(c, a, b)
	if near.distance_to(c) > r:
		return false
	var span := a.distance_to(b)
	var y: float = lerpf(from.y, to.y, a.distance_to(near) / span) if span > 0.0001 else from.y
	return y >= float(slab["top"]) - float(slab["thickness"]) and y <= float(slab["top"]) + CROSS_HEIGHT


static func stands_on(slab: Dictionary, ball: Vector3, ball_radius: float) -> bool:
	var centre: Vector3 = slab["at"]
	return Vector2(ball.x - centre.x, ball.z - centre.z).length() <= float(slab["radius"]) + ball_radius \
		and absf(ball.y - ball_radius - float(slab["top"])) <= STAND_GAP


static func in_shard_cone(cone: Dictionary, point: Vector3) -> bool:
	var apex: Vector3 = cone["at"]
	var dir: Vector3 = cone["dir"]
	var offset := Vector3(point.x - apex.x, 0.0, point.z - apex.z)
	if absf(point.y - apex.y) > CONE_HEIGHT:
		return false
	var along := offset.dot(dir)
	if along < -AbilityState.FORGIVENESS or offset.length() > float(cone["length"]) + AbilityState.FORGIVENESS:
		return false
	var lateral := (offset - dir * along).length()
	return lateral <= maxf(along, 0.0) * tan(float(cone["half_angle"])) + AbilityState.FORGIVENESS


func _shard_cone(apex: Vector3, dir: Vector3, source: String) -> Dictionary:
	var flat := Vector3(dir.x, 0.0, dir.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var cone := {"at": apex, "dir": flat, "length": SHARD_CONE_LENGTH, "half_angle": deg_to_rad(SHARD_CONE_DEG),
		"damage": shatter_damage(), "struck": []}
	cone["node"] = _draw_cone(cone)
	_cone_shards(cone)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if in_shard_cone(cone, (enemy as Node3D).global_position) and _evolution_strike(enemy, float(cone["damage"]), source):
			(cone["struck"] as Array).append(enemy)
	shard_cone.emit(cone)
	return cone


func _unshaded_material(color: Color, double_sided := false) -> StandardMaterial3D:
	var key := (color.to_rgba32() << 1) | int(double_sided)
	var cached: StandardMaterial3D = _unshaded_cache.get(key)
	if cached != null:
		return cached
	var mat := PaletteMaterials.unshaded(color)
	if double_sided:
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_unshaded_cache[key] = mat
	return mat


func _cone_mesh(length: float, half: float) -> ArrayMesh:
	var key := "%.3f:%.4f" % [length, half]
	var cached: ArrayMesh = _cone_meshes.get(key)
	if cached != null:
		return cached
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var steps := 12
	for n in steps:
		var a := Vector3.FORWARD.rotated(Vector3.UP, lerpf(-half, half, float(n) / steps)) * length
		var b := Vector3.FORWARD.rotated(Vector3.UP, lerpf(-half, half, float(n + 1) / steps)) * length
		for v in [Vector3.ZERO, a, b]:
			surface.add_vertex(v)
	var mesh := surface.commit()
	_cone_meshes[key] = mesh
	return mesh


func _flash_ring_mesh() -> TorusMesh:
	if _ring_mesh == null:
		_ring_mesh = TorusMesh.new()
		_ring_mesh.inner_radius = 0.9
		_ring_mesh.outer_radius = 1.0
		_ring_mesh.rings = 24
		_ring_mesh.ring_segments = 8
	return _ring_mesh


func _evict_puffs() -> void:
	while _puffs.size() >= MAX_PUFFS:
		var old: Dictionary = _puffs.pop_front()
		var old_node = old.get("node")
		if is_instance_valid(old_node):
			old_node.queue_free()


func _draw_cone(cone: Dictionary) -> MeshInstance3D:
	var apex: Vector3 = cone["at"]
	var dir: Vector3 = cone["dir"]
	var length: float = cone["length"]
	var half: float = cone["half_angle"]
	_evict_puffs()
	var node := MeshInstance3D.new()
	node.name = "ShardCone"
	node.mesh = _cone_mesh(length, half)
	node.material_override = _unshaded_material(Color(Palette.ICE.r, Palette.ICE.g, Palette.ICE.b, 0.55), true)
	add_child(node)
	node.global_position = apex + Vector3.UP * 0.1
	node.rotation.y = atan2(-dir.x, -dir.z)
	_puffs.append({"node": node, "left": PUFF_SECONDS})
	return node


func _cone_shards(cone: Dictionary) -> void:
	var apex: Vector3 = cone["at"]
	var dir: Vector3 = cone["dir"]
	var half: float = cone["half_angle"]
	for n in SHARDS_PER_SLAB:
		if _shards.size() >= MAX_SHARDS:
			break
		var heading := dir.rotated(Vector3.UP, lerpf(-half, half, float(n) / float(SHARDS_PER_SLAB - 1)))
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = _shard_material
		add_child(shard)
		shard.global_position = apex + Vector3.UP * 0.5
		shard.look_at(apex + heading * 4.0 + Vector3.UP * 0.5, Vector3.UP)
		_shards.append({"node": shard, "velocity": (heading + Vector3.UP * 0.2).normalized() * 22.0, "left": SHARD_SECONDS})


func _evolution_strike(enemy: Node3D, damage: float, source: String) -> bool:
	if ctx == null or ctx.spawner == null or damage <= 0.0 or not is_instance_valid(enemy) \
			or (enemy.has_method("is_dead") and enemy.is_dead()):
		return false
	ctx.spawner.strike(enemy, EVOLUTION_STRIKE, damage, "", source)
	return true


func _burst(at: Vector3) -> void:
	for n in SHARDS_PER_SLAB:
		if _shards.size() >= MAX_SHARDS:
			break
		var angle := TAU * float(n) / SHARDS_PER_SLAB
		var dir := Vector3(cos(angle), 0.55, sin(angle)).normalized()
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = _shard_material
		add_child(shard)
		shard.global_position = at + Vector3.UP * 0.5
		shard.look_at(at + dir * 4.0 + Vector3.UP * 0.5, Vector3.UP)
		_shards.append({"node": shard, "velocity": dir * 22.0, "left": SHARD_SECONDS})


func puff(at: Vector3) -> void:
	if _puffs.size() >= MAX_PUFFS:
		return
	var node := MeshInstance3D.new()
	node.mesh = _puff_mesh
	node.material_override = _puff_material
	add_child(node)
	node.global_position = at
	_puffs.append({"node": node, "left": PUFF_SECONDS, "grow": 1.0})


func zap_line(from: Vector3, to: Vector3) -> void:
	if _zaps.size() >= MAX_ZAPS:
		return
	var node := MeshInstance3D.new()
	var line := ImmediateMesh.new()
	line.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var steps := 5
	for i in steps + 1:
		var t := float(i) / steps
		var jitter := Vector3.ZERO
		if i > 0 and i < steps:
			jitter = Vector3(sin(i * 12.9 + _flicker * 40.0), cos(i * 7.3), sin(i * 3.1)) * 0.6
		line.surface_add_vertex(from.lerp(to, t) + jitter)
	line.surface_end()
	node.mesh = line
	node.material_override = _unshaded_material(Palette.ARC)
	add_child(node)
	_zaps.append({"node": node, "left": ZAP_SECONDS})


func flash_ring(at: Vector3, radius: float, color: Color) -> void:
	_evict_puffs()
	var node := MeshInstance3D.new()
	node.mesh = _flash_ring_mesh()
	node.material_override = _unshaded_material(Color(color, FlashGuard.info(color.a)))
	add_child(node)
	node.global_position = at
	_puffs.append({"node": node, "left": PUFF_SECONDS, "grow": radius})


func status_of(enemy: Node3D) -> String:
	var status: Dictionary = _statuses.get(enemy.get_instance_id(), {})
	return String(status.get("element", "")) if float(status.get("until", -INF)) > _clock else ""


func is_held(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and _held.has(enemy.get_instance_id())


func active_count() -> int:
	return _fusions.size()


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if Elements.STATUS_KINDS.has(kind):
		touch(enemy, Elements.STATUS_KINDS[kind])


func _touch_near(element_id: String, at: Vector3, radius: float) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var p: Vector3 = (enemy as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() <= radius and absf(p.y - at.y) <= radius + 1.5:
			touch(enemy, element_id)


func touch(enemy: Node3D, element_id: String) -> Dictionary:
	if not is_instance_valid(enemy) or (enemy.has_method("is_dead") and enemy.is_dead()):
		return {}
	var id := enemy.get_instance_id()
	var held := status_of(enemy)
	var row := Elements.fuse(held, element_id) if held != "" else {}
	if row.is_empty():
		_statuses[id] = {"element": element_id, "until": _clock + Elements.STATUS_SECONDS}
		return {}
	_statuses.erase(id)
	return _commit_fusion(row, Elements.fusion_key(held, element_id), enemy)


func _commit_fusion(row: Dictionary, key: String, enemy: Node3D) -> Dictionary:
	var at := enemy.global_position
	var preview := MeshInstance3D.new()
	preview.name = "FusionPreview"
	preview.mesh = _preview_ring()
	var colour := fusion_colour(key)
	preview.material_override = _unshaded_material(Color(colour.r, colour.g, colour.b, 0.7))
	add_child(preview)
	preview.global_position = at + Vector3.UP * 0.1
	preview.scale = Vector3(row["radius"], 1.0, row["radius"])
	var result := {
		"key": key, "behaviour": row["behaviour"], "kind": row["kind"], "at": at,
		"radius": float(row["radius"]), "seconds": float(row.get("seconds", 0.0)), "damage": float(row["damage"]),
		"interval": float(row.get("interval", 0.0)), "elite_share": float(row.get("elite_share", 1.0)),
		"commit_frame": Engine.get_physics_frames(),
		"land_frame": Engine.get_physics_frames() + Elements.FUSION_LEAD_FRAMES,
		"preview": preview, "colour": colour, "landed": false, "left": 0.0, "beat": 0.0,
	}
	_fusions.append(result)
	if Elements.FUSIONS.has(key):
		fused.emit(result)
	else:
		extended_fused.emit(result)
		if ctx != null and ctx.codex != null and ctx.codex.has_method("mark_found"):
			ctx.codex.mark_found(Elements.card_text(row), "synergy", ["player"])
	return result


func _in_area(fusion: Dictionary) -> Array:
	var at: Vector3 = fusion["at"]
	var found := []
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var p: Vector3 = (enemy as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() <= fusion["radius"] and absf(p.y - at.y) <= fusion["radius"]:
			found.append(enemy)
	return found


static func _elite(enemy: Node3D) -> bool:
	return Elements.elite_rules(String(enemy.get("kind")) if "kind" in enemy else "",
		enemy.has_meta("elite_pack") or enemy.has_meta("elite_affix"))


static func fusion_colour(key: String) -> Color:
	var pair := key.split("+")
	return ELEMENT_COLOURS[pair[0]].lerp(ELEMENT_COLOURS[pair[1]], 0.5)


func _fusion_strike(enemy: Node3D, damage: float) -> void:
	if ctx != null and ctx.spawner != null and damage > 0.0:
		ctx.spawner.strike(enemy, Elements.FUSION_STRIKE, damage, "", "item_proc")


func _land(fusion: Dictionary) -> void:
	fusion["landed"] = true
	fusion["left"] = fusion["seconds"]
	flash_ring(fusion["at"], fusion["radius"], fusion["colour"])
	for enemy in _in_area(fusion):
		match fusion["behaviour"]:
			"lock":
				_fusion_strike(enemy, fusion["damage"])
				if not _elite(enemy):
					_hold(enemy, fusion["seconds"])
			"overload":
				_fusion_strike(enemy, fusion["damage"])
	if fusion["behaviour"] == "grind":
		_grind(fusion)


func _grind(fusion: Dictionary) -> void:
	fusion["beat"] = fusion["interval"]
	for enemy in _in_area(fusion):
		_fusion_strike(enemy, fusion["damage"] * (fusion["elite_share"] if _elite(enemy) else 1.0))


func _hold(enemy: Node3D, seconds: float) -> void:
	var id := enemy.get_instance_id()
	var resume: bool = _held[id]["resume"] if _held.has(id) else enemy.is_physics_processing()
	_held[id] = {"enemy": enemy, "until": _clock + seconds, "resume": resume}
	enemy.set_physics_process(false)
	if enemy.has_method("flash"):
		enemy.flash()


func _release(id: int) -> void:
	var hold: Dictionary = _held[id]
	_held.erase(id)
	if is_instance_valid(hold["enemy"]) and hold["resume"]:
		hold["enemy"].set_physics_process(true)


func _step_fusions(delta: float) -> void:
	var frame := Engine.get_physics_frames()
	var i := _fusions.size() - 1
	while i >= 0:
		var fusion: Dictionary = _fusions[i]
		if not fusion["landed"]:
			if frame >= fusion["land_frame"]:
				_land(fusion)
		else:
			fusion["left"] -= delta
			if fusion["behaviour"] == "grind" and fusion["left"] > 0.0:
				fusion["beat"] -= delta
				if fusion["beat"] <= 0.0:
					_grind(fusion)
		if fusion["landed"] and fusion["left"] <= 0.0:
			if is_instance_valid(fusion["preview"]):
				fusion["preview"].queue_free()
			_fusions.remove_at(i)
		i -= 1
	for id in _held.keys():
		if float(_held[id]["until"]) <= _clock or not is_instance_valid(_held[id]["enemy"]):
			_release(id)
	for id in _statuses.keys():
		if float(_statuses[id]["until"]) <= _clock:
			_statuses.erase(id)


func _preview_ring() -> ArrayMesh:
	if _preview_mesh != null:
		return _preview_mesh
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 32:
		var a := TAU * i / 32.0
		var b := TAU * (i + 1) / 32.0
		for p in [Vector2(a, 0.9), Vector2(b, 0.9), Vector2(a, 1.0), Vector2(b, 0.9), Vector2(b, 1.0), Vector2(a, 1.0)]:
			surface.add_vertex(Vector3(cos(p.x) * p.y, 0.0, sin(p.x) * p.y))
	_preview_mesh = surface.commit()
	return _preview_mesh


func step(delta: float) -> void:
	_clock += delta
	_step_fusions(delta)
	var i := _slabs.size() - 1
	while i >= 0:
		_slabs[i]["left"] -= delta
		if _slabs[i]["left"] <= 0.0:
			_remove_slab(i, false)
		i -= 1
	i = _zones.size() - 1
	while i >= 0:
		var zone: Dictionary = _zones[i]
		zone["left"] -= delta
		zone["clock"] -= delta
		if zone["clock"] <= 0.0:
			zone["clock"] += zone["interval"]
			_zap_zone(zone)
		if zone["left"] <= 0.0:
			if is_instance_valid(zone["node"]):
				zone["node"].queue_free()
			_zones.remove_at(i)
		i -= 1
	i = _steam_clouds.size() - 1
	while i >= 0:
		var cloud: Dictionary = _steam_clouds[i]
		cloud["left"] -= delta
		if ctx != null and ctx.player != null:
			var ball: Vector3 = ctx.player.ball_position()
			var at: Vector3 = cloud["at"]
			if Vector2(ball.x - at.x, ball.z - at.z).length() <= float(cloud["radius"]) \
					and ball.y >= at.y - 1.0 and ball.y <= at.y + 8.0:
				if ctx.player.has_method("add_external_accel"):
					ctx.player.add_external_accel(Vector3.UP * float(cloud["updraft"]))
				cloud["lifts"] = int(cloud.get("lifts", 0)) + 1
		if cloud["left"] <= 0.0:
			if is_instance_valid(cloud["node"]):
				cloud["node"].queue_free()
			_steam_clouds.remove_at(i)
		i -= 1


func _zap_zone(zone: Dictionary) -> void:
	if ctx == null or ctx.spawner == null:
		return
	var at: Vector3 = zone["at"]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var p: Vector3 = (enemy as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() > zone["radius"] or p.y > float(zone["surface_y"]) + 1.6:
			continue
		if material_at(p, 1.6).get("material", "") != "water":
			continue
		ctx.spawner.strike(enemy, "arc", zone["damage"])
		zone["hits"] += 1


func _process(delta: float) -> void:
	_flicker += delta
	for slab in _slabs:
		var mat: StandardMaterial3D = slab["material"]
		var alpha := 0.85
		if slab["left"] < slab["fade"]:
			alpha = 0.35 + 0.5 * (0.5 + 0.5 * sin(_flicker * TAU * FlashGuard.rate(ICE_BLINK_HZ)))
		mat.albedo_color.a = alpha
	for zone in _zones:
		var node: MeshInstance3D = zone["node"]
		if is_instance_valid(node):
			node.visible = FlashGuard.blink(fmod(_flicker * 20.0, 1.0) > 0.25)
	for list in [_shards, _puffs, _zaps]:
		var i: int = list.size() - 1
		while i >= 0:
			var fx: Dictionary = list[i]
			fx["left"] -= delta
			var node: Node3D = fx["node"]
			if fx["left"] <= 0.0 or not is_instance_valid(node):
				if is_instance_valid(node):
					node.queue_free()
				list.remove_at(i)
			else:
				if fx.has("velocity"):
					node.global_position += fx["velocity"] * delta
					fx["velocity"] += Vector3.DOWN * 30.0 * delta
				elif fx.has("grow"):
					var t: float = 1.0 - fx["left"] / PUFF_SECONDS
					var grow: float = fx.get("grow", 1.0)
					if grow > 1.0:
						node.scale = Vector3(grow * t + 0.3, 1.0, grow * t + 0.3)
					else:
						node.scale = Vector3.ONE * (1.4 - t)
			i -= 1
