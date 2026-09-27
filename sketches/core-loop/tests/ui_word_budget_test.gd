extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The v2 word budget (playtest entry 7: "so much words"). A real stage-1 fight as the
# runner, gun held, three chasers close, a part and a threat toast just landed and
# nothing held open: the words a player can read on the HUD stay at or under 25.
# World signs (Label3D, owned by other modules) are counted and reported beside it.

const BUDGET := 25
const SETTLE_TICKS := 300
const FIGHT_TICKS := 20

var _game
var _failures := 0
var _phase := "boot"
var _wait := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			var source := Intent.Scripted.new()
			source.hold["fire_held"] = true
			_game.player.source = source
			_game.flow.press_start()
			_game.flow.choose_class(1)
			_phase = "settle"
			_wait = 0
		"settle":
			if _wait == SETTLE_TICKS:
				_stage_fight()
				_phase = "fight"
				_wait = 0
		"fight":
			if _wait == FIGHT_TICKS:
				_count()
				print("ui_word_budget_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
				quit(0 if _failures == 0 else 1)
				return true
	return false


func _stage_fight() -> void:
	var ball: Vector3 = _game.player.ball_position()
	var ahead: Vector3 = -_game.camera.cam.global_basis.z
	ahead.y = 0.0
	ahead = ahead.normalized()
	for i in 3:
		var side := ahead.cross(Vector3.UP) * (float(i) - 1.0) * 4.0
		_game.ctx.spawner.spawn_enemy("chaser", _game.ctx.terrain.drop_point(ball.x + ahead.x * 12.0 + side.x, ball.z + ahead.z * 12.0 + side.z, 1.0))
	_game.run.add_scrap(30, ball)
	_game.run.add_part("boost_coil", "test")
	_game.events.threat_rose.emit(1)


func _count() -> void:
	var seen: Dictionary = WordBudget.count(_game, _game.camera.cam)
	var listed := PackedStringArray()
	for item in seen["items"]:
		listed.append("%s %s %d \"%s\"" % [item["kind"], item["node"], item["words"], item["text"]])
	print("  on screen: " + " | ".join(listed))
	_report("word budget", seen["hud"] <= BUDGET and _game.flow.in_play(),
		"%d HUD words in a stage-%d fight (budget %d); %d more on world signs in view"
			% [seen["hud"], _game.run.stage, BUDGET, seen["world"]])
