class_name ModelVariants
extends RefCounted

# Chooses between an authored model and its Tripo-generated sibling, so the generated set can be
# judged in the game beside the authored one without replacing a file. The sibling sits next to
# the authored GLB as `<stem>_tripo.glb` (made by tools/tripo/, receipts in its README). Off unless
# the game is launched with --models=tripo; a model with no sibling stays authored.

const SUFFIX := "_tripo"
const FLAG := "--models=tripo"

static var _on := -1


# The path to load for `authored`: its Tripo sibling when the switch is on and the sibling exists.
static func path(authored: String) -> String:
	if not enabled():
		return authored
	var alt := authored.get_basename() + SUFFIX + "." + authored.get_extension()
	return alt if ResourceLoader.exists(alt) else authored


static func enabled() -> bool:
	if _on < 0:
		_on = 1 if (FLAG in OS.get_cmdline_args() or FLAG in OS.get_cmdline_user_args()) else 0
	return _on == 1


# Tests and tools set the switch directly instead of through the command line.
static func set_enabled(on: bool) -> void:
	_on = 1 if on else 0
