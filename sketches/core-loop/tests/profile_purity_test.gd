extends SceneTree

const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")

# The profile layer is read only by the game, the UI and core (P2-4). Movement, combat, build,
# world and boss code never touch it. The scan matches whole identifiers and file names, not
# the words "profile" or "progress", which name unrelated things (camera and terrain profiles).

const DIRS := ["src/movement", "src/combat", "src/build", "src/world", "src/boss"]
const PATTERN := "\\b(ctx\\.profile|Profile|Progress|Achievements|Cosmetics)\\b|\\b(profile|progress|achievements|cosmetics)\\.gd\\b"

var _t := T.new("profile_purity_test")


func _initialize() -> void:
	var re := RegEx.create_from_string(PATTERN)
	_t.check("scan self-check: a planted ctx.profile read is caught", _hits(re, "var x = ctx.profile.has_pilot(id)\n").size() == 1, "planted line")
	_t.check("scan self-check: a planted preload is caught", _hits(re, "const P := preload(\"res://src/core/profile.gd\")\n").size() == 1, "planted preload")
	_t.check("scan self-check: camera profiles and progress variables pass", _hits(re, "var profile := PROFILES[k]\nvar progress := 0.5\n").is_empty(), "bare words")
	var sources := SourceScan.sources(_t, DIRS.map(func(dir: String) -> String: return "res://" + dir))
	for path in sources:
		var hits := _hits(re, sources[path])
		_t.check("P2-4 %s has no profile-layer reference" % path, hits.is_empty(), "hits %s" % [hits])
	_t.check("P2-4 the scan saw files", sources.size() > 20, "%d files" % sources.size())
	var pilots: Array = []
	for def in ClassDef.all():
		pilots.append(def.id)
	var problems := Achievements.validate(Achievements.ROWS, Achievements.bus_signals(), pilots, Cosmetics.ids())
	_t.check("P2-4 Achievements.validate finds no problems", problems.is_empty(), "problems %s" % [problems])
	quit(_t.verdict())


func _hits(re: RegEx, text: String) -> Array:
	var out: Array = []
	var n := 0
	for line in text.split("\n"):
		n += 1
		if re.search(line) != null:
			out.append("%d: %s" % [n, line.strip_edges()])
	return out
