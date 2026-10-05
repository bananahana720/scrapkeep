extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const ClassPreview := preload("res://src/ui/class_preview.gd")
const T := preload("res://tests/support/t.gd")

# The class card's preview seats the same animated pilot the game does: for every row
# with a hero shell, an "AnimatedPilot" under the preview Pod instanced from
# HeroAssets.PILOTS[id] (checked by its scene_file_path), and the shell's embedded
# "Pilot" placeholder hidden the way hide_placeholder hides it.

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
	_t.check(def.id + " placeholder present", placeholders.size() >= 1, "%d found" % placeholders.size())
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
