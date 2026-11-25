extends Node3D

const YARD_PATH := "ArenaBowlDress/FleetYard"
const FANS := "CrewFans"
const CLASH_SECONDS := 1.0
const CLASH_FREEZE := 2.0 / 60.0
const FREEZE_FACT := "posture_break"
const CLASH_HOLD := 0.6
const CLASH_SHAKE_HZ := 4.0
const CLASH_SWING := 0.22
const SCORE_SECONDS := 0.8
const SCORE_LIFT := 0.6
const SCORE_LIFT_PER_LINK := 0.07
const SCORE_LINKS_CAP := 6
const PEEK_AT := 60.0 / 129.0
const ROUT_SECONDS := 2.6
const BLEND := 0.12

const REST := Vector3(0.76, 0.85, 0.12)
const LEAN := 0.35
const UP := Vector3(0.3, 2.0, 0.2)
const OVERHEAD := Vector3(0.15, 2.45, 0.0)
const IMPACT_SCALE := 1.35
const HIDE := Vector3(0.8, 1.15, 0.0)
const PEEK := Vector3(0.8, 0.86, 0.0)
const BOARD := Vector3(0.035, 0.62, 0.48)
const SHEET := Vector2(0.52, 0.40)
const CLIP := Vector3(0.06, 0.07, 0.16)
const BOARD_COLOUR := Color("3a2e24")
const SHEET_COLOUR := Color("e8dcc0")
const CLIP_COLOUR := Color("b08d3c")

var boards: MultiMeshInstance3D
var _fans: MultiMeshInstance3D
var _yard: Node
var _rests: Array[Transform3D] = []
var _delays := PackedFloat32Array()
var _posed: Array[Transform3D] = []
var _beat := {}
var _clock := 0.0
var _links := 0
var _freeze := Callable()
var _freeze_pending := false


static func build(arena: Node3D) -> Node3D:
	var yard := arena.get_node_or_null(YARD_PATH)
	var fans := yard.get_node_or_null(FANS) as MultiMeshInstance3D if yard != null else null
	if fans == null or fans.multimesh == null:
		return null
	var crew := new()
	crew.name = "StandCrew"
	crew._seat(arena, yard, fans)
	arena.add_child(crew)
	return crew


static func bind_bowl(arena: Node3D) -> void:
	var crew = arena.get_node_or_null("StandCrew")
	var game := arena.get_parent()
	if crew == null or game == null:
		return
	var presentation = game.get("presentation")
	var juice = presentation.get("juice") if presentation != null else null
	crew.bind(game.get("events"), Callable(juice, "request_hit_stop") if juice != null else Callable())


func bind(events, freeze: Callable) -> void:
	_freeze = freeze
	set_process(false)
	if events == null:
		return
	events.boss_phase_changed.connect(_on_phase)
	events.boss_attack_telegraphed.connect(_on_tell.unbind(2))
	events.attack_cued.connect(_on_tell.unbind(3))
	events.line_state_changed.connect(_on_line)
	events.boss_defeated.connect(_on_rout)
	events.fight_phase_changed.connect(_wake.unbind(3))
	events.boss_weak_point_hit.connect(_wake.unbind(1))


func reacting() -> String:
	return String(_beat.get("kind", "")) if _live() else ""


func board_count() -> int:
	return boards.multimesh.instance_count if boards != null else 0


func board_transform(i: int) -> Transform3D:
	return boards.transform * _posed[i]


func held(i: int) -> Transform3D:
	return _held(_clock - float(_beat.get("start", 0.0)), i)


func _seat(arena: Node3D, yard: Node, fans: MultiMeshInstance3D) -> void:
	set_process(false)
	_yard = yard
	_fans = fans
	var seats: Array = yard.seats[yard.crowds.find(fans)]
	var count := seats.size()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _board_mesh()
	multi.instance_count = count
	_delays.resize(count)
	_posed.resize(count)
	for i in count:
		_rests.append(seats[i].rest)
		_delays[i] = float(seats[i].delay)
	boards = MultiMeshInstance3D.new()
	boards.name = "CrewClipboards"
	boards.multimesh = multi
	boards.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	boards.transform = _frame_of(fans, arena)
	add_child(boards)
	_pose_all()


static func _frame_of(fans: Node3D, arena: Node3D) -> Transform3D:
	var xf := fans.transform
	var node := fans.get_parent() as Node3D
	while node != null and node != arena:
		xf = node.transform * xf
		node = node.get_parent() as Node3D
	return xf


func _board_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_box(st, Vector3.ZERO, BOARD, BOARD_COLOUR)
	_box(st, Vector3(BOARD.x * 0.5 + 0.004, -0.03, 0.0), Vector3(0.004, SHEET.x, SHEET.y), SHEET_COLOUR)
	_box(st, Vector3(BOARD.x * 0.5 + 0.02, BOARD.y * 0.5 - 0.04, 0.0), CLIP, CLIP_COLOUR)
	st.generate_normals()
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	mesh.surface_set_material(0, mat)
	return mesh


func _box(st: SurfaceTool, centre: Vector3, size: Vector3, colour: Color) -> void:
	st.set_color(colour)
	var h := size * 0.5
	var corners := []
	for k in 8:
		corners.append(centre + Vector3(h.x if k & 1 else -h.x, h.y if k & 2 else -h.y, h.z if k & 4 else -h.z))
	for face in [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		for p in [a, b, c, a, c, d]:
			st.add_vertex(p)


func _on_phase(phase: int, _name: String) -> void:
	_links = 0
	if phase <= 1:
		return
	_start("clash")
	_freeze_pending = true
	_send_freeze.call_deferred()


func _on_tell() -> void:
	_freeze_pending = false


func _send_freeze() -> void:
	if not _freeze_pending or not is_inside_tree():
		return
	_freeze_pending = false
	for node in get_tree().get_nodes_in_group("threat"):
		if not node.is_queued_for_deletion():
			return
	if _freeze.is_valid():
		_freeze.call(CLASH_FREEZE, FREEZE_FACT)


func _on_line(state: String, _target: Node3D, _at: Vector3, _cause: String) -> void:
	match state:
		"chain_link":
			_links += 1
			if _links >= 2:
				_start("score", mini(_links, SCORE_LINKS_CAP))
		"chain_end":
			_links = 0


func _on_rout() -> void:
	_links = 0
	_start("rout")


const RANK := {"score": 0, "clash": 1, "rout": 2}


func _start(kind: String, links := 0) -> void:
	if _live() and int(RANK[_beat.kind]) > int(RANK[kind]):
		return
	_beat = {"kind": kind, "start": _clock, "links": links}
	set_process(true)


func _wake() -> void:
	set_process(true)


func _live() -> bool:
	return not _beat.is_empty() and _clock - float(_beat.start) < _length(String(_beat.kind))


func _length(kind: String) -> float:
	match kind:
		"clash":
			return CLASH_SECONDS
		"score":
			return SCORE_SECONDS + _yard.WAVE_SECONDS
		_:
			return ROUT_SECONDS


func _process(delta: float) -> void:
	_clock += delta
	_pose_all()
	if not _live():
		_beat = {}
		if _yard.cheering() == "":
			set_process(false)


func _pose_all() -> void:
	var multimesh := boards.multimesh
	var hopping: bool = _yard.cheering() != ""
	var t := _clock - float(_beat.get("start", 0.0))
	for i in multimesh.instance_count:
		var fan: Transform3D = _fans.multimesh.get_instance_transform(i) if hopping else _rests[i]
		_posed[i] = fan * _held(t, i)
		multimesh.set_instance_transform(i, _posed[i])


func _held(t: float, i: int) -> Transform3D:
	var rest := _at(REST, LEAN)
	if not _live():
		return rest
	match String(_beat.kind):
		"clash":
			var swing := CLASH_SWING * sin(TAU * CLASH_SHAKE_HZ * t + i) * maxf(0.0, 1.0 - t / CLASH_HOLD)
			var up := _at(OVERHEAD + Vector3(0.0, 0.0, swing), 0.0, lerpf(IMPACT_SCALE, 1.0, clampf(t / BLEND, 0.0, 1.0)))
			if t < CLASH_HOLD:
				return up
			return _blend(up, rest, (t - CLASH_HOLD) / (CLASH_SECONDS - CLASH_HOLD))
		"score":
			var u := t - _delays[i]
			if u <= 0.0 or u >= SCORE_SECONDS:
				return rest
			var reach := minf(1.0, SCORE_LIFT + SCORE_LIFT_PER_LINK * float(_beat.links))
			return _blend(rest, _at(UP, 0.0), reach * sin(PI * u / SCORE_SECONDS) * absf(sin(TAU * u / SCORE_SECONDS)))
		_:
			var hide := _at(HIDE, 0.0)
			var peek := _at(PEEK, -0.12)
			if t < PEEK_AT:
				return _blend(rest, hide, t / BLEND)
			if t < ROUT_SECONDS - 2.0 * BLEND:
				return _blend(hide, peek, (t - PEEK_AT) / BLEND)
			return _blend(peek, rest, (t - ROUT_SECONDS + 2.0 * BLEND) / (2.0 * BLEND))


func _at(centre: Vector3, lean: float, size := 1.0) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, lean).scaled(Vector3.ONE * size), centre)


func _blend(a: Transform3D, b: Transform3D, f: float) -> Transform3D:
	return a.interpolate_with(b, smoothstep(0.0, 1.0, clampf(f, 0.0, 1.0)))
