extends SceneTree

# W46-INK: the comic ink line round pilots' shells, enemies and Wardens (src/presentation/ink_outline.gd).
# What it checks:
#   weld      a hard-edged cube's split normals become one averaged diagonal per corner (no seam), the copy keeps every
#             other channel, a skinned surface stores its welded normal in its own normal-tangent frame, and the copy
#             is made once per source mesh, so a second actor reuses it.
#   weight    Warden over enemy over pilot, each capped in metres, fading to none between FADE_FROM and FADE_TO.
#   ink       warm charcoal, far from HAZARD, the mint ARC and Kindness's magenta.
#   lift      a Fleet edge layer is kept: the line chains after a copy, and BakeLook.edge_lift() is never touched.
#   filter    an opaque body takes the line; glass, see-through, unshaded, glowing, telegraph, cut-away and lens slots do
#             not; a primitive keeps its mesh; owned and shader materials line in place, shared ones through a twin.
#   again     apply() twice changes nothing more; strip() and BakeLook.unbaked() give debris no line; the switch and
#             reset_for_tests().
#   mounted   Rivet's and Sable's fitted shells, a spawned chaser, a Warden-class miniboss and Brindle all draw it.
#   cutaway   under the shipped cutaway look every pilot's shell and seated AnimatedPilot draw it, the shell through the
#             variant that cuts the same window (hero_warden_assets_test checks live clamp and park Wardens).
#   reset     a twin lives on the view, never the shared welded mesh, so a role after reset_for_tests() draws fresh.

const T := preload("res://tests/support/t.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Palette := preload("res://src/core/palette.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const BakeWarm := preload("res://src/presentation/bake_warm.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const BallLooks := preload("res://src/presentation/ball_looks.gd")

var _t := T.new("ink_outline_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	InkOutline.reset_for_tests()
	_weld()
	_skinned()
	_weight()
	_ink()
	_lift()
	_filter()
	_again()
	_reset_roles()
	await _mounted()
	await _cutaway()
	InkOutline.reset_for_tests()
	quit(_t.verdict())


func _cube(bones := false) -> ArrayMesh:
	var arrays := BoxMesh.new().surface_get_arrays(0)
	if bones:
		var count: int = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var ids := PackedInt32Array()
		var weights := PackedFloat32Array()
		for v in count:
			ids.append_array([0, 0, 0, 0])
			weights.append_array([1.0, 0.0, 0.0, 0.0])
		arrays[Mesh.ARRAY_BONES] = ids
		arrays[Mesh.ARRAY_WEIGHTS] = weights
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_name(0, "paint")
	return mesh


func _custom(mesh: Mesh, v: int) -> Vector4:
	var custom: PackedFloat32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]
	return Vector4(custom[v * 4], custom[v * 4 + 1], custom[v * 4 + 2], custom[v * 4 + 3])


func _weld() -> void:
	var cube := _cube()
	var hull := InkOutline.hull(cube)
	_t.check("a cube copies with a welded normal channel", hull != null and hull != cube
		and (hull.surface_get_format(0) & Mesh.ARRAY_FORMAT_CUSTOM0) != 0)
	if hull == null:
		return
	var source := cube.surface_get_arrays(0)
	var copied := hull.surface_get_arrays(0)
	var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var corners := {}
	var diagonal := true
	var split := 0
	for v in points.size():
		var welded := _custom(hull, v)
		var n := Vector3(welded.x, welded.y, welded.z)
		var key := points[v].snappedf(0.001)
		if corners.has(key):
			if (corners[key] as Vector3).dot(n) < 0.99999:
				diagonal = false
		corners[key] = n
		diagonal = diagonal and n.dot(points[v].sign().normalized()) > 0.9999 and welded.w == 0.0
		if (source[Mesh.ARRAY_NORMAL] as PackedVector3Array)[v].dot(n) < 0.99:
			split += 1
	_t.check("every corner's split normals weld to one diagonal: no seam", diagonal and corners.size() == 8 and split == points.size(),
		"%d corners, %d split normals replaced" % [corners.size(), split])
	_t.check("the copy keeps positions, normals, UVs, tangents and indices as they were",
		copied[Mesh.ARRAY_VERTEX] == source[Mesh.ARRAY_VERTEX] and copied[Mesh.ARRAY_NORMAL] == source[Mesh.ARRAY_NORMAL]
		and copied[Mesh.ARRAY_TEX_UV] == source[Mesh.ARRAY_TEX_UV] and copied[Mesh.ARRAY_INDEX] == source[Mesh.ARRAY_INDEX]
		and copied[Mesh.ARRAY_TANGENT] == source[Mesh.ARRAY_TANGENT] and hull.surface_get_name(0) == "paint")
	var a := _view(cube, _body())
	var b := _view(cube, _body())
	InkOutline.apply(a)
	InkOutline.apply(b)
	_t.check("the welded copy is made once per source mesh and shared", a.mesh == hull and b.mesh == hull and InkOutline.hull(cube) == hull
		and InkOutline.hull(hull) == hull)
	a.free()
	b.free()


func _skinned() -> void:
	var hull := InkOutline.hull(_cube(true))
	if not _t.check("a skinned cube copies", hull != null):
		return
	var arrays := hull.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	var ok := arrays[Mesh.ARRAY_BONES] != null and arrays[Mesh.ARRAY_WEIGHTS] != null
	for v in points.size():
		var c := _custom(hull, v)
		var n := normals[v]
		var t := Vector3(tangents[v * 4], tangents[v * 4 + 1], tangents[v * 4 + 2])
		t = (t - n * n.dot(t)).normalized()
		var rebuilt := t * c.x + n.cross(t) * c.y + n * c.z
		ok = ok and c.w == 1.0 and rebuilt.dot(points[v].sign().normalized()) > 0.9999
	_t.check("a skinned surface keeps its bones and stores the welded normal in its own normal-tangent frame", ok)


func _weight() -> void:
	_t.check("a Warden's line is the heaviest and a pilot's the lightest", InkOutline.WIDTH_PX.warden > InkOutline.WIDTH_PX.enemy
		and InkOutline.WIDTH_PX.enemy > InkOutline.WIDTH_PX.pilot and InkOutline.WIDTH_PX.pilot >= 1.5 and InkOutline.WIDTH_PX.warden <= 2.8
		and InkOutline.WIDTH_PX.enemy <= 2.0)
	_t.near("near, the line is its pixel width", InkOutline.width_at("enemy", 10.0, 0.01), InkOutline.WIDTH_PX.enemy * 0.01)
	_t.check("far, the line stops at its cap in metres", is_equal_approx(InkOutline.width_at("pilot", 40.0, 0.5), InkOutline.WIDTH_CAP.pilot)
		and InkOutline.WIDTH_CAP.pilot < InkOutline.WIDTH_CAP.enemy and InkOutline.WIDTH_CAP.enemy < InkOutline.WIDTH_CAP.warden)
	var mid := InkOutline.width_at("warden", 80.0, 0.01)
	_t.check("the line fades out between FADE_FROM and FADE_TO", InkOutline.FADE_FROM == 65.0 and InkOutline.FADE_TO == 95.0
		and is_equal_approx(InkOutline.width_at("warden", 65.0, 0.01), 0.025) and mid > 0.0 and mid < 0.025
		and InkOutline.width_at("warden", 95.0, 0.01) == 0.0 and InkOutline.width_at("warden", 140.0, 0.01) == 0.0)
	_t.check("an unknown role draws as an enemy", InkOutline.ink("rogue") == InkOutline.ink("enemy")
		and InkOutline.width_at("rogue", 10.0, 0.01) == InkOutline.width_at("enemy", 10.0, 0.01))
	var warden := InkOutline.ink("warden")
	_t.check("each role's pass carries its weight and the fade", is_equal_approx(warden.get_shader_parameter("width_px"), InkOutline.WIDTH_PX.warden)
		and is_equal_approx(warden.get_shader_parameter("width_cap"), InkOutline.WIDTH_CAP.warden)
		and is_equal_approx(warden.get_shader_parameter("fade_to"), InkOutline.FADE_TO))
	var code := (warden.shader as Shader).code
	_t.check("the pass is a flat, front-culled hull that casts no shadow", code.contains("unshaded") and code.contains("cull_front")
		and code.contains("IN_SHADOW_PASS") and code.contains("CUSTOM0") and code.contains("abs(PROJECTION_MATRIX[1][1])"))


func _ink() -> void:
	var ink := InkOutline.INK
	_t.check("the ink is the warm charcoal", ink == Color(0.08, 0.09, 0.11) and InkOutline.ink("pilot").get_shader_parameter("ink") == ink
		and ink.get_luminance() < Palette.CHARCOAL.get_luminance() + 0.05)
	var far := func(other: Color) -> float:
		return Vector3(ink.r - other.r, ink.g - other.g, ink.b - other.b).length()
	_t.check("the ink is far from HAZARD and the mint", far.call(Palette.HAZARD) > 0.8 and far.call(Palette.ARC) > 0.8)
	var hue := ink.h * 360.0
	_t.check("the ink is not Kindness's magenta", not (hue >= 300.0 and hue <= 330.0) and far.call(Palette.KINDNESS) > 0.6, "hue %.0f" % hue)


func _lift() -> void:
	var lift := BakeLook.edge_lift()
	var before := [lift.next_pass, lift.get_shader_parameter("lift"), lift.get_shader_parameter("bone"), lift.get_meta_list()]
	var paint := _body()
	paint.next_pass = lift
	var view := _view(_cube(), paint)
	InkOutline.apply(view, "enemy", [paint])
	var chained := paint.next_pass
	_t.check("a Fleet paint keeps its edge layer: the line chains after a copy of it", chained != lift and chained is ShaderMaterial
		and (chained as ShaderMaterial).shader == lift.shader and chained.next_pass == InkOutline.ink("enemy")
		and is_equal_approx(chained.get_shader_parameter("lift"), BakeLook.LIFT))
	_t.check("BakeLook.edge_lift() itself is untouched", BakeLook.edge_lift() == lift
		and [lift.next_pass, lift.get_shader_parameter("lift"), lift.get_shader_parameter("bone"), lift.get_meta_list()] == before)
	_t.check("stripped, the paint keeps its edge layer and loses the line", InkOutline.strip(paint).next_pass == lift)
	view.free()


func _filter() -> void:
	var body := _body()
	var glass := _body()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var flat := _body()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var glow := _body()
	glow.emission_enabled = true
	glow.emission = Color.WHITE
	glow.emission_energy_multiplier = 2.0
	var dark_emit := _body()
	dark_emit.emission_enabled = true
	dark_emit.emission = Color.BLACK
	var add := _body()
	add.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var tagged := _body()
	tagged.set_meta("no_bake", true)
	var see := _shader("shader_type spatial;\nvoid fragment() { ALBEDO = vec3(1.0); ALPHA = 0.4; }")
	var cut := _shader("shader_type spatial;\nvoid fragment() { if (UV.x > 0.5) { discard; } ALBEDO = vec3(1.0); }")
	var live := _shader("shader_type spatial;\nuniform vec4 tint : source_color;\nvoid fragment() { ALBEDO = tint.rgb; }")
	var cases := [[body, "paint", true], [glass, "paint", false], [flat, "paint", false], [glow, "paint", false],
		[dark_emit, "paint", true], [add, "paint", false], [tagged, "paint", false], [Palette.hazard_stripe(), "paint", false],
		[_body(), "ancient_lens", false], [_body(), "slag_glow", false], [_body(), "glass", false], [_body(), "class_accent", false],
		[see, "paint", false], [cut, "paint", false], [live, "paint", true]]
	var right := 0
	for row in cases:
		if InkOutline.drawable(_cube_named(row[1]), 0, row[0]) == row[2]:
			right += 1
	_t.check("bodies and dark paint take a line; glass, see-through, unshaded, glowing, additive, telegraph, lens, accent and cut-away surfaces do not",
		right == cases.size(), "%d of %d" % [right, cases.size()])
	var holder := Node3D.new()
	var shared := _view(_cube(), body)
	var owned_paint := _body()
	var owned := _view(_cube(), owned_paint)
	var shader_view := _view(_cube(), live)
	var glass_view := _view(_cube(), glass)
	var box := MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.material_override = _body()
	var cockpit := Node3D.new()
	cockpit.name = "Cockpit"
	var lever := _view(_cube(), _body())
	cockpit.add_child(lever)
	var glass_mesh := glass_view.mesh
	for node in [shared, owned, shader_view, glass_view, box, cockpit]:
		holder.add_child(node)
	var lined := InkOutline.apply(holder, "warden", [owned_paint])
	_t.check("a shared standard material draws through an inked twin and is itself untouched", body.next_pass == null
		and shared.material_override != body and shared.material_override.next_pass == InkOutline.ink("warden")
		and shared.material_override.get_meta("ink_source") == body.get_instance_id() and body.get_meta("ink_twin_warden") == shared.material_override)
	_t.check("an owned material takes the line in place, so the hit flash's changes still draw", shared.material_override != owned_paint
		and owned.material_override == owned_paint and owned_paint.next_pass == InkOutline.ink("warden"))
	_t.check("a shader material takes the line in place", shader_view.material_override == live and live.next_pass == InkOutline.ink("warden"))
	_t.check("glass, a primitive and the cockpit's controls stay as they were", glass_view.mesh == glass_mesh and glass.next_pass == null
		and box.mesh is BoxMesh and (box.material_override as Material).next_pass == null and not lever.mesh.has_meta("ink_hull_of")
		and lined == 3, "%d lined" % lined)
	var twin: Material = shared.material_override
	_t.check("apply() twice lines nothing twice", InkOutline.apply(holder, "warden", [owned_paint]) == 3 and shared.material_override == twin
		and twin.next_pass == InkOutline.ink("warden") and InkOutline.ink("warden").next_pass == null and owned_paint.next_pass == InkOutline.ink("warden"))
	var vfx_holder := Node3D.new()
	var puff := _view(_cube(), _body())
	puff.name = "JetPuff"
	var dust := _view(_cube(), _body())
	dust.name = "DigDustQuad"
	var faded := _view(_cube(), _body())
	faded.transparency = 0.35
	var tagged_view := _view(_cube(), _body())
	tagged_view.set_meta("no_ink", true)
	var semi_mat := _body()
	semi_mat.albedo_color.a = 0.7
	var semi := _view(_cube(), semi_mat)
	for node in [puff, dust, faded, tagged_view, semi]:
		vfx_holder.add_child(node)
	var vfx_lined := InkOutline.apply(vfx_holder, "pilot")
	_t.eq("translucent, puff, dust, and no_ink VFX meshes receive zero ink outlines", vfx_lined, 0)
	vfx_holder.free()
	holder.free()


func _again() -> void:
	var paint := _body()
	var view := _view(_cube(), paint)
	BakeLook.apply(paint)
	InkOutline.apply(view)
	var twin: Material = view.material_override
	_t.check("a twin strips back to its source", InkOutline.strip(twin) == paint and InkOutline.strip(paint) == paint and InkOutline.strip(null) == null)
	var owned := _body()
	owned.next_pass = InkOutline.ink("enemy")
	var stripped := InkOutline.strip(owned)
	_t.check("an inked material strips to a copy with no line, made once", stripped != owned and stripped.next_pass == null
		and InkOutline.strip(owned) == stripped and owned.next_pass == InkOutline.ink("enemy"))
	_t.check("death debris borrowing a baked, inked material draws no line", BakeLook.unbaked(twin).next_pass == null)
	view.free()
	# BallLooks.light_pilot lights a duplicate of a material that was inked once already.
	var lit := paint.duplicate() as StandardMaterial3D
	lit.backlight_enabled = true
	var seated := _view(_cube(), lit)
	InkOutline.apply(seated, "enemy")
	var lit_twin := seated.material_override as StandardMaterial3D
	_t.check("a copy of an inked material gets its own twin, not the original's", lit_twin != twin and lit_twin.backlight_enabled
		and lit_twin.get_meta("ink_source") == lit.get_instance_id() and InkOutline.strip(lit_twin) == lit)
	seated.free()
	InkOutline.enabled = false
	var off := _view(_cube(), _body())
	var off_mesh := off.mesh
	_t.check("switched off, apply() lines nothing", InkOutline.apply(off) == 0 and off.mesh == off_mesh)
	off.free()
	var lift := InkOutline.ink("pilot")
	InkOutline.reset_for_tests()
	_t.check("reset_for_tests() switches it back on and drops its passes", InkOutline.enabled and InkOutline.ink("pilot") != lift)


class Look:
	var look := "cutaway"

	func option(_key: String):
		return look


func _reset_roles() -> void:
	var source := _cube()
	var paint := _body()
	source.surface_set_material(0, paint)
	var first := MeshInstance3D.new()
	first.mesh = source
	InkOutline.apply(first, "enemy")
	var hull := InkOutline.hull(source)
	InkOutline.reset_for_tests()
	var second := MeshInstance3D.new()
	second.mesh = source
	InkOutline.apply(second, "warden")
	var drawn := second.get_active_material(0)
	_t.check("the shared welded mesh keeps its own material: twins sit on each view", hull.surface_get_material(0) == paint
		and paint.next_pass == null and first.get_surface_override_material(0) != null)
	_t.check("after reset_for_tests() a Warden on the same mesh draws the current Warden pass, not a stale enemy one",
		second.mesh == hull and drawn != paint and drawn.next_pass == InkOutline.ink("warden"))
	first.free()
	second.free()


func _cutaway() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var hook := HeroAssets.new()
	var tuning := Look.new()
	hook.ctx = {"tuning": tuning}
	world.add_child(hook)
	for pilot in HeroAssets.SHELLS.keys():
		var ball := Node3D.new()
		world.add_child(ball)
		var rec: Dictionary = hook.fit_shell_into(ball, pilot, "", 1, {})
		if not _t.check("%s fits a cutaway shell" % pilot, not rec.is_empty()):
			continue
		var seated: Dictionary = hook.fit_pilot_into(rec.pod, pilot, Color.WHITE) if HeroAssets.PILOTS.has(pilot) else {}
		var cut_lined := 0
		var window_ok := true
		var shell_lined := 0
		for part in [rec.core, rec.pod]:
			for view: MeshInstance3D in (part as Node).find_children("*", "MeshInstance3D", true, false):
				if view.mesh == null or view.name == "AnimatedPilot" or (seated.has("pilot") and (seated.pilot as Node).is_ancestor_of(view)):
					continue
				for i in view.mesh.get_surface_count():
					var mat := view.get_active_material(i)
					var line: Material = mat.next_pass if mat != null else null
					if line == null or not line.has_meta("ink_role"):
						continue
					shell_lined += 1
					if mat is ShaderMaterial and (mat as ShaderMaterial).shader.code == BallLooks.CUTAWAY_SHADER:
						cut_lined += 1
						var cut := line as ShaderMaterial
						window_ok = window_ok and cut.shader.code.contains("keep_within") and cut.get_meta("ink_role") == "pilot"
						for key in InkOutline.CUT_PARAMETERS:
							var want = (mat as ShaderMaterial).get_shader_parameter(key)
							window_ok = window_ok and (want == null or cut.get_shader_parameter(key) == want)
		_t.check("%s's cutaway shell draws the pilot's line through the window-cutting variant" % pilot,
			shell_lined >= 3 and cut_lined >= 3 and window_ok, "%d lined, %d cut" % [shell_lined, cut_lined])
		if HeroAssets.PILOTS.has(pilot):
			var census := _census(seated.get("pilot")) if seated.has("pilot") else {"lined": 0, "roles": {}}
			_t.check("%s's seated pilot draws the pilot's line" % pilot, census.lined >= 1 and census.roles.keys() == ["pilot"], "%s" % census)
	world.free()


func _mounted() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var hook := HeroAssets.new()
	world.add_child(hook)
	for pilot in ["runner_gunner", "pylon_engineer"]:
		var ball := Node3D.new()
		world.add_child(ball)
		var rec: Dictionary = hook.fit_shell_into(ball, pilot, "", 1, {})
		var census := _census(ball)
		_t.check("%s's fitted shell draws the pilot's line, and its accents and glass none" % pilot, not rec.is_empty()
			and census.roles.keys() == ["pilot"] and census.lined >= 10 and census.accent_lined == 0 and census.glass_lined == 0,
			"%s" % census)
	var chaser := BakeWarm.spawn_view(load("res://src/combat/chaser.gd"), world, null, null)
	var boss := BakeWarm.spawn_view(load("res://src/combat/miniboss.gd"), world, null, null)
	await process_frame
	await process_frame
	var enemy: Node = chaser.get_child(0)
	var census := _census(chaser)
	var owned: Array = enemy.owned_materials()
	var flash_ok := not owned.is_empty()
	for mat in owned:
		flash_ok = flash_ok and (mat.next_pass == null or mat.next_pass.has_meta("ink_role"))
	_t.check("a spawned chaser draws the enemy's line and keeps its owned paint in place", census.roles.keys() == ["enemy"]
		and census.lined >= 3 and census.owned_drawn and flash_ok, "%s" % census)
	census = _census(boss)
	_t.check("a Warden-class miniboss draws the Warden's line", census.roles.keys() == ["warden"] and census.lined >= 3, "%s" % census)
	var brindle := BossModel.load_scene("res://assets/models/bosses/boss_brindle.glb")
	if brindle != null:
		world.add_child(brindle)
		census = _census(brindle)
		_t.check("Brindle's Requisition draws the boss's line, its glass none", census.roles.keys() == ["boss"]
			and census.lined >= 20 and census.glass_lined == 0, "%s" % census)
	else:
		_t.check("Brindle's model loads", false)
	world.free()


func _census(root_node: Node) -> Dictionary:
	var out := {"lined": 0, "roles": {}, "accent_lined": 0, "glass_lined": 0, "owned_drawn": false}
	var owned: Array = []
	for node in root_node.get_children():
		if node.has_method("owned_materials"):
			owned = node.owned_materials()
	for view: MeshInstance3D in root_node.find_children("*", "MeshInstance3D", true, false):
		if view.mesh == null:
			continue
		for i in view.mesh.get_surface_count():
			var mat := view.get_active_material(i)
			if mat == null:
				continue
			var pass_mat := mat.next_pass
			var lined := pass_mat != null and pass_mat.has_meta("ink_role")
			if mat in owned and lined:
				out.owned_drawn = true
			if not lined:
				continue
			out.lined += 1
			out.roles[pass_mat.get_meta("ink_role")] = true
			var slot := (view.mesh as ArrayMesh).surface_get_name(i) if view.mesh is ArrayMesh else ""
			if slot.contains("class_accent") or mat.resource_name.contains("class_accent"):
				out.accent_lined += 1
			if slot.contains("glass") or mat.resource_name.contains("glass"):
				out.glass_lined += 1
	return out


func _body() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Palette.RUST
	return mat


func _shader(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var mat := ShaderMaterial.new()
	mat.shader = shader
	return mat


func _cube_named(slot: String) -> ArrayMesh:
	var mesh := _cube()
	mesh.surface_set_name(0, slot)
	return mesh


func _view(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.material_override = mat
	return view
