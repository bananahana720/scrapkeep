extends Node3D


const Palette := preload("res://src/core/palette.gd")
const PhysicsLayers := preload("res://src/core/physics_layers.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

const PIECE := "camp_skee_lane"
const BALLS := 9

const CUPS := {
	"cup_10": {"points": 10, "radius": 2.0, "word": "CLUNK!"},
	"cup_20": {"points": 20, "radius": 1.4, "word": "TOCK!"},
	"cup_30": {"points": 30, "radius": 1.3, "word": "PLINK!"},
	"cup_40": {"points": 40, "radius": 1.3, "word": "DONK!"},
	"cup_50": {"points": 50, "radius": 1.25, "word": "CLANG!"},
	"cup_100_l": {"points": 100, "radius": 1.25, "word": "KA-CHING!!"},
	"cup_100_r": {"points": 100, "radius": 1.25, "word": "KA-CHING!!"},
}
const GUTTER_WORD := "FWUP."
const DEAD_WORD := "THUNK."
const GUTTER_RADIUS := 1.2

const SEAT_DISTANCE := 1.6
const GUTTER_ACROSS := 1.0
const GUTTER_HEIGHT := 1.0
const SEAT_TIME := 0.06
const SETTLE_TIME := 1.1
const GRACE := 0.25
const BEAT_TIME := 2.5
const STILL_SPEED := 0.4
const STILL_TIME := 6.0
const LEFT_BAR := 3.0
const LEAVE_Z := 5.0
const LEAVE_X := 9.0
const LEAVE_Y := -4.0

enum Phase { IDLE, PLAYING, SETTLING }

var hub
var records
var match_state := Match.new()
var phase := Phase.IDLE
var score_label: Label3D

var _lane_xf := Transform3D.IDENTITY
var _sensors := {}
var _seated := {}
var _settle := 0.0
var _after := 0.0
var _rolled := false
var _still := 0.0
var _grace := 0.0


class Match:
	var balls_total := BALLS
	var balls_left := BALLS
	var score := 0
	var rolls: Array = []

	func reset(balls := BALLS) -> void:
		balls_total = balls
		balls_left = balls
		score = 0
		rolls = []

	func roll(points: int) -> void:
		if balls_left <= 0:
			return
		balls_left -= 1
		score += points
		rolls.append(points)

	func over() -> bool:
		return balls_left <= 0

	func board() -> String:
		return "SCORE %d   BALLS %d" % [score, balls_left]


const CLASS_TAG := "camp_skee"


static func attach(hub_ref) -> void:
	for stem in [PIECE]:
		if hub_ref.piece(stem) == null:
			push_warning("%s: camp piece %s is missing; left out" % [CLASS_TAG, stem])
			return
	var lane := new()
	lane.name = "CampSkee"
	hub_ref.root.add_child(lane)
	lane.setup(hub_ref)


static func points_for(id: String) -> int:
	return int(CUPS[id]["points"]) if CUPS.has(id) else 0


func setup(hub_ref, records_ref = null) -> void:
	hub = hub_ref
	records = records_ref if records_ref != null else hub.camp_records
	_lane_xf = hub.piece(PIECE).global_transform
	for id in CUPS:
		_sensors[id] = _sensor(id, float(CUPS[id]["radius"]))
	_sensors["return"] = _sensor("return_exit", GUTTER_RADIUS)
	score_label = _board_label()
	_show_idle()
	var at: Vector3 = hub.socket(PIECE, "interact").origin
	hub.add_station("camp_skee", at, "Skee-ball: nine balls", "interact", 3.0, Callable(self, "start_game"))
	if hub.has_signal("walk_left"):
		hub.walk_left.connect(_on_walk_left)


func _sensor(socket: String, radius: float) -> Area3D:
	var area := Area3D.new()
	area.name = "Sensor_" + socket
	area.collision_layer = PhysicsLayers.NONE
	area.collision_mask = PhysicsLayers.NONE
	area.set_collision_mask_value(PhysicsLayers.BALL_LAYER, true)
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	area.add_child(shape)
	hub.root.add_child(area)
	area.global_position = hub.socket(PIECE, socket).origin
	return area


func _board_label() -> Label3D:
	var label := Label3D.new()
	label.name = "SkeeBoard"
	label.font = UiFonts.mono()
	label.font_size = 64
	label.pixel_size = 0.014
	label.modulate = Palette.AMBER
	label.outline_modulate = Palette.CHARCOAL
	label.outline_size = 14
	label.shaded = false
	label.double_sided = false
	label.no_depth_test = false
	hub.root.add_child(label)
	var face: Transform3D = hub.socket(PIECE, "score")
	label.global_transform = Transform3D(_lane_xf.basis, face.origin + _lane_xf.basis.z * 0.25)
	return label


func _show_idle() -> void:
	var best: int = records.skee_best()
	score_label.text = "SKEE-BALL   BEST %d" % best if best > 0 else "SKEE-BALL   %d BALLS" % BALLS


func start_game() -> void:
	if phase != Phase.IDLE:
		return
	match_state.reset(BALLS)
	_serve()
	score_label.text = match_state.board()


func _serve() -> void:
	phase = Phase.PLAYING
	_rolled = false
	_still = 0.0
	_grace = GRACE
	_seated.clear()
	hub.ball.reset_to(hub.socket(PIECE, "start").origin, Vector3.ZERO)


func _ball_body() -> Node3D:
	return hub.ball.body() if hub != null and hub.ball != null else null


func _physics_process(delta: float) -> void:
	if phase == Phase.IDLE:
		return
	var body := _ball_body()
	if body == null:
		return
	if phase == Phase.SETTLING:
		_settle -= delta
		if _settle <= 0.0:
			_after_settle()
		return
	if _grace > 0.0:
		_grace -= delta
		return
	var local := _lane_xf.affine_inverse() * body.global_position
	if local.z > LEAVE_Z or absf(local.x) > LEAVE_X or local.y < LEAVE_Y:
		end_game(true)
		return
	_sense(body, delta)
	if phase == Phase.PLAYING:
		_watch_still(body, local, delta)


func _sense(body: Node3D, delta: float) -> void:
	for id in _sensors:
		var area: Area3D = _sensors[id]
		if not area.overlaps_body(body) or not _seats(id, body.global_position):
			_seated[id] = 0.0
			continue
		_seated[id] = float(_seated.get(id, 0.0)) + delta
		if _seated[id] >= SEAT_TIME:
			land(id)
			return


func _seats(id: String, at: Vector3) -> bool:
	var floor_at: Vector3 = _sensors[id].global_position
	if id == "return":
		var across := Vector2(at.x - floor_at.x, at.z - floor_at.z).length()
		return across <= GUTTER_ACROSS and absf(at.y - floor_at.y) <= GUTTER_HEIGHT
	return at.distance_to(floor_at) <= SEAT_DISTANCE


func _watch_still(body: Node3D, local: Vector3, delta: float) -> void:
	var start: Vector3 = _lane_xf.affine_inverse() * hub.socket(PIECE, "start").origin
	if not _rolled:
		_rolled = local.distance_to(start) > LEFT_BAR
		return
	var speed := 0.0
	if body is RigidBody3D:
		speed = (body as RigidBody3D).linear_velocity.length()
	_still = _still + delta if speed < STILL_SPEED else 0.0
	if _still >= STILL_TIME:
		land("dead")


func land(id: String) -> void:
	if phase != Phase.PLAYING:
		return
	var points := points_for(id)
	match_state.roll(points)
	score_label.text = match_state.board()
	var at: Vector3 = hub.ball.body().global_position
	if CUPS.has(id):
		_say(CUPS[id]["word"], _sensors[id].global_position + Vector3.UP * 1.5, points >= 100)
	else:
		_say(GUTTER_WORD if id == "return" else DEAD_WORD, at + Vector3.UP * 2.0, false)
	phase = Phase.SETTLING
	_settle = SETTLE_TIME


func _after_settle() -> void:
	if match_state.over():
		end_game(false)
	else:
		_serve()


func end_game(left: bool) -> void:
	if phase == Phase.IDLE:
		return
	phase = Phase.IDLE
	var total := match_state.score
	var fresh: bool = records.submit_skee(total)
	if left:
		score_label.text = "GAME OVER   %d" % total
	else:
		score_label.text = "FINAL %d   BEST %d" % [total, records.skee_best()]
		hub.ball.reset_to(hub.socket(PIECE, "interact").origin, Vector3.ZERO)
	if fresh and total > 0:
		_say("NEW BEST!", hub.socket(PIECE, "score").origin + Vector3.DOWN * 3.0, true)
	var timer := get_tree().create_timer(BEAT_TIME * 2.0)
	timer.timeout.connect(func():
		if phase == Phase.IDLE:
			_show_idle())


func _on_walk_left() -> void:
	if phase != Phase.IDLE:
		end_game(true)


func _say(word: String, at: Vector3, big: bool) -> void:
	var label := Label3D.new()
	label.text = word
	label.font = UiFonts.bold()
	label.font_size = 160 if big else 96
	label.pixel_size = 0.02
	label.modulate = Palette.AMBER if big else Palette.LEDGER
	label.outline_modulate = Palette.CHARCOAL
	label.outline_size = 24 if big else 16
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.shaded = false
	label.no_depth_test = true
	label.render_priority = 5
	hub.root.add_child(label)
	label.global_position = at
	label.scale = Vector3.ONE * 0.2
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "scale", Vector3.ONE * (1.3 if big else 1.0), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y + (3.0 if big else 1.8), BEAT_TIME)
	tween.tween_property(label, "modulate:a", 0.0, 0.6).set_delay(BEAT_TIME - 0.6)
	tween.chain().tween_callback(label.queue_free)
