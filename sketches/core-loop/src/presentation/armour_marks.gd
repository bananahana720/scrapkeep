extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const Palette := preload("res://src/core/palette.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")


const ICON_HEIGHT := 3.1
const ICON_SIZE := 0.32
const READ_STATES := {"resisted": "dented", "weak": "zzapped"}
const CODEX_OF := {"plated": "armour_plated", "wet": "armour_wet"}

var ctx
var fx
var stamped: Array[String] = []

var _shown := {}
var _icon_mesh: Mesh
var _icon_material: StandardMaterial3D


func setup(ctx_ref, fx_ref = null) -> void:
	ctx = ctx_ref
	fx = fx_ref
	name = "ArmourMarks"
	_icon_mesh = icon_mesh()
	_icon_material = icon_material()
	ctx.events.enemy_spawned.connect(_on_spawned)
	ctx.events.enemy_struck.connect(_on_struck)
	ctx.events.run_started.connect(func(_class_id: String):
		_shown = {}
		stamped.clear())


func known(armour: String) -> bool:
	var codex = ctx.codex if ctx != null else null
	return codex != null and CODEX_OF.has(armour) and codex.known(String(CODEX_OF[armour]))


func _on_spawned(enemy: Node3D, _kind: String) -> void:
	_badge(enemy)


func _on_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.has_meta("armour_read"):
		return
	var read := String(enemy.get_meta("armour_read"))
	var armour := DamageFamilies.armour_of(enemy)
	if read == "" or armour == "":
		return
	var key := armour + ":" + read
	if not _shown.has(key) and _stamp(enemy, String(READ_STATES.get(read, ""))):
		_shown[key] = true
	if known(armour):
		for other in get_tree().get_nodes_in_group("enemy"):
			if other is Node3D and DamageFamilies.armour_of(other) == armour:
				_badge(other)


func _stamp(enemy: Node3D, state: String) -> bool:
	var text := word_text(state)
	if text == "" or fx == null or not fx.read_word(text, enemy, EventKinds.state_color(state)):
		return false
	stamped.append(text)
	return true


func _badge(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or enemy.has_node("ArmourIcon"):
		return
	var armour := DamageFamilies.armour_of(enemy)
	if armour == "" or not known(armour):
		return
	enemy.add_child(icon_view(_icon_mesh, _icon_material))


static func icon_mesh() -> Mesh:
	var box := BoxMesh.new()
	box.size = Vector3.ONE * ICON_SIZE
	return box


static func icon_material() -> StandardMaterial3D:
	var material := Palette.solid(EventKinds.state_color("plated"), 0.6)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


static func icon_view(mesh: Mesh, material: Material) -> MeshInstance3D:
	var icon := MeshInstance3D.new()
	icon.name = "ArmourIcon"
	icon.mesh = mesh
	icon.material_override = material
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	icon.position = Vector3.UP * ICON_HEIGHT
	icon.rotation = Vector3(0.0, PI * 0.25, PI * 0.25)
	return icon


static func word_text(state: String) -> String:
	return String(EventKinds.state_row(state).get("word", ""))


static func warm_views() -> Array[Node3D]:
	var views: Array[Node3D] = [icon_view(icon_mesh(), icon_material())]
	for state in READ_STATES.values():
		var label := PlayerFx.word_label(PlayerFx.word_font())
		label.text = word_text(state)
		views.append(label)
	return views
