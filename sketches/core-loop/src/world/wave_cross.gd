extends Node3D

const EventKinds := preload("res://src/core/event_kinds.gd")
const Palette := preload("res://src/core/palette.gd")
const Self := preload("res://src/world/wave_cross.gd")

# The twin of the arena_wave whistle (event_kinds.gd WORLD_ROWS row "arena_wave"): one hazard cross per spot the
# crew lands on, held up at the height the crew drops from and turned to face the camera. It is not
# a floor ring, because nothing at the landing spot hurts (LEGIBILITY.md line 21: the floor is the
# hazard's alone). Colour and shape come from the registry row, so the sound and this mark cannot drift.
const KIND := "arena_wave"
const ARM_M := 1.6
const INNER_M := 0.66
const ARM_WIDTH_M := 0.34
# The full opening mark spans at most 8% of screen height (58 px at 720p).
const MAX_HEIGHT_SHARE := 0.08
const SPAN_M := (2.0 * ARM_M + ARM_WIDTH_M) * 0.70710678
const START_SCALE := 2.2

var _tips: ArrayMesh
var _distant_cross: ArrayMesh
var shape := ""
var _lead_s := 0.0
var _hold_s := 0.0
var _age := 0.0


# Shows a cross at each spot. Over lead_s it closes from START_SCALE to its true size; hold_s keeps
# it there before it frees itself (0 leaves the removal to the caller, as the yard does when it lands).
static func mark(parent: Node, spots: Array, lead_s: float, hold_s := 0.0) -> Node3D:
	var cross := Self.new()
	cross.name = "ArenaWaveMarks"
	cross.process_priority = 100
	cross._lead_s = maxf(lead_s, 0.001)
	cross._hold_s = hold_s
	cross.shape = String(EventKinds.world_row(KIND).get("shape", ""))
	parent.add_child(cross)
	cross._tips = _mesh(INNER_M, ARM_WIDTH_M)
	cross._distant_cross = _mesh(0.0, 0.5)
	var material := Palette.unshaded(EventKinds.world_row(KIND).get("color", Palette.HAZARD))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	for spot in spots:
		var arms := MeshInstance3D.new()
		arms.mesh = cross._distant_cross
		arms.material_override = material
		cross.add_child(arms)
		arms.global_position = spot
	cross._close()
	return cross


func _physics_process(delta: float) -> void:
	_age += delta
	if _hold_s > 0.0 and _age >= _lead_s + _hold_s:
		queue_free()


# Reproject after the chase camera moves, including frames between physics ticks.
func _process(_delta: float) -> void:
	_close()


func _close() -> void:
	var camera := get_viewport().get_camera_3d()
	var left := clampf(1.0 - _age / _lead_s, 0.0, 1.0)
	for arms in get_children():
		var unit := 1.0
		var tips := false
		if camera != null and not camera.is_position_behind(arms.global_position):
			var centre: Vector2 = camera.unproject_position(arms.global_position)
			var top: Vector2 = camera.unproject_position(arms.global_position + camera.global_basis.y)
			var full_span := centre.distance_to(top) * SPAN_M * START_SCALE
			# At distance the strokes meet. Up close they open over the live shell.
			var screen_h := get_viewport().get_visible_rect().size.y
			tips = full_span >= screen_h * (0.036 if arms.mesh == _tips else 0.04)
			if full_span > 0.0:
				unit = minf(1.0, MAX_HEIGHT_SHARE * screen_h / full_span)
		arms.mesh = _tips if tips else _distant_cross
		arms.scale = Vector3.ONE * unit * lerpf(1.0, START_SCALE, left)


# Four diagonal tips keep the centre open over a live attack, all on one surface.
static func _mesh(inner: float, stroke: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in 4:
		var turn := PI * (0.25 + i * 0.5)
		var along := Vector3(cos(turn), sin(turn), 0.0)
		var across := Vector3(-sin(turn), cos(turn), 0.0)
		var base := verts.size()
		for corner in [Vector2(inner, -0.5), Vector2(ARM_M, -0.5), Vector2(ARM_M, 0.5), Vector2(inner, 0.5)]:
			verts.append(along * corner.x + across * stroke * corner.y)
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
