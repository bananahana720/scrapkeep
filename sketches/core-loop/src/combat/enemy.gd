extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")

# What every enemy shares: health, plating, weight, knockback, the flash, the plating
# tint, death and its telegraph. The spine's ball calls knock() and flash() on contact
# (CONTRACTS.md), so collisions have weight whatever combat does with the damage;
# weight divides every shove, so a miniboss barely rocks where a chaser flies.
#
# Plating (DEMO-SPEC Rules): combat's strike() asks plating_for(kind, part) and
# hit_mult(kind, part). A hit whose punch reaches the plating lands in full; below it
# the hit chips 20%. Weak points are parts: an enemy may list them in weak_points()
# (spheres a bolt can hit) or name one from a contact in contact_part(). The base enemy
# has none and one plating for everything.
#
# An enemy never damages the player directly. It emits hit_player(amount, shove) only
# after its committed telegraph's contains() says the ball was inside, and the spawner
# turns that into run.damage. Walking into an enemy costs nothing but the bump.

const GRAVITY := 26.0
const KNOCK_DECAY := 16.0
const FLOOR_RESCUE := 30.0
# Plating reads: amber when your punch beats it, slate when it does not.
const AMBER := Palette.AMBER
const SLATE := Color("5d6b78")
const TINT_ENERGY := 0.9

signal hit_player(amount: float, shove: Vector3)
signal died(at: Vector3, scrap_value: int)

var kind := "chaser"
var target
var terrain
var world_root: Node3D
var live := Callable()
var spec := {}
var hp := 40.0
var max_hp := 40.0
var plating := 0.0
var scrap_value := 3
var weight := 1.0
var radius := 1.0
var half_height := 1.5
# "", "amber" or "slate", set by combat every physics tick from punch_now().
var tint_state := ""

var _knock := Vector3.ZERO
var _flash := 0.0
var _dead := false
var _material: StandardMaterial3D
var _base_color := Palette.RUST
var _telegraph: Node3D
# Extra materials a plated enemy recolours with its tint (armour plates, shells).
var _tint_materials: Array = []


# Subclasses call this first from their own setup, then build their body.
func _setup_common(target_ref, terrain_ref, root_ref, live_ref: Callable, spec_ref := {}) -> void:
	target = target_ref
	terrain = terrain_ref
	world_root = root_ref
	live = live_ref
	spec = spec_ref
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)


func _set_health(value: float) -> void:
	hp = value
	max_hp = value


func knock(direction: Vector3, force: float) -> void:
	if _dead or direction.length_squared() < 0.0001:
		return
	var push := direction.normalized() * force / weight
	if push.length() > Vector3(_knock.x, 0.0, _knock.z).length():
		_knock = Vector3(push.x, _knock.y, push.z)
	_knock.y = maxf(_knock.y, maxf(push.y, force * 0.2 / weight))


func flash() -> void:
	_flash = 1.0


func is_dead() -> bool:
	return _dead


# --- Plating --------------------------------------------------------------------------

# The plating right now, before any weak point. The miniboss drops it to 0 in its weak
# window; the Warden drops it to 0 while its magnet is shot.
func plating_now() -> float:
	return plating


# The plating one hit meets. `part` is "" for the body or a weak point id.
func plating_for(_kind: String, _part: String) -> float:
	return plating_now()


# The damage multiplier on a hit that beat the plating (a Warden vent cap takes 1.5).
func hit_mult(_kind: String, _part: String) -> float:
	return 1.0


# Weak points a bolt can hit: [{id, at: Vector3, radius}]. Checked before the body.
func weak_points() -> Array:
	return []


# The weak point a ball contact (stomp, ram, slam) lands on, or "".
func contact_part(_ball: Vector3, _kind: String) -> String:
	return ""


# Called by strike() after the hit is resolved and before the damage, so an enemy can
# react to what hit it (the Warden's magnet). `result` is combat's resolve record.
func on_struck(_kind: String, _part: String, _result: Dictionary) -> void:
	pass


func set_tint(state: String) -> void:
	if state == tint_state:
		return
	tint_state = state
	var color := AMBER if state == "amber" else SLATE
	for mat in _tint_materials:
		(mat as StandardMaterial3D).albedo_color = color
	if _flash <= 0.0:
		_apply_rest_look()


# Kept for callers from the first cut; plating replaced the multipliers.
func damage_scale() -> float:
	return 1.0


# Resolves one hit's damage, already decided by strike(). Returns the damage dealt.
func take_damage(amount: float) -> float:
	if _dead:
		return 0.0
	hp -= amount
	flash()
	if hp <= 0.0:
		_die()
	return amount


func telegraph() -> Node3D:
	return _telegraph if is_instance_valid(_telegraph) else null


func _die() -> void:
	_dead = true
	_clear_telegraph()
	died.emit(global_position, scrap_value)
	queue_free()


func _exit_tree() -> void:
	_clear_telegraph()


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _commit_ring(at: Vector3, ring_radius: float, reach := 3.5) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.ring(world_root, terrain, at, ring_radius, reach)
	return _telegraph


func _commit_lane(from: Vector3, heading: Vector3, lane_length: float, lane_width: float, reach := 3.5) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.lane(world_root, terrain, from, heading, lane_length, lane_width, reach)
	return _telegraph


func _in_play() -> bool:
	return not live.is_valid() or live.call()


func _ball() -> Vector3:
	return target.ball_position()


func _flat_to_ball() -> Vector3:
	var to: Vector3 = _ball() - global_position
	to.y = 0.0
	return to


# Knockback wins over the enemy's own intent until it has bled below walking pace.
func _move(delta: float, desired: Vector3) -> void:
	var horizontal := Vector3(_knock.x, 0.0, _knock.z)
	if horizontal.length() < 1.0:
		horizontal = desired
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if _knock.y > 0.0:
		velocity.y = _knock.y
		_knock.y = 0.0
	velocity.y -= GRAVITY * delta
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	_rescue()


func _knocked_speed() -> float:
	return Vector3(_knock.x, 0.0, _knock.z).length()


# An enemy that falls through the map is put back on the ground, not killed: a kill
# would hand out scrap nobody earned.
func _rescue() -> void:
	if terrain == null:
		return
	var ground: float = terrain.height(global_position.x, global_position.z)
	if global_position.y < ground - FLOOR_RESCUE:
		global_position = terrain.drop_point(global_position.x, global_position.z, half_height + 0.5)
		velocity = Vector3.ZERO


func _update_flash(delta: float) -> void:
	if _material == null:
		return
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.5)
		_material.albedo_color = _base_color.lerp(Color(1.0, 1.0, 0.85), _flash)
		_material.emission_enabled = true
		_material.emission = Palette.AMBER
		_material.emission_energy_multiplier = _flash * 2.0
		if _flash <= 0.0:
			_apply_rest_look()


# The resting look: the base colour, with the plating tint glowing through on a plated
# enemy so the read survives any lighting.
func _apply_rest_look() -> void:
	if _material == null:
		return
	_material.albedo_color = _base_color
	if tint_state == "":
		_material.emission_enabled = false
		return
	_material.emission_enabled = true
	_material.emission = AMBER if tint_state == "amber" else SLATE
	_material.emission_energy_multiplier = TINT_ENERGY


func _add_capsule(capsule_radius: float, capsule_height: float, color: Color) -> MeshInstance3D:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = capsule_radius
	capsule.height = capsule_height
	shape.shape = capsule
	add_child(shape)
	_base_color = color
	_material = Palette.solid(color)
	var mesh := MeshInstance3D.new()
	var capsule_mesh := CapsuleMesh.new()
	capsule_mesh.radius = capsule_radius
	capsule_mesh.height = capsule_height
	mesh.mesh = capsule_mesh
	mesh.material_override = _material
	add_child(mesh)
	return mesh


# A tinted material for a plating mesh, registered so set_tint recolours it.
func _plate_material() -> StandardMaterial3D:
	var mat := Palette.solid(SLATE)
	mat.metallic = 0.6
	mat.roughness = 0.4
	_tint_materials.append(mat)
	return mat
