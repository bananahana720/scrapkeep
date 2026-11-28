extends SceneTree

# One effect budget (BACKLOG.md FX-21): fx_budget.gd reads every effect ceiling from its owner and
# sums a world's worst case. This test pins that the ceilings are the ones tuned today (the table
# adds no limit and moves none), that no effect pool sits outside the table, and prints each
# world's worst case so the number is on every run.

const Budget := preload("res://src/presentation/fx_budget.gd")
const Specs := preload("res://src/presentation/world_fx/world_fx_specs.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const LandmarkBeam := preload("res://src/presentation/landmark_beam.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const ChargeHalo := preload("res://src/presentation/charge_halo.gd")
const T := preload("res://tests/support/t.gd")

# The ceilings on cand/w40 f4e04867 (effects-critique.md "How the effects system scales"), with
# hits and kills raised from 752 to 800 by FX-01's kill_shards pool (3 x 16) on stage/alpha-w40.
# A ceiling that moves on purpose moves here in the same change.
const TODAY := {"world_air": 330, "anchors": 760, "hits_and_kills": 800, "machines": 876}
# The weapon effects of wave 46 (3D blueprint sections 3.2 and 3.3), every unit each one costs.
const WEAPON_TODAY := {"sable_charge": {"particles": 12, "draws": 2}, "rivet_fire": {"draws": 2, "nodes": 8}}

var _t := T.new("fx_budget_test")


func _initialize() -> void:
	_rows()
	_every_pool_has_a_row()
	_beam()
	_weapons()
	_counted_in_source()
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
		for unit in row.get("more", {}):
			var consts: Dictionary = (load(row.owner) as GDScript).get_script_constant_map()
			_t.check("%s reads its %s from %s" % [id, unit, row.more[unit]], unit in ["particles", "nodes", "draws"] and unit != row.unit
				and consts.has(row.more[unit]), row.owner)
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
	_t.eq("the landmark beam draws BEAM_LAYERS meshes", meshes, LandmarkBeam.BEAM_LAYERS)
	parent.free()


# The weapon rows read what the owners build: a standing ChargeHalo carries SPARKS particles and DRAWS
# meshes (the halo and the ring MultiMesh, which holds RINGS), and each world's worst case counts them.
func _weapons() -> void:
	for id in WEAPON_TODAY:
		_t.eq("%s ceilings unchanged" % id, Budget.ceilings(id), WEAPON_TODAY[id])
	var halo: Node3D = ChargeHalo.new()
	root.add_child(halo)
	var sparks := halo.find_children("*", "GPUParticles3D", true, false)
	_t.check("the halo builds one spark emitter of SPARKS", sparks.size() == 1 and sparks[0].amount == ChargeHalo.SPARKS, str(sparks.size()))
	var meshes := halo.find_children("*", "MeshInstance3D", true, false).size() + halo.find_children("*", "MultiMeshInstance3D", true, false).size()
	_t.eq("the halo builds DRAWS meshes", meshes, ChargeHalo.DRAWS)
	var rings: Array = halo.find_children("ReleaseRings", "MultiMeshInstance3D", true, false)
	_t.check("the release rings are one MultiMesh of RINGS", rings.size() == 1 and rings[0].multimesh.instance_count == ChargeHalo.RINGS)
	halo.free()
	var without := {"particles": 0, "nodes": 0, "draws": 0}
	for id in Budget.ROWS:
		if Budget.in_world(id, 1) and not Budget.ROWS[id].has("per") and not WEAPON_TODAY.has(id):
			without[Budget.ROWS[id].unit] += Budget.ceiling(id)
	var worst: Dictionary = Budget.worst_case(1)
	_t.check("world 1's worst case counts the weapon rows in every unit", int(worst.particles) == int(without.particles) + 12
		and int(worst.draws) == int(without.draws) + 4 and int(worst.nodes) == int(without.nodes) + 8, "%s vs %s" % [worst, without])


# The counts the owners build in code: the sparkle cap is the top of vfx.gd's clampi on the scrap
# sparkle, a thermal builds THERMAL_VIEWS multimeshes, and each scenery build batches one WaterMist.
func _counted_in_source() -> void:
	var vfx := FileAccess.get_file_as_string("res://src/presentation/vfx.gd")
	_t.check("vfx.gd caps a sparkle at SPARKLE_MAX", vfx.contains("p.amount = clampi(6 + amount * 2, 6, SPARKLE_MAX)") and Vfx.SPARKLE_MAX == 20, str(Vfx.SPARKLE_MAX))
	_t.eq("the sparkle ceiling is SPARKLE_POOL emitters of SPARKLE_MAX", Budget.ceiling("sparkles"), Vfx.SPARKLE_POOL * Vfx.SPARKLE_MAX)
	_t.eq("the kill burst ceiling is Vfx.burst_ceiling()", Budget.ceiling("kill_bursts"), Vfx.burst_ceiling())
	var hd := FileAccess.get_file_as_string("res://src/presentation/highdraft_fx.gd")
	_t.check("a thermal builds THERMAL_VIEWS multimeshes", hd.contains("for kind in %d:" % Budget.THERMAL_VIEWS) and hd.contains("MultiMeshInstance3D.new()"), "highdraft_fx.gd _thermal")
	var scenery := FileAccess.get_file_as_string("res://src/presentation/spillway_scenery.gd")
	var builds := 0
	var most := 0
	for part in scenery.split("\nstatic func "):
		var n := part.count("\"WaterMist\", puff")
		most = maxi(most, n)
		builds += n
	_t.check("each scenery build batches at most one WaterMist", most == 1 and builds >= 1, "%d batches, at most %d per build" % [builds, most])
	# Every world_fx burst hook effect is a burst spec, so BURST_POOL covers it.
	for hook in Specs.HOOKS:
		for fx_id in Specs.HOOKS[hook].effects:
			_t.check("hook %s effect %s is a spec" % [hook, fx_id], Specs.SPECS.has(fx_id), fx_id)


func _worlds() -> void:
	for world in Specs.WORLD_SETS:
		var worst: Dictionary = Budget.worst_case(world)
		var rows := []
		for id in Budget.ROWS:
			if Budget.in_world(id, world):
				rows.append("%s %d" % [id, Budget.ceiling(id)])
		print("world %d worst case: %s (%s); per placed thing %s" % [world, worst, ", ".join(rows), Budget.per_thing(world)])
		_t.check("world %d has a worst case" % world, int(worst.particles) > 0 and int(worst.nodes) > 0 and int(worst.draws) > 0, str(worst))
	var shared := 0
	for id in ["world_air", "anchors", "hits_and_kills", "machines", "player_layer", "kill_bursts"]:
		shared += Budget.ceiling(id)
	for world in Specs.WORLD_SETS:
		_t.check("world %d particles at least the shared ceilings" % world, int(Budget.worst_case(world).particles) >= shared,
			"%d of %d" % [Budget.worst_case(world).particles, shared])
