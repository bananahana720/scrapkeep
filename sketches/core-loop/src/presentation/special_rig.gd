extends Node

const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const CLIPS := {
	"foreman": {"loop": "idle", "tell": "tell", "break": "break"},
	"dispatcher": {"loop": "idle", "tell": "tell", "break": "break"},
	"splitter": {"loop": "crawl", "tell": "tell", "break_split": "break_split", "break_clean": "break_clean"},
	"linker": {"loop": "idle", "tell": "brace", "after_tell": "braced", "slack": "slack", "break": "cut"},
	"splitter_piece": {"loop": "scurry", "spawn": "pop_in"},
}
const BREAKS := ["break", "break_split", "break_clean"]
const BLEND_TELL := 0.1
const BLEND_LOOP := 0.15
const EASE_REST := 0.15
const CHANNELS := [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]
const FILLED := "rest_filled"

var kind := ""
var player: AnimationPlayer
var skeleton: Skeleton3D
var _loop := ""
var _held := false
var _started := false
var _ease_left := 0.0
var _ease_from: Array = []


static func attach(enemy: Node, model: Node, special: String) -> Node:
	var anim := model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rig := model.find_child("Skeleton3D", true, false) as Skeleton3D
	if anim == null or rig == null or not CLIPS.has(special):
		return null
	var node: Node = (load("res://src/presentation/special_rig.gd") as GDScript).new()
	node.name = "SpecialRig"
	node.kind = special
	node.player = anim
	node.skeleton = rig
	enemy.add_child(node)
	if enemy.has_signal("special_tell"):
		enemy.connect("special_tell", node.moment)
	anim.animation_finished.connect(node._finished)
	node._play(CLIPS[special]["loop"], true)
	return node


static func seat(enemy: Node, pivot: Node3D, path: String, special: String) -> Node3D:
	if not EnemyMotion.active() or not ResourceLoader.exists(path):
		return null
	var model := (load(path) as PackedScene).instantiate() as Node3D
	pivot.add_child(model)
	if attach(enemy, model, special) == null:
		pivot.remove_child(model)
		model.free()
		return null
	return model


func _ready() -> void:
	set_process(_ease_left > 0.0)


func moment(name: String) -> void:
	var row: Dictionary = CLIPS.get(kind, {})
	if _held or not row.has(name):
		return
	if name in BREAKS:
		_held = true
	_play(String(row[name]), false)


func _play(clip: String, loop: bool) -> void:
	if player == null or not player.has_animation(clip):
		return
	if loop:
		_loop = clip
		player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		if EnemyMotion.motion_scale <= 0.0:
			_ease_to_rest()
			return
	_ease_left = 0.0
	fill_rest(player, skeleton)
	var blend := 0.0 if not _started or _is_hit(clip) else (BLEND_LOOP if loop else BLEND_TELL)
	_started = true
	player.play(clip, blend)
	player.seek(0.0, true)


func _is_hit(clip: String) -> bool:
	var row: Dictionary = CLIPS.get(kind, {})
	for name in row:
		if String(row[name]) == clip and (name in BREAKS or name == "spawn"):
			return true
	return false


static func fill_rest(player: AnimationPlayer, skeleton: Skeleton3D) -> void:
	var names := player.get_animation_list()
	if names.is_empty() or player.get_animation(names[0]).has_meta(FILLED):
		return
	var wanted := {}
	for name in names:
		var anim := player.get_animation(name)
		for i in anim.get_track_count():
			var type := anim.track_get_type(i)
			var path := anim.track_get_path(i)
			if type in CHANNELS and path.get_subname_count() == 1 and skeleton.find_bone(path.get_subname(0)) >= 0:
				wanted[[path, type]] = true
	for name in names:
		var anim := player.get_animation(name)
		anim.set_meta(FILLED, true)
		var have := {}
		for i in anim.get_track_count():
			have[[anim.track_get_path(i), anim.track_get_type(i)]] = true
		for key in wanted:
			if have.has(key):
				continue
			var path: NodePath = key[0]
			var rest := skeleton.get_bone_rest(skeleton.find_bone(path.get_subname(0)))
			var track := anim.add_track(key[1])
			anim.track_set_path(track, path)
			match int(key[1]):
				Animation.TYPE_POSITION_3D:
					anim.position_track_insert_key(track, 0.0, rest.origin)
				Animation.TYPE_ROTATION_3D:
					anim.rotation_track_insert_key(track, 0.0, rest.basis.get_rotation_quaternion())
				Animation.TYPE_SCALE_3D:
					anim.scale_track_insert_key(track, 0.0, rest.basis.get_scale())


func _ease_to_rest() -> void:
	_ease_from.clear()
	for i in skeleton.get_bone_count():
		_ease_from.append([skeleton.get_bone_pose_position(i), skeleton.get_bone_pose_rotation(i), skeleton.get_bone_pose_scale(i)])
	player.stop()
	_ease_left = EASE_REST
	set_process(true)
	_process(0.0)


func _process(delta: float) -> void:
	if _ease_left <= 0.0:
		set_process(false)
		return
	_ease_left = maxf(0.0, _ease_left - delta)
	var k := smoothstep(0.0, 1.0, 1.0 - _ease_left / EASE_REST)
	for i in _ease_from.size():
		var rest := skeleton.get_bone_rest(i)
		var from: Array = _ease_from[i]
		skeleton.set_bone_pose_position(i, (from[0] as Vector3).lerp(rest.origin, k))
		skeleton.set_bone_pose_rotation(i, (from[1] as Quaternion).slerp(rest.basis.get_rotation_quaternion(), k))
		skeleton.set_bone_pose_scale(i, (from[2] as Vector3).lerp(rest.basis.get_scale(), k))
	if _ease_left <= 0.0:
		skeleton.reset_bone_poses()
		set_process(false)


func _finished(clip: StringName) -> void:
	if _held:
		return
	var row: Dictionary = CLIPS.get(kind, {})
	if String(clip) == row.get("tell", "") and row.has("after_tell"):
		_play(String(row["after_tell"]), true)
	elif String(clip) != _loop:
		_play(String(row["loop"]), true)
