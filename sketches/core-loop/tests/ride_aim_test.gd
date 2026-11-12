extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Arena := preload("res://src/boss/arena.gd")

# Wave 37, ruling cv (one ride through a world): both world 1 launches, dam to flume and flume to the Slag Bowl,
# through the real flow with a scripted ball. At each cut the ball's heading and the camera's yaw on the last tick of
# the flight are set beside the first tick after it: the rail turns both in flight to the heading the next place is
# entered on, so neither moves more than YAW_MAX_DEG at the cut. Horizontal speed after the cut is at least the flight's
# last reading (the stage entry keeps it exactly; the bowl raises a slow ball to cruise). The flume launch comes down
# inside the bowl, on landing rings marked at the touchdown.
#
# Planted: a second run takes the dam launch with the rail's turn switched off (Launch.aim with no heading); its cut
# must snap by more than YAW_MAX_DEG, or the measure cannot see a snap.

const BEACON_SECONDS := 0.6
const APPROACH := 16.0
const APPROACH_SPEED := 21.0
const YAW_MAX_DEG := 5.0
const PAD_TOLERANCE := 6.0
const TICK_LIMIT := 90 * 90

var _game
var _source: Intent.Scripted
var _failures := 0
var _ticks := 0
var _started := false
var _planted := false
var _phase := "boot"
var _wait := 0
var _last := {}
var _seams: Array[Dictionary] = []
var _bowl := {}


func _initialize() -> void:
	_boot()


func _boot() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	_source = Intent.Scripted.new()
	_started = false
	_ticks = 0
	_phase = "boot"
	_last = {}
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> bool:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
	return ok


func _physics_process(_delta: float) -> bool:
	if not _started:
		if _game == null or _game.flow == null:
			return false
		_start()
		return false
	_ticks += 1
	if _ticks > TICK_LIMIT:
		_report("timeout", false, "stalled in %s, phase %s, planted %s" % [_game.flow.state_name(), _phase, _planted])
		return _finish()
	return _step()


func _start() -> void:
	_started = true
	var events = _game.events
	events.stage_entered.connect(_on_stage_entered)
	events.reward_offered.connect(_on_offered)
	events.launched.connect(_on_launched)
	_game.ctx.calm = true
	_game.flow.beacon_seconds_override = BEACON_SECONDS
	_game.player.source = _source
	_game.flow.press_start()
	_game.flow.choose_class(0)


# The ball's heading and the camera's yaw, both as a camera yaw (ChaseCamera.snap: atan2(-x, -z)).
func _sample() -> Dictionary:
	var v: Vector3 = _game.player.state.velocity
	return {"state": _game.flow.state_name(), "stage": _game.flow.stage(), "ball": atan2(-v.x, -v.z),
		"camera": float(_game.camera.yaw), "speed": Vector2(v.x, v.z).length()}


func _step() -> bool:
	var now := _sample()
	if _phase == "flight":
		print("FLIGHT %s stage %d ball %.1f camera %.1f speed %.2f" % [now["state"], now["stage"], rad_to_deg(now["ball"]), rad_to_deg(now["camera"]), now["speed"]])
	if _phase == "flight" and now["state"] != "launch" and not _last.is_empty() and _last["state"] == "launch":
		if _seam(_last, now):
			return _finish()
	_last = now
	var player = _game.player
	match _phase:
		"to_beacon":
			_wait += 1
			if _wait == 2:
				var at: Vector3 = _game.flow.beacon.global_position + Vector3.UP * 1.5
				player.reset_to(at)
				player.body().global_position = at
		"bowl":
			_wait += 1
			if player.state.grounded and not _bowl.has("touchdown"):
				_bowl["touchdown"] = player.ball_position()
			if _bowl.has("touchdown") or _wait > 270:
				return _finish()
	return false


func _on_launched(_velocity: Vector3) -> void:
	_source.hold = {}
	_phase = "flight"


# True when the run has seen what it came for.
func _seam(before: Dictionary, after: Dictionary) -> bool:
	var name := "dam_to_flume" if after["state"] != "boss" else "flume_to_bowl"
	var row := {"seam": name, "planted": _planted,
		"ball": absf(rad_to_deg(angle_difference(before["ball"], after["ball"]))),
		"camera": absf(rad_to_deg(angle_difference(before["camera"], after["camera"]))),
		"before": before["speed"], "after": after["speed"]}
	_seams.append(row)
	print("SEAM %s planted=%s ball_yaw_jump=%.1f camera_yaw_jump=%.1f speed %.2f -> %.2f" % [name, _planted, row["ball"], row["camera"], row["before"], row["after"]])
	if _planted:
		return true
	if name == "flume_to_bowl":
		var launch = _game.world.launch
		_bowl = {"rings": launch.landing_rings(), "pad": launch.landing_point}
		_phase = "bowl"
	else:
		_phase = "to_beacon"
	_wait = 0
	return false


func _on_stage_entered(stage: int, _retry: bool) -> void:
	_source.hold = {}
	if _planted and stage == 1:
		# The turn switched off: the rail keeps the launch's heading and the cut snaps it.
		_game.world.launch.aim(Vector3.ZERO)
	if stage == 1:
		_phase = "to_beacon"
		_wait = 0


func _on_offered(offers: Array) -> void:
	if _phase == "approach" or _phase == "flight":
		return
	var offer: Dictionary = offers[0]
	var facing: Vector3 = offer["facing"]
	var start: Vector3 = offer["at"] - facing * APPROACH
	var at: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.player.reset_to(at, facing * APPROACH_SPEED)
	_game.player.body().global_position = at
	_game.camera.snap(facing)
	_source.hold = {"move": Vector2(0.0, 1.0)}
	_phase = "approach"


func _finish() -> bool:
	if not _planted:
		_judge_live()
		_game.free()
		_game = null
		if not _game_has_aim():
			return _done()
		_planted = true
		_boot()
		return false
	_judge_planted()
	return _done()


var _aim_known := true


func _game_has_aim() -> bool:
	return _aim_known


func _judge_live() -> void:
	var live := _seams.filter(func(r: Dictionary): return not r["planted"])
	_aim_known = _game.world.launch.has_method("aim")
	for name in ["dam_to_flume", "flume_to_bowl"]:
		var rows := live.filter(func(r: Dictionary): return r["seam"] == name)
		if not _report("%s measured" % name, rows.size() == 1, "%d cut(s) seen" % rows.size()):
			continue
		var r: Dictionary = rows[0]
		_report("%s ball heading at the cut" % name, r["ball"] < YAW_MAX_DEG, "the ball's heading moved %.1f degrees between the last tick of the flight and the first after the cut (under %.0f)" % [r["ball"], YAW_MAX_DEG])
		_report("%s camera at the cut" % name, r["camera"] < YAW_MAX_DEG, "the camera's yaw moved %.1f degrees at the cut (under %.0f)" % [r["camera"], YAW_MAX_DEG])
		_report("%s speed carried" % name, r["after"] >= r["before"] - 0.05, "%.2f m/s horizontal on the last tick of the flight, %.2f on the first after the cut" % [r["before"], r["after"]])
	var arena = _game.boss.arena if _game.boss != null and "arena" in _game.boss else null
	var pad: Vector3 = _bowl.get("pad", Vector3.INF)
	var inside: bool = arena != null and pad != Vector3.INF and arena.radius_of(pad) <= Arena.BANK_R
	_report("flume_to_bowl landing rings", int(_bowl.get("rings", 0)) > 0 and inside,
		"%d rings stand at the bowl entry; the pad marks %s, %s" % [_bowl.get("rings", 0), pad,
			("%.1f m from the bowl's centre (bank at %.0f)" % [arena.radius_of(pad), Arena.BANK_R]) if arena != null and pad != Vector3.INF else "no mark"])
	var down: Vector3 = _bowl.get("touchdown", Vector3.INF)
	var miss := Vector2(pad.x - down.x, pad.z - down.z).length() if pad != Vector3.INF and down != Vector3.INF else INF
	_report("flume_to_bowl touchdown", arena != null and down != Vector3.INF and arena.radius_of(down) <= Arena.BANK_R and miss <= PAD_TOLERANCE,
		"the ball came down at %s, %.1f m from the pad" % [down, miss])


func _judge_planted() -> void:
	var rows := _seams.filter(func(r: Dictionary): return r["planted"])
	var snapped: bool = rows.size() == 1 and rows[0]["ball"] > YAW_MAX_DEG and rows[0]["camera"] > YAW_MAX_DEG
	_report("planted: turn switched off snaps at the dam cut", snapped,
		("ball %.1f, camera %.1f degrees at the cut (must exceed %.0f)" % [rows[0]["ball"], rows[0]["camera"], YAW_MAX_DEG]) if rows.size() == 1 else "%d planted cut(s) seen" % rows.size())


func _done() -> bool:
	if not _aim_known:
		_report("planted: Launch.aim exists to switch the turn off", false, "no aim() on the launch")
	print("ride_aim_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	if _game != null:
		_game.free()
		_game = null
	quit(0 if _failures == 0 else 1)
	return true
