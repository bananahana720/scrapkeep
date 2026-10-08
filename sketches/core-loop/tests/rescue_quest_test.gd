extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Profile := preload("res://src/core/profile.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# World one's rescue quest (rescue_site.gd), on the default table, as Sable on the Spillway:
# - a caged runner stands on stage 1 as one registered device and not on stage 2;
# - a tap of E leaves the lock shut; a hold starts it breaking, and it gives way after
#   BREAK_SECONDS of physics frames, never sooner;
# - rescue_completed("rivet") then fires once, the interact system hears interact_fired once
#   and the profile earns rivet_rescued once, kept after a save and reload;
# - a second completion in the same run changes nothing;
# - a retry rebuilds the cage shut when the quest is not done and open when it is; a new run
#   shuts it again.
# Every wait is counted in physics frames; none reads the wall clock.

const AT := Vector2(60.0, -150.0)
const STANDOFF := 6.0
const HOLD_FRAMES := 60

var _t := preload("res://tests/support/t.gd").new("rescue_quest_test")
var _game
var _source := Intent.Scripted.new()
var _rescued: Array = []
var _fired: Array = []
var _earned: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


# The wait for one lock to break, in the frames of this run's physics rate, with a margin.
func _break_frames() -> int:
	return int(ceil(RescueSites.BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10


func _cage():
	return _game.world.rescue.cage("rivet")


func _forward() -> Vector3:
	var f: Vector3 = -_game.camera.yaw_basis().z
	return Vector3(f.x, 0.0, f.z).normalized()


# The ball on the ground STANDOFF metres short of the cage, looking at it.
func _approach() -> void:
	var at: Vector3 = _cage().global_position - _forward() * STANDOFF
	var ball: Vector3 = _game.ctx.terrain.drop_point(at.x, at.z, 1.05)
	_game.player.reset_to(ball, Vector3.ZERO)
	_game.player.body().global_position = ball
	_source.hold = {}
	_source.press = {}
	await _frames(2)


func _hold_e(frames: int) -> void:
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true
	await _frames(frames)
	_source.hold = {}


func _run() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = _source
	_game.events.rescue_completed.connect(func(quest: String): _rescued.append(quest))
	_game.events.interact_fired.connect(func(family: String, id: String, _at: Vector3): _fired.append([family, id]))
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	await _frames(60)
	var interact = _game.world.interact
	_t.eq("stage 1 stands one cage", _game.world.rescue.cages.size(), 1)
	_t.check("it is a registered device in the ally family", interact.devices.has(_cage()) and _cage().family == "ally", "devices %s" % [interact.devices.size()])
	var map = _game.ctx.terrain.map()
	_t.check("the site stands on authored flat ground", map.rescue_sites[0]["at"] == AT, "at %s" % [map.rescue_sites[0]["at"]])
	_t.check("the prompt reads five words or fewer", _cage().words().split(" ", false).size() <= 5, _cage().words())

	await _approach()
	_t.check("the player starts with Rivet earned: no", not _game.ctx.profile.earned("rivet_rescued"), "earned")
	_source.press["mount_pressed"] = true
	_source.hold["mount_held"] = true
	await _frames(1)
	_source.hold = {}
	await _frames(10)
	_t.check("a tap leaves the lock shut", not _cage().breaking and not _cage().spent and _rescued.is_empty(), "breaking %s" % _cage().breaking)

	await _approach()
	await _hold_e(HOLD_FRAMES)
	_t.check("a hold starts the lock breaking", _cage().breaking, "breaking %s progress %.2f" % [_cage().breaking, _cage().progress])
	await _frames(int(Engine.physics_ticks_per_second))
	_t.check("nothing is rescued a second in", _rescued.is_empty() and _cage().breaking, "rescued %s" % [_rescued])
	await _frames(_break_frames())
	_t.eq("rescue_completed fires once with rivet", _rescued, ["rivet"])
	_t.eq("interact_fired fires once for the cage", _fired, [["ally", "rivet_cage"]])
	_t.eq("rivet_rescued is announced once", _earned.filter(func(id): return id == "rivet_rescued").size(), 1)
	_t.check("the cage is spent with its exit wall folded", _cage().spent and _cage()._bars.visible
		and absf(_cage()._freed_wall.rotation.x) > deg_to_rad(60.0), "spent %s" % _cage().spent)
	var profile = _game.ctx.profile
	_t.check("the profile earned it", profile.earned("rivet_rescued"), "earned")
	_t.near("the profile counts it once", profile.stat("ach.rivet_rescued"), 1.0)
	var path: String = _game.storage_dir.path_join("profile.json")
	var disk := Profile.new(path)
	disk.load_profile()
	_t.check("it survives save and reload", disk.earned("rivet_rescued"), "second Profile reads it")
	_t.near("the reloaded count is 1", disk.stat("ach.rivet_rescued"), 1.0)

	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_game.world.rescue.complete("rivet")
	_t.eq("a second completion in the run emits nothing more", _rescued, ["rivet"])
	_t.near("and the count stays 1", profile.stat("ach.rivet_rescued"), 1.0)

	_game.flow.retry_stage()
	await _frames(3)
	_t.check("a retry after the rescue keeps the exit wall folded", _game.world.rescue.cages.size() == 1 and _cage().spent
		and _cage()._bars.visible and absf(_cage()._freed_wall.rotation.x) > deg_to_rad(60.0), "spent")
	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_t.eq("an open cage completes nothing again", _rescued, ["rivet"])

	_game.events.run_started.emit("sable")
	_game.flow.retry_stage()
	await _frames(3)
	_t.check("a new run shuts the cage again", not _cage().spent and _cage()._bars.visible, "spent %s" % _cage().spent)
	_game.world.rescue._done.clear()
	_game.flow.retry_stage()
	await _frames(3)
	_t.check("a retry of an unfinished quest rebuilds it shut", not _cage().spent and not _cage().breaking, "spent")

	_game.flow.enter_stage(2, Vector3.ZERO, false)
	await _frames(3)
	_t.eq("stage 2 stands no cage", _game.world.rescue.cages.size(), 0)
	_t.check("and no rescue device is registered", _game.world.interact.devices.all(func(d): return not d is RescueSites.Cage), "devices %s" % [_game.world.interact.devices.size()])
	_game.queue_free()
	quit(_t.verdict())
