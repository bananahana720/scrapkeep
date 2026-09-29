extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

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
# The class colour "now" is drawn in: combat sets it when a run starts.
static var rim_color := Palette.ARC

signal hit_player(amount: float, shove: Vector3)
signal died(at: Vector3, scrap_value: int)
# Attack facts (DESIGN-NOTES, "Attack facts, enemies"): one read-only fact per phase
# change of a mapped enemy's attack. It decides nothing and owns no clock; it reports
# what the existing state machine and its committed telegraph already did.
signal attack_phase(facts: Dictionary)

const PHASE_WINDUP := "windup"
const PHASE_STRIKE := "strike"
const PHASE_RECOVER := "recover"
const PHASE_CANCELLED := "cancelled"
# Enemies whose attack has no clean owner among these files, so they publish nothing.
const FACTS_UNMAPPED := {
	"swarm_remnant": "the formation lane is committed and driven by swarm.gd, not by the remnant's own state",
}
# The lobber's muzzle glow is its wind-up: _show_charge sets emission to 0.8 + 5 x charge.
const LOBBER_GLOW_BASE := 0.8
const LOBBER_GLOW_SPAN := 5.0
const LOBBER_MIN_CHARGE := 0.0005
# Instance ids are unique for the process; nothing reads their order.
static var _attack_serial := 0

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
# The open attack instance, or {} between attacks: instance, row, phase, managed, geometry, progress.
var _atk := {}


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
	if has_signal("fired"):
		connect("fired", _facts_on_fired)


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
	_facts_end(true)
	collision_layer = 0
	collision_mask = 0
	_clear_telegraph()
	died.emit(global_position, scrap_value)
	queue_free()


func _exit_tree() -> void:
	_facts_end(true)
	_clear_telegraph()


func _clear_telegraph() -> void:
	_facts_end(false)
	if is_instance_valid(_telegraph):
		_telegraph.queue_free()
	_telegraph = null


func _commit_ring(threat_type: int, at: Vector3, ring_radius: float, reach := 3.5, tint := Palette.HAZARD) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.ring(world_root, terrain, threat_type, at, ring_radius, reach, tint)
	_facts_begin(_telegraph)
	return _telegraph


func _commit_lane(threat_type: int, from: Vector3, heading: Vector3, lane_length: float, lane_width: float, reach := 3.5) -> Node3D:
	_clear_telegraph()
	_telegraph = Telegraph.lane(world_root, terrain, threat_type, from, heading, lane_length, lane_width, reach)
	_facts_begin(_telegraph)
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
	_material.emission_enabled = tint_state == "amber"
	_material.emission = rim_color
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
func _plate_material() -> StandardMaterial3D:
	var mat := Palette.solid(PLATE_CLOSED)
	mat.metallic = 0.6
	mat.roughness = 0.4
	_paint_plate(mat, PLATE_CLOSED, false)
	_tint_materials.append(mat)
	return mat


# Plating carries its read in light, not just paint, so it survives distance and shade:
# the class-colour rim burns (your punch breaks through now); closed plates stay dark.
static func _paint_plate(mat: StandardMaterial3D, color: Color, beatable: bool) -> void:
	mat.albedo_color = color.darkened(0.35) if beatable else color
	mat.emission_enabled = beatable
	mat.emission = color
	mat.emission_energy_multiplier = PLATE_GLOW_AMBER if beatable else PLATE_GLOW_SLATE


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


# --- Attack facts ---------------------------------------------------------------------

func _notification(what: int) -> void:
	if what == NOTIFICATION_PHYSICS_PROCESS:
		_facts_poll()


# The open attack as a fact, with the geometry and progress it has right now; {} when
# this enemy is between attacks or unmapped.
func attack_facts() -> Dictionary:
	if _atk.is_empty():
		return {}
	return _facts_dict(String(_atk["phase"]))


# The row an attack of this enemy reads (ATTACK_ROWS): its roster row, chosen by lane or
# ring when the owner has two (the miniboss). "" for an unmapped enemy.
func _facts_row(is_lane: bool) -> String:
	if FACTS_UNMAPPED.has(kind):
		return ""
	var found: Array = []
	for id in EventKinds.ATTACK_ROWS:
		var row: Dictionary = EventKinds.ATTACK_ROWS[id]
		if row["group"] == "enemy" and row["owner_kind"] == "roster" and row["owner"] == kind:
			found.append(id)
	if found.size() <= 1:
		return "" if found.is_empty() else found[0]
	for id in found:
		if (EventKinds.ATTACK_ROWS[id]["threat"] == "threat_lane") == is_lane:
			return id
	return ""


func _facts_begin(tele: Node3D, managed := false) -> void:
	_facts_end(false)
	var row := _facts_row(tele.shape == Telegraph.Shape.LANE)
	if row == "":
		return
	_attack_serial += 1
	_atk = {"instance": _attack_serial, "row": row, "phase": PHASE_WINDUP, "managed": managed, "tele": tele,
		"geometry": tele.descriptor(), "progress": tele.progress}
	attack_phase.emit(_facts_dict(PHASE_WINDUP))


# A counter drives its own phases: it takes over an instance the commit opened, or opens
# one for a telegraph it set directly (the swatter's wedge).
func _facts_manage(tele: Node3D) -> void:
	if _atk.is_empty():
		_facts_begin(tele, true)
	else:
		_atk["managed"] = true


func _facts_phase(phase: String) -> void:
	if _atk.is_empty() or _atk["phase"] == phase:
		return
	_facts_refresh()
	_atk["phase"] = phase
	attack_phase.emit(_facts_dict(phase))


# Closes the open instance. A wind-up that never reached its strike, and any death or
# removal, is cancelled; an attack that struck ends in recover.
func _facts_end(cancel: bool) -> void:
	if _atk.is_empty():
		return
	if not cancel and not _dead:
		_facts_poll()
	var closing := PHASE_CANCELLED if (cancel or _dead or _atk["phase"] == PHASE_WINDUP) else PHASE_RECOVER
	_facts_refresh()
	var facts := _facts_dict(closing)
	_atk = {}
	attack_phase.emit(facts)


func _facts_refresh() -> void:
	var tele = _atk.get("tele")
	if tele != null and is_instance_valid(tele):
		_atk["geometry"] = tele.descriptor()
		_atk["progress"] = tele.progress


func _facts_dict(phase: String) -> Dictionary:
	if String(_atk["phase"]) == phase:
		_facts_refresh()
	var geometry: Dictionary = _atk["geometry"]
	return {"instance": _atk["instance"], "row": _atk["row"], "owner": kind, "phase": phase,
		"committed": not geometry.is_empty(), "progress": _atk["progress"], "geometry": geometry.duplicate(),
		"at": global_position}


func _facts_poll() -> void:
	if _dead:
		return
	if kind == "lobber":
		_facts_poll_lobber()
		return
	if _atk.is_empty() or _atk["managed"] or _atk["phase"] != PHASE_WINDUP:
		return
	var tele = _atk.get("tele")
	if tele != null and is_instance_valid(tele) and tele.progress >= 1.0:
		_facts_phase(PHASE_STRIKE)


# The lobber has no telegraph until release, so its wind-up is the muzzle charge it
# already draws, and its aim stays uncommitted (empty geometry) until fired.
func _facts_poll_lobber() -> void:
	var mat = get("_muzzle_material")
	if mat == null:
		return
	var charge: float = (mat.emission_energy_multiplier - LOBBER_GLOW_BASE) / LOBBER_GLOW_SPAN
	if _atk.is_empty():
		if charge > LOBBER_MIN_CHARGE and _in_play():
			_facts_begin_lobber(charge)
	elif _atk["phase"] == PHASE_WINDUP:
		if charge <= LOBBER_MIN_CHARGE:
			_facts_end(true)
		else:
			_atk["progress"] = clampf(charge, 0.0, 1.0)


func _facts_begin_lobber(charge: float) -> void:
	var row := _facts_row(false)
	if row == "":
		return
	_attack_serial += 1
	_atk = {"instance": _attack_serial, "row": row, "phase": PHASE_WINDUP, "managed": true, "tele": null,
		"geometry": {}, "progress": clampf(charge, 0.0, 1.0)}
	attack_phase.emit(_facts_dict(PHASE_WINDUP))


# The release commits the aim: strike carries the landing ring the shell will draw
# (projectile.gd), then the lobber's own part is over.
func _facts_on_fired(_origin: Vector3, landing: Vector3, flight: float) -> void:
	if _dead:
		return
	if _atk.is_empty():
		_facts_begin_lobber(1.0)
	if _atk.is_empty():
		return
	var blast: float = load("res://src/combat/projectile.gd").BLAST_RADIUS
	_atk["geometry"] = {"type": Threat.Type.PROJECTILE, "form": "radial", "centre": landing, "reach": 3.5,
		"r_in": 0.0, "r_out": blast, "a0": 0.0, "a1": TAU, "progress": 0.0, "live": false, "flight": flight}
	_atk["progress"] = 0.0
	_facts_phase(PHASE_STRIKE)
	_facts_end(false)
