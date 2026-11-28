extends SceneTree

# The Dig and Highdraft events' foley (foley_audio.gd, files from PR #12), loaded only if
# present:
# - with a file, its stream loads (the presence one loops); without one, it is null and
#   nothing plays, so the events run silent on their row sounds;
# - a rubble fall starts its warn sound when it commits and its land sound land_lead before
#   it lands, each as a one-shot beside the fall.
# Passes with or without the files; it prints which.

const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const RubbleFall := preload("res://src/world/events/rubble_fall.gd")
const WarningGap := preload("res://src/world/events/warning_gap.gd")
const Cues := preload("res://src/presentation/positional_cue_rows.gd")
const T := preload("res://tests/support/t.gd")
const IDS := ["lift_cage_arrive", "zipline_whine", "zipline_snap", "cave_in_rumble", "cave_in_debris", "prop_crew_presence",
	"prop_crew_strain", "prop_crew_collapse"]

var t := T.new("foley_audio_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var present := 0
	for id in IDS:
		var has_file := ResourceLoader.exists(Cues.DIR + Cues.ROWS[id]["file"]) or FileAccess.file_exists(Cues.DIR + Cues.ROWS[id]["file"])
		var s := FoleyAudio.stream(id)
		if has_file:
			present += 1
			t.check(id + " loads", s != null and s.data.size() > 0)
			if Cues.ROWS[id].get("loop", false) and s != null:
				t.check(id + " loops", s.loop_mode == AudioStreamWAV.LOOP_FORWARD)
		else:
			t.check(id + " is silent with no file", s == null)
	print("foley files present: %d of %d" % [present, IDS.size()])

	var host := Node3D.new()
	root.add_child(host)
	root.remove_meta(WarningGap.LAST_META)
	var fall = RubbleFall.new()
	fall.configure("foley_probe", Vector3.ZERO, 3.0, 1.0, null, null, Callable())
	fall.warn_sound = "cave_in_rumble"
	fall.land_sound = "cave_in_debris"
	fall.land_lead = 0.3
	host.add_child(fall)
	var heard := []
	var at_land := -1.0
	for frame in 150:
		await physics_frame
		for node in host.find_children("Foley_*", "AudioStreamPlayer3D", true, false):
			if not String(node.name) in heard:
				heard.append(String(node.name))
				if String(node.name) == "Foley_cave_in_debris" and fall.committed():
					at_land = fall.hazard.warn_seconds - fall.hazard.age
	var want := []
	for id in ["cave_in_rumble", "cave_in_debris"]:
		if FoleyAudio.stream(id) != null:
			want.append("Foley_" + id)
	t.eq("the fall plays the sounds whose files exist", heard, want)
	if want.has("Foley_cave_in_debris"):
		t.check("the land sound starts land_lead before the landing", absf(at_land - 0.3) <= 1.5 / 90.0, "%.3f s before" % at_land)
	host.free()
	# A freed player's playback leaves the AudioServer only after its mix thread runs and the
	# main loop collects it; quitting first leaks the stream. Step frames until no playback
	# holds a foley stream (the cache's own reference and this loop's are all that remain).
	for frame in 20000:
		var held := false
		for id in IDS:
			var s := FoleyAudio.stream(id)
			if s != null and s.get_reference_count() > 2:
				held = true
		if not held:
			break
		await process_frame
	quit(t.verdict())
