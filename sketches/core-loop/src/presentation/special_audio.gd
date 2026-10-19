extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")

# The kill-first specials' voices (INTEGRATION.md section 7, item 5). You hear which special
# is near before you see it: <name>_presence loops on the enemy, <name>_tell on the frame of
# its visual tell, <name>_break on death, <name>_spawn on the next beat.
#
# The enemy scripts (foreman.gd, dispatcher.gd, splitter.gd, linker.gd) meet this contract. An enemy spawned with
# kind "foreman", "dispatcher", "splitter" or "linker" is picked up by audio.gd. It may emit
# `special_tell` on the frame its tell shows (or the game calls Audio.special_tell(enemy)), and
# the splitter's break reads SpecialCues.rammed (`rammed_at_ground` or its `split` meta). `died` ends it.

const CAP := 2
# The drop answer's gain on top of the spawn cue's own trim (sfx_bank.gd, -6 dB).
const DROP_DB := -3.0
const PRESENCE_DB := -14.0
const PRESENCE_UNIT_SIZE := 12.0
const PRESENCE_MAX_DISTANCE := 70.0


static func is_special(kind: String) -> bool:
	return kind in SfxBank.SPECIALS


# The cue for one part of a special. Only the splitter breaks two ways.
static func cue(name: String, part: String, rammed_at_ground := false) -> String:
	# The Dispatcher's drop answer is its rendered spawn cue again (no file of its own).
	if part == "drop":
		return "%s_spawn" % name
	if part == "break" and name == "splitter":
		return "splitter_break_split" if rammed_at_ground else "splitter_break_clean"
	return "%s_%s" % [name, part]


# The ids whose presence loops sound: the cap nearest, nearest first. distances maps id to metres.
static func heard(distances: Dictionary, cap := CAP) -> Array:
	var ids: Array = distances.keys()
	ids.sort_custom(func(a, b): return float(distances[a]) < float(distances[b]) or (float(distances[a]) == float(distances[b]) and str(a) < str(b)))
	return ids.slice(0, maxi(cap, 0))


# Whether an enemy was rammed at ground level when it died. 2026-10-18 (w18 splitter cue): this
# is SpecialCues.rammed itself, so the sound and the machine_fx burst read one fact (the real
# Splitter sets meta "split", not rammed_at_ground); the rammed_at_ground fallback lives there.
static func rammed(enemy: Object) -> bool:
	return SpecialCues.rammed(enemy)


# The looping AudioStreamPlayer3D a special carries. Its own player, so it never takes a voice
# from the polyphonic combat pool. Silent until the director marks it heard.
static func presence_player(name: String) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = "SpecialPresence"
	player.stream = SfxBank.loop_stream(name + "_presence")
	player.bus = "SFX"
	player.volume_db = SfxBank.trim_db(name + "_presence")
	player.unit_size = PRESENCE_UNIT_SIZE
	player.max_distance = PRESENCE_MAX_DISTANCE
	player.autoplay = false
	return player
