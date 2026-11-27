extends SceneTree

# A colour means one thing (BACKLOG.md FX-20, effects-critique.md E6). colour_meanings.gd names
# what each palette colour means and which kinds of code must never draw a reserved one. This
# test scans every src/ script for a reserved colour (a palette constant through the file's
# own or an inherited preload alias, its hex, or its name as a row string) and fails one that
# sits in a forbidden domain without a KNOWN row. A KNOWN row whose file no longer uses its
# colour fails too, so a fixed overload deletes its row and the count printed here falls.

const Meanings := preload("res://tests/support/colour_meanings.gd")
const Palette := preload("res://src/core/palette.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const T := preload("res://tests/support/t.gd")

const ROOT := "res://src"
const PALETTE_PATH := "res://src/core/palette.gd"
const HOME := "res://tests/support/colour_meanings.gd"

var _t := T.new("colour_meanings_test")
var _palette: Dictionary = (Palette as GDScript).get_script_constant_map()
var _extends := {}
var _alias_re := RegEx.new()
var _extends_re := RegEx.new()


func _initialize() -> void:
	_alias_re.compile("const\\s+(\\w+)\\s*:?=\\s*preload\\(\"" + PALETTE_PATH + "\"\\)")
	_extends_re.compile("(?m)^extends\\s+\"(res://[^\"]+)\"")
	var scripts := _scripts(ROOT)
	for path in scripts:
		var m := _extends_re.search(FileAccess.get_file_as_string(path))
		if m != null:
			_extends[path] = m.get_string(1)
	_rows()
	_meanings()
	var domains := _domains(scripts)
	_scan(scripts, domains)
	_known()
	quit(_t.verdict())


# Every row names a real palette colour and a known domain.
func _rows() -> void:
	for meaning in Meanings.MEANINGS:
		_t.check("%s names a palette colour" % meaning, _palette.get(Meanings.MEANINGS[meaning]) is Color, Meanings.MEANINGS[meaning])
	for rung in Meanings.REWARD_RUNGS:
		_t.check("reward rung %s names a palette colour" % rung, _palette.get(Meanings.REWARD_RUNGS[rung]) is Color, Meanings.REWARD_RUNGS[rung])
	for colour in Meanings.RESERVED:
		var row: Dictionary = Meanings.RESERVED[colour]
		_t.check("reserved %s is a palette colour" % colour, _palette.get(colour) is Color, colour)
		_t.check("reserved %s has a meaning" % colour, row.meaning in Meanings.MEANINGS or row.meaning == "reward", row.meaning)
		for domain in row.never:
			_t.check("reserved %s domain %s exists" % [colour, domain], Meanings.DOMAINS.has(domain), domain)
	var kinds := ["overload", "ruled"]
	for row in Meanings.KNOWN:
		_t.check("known row %s %s has a kind and a reason" % [row.path, row.colour],
			row.kind in kinds and String(row.why) != "" and _palette.get(row.colour) is Color, str(row))


# Reading a meaning gives today's palette colour: the table changes no colour.
func _meanings() -> void:
	_t.eq("danger is HAZARD", Meanings.of("danger"), Palette.HAZARD)
	_t.eq("live is ARC", Meanings.of("live"), Palette.ARC)
	_t.eq("ancient is ANCIENT", Meanings.of("ancient"), Palette.ANCIENT)
	_t.eq("loss is RUST", Meanings.of("loss"), Palette.RUST)
	_t.eq("boss is BRASS", Meanings.of("boss"), Palette.BRASS)
	_t.eq("the rare rung is COBALT", Meanings.rung("rare"), Palette.COBALT)
	var rivet := ClassDef.new()
	rivet.color = Color("b77843")
	_t.eq("yours is the class colour", Meanings.of("yours", rivet), rivet.color)
	_t.eq("yours with no class is live", Meanings.of("yours"), Palette.live())


func _domains(scripts: Array) -> Dictionary:
	var out := {}
	for domain in Meanings.DOMAINS:
		var spec: Dictionary = Meanings.DOMAINS[domain]
		var members := {}
		for path in scripts:
			if path in spec.files or _under(path, spec.dirs) or _reaches(path, spec.extends):
				members[path] = true
		for path in spec.files:
			_t.check("%s domain file %s exists" % [domain, path], FileAccess.file_exists(path), path)
		_t.check("%s domain has members" % domain, members.size() >= spec.files.size() and members.size() > 0, "%d scripts" % members.size())
		out[domain] = members
	return out


func _scan(scripts: Array, domains: Dictionary) -> void:
	var known := {}
	for row in Meanings.KNOWN:
		known[row.path + ":" + row.colour] = true
	var found := []
	var stray := []
	for path in scripts:
		if path == HOME or path == PALETTE_PATH:
			continue
		var used := _colours_in(path, Meanings.RESERVED.keys())
		for colour in used:
			for domain in Meanings.RESERVED[colour].never:
				if not domains[domain].has(path):
					continue
				found.append("%s %s (%s)" % [path, colour, domain])
				if not known.has(path + ":" + colour):
					stray.append("%s draws %s, reserved for %s, in %s code" % [path, colour, Meanings.RESERVED[colour].meaning, domain])
	var overloads := 0
	for row in Meanings.KNOWN:
		if row.kind == "overload":
			overloads += 1
	print("reserved colours in forbidden domains: %d sites; known rows %d (%d overloads to burn down)" % [found.size(), Meanings.KNOWN.size(), overloads])
	_t.check("no reserved colour outside its meaning", stray.is_empty(),
		"draw the meaning this code owns, or add a KNOWN row in colour_meanings.gd with its reason: %s" % [stray])
	_t.check("the scan sees the known overloads", found.size() > 0, "%d sites" % found.size())


# A row whose file no longer draws its colour is burned down: delete it.
func _known() -> void:
	for row in Meanings.KNOWN:
		var exists := FileAccess.file_exists(row.path)
		_t.check("known row file %s exists" % row.path, exists, row.path)
		if exists:
			_t.check("known row %s still draws %s" % [row.path, row.colour], row.colour in _colours_in(row.path, [row.colour]),
				"fixed: delete its KNOWN row in colour_meanings.gd")


func _colours_in(path: String, colours: Array) -> Array:
	var code := _code(FileAccess.get_file_as_string(path))
	var aliases := _aliases(path)
	var out := []
	for colour in colours:
		var hex: String = (_palette[colour] as Color).to_html(false).to_lower()
		var hit := code.to_lower().contains(hex) or code.contains("\"%s\"" % colour)
		# Asking by meaning is drawing the colour too: of("danger") in player code is still danger red.
		for meaning in Meanings.MEANINGS:
			if Meanings.MEANINGS[meaning] == colour and code.contains(".of(\"%s\"" % meaning):
				hit = true
		for alias in aliases:
			if hit:
				break
			var re := RegEx.new()
			re.compile("\\b%s\\.%s\\b" % [alias, colour])
			hit = re.search(code) != null
			# Palette.live() is mint today (palette.gd).
			if not hit and colour == "ARC":
				re.compile("\\b%s\\.live\\(" % alias)
				hit = re.search(code) != null
		if hit:
			out.append(colour)
	return out


# The palette aliases a script can use: its own preloads and every base script's.
func _aliases(path: String) -> Array:
	var out := []
	var cur := path
	var guard := 0
	while cur != "" and guard < 16:
		for m in _alias_re.search_all(FileAccess.get_file_as_string(cur)):
			out.append(m.get_string(1))
		cur = String(_extends.get(cur, ""))
		guard += 1
	return out


func _reaches(path: String, bases: Array) -> bool:
	var cur := String(_extends.get(path, ""))
	var guard := 0
	while cur != "" and guard < 16:
		if cur in bases:
			return true
		cur = String(_extends.get(cur, ""))
		guard += 1
	return false


func _under(path: String, dirs: Array) -> bool:
	for dir in dirs:
		if path.begins_with(dir):
			return true
	return false


# Code only: comments are skipped, so a comment naming a colour is not a site.
func _code(text: String) -> String:
	var lines := PackedStringArray()
	for line in text.split("\n"):
		var cut := line.length()
		var quoted := false
		for i in line.length():
			if line[i] == "\"":
				quoted = not quoted
			elif line[i] == "#" and not quoted:
				cut = i
				break
		lines.append(line.substr(0, cut))
	return "\n".join(lines)


func _scripts(dir_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	for sub in dir.get_directories():
		out.append_array(_scripts(dir_path.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(dir_path.path_join(file))
	out.sort()
	return out
