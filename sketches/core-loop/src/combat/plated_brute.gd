extends "res://src/combat/counter.gd"

const EliteAffixes := preload("res://src/combat/elite_affixes.gd")
const SwingArc := preload("res://src/combat/swing_arc.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")

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

var plates := 1
var plates_popped := 0
var slams := 0
var slam_shove := SLAM_SHOVE
var affix := {}
var affix_attacks := 0
var _affix_attack := false
var hurls := 0
var _hurl := false
var _next_affix := true
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
	return (to_ball.length() <= attack_range or _can_hurl(to_ball)) and is_on_floor()


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
	_hurl = _can_hurl(to_ball)
	if _hurl:
		warn_seconds = 1.1
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
		warn_seconds = float(affix.warn_seconds) if _affix_attack else 1.1
	if _affix_attack:
		match String(affix.behaviour):
			"target_stamp":
				return _commit_ring(Threat.Type.INSTANT, _ball(), affix.radius, affix.reach)
			"rail_strike":
				return _commit_lane(Threat.Type.LANE, global_position, to_ball, affix.length, affix.width, affix.reach)
			"rear_blast":
				return _commit_ring(Threat.Type.INSTANT, global_position - global_basis.z * float(affix.offset), affix.radius, affix.reach)
	return _commit_ring(Threat.Type.INSTANT, global_position, SLAM_RADIUS, 2.2)


func _voice(tele: Node3D) -> void:
	super(tele)
	if _affix_attack:
		tele.mechanic_tag = String(affix.mechanic_tag)
		tele.warn_seconds = float(affix.warn_seconds)


func _go_live() -> void:
	if _hurl:
		hurls += 1
		var thrown := telegraph()
		var target_ball := _real_ball()
		if thrown == null or not thrown.contains(target_ball):
			return
		var away: Vector3 = target_ball - thrown.center
		away.y = 0.0
		var heading := away.normalized() if away.length() > 0.1 else Vector3.FORWARD
		hit_player.emit(HURL_DAMAGE, heading * HURL_SHOVE + Vector3.DOWN * 2.0)
		return
	if _affix_attack:
		affix_attacks += 1
	else:
		slams += 1
	var ring := telegraph()
	var ball := _real_ball()
	if ring == null or not ring.contains(ball):
		return
	var out: Vector3 = ball - (ring.center if _affix_attack else global_position)
	out.y = 0.0
	var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
	hit_player.emit(float(affix.damage) if _affix_attack else SLAM_DAMAGE, dir * slam_shove + Vector3.UP * 3.0)


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
func _pose() -> void:
	if _windup_rig == null:
		return
	var lift := 0.0
	var rear := 0.0
	if windup_pose_enabled and not is_dead() and _in_play():
		if phase == Phase.WARN:
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
	var tilt := Basis(Vector3.RIGHT, deg_to_rad(REAR_ANGLE) * rear)
	_windup_rig.set_bone_pose_rotation(_rear_bone, (tilt * rear_rest.basis).get_rotation_quaternion())
