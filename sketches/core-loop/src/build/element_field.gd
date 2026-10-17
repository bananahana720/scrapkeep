extends Node3D

const Elements := preload("res://src/build/elements.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")

# Resolves the element x material table in the world, once per application, and owns
# what the result leaves behind: ice slabs (real StaticBody3D ground on physics layer
# 1), electrified water zones and the shard nova. Rendering draws the same slab the
# collider is, so what you see is what you can drive on (TADR-009).
#
# Where a material is comes from three places, in this order: the surfaces this field
# created (ice sits on top of the water it came from), providers registered with
# register_material(), and ctx.terrain.material_at(point) when the world offers it.

signal resolved(result: Dictionary)
# SG2: a pair of statuses fused on an enemy, at the frame it commits its area (the result
# carries behaviour, kind, at, radius, seconds, damage and the drawn preview node).
signal fused(result: Dictionary)

const ICE := Color("c8f0ff")
const FROST := Color("e9f8ff")
# What each element draws in: the arc ring, frost puffs and the slam's copper.
const ELEMENT_COLOURS := {"arc": Palette.ARC, "frost": FROST, "kinetic": Palette.COPPER}
# An element reaches a surface this far below the point it was applied at, so a dash
# a few metres over the flood still freezes it.
const REACH := 4.5
const MAX_SLABS := 64
const MAX_ZONES := 6
const MAX_PUFFS := 40
const BALL_CLEARANCE := 0.06
const SHARDS_PER_SLAB := 8
const SHARD_SECONDS := 0.45
const PUFF_SECONDS := 0.4
const MAX_ZAPS := 12
const ZAP_SECONDS := 0.12

var ctx
# Multiplies shatter damage; build sets it from the sheet (Thermal Shock doubles it).
var shatter_scale := 1.0

var _providers := {}
var _slabs: Array[Dictionary] = []
var _zones: Array[Dictionary] = []
var _shards: Array[Dictionary] = []
var _puffs: Array[Dictionary] = []
var _zaps: Array[Dictionary] = []
var _shard_mesh: BoxMesh
var _puff_mesh: SphereMesh
var _shard_material: StandardMaterial3D
var _puff_material: StandardMaterial3D
var _flicker := 0.0
# SG2 statuses and fusions. _statuses: enemy instance id -> {element, until}, at most one each
# (a second fuses and spends both). _fusions: committed areas waiting to land or still running.
# _held: enemy instance id -> {enemy, until, resume}, the lock's hold.
var _clock := 0.0
var _statuses := {}
var _fusions: Array[Dictionary] = []
var _held := {}
var _preview_mesh: ArrayMesh


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	_shard_mesh = BoxMesh.new()
	_shard_mesh.size = Vector3(0.35, 0.35, 0.9)
	_shard_material = Palette.solid(ICE, 2.2)
	_puff_mesh = SphereMesh.new()
	_puff_mesh.radius = 0.45
	_puff_mesh.height = 0.9
	_puff_material = Palette.unshaded(Color(FROST.r, FROST.g, FROST.b, 0.7))
	if ctx != null and ctx.events != null:
		ctx.events.enemy_struck.connect(_on_enemy_struck)


# A provider is func(point: Vector3) -> Dictionary: {"surface_y": float} when the point
# is over that material, else {}. The world registers water this way if it prefers
# pushing to answering ctx.terrain.material_at.
func register_material(material_id: String, provider: Callable) -> void:
	var list: Array = _providers.get(material_id, [])
	list.append(provider)
	_providers[material_id] = list


func clear_providers() -> void:
	_providers.clear()


# Stage content: every created surface and zone goes with the stage.
func clear() -> void:
	for slab in _slabs:
		if is_instance_valid(slab["body"]):
			slab["body"].queue_free()
	_slabs.clear()
	for zone in _zones:
		if is_instance_valid(zone["node"]):
			zone["node"].queue_free()
	_zones.clear()
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


func slabs() -> Array[Dictionary]:
	return _slabs


# What material is at or just below point: {"material", "surface_y"} or {}.
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


# The one entry point: apply an element at a point, resolve the table once, leave the
# result in the world and return it ({} when nothing happens).
func apply(element_id: String, at: Vector3, source := "") -> Dictionary:
	if element_id in Elements.TOUCH_ELEMENTS:
		_touch_near(element_id, at)
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
	resolved.emit(result)
	return result


func _create_surface(surface: Dictionary, result: Dictionary) -> void:
	var at: Vector3 = result["at"]
	var radius: float = surface["radius"]
	var thickness: float = surface["thickness"]
	var top: float = at.y
	# Never form inside the ball: if it sits lower than the new top, the slab forms
	# just under it instead, so creation never pops or blocks the ball.
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
	var mat := Palette.solid(ICE, 0.6)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(ICE.r, ICE.g, ICE.b, 0.85)
	mat.roughness = 0.15
	mesh.material_override = mat
	body.add_child(mesh)
	add_child(body)
	body.global_position = Vector3(at.x, top - thickness * 0.5, at.z)
	result["top"] = top
	result["body"] = body
	_slabs.append({
		"body": body, "material": mat, "at": Vector3(at.x, top, at.z), "top": top,
		"radius": radius, "thickness": thickness, "left": surface["seconds"], "fade": surface["fade"],
	})


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
	node.material_override = Palette.unshaded(Color(Palette.ARC.r, Palette.ARC.g, Palette.ARC.b, 0.45))
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


func _remove_slab(index: int, burst: bool) -> void:
	var slab: Dictionary = _slabs[index]
	_slabs.remove_at(index)
	if burst:
		_burst(slab["at"])
	if is_instance_valid(slab["body"]):
		slab["body"].queue_free()


# A shard burst anywhere, for shrapnel and shatter.
func shard_burst(at: Vector3) -> void:
	_burst(at)


func _burst(at: Vector3) -> void:
	for n in SHARDS_PER_SLAB:
		var angle := TAU * float(n) / SHARDS_PER_SLAB
		var dir := Vector3(cos(angle), 0.55, sin(angle)).normalized()
		var shard := MeshInstance3D.new()
		shard.mesh = _shard_mesh
		shard.material_override = _shard_material
		add_child(shard)
		shard.global_position = at + Vector3.UP * 0.5
		shard.look_at(at + dir * 4.0 + Vector3.UP * 0.5, Vector3.UP)
		_shards.append({"node": shard, "velocity": dir * 22.0, "left": SHARD_SECONDS})


# A frost puff: the dash trail's visible cue, drawn whether or not it met water.
func puff(at: Vector3) -> void:
	if _puffs.size() >= MAX_PUFFS:
		return
	var node := MeshInstance3D.new()
	node.mesh = _puff_mesh
	node.material_override = _puff_material
	add_child(node)
	node.global_position = at
	_puffs.append({"node": node, "left": PUFF_SECONDS, "grow": 1.0})


# A jagged arc from one point to another, for synergy zaps. Capped, so a storm of them
# never hides the field (principle 4).
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
	node.material_override = Palette.unshaded(Palette.ARC)
	add_child(node)
	_zaps.append({"node": node, "left": ZAP_SECONDS})


# A flat ring that bursts out to radius: the arc coil's discharge, sized to its reach.
func flash_ring(at: Vector3, radius: float, color: Color) -> void:
	var node := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	torus.rings = 48
	node.mesh = torus
	node.material_override = Palette.unshaded(color)
	add_child(node)
	node.global_position = at
	_puffs.append({"node": node, "left": PUFF_SECONDS, "grow": radius})


# --- SG2 statuses and fusions ---------------------------------------------------------

func status_of(enemy: Node3D) -> String:
	var status: Dictionary = _statuses.get(enemy.get_instance_id(), {})
	return String(status.get("element", "")) if float(status.get("until", -INF)) > _clock else ""


func is_held(enemy: Node3D) -> bool:
	return is_instance_valid(enemy) and _held.has(enemy.get_instance_id())


# Fusions committed and not yet finished (their preview still drawn).
func active_count() -> int:
	return _fusions.size()


func _on_enemy_struck(enemy: Node3D, kind: String, _force: float) -> void:
	if Elements.STATUS_KINDS.has(kind):
		touch(enemy, Elements.STATUS_KINDS[kind])


func _touch_near(element_id: String, at: Vector3) -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var p: Vector3 = (enemy as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() <= Elements.TOUCH_RADIUS and absf(p.y - at.y) <= Elements.TOUCH_RADIUS + 1.5:
			touch(enemy, element_id)


# The one status entry: an element reaches an enemy. With no live status it leaves one; with
# the same element it refreshes; with a different one the pair fuses once and both are spent.
# Returns the fusion result, or {}.
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


# Commits the area once, at the enemy where the pair met, and draws it now; step() lands the
# damage and hold FUSION_LEAD_FRAMES later on that same area.
func _commit_fusion(row: Dictionary, key: String, enemy: Node3D) -> Dictionary:
	var at := enemy.global_position
	var preview := MeshInstance3D.new()
	preview.name = "FusionPreview"
	preview.mesh = _preview_ring()
	var colour := fusion_colour(key)
	preview.material_override = Palette.unshaded(Color(colour.r, colour.g, colour.b, 0.7))
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
	fused.emit(result)
	return result


# Every enemy whose position is inside the committed area, the same test for damage and hold.
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


# A fusion wears an even mix of its two elements' colours.
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


# The lock: the enemy stops thinking and moving until the hold ends. One that was already
# still (not processing physics) is left that way on release.
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


# A unit-radius flat ring (outer edge 1.0), scaled to the committed radius.
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


# Physics step: effect windows count down here, and electrified water strikes on its beat.
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


func _zap_zone(zone: Dictionary) -> void:
	if ctx == null or ctx.spawner == null:
		return
	var at: Vector3 = zone["at"]
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var p: Vector3 = (enemy as Node3D).global_position
		if Vector2(p.x - at.x, p.z - at.z).length() > zone["radius"] or p.y > float(zone["surface_y"]) + 1.6:
			continue
		# Standing on ice over the water is not standing in it.
		if material_at(p, 1.6).get("material", "") != "water":
			continue
		ctx.spawner.strike(enemy, "arc", zone["damage"])
		zone["hits"] += 1


func _process(delta: float) -> void:
	_flicker += delta
	for slab in _slabs:
		var mat: StandardMaterial3D = slab["material"]
		var alpha := 0.85
		# Melting ice blinks for its last beat, so losing the ground is never a surprise.
		if slab["left"] < slab["fade"]:
			alpha = 0.35 + 0.5 * (0.5 + 0.5 * sin(_flicker * 28.0))
		mat.albedo_color.a = alpha
	for zone in _zones:
		var node: MeshInstance3D = zone["node"]
		if is_instance_valid(node):
			node.visible = fmod(_flicker * 20.0, 1.0) > 0.25
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
