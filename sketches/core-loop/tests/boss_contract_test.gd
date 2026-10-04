extends SceneTree

const Game := preload("res://src/game.gd")
const BossContract := preload("res://src/boss/boss_contract.gd")

# The frozen boss contract (src/boss/boss_contract.gd): the posture Warden built on the
# slice table conforms to TARGET and each method answers its declared type; a double
# missing one method is named; two module doubles satisfy MODULE side by side without
# touching ctx.boss; describe() names every method once. Brindle (F2a) and the later-world
# stub (F5) are pending and not checked here.
#
# Evidence limit: this checks the surface and return types, not the fight's behaviour.

const TARGET_COUNT := 19
const PROPERTY_COUNT := 6
const MODULE_COUNT := 6

var _game
var _failures := 0


# A TARGET double that answers everything except what it is told to drop.
class TargetDouble:
	extends RefCounted
	var plating := 0.0
	var hp := 10.0
	var max_hp := 10.0
	var radius := 1.0
	var half_height := 1.0
	var kind := "warden"
	func knock(_direction: Vector3, _force: float) -> void: pass
	func flash() -> void: pass
	func set_tint(_state: String) -> void: pass
	func plating_now() -> float: return 0.0
	func unplated_by_magnet() -> bool: return false
	func fight() -> String: return "posture"
	func posture() -> float: return 0.0
	func staggered() -> bool: return false
	func stagger_left() -> float: return 0.0
	func chunks_left() -> int: return 4
	func glances() -> int: return 0
	func chunk_cracked() -> bool: return false
	func take_damage(_amount: float) -> float: return 0.0
	func is_dead() -> bool: return false
	func plating_for(_kind: String, _part: String) -> float: return 0.0
	func hit_mult(_kind: String, _part: String) -> float: return 1.0
	func contact_part(_ball: Vector3, _kind: String) -> String: return ""
	func on_struck(_kind: String, _part: String, _result: Dictionary) -> void: pass


# A double that lacks the properties combat reads.
class NoPropsDouble:
	extends RefCounted
	func fight() -> String: return "posture"


# The same, with judge_hit: the full conforming double.
class FullDouble:
	extends TargetDouble
	func judge_hit(_kind: String, _punch: float, _smash: bool, _tier: int) -> Dictionary: return {}


class ModuleDouble:
	extends RefCounted
	var entered := 0
	func enter_arena(_v: Vector3) -> void: entered += 1
	func exit_arena() -> void: pass
	func active() -> bool: return entered > 0
	func ground_height_at(_p: Vector3) -> float: return 0.0
	func music_state() -> Dictionary: return {}
	func objective_text() -> String: return ""


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	_game.table = "slice"
	root.add_child(_game)
	_run()


func _report(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _frames(count: int) -> void:
	for i in count:
		await physics_frame


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	_game.ctx.calm = true
	_game.flow.force_warden = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	await _frames(24)
	var warden = _game.flow.warden
	if not is_instance_valid(warden):
		print("boss_contract_test: FAIL (no Warden on the slice table)")
		quit(1)
		return

	# (a) the posture Warden conforms, and each call returns the declared type.
	var missing: Array = BossContract.conforms(warden, BossContract.TARGET)
	_report("warden conforms to TARGET", missing.is_empty(), "missing %s" % [missing])
	var args := {"judge_hit": ["ram", 0.0, false, 0], "take_damage": [0.0], "plating_for": ["ram", ""],
			"hit_mult": ["ram", ""], "contact_part": [Vector3.ZERO, "ram"],
			"knock": [Vector3.FORWARD, 0.0], "set_tint": ["calm"]}
	var typed := true
	var wrong: Array = []
	for row in BossContract.TARGET:
		if row[0] == "on_struck":
			continue
		var got = warden.callv(row[0], args.get(row[0], []))
		if typeof(got) != int(row[2]):
			typed = false
			wrong.append("%s %d" % [row[0], typeof(got)])
	_report("warden returns the declared types", typed, "wrong %s" % [wrong])

	# (b) a double missing judge_hit is named; the full double conforms.
	var short_missing: Array = BossContract.conforms(TargetDouble.new(), BossContract.TARGET)
	_report("double without judge_hit is named", short_missing == ["judge_hit"], "missing %s" % [short_missing])
	var no_props: Array = BossContract.conforms(NoPropsDouble.new(), BossContract.TARGET)
	var props_named := true
	for row in BossContract.TARGET_PROPERTIES:
		props_named = props_named and row[0] in no_props
	_report("double without properties is named", props_named, "missing %s" % [no_props])
	_report("full double conforms", BossContract.conforms(FullDouble.new(), BossContract.TARGET).is_empty(), "")
	_report("null conforms to nothing", BossContract.conforms(null, BossContract.MODULE).size() == MODULE_COUNT, "")

	# (c) two module doubles side by side leave ctx.boss alone.
	var before = _game.ctx.boss if "boss" in _game.ctx else _game.ctx.get_meta("boss", null)
	var one := ModuleDouble.new()
	var two := ModuleDouble.new()
	one.enter_arena(Vector3.ZERO)
	var after = _game.ctx.boss if "boss" in _game.ctx else _game.ctx.get_meta("boss", null)
	_report("module doubles conform", BossContract.conforms(one, BossContract.MODULE).is_empty() \
			and BossContract.conforms(two, BossContract.MODULE).is_empty(), "")
	_report("two modules stand side by side", one.active() and not two.active() and after == before, "ctx.boss unchanged %s" % [after == before])

	# (d) describe() names every method once, and the lists keep their size.
	var text: String = BossContract.describe()
	var once := true
	for row in BossContract.TARGET + BossContract.MODULE:
		if text.count("  %s(" % row[0]) != 1:
			once = false
	_report("describe names each method once", once, "")
	_report("list sizes", BossContract.TARGET.size() == TARGET_COUNT and BossContract.MODULE.size() == MODULE_COUNT \
			and BossContract.TARGET_PROPERTIES.size() == PROPERTY_COUNT,
			"%d, %d and %d" % [BossContract.TARGET.size(), BossContract.MODULE.size(), BossContract.TARGET_PROPERTIES.size()])

	print("boss_contract_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)
