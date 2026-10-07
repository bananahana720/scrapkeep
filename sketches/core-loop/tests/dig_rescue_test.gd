extends SceneTree

const Achievements := preload("res://src/core/achievements.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Profile := preload("res://src/core/profile.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# Kest's rescue on the default table: completing kest_cage on stage 3 (the Dig) fires
# rescue_completed("dig") once, the profile earns dig_rescued and unlocks demolitions_caster
# once across a retry, and the locked Kest card's hint is the dig_rescued row text.
# Every wait is counted in physics frames; none reads the wall clock.

const STANDOFF := 6.0
const HOLD_FRAMES := 60

var _t := preload("res://tests/support/t.gd").new("dig_rescue_test")
var _game
var _source := Intent.Scripted.new()
var _rescued: Array = []
var _earned: Array = []


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		_game.player.set_velocity_now(Vector3.ZERO)
		await physics_frame


func _break_frames() -> int:
	return int(ceil(RescueSites.BREAK_SECONDS * Engine.physics_ticks_per_second)) + 10


func _cage():
	return _game.world.rescue.cage("dig")


func _forward() -> Vector3:
	var f: Vector3 = -_game.camera.yaw_basis().z
	return Vector3(f.x, 0.0, f.z).normalized()


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
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	_game.flow.enter_stage(3, Vector3.ZERO, false)
	await _frames(60)

	var profile = _game.ctx.profile
	var kest = ClassDef.by_id("demolitions_caster")
	var map = _game.ctx.terrain.map()
	_t.eq("stage 3 is the Dig", map.title, "Dig: the upper bench")
	_t.eq("it stands one cage", _game.world.rescue.cages.size(), 1)
	_t.check("the dig cage is a registered ally device", _game.world.interact.devices.has(_cage()) and _cage().family == "ally", "devices %s" % [_game.world.interact.devices.size()])
	var site: Vector2 = map.rescue_sites[0]["at"]
	var cage_at: Vector3 = _cage().global_position
	_t.check("the cage stands at the map's rescue site", Vector2(cage_at.x, cage_at.z).distance_to(site) < 0.5, "cage %s site %s" % [cage_at, site])
	print("dig_rescue_test: observation: cage.terms() = \"%s\"" % _cage().terms())

	var hint_row: String = Achievements.ROWS["dig_rescued"]["text"]
	_t.check("Kest starts locked", not profile.has_pilot("demolitions_caster") and not _game.pilot_unlocked(kest), "locked")
	_t.eq("the locked card hint is the dig_rescued row text", ClassCard.unlock_hint(kest, _game.progress), hint_row)

	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_t.eq("rescue_completed fired once with dig", _rescued, ["dig"])
	_t.eq("dig_rescued is announced once", _earned.filter(func(id): return id == "dig_rescued").size(), 1)
	_t.check("the cage is spent and open", _cage().spent and not _cage()._bars.visible, "spent %s" % _cage().spent)
	_t.check("the profile earned dig_rescued", profile.earned("dig_rescued"), "earned")
	_t.near("the profile counts it once", profile.stat("ach.dig_rescued"), 1.0)
	_t.check("Kest is unlocked", profile.has_pilot("demolitions_caster") and _game.pilot_unlocked(kest), "unlocked")

	_game.world.rescue.complete("dig")
	_t.eq("a second completion in the run emits nothing more", _rescued, ["dig"])
	_t.near("and the count stays 1", profile.stat("ach.dig_rescued"), 1.0)

	_game.flow.retry_stage()
	await _frames(3)
	_t.check("a retry rebuilds the cage spent and open", _game.world.rescue.cages.size() == 1 and _cage().spent and not _cage()._bars.visible, "spent")
	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_t.eq("a hold on the open cage fires nothing", _rescued, ["dig"])
	_t.near("the stat stays 1 after the retry", profile.stat("ach.dig_rescued"), 1.0)
	_t.check("still unlocked after the retry", profile.has_pilot("demolitions_caster"), "unlocked")

	var disk := Profile.new(_game.storage_dir.path_join("profile.json"))
	disk.load_profile()
	_t.check("a fresh Profile on the saved file reads Kest unlocked", disk.has_pilot("demolitions_caster"), "second Profile reads it")
	_game.queue_free()
	quit(_t.verdict())
