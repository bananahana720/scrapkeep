extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const Profile := preload("res://src/core/profile.gd")
const Progress := preload("res://src/core/progress.gd")
const Achievements := preload("res://src/core/achievements.gd")
const AchievementsPage := preload("res://src/ui/achievements_page.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const T := preload("res://tests/support/t.gd")

# The Highdraft fragment: beating the Mind (world three's boss_defeated) earns mind_quieted
# once per profile. Isolated part: a fresh profile and the real bus, world two then three.
# Live part: the default table, the Mind fought with paced hits, an arena retry mid-fight,
# then a second run's win earns nothing new.
#
# Evidence limit: hits are TARGET calls, not ball contacts.

const NOW := 1700000000.0
const FIGHT_CAP := 90 * 90
const IDLE_FRAMES := 90 * 5
const HIT_EVERY := 90

var _t := T.new("achievement_fragment_test")
var _game
var _earned: Array[String] = []


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.events.achievement_earned.connect(func(id: String): _earned.append(id))
	await physics_frame
	await _live()
	_isolated()
	_page()
	_game.free()
	quit(_t.verdict())


func _count(id: String) -> int:
	return _earned.count(id)


func _isolated() -> void:
	var profile := Profile.new("%s/fragment_isolated.json" % _game.storage_dir)
	profile.load_profile()
	var progress := Progress.new()
	_game.add_child(progress)
	progress.setup(_game.events, _game.run, profile, func(): return NOW)
	_game.run.begin(ClassDef.all()[0])
	_earned.clear()
	_game.events.world_entered.emit(2)
	_game.events.boss_defeated.emit()
	_t.check("P1 a world-two boss does not earn it", not profile.earned("mind_quieted"), "world 2")
	_t.eq("P1 nothing announced for world two", _count("mind_quieted"), 0)
	_game.events.world_entered.emit(3)
	_game.events.boss_defeated.emit()
	_t.check("P1 the world-three boss earns it", profile.earned("mind_quieted"), "world 3")
	_t.eq("P1 announced once", _count("mind_quieted"), 1)
	_game.events.boss_defeated.emit()
	_t.eq("P1 a second win announces nothing", _count("mind_quieted"), 1)
	progress.free()


func _page() -> void:
	var fresh := Profile.new("%s/fragment_page.json" % _game.storage_dir)
	fresh.load_profile()
	var reading := AchievementsPage.reading("mind_quieted", fresh, null)
	_t.check("P2 the locked card is not earned and names the Highdraft",
		not reading["earned"] and String(reading["text"]).contains("Highdraft"), "%s" % [reading])
	var problems := Achievements.validate(Achievements.ROWS, Achievements.bus_signals(),
		ClassDef.all().map(func(d): return d.id), Cosmetics.ids())
	_t.eq("P2 the table validates", problems, [])


func _pace(mod) -> int:
	var frames := 0
	while Harness._alive(Harness.target(mod)) and frames < FIGHT_CAP:
		if frames >= IDLE_FRAMES and (frames - IDLE_FRAMES) % HIT_EVERY == 0:
			Harness.hit(mod)
		frames += 1
		await physics_frame
	return frames


# boss_defeated comes a beat after the body falls; wait for the run's summary to settle.
func _settle() -> void:
	for _i in 120:
		await physics_frame


func _live() -> void:
	var game = _game
	var flow = game.flow
	var profile = game.ctx.profile
	_t.check("L0 the live profile starts without it", not profile.earned("mind_quieted"), "fresh test storage")
	_earned.clear()
	Harness.boot(game)
	Harness.enter_world(game, 3)
	var mod = Harness.module(game, 3)
	if not _t.check("L1 world 3 module is mind.gd", mod != null and mod.get_script().resource_path.ends_with("mind.gd"), "module %s" % [mod]):
		return
	var frames := 0
	while frames < IDLE_FRAMES + 2 * HIT_EVERY:
		frames += 1
		await physics_frame
	flow.retry_stage()
	_t.check("L2 the arena retry earns nothing", not profile.earned("mind_quieted"), "retried mid-fight")
	mod = Harness.module(game, 3)
	var won_frames: int = await _pace(mod)
	await _settle()
	print("fragment: first victory after %d frame(s) post-retry" % won_frames)
	_t.check("L3 the Mind fell", not Harness._alive(Harness.target(mod)), "%d frames" % won_frames)
	_t.check("L3 mind_quieted earned", profile.earned("mind_quieted"), "after victory")
	var at: int = profile.earned_at("mind_quieted")
	_t.check("L3 earned_at recorded", at > 0, "at %d" % at)
	_t.eq("L3 announced once", _count("mind_quieted"), 1)

	flow.new_run()
	Harness.boot(game)
	Harness.enter_world(game, 3)
	mod = Harness.module(game, 3)
	if not _t.check("L4 second run reaches the Mind", mod != null, "module %s" % [mod]):
		return
	var again: int = await _pace(mod)
	await _settle()
	print("fragment: second victory after %d frame(s)" % again)
	_t.check("L4 the second Mind fell", not Harness._alive(Harness.target(mod)), "%d frames" % again)
	_t.eq("L4 still one announcement", _count("mind_quieted"), 1)
	_t.eq("L4 earned_at unchanged", profile.earned_at("mind_quieted"), at)
