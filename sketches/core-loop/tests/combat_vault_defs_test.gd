extends SceneTree

const Game := preload("res://src/game.gd")
const StageDefs := preload("res://src/core/stage_defs.gd")

# A vault is plated at the next stage's Warden, read from StageDefs.of(stage + 1), so a
# tuning edit to stage_defs moves the vault with it. The lookup here is StageDefs with
# the stage-2 def duplicated and its warden_plating edited to 77; a stage-1 vault must
# read 77. A second def with the field removed falls back to the spec's 60.

const EDITED := 77.0


class Defs:
	var edited: Dictionary

	func of(stage: int) -> Dictionary:
		return edited if stage == 2 else StageDefs.of(stage)


var _game
var _combat
var _failures := 0


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)


func _report(check: String, ok: bool, detail: String) -> void:
	print("[%s] %s -> %s" % [check, detail, "PASS" if ok else "FAIL"])
	if not ok:
		_failures += 1


func _physics_process(_delta: float) -> bool:
	if _game.flow == null:
		return false
	_combat = _game.ctx.spawner
	_game.ctx.calm = true
	_game.flow.press_start()
	_game.flow.choose_class(1)
	var defs := Defs.new()
	defs.edited = StageDefs.of(2).duplicate()
	defs.edited["warden_plating"] = EDITED
	_combat.set("stage_defs", defs)
	var edited: float = _vault_plating()
	_report("edited", edited == EDITED,
		"stage 1 vault with stage 2's warden_plating edited to %.0f reads %.0f" % [EDITED, edited])
	defs.edited = StageDefs.of(2).duplicate()
	defs.edited.erase("warden_plating")
	var missing: float = _vault_plating()
	_report("fallback", missing == 60.0,
		"with the field missing the vault falls back to the spec's 60: reads %.0f" % missing)
	var ok := _failures == 0
	print("combat_vault_defs_test: %s" % ("PASS" if ok else "FAIL"))
	_game.free()
	quit(0 if ok else 1)
	return true


func _vault_plating() -> float:
	var ctx = _game.ctx
	var at: Vector3 = ctx.terrain.spawn_point(1) + Vector3(20.0, 0.0, 40.0)
	var vault: Node3D = ctx.spawner.spawn_enemy("vault", at)
	var plating: float = vault.plating
	vault.free()
	return plating
