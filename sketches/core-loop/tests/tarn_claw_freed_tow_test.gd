extends "res://tests/tarn_claw_drag_test.gd"

# 2026-11-08 (w31 bands B, w1-expert-40305): a towed enemy freed mid-flight stayed in the claw's
# tow and failed the typed _movable argument every step (tarn_claw.gd:405, 43 SCRIPT ERROR lines).
# The claw now drops a held body (tow, hurl, drag target) when it leaves the tree.
# Expected: 9 checks including the count assertion.


func _initialize() -> void:
	_t = T.new("tarn_claw_freed_tow_test")
	_expected_checks = 9
	super._initialize()


func _piece(id: String, from: Vector3, to: Vector3) -> void:
	var ult = _combat.ultimate
	_player.abilities.ultimate_id = id
	ult._id = id
	ult._plan = {"path": "arc", "from": from, "to": to, "flight": 2.4, "seconds": 2.75, "beats": 7,
		"legs": [{"mode": "arc", "to": to, "seconds": 2.4, "beats": 7, "strike": true}]}
	ult.last_plan = ult._plan
	ult._leg = 0
	ult._leg_time = 0.0
	ult._phase = "flight"
	ult._posture_spent = {}
	_game.events.ultimate_started.emit(id, "arc", from, to, 2.75)


func _tech(id: String, beat: int, ball: Vector3) -> int:
	return int(_combat.ultimate._ult_rows[id]["tech"].call(beat, ball, Vector3.FORWARD, 1.0))


func _run() -> void:
	await _boot()
	var ball: Vector3 = _player.ball_position()
	_piece("redjaw_rend", ball, ball + Vector3.RIGHT * 25.0)
	var doomed := _enemy("chaser", 4.0)
	var kept := _enemy("chaser", 6.0)
	_tech("redjaw_rend", 1, ball)
	_t.check("both chasers join the tow", _claw.tow.size() == 2 and _claw.tow.has(doomed) and _claw.tow.has(kept))
	doomed.queue_free()
	await process_frame
	_t.check("a freed towed enemy leaves the tow", _claw.tow == [kept])
	_claw.step(DT)
	_t.check("the flight step still carries the survivor", _claw.tow == [kept])
	# Freed with free() between steps, the hook still fires before the instance goes.
	kept.free()
	_t.check("an immediate free also leaves the tow", _claw.tow.is_empty())
	_claw.step(DT)
	_t.check("a step after both frees runs clean", _claw.tow.is_empty() and _claw._piece == "redjaw_rend")

	await _fresh()
	ball = _player.ball_position()
	_player.abilities.ultimate_id = "vice_leap"
	_piece("vice_leap", ball, ball + Vector3.RIGHT * 12.0)
	var thrown := _enemy("chaser", 3.0)
	_tech("vice_leap", 1, ball)
	_t.check("vice leap hurls the chaser", _claw.hurls.any(func(h): return h["enemy"] == thrown))
	thrown.queue_free()
	await process_frame
	_t.check("a freed hurled enemy leaves the hurls", _claw.hurls.is_empty())

	await _fresh()
	var dragged := _enemy("chaser", 6.0)
	_claw.on_body(dragged, 1.0, 1.0)
	var held: bool = not _claw.drag.is_empty() and _claw.drag["target"] == dragged
	dragged.queue_free()
	await process_frame
	_t.check("a freed drag target ends the drag", held and _claw.drag.is_empty())
	_finish()
