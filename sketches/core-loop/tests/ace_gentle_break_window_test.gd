extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

# A Warden break asked in the last moments before the non-looping drop stems end must
# enter on the drop's end, never a bar later: the stems would run out into silence.
# Gentle's break join is longer than the follower's, which is what opened that window.

const ASKED_BEFORE_END := 1500
const BLOCK := 4410

var _t := T.new("ace_gentle_break_window_test")


func _initialize() -> void:
	var probe := Ace.new()
	if not probe.missing.is_empty():
		print("[ace break window] %s is missing; run tools/ace/package_music.py -> SKIP" % probe.missing)
		quit(0)
		return

	for style in ["raw", "hard", "gentle"]:
		_check(style)
	quit(_t.verdict())


func _check(style: String) -> void:
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
	if not _t.check("%s drop schedules a follower" % style, not seq.pending.is_empty(), "pending %s" % [seq.pending]):
		return
	var end: int = seq.pending["at"]
	_render_to(seq, end - ASKED_BEFORE_END)
	seq.warden_broken()
	_render_to(seq, end + 2 * seq.grid_bar)
	var entered := -1
	for e in seq.events_log:
		if e[0] == "enter" and e[2] == "break" and int(e[1]) >= end - ASKED_BEFORE_END:
			entered = int(e[1])
			break
	_t.check("%s stems never run out" % style, seq.misses == 0, "%d stems ran out with nothing scheduled (silence); break entered at %d, drop ends at %d" % [seq.misses, entered, end])
	_t.check("%s break enters by the drop's end" % style, entered >= 0 and entered <= end, "break entered at %d, want at or before the drop's end %d" % [entered, end])


func _render_to(seq: Ace, sample: int) -> void:
	while seq.clock < sample:
		seq.render(mini(BLOCK, sample - seq.clock))
