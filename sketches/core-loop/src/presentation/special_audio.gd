extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")


const CAP := 2
const DROP_DB := -3.0


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
	var id := name + "_presence"
	var player := FoleyAudio.player(id, null, SfxBank.loop_stream(id))
	player.name = "SpecialPresence"
	return player
