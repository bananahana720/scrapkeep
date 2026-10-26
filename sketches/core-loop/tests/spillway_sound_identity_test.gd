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
const SHARED := ["drop_flood", "drop_fleet", "drop_ancient", "drop_industrial", "drop_collapse", "drop_natural", "drop_lightning"]
const RISERS := ["riser_natural", "riser_fleet", "riser_ancient", "riser_industrial", "riser_dam_siren"]
const MIN_DISTINCT := 12
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
			_t.check("02 %s %s: land %s is not a shared family drop" % [park, row.id, land], land != "" and not land in SHARED, land)
			_t.check("03 %s %s: land %s is a row with a designed file in %s" % [park, row.id, land, zone],
				MusicRows.CUES.has(land) and not MusicRows.CUES[land].has("alias") and _file_bytes(zone, land) > MIN_SAMPLE_BYTES,
				"%d bytes" % _file_bytes(zone, land))
			_t.check("04 %s %s: telegraph %s is a family riser" % [park, row.id, telegraph], telegraph in RISERS, telegraph)
			var played := MusicRows.cue(land, {"stage": zone.replace("_", "-")})
			_t.check("05 %s %s: the stage plays the zone file, not the synth row" % [park, row.id],
				bool(played.get("stinger", false)) and String(played.sound) == SfxBank.stinger_id(zone, land), str(played.get("sound", "")))
		print("%s distinct event sounds: %d" % [park, distinct.size()])
	_t.check("06 dam and flume together name %d or more distinct sounds" % MIN_DISTINCT, union.size() >= MIN_DISTINCT, "%d: %s" % [union.size(), str(union.keys())])

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
	# The generic sound of the same moment is ducked while the sting holds it.
	player.stop_all()
	_t.check("22 a generic stage sound takes the duck while a sting holds the moment", audio.story_duck_db("stage_entered") < 0.0, str(audio.story_duck_db("stage_entered")))
	_t.check("23 a kind outside the moment is not ducked", audio.story_duck_db("hit_thwack") == 0.0, "")
	game.free()
	await _frames(2)
