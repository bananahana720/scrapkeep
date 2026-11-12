extends SceneTree

# One effect budget (BACKLOG.md FX-21): fx_budget.gd reads every effect ceiling from its owner and
# sums a world's worst case. This test pins that the ceilings are the ones tuned today (the table
# adds no limit and moves none), that no effect pool sits outside the table, and prints each
# world's worst case so the number is on every run.

const Budget := preload("res://src/presentation/fx_budget.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")
const T := preload("res://tests/support/t.gd")

# The ceilings on cand/w40 f4e04867 (effects-critique.md "How the effects system scales").
const TODAY := {"world_air": 330, "anchors": 760, "hits_and_kills": 752, "machines": 876}

var _t := T.new("fx_budget_test")


func _initialize() -> void:
	_rows()
	_every_pool_has_a_row()
	_beam()
	_worlds()
	quit(_t.verdict())


func _rows() -> void:
	for id in Budget.ROWS:
		var row: Dictionary = Budget.ROWS[id]
		_t.check("%s owner exists" % id, ResourceLoader.exists(row.owner), row.owner)
		_t.check("%s has a unit" % id, row.unit in ["particles", "nodes", "draws"], row.unit)
		if row.has("const"):
			var map: Dictionary = (load(row.owner) as GDScript).get_script_constant_map()
			_t.check("%s reads %s from its owner" % [id, row.const], map.has(row.const), row.owner)
		_t.check("%s has a ceiling" % id, Budget.ceiling(id) > 0, str(Budget.ceiling(id)))
		var scope := String(row.worlds)
		_t.check("%s names a known world scope" % id, scope in ["all", "water"] or scope in Specs.WORLD_SETS.values(), scope)
	for id in TODAY:
		_t.eq("%s ceiling unchanged" % id, Budget.ceiling(id), TODAY[id])


# Every fx_library owner is a budget row, so a new pool cannot sit outside the table.
func _every_pool_has_a_row() -> void:
	var counted := {"vfx": true, "machine": true}
	for id in Budget.ROWS:
		if String(Budget.ROWS[id].get("read", "")) == "library_owner":
			counted[String(Budget.ROWS[id].worlds)] = true
	var loose := []
	for id in FxLibrary.SPECS:
		var owner := String(FxLibrary.SPECS[id].get("owner", "vfx"))
		if not counted.has(owner):
			loose.append("%s (owner %s)" % [id, owner])
	_t.check("every fx_library pool is in the budget", loose.is_empty(), str(loose))


func _beam() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var beam: Node3D = LandmarkBeam.make(parent, Vector3.ZERO, 100.0, 0.0)
	var meshes := beam.find_children("*", "MeshInstance3D", true, false).size()
	_t.eq("the landmark beam draws BEAM_LAYERS meshes", meshes, Budget.BEAM_LAYERS)
	parent.free()


func _worlds() -> void:
	for world in Specs.WORLD_SETS:
		var worst: Dictionary = Budget.worst_case(world)
		var rows := []
		for id in Budget.ROWS:
			if Budget.in_world(id, world):
				rows.append("%s %d" % [id, Budget.ceiling(id)])
		print("world %d worst case: %s (%s)" % [world, worst, ", ".join(rows)])
		_t.check("world %d has a worst case" % world, int(worst.particles) > 0 and int(worst.nodes) > 0 and int(worst.draws) > 0, str(worst))
	var shared := 0
	for id in ["world_air", "anchors", "hits_and_kills", "machines"]:
		shared += Budget.ceiling(id)
	for world in Specs.WORLD_SETS:
		_t.check("world %d particles at least the shared ceilings" % world, int(Budget.worst_case(world).particles) >= shared,
			"%d of %d" % [Budget.worst_case(world).particles, shared])
