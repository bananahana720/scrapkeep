extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const DamageFamilies := preload("res://src/combat/damage_families.gd")
const Palette := preload("res://src/core/palette.gd")

# Learn on first hit (Andrew's Q6, 2026-10-17 22:12:39Z; FIELDS-AND-CASTS section 6). The first
# resisted and the first weak hit on an armour class each run stamp the STATE_ROWS word, DENT or
# ZZAP!, over the struck body: a comic onomatopoeia that rises and fades. Combat discovers the
# class's codex entry on that first read; from then on (it persists) every enemy of the class
# wears a small icon, high above its body so it never sits on a ground telegraph or on the
# interrupted star (status_marks.gd, 2.4 m). The read comes from the hit's own target (meta
# "armour_read", set by combat's caps stage before enemy_struck goes out).

const WORD_HEIGHT := 2.2
const WORD_RISE := 0.6
const WORD_SECONDS := 0.8
const WORD_PIXEL := 0.012
const WORD_FONT := 72
const ICON_HEIGHT := 3.1
const ICON_SIZE := 0.32
const READ_STATES := {"resisted": "dented", "weak": "zzapped"}
const CODEX_OF := {"plated": "armour_plated", "wet": "armour_wet"}

var ctx
var words: Array = []
var stamped := 0

var _shown := {}
var _icon_mesh: Mesh
var _icon_material: StandardMaterial3D


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "ArmourMarks"
	var box := BoxMesh.new()
	box.size = Vector3.ONE * ICON_SIZE
	_icon_mesh = box
	_icon_material = Palette.solid(EventKinds.state_color("plated"), 0.6)
	_icon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ctx.events.enemy_spawned.connect(_on_spawned)
	ctx.events.enemy_struck.connect(_on_struck)
	ctx.events.run_started.connect(func(_class_id: String): _shown = {})


func _process(delta: float) -> void:
	for i in range(words.size() - 1, -1, -1):
		var w: Dictionary = words[i]
		var label: Label3D = w["label"]
		w["t"] = float(w["t"]) + delta / WORD_SECONDS
		if w["t"] >= 1.0 or not is_instance_valid(label):
			if is_instance_valid(label):
				label.queue_free()
			words.remove_at(i)
			continue
		label.position = (w["at"] as Vector3) + Vector3.UP * WORD_RISE * float(w["t"])
		label.modulate.a = 1.0 - float(w["t"]) * float(w["t"])


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
	if not _shown.has(key):
		_shown[key] = true
		_stamp(enemy.global_position, String(READ_STATES.get(read, "")))
	if known(armour):
		for other in get_tree().get_nodes_in_group("enemy"):
			if other is Node3D and DamageFamilies.armour_of(other) == armour:
				_badge(other)


func _stamp(at: Vector3, state: String) -> void:
	var row := EventKinds.state_row(state)
	var text := String(row.get("word", ""))
	if text == "" or not is_inside_tree():
		return
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = WORD_FONT
	label.outline_size = 16
	label.pixel_size = WORD_PIXEL
	label.modulate = EventKinds.state_color(state)
	label.outline_modulate = Color(0.05, 0.05, 0.05)
	add_child(label)
	var base := at + Vector3.UP * WORD_HEIGHT
	label.position = base
	words.append({"label": label, "at": base, "t": 0.0})
	stamped += 1


# The class icon on one enemy, once its armour's codex entry is known.
func _badge(enemy: Node3D) -> void:
	if not is_instance_valid(enemy) or enemy.has_node("ArmourIcon"):
		return
	var armour := DamageFamilies.armour_of(enemy)
	if armour == "" or not known(armour):
		return
	var icon := MeshInstance3D.new()
	icon.name = "ArmourIcon"
	icon.mesh = _icon_mesh
	icon.material_override = _icon_material
	icon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	icon.position = Vector3.UP * ICON_HEIGHT
	icon.rotation = Vector3(0.0, PI * 0.25, PI * 0.25)
	enemy.add_child(icon)
