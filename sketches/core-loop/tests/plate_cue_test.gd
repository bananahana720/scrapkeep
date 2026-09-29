extends SceneTree

const Game := preload("res://src/game.gd")
const Enemy := preload("res://src/combat/enemy.gd")

# The plating cue lives on the plate's rim, bolts and glyph (Andrew, 2026-09-29), not the
# body or the plate faces. Amber: the plate material emits through its mask and only the
# rim and bolt texels are lit; slate: no emission at all. Both states keep the resting
# albedo, the body never glows, the switch follows tint_state, and no draw is added.

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


func _run() -> void:
	game.ctx.calm = true
	var brute: Node3D = game.ctx.spawner.spawn_enemy("plated_brute", Vector3(0, 30, 0))
	await process_frame
	var plate := brute.get_node("BrutePlates") as MeshInstance3D
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
	var slate_sum := 0.0
	for i in uvs.size():
		slate_sum += _added(mat, uvs[i].x, uvs[i].y)
	var slate_draws := _draws(brute)
	brute.set_tint("amber")
	_check(brute.tint_state == "amber" and mat.emission_enabled, "amber: the plate material emits (state follows tint_state)")
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
	_check(lit_rim > 0 and dark_rim == 0, "amber: every rim and bolt vertex is lit (%d lit, %d dark)" % [lit_rim, dark_rim])
	_check(lit_face == 0 and dark_face > 0, "amber: no plate-face vertex is lit (%d lit, %d dark)" % [lit_face, dark_face])
	_check(mat.albedo_color == slate_albedo and mat.albedo_color == Enemy.PLATE_CLOSED, "plate faces keep the resting albedo in both states")
	_check(not brute._material.emission_enabled and brute._material.albedo_color == slate_body_albedo and not slate_body_on,
		"body keeps its resting finish and never glows in either state")
	_check(is_zero_approx(slate_sum), "slate: no added light on any plate vertex")
	_check(_draws(brute) == slate_draws and slate_draws == 3, "draws per brute unchanged across states (%d)" % slate_draws)
	# The crack glyph is the third part of the cue (its strokes are counted apart, as in the asset test).
	var crack := brute.get_node("BrutePlates/PlateCrack") as Node3D
	_check(crack.visible, "amber: the crack glyph shows")
	brute.set_tint("slate")
	_check(not mat.emission_enabled and not crack.visible and brute.tint_state == "slate", "back to slate: the switch follows tint_state, no light, no glyph")
	# Combat drives the state from punch_now(); one _tint() pass must agree with it, and the
	# cue must follow: amber lights the rim, slate is dark (the switch reads tint_state only).
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
		_check(mat.emission_enabled == (brute.tint_state == "amber"), "the plate light follows the state combat wrote (%s)" % brute.tint_state)
	_check(brute.tint_state == "slate" and not mat.emission_enabled, "combat closed the plate again and the light went out")

	# Warden: the jaw plates take the frame mask, a rim on every face of the box.
	var warden: Node3D = game.ctx.spawner.spawn_enemy("warden", Vector3(40, 30, 0))
	await process_frame
	var jaw_mat: StandardMaterial3D = warden._look.plate_material
	warden.set_tint("amber")
	var centre := _added(jaw_mat, 1.0 / 6.0, 0.25)
	var edge := _added(jaw_mat, 0.5 / 24.0, 0.25)
	_check(jaw_mat.emission_enabled and edge > 0.0 and is_zero_approx(centre), "warden jaw: amber lights the face edge (%.2f) and not the face centre (%.2f)" % [edge, centre])
	_check(jaw_mat.albedo_color == Enemy.PLATE_CLOSED, "warden jaw keeps the resting plate albedo in amber")
	warden.set_tint("slate")
	_check(is_zero_approx(_added(jaw_mat, 0.5 / 24.0, 0.25)), "warden jaw: slate adds no light")

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
			_check(is_zero_approx(b_slate) and b_edge > 0.0 and is_zero_approx(b_face) and bmat.albedo_color == Enemy.PLATE_CLOSED,
				"%s: amber lights the plate rim (%.2f), not the face (%.2f); slate is dark" % [kind, b_edge, b_face])
	print("plate_cue_test: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(0 if failures == 0 else 1)
