extends Node

const AppShell := preload("res://src/core/app_shell.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const Comfort := preload("res://src/core/comfort.gd")


const DIR := "res://assets/models/world_one/clips/"
const CLIPS := ["idle", "move", "windup", "attack", "hit", "death"]
const HARD := ["windup", "attack", "hit", "death"]
const BLEND := 0.15
const MOVE_MIN := 0.8
const JOINT_PREFIX := "Clip_"

const ROWS := {
	"chaser": {"stride": 2.2, "parts": {"body": ["ChaserBody/ChaserBody"], "fin": ["ChaserBody/ChaserFin"],
		"claws": ["ChaserBody/ChaserClaws"]}},
	"lobber": {"stride": 1.6, "parts": {"body": ["LobberBody"], "barrel": ["LobberBody/LobberBarrel"], "bulb": ["LobberBulb"]}},
	"mag_trapper": {"stride": 1.8, "parts": {"cart": ["MagTrapperBody/Cart"], "stack": ["MagTrapperBody/MagStack"]}},
	"plated_brute": {"stride": 1.5, "parts": {"body": ["BruteBody", "BrutePlates"]},
		"bones": {"feet": ["Skeleton3D", "BruteFeet", "prs"], "pad_l": ["Skeleton3D", "SlamPadLeft", "rs"],
			"pad_r": ["Skeleton3D", "SlamPadRight", "rs"]}},
	"winch_drone": {"stride": 2.4, "parts": {"body": ["WinchBody"], "drum": ["WinchBody/WinchDrum"], "rotor": ["WinchBody/WinchRotor"]}},
	"jolt_layer": {"stride": 1.8, "parts": {"body": ["JoltBody"], "coil": ["JoltCoil"]}},
	"hooker": {"stride": 1.8, "parts": {"body": ["HookerBody/Body"], "harpoon": ["HookerBody/HookerHarpoon"]}},
	"ramp_flipper": {"stride": 1.8, "parts": {"body": ["RampBody"]}},
	"boom_tender": {"stride": 2.4, "parts": {"hull": ["BoomTenderBody/TenderHull"], "reel": ["BoomTenderBody/TenderReel"],
		"boom": ["BoomTenderBody/Boom"]}},
	"netcaster": {"stride": 1.8, "parts": {"body": ["NetcasterBody/Body", "NetcasterNet"]}},
	"bola_thrower": {"stride": 1.8, "parts": {"body": ["BolaThrowerBody"], "bola": ["BolaLoop"]}},
	"swatter": {"stride": 1.8, "parts": {"body": ["SwatterBody"], "paddle": ["SwatterPaddle"]}},
	"catch_trap": {"stride": 1.6, "parts": {"body": ["CatchBody"], "cup": ["CatchCup"]}},
	"deflector": {"stride": 1.8, "parts": {"body": ["DeflectorBody/Body"], "dish": ["DeflectorBody/DishWall"]}},
	"gyro_jammer": {"stride": 1.8, "parts": {"body": ["GyroBody"], "aerial": ["GyroAerial"]}},
}

static var headless := false
static var _libraries := {}

var kind := ""
var enemy: Node3D
var lib: Dictionary
var clip := ""
var clip_time := 0.0
var _joints: Array = []
var _bones: Array = []
var _poses: Array = []
var _from: Array = []
var _blend_left := 0.0
var _idle_clock := 0.0
var _rolled := 0.0
var _last_at := Vector3.INF
var _strike_age := -1.0
var _hit_age := -1.0
var _dying := false
var _death_age := 0.0
var _death_direction := Vector3.ZERO
var _holder: Node3D


static func active() -> bool:
	return headless or not AppShell.headless()


static func path_for(kind_name: String) -> String:
	return DIR + kind_name + "_clips.glb"


static func has_clips(kind_name: String) -> bool:
	return ROWS.has(kind_name) and ResourceLoader.exists(path_for(kind_name))


static func library(kind_name: String) -> Dictionary:
	if _libraries.has(kind_name):
		return _libraries[kind_name]
	var found := {}
	if has_clips(kind_name):
		var scene := (load(path_for(kind_name)) as PackedScene).instantiate()
		var skeleton := scene.find_child("Skeleton3D", true, false) as Skeleton3D
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if skeleton != null and player != null:
			var bones := []
			var index := {}
			for i in skeleton.get_bone_count():
				bones.append({"name": skeleton.get_bone_name(i), "parent": skeleton.get_bone_parent(i), "rest": skeleton.get_bone_rest(i)})
				index[skeleton.get_bone_name(i)] = i
			var anims := {}
			for clip_name in CLIPS:
				if not player.has_animation(clip_name):
					continue
				var anim := player.get_animation(clip_name)
				var tracks := []
				for t in anim.get_track_count():
					var bone_name := String(anim.track_get_path(t).get_concatenated_subnames())
					if index.has(bone_name):
						tracks.append([int(index[bone_name]), anim.track_get_type(t), t])
				anims[clip_name] = {"anim": anim, "length": anim.length, "tracks": tracks}
			var globals := []
			for bone in bones:
				var rest: Transform3D = bone.rest
				globals.append(rest if int(bone.parent) < 0 else (globals[int(bone.parent)] as Transform3D) * rest)
			found = {"bones": bones, "index": index, "anims": anims, "rest_globals": globals}
		scene.free()
	_libraries[kind_name] = found
	return found


static func seat(body: Node3D) -> Node:
	var kind_name := String(body.get("kind"))
	var pivot := body.get("reaction_pivot") as Node3D
	if not active() or pivot == null or not has_clips(kind_name):
		return null
	var found := library(kind_name)
	if found.is_empty():
		return null
	var row: Dictionary = ROWS[kind_name]
	for bone_name in row.parts:
		for part_path in row.parts[bone_name]:
			if pivot.get_node_or_null(NodePath(part_path)) == null or not found.index.has(bone_name):
				return null
	var driver: Node = (load("res://src/presentation/enemy_clips.gd") as GDScript).new()
	driver.name = "EnemyClips"
	driver.kind = kind_name
	driver.enemy = body
	driver.lib = found
	driver._build(pivot, row)
	pivot.add_child(driver)
	if body.has_signal("attack_phase"):
		body.connect("attack_phase", driver._on_attack_phase)
	return driver


func _build(pivot: Node3D, row: Dictionary) -> void:
	var targets := {}
	for bone_name in row.parts:
		for part_path in row.parts[bone_name]:
			targets[pivot.get_node(NodePath(part_path))] = int(lib.index[bone_name])
	for part in targets:
		var node := part as Node3D
		var ancestor := -1
		var offset := Vector3.ZERO
		var up := node.get_parent() as Node3D
		while up != null and up != pivot:
			offset += up.position
			if targets.has(up):
				ancestor = targets[up]
				break
			up = up.get_parent() as Node3D
		var skeleton: Node = null
		if node is MeshInstance3D and not (node as MeshInstance3D).skeleton.is_empty():
			skeleton = node.get_node_or_null((node as MeshInstance3D).skeleton)
		var parent := node.get_parent()
		var at := node.get_index()
		var joint := Node3D.new()
		joint.name = JOINT_PREFIX + String(node.name)
		parent.remove_child(node)
		parent.add_child(joint)
		parent.move_child(joint, at)
		joint.add_child(node)
		if skeleton != null:
			(node as MeshInstance3D).skeleton = node.get_path_to(skeleton)
		_joints.append({"joint": joint, "bone": targets[part], "ancestor": ancestor, "offset": offset})
	for bone_name in row.get("bones", {}):
		var spec: Array = row.bones[bone_name]
		var skeleton := pivot.get_node_or_null(NodePath(String(spec[0]))) as Skeleton3D
		if skeleton == null or not lib.index.has(bone_name):
			continue
		var target := skeleton.find_bone(String(spec[1]))
		if target < 0:
			continue
		_bones.append({"skeleton": skeleton, "target": target, "bone": int(lib.index[bone_name]), "channels": String(spec[2]),
			"rest": skeleton.get_bone_rest(target)})
	for i in lib.bones.size():
		_poses.append(lib.bones[i].rest)
	var spawn: Vector3 = enemy.global_position
	var idle: Dictionary = lib.anims.get("idle", {})
	_idle_clock = float(absi(hash(Vector3i(spawn.round()))) % 101) / 101.0 * float(idle.get("length", 1.0))


func _on_attack_phase(facts: Dictionary) -> void:
	if String(facts.get("phase", "")) == "strike":
		_strike_age = 0.0


func hit() -> void:
	if clip in ["windup", "attack"] or _dying:
		return
	if _hit_age < 0.0 or _hit_age > float(lib.anims.get("hit", {}).get("length", 0.3)) * 0.6:
		_hit_age = 0.0


var _land := Callable()


func die(direction: Vector3, land := Callable()) -> bool:
	_land = land
	var pivot := get_parent() as Node3D
	var world := enemy.get_parent() if enemy != null else null
	if _dying or not lib.anims.has("death") or pivot == null or world == null:
		return false
	_detach_away_tools()
	_holder = Node3D.new()
	_holder.name = "DeathClip"
	world.add_child(_holder)
	_holder.global_transform = enemy.global_transform
	var keep := pivot.global_transform
	pivot.get_parent().remove_child(pivot)
	_holder.add_child(pivot)
	pivot.global_transform = keep
	_dying = true
	_death_direction = direction
	_death_age = 0.0
	_set_clip("death")
	return true


func _detach_away_tools() -> void:
	for row in _joints:
		for part in (row.joint as Node3D).get_children():
			if part is Node3D and (part as Node3D).top_level:
				(part as Node3D).visible = false
	var pivot := get_parent() as Node3D
	if pivot != null:
		for child in pivot.get_children():
			if child is Node3D and (child as Node3D).top_level:
				(child as Node3D).visible = false


func _physics_process(delta: float) -> void:
	if _dying:
		_sample("death", _death_age, 1.0)
		_death_age += delta
		if _death_age >= float(lib.anims.death.length):
			EnemyMotion.scatter(_holder, kind, _death_direction, _land)
			_holder.queue_free()
			set_physics_process(false)
		return
	if not is_instance_valid(enemy):
		return
	var at := enemy.global_position
	if _last_at != Vector3.INF:
		_rolled += Vector2(at.x - _last_at.x, at.z - _last_at.z).length()
	_last_at = at
	_idle_clock += delta
	var choice := _choose()
	_set_clip(String(choice[0]))
	clip_time = float(choice[1])
	var weight := 1.0 if clip in HARD else Comfort.motion_scale()
	_sample(clip, clip_time, weight)
	if _strike_age >= 0.0:
		_strike_age += delta
	if _hit_age >= 0.0:
		_hit_age += delta


func _choose() -> Array:
	var atk: Dictionary = enemy.attack_state() if enemy.has_method("attack_state") else {}
	var anims: Dictionary = lib.anims
	if not atk.is_empty() and String(atk["phase"]) == "windup" and anims.has("windup"):
		_strike_age = -1.0
		_hit_age = -1.0
		var progress := float(atk["progress"])
		var run: float = enemy.windup_run() if enemy.has_method("windup_run") else -1.0
		if run >= 0.0:
			progress = run
		return ["windup", clampf(progress, 0.0, 1.0) * float(anims.windup.length)]
	if _strike_age >= 0.0 and anims.has("attack"):
		if _strike_age <= float(anims.attack.length) or not atk.is_empty():
			return ["attack", minf(_strike_age, float(anims.attack.length))]
		_strike_age = -1.0
	if _hit_age >= 0.0 and anims.has("hit"):
		if _hit_age <= float(anims.hit.length):
			return ["hit", _hit_age]
		_hit_age = -1.0
	var planar := Vector2(enemy.velocity.x, enemy.velocity.z).length() if enemy is CharacterBody3D else 0.0
	if planar > (MOVE_MIN * 0.6 if clip == "move" else MOVE_MIN) and anims.has("move"):
		var stride := float(ROWS[kind].get("stride", 2.0))
		return ["move", fposmod(_rolled / stride, 1.0) * float(anims.move.length)]
	return ["idle", fposmod(_idle_clock, float(anims.idle.length)) if anims.has("idle") else 0.0]


func _set_clip(next: String) -> void:
	if next == clip:
		return
	_from = _poses.duplicate()
	_blend_left = 0.0 if next in HARD else BLEND
	clip = next


func _sample(clip_name: String, seconds: float, weight: float) -> void:
	var entry: Dictionary = lib.anims.get(clip_name, {})
	var bones: Array = lib.bones
	var local: Array = []
	for bone in bones:
		local.append([(bone.rest as Transform3D).origin, Quaternion.IDENTITY, Vector3.ONE])
	if not entry.is_empty():
		var anim: Animation = entry.anim
		var t := clampf(seconds, 0.0, float(entry.length))
		for track in entry.tracks:
			match int(track[1]):
				Animation.TYPE_POSITION_3D:
					local[track[0]][0] = anim.position_track_interpolate(track[2], t)
				Animation.TYPE_ROTATION_3D:
					local[track[0]][1] = anim.rotation_track_interpolate(track[2], t)
				Animation.TYPE_SCALE_3D:
					local[track[0]][2] = anim.scale_track_interpolate(track[2], t)
	var mix := 1.0
	if _blend_left > 0.0:
		_blend_left = maxf(0.0, _blend_left - get_physics_process_delta_time())
		mix = 1.0 - _blend_left / BLEND
	for i in bones.size():
		var rest: Transform3D = bones[i].rest
		var pose := Transform3D(Basis(local[i][1]) * Basis.from_scale(local[i][2]), local[i][0])
		if weight < 1.0:
			pose = rest.interpolate_with(pose, weight)
		if mix < 1.0 and i < _from.size():
			pose = (_from[i] as Transform3D).interpolate_with(pose, mix)
		_poses[i] = pose
	_apply()


func _apply() -> void:
	var bones: Array = lib.bones
	var deltas := []
	var globals := []
	for i in bones.size():
		var parent := int(bones[i].parent)
		var global: Transform3D = _poses[i] if parent < 0 else (globals[parent] as Transform3D) * (_poses[i] as Transform3D)
		globals.append(global)
		deltas.append(global * (lib.rest_globals[i] as Transform3D).affine_inverse())
	for row in _joints:
		var delta: Transform3D = deltas[row.bone]
		if int(row.ancestor) >= 0:
			delta = (deltas[row.ancestor] as Transform3D).affine_inverse() * delta
		var shift := Transform3D(Basis.IDENTITY, row.offset)
		(row.joint as Node3D).transform = shift.affine_inverse() * delta * shift
	for row in _bones:
		var skeleton: Skeleton3D = row.skeleton
		if not is_instance_valid(skeleton):
			continue
		var pose: Transform3D = _poses[row.bone]
		var rest: Transform3D = lib.bones[row.bone].rest
		var channels: String = row.channels
		if "p" in channels:
			skeleton.set_bone_pose_position(row.target, (row.rest as Transform3D).origin + pose.origin - rest.origin)
		if "r" in channels:
			skeleton.set_bone_pose_rotation(row.target, pose.basis.get_rotation_quaternion())
		if "s" in channels:
			skeleton.set_bone_pose_scale(row.target, pose.basis.get_scale())


func state() -> Dictionary:
	return {"clip": clip, "time": clip_time, "dying": _dying}
