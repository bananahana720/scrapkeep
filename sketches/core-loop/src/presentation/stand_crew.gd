extends Node3D

# The Slag Bowl's stand crew at work (W46-12, catalyst W46-C3): every plush fan the Fleet yard seats
# (arena_bowl_yard.gd) holds a Fleet clipboard, and the boards answer the fight. A combo (the harpoon chain's
# second link on, line_state_changed "chain_link") gets boards pumped up in a wave round the stands. Each of
# Brindle's phase turns (boss_phase_changed) plays the clash beat: every board snaps overhead at once on the
# turn's frame, shakes, and settles inside CLASH_SECONDS, while juice holds a two-frame freeze on that frame.
# The rout hides every face behind its paperwork, then one beat later the boards dip and the crew peek over.
#
# The boards are one MultiMesh (one draw), seated behind the rim wall with the fans: no collider, no group,
# nothing to aim at or hit, and nothing that can stand over a telegraph (ruling cx). Idle, it does no work.
#
# Ruling cu, the freeze may not hide a tell: the freeze is asked once, after the turn's frame has published
# everything it will, and only if no boss tell (boss_attack_telegraphed, attack_cued) came with the turn.
# Brindle's turn into phase 2 or 3 cancels his hazards and opens the transition beat, in which no attack
# commits, so the freeze plays there; the chase's turn cues the eject's catch mark on the same frame, so its
# clash plays without the freeze. stand_crew_test holds both against the live fight.

const YARD_PATH := "ArenaBowlDress/FleetYard"
const FANS := "CrewFans"
# The beat a phase turn plays, and its freeze: two frames at 60 Hz. The fact is the hull's armour break the
# turn lands (juice.gd STRIKE_STOP_FACTS), so the freeze shares the one stop budget and never stacks on the
# break's own stop: a turn on the breaking hit's frame keeps that stop instead.
const CLASH_SECONDS := 1.0
const CLASH_FREEZE := 2.0 / 60.0
const FREEZE_FACT := "posture_break"
# The clash: overhead and shaking until CLASH_HOLD, then back to rest by CLASH_SECONDS.
const CLASH_HOLD := 0.6
const CLASH_SHAKE_HZ := 4.0
const CLASH_SWING := 0.22
# A combo: the chain's second link on. Boards pump twice in SCORE_SECONDS, higher for a longer chain, in the yard's wave.
const SCORE_SECONDS := 0.8
# The share of the way to UP a pump reaches: a two-link chain most of it, a full one all of it.
const SCORE_LIFT := 0.6
const SCORE_LIFT_PER_LINK := 0.07
const SCORE_LINKS_CAP := 6
# The rout: hide at once, peek one beat later (the 129 BPM fight tempo, machine_fx.gd WINK_DELAY), back by ROUT_SECONDS.
const PEEK_AT := 60.0 / 129.0
const ROUT_SECONDS := 2.6
const BLEND := 0.12

# Poses in the fan's own frame (the fan faces +X, the bowl; its pear body reaches x 0.69 and its raised hands y 1.56,
# tools/blender/bosses/arena_bowl_yard.py): at rest the board is held at the chest, leaning back as if read; a combo
# pumps it up to the raised hands; the clash flings it high overhead, a size up on the impact frame; the rout holds it
# over the face, then dips it under the eyes. The sheet always faces the bowl.
const REST := Vector3(0.76, 0.85, 0.12)
const LEAN := 0.35
const UP := Vector3(0.3, 2.0, 0.2)
const OVERHEAD := Vector3(0.15, 2.45, 0.0)
const IMPACT_SCALE := 1.35
const HIDE := Vector3(0.8, 1.15, 0.0)
const PEEK := Vector3(0.8, 0.86, 0.0)
# The board in fan units (the yard seats fans at about 1.35 scale): a dark Fleet board, a cream sheet, a brass clip.
const BOARD := Vector3(0.035, 0.62, 0.48)
const SHEET := Vector2(0.52, 0.40)
const CLIP := Vector3(0.06, 0.07, 0.16)
const BOARD_COLOUR := Color("3a2e24")
const SHEET_COLOUR := Color("e8dcc0")
const CLIP_COLOUR := Color("b08d3c")

var boards: MultiMeshInstance3D
var _fans: MultiMeshInstance3D
var _yard: Node
# Each fan's seat at rest and its place in the yard's wave (arena_bowl_yard.gd seats), and each board as last posed,
# kept here so a caller never reads a board back from the draw.
var _rests: Array[Transform3D] = []
var _delays := PackedFloat32Array()
var _posed: Array[Transform3D] = []
var _beat := {}
var _clock := 0.0
var _links := 0
var _freeze := Callable()
var _freeze_pending := false


# Seats a board in every fan's hand, under the bowl; arena.gd calls it as its dressing step builds. Null when the
# bowl has no Fleet yard (its kit missing): the stands are empty, so there is no one to hold a board.
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


# The crew on the game bus, once the bowl is in the tree (arena.gd _ready, as BowlDress.bind_yard): the bus and juice's
# stop are the bowl's parent's, the game's.
static func bind_bowl(arena: Node3D) -> void:
	var crew = arena.get_node_or_null("StandCrew")
	var game := arena.get_parent()
	if crew == null or game == null:
		return
	var presentation = game.get("presentation")
	var juice = presentation.get("juice") if presentation != null else null
	crew.bind(game.get("events"), Callable(juice, "request_hit_stop") if juice != null else Callable())


# `freeze` takes (seconds, fact), as juice.request_hit_stop. A crew with no bus stays at rest.
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
	# The yard hops the fans on these; the boards wake to stay in their hands.
	events.fight_phase_changed.connect(_wake.unbind(3))
	events.boss_weak_point_hit.connect(_wake.unbind(1))


# The beat on show: "clash", "score", "rout", or "" at rest.
func reacting() -> String:
	return String(_beat.get("kind", "")) if _live() else ""


func board_count() -> int:
	return boards.multimesh.instance_count if boards != null else 0


# A board's transform in the bowl's frame, as last posed.
func board_transform(i: int) -> Transform3D:
	return boards.transform * _posed[i]


# A board in its own fan's frame: what the beat does with it, whatever the yard does with the fan.
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
	# The fans' frame in the bowl's: the boards are drawn in it, so a seat's transform carries over as it is.
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


# --- The fight's facts ---------------------------------------------------------------------

func _on_phase(phase: int, _name: String) -> void:
	if phase <= 1:
		return
	_start("clash")
	# Everything the turn's frame publishes lands before this runs; a tell among it calls the freeze off.
	_freeze_pending = true
	_send_freeze.call_deferred()


func _on_tell() -> void:
	_freeze_pending = false


func _send_freeze() -> void:
	if not _freeze_pending:
		return
	_freeze_pending = false
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
	_start("rout")


# A bigger beat holds over a smaller one: a combo never cuts the clash or the rout short.
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


# While the yard hops its fans, each board rides its fan's drawn transform (the yard writes it to the fans' MultiMesh
# every frame of a cheer, so it is held on the CPU and reads back cheaply); otherwise the fan sits at its rest.
func _pose_all() -> void:
	var multimesh := boards.multimesh
	var hopping: bool = _yard.cheering() != ""
	var t := _clock - float(_beat.get("start", 0.0))
	for i in multimesh.instance_count:
		var fan: Transform3D = _fans.multimesh.get_instance_transform(i) if hopping else _rests[i]
		_posed[i] = fan * _held(t, i)
		multimesh.set_instance_transform(i, _posed[i])


# The board in the fan's frame, `t` seconds into the beat.
func _held(t: float, i: int) -> Transform3D:
	var rest := _at(REST, LEAN)
	if not _live():
		return rest
	match String(_beat.kind):
		"clash":
			# The turn's frame is the impact: overhead at once and a size up, and the freeze holds it there.
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
