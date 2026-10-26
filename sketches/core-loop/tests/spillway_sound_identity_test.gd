extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const SpillwayStory := preload("res://src/presentation/spillway_story.gd")
const T := preload("res://tests/support/t.gd")

# World 1 unit 18, "Spillway sound identity". Rules:
#   events   every dam and flume event's land cue resolves to an id only world 1 plays (not the
#            shared family drops the Dig and the Highdraft use) and has a designed file in its own
#            zone (1_1 dam, 1_2 flume); a telegraph is a shared family riser or the dam siren
#   count    the dam and flume parks together name 12 or more distinct sounds after alias chains
#            (the intent scorecard's "Distinct event sounds")
#   stings   each spillway_story row has a sting file; starting the row plays it once on the cue
#            log as kind story_sting, and the moment's generic bus sound is ducked, not doubled
# Evidence limit: files, rows and the cue log; how the sounds read in play is the sitting's ear.

const PARKS := {"park_dam": "1_1", "park_flume": "1_2"}
# The family drops other worlds play, by the id _resolve returns. dome_lightning keeps stinger_lightning
# on purpose (unit 18 spec), so a land cue in KEPT passes check 02 and counts only in the union.
const SHARED := ["drop_flood", "drop_fleet", "drop_ancient", "drop_industrial", "drop_collapse", "stinger_lightning"]
const KEPT := ["stinger_lightning"]
const RISERS := ["riser_natural", "riser_fleet", "riser_ancient", "riser_industrial", "riser_dam_siren"]
# The scorecard counts every distinct id after aliases, shared risers and the kept lightning included:
# dam 11 + flume 10 gives 14 together. The own-land floor counts only ids no other world plays.
const MIN_DISTINCT := 14
const MIN_OWN_LANDS := 8
const MIN_SAMPLE_BYTES := 8000

var _t := T.new("spillway_sound_identity_test")


func _initialize() -> void:
	_run()


func _frames(count: int) -> void:
	for i in count:
		await process_frame


func _resolve(id: String) -> String:
	var seen := {}
	while MusicRows.CUES.has(id) and MusicRows.CUES[id].has("alias") and not seen.has(id):
		seen[id] = true
		id = String(MusicRows.CUES[id]["alias"])
	return id


func _events(park: String) -> Array:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://src/world/park/%s.json" % park))
	return parsed["event_rows"] if parsed is Dictionary else []


func _file_bytes(zone: String, cue: String) -> int:
	var file := FileAccess.open("res://assets/audio/stingers/%s/%s.wav" % [zone, cue], FileAccess.READ)
	return file.get_length() if file != null else -1


func _run() -> void:
	var union := {}
	var own_lands := {}
	for park in PARKS:
		var zone: String = PARKS[park]
		var distinct := {}
		var rows := _events(park)
		_t.check("01 %s names event rows" % park, rows.size() >= 6, str(rows.size()))
		for row in rows:
			var cue: Dictionary = row.get("music_cue", {})
			var land := _resolve(String(cue.get("land", "")))
			var telegraph := _resolve(String(cue.get("telegraph", "")))
			distinct[land] = true
			distinct[telegraph] = true
			union[land] = true
			union[telegraph] = true
			_t.check("02 %s %s: land %s is not a shared family drop" % [park, row.id, land], land != "" and (land in KEPT or not land in SHARED), land)
			if not land in SHARED:
				own_lands[land] = true
			_t.check("03 %s %s: land %s is a row with a designed file in %s" % [park, row.id, land, zone],
				MusicRows.CUES.has(land) and not MusicRows.CUES[land].has("alias") and _file_bytes(zone, land) > MIN_SAMPLE_BYTES,
				"%d bytes" % _file_bytes(zone, land))
			_t.check("04 %s %s: telegraph %s is a family riser" % [park, row.id, telegraph], telegraph in RISERS, telegraph)
			var played := MusicRows.cue(land, {"stage": zone.replace("_", "-")})
			_t.check("05 %s %s: the stage plays the zone file, not the synth row" % [park, row.id],
				bool(played.get("stinger", false)) and String(played.sound) == SfxBank.stinger_id(zone, land), str(played.get("sound", "")))
		print("%s distinct event sounds: %d" % [park, distinct.size()])
	_t.check("06 dam and flume together name %d or more distinct sounds" % MIN_DISTINCT, union.size() >= MIN_DISTINCT, "%d: %s" % [union.size(), str(union.keys())])

	_t.check("07 at least %d land ids are world 1's own" % MIN_OWN_LANDS, own_lands.size() >= MIN_OWN_LANDS, str(own_lands.keys()))
	_t.check("08 the dam's boiler is not the Highdraft's drop_boiler", not union.has("drop_boiler") and union.has("drop_spill_boiler"), "")

	for row_id in SpillwayStory.ROWS:
		var sting: String = SpillwayStory.STINGS.get(row_id, "")
		_t.check("10 %s has a sting file in 1_1" % row_id, sting != "" and _file_bytes("1_1", sting) > MIN_SAMPLE_BYTES, "%s %d bytes" % [sting, _file_bytes("1_1", sting)])
	await _stings()
	quit(_t.verdict())


func _stings() -> void:
	var game = Game.new()
	game.test_mode = true
	game.table = "park"
	root.add_child(game)
	while game.flow == null:
		await physics_frame
	game.player.source = Intent.Scripted.new()
	var audio = game.presentation.audio
	var player = game.presentation.flourish
	audio.set_process(false)
	audio.bake_now()
	_t.check("20 the audio director is ready", audio.sound_ready, "")
	for row_id in SpillwayStory.ROWS:
		player.stop_all()
		audio.cue_log.clear()
		player.play(row_id)
		var sound := SfxBank.stinger_id("1_1", SpillwayStory.STINGS[row_id])
		var hits: Array = audio.cue_log.filter(func(entry): return entry[0] == "story_sting")
		_t.check("21 %s starts one sting on the cue log" % row_id, hits.size() == 1 and hits[0][1] == sound and hits[0][2] == "now", str(hits))
	# The generic sound of the same moment is ducked as logged, not just in the helper afterwards.
	# Rivet's cage: the bus fact reaches audio before the story node, so audio defers the generic
	# play a frame and the sting opens the duck window first.
	player.stop_all()
	audio._story_until_ms = 0
	audio.cue_log.clear()
	audio.play("rescue_completed")
	var plain: Array = audio.cue_log.filter(func(entry): return entry[0] == "rescue_completed" and entry[2] == "now")
	_t.check("22 a plain rescue_completed logs its volume", plain.size() == 1, str(plain))
	var plain_db := float(plain[0][5]) if plain.size() == 1 else 0.0
	audio._last_start.clear()
	audio.cue_log.clear()
	game.events.rescue_completed.emit("rivet")
	await process_frame
	await process_frame
	var log: Array = audio.cue_log
	var sting_at := log.find_custom(func(entry): return entry[0] == "story_sting")
	var generic_at := log.find_custom(func(entry): return entry[0] == "rescue_completed" and entry[2] == "now")
	_t.check("23 the sting and the generic rescue sound both log, sting first", sting_at >= 0 and generic_at > sting_at, str(log))
	if generic_at >= 0:
		_t.near("24 the generic rescue sound is logged duck dB below its plain volume", float(log[generic_at][5]), plain_db + audio.STORY_DUCK_DB, 0.01)
	_t.check("25 run_started and stage_entered are ducked too, an unrelated kind is not",
		audio.story_duck_db("run_started") < 0.0 and audio.story_duck_db("stage_entered") < 0.0 and audio.story_duck_db("hit_thwack") == 0.0, "")
	player.stop_all()
	game.free()
	await _frames(2)
