extends SceneTree

const Tuning := preload("res://src/movement/tuning.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")

# The launch flags: one table (Tuning.FLAGS) and one parse pass (Tuning.apply_args). Every
# flag has a valid and an invalid value here; a flag dropped from the table fails the
# EXPECTED list below, and one added without a row here fails the last check.

# flag -> [tuning key, valid value, invalid value, when]. Numbers have no invalid option.
const EXPECTED := {
	"scrap": ["scrap_mode", "armor", "bogus", "start"],
	"wear": ["wear", "on", "bogus", "start"],
	"route-seed": ["route_seed", "7", "seven", "start"],
	"start-mass": ["start_mass", "200", "heavy", "start"],
	"loop": ["loop_mode", "laps", "bogus", "launch"],
	"gun": ["gun_role", "full", "bogus", "launch"],
	"music": ["music", "ace", "bogus", "launch"],
	"breath": ["breath", "gentle", "bogus", "launch"],
	"discovery": ["discovery", "cards", "bogus", "launch"],
	"telegraph": ["telegraph", "haze", "bogus", "launch"],
	"world-one-builds": ["world_one_builds", "on", "bogus", "launch"],
	"hotwire-shell": ["hotwire_shell", "on", "bogus", "launch"],
	"hotwire-tread": ["hotwire_tread", "on", "bogus", "launch"],
	"harpoon": ["harpoon", "lock", "bogus", "launch"],
	"harpoon-pull": ["harpoon_pull", "heft", "bogus", "launch"],
	"harpoon-keys": ["harpoon_keys", "keep", "bogus", "launch"],
}

var _failures := 0


func _initialize() -> void:
	for flag in EXPECTED:
		_flag(flag, EXPECTED[flag])
	var t := Tuning.new()
	var before := _snapshot(t)
	var applied := t.apply_args(PackedStringArray(["--nonsense=1", "--path", "x", "--loop", "--=drop", "-loop=drop", "loop=drop"]))
	_check("unknown ignored", applied.is_empty() and _snapshot(t) == before, "unknown flags and malformed args change nothing: %s" % [applied])
	var all := PackedStringArray()
	for flag in EXPECTED:
		all.append("--%s=%s" % [flag, EXPECTED[flag][1]])
	var one := Tuning.new()
	var everything := one.apply_args(all)
	var every_ok: bool = everything.size() == EXPECTED.size()
	for flag in EXPECTED:
		every_ok = every_ok and _holds(one, flag, EXPECTED[flag])
	_check("one pass", every_ok, "all %d flags in one apply_args: %s" % [EXPECTED.size(), everything])
	var start := Tuning.new()
	var launch := Tuning.new()
	var started := start.apply_args(all, "start")
	var launched := launch.apply_args(all, "launch")
	var phases_ok: bool = true
	for flag in EXPECTED:
		phases_ok = phases_ok and started.has(flag) == (EXPECTED[flag][3] == "start") and launched.has(flag) == (EXPECTED[flag][3] == "launch")
	_check("phases", phases_ok and LoopMode.apply_args(Tuning.new(), all).size() == launched.size(),
		"start applies %s; launch applies %s; LoopMode.apply_args is the launch pass" % [started.keys(), launched.keys()])
	_check("table matches", Tuning.FLAGS.size() == EXPECTED.size() and _same_keys(Tuning.FLAGS, EXPECTED),
		"Tuning.FLAGS has %d rows, this test covers %d" % [Tuning.FLAGS.size(), EXPECTED.size()])
	_check("haze name", Threat.TELEGRAPH_FLAG == "telegraph" and Tuning.FLAGS.has(Threat.TELEGRAPH_FLAG)
		and Tuning.FLAGS[Threat.TELEGRAPH_FLAG][0] == LoopMode.TELEGRAPH_KEY and Tuning.new().options_of(LoopMode.TELEGRAPH_KEY).has("haze"),
		"Painter.haze_on() reads --%s=haze, a row in the table" % Threat.TELEGRAPH_FLAG)
	print("tuning_flags_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _flag(flag: String, row: Array) -> void:
	var row_in_table: Array = Tuning.FLAGS.get(flag, [])
	var t := Tuning.new()
	var default_value := t.base(row[0])
	var applied := t.apply_args(PackedStringArray(["--%s=%s" % [flag, row[1]]]))
	var valid_ok: bool = not row_in_table.is_empty() and row_in_table[0] == row[0] and row_in_table[2] == row[3] and applied.get(flag) == row[1] and _holds(t, flag, row)
	var bad := Tuning.new()
	var refused := bad.apply_args(PackedStringArray(["--%s=%s" % [flag, row[2]]]))
	var invalid_ok: bool = refused.is_empty() and bad.base(row[0]) == default_value
	_check("--" + flag, valid_ok and invalid_ok, "valid %s -> %s, invalid %s refused %s" % [row[1], applied, row[2], invalid_ok])


func _holds(t, flag: String, row: Array) -> bool:
	if Tuning.FLAGS.get(flag, [])[1] == "number":
		return t.base(row[0]) == float(row[1])
	return t.option(row[0]) == row[1]


func _snapshot(t) -> Dictionary:
	var out := {}
	for spec in Tuning.SPECS:
		out[spec["key"]] = t.base(spec["key"])
	return out


func _same_keys(a: Dictionary, b: Dictionary) -> bool:
	for key in a:
		if not b.has(key):
			return false
	return true


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
