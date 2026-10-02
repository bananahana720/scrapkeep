extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The word budget (playtest entry 7: "so much words"; design-v3/LEGIBILITY.md section 4) on
# the slice table: a stage-1 fight with a posture Warden engaged, a boss plate mounted (a
# stand-in Control that reports two words), two prompts, one named callout and a part name
# on screen. The words a player can read on the HUD stay at or under 25.
# World signs (Label3D, owned by other modules) are counted and reported beside it.

const BUDGET := 25
const SETTLE_TICKS := 300
const FIGHT_TICKS := 20
const PLATING := 45.0
const PLATE_SIZE := Vector2(420.0, 44.0)


class Plate:
	extends Control

	func drawn_words() -> PackedStringArray:
		return PackedStringArray(["Rust Warden"])


var _game
var _failures := 0
var _phase := "boot"
var _wait := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
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


# The Warden woken by a real ram; the plate mounted; the two prompts the ball can have in a
# fight (the winch on a body and the boost) stepped from a scripted view; a synergy's named
# callout fired; a part gained. The part is a repeat find: a first find's reveal card is the
# ceremony's own (presentation) and is not part of this case.
func _stage_fight() -> void:
	var hud = _game.hud
	var combat = _game.ctx.spawner
	combat.heft_override = 1.0
	var force := 1.0
	while combat.punch_of("ram", force) < PLATING:
		force += 0.05
	combat.strike(_game.flow.warden, "ram", force)
	var plate := Plate.new()
	plate.custom_minimum_size = PLATE_SIZE
	hud.mount_plate(plate)
	hud.key_glyphs.set_physics_process(false)
	hud.key_glyphs.new_run()
	var view := {"ready": {"harpoon": false, "haul": true, "boost": true, "interact": false, "jump": false}, "line": "body", "charging": false,
		"mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": Vector3.ONE, "haul": Vector3.ONE, "boost": Vector3.ONE, "interact": Vector3.ONE, "jump": Vector3.ONE}}
	hud.key_glyphs.step(2.0, view)
	_game.events.cause_fired.emit("wrecking_ball", null, _game.player.ball_position())
	_game.presentation.ceremony.find_of("boost_coil", "pickup")
	_game.events.part_gained.emit("boost_coil", "pickup")


func _count() -> void:
	var seen: Dictionary = WordBudget.count(_game, _game.camera.cam)
	var listed := PackedStringArray()
	for item in seen["items"]:
		listed.append("%s %s %d \"%s\"" % [item["kind"], item["node"], item["words"], item["text"]])
	print("  on screen: " + " | ".join(listed))
	_report("word budget", seen["hud"] <= BUDGET and _game.flow.in_play() and _game.flow.warden.fight() == "posture",
		"%d HUD words in a stage-%d posture fight (budget %d); %d more on world signs in view"
			% [seen["hud"], _game.run.stage, BUDGET, seen["world"]])
