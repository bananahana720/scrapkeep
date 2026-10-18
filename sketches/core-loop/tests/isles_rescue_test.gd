extends SceneTree

const Achievements := preload("res://src/core/achievements.gd")
const ClassCard := preload("res://src/ui/class_card.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Profile := preload("res://src/core/profile.gd")
const RescueSites := preload("res://src/world/rescue_site.gd")

# Tally's rescue on the park table (Andrew's "Rescue on the isles" and "Either path", 2026-10-17):
# park_islands.json's rescue row stands tally_cage on stage 5 with Tally named as data; completing it
# fires rescue_completed("isles") once, the profile earns isles_rescued and opens Tally once across a
# retry, and the ledger path stays open beside it (pilot_locks_test GP5-5 runs both orders).
# Every wait is counted in physics frames; none reads the wall clock.

const STANDOFF := 6.0
const HOLD_FRAMES := 60

var _t := preload("res://tests/support/t.gd").new("isles_rescue_test")
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
	return _game.world.rescue.cage("isles")


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
	_game.table = "park"
	root.add_child(_game)
	while _game.flow == null:
		await physics_frame
	_game.player.source = _source
	_game.events.rescue_completed.connect(func(quest: String): _rescued.append(quest))
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	_game.flow.press_start()
	_game.flow.choose_class(0)
	_game.ctx.calm = true
	_game.flow.enter_stage(5, Vector3.ZERO, false)
	await _frames(60)
	var profile = _game.ctx.profile
	var tally = ClassDef.by_id("tally")
	var map = _game.ctx.terrain.map()
	_t.eq("stage 5 is the sky islands", map.title, "park_islands")
	_t.eq("it stands one cage", _game.world.rescue.cages.size(), 1)
	_t.check("the isles cage is a registered ally device", _game.world.interact.devices.has(_cage()) and _cage().family == "ally", "devices %s" % [_game.world.interact.devices.size()])
	_t.eq("the park row names Tally as data", map.rescue_sites[0]["pilot"], "tally")
	var site: Vector2 = map.rescue_sites[0]["at"]
	var cage_at: Vector3 = _cage().global_position
	_t.check("the cage stands at the park's rescue row", Vector2(cage_at.x, cage_at.z).distance_to(site) < 0.5, "cage %s site %s" % [cage_at, site])
	_t.check("Tally sits in the cage", _cage()._pilot != null, "no caged pilot")
	print("isles_rescue_test: observation: cage.terms() = \"%s\"" % _cage().terms())

	_t.check("Tally starts locked", not profile.has_pilot("tally") and not _game.pilot_unlocked(tally), "locked")
	_t.check("the locked card hint names both paths", ClassCard.unlock_hint(tally, _game.progress).begins_with(String(tally.unlock["label"])), ClassCard.unlock_hint(tally, _game.progress))

	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_t.eq("rescue_completed fired once with isles", _rescued, ["isles"])
	_t.eq("isles_rescued is announced once", _earned.filter(func(id): return id == "isles_rescued").size(), 1)
	_t.check("the cage is spent and open", _cage().spent and not _cage()._bars.visible, "spent %s" % _cage().spent)
	_t.near("the profile counts it once", profile.stat("ach.isles_rescued"), 1.0)
	_t.check("Tally is unlocked by the rescue", profile.has_pilot("tally") and _game.pilot_unlocked(tally), "unlocked")
	_t.check("the ledger row is not earned by the rescue", not profile.earned(ClassDef.unlock_row("leaves:3")), "ledger path stays its own")

	_game.flow.retry_stage()
	await _frames(3)
	_t.check("a retry rebuilds the cage spent and open", _game.world.rescue.cages.size() == 1 and _cage().spent and not _cage()._bars.visible, "spent")
	await _approach()
	await _hold_e(HOLD_FRAMES)
	await _frames(_break_frames())
	_t.eq("a hold on the open cage fires nothing", _rescued, ["isles"])
	_t.near("the stat stays 1 after the retry", profile.stat("ach.isles_rescued"), 1.0)

	var disk := Profile.new(_game.storage_dir.path_join("profile.json"))
	disk.load_profile()
	_t.check("a fresh Profile on the saved file reads Tally unlocked", disk.has_pilot("tally"), "second Profile reads it")
	_game.queue_free()
	quit(_t.verdict())
