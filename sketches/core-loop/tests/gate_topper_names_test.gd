extends SceneTree

# Rule: the gate GLB holds exactly common, rare, relic and evolved toppers. Each
# resolves directly through HeroAssets to a mesh and dresses its live placeholder.
# Evolved is a crown (relic a four-point star) and stands at least 20% taller than relic.
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const RARITIES := ["common", "rare", "relic", "evolved"]
const TOPPERS := ["Topper_common", "Topper_rare", "Topper_relic", "Topper_evolved"]


class GateParent:
	extends Node3D
	var offers: Array = []


var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _run() -> void:
	var packed := load(HeroAssets.GATE_PATH) as PackedScene
	_report("gate imports", packed != null, HeroAssets.GATE_PATH + " loads as a PackedScene")
	if packed != null:
		_check_toppers(packed.instantiate())
	print("gate_topper_names_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check_toppers(scene: Node) -> void:
	var actual: Array[String] = []
	for node in scene.find_children("Topper_*", "", true, false):
		actual.append(String(node.name))
	actual.sort()
	var expected := TOPPERS.duplicate()
	expected.sort()
	_report("exact topper names", actual == expected, "expected %s, found %s; no legacy names" % [expected, actual])
	var hook := HeroAssets.new()
	root.add_child(hook)
	for i in RARITIES.size():
		var rarity: String = RARITIES[i]
		var node_name: String = TOPPERS[i]
		_report("direct lookup " + rarity, HeroAssets.topper_name(rarity) == node_name, "Topper_ + rarity = " + node_name)
		var mesh := hook.mesh_named(HeroAssets.GATE_PATH, HeroAssets.topper_name(rarity))
		var authored := scene.find_child(node_name, true, false) as MeshInstance3D
		_report("resolved mesh " + rarity, mesh != null and authored != null and authored.mesh == mesh,
			"HeroAssets resolves the authored " + node_name + " mesh")
		_check_dressed(hook, rarity, mesh)
	var relic := hook.mesh_named(HeroAssets.GATE_PATH, "Topper_relic")
	var evolved := hook.mesh_named(HeroAssets.GATE_PATH, "Topper_evolved")
	var relic_height := relic.get_aabb().size.y if relic != null else 0.0
	var evolved_height := evolved.get_aabb().size.y if evolved != null else 0.0
	_report("evolved taller crown", relic_height > 0.0 and evolved_height >= relic_height * 1.2,
		"relic %.3f m, evolved %.3f m; evolved at least 20%% taller" % [relic_height, evolved_height])
	hook.free()
	scene.free()


func _check_dressed(hook: Node, rarity: String, mesh: Mesh) -> void:
	var parent := GateParent.new()
	parent.offers = [{"at": Vector3.ZERO, "rarity": rarity}]
	root.add_child(parent)
	var gate := Node3D.new()
	parent.add_child(gate)
	var topper := MeshInstance3D.new()
	topper.name = "Topper"
	topper.mesh = BoxMesh.new()
	gate.add_child(topper)
	hook._dress_gate(gate)
	var hero := topper.get_node_or_null("HeroTopper") as MeshInstance3D
	_report("dressed topper " + rarity, mesh != null and hero != null and hero.mesh == mesh and topper.layers == 0,
		"HeroTopper wears the resolved mesh and hides the primitive")
	parent.free()
