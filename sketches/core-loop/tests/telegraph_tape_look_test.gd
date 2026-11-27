extends SceneTree

const T := preload("res://tests/support/t.gd")
const Palette := preload("res://src/core/palette.gd")
const Telegraph := preload("res://src/combat/telegraph.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The telegraph row's tape look (UI findings UF-02 and UF-03; Andrew, 13 Nov 2026: keep the
# colours, add shapes). Danger red and the player's own amber read as one colour under red-green
# colour blindness, so a hostile floor must differ from the player's own by shape. Tape is the
# clear look with the hostile stripes back as a faint band of the same red.
#   - tape is a soft look and a haze look: everything clear changed stays changed;
#   - a hostile ring's fill layers draw the stripe pattern; the player's own amber ring and a
#     harmless bone ring draw none;
#   - the band is the same red, darker, never charcoal: lighter than classic's bar, and narrower;
#   - clear, edges and haze still draw no stripes, and classic still draws its own;
#   - planted: a pattern whose band is as light as the rest carries no shape, and the judge
#     fails it.

var _t := T.new("telegraph_tape_look_test")


class Flat:
	func height(_x: float, _z: float) -> float:
		return 0.0


func _initialize() -> void:
	_run.call_deferred()


# Which of a ring's layers that hold any geometry draw with the stripe pattern.
func _striped_layers(world: Node3D, tone: Color) -> Array:
	var ring: Node3D = Telegraph.ring(world, Flat.new(), Threat.Type.INSTANT, Vector3.ZERO, 3.0, 3.5, tone)
	var out := []
	for layer in ring.painter()._layers:
		var view: MeshInstance3D = ring.painter()._layers[layer]
		if view.mesh == null or view.mesh.get_surface_count() == 0:
			continue
		var mat = view.material_override
		if (mat is ShaderMaterial and mat.shader.code.contains("#define STRIPES")) or (mat is StandardMaterial3D and mat.albedo_texture != null):
			out.append(layer)
	ring.free()
	out.sort()
	return out


# The pattern's lightest and darkest value and the dark band's share of a period.
static func _pattern(texture: Texture2D) -> Dictionary:
	var image := texture.get_image()
	var light := 0.0
	var dark := 1.0
	var dark_px := 0
	for x in image.get_width():
		var v := image.get_pixel(x, 0).get_luminance()
		light = maxf(light, v)
		dark = minf(dark, v)
	for x in image.get_width():
		if image.get_pixel(x, 0).get_luminance() < (light + dark) * 0.5:
			dark_px += 1
	return {"light": light, "dark": dark, "share": float(dark_px) / image.get_width()}


# A pattern carries a shape when its band is clearly darker than the rest, and stays faint when
# the band keeps at least half the light and less than half the ground.
static func _faint_but_there(p: Dictionary) -> bool:
	return p["dark"] <= p["light"] * 0.75 and p["dark"] >= p["light"] * 0.5 and p["share"] > 0.2 and p["share"] < 0.5


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	Threat.set_look("tape")
	_t.check("tape is a soft look and a haze look", Threat.soft() and Threat.haze() and Threat.striped())
	var hostile := _striped_layers(world, Palette.HAZARD)
	_t.check("a hostile ring's fills draw the stripe pattern", "stripe" in hostile and "stripe_motion" in hostile, str(hostile))
	_t.eq("the player's own amber ring draws no stripes", _striped_layers(world, Palette.AMBER), [])
	_t.eq("a harmless bone ring draws no stripes", _striped_layers(world, Palette.SAND), [])
	var tape := _pattern(Threat.Painter.stripe_texture())
	_t.check("tape's band is the same red, darker, and narrow", _faint_but_there(tape), str(tape))
	for name in ["haze", "clear", "edges"]:
		Threat.set_look(name)
		_t.eq("%s draws no stripes on a hostile ring" % name, _striped_layers(world, Palette.HAZARD), [])
	Threat.set_look("classic")
	_t.check("classic still stripes a hostile ring", "stripe" in _striped_layers(world, Palette.HAZARD))
	var classic := _pattern(Threat.Painter.stripe_texture())
	_t.check("classic's bar is darker and wider than tape's", classic["dark"] < tape["dark"] and classic["share"] > tape["share"], "%s against %s" % [classic, tape])
	_t.check("planted: a band as light as the rest carries no shape", not _faint_but_there({"light": 1.0, "dark": 1.0, "share": 0.35}))
	_t.check("planted: classic's charcoal bar is not faint", not _faint_but_there(classic))
	Threat.reset_for_tests()
	_t.check("with no look set, the shipping default is tape", Threat.look() == "tape" and "stripe" in _striped_layers(world, Palette.HAZARD), Threat.look())
	quit(_t.verdict())
