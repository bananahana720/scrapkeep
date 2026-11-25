extends RefCounted


const SLOW_MS := 100.0
const GAP_MS := 20.0

var rows: Array[Dictionary] = []
var frame := 0
var _marks: Array = []
var _stamps := PackedInt64Array()
var _names := PackedStringArray()


class Mark:
	extends Node
	var probe
	var index := 0

	func _physics_process(_delta: float) -> void:
		probe._stamps[index] = Time.get_ticks_usec()


class Tail:
	extends Node
	var probe

	func _init() -> void:
		process_physics_priority = 2147483647

	func _physics_process(_delta: float) -> void:
		probe._close(Time.get_ticks_usec())


class Head:
	extends Node
	var probe

	func _init() -> void:
		process_physics_priority = -2147483648

	func _physics_process(_delta: float) -> void:
		probe._open(Time.get_ticks_usec())


var _start := 0


func watch(tree: SceneTree, parents: Array) -> void:
	var head := Head.new()
	head.probe = self
	tree.root.add_child(head)
	for parent: Node in parents:
		for child in parent.get_children():
			if child is Mark:
				continue
			var mark := Mark.new()
			mark.probe = self
			mark.index = _marks.size()
			mark.name = "ProbeMark%d" % mark.index
			_marks.append(mark)
			_names.append("%s/%s" % [parent.name, child.name])
			parent.add_child(mark)
			parent.move_child(mark, child.get_index())
	_stamps.resize(_marks.size())
	var tail := Tail.new()
	tail.probe = self
	tree.root.add_child(tail)


func _open(now: int) -> void:
	_start = now
	_stamps.fill(0)


func _close(now: int) -> void:
	var total := (now - _start) / 1000.0
	if total < SLOW_MS:
		return
	var gaps := []
	var last := _start
	var last_name := "(before the first marker)"
	for i in _marks.size():
		if _stamps[i] == 0:
			continue
		var gap := (_stamps[i] - last) / 1000.0
		if gap >= GAP_MS:
			gaps.append([last_name, snappedf(gap, 0.1)])
		last = _stamps[i]
		last_name = _names[i]
	var tail_gap := (now - last) / 1000.0
	if tail_gap >= GAP_MS:
		gaps.append([last_name, snappedf(tail_gap, 0.1)])
	rows.append({"f": frame, "tick_ms": snappedf(total, 0.1), "gaps": gaps})
