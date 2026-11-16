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
const ARM_WIDTH_M := 0.5
const START_SCALE := 2.2

var shape := ""
var _lead_s := 0.0
var _hold_s := 0.0
var _age := 0.0


# Shows a cross at each spot. Over lead_s it closes from START_SCALE to its true size; hold_s keeps
# it there before it frees itself (0 leaves the removal to the caller, as the yard does when it lands).
static func mark(parent: Node, spots: Array, lead_s: float, hold_s := 0.0) -> Node3D:
	var cross := Self.new()
	cross.name = "ArenaWaveMarks"
	cross._lead_s = maxf(lead_s, 0.001)
	cross._hold_s = hold_s
	cross.shape = String(EventKinds.world_row(KIND).get("shape", ""))
	parent.add_child(cross)
	var mesh := _mesh()
	var material := Palette.unshaded(EventKinds.world_row(KIND).get("color", Palette.HAZARD))
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.billboard_keep_scale = true
	for spot in spots:
		var arms := MeshInstance3D.new()
		arms.mesh = mesh
		arms.material_override = material
		cross.add_child(arms)
		arms.global_position = spot
	cross._close()
	return cross


func _physics_process(delta: float) -> void:
	_age += delta
	if _hold_s > 0.0 and _age >= _lead_s + _hold_s:
		queue_free()
		return
	_close()


func _close() -> void:
	var left := clampf(1.0 - _age / _lead_s, 0.0, 1.0)
	for arms in get_children():
		arms.scale = Vector3.ONE * (1.0 + (START_SCALE - 1.0) * left)


# Two bars crossing at right angles, in the mesh's own XY plane, as one surface.
static func _mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for turn in [PI * 0.25, -PI * 0.25]:
		var along := Vector3(cos(turn), sin(turn), 0.0)
		var across := Vector3(-sin(turn), cos(turn), 0.0)
		var base := verts.size()
		for corner in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
			verts.append(along * ARM_M * corner[0] + across * ARM_WIDTH_M * 0.5 * corner[1])
		indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
