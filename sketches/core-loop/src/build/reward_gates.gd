extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# Two gates placed ahead of the ball along its line; rolling through one takes its
# part. There is no collider and no menu, so choosing never costs speed. If you roll
# past both, they are put ahead of you again rather than waiting behind you.

signal chosen(part_id: String)

const AHEAD := 38.0
const SPREAD := 9.0
const WIDTH := 8.0
const HEIGHT := 7.0
const MISSED_BEYOND := 20.0
const LOST_BEYOND := 110.0

var offers: Array = []

var _terrain
var _ids: Array = []
var _last_side := {}
var _gates: Array[Node3D] = []


func setup(terrain) -> void:
	_terrain = terrain
	visible = false


# Returns the published offers: part_id, at (ground centre), facing (the way through),
# width. Presentation and tests read the same records the crossing test uses.
func open(part_ids: Array, ball: Vector3, heading: Vector3) -> Array:
	_ids = part_ids
	_place(ball, heading)
	visible = true
	return offers


func close() -> void:
	visible = false
	offers = []
	for gate in _gates:
		gate.queue_free()
	_gates.clear()


func is_open() -> bool:
	return not offers.is_empty()


# Returns true when the gates moved, so the owner can publish the new offers.
func step(ball: Vector3, heading: Vector3) -> bool:
	if offers.is_empty():
		return false
	var passed_all := true
	for i in offers.size():
		var offer: Dictionary = offers[i]
		var rel: Vector3 = ball - offer["at"]
		var along: float = rel.dot(offer["facing"])
		var side: float = (rel - (offer["facing"] as Vector3) * along).length()
		var was: float = _last_side.get(i, along)
		_last_side[i] = along
		if was < 0.0 and along >= 0.0 and side <= WIDTH * 0.5 + 1.0 and absf(rel.y) < HEIGHT + 4.0:
			var id: String = offer["part_id"]
			close()
			chosen.emit(id)
			return false
		if along < MISSED_BEYOND and rel.length() < LOST_BEYOND:
			passed_all = false
	if passed_all:
		_place(ball, heading)
		return true
	return false


func _place(ball: Vector3, heading: Vector3) -> void:
	for gate in _gates:
		gate.queue_free()
	_gates.clear()
	offers = []
	_last_side = {}
	var facing := Vector3(heading.x, 0.0, heading.z).normalized()
	var side := facing.cross(Vector3.UP).normalized()
	for i in _ids.size():
		var offset := (float(i) - (_ids.size() - 1) * 0.5) * 2.0 * SPREAD
		var spot := ball + facing * AHEAD + side * offset
		var at: Vector3 = _terrain.drop_point(spot.x, spot.z, 0.0)
		offers.append({"part_id": _ids[i], "at": at, "facing": facing, "width": WIDTH})
		_gates.append(_build_gate(at, facing, _ids[i]))


func _build_gate(at: Vector3, facing: Vector3, part_id: String) -> Node3D:
	var gate := Node3D.new()
	add_child(gate)
	gate.global_position = at
	gate.global_basis = Basis.looking_at(facing, Vector3.UP)
	var tint := EventKinds.color("reward_offered")
	var mat := Palette.solid(tint, 1.4)
	for x in [-WIDTH * 0.5, WIDTH * 0.5]:
		var post := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.5, HEIGHT, 0.5)
		post.mesh = box
		post.material_override = mat
		post.position = Vector3(x, HEIGHT * 0.5, 0.0)
		gate.add_child(post)
	var bar := MeshInstance3D.new()
	var bar_box := BoxMesh.new()
	bar_box.size = Vector3(WIDTH + 0.5, 0.5, 0.5)
	bar.mesh = bar_box
	bar.material_override = mat
	bar.position = Vector3(0.0, HEIGHT, 0.0)
	gate.add_child(bar)
	var label := Label3D.new()
	label.text = part_id.replace("_", " ").capitalize()
	label.font_size = 96
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint
	label.outline_size = 12
	label.position = Vector3(0.0, HEIGHT + 1.6, 0.0)
	gate.add_child(label)
	return gate
