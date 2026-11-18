extends "res://tools/prim_census_run.gd"

# Observe the same ride, seed and census cadence. The arrays record each gate before
# and after presentation dressing. Sampling does not touch the offers or the gate.
var last := {}
var emitted := false


func _initialize() -> void:
	process_frame.connect(func(): _record("idle_start"))
	super._initialize()


func _physics_process(delta: float) -> bool:
	var result := super._physics_process(delta)
	_record("physics")
	if _ticks == 11961 and emitted:
		quit()
	return result


func _record(sample: String) -> void:
	if _game == null or _game.build == null or _game.build.gates == null:
		return
	var gates: Node3D = _game.build.gates
	if _ticks < 11890 or _ticks > 11960:
		return
	var rows := []
	for gate in gates.get_children():
		if not gate is Node3D:
			continue
		var bare: Array = []
		for geo: MeshInstance3D in gate.find_children("*", "MeshInstance3D", true, false):
			if geo.mesh is PrimitiveMesh and geo.is_visible_in_tree() and geo.layers != 0:
				bare.append(String(geo.mesh.get_class()))
		var nearest := INF
		for offer in gates.offers:
			nearest = minf(nearest, gate.global_position.distance_to(offer.at))
		rows.append({"id": gate.get_instance_id(), "arch": gate.has_node("HeroArch"),
			"topper": gate.has_node("Topper/HeroTopper"), "visible_primitives": bare,
			"queued_free": gate.is_queued_for_deletion(), "offer_error_m": nearest if is_finite(nearest) else null})
	var text := JSON.stringify(rows)
	if text != last.get(sample, "") or _ticks in [11910, 11911, 11912, 11940]:
		print("GATE_TICK ", JSON.stringify({"sample": sample, "tick": _ticks, "stage": _game.run.stage, "gates": rows}))
	last[sample] = text
	emitted = true
