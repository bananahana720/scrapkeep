extends Node3D

const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const MathUtil := preload("res://src/core/math_util.gd")
const Synergies := preload("res://src/build/synergies.gd")
const TierMark := preload("res://src/build/tier_mark.gd")
const ModelVariants := preload("res://src/presentation/model_variants.gd")
const CraftedGear := preload("res://src/presentation/crafted_ball_gear.gd")
const InkOutline := preload("res://src/presentation/ink_outline.gd")


const MAX_CHUNKS := 36
const MAX_PIECES := 24
const CHUNK_PER_ROOT_SCRAP := 2.2
const POP_SCALE := 1.9
const POP_RATE := 12.0
const SHELL_PER_CLASS := 0.07
const FLING_SECONDS := 0.45
const LATTICE_SHELL_PER_CLASS := 0.0
const LATTICE_TWIST := 72.0 * PI / 180.0
const LATTICE_HUB_RADIUS := 0.9575
const LATTICE_SEAT := 0.99

const RARITY_COLORS := {
	"common": Palette.COPPER,
	"rare": Palette.COBALT,
	"relic": Palette.AMBER,
	"evolved": Palette.ANCIENT,
}
const ICE := Color("c8f0ff")
const PART_GLB := "res://assets/models/item_parts/part_%s_tripo.glb"
const TAG_COLORS := {
	"frost": ICE, "arc": Palette.ARC, "kinetic": Palette.COPPER, "split": Palette.SAND,
	"spiral": Palette.AMBER, "chain": Palette.ARC, "anchor": Palette.VERDIGRIS,
	"speed": Palette.AMBER, "mass": Palette.RUST,
}

var _chunks: Array[MeshInstance3D] = []
var _pieces: Array[Node3D] = []
var _shown_parts: Array = []
var _halos := {}
var _chunk_mesh: Mesh
var _chunk_material: StandardMaterial3D
var _flung: Array[Dictionary] = []
var _shell_class := 1
var lattice := false
static var _layout := {}
static var _part_meshes := {}


func setup() -> void:
	name = "Accretion"
	_chunk_mesh = CraftedGear.chunk_mesh(0)
	_chunk_material = Palette.solid(Palette.ARC.lerp(Palette.RUST, 0.45), 0.16)
	_chunk_material.metallic = 0.34
	_chunk_material.roughness = 0.62
	_chunk_material.albedo_texture = Palette.painted_texture(128)
	_chunk_material.uv1_triplanar = true
	_chunk_material.uv1_scale = Vector3.ONE * 3.0
	_chunk_material.vertex_color_use_as_albedo = true


static func chunks_for(mass: float) -> int:
	return mini(MAX_CHUNKS, int(sqrt(maxf(0.0, mass)) * CHUNK_PER_ROOT_SCRAP))


static func shell_scale(heft_class: int, on_lattice := false) -> float:
	var per := LATTICE_SHELL_PER_CLASS if on_lattice else SHELL_PER_CLASS
	return 1.0 + per * float(maxi(1, heft_class) - 1)


func set_lattice(on: bool) -> void:
	lattice = on
	scale = Vector3.ONE * shell_scale(_shell_class, lattice)
	for i in _chunks.size():
		var pt := chunk_point(i)
		_chunks[i].position = pt
		_chunks[i].basis = MathUtil.basis_up(pt.normalized()) * Basis(Vector3.UP, float(i) * 1.3)


func chunk_point(index: int) -> Vector3:
	var dir := _slot(index, MAX_CHUNKS)
	if lattice:
		if absf(dir.y) < 0.46:
			var sy := 1.0 if dir.y >= 0.0 else -1.0
			dir = Vector3(dir.x, sy * 0.62, dir.z).normalized()
		if dir.y > 0.0 and absf(dir.z) < 0.58 and absf(dir.x) > 0.36:
			var sz := 1.0 if dir.z >= 0.0 else -1.0
			dir = Vector3(dir.x * 0.42, maxf(dir.y, 0.62), sz * 0.74).normalized()
		return lattice_snap(dir) * LATTICE_SEAT
	return dir * 1.02


static func lattice_layout() -> Dictionary:
	if not _layout.is_empty():
		return _layout
	var zr := 1.0 / sqrt(5.0)
	var rr := 2.0 / sqrt(5.0)
	var five: Array[Vector3] = [Vector3(0, 0, 1)]
	for k in 5:
		var a := LATTICE_TWIST + k * TAU / 5.0
		five.append(Vector3(rr * cos(a), rr * sin(a), zr))
	for k in 5:
		var a := LATTICE_TWIST + PI / 5.0 + k * TAU / 5.0
		five.append(Vector3(rr * cos(a), rr * sin(a), -zr))
	five.append(Vector3(0, 0, -1))
	var edge := INF
	for p in five.slice(1):
		edge = minf(edge, five[0].distance_to(p))
	var linked := {}
	for i in 12:
		for j in range(i + 1, 12):
			if absf(five[i].distance_to(five[j]) - edge) < 0.0001:
				linked[Vector2i(i, j)] = true
	var hubs: Array[Vector3] = []
	for p in five:
		hubs.append(Vector3(p.x, p.z, -p.y))
	var links: Array[Vector2i] = []
	for e: Vector2i in linked:
		for k in range(e.y + 1, 12):
			if linked.has(Vector2i(e.x, k)) and linked.has(Vector2i(e.y, k)):
				var f := hubs.size()
				hubs.append((hubs[e.x] + hubs[e.y] + hubs[k]).normalized())
				links.append_array([Vector2i(e.x, f), Vector2i(e.y, f), Vector2i(k, f)])
	_layout = {"hubs": hubs, "links": links}
	return _layout


static func lattice_snap(dir: Vector3) -> Vector3:
	var d := dir.normalized()
	var layout := lattice_layout()
	var hubs: Array[Vector3] = layout["hubs"]
	var best := hubs[0]
	for link: Vector2i in layout["links"]:
		var a := hubs[link.x]
		var b := hubs[link.y]
		var n := a.cross(b).normalized()
		var q := d - n * d.dot(n)
		var p := a if d.dot(a) > d.dot(b) else b
		if q.length_squared() > 0.000001:
			q = q.normalized()
			if a.cross(q).dot(n) >= 0.0 and q.cross(b).dot(n) >= 0.0:
				p = q
		if p.dot(d) > best.dot(d):
			best = p
	return best


func chunk_count() -> int:
	return _chunks.size()


func piece_count() -> int:
	return _pieces.size()


func halo_visible(synergy_id: String) -> bool:
	return _halos.has(synergy_id) and (_halos[synergy_id] as Node3D).visible


func shell_class() -> int:
	return _shell_class


func show_build(mass: float, parts: Array, synergies: Array, heft_class := 1) -> void:
	_shell_class = heft_class
	scale = Vector3.ONE * shell_scale(heft_class, lattice)
	var want := chunks_for(mass)
	while _chunks.size() > want:
		_chunks.pop_back().queue_free()
	if _chunks.size() < want or parts != _shown_parts:
		set_process(true)
	while _chunks.size() < want:
		_add_chunk(_chunks.size())
	if parts != _shown_parts:
		_rebuild_pieces(parts)
	for key in Synergies.ROWS:
		var halo: Node3D = _halos.get(key)
		if halo == null:
			halo = _build_halo(key)
			_halos[key] = halo
		halo.visible = key in synergies


func fling(count: int, at: Vector3, fx_parent: Node3D) -> void:
	for i in mini(count, _chunks.size()):
		var chunk: MeshInstance3D = _chunks.pop_back()
		var from := chunk.global_position
		chunk.reparent(fx_parent)
		_flung.append({"node": chunk, "from": from, "to": at, "t": 0.0})
	if not _flung.is_empty():
		set_process(true)


func flung_count() -> int:
	return _flung.size()


static func _slot(index: int, count: int, phase := 0.0) -> Vector3:
	var y := 1.0 - (float(index) + 0.5) / float(count) * 2.0
	var r := sqrt(maxf(0.0, 1.0 - y * y))
	var angle := float(index) * 2.39996 + phase
	return Vector3(cos(angle) * r, y, sin(angle) * r)


func _add_chunk(index: int) -> void:
	var chunk := MeshInstance3D.new()
	chunk.mesh = CraftedGear.chunk_mesh(index)
	chunk.material_override = _chunk_material
	chunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pt := chunk_point(index)
	chunk.position = pt
	chunk.basis = MathUtil.basis_up(pt.normalized()) * Basis(Vector3.UP, float(index) * 1.3)
	chunk.scale = Vector3.ONE * POP_SCALE
	InkOutline.apply(chunk, "pilot")
	add_child(chunk)
	_chunks.append(chunk)


func _rebuild_pieces(parts: Array) -> void:
	for piece in _pieces:
		piece.queue_free()
	_pieces.clear()
	_shown_parts = parts.duplicate()
	var chunk_dirs: Array[Vector3] = []
	for chunk in _chunks:
		if is_instance_valid(chunk) and chunk.position.length_squared() > 0.0001:
			chunk_dirs.append(chunk.position.normalized())
	var piece_dirs: Array[Vector3] = []
	var shown := mini(parts.size(), MAX_PIECES)
	for i in shown:
		var part_id: String = parts[i]
		var piece := _piece(part_id)
		for mesh: MeshInstance3D in piece.find_children("*", "MeshInstance3D", true, false):
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var dir := _clear_piece_dir(i, chunk_dirs, piece_dirs)
		piece_dirs.append(dir)
		piece.position = dir * (LATTICE_SEAT if lattice else 0.99)
		piece.basis = MathUtil.basis_up(dir)
		if i == shown - 1:
			piece.scale = Vector3.ONE * POP_SCALE
		add_child(piece)
		_pieces.append(piece)


static func _clear_piece_dir(index: int, chunk_dirs: Array[Vector3], piece_dirs: Array[Vector3]) -> Vector3:
	const CANDIDATES := 144
	var best := Vector3(0.0, 0.80, 0.60).normalized()
	var best_score := 99.0
	for step in CANDIDATES:
		var t := (float(step) + 0.5) / float(CANDIDATES)
		var y := lerpf(0.92, 0.64, t / 0.65) if t < 0.65 else lerpf(-0.64, -0.90, (t - 0.65) / 0.35)
		var r := sqrt(maxf(0.0, 1.0 - y * y))
		var ang := float(step) * 2.39996 + 1.1 + float(index) * 0.37
		var cand := Vector3(cos(ang) * r, y, sin(ang) * r).normalized()
		if cand.y > 0.0 and absf(cand.x) > 0.36:
			continue
		if cand.y < 0.0 and cand.z < -0.28 and cand.y > -0.78:
			continue
		var chunk_dot := -1.0
		for occ in chunk_dirs:
			chunk_dot = maxf(chunk_dot, cand.dot(occ))
		var piece_dot := -1.0
		for p in piece_dirs:
			piece_dot = maxf(piece_dot, cand.dot(p))
		var score := maxf(chunk_dot, piece_dot * 1.18)
		if score < best_score:
			best_score = score
			best = cand
	return best


func _piece(part_id: String) -> Node3D:
	var d: Resource = Parts.def(part_id)
	var family: String = d.family if d != null else "stat"
	var rarity: String = ItemGen.resolve_rarity(d.rarity) if d != null else ""
	if rarity == "":
		rarity = "common"
	var color: Color = RARITY_COLORS.get(rarity, Palette.COPPER)
	var mat := Palette.solid(color, 1.4 if rarity != "common" else 0.4)
	mat.metallic = 0.36
	mat.roughness = 0.60
	mat.albedo_texture = Palette.painted_texture(128)
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3.ONE * 3.0
	mat.vertex_color_use_as_albedo = true
	var root := Node3D.new()
	root.name = "Part_" + part_id
	var own := _own_shape(part_id, mat)
	if own != null:
		root.add_child(own)
		var own_foot := TierMark.foot(rarity, mat)
		if own_foot != null:
			root.add_child(own_foot)
		return root
	var crafted := MeshInstance3D.new()
	crafted.name = "CraftedHardware"
	crafted.mesh = CraftedGear.part_mesh(part_id, family)
	var piece_mat := mat
	if part_id not in ["cross_split", "spiral_wave", "chain_arc"] and family in ["class", "milestone"]:
		piece_mat = Palette.solid(color, 3.0)
		piece_mat.metallic = 0.38
		piece_mat.roughness = 0.54
		piece_mat.albedo_texture = Palette.painted_texture(128)
		piece_mat.uv1_triplanar = true
		piece_mat.uv1_scale = Vector3.ONE * 3.0
		piece_mat.vertex_color_use_as_albedo = true
	crafted.material_override = piece_mat
	root.add_child(crafted)
	InkOutline.apply(crafted, "pilot")
	var foot := TierMark.foot(rarity, mat)
	if foot != null:
		root.add_child(foot)
	return root


static func _own_shape(part_id: String, mat: Material) -> MeshInstance3D:
	var path := ModelVariants.only(PART_GLB % part_id)
	if path == "":
		return null
	if not _part_meshes.has(path):
		var packed := load(path) as PackedScene
		var mesh: Mesh = null
		if packed != null:
			var scene := packed.instantiate()
			var found := scene.find_children("*", "MeshInstance3D", true, false)
			mesh = (found[0] as MeshInstance3D).mesh if found.size() == 1 else null
			scene.free()
		if mesh == null:
			push_error("accretion: %s must load and hold one mesh" % path)
		_part_meshes[path] = mesh
	if _part_meshes[path] == null:
		return null
	var shape := MeshInstance3D.new()
	shape.name = "Own"
	shape.mesh = _part_meshes[path]
	shape.material_override = mat
	return shape


func _build_halo(synergy_id: String) -> Node3D:
	var halo := Node3D.new()
	halo.name = "Halo_" + synergy_id
	var index: int = Synergies.ROWS.keys().find(synergy_id)
	var tag: String = Synergies.ROWS[synergy_id]["tags"][0]
	var mat := Palette.unshaded(TAG_COLORS.get(tag, Palette.SAND))
	var rings: Array = [Vector3(0.35 * index, 0.9 * index, 0.25)]
	var inner := 1.3 + 0.05 * index
	var outer := inner + 0.07
	if synergy_id == "storm_lattice":
		rings = [Vector3.ZERO, Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5)]
	elif synergy_id == "thermal_shock":
		mat = Palette.solid(ICE, 2.0)
		inner = 1.1
		outer = 1.28
	var ring_mesh := CraftedGear.synergy_ring_mesh(inner, outer)
	for rot in rings:
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		ring.material_override = mat
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation = rot
		halo.add_child(ring)
	halo.visible = false
	add_child(halo)
	return halo


func _process(delta: float) -> void:
	var i := _flung.size() - 1
	while i >= 0:
		var fx: Dictionary = _flung[i]
		fx["t"] += delta / FLING_SECONDS
		var node: Node3D = fx["node"]
		if fx["t"] >= 1.0 or not is_instance_valid(node):
			if is_instance_valid(node):
				node.queue_free()
			_flung.remove_at(i)
		else:
			var t: float = fx["t"]
			node.global_position = (fx["from"] as Vector3).lerp(fx["to"], t) + Vector3.UP * 4.0 * t * (1.0 - t)
		i -= 1
	var settle := minf(1.0, POP_RATE * delta)
	var settling := false
	for chunk in _chunks:
		if chunk.scale.x > 1.001:
			chunk.scale = chunk.scale.lerp(Vector3.ONE, settle)
			settling = settling or chunk.scale.x > 1.001
	for piece in _pieces:
		if piece.scale.x > 1.001:
			piece.scale = piece.scale.lerp(Vector3.ONE, settle)
			settling = settling or piece.scale.x > 1.001
	if _flung.is_empty() and not settling:
		set_process(false)
