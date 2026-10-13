extends SceneTree

# Object identity never reaches a gameplay value. Under res://src, a get_instance_id() result
# (or a variable assigned straight from one) may be a dictionary key, an equality test or a
# lookup key within one run; it may not feed arithmetic, a magnitude comparison, or a string
# format that becomes game data. Two runs with the same inputs must play the same whether or
# not a bot runner attaches its hooks.
# - the lint scans every .gd under res://src and prints each offending file:line;
# - a known out-of-scope use is listed in EXEMPT by its exact text, and the list must match
#   exactly, so an exemption cannot outlive its line;
# - seeded controls prove the scanner fires where it should and stays quiet on keys and equality;
# - the scrap catch side is a serial on the field (or the bot's sign), so two fields given the
#   same catches swirl the same way, however many throwaway objects each run allocates.

const T := preload("res://tests/support/t.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const GID := "get_instance_id()"
const OP := "(?:%|\\*|/|\\+|-(?!>)|<=|>=|<|>)"
const COUNT := 6
const EXPECTED_CHECKS := 19
const MIN_SRC_FILES := 300
# Out-of-scope uses that the fix does not touch. Each entry is "<path>|<stripped line text>".
# item_effects.gd: a victim's instance id rolls an item effect (a gameplay leak; owner ruling and a
# follow-up unit are needed). drill_crew.gd: the id string is written into a death fact.
const EXEMPT := [
	"res://src/build/item_effects.gd|var roll: float = fposmod(_clock * 7.31 + float(key % 997) * Triggers.SPREAD, 1.0)",
	"res://src/combat/drill_crew.gd|bore_fact = {\"breached\": true, \"kind\": \"drill_crew\", \"id\": \"drill_%d\" % get_instance_id(),",
]

static var _assign := RegEx.create_from_string("^\\s*(?:var\\s+)?([A-Za-z_]\\w*)\\s*(?::\\s*\\w+)?\\s*:?=\\s*(.*)$")
static var _rhs_id := RegEx.create_from_string("^(?:int\\(|float\\()?\\s*[\\w.]*get_instance_id\\(\\)")
static var _receiver := RegEx.create_from_string("[A-Za-z_]\\w*(?:\\.\\w+)*\\.\\s*$")
static var _right_op := RegEx.create_from_string("^\\s*" + OP)
static var _left_op := RegEx.create_from_string(OP + "\\s*$")
static var _plus_quote_right := RegEx.create_from_string("^\\s*\\+\\s*\"")
static var _plus_quote_left := RegEx.create_from_string("\"\\s*\\+\\s*$")
static var _cast_left := RegEx.create_from_string("\\b(?:float|int)\\(\\s*$")
static var _key_lhs := RegEx.create_from_string("^\\s*(?:var\\s+)?key\\s*:?=")


var _ran := false


# The checks run on the first frame, once the scene tree is live, so the catch fields
# are inside the tree when their scraps are caught.
func _process(_delta: float) -> bool:
	if _ran:
		return false
	_ran = true
	_run_checks()
	return false


func _run_checks() -> void:
	var t := T.new("identity_value_lint_test")
	var paths: Array[String] = []
	_collect("res://src", paths)
	t.check("the lint scans a full src tree (%d files)" % paths.size(), paths.size() >= MIN_SRC_FILES,
		"at least %d .gd files under res://src" % MIN_SRC_FILES)
	var found: Array = []
	var matched := {}
	for path in paths:
		var text := FileAccess.get_file_as_string(path)
		var raws := text.split("\n")
		for hit in scan(text):
			var line: String = raws[hit["line"] - 1].strip_edges()
			var key := "%s|%s" % [path, line]
			if key in EXEMPT:
				matched[key] = true
			else:
				found.append("%s:%d" % [path, hit["line"]])
	t.check("no identity value feeds gameplay arithmetic in src (%d files scanned)" % paths.size(),
		found.is_empty(), "offending: " + ", ".join(found))
	t.check("each exempt out-of-scope use still matches its exact line (%d)" % EXEMPT.size(),
		matched.size() == EXEMPT.size(), "matched %d of %d" % [matched.size(), EXEMPT.size()])

	_control(t, "a modulo on an id is caught", "var x := get_instance_id() % 3", 1)
	_control(t, "an id equality test is allowed", "if a.get_instance_id() == b.get_instance_id():", 0)
	_control(t, "a variable taken from an id and used in arithmetic is caught",
		"var a := node.get_instance_id()\nvar b := a % 7", 1)
	_control(t, "an id used as a dictionary key is allowed", "_dict[enemy.get_instance_id()] = 1", 0)
	_control(t, "a format of an id into a non-key value is caught", "var k := \"x_%d\" % get_instance_id()", 1)
	_control(t, "a format of an id into a key is allowed", "var key := \"x_%d\" % get_instance_id()", 0)
	_control(t, "an id passed as a get() key before a comparison is allowed",
		"ok = x.get(get_instance_id(), -1.0) > clock", 0)
	_control(t, "a float cast of an id is caught", "float(enemy.get_instance_id()) > clock", 1)
	_control(t, "string concatenation of an id into a key is allowed",
		"var id := node.get_instance_id()\n_gates[\"cause:\" + id] = clock", 0)
	_control(t, "a field set from an id feeds arithmetic in a later line",
		"var p := 0.0\np = float(get_instance_id() % 628) * 0.01\n_pull(sin(p + 1.0))", 2)

	_catch_checks(t)
	var code := t.verdict()
	print("identity_value_lint_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# A control scans a synthetic source and expects a given number of hits.
func _control(t: T, label: String, source: String, want: int) -> void:
	var hits := scan(source)
	t.check("control: " + label, hits.size() == want, "%d hits, want %d" % [hits.size(), want])


# The scrap catch side: the bot's sign when it set one, else this field's catch serial.
func _catch_checks(t: T) -> void:
	var first := _catch_run(0)
	var second := _catch_run(3)
	var want: Array = []
	for i in COUNT:
		want.append(1.0 if i % 2 == 0 else -1.0)
	t.eq("run one catch sides alternate in catch order", first["sides"], want)
	t.eq("run two catch sides alternate in catch order despite throwaway allocations", second["sides"], want)
	t.eq("identical catch sequences swirl identically across runs", second["sides"], first["sides"])
	t.eq("clear() resets the catch serial, so the next catch is +1", first["after_clear"], 1.0)

	var bot_field := ScrapField.new()
	bot_field.setup()
	root.add_child(bot_field)
	var bot_item := bot_field._add(Vector3.ZERO)
	bot_item.set_meta("bot_side", -1.0)
	bot_field.step(Vector3(4.0, 0.0, 0.0), 0.0, 0.016)
	t.eq("a bot_side item keeps its sign", float(bot_field._caught[bot_item]), -1.0)
	t.eq("a bot_side item leaves the catch serial alone", _catch_one(bot_field, Vector3(100.0, 0.0, 0.0)), 1.0)
	bot_field.free()


# Catches COUNT items one at a time, allocating `throwaway` objects before each catch so that
# instance IDs differ between runs.
func _catch_run(throwaway: int) -> Dictionary:
	var field := ScrapField.new()
	field.setup()
	root.add_child(field)
	var sides: Array = []
	for k in COUNT:
		var junk: Array = []
		for j in throwaway:
			junk.append(Node3D.new())
		sides.append(_catch_one(field, Vector3(k * 100.0, 0.0, 0.0)))
		for node in junk:
			node.free()
	field.clear()
	var after_clear := _catch_one(field, Vector3.ZERO)
	field.free()
	return {"sides": sides, "after_clear": after_clear}


# One scrap at `at`, with the ball 4 m away: inside the magnet reach and outside the collect range.
func _catch_one(field: ScrapField, at: Vector3) -> float:
	var item := field._add(at)
	field.step(at + Vector3(4.0, 0.0, 0.0), 0.0, 0.016)
	return float(field._caught[item])


# Returns [{"line": n}] for each line that feeds an identity value into gameplay arithmetic.
static func scan(text: String) -> Array:
	var raws := text.split("\n")
	var codes: Array = []
	for raw in raws:
		codes.append(_code_of(raw))
	var tainted := {}
	for code in codes:
		var m := _assign.search(code)
		if m != null and code.contains(GID) and _rhs_id.search(m.get_string(2).strip_edges()) != null:
			tainted[m.get_string(1)] = true
	var hits: Array = []
	for i in codes.size():
		var code: String = codes[i]
		var hit := false
		var at := 0
		while true:
			var idx := code.find(GID, at)
			if idx < 0:
				break
			at = idx + GID.length()
			var left := code.substr(0, idx)
			var recv := _receiver.search(left)
			if recv != null:
				left = left.substr(0, recv.get_start())
			var right := code.substr(idx + GID.length())
			if _right_op.search(right) != null and _plus_quote_right.search(right) == null:
				hit = true
			if _is_left_operand(left) and _key_lhs.search(code) == null:
				hit = true
		for name in tainted:
			var name_re := RegEx.create_from_string("(?<![\\w.])" + name + "(?!\\w)")
			var own_lhs := RegEx.create_from_string("^\\s*(?:var\\s+)?" + name + "\\s*:?=")
			for m in name_re.search_all(code):
				var after := code.substr(m.get_end())
				var before := code.substr(0, m.get_start())
				if own_lhs.search(code) != null:
					continue
				if _right_op.search(after) != null and _plus_quote_right.search(after) == null:
					hit = true
				if _is_left_operand(before):
					hit = true
		if hit:
			hits.append({"line": i + 1})
	return hits


static func _is_left_operand(left: String) -> bool:
	if _left_op.search(left) != null and _plus_quote_left.search(left) == null:
		return true
	return _cast_left.search(left) != null


# The source text of a line with any trailing comment removed; a # inside a string stays.
static func _code_of(line: String) -> String:
	var quote := ""
	var i := 0
	while i < line.length():
		var c := line[i]
		if quote != "":
			if c == "\\":
				i += 2
				continue
			if c == quote:
				quote = ""
		elif c == "\"" or c == "'":
			quote = c
		elif c == "#":
			return line.substr(0, i)
		i += 1
	return line


func _collect(folder: String, paths: Array[String]) -> void:
	for file in DirAccess.get_files_at(folder):
		if file.ends_with(".gd"):
			paths.append(folder.path_join(file))
	for child in DirAccess.get_directories_at(folder):
		_collect(folder.path_join(child), paths)
