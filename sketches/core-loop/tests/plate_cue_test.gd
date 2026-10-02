extends SceneTree

const Game := preload("res://src/game.gd")
const Enemy := preload("res://src/combat/enemy.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")

# The plating cue lives on the plate's rim, bolts and glyph (Andrew, 2026-09-29), not the
# body or the plate faces. Amber: the plate material emits through its mask in the live
# colour and only the rim and bolt texels are lit; slate: the same texels glow in the slate
# role colour at a lower, steady energy. Both states keep the resting albedo, the body never
# glows, the switch follows tint_state, and no draw is added.
# The cue is trim, not a flood: what lights must stay a small share of the plate group's face
# area (LIT_CEILING), so a recipe that paints a slab, brow or cap as rim fails.

const LIT_CEILING := 0.15
# The two capture cameras (capture_cameras.gd ASSET: dir, dist, up, fov 65), staged from the
# ball's side (+Z, the side a brute faces) at the brute's centre + 1.5 m.
const CAMERAS := {"asset-use6": 6.0, "asset-front30": 30.0}
const CAM_UP := 3.0
const CAM_FOV := 65.0
const FRAME := Vector2(1920.0, 1080.0)

var failures := 0
var game


func _initialize() -> void:
	game = Game.new()
	game.test_mode = true
	root.add_child(game)
	_run.call_deferred()


func _check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])


# Light the material adds at a texel: 0 unless emission is on, else energy times mask value.
func _added(mat: StandardMaterial3D, u: float, v: float) -> float:
	if not mat.emission_enabled or mat.emission_operator != BaseMaterial3D.EMISSION_OP_MULTIPLY:
		return 0.0 if not mat.emission_enabled else 999.0
	var img := mat.emission_texture.get_image()
	var px := img.get_pixel(clampi(int(u * img.get_width()), 0, img.get_width() - 1), clampi(int(v * img.get_height()), 0, img.get_height() - 1))
	return mat.emission_energy_multiplier * px.r


func _draws(node: Node) -> int:
	var n := 0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		if mi.get_parent() != null and mi.get_parent().name == "PlateCrack":
			continue
		n += mi.mesh.get_surface_count()
	return n


# Screen box (in pixels of the 1920x1080 frame) the glyph's strokes project to from a capture
# camera on the ball's side; corners behind the camera return an empty rect.
func _glyph_rect(brute: Node3D, crack: Node3D, dist: float) -> Rect2:
	var centre := brute.global_position + Vector3.UP * 1.5
	var eye := brute.global_position + brute.global_basis.z * dist + Vector3.UP * CAM_UP
	var cam := Transform3D(Basis.IDENTITY, eye).looking_at(centre, Vector3.UP)
	var inv := cam.affine_inverse()
	var tan_half := tan(deg_to_rad(CAM_FOV) * 0.5)
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for stroke in crack.get_children():
		var mi := stroke as MeshInstance3D
		var box := mi.mesh.get_aabb()
		for corner in 8:
			var local := box.position + box.size * Vector3(corner & 1, (corner >> 1) & 1, (corner >> 2) & 1)
			var p := inv * (mi.global_transform * local)
			if p.z >= -0.05:
				return Rect2()
			var px := Vector2(p.x / -p.z / (tan_half * FRAME.x / FRAME.y), -p.y / -p.z / tan_half)
			var pix := (px * 0.5 + Vector2(0.5, 0.5)) * FRAME
			lo = lo.min(pix)
			hi = hi.max(pix)
	return Rect2(lo, hi - lo)


func _run() -> void:
	game.ctx.calm = true
	var brute: Node3D = game.ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, 0))
	await process_frame
	var plate := brute.get_node("ReactionPivot/BrutePlates") as MeshInstance3D
	var mat := plate.material_override as StandardMaterial3D
	var arrays := plate.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var lit_rim := 0
	var lit_face := 0
	var dark_rim := 0
	var dark_face := 0
	brute.set_tint("slate")
	var slate_albedo := mat.albedo_color
	var slate_body_on: bool = brute._material.emission_enabled
	var slate_body_albedo: Color = brute._material.albedo_color
	var slate_rim_sum := 0.0
	var slate_face_sum := 0.0
	var slate_color := mat.emission
	var slate_energy := mat.emission_energy_multiplier
	for i in uvs.size():
		if colors[i].r < 0.5:
			slate_rim_sum += _added(mat, uvs[i].x, uvs[i].y)
		else:
			slate_face_sum += _added(mat, uvs[i].x, uvs[i].y)
	var slate_draws := _draws(brute)
	brute.set_tint("amber")
	var total_area := 0.0
	var lit_area := 0.0
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in idx.size() / 3:
		var a := verts[idx[t * 3]]
		var b := verts[idx[t * 3 + 1]]
		var c := verts[idx[t * 3 + 2]]
		var area := (b - a).cross(c - a).length() * 0.5
		var lit_verts := 0
		for k in 3:
			if _added(mat, uvs[idx[t * 3 + k]].x, uvs[idx[t * 3 + k]].y) > 0.0:
				lit_verts += 1
		total_area += area
		lit_area += area * lit_verts / 3.0
	for i in uvs.size():
		var light := _added(mat, uvs[i].x, uvs[i].y)
		var rim: bool = colors[i].r < 0.5
		if light > 0.0:
			if rim:
				lit_rim += 1
			else:
				lit_face += 1
		elif rim:
			dark_rim += 1
		else:
			dark_face += 1
	_check(brute.tint_state == "amber" and mat.emission_enabled, "amber: the plate material emits (state follows tint_state)")
	_check(lit_rim > 0 and dark_rim == 0, "amber: every rim and bolt vertex is lit (%d lit, %d dark)" % [lit_rim, dark_rim])
	_check(lit_face == 0 and dark_face > 0, "amber: no plate-face vertex is lit (%d lit, %d dark)" % [lit_face, dark_face])
	var frac := lit_area / total_area
	print("plate group: lit area %.3f of %.3f m2 = %.1f%% (ceiling %.0f%%)" % [lit_area, total_area, frac * 100.0, LIT_CEILING * 100.0])
	_check(frac > 0.0 and frac <= LIT_CEILING, "amber: lit area is trim, at most %.0f%% of the plate group's face area (%.1f%%)" % [LIT_CEILING * 100.0, frac * 100.0])
	_check(mat.albedo_color == slate_albedo and mat.albedo_color == Enemy.PLATE_CLOSED, "plate faces keep the resting albedo in both states")
	_check(not brute._material.emission_enabled and brute._material.albedo_color == slate_body_albedo and not slate_body_on,
		"body keeps its resting finish and never glows in either state")
	_check(slate_rim_sum > 0.0 and is_zero_approx(slate_face_sum), "slate: the rim carries light and no plate face does")
	_check(slate_color == EventKinds.role_color("slate") and slate_energy > 0.0 and slate_energy < Enemy.PLATE_GLOW_LIVE,
		"slate: the rim is the slate role colour at energy %.2f, below the live rim's %.2f" % [slate_energy, Enemy.PLATE_GLOW_LIVE])
	_check(mat.emission == EventKinds.state_color("will_break"), "amber: the rim is the live colour, not the class colour")
	_check(_draws(brute) == slate_draws and slate_draws == 3, "draws per brute unchanged across states (%d)" % slate_draws)
	# The crack glyph is the third part of the cue (its strokes are counted apart, as in the asset test).
	var crack := brute.get_node("ReactionPivot/BrutePlates/PlateCrack") as Node3D
	_check(crack.visible, "amber: the crack glyph shows")
	# The glyph must read on the slab's face from the ball's side at both capture cameras: on the
	# camera-facing side of the slab face (z = 1.35), its box inside the frame and big enough to see.
	var glyph_z: float = crack.global_position.z - brute.global_position.z
	_check(glyph_z > 1.35 and crack.global_basis.z.dot(brute.global_basis.z) > 0.99, "glyph stands off the slab's front face, on the ball's side (z %.2f > 1.35)" % glyph_z)
	for cam_name in CAMERAS:
		var rect := _glyph_rect(brute, crack, CAMERAS[cam_name])
		var inside := rect.size != Vector2.ZERO and rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= FRAME.x and rect.end.y <= FRAME.y
		_check(inside and rect.size.y >= 30.0, "%s: glyph box %.0f x %.0f px at (%.0f, %.0f) inside the frame, at least 30 px tall" % [cam_name, rect.size.x, rect.size.y, rect.position.x, rect.position.y])
	brute.set_tint("slate")
	_check(mat.emission_enabled and mat.emission == EventKinds.role_color("slate") and not crack.visible and brute.tint_state == "slate",
		"back to slate: the switch follows tint_state, a slate rim, no glyph")
	# Combat drives the state from punch_now(); one _tint() pass must agree with it, and the
	# cue must follow: amber lights the rim live, slate lights it slate (the switch reads tint_state only).
	var combat = game.ctx.spawner
	brute.set_tint("")
	brute.plating = 40.0
	for open_case in [true, false]:
		# Shred the whole plate away (punch 0 then meets plating 0: amber), or leave it whole (slate).
		if open_case:
			combat._shred[brute.get_instance_id()] = {"amount": 1.0e9, "cap": 1.0e9, "idle": 0.0}
		else:
			combat._shred.erase(brute.get_instance_id())
		combat._tint()
		var expect: String = "amber" if combat.punch_now() >= combat.plating_of(brute) else "slate"
		_check(brute.tint_state == expect, "combat _tint writes tint_state (%s, expected %s)" % [brute.tint_state, expect])
		var want := EventKinds.state_color("will_break") if brute.tint_state == "amber" else EventKinds.role_color("slate")
		_check(mat.emission_enabled and mat.emission == want, "the plate light follows the state combat wrote (%s)" % brute.tint_state)
	_check(brute.tint_state == "slate" and mat.emission == EventKinds.role_color("slate") and mat.emission_energy_multiplier < Enemy.PLATE_GLOW_LIVE,
		"combat closed the plate again and the rim went slate")

	# Warden: the jaw plates take the frame mask, a rim on every face of the box.
	var warden: Node3D = game.ctx.spawner.spawn_enemy("warden", Vector3(40, 30, 0))
	await process_frame
	var jaw_mat: StandardMaterial3D = warden._look.plate_material
	warden.set_tint("amber")
	var centre := _added(jaw_mat, 1.0 / 6.0, 0.25)
	var edge := _added(jaw_mat, 0.5 / 24.0, 0.25)
	var amber_edge := edge
	_check(jaw_mat.emission_enabled and edge > 0.0 and is_zero_approx(centre), "warden jaw: amber lights the face edge (%.2f) and not the face centre (%.2f)" % [edge, centre])
	_check(jaw_mat.albedo_color == Enemy.PLATE_CLOSED, "warden jaw keeps the resting plate albedo in amber")
	warden.set_tint("slate")
	var slate_edge := _added(jaw_mat, 0.5 / 24.0, 0.25)
	_check(slate_edge > 0.0 and slate_edge < amber_edge and is_zero_approx(_added(jaw_mat, 1.0 / 6.0, 0.25)),
		"warden jaw: slate lights the face edge (%.2f) below amber (%.2f) and not the face centre" % [slate_edge, amber_edge])

	# A mesh with no mask UVs gets the dark default: no flood on its faces.
	var hand: Node3D = game.ctx.spawner.spawn_enemy("mind_hand", Vector3(80, 30, 0))
	await process_frame
	var found := false
	for mi in hand.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m != null and m.emission_texture != null:
			found = true
			hand.set_tint("amber")
			_check(is_zero_approx(_added(m, 0.5, 0.5)) and is_zero_approx(_added(m, 0.1, 0.9)), "mind hand plate bone: dark mask, no face light in amber")
			break
	_check(found, "mind hand plate bone carries a mask material")
	# Miniboss and vault: BoxMesh plates take the frame mask, so amber still differs from slate.
	for kind in ["miniboss", "vault"]:
		var boxed: Node3D = game.ctx.spawner.spawn_enemy(kind, Vector3(120, 30, 0))
		await process_frame
		var bmat: StandardMaterial3D = null
		for mi in boxed.find_children("*", "MeshInstance3D", true, false):
			var bm := (mi as MeshInstance3D).material_override as StandardMaterial3D
			if bm != null and bm.emission_operator == BaseMaterial3D.EMISSION_OP_MULTIPLY:
				bmat = bm
				break
		_check(bmat != null, "%s carries a plate material" % kind)
		if bmat != null:
			boxed.set_tint("slate")
			var b_slate := _added(bmat, 0.5 / 24.0, 0.25)
			boxed.set_tint("amber")
			var b_edge := _added(bmat, 0.5 / 24.0, 0.25)
			var b_face := _added(bmat, 1.0 / 6.0, 0.25)
			_check(b_slate > 0.0 and b_slate < b_edge and is_zero_approx(b_face) and bmat.albedo_color == Enemy.PLATE_CLOSED,
				"%s: amber lights the plate rim (%.2f), not the face (%.2f); slate lights the rim lower (%.2f)" % [kind, b_edge, b_face, b_slate])
	print("plate_cue_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
