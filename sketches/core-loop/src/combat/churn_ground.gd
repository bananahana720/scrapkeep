extends RefCounted

const SpeedTier := preload("res://src/movement/speed_tier.gd")

const CELL := 3.0
const WINDOW := 14.0
const AWAY := 1.5
const DRAG := 0.35
const MAX_LEVEL := 3
const MAX_DISCS := 48
const SILT := Color("3a2f24")

var drag_s := 0.0
var churned_cells := 0

var _ctx
var _clock := 0.0
var _settle_clock := 0.0
var _cells := {}
var _last := Vector2i(1 << 30, 1 << 30)
var _discs := {}


func setup(ctx) -> void:
	_ctx = ctx


func strength() -> float:
	if _ctx == null or _ctx.run == null:
		return 0.0
	return ChallengeDials.by_stage_or("ground.churn_by_stage", int(_ctx.run.stage), 0.0)


func level_at(at: Vector3) -> int:
	var rec: Dictionary = _cells.get(_cell(at), {})
	if rec.is_empty() or _clock - float(rec.last) > WINDOW:
		return 0
	return mini(int(rec.passes) - 1, MAX_LEVEL)


func reset(counts := false) -> void:
	_clear()
	if counts:
		drag_s = 0.0
		churned_cells = 0


func step(delta: float) -> void:
	var k := strength()
	if k <= 0.0 or not _ctx.flow.in_stage():
		return
	_clock += delta
	var player = _ctx.player
	var ball: Vector3 = player.ball_position()
	var cell := _cell(ball)
	var grounded: bool = player.state.on_floor()
	if grounded and cell != _last:
		var rec: Dictionary = _cells.get(cell, {})
		if rec.is_empty() or _clock - float(rec.last) > WINDOW:
			rec = {"passes": 1, "last": _clock, "left": _clock}
		elif _clock - float(rec.left) >= AWAY:
			rec.passes = int(rec.passes) + 1
		_cells[cell] = rec
		if _cells.has(_last):
			_cells[_last].left = _clock
		_last = cell
		_paint(cell, ball)
	if grounded and _cells.has(cell):
		_cells[cell].last = _clock
		_cells[cell].left = _clock
	var level := level_at(ball)
	var v: Vector3 = player.planar_velocity()
	var fast: float = _ctx.tuning.f("cruise") * SpeedTier.MULTIPLES[SpeedTier.FAST]
	if grounded and level > 0 and v.length() < fast:
		player.add_external_accel(-v * DRAG * level * k)
		drag_s += delta
	_settle_clock += delta
	if _settle_clock >= 1.0:
		_settle_clock = 0.0
		_settle()


func _cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / CELL), floori(at.z / CELL))


func _settle() -> void:
	for cell in _cells.keys():
		if _clock - float(_cells[cell].last) > WINDOW:
			_cells.erase(cell)
			_drop_disc(cell)


func _clear() -> void:
	for cell in _discs.keys():
		_drop_disc(cell)
	_cells.clear()
	_last = Vector2i(1 << 30, 1 << 30)


func _paint(cell: Vector2i, ball: Vector3) -> void:
	var level := mini(int(_cells[cell].passes) - 1, MAX_LEVEL)
	if level <= 0:
		return
	if not _discs.has(cell):
		churned_cells += 1
		if _discs.size() >= MAX_DISCS:
			_drop_disc(_discs.keys()[0])
		var disc := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = CELL * 0.62
		mesh.bottom_radius = CELL * 0.62
		mesh.height = 0.04
		mesh.radial_segments = 12
		disc.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		disc.material_override = mat
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_ctx.root.add_child(disc)
		var centre := Vector3((cell.x + 0.5) * CELL, 0.0, (cell.y + 0.5) * CELL)
		var floor_y: float = _ctx.terrain.height(centre.x, centre.z) if _ctx.terrain != null else ball.y - 0.9
		disc.global_position = Vector3(centre.x, floor_y + 0.03, centre.z)
		_discs[cell] = disc
	var mat: StandardMaterial3D = _discs[cell].material_override
	mat.albedo_color = Color(SILT, 0.35 + 0.2 * level)


func _drop_disc(cell: Vector2i) -> void:
	if _discs.has(cell):
		var disc: Node = _discs[cell]
		if is_instance_valid(disc):
			disc.queue_free()
		_discs.erase(cell)
