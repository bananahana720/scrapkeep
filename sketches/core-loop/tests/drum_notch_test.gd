# smoke: solo timeout=420s (one headless terrain build and about fifty 3 to 4 s ball runs at physics pace)
extends SceneTree

const Terrain := preload("res://src/world/terrain.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const PlayerBall := preload("res://src/movement/player_ball.gd")
const Intent := preload("res://src/movement/intent.gd")
const T := preload("res://tests/support/t.gd")

# The notch between drum_lip_kicker's lip and the terrace edge on park_flume (stage 2). Since 2026-10-23
# (#373 moved the kicker to at.x 256.07) the lip stands at x 270.07, y 0.42 to 0.49, and the terrace edge
# (first ground at or above y -0.5) at x 272, y 0.0; between them ran a 1.93 m V along z behind the kicker's
# 34 m width (z 463 to 497, the rays of 2026-10-23: terrain -10.5 at x 270.5, -7.0 at 271, -3.5 at 271.5). A
# 2 m ball bridged the V and rested at (271.07, 0.37, 480): no input, roll or boost along x moved it 0.00 m, roll
# along z only ran it along the groove, and only a jump (0.44 to 0.49 s) left. The row drum_lip_fill (a greybox
# ground box, x 270.07 to 272, z 463 to 497, top y 0.0) fills the V flush with the terrace edge and 0.42 under the lip.
#
# Zone, from the base geometry: x 270.0 to 272.0 and z 463 to 497 (the groove's footprint, ZONE_*). A ball is
# "notched" when it rests there (speed under REST_V for REST_S) with its centre under NOTCH_Y 0.9: a 2 m ball
# sits at y 1.0 on a flat y 0 surface and at 0.37 bridged in the V, so a ball resting on the filler or the
# terrace edge at 1.0 is a ball on level ground, not a trap.
# (a) escape: from the old rest pose (271.07, 0.37, z) at three z along the groove, for no input, +x, -x, +z, -z,
#     four diagonals, +x and -x with boost, each held HOLD_S: every roll case ends out of the zone's x/z box;
#     no input, and jump alone (a hop in place on level ground leaves no x/z), never rest notched.
# (b) planted drops at 0 m/s along the old groove (x 270.5, 271.0 and 271.5 at z 466, 480 and 494) and rolling west
#     off the terrace edge (x 274 at 2, 5 and 10 m/s): none rests notched.
# Control, 2026-10-23: the same file on the base tree (0c2702b1, no filler row) fails; the counts are in the stage doc.
# The pass count must be nonzero.

const ZONE_X0 := 270.0
const ZONE_X1 := 272.0
const ZONE_Z0 := 463.0
const ZONE_Z1 := 497.0
const NOTCH_Y := 0.9
const REST_V := 0.1
const REST_S := 2.0
const HOLD_S := 3.0
const SETTLE_S := 0.5
const START_Y := 0.37
const ESCAPE_Z := [470.0, 480.0, 490.0]
const DROP_X := [270.5, 271.0, 271.5]
const DROP_Z := [466.0, 480.0, 494.0]
const ROLL_SPEEDS := [2.0, 5.0, 10.0]

var _t := T.new("drum_notch_test")
var space: PhysicsDirectSpaceState3D
var player
var src := Intent.Scripted.new()
var _passes := 0


func _initialize() -> void:
	_run.call_deferred()


func _in_zone(b: Vector3) -> bool:
	return b.x >= ZONE_X0 and b.x <= ZONE_X1 and b.z >= ZONE_Z0 and b.z <= ZONE_Z1


# Plays secs of physics with the given hold; returns {"notched": bool, "end": Vector3, "v": float}.
func _play(secs: float, hold: Dictionary, jump: bool, boost: bool) -> Dictionary:
	src.hold = hold
	var ticks := int(secs * Engine.physics_ticks_per_second)
	var rest_need := int(REST_S * Engine.physics_ticks_per_second)
	var rest := 0
	var notched := false
	for t in ticks:
		if t % 30 == 0:
			src.press = {}
			if jump:
				src.press["jump_pressed"] = true
			if boost:
				src.press["boost_pressed"] = true
		await physics_frame
		var b: Vector3 = player.ball_position()
		if player.state.velocity.length() < REST_V and _in_zone(b) and b.y < NOTCH_Y:
			rest += 1
			if rest >= rest_need:
				notched = true
		else:
			rest = 0
	return {"notched": notched, "end": player.ball_position(), "v": player.state.velocity.length()}


func _escape(label: String, z: float, move: Vector2, jump: bool, boost: bool) -> void:
	player.reset_to(Vector3(271.07, START_Y, z), Vector3.ZERO)
	src.hold = {}
	src.press = {}
	var settled := await _play(SETTLE_S, {}, false, false)
	var hold := {"move": move}
	if jump:
		hold["jump_held"] = true
	var r := await _play(HOLD_S, hold, jump, boost)
	var b: Vector3 = r["end"]
	var detail := "%s z %.0f: settled (%.2f, %.2f), end (%.2f, %.2f, %.2f) v %.2f" % [label, z, (settled["end"] as Vector3).x, (settled["end"] as Vector3).y, b.x, b.y, b.z, r["v"]]
	if move == Vector2.ZERO:
		_t.check("%s z %.0f never rests notched" % [label, z], not r["notched"] and not settled["notched"], detail)
		_passes += 0 if (r["notched"] or settled["notched"]) else 1
	else:
		var out := not _in_zone(b)
		_t.check("%s z %.0f ends out of the zone" % [label, z], out and not r["notched"], detail)
		_passes += 1 if (out and not r["notched"]) else 0


func _drop(label: String, start: Vector3, vel: Vector3) -> void:
	player.reset_to(start, vel)
	src.hold = {}
	src.press = {}
	for i in 3:
		await physics_frame
	var r := await _play(HOLD_S + 1.0, {}, false, false)
	var b: Vector3 = r["end"]
	_t.check("%s never rests notched" % label, not r["notched"], "end (%.2f, %.2f, %.2f) v %.2f" % [b.x, b.y, b.z, r["v"]])
	_passes += 0 if r["notched"] else 1


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	var cam := Camera3D.new()
	holder.add_child(cam)
	cam.make_current()
	var terrain = Terrain.new({"DEFS": [{"stage": 1, "world": 1, "map": "park_flume"}]})
	terrain.build(holder)
	terrain.use(1)
	for i in 600:
		await physics_frame
		if terrain.rows_ready(1) and i > 5:
			break
	await physics_frame
	await physics_frame
	space = holder.get_world_3d().direct_space_state
	var events := GameEvents.new()
	holder.add_child(events)
	player = PlayerBall.new()
	holder.add_child(player)
	player.setup(Tuning.new(), events, Vector3(232, -13, 480))
	player.source = src
	for i in 10:
		await physics_frame
	var moves := [
		["no input", Vector2.ZERO, false, false],
		["+x", Vector2(1, 0), false, false], ["-x", Vector2(-1, 0), false, false],
		["+z", Vector2(0, 1), false, false], ["-z", Vector2(0, -1), false, false],
		["+x+z", Vector2(0.7, 0.7), false, false], ["+x-z", Vector2(0.7, -0.7), false, false],
		["-x+z", Vector2(-0.7, 0.7), false, false], ["-x-z", Vector2(-0.7, -0.7), false, false],
		["+x boost", Vector2(1, 0), false, true], ["-x boost", Vector2(-1, 0), false, true],
		["jump", Vector2.ZERO, true, false],
	]
	for z in ESCAPE_Z:
		for m in moves:
			await _escape(m[0], z, m[1], m[2], m[3])
	for x in DROP_X:
		for z in DROP_Z:
			await _drop("drop at rest (%.1f, %.0f)" % [x, z], Vector3(x, 1.5, z), Vector3.ZERO)
	for sp in ROLL_SPEEDS:
		await _drop("terrace edge west %.0f m/s" % sp, Vector3(274.0, 1.0, 480.0), Vector3(-sp, 0, 0))
	_t.check("the run counted passes", _passes > 0, "%d passes" % _passes)
	print("drum_notch_test: %d of %d cases pass" % [_passes, ESCAPE_Z.size() * moves.size() + DROP_X.size() * DROP_Z.size() + ROLL_SPEEDS.size()])
	quit(_t.verdict())
