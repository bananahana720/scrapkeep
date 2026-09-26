extends Node3D

const Palette := preload("res://src/core/palette.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")

# The roll-through reward gates after the beacon. Two arches stand ahead of the ball on
# its line; rolling through one takes its part. There is no collider and no menu, so
# choosing never costs speed. If you roll past both, they are put ahead of you again
# rather than waiting behind you.
#
# Each gate says what it gives while you approach, in the order you need it:
# "{name}: {verb}. Punch +{n}", its effect in one line, and a star line when it would
# complete a named synergy ("* completes Storm Lattice *") or is a known ingredient
# ("* ingredient: ??? *"). Rarity shows twice: the arch's colour and the topper's shape
# (a bar for common, a diamond for uncommon, a star for rare, a tall star for
# rare-plus), so colour never carries it alone.

signal chosen(part_id: String)

const AHEAD := 38.0
const SPREAD := 9.0
const WIDTH := 8.0
const HEIGHT := 7.0
const MISSED_BEYOND := 20.0
const LOST_BEYOND := 110.0

var offers: Array = []
# Build's offer_mark(part_id) -> String; the star line under an offer, or "".
var mark_for: Callable

var _terrain
var _ids: Array = []
var _held: Array = []
var _last_side := {}
var _gates: Array[Node3D] = []
var _spin := 0.0


func setup(terrain) -> void:
	_terrain = terrain
	visible = false


# Returns the published offers: part_id, at (ground centre), facing (the way through)
# and width, plus name, text, rarity, tier and synergy for anything that draws them.
func open(part_ids: Array, ball: Vector3, heading: Vector3, held: Array = []) -> Array:
	_ids = part_ids
	_held = held.duplicate()
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
		var part_id: String = _ids[i]
		var d: Resource = Parts.def(part_id)
		var completes := Parts.completed_by(part_id, _held)
		offers.append({
			"part_id": part_id, "at": at, "facing": facing, "width": WIDTH,
			"name": Parts.display_name(part_id),
			"headline": Parts.headline(part_id),
			"verb": d.verb if d != null else "",
			"punch": d.punch if d != null else 0.0,
			"text": d.text if d != null else "",
			"rarity": d.rarity if d != null else "common",
			"tier": d.tier if d != null else 1,
			"synergy": Synergies.ROWS[completes]["name"] if completes != "" else "",
			"mark": mark_for.call(part_id) if mark_for.is_valid() else "",
		})
		_gates.append(_build_gate(at, facing, offers[-1]))


static func rarity_color(rarity: String) -> Color:
	match rarity:
		"uncommon":
			return Palette.ARC
		"rare":
			return Palette.AMBER
		"rare_plus":
			return Palette.HAZARD
	return Palette.SANDSTONE


func _build_gate(at: Vector3, facing: Vector3, offer: Dictionary) -> Node3D:
	var gate := Node3D.new()
	add_child(gate)
	gate.global_position = at
	gate.global_basis = Basis.looking_at(facing, Vector3.UP)
	var tint := rarity_color(offer["rarity"])
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
	var topper := _topper(offer["rarity"], Palette.solid(tint, 2.6))
	topper.name = "Topper"
	topper.position = Vector3(0.0, HEIGHT + 1.2, 0.0)
	gate.add_child(topper)
	var label := Label3D.new()
	var lines := "%s\n%s" % [offer["headline"], offer["text"]]
	if offer["mark"] != "":
		lines += "\n" + offer["mark"]
	label.text = lines
	label.font_size = 80
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = tint.lerp(Color.WHITE, 0.25)
	label.outline_size = 14
	label.position = Vector3(0.0, HEIGHT + 3.4, 0.0)
	gate.add_child(label)
	return gate


static func _topper(rarity: String, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	match rarity:
		"uncommon":
			var gem := SphereMesh.new()
			gem.radius = 0.8
			gem.height = 2.0
			gem.radial_segments = 4
			gem.rings = 2
			node.mesh = gem
		"rare", "rare_plus":
			var star := PrismMesh.new()
			star.size = Vector3(1.8, 2.8 if rarity == "rare_plus" else 1.8, 0.4)
			node.mesh = star
		_:
			var slab := BoxMesh.new()
			slab.size = Vector3(1.6, 0.4, 0.4)
			node.mesh = slab
	node.material_override = mat
	return node


func _process(delta: float) -> void:
	if offers.is_empty():
		return
	_spin += delta * 1.8
	for gate in _gates:
		var topper := gate.get_node_or_null("Topper") as Node3D
		if topper != null:
			topper.rotation = Vector3(0.0, _spin, 0.0)
