extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")
const Trigger := preload("res://tests/support/pilot_clip_trigger.gd")

# The class card's preview seats the same animated pilot the game does: for every row
# with a hero shell, an "AnimatedPilot" under the preview Pod instanced from
# HeroAssets.PILOTS[id] (checked by its scene_file_path), and the shell's embedded
# "Pilot" placeholder hidden the way hide_placeholder hides it.
#
# Two checks added 2026-10-11 (PE-0, PILOT-CLIPS sections 1.4 and 3 rule 9), on synthetic clips
# because today's GLBs carry neither: the preview pilot plays idle_loop when the GLB has it, and
# under --profile=sitting the first focus of a launch plays unlock, then idle_loop, and a second
# focus plays nothing new.

const SABLE_PILOT := "res://assets/models/pilot_sable_anim.glb"

var _t := T.new("class_preview_pilot_test")


func _init() -> void:
	var rows := 0
	for def in ClassDef.all():
		if not HeroAssets.SHELLS.has(def.id):
			continue
		rows += 1
		_check_row(def)
	_t.check("rows with shells", rows >= 5, "%d rows" % rows)
	_check_clips()
	quit(_t.verdict())


func _check_row(def: Resource) -> void:
	var preview := ClassPreview.new(def)
	var pod: Node3D = preview._pod
	var pilot := pod.get_node_or_null("AnimatedPilot") if pod != null else null
	var path: String = pilot.scene_file_path if pilot != null else ""
	_t.eq(def.id + " pilot scene", path, HeroAssets.PILOTS[def.id])
	if def.id in ["tally", "remembered_cannon"]:
		_t.check(def.id + " not Sable pilot", pilot != null and path != SABLE_PILOT, "scene %s" % path)
	var placeholders: Array = []
	if pod != null:
		for node in pod.find_children("Pilot", "GeometryInstance3D", true, false):
			# The pilot glb's own body mesh is also named Pilot; only the shell's is a placeholder.
			if pilot == null or not pilot.is_ancestor_of(node):
				placeholders.append(node)
	var shown: Array = []
	for node in placeholders:
		var gi := node as GeometryInstance3D
		if gi.layers != 0 or gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shown.append(str(gi.get_path()))
	# The bespoke Tarn, Tally and cannon shells model no seated placeholder to hide.
	var bespoke: bool = def.id in ["tarn", "tally", "remembered_cannon"]
	_t.check(def.id + " placeholder present", placeholders.size() >= 1 or bespoke, "%d found" % placeholders.size())
	_t.eq(def.id + " placeholder hidden (%d found)" % placeholders.size(), shown, [])
	# The animated pilot's own body mesh must stay visible; only the shell's placeholder hides.
	var own_hidden: Array = []
	if pilot != null:
		for node in pilot.find_children("*", "GeometryInstance3D", true, false):
			var gi := node as GeometryInstance3D
			if gi.layers == 0:
				own_hidden.append(str(gi.get_path()))
	_t.eq(def.id + " animated pilot visible", own_hidden, [])
	preview.free()


func _check_clips() -> void:
	var preview := ClassPreview.new(ClassDef.by_id("pylon_engineer"))
	var animator: AnimationPlayer = preview._animator
	if animator == null:
		_t.check("preview pilot has an animator", false)
		preview.free()
		return
	# Sable's GLB ships a real idle_loop (2026-10-18): the preview then already plays it.
	var seated_still := animator.has_animation("idle_loop") or not animator.is_playing()
	Trigger.add_synthetic_clips(animator, "pylon_engineer")
	_t.check("preview plays idle_loop when the GLB has it (seated still before)",
		seated_still and preview.seat_pilot() == "idle_loop" and animator.is_playing() and animator.current_animation == "idle_loop")
	preview.sitting = true
	preview.open = 1.0
	preview.track_focus()
	var first := preview.last_focus_clip
	var first_playing := animator.current_animation
	animator.advance(animator.current_animation_length + 0.01)
	var after := animator.current_animation
	preview.open = 0.0
	preview.track_focus()
	preview.open = 1.0
	preview.track_focus()
	_t.check("sitting: first focus plays unlock, then idle_loop; a second focus does not",
		first == "unlock" and first_playing == "unlock" and after == "idle_loop" and preview.last_focus_clip == "",
		"first %s playing %s after %s second %s" % [first, first_playing, after, preview.last_focus_clip])
	preview.free()
