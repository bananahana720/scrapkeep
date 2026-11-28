extends SceneTree

const ContentRegistry := preload("res://tests/support/content_registry.gd")
const GameEvents := preload("res://src/core/game_events.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const T := preload("res://tests/support/t.gd")

# BUGFIX-CORE F005 (2026-10-09): tree reachability follows the whole heap chain. A blank
# root id cuts off every node below it, grandchildren included, not only its two children.

const TABLE := "upgrade_tree.TREES"

var _t := T.new("content_registry_reach_test")


func _reach_rows(issues: Array, pilot: String) -> Array:
	var rows: Array = []
	for issue in issues:
		if issue.rule == "reachable" and String(issue.row).begins_with(pilot + "/"):
			rows.append(int(String(issue.row).get_slice("/", 1)))
	rows.sort()
	return rows


func _initialize() -> void:
	var tables := ContentRegistry.snapshot()
	var rows: Dictionary = (tables[TABLE] as Dictionary).duplicate(true)
	var pilot = rows.keys()[0]
	var nodes: Array = rows[pilot]
	_t.eq("the shipped tree has no reachability issue", _reach_rows(ContentRegistry.validate_table(TABLE, rows, tables, false), str(pilot)), [])
	nodes[0]["id"] = "  "
	# Every heap descendant of node 0 is cut off; node 1's side stays reachable.
	var below_zero := {0: true}
	var want: Array = []
	for index in range(2, nodes.size()):
		var parent: int = (index - 2) / 2
		if below_zero.has(parent):
			below_zero[index] = true
			want.append(index)
	_t.check("the probe reaches a grandchild", want.has(6), "descendants %s" % [want])
	_t.eq("a blank root cuts off its whole subtree", _reach_rows(ContentRegistry.validate_table(TABLE, rows, tables, false), str(pilot)), want)
	var bus_names: Array = Array(GameEvents.signal_names())
	bus_names.sort()
	var kind_names: Array = EventKinds.ROWS.keys() + EventKinds.LINE_SIGNALS.keys()
	kind_names.sort()
	_t.eq("every GameEvents signal has a matching EventKinds row", bus_names, kind_names)
	var bus_source := FileAccess.get_file_as_string("res://src/core/game_events.gd")
	_t.check("game_events.gd uses no add_user_signal calls", not bus_source.contains("add_user_signal"))
	quit(_t.verdict())
