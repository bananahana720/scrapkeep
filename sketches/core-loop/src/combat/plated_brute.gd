extends "res://src/combat/counter.gd"

const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const SwingArc := preload("res://src/combat/swing_arc.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")

# The plated brute (DESIGN-V2 section 10): a mini-Warden, bolted plate layers visibly
# one layer more than any other crew. It keeps the Warden's plating grammar (a punch
# below its plating chips 20%, the class-colour rim and open crack say "breaks now")
# with one extra rule: its outer plate takes the first breaking hit whole and pops off,
# so the body takes only the second. It walks you down and slams the ground around
# itself: an instant ring that knocks you out of it. It holds nothing; as the
# director's punisher it lands on a ball a controller is holding.
#
# A pilot latched on a line is out of the slam's reach, so the brute hurls a plate: when the
# line stands and the ball is HURL_MIN or more above the ground, it commits an aerial ring
# (telegraph.gd aerial_ring) at the swing arc's forecast (swing_arc.gd) over its warn, within
# HURL_RANGE on the flat. The band is HURL_BAND tall, the same geometry it draws and hits with.

const PLATING_SCALE := 0.6
const SLAM_RADIUS := 6.0
const SLAM_RANGE := 6.5
const SLAM_DAMAGE := 12.0
const SLAM_SHOVE := 9.0
const HP := 110.0
const HURL_RANGE := 22.0
const HURL_MIN := 3.0
# A thrown plate climbs about as far as it flies on the flat (22 m out, 20 m up is a steep lob);
# a pilot latched higher than that over the brute is out of its throw.
const HURL_MAX_UP := 20.0
const HURL_RADIUS := 3.0
const HURL_BAND := 5.0
const HURL_LOB := 4.0
const HURL_DAMAGE := 10.0
const HURL_SHOVE := 5.0
# Secondary attack (W47-E1): Bulldoze Shield-Charge. Triggered when the player orbits 7-16 m
# after a slam. 0.85 s horn + front stoplog drop commits a 16 m HAZARD ram lane; baiting it
# into a Heft Destructible, pillar/wall, or another Brute opens shortcuts at ANY heft and
# strips the outer plate immediately.
const CHARGE_WARN := 0.85
const CHARGE_MIN_RANGE := 7.0
const CHARGE_MAX_RANGE := 16.0
const CHARGE_LENGTH := 16.0
const CHARGE_WIDTH := 3.4
const CHARGE_SPEED := 24.0
const CHARGE_TIME := CHARGE_LENGTH / CHARGE_SPEED
const CHARGE_DAMAGE := 18.0
const CHARGE_SHOVE := 11.0
const CHARGE_HIT_REACH := 2.4
const CHARGE_BREAK_RADIUS := 3.2
const CHARGE_PAD_DROP := -0.35
const CHARGE_LEAN_ANGLE := 18.0
const SLAM_WARN := 1.1
const SLAM_LIVE := 0.15

var plates := 1
var plates_popped := 0
var slams := 0
var charges := 0
var charge_crashes := 0
var last_crash_cause := ""
var landed_attack := ""
var slam_shove := SLAM_SHOVE
var affix := {}
var affix_attacks := 0
var _affix_attack := false
var hurls := 0
var _hurl := false
var _next_affix := true
var _charging := false
var _charge_primed := false
var _charge_dir := Vector3.FORWARD
var _charge_hit_player := false
var _charge_crashed := false
# A hauler bounty's brute (world/activities.gd): it stands at bounty_home until the ball comes
# within bounty_wake or it is hit, follows the ball while the ball is within bounty_leash of
# home, and walks back at bounty_return_speed once the ball is further. Unset, it is an
# ordinary brute.
var bounty_home := Vector3.INF
var bounty_wake := 30.0
var bounty_leash := 40.0
var bounty_return_speed := 9.0
var bounty_woken := false
# Whether the ball has ever woken it. It falls asleep again each time it walks home, so a ball
# shooting it from beyond its leash wakes it with every bolt; what reads "the player has met this
# hauler" (the objective plate, through world/activities.gd at_hand) reads this.
var bounty_met := false
var _crate: MeshInstance3D
var _absorb := false
var _plate: MeshInstance3D
# Visual-only seam for the seeded physics control.
var windup_pose_enabled := true
var _windup_rig: Skeleton3D
var _pad_bones: Array[int] = []
var _rear_bone := -1
const PAD_RISE := 2.5
const REAR_ANGLE := -30.0
const PAD_DROP_SECONDS := 0.08
const PAD_PLANT := -0.47


func _configure(threat: float) -> void:
	_set_health(HP * threat)
	plating = float(spec.get("plating", 24.0))
	scrap_value = 8
	weight = 3.0
	walk_speed = 3.2
	keep_near = 3.0
	keep_far = 30.0
	attack_range = SLAM_RANGE
	warn_seconds = 1.1
	live_seconds = 0.15
	rest_seconds = 2.8
	interruptible = false
	affix = EliteAffixes.row(String(spec.get("affix", "")))
	if not affix.is_empty():
		var step := clampi(int(spec.get("affix_world", 1)), 1, 3) - 1
		for stat in affix.stats:
			set(stat, affix.stats[stat][step])
		set_meta("enemy_name", affix.name)
		set_meta("elite_affix", String(spec.affix))
		set_meta("elite_stat", {"id": affix.stat, "value": get(affix.stat), "world": step + 1})


# C15 dressing (enemy_plated_brute.glb). The counter's capsule crew is replaced by the glb's
# body (the collider _add_capsule laid stays) and the plate slab and pads by one plate group
# (front slab, shoulder and rear cladding) that shows exactly while plates > 0. The glb is read
# once; every brute shares its meshes and adds only its own flashing body material as a surface
# override and its own tinted plate material.
static var _warned_asset := false
static var _shared: Dictionary = {}

# The crack glyph sits on the slab's face (front face at z = 1.35), 0.07 m off it so its strokes
# clear the face and the lit bolts, centred between the two ribs and under the brow lip. Sized
# 1.5 so it reads at asset-front30 (about 40 px tall) and at asset-use6.
const GLYPH_AT := Vector3(0.0, -0.05, 1.42)
const GLYPH_SIZE := 1.5


func _build_tool() -> void:
	_crew.free()
	var parts := _parts()
	_windup_rig = parts["rig"].instantiate() as Skeleton3D
	_visual_parent().add_child(_windup_rig)
	for bone_name in ["SlamPadLeft", "SlamPadRight"]:
		_pad_bones.append(_windup_rig.find_bone(bone_name))
	_rear_bone = _windup_rig.find_bone("BruteRear")
	_crew = MeshInstance3D.new()
	_crew.name = "BruteBody"
	_crew.mesh = parts["body"]
	_crew.set_surface_override_material(parts["flash"], _material)
	_visual_parent().add_child(_crew)
	_crew.skin = parts["skin"]
	_crew.skeleton = _crew.get_path_to(_windup_rig)
	_plate = MeshInstance3D.new()
	_plate.name = "BrutePlates"
	_plate.mesh = parts["plates"]
	_plate.material_override = _plate_material(_rim_mask())
	_visual_parent().add_child(_plate)
	_add_crack(_plate, GLYPH_AT, GLYPH_SIZE).name = "PlateCrack"


static func _parts() -> Dictionary:
	if not _shared.is_empty():
		return _shared
	var scene := (load("res://assets/models/world_one/enemy_plated_brute.glb") as PackedScene).instantiate()
	var charcoal := Palette.solid(Palette.CHARCOAL)
	var painted := Palette.solid(Color.WHITE)
	painted.vertex_color_use_as_albedo = true
	var flash := -1
	var meshes := {}
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = (node as MeshInstance3D).mesh.duplicate()
		for i in mesh.get_surface_count():
			var surface_material := mesh.surface_get_material(i)
			if surface_material == null and not _warned_asset:
				_warned_asset = true
				push_warning("plated_brute: surface has no material; using default finish")
			var slot := surface_material.resource_name if surface_material != null else ""
			if slot == "fleet_paint":
				flash = i
			mesh.surface_set_material(i, painted if slot == "paint" else charcoal)
		meshes[node.name] = mesh
	if flash < 0:
		if not _warned_asset:
			_warned_asset = true
			push_warning("enemy_plated_brute.glb has no fleet_paint surface; using default finish")
		flash = 0
	meshes["BrutePlates"] = _mask_uvs(meshes["BrutePlates"])
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var source := scene.find_child("BruteBody", true, false) as MeshInstance3D
	var skin := source.skin
	# Cache only the rest rig; the live body and plate keep their existing names/parents.
	for child in rig.get_children():
		child.free()
	rig.get_parent().remove_child(rig)
	var packed_rig := PackedScene.new()
	packed_rig.pack(rig)
	rig.free()
	_shared = {"body": meshes["BruteBody"], "plates": meshes["BrutePlates"], "flash": flash, "rig": packed_rig, "skin": skin}
	scene.free()
	return _shared


# The amber cue's mask. The recipe paints the plate's rim and bolts vertex-colour black;
# each vertex's UV is moved to the lit texel (right) or the dark one (left) of a 2x1 mask,
# so the emission lands on the rim and bolts of the one plate surface.
static var _mask: ImageTexture


static func _rim_mask() -> ImageTexture:
	if _mask == null:
		_mask = mask_texture([Color.BLACK, Color.WHITE], 2)
	return _mask


static func _mask_uvs(mesh: ArrayMesh) -> ArrayMesh:
	var out := ArrayMesh.new()
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var uvs := PackedVector2Array()
		for c in colors:
			uvs.append(Vector2(0.25 if c.r > 0.5 else 0.75, 0.5))
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(i, mesh.surface_get_material(i))
	return out


func _wants_attack(to_ball: Vector3) -> bool:
	if is_bounty() and (not bounty_woken or _homeward(to_ball)):
		return false
	return (to_ball.length() <= attack_range or _can_hurl(to_ball) or _can_charge(to_ball)) and is_on_floor()


func is_charging() -> bool:
	return _charging and phase != Phase.ROAM


# Secondary attack trigger: player orbits 7-16 m away after a primary slam.
func _can_charge(to_ball: Vector3) -> bool:
	if not _charge_primed or not is_on_floor():
		return false
	var dist := Vector2(to_ball.x, to_ball.z).length()
	return dist >= CHARGE_MIN_RANGE and dist <= CHARGE_MAX_RANGE


# The ball hangs on a line, above the slam and inside the hurl's flat range.
func _can_hurl(to_ball: Vector3) -> bool:
	var player = _player()
	if player == null or not player.kit.hooked:
		return false
	# to_ball is flat; the ball's own height is what the slam cannot reach.
	var ball := _real_ball()
	var ground: float = terrain.height(ball.x, ball.z) if terrain != null else 0.0
	return ball.y - ground >= HURL_MIN and ball.y - global_position.y <= HURL_MAX_UP \
		and Vector2(to_ball.x, to_ball.z).length() <= HURL_RANGE


func is_bounty() -> bool:
	return bounty_home != Vector3.INF


# Marks this brute as the bounty: the crate on its back wears the activity colour, apart from
# its plates, so the plate cue still reads.
func carry_bounty(home: Vector3, color: Color) -> void:
	bounty_home = home
	# The crew's cache chest and lid (CrackedCache's model) in the bounty's glowing colour, about 1.4 by 1.1 by
	# 1.4 m, riding the brute's back; a plain box when the model is missing.
	var glow := Palette.solid(color, 1.6)
	_crate = CrackedCache.model_part("CacheChest", self)
	if _crate != null:
		_crate.transform = Transform3D(Basis.from_scale(Vector3(0.7, 0.73, 0.95)), Vector3(0.0, 2.35, -0.5))
		var lid := CrackedCache.model_part("CacheLid", _crate)
		lid.position = Vector3.UP * 1.35
		lid.material_override = glow
	else:
		_crate = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.4, 1.1, 1.4)
		_crate.mesh = bm
		_crate.position = Vector3(0.0, 2.9, -0.5)
		add_child(_crate)
	_crate.name = "BountyCrate"
	_crate.material_override = glow


# The ball is out of the leash, or the brute has been walked off by it and now heads home.
func _homeward(to_ball: Vector3) -> bool:
	var ball := global_position + to_ball
	var out := Vector2(ball.x - bounty_home.x, ball.z - bounty_home.z).length()
	return out > bounty_leash


func _roam(to_ball: Vector3) -> Vector3:
	if not is_bounty():
		return super(to_ball)
	if not bounty_woken and to_ball.length() <= bounty_wake:
		bounty_woken = true
		bounty_met = true
	if not bounty_woken:
		return Vector3.ZERO
	if _homeward(to_ball):
		var back := bounty_home - global_position
		back.y = 0.0
		if back.length() <= 2.0:
			bounty_woken = false
			return Vector3.ZERO
		return back.normalized() * bounty_return_speed
	return super(to_ball)


func _commit(to_ball: Vector3) -> Node3D:
	_facing(to_ball)
	_charging = false
	_charge_hit_player = false
	_charge_crashed = false
	_hurl = _can_hurl(to_ball)
	if _hurl:
		warn_seconds = SLAM_WARN
		live_seconds = SLAM_LIVE
		_affix_attack = false
		var aim: Vector3 = SwingArc.forecast(_player(), warn_seconds)
		_clear_telegraph()
		_telegraph = Telegraph.aerial_ring(world_root, terrain, Threat.Type.PROJECTILE,
			aim - Vector3.UP * HURL_BAND * 0.5, HURL_RADIUS, HURL_BAND)
		_telegraph.set_flight(global_position + Vector3.UP * 2.5, HURL_LOB)
		_facts_begin(_telegraph)
		return _telegraph
	_affix_attack = not affix.is_empty() and _next_affix
	if not affix.is_empty():
		_next_affix = not _next_affix
		warn_seconds = float(affix.warn_seconds) if _affix_attack else SLAM_WARN
	if _affix_attack:
		live_seconds = SLAM_LIVE
		match String(affix.behaviour):
			"target_stamp":
				return _commit_ring(Threat.Type.INSTANT, _ball(), affix.radius, affix.reach)
			"rail_strike":
				return _commit_lane(Threat.Type.LANE, global_position, to_ball, affix.length, affix.width, affix.reach)
			"rear_blast":
				return _commit_ring(Threat.Type.INSTANT, global_position - global_basis.z * float(affix.offset), affix.radius, affix.reach)
	if _can_charge(to_ball):
		_charging = true
		_charge_primed = false
		warn_seconds = CHARGE_WARN
		live_seconds = CHARGE_TIME
		var flat := Vector3(to_ball.x, 0.0, to_ball.z)
		_charge_dir = flat.normalized() if flat.length() > 0.05 else Vector3.FORWARD
		_clear_telegraph()
		_telegraph = Telegraph.secondary_lane(world_root, terrain, Threat.Type.LANE, global_position, _charge_dir, CHARGE_LENGTH, CHARGE_WIDTH, CHARGE_WARN, 2.6)
		_telegraph.run_body(0.0, CHARGE_HIT_REACH)
		_facts_begin(_telegraph)
		return _telegraph
	warn_seconds = SLAM_WARN
	live_seconds = SLAM_LIVE
	return _commit_ring(Threat.Type.INSTANT, global_position, SLAM_RADIUS, 2.2)


func _voice(tele: Node3D) -> void:
	super(tele)
	if _affix_attack:
		tele.mechanic_tag = String(affix.mechanic_tag)
		tele.warn_seconds = float(affix.warn_seconds)
	elif _charging:
		tele.mechanic_tag = "klaxon"
		tele.warn_seconds = CHARGE_WARN


func _go_live() -> void:
	if _hurl:
		hurls += 1
		landed_attack = "plate_hurl"
		var thrown := telegraph()
		var target_ball := _real_ball()
		if thrown == null or not thrown.contains(target_ball):
			return
		var away: Vector3 = target_ball - thrown.center
		away.y = 0.0
		var heading := away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(HURL_DAMAGE, heading * HURL_SHOVE + Vector3.DOWN * 2.0)
		return
	if _charging:
		charges += 1
		landed_attack = "shield_charge"
		if world_root != null and is_inside_tree():
			FxLibrary.burst(world_root, "steam_puff", global_position, 6)
		return
	if _affix_attack:
		affix_attacks += 1
		landed_attack = String(affix.behaviour)
	else:
		slams += 1
		_charge_primed = true
		landed_attack = "slam"
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var out: Vector3 = ball - (ring.center if _affix_attack else global_position)
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	hit_player.emit(float(affix.damage) if _affix_attack else SLAM_DAMAGE, dir * slam_shove + Vector3.UP * 3.0)


func _live_motion(_to_ball: Vector3) -> Vector3:
	if _charging and not _charge_crashed:
		return _charge_dir * CHARGE_SPEED
	return Vector3.ZERO


func _live(_delta: float) -> bool:
	if not _charging:
		return true
	var lane := telegraph()
	if lane == null or _charge_crashed:
		return false
	var along: float = (global_position - lane.center).dot(lane.dir)
	lane.run_body(along, CHARGE_HIT_REACH)
	if not _charge_hit_player:
		var ball := _real_ball()
		var flat := Vector3(ball.x - global_position.x, 0.0, ball.z - global_position.z)
		if flat.length() <= CHARGE_HIT_REACH and lane.contains(ball):
			_charge_hit_player = true
			landed_attack = "shield_charge"
			hit_player.emit(CHARGE_DAMAGE, _charge_dir * CHARGE_SHOVE + Vector3.UP * 3.0)
	if along >= 2.0 and (_try_break_destructible() or _try_crash_brute() or _try_crash_wall()):
		return false
	return along < lane.length


func _on_end() -> void:
	_charging = false
	_charge_hit_player = false
	_charge_crashed = false
	warn_seconds = SLAM_WARN
	live_seconds = SLAM_LIVE


func _destructibles() -> Node:
	if fleet != null and fleet.ctx != null and is_instance_valid(fleet.ctx.destructibles):
		return fleet.ctx.destructibles
	if world_root != null and is_instance_valid(world_root):
		for child in world_root.get_children():
			if child.has_method("on_blast") and child.has_method("intact_count"):
				return child
	return null


# Baiting the Bulldoze Shield-Charge into any Heft Destructible smashes the shortcut open
# at ANY player heft (heft class 5) and strips the Brute's outer plate immediately.
func _try_break_destructible() -> bool:
	var props := _destructibles()
	if props == null:
		return false
	var before := int(props.intact_count())
	if before <= 0:
		return false
	props.on_blast(global_position + _charge_dir * 1.4, CHARGE_BREAK_RADIUS, "brute_charge", 0, 5)
	if int(props.intact_count()) < before:
		_on_charge_crash("destructible")
		return true
	return false


func _try_crash_brute() -> bool:
	if not is_inside_tree():
		return false
	for other in get_tree().get_nodes_in_group("enemy"):
		if other == self or not is_instance_valid(other) or other.is_dead() or other.kind != "plated_brute":
			continue
		var to_other: Vector3 = other.global_position - global_position
		var flat := Vector3(to_other.x, 0.0, to_other.z)
		if flat.length() <= radius + float(other.radius) + 1.4 and flat.dot(_charge_dir) > 0.0:
			if other.has_method("strip_outer_plate"):
				other.strip_outer_plate()
			other.knock(_charge_dir, 14.0)
			if "stun_left" in other:
				other.stun_left = maxf(float(other.stun_left), STAGGER_WINDOW)
			_on_charge_crash("brute")
			return true
	return false


func _try_crash_wall() -> bool:
	for i in get_slide_collision_count():
		var hit := get_slide_collision(i)
		if not BallRules.world_face(hit.get_collider()):
			continue
		var n := hit.get_normal()
		if n.angle_to(Vector3.UP) <= floor_max_angle:
			continue
		var flat_n := Vector3(n.x, 0.0, n.z)
		if flat_n.length_squared() < 0.01:
			continue
		if -_charge_dir.dot(flat_n.normalized()) >= 0.70:
			_on_charge_crash("wall")
			return true
	return false


func strip_outer_plate() -> bool:
	if plates <= 0:
		return false
	plates = 0
	plates_popped += 1
	if _plate != null:
		_fling_plate()
		_plate.visible = false
	if fleet != null:
		fleet.discover("plate_peel", global_position)
	return true


func _on_charge_crash(cause: String) -> void:
	_charge_crashed = true
	charge_crashes += 1
	last_crash_cause = cause
	strip_outer_plate()
	stun_left = maxf(stun_left, STAGGER_WINDOW)
	staggers += 1
	if world_root != null and is_inside_tree():
		FxLibrary.burst(world_root, "brass_spark", global_position + _charge_dir * 1.2, 16)
		FxLibrary.burst(world_root, "steam_puff", global_position, 8)


class FlungPlate extends Node3D:
	const LIFE := 0.72
	const GRAVITY := 24.0
	var vel := Vector3.ZERO
	var spin := Vector3.ZERO
	var floor_y := -INF
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		vel.y -= GRAVITY * delta
		global_position += vel * delta
		if global_position.y < floor_y:
			global_position.y = floor_y
			vel.y = absf(vel.y) * 0.35
			vel.x *= 0.65
			vel.z *= 0.65
		rotation += spin * delta * EnemyMotion.motion_scale
		var fade := clampf((_t - LIFE * 0.55) / (LIFE * 0.45), 0.0, 1.0)
		var s := maxf(0.01, 1.0 - fade)
		scale = Vector3.ONE * s
		if _t >= LIFE:
			queue_free()


func _fling_plate() -> void:
	if _plate == null or world_root == null or not is_inside_tree():
		return
	var at := _plate.global_position
	FxLibrary.burst(world_root, "brass_spark", at, 14)
	FxLibrary.burst(world_root, "plate_chunks", at, 10)
	if _plate.mesh == null or _plate.mesh is PrimitiveMesh:
		return
	var flung := FlungPlate.new()
	flung.name = "FlungBrutePlate"
	world_root.add_child(flung)
	flung.global_transform = _plate.global_transform
	var view := MeshInstance3D.new()
	view.name = "PlateShard"
	view.mesh = _plate.mesh
	view.material_override = _plate.material_override
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flung.add_child(view)
	var out := global_position - _real_ball()
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else -global_basis.z
	flung.vel = dir * 9.5 + Vector3.UP * 8.5 + global_basis.x * 2.5
	flung.spin = Vector3(11.0, 6.5, -8.0)
	if terrain != null and terrain.has_method("height"):
		flung.floor_y = float(terrain.height(at.x, at.z)) + 0.15


func on_struck(_kind: String, _part: String, result: Dictionary) -> void:
	bounty_woken = true
	bounty_met = true
	if result.get("full", false) and plates == 0 and plates_popped > 0 and fleet != null:
		fleet.discover("plate_peel", global_position)
	if result.get("full", false) and plates > 0:
		plates -= 1
		plates_popped += 1
		_absorb = true
		if _plate != null:
			_fling_plate()
			_plate.visible = false


# True when on_struck will pop a plate for this hit, so it removes nothing (combat marks the
# result "absorbed" before the hit is announced, and no damage number rises for it).
func absorbs_hit(result: Dictionary) -> bool:
	return bool(result.get("full", false)) and plates > 0


# The popped plate took that hit whole: the body is untouched this once.
func take_damage(amount: float) -> float:
	if _absorb:
		_absorb = false
		flash()
		return 0.0
	return super.take_damage(amount)


# E09 e09_pads_raise: glTF joint nodes preserve the body's two surfaces. Every value reads the counter's clock; no tween, timer or pivot write.
# During Bulldoze Shield-Charge, pads drop forward-low (front stoplog drop) and the torso leans into the ram.
func _pose() -> void:
	if _windup_rig == null:
		return
	var lift := 0.0
	var rear := 0.0
	var lean_deg := REAR_ANGLE
	if windup_pose_enabled and not is_dead() and _in_play():
		if _charging:
			lean_deg = CHARGE_LEAN_ANGLE
			if phase == Phase.WARN:
				var progress := smoothstep(0.0, 1.0, clampf(_warn_progress(), 0.0, 1.0))
				lift = (CHARGE_PAD_DROP / PAD_RISE) * progress
				rear = progress
			elif phase == Phase.LIVE:
				lift = CHARGE_PAD_DROP / PAD_RISE
				rear = 1.0
		elif phase == Phase.WARN:
			var progress := clampf(_warn_progress(), 0.0, 1.0)
			lift = progress * progress
			rear = lift
		elif phase == Phase.LIVE:
			# LIVE starts at t=0 on the release frame, so that frame is full pose.
			rear = 1.0 - clampf(_t / PAD_DROP_SECONDS, 0.0, 1.0)
			lift = lerpf(PAD_PLANT / PAD_RISE, 1.0, rear)
	# Rigid weights make each pad's complete arm/fist travel together in enemy space.
	for bone in _pad_bones:
		var rest := _windup_rig.get_bone_rest(bone)
		_windup_rig.set_bone_pose_position(bone, rest.origin + Vector3.UP * PAD_RISE * lift)
	var rear_rest := _windup_rig.get_bone_rest(_rear_bone)
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(lean_deg) * rear)
	_windup_rig.set_bone_pose_rotation(_rear_bone, (tilt * rear_rest.basis).get_rotation_quaternion())
