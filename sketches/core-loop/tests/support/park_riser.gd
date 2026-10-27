extends RefCounted

const MusicRows := preload("res://src/presentation/music_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")


# The [at, end] of each riser piece the engine logs for a warning of `lead` frames from `start`.
# A stage with a rendered riser plays synth cells over lead minus the file, then the file, which
# ends on the landing; a stage without one spreads the synth cells over the whole lead.
static func pieces(id: String, options: Dictionary, lead: int, start: int) -> Array:
	var row := MusicRows.cue(id, options)
	var synth := MusicRows.synth_cue(id, options)
	var count: int = synth.notes.size()
	var out := []
	var before := lead
	var file_length := 0
	if row.get("stinger", false):
		file_length = SfxBank.file_samples(row.sound).size()
		before = lead - file_length
	if before > 0:
		for cell in count:
			out.append([start + roundi(float(before) * cell / count), start + roundi(float(before) * (cell + 1) / count)])
	if file_length > 0:
		out.append([start + maxi(0, before), start + lead])
	return out


static func options(audio) -> Dictionary:
	var zone: String = MusicRows.zone_id(audio._stage_now, audio._music_stages()) if audio._stage_now > 0 else ""
	return {"theme": audio.engine.theme, "stage": zone}


static func starts(id: String, options: Dictionary, lead: int, start: int) -> Array:
	return pieces(id, options, lead, start).map(func(p): return p[0])


# The cue id a park_dam event row names for `key` ("telegraph" or "land"), so a test follows the
# row's own sound rather than a family id it once shared.
static func dam_cue(event_id: String, key: String) -> String:
	var park = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/park_dam.json"))
	for row in park.event_rows:
		if row.id == event_id:
			return row.music_cue[key]
	return ""
