extends SceneTree

const T := preload("res://tests/support/t.gd")
const Accretion := preload("res://src/build/accretion.gd")
const Parts := preload("res://src/build/parts.gd")
const Synergies := preload("res://src/build/synergies.gd")
const ScrapField := preload("res://src/build/scrap_field.gd")
const Panels := preload("res://src/build/panels.gd")
const WardenRing := preload("res://src/presentation/warden_ring.gd")

const MAX_PRIM_TRIANGLES := 768

var _t := T.new("w45_perf_gpu_unit1_test")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_accretion()
	_check_scrap_field()
	_check_warden_ring()
	quit(_t.verdict())


func _meshes(node: Node) -> Array:
	return node.find_children("*", "MeshInstance3D", true, false)


func _shadowed(node: Node) -> Array:
	return _meshes(node).filter(func(m: MeshInstance3D) -> bool:
		return m.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).map(func(m: MeshInstance3D) -> String:
		return str(m.get_path()) if m.is_inside_tree() else String(m.name))


func _heavy(node: Node) -> Array:
	var out := []
	for m: MeshInstance3D in _meshes(node):
		if m.mesh is PrimitiveMesh and m.mesh.get_faces().size() / 3 > MAX_PRIM_TRIANGLES:
			out.append("%s %s %d" % [m.name, m.mesh.get_class(), m.mesh.get_faces().size() / 3])
	return out


func _settle(acc: Node3D) -> int:
	var frames := 0
	while acc.is_processing() and frames < 600:
		acc._process(1.0 / 60.0)
		frames += 1
	return frames


func _check_accretion() -> void:
	var ids: Array = Parts.rows().keys()
	for id in Parts.EVOLVED:
		if not id in ids:
			ids.append(id)
	for want in ["spiral_wave", "chain_arc", "cross_split"]:
		_t.check("%s is a part" % want, want in ids)
	var acc := Accretion.new()
	acc.setup()
	root.add_child(acc)
	var bad_shadow := []
	var heavy := []
	var feet := {}
	var start := 0
	var batch: Array = []
	while start < ids.size():
		batch = ids.slice(start, start + Accretion.MAX_PIECES)
		acc.show_build(100.0, batch, Synergies.ROWS.keys(), 3)
		bad_shadow.append_array(_shadowed(acc))
		heavy.append_array(_heavy(acc))
		for foot in acc.find_children("Foot_*", "Node3D", true, false):
			feet[String(foot.name)] = true
		start += Accretion.MAX_PIECES
	_t.check("every part, chunk and halo was drawn", acc.chunk_count() > 0 and acc.piece_count() > 0 \
			and Synergies.ROWS.keys().all(func(k: String) -> bool: return acc.halo_visible(k)))
	_t.check("relic and evolved feet were drawn", feet.has("Foot_star") and feet.has("Foot_crown"), str(feet.keys()))
	_t.check("no build mesh casts a shadow", bad_shadow.is_empty(), str(bad_shadow.slice(0, 8)))
	_t.check("no build primitive past %d triangles" % MAX_PRIM_TRIANGLES, heavy.is_empty(), str(heavy.slice(0, 8)))

	var frames := _settle(acc)
	_t.check("accretion sleeps once its pops settle", not acc.is_processing() and frames > 1 and frames < 600, "frames %d" % frames)
	for node: Node3D in acc.get_children():
		if not node.is_queued_for_deletion() and (node is MeshInstance3D or node.name.begins_with("Part_")):
			if node.scale.x > 1.001:
				_t.check("settled piece at rest scale", false, "%s %s" % [node.name, node.scale])
				break
	acc.show_build(100.0, batch, Synergies.ROWS.keys(), 3)
	_t.check("an unchanged redraw leaves it asleep", not acc.is_processing())
	acc.show_build(400.0, batch, Synergies.ROWS.keys(), 3)
	_t.check("a new chunk wakes it", acc.is_processing())
	_settle(acc)
	acc.show_build(400.0, ids.slice(0, Accretion.MAX_PIECES), Synergies.ROWS.keys(), 3)
	_t.check("a rebuilt piece list wakes it", acc.is_processing())
	_settle(acc)
	var fx := Node3D.new()
	root.add_child(fx)
	acc.fling(3, Vector3(20.0, 0.0, 0.0), fx)
	_t.check("a fling wakes it", acc.is_processing() and acc.flung_count() == 3)
	frames = _settle(acc)
	_t.check("the flung chunks land and it sleeps again", acc.flung_count() == 0 and not acc.is_processing(), "frames %d flung %d" % [frames, acc.flung_count()])
	acc.free()
	fx.free()


func _check_scrap_field() -> void:
	var field := ScrapField.new()
	field.setup()
	root.add_child(field)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var far := Vector3(ScrapField.SPIN_RANGE + 80.0, 0.0, 0.0)
	field.drop(Vector3.ZERO, 3, rng)
	field.drop(far, 3, rng)
	var panel_id: String = Panels.ROWS.keys()[0]
	field.drop_panel(Vector3(0.0, 0.0, 4.0), panel_id, false, false)
	field.drop_panel(far + Vector3(0.0, 0.0, 10.0), panel_id, false, true)
	field.drop_recovery(null, far, Vector3.FORWARD, 6, 2, rng)
	_t.check("no pickup, column or cluster casts a shadow", _shadowed(field).is_empty(), str(_shadowed(field)))

	var near_items: Array = []
	var far_items: Array = []
	for item: MeshInstance3D in field.get_children():
		(far_items if item.position.distance_to(Vector3.ZERO) > ScrapField.SPIN_RANGE else near_items).append(item)
	var far_before := far_items.map(func(item: Node3D) -> Vector3: return item.rotation)
	var near_before := near_items.map(func(item: Node3D) -> Vector3: return item.rotation)
	var ball := Vector3(0.0, 0.0, -40.0)
	field.step(ball, 0.0, 0.1)
	var near_turned := range(near_items.size()).all(func(i: int) -> bool:
		return not (near_items[i] as Node3D).rotation.is_equal_approx(near_before[i]))
	var far_held := range(far_items.size()).all(func(i: int) -> bool:
		return (far_items[i] as Node3D).rotation.is_equal_approx(far_before[i]))
	_t.check("near pickups turn", near_items.size() == 4 and near_turned, "%d near" % near_items.size())
	_t.check("pickups past SPIN_RANGE hold still", far_items.size() >= 5 and far_held, "%d far" % far_items.size())

	var taken := 0
	var panels := 0
	for i in 120:
		taken += field.step(Vector3.ZERO, 0.0, 1.0 / 30.0).size()
		panels += field.panel_takes.size()
	_t.check("near scrap and the near panel still home in and land", taken == 3 and panels == 1, "taken %d panels %d" % [taken, panels])
	_t.check("far pickups stay on the field", field.count() == 3 + field.recovery_count() and field.panel_count() == 1)
	var expired := 0
	for i in 6:
		field.step(Vector3.ZERO, 0.0, ScrapField.RECOVERY_LIFE / 4.0)
		expired += field.expired_values.size()
	_t.check("a far recovery cluster still expires", expired == 2 and field.recovery_count() == 0, "expired %d" % expired)
	field.free()


func _check_warden_ring() -> void:
	var warden := Node3D.new()
	var ring := WardenRing.new()
	ring.bind(warden)
	var marks := _meshes(ring)
	_t.eq("the ring draws fourteen floor marks", marks.size(), 14)
	_t.check("no floor mark casts a shadow", _shadowed(ring).is_empty(), str(_shadowed(ring)))
	ring.free()
	warden.free()
