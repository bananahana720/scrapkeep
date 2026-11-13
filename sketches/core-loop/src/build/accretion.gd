extends Node3D

const Parts := preload("res://src/build/parts.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const Palette := preload("res://src/core/palette.gd")
const Synergies := preload("res://src/build/synergies.gd")
const TierMark := preload("res://src/build/tier_mark.gd")

# Scrap becomes your build, on the ball. Mass (DEMO-SPEC heft) shows as chunks stuck
# to the surface, and each part as a piece of hardware whose shape says its family and
# whose foot and colour say its rarity (TierMark: none, diamond, star, crown). Spending compacts scrap into a part: the wallet drops
# but mass does not, so a fabricator purchase bolts a part on and takes no chunk off.
# Only a theft (scrap_lost) takes chunks, and they fly off toward the thief. The whole
# shell grows a step per heft class; the collider never does. This node lives under
# the ball's roll_node(), so everything rolls with the surface. It is drawn from
# run.mass, run.parts and the heft class every time, so a retry redraws the restored
# build exactly.
#
# Visual budget: at most MAX_CHUNKS chunks and MAX_PIECES pieces; at heft class V the
# hardware stands at most about 1.1 m off the collider, so the build never hides the
# ball's line or a threat.

const MAX_CHUNKS := 36
const MAX_PIECES := 24
const CHUNK_PER_ROOT_SCRAP := 2.2
const POP_SCALE := 1.9
const POP_RATE := 12.0
# The shell's scale per heft class above I, and how long a stolen chunk flies.
const SHELL_PER_CLASS := 0.07
const FLING_SECONDS := 0.45
# Hoberman shells (ROSTER-LOOK section 5): chunks clamp onto the lattice, a hub or a strut,
# instead of floating in its open gaps, and the gap panels carry the growth read, so the shell
# does not scale per class. The layout mirrors tools/blender/shell_base.lattice_layout() in Godot
# axes (Blender x, y, z is Godot x, z, -y): 12 five-way hubs, 20 three-way hubs, 60 links,
# turned LATTICE_TWIST about the vertical. Chunk centres sit at LATTICE_SEAT, just outside the
# strut mid surface at LATTICE_HUB_RADIUS.
const LATTICE_SHELL_PER_CLASS := 0.0
const LATTICE_TWIST := 72.0 * PI / 180.0
const LATTICE_HUB_RADIUS := 0.9575
const LATTICE_SEAT := 0.99

# The ladder's rung colours on the ball's part pieces, except common: a common piece stays
# copper hardware, so mint (Sable's and the field's) never coats the shell. Rare pieces are
# the cobalt parts that hang on the shell (fleet grade), relics amber.
const RARITY_COLORS := {
	"common": Palette.COPPER,
	"rare": Palette.COBALT,
	# Red is only for what hurts you (DESIGN-V2 section 11).
	"relic": Palette.AMBER,
	"evolved": Palette.ANCIENT,
}
const ICE := Color("c8f0ff")
# One colour per tag, so a synergy's ring says what it is made of.
const TAG_COLORS := {
	"frost": ICE, "arc": Palette.ARC, "kinetic": Palette.COPPER, "split": Palette.SAND,
	"spiral": Palette.AMBER, "chain": Palette.ARC, "anchor": Palette.VERDIGRIS,
	"speed": Palette.AMBER, "mass": Palette.RUST,
}

var _chunks: Array[MeshInstance3D] = []
var _pieces: Array[Node3D] = []
var _shown_parts: Array = []
var _halos := {}
var _chunk_mesh: BoxMesh
var _chunk_material: StandardMaterial3D
var _flung: Array[Dictionary] = []
var _shell_class := 1
# True while the ball wears a Hoberman shell; set_lattice() re-seats the chunks.
var lattice := false
static var _layout := {}


func setup() -> void:
	name = "Accretion"
	_chunk_mesh = BoxMesh.new()
	_chunk_mesh.size = Vector3(0.42, 0.3, 0.5)
	_chunk_material = Palette.solid(Palette.ARC.lerp(Palette.RUST, 0.45), 0.5)


static func chunks_for(mass: float) -> int:
	return mini(MAX_CHUNKS, int(sqrt(maxf(0.0, mass)) * CHUNK_PER_ROOT_SCRAP))


static func shell_scale(heft_class: int, on_lattice := false) -> float:
	var per := LATTICE_SHELL_PER_CLASS if on_lattice else SHELL_PER_CLASS
	return 1.0 + per * float(maxi(1, heft_class) - 1)


func set_lattice(on: bool) -> void:
	lattice = on
	scale = Vector3.ONE * shell_scale(_shell_class, lattice)
	for i in _chunks.size():
		_chunks[i].position = chunk_point(i)


# Where chunk index sits: on the unit-sphere spread, or clamped onto the lattice.
func chunk_point(index: int) -> Vector3:
	var dir := _slot(index, MAX_CHUNKS)
	return lattice_snap(dir) * LATTICE_SEAT if lattice else dir * 1.02


# {hubs: unit directions, five-way first; links: [five-way index, three-way index]}.
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


# The point of the lattice (a hub or a strut's arc) nearest dir, as a unit direction.
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


# Idempotent: draws exactly this mass, part list, synergy set and heft class.
func show_build(mass: float, parts: Array, synergies: Array, heft_class := 1) -> void:
	_shell_class = heft_class
	scale = Vector3.ONE * shell_scale(heft_class, lattice)
	var want := chunks_for(mass)
	while _chunks.size() > want:
		_chunks.pop_back().queue_free()
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


# A theft: the outermost count chunks leave the ball and fly to at (world space) under
# fx_parent, then vanish. The caller redraws after, so the counts stay in step.
func fling(count: int, at: Vector3, fx_parent: Node3D) -> void:
	for i in mini(count, _chunks.size()):
		var chunk: MeshInstance3D = _chunks.pop_back()
		var from := chunk.global_position
		chunk.reparent(fx_parent)
		_flung.append({"node": chunk, "from": from, "to": at, "t": 0.0})


func flung_count() -> int:
	return _flung.size()


# A point on the unit sphere, spread evenly by index (golden-angle spiral), so the same
# index always lands in the same spot.
static func _slot(index: int, count: int, phase := 0.0) -> Vector3:
	var y := 1.0 - (float(index) + 0.5) / float(count) * 2.0
	var r := sqrt(maxf(0.0, 1.0 - y * y))
	var angle := float(index) * 2.39996 + phase
	return Vector3(cos(angle) * r, y, sin(angle) * r)


func _add_chunk(index: int) -> void:
	var chunk := MeshInstance3D.new()
	chunk.mesh = _chunk_mesh
	chunk.material_override = _chunk_material
	var dir := _slot(index, MAX_CHUNKS)
	chunk.position = chunk_point(index)
	chunk.basis = _facing(dir) * Basis(Vector3.UP, float(index) * 1.3)
	chunk.scale = Vector3.ONE * POP_SCALE
	add_child(chunk)
	_chunks.append(chunk)


func _rebuild_pieces(parts: Array) -> void:
	for piece in _pieces:
		piece.queue_free()
	_pieces.clear()
	_shown_parts = parts.duplicate()
	var shown := mini(parts.size(), MAX_PIECES)
	for i in shown:
		var part_id: String = parts[i]
		var piece := _piece(part_id)
		var dir := _slot(i, MAX_PIECES, 1.1)
		piece.position = dir * 1.0
		piece.basis = _facing(dir)
		# The newest piece pops like a chunk does.
		if i == shown - 1:
			piece.scale = Vector3.ONE * POP_SCALE
		add_child(piece)
		_pieces.append(piece)


# A basis whose +Y points out of the ball along dir.
static func _facing(dir: Vector3) -> Basis:
	var up := dir.normalized()
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	side = (side - up * side.dot(up)).normalized()
	return Basis(side, up, side.cross(up))


func _piece(part_id: String) -> Node3D:
	var d: Resource = Parts.def(part_id)
	var family: String = d.family if d != null else "stat"
	# An old id (uncommon, rare_plus) wears the rung it folds into.
	var rarity: String = ItemGen.resolve_rarity(d.rarity) if d != null else ""
	if rarity == "":
		rarity = "common"
	var color: Color = RARITY_COLORS.get(rarity, Palette.COPPER)
	var mat := Palette.solid(color, 1.4 if rarity != "common" else 0.4)
	var root := Node3D.new()
	root.name = "Part_" + part_id
	match part_id:
		"cross_split":
			for yaw in [0.0, PI * 0.5]:
				_box(root, Vector3(0.9, 0.12, 0.16), Vector3(0.0, 0.2, 0.0), mat, yaw)
		"spiral_wave":
			var coil := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.18
			torus.outer_radius = 0.34
			coil.mesh = torus
			coil.material_override = mat
			coil.position = Vector3(0.0, 0.25, 0.0)
			coil.rotation = Vector3(0.4, 0.0, 0.0)
			root.add_child(coil)
		"chain_arc":
			_rod(root, 0.55, mat)
			_ball(root, 0.16, Vector3(0.0, 0.62, 0.0), mat)
		_:
			match family:
				"weapon":
					_rod(root, 0.5, mat)
				"mobility":
					_box(root, Vector3(0.1, 0.55, 0.6), Vector3(0.0, 0.25, 0.0), mat, 0.0)
				"class":
					_rod(root, 0.35, mat, 0.16)
					_ball(root, 0.12, Vector3(0.0, 0.42, 0.0), Palette.solid(color, 3.0))
				"milestone":
					var star := MeshInstance3D.new()
					var gem := SphereMesh.new()
					gem.radius = 0.32
					gem.height = 0.8
					gem.radial_segments = 4
					gem.rings = 2
					star.mesh = gem
					star.material_override = Palette.solid(color, 3.0)
					star.position = Vector3(0.0, 0.35, 0.0)
					root.add_child(star)
				_:
					_disc(root, 0.3, 0.12, Vector3(0.0, 0.05, 0.0), mat)
	var foot := TierMark.foot(rarity, mat)
	if foot != null:
		root.add_child(foot)
	return root


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, yaw: float) -> void:
	var node := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	node.mesh = box
	node.material_override = mat
	node.position = at
	node.rotation = Vector3(0.0, yaw, 0.0)
	parent.add_child(node)


# Round, so a tier foot's points stand clear of it.
func _disc(parent: Node3D, radius: float, thick: float, at: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = thick
	cyl.radial_segments = 16
	node.mesh = cyl
	node.material_override = mat
	node.position = at
	parent.add_child(node)


func _rod(parent: Node3D, length: float, mat: Material, radius := 0.08) -> void:
	var node := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius * 1.3
	cyl.height = length
	node.mesh = cyl
	node.material_override = mat
	node.position = Vector3(0.0, length * 0.5, 0.0)
	parent.add_child(node)


func _ball(parent: Node3D, radius: float, at: Vector3, mat: Material) -> void:
	var node := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	node.mesh = sphere
	node.material_override = mat
	node.position = at
	parent.add_child(node)


# One ring per live synergy, each at its own tilt and radius and coloured by its
# first tag, so up to eight stay separable. Storm Lattice is a gyroscope cage and
# Thermal Shock a thick frosted coil. They roll with the ball, so a synergy is on
# screen all run (the "ring added to the ball" on discovery).
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
	for rot in rings:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = inner
		torus.outer_radius = outer
		ring.mesh = torus
		ring.material_override = mat
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
	for chunk in _chunks:
		if chunk.scale.x > 1.001:
			chunk.scale = chunk.scale.lerp(Vector3.ONE, settle)
	for piece in _pieces:
		if piece.scale.x > 1.001:
			piece.scale = piece.scale.lerp(Vector3.ONE, settle)
