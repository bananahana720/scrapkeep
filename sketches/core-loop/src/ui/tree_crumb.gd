extends Control

const Palette := preload("res://src/core/palette.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# The run's path through its upgrade tree, drawn as the tree itself: a fan of 2, 4, 8
# and 16 dots, one row per depth, so the doubling reads without a number. Every branch
# is a faint line; the picks so far are lit in the class colour and joined; the pair on
# offer pulses; what the pair can still lead to is brighter than what the path has
# already closed off. No words.

const ROW_GAP := 20.0
const DOT := 3.0
const PULSE_HZ := 1.6

var path: Array = []
var offered: Array = []
var class_id := ""
var color := Palette.SAND
var _clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(300.0, ROW_GAP * (UpgradeTree.DEPTHS - 1) + DOT * 6.0)


func set_path(for_class: String, picked: Array, pair: Array, tint: Color) -> void:
	class_id = for_class
	path = picked.map(func(id): return UpgradeTree.index_of(for_class, id))
	offered = pair.map(func(id): return UpgradeTree.index_of(for_class, id))
	color = tint
	queue_redraw()


func drawn_words() -> PackedStringArray:
	return PackedStringArray()


func point_of(index: int) -> Vector2:
	var depth := UpgradeTree.depth_of(index)
	var count := 1 << depth
	var k := index - (count - 2)
	return Vector2((k + 0.5) / float(count) * size.x, DOT * 3.0 + (depth - 1) * ROW_GAP)


# Whether index can still be reached from the offered pair (itself or below it).
func _open(index: int) -> bool:
	var i := index
	while i >= 0:
		if i in offered:
			return true
		i = (i - 2) / 2 if i >= 2 else -1
	return false


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var total := (1 << (UpgradeTree.DEPTHS + 1)) - 2
	for i in range(2, total):
		var parent := (i - 2) / 2
		var lit := parent in path and (i in path or i in offered)
		var tint := color if lit else Color(Palette.SAND, 0.35 if _open(i) else 0.12)
		draw_line(point_of(parent), point_of(i), tint, 2.5 if lit else 1.0)
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * PULSE_HZ)
	for i in total:
		var at := point_of(i)
		if i in path:
			draw_circle(at, DOT + 1.5, color)
		elif i in offered:
			draw_circle(at, DOT + 1.0, Palette.SAND)
			draw_arc(at, DOT + 4.0 + 2.0 * pulse, 0.0, TAU, 16, Color(color, 0.5 + 0.5 * pulse), 2.0)
		else:
			draw_circle(at, DOT * 0.7, Color(Palette.SAND, 0.45 if _open(i) else 0.15))
