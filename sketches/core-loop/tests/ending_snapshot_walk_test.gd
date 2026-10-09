extends SceneTree

# Rule (src/ui/ending_sequence.gd _snapshot): the fly-over copy walks every visible node of a
# stage. Meshes and multimeshes are copied with their render layers and materials; any other node,
# a plain Node3D or a drawing kind the walk does not copy (particles, labels, sprites), becomes a
# plain holder with its transform and children. Found by INTEG-FIX-1 (wave 12): the Highdraft's
# NetDust GPUParticles3D reached the layers copy on a plain Node3D and stopped the ending's walk.

const Sequence := preload("res://src/ui/ending_sequence.gd")
const T := preload("res://tests/support/t.gd")

const MESH_LAYERS := 5

var _t := T.new("ending_snapshot_walk_test")


func _initialize() -> void:
	var stage := _stage()
	var holder := Node3D.new()
	var seq = Sequence.new()
	seq._snapshot(stage, holder, true)
	var copy := holder.get_node_or_null("Stage")
	if not _t.check("the walk copies the stage root", copy != null):
		quit(_t.verdict())
		return
	for path in ["Mesh", "Plain", "Plain/Inner", "NetDust", "NetDust/Child", "Grit", "Sign", "Badge"]:
		_t.check("the walk copies " + path, copy.has_node(path))
	var mesh := copy.get_node_or_null("Mesh") as MeshInstance3D
	_t.check("a mesh copy keeps its render layers", mesh != null and mesh.layers == MESH_LAYERS,
		"layers %s" % (mesh.layers if mesh != null else -1))
	for path in ["Plain", "NetDust", "Grit", "Sign", "Badge"]:
		var view := copy.get_node_or_null(path)
		_t.check(path + " becomes a plain holder", view != null and view.get_class() == "Node3D",
			view.get_class() if view != null else "missing")
	var dust := copy.get_node_or_null("NetDust") as Node3D
	_t.check("a holder keeps its source transform", dust != null and dust.position.is_equal_approx(Vector3(2.0, 3.0, 4.0)))
	_t.check("a child under a holder is still a mesh", copy.get_node_or_null("NetDust/Child") is MeshInstance3D)
	seq.free()
	stage.free()
	holder.free()
	quit(_t.verdict())


func _stage() -> Node3D:
	var stage := Node3D.new()
	stage.name = "Stage"
	var mesh := MeshInstance3D.new()
	mesh.name = "Mesh"
	mesh.mesh = BoxMesh.new()
	mesh.layers = MESH_LAYERS
	stage.add_child(mesh)
	var plain := Node3D.new()
	plain.name = "Plain"
	stage.add_child(plain)
	var inner := MeshInstance3D.new()
	inner.name = "Inner"
	inner.mesh = BoxMesh.new()
	plain.add_child(inner)
	var dust := GPUParticles3D.new()
	dust.name = "NetDust"
	dust.position = Vector3(2.0, 3.0, 4.0)
	stage.add_child(dust)
	var child := MeshInstance3D.new()
	child.name = "Child"
	child.mesh = BoxMesh.new()
	dust.add_child(child)
	var grit := CPUParticles3D.new()
	grit.name = "Grit"
	stage.add_child(grit)
	var sign := Label3D.new()
	sign.name = "Sign"
	stage.add_child(sign)
	var badge := Sprite3D.new()
	badge.name = "Badge"
	stage.add_child(badge)
	return stage
