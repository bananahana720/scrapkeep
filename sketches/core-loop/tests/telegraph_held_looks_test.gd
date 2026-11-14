extends SceneTree

const T := preload("res://tests/support/t.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Projectile := preload("res://src/combat/projectile.gd")

# A lobber volley rebuilt two shader looks on the 4080 every time it came after the last shell had
# gone (about 5 ms each in the physics tick, #512 probe on a542e400): each mark layer's
# StandardMaterial3D and each shell's rim material is its own, and Godot frees a look's shader with
# the last material that uses it. The first material of each look is held for the session, so once
# every ring and shell is freed a material of each look still stands, and later marks still get
# materials of their own (tint() and the rim pulse write them). A shell's stripes are driven
# (shared ShaderMaterials), so its line layers draw the plain look.

var _t := T.new("telegraph_held_looks_test")


class Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


class Ball:
	func ball_position() -> Vector3:
		return Vector3(500.0, 1.0, 500.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Held looks are the StandardMaterial3D line layers of the haze and classic looks; the soft looks
	# draw their lines with the shared, cached mark shaders (telegraph_clear_look_test).
	Threat.set_look("haze")
	var world := Node3D.new()
	root.add_child(world)
	var first_layers := {}
	var first_rim: Material
	for volley in 2:
		var shell := Projectile.new()
		world.add_child(shell)
		shell.setup(Ball.new(), Flat.new(), world, func() -> bool: return true, Vector3(10.0, 8.0, 4.0), Vector3(-6.0, 0.0, 9.0), 1.6)
		var looks := _looks(shell.ring.painter())
		var rim: Material = shell.get_node("BatRim").material_override
		if volley == 0:
			first_layers = looks
			first_rim = rim
		else:
			var own := true
			for look in looks:
				own = own and looks[look] != first_layers.get(look)
			_t.check("a later shell's mark layers draw with materials of their own", own and looks.has("plain"), str(looks.keys()))
			_t.check("a later shell's rim draws with a material of its own", rim != first_rim)
		var ring: Node = shell.ring
		shell.free()
		ring.free()
	var held: Material = Threat.Painter._held_looks.get("plain")
	_t.check("the plain mark look is held after its marks are freed", held != null and held == first_layers.get("plain"))
	_t.check("the shell rim look is held after its shells are freed", Projectile._held_rim != null and Projectile._held_rim == first_rim)
	quit(_t.verdict())


# The line layers' own materials by look (the driven layers draw with shared ShaderMaterials).
func _looks(painter) -> Dictionary:
	var out := {}
	for layer in painter._layers:
		var mat = painter._layers[layer].material_override
		if mat is StandardMaterial3D:
			var look := "striped" if mat.albedo_texture != null else "plain"
			if not out.has(look):
				out[look] = mat
	return out
