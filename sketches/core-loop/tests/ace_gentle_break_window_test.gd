extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")

# A Warden break asked in the last moments before the non-looping drop stems end must
# enter on the drop's end, never a bar later: the stems would run out into silence.
# Gentle's break join is longer than the follower's, which is what opened that window.

const ASKED_BEFORE_END := 1500
const BLOCK := 4410


func _initialize() -> void:
	var probe := Ace.new()
	if not probe.missing.is_empty():
		print("[ace break window] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		quit(0)
		return

	var failures := 0
	for style in ["raw", "hard", "gentle"]:
		failures += _check(style)
	if failures > 0:
		printerr("ace break window: %d failure(s)" % failures)
		quit(1)
		return
	print("ace break window: ok")
	quit(0)


func _check(style: String) -> int:
	var seq := Ace.new()
	seq.set_breath(style)
	seq.start_level(0)
	seq.commit_warden()
	_render_to(seq, 400000)
	seq.drop_now()
	var guard := 0
	while (seq.section != "drop" or seq.pending.is_empty()) and guard < 400:
		seq.render(BLOCK)
		guard += 1
	if seq.pending.is_empty():
		printerr("FAIL %s: the drop never scheduled a follower" % style)
		return 1
	var end: int = seq.pending["at"]
	_render_to(seq, end - ASKED_BEFORE_END)
	seq.warden_broken()
	_render_to(seq, end + 2 * seq.grid_bar)
	var entered := -1
	for e in seq.events_log:
		if e[0] == "enter" and e[2] == "break" and int(e[1]) >= end - ASKED_BEFORE_END:
			entered = int(e[1])
			break
	var failures := 0
	if seq.misses > 0:
		failures += 1
		printerr("FAIL %s: %d stems ran out with nothing scheduled (silence); break entered at %d, drop ends at %d" % [style, seq.misses, entered, end])
	if entered < 0 or entered > end:
		failures += 1
		printerr("FAIL %s: break entered at %d, want at or before the drop's end %d" % [style, entered, end])
	return failures


func _render_to(seq: Ace, sample: int) -> void:
	while seq.clock < sample:
		seq.render(mini(BLOCK, sample - seq.clock))
