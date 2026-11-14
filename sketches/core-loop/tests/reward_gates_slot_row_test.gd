extends SceneTree

# A park with one gate slot stands more gates in a row centred on it, across its facing (reward_gates.gd
# _slot_plan), not at the ordinary placement. The pit and the sinkhole author one slot; a two-gate
# offer there once used the ordinary placement, and in the sinkhole's bowl every candidate climbs,
# so seed 6 skipper (row 31's run, #351) got gates on the rim 4 m up a bank and stalled in "gates".
# Checked on the real park files, from that ball in the bowl (a fixed plan ignores the ball): two and
# three gates get the slot row; one gate keeps the slot; the pit's row lies across its slot; a
# three-slot park keeps its slots for three gates. Four gates (W1-62: a quick break's arch beside the
# first Warden's hot-wired one) stand on the dam's slot row at its spacing; on a Highdraft island a
# row spot past the slots never stands off the slots' ground (it falls back to the ordinary placement).

const T := preload("res://tests/support/t.gd")
const Terrain := preload("res://src/world/terrain.gd")
const RewardGates := preload("res://src/build/reward_gates.gd")

# The seed 6 opening: the ball on the bowl's south slope after the Warden fight, heading north.
const BOWL_BALL := Vector3(0.226, -101.56, 385.326)
const BOWL_HEADING := Vector3(0.084, 0.0, -0.996)

var t := T.new("reward_gates_slot_row_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var holder := Node3D.new()
	root.add_child(holder)
	# Terrain3D follows the active camera, as the game's; without one it prints an error each run.
	var camera := Camera3D.new()
	holder.add_child(camera)
	camera.make_current()
	var terrain = Terrain.new({"DEFS": [
		{"stage": 1, "world": 2, "map": "park_sinkhole"},
		{"stage": 2, "world": 2, "map": "park_pit"},
		{"stage": 3, "world": 1, "map": "park_dam"},
		{"stage": 4, "world": 3, "map": "park_islands"},
	]})
	terrain.build(holder)
	var gates := RewardGates.new()
	holder.add_child(gates)
	gates.setup(terrain)

	terrain.use(1)
	var slot: Vector2 = terrain.map().gate_slots[0]["at"]
	t.check("the sinkhole authors one gate slot", terrain.map().gate_slots.size() == 1, str(terrain.map().gate_slots))
	var two := _plan(gates, 2, BOWL_BALL, BOWL_HEADING)
	t.check("two gates from the bowl stand on the slot row, not the ordinary placement", two.get("fixed", false), str(two))
	t.check("the row is centred on the slot, 18 m apart across its facing", _row(two, slot, Vector2(1, 0), 18.0), str(two.get("spots")))
	t.check("the row faces the slot's way", two.get("facing", Vector3.ZERO).is_equal_approx(terrain.map().gate_slots[0]["facing"]))
	var climb := -INF
	for at: Vector3 in two.get("spots", []):
		climb = maxf(climb, at.y - terrain.height(slot.x, slot.y))
	t.check("no gate stands above the slot's own ground by more than a metre", climb <= 1.0, "%.2f m" % climb)
	var three := _plan(gates, 3, BOWL_BALL, BOWL_HEADING)
	t.check("three gates make a three-wide row", three.get("fixed", false) and _row(three, slot, Vector2(1, 0), 18.0), str(three.get("spots")))
	var one := _plan(gates, 1, BOWL_BALL, BOWL_HEADING)
	t.check("one gate keeps the slot itself", one.get("fixed", false) and one["spots"].size() == 1
		and _flat(one["spots"][0]).distance_to(slot) < 0.01, str(one.get("spots")))

	terrain.use(2)
	var pit_slot: Vector2 = terrain.map().gate_slots[0]["at"]
	var pit := _plan(gates, 2, Vector3(0.0, -100.0, 255.0), Vector3.FORWARD)
	# The pit's slot faces +z, so its row runs along x.
	t.check("the pit's two gates stand on its slot row", pit.get("fixed", false) and _row(pit, pit_slot, Vector2(-1, 0), 18.0),
		str(pit.get("spots")))

	terrain.use(3)
	var dam_slots: Array = terrain.map().gate_slots
	var dam := _plan(gates, 3, Vector3(0.0, 0.0, 500.0), Vector3.FORWARD)
	var on_slots: bool = dam.get("fixed", false) and dam_slots.size() == 3
	for i in dam_slots.size():
		on_slots = on_slots and _flat(dam["spots"][i]).distance_to(dam_slots[i]["at"]) < 0.01
	t.check("three gates on a three-slot park keep its slots", on_slots, str(dam.get("spots")))
	var four := _plan(gates, 4, Vector3(0.0, 0.0, 500.0), Vector3.FORWARD)
	var step: Vector2 = (dam_slots[1]["at"] as Vector2) - (dam_slots[0]["at"] as Vector2)
	t.check("four gates on the dam stand on its slot row at the slots' spacing", four.get("fixed", false)
		and _row(four, dam_slots[1]["at"], step.normalized(), step.length()), str(four.get("spots")))
	terrain.use(4)
	var isle_slots: Array = terrain.map().gate_slots
	var ground := 0.0
	for isle_slot in isle_slots:
		ground += terrain.height(isle_slot["at"].x, isle_slot["at"].y) / isle_slots.size()
	var isle := _plan(gates, 4, Vector3(0.0, 0.0, 700.0), Vector3.FORWARD)
	var off := []
	if isle.get("fixed", false):
		for at: Vector3 in isle["spots"]:
			if absf(terrain.height(at.x, at.z) - ground) > RewardGates.SLOT_LINE_DROP:
				off.append(at)
	t.check("four gates on an island never stand off the slots' ground", isle.get("spots", []).size() == 4 and off.is_empty(),
		"fixed %s, off %s" % [isle.get("fixed", false), off])

	holder.queue_free()
	await process_frame
	quit(t.verdict())


func _plan(gates, count: int, ball: Vector3, heading: Vector3) -> Dictionary:
	gates._ids = []
	for i in count:
		gates._ids.append("part_%d" % i)
	return gates.choose_placement(ball, heading)


# The spots stand in one row through centre along side, gap apart, in order.
func _row(plan: Dictionary, centre: Vector2, side: Vector2, gap: float) -> bool:
	var spots: Array = plan.get("spots", [])
	if spots.is_empty():
		return false
	for i in spots.size():
		var want := centre + side * (float(i) - (spots.size() - 1) * 0.5) * gap
		if _flat(spots[i]).distance_to(want) > 0.01:
			return false
	return true


static func _flat(at: Vector3) -> Vector2:
	return Vector2(at.x, at.z)
