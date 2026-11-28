extends Node3D

const AppShell := preload("res://src/core/app_shell.gd")
const Palette := preload("res://src/core/palette.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Roster := preload("res://src/combat/roster.gd")


const PARTS_MIN := 3
const REST_CLOCK := 1.0
const LOW_PART_CAP := 4
const GRAVITY := 18.0
const SHRINK := 0.5
const SPECK := 0.01
const TICK_STEPS := [0.0, 0.5, 1.0, 0.5]

static var motion_scale := 1.0
static var headless_idle := false

var seconds := 0.5
var style := "scatter"
var t := 0.0
var _pieces: Array = []
var ground := Callable()
var rest := 0.0
const BOUNCE := 0.3
const SKID := 0.55
const SETTLE_SPEED := 0.8
const LAND_REST := 0.9
const SPIN_STILL := 0.01

const TAG_NAME := "ShiftOverTag"
const MAX_TAGS := 8
const TAG_LIFE := 0.9
const TAG_REST := 0.8
const TAG_GRAVITY := 22.0
const TAG_BOUNCE := 0.45
const TAG_SKID := 0.6
const TAG_UP := 7.4
const TAG_OUT := 2.4
const TAG_SPIN := 12.0
const TAG_SIZE := Vector3(0.56, 0.055, 0.32)
const TAG_LIFT := 0.9
static var _tag_mesh: ArrayMesh
static var _tag_material: StandardMaterial3D
static var _live_tags: Array = []
static var _enemy_script: GDScript


class ShiftOverTag extends Node3D:
	var ground := Callable()
	var velocity := Vector3.ZERO
	var spin := Vector3.ZERO
	var spin_scale := 1.0
	var turn := Basis.IDENTITY
	var t := 0.0
	var bounces := 0
	var landed := false
	var _visual: MeshInstance3D
	var _half_thick := 0.06

	func mount_visual(mesh_ref: ArrayMesh, mat_ref: StandardMaterial3D, initial_turn: Basis) -> void:
		turn = initial_turn
		_visual = MeshInstance3D.new()
		_visual.name = "BrassTag"
		_visual.mesh = mesh_ref
		_visual.material_override = mat_ref
		_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_visual.basis = turn
		add_child(_visual)

	func visual_basis() -> Basis:
		return _visual.basis if _visual != null else turn

	func life() -> float:
		return TAG_LIFE + (TAG_REST if ground.is_valid() else 0.0)

	func floor_y() -> float:
		if not ground.is_valid():
			return -INF
		return float(ground.call(global_position.x, global_position.z)) + _half_thick

	func _physics_process(delta: float) -> void:
		t += delta
		var total := life()
		var size := clampf((total - t) / (TAG_LIFE * SHRINK), SPECK, 1.0)
		if not landed and spin_scale > 0.0 and spin.length_squared() > 0.0:
			turn = turn.rotated(spin.normalized(), spin.length() * spin_scale * delta)
		if _visual != null:
			_visual.basis = turn * size
		if not landed:
			velocity.y -= TAG_GRAVITY * delta
			global_position += velocity * delta
			var y_floor := floor_y()
			if global_position.y <= y_floor and velocity.y <= 0.0:
				global_position.y = y_floor
				if velocity.y < -SETTLE_SPEED:
					velocity.y = -velocity.y * TAG_BOUNCE
					velocity.x *= TAG_SKID
					velocity.z *= TAG_SKID
					spin = spin * TAG_SKID if spin.length() * TAG_SKID > SPIN_STILL else Vector3.ZERO
					bounces += 1
				else:
					velocity = Vector3.ZERO
					spin = Vector3.ZERO
					landed = true
					var yaw := atan2(turn.z.x, turn.z.z)
					turn = Basis(Vector3.UP, yaw)
					if _visual != null:
						_visual.basis = turn * size
		if t >= total:
			queue_free()


static func tag_cap() -> int:
	return maxi(1, MAX_TAGS / 2) if GraphicsPreset.current == "low" else MAX_TAGS


static func live_tag_count() -> int:
	_prune_live_tags()
	return _live_tags.size()


static func _prune_live_tags() -> void:
	var kept: Array = []
	for tag in _live_tags:
		if is_instance_valid(tag) and not (tag as Node).is_queued_for_deletion():
			kept.append(tag)
	_live_tags = kept


static func _drop_live_tag(tag: Node) -> void:
	_live_tags.erase(tag)


static func _is_ordinary_kind(kind: String) -> bool:
	if _enemy_script == null:
		_enemy_script = load("res://src/combat/enemy.gd") as GDScript
	return _enemy_script.is_ordinary_kind(kind)


static func _st_quad(st: SurfaceTool, quad: Array, normal: Vector3, color: Color) -> void:
	var a: Vector3 = quad[0]
	var b: Vector3 = quad[1]
	var c: Vector3 = quad[2]
	var d: Vector3 = quad[3]
	var verts := [a, b, c, a, c, d] if (c - a).cross(b - a).dot(normal) > 0.0 else [a, c, b, a, d, c]
	for v in verts:
		st.set_normal(normal)
		st.set_color(color)
		st.add_vertex(v)


static func _st_box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var p := [
		center + Vector3(-h.x, -h.y, -h.z), center + Vector3(h.x, -h.y, -h.z),
		center + Vector3(h.x, h.y, -h.z), center + Vector3(-h.x, h.y, -h.z),
		center + Vector3(-h.x, -h.y, h.z), center + Vector3(h.x, -h.y, h.z),
		center + Vector3(h.x, h.y, h.z), center + Vector3(-h.x, h.y, h.z),
	]
	_st_quad(st, [p[3], p[2], p[6], p[7]], Vector3.UP, color)
	_st_quad(st, [p[0], p[4], p[5], p[1]], Vector3.DOWN, color)
	_st_quad(st, [p[4], p[7], p[6], p[5]], Vector3.BACK, color)
	_st_quad(st, [p[0], p[1], p[2], p[3]], Vector3.FORWARD, color)
	_st_quad(st, [p[1], p[5], p[6], p[2]], Vector3.RIGHT, color)
	_st_quad(st, [p[0], p[3], p[7], p[4]], Vector3.LEFT, color)


static func _st_prism(st: SurfaceTool, center: Vector3, dims: Vector2, color: Color) -> void:
	var radius := dims.x
	var hy := dims.y * 0.5
	var sides := 12
	var top_c := center + Vector3(0.0, hy, 0.0)
	var bot_c := center + Vector3(0.0, -hy, 0.0)
	for i in sides:
		var a0 := TAU * float(i) / float(sides)
		var a1 := TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var t0 := top_c + d0 * radius
		var t1 := top_c + d1 * radius
		var b0 := bot_c + d0 * radius
		var b1 := bot_c + d1 * radius
		var side_n := (d0 + d1).normalized()
		_st_quad(st, [b0, b1, t1, t0], side_n, color)
		for tri in [[top_c, t1, t0, Vector3.UP], [bot_c, b0, b1, Vector3.DOWN]]:
			var v0: Vector3 = tri[0]
			var v1: Vector3 = tri[1]
			var v2: Vector3 = tri[2]
			var n: Vector3 = tri[3]
			var ordered := [v0, v1, v2] if (v2 - v0).cross(v1 - v0).dot(n) > 0.0 else [v0, v2, v1]
			for v in ordered:
				st.set_normal(n)
				st.set_color(color)
				st.add_vertex(v)


static func _build_tag_mesh() -> ArrayMesh:
	if _tag_mesh != null:
		return _tag_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_st_box(st, Vector3.ZERO, TAG_SIZE, Palette.BRASS)
	_st_prism(st, Vector3(-TAG_SIZE.x * 0.32, 0.0, 0.0), Vector2(0.06, TAG_SIZE.y + 0.015), Palette.CHARCOAL)
	_st_box(st, Vector3(TAG_SIZE.x * 0.12, 0.0, 0.0), Vector3(TAG_SIZE.x * 0.44, TAG_SIZE.y + 0.012, TAG_SIZE.z * 0.26), Palette.RUST)
	_tag_mesh = st.commit()
	return _tag_mesh


static func _build_tag_material() -> StandardMaterial3D:
	if _tag_material != null:
		return _tag_material
	_tag_material = Palette.solid(Color.WHITE, 0.0)
	Palette.brass_finish(_tag_material)
	_tag_material.vertex_color_use_as_albedo = true
	return _tag_material


static func pop_shift_tag(enemy: Node3D, kind: String, direction: Vector3, land := Callable()) -> Node3D:
	if enemy == null or enemy.get_parent() == null or not _is_ordinary_kind(kind):
		return null
	_prune_live_tags()
	var cap := tag_cap()
	while _live_tags.size() >= cap:
		var oldest: Node = _live_tags.pop_front()
		if is_instance_valid(oldest) and not oldest.is_queued_for_deletion():
			oldest.queue_free()
	var tag := ShiftOverTag.new()
	tag.name = TAG_NAME
	enemy.get_parent().add_child(tag)
	tag.tree_exiting.connect(_drop_live_tag.bind(tag))
	_live_tags.append(tag)
	var at := enemy.global_position
	tag.global_position = at + Vector3.UP * TAG_LIFT
	var seed_hash := absi(hash(Vector3i(at.round())))
	var angle := TAU * float(seed_hash % 31) / 31.0
	var toss := Vector3(direction.x, 0.0, direction.z)
	toss = toss.normalized() if toss.length_squared() > 0.001 else Vector3(cos(angle), 0.0, sin(angle))
	tag.velocity = toss * TAG_OUT + Vector3.UP * TAG_UP
	var axis := Vector3(-toss.z, 0.35, toss.x).normalized()
	tag.spin = axis * TAG_SPIN
	tag.spin_scale = motion_scale
	tag.mount_visual(_build_tag_mesh(), _build_tag_material(), Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, 0.45))
	if land.is_valid():
		tag.ground = land
	return tag


static func active() -> bool:
	return headless_idle or not AppShell.headless()


static func attack_clock(kind: String, enemy: Object) -> float:
	var spec: Dictionary = WindupRows.ROWS.get(kind, {})
	if spec.is_empty() or spec.attacks.is_empty():
		return REST_CLOCK
	var lead := float(WindupRows.row(kind, enemy, String(spec.attacks.keys()[0])).get("lead_seconds", 0.0))
	return lead if lead > 0.0 else REST_CLOCK


static func idle_offset(idle: Dictionary, clock: float, period: float) -> Vector3:
	var amp := float(idle.get("amplitude", 0.0)) * motion_scale
	if amp <= 0.0 or period <= 0.0:
		return Vector3.ZERO
	var turn := fposmod(clock / period, 1.0)
	var wave := sin(TAU * turn)
	match String(idle.get("style", "")):
		"bob":
			return Vector3(0.0, amp * wave, 0.0)
		"sway":
			return Vector3(amp * wave, 0.0, 0.0)
		"breathe":
			return Vector3(0.0, amp * wave * wave, 0.0)
		"hover":
			return Vector3(amp * 0.6 * cos(TAU * turn), amp * 0.8 * wave, 0.0)
		"tick":
			return Vector3(0.0, amp * float(TICK_STEPS[int(turn * TICK_STEPS.size()) % TICK_STEPS.size()]), 0.0)
	return Vector3.ZERO


static func pose_basis(spec: Dictionary) -> Basis:
	var pose: Dictionary = spec.get("pose", {})
	if pose.is_empty():
		return Basis.IDENTITY
	return Basis(Vector3.RIGHT, -deg_to_rad(float(pose.get("degrees", 0.0))))


const REPEAT_SCALE := 0.6


static func part_count(death: Dictionary) -> int:
	var parts := int(death.get("parts", PARTS_MIN))
	return mini(parts, LOW_PART_CAP) if GraphicsPreset.current == "low" else parts


static func scatter(enemy: Node3D, kind: String, direction: Vector3, land := Callable()) -> Node3D:
	var death: Dictionary = WindupRows.ROWS.get(kind, {}).get("death", {})
	var parent := enemy.get_parent()
	if death.is_empty() or parent == null:
		return null
	var sources := _parts_of(enemy)
	var node: Node3D = (load("res://src/presentation/enemy_motion.gd") as GDScript).new()
	node.name = "DeathScatter"
	node.style = String(death.style)
	node.seconds = float(death.seconds)
	parent.add_child(node)
	var at := enemy.global_position
	node.global_transform = Transform3D(Basis.IDENTITY, at)
	if land.is_valid() and motion_scale > 0.0 and active() and Roster.CHASSIS.get(kind, {}).get("move_class", "") != "airborne":
		node.ground = land
		node.rest = LAND_REST
	var material: Material = null
	if not sources.is_empty():
		material = sources[0]["material"]
	var throw := Vector3(direction.x, 0.0, direction.z)
	throw = throw.normalized() if throw.length_squared() > 0.0001 else Vector3.ZERO
	var count := part_count(death)
	var seed_hash := absi(hash(Vector3i(at.round())))
	for i in count:
		var piece := MeshInstance3D.new()
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle := TAU * (float(i) + float((seed_hash >> (i % 16)) % 7) / 14.0) / float(count)
		var out := Vector3(cos(angle), 0.0, sin(angle))
		node.add_child(piece)
		if sources.size() >= 2:
			var src: Dictionary = sources[i % sources.size()]
			piece.mesh = src["mesh"]
			piece.material_override = src["override"]
			var overrides: Array = src["surfaces"]
			for surface in overrides.size():
				piece.set_surface_override_material(surface, overrides[surface])
			piece.global_transform = src["xform"]
			var again := i / sources.size()
			if again > 0:
				var turn := Basis(out.cross(Vector3.UP).normalized(), PI * 0.5 * float(again) + float(seed_hash % 5) * 0.3)
				var xform: Transform3D = src["xform"]
				piece.basis = turn * xform.basis * REPEAT_SCALE
				piece.global_position = xform.origin + out * 0.3 * float(again)
		else:
			var box := BoxMesh.new()
			box.size = Vector3.ONE * (0.45 - 0.03 * float(i % 4))
			piece.mesh = box
			piece.material_override = BakeLook.unbaked(material)
			piece.position = out * 0.4 + Vector3.UP * 0.6
		node._pieces.append({"node": piece, "velocity": _throw(node.style, out, throw), "spin": out.cross(Vector3.UP) * 6.0, "turn": piece.basis})
	return node


static func _parts_of(enemy: Node3D) -> Array:
	var parts := []
	for found in enemy.find_children("*", "GeometryInstance3D", true, false):
		if not (found as Node3D).is_visible_in_tree():
			continue
		if found is MeshInstance3D and (found as MeshInstance3D).mesh != null:
			var mi := found as MeshInstance3D
			var surfaces := []
			for i in mi.get_surface_override_material_count():
				surfaces.append(mi.get_surface_override_material(i))
			parts.append({"mesh": mi.mesh, "override": mi.material_override, "surfaces": surfaces,
				"material": mi.material_override if mi.material_override != null else mi.get_active_material(0), "xform": mi.global_transform})
		elif found is MultiMeshInstance3D:
			var mmi := found as MultiMeshInstance3D
			var mm := mmi.multimesh
			if mm == null or mm.mesh == null or mm.transform_format != MultiMesh.TRANSFORM_3D or mm.use_colors:
				continue
			for i in mini(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count, mm.instance_count):
				parts.append({"mesh": mm.mesh, "override": mmi.material_override, "surfaces": [],
					"material": mmi.material_override if mmi.material_override != null or mm.mesh.get_surface_count() == 0 else mm.mesh.surface_get_material(0),
					"xform": mmi.global_transform * mm.get_instance_transform(i)})
	return parts


static func _throw(death_style: String, out: Vector3, throw: Vector3) -> Vector3:
	match death_style:
		"collapse":
			return out * 1.2 + throw + Vector3.UP * 0.5
		"spin_down":
			return out * 1.5 + throw * 2.0 + Vector3.UP * 2.0
		"pop":
			return out * 6.0 + throw * 2.0 + Vector3.UP * 3.0
	return out * 3.0 + throw * 4.0 + Vector3.UP * 4.0


func floor_at(piece: MeshInstance3D) -> float:
	if not ground.is_valid():
		return -INF
	var at := global_transform * piece.position
	var low := 0.0
	if piece.mesh != null:
		low = maxf(0.0, -(Transform3D(piece.basis, Vector3.ZERO) * piece.mesh.get_aabb()).position.y)
	return float(ground.call(at.x, at.z)) - global_position.y + low


func life() -> float:
	return seconds + rest


func _physics_process(delta: float) -> void:
	t += delta
	var size := clampf((1.0 - t / life()) / SHRINK, SPECK, 1.0) if rest == 0.0 \
		else clampf((life() - t) / (seconds * SHRINK), SPECK, 1.0)
	for piece in _pieces:
		var mi: MeshInstance3D = piece.node
		var spin: Vector3 = piece.spin * (3.0 if style == "spin_down" else 1.0)
		var turn: Basis = piece.turn
		if spin.length_squared() > 0.0:
			turn = turn.rotated(spin.normalized(), spin.length() * delta)
			piece.turn = turn
		mi.basis = turn * size
		var v: Vector3 = piece.velocity
		v.y -= GRAVITY * delta
		mi.position += v * delta
		var floor_y := floor_at(mi)
		if mi.position.y < floor_y and v.y <= 0.0:
			mi.position.y = floor_y
			v.y = -v.y * BOUNCE if v.y < -SETTLE_SPEED else 0.0
			v.x *= SKID
			v.z *= SKID
			piece.spin = piece.spin * SKID if piece.spin.length() * SKID > SPIN_STILL else Vector3.ZERO
		piece.velocity = v
	if t >= life():
		queue_free()
