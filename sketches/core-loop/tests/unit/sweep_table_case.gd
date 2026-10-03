extends RefCounted

const Sweep := preload("res://tools/posture_sweep.gd")
const SliceDefs := preload("res://src/core/slice_defs.gd")

# The posture sweep swaps its own Table into ctx.stages, so the game asks that Table every
# question it would ask the slice table. A lookup the Table lacks crashes stage entry and the
# bot run waits until its wall limit; posture_bands_test then times out instead of failing.
# - the Table answers every static function the slice table has;
# - each forwarded answer equals the slice table's for the slice's stage and world.


func run(t) -> void:
	var table = Sweep.Table.new()
	var slice: Script = SliceDefs
	var missing: Array = []
	for method in slice.get_script_method_list():
		var name: String = method["name"]
		if name.begins_with("_"):
			continue
		if not table.has_method(name):
			missing.append(name)
	t.check("sweep table answers every slice table lookup", missing.is_empty(), "missing %s" % [missing])
	if not missing.is_empty():
		return
	var same: bool = table.world_of(1) == SliceDefs.world_of(1) and table.local(1) == SliceDefs.local(1) \
		and table.first_of(1) == SliceDefs.first_of(1) and table.last_of(1) == SliceDefs.last_of(1) \
		and table.worlds() == SliceDefs.worlds() and table.is_world_last(1) == SliceDefs.is_world_last(1) \
		and table.is_run_last(1) == SliceDefs.is_run_last(1)
	t.check("sweep table's world answers match the slice table", same, "world_of %s local %s worlds %s" % [table.world_of(1), table.local(1), table.worlds()])
