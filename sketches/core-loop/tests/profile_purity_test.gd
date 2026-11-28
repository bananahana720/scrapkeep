extends SceneTree

const Achievements := preload("res://src/core/achievements.gd")
const Cosmetics := preload("res://src/core/cosmetics.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")
const SourceScan := preload("res://tests/support/source_scan.gd")

# The profile layer is read only by the game, the UI and core (P2-4). Movement, combat, build,
# world and boss code never touch it: not by name, not through the context, not in a field the
# game fills with it. The game hands such code only the calls it needs, as a Callable or a core
# object (CampRecords). The scan matches whole identifiers and file names, not the words
# "profile" or "progress", which name unrelated things (camera and terrain profiles).

const DIRS := ["src/movement", "src/combat", "src/build", "src/world", "src/boss"]
const PATTERN := "\\b(\\w*ctx\\.(profile|progress|achievements|cosmetics)|Profile|Progress|Achievements|Cosmetics)\\b|\\b(profile|progress|achievements|cosmetics)\\.gd\\b|\\b\\w*ctx(\\.get\\(|\\[)\\s*[\"'](profile|progress|achievements|cosmetics)[\"']"
const FIELD_PATTERN := "(?m)^\\s*(?!ctx\\.)[A-Za-z_]\\w*(?:\\.[A-Za-z_]\\w*)+\\s*=\\s*(?:[A-Za-z_]\\w*\\.)*ctx\\.(?:profile|progress|achievements|cosmetics)\\s*$"

var _t := T.new("profile_purity_test")


func _initialize() -> void:
	var re := RegEx.create_from_string(PATTERN)
	_t.check("scan self-check: a planted ctx.profile read is caught", _hits(re, "var x = ctx.profile.has_pilot(id)\n").size() == 1, "planted line")
	_t.check("scan self-check: a planted preload is caught", _hits(re, "const P := preload(\"res://src/core/profile.gd\")\n").size() == 1, "planted preload")
	_t.check("scan self-check: a planted context read by string is caught", _hits(re, "var p = ctx.get(\"profile\")\n").size() == 1, "planted ctx.get")
	_t.check("scan self-check: a planted context index is caught", _hits(re, "var p = _ctx[\"progress\"]\n").size() == 1, "planted ctx[]")
	_t.check("scan self-check: a planted ctx.progress call is caught", _hits(re, "fleet.ctx.progress.settle(id)\n").size() == 1, "planted ctx.progress")
	_t.check("scan self-check: camera profiles and progress variables pass", _hits(re, "var profile := PROFILES[k]\nvar progress := 0.5\nentry.progress = progress\nvar t = ctx.get(\"tuning\")\n").is_empty(), "bare words")
	var field_re := RegEx.create_from_string(FIELD_PATTERN)
	_t.check("field self-check: a planted field filled with the profile is caught", _hits(field_re, "\t\thub.camp_store = ctx.profile\n").size() == 1, "planted field")
	_t.check("field self-check: the context's own fields and a handed object pass", _hits(field_re, "ctx.profile = Profile.new(path)\nctx.progress = progress\nhub.camp_records = CampRecords.new(ctx.profile)\n").is_empty(), "context and handed object")
	_t.eq("P2-4 no script fills a field with the profile layer", SourceScan.matching(_t, ["res://src"], FIELD_PATTERN), [])
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
