extends SceneTree

# Object identity never reaches a gameplay value. Under res://src, a get_instance_id() result
# (or a variable assigned from one) may be a dictionary key, an equality test, a has/get/erase
# argument, or a plain value passed on (a cue argument, a dictionary literal entry). It may not
# feed arithmetic or bitwise operators, a magnitude comparison, a numeric call, a seed, or a
# string format or concatenation that is not a key. Two runs with the same inputs must play the
# same whether or not a bot runner attaches its hooks.
# - the scanner is an allow-list: an identity occurrence is a hit unless its context is one of
#   the key or value contexts below, so an unlisted shape fails the lint;
# - a value that an assignment copies from an identity taints its target, followed to a fixed
#   point within one function body, so a one- or two-hop copy into arithmetic is caught;
# - the lint scans every .gd under res://src and prints each offending file:line;
# - a known out-of-scope use is listed in EXEMPT by its exact text, and the list must match
#   exactly, so an exemption cannot outlive its line;
# - seeded controls prove the scanner fires where it should and stays quiet on keys and equality;
# - the scrap catch side is a serial on the field (or the bot's sign), so two fields given the
#   same catches swirl the same way, however many throwaway objects each run allocates.

const SourceScan := preload("res://tests/support/source_scan.gd")
const T := preload("res://tests/support/t.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const GID := "get_instance_id()"
const OP := "(?:%|\\*|/|\\+|-(?!>)|<=|>=|<|>|(?<!&)&(?!&)|(?<!\\|)\\|(?!\\|)|\\^)"
const COUNT := 6
const EXPECTED_CHECKS := 32
const MIN_SRC_FILES := 300
# Calls whose result or ordering depends on the magnitude of their arguments.
const NUMERIC_CALLS := [
	"float", "int", "posmod", "fposmod", "hash", "seed", "abs", "absf", "absi", "sign", "signf",
	"sin", "cos", "roundi", "floori", "ceili", "min", "max", "mini", "maxi", "minf", "maxf", "pow",
	"sqrt", "clampf", "clampi", "wrapf", "wrapi", "randi_range", "randf_range", "lerpf", "remap",
]
# Calls that take an id only as a lookup key.
const KEY_CALLS := ["has", "get", "erase", "find"]
# Out-of-scope uses that the fix does not touch. Each entry is "<path>|<stripped line text>".
# drill_crew.gd: the id string is written into a death fact; no reader of that fact exists under
# src (inference that it is a key only).
const EXEMPT := [
	"res://src/combat/drill_crew.gd|bore_fact = {\"breached\": true, \"kind\": \"drill_crew\", \"id\": \"drill_%d\" % get_instance_id(),",
]

static var _assign := RegEx.create_from_string("^\\s*(?:var\\s+)?([A-Za-z_]\\w*)\\s*(?::\\s*\\w+)?\\s*:?=\\s*(.*)$")
static var _receiver := RegEx.create_from_string("[A-Za-z_]\\w*(?:\\.\\w+)*\\.\\s*$")
static var _right_op := RegEx.create_from_string("^\\s*" + OP)
static var _left_op := RegEx.create_from_string(OP + "\\s*$")
static var _eq_left := RegEx.create_from_string("(?:==|!=)\\s*$")
static var _eq_right := RegEx.create_from_string("^\\s*(?:==|!=)")
static var _format_left := RegEx.create_from_string("[\"']\\s*%\\s*$")
static var _format_any := RegEx.create_from_string("[\"']\\s*%")
static var _concat_left := RegEx.create_from_string("[\"']\\s*\\+\\s*$")
static var _concat_right := RegEx.create_from_string("^\\s*\\+\\s*[\"']")
static var _key_lhs := RegEx.create_from_string("^\\s*(?:var\\s+)?\\w*key\\s*(?::\\s*\\w+)?\\s*:?=")
static var _seed_lhs := RegEx.create_from_string("^\\s*(?:[\\w.]+\\.)?seed\\s*=(?!=)")
static var _func_start := RegEx.create_from_string("^(?:static\\s+)?func\\s")
static var _ends_ident := RegEx.create_from_string("[\\w)\\]]\\s*$")
static var _word := RegEx.create_from_string("^\\w$")


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
	var sources := SourceScan.sources(t, ["res://src"])
	t.check("the lint scans a full src tree (%d files)" % sources.size(), sources.size() >= MIN_SRC_FILES,
		"at least %d .gd files under res://src" % MIN_SRC_FILES)
	var found: Array = []
	var matched := {}
	for path in sources:
		var text: String = sources[path]
		var raws := text.split("\n")
		for hit in scan(text):
			var line: String = raws[hit["line"] - 1].strip_edges()
			var key := "%s|%s" % [path, line]
			if key in EXEMPT:
				matched[key] = true
			else:
				found.append("%s:%d" % [path, hit["line"]])
	t.check("no identity value feeds gameplay arithmetic in src (%d files scanned)" % sources.size(),
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
	_control(t, "a bitwise and of an id is caught", "var ok := get_instance_id() & 1", 1)
	_control(t, "an id inside posmod is caught", "var p := posmod(get_instance_id(), 2)", 1)
	_control(t, "an id as any argument of max is caught", "var m := max(0, get_instance_id())", 1)
	_control(t, "an id hashed is caught", "var h := hash(get_instance_id())", 1)
	_control(t, "an id assigned to a seed is caught", "rng.seed = get_instance_id()", 1)
	_control(t, "a two-hop copy of an id into arithmetic is caught",
		"var a := node.get_instance_id()\nvar b := a\nvar c := b % 7", 1)
	_control(t, "arithmetic on an id inside a subscript is caught", "_dict[get_instance_id() % 3] = 1", 1)
	_control(t, "a subscript inside a numeric call is a key, not a call argument",
		"var n := int(_wound[enemy.get_instance_id()])", 0)
	_control(t, "a product of an id that becomes a key and is then used is caught",
		"var key := 3 * get_instance_id()\nvar roll := float(key % 997)", 2)
	_control(t, "a format list of ids into a non-key value is caught",
		"var t := \"x_%d\" % [get_instance_id()]", 1)
	_control(t, "a format list of ids into a key is allowed",
		"var key := \"%d:%d\" % [a.get_instance_id(), b.get_instance_id()]", 0)
	_control(t, "an id passed as a plain argument is allowed", "ship.cue(\"crane_warn\", h.get_instance_id())", 0)
	_control(t, "a name tainted in one function does not taint another",
		"func a() -> void:\n\tvar id := node.get_instance_id()\nfunc b() -> void:\n\tvar c := id % 7", 0)

	_catch_checks(t)
	# An early return that skips checks must not pass: the run counts its own checks.
	t.eq("every check ran", t.checks, EXPECTED_CHECKS)
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


# Returns [{"line": n}] for each line where an identity value reaches a gameplay use. Taint is
# scoped to one function body: each `func` line starts a new block.
static func scan(text: String) -> Array:
	var codes: Array = []
	for raw in text.split("\n"):
		codes.append(_code_of(raw))
	var hits: Array = []
	var block_start := 0
	for i in range(1, codes.size() + 1):
		if i == codes.size() or _func_start.search(codes[i]) != null:
			hits.append_array(_scan_block(codes, block_start, i))
			block_start = i
	return hits


static func _scan_block(codes: Array, from: int, to: int) -> Array:
	var tainted := {}
	var cache := {}
	var changed := true
	var rounds := 0
	while changed and rounds < 10:
		changed = false
		rounds += 1
		for i in range(from, to):
			var code: String = codes[i]
			var m := _assign.search(code)
			if m == null or tainted.has(m.get_string(1)):
				continue
			if _taints(code, tainted, cache):
				tainted[m.get_string(1)] = true
				changed = true
	var hits: Array = []
	for i in range(from, to):
		var code: String = codes[i]
		var occs := _occurrences(code, tainted, cache)
		var seed_hit := _seed_lhs.search(code) != null and not occs.is_empty()
		if seed_hit or _has_hit(occs):
			hits.append({"line": i + 1})
	return hits


static func _has_hit(occs: Array) -> bool:
	for occ in occs:
		if occ["class"] == "hit":
			return true
	return false


# An assignment taints its target when a value copied from an identity reaches its right side
# (not a key, not a format of a key). A format on the right side is a label, never a value.
static func _taints(code: String, tainted: Dictionary, cache: Dictionary) -> bool:
	var m := _assign.search(code)
	if m == null:
		return false
	var rhs_start := m.get_start(2)
	if _format_any.search(code.substr(rhs_start)) != null:
		return false
	for occ in _occurrences(code, tainted, cache):
		if occ["start"] >= rhs_start and occ["class"] != "key":
			return true
	return false


# Every identity occurrence on a line: the GID call and each tainted name, minus the name the
# line assigns to. Each carries its class: "key", "hit" or "value".
static func _occurrences(code: String, tainted: Dictionary, cache: Dictionary) -> Array:
	var found: Array = []
	var key_lhs := _key_lhs.search(code) != null
	var lhs := _assign.search(code)
	var lhs_start := -1
	if lhs != null:
		lhs_start = lhs.get_start(1)
	var at := 0
	while true:
		var idx := code.find(GID, at)
		if idx < 0:
			break
		at = idx + GID.length()
		found.append({"start": idx, "class": _classify(code, idx, at, key_lhs)})
	for name in tainted:
		for m in _name_regex(name, cache).search_all(code):
			if m.get_start() != lhs_start:
				found.append({"start": m.get_start(), "class": _classify(code, m.get_start(), m.get_end(), key_lhs)})
	return found


static func _name_regex(name: String, cache: Dictionary) -> RegEx:
	if not cache.has(name):
		cache[name] = RegEx.create_from_string("(?<![\\w.])" + name + "(?!\\w)")
	return cache[name]


# Classifies one occurrence by its context on the line.
#   key   equality test, lookup key (subscript, has/get/erase/find argument), key format or concat
#   hit   arithmetic or bitwise operator, numeric call argument, or a non-key format or concat
#   value anything else: a plain argument, a dictionary entry, an assignment's right side
static func _classify(code: String, start: int, end: int, key_lhs: bool) -> String:
	var left := code.substr(0, start)
	var recv := _receiver.search(left)
	if recv != null:
		left = left.substr(0, recv.get_start())
	var right := code.substr(end)
	if _eq_left.search(left) != null or _eq_right.search(right) != null:
		return "key"
	# The innermost open bracket and paren decide the context: a subscript inside a call is a
	# key use of the call's argument, not an argument of the call.
	var open := _innermost_unclosed(left, "[", "]")
	var paren := _innermost_unclosed(left, "(", ")")
	var subscript := open >= 0 and _ends_ident.search(left.substr(0, open)) != null
	var in_format_list := open >= 0 and not subscript and _format_left.search(left.substr(0, open)) != null
	var call := _call_name(left, paren) if paren > open else ""
	if _format_left.search(left) != null or in_format_list or call == "str" \
			or _concat_left.search(left) != null or _concat_right.search(right) != null:
		return "key" if key_lhs or subscript else "hit"
	if _right_op.search(right) != null or _left_op.search(left) != null:
		return "hit"
	if NUMERIC_CALLS.has(call):
		return "hit"
	if KEY_CALLS.has(call) or subscript:
		return "key"
	return "value"


# Index of the innermost unclosed `open_ch` in `left`, or -1.
static func _innermost_unclosed(left: String, open_ch: String, close_ch: String) -> int:
	var depth := 0
	var i := left.length() - 1
	while i >= 0:
		var c := left[i]
		if c == close_ch:
			depth += 1
		elif c == open_ch:
			if depth == 0:
				return i
			depth -= 1
		i -= 1
	return -1


# The name of the call whose '(' sits at `paren`, or "".
static func _call_name(left: String, paren: int) -> String:
	var j := paren
	while j > 0 and _word.search(left[j - 1]) != null:
		j -= 1
	return left.substr(j, paren - j)


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
