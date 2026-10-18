extends SceneTree

const Holds := preload("res://src/combat/holds.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Roster := preload("res://src/combat/roster.gd")

# 2026-10-18 (w17 hook out): a harpoon bite on world geometry breaks any hold whose row lists
# "hook", as a player break (reason "hook", the refund) with a SNAP_KICK along the line to the
# anchor. A bite on an enemy does not, and the netcaster and anchor crew do not list it.

var _checks := 0
var _failures := 0


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _initialize() -> void:
	for kind in ["mag_trapper", "gyro_jammer", "catch_trap", "winch_drone", "bola_thrower"]:
		_check("row " + kind, "hook" in Roster.ROWS[kind]["breaks"], "%s breaks %s" % [kind, Roster.ROWS[kind]["breaks"]])
	for kind in ["netcaster", "anchor_crew"]:
		if Roster.ROWS.has(kind):
			_check("row " + kind, not "hook" in Roster.ROWS[kind]["breaks"], "%s breaks %s" % [kind, Roster.ROWS[kind]["breaks"]])

	# A geometry bite: hook out, along the line, not along the velocity.
	var rig := _rig()
	# One physics frame, so the holds node has a physics delta to turn a kick into an accel.
	await physics_frame
	await physics_frame
	var holds: Holds = rig["holds"]
	var player: _Player = rig["player"]
	var src := Node3D.new()
	root.add_child(src)
	holds.catch(src, "mag_pit", ["jump", "smash", "hook"])
	player.kit.anchor_body = null
	rig["events"].grapple_fired.emit(Vector3(0, 5, -10))
	var step := holds.get_physics_process_delta_time()
	var kick: Vector3 = player.accel * step
	_check("released", not holds.holding() and holds.last_release.get("reason") == "hook", "last_release %s" % [holds.last_release])
	_check("counted", holds.breaks_by_player == 1, "breaks_by_player %d" % holds.breaks_by_player)
	_check("kick along line", kick.is_equal_approx(Vector3(0, 0, -Holds.SNAP_KICK)), "kick %s (velocity is +x)" % [kick])
	_check("refund", player.refunds == [Holds.BREAK_REFUND], "refunds %s" % [player.refunds])

	# A post or world solid that is not an enemy still counts.
	var post := Node3D.new()
	root.add_child(post)
	holds.catch(src, "mag_pit", ["jump", "hook"])
	player.kit.anchor_body = post
	rig["events"].grapple_fired.emit(Vector3(0, 0, -10))
	_check("post bite hooks out", not holds.holding(), "last_release %s" % [holds.last_release])

	# A bite on an enemy does not.
	var enemy := Node3D.new()
	enemy.add_to_group("enemy")
	root.add_child(enemy)
	holds.catch(src, "mag_pit", ["jump", "hook"])
	player.kit.anchor_body = enemy
	rig["events"].grapple_fired.emit(Vector3(0, 0, -10))
	_check("enemy bite does not", holds.holding(), "holding %s" % [holds.held_kinds()])
	holds.clear()

	# Holds that do not list hook (netcaster, anchor crew) stay held.
	for kind in ["air_net", "anchor_tether"]:
		var row_breaks: Array = ["jump", "glide", "smash"] if kind == "air_net" else ["boost", "speed"]
		holds.catch(src, kind, row_breaks)
		player.kit.anchor_body = null
		rig["events"].grapple_fired.emit(Vector3(0, 0, -10))
		_check("no hook for " + kind, holds.holding(), "held %s" % [holds.held_kinds()])
		holds.clear()

	# Straight overhead has no planar line: falls back to the velocity direction.
	player.accel = Vector3.ZERO
	holds.catch(src, "mag_pit", ["hook"])
	rig["events"].grapple_fired.emit(player.ball_position() + Vector3(0, 8, 0))
	_check("overhead falls back", (player.accel * step).is_equal_approx(Vector3(Holds.SNAP_KICK, 0, 0)), "kick %s" % [player.accel * step])

	for node in [holds, src, post, enemy]:
		node.free()
	rig["events"].free()
	print("holds_hook_out_test: %s (%d checks)" % ["PASS" if _failures == 0 else "FAIL (%d)" % _failures, _checks])
	quit(0 if _failures == 0 and _checks > 0 else 1)


func _rig() -> Dictionary:
	var holds := Holds.new()
	var ctx := _Ctx.new()
	ctx.events = GameEvents.new()
	ctx.player = _Player.new()
	root.add_child(holds)
	holds.setup(ctx)
	return {"holds": holds, "events": ctx.events, "player": ctx.player}


class _Kit:
	extends RefCounted
	var sprinting := false
	var gliding := false
	var slamming := false
	var anchor_body = null


class _Abilities:
	extends RefCounted
	var owner_player

	func refund(_slot, amount: float) -> void:
		owner_player.refunds.append(amount)


class _Player:
	extends RefCounted
	var kit := _Kit.new()
	var abilities := _Abilities.new()
	var accel := Vector3.ZERO
	var refunds: Array = []

	func _init() -> void:
		abilities.owner_player = self

	func crowd_control(_kind: String, _accel: Vector3, _first: bool) -> bool:
		return true

	func cut_line() -> void:
		pass

	func ball_position() -> Vector3:
		return Vector3.ZERO

	func shown_position() -> Vector3:
		return Vector3.ZERO

	func planar_velocity() -> Vector3:
		return Vector3(12, 0, 0)

	func add_external_accel(a: Vector3) -> void:
		accel += a


class _Ctx:
	extends RefCounted
	var player = null
	var events = null
	var camera = null
