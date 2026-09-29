extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

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
# The plating dress (primer ruling 6, 2026-09-27): "breaks now" is a rim in the class
# colour with an open-crack glyph; "not yet" is closed plates with no rim, and the
# clank ladder already says how close you were. Amber belongs to Kest and the rare
# rarity and slate vanishes on ancient petrol, so neither reads plating any more. The
# tint_state names ("amber" for now, "slate" for not yet) stay as the state's names.
const AMBER := Palette.AMBER
const SLATE := Color("5d6b78")
const PLATE_CLOSED := Color("3b403d")
const TINT_ENERGY := 0.9
const PLATE_GLOW_AMBER := 1.8
const PLATE_GLOW_SLATE := 0.0
# The cue lives on the plate's rim, not its faces (Andrew, 2026-09-29): the plate material
# emits through a tiny nearest-filtered mask texture, so light appears only where the mask
# is white (rim, bolts) and body and plate faces keep their resting finish in both states.
# One material, one draw: the mask adds no surface. A mesh with no mask UVs takes the dark
# mask and shows nothing on its faces; its crack glyph carries the cue.
const RIM_CELL := 8
const RIM_EDGE := 2
# The class colour "now" is drawn in: combat sets it when a run starts.
static var rim_color := Palette.ARC

signal hit_player(amount: float, shove: Vector3)
signal died(at: Vector3, scrap_value: int)

var kind := "chaser"
# The faction whose timbre and arrival cue this enemy carries (roster.gd): "fleet", or
# an ancient family, "reactor", "swarm" or "mind".
var faction := "fleet"
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
# How many shoves this enemy has taken, for tests and anything that reads weight.
var knocks := 0

var _knock := Vector3.ZERO
var _flash := 0.0
var _dead := false
var _material: StandardMaterial3D
var _base_color := Palette.RUST
var _telegraph: Node3D
# Extra materials a plated enemy recolours with its tint (armour plates, shells).
var _tint_materials: Array = []
# Open-crack glyphs a plated enemy shows only while your punch breaks it now.
var _cracks: Array = []


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
	knocks += 1
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
	var now := state == "amber"
	for mat in _tint_materials:
		_paint_plate(mat as StandardMaterial3D, rim_color if now else PLATE_CLOSED, now)
	for crack in _cracks:
		if is_instance_valid(crack):
			crack.visible = now
	if _flash <= 0.0:
		_apply_rest_look()


# Kept for callers from the first cut; plating replaced the multipliers.
func damage_scale() -> float:
	return 1.0


# Resolves one hit's damage, already decided by strike(). Returns the HP actually
# removed, clamped to what was left (M0's delivered-damage ledger reads this, not the
# raw amount, so overkill is clamped at the one place hp actually changes).
func take_damage(amount: float) -> float:
	if _dead:
		return 0.0
	var removed := minf(amount, hp)
	hp -= amount
	flash()
	if hp <= 0.0:
		_die()
	return removed


func telegraph() -> Node3D:
	return _telegraph if is_instance_valid(_telegraph) else null


# The kill is recorded on the tick health reaches 0, and the body stops colliding on
# that same tick, so a crush exception can never end inside a live collider. Any death
# visual belongs to presentation, reading enemy_killed; this node is gone at frame end.
func _die() -> void:
	_dead = true
	collision_layer = 0
	collision_mask = 0
	_clear_telegraph()
	died.emit(global_position, scrap_value)
	queue_free()


func _exit_tree() -> void:
	_clear_telegraph()


func _clear_telegraph() -> void:
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _commit_ring(threat_type: int, at: Vector3, ring_radius: float, reach := 3.5, tint := Palette.HAZARD) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.ring(world_root, terrain, threat_type, at, ring_radius, reach, tint)
	return _telegraph


func _commit_lane(threat_type: int, from: Vector3, heading: Vector3, lane_length: float, lane_width: float, reach := 3.5) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.lane(world_root, terrain, threat_type, from, heading, lane_length, lane_width, reach)
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


# The resting look: the base colour and no glow. The plating cue is on the plate's rim.
func _apply_rest_look() -> void:
	if _material == null:
		return
	_material.albedo_color = _base_color
	_material.emission_enabled = false


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


# A visual-only accent: a lit mesh that grows an enemy's silhouette or marks it from
# 60 to 100 m. It never collides; the enemy's collider is unchanged.
func _accent(mesh: Mesh, color: Color, energy: float, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Palette.solid(color, energy)
	instance.position = at
	parent.add_child(instance)
	return instance


# A tinted material for a plating mesh, registered so set_tint recolours it.
# `rim_mask` is the emission mask: rim_frame_mask() for BoxMesh plates, a mesh-specific
# mask where the mesh carries its own UVs, or the dark default (no plate-face light).
func _plate_material(rim_mask: Texture2D = null) -> StandardMaterial3D:
	var mat := Palette.solid(PLATE_CLOSED)
	mat.metallic = 0.6
	mat.roughness = 0.4
	mat.emission_texture = rim_mask if rim_mask != null else mask_texture([Color.BLACK], 1)
	# Multiply, not the default add: the colour must only show where the mask is white.
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_paint_plate(mat, PLATE_CLOSED, false)
	_tint_materials.append(mat)
	return mat


# Plating carries its read in light, not just paint, so it survives distance and shade:
# the class-colour rim burns (your punch breaks through now); closed plates stay dark.
static func _paint_plate(mat: StandardMaterial3D, color: Color, beatable: bool) -> void:
	# The resting finish stays in both states; "now" arrives as light through the mask.
	mat.albedo_color = PLATE_CLOSED
	mat.emission_enabled = beatable
	mat.emission = color
	mat.emission_energy_multiplier = PLATE_GLOW_AMBER if beatable else PLATE_GLOW_SLATE


# A one-row or grid mask texture, nearest-sampled and mipless so a texel never blends.
static func mask_texture(texels: Array, width: int, height := 1) -> ImageTexture:
	var img := Image.create_empty(width, height, false, Image.FORMAT_RGB8)
	for i in texels.size():
		img.set_pixel(i % width, i / width, texels[i])
	return ImageTexture.create_from_image(img)


# White border on every cell of BoxMesh's 3x2 face atlas: a rim on all six faces.
static var _frame_mask: ImageTexture
static func rim_frame_mask() -> ImageTexture:
	if _frame_mask == null:
		var w := RIM_CELL * 3
		var h := RIM_CELL * 2
		var texels := []
		for y in h:
			for x in w:
				var cx := x % RIM_CELL
				var cy := y % RIM_CELL
				var edge := cx < RIM_EDGE or cx >= RIM_CELL - RIM_EDGE or cy < RIM_EDGE or cy >= RIM_CELL - RIM_EDGE
				texels.append(Color.WHITE if edge else Color.BLACK)
		_frame_mask = mask_texture(texels, w, h)
	return _frame_mask


# An open-crack glyph on a plate: a lit zigzag in the class colour, shown only while
# the plate breaks now. Visual only; parented to the plate so it moves with it.
func _add_crack(parent: Node3D, at: Vector3, size := 0.9) -> Node3D:
	var glyph := Node3D.new()
	glyph.position = at
	var mat := Palette.unshaded(rim_color)
	for i in 3:
		var stroke := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.09, size * 0.45, 0.06)
		stroke.mesh = box
		stroke.material_override = mat
		stroke.position = Vector3((i - 1) * size * 0.18, (1 - i) * size * 0.28, 0.0)
		stroke.rotation.z = 0.6 if i % 2 == 0 else -0.6
		glyph.add_child(stroke)
	glyph.visible = tint_state == "amber"
	parent.add_child(glyph)
	_cracks.append(glyph)
	return glyph
