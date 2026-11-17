# smoke: bots timeout=1200s (five launched-game children: a keys-only run to stage 2 beside a planted death and a refused Continue, then two relaunches on the used saves, one continuing the first to stage 2's exit; 125 s and 88 s for the long two on a 4-core cloud box, 2026-11-09)
extends SceneTree

const T := preload("res://tests/support/t.gd")
const ChildRuns := preload("res://tests/trees/child_runs.gd")

# A sitting is a session, not a run: launch, the title, the prologue, a pilot, play, a death or a
# quit, and coming back. This plays those seams on the game a player launches (the main scene, the
# park maps, real ticks, its own save folder), with every menu pressed as a key through the game's
# own input path (tools/self_play.gd --self-play-keys=1), never by a call into the flow:
#   first    a fresh save: Space on the title, the prologue read with the interact key, the pilot's
#            number key, the dam played to its exit, and the game quit a few seconds into the flume;
#   again    the same save folder launched again: Continue is offered, C takes it, the run lands in
#            the flume with the hull, scrap, cogs, parts and tree picks the first launch carried in,
#            the saved picks replay without a warning, and the flume is played to its exit;
#   death    a fresh save: a scripted kill DEATH_AT_S into the dam with scrap aboard, N on the
#            death screen, and a second run that stands in play at stage 1 holding what a first run
#            starts with (hull, no scrap, no cogs, no parts, one kit pick);
#   back     the death leg's save launched again: Space and the pilot's key reach play, and the
#            prologue, read once, does not play a second time;
#   refused  the control: a fresh save has nothing to continue, C on its title starts nothing, and
#            the game quits 1.
# Each leg that plays: no script error or ERROR line, and the play watch saw no wedge and no fall.
# A file of its own (ruling ca): the legs run one after another on shared save folders, which
# world1_run_test's side-by-side pilots cannot host, and self_play_launch_test proves the bot
# tool's own flags and quit codes, not the game's seams.
# Evidence limit: one seed, the first pilot a fresh save has open, the skipper, headless; real
# ticks, so a red here wants one rerun before it counts (the first leg has to clear the dam
# without dying, and the continued leg the flume). Keys are injected events, not a keyboard; the
# mouse, a pad and the pause menu are not pressed (ui_pause_menu_test, input_pad_menus_test and
# death_summary_loop_test press those in a test game). The game is still bot-driven, so the launch
# take, the opening and the start-pick card do not show. The carry line holds hull, scrap, cogs,
# parts and tree picks, not every field of the save. The second run after the death is not played:
# the dead run's bot is spent.

const FIRST_S := 600.0
const AGAIN_S := 420.0
const DEATH_AT_S := 40
const KEYS := ["--self-play", "--self-play-seed=1", "--self-play-keys=1", "--self-play-watch=1", "--self-play-save=session"]


func _initialize() -> void:
	var t := T.new("session_test")
	var base := ProjectSettings.globalize_path("user://").path_join("session-%d" % OS.get_process_id())
	var opening := ChildRuns.run_launched([
		{"name": "player", "args": KEYS + ["--self-play-until=2", "--self-play-hold=3"]},
		{"name": "death", "args": KEYS + ["--self-play-plant-death=%d" % DEATH_AT_S, "--self-play-hold=10"]},
		{"name": "refused", "args": KEYS + ["--self-play-continue=1"]},
	], base, FIRST_S, 3, FIRST_S)
	var first: Dictionary = opening[0]
	var death: Dictionary = opening[1]
	var refused: Dictionary = opening[2]
	# Read before anything launches on that folder again: the run the quit left on disk.
	var saved := _saved_stage(first["data"])
	# The same folders, launched again: what the first launches saved is what these find.
	var returning := ChildRuns.run_launched([
		{"name": "player", "args": KEYS + ["--self-play-continue=1", "--self-play-until=exit2", "--self-play-hold=1"]},
		{"name": "death", "args": KEYS + ["--self-play-until=1", "--self-play-hold=2"]},
	], base, AGAIN_S, 2, AGAIN_S)
	var again: Dictionary = returning[0]
	var back: Dictionary = returning[1]

	_quits(t, "first", first, 0)
	t.check("first: the prologue is read with the interact key", _line(first["text"], "self-play: prologue read with ") != "", _line(first["text"], "self-play: prologue read with "))
	t.check("first: the run is in play by keys alone", _line(first["text"], "self-play: in play by keys at ") != "", _line(first["text"], "self-play: in play by keys at "))
	t.check("first: the dam's exit is taken and the flume entered", _line(first["text"], "self-play: stage 1 exit taken at ") != "" and _line(first["text"], "self-play: stage 2 entered at ") != "",
		_line(first["text"], "self-play: stage 2 entered at "))
	var carried := _line(first["text"], "self-play: carry stage=2 ")
	t.check("first: it carries scrap into the flume", carried != "" and not carried.contains(" mass=0.00 "), carried)
	_clean(t, "first", first)
	t.check("first: the quit left the flume's entrance on disk", saved == 2, "saved stage %d" % saved)

	_quits(t, "again", again, 0)
	t.check("again: Continue is offered and taken with C", _line(again["text"], "self-play: continue pressed at ") != "", _line(again["text"], "self-play: continue pressed at "))
	var entered := _lines(again["text"], "self-play: stage ").filter(func(line: String): return line.contains(" entered"))
	t.check("again: the run lands in the flume, not the dam", not entered.is_empty() and entered[0].begins_with("self-play: stage 2 entered"), "%s" % [entered.slice(0, 2)])
	t.check("again: it carries what the first launch carried in", carried != "" and _line(again["text"], "self-play: carry stage=2 ") == carried,
		"first '%s', again '%s'" % [carried.trim_prefix("self-play: carry "), _line(again["text"], "self-play: carry stage=2 ").trim_prefix("self-play: carry ")])
	var dropped := _lines(again["text"], "WARNING: flow: saved ")
	t.check("again: the saved tree picks replay without a warning", dropped.is_empty(), "%d lines%s" % [dropped.size(), "" if dropped.is_empty() else ": " + String(dropped[0])])
	t.check("again: the flume is played to its exit", _line(again["text"], "self-play: stage 2 exit taken at ") != "", _line(again["text"], "self-play: stage 2 exit taken at "))
	_clean(t, "again", again)

	_quits(t, "death", death, 0)
	var hit := _line(death["text"], "self-play: planted death at ")
	t.check("death: the scripted kill lands on a run holding scrap", hit != "" and not hit.contains(" mass=0.00 "), hit)
	t.check("death: N on the death screen starts a new run", _line(death["text"], "self-play: new run pressed on ") != "", _line(death["text"], "self-play: new run pressed on "))
	var runs := _lines(death["text"], "self-play: carry stage=1 ")
	# Which kit pick the bot draws is not held: its draws run on through both runs, and the first run
	# spends a second one when its haul reaches the next heft class before the kill (the planted
	# death line counts its picks), which moves with real ticks. One pick, and the rest equal, is.
	t.check("death: the second run starts at the dam holding what the first started with", runs.size() == 2 and _held(runs[1]) == _held(runs[0]) and String(runs[1]).contains(" mass=0.00 cogs=0 ")
		and _picks(runs[0]) == 1 and _picks(runs[1]) == 1, "%s" % [runs])
	t.check("death: and stands in play", _line(death["text"], "self-play: second run in play at ") != "", _line(death["text"], "self-play: second run in play at "))
	_clean(t, "death", death)

	_quits(t, "back", back, 0)
	t.check("back: the prologue was read once, on the fresh save", _line(death["text"], "self-play: prologue read with ") != "", _line(death["text"], "self-play: prologue read with "))
	t.check("back: the pilot select is reached again and the pilot picked by key", _line(back["text"], "self-play: pilot ") != "" and _line(back["text"], "self-play: in play by keys at ") != "",
		_line(back["text"], "self-play: pilot "))
	t.check("back: the prologue does not play a second time", _lines(back["text"], "self-play: prologue read with ").is_empty(), "%d prologue lines" % _lines(back["text"], "self-play: prologue read with ").size())
	_clean(t, "back", back)

	_quits(t, "refused", refused, 1)
	t.check("refused: a fresh save offers no Continue, and C on its title starts nothing", _line(refused["text"], "self-play: no Continue offered at ").contains("the title stands") and _line(refused["text"], "self-play: stage ") == "",
		_line(refused["text"], "self-play: no Continue offered at "))

	var code := t.verdict()
	# A green run leaves nothing behind; a red one keeps each child's log and save for reading.
	if code == 0:
		OS.execute("rm", ["-rf", base])
	quit(code)


func _quits(t: T, leg: String, run: Dictionary, code: int) -> void:
	t.check("%s: the game quits %d" % [leg, code], run["code"] == code and not run["timed_out"],
		"exit %d%s, %.0f s wall; %s" % [run["code"], " (killed)" if run["timed_out"] else "", run["seconds"], " | ".join(_lines(run["text"], "self-play: ").slice(-3))])


# Nothing a player would report: no error line, no wedge at rest, no fall through the floor.
func _clean(t: T, leg: String, run: Dictionary) -> void:
	var text: String = run["text"]
	var errors := []
	for line in text.split("\n"):
		if line.contains("SCRIPT ERROR") or line.begins_with("ERROR"):
			errors.append(line.strip_edges())
	t.check("%s: no script error or ERROR line" % leg, errors.is_empty(), "%d lines%s" % [errors.size(), "" if errors.is_empty() else ": " + errors[0]])
	var watch := _line(text, "self-play: watch ")
	t.check("%s: the ball never wedged at rest and never fell through" % leg, watch.contains(" wedged=0 ") and watch.contains(" fell=0 "), watch)


# A carry line without its picks, and how many picks it names.
func _held(carry: String) -> String:
	return carry.get_slice(" picks=", 0)


func _picks(carry: String) -> int:
	var named := carry.get_slice(" picks=", 1)
	return 0 if named == "" else named.split("+").size()


func _line(text: String, prefix: String) -> String:
	var found := _lines(text, prefix)
	return "" if found.is_empty() else String(found[0])


func _lines(text: String, prefix: String) -> Array:
	var out := []
	for line in text.split("\n"):
		if line.begins_with(prefix):
			out.append(line.strip_edges())
	return out


# The stage of the run saved in the leg's folder, 0 when there is none (no file, or an ended run's empty one).
func _saved_stage(data: String) -> int:
	var apps := ChildRuns.userdata_root(data)
	for app in DirAccess.get_directories_at(apps):
		var doc = JSON.parse_string(FileAccess.get_file_as_string(apps.path_join(app).path_join("self-play-session/run.json")))
		if doc is Dictionary and doc.get("run") is Dictionary:
			return int(doc["run"].get("stage", 0))
	return 0
