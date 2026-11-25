extends Node

const ModelKit := preload("res://src/world/model_kit.gd")
const Palette := preload("res://src/core/palette.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Records := preload("res://src/world/camp_records.gd")
const SurvivalCount := preload("res://src/world/survival_count.gd")


const STATION := "camp_ring"
const KEY := "key_e"
const STATION_RADIUS := 3.5
const POST_M := 14.0
const EDGE_M := 20.0
const ARRIVE_S := 0.4
const SPREAD := 1.1
const BOARD_ABOVE_M := 0.8
const POST_HEIGHT := 2.2
const POST := "res://assets/models/world_one/poi_camp_tally_post.glb"
const POST_MODEL_HEIGHT := 2.5
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
var _rng := RandomNumberGenerator.new()


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
	hub.walk_entered.connect(_show)
	hub.walk_left.connect(stop)
	_show()


func running() -> bool:
	return count != null and not count.done


func best() -> int:
	return records.ring_best(_pilot())


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


func _post(at: Vector3) -> MeshInstance3D:
	var foot := Node3D.new()
	foot.name = "RingPost"
	hub.root.add_child(foot)
	foot.global_position = Vector3(at.x, sandbox.ground.floor_y, at.z)
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
