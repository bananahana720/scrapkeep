extends SceneTree

# The polish bake shows through runtime materials (BakeLook): the UV2 shade lands on the faces
# outside the vertex-colour slots, owned materials change in place so the hit flash still shows,
# shared ones get twins, the vertex-colour slots only lose the world grain, and the hazard stripe
# and unbaked meshes stay as they are. Also pins the grain opt-out that keeps UV1 masks mapped.
const T := preload("res://tests/support/t.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Palette := preload("res://src/core/palette.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

var t := T.new("bake_look_test")


func _initialize() -> void:
	_run.call_deferred()


func _surface(mesh: ArrayMesh, slot: String, baked: bool, mat: Material) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3.ZERO, Vector3.RIGHT, Vector3.UP])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	if baked:
		arrays[Mesh.ARRAY_TEX_UV2] = PackedVector2Array([Vector2(1, 0.5), Vector2(0.4, 0.5), Vector2(1, 0)])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var i := mesh.get_surface_count() - 1
	mesh.surface_set_name(i, slot)
	mesh.surface_set_material(i, mat)


func _shade(ramp: Image, open: float, wear_v: float) -> float:
	return ramp.get_pixel(roundi(open * (BakeLook.RAMP - 1)), roundi(wear_v * (BakeLook.RAMP - 1))).r


func _run() -> void:
	var ramp := BakeLook.ramp().get_image()
	t.near("open, unworn: no shade", _shade(ramp, 1.0, 0.5), 1.0, 0.02)
	t.near("fully covered: the bake's AO multiplier", _shade(ramp, 0.0, 0.5), 1.0 - BakeLook.AO_STRENGTH, 0.02)
	t.near("glTF V 1 is the crease: the bake's wear multiplier", _shade(ramp, 1.0, 1.0), 1.0 - BakeLook.EDGE, 0.02)
	t.near("glTF V 0 is the worn convex edge: a multiply stops at neutral", _shade(ramp, 1.0, 0.0), 1.0, 0.02)

	var flash := Palette.solid(Color.WHITE)
	var paint := Palette.solid(Color.WHITE)
	paint.vertex_color_use_as_albedo = true
	var rubber := Palette.solid(Palette.CHARCOAL)
	var both := Palette.solid(Palette.BRASS)
	var stripe := Palette.hazard_stripe()
	var grain := rubber.normal_texture
	var body := ArrayMesh.new()
	_surface(body, "fleet_paint", true, paint)
	_surface(body, "paint", true, paint)
	_surface(body, "rubber", true, rubber)
	_surface(body, "bare_metal", true, stripe)
	_surface(body, "brass", true, both)
	var warning := StandardMaterial3D.new()
	warning.albedo_texture = Threat.Painter.stripe_texture()
	_surface(body, "bare_metal", true, warning)
	var bare := ArrayMesh.new()
	_surface(bare, "brass", false, both)
	var root := Node3D.new()
	var view := MeshInstance3D.new()
	view.mesh = body
	view.set_surface_override_material(0, flash)
	root.add_child(view)
	var plain := MeshInstance3D.new()
	plain.mesh = bare
	root.add_child(plain)

	t.eq("baked surfaces dressed, stripes and the mixed owned material skipped", BakeLook.dress(root, [flash, both]), 3)
	t.check("owned flash paint shaded in place, so the hit flash still shows", view.get_active_material(0) == flash
		and flash.get_meta("bake_look", false) and flash.detail_albedo == BakeLook.ramp()
		and flash.detail_uv_layer == BaseMaterial3D.DETAIL_UV_2 and flash.detail_blend_mode == BaseMaterial3D.BLEND_MODE_MUL
		and not flash.uv2_triplanar)
	t.check("the shade samples texel centres, so an open face never wraps to the covered column",
		flash.uv2_offset.x > 0.0 and flash.uv2_scale.x < 1.0)
	t.check("shaded paint loses the world grain (soft toy)", flash.normal_texture == null and not flash.uv1_triplanar)
	var vc := body.surface_get_material(1) as StandardMaterial3D
	t.check("vertex-colour slot gets a smooth twin: grain off, no second shade", vc != paint
		and vc.get_meta("bake_smooth", false) and not vc.detail_enabled and vc.normal_texture == null and vc.vertex_color_use_as_albedo)
	var twin := body.surface_get_material(2) as StandardMaterial3D
	t.check("shared rubber swapped for a shaded twin; the original keeps its grain", twin != rubber
		and twin.get_meta("bake_look", false) and rubber.normal_texture == grain and not rubber.get_meta("bake_look", false))
	t.check("hazard stripe stays flat", body.surface_get_material(3) == stripe and not stripe.get_meta("bake_look", false))
	t.check("a script's own stripe (the threat texture) stays flat", body.surface_get_material(5) == warning and not warning.get_meta("bake_look", false))
	t.check("owned material that also draws an unbaked mesh stays as it is, so its changes keep drawing",
		body.surface_get_material(4) == both and not both.get_meta("bake_look", false) and bare.surface_get_material(0) == both)
	var debris := BakeLook.unbaked(flash) as StandardMaterial3D
	t.check("a mesh with no UV2 borrows the material without the shade", debris != flash and not debris.detail_enabled
		and debris.albedo_color == flash.albedo_color and BakeLook.unbaked(rubber) == rubber)
	t.eq("dressing again changes nothing", BakeLook.dress(root, [flash, both]), 0)
	t.check("twins are shared between instances", BakeLook.twin(rubber) == twin)

	var ungrained := Palette.solid(Palette.BRASS, 0.0, false)
	t.check("solid without grain keeps plain UV1 for its own mask", not ungrained.uv1_triplanar and ungrained.normal_texture == null
		and not ungrained.detail_enabled and ungrained.get_meta("palette_solid", false))
	var enemy := Enemy.new()
	var plate: StandardMaterial3D = enemy._plate_material()
	t.check("plate rim mask maps on the mesh's UV1, not world grain (it striped the plates)", not plate.uv1_triplanar and plate.emission_texture != null)
	enemy.free()
	root.free()
	quit(t.verdict())
