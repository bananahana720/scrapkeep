extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")

# Between start_level and the first commit the section is empty, but the calm that is
# about to enter already owns the grid: a beat or bar asked in that window lands on it,
# never on the render head.


func _initialize() -> void:
	var probe := Ace.new()
	if not probe.missing.is_empty():
		print("[ace stage window grid] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		quit(0)
		return

	var seq := Ace.new()
	var at := 40000
	seq.start_level(at)
	seq.advance(1234)
	var clip: Dictionary = seq.clips[seq.sections[String(seq.pending["section"])]["clip"]]
	var calm_at: int = seq.pending["at"]
	var failures := 0
	for pair in [["beat", seq.next_beat(), int(clip["beat"])], ["bar", seq.next_bar(), int(clip["bar"])]]:
		var asked: int = pair[1]
		if asked < seq.clock or posmod(calm_at - asked, int(pair[2])) != 0:
			failures += 1
			printerr("FAIL next_%s in the start_level window: asked %d at clock %d, calm enters at %d on a %d-frame grid" % [pair[0], asked, seq.clock, calm_at, pair[2]])
	if failures > 0:
		printerr("ace stage window grid: %d failure(s)" % failures)
		quit(1)
		return
	print("ace stage window grid: ok")
	quit(0)
