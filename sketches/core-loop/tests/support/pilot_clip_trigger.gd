extends RefCounted

# Shared helper for the pilot clip tests (design-v3/PILOT-CLIPS.md section 7.2): the roster,
# synthetic clips for a GLB that lacks the new ones, finishing a clip through the real
# animation_finished path, the bone-rest check, and a cockpit fixture Pod for the mecha motion.

const ROSTER_PATH := "res://src/presentation/clips/roster.json"
const FIXTURE_CONTROLS := ["Trigger", "Lever", "Crank", "Plunger", "Pedal.L", "Pedal.R", "LapBar"]


static func roster() -> Dictionary:
	var text := FileAccess.get_file_as_string(ROSTER_PATH)
	var parsed = JSON.parse_string(text) if text != "" else null
	return parsed if parsed is Dictionary else {}


# The roster stem (sable, rivet, ...) of a class id, or "".
static func stem_of(class_id: String) -> String:
	var pilots: Dictionary = roster().get("pilots", {})
	for stem in pilots:
		if String(pilots[stem].get("class", "")) == class_id:
			return stem
	return ""


# Adds every roster clip the animator lacks as a copy of drop_land, cut to the pilot's end
# frame from PILOT-CLIPS section 1.2 ((E - 1) / 30 s), looping for the _loop names. The same
# move the policy fixture in pilot_reactions_test makes for the kept clips. Returns the names added.
static func add_synthetic_clips(animator: AnimationPlayer, class_id: String) -> Array:
	var data := roster()
	var ends: Dictionary = data.get("end_frames", {}).get(stem_of(class_id), {})
	var fps := float(data.get("fps", 30))
	var imported := animator.get_animation_library("")
	var source := animator.get_animation("drop_land")
	var added: Array = []
	for clip in Array(data.get("kept", [])) + Array(data.get("new", [])):
		if animator.has_animation(clip):
			continue
		var fixture := source.duplicate(true) as Animation
		if ends.has(clip):
			fixture.length = (float(ends[clip]) - 1.0) / fps
		fixture.loop_mode = Animation.LOOP_LINEAR if String(clip).ends_with("_loop") else Animation.LOOP_NONE
		imported.add_animation(clip, fixture)
		added.append(clip)
	return added


# Plays the current one-shot to its end, so animation_finished runs the real hand-off.
static func finish(rec: Dictionary) -> void:
	var animator: AnimationPlayer = rec.animator
	if animator.is_playing() and animator.get_animation(animator.current_animation).loop_mode == Animation.LOOP_NONE:
		animator.advance(animator.current_animation_length - animator.current_animation_position + 0.01)


static func seconds_left(rec: Dictionary) -> float:
	var animator: AnimationPlayer = rec.animator
	if not animator.is_playing():
		return 0.0
	return animator.current_animation_length - animator.current_animation_position


static func bones_at_rest(pilot: Node) -> bool:
	for skeleton in pilot.find_children("*", "Skeleton3D", true, false):
		for bone in skeleton.get_bone_count():
			if not skeleton.get_bone_pose(bone).is_equal_approx(skeleton.get_bone_rest(bone)):
				return false
	return true


# A Pod with the cockpit control empties a Hoberman shell exports (tools/blender/shell_base.py
# CONTROLS and the bank), named the way Godot's glTF import names them ("." becomes "_"), plus
# the machinery nodes a test asks for. The Core is a sibling, as in the shell.
static func fixture_pod(machinery_nodes: Array = []) -> Node3D:
	var ball := Node3D.new()
	ball.name = "FixtureBall"
	var core := Node3D.new()
	core.name = "Core"
	ball.add_child(core)
	var pod := Node3D.new()
	pod.name = "Pod"
	ball.add_child(pod)
	for control in FIXTURE_CONTROLS:
		var node := Node3D.new()
		node.name = ("Control." + control).replace(".", "_")
		pod.add_child(node)
	for node_name in machinery_nodes:
		var node: Node3D = MeshInstance3D.new() if String(node_name).begins_with("Mesh") else Node3D.new()
		node.name = String(node_name).replace(".", "_")
		pod.add_child(node)
	return pod
