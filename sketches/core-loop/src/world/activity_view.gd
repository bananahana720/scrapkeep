extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const PresentationRows := preload("res://src/presentation/rows.gd")

# What a standing activity looks like (LEGIBILITY section 7 and 9): an amber light column from
# the site's first frame, the row's glyph at its top, a dashed ground ring and, within WORD_REACH,
# the row's one word. Colour, shape and word come from EventKinds.ACTIVITY_ROWS; nothing here
# picks its own. Steady means no pulse and no timer. finish() takes all four away.

const COLUMN_HEIGHT := 70.0
const COLUMN_WIDTH := 1.4
const GLYPH_SIZE := 3.2
const GLYPH_ENERGY := 2.4
const COLUMN_ENERGY := 1.8
const COLUMN_ALPHA := 0.55
const BEAM_ALPHA := 0.5
const RING_DASHES := 20
const WORD_REACH := 30.0
const WORD_HEIGHT := 5.0

var id := ""
var column: MeshInstance3D
var glyph: Node3D
var ring: Node3D
var word: Label3D
var shown := true
var cue_record := {}
var _tell_audio
# How far the word reads; a stage modifier scales it with the column (set_sight).
var word_reach := WORD_REACH
var _tell_heard := false


func build(activity_id: String, ring_radius: float, tell := {}, tell_audio = null) -> void:
	id = activity_id
	name = "View_" + id
	var row := EventKinds.activity_row(String(tell.get("record", id))).duplicate(true)
	if not tell.is_empty():
		row["word"] = tell.word
	cue_record = row
	_tell_audio = tell_audio
	var color := EventKinds.role_color(String(row.color))
	column = MeshInstance3D.new()
	column.name = "Column"
	var cm := BoxMesh.new()
	cm.size = Vector3(COLUMN_WIDTH, COLUMN_HEIGHT, COLUMN_WIDTH)
	column.mesh = cm
	column.material_override = Palette.unshaded(_veil(color, COLUMN_ALPHA))
	column.position = Vector3.UP * COLUMN_HEIGHT * 0.5
	add_child(column)
	glyph = _glyph(String(row.get("shape", "none")), color)
	glyph.name = "Glyph"
	glyph.position = Vector3.UP * (COLUMN_HEIGHT + GLYPH_SIZE)
	add_child(glyph)
	ring = _ring(ring_radius, color)
	ring.name = "Ring"
	add_child(ring)
	word = Label3D.new()
	word.name = "Word"
	word.text = String(row.get("word", ""))
	word.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	word.no_depth_test = true
	word.modulate = color
	word.pixel_size = 0.012
	word.font_size = 64
	word.position = Vector3.UP * WORD_HEIGHT
	word.visible = false
	add_child(word)


# A stage modifier's sight scale (SI3): the column, its glyph and the word's reach grow or shrink
# together. It only draws; 1.0 leaves the view as built.
func set_sight(scale: float) -> void:
	if column == null or is_equal_approx(scale, 1.0):
		return
	var height := COLUMN_HEIGHT * scale
	(column.mesh as BoxMesh).size.y = height
	column.position = Vector3.UP * height * 0.5
	glyph.position = Vector3.UP * (height + GLYPH_SIZE)
	word_reach = WORD_REACH * scale


# The word shows only near the site. A finished site shows nothing.
func near(ball: Vector3) -> void:
	if word == null or not shown:
		return
	word.visible = Vector2(ball.x - global_position.x, ball.z - global_position.z).length() <= word_reach
	if word.visible and _tell_audio != null and not _tell_heard:
		_tell_heard = _tell_audio.play("interaction_found", 0.0, 1.0, "SFX", PresentationRows.heard(cue_record, _tell_audio.cue_context()))


func finish() -> void:
	shown = false
	for part in [column, glyph, ring, word]:
		if part != null:
			part.visible = false


func lit() -> bool:
	return shown and column.visible and glyph.visible and ring.visible


# The glyph is a solid, so it reads from every side: a cross of three bars, a diamond (an
# octahedron) or a cube.
static func _glyph(shape: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := Palette.solid(color, GLYPH_ENERGY)
	match shape:
		"cross":
			for axis in 3:
				var size := Vector3.ONE * GLYPH_SIZE * 0.3
				size[axis] = GLYPH_SIZE
				root.add_child(_box(size, mat))
		"diamond":
			var mesh := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = GLYPH_SIZE * 0.55
			sm.height = GLYPH_SIZE * 1.1
			sm.radial_segments = 4
			sm.rings = 2
			mesh.mesh = sm
			mesh.material_override = mat
			root.add_child(mesh)
		_:
			root.add_child(_box(Vector3.ONE * GLYPH_SIZE * 0.8, mat))
	return root


static func _veil(color: Color, alpha: float) -> Color:
	var out := color
	out.a = alpha
	return out


static func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	return mesh


static func _ring(radius: float, color: Color) -> Node3D:
	var out := Node3D.new()
	var mat := Palette.solid(color, COLUMN_ENERGY)
	for k in RING_DASHES:
		var a := TAU * k / float(RING_DASHES)
		var dash := _box(Vector3(0.45, 0.1, radius * TAU / float(RING_DASHES * 2)), mat)
		dash.position = Vector3(cos(a), 0.06, sin(a)) * radius
		dash.rotation.y = -a
		out.add_child(dash)
	return out


# The pay: an amber gem on a short plinth, the same shape as the row's glyph.
static func gem(id_ref: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Pay"
	var color := EventKinds.activity_color(id_ref)
	var stone := _glyph(String(EventKinds.activity_row(id_ref).get("shape", "none")), color)
	stone.scale = Vector3.ONE * 0.35
	stone.position = Vector3.UP * 1.4
	root.add_child(stone)
	var beam := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.35, 14.0, 0.35)
	beam.mesh = cm
	beam.material_override = Palette.unshaded(_veil(color, BEAM_ALPHA))
	beam.position = Vector3.UP * 7.0
	root.add_child(beam)
	return root
