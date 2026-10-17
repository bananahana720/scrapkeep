extends SceneTree

const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# The park table rescues Rivet and Kest (KD7 makes it the launch default): park_dam and park_pit
# pass the schema with their rescue_rows, stage 1 (park_dam) stands Rivet's cage and stage 3
# (park_pit) Kest's, each at its row's site with its pilot seated. Each cage stands on flat ground
# with a flat line in along its face, and Sable rolling in on that line at cruise speed, pressing
# E once the cage is in reach, frees it without mounting a face; that fires its quest and unlocks
# its pilot. Every wait is counted in physics frames; none reads the wall clock.

const HOLD_FRAMES := 60
const ROLL_IN := 15.0
const CRUISE := 14.0
# Ground within FLAT_RING of the cage stays within FLAT_RISE of its foot; the roll-in line climbs
# no more than LINE_GRADE per metre.
const FLAT_RING := 4.0
const FLAT_RISE := 0.5
const LINE_GRADE := 0.1
const ROLL_FRAMES := 240
const CAGES := [
	{"stage": 1, "map": "park_dam", "id": "rivet_cage", "quest": "rivet", "pilot": "runner_gunner"},
	{"stage": 3, "map": "park_pit", "id": "kest_cage", "quest": "dig", "pilot": "demolitions_caster"},
]

var _t := preload("res://tests/support/t.gd").new("park_rescue_test")
var _game
var _source := Intent.Scripted.new()
var _rescued: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _break_frames() -> int:
	return int(ceil(RescueSites.BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10


func _ring_rise(at: Vector2) -> float:
	var t = _game.ctx.terrain
	var foot: float = t.height(at.x, at.y)
	var rise := 0.0
	for a in 16:
		var ang := a * TAU / 16.0
		for d in [FLAT_RING * 0.5, FLAT_RING]:
			rise = maxf(rise, absf(t.height(at.x + cos(ang) * d, at.y + sin(ang) * d) - foot))
	return rise


func _line_grade(at: Vector2, face: Vector2) -> float:
	var t = _game.ctx.terrain
	var worst := 0.0
	var prev: float = t.height(at.x, at.y)
	for m in range(1, int(ROLL_IN) + 2):
		var p := at + face * m
		var h: float = t.height(p.x, p.y)
		worst = maxf(worst, absf(h - prev))
		prev = h
	return worst


# Rolls Sable in from ROLL_IN out along the cage's face at cruise speed, coasting, and presses and
# holds E the first frame the cage is in reach, the camera looking down the line as a player rolling
# in would. Returns whether she ever mounted a face.
func _roll_in(cage, face: Vector2) -> bool:
	var dir := Vector3(-face.x, 0.0, -face.y)
	var start: Vector3 = cage.global_position - dir * ROLL_IN
	var ball: Vector3 = _game.ctx.terrain.drop_point(start.x, start.z, 1.05)
	_game.camera.snap(dir)
	_game.player.reset_to(ball, dir * CRUISE)
	_game.player.body().global_position = ball
	_source.hold = {}
	_source.press = {}
	var mounted := false
	var held := 0
	for i in ROLL_FRAMES:
		await physics_frame
		mounted = mounted or _game.player.kit.mounted
		if held == 0 and not cage.near(_game.ctx.player.ball_position()):
			continue
		if held == 0:
			_source.press["mount_pressed"] = true
		_source.hold["mount_held"] = true
		held += 1
		if held >= HOLD_FRAMES:
			break
	_source.hold = {}
	_source.press = {}
	return mounted


func _run() -> void:
	for row in CAGES:
		var park := ParkMap.new("res://src/world/park/%s.json" % row["map"])
		_t.check("%s passes the park schema" % row["map"], park.ok, str(park.errors))
		_t.eq("%s lists one rescue" % row["map"], park.rescue_sites.map(func(s): return s["id"]), [row["id"]])

	_game = Game.new()
	_game.test_mode = true
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = _source
	_game.events.rescue_completed.connect(func(quest: String): _rescued.append(quest))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	var profile = _game.ctx.profile

	for row in CAGES:
		_game.flow.enter_stage(row["stage"], Vector3.ZERO, false)
		await _frames(60)
		var map = _game.ctx.terrain.map()
		var label: String = row["map"]
		_t.eq("stage %d is %s" % [row["stage"], label], map.title, label)
		_t.eq("%s stands one cage" % label, _game.world.rescue.cages.size(), 1)
		var cage = _game.world.rescue.cage(row["quest"])
		if cage == null:
			_t.check("%s has the %s cage" % [label, row["quest"]], false)
			continue
		var site: Vector2 = map.rescue_sites[0]["at"]
		_t.check("%s's cage stands at its row's site" % label, Vector2(cage.global_position.x, cage.global_position.z).distance_to(site) < 0.5,
			"cage %s site %s" % [cage.global_position, site])
		_t.check("%s's cage is a registered ally device" % label, _game.world.interact.devices.has(cage) and cage.family == "ally")
		var pilot = ClassDef.by_id(row["pilot"])
		_t.check("%s starts locked" % row["pilot"], not profile.has_pilot(row["pilot"]) and not _game.pilot_unlocked(pilot))

		var face: Vector2 = map.rescue_sites[0]["face"]
		var rise := _ring_rise(site)
		_t.check("%s's cage stands on flat ground" % label, rise <= FLAT_RISE, "rise %.2f m within %.0f m" % [rise, FLAT_RING])
		var grade := _line_grade(site, face)
		_t.check("%s's roll-in line is flat" % label, grade <= LINE_GRADE, "worst %.3f m per m over %.0f m" % [grade, ROLL_IN])

		var mounted: bool = await _roll_in(cage, face)
		_t.check("rolling in at cruise speed never mounts a face at %s" % label, not mounted)
		await _frames(_break_frames())
		_t.check("%s's rescue fires %s" % [label, row["quest"]], _rescued.has(row["quest"]), str(_rescued))
		_t.check("%s is unlocked by the park rescue" % row["pilot"], profile.has_pilot(row["pilot"]) and _game.pilot_unlocked(pilot))

	_t.eq("each rescue fired once", _rescued, ["rivet", "dig"])
	_game.free()
	quit(_t.verdict())
