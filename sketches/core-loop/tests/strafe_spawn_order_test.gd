extends SceneTree

# A counter's strafe sign without a bot hook comes from its spawn order in the run (a serial
# on world_root), never from its object identity. Two runs with the same spawn sequence must
# strafe identically even when throwaway allocations shift instance IDs between spawns.
# - the sign alternates +1, -1, +1, ... in spawn order, and the serial on world_root counts spawns;
# - a bot_strafe hook keeps its own sign;
# - a counter with no world root falls back to +1;
# - counter.gd no longer reads get_instance_id.

const Counter := preload("res://src/combat/counter.gd")
const T := preload("res://tests/support/t.gd")
const COUNT := 6
const EXPECTED_CHECKS := 8  # content checks before the count check itself, which makes 9 printed lines


func _initialize() -> void:
	var t := T.new("strafe_spawn_order_test")
	var want: Array = []
	for i in COUNT:
		want.append(1.0 if i % 2 == 0 else -1.0)
	var first := _run(0)
	var second := _run(3)
	t.eq("run one strafe signs alternate in spawn order", first["signs"], want)
	t.eq("run one serial counts its spawns", first["serial"], COUNT)
	t.eq("run two strafe signs alternate in spawn order", second["signs"], want)
	t.eq("run two serial counts its spawns", second["serial"], COUNT)
	t.eq("identical spawn sequences strafe identically across runs", second["signs"], first["signs"])

	var bot_root := Node3D.new()
	var bot := Counter.new()
	bot.set_meta("bot_strafe", -1.0)
	bot.setup(null, null, bot_root, Callable(), 1.0, {})
	t.eq("bot_strafe metadata keeps its sign on a serial-zero spawn", bot._strafe, -1.0)
	bot.free()
	bot_root.free()

	var orphan := Counter.new()
	orphan.setup(null, null, null, Callable(), 1.0, {})
	t.eq("null world root falls back to +1", orphan._strafe, 1.0)
	orphan.free()

	var source := FileAccess.get_file_as_string("res://src/combat/counter.gd")
	t.eq("counter.gd does not read get_instance_id", source.contains("get_instance_id"), false)

	t.eq("the content checks above number exactly %d" % EXPECTED_CHECKS, t.checks, EXPECTED_CHECKS)
	var code := t.verdict()
	print("strafe_spawn_order_test: %s" % ("PASS" if code == 0 else "FAIL"))
	quit(code)


# Spawns COUNT counters under one fresh root, allocating `throwaway` objects before each spawn
# so that instance IDs differ between runs.
func _run(throwaway: int) -> Dictionary:
	var root := Node3D.new()
	var signs: Array = []
	var counters: Array = []
	for i in COUNT:
		var junk: Array = []
		for j in throwaway:
			junk.append(Node3D.new())
		var counter := Counter.new()
		counter.setup(null, null, root, Callable(), 1.0, {})
		signs.append(counter._strafe)
		counters.append(counter)
		for node in junk:
			node.free()
	var serial := int(root.get_meta("counter_spawn_serial", -1))
	for counter in counters:
		counter.free()
	root.free()
	return {"signs": signs, "serial": serial}
