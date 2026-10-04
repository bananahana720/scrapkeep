extends "res://src/boss/stub_boss.gd"

const Worlds := preload("res://src/core/worlds.gd")

# The Mind's module. Until its own fight lands it runs the stub's posture Warden on a flat
# pad; it differs only in reading its own Worlds.BOSSES row for the plate name, the
# objective text and the music id.
const BOSS_ID := "mind"


func setup(ctx_ref) -> void:
	super(ctx_ref)
	name = "MindBoss"


func _row() -> Dictionary:
	return Worlds.BOSSES[BOSS_ID]


func music_state() -> Dictionary:
	var state := super()
	if not state.is_empty():
		state["id"] = String(_row().get("music", BOSS_ID))
	return state
