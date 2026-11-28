extends SceneTree

const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

# Wave 19, "No free retry": a death ends the run, so no player-facing line may promise a free
# stage retry. The guard scans the card's docs (README, CONTRACTS, DESIGN-NOTES), the string
# literals in src/ui/*.gd (field_notes.gd included) and the radio catalogue for the retired
# phrasing. Three parts:
#   (a) a planted positive control: the matcher flags every known-bad line, including the old
#       README sentence;
#   (b) a held-out negative set of legitimate current lines (the hold-R restart, the no-free-retry
#       statement, code names) that must all pass unflagged;
#   (c) the real files carry no flagged line. There is no allowlist.
# The phrases are narrow on purpose: internal stage and arena retries still exist in the code and
# the contracts, so the bare word "retry" is not flagged.

const DOCS := ["res://README.md", "res://CONTRACTS.md", "res://DESIGN-NOTES.md"]
const CATALOGUE := "res://assets/radio/catalogue.json"
const UI_DIR := "res://src/ui"
const LITERAL := "\"(?:[^\"\\\\]|\\\\.)*\""

# Case-insensitive phrases.
const PHRASES := [
	"\\bpress r\\b",
	"back at the stage start",
	"(?<!no )free retry",
	"retries once",
	"\\br to retry\\b",
	"death screen: choose a class",
	"(death|dead) screen: (replay|retry)",
	"\\bR, T and N\\b",
	"death screen offers",
	"(?<!no )\\bretry the stage\\b",
]
# Case-sensitive: a capitalised Retry as a button or menu label (quoted, bracketed or a table cell).
const LABELS := [
	"[\"'\\[|]\\s*Retry\\s*[\"'\\]|]",
	"(?<!no )\\bRetry (button|menu|stage)\\b",
]

const KNOWN_BAD := [
	"5. Get scrapped on purpose, then press R. You are back at the stage start in under a second.",
	"Get scrapped on purpose, then press R: you are back at the stage start in under a second.",
	"Press R to retry",
	"press r to retry the stage",
	"Dying costs you nothing: take a free retry.",
	"One held R retries once.",
	"R to retry from the stage start",
	"\"Retry\"",
	"| Retry | restart the stage |",
	"[Retry]",
	"the Retry button",
	"| C | death screen: choose a class |",
	"| T | death screen: replay the world's last stage |",
	"The death screen offers R, T and N.",
	"Press N to retry the stage.",
	"| R | death screen: retry the stage, or the fight in the arena |",
	"dead screen: retry the fight",
	"Serves 2 (R, T and N on one screen)",
]

const KNOWN_GOOD := [
	"If you are scrapped, a death ends the run as RUN OVER: there is no free stage retry.",
	"There is no free retry; the earned save catches one lethal hit.",
	"Hold R in play to restart the run.",
	"{\"keys\": \"R (hold)\", \"does\": \"restart the run: a new run as the same pilot, from world 1\", \"short\": \"hold restart\"},",
	"Get scrapped on purpose, then hold R. You are in a new run as the same pilot, back at world 1.",
	"flow.retry_stage(2)",
	"T calls `replay_stage(3)` and restores the first stage-3 start the run kept.",
	"\"cl_retry\": {\"keys\": [KEY_R], \"pad\": JOY_BUTTON_RIGHT_SHOULDER},",
	"A retry restores the stage-start snapshot, so it restores prices too.",
	"One held R restarts once.",
	"Press right to turn the page.",
	"Press N for a new run as the same class, or Space to choose a class.",
	"release before holding again",
	"The arena retry rewinds only what the fight discovered.",
	"(Superseded: the dead screen has no Retry button now.)",
	"Hold R to start a new run as the same pilot.",
	"# retry the fetch once if the asset download times out",
	"var tries := 0  # retry the request on a network error",
]

var _t := T.new("retired_retry_text_test")


func _initialize() -> void:
	_run()
	quit(_t.verdict())


func flagged(line: String) -> bool:
	for p in PHRASES:
		if not SourceScan.search(_t, line, "(?i)" + p).is_empty():
			return true
	for p in LABELS:
		if not SourceScan.search(_t, line, p).is_empty():
			return true
	return false


func _run() -> void:
	for line in KNOWN_BAD:
		_t.check("control flags: %s" % line, flagged(line), "not flagged")
	_t.check("negative set is held out at 8 or more lines", KNOWN_GOOD.size() >= 8, "%d" % KNOWN_GOOD.size())
	for line in KNOWN_GOOD:
		_t.check("negative passes: %s" % line, not flagged(line), "flagged")
	for path in DOCS:
		_scan_lines(path, _lines(path))
	_scan_lines(CATALOGUE, _lines(CATALOGUE))
	var sources := SourceScan.sources(_t, [UI_DIR])
	_t.check("src/ui holds field_notes.gd", sources.has(UI_DIR.path_join("field_notes.gd")), str(sources.keys()))
	for path in sources:
		_scan_lines(path, _literals(sources[path]))


func _lines(path: String) -> Array:
	return Array(SourceScan.text(_t, path).split("\n"))


# The string literals on each non-comment line of a script, with the line number kept.
func _literals(text: String) -> Array:
	var out: Array = []
	for line in text.split("\n"):
		if String(line).strip_edges().begins_with("#"):
			out.append("")
			continue
		var parts := PackedStringArray()
		for m in SourceScan.search(_t, line, LITERAL):
			parts.append(m.get_string())
		out.append(" ".join(parts))
	return out


func _scan_lines(path: String, lines: Array) -> void:
	var hits: Array = []
	for i in lines.size():
		if flagged(String(lines[i])):
			hits.append("%d: %s" % [i + 1, String(lines[i]).left(120)])
	_t.check("no retired retry text in %s" % path, hits.is_empty(), "; ".join(hits))
