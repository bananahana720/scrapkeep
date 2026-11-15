extends Node

const ModelKit := preload("res://src/world/model_kit.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Records := preload("res://src/world/camp_records.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")

# The camp ring: the stocktake fought in the camp's practice yard, for a best count and nothing
# else (survival_count.gd form "ring"). A post in the yard starts it; counts of world 1's machines
# climb in at the fence across from the ball, each count harder by the same rule the run's yards
# use, with no gate to leave by and no pay. It ends when the yard's hull is wrecked or the ball
# leaves the yard, and the last count cleared is kept as that pilot's best.
#
# The yard (camp_sandbox.gd) owns the enemies, the floor and the hull, so nothing here is a run:
# the ring asks it to stand each machine and reads how many are up. The arena's flood (the count's
# hazard) is not drawn here; the camp yard is dry.

const STATION := "camp_ring"
const KEY := "key_e"
const STATION_RADIUS := 3.5
# The post stands this far from the yard's centre, on the side away from the call box.
const POST_M := 14.0
# Machines climb in on a circle this far from the yard's centre, one every ARRIVE_S.
const EDGE_M := 20.0
const ARRIVE_S := 0.4
# How far to either side of straight across from the ball a count spreads, in radians.
const SPREAD := 1.1
# The board floats this far above the post's lamp, so it clears the post whatever its height.
const BOARD_ABOVE_M := 0.8
const POST_HEIGHT := 2.2
const POST := "res://assets/models/world_one/poi_camp_tally_post.glb"
const POST_MODEL_HEIGHT := 2.5
# The model is drawn this much larger: at 2.5 m it read small at play distance in the PC stills of 14 Nov.
const POST_MODEL_SCALE := 1.6

var hub
var sandbox
var records
var count: SurvivalCount
var board: Label3D

var _centre := Vector3.ZERO
var _owed: Array = []
var _wait := 0.0
var _wrecks := 0
var _clears := 0
var _lamp: MeshInstance3D
# Where along the fence each machine climbs in: a stream of the ring's own, off the run's seed.
var _rng := RandomNumberGenerator.new()


# The camp hub calls this once after it is built, after the yard's own feature.
static func attach(camp_hub) -> void:
	var yard: Node = camp_hub.root.get_node_or_null("CampSandbox")
	if yard == null or camp_hub.piece("camp_sandbox_yard") == null:
		push_warning("camp_ring: the practice yard is missing; left out")
		return
	var ring := new()
	ring.name = "CampRing"
	camp_hub.root.add_child(ring)
	ring.bind(camp_hub, yard)


func bind(camp_hub, yard: Node, records_ref = null) -> void:
	hub = camp_hub
	sandbox = yard
	records = records_ref if records_ref != null else Records.new(hub.get("camp_store"))
	_centre = hub.piece("camp_sandbox_yard").global_position
	var box: Vector3 = hub.socket("camp_call_box", "interact").origin
	var away := Vector3(_centre.x - box.x, 0.0, _centre.z - box.z)
	away = away.normalized() if away.length() > 0.5 else Vector3.BACK
	var post := _centre + away * POST_M
	hub.add_station(STATION, post, "Stocktake: endless counts", KEY, STATION_RADIUS, begin)
	_lamp = _post(post)
	board = _board(_lamp.global_position + Vector3.UP * BOARD_ABOVE_M)
	# The pilot at the gate can change between walks, and the board shows that pilot's best.
	hub.walk_entered.connect(_show)
	hub.walk_left.connect(stop)
	_show()


func running() -> bool:
	return count != null and not count.done


# The best count of the pilot standing at the gate.
func best() -> int:
	return records.ring_best(_pilot())


# The first count climbs in. Nothing happens off the walk, outside the yard, in a run or mid-count.
func begin() -> void:
	if running() or hub.game.flow.in_play() or not sandbox.walking or not sandbox.inside:
		return
	sandbox.clear()
	sandbox.mend()
	_wrecks = sandbox.wrecks
	_clears = sandbox.clears
	count = SurvivalCount.new(1, "ring")
	_owe(count.begin())
	_show()


func _physics_process(delta: float) -> void:
	if not running():
		return
	# The count ends when the yard stops fighting (the walk ends, the ball leaves, the call box's page opens), when
	# the hull is wrecked, and when the yard is emptied by anything but kills (the call box's "Clear yard").
	if not sandbox.fighting() or sandbox.wrecks != _wrecks or sandbox.clears != _clears:
		stop()
		return
	_arrive(delta)
	var was := count.count
	if count.step(delta, sandbox.live_count() + _owed.size()) in ["count", "pile"]:
		_owe(count.pack(count.count))
	if count.count != was:
		_show()


func _owe(pack: Array) -> void:
	var health := count.strength(count.count)
	for kind in pack:
		_owed.append({"kind": kind, "health": health})


# One owed machine climbs in at the fence, across the yard from the ball.
func _arrive(delta: float) -> void:
	_wait -= delta
	if _owed.is_empty() or _wait > 0.0:
		return
	_wait = ARRIVE_S
	var row: Dictionary = _owed.pop_front()
	var ball: Vector3 = hub.ball.ball_position()
	var across := Vector2(_centre.x - ball.x, _centre.z - ball.z)
	across = across.normalized() if across.length() > 0.5 else Vector2.UP
	across = across.rotated(_rng.randf_range(-SPREAD, SPREAD))
	sandbox.stand(row["kind"], _centre + Vector3(across.x, 0.0, across.y) * EDGE_M, row["health"])


# The count is over: the last count cleared is kept when it beat the pilot's best.
func stop() -> void:
	if not running():
		return
	var record := int(count.leave().get("record", 0))
	count = null
	_owed.clear()
	_wait = 0.0
	records.submit_ring(_pilot(), record)
	sandbox.clear()
	sandbox.mend()
	_show()


func _pilot() -> String:
	var pilot = hub.game.gate_pilot()
	return str(pilot.id) if pilot != null else ""


# The board over the post: the count now standing, or the pilot's best while the yard is quiet.
func _show() -> void:
	if running():
		board.text = str(count.count)
		board.modulate = Palette.HAZARD
		_lamp.material_override = Palette.solid(Palette.HAZARD, 2.0, false)
	else:
		var kept := best()
		board.text = "BEST %d" % kept if kept > 0 else ""
		board.modulate = Palette.AMBER
		_lamp.material_override = Palette.solid(Palette.AMBER, 1.0, false)


# The post the ball rolls up to: a dark pole with a lamp on top, amber while the yard is quiet and
# red while a count stands, so the place is marked before any best is on the board.
func _post(at: Vector3) -> MeshInstance3D:
	var foot := Node3D.new()
	foot.name = "RingPost"
	hub.root.add_child(foot)
	foot.global_position = Vector3(at.x, sandbox.ground.floor_y, at.z)
	# The camp tally post's model (2.5 m, drawn at POST_MODEL_SCALE), facing the yard's centre; the plain pole when the file is missing.
	var top := POST_HEIGHT
	if ModelKit.whole(POST, foot) != null:
		top = POST_MODEL_HEIGHT * POST_MODEL_SCALE
		foot.scale = Vector3.ONE * POST_MODEL_SCALE
		foot.rotation.y = atan2(at.z - _centre.z, _centre.x - at.x)
	else:
		var pole := MeshInstance3D.new()
		var shaft := CylinderMesh.new()
		shaft.top_radius = 0.14
		shaft.bottom_radius = 0.2
		shaft.height = POST_HEIGHT
		pole.mesh = shaft
		pole.material_override = Palette.solid(Palette.CHARCOAL)
		pole.position = Vector3.UP * POST_HEIGHT * 0.5
		foot.add_child(pole)
	var lamp := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = 0.34
	bulb.height = 0.68
	lamp.mesh = bulb
	foot.add_child(lamp)
	# Set in the world's frame: the foot may be scaled.
	lamp.top_level = true
	lamp.global_position = foot.global_position + Vector3.UP * (top + 0.2)
	return lamp


func _board(at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.name = "RingBoard"
	label.font = UiFonts.mono()
	label.font_size = 96
	label.pixel_size = 0.014
	label.outline_modulate = Palette.CHARCOAL
	label.outline_size = 14
	label.shaded = false
	label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hub.root.add_child(label)
	label.global_position = at
	return label
