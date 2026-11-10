extends Node

# --sitting-notes: the build takes notes while a person plays (ruling cg, Andrew, 9 Nov 2026), so
# a sitting leaves a record that does not depend on what the player remembers. Nothing shows on
# screen and nothing is played back. Without the flag this node is never made.
#
# One file a launch, user://sitting-notes/notes-<UTC start>.ndjson, one JSON row a line. Every row
# has "t" (seconds since the notes started), "utc" and "kind":
#   start      the build's facts: executable, window, refresh rate, physics rate, the hitch limit
#   stuck, hung, wedged, fell, objective, blank, bar   the play watch's rows (src/core/play_watch.gd).
#              A stuck row is also what a person standing still for 8 s in play writes: read it
#              with the place.
#   hitch      frames that each took hitch_ms or longer, one row a burst (frames within BURST_GAP_S
#              of each other, cut every BURST_MAX_S): how many, the worst and the total, where and
#              in which flow state.
#              A frame while the window is not focused is not counted.
#   mark       the player pressed MARK_KEY (F8), or clicked both sticks together on a pad: "look
#              here". Carries the place, the objective plate's words and the frame rate.
#   end        the watch's counts and the marks, with the longest stretches the plate stood empty
#              (blank_max_s) and the hull bar stood off the hull (bar_off_max_s), as the game closes
# Cost: one clock read a frame, the watch's reads a physics tick, the plate read once a second.
# It only reads the game, and each row is closed onto disk as it is written, so a crash keeps them.

const PlayWatch := preload("res://src/core/play_watch.gd")
const SafeStore := preload("res://src/core/safe_store.gd")

const FLAG := "--sitting-notes"
const HITCH_FLAG := "--sitting-notes-hitch="
const DIR := "user://sitting-notes"
const MARK_KEY := KEY_F8
const MARK_PAD := [JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]
# A frame this long or longer is a hitch: three frames lost at 144 Hz, one and a half at 60.
const HITCH_MS := 25.0
const BURST_GAP_S := 0.5
# Slow frames that never let up are written this often, so the row does not wait for them to end.
const BURST_MAX_S := 5.0
const READ_S := 1.0

var game
var dir := DIR
var hitch_ms := HITCH_MS
var path := ""
var marks := 0
var hitches := 0

var _open := false
var _watch
var _start_usec := 0
var _last_usec := -1
var _burst := {}
var _read := 0.0
var _sticks := {}


static func wanted() -> bool:
	return FLAG in OS.get_cmdline_user_args() or FLAG in OS.get_cmdline_args()


func _ready() -> void:
	name = "SittingNotes"
	# Marks and hitches count in a pause and in the workshop too.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(HITCH_FLAG):
			hitch_ms = maxf(float(arg.trim_prefix(HITCH_FLAG)), 1.0)
	DirAccess.make_dir_recursive_absolute(dir)
	var started := Time.get_datetime_string_from_system(true)
	path = dir.path_join("notes-%s.ndjson" % started.replace("-", "").replace(":", ""))
	_start_usec = Time.get_ticks_usec()
	_open = true
	var window := get_window()
	_note({"kind": "start", "exe": OS.get_executable_path().get_file(), "engine": Engine.get_version_info().get("string", ""),
		"window": [window.size.x, window.size.y], "refresh_hz": snappedf(DisplayServer.screen_get_refresh_rate(window.current_screen), 0.1),
		"physics_hz": Engine.physics_ticks_per_second, "interpolation": get_tree().physics_interpolation,
		"hitch_ms": hitch_ms, "mark_key": OS.get_keycode_string(MARK_KEY)})
	if not _open:
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	_watch = PlayWatch.new()
	_watch.watch(game, _note)
	print("SCRAPKEEP_SITTING_NOTES %s" % ProjectSettings.globalize_path(path))


func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		_watch.step(delta)


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	if _last_usec >= 0 and get_window().has_focus():
		frame((now - _last_usec) / 1000.0, (now - _start_usec) / 1000000.0)
	_last_usec = now
	if get_tree().paused:
		return
	_read += delta
	if _read >= READ_S:
		_watch.read_text(_read)
		_read = 0.0


# One frame's length, at at_s seconds since the notes started. A hitch opens or joins a burst;
# a burst is written once BURST_GAP_S has passed without another.
func frame(ms: float, at_s: float) -> void:
	if not _burst.is_empty() and at_s - float(_burst["last"]) > BURST_GAP_S:
		_close_burst()
	if ms < hitch_ms:
		return
	if _burst.is_empty():
		_burst = _where()
		_burst.merge({"t": snappedf(at_s, 0.01), "frames": 0, "worst_ms": 0.0, "total_ms": 0.0})
	_burst["frames"] = int(_burst["frames"]) + 1
	_burst["worst_ms"] = maxf(float(_burst["worst_ms"]), snappedf(ms, 0.1))
	_burst["total_ms"] = snappedf(float(_burst["total_ms"]) + ms, 0.1)
	_burst["last"] = at_s
	if at_s - float(_burst["t"]) >= BURST_MAX_S:
		_close_burst()


func _close_burst() -> void:
	if _burst.is_empty():
		return
	var row := {"kind": "hitch"}
	row.merge(_burst)
	row.erase("last")
	_burst = {}
	hitches += 1
	_note(row)


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo and event.physical_keycode == MARK_KEY:
			mark()
	elif event is InputEventJoypadButton and event.button_index in MARK_PAD:
		var both_before := _sticks.size() == MARK_PAD.size()
		if event.pressed:
			_sticks[event.button_index] = true
		else:
			_sticks.erase(event.button_index)
		if _sticks.size() == MARK_PAD.size() and not both_before:
			mark()


# "Look here": the player wants this moment read afterwards.
func mark() -> void:
	marks += 1
	var row := {"kind": "mark", "n": marks}
	row.merge(_where())
	if game != null and game.hud != null and game.flow != null and game.flow.in_play():
		row["words"] = String(game.hud.objective_reading().get("words", ""))
	row["fps"] = Engine.get_frames_per_second()
	_note(row)


# Where the game is now: the stage, its clock, the ball and the flow state. Empty before a run.
func _where() -> Dictionary:
	if game == null or game.flow == null:
		return {}
	var out := {"flow": game.flow.state_name()}
	if game.run != null and game.player != null and game.flow.in_play():
		var at: Vector3 = game.player.ball_position()
		out.merge({"stage": game.run.stage, "s": snappedf(game.run.stage_time, 0.1), "at": PlayWatch._v(at)})
	return out


# Every row goes through here: the watch's rows keep their own fields and gain the two clocks.
func _note(row: Dictionary) -> void:
	if not _open:
		return
	var out := {"t": snappedf((Time.get_ticks_usec() - _start_usec) / 1000000.0, 0.01), "utc": Time.get_datetime_string_from_system(true)}
	out.merge(row, true)
	var err := SafeStore.append_line(path, JSON.stringify(out))
	if err != OK:
		# One failed line ends the notes: a sitting must not fill the console with the same error.
		_open = false
		push_error("sitting notes: cannot write %s (%s)" % [path, error_string(err)])


func _exit_tree() -> void:
	if not _open:
		return
	_close_burst()
	_note({"kind": "end", "marks": marks, "hitches": hitches, "watch": _watch.counts, "plates": _watch.plates, "blank_max_s": snappedf(_watch.blank_max, 0.1),
		"bar_off_max_s": snappedf(_watch.bar_off_max, 0.1)})
	_open = false
