extends RefCounted

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const KeyGlyphs := preload("res://src/ui/key_glyphs.gd")
const WordBudget := preload("res://src/ui/word_budget.gd")

# The fight the word-budget tests share (playtest entry 7: "so much words";
# design-v3/LEGIBILITY.md section 4), on the slice table: a stage-1 fight with a posture Warden
# engaged, a boss plate mounted (a stand-in Control that reports two words), two prompts, one
# named callout and a part name on screen. The words a player can read on the HUD must stay at
# or under the budget. repeat_find primes the ceremony and the banner so the pickup is a
# repeat find and no reveal card is held; without it the pickup is a first find, whose card
# waits for the fight to end. World signs (Label3D, owned by other modules) are counted and
# reported beside it.
#
# 2026-10-10 re-pin (wave 13 B2 fix round, the acceptance gate's finding): the count fails
# unless both prompts are drawn (key_glyphs.shown_glyphs() holds two), and the prompts are
# re-stepped from a fresh camera-ahead anchor just before each count, so a prompt that drifted
# off view can no longer pass the budget by being left out. The same fight is also counted with
# a full ultimate meter (SKILL-BAR.md section 5: "plus Q only when full"), once on a profile
# that has never fired the ultimate (its prompt wears ULTIMATE) and once on one that has fired
# it three times.

const BUDGET := 25
const SETTLE_TICKS := 300
const FIGHT_TICKS := 20
const PLATING := 45.0
const PLATE_SIZE := Vector2(420.0, 44.0)


class Plate:
	extends Control

	func drawn_words() -> PackedStringArray:
		return PackedStringArray(["Rust Warden"])


# A full stand-in for B3's UltimateMeter: only what AbilityState.ultimate() reads.
class FullMeter:
	extends RefCounted
	var locked := false

	func fraction() -> float:
		return 1.0

	func full() -> bool:
		return true


var game
var failures := 0
var _tree: SceneTree
var _name: String
var _repeat_find: bool
var _phase := "boot"
var _wait := 0


func _init(tree: SceneTree, test_name: String, repeat_find: bool) -> void:
	_tree = tree
	_name = test_name
	_repeat_find = repeat_find
	game = Game.new()
	game.test_mode = true
	game.table = "slice"
	tree.root.add_child(game)


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


# One physics frame of the walk; true once the verdict line is printed and the tree is told to quit.
func tick() -> bool:
	if game.flow == null:
		return false
	_wait += 1
	match _phase:
		"boot":
			var source := Intent.Scripted.new()
			source.hold["fire_held"] = true
			game.player.source = source
			game.flow.press_start()
			game.flow.choose_class(1)
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
				print("%s: %s" % [_name, "PASS" if failures == 0 else "FAIL (%d)" % failures])
				_tree.quit(0 if failures == 0 else 1)
				return true
	return false


# The Warden woken by a real ram; the plate mounted; the two prompts the ball can have in a
# fight (the winch on a body and the boost) stepped from a scripted view; a synergy's named
# callout fired; a part gained.
func _stage_fight() -> void:
	var hud = game.hud
	var combat = game.ctx.spawner
	combat.heft_override = 1.0
	var force := 1.0
	while combat.punch_of("ram", force) < PLATING:
		force += 0.05
	combat.strike(game.flow.warden, "ram", force)
	var plate := Plate.new()
	plate.custom_minimum_size = PLATE_SIZE
	hud.mount_plate(plate)
	hud.key_glyphs.set_physics_process(false)
	hud.key_glyphs.new_run()
	hud.key_glyphs.step(2.0, _view())
	game.events.cause_fired.emit("wrecking_ball", null, game.player.ball_position())
	if _repeat_find:
		game.presentation.ceremony._mark_seen("boost_coil")
		game.presentation.banner._mark_seen("part:boost_coil")
	game.events.part_gained.emit("boost_coil", "pickup")


# The two prompts the ball can have in a fight (the winch on a body and the boost), anchored
# 5 m ahead of the camera as it stands now, plus the ultimate when a press would start it.
func _view() -> Dictionary:
	var cam: Camera3D = game.camera.cam
	var ahead: Vector3 = cam.global_position - cam.global_transform.basis.z * 5.0
	return {"ready": {"harpoon": false, "haul": true, "boost": true, "interact": false, "jump": false,
			"ultimate": KeyGlyphs.ultimate_ready(game.player)},
		"line": "body", "charging": false, "mounted": false, "airborne": false, "winching": false,
		"points": {"harpoon": ahead, "haul": ahead, "boost": ahead, "interact": ahead, "jump": ahead}}


func _count() -> void:
	var kind := "repeat find" if _repeat_find else "first find"
	_measure("word budget", kind)
	game.player.abilities.meter = FullMeter.new()
	game.hud.profile.glyph_uses["ultimate"] = 0
	game.hud.key_glyphs.new_run()
	_measure("word budget, full meter, ultimate never fired", kind)
	game.hud.profile.glyph_uses["ultimate"] = KeyGlyphs.RETIRE_AFTER["ultimate"]
	game.hud.key_glyphs.new_run()
	_measure("word budget, full meter, ultimate fired 3 times", kind)
	game.player.abilities.meter = null
	game.hud.profile.glyph_uses.erase("ultimate")


# Re-steps the prompts from a fresh anchor and runs one HUD tick, then counts. Both prompts must
# be drawn, so the count is the picture the budget is about.
func _measure(label: String, kind: String) -> void:
	var glyphs = game.hud.key_glyphs
	glyphs.step(0.016, _view())
	game.hud._process(0.0)
	var drawn: Array[String] = glyphs.shown_glyphs()
	var seen: Dictionary = WordBudget.count(game, game.camera.cam)
	var listed := PackedStringArray()
	for item in seen["items"]:
		listed.append("%s %s %d \"%s\"" % [item["kind"], item["node"], item["words"], item["text"]])
	print("  on screen: " + " | ".join(listed))
	_report(label, drawn.size() == 2 and seen["hud"] <= BUDGET and game.flow.in_play() and game.flow.warden.fight() == "posture",
		"%d HUD words in a stage-%d posture fight with a %s (budget %d), prompts drawn %s, reticle Q %s; %d more on world signs in view"
			% [seen["hud"], game.run.stage, kind, BUDGET, drawn, game.hud.reticle.q_shown(), seen["world"]])
