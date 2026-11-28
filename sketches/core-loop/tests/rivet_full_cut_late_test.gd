extends "res://tests/rivet_set_piece_test.gd"

# Full Cut's carve tests up to about 19,000 parts against terrain shadows, a physics tick of 100 to
# 450 ms in a park (board #934, 13 Nov 2026), so it runs on a worker and the cut lands CUT_TICKS
# after the peak, on the same tick every time. Nothing is hit on the peak tick or the tick before
# the cut is due; on the due tick the machine on the cut takes FULL_CUT_DAMAGE x heft, the scar
# is drawn and the strike's record counts the hit. The landed cut is the cut made at once.

func _initialize() -> void:
	_t = T.new("rivet_full_cut_late_test")
	_expected_checks = 8
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


const AIM := Vector3(0.98, -0.2, 0.0)


func _run() -> void:
	await _boot()
	_t.eq("the cut lands 5 ticks after the peak, the Breach's beat", Kit.CUT_TICKS, Kit.LATE_TICKS)
	# A wall across the cut, so the carve has terrain to shade.
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 30.0, 30.0)
	collision.shape = box
	wall.add_child(collision)
	_game.add_child(wall)
	wall.global_position = _player.ball_position() + Vector3.RIGHT * 6.5
	await _fresh()
	_kit.cut_ticks = Kit.CUT_TICKS
	var target: Node3D = await _stand()
	var ult = _combat.ultimate
	var peak := Engine.get_physics_frames()
	ult._peak(_player.ball_position())
	_t.check("nothing is hit on the peak tick", _hits(target).is_empty())
	_kit._step_cuts(peak + Kit.CUT_TICKS - 1)
	_t.check("nothing is hit the tick before the cut is due", _hits(target).is_empty() and not _kit._cuts_due.is_empty())
	_kit._step_cuts(peak + Kit.CUT_TICKS)
	_t.check("the cut lands on its due tick", _kit._cuts_due.is_empty() and not _hits(target).is_empty())
	_t.check("the scar is drawn as the cut lands", _kit.volume_indicator.shapes.has("rivet_scar"))
	_t.eq("the strike's record counts the late hit", int(ult.record().get("volley_hits", 0)), 1)
	# One fixed aim for both carves: the strike's own aim carries state between stands.
	var at: Vector3 = _player.ball_position()
	_kit.cut_ticks = Kit.CUT_TICKS
	_kit.full_cut(at, AIM, 1.0)
	_kit._step_cuts(Engine.get_physics_frames() + Kit.CUT_TICKS)
	var late_cells: Array = (_kit.volume_indicator.shapes["rivet_scar"]["cells"] as Array).duplicate(true)
	_kit.cut_ticks = 0
	_kit.full_cut(at, AIM, 1.0)
	var now_cut: Array = _kit.volume_indicator.shapes["rivet_scar"]["cells"]
	_t.check("the late cut is the cut made at once", not now_cut.is_empty() and var_to_str(late_cells) == var_to_str(now_cut), "%d vs %d cells" % [late_cells.size(), now_cut.size()])
	_finish()


# Full Cut aimed down +x with a still machine 5 m out, in front of the wall.
func _stand() -> Node3D:
	_kit.volume_indicator.clear("rivet_scar")
	_piece("foundry_cutter")
	var target := _enemy("chaser", 5.0)
	target.set_physics_process(false)
	_game.camera.set_physics_process(false)
	_game.camera.cam.get_parent().global_position = _player.ball_position()
	_game.camera.cam.global_basis = Basis.looking_at(Vector3.RIGHT)
	_kit._last_aim = Vector3.RIGHT  # the strike aims from its last aim, not the camera, in a test
	await physics_frame
	await physics_frame
	return target
