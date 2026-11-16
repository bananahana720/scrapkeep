extends SceneTree

const T := preload("res://tests/support/t.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Hazard := preload("res://src/boss/hazard.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# PF-52: a hostile landing's flash, crack ring and dust (TINTED_LAYERS) drew with no depth test in
# every look, so a landing behind a ridge painted the screen flat orange. In the clear and edges
# looks each tinted layer is now depth tested and moved DEPTH_PULL metres toward the eye; haze and
# classic keep the old draw. The pull lives in Painter, so the live fill of an INSTANT telegraph and
# of a boss hazard, plain Painters, get it too.

var _t := T.new("threat_landing_depth_test")


class Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	_run.call_deferred()


# The landing Flash a hostile INSTANT ring leaves in `world`.
func _landing(world: Node3D) -> Node3D:
	var ring := Telegraph.ring(world, Flat.new(), Threat.Type.INSTANT, Vector3(0.0, 0.0, -30.0), 4.0)
	ring.land()
	ring.free()
	for node in world.get_children():
		if node.get("_tone") != null and node.get("_fill") != null:
			return node
	return null


func _run() -> void:
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.global_position = Vector3(0.0, 3.0, 0.0)
	cam.make_current()
	for look in ["clear", "edges", "haze", "classic"]:
		Threat.set_look(look)
		var world := Node3D.new()
		root.add_child(world)
		await process_frame
		var flash := _landing(world)
		_t.check("%s: a hostile INSTANT ring leaves a landing" % look, flash != null)
		if flash == null:
			world.free()
			continue
		await process_frame
		var layers: Dictionary = flash._layers
		for layer in Threat.TINTED_LAYERS:
			_t.check("%s: the landing has a %s layer" % [look, layer], layers.has(layer))
			if not layers.has(layer):
				continue
			var instance: MeshInstance3D = layers[layer]
			var tested: bool = not (instance.material_override as StandardMaterial3D).no_depth_test
			var want: bool = look in ["clear", "edges"]
			_t.check("%s: the %s layer %s" % [look, layer, "is depth tested" if want else "keeps no depth test"], tested == want)
			var aabb := instance.mesh.get_aabb()
			var middle: Vector3 = instance.global_transform * aabb.get_center()
			var moved := instance.global_position.length()
			var line := (cam.global_position - middle)
			_t.check("%s: the %s layer %s" % [look, layer, "sits DEPTH_PULL metres toward the eye" if want else "stays where it was drawn"],
				absf(moved - Threat.DEPTH_PULL) < 0.001 if want else moved < 0.001, "moved %.3f m" % moved)
			if want:
				# The layer moved to its pull, so its middle is nearer the lens than where it lies.
				var before := middle - instance.global_position
				_t.check("%s: the %s layer's middle is %.1f m nearer the lens" % [look, layer, Threat.DEPTH_PULL],
					absf((cam.global_position - before).length() - line.length() - Threat.DEPTH_PULL) < 0.01)
		world.free()
	for look in ["clear", "edges", "haze", "classic"]:
		Threat.set_look(look)
		var world := Node3D.new()
		root.add_child(world)
		var ring := Telegraph.ring(world, Flat.new(), Threat.Type.INSTANT, Vector3(0.0, 0.0, -30.0), 4.0)
		ring.set_progress(1.0)
		var hazard := Hazard.new()
		hazard.commit_annulus("pf52_test", Threat.Type.INSTANT, Vector3(0.0, 0.0, -30.0), Vector2(3.0, 6.0), 3.5, 1.0, 1.0)
		world.add_child(hazard)
		await process_frame
		await process_frame
		_owner_fill(look, "live INSTANT telegraph", ring.painter(), cam)
		_owner_fill(look, "boss hazard", hazard.painter(), cam)
		world.free()
	Threat.set_look("haze")
	quit(_t.verdict())


# The fill layer of a Painter an owner (a telegraph, a boss hazard) made: depth tested and pulled
# DEPTH_PULL toward the eye in the soft looks, left alone in haze and classic.
func _owner_fill(look: String, who: String, painter, cam: Camera3D) -> void:
	var has: bool = painter != null and painter._layers.has("fill")
	_t.check("%s: the %s has a fill layer" % [look, who], has)
	if not has:
		return
	var instance: MeshInstance3D = painter._layers["fill"]
	var want: bool = look in ["clear", "edges"]
	var tested: bool = not (instance.material_override as StandardMaterial3D).no_depth_test
	_t.check("%s: the %s fill %s" % [look, who, "is depth tested" if want else "keeps no depth test"], tested == want)
	var moved := instance.global_position.length()
	_t.check("%s: the %s fill %s" % [look, who, "sits DEPTH_PULL metres toward the eye" if want else "stays where it was drawn"],
		absf(moved - Threat.DEPTH_PULL) < 0.001 if want else moved < 0.001, "moved %.3f m" % moved)
