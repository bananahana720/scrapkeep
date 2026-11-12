extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const Objectives := preload("res://src/core/objectives.gd")
const Palette := preload("res://src/core/palette.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const Hitscan := preload("res://src/combat/hitscan.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const UiDraw := preload("res://src/ui/ui_draw.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")

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
#
# An event on its way to one place (a park event's site, a terrain change, an offer's ring)
# points the same way through its lead, in the warning colour with the event glyph, so the
# warning says where as well as what (PF-16: "Dome Lightning incoming" named the event and not
# its place). The world publishes the place with the announcement; the marker goes when the
# event starts, ends or its lead runs out. The weather and the flood have no one place and get none.
#
# In a fight whose row names a thing (Brindle's arena, the Spillway's two mounted Wardens) the
# markers point at that thing (boss.gd and warden_reactor.gd plate_targets: the crane magnets, the
# vent caps, the open cockpit, the scooter, the water sheet's foot, the relic to latch). Nothing
# else on the screen says which part of the scene a row means, so these targets keep a mark in
# view too: brackets round the thing and, where there is room, a tag with its name or the next
# move there (objectives.gd TAGS). The plate is the plan; the mark is the
# next move, on the thing itself. A chevron over the thing was tried first and nobody saw it
# (second first-timer film, PF-17).
#
# A mark is only as true as the picture under it (PC film of PR 729): a thing behind a wall, a
# pillar, the ground or Brindle's wreck wears its brackets faint and no tag, so the brackets never
# claim a wall is the scooter; with no room it is left out, never sent to the edge, since it is in
# view. A comic panel up over the play (Brindle's arrival close-up) or the start pick card takes
# no mark either: the marks belong to the play view, and the panel shows another camera.

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
# A marked target in view. Its box's half-size is the screen size of MARK_RADIUS_M at the target,
# kept between MARK_MIN and MARK_MAX; the brackets breathe by MARK_PULSE of it at MARK_HZ.
const MARK_RADIUS_M := 1.6
const MARK_MIN := 24.0
const MARK_MAX := 56.0
const MARK_STROKE := 4.0
const MARK_PULSE := 0.08
const MARK_HZ := 1.2
# A thing counts as seen when the ray from the camera stops within SIGHT_SLACK_M of it (its own
# ground, its own mount); a thing behind something else wears HIDDEN_ALPHA of its colour and no
# tag. The avoided panels are grown by AVOID_GROW pixels, for their tilt.
const SIGHT_SLACK_M := 2.5
const HIDDEN_ALPHA := 0.35
const AVOID_GROW := 16.0
# The tag: its font size, the padding of its chip, and the gap between the chip and the brackets.
const TAG_FONT := UiTokens.BODY
const TAG_PAD := Vector2(8.0, 4.0)
const TAG_GAP := 6.0
# The rows of a mounted Warden's fight whose thing the driver names (warden_reactor.gd plate_targets).
const MOUNT_ROWS := ["ride_sheet", "line_fight"]

var game
# The objective row the plate shows now and the glyph it wears, set by the HUD each frame.
var objective_id := ""
var objective_icon := ""
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
# Events announced with a place and not started: {event_id: {at, left}}, left in seconds.
var _incoming := {}


func setup(game_ref) -> void:
	game = game_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the key prompts and the damage numbers: a mark is the fight's goal, and both sit where it does.
	z_index = 1
	game.events.reward_offered.connect(func(offers: Array):
		gate_points.clear()
		for offer in offers:
			gate_points.append(offer["at"]))
	game.events.flow_changed.connect(func(state: String):
		if state != "gates":
			gate_points.clear())
	# Door keys repeat across runs, so a new run forgets what the last one found.
	game.events.run_started.connect(func(_class_id: String):
		discovered.clear()
		_incoming.clear())
	game.events.event_announced.connect(note_incoming)
	# A retry or a new stage ends what was announced without an end for each event.
	game.events.stage_entered.connect(func(_stage: int, _retry: bool): _incoming.clear())
	game.events.event_started.connect(func(id: String): _incoming.erase(id))
	game.events.event_ended.connect(func(id: String, _outcome: String): _incoming.erase(id))


# An event announced `seconds` ahead of landing at `at`; one with no lead or no place is not marked.
func note_incoming(event_id: String, seconds: float, at: Vector3) -> void:
	if seconds > 0.0 and at.is_finite():
		_incoming[event_id] = {"at": at, "left": seconds}
	else:
		_incoming.erase(event_id)


func step_incoming(delta: float) -> void:
	for id in _incoming.keys():
		_incoming[id]["left"] -= delta
		if _incoming[id]["left"] <= 0.0:
			_incoming.erase(id)


func incoming_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _incoming:
		out.append({"at": _incoming[id]["at"], "kind": "event_announced", "icon": "obj_event"})
	return out


# What the markers point at now: {at, kind, icon}, kind naming the event_kinds row and
# icon the plate's glyph for the row in force.
func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flow = game.flow
	match flow.state_name():
		"stage", "beacon":
			if yard_locked:
				return out
			var marks := _mount_marks()
			out.append_array(marks)
			# A mark on the Warden itself stands in for the Warden's own marker.
			if is_instance_valid(flow.warden) and marks.any(func(mark): return mark["at"].is_equal_approx(flow.warden.global_position)):
				pass
			elif flow.sealed and is_instance_valid(flow.warden):
				out.append({"at": flow.warden.global_position, "kind": "warden_engaged", "icon": _glyph("obj_warden")})
			elif game.beacon != null:
				out.append({"at": game.beacon.global_position, "kind": "beacon_charge_changed", "state": game.beacon.state_id(), "icon": _glyph("obj_beacon")})
			out.append_array(incoming_targets())
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
		"boss":
			var boss = game.ctx.boss
			if is_instance_valid(boss) and boss.has_method("plate_targets") and Objectives.ROWS.has(objective_id):
				for target in boss.plate_targets():
					out.append({"at": target["at"], "kind": "boss_arena_entered", "icon": _row_icon(), "mark": true,
						"tag": Objectives.tag(target["what"])})
	return out


# The marked targets of a mounted Warden's fight, while the plate shows that fight's row.
func _mount_marks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var warden = game.flow.warden
	if not engaged or objective_id not in MOUNT_ROWS or not is_instance_valid(warden):
		return out
	var driver = warden.get("mount_driver")
	if driver == null or not driver.has_method("plate_targets"):
		return out
	for target in driver.plate_targets(warden):
		out.append({"at": target["at"], "kind": "warden_engaged", "icon": _row_icon(), "mark": true,
			"tag": Objectives.tag(target["what"])})
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
	return pocket_targets(doors, discovered, game.player.shown_position(), Callable(terrain, "height"))


# Latches every door that is in view, in range and in sight as discovered. Called each frame.
func note_pockets(size: Vector2) -> void:
	if game == null or game.world == null or game.player == null or not game.flow.in_play():
		return
	var terrain = game.world.terrain
	var cam: Camera3D = game.camera.cam
	var ground := Callable(terrain, "height")
	var ball: Vector3 = game.player.shown_position()
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


# The glyph a marked target wears at the view's edge: the plate's own now (an open cockpit turns
# it), or the row's when the HUD has handed none.
func _row_icon() -> String:
	return objective_icon if objective_icon != "" else Objectives.glyph(objective_id)


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
	return gate.clamp_crew(game.player.shown_position())


# The play view markers stay inside: clear of the top, toast and bottom bands.
static func view_rect(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("toasts", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


# One record per off-screen target: {at (screen), dir, size, color, icon}. A target with `mark`
# has one in view as well: {box, color, tag}, brackets round the box, with targets whose boxes
# touch sharing one pair of brackets, and the tag on the box nearest the middle of the view. Where
# a mark would run under the top or the bottom band its targets go to the play view's edge like
# any other.
func markers(size: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if game == null or not game.flow.in_play():
		return out
	var cam: Camera3D = game.camera.cam
	var screen := Rect2(Vector2.ZERO, size)
	var away: Array[Dictionary] = []
	var groups: Array[Dictionary] = []
	for target in targets():
		var at: Vector3 = target["at"]
		var projected := cam.unproject_position(at) if not cam.is_position_behind(at) else Vector2.INF
		if projected == Vector2.INF or not screen.has_point(projected):
			away.append(target)
		elif target.get("mark", false):
			var half := clampf(cam.unproject_position(at + cam.global_transform.basis.x * MARK_RADIUS_M).distance_to(projected), MARK_MIN, MARK_MAX)
			var seen := in_sight(cam, at)
			var color := marker_color(target)
			_group(groups, {"box": Rect2(projected - Vector2(half, half), Vector2(half, half) * 2.0),
				"color": color if seen else Color(color, color.a * HIDDEN_ALPHA),
				"tag": String(target.get("tag", "")) if seen else "", "seen": seen, "targets": [target]})
	# Every group wears its tag where there is room for it, the seen groups first and the group
	# nearest the middle of the view first among them: over the brackets, else under them, else not
	# at all. A group with no room even for its brackets sends its targets to the edge; one under a
	# comic panel or the start pick card is not drawn.
	var room := mark_view(size)
	var centre := size * 0.5
	groups.sort_custom(func(a, b):
		if a["seen"] != b["seen"]:
			return a["seen"]
		return a["box"].get_center().distance_to(centre) < b["box"].get_center().distance_to(centre))
	var covered := avoid_rects()
	var taken: Array[Rect2] = covered.duplicate()
	for group in groups:
		var box := _slid(group["box"], room)
		if covered.any(func(panel: Rect2): return panel.intersects(mark_rect(box, ""))):
			continue
		var tag: String = group["tag"]
		var under := false
		if tag != "" and not _free(mark_rect(box, tag), room, taken):
			under = _free(mark_rect(box, tag, true), room, taken)
			tag = tag if under else ""
		if tag == "" and not _free(mark_rect(box, ""), room, taken):
			if group["seen"]:
				away.append_array(group["targets"])
			continue
		taken.append(mark_rect(box, tag, under))
		out.append({"box": box, "color": group["color"], "tag": tag, "under": under})
	var view := view_rect(size)
	var ball: Vector3 = game.player.shown_position()
	for target in away:
		var at: Vector3 = target["at"]
		var dir: Vector2
		if cam.is_position_behind(at):
			var local := cam.global_transform.affine_inverse() * at
			dir = Vector2(local.x, -local.y)
			if dir.length() < 0.001:
				dir = Vector2.DOWN
		else:
			dir = cam.unproject_position(at) - centre
		dir = dir.normalized()
		var near := clampf((ball.distance_to(at) - NEAR) / (FAR - NEAR), 0.0, 1.0)
		out.append({"at": _on_edge(view, centre, dir), "dir": dir, "size": lerpf(MAX_SIZE, MIN_SIZE, near),
			"color": marker_color(target), "icon": target["icon"]})
	return out


# Whether the camera sees the thing at `at`: the world ray to it (Hitscan.WORLD; the ball is on
# its own layer) meets nothing short of SIGHT_SLACK_M before it. A live Brindle part and a Warden's
# body are on the enemy layer, so they never hide their own parts; Brindle's wreck turns world at
# the eject and hides the scooter like any wall.
func in_sight(cam: Camera3D, at: Vector3) -> bool:
	if not cam.is_inside_tree():
		return true
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, at, Hitscan.WORLD)
	var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["position"].distance_to(at) <= SIGHT_SLACK_M


# The screen held by a comic panel or the start pick card (flourish_player.gd AVOID_GROUP), grown
# for their tilt.
func avoid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(FlourishPlayer.AVOID_GROUP):
		if node is Control and node.is_visible_in_tree():
			out.append(node.get_global_rect().grow(AVOID_GROW))
	return out


# Adds a mark to the groups: into every group of its tag whose box touches it, as one box. The
# box grows as it takes groups in, so the pass repeats until it takes none.
static func _group(groups: Array[Dictionary], mark: Dictionary) -> void:
	var took := true
	while took:
		took = false
		for i in range(groups.size() - 1, -1, -1):
			if groups[i]["tag"] == mark["tag"] and groups[i]["box"].intersects(mark["box"]):
				mark["box"] = mark["box"].merge(groups[i]["box"])
				mark["targets"].append_array(groups[i]["targets"])
				groups.remove_at(i)
				took = true
	groups.append(mark)


# Where a mark may stand: the screen between the top band and the bottom band. The toasts band is
# sky in most fights, and a marked thing can be up there (Brindle's scooter), so a mark may too.
static func mark_view(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("top", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


# The tags drawn now, for the HUD's word budget (word_budget.gd).
func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for marker in _shown:
		if marker.get("tag", "") != "":
			out.append(marker["tag"])
	return out


# Whether a mark may take this screen: inside the room and over no mark already placed.
static func _free(rect: Rect2, room: Rect2, taken: Array[Rect2]) -> bool:
	return room.encloses(rect) and not taken.any(func(other: Rect2): return other.intersects(rect))


# A mark's box moved the least it takes to stand in the room, while the thing's middle stays
# inside the brackets (Brindle's scooter flies at the top band's edge); otherwise as it was.
static func _slid(box: Rect2, room: Rect2) -> Rect2:
	var grown := mark_rect(box, "")
	var move := Vector2(maxf(room.position.x - grown.position.x, 0.0) + minf(room.end.x - grown.end.x, 0.0),
		maxf(room.position.y - grown.position.y, 0.0) + minf(room.end.y - grown.end.y, 0.0))
	if absf(move.x) >= box.size.x * 0.5 or absf(move.y) >= box.size.y * 0.5:
		return box
	return Rect2(box.position + move, box.size)


# The screen a mark takes: its brackets at their widest, and its tag's chip over them (under
# them when the room over them is taken).
static func mark_rect(box: Rect2, tag: String, under := false) -> Rect2:
	var out := box.grow(maxf(box.size.x, box.size.y) * 0.5 * MARK_PULSE + MARK_STROKE)
	return out.merge(tag_rect(box, tag, under)) if tag != "" else out


# The tag's chip: centred over the brackets, or under them.
static func tag_rect(box: Rect2, tag: String, under := false) -> Rect2:
	var chip := Vector2(UiDraw.width(tag, TAG_FONT), UiFonts.bold().get_height(TAG_FONT)) + TAG_PAD * 2.0
	var off := maxf(box.size.x, box.size.y) * 0.5 * MARK_PULSE + MARK_STROKE + TAG_GAP
	var top := box.end.y + off if under else box.position.y - off - chip.y
	return Rect2(Vector2(box.get_center().x - chip.x * 0.5, top), chip)


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


func _process(delta: float) -> void:
	if game == null:
		return
	step_incoming(delta)
	note_pockets(get_viewport_rect().size)
	var now := markers(get_viewport_rect().size)
	# A mark breathes, so it is drawn every frame while one is up.
	if now != _shown or now.any(func(marker): return marker.has("box")):
		_shown = now
		queue_redraw()


func _draw() -> void:
	for marker in _shown:
		if marker.has("box"):
			_draw_mark(marker)
			continue
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


# A mark in view: four corner brackets round the box, inked dark under the row's colour so they
# hold on any ground, and the tag on a dark chip over them with a stem down to the brackets.
func _draw_mark(marker: Dictionary) -> void:
	var color: Color = marker["color"]
	var rest: Rect2 = marker["box"]
	var reach := maxf(rest.size.x, rest.size.y) * 0.5
	var box := rest.grow(reach * MARK_PULSE * sin(Time.get_ticks_msec() * 0.001 * TAU * MARK_HZ))
	var arm := minf(box.size.x, box.size.y) * 0.22
	for corner in [Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 1.0), Vector2(0.0, 1.0)]:
		var tip: Vector2 = box.position + box.size * corner
		var inward: Vector2 = Vector2(1.0, 1.0) - corner * 2.0
		var bracket := PackedVector2Array([tip + Vector2(inward.x * arm, 0.0), tip, tip + Vector2(0.0, inward.y * arm)])
		draw_polyline(bracket, UiDraw.OUTLINE, MARK_STROKE + 4.0)
		draw_polyline(bracket, color, MARK_STROKE)
	var tag: String = marker["tag"]
	if tag == "":
		return
	var under: bool = marker.get("under", false)
	var chip := tag_rect(rest, tag, under)
	var stem := Vector2(chip.get_center().x, chip.position.y if under else chip.end.y)
	var point := -1.0 if under else 1.0
	draw_colored_polygon(PackedVector2Array([stem + Vector2(-6.0, -point), stem + Vector2(6.0, -point), stem + Vector2(0.0, (TAG_GAP + 2.0) * point)]), Color(Palette.CHARCOAL, 0.92))
	draw_rect(chip, Color(Palette.CHARCOAL, 0.92))
	draw_rect(chip, color, false, 2.0)
	UiDraw.text(self, chip.position.x + TAG_PAD.x, chip.get_center().y, tag, TAG_FONT, color)
