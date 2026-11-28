extends Node3D


const FoleyAudio := preload("res://src/presentation/foley_audio.gd")
const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const Groups := preload("res://src/core/groups.gd")
const EventGround := preload("res://src/world/events/event_ground.gd")
const CaveIns := preload("res://src/world/events/cave_ins.gd")
const HULL_HEIGHT_M := 2.0
const KINDS := ["fleet_landing", "lift_cage", "zipline_drop"]
const CAGE_HEIGHT_M := 3.6
const SHAFT_DEPTH_M := 6.0
const CAGE_DROP_S := 1.2
const CAGE_CLIMB_FROM := 0.35
const CAGE_SLAM_REACH_M := 3.0
const ZIP_DEFAULT_ANCHOR := [-60.0, 0.0]
const ZIP_DEFAULT_UP_M := 30.0
const ZIP_LAND_UP_M := 2.5
const ZIP_CUT_M := 1.8
const ZIP_IMPACT_EXTRA_M := 6.0
const ZIP_KNOCK := 22.0

var world
var active := {}
var cave_ins
var cages_dropped := 0
var lines_cut := 0
var _sites := {}


func setup(world_ref) -> void:
	world = world_ref
	name = "FleetEvents"
	for site in world.terrain.map().park.park_rows:
		_sites[site.id] = site
	cave_ins = CaveIns.new()
	add_child(cave_ins)
	cave_ins.setup(world)
	var bus = world.ctx.events if "ctx" in world and world.ctx != null else null
	if bus != null and bus.has_signal("slammed"):
		bus.slammed.connect(on_slammed)


func handle(action: String, row: Dictionary, ctx: Dictionary) -> void:
	match row.kind:
		"lift_cage":
			_lift(action, row, ctx)
			return
		"zipline_drop":
			_zipline(action, row, ctx)
			return
		"fleet_landing":
			pass
		_:
			return
	match action:
		"telegraph":
			active[row.id] = {"mark": _vessel(row)}
		"land":
			if not active.has(row.id):
				return
			_set_down(row)
			world.director.activate_home(row.effect.home)
		"end":
			_end(row)


func _vessel(row: Dictionary) -> Node3D:
	var site: Dictionary = _sites[row.site]
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	var base: float = world.terrain.height(at.x, at.y)
	var footprint: Array = row.effect.footprint_m
	var half := Vector2(float(footprint[0]), float(footprint[1])) * 0.5
	var geometry := {"at": Vector3(at.x, base, at.y), "yaw": deg_to_rad(float(site.yaw_deg)), "half": half}
	var rectangle := [Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)]
	var surface = EventGround.project_surface(world, geometry, [rectangle])
	var mark := Node3D.new()
	mark.set_meta("row_id", row.id)
	mark.position = Vector3.UP * base
	var mesh := MeshInstance3D.new()
	mesh.name = "Vessel"
	mesh.mesh = _lowered(surface.mesh, base)
	mesh.material_override = PaletteMaterials.unshaded(Palette.HAZARD)
	mark.add_child(mesh)
	add_child(mark)
	return mark


func _set_down(row: Dictionary) -> void:
	var state: Dictionary = active[row.id]
	var mesh: MeshInstance3D = state.mark.get_node("Vessel")
	mesh.mesh = _hull(mesh.mesh)
	mesh.material_override = PaletteMaterials.unshaded(Palette.SLATE)


func _hull(floor_mesh: ArrayMesh) -> ArrayMesh:
	var floor_vertices: PackedVector3Array = floor_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vertices := PackedVector3Array()
	var up := Vector3.UP * HULL_HEIGHT_M
	for k in range(0, floor_vertices.size(), 3):
		var a := floor_vertices[k]
		var b := floor_vertices[k + 1]
		var c := floor_vertices[k + 2]
		vertices.append_array([c, b, a, a + up, b + up, c + up])
		for edge in [[a, b], [b, c], [c, a]]:
			vertices.append_array([edge[0], edge[1], edge[1] + up, edge[0], edge[1] + up, edge[0] + up])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var hull := ArrayMesh.new()
	hull.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return hull


func _lowered(mesh: ArrayMesh, drop: float) -> ArrayMesh:
	if mesh.get_surface_count() == 0:
		return mesh
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in vertices.size():
		vertices[k] = vertices[k] - Vector3.UP * drop
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var lowered := ArrayMesh.new()
	lowered.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return lowered


func _end(row: Dictionary) -> void:
	if not active.has(row.id):
		return
	active[row.id].mark.free()
	active.erase(row.id)


func _lift(action: String, row: Dictionary, _ctx: Dictionary) -> void:
	match action:
		"telegraph":
			var mark := _vessel(row)
			var cage := _cage(row)
			cage.position = Vector3.DOWN * (CAGE_HEIGHT_M + SHAFT_DEPTH_M)
			mark.add_child(cage)
			active[row.id] = {"kind": row.kind, "mark": mark, "cage": cage, "row": row, "age": 0.0,
				"lead": float(row.telegraph.lead_s), "landed": false, "dropped": false, "drop_age": 0.0}
		"land":
			if not active.has(row.id):
				return
			var state: Dictionary = active[row.id]
			state.landed = true
			state.cage.position = Vector3.ZERO
			state.mark.get_node("Vessel").material_override = PaletteMaterials.unshaded(Palette.SLATE)
			world.director.activate_home(row.effect.home)
			FoleyAudio.one_shot("lift_cage_arrive", self, state.mark.global_position if state.mark.is_inside_tree() else Vector3.ZERO)
		"end":
			_end(row)


func _cage(row: Dictionary) -> Node3D:
	var site: Dictionary = _sites[row.site]
	var footprint: Array = row.effect.footprint_m
	var half := Vector2(float(footprint[0]), float(footprint[1])) * 0.5
	var cage := Node3D.new()
	cage.name = "Cage"
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	cage.set_meta("centre", at)
	var holder := Node3D.new()
	holder.position = Vector3(at.x, 0.0, at.y)
	holder.rotation.y = deg_to_rad(float(site.yaw_deg))
	cage.add_child(holder)
	var steel := PaletteMaterials.solid(Palette.CHARCOAL.lightened(0.15))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_bar(holder, Vector3(0.35, CAGE_HEIGHT_M, 0.35), Vector3(sx * half.x, CAGE_HEIGHT_M * 0.5, sz * half.y), steel)
	for y in [0.1, CAGE_HEIGHT_M]:
		_bar(holder, Vector3(half.x * 2.0, 0.2, 0.3), Vector3(0.0, y, -half.y), steel)
		_bar(holder, Vector3(half.x * 2.0, 0.2, 0.3), Vector3(0.0, y, half.y), steel)
		_bar(holder, Vector3(0.3, 0.2, half.y * 2.0), Vector3(-half.x, y, 0.0), steel)
		_bar(holder, Vector3(0.3, 0.2, half.y * 2.0), Vector3(half.x, y, 0.0), steel)
	_bar(holder, Vector3(half.x * 1.6, 0.12, half.y * 1.6), Vector3(0.0, 0.05, 0.0), PaletteMaterials.solid(Palette.HAZARD, 0.4))
	return cage


func _bar(parent: Node3D, size: Vector3, at: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var bar := MeshInstance3D.new()
	bar.mesh = mesh
	bar.material_override = material
	bar.position = at
	parent.add_child(bar)


func _physics_process(delta: float) -> void:
	for id in active:
		var state: Dictionary = active[id]
		match state.get("kind", ""):
			"lift_cage":
				_step_cage(state, delta)
			"zipline_drop":
				_step_line(state, delta)


func _step_cage(state: Dictionary, delta: float) -> void:
	var cage: Node3D = state.cage
	if state.dropped:
		state.drop_age += delta
		cage.position.y = -lerpf(0.0, CAGE_HEIGHT_M + SHAFT_DEPTH_M, clampf(state.drop_age / CAGE_DROP_S, 0.0, 1.0))
		return
	if state.landed:
		return
	state.age += delta
	var f := smoothstep(CAGE_CLIMB_FROM, 1.0, clampf(state.age / maxf(0.01, state.lead), 0.0, 1.0))
	cage.position.y = -lerpf(CAGE_HEIGHT_M + SHAFT_DEPTH_M, CAGE_HEIGHT_M * 0.25, f)


func on_slammed(at: Vector3, _strength := 0.0, _flatness := 0.0) -> void:
	for id in active:
		var state: Dictionary = active[id]
		if state.get("kind", "") != "lift_cage" or not state.landed or state.dropped:
			continue
		var row: Dictionary = state.row
		var site: Dictionary = _sites[row.site]
		var base: float = world.terrain.height(float(site.at[0]), float(site.at[1]))
		if absf(at.y - base) > CAGE_SLAM_REACH_M + CAGE_HEIGHT_M or not footprint_has(row, Vector2(at.x, at.z)):
			continue
		state.dropped = true
		state.drop_age = 0.0
		cages_dropped += 1
		world.director.break_home(row.effect.home)


func footprint_has(row: Dictionary, point: Vector2) -> bool:
	var site: Dictionary = _sites[row.site]
	var footprint: Array = row.effect.footprint_m
	var local := (point - Vector2(float(site.at[0]), float(site.at[1]))).rotated(deg_to_rad(float(site.yaw_deg)))
	return absf(local.x) <= float(footprint[0]) * 0.5 and absf(local.y) <= float(footprint[1]) * 0.5


func _zipline(action: String, row: Dictionary, _ctx: Dictionary) -> void:
	match action:
		"telegraph":
			var mark := _vessel(row)
			var ends := zip_ends(row)
			var line := _cable(ends[0], ends[1], mark.position.y)
			mark.add_child(line)
			active[row.id] = {"kind": row.kind, "mark": mark, "line": line, "row": row, "age": 0.0,
				"lead": float(row.telegraph.lead_s), "from": ends[0], "to": ends[1], "cut": false, "landed": false, "knocked": 0}
		"land":
			if not active.has(row.id):
				return
			var state: Dictionary = active[row.id]
			state.landed = true
			if state.cut:
				return
			state.line.get_node("Trolley").position = state.to - Vector3.UP * state.mark.position.y
			FoleyAudio.one_shot("zipline_snap", self, state.to)
			state.mark.get_node("Vessel").material_override = PaletteMaterials.unshaded(Palette.SLATE)
			world.director.activate_home(row.effect.home)
			state.knocked = _impact(row, state.to)
		"end":
			_end(row)


func zip_ends(row: Dictionary) -> Array:
	var site: Dictionary = _sites[row.site]
	var at := Vector2(float(site.at[0]), float(site.at[1]))
	var ground: float = world.terrain.height(at.x, at.y)
	var offset: Array = row.effect.get("anchor_m", ZIP_DEFAULT_ANCHOR)
	var up := float(row.effect.get("anchor_up_m", ZIP_DEFAULT_UP_M))
	var to := Vector3(at.x, ground + ZIP_LAND_UP_M, at.y)
	var from := Vector3(at.x + float(offset[0]), ground + up, at.y + float(offset[1]))
	return [from, to]


func _cable(from: Vector3, to: Vector3, base: float) -> Node3D:
	var line := Node3D.new()
	line.name = "Zipline"
	var span := to - from
	var cable := MeshInstance3D.new()
	cable.name = "Cable"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.12, span.length())
	cable.mesh = mesh
	cable.material_override = PaletteMaterials.unshaded(Palette.HAZARD)
	cable.position = (from + to) * 0.5 - Vector3.UP * base
	cable.basis = Basis.looking_at(span.normalized(), Vector3.UP if absf(span.normalized().y) < 0.99 else Vector3.RIGHT)
	line.add_child(cable)
	var trolley := MeshInstance3D.new()
	trolley.name = "Trolley"
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 1.6, 2.4)
	trolley.mesh = box
	trolley.material_override = PaletteMaterials.solid(Palette.RUST)
	trolley.position = from - Vector3.UP * base
	line.add_child(trolley)
	return line


func _step_line(state: Dictionary, delta: float) -> void:
	if state.landed or state.cut:
		return
	state.age += delta
	var f := clampf(state.age / maxf(0.01, state.lead), 0.0, 1.0)
	var trolley: Node3D = state.line.get_node("Trolley")
	var rider: Vector3 = state.from.lerp(state.to, f * f)
	trolley.position = rider - Vector3.UP * state.mark.position.y
	if not state.has("whine") and state.lead - state.age <= FoleyAudio.WHINE_LEAD:
		state.whine = FoleyAudio.player("zipline_whine", trolley)
		if state.whine != null:
			state.whine.play()
	var player = world.ctx.player if "ctx" in world and world.ctx != null else null
	if player == null or not is_instance_valid(player) or player.state.grounded:
		return
	if cuts(state.from, state.to, player.ball_position()):
		cut_line(state)


static func cuts(from: Vector3, to: Vector3, ball: Vector3) -> bool:
	return Geometry3D.get_closest_point_to_segment(ball, from, to).distance_to(ball) <= ZIP_CUT_M


func cut_line(state: Dictionary) -> void:
	if state.cut:
		return
	state.cut = true
	lines_cut += 1
	if state.get("whine") != null and is_instance_valid(state.whine):
		state.whine.stop()
	var trolley_at: Vector3 = state.line.get_node("Trolley").global_position if state.line.is_inside_tree() else state.to
	FoleyAudio.one_shot("zipline_snap", self, trolley_at)
	state.line.get_node("Cable").visible = false
	var trolley: Node3D = state.line.get_node("Trolley")
	trolley.position.y -= 40.0
	world.director.break_home(state.row.effect.home)


func _impact(row: Dictionary, at: Vector3) -> int:
	if not is_inside_tree():
		return 0
	var footprint: Array = row.effect.footprint_m
	var reach := maxf(float(footprint[0]), float(footprint[1])) * 0.5 + ZIP_IMPACT_EXTRA_M
	var knocked := 0
	for enemy in get_tree().get_nodes_in_group(Groups.ENEMY):
		if not is_instance_valid(enemy) or not enemy.has_method("knock"):
			continue
		if enemy.has_method("is_dead") and enemy.is_dead():
			continue
		var out: Vector3 = enemy.global_position - at
		out.y = 0.0
		if out.length() > reach:
			continue
		var dir := out.normalized() if out.length() > 0.1 else Vector3.FORWARD
		enemy.knock(dir + Vector3.UP * 0.3, ZIP_KNOCK)
		knocked += 1
	return knocked


func release() -> void:
	for id in active.keys():
		_end({"id": id, "kind": "fleet_landing"})
	if cave_ins != null:
		cave_ins.release()
	var bus = world.ctx.events if world != null and "ctx" in world and world.ctx != null else null
	if bus != null and bus.has_signal("slammed") and bus.slammed.is_connected(on_slammed):
		bus.slammed.disconnect(on_slammed)
	_sites.clear()
	world = null
