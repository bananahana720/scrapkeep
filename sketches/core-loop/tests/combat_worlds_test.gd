extends SceneTree

const TwoWorld := preload("res://tests/doubles/two_world_defs.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")
const Roster := preload("res://src/combat/roster.gd")
const T := preload("res://tests/support/t.gd")

# Stages past three take the Warden family their row names (W4), and a boss piece is
# known from the Worlds.BOSSES table:
# - on the six-stage double, the stage-4 Warden is a reactor and the stage-5 one a hive,
#   where the positional clamp would give the Mind for both;
# - brindle_hull, waking_core and mind_lens class as boss and are not ordinary reactions;
#   chaser and warden are neither;
# - a row with no warden_family falls back to the roster and warns once per stage.

class TwoWorldGame extends "res://src/game.gd":
	func _chosen_table():
		return TwoWorld

# A table whose rows name no family, so warden_spec falls back to the roster.
class BareTable extends RefCounted:
	func of(_stage: int) -> Dictionary:
		return {"warden_plating": 10.0, "warden_hp": 100.0, "warden_lesson": "plate"}

var _t := T.new("combat_worlds_test")
var _game
var _step := 0
var _ticks := 0


func _initialize() -> void:
	_game = TwoWorldGame.new()
	_game.test_mode = true
	root.add_child(_game)
	_rows()


func _rows() -> void:
	for table in [StageDefs, SliceDefs, TwoWorld]:
		for row in table.DEFS:
			_t.check("row %d names a family" % row["stage"], row.has("warden_family") and row["warden_family"] in Roster.WARDEN_FAMILIES,
				"%s stage %d: %s" % [table.resource_path.get_file(), row["stage"], row.get("warden_family", "none")])


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_ticks += 1
	match _step:
		0:
			_game.ctx.calm = true
			_game.flow.force_warden = true
			_game.flow.press_start()
			_game.flow.choose_class(0)
			_step = 1
		1:
			_enter_and_read(4, "reactor")
			_enter_and_read(5, "swarm")
			_enter_and_read(6, "mind")
			_pieces()
			_fallback()
			quit(_t.verdict())
			return true
	return false


func _enter_and_read(stage: int, want: String) -> void:
	_game.flow.enter_stage(stage, Vector3.ZERO, false)
	var warden = _game.flow.warden
	_t.check("stage %d Warden" % stage, warden != null and warden.family == want,
		"stage %d Warden family %s, want %s (the clamp gives %s)" % [stage, warden.family if warden else "none", want, Roster.warden_family(stage)])


func _pieces() -> void:
	var combat = _game.ctx.spawner
	for kind in ["brindle_hull", "waking_core", "mind_lens"]:
		_t.eq("%s classes as boss" % kind, combat._target_class_of_kind(kind), "boss")
		_t.check("%s is a boss piece" % kind, Roster.is_boss_piece(kind), kind)
	for kind in ["chaser", "warden", "mind", "brindle"]:
		_t.check("%s is not a boss piece" % kind, not Roster.is_boss_piece(kind), kind)
		_t.check("%s does not class as boss" % kind, combat._target_class_of_kind(kind) != "boss", kind)
	var claimed: Array = []
	for kind in Roster.ROWS:
		if Roster.is_boss_piece(kind) or combat._target_class_of_kind(kind) == "boss":
			claimed.append(kind)
	_t.check("no roster enemy kind reads as a boss piece", claimed.is_empty(), "claimed %s" % [claimed])
	# Every roster kind that lands in "adds" is a named one, so _target_class_of_kind never
	# warns for it (the stage 4 dry run warned on drill_crew, a world 2 kind, 23 Oct).
	var unnamed: Array = []
	for kind in Roster.ROWS:
		if combat._target_class_of_kind(kind) == "adds" and not (Roster.is_reinforcement(kind)
				or Roster.row(kind).has("priority") or Roster.is_world_kind(kind)):
			unnamed.append(kind)
	_t.check("every roster kind classed as adds is a reinforcement, special spawn or world kind", unnamed.is_empty(), "unnamed %s" % [unnamed])
	for kind in ["drill_crew", "boom_tender", "jolt_layer"]:
		_t.check("%s is a world kind" % kind, Roster.is_world_kind(kind), kind)
	var hand = load("res://src/combat/enemy.gd").new()
	hand.kind = "mind_hand"
	_t.check("mind_hand is an ordinary reaction", hand._ordinary_reaction(), "mind_hand")
	hand.free()
	var Enemy := load("res://src/combat/enemy.gd")
	for kind in ["brindle_hull", "waking_core", "mind_lens", "warden"]:
		var e = Enemy.new()
		e.kind = kind
		_t.check("%s is not an ordinary reaction" % kind, not e._ordinary_reaction(), kind)
		e.free()
	var chaser = Enemy.new()
	chaser.kind = "chaser"
	_t.check("chaser is an ordinary reaction", chaser._ordinary_reaction(), "chaser")
	chaser.free()


func _fallback() -> void:
	var combat = _game.ctx.spawner
	combat.stage_defs = BareTable.new()
	_t.eq("a bare row at stage 2 falls back to the roster", combat.warden_spec(2)["family"], Roster.warden_family(2))
	_t.eq("a stage the double's rows cover warned nothing", combat._warden_warned.size(), 0)
	_t.eq("a bare row at stage 8 clamps to the last family", combat.warden_spec(8)["family"], Roster.warden_family(8))
	combat.warden_spec(8)
	_t.eq("stage 8 warned for itself, once", combat._warden_warned.keys(), [8])
	combat.stage_defs = null
