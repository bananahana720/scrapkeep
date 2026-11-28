extends RefCounted

const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")


func _gd_files(root_dir: String, out: Array[String]) -> void:
	var dir := DirAccess.open(root_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := root_dir.path_join(entry)
			if dir.current_is_dir():
				_gd_files(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()


func run(t) -> void:
	var files: Array[String] = []
	_gd_files("res://src", files)
	_gd_files("res://tools", files)
	files.sort()

	var global_patterns := [
		["audio private reach", "(?:\\b|_)audio\\._(?:admit|start|flush_flow|music_pb|finish_opening|rest_task|on_node_added)\\b"],
		["music_engine private reach", "\\bengine\\._(?:bar_step|parameter_phrase_due|cadence_bar|floor|add_action)\\b"],
		["ace_sequencer private reach", "\\bace\\._parameter_danger_floor\\b"],
		["sfx_bank private reach", "\\bSfxBank\\._(?:said|motif_score)\\b"],
	]
	var presentation_patterns := [
		["event_director private park reach from presentation", "(?:\\bdirector|_park_director\\(\\))\\._park_"],
		["ultimate private beat reach from presentation", "\\bult\\._beat\\b"],
	]

	var global_hits: Array[String] = []
	var presentation_hits: Array[String] = []
	for path in files:
		var text := FileAccess.get_file_as_string(path)
		for row in global_patterns:
			var re := RegEx.new()
			re.compile(row[1])
			if re.search(text) != null:
				global_hits.append("%s (%s)" % [path, row[0]])
		if path.begins_with("res://src/presentation/"):
			for row in presentation_patterns:
				var re := RegEx.new()
				re.compile(row[1])
				if re.search(text) != null:
					presentation_hits.append("%s (%s)" % [path, row[0]])

	t.eq("src and tools have no closed sound underscore reach-ins", global_hits, [])
	t.eq("src/presentation has no event_director._park_ or ult._beat reach-ins", presentation_hits, [])

	var natural := FileAccess.get_file_as_string("res://src/world/events/natural.gd")
	var natural_bad: Array[String] = []
	for needle in [
		"res://src/presentation/audio.gd",
		"res://src/presentation/sfx_bank.gd",
		"res://src/presentation/rows.gd",
		"res://src/presentation/harmony.gd",
		"get_signal_connection_list(\"world_fact\")",
	]:
		if natural.contains(needle):
			natural_bad.append(needle)
	t.eq("natural.gd drops audio preloads and world_fact hijack", natural_bad, [])

	var ending := FileAccess.get_file_as_string("res://src/ui/ending_sequence.gd")
	t.check(
		"ending_sequence.gd uses play_ending_summary without touching audio.engine",
		ending.contains("audio.play_ending_summary()") and not ending.contains("audio.engine.menu_theme"),
	)

	t.eq("VoiceSynth.parse_said splits speaker and text", VoiceSynth.parse_said("say|sable|line|two"), ["sable", "line|two"])
	t.eq("VoiceSynth.parse_said handles missing text", VoiceSynth.parse_said("say|sable"), ["sable", ""])
	var method_names := (SfxBank as GDScript).get_script_method_list().map(func(m): return m["name"])
	var voice_methods := (VoiceSynth as GDScript).get_script_method_list().map(func(m): return m["name"])
	t.check(
		"SfxBank promotes motif_score and VoiceSynth owns parse_said without forwarding copies",
		method_names.has("motif_score") and not method_names.has("_motif_score") and not method_names.has("_said") and not method_names.has("parse_said")
		and voice_methods.has("parse_said") and not voice_methods.has("_said"),
	)

	var bus_index_allowed := [
		"res://src/presentation/mix_rows.gd",
		"res://src/presentation/audio.gd",
		"res://src/presentation/music_dsp.gd",
		"res://src/presentation/craft/craft_audio_cues.gd",
	]
	var bus_const_allowed := ["res://src/presentation/mix_rows.gd"]
	var ace_root_allowed := ["res://src/presentation/music_rows.gd"]
	var bus_const_re := RegEx.new()
	bus_const_re.compile("(?m)^[ \\t]*const\\s+[A-Za-z0-9_]+\\s*(?::\\s*(?:String|StringName)\\s*)?:?=\\s*&?[\"'](?:Master|Music|SFX|UI|Ambient|StingerMusic)[\"']")

	var src_files: Array[String] = []
	_gd_files("res://src", src_files)
	src_files.sort()

	var bus_index_hits: Array[String] = []
	var bus_const_hits: Array[String] = []
	var ace_root_hits: Array[String] = []
	for path in src_files:
		var text := FileAccess.get_file_as_string(path)
		if text.contains("AudioServer.get_bus_index(") and not bus_index_allowed.has(path):
			bus_index_hits.append(path)
		if bus_const_re.search(text) != null and not bus_const_allowed.has(path):
			bus_const_hits.append(path)
		if text.contains("res://assets/music_ace/") and not ace_root_allowed.has(path):
			ace_root_hits.append(path)

	t.eq("src has no unapproved AudioServer.get_bus_index calls", bus_index_hits, [])
	t.eq("src declares bus name constants only in mix_rows.gd", bus_const_hits, [])
	t.eq("src writes res://assets/music_ace/ only in music_rows.gd", ace_root_hits, [])

	var audio_src := FileAccess.get_file_as_string("res://src/presentation/audio.gd")
	t.check("audio.gd does not preload unused park_graph.gd", not audio_src.contains("res://src/world/park/park_graph.gd"))
