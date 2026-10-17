extends Node

# A kill-first special's body acting, driven by the same special_tell(moment) signal that
# fires its sound and machine_fx's burst (design-v3/MACHINE-VFX.md, "The four specials").
# Each clip in tools/blender/world_one/kill_first_motion.py has age 0 on the frame its
# sound starts, so playing it from 0 on that signal keeps picture and sound on one frame.
# A tell returns to the body's loop when it ends; a break holds its last pose for the death.
# Presentation only: nothing here moves a collider or the committed telegraph.

const CLIPS := {
	"foreman": {"loop": "idle", "tell": "tell", "break": "break"},
	"dispatcher": {"loop": "idle", "tell": "tell", "break": "break"},
	"splitter": {"loop": "crawl", "tell": "tell", "break_split": "break_split", "break_clean": "break_clean"},
	# The Linker holds its dish braced (a loop) once the brace lands, until slack or cut.
	"linker": {"loop": "idle", "tell": "brace", "after_tell": "braced", "slack": "slack", "break": "cut"},
	"splitter_piece": {"loop": "scurry", "spawn": "pop_in"},
}
const BREAKS := ["break", "break_split", "break_clean"]

var kind := ""
var player: AnimationPlayer
var skeleton: Skeleton3D
var _loop := ""
var _held := false


# Seats the driver under `enemy`, reading the clips from `model` (the special's GLB scene).
# Returns null when the model carries no rig or the kind has no clip table.
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


# One moment from the body's special_tell signal. Unknown moments are ignored, and nothing
# plays over a break: a dying body keeps its fall.
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
	# The importer drops constant tracks, so a clip that never keys a bone would inherit the
	# last clip's pose for it. Every switch starts from rest.
	skeleton.reset_bone_poses()
	player.play(clip)
	player.seek(0.0, true)


func _finished(clip: StringName) -> void:
	if _held:
		return
	var row: Dictionary = CLIPS.get(kind, {})
	if String(clip) == row.get("tell", "") and row.has("after_tell"):
		_play(String(row["after_tell"]), true)
	elif String(clip) != _loop:
		_play(String(row["loop"]), true)
