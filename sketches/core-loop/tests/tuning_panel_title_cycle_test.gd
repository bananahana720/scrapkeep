extends SceneTree

const Tuning := preload("res://src/movement/tuning.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")

# The title's B key changes the tuning without telling
# the F1 panel; the panel shows the live row whenever it is visible, so a later drag
# never writes from a stale slider.

var _failures := 0


func _initialize() -> void:
	var t := Tuning.new()
	t.apply_args(PackedStringArray(["--music=ace", "--telegraph=haze"]), "launch")
	var panel := TuningPanel.new()
	root.add_child(panel)
	panel.setup(t)
	panel.visible = true
	_cycle(t, "telegraph")
	_cycle(t, "breath")
	await process_frame
	await process_frame
	_check("telegraph label", panel._rows["telegraph"]["label"].text.contains(t.option("telegraph")), panel._rows["telegraph"]["label"].text)
	_check("telegraph slider", panel._rows["telegraph"]["slider"].value == t.base("telegraph"), "telegraph slider %s" % panel._rows["telegraph"]["slider"].value)
	_check("breath label", panel._rows["breath"]["label"].text.contains(t.option("breath")), panel._rows["breath"]["label"].text)
	_check("breath slider", panel._rows["breath"]["slider"].value == t.base("breath"), "breath slider %s" % panel._rows["breath"]["slider"].value)
	panel._rows["breath"]["slider"].value = 0.0
	_check("drag", t.option("breath") == "raw", "a drag writes the value it shows: %s" % t.option("breath"))
	print("tuning_panel_title_cycle_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])


func _cycle(t, key: String) -> void:
	var options: Array = t.options_of(key)
	t.set_option(key, options[(options.find(t.option(key)) + 1) % options.size()])
