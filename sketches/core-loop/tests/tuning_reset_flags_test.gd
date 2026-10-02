extends SceneTree

const Tuning := preload("res://src/movement/tuning.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")

# Reset defaults in the F1 panel returns to how this launch started: the sliders go back
# to their defaults, the launch flags keep the value the command line gave them.

var _failures := 0


func _initialize() -> void:
	var t := Tuning.new()
	t.apply_args(PackedStringArray(["--music=ace", "--breath=gentle", "--telegraph=haze", "--scrap=armor", "--start-mass=200"]), "launch")
	t.apply_args(PackedStringArray(["--scrap=armor", "--start-mass=200"]), "start")
	t.set_value("cruise", 30.0)
	t.set_option("breath", "raw")
	var panel := TuningPanel.new()
	root.add_child(panel)
	panel.setup(t)
	panel._on_reset()
	_check("breath", t.option("breath") == "gentle", "breath after reset: %s" % t.option("breath"))
	_check("music", t.option("music") == "ace", "music after reset: %s" % t.option("music"))
	_check("telegraph", t.option("telegraph") == "haze", "telegraph after reset: %s" % t.option("telegraph"))
	_check("scrap", t.option("scrap_mode") == "armor", "scrap after reset: %s" % t.option("scrap_mode"))
	_check("start mass", t.base("start_mass") == 200.0, "start mass after reset: %s" % t.base("start_mass"))
	_check("slider", t.base("cruise") == 14.0, "a knob the flags never set returns to its default: %s" % t.base("cruise"))
	_check("slider row", panel._rows["breath"]["slider"].value == 2.0, "the breath row's slider shows the launch value")
	var bare := Tuning.new()
	bare.set_option("breath", "raw")
	bare.reset()
	_check("no flags", bare.option("breath") == "hard", "a launch with no flag resets to the default: %s" % bare.option("breath"))
	print("tuning_reset_flags_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
