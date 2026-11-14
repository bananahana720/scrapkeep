class_name ModelVariants
extends RefCounted

# Chooses between an authored model and its Tripo-generated sibling, so the generated set can be
# judged in the game beside the authored one without replacing a file. The sibling sits next to
# the authored GLB as `<stem>_tripo.glb` (made by tools/tripo/, receipts in its README). Off unless
# the game is launched with --models=tripo; a model with no sibling stays authored.
#
# Each sibling is accepted or rejected on its own (ruling dr): --models=tripo loads only the accepted
# ones, so one weak model cannot sink the set. REJECTED lists the rejected siblings by their own path
# with the reason; each one's registry row (assets/registry.d) says "accepted": false with the same
# reason, and tests/tripo_variants_test.gd holds the two together. --models=tripo-all loads every
# sibling, rejected ones too, for judging them in the game.

const SUFFIX := "_tripo"
const FLAG := "--models=tripo"
const FLAG_ALL := "--models=tripo-all"
const REJECTED := {
	"res://assets/models/world_one/enemy_chaser_tripo.glb": "far side 0.54 of the authored brightness, loose black faces (render check, 14 November 2026)",
	"res://assets/models/world_one/enemy_hooker_tripo.glb": "renders near-black beside the authored barrel (PC looks of PRs 1022 and 1024)",
	"res://assets/models/world_one/enemy_netcaster_tripo.glb": "torso renders near-black beside the authored one (render check, 14 November 2026)",
	"res://assets/models/park/props/flume/sluice_shed_a_tripo.glb": "loses the big red water wheel, the authored landmark shape (PC look of PR 1024)",
	"res://assets/models/park/props/flume/sluice_shed_a_lod1_tripo.glb": "loses the big red water wheel, the authored landmark shape (PC look of PR 1024)",
	"res://assets/models/park/props/flume/sluice_shed_a_lod2_tripo.glb": "loses the big red water wheel, the authored landmark shape (PC look of PR 1024)",
}

static var _on := -1
static var _rejected: Dictionary = REJECTED
static var _stamp := 0


# The path to load for `authored`: its Tripo sibling when the switch is on and the sibling exists.
static func path(authored: String) -> String:
	if not enabled():
		return authored
	var alt := authored.get_basename() + SUFFIX + "." + authored.get_extension()
	return alt if accepted(alt) and ResourceLoader.exists(alt) else authored


# A Tripo model that has no authored file to sit beside (a ball part's own shape): `tripo_path`
# when the switch is on and the file exists, else "" and the caller draws what it always drew.
static func only(tripo_path: String) -> String:
	return tripo_path if enabled() and accepted(tripo_path) and ResourceLoader.exists(tripo_path) else ""


# Whether the switch may load this sibling: every sibling under --models=tripo-all, else the ones not in REJECTED.
static func accepted(tripo_path: String) -> bool:
	return _on == 2 or not _rejected.has(tripo_path)


static func enabled() -> bool:
	if _on < 0:
		var args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
		_on = 2 if FLAG_ALL in args else (1 if FLAG in args else 0)
	return _on >= 1


# Changes each time a test or tool changes the switch or the rejected list, so a caller that keeps answers
# from path() knows when to drop them. In a game run it never changes.
static func stamp() -> int:
	return _stamp


# Tests and tools set the switch directly instead of through the command line.
static func set_enabled(on: bool, all := false) -> void:
	_on = (2 if all else 1) if on else 0
	_stamp += 1


# Tests swap the rejected list to prove a rejected sibling stays out; no argument restores REJECTED.
static func set_rejected(rejected: Dictionary = REJECTED) -> void:
	_rejected = rejected
	_stamp += 1
