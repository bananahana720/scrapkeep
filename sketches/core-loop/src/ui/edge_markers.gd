extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Icons := preload("res://src/ui/icons.gd")
const Objectives := preload("res://src/core/objectives.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")

# Edge markers: while the Warden (or the beacon, once it has no Warden) or an open
# reward gate is off screen, a chevron on the edge of the play view points at it, with
# its objective glyph behind. Closer targets draw bigger. No words: the glyph is the
# objective plate's own (objectives.gd, through objective_id) and the colour is the
# target's event_kinds row.
#
# While the Warden's clamp is shut (the plate's "Clamp shut: break the crews" row), one more
# chevron points at the crew nearest to lighting a pip, in the fleet's hazard colour with the
# plate's glyph; the Warden's marker keeps the Warden's glyph then.
#
# One more kind (SQ16): a discovered hidden-pocket door (a valve's door or a cracked wall)
# shows an amber chevron while the ball is inside POCKET_RANGE of it with a clear ray to it.
# PARK.md:265 sets the range at 240 m (sight_ok), never the comps note's 60 m (memo 2, row 29a).
# It is a pointer, not a map: no panel, no list, and no marker once the door is open.

const SIDE_INSET := 0.035
const BAND_CLEARANCE := 16.0
const MIN_SIZE := 13.0
const MAX_SIZE := 30.0
const NEAR := 25.0
const FAR := 180.0
# Hidden-pocket doors (W13-INTEGRATION-2.md row 29a; PARK.md:248, :265): the sight_ok range, the eye
# height the ray starts from, the ray's sample spacing and the marker's height above the door's
# ground. The range check adds a hair for float32 positions, so a door at exactly 240 m counts.
const POCKET_RANGE := 240.0
const POCKET_EYE_M := 2.0
const POCKET_STEP_M := 4.0
const POCKET_DOOR_LIFT := 1.5
const POCKET_RANGE_SLACK := 0.01
const CLAMP_ROW := "break_clamp_crews"

var game
# The objective row the plate shows now, set by the HUD each frame.
var objective_id := ""
# Whether the Warden fight is engaged, set by the HUD each frame; activity markers hide while it is.
var engaged := false
# Whether the yard lock holds the ball, set by the HUD each frame; every stage marker points past
# its wall then, so none shows until it opens.
var yard_locked := false
var gate_points: Array[Vector3] = []
# Pocket doors the player has had in view inside POCKET_RANGE (pocket_doors' key to true). A door
# is discovered once and stays so for the run; an undiscovered door never gets a marker.
var discovered := {}
var _shown: Array[Dictionary] = []


func setup(game_ref) -> void:
	game = game_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.events.reward_offered.connect(func(offers: Array):
		gate_points.clear()
		for offer in offers:
			gate_points.append(offer["at"]))
	game.events.flow_changed.connect(func(state: String):
		if state != "gates":
			gate_points.clear())
	# Door keys repeat across runs, so a new run forgets what the last one found.
	game.events.run_started.connect(func(_class_id: String): discovered.clear())


# What the markers point at now: {at, kind, icon}, kind naming the event_kinds row and
# icon the plate's glyph for the row in force.
func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flow = game.flow
	match flow.state_name():
		"stage", "beacon":
			if yard_locked:
				return out
			if flow.sealed and is_instance_valid(flow.warden):
				out.append({"at": flow.warden.global_position, "kind": "warden_engaged", "icon": _glyph("obj_warden")})
			elif game.beacon != null:
				out.append({"at": game.beacon.global_position, "kind": "beacon_charge_changed", "state": game.beacon.state_id(), "icon": _glyph("obj_beacon")})
			var crew = _clamp_crew()
			if crew != null:
				out.append({"at": crew.global_position, "kind": "pack_arrived", "icon": Objectives.glyph(CLAMP_ROW)})
			if not engaged:
				for site in unfinished_sites():
					out.append({"at": site.global_position, "kind": site.id, "activity": String(site.rule.get("cue", {}).get("view", site.id)), "icon": Objectives.glyph("find_activity")})
				out.append_array(_pocket_targets_now())
		"gates":
			for at in gate_points:
				out.append({"at": at, "kind": "reward_offered", "icon": _glyph("obj_gate")})
	return out


# The activity sites still standing: built, valid and not done. Field finds (secrets.gd FINDS)
# are left out, so neither a marker nor the HUD's count gives a secret away.
func unfinished_sites() -> Array:
	var out: Array = []
	if game == null or game.world == null or game.world.activities == null:
		return out
	for site in game.world.activities.sites:
		if is_instance_valid(site) and not site.done and not site.has_meta("find"):
			out.append(site)
	return out


# The hidden-pocket doors of a map: a valve's door or a cracked wall, each {id, key, at (x, z), kind}.
# The key names a door by id and place, so it holds across maps.
static func pocket_doors(map) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if map == null or not "contraptions" in map:
		return out
	for spec in map.contraptions:
		var where = null
		match spec["kind"]:
			"valve":
				where = spec["door"]["at"]
			"cracked_wall":
				where = spec["at"]
		if where == null:
			continue
		var at := Vector2(where.x, where.y if where is Vector2 else where.z)
		out.append({"id": spec["id"], "key": "%s@%d,%d" % [spec["id"], roundi(at.x), roundi(at.y)], "at": at, "kind": spec["kind"]})
	return out


# One amber target per door that is discovered, not done, inside POCKET_RANGE of the ball and
# seen over the ground from the ball's eye. ground is (x, z) to height.
static func pocket_targets(doors: Array, found: Dictionary, ball: Vector3, ground: Callable) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for door in doors:
		if door.get("done", false) or not found.has(door["key"]):
			continue
		var at: Vector2 = door["at"]
		var door_pos := Vector3(at.x, ground.call(at.x, at.y) + POCKET_DOOR_LIFT, at.y)
		if ball.distance_to(door_pos) > POCKET_RANGE + POCKET_RANGE_SLACK:
			continue
		if not sight_clear(ground, ball + Vector3.UP * POCKET_EYE_M, door_pos):
			continue
		out.append({"at": door_pos, "kind": "pocket_door", "pocket": door["id"], "color": EventKinds.role_color("amber"),
			"icon": Objectives.glyph("find_activity")})
	return out


# True when no ground between the two points rises above the ray, sampled every POCKET_STEP_M
# and stopping short of the far end so the door's own slope never hides it.
static func sight_clear(ground: Callable, from: Vector3, to: Vector3) -> bool:
	var span := from.distance_to(to)
	var steps := int(span / POCKET_STEP_M)
	for i in range(1, steps):
		var p := from.lerp(to, float(i) * POCKET_STEP_M / span)
		if ground.call(p.x, p.z) > p.y:
			return false
	return true


# The pocket targets for the stage in play, doors the player has opened left out.
func _pocket_targets_now() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or game.world == null or game.player == null:
		return out
	var terrain = game.world.terrain
	var doors := pocket_doors(terrain.map())
	var opened := _opened_ids(game.world.contraptions.get(terrain.stage))
	for door in doors:
		door["done"] = opened.has(door["id"])
	return pocket_targets(doors, discovered, game.player.ball_position(), Callable(terrain, "height"))


# Latches every door that is in view, in range and in sight as discovered. Called each frame.
func note_pockets(size: Vector2) -> void:
	if game == null or game.world == null or game.player == null or not game.flow.in_play():
		return
	var terrain = game.world.terrain
	var cam: Camera3D = game.camera.cam
	var ground := Callable(terrain, "height")
	var ball: Vector3 = game.player.ball_position()
	for door in pocket_doors(terrain.map()):
		if discovered.has(door["key"]):
			continue
		var seen := pocket_targets([door], {door["key"]: true}, ball, ground)
		if seen.is_empty():
			continue
		var at: Vector3 = seen[0]["at"]
		if not cam.is_position_behind(at) and Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(at)):
			discovered[door["key"]] = true


# Ids of the stage's doors already opened or broken: a valve's id, a wall's id.
static func _opened_ids(contraptions) -> Dictionary:
	var out := {}
	if contraptions == null:
		return out
	for v in contraptions.valves:
		if v["open"]:
			out[v["spec"]["id"]] = true
	for w in contraptions.walls:
		if w["broken"]:
			out[w["spec"]["id"]] = true
	return out


# The plate's glyph for the Warden and beacon markers; the activity row's own glyph belongs
# to the activity markers, so it never stands in for the Warden's.
# While the clamp row shows, its glyph rides the crew marker and the Warden's keeps its own.
func _glyph(fallback: String) -> String:
	return Objectives.glyph(objective_id) if objective_id not in ["", "find_activity", CLAMP_ROW] else fallback


# While the plate shows the clamp row, the crew nearest to lighting a pip (stage_locks.gd clamp_crew).
func _clamp_crew() -> Node3D:
	var gate = game.flow.get("gate")
	if objective_id != CLAMP_ROW or gate == null or not gate.has_method("clamp_crew") or game.player == null:
		return null
	return gate.clamp_crew(game.player.ball_position())


# The play view markers stay inside: clear of the top, toast and bottom bands.
static func view_rect(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("toasts", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


# One record per off-screen target: {at (screen), dir, size, color, icon}.
func markers(size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.flow.in_play():
		return out
	var cam: Camera3D = game.camera.cam
	var view := view_rect(size)
	var screen := Rect2(Vector2.ZERO, size)
	var centre := size * 0.5
	var ball: Vector3 = game.player.ball_position()
	for target in targets():
		var at: Vector3 = target["at"]
		var behind := cam.is_position_behind(at)
		var projected := cam.unproject_position(at) if not behind else Vector2.ZERO
		if not behind and screen.has_point(projected):
			continue
		var dir: Vector2
		if behind:
			var local := cam.global_transform.affine_inverse() * at
			dir = Vector2(local.x, -local.y)
			if dir.length() < 0.001:
				dir = Vector2.DOWN
		else:
			dir = projected - centre
		dir = dir.normalized()
		var near := clampf((ball.distance_to(at) - NEAR) / (FAR - NEAR), 0.0, 1.0)
		out.append({"at": _on_edge(view, centre, dir), "dir": dir, "size": lerpf(MAX_SIZE, MIN_SIZE, near),
			"color": marker_color(target), "icon": target["icon"]})
	return out


static func marker_color(target: Dictionary) -> Color:
	if target.has("color"):
		return target["color"]
	if target.has("activity"):
		return EventKinds.activity_color(target["activity"])
	return EventKinds.state_color(target["state"]) if target.has("state") else EventKinds.color(target["kind"])


static func _on_edge(view: Rect2, centre: Vector2, dir: Vector2) -> Vector2:
	var reach := INF
	if dir.x > 0.0001:
		reach = minf(reach, (view.end.x - centre.x) / dir.x)
	elif dir.x < -0.0001:
		reach = minf(reach, (view.position.x - centre.x) / dir.x)
	if dir.y > 0.0001:
		reach = minf(reach, (view.end.y - centre.y) / dir.y)
	elif dir.y < -0.0001:
		reach = minf(reach, (view.position.y - centre.y) / dir.y)
	return centre + dir * reach


func _process(_delta: float) -> void:
	if game == null:
		return
	note_pockets(get_viewport_rect().size)
	var now := markers(get_viewport_rect().size)
	if now != _shown:
		_shown = now
		queue_redraw()


func _draw() -> void:
	for marker in _shown:
		var at: Vector2 = marker["at"]
		var dir: Vector2 = marker["dir"]
		var s: float = marker["size"]
		var color: Color = marker["color"]
		var side := Vector2(-dir.y, dir.x)
		var tip := at
		var chevron := PackedVector2Array([tip, tip - dir * s + side * s * 0.8, tip - dir * s * 0.55,
			tip - dir * s - side * s * 0.8])
		draw_colored_polygon(chevron, color)
		draw_polyline(PackedVector2Array([chevron[0], chevron[1], chevron[2], chevron[3], chevron[0]]), Color(0.0, 0.0, 0.0, 0.7), 1.5)
		var icon_at := tip - dir * s * 1.9
		draw_texture_rect(Icons.texture(marker["icon"]), Rect2(icon_at - Vector2(s, s) * 0.5, Vector2(s, s)), false, Icons.tint(marker["icon"], color))
