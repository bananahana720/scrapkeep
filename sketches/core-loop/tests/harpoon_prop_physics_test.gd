extends SceneTree

const T := preload("res://tests/support/t.gd")
const HarpoonPhysicsRig := preload("res://src/presentation/harpoon_physics_rig.gd")
const PropMotionRig := preload("res://src/presentation/prop_motion_rig.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const AugmentKit := preload("res://src/movement/augment_kit.gd")
const Augments := preload("res://src/movement/augments.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const Palette := preload("res://src/core/palette.gd")
const Comfort := preload("res://src/core/comfort.gd")

const FRAME := 1.0 / 60.0

var _t


class StubPlayer extends Node3D:
	var kit := AugmentKit.new()
	var events := GameEvents.new()

	func shown_position() -> Vector3:
		return global_position

	func ball_position() -> Vector3:
		return global_position

	func grapple_range() -> float:
		return 60.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_t = T.new("harpoon_prop_physics_test")
	Comfort.reduced_motion = false
	FlashGuard.on = false
	HarpoonPhysicsRig.reset_for_tests()

	_check_watertight_meshes()
	_check_cable_solver()
	_check_harpoon_head_articulation()
	_check_line_view_integration()
	_check_live_rope_exit_registration()
	_check_60hz_continuity_and_loop_closure()
	_check_prop_motion_rig()
	_check_reduced_motion_and_flash_guard()

	Comfort.reduced_motion = false
	FlashGuard.on = false
	HarpoonPhysicsRig.reset_for_tests()
	quit(_t.verdict())


func _verify_manifold(label: String, mesh: ArrayMesh) -> void:
	_t.check(label + " non-null ArrayMesh", mesh != null and mesh.get_surface_count() >= 1, "surfaces=%d" % (mesh.get_surface_count() if mesh != null else 0))
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var arrays := mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	_t.check(label + " valid triangle stream", verts.size() >= 12 and verts.size() % 3 == 0 and norms.size() == verts.size() and uvs.size() == verts.size() and cols.size() == verts.size(),
		"verts=%d norms=%d uvs=%d cols=%d" % [verts.size(), norms.size(), uvs.size(), cols.size()])

	var edge_counts := {}
	var bad_normals := 0
	var inverted_normals := 0
	var bad_verts := 0
	var degen_tris := 0
	var signed_vol_6 := 0.0
	for i in range(0, verts.size(), 3):
		var a := verts[i]
		var b := verts[i + 1]
		var c := verts[i + 2]
		if not (a.is_finite() and b.is_finite() and c.is_finite()):
			bad_verts += 1
			continue
		var face_cross := (c - a).cross(b - a)
		if face_cross.length_squared() < 1.0e-12:
			degen_tris += 1
		else:
			var face_n := face_cross.normalized()
			signed_vol_6 += a.dot((c - Vector3.ZERO).cross(b - Vector3.ZERO))
			for k in 3:
				var n := norms[i + k]
				if not n.is_finite() or absf(n.length() - 1.0) > 0.02:
					bad_normals += 1
				elif n.dot(face_n) < 0.95:
					inverted_normals += 1
		var ka := _vkey(a)
		var kb := _vkey(b)
		var kc := _vkey(c)
		for edge in [[ka, kb], [kb, kc], [kc, ka]]:
			var key := "%s>%s" % [edge[0], edge[1]]
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1

	var unmatched := 0
	var non_manifold := 0
	for key in edge_counts:
		var count: int = edge_counts[key]
		if count != 1:
			non_manifold += 1
		var parts := (key as String).split(">")
		var twin := "%s>%s" % [parts[1], parts[0]]
		if int(edge_counts.get(twin, 0)) != count:
			unmatched += 1
	_t.check(label + " watertight closed manifold",
		bad_verts == 0 and bad_normals == 0 and inverted_normals == 0 and degen_tris == 0 and unmatched == 0 and non_manifold == 0 and signed_vol_6 > 0.0,
		"tris=%d vol=%.6f bad_v=%d bad_n=%d inv_n=%d degen=%d open=%d non_manifold=%d" % [
			verts.size() / 3, signed_vol_6 / 6.0, bad_verts, bad_normals, inverted_normals, degen_tris, unmatched, non_manifold])


static func _vkey(v: Vector3) -> String:
	return "%d,%d,%d" % [roundi(v.x * 10000.0), roundi(v.y * 10000.0), roundi(v.z * 10000.0)]


func _check_watertight_meshes() -> void:
	_verify_manifold("harpoon body_mesh", HarpoonPhysicsRig.body_mesh())
	_verify_manifold("harpoon core_mesh", HarpoonPhysicsRig.core_mesh())
	_verify_manifold("harpoon jaw_mesh", HarpoonPhysicsRig.jaw_mesh())
	_verify_manifold("fairlead spool_mesh", HarpoonPhysicsRig.spool_mesh())


func _check_cable_solver() -> void:
	var solver := HarpoonPhysicsRig.CableSolver.new(20)
	_t.eq("solver segment count in [16,24]", solver.segments, 20)
	var a := Vector3(0.0, 2.0, 0.0)
	var b := Vector3(0.0, 2.0, -14.0)

	solver.trigger_launch()
	var launch_peak := 0.0
	for i in 12:
		var tip := a.lerp(b, float(i + 1) / 12.0)
		solver.step(FRAME, a, tip, false)
		var pts := solver.sample_points(a, tip, 0.0, false)
		_t.check("launch endpoints exact #%d" % i, pts.size() == 21 and pts[0] == a and pts[20] == tip,
			"size=%d start=%s end=%s" % [pts.size(), pts[0], pts[20]])
		for k in range(1, 20):
			var base := a.lerp(tip, float(k) / 20.0)
			launch_peak = maxf(launch_peak, pts[k].distance_to(base))
	_t.check("launch whip produces transverse wave", launch_peak > 0.08, "peak=%.3f m" % launch_peak)
	_t.check("fairlead spool spins during payout", absf(solver.spool_angle) > 0.2 and solver.spool_speed > 0.5,
		"angle=%.3f rad speed=%.2f rad/s" % [solver.spool_angle, solver.spool_speed])

	solver.trigger_bite(1.0)
	var early_strum := 0.0
	for i in 6:
		solver.step(FRAME, a, b, true)
		var pts := solver.sample_points(a, b, 0.0, true)
		early_strum = maxf(early_strum, pts[10].distance_to(a.lerp(b, 0.5)))
	for i in 40:
		solver.step(FRAME, a, b, true)
	var late_pts := solver.sample_points(a, b, 0.0, true)
	var late_strum := late_pts[10].distance_to(a.lerp(b, 0.5))
	_t.check("bite strum oscillates then decays cleanly", early_strum > 0.05 and late_strum < early_strum * 0.25,
		"early=%.3f m late=%.4f m" % [early_strum, late_strum])

	solver.reset()
	solver.step(FRAME, a, b, false)
	var cat_pts := solver.sample_points(a, b, 2.2, false)
	var mid_drop := 2.0 - cat_pts[10].y
	var sym_err := absf(cat_pts[5].y - cat_pts[15].y)
	_t.check("slack catenary sag exact midpoint and symmetric", absf(mid_drop - 2.2) < 0.01 and sym_err < 0.001 and cat_pts[0] == a and cat_pts[20] == b,
		"mid_drop=%.3f m sym_err=%.5f" % [mid_drop, sym_err])

	solver.trigger_retract()
	var retract_peak := 0.0
	for i in 8:
		var tip := b.lerp(a, float(i + 1) / 10.0)
		solver.step(FRAME, a, tip, false)
		var pts := solver.sample_points(a, tip, 0.0, false)
		for k in range(1, 20):
			retract_peak = maxf(retract_peak, pts[k].distance_to(a.lerp(tip, float(k) / 20.0)))
	_t.check("retract whip-back and reverse spool spin", retract_peak > 0.05 and solver.spool_speed < -0.5,
		"peak=%.3f m spool_speed=%.2f rad/s" % [retract_peak, solver.spool_speed])

	solver.step(5.0, a, a, true)
	var degen := solver.sample_points(a, a, 1.5, false)
	var all_finite := true
	for p in degen:
		if not p.is_finite():
			all_finite = false
	_t.check("degenerate zero-span finite safety", all_finite and degen.size() == 21, "finite=%s" % all_finite)


func _check_harpoon_head_articulation() -> void:
	var head := HarpoonPhysicsRig.make_head()
	root.add_child(head)
	_t.check("head has 3 hinged jaws and live core", head.jaws.size() == 3 and head.core_node != null and head.mesh is ArrayMesh,
		"jaws=%d core=%s" % [head.jaws.size(), head.core_node != null])

	head.set_mode("launch")
	head.step_head(FRAME, false)
	var open_angle := head.current_jaw_angle()
	_t.check("launch flares jaws open", open_angle > 0.65, "angle=%.3f rad" % open_angle)

	head.set_mode("bite", true)
	head.step_head(FRAME, true)
	var bite_impulse_angle := head.current_jaw_angle()
	for i in 30:
		head.step_head(FRAME, true)
	var bite_settled_angle := head.current_jaw_angle()
	_t.check("bite snaps jaws shut with clamp impulse", bite_settled_angle < -0.1 and bite_impulse_angle < open_angle,
		"open=%.3f impulse=%.3f settled=%.3f" % [open_angle, bite_impulse_angle, bite_settled_angle])

	head.set_mode("retract")
	for i in 30:
		head.step_head(FRAME, false)
	var retract_angle := head.current_jaw_angle()
	_t.check("retract stows jaws neutral", retract_angle > 0.1 and retract_angle < open_angle, "angle=%.3f rad" % retract_angle)

	head.free()


func _check_line_view_integration() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 2.0, 20.0)
	root.add_child(cam)
	var player := StubPlayer.new()
	player.position = Vector3(-4.0, 0.0, 0.0)
	root.add_child(player)
	var view := LineView.new()
	root.add_child(view)
	view.setup(player, cam, player.events)

	player.kit.hooked = true
	player.kit.on_body = true
	player.kit.rope = 10.0
	player.kit.anchor = Vector3(6.0, 1.0, 0.0)
	player.events.harpoon_bit.emit(null, player.kit.anchor)
	view.step(FRAME)
	_t.check("LineView body latch uses sculpted HarpoonHead", view.barb is HarpoonPhysicsRig.HarpoonHead and not (view.barb.mesh is BoxMesh) and view.barb.visible,
		"barb=%s mesh=%s" % [view.barb.get_class(), view.barb.mesh.get_class() if view.barb != null and view.barb.mesh != null else "null"])
	_t.check("LineView fairlead spool visible while hooked", view.fairlead_spool != null and view.fairlead_spool.visible,
		"spool_vis=%s" % (view.fairlead_spool != null and view.fairlead_spool.visible))
	_t.check("LineView bite excites cable strum", view.cable_solver != null and view.cable_solver.strum_energy > 0.05,
		"strum=%.3f" % (view.cable_solver.strum_energy if view.cable_solver != null else -1.0))

	var old_barb := view.barb
	player.kit.hooked = false
	player.kit.on_body = false
	view.step(FRAME)
	_t.check("LineView unhook frees sculpted barb cleanly", view.barb == null and not is_instance_valid(old_barb) and not view.fairlead_spool.visible,
		"freed=%s" % (not is_instance_valid(old_barb)))

	player.events.line_state_changed.emit("dry_fire", null, player.global_position, "")
	view.step(FRAME)
	_t.check("LineView dry_fire shows flared flight head", view.flight_head != null and view.flight_head.visible and view.flight_head.current_jaw_angle() > 0.5,
		"vis=%s jaw=%.3f" % [view.flight_head.visible, view.flight_head.current_jaw_angle()])
	player.kit.hooked = true
	player.kit.on_body = false
	player.kit.rope = 18.0
	player.kit.anchor = Vector3(6.0, 1.0, 0.0)
	for i in 12:
		view.step(FRAME)
	_t.check("LineView slack world latch keeps jaws clamped", view.flight_head.visible and view.flight_head.current_jaw_angle() < 0.0 and view.barb == null,
		"vis=%s jaw=%.3f" % [view.flight_head.visible, view.flight_head.current_jaw_angle()])

	view.free()
	player.events.free()
	player.free()
	cam.free()


func _check_live_rope_exit_registration() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 5.0, 18.0)
	root.add_child(cam)
	var player := StubPlayer.new()
	player.position = Vector3(2.0, 1.5, -1.0)
	root.add_child(player)
	var pod := Node3D.new()
	pod.name = "Pod"
	player.add_child(pod)
	var rope_exit := Node3D.new()
	rope_exit.name = "RopeExit"
	pod.add_child(rope_exit)
	HeroAssets.add_fairlead(pod)
	var hero := HeroAssets.new()
	var view := LineView.new()
	root.add_child(view)
	view.setup(player, cam, player.events)

	var max_origin_err := 0.0
	var max_spool_err := 0.0
	var min_ball_clearance := INF
	var max_strip_start_err := 0.0
	var yaws := [0.0, 0.78, 1.92, 3.55, 5.42]
	var slopes := [
		Vector3.UP,
		Vector3(0.24, 0.97, 0.0).normalized(),
		Vector3(-0.18, 0.94, 0.28).normalized(),
		Vector3(0.12, 0.96, -0.25).normalized(),
		Vector3.UP,
	]
	player.kit.hooked = true
	player.kit.on_body = false
	player.kit.rope = 16.0

	for idx in yaws.size():
		pod.rotation.y = yaws[idx]
		var anchor_angle := float(idx) * 1.15
		player.kit.anchor = player.global_position + Vector3(cos(anchor_angle) * 12.0, 2.5, sin(anchor_angle) * 12.0)
		for s in 35:
			var bank: Basis = hero.update_carrier_bank(pod, slopes[idx], FRAME)
			player.set_meta("carrier_bank", bank)
			hero.steer_fairlead(pod, player.kit.anchor, INF if s == 0 else FRAME)
			view.step(FRAME)
		var exit_pos := rope_exit.global_position
		max_origin_err = maxf(max_origin_err, view.cable_origin.distance_to(exit_pos))
		max_spool_err = maxf(max_spool_err, view.fairlead_spool.global_position.distance_to(exit_pos))
		min_ball_clearance = minf(min_ball_clearance, view.cable_origin.distance_to(player.global_position))
		var verts: PackedVector3Array = view.cable.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var strip_start := (verts[0] + verts[1]) * 0.5
		max_strip_start_err = maxf(max_strip_start_err, strip_start.distance_to(exit_pos))

	_t.check("live RopeExit registers with cable_origin & spool across rolling banks",
		max_origin_err <= 0.005 and max_spool_err <= 0.005 and max_strip_start_err <= 0.005 and min_ball_clearance >= 1.055,
		"origin_err=%.5f m spool_err=%.5f m strip_err=%.5f m min_clear=%.4f m" % [
			max_origin_err, max_spool_err, max_strip_start_err, min_ball_clearance])

	view.free()
	hero.free()
	player.events.free()
	player.free()
	cam.free()


func _check_60hz_continuity_and_loop_closure() -> void:
	var head := HarpoonPhysicsRig.make_head()
	root.add_child(head)
	head.set_mode("bite", true)
	head.step_head(FRAME, true)
	var prev_deg := rad_to_deg(head.current_jaw_angle())
	var max_step_deg := 0.0
	for f in range(1, 24):
		head.step_head(FRAME, true)
		var cur_deg := rad_to_deg(head.current_jaw_angle())
		if f >= 3:
			max_step_deg = maxf(max_step_deg, absf(cur_deg - prev_deg))
		prev_deg = cur_deg
	_t.check("60 Hz jaw settle velocity bounded (<= 25 deg/frame)", max_step_deg <= 25.0,
		"max_step=%.2f deg/frame" % max_step_deg)
	head.free()

	var prop_root := Node3D.new()
	root.add_child(prop_root)
	var p_node := Node3D.new()
	var t_node := Node3D.new()
	var b_node := Node3D.new()
	prop_root.add_child(p_node)
	prop_root.add_child(t_node)
	prop_root.add_child(b_node)
	var rig := PropMotionRig.new()
	rig.add_part("piston", p_node, {"cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.UP, "amplitude": 0.30, "hz": 1.0})
	rig.add_part("turbine", t_node, {"cycle": PropMotionRig.CYCLE_TURBINE, "axis": Vector3.FORWARD, "hz": 1.0})
	rig.add_part("breathe", b_node, {"cycle": PropMotionRig.CYCLE_BREATHE, "axis": Vector3.UP, "amplitude": 0.25, "hz": 1.0})

	var p0 := p_node.position
	var t0 := t_node.basis
	var b0_pos := b_node.position
	var b0_scale := b_node.scale
	for i in 60:
		rig.step(FRAME, Vector3.ZERO)
	var p_err := p_node.position.distance_to(p0)
	var t_err := (t_node.basis.x - t0.x).length() + (t_node.basis.y - t0.y).length()
	var b_err := b_node.position.distance_to(b0_pos) + b_node.scale.distance_to(b0_scale)
	_t.check("PropMotionRig exact loop-seam closure pose(0) == pose(T)",
		p_err < 0.002 and t_err < 0.002 and b_err < 0.002,
		"piston_err=%.5f turbine_err=%.5f breathe_err=%.5f" % [p_err, t_err, b_err])
	rig.clear()
	prop_root.free()


func _check_prop_motion_rig() -> void:
	var prop_root := Node3D.new()
	prop_root.position = Vector3(5.0, 2.0, -3.0)
	root.add_child(prop_root)

	var collider_body := StaticBody3D.new()
	var col_shape := CollisionShape3D.new()
	col_shape.shape = BoxShape3D.new()
	collider_body.add_child(col_shape)
	prop_root.add_child(collider_body)
	var rest_col_xform := collider_body.global_transform
	var rest_shape_xform := col_shape.global_transform

	var hanging_visual := Node3D.new()
	var piston_visual := Node3D.new()
	var turbine_visual := Node3D.new()
	var breathe_visual := Node3D.new()
	prop_root.add_child(hanging_visual)
	prop_root.add_child(piston_visual)
	prop_root.add_child(turbine_visual)
	prop_root.add_child(breathe_visual)

	var rig := PropMotionRig.new()
	_t.check("rejects binding StaticBody3D or CollisionShape3D",
		not PropMotionRig.is_visual_pivot(collider_body) and not PropMotionRig.is_visual_pivot(col_shape),
		"body=%s shape=%s" % [PropMotionRig.is_visual_pivot(collider_body), PropMotionRig.is_visual_pivot(col_shape)])

	rig.add_part("hanging", hanging_visual, {"sway": true, "sway_max_rad": 0.40, "sway_gain": 0.04})
	rig.add_part("piston", piston_visual, {"cycle": PropMotionRig.CYCLE_PISTON, "axis": Vector3.UP, "amplitude": 0.28, "hz": 1.5})
	rig.add_part("turbine", turbine_visual, {"cycle": PropMotionRig.CYCLE_TURBINE, "axis": Vector3.FORWARD, "hz": 2.0})
	rig.add_part("breathe", breathe_visual, {"cycle": PropMotionRig.CYCLE_BREATHE, "axis": Vector3.UP, "amplitude": 0.25, "hz": 1.0})
	_t.eq("rig tracks 4 visual parts", rig.part_count(), 4)

	var max_sway := 0.0
	var max_piston := 0.0
	var max_breathe_scale := 1.0
	for i in 30:
		rig.step(FRAME, Vector3(12.0, 0.0, -8.0))
		max_sway = maxf(max_sway, hanging_visual.basis.get_euler().length())
		max_piston = maxf(max_piston, absf(piston_visual.position.y))
		max_breathe_scale = maxf(max_breathe_scale, breathe_visual.scale.x)
	var turbine_rot := rig.part("turbine").cycle_angle
	_t.check("sway responds to velocity and clamps", max_sway > 0.08 and max_sway <= 0.62, "max_sway=%.3f rad" % max_sway)
	_t.check("piston strokes along local axis", max_piston > 0.15, "max_piston=%.3f m" % max_piston)
	_t.check("turbine spins continuously", absf(turbine_rot) > 0.2, "angle=%.3f rad" % turbine_rot)
	_t.check("breathe scales smoothly", max_breathe_scale > 1.01, "scale_x=%.4f" % max_breathe_scale)

	rig.apply_impulse(Vector3(1.0, 0.0, 0.0), 1.2, "hanging")
	var peak_jolt := 0.0
	for i in 12:
		rig.step(FRAME, Vector3.ZERO)
		peak_jolt = maxf(peak_jolt, hanging_visual.position.length())
	for i in 90:
		rig.step(FRAME, Vector3.ZERO)
	var settled_jolt := hanging_visual.position.length()
	_t.check("impact jolt recoils then settles", peak_jolt > 0.08 and settled_jolt < 0.02,
		"peak=%.3f m settled=%.4f m" % [peak_jolt, settled_jolt])

	_t.check("zero collider drift on StaticBody3D and CollisionShape3D",
		collider_body.global_transform.is_equal_approx(rest_col_xform) and col_shape.global_transform.is_equal_approx(rest_shape_xform),
		"body_delta=%.6f shape_delta=%.6f" % [
			collider_body.global_position.distance_to(rest_col_xform.origin),
			col_shape.global_position.distance_to(rest_shape_xform.origin)
		])

	breathe_visual.free()
	rig.step(FRAME, Vector3.ZERO)
	_t.eq("pruned freed visual part safely", rig.part_count(), 3)

	rig.clear()
	prop_root.free()


func _check_reduced_motion_and_flash_guard() -> void:
	Comfort.reduced_motion = true
	FlashGuard.on = true

	var solver := HarpoonPhysicsRig.CableSolver.new(20)
	var a := Vector3.ZERO
	var b := Vector3(0.0, 0.0, -10.0)
	solver.trigger_launch()
	solver.step(FRAME, a, b, false)
	var pts := solver.sample_points(a, b, 0.0, false)
	var dev := pts[10].distance_to(a.lerp(b, 0.5))
	solver.trigger_bite(1.0)
	solver.step(FRAME, a, b, true)
	var bite_dev := solver.sample_points(a, b, 0.0, true)[10].distance_to(a.lerp(b, 0.5))
	_t.check("reduced_motion zeroes cable whip, strum, and spool spin",
		dev < 0.0001 and bite_dev < 0.0001 and solver.spool_speed == 0.0,
		"launch_dev=%.5f bite_dev=%.5f spool=%.3f" % [dev, bite_dev, solver.spool_speed])

	var head := HarpoonPhysicsRig.make_head()
	root.add_child(head)
	head.set_mode("bite", true)
	head.step_head(FRAME, true)
	var mat := head.core_node.material_override as StandardMaterial3D
	_t.check("reduced_motion zeroes clamp overshoot and FlashGuard bounds core emission",
		head.clamp_impulse == 0.0 and mat.emission_energy_multiplier <= 1.0,
		"impulse=%.3f emission=%.3f" % [head.clamp_impulse, mat.emission_energy_multiplier])
	head.free()

	var node := Node3D.new()
	node.position = Vector3(1.0, 2.0, 3.0)
	root.add_child(node)
	var rig := PropMotionRig.new()
	rig.add_part("p", node, {"sway": true, "cycle": PropMotionRig.CYCLE_PISTON, "amplitude": 0.4, "hz": 2.0})
	rig.apply_impulse(Vector3.RIGHT, 2.0)
	for i in 15:
		rig.step(FRAME, Vector3(20.0, 0.0, 0.0))
	_t.check("reduced_motion holds PropMotionRig at exact rest pose",
		node.position.is_equal_approx(Vector3(1.0, 2.0, 3.0)) and node.basis.is_equal_approx(Basis.IDENTITY),
		"pos=%s" % node.position)
	rig.clear()
	node.free()
