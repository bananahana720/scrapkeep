extends Node3D

const Palette := preload("res://src/core/palette.gd")
const PaletteMaterials := preload("res://src/presentation/palette_materials.gd")
const FlashGuard := preload("res://src/core/flash_guard.gd")


const FLASH_SECONDS := 0.12
const TRACE_DOTS := 14
const TRACE_FROM := Vector3(-70.0, 140.0, -90.0)
const GRIT := 6

var _entries: Array[Dictionary] = []
var _height: Callable
var _stripe: StandardMaterial3D


func setup(height: Callable) -> void:
	_height = height
	_stripe = _stripe_material()


func rebuild(director) -> void:
	clear()
	if director == null:
		return
	for t in director.terrain:
		_entries.append(_build(t))


func clear() -> void:
	for e in _entries:
		(e["root"] as Node3D).queue_free()
	_entries.clear()


func _build(model) -> Dictionary:
	var root := Node3D.new()
	root.name = "Telegraph_" + model.id
	add_child(root)
	var c: Vector2 = model.centre()
	var r: float = model.footprint[0]["radius"]
	var at := Vector3(c.x, float(_height.call(c.x, c.y)) + 0.15, c.y)
	root.position = at
	var keyline := _flat_ring(root, r + 0.25, 0.5, PaletteMaterials.solid(Palette.CHARCOAL), 0.02)
	var edge := _flat_ring(root, r, 0.25, PaletteMaterials.unshaded(Palette.HAZARD), 0.06)
	var fill := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.outer_radius = r
	tm.inner_radius = r - 0.01
	tm.rings = 48
	fill.mesh = tm
	fill.material_override = _stripe
	fill.scale = Vector3(1.0, 0.03, 1.0)
	root.add_child(fill)
	var entry := {"model": model, "root": root, "fill": fill, "torus": tm, "edge": edge, "keyline": keyline, "radius": r,
		"at": at, "flash": 0.0, "was": model.phase, "brackets": [], "dots": [], "chunk": null, "grit": []}
	if model.id == "impact":
		for k in 4:
			entry["brackets"].append(_bracket(root))
		for k in TRACE_DOTS:
			var dot := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			dot.mesh = s
			dot.material_override = PaletteMaterials.unshaded(Palette.HAZARD)
			add_child(dot)
			entry["dots"].append(dot)
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(4.0, 3.0, 3.0)
		chunk.mesh = bm
		chunk.material_override = PaletteMaterials.solid(Palette.VERDIGRIS.lerp(Palette.CHARCOAL, 0.2))
		add_child(chunk)
		entry["chunk"] = chunk
	else:
		for k in GRIT:
			var grit := MeshInstance3D.new()
			var gm := BoxMesh.new()
			gm.size = Vector3(0.5, 0.5, 0.5)
			grit.mesh = gm
			grit.material_override = PaletteMaterials.solid(Palette.SANDSTONE)
			root.add_child(grit)
			entry["grit"].append(grit)
	_show(entry, false)
	return entry


func _process(delta: float) -> void:
	for e in _entries:
		_draw(e, delta)


func _draw(e: Dictionary, delta: float) -> void:
	var model = e["model"]
	if model.phase != e["was"]:
		if e["was"] != model.CHANGED and model.phase == model.CHANGED:
			e["flash"] = FLASH_SECONDS
		e["was"] = model.phase
	var live: bool = model.phase == model.ANNOUNCED or model.phase == model.HOLDING
	e["flash"] = maxf(0.0, e["flash"] - delta)
	var flashing: bool = e["flash"] > 0.0
	_show(e, live or flashing)
	if not (live or flashing):
		return
	var r: float = e["radius"]
	var f: float = 1.0 if flashing else model.fill()
	var tm: TorusMesh = e["torus"]
	tm.inner_radius = clampf(r * (1.0 - f), 0.05, r - 0.05)
	(e["fill"] as MeshInstance3D).material_override = PaletteMaterials.unshaded(Color(Palette.HAZARD, FlashGuard.info(1.0))) if flashing else _stripe
	if model.id == "impact":
		_draw_impact(e, f)
	else:
		for k in (e["grit"] as Array).size():
			var g: MeshInstance3D = e["grit"][k]
			var a := TAU * k / GRIT
			var fall := fposmod(Time.get_ticks_msec() / 1000.0 * 1.6 + k * 0.37, 1.0)
			g.position = Vector3(cos(a) * r * 0.6, 9.0 * (1.0 - fall), sin(a) * r * 0.6)


func _draw_impact(e: Dictionary, f: float) -> void:
	var r: float = e["radius"]
	var reach := r * (1.0 + 1.2 * (1.0 - f))
	for k in 4:
		var b: Node3D = e["brackets"][k]
		var a := PI * 0.25 + k * PI * 0.5
		b.position = Vector3(cos(a), 0.0, sin(a)) * reach
		b.rotation.y = -a
	var at: Vector3 = e["at"]
	var from := at + TRACE_FROM
	var dots: Array = e["dots"]
	for k in dots.size():
		var s := float(k + 1) / (dots.size() + 1)
		var dot: MeshInstance3D = dots[k]
		dot.position = _trace(from, at, s)
		dot.visible = s <= f + 0.1
	var chunk: MeshInstance3D = e["chunk"]
	chunk.visible = f >= 0.75
	chunk.position = _trace(from, at, clampf((f - 0.75) / 0.25, 0.0, 0.97))


static func _trace(from: Vector3, to: Vector3, s: float) -> Vector3:
	var p := from.lerp(to, s)
	p.y += sin(s * PI) * 20.0
	return p


func _show(e: Dictionary, on: bool) -> void:
	for key in ["fill", "edge", "keyline"]:
		(e[key] as Node3D).visible = on
	for b in e["brackets"]:
		b.visible = on
	for d in e["dots"]:
		d.visible = on and d.visible
	if e["chunk"] != null:
		e["chunk"].visible = on and e["chunk"].visible
	for g in e["grit"]:
		g.visible = on


static func _flat_ring(parent: Node3D, radius: float, width: float, mat: Material, lift: float) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.outer_radius = radius + width * 0.5
	t.inner_radius = radius - width * 0.5
	t.rings = 48
	ring.mesh = t
	ring.material_override = mat
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position = Vector3.UP * lift
	parent.add_child(ring)
	return ring


static func _bracket(parent: Node3D) -> Node3D:
	var node := Node3D.new()
	for side in [Vector3(2.0, 0.0, 0.0), Vector3(0.0, 0.0, 2.0)]:
		var under := MeshInstance3D.new()
		var um := BoxMesh.new()
		um.size = Vector3(0.5, 0.1, 0.5) + side * 2.0
		under.mesh = um
		under.material_override = PaletteMaterials.solid(Palette.CHARCOAL)
		under.position = side
		node.add_child(under)
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 0.14, 0.3) + side * 2.0
		bar.mesh = bm
		bar.material_override = PaletteMaterials.unshaded(Palette.HAZARD)
		bar.position = side + Vector3.UP * 0.04
		node.add_child(bar)
	node.rotation.y = 0.0
	parent.add_child(node)
	return node


static func _stripe_material() -> StandardMaterial3D:
	var image := Image.create_empty(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var on := int((x + y) / 16) % 2 == 0
			var c := Palette.HAZARD if on else Palette.CHARCOAL
			image.set_pixel(x, y, Color(c, 0.35 if on else 0.3))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(image)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(1.0, 1.0, 1.0)
	return mat
