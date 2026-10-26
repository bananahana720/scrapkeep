extends SceneTree
# smoke: timeout=420s

# The dam's canyon walls (park_dam.json canyon_wall_*, mesa_rim ground rows, unit 10 "park edge"). On 0e2bc2f0 the ground
# ran flat to the play square's edge and a ball held outward was snapped 39 m back to the play rect at +-799 m
# (flow.gd _rescue_if_fallen) with nothing to read; four rolls, one or two snaps each. The walls stand inside the square:
# a 32 m mesa stamp whose face rises over 9.6 m from its foot, then a flat top out to the edge, which the apron rim carries
# on. Anchor fields stop 12 m short of each foot, so no post stands on a face.
#
# The real Game on the park table (stage 1, park_dam, calm, no Warden), the real ball and its scripted stick, set in the
# camera's frame each tick as a person's keys are. Two opposite corners (north-east, south-west) carry all four walls,
# and a corner, two faces meeting, is where a ball could wedge. Each starts at a rest LEAD_M inside both feet and runs:
#   press   the stick held diagonally into the corner for PRESS_S: the ball reaches both faces (a control that the walls
#           are really there) and is held: its centre never passes a crest line and it is never snapped back.
#   escape  from where press left it, straight back and along each wall (away from the other) for ESCAPE_S: the ball
#           leaves by LEAVE_M at least, so the corner holds no wedge.
#   launch  from the rest, the ball sent square at each of the two walls at LAUNCH_MPS, past a cracked build's top speed:
#           SETTLE_S later it rolls on the basin floor inside the feet, never snapped back.
# Every wall's crest stands at least RISE_MIN_M over its foot along its length (read from the ground, no play). The
# 25 Oct fin-foot spot (98, 103, 137) is park_dam_fin_foot_probe_test's, which stays green. Each spot costs a far
# teleport (the cloud's 4 vCPU box runs this scene several times slower than real time), so the shots are short and few.

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const T := preload("res://tests/support/t.gd")

# The walls' feet and crests (the face rises 0.3 x 32 m from the foot), from the rows in park_dam.json.
const FOOT := {"east": 765.0, "west": -765.0, "north": -775.0, "south": 765.0}
const RISE_M := 9.6
const RISE_MIN_M := 25.0
const CORNERS := [["north", "east"], ["south", "west"]]
const LEAD_M := 12.0
const PRESS_S := 2.0
const ESCAPE_S := 1.5
const LEAVE_M := 8.0
const LAUNCH_MPS := 45.0
const SETTLE_S := 4.5
# A ball resting at the foot's crease stands off the foot line by up to its radius (the face starts mid cell).
const FACE_SLACK_M := Tuning.RADIUS + 0.5
const SNAP_M := 8.0
const FLOOR_SLACK_M := 3.0

var t := T.new("park_dam_rim_roll_test")
var game
var source := Intent.Scripted.new()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	game.ctx.calm = true
	game.flow.force_warden = false
	game.player.source = source
	game.flow.press_start()
	game.flow.choose_class(1)
	game.flow.enter_stage(1, Vector3.ZERO, false)
	await physics_frame
	await physics_frame
	var terrain = game.ctx.terrain
	t.eq("real Game plays the dam on the park table", terrain.map().title, "park_dam")
	var low := INF
	var low_at := ""
	for side: String in FOOT:
		for s in range(-740, 741, 20):
			var foot := _point([side], s, 0.0)
			var crest := _point([side], s, -RISE_M)
			var rise: float = terrain.height(crest.x, crest.y) - terrain.height(foot.x, foot.y)
			if rise < low:
				low = rise
				low_at = "%s %d" % [side, s]
	t.check("every wall's crest stands at least %.0f m over its foot" % RISE_MIN_M, low >= RISE_MIN_M, "lowest %.1f m at %s" % [low, low_at])
	for corner: Array in CORNERS:
		await _corner(corner)
	game.free()
	quit(t.verdict())


func _corner(sides: Array) -> void:
	var terrain = game.ctx.terrain
	var name := "%s-%s" % sides
	var start := _point(sides, 0.0, LEAD_M)
	var rest := Vector3(start.x, terrain.height(start.x, start.y) + Tuning.RADIUS + 0.2, start.y)
	var out := (_outward(sides[0]) + _outward(sides[1])).normalized()
	var press := await _shot(rest, out, PRESS_S)
	print("  %s press: end=%s outmost=%.2f snaps=%d" % [name, press["end"], press["outmost"], press["snaps"]])
	for side: String in sides:
		t.check("%s: the ball reaches the %s face (control)" % [name, side], _beyond(side, press["end"]) > -FACE_SLACK_M, "end %s" % press["end"])
	t.check("%s: the walls hold it below the crest" % name, press["outmost"] < RISE_M, "outmost %.2f m past a foot" % press["outmost"])
	t.check("%s: no snap back" % name, press["snaps"] == 0, "%d snaps" % press["snaps"])
	var aways := {"back": -out}
	for side: String in sides:
		aways["along %s" % side] = -_outward(sides[1] if side == sides[0] else sides[0])
	for away: String in aways:
		var shot := await _shot(press["end"], aways[away], ESCAPE_S)
		print("  %s escape %s: moved=%.1f m" % [name, away, shot["moved"]])
		t.check("%s: escapes %s" % [name, away], shot["moved"] >= LEAVE_M, "moved %.1f m in %.1f s" % [shot["moved"], ESCAPE_S])
	for side: String in sides:
		var launch := await _shot(rest, Vector3.ZERO, SETTLE_S, _outward(side) * LAUNCH_MPS)
		var end: Vector3 = launch["end"]
		var floor_y: float = terrain.height(end.x, end.z)
		print("  %s launch at %s: end=%s climbed=%.2f snaps=%d" % [name, side, end, launch["outmost"], launch["snaps"]])
		t.check("%s: a ball launched at the %s wall ends inside the feet" % [name, side], not _past(sides, end, 0.0), "end %s" % end)
		t.check("%s: a ball launched at the %s wall is never snapped back" % [name, side], launch["snaps"] == 0, "%d snaps" % launch["snaps"])
		t.check("%s: a ball launched at the %s wall ends on the basin floor" % [name, side], end.y - floor_y < Tuning.RADIUS + FLOOR_SLACK_M,
				"%.1f m over the ground" % (end.y - floor_y))


# A point `inset` metres inside the feet of `sides` (negative: past the foot, toward the edge), `s` along the first side.
func _point(sides: Array, s: float, inset: float) -> Vector2:
	var p := Vector2.ZERO
	for side: String in ["east", "west", "north", "south"]:
		if not sides.has(side):
			continue
		var foot: float = FOOT[side] - signf(FOOT[side]) * inset
		if side == "east" or side == "west":
			p.x = foot
		else:
			p.y = foot
	if sides.size() == 1:
		if sides[0] == "east" or sides[0] == "west":
			p.y = s
		else:
			p.x = s
	return p


func _outward(side: String) -> Vector3:
	match side:
		"east": return Vector3.RIGHT
		"west": return Vector3.LEFT
		"north": return Vector3.FORWARD
	return Vector3.BACK


# Whether `at` lies past (outward of) any of `sides`' feet by more than `slack` metres.
func _past(sides: Array, at: Vector3, slack: float) -> bool:
	for side: String in sides:
		if _beyond(side, at) > slack:
			return true
	return false


func _beyond(side: String, at: Vector3) -> float:
	var foot: float = FOOT[side]
	var c := at.x if side == "east" or side == "west" else at.z
	return (c - foot) * signf(foot)


func _shot(from: Vector3, want: Vector3, secs: float, velocity := Vector3.ZERO) -> Dictionary:
	var player = game.player
	var sides := ["east", "west", "north", "south"]
	player.reset_to(from, velocity)
	source.hold = {}
	await physics_frame
	var prev: Vector3 = player.ball_position()
	var outmost := -INF
	var snaps := 0
	for tick in int(secs * Engine.physics_ticks_per_second):
		if want != Vector3.ZERO:
			var yaw: float = game.camera.yaw
			var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
			var right := Vector3(cos(yaw), 0.0, -sin(yaw))
			source.hold = {"move": Vector2(want.dot(right), want.dot(forward)).normalized()}
		await physics_frame
		var b: Vector3 = player.ball_position()
		if Vector2(b.x - prev.x, b.z - prev.z).length() > SNAP_M:
			snaps += 1
		for side: String in sides:
			outmost = maxf(outmost, _beyond(side, b))
		prev = b
	source.hold = {}
	return {"end": prev, "moved": Vector2(prev.x - from.x, prev.z - from.z).length(), "outmost": outmost, "snaps": snaps}
