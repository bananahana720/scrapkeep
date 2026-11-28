extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")


const CAP := 2
const DROP_DB := -3.0
const PRESENCE_UNIT_SIZE := 12.0
const PRESENCE_MAX_DISTANCE := 70.0


static func is_special(kind: String) -> bool:
	return kind in SfxBank.SPECIALS


static func cue(name: String, part: String, rammed_at_ground := false) -> String:
	if part == "drop":
		return "%s_spawn" % name
	if part == "break" and name == "splitter":
		return "splitter_break_split" if rammed_at_ground else "splitter_break_clean"
	return "%s_%s" % [name, part]


static func heard(distances: Dictionary, cap := CAP) -> Array:
	var ids: Array = distances.keys()
	ids.sort_custom(func(a, b): return float(distances[a]) < float(distances[b]) or (float(distances[a]) == float(distances[b]) and str(a) < str(b)))
	return ids.slice(0, maxi(cap, 0))


static func rammed(enemy: Object) -> bool:
	return SpecialCues.rammed(enemy)


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
