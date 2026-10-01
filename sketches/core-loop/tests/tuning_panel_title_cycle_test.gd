extends SceneTree

const Tuning := preload("res://src/movement/tuning.gd")
const TuningPanel := preload("res://src/ui/tuning_panel.gd")
const LoopMode := preload("res://src/core/loop_mode.gd")

# The title's L, G and B keys change the tuning through LoopMode.cycle without telling
# the F1 panel; the panel shows the live row whenever it is visible, so a later drag
# never writes from a stale slider.

var _failures := 0


func _initialize() -> void:
	var t := Tuning.new()
	t.apply_args(PackedStringArray(["--loop=drop", "--music=ace"]), "launch")
	var panel := TuningPanel.new()
	root.add_child(panel)
	panel.setup(t)
	panel.visible = true
	LoopMode.cycle(t, "loop_mode")
	LoopMode.cycle(t, "gun_role")
	LoopMode.cycle(t, "breath")
	await process_frame
	await process_frame
	_check("loop label", panel._rows["loop_mode"]["label"].text.begins_with("Loop mode: laps"), panel._rows["loop_mode"]["label"].text)
	_check("loop slider", panel._rows["loop_mode"]["slider"].value == 2.0, "loop slider %s" % panel._rows["loop_mode"]["slider"].value)
	_check("gun label", panel._rows["gun_role"]["label"].text.contains(LoopMode.gun_role(t)), panel._rows["gun_role"]["label"].text)
	_check("gun slider", panel._rows["gun_role"]["slider"].value == t.base("gun_role"), "gun slider %s" % panel._rows["gun_role"]["slider"].value)
	_check("breath slider", panel._rows["breath"]["slider"].value == t.base("breath"), "breath slider %s" % panel._rows["breath"]["slider"].value)
	panel._rows["loop_mode"]["slider"].value = 1.0
	_check("drag", t.option("loop_mode") == "drop", "a drag writes the value it shows: %s" % t.option("loop_mode"))
	print("tuning_panel_title_cycle_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
