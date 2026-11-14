extends Node

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
const BOARD_HEIGHT := 3.2

var hub
var sandbox
var records
var count: SurvivalCount
var board: Label3D

var _centre := Vector3.ZERO
var _owed: Array = []
var _wait := 0.0
var _wrecks := 0


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
	hub.add_station(STATION, post, "Stocktake", KEY, STATION_RADIUS, begin)
	board = _board(post)
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
	count = SurvivalCount.new(1, "ring")
	_owe(count.begin())
	_show()


func _physics_process(delta: float) -> void:
	if not running():
		return
	if not sandbox.walking or not sandbox.inside or sandbox.wrecks != _wrecks:
		stop()
		return
	if sandbox.page_open:
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
	across = across.rotated(randf_range(-SPREAD, SPREAD))
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
	else:
		var kept := best()
		board.text = "BEST %d" % kept if kept > 0 else ""
		board.modulate = Palette.AMBER


func _board(post: Vector3) -> Label3D:
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
	label.global_position = post + Vector3.UP * BOARD_HEIGHT
	return label
