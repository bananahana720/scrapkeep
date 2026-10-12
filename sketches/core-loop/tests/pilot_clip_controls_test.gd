extends SceneTree

const Motion := preload("res://src/presentation/mecha_motion.gd")
const T := preload("res://tests/support/t.gd")
var t := T.new("pilot_clip_controls_test")

func _initialize() -> void:
	var shell := Node3D.new()
	shell.name = "Shell"
	root.add_child(shell)
	var pod := _child(shell, "Pod")
	var core := _child(shell, "Core")
	var fin := _child(core, "Fin_L")
	var bank := _child(pod, "Bank")
	var control := _child(bank, "Control_Lever")
	var motion := Motion.new(pod, core, "runner_gunner")
	t.eq("sibling Core", motion._node("Core"), core)
	t.eq("sibling descendant Fin.L", motion._node("Fin.L"), fin)
	t.eq("declared path from shell root", motion._node("Pod/Bank/Control.Lever"), control)
	t.eq("pod-relative path", motion._node("Bank/Control.Lever"), control)
	t.eq("exact declared Core path", motion._node("Core/Fin.L"), fin)
	motion._node("TrulyMissing")
	motion._node("TrulyMissing")
	t.eq("missing emits one line", motion.skip_lines.count("SKIP control TrulyMissing"), 1)
	t.eq("only truly missing skips", motion.skip_lines.size(), 1)
	core.name = "HeroCore"
	pod.name = "HeroPod"
	var fitted := Motion.new(pod, core, "demolitions_caster")
	t.eq("renamed runtime Core", fitted._node("Core"), core)
	t.eq("renamed runtime Core path", fitted._node("Core/Fin.L"), fin)
	t.eq("stated check count", t.checks + 1, 10)
	shell.free()
	quit(t.verdict())

func _child(parent: Node, label: String) -> Node3D:
	var child := Node3D.new()
	child.name = label
	parent.add_child(child)
	return child
