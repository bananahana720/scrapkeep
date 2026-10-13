extends SceneTree

const Music := preload("res://src/presentation/music_engine.gd")
const Harmony := preload("res://src/presentation/harmony.gd")
const MusicRows := preload("res://src/presentation/music_rows.gd")
const Synth := preload("res://src/presentation/synth.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("render_park_music_cue: expected CUE OUTPUT.wav [LEAD_S KEY THEME ANCIENT MOTIF BAND]")
		quit(2)
		return
	var id: String = args[0]
	var lead_s := float(args[2]) if args.size() > 2 else 6.0
	var key := int(args[3]) if args.size() > 3 else 3
	var theme := int(args[4]) if args.size() > 4 else 0
	var options := {"theme": theme, "ancient": args[5] if args.size() > 5 else "reactor", "motif": args[6] if args.size() > 6 else "sable"}
	var band: bool = args.size() > 7 and args[7] == "band"
	var row := MusicRows.cue(id, options)
	if row.is_empty() or lead_s <= 0.0:
		push_error("render_park_music_cue: unknown cue or invalid lead")
		quit(2)
		return
	var engine := Music.new()
	engine.key = key
	engine.theme = theme
	engine.band_muted = not band
	var lead := roundi(lead_s * Harmony.RATE)
	var kind := "event_announced" if row.rise else "event_started"
	engine.park_cue(id, lead if row.rise else 0, 0, options, Audio.PRIORITY_DB[Rows.priority(kind)])
	var total := lead + Harmony.BEAT if row.rise else Harmony.BAR * 3
	var pcm := PackedFloat32Array()
	while pcm.size() < total:
		var frames := mini(4096, total - pcm.size())
		engine.render(frames)
		for i in frames:
			var stereo: Vector2 = engine.out_stinger[i]
			if band:
				stereo += engine.out_music[i]
			pcm.append((stereo.x + stereo.y) * 0.5)
	var error := Synth.to_wav(pcm).save_to_wav(args[1])
	print("render_park_music_cue: %s cue=%s frames=%d key=%d theme=%d voices=%d output=%s" % ["PASS" if error == OK else "FAIL", id, pcm.size(), key, theme, engine.park_cue_log.size(), args[1]])
	quit(0 if error == OK else 1)
