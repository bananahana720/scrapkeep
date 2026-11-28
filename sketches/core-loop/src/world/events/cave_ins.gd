extends Node3D


const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Groups := preload("res://src/core/groups.gd")
const RubbleFall := preload("res://src/world/events/rubble_fall.gd")

const RADIUS_M := 4.5
const WARN_S := 1.2
const DAMAGE := 6
const GAP_S := 4.0
const MAX_LIVE := 1
const LIFT_MPS := 6.0

var world
var active := false
var falls_started := 0
var balls_hit := 0
var last_at := Vector3.INF
var _seen := {}
var _live: Array = []
var _since_last := INF


func setup(world_ref) -> void:
	world = world_ref
	name = "CaveIns"
	add_to_group(Groups.WORLD_TELEGRAPHS)
	var map = world.terrain.map()
	if not "park" in map or map.park.is_empty():
		return
	for home in map.park.get("home_rows", []):
		if String(home.get("enemy", "")) == "burrower":
			active = true


func telegraphs(ball: Vector3) -> Array:
	var out: Array = []
	for fall in _live:
		if is_instance_valid(fall) and fall.hazard != null and is_instance_valid(fall.hazard):
			out.append({"id": fall.hazard.get_instance_id(), "cause": "cave_in", "covers": fall.hazard.contains(ball)})
	return out


func handle(_action: String, _row: Dictionary, _ctx: Dictionary) -> void:
	pass


func _physics_process(delta: float) -> void:
	if not active or world == null or not is_inside_tree():
		return
	_since_last += delta
	_live = _live.filter(func(fall) -> bool: return is_instance_valid(fall))
	for burrower in get_tree().get_nodes_in_group(Groups.ENEMY):
		if String(burrower.get("kind")) != "burrower":
			continue
		if burrower.has_method("is_dead") and burrower.is_dead():
			continue
		if _surfaced(burrower):
			surface_at(burrower.global_position)


func _surfaced(burrower) -> bool:
	var id: int = burrower.get_instance_id()
	var now := {"bursts": int(burrower.get("bursts") if burrower.get("bursts") != null else 0),
		"hidden": bool(burrower.get("hidden") if burrower.get("hidden") != null else true)}
	var was: Dictionary = _seen.get(id, now)
	_seen[id] = now
	return now.bursts > was.bursts or (was.hidden and not now.hidden)


func surface_at(at: Vector3) -> Node3D:
	if _live.size() >= MAX_LIVE or _since_last < GAP_S:
		return null
	var player = world.ctx.player if "ctx" in world and world.ctx != null else null
	var ground_y: float = world.terrain.height(at.x, at.z)
	var fall = RubbleFall.new()
	fall.configure("cave_in_%d" % falls_started, Vector3(at.x, ground_y, at.z), RADIUS_M, WARN_S, world.terrain, player,
		Callable(self, "_hit_ball"), 0.0, _debris(Vector3(at.x, ground_y + 9.0, at.z)))
	fall.voice = "clank"
	fall.warn_sound = "cave_in_rumble"
	fall.land_sound = "cave_in_debris"
	add_child(fall)
	_live.append(fall)
	_since_last = 0.0
	falls_started += 1
	last_at = at
	return fall


func _debris(at: Vector3) -> Node3D:
	var debris := Node3D.new()
	debris.name = "CaveInDebris"
	var rock := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(RADIUS_M * 1.2, 1.0, RADIUS_M * 1.1)
	rock.mesh = mesh
	rock.material_override = PaletteMaterials.solid(Palette.SANDSTONE.darkened(0.45))
	rock.rotation = Vector3(0.2, 0.7, -0.15)
	debris.add_child(rock)
	debris.position = at
	return debris


func _hit_ball() -> void:
	balls_hit += 1
	if world == null or not "ctx" in world or world.ctx == null or world.ctx.run == null:
		return
	var player = world.ctx.player
	var ball: Vector3 = player.ball_position()
	var taken: int = world.ctx.run.lose_scrap(DAMAGE, ball, "cave_in")
	if taken < DAMAGE:
		var velocity: Vector3 = player.state.velocity
		velocity.y = maxf(velocity.y, LIFT_MPS)
		player.set_velocity_now(velocity, "cave_in")


func release() -> void:
	for fall in _live:
		if is_instance_valid(fall):
			fall.free()
	_live.clear()
	_seen.clear()
	world = null
	active = false
