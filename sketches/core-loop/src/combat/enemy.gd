extends CharacterBody3D

const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")

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
# Ring-outs (design-v3/WORLD-ROSTERS.md, Andrew's "Ring-outs" tap, 17 Oct 20:03Z): in the
# Highdraft an enemy knocked off an island edge is gone, a kill for the pilot. Only a knock
# counts: one that walks off is still rescued. A knock opens the fall; in the air over ground
# RING_OUT_DROP below the floor it was knocked from, the enemy rings out. Bosses, Wardens, their relics and the
# kill-first specials are always rescued.
const RING_OUT_WORLD := 3
const RING_OUT_DROP := 6.0
# Boss pieces are kept too (Roster.is_boss_piece). Splitter pods can be rung out
# (WORLD-ROSTERS.md); the mama splitter cannot. Flyers (kite and winch drones) hover and
# move on their own _move, so a knock never drops them.
const RING_OUT_KEPT := ["warden", "vault", "miniboss", "reactor_relic", "swarm_remnant", "mind_hand",
	"foreman", "dispatcher", "splitter", "linker"]
# The plating dress reads the colour law (LEGIBILITY, STATE_ROWS): "breaks now" is a rim and
# an open-crack glyph in the live colour, pulsing; "not yet" is a steady slate rim and no
# crack. The tint_state names ("amber" for will break, "slate" for glances) stay as combat
# passes them; what they draw comes from the will_break and glancing rows.
const PLATE_CLOSED := Color("3b403d")
const TINT_ENERGY := 0.9
const PLATE_GLOW_LIVE := 1.8
const PLATE_GLOW_SLATE := 0.5
const PULSE_DEPTH := 0.14
const PULSE_HZ := 2.0
# The cue lives on the plate's rim, not its faces (Andrew, 2026-09-29): the plate material
# emits through a tiny nearest-filtered mask texture, so light appears only where the mask
# is white (rim, bolts) and body and plate faces keep their resting finish in both states.
# One material, one draw: the mask adds no surface. A mesh with no mask UVs takes the dark
# mask and shows nothing on its faces; its crack glyph carries the cue.
const RIM_CELL := 8
const RIM_EDGE := 2
# The pilot's class colour, set when a run starts. Identity only: no plate cue reads it.
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
# Who is dealing the hit that may kill: "" for every ordinary source, "spark" while a wear
# patch resolves (wear_trail sets it around take_damage). The died handler passes it on.
var last_damage_source := ""
var ringed_out := false
# The height the open knock started from; INF while no knock is open.
var _ring_from := INF
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
var _rim_clock := 0.0
# The open attack instance, or {} between attacks: instance, row, phase, managed, geometry, progress.
var _atk := {}


# The test seam disables only this visual layer, never the enemy's physics loop.
var reactions_enabled := true
var reaction_pivot: Node3D
var _reaction_bus: Node
var _react_row := {}
var _react_time := 0.0
var _react_duration := 0.0
var _react_start := Quaternion.IDENTITY
var _react_pose := Quaternion.IDENTITY
var _react_direction := Vector3.FORWARD
var _react_speed := 0.0
var _reaction_handed := false
var _line_lean := 0.0
var _line_lean_goal := 0.0
var _line_lean_from := 0.0
var _line_lean_time := LINE_EASE
const LINE_LEAN := 10.0
const LINE_EASE := 0.15
# The idle (EnemyMotion, read from this kind's WindupRows row): the pivot's offset now, on
# its own sim clock, which stops while an attack is open.
var idle_offset := Vector3.ZERO
var _idle_pose := Basis.IDENTITY
var _idle_clock := -1.0
var _idle_period := 0.0


func _visual_parent() -> Node3D:
	if reaction_pivot == null:
		reaction_pivot = Node3D.new()
		reaction_pivot.name = "ReactionPivot"
		add_child(reaction_pivot)
	return reaction_pivot


func _ordinary_reaction() -> bool:
	return kind not in ["warden", "vault", "miniboss"] and not preload("res://src/combat/roster.gd").is_boss_piece(kind)


func react(reaction: String, direction: Vector3, handed := false) -> void:
	_reaction_handed = handed
	if not reactions_enabled or _dead or not _ordinary_reaction():
		return
	_react_row = EventKinds.REACTIONS[reaction]
	_react_start = _react_pose
	_react_direction = Vector3(direction.x, 0.0, direction.z).normalized()
	_react_speed = _knocked_speed()
	_react_time = 0.0
	_react_duration = float(_react_row["rise"]) + float(_react_row["hold"]) + float(_react_row["recover"])
	if float(_react_row["tumble"]) > 0.0:
		_react_duration = minf(float(_react_row["limit"]), maxf(_react_duration, _react_speed / KNOCK_DECAY + float(_react_row["recover"])))
	_visual_parent()


# Contacts call strike() directly; _hit() has already handed its row to react().
func _on_reaction_hit(enemy: Node3D, hit: String, _force: float) -> void:
	if enemy != self:
		return
	if _reaction_handed:
		_reaction_handed = false
		return
	var away := _knock if _knocked_speed() > 0.0 else global_position - _reaction_ball()
	react(String(EventKinds.impact(hit)["react"]), away)


func _reaction_ball() -> Vector3:
	# Sight may show a cloak decoy; a held body leans toward the real ball.
	var player = target.get("player") if is_instance_valid(target) and "player" in target else target
	return player.ball_position() if is_instance_valid(player) else global_position


func _on_reaction_line(state: String, held: Node3D, _at: Vector3, _cause: String) -> void:
	if state.begins_with("chain_"):
		return
	if not reactions_enabled or _dead or not _ordinary_reaction():
		return
	if state == "latched_body":
		_set_line_lean(1.0 if held == self else 0.0)
	elif state == "smash_committed":
		if _line_lean_goal != 0.0:
			_set_line_lean(-1.0)
	else:
		_set_line_lean(0.0)


func _set_line_lean(goal: float) -> void:
	if goal == _line_lean_goal:
		return
	_line_lean_from = _line_lean
	_line_lean_goal = goal
	_line_lean_time = 0.0


func _reaction_axis(direction: Vector3) -> Vector3:
	var local := global_basis.inverse() * direction
	var axis := Vector3.UP.cross(local)
	return axis.normalized() if axis.length_squared() > 0.0001 else Vector3.RIGHT


func _update_reaction(delta: float) -> void:
	if not reactions_enabled or not _ordinary_reaction():
		_react_row = {}
		_react_pose = Quaternion.IDENTITY
		_line_lean = 0.0
		_line_lean_goal = 0.0
		_line_lean_from = 0.0
	if not _react_row.is_empty():
		_react_time += delta
		var rise := float(_react_row["rise"])
		var scale_angle := 1.0 / sqrt(maxf(weight, 1.0))
		var axis := _reaction_axis(_react_direction)
		var peak := deg_to_rad(float(_react_row["angle"])) * scale_angle
		if _react_time >= _react_duration:
			_react_pose = Quaternion.IDENTITY
			_react_row = {}
		elif _react_time < rise:
			_react_pose = _react_start.slerp(Quaternion(axis, peak), smoothstep(0.0, rise, _react_time))
		else:
			var recovery := rise + float(_react_row["hold"])
			var progress := clampf((_react_time - recovery) / (_react_duration - recovery), 0.0, 1.0)
			var angle := peak * (1.0 - smoothstep(0.0, 1.0, progress))
			if float(_react_row["tumble"]) > 0.0:
				var knock_share := clampf(_knocked_speed() / maxf(_react_speed, 0.001), 0.0, 1.0)
				angle *= knock_share
				angle += deg_to_rad(float(_react_row["tumble"])) * scale_angle * sin(PI * progress) * knock_share
			elif float(_react_row["overshoot"]) > 0.0:
				var overshoot := -peak * float(_react_row["overshoot"])
				angle = lerpf(peak, overshoot, smoothstep(0.0, 0.72, progress)) if progress < 0.72 else lerpf(overshoot, 0.0, smoothstep(0.72, 1.0, progress))
			_react_pose = Quaternion(axis, angle)
	_line_lean_time = minf(LINE_EASE, _line_lean_time + delta)
	_line_lean = _line_lean_goal if _line_lean_time >= LINE_EASE else lerpf(_line_lean_from, _line_lean_goal, smoothstep(0.0, LINE_EASE, _line_lean_time))
	if reaction_pivot == null and (_line_lean != 0.0 or not _react_row.is_empty()):
		_visual_parent()
	_update_idle(delta)
	if reaction_pivot != null:
		var lean_pose := Quaternion.IDENTITY
		if _line_lean != 0.0 and is_instance_valid(target):
			lean_pose = Quaternion(_reaction_axis(_reaction_ball() - global_position), deg_to_rad(LINE_LEAN) * _line_lean)
		reaction_pivot.transform = Transform3D(Basis(lean_pose * _react_pose) * _idle_pose, idle_offset)


# The model breathes between attacks and holds still (or takes its row's pose) through
# every open attack, so the idle is never read as a telegraph.
func _update_idle(delta: float) -> void:
	idle_offset = Vector3.ZERO
	_idle_pose = Basis.IDENTITY
	if reaction_pivot == null or _dead or not EnemyMotion.active():
		return
	var row: Dictionary = WindupRows.ROWS.get(kind, {})
	if winding_up():
		_idle_pose = EnemyMotion.pose_basis(row)
		return
	if _idle_clock < 0.0:
		_idle_period = float(row.get("idle", {}).get("beats", 0.0)) * EnemyMotion.attack_clock(kind, self)
		_idle_clock = float(absi(hash(Vector3i(global_position.round()))) % 97) / 97.0 * _idle_period
	_idle_clock += delta
	idle_offset = EnemyMotion.idle_offset(row.get("idle", {}), _idle_clock, _idle_period)


# An attack is open: a wind-up or strike instance, a committed telegraph, or the state the
# Warden and swarm remnant publish instead.
func winding_up() -> bool:
	return not _atk.is_empty() or telegraph() != null or not WindupRows.state_facts(self).is_empty()


func _death_direction() -> Vector3:
	var away := Vector3(_knock.x, 0.0, _knock.z)
	if away.length_squared() < 0.01:
		away = global_position - _reaction_ball()
		away.y = 0.0
	return away.normalized() if away.length_squared() > 0.0001 else Vector3.ZERO


# Subclasses call this first from their own setup, then build their body.
func _setup_common(target_ref, terrain_ref, root_ref, live_ref: Callable, spec_ref := {}) -> void:
	target = target_ref
	terrain = terrain_ref
	world_root = root_ref
	live = live_ref
	spec = spec_ref
	_reaction_bus = world_root.get_node_or_null("GameEvents") if world_root != null else null
	if _reaction_bus != null:
		_reaction_bus.line_state_changed.connect(_on_reaction_line)
		_reaction_bus.enemy_struck.connect(_on_reaction_hit)
	add_to_group("enemy")
	collision_layer = 0
	collision_mask = 0
	set_collision_layer_value(3, true)
	set_collision_mask_value(1, true)
	floor_max_angle = deg_to_rad(60.0)
	if has_signal("released"):
		connect("released", _facts_on_released)


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
		_paint_plate(mat as StandardMaterial3D, state)
	for crack in _cracks:
		if is_instance_valid(crack):
			crack.visible = now
	_rim_clock = 0.0
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
# The break-up (EnemyMotion.scatter) lives in its own detached node and frees itself.
func _die() -> void:
	_dead = true
	_facts_end(true)
	collision_layer = 0
	collision_mask = 0
	_clear_telegraph()
	EnemyMotion.scatter(self, kind, _death_direction())
	died.emit(global_position, scrap_value)
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_reaction_bus) and _reaction_bus.line_state_changed.is_connected(_on_reaction_line):
		_reaction_bus.line_state_changed.disconnect(_on_reaction_line)
	if is_instance_valid(_reaction_bus) and _reaction_bus.enemy_struck.is_connected(_on_reaction_hit):
		_reaction_bus.enemy_struck.disconnect(_on_reaction_hit)
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
	var grounded := is_on_floor()
	move_and_slide()
	if is_on_floor() and velocity.y < 0.0:
		velocity.y = 0.0
	_knock = _knock.move_toward(Vector3.ZERO, KNOCK_DECAY * delta)
	if _rings_out(grounded):
		return
	_rescue()


func _knocked_speed() -> float:
	return Vector3(_knock.x, 0.0, _knock.z).length()


# A knock opens the fall when it strikes an enemy standing on a floor, and the fall closes
# once the enemy is back on a floor with the knock spent. Being in the air RING_OUT_DROP
# below the floor it was knocked from, over ground at least that far down, is a ring-out:
# off an edge the ground falls away under it, while down a slope or a ramp it stays close. Returns true when this tick rang the enemy out.
func _rings_out(grounded: bool) -> bool:
	if _dead or not ring_outs_here():
		_ring_from = INF
		return false
	var knocked := _knocked_speed() >= 1.0
	if _ring_from == INF:
		if knocked and grounded:
			_ring_from = global_position.y
		return false
	var floor_line := _ring_from - RING_OUT_DROP
	if not is_on_floor() and global_position.y < floor_line \
			and terrain.height(global_position.x, global_position.z) + half_height < floor_line:
		ring_out()
		return true
	if is_on_floor() and not knocked:
		_ring_from = INF
	return false


# A throw that moves the enemy itself (Tarn's tow and hurl) opens the fall from where it
# stood, the way a knock would.
func open_ring_out() -> void:
	if _ring_from == INF and is_on_floor():
		_ring_from = global_position.y


func ring_outs_here() -> bool:
	return terrain != null and terrain.has_method("world") and terrain.world() == RING_OUT_WORLD \
		and not kind in RING_OUT_KEPT and not preload("res://src/combat/roster.gd").is_boss_piece(kind)


# Knocked off the edge: a kill the pilot earned, whatever health or plating was left.
func ring_out() -> void:
	if _dead:
		return
	ringed_out = true
	last_damage_source = "ring_out"
	if _reaction_bus != null and _reaction_bus.has_signal("enemy_ringed_out"):
		_reaction_bus.enemy_ringed_out.emit(kind, global_position)
	hp = 0.0
	_die()


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
		_material.emission = EventKinds.role_color("neutral")
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
	_visual_parent().add_child(mesh)
	return mesh


# A visual-only accent: a lit mesh that grows an enemy's silhouette or marks it from
# 60 to 100 m. It never collides; the enemy's collider is unchanged.
func _accent(mesh: Mesh, color: Color, energy: float, at: Vector3, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = Palette.solid(color, energy)
	instance.position = at
	(_visual_parent() if parent == self else parent).add_child(instance)
	return instance


# A tinted material for a plating mesh, registered so set_tint recolours it.
# `rim_mask` is the emission mask: rim_frame_mask() for BoxMesh plates, a mesh-specific
# mask where the mesh carries its own UVs. With no mask the plates are BoxMesh (miniboss,
# vault), so they get the frame mask; only the mind hand's round bone stays dark.
func _plate_material(rim_mask: Texture2D = null) -> StandardMaterial3D:
	if rim_mask == null and not _plates_are_round():
		rim_mask = rim_frame_mask()
	var mat := Palette.solid(PLATE_CLOSED)
	mat.metallic = 0.6
	mat.roughness = 0.4
	mat.emission_texture = rim_mask if rim_mask != null else mask_texture([Color.BLACK], 1)
	# Multiply, not the default add: the colour must only show where the mask is white.
	mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_paint_plate(mat, "")
	_tint_materials.append(mat)
	return mat


# The mind hand's plate bone is a cylinder; the box frame mask would stripe it.
func _plates_are_round() -> bool:
	var script := get_script() as Script
	return script != null and script.resource_path.get_file() == "mind_hand.gd"


# Plating carries its read in light, not just paint, so it survives distance and shade:
# the live rim burns (your punch breaks through now), a slate rim holds (it would glance),
# and no state leaves the plates at rest. The resting finish stays in every state; the
# state arrives as light through the mask.
static func _paint_plate(mat: StandardMaterial3D, state: String) -> void:
	mat.albedo_color = PLATE_CLOSED
	mat.emission_enabled = state == "amber" or state == "slate"
	if state == "amber":
		mat.emission = EventKinds.state_color("will_break")
		mat.emission_energy_multiplier = PLATE_GLOW_LIVE
	elif state == "slate":
		mat.emission = EventKinds.state_color("glancing")
		mat.emission_energy_multiplier = PLATE_GLOW_SLATE
	else:
		mat.emission = PLATE_CLOSED
		mat.emission_energy_multiplier = 0.0


static func _pulses() -> bool:
	return String(EventKinds.state_row("will_break").get("motion", "none")) == "pulse"


# The will_break row pulses at 2 Hz (LINE_ROWS' brackets beat the same).
func _pulse_rim(delta: float) -> void:
	_rim_clock += delta
	var swing := 1.0 + PULSE_DEPTH * sin(TAU * PULSE_HZ * _rim_clock)
	for mat in _tint_materials:
		(mat as StandardMaterial3D).emission_energy_multiplier = PLATE_GLOW_LIVE * swing


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


# An open-crack glyph on a plate: a lit zigzag in the live colour, shown only while
# the plate breaks now. Visual only; parented to the plate so it moves with it.
func _add_crack(parent: Node3D, at: Vector3, size := 0.9) -> Node3D:
	var glyph := Node3D.new()
	glyph.position = at
	var mat := Palette.unshaded(EventKinds.state_color("will_break"))
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
		_update_reaction(get_physics_process_delta_time())
		_facts_poll()
		if tint_state == "amber" and _pulses():
			_pulse_rim(get_physics_process_delta_time())


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


# The lobber has no telegraph until release, so its wind-up is its public charge, and
# its aim stays uncommitted (empty geometry) until released.
func _facts_poll_lobber() -> void:
	var charge: float = get("charge")
	if _atk.is_empty():
		if charge > 0.0 and _in_play():
			_facts_begin_lobber(charge)
	elif _atk["phase"] == PHASE_WINDUP:
		if charge <= 0.0:
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


# The release is the strike. The lobber hands over the descriptor of the ring its shell
# just committed (the shell's own Telegraph builds it), so the strike is committed with
# that geometry; then recover in the same tick, since the shell's flight belongs to the
# projectile. An empty ring (no shell was made) leaves the strike uncommitted.
func _facts_on_released(ring: Dictionary) -> void:
	if _dead:
		return
	if _atk.is_empty():
		_facts_begin_lobber(1.0)
	if _atk.is_empty():
		return
	_atk["progress"] = 0.0
	_atk["geometry"] = ring.duplicate()
	_facts_phase(PHASE_STRIKE)
	_facts_end(false)
