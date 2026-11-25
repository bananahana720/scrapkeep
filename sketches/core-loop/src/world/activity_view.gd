extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const PresentationRows := preload("res://src/presentation/rows.gd")


const COLUMN_HEIGHT := 70.0
const COLUMN_WIDTH := 1.4
const GLYPH_SIZE := 3.2
const GLYPH_ENERGY := 2.4
const COLUMN_ENERGY := 1.8
const COLUMN_ALPHA := 0.55
const COLUMN_FADE := Vector2(3.0, 14.0)
const BEAM_ALPHA := 0.5
const RING_DASHES := 20
const RING_VIEW_END_M := 420.0
const RING_VIEW_MARGIN_M := 30.0
const WORD_REACH := 30.0
const WORD_HEIGHT := 5.0
const WORD_GAP := 116.0
const WORD_OUTLINE := 14
const WORD_WIDTH := 760.0

var id := ""
var column: MeshInstance3D
var glyph: Node3D
var ring: Node3D
var word: Label3D
var shown := true
var cue_record := {}
var _tell_audio
var word_reach := WORD_REACH
var _tell_heard := false

static var _shared := {}


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
	column.mesh = _box_mesh(Vector3(COLUMN_WIDTH, COLUMN_HEIGHT, COLUMN_WIDTH))
	column.material_override = _column_material(color)
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
	word.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	word.offset = Vector2(WORD_GAP, 0.0)
	word.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	word.width = WORD_WIDTH
	word.outline_size = WORD_OUTLINE
	word.outline_modulate = Palette.CHARCOAL
	word.modulate = color
	word.pixel_size = 0.012
	word.font_size = 64
	word.position = Vector3.UP * WORD_HEIGHT
	word.visible = false
	add_child(word)


func set_sight(scale: float) -> void:
	if column == null or is_equal_approx(scale, 1.0):
		return
	var height := COLUMN_HEIGHT * scale
	var own := column.mesh.duplicate() as BoxMesh
	own.size.y = height
	column.mesh = own
	column.position = Vector3.UP * height * 0.5
	glyph.position = Vector3.UP * (height + GLYPH_SIZE)
	word_reach = WORD_REACH * scale


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


func say(text: String) -> void:
	word.text = text


func ring_role(role: String) -> void:
	if ring == null:
		return
	var mat := _solid(EventKinds.role_color(role), COLUMN_ENERGY)
	for dash in ring.get_children():
		(dash as MeshInstance3D).material_override = mat


func lit() -> bool:
	return shown and column.visible and glyph.visible and ring.visible


static func _glyph(shape: String, color: Color) -> Node3D:
	var root := Node3D.new()
	var mat := _solid(color, GLYPH_ENERGY)
	match shape:
		"cross":
			for axis in 3:
				var size := Vector3.ONE * GLYPH_SIZE * 0.3
				size[axis] = GLYPH_SIZE
				root.add_child(_box(size, mat))
		"diamond":
			var mesh := MeshInstance3D.new()
			if not _shared.has("diamond"):
				var sm := SphereMesh.new()
				sm.radius = GLYPH_SIZE * 0.55
				sm.height = GLYPH_SIZE * 1.1
				sm.radial_segments = 4
				sm.rings = 2
				_shared["diamond"] = sm
			mesh.mesh = _shared["diamond"]
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
	mesh.mesh = _box_mesh(size)
	mesh.material_override = mat
	return mesh


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box:%s" % size
	if not _shared.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_shared[key] = bm
	return _shared[key]


static func _solid(color: Color, emit: float) -> StandardMaterial3D:
	var key := "solid:%s:%s" % [color.to_html(), emit]
	if not _shared.has(key):
		_shared[key] = Palette.solid(color, emit)
	return _shared[key]


static func _unshaded(color: Color) -> StandardMaterial3D:
	var key := "unshaded:%s" % color.to_html()
	if not _shared.has(key):
		_shared[key] = Palette.unshaded(color)
	return _shared[key]


static func _column_material(color: Color) -> StandardMaterial3D:
	var key := "column:%s" % color.to_html()
	if not _shared.has(key):
		var mat := Palette.unshaded(_veil(color, COLUMN_ALPHA))
		mat.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		mat.distance_fade_min_distance = COLUMN_FADE.x
		mat.distance_fade_max_distance = COLUMN_FADE.y
		_shared[key] = mat
	return _shared[key]


static func _ring(radius: float, color: Color) -> Node3D:
	var out := Node3D.new()
	var mat := _solid(color, COLUMN_ENERGY)
	var dash_mesh := _box_mesh(Vector3(0.45, 0.1, radius * TAU / float(RING_DASHES * 2)))
	for k in RING_DASHES:
		var a := TAU * k / float(RING_DASHES)
		var dash := MeshInstance3D.new()
		dash.mesh = dash_mesh
		dash.material_override = mat
		dash.position = Vector3(cos(a), 0.06, sin(a)) * radius
		dash.rotation.y = -a
		dash.visibility_range_end = RING_VIEW_END_M
		dash.visibility_range_end_margin = RING_VIEW_MARGIN_M
		dash.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		out.add_child(dash)
	return out


static func gem(id_ref: String) -> Node3D:
	var root := Node3D.new()
	root.name = "Pay"
	var color := EventKinds.activity_color(id_ref)
	var stone := _glyph(String(EventKinds.activity_row(id_ref).get("shape", "none")), color)
	stone.scale = Vector3.ONE * 0.35
	stone.position = Vector3.UP * 1.4
	root.add_child(stone)
	var beam := MeshInstance3D.new()
	beam.mesh = _box_mesh(Vector3(0.35, 14.0, 0.35))
	beam.material_override = _unshaded(_veil(color, BEAM_ALPHA))
	beam.position = Vector3.UP * 7.0
	root.add_child(beam)
	return root
