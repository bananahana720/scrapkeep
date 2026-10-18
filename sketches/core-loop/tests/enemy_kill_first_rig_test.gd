extends SceneTree
# Kill-first rigs (tools/blender/world_one/kill_first_rig.py and kill_first_motion.py): each
# special's GLB carries one skeleton that skins every mesh, and the clips its sounds are timed
# to (design-v3/sound/specials.py on PR #12). Checks the clip names and lengths the behaviour
# units will seek by, that each tell starts from rest on its first frame (the sound is full on
# frame one, so nothing may jump), that each tell and break actually moves the body, and that
# loop clips close on their first pose.

const T := preload("res://tests/support/t.gd")
const BEAT := 60.0 / 129.0
const FRAME := 1.0 / 30.0
const RIGS := {
	"res://assets/models/world_one/enemy_foreman.glb": {
		"bones": ["Hand", "Hat", "Mast", "HornBig"],
		"clips": {"idle": 8 * BEAT, "tell": 0.9, "break": 2.4},
		"loops": ["idle"], "tell": "tell", "breaks": ["break"]},
	"res://assets/models/world_one/enemy_dispatcher.glb": {
		"bones": ["Radar", "Tube3", "EyeL", "Tongue"],
		"clips": {"idle": 8 * BEAT, "tell": 1.0, "break": 1.6},
		"loops": ["idle"], "tell": "tell", "breaks": ["break"]},
	"res://assets/models/world_one/enemy_splitter.glb": {
		"bones": ["PodA", "PodB", "PodC", "Core", "Lamp"],
		"clips": {"crawl": 8 * BEAT, "tell": 0.4, "break_split": 0.2, "break_clean": 1.0},
		"loops": ["crawl"], "tell": "tell", "breaks": ["break_clean"]},
	"res://assets/models/world_one/enemy_splitter_piece.glb": {
		"bones": ["Body", "Snout", "LegL", "LegR"],
		"clips": {"scurry": BEAT, "pop_in": 0.25},
		"loops": ["scurry"], "tell": "", "breaks": []},
	"res://assets/models/world_one/enemy_linker.glb": {
		"bones": ["DishAim", "DishBrace", "Sag", "Ears"],
		"clips": {"idle": 8 * BEAT, "brace": 0.8, "braced": BEAT, "slack": 0.5, "cut": 2.4},
		"loops": ["idle", "braced"], "tell": "brace", "breaks": ["cut"]},
}

var t := T.new("enemy_kill_first_rig_test")


func _initialize() -> void:
	_run.call_deferred()


# Every bone's posed origin and scale, in skeleton space, after seeking `clip` to `at`.
func _pose(player: AnimationPlayer, rig: Skeleton3D, clip: String, at: float) -> Array:
	rig.reset_bone_poses()
	player.play(clip)
	player.seek(at, true)
	var out := []
	for i in rig.get_bone_count():
		var xf := rig.get_bone_global_pose(i)
		out.append([xf.origin, xf.basis.get_scale(), xf.basis.get_rotation_quaternion()])
	return out


func _distance(a: Array, b: Array) -> float:
	var worst := 0.0
	for i in a.size():
		worst = maxf(worst, (a[i][0] as Vector3).distance_to(b[i][0]))
		worst = maxf(worst, ((a[i][1] as Vector3) - (b[i][1] as Vector3)).length())
		worst = maxf(worst, (a[i][2] as Quaternion).angle_to(b[i][2]))
	return worst


func _rest(rig: Skeleton3D) -> Array:
	rig.reset_bone_poses()
	var out := []
	for i in rig.get_bone_count():
		var xf := rig.get_bone_global_pose(i)
		out.append([xf.origin, xf.basis.get_scale(), xf.basis.get_rotation_quaternion()])
	return out


func _check(path: String, spec: Dictionary) -> void:
	var label := path.get_file().get_basename()
	var packed := load(path) as PackedScene
	t.check(label + " loads", packed != null)
	if packed == null:
		return
	var scene := packed.instantiate() as Node3D
	root.add_child(scene)
	var rig := scene.find_child("Skeleton3D", true, false) as Skeleton3D
	var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
	t.check(label + " has a skeleton", rig != null)
	t.check(label + " has clips", player != null)
	if rig == null or player == null:
		scene.queue_free()
		return
	for bone in spec.bones:
		t.check(label + " bone " + bone, rig.find_bone(bone) >= 0)
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		t.check(label + " " + mi.name + " skinned to the rig", mi.skin != null and mi.get_node_or_null(mi.skeleton) == rig)
	var clips: Dictionary = spec.clips
	t.check(label + " clip set", player.get_animation_list().size() == clips.size(), str(player.get_animation_list()))
	for clip in clips:
		var ok := player.has_animation(clip)
		t.check(label + " has " + clip, ok)
		if ok:
			# Clips are 30 fps; a length within one frame of the sound's keeps the cue in sync.
			t.near(label + " " + clip + " length", player.get_animation(clip).length, clips[clip], FRAME + 0.001)
	var rest := _rest(rig)
	if spec.tell != "":
		var tell: String = spec.tell
		t.check(label + " " + tell + " starts from rest", _distance(_pose(player, rig, tell, 0.0), rest) < 0.01)
		var peak := 0.0
		var length := player.get_animation(tell).length
		for k in 10:
			peak = maxf(peak, _distance(_pose(player, rig, tell, length * (k + 1) / 10.0), rest))
		t.check(label + " " + tell + " reads (moves a bone 0.15+)", peak > 0.15, str(peak))
	for clip in spec.breaks:
		var end := _distance(_pose(player, rig, clip, player.get_animation(clip).length), rest)
		t.check(label + " " + clip + " ends in a downed pose", end > 0.15, str(end))
	for clip in spec.loops:
		var length := player.get_animation(clip).length
		var seam := _distance(_pose(player, rig, clip, 0.0), _pose(player, rig, clip, length))
		t.check(label + " " + clip + " loops seamlessly", seam < 0.02, str(seam))
	scene.queue_free()


func _run() -> void:
	for path in RIGS:
		_check(path, RIGS[path])
	quit(t.verdict())
