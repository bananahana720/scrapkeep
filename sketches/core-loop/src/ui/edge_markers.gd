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
const Interactables := preload("res://src/world/interactables.gd")
const EventDirector := preload("res://src/world/event_director.gd")


const SIDE_INSET := 0.035
const BAND_CLEARANCE := 16.0
const ICON_BACK := 1.9
const MIN_SIZE := 13.0
const MAX_SIZE := 30.0
const ARROW_SLIDE_MAX := 160.0
const ARROW_HOLD := 12.0
const NEAR := 25.0
const FAR := 180.0
const POCKET_RANGE := 240.0
const POCKET_EYE_M := 2.0
const POCKET_STEP_M := 4.0
const POCKET_DOOR_LIFT := 1.5
const POCKET_RANGE_SLACK := 0.01
const CLAMP_ROW := "break_clamp_crews"
const MARK_RADIUS_M := 1.6
const MARK_MIN := 24.0
const MARK_MAX := 56.0
const MARK_STROKE := 4.0
const MARK_PULSE := 0.08
const MARK_HZ := 1.2
const SIGHT_SLACK_M := 2.5
const HIDDEN_ALPHA := 0.35
const AVOID_GROW := 16.0
const TAG_FONT := UiTokens.BODY
const TAG_PAD := Vector2(8.0, 4.0)
const TAG_GAP := 6.0
const TAG_SLIDE := 0.45
const TAG_CLEAR := 2.0
const MOUNT_ROWS := ["ride_sheet", "line_fight"]

var game
var objective_id := ""
var objective_icon := ""
var engaged := false
var yard_locked := false
var gate_points: Array[Vector3] = []
var keep_clear: Array[Rect2] = []
var sign_rects: Array[Rect2] = []
var discovered := {}
var _doors_cache: Array[Dictionary] = []
var _doors_map_id := 0
var _doors_count := -1
const POCKET_STILL_M := 0.2
const _NO_OVERLAYS: Array = []
const _EMPTY_TARGETS: Array[Dictionary] = []
var _pockets_ball := Vector3.INF
var _pockets_cam_xform := Transform3D()
var _pockets_size := Vector2.ZERO
var _pockets_map_id := 0
var _pockets_doors_count := -1
var _pockets_found := -1
var _pockets_overlays: Array = []
var _targets_ball := Vector3.INF
var _targets_map_id := 0
var _targets_doors_count := -1
var _targets_found := Vector2i.ZERO
var _targets_opened := Vector2i.ZERO
var _targets_stage := -1
var _targets_overlays: Array = []
var _targets_cache: Array[Dictionary] = []
var _shown: Array[Dictionary] = []
var _slide := {}
var _incoming := {}


func setup(game_ref) -> void:
	game = game_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 1
	game.events.reward_offered.connect(func(offers: Array):
		gate_points.clear()
		for offer in offers:
			gate_points.append(offer["at"]))
	game.events.flow_changed.connect(func(state: String):
		if state != "gates":
			gate_points.clear())
	game.events.run_started.connect(func(_class_id: String):
		discovered.clear()
		_incoming.clear()
		_reset_pocket_caches())
	game.events.event_announced.connect(note_incoming)
	game.events.stage_entered.connect(func(_stage: int, _retry: bool):
		_incoming.clear()
		_reset_pocket_caches())
	game.events.stage_content_cleared.connect(func(_reason: String): _incoming.clear())
	game.events.event_started.connect(func(id: String): _incoming.erase(id))
	game.events.event_ended.connect(func(id: String, _outcome: String): _incoming.erase(id))


func note_incoming(event_id: String, seconds: float, at: Vector3) -> void:
	if seconds > 0.0 and at.is_finite():
		_incoming[event_id] = {"at": at, "offer_left": seconds} if event_id in EventDirector.PARTICIPATORY else {"at": at}
	else:
		_incoming.erase(event_id)


func step_incoming(delta: float) -> void:
	for id in _incoming.keys():
		var entry: Dictionary = _incoming[id]
		if not entry.has("offer_left"):
			continue
		entry["offer_left"] -= delta
		if entry["offer_left"] <= 0.0:
			_incoming.erase(id)


func held_ids() -> Array:
	return _incoming.keys().filter(func(id): return not _incoming[id].has("offer_left"))


func incoming_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in _incoming:
		out.append({"at": _incoming[id]["at"], "kind": "event_announced", "icon": "obj_event", "mark": true})
	return out


func targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var flow = game.flow
	match flow.state_name():
		"stage", "beacon":
			if yard_locked:
				var member = _yard_crew()
				if member != null:
					out.append({"at": member.global_position, "kind": "pack_arrived", "icon": Objectives.glyph("break_yard_crew")})
				return out
			var marks := _mount_marks()
			out.append_array(marks)
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
				out.append_array(cage_targets())
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


func unfinished_sites() -> Array:
	if game == null or game.world == null or game.world.activities == null:
		return []
	return game.world.activities.on_offer()


func cage_targets() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var rescue = game.world.get("rescue") if game != null and game.world != null else null
	if rescue == null:
		return out
	var ally := Interactables.row("ally")
	for cage in rescue.waiting():
		out.append({"at": cage["at"], "kind": "rescue_completed", "color": ally["color"], "icon": ally["icon"]})
	return out


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


static func sight_clear(ground: Callable, from: Vector3, to: Vector3) -> bool:
	var span := from.distance_to(to)
	var steps := int(span / POCKET_STEP_M)
	for i in range(1, steps):
		var p := from.lerp(to, float(i) * POCKET_STEP_M / span)
		if ground.call(p.x, p.z) > p.y:
			return false
	return true


func _doors_of(map) -> Array[Dictionary]:
	var id: int = map.get_instance_id() if map != null else 0
	var count: int = map.contraptions.size() if map != null and "contraptions" in map else -1
	if id != _doors_map_id or count != _doors_count:
		_doors_map_id = id
		_doors_count = count
		_doors_cache = pocket_doors(map)
	return _doors_cache


func _reset_pocket_caches() -> void:
	_pockets_ball = Vector3.INF
	_targets_ball = Vector3.INF
	_targets_cache.clear()


static func _overlays_of(terrain) -> Array:
	return terrain.overlays if terrain != null and "overlays" in terrain else _NO_OVERLAYS


static func _opened_sig(contraptions) -> Vector2i:
	if contraptions == null:
		return Vector2i.ZERO
	var count := 0
	var bits := 0
	for v in contraptions.valves:
		if v["open"]:
			count += 1
			bits ^= hash(v["spec"]["id"])
	for w in contraptions.walls:
		if w["broken"]:
			count += 1
			bits ^= hash(w["spec"]["id"])
	return Vector2i(count, bits)


func _discovered_sig() -> Vector2i:
	var bits := 0
	for key in discovered:
		bits ^= hash(key)
	return Vector2i(discovered.size(), bits)


func _pocket_targets_now() -> Array[Dictionary]:
	if discovered.is_empty() or game == null or game.world == null or game.player == null:
		return _EMPTY_TARGETS
	var terrain = game.world.terrain
	var all_doors := _doors_of(terrain.map())
	if all_doors.is_empty():
		return _EMPTY_TARGETS
	var contraptions = game.world.contraptions.get(terrain.stage)
	var opened_sig := _opened_sig(contraptions)
	var found_sig := _discovered_sig()
	var ball: Vector3 = game.player.shown_position()
	var overlays := _overlays_of(terrain)
	if ball.distance_to(_targets_ball) < POCKET_STILL_M and _doors_map_id == _targets_map_id \
			and _doors_count == _targets_doors_count and found_sig == _targets_found \
			and opened_sig == _targets_opened and terrain.stage == _targets_stage \
			and overlays == _targets_overlays:
		return _targets_cache
	_targets_ball = ball
	_targets_map_id = _doors_map_id
	_targets_doors_count = _doors_count
	_targets_found = found_sig
	_targets_opened = opened_sig
	_targets_stage = terrain.stage
	_targets_overlays = overlays.duplicate()
	var opened := _opened_ids(contraptions)
	var doors: Array[Dictionary] = []
	for door in all_doors:
		if not opened.has(door["id"]):
			doors.append(door)
	_targets_cache = pocket_targets(doors, discovered, ball, Callable(terrain, "height"))
	return _targets_cache


func note_pockets(size: Vector2) -> void:
	if game == null or game.world == null or game.player == null or not game.flow.in_play():
		return
	var terrain = game.world.terrain
	var doors := _doors_of(terrain.map())
	if doors.is_empty() or _all_found(doors):
		return
	var cam: Camera3D = game.camera.cam
	var ball: Vector3 = game.player.shown_position()
	var overlays := _overlays_of(terrain)
	if ball.distance_to(_pockets_ball) < POCKET_STILL_M and cam.global_transform == _pockets_cam_xform and size == _pockets_size \
			and _doors_map_id == _pockets_map_id and _doors_count == _pockets_doors_count \
			and discovered.size() == _pockets_found and overlays == _pockets_overlays:
		return
	_pockets_ball = ball
	_pockets_cam_xform = cam.global_transform
	_pockets_size = size
	_pockets_map_id = _doors_map_id
	_pockets_doors_count = _doors_count
	_pockets_overlays = overlays.duplicate()
	var ground := Callable(terrain, "height")
	for door in doors:
		if discovered.has(door["key"]):
			continue
		var seen := pocket_targets([door], {door["key"]: true}, ball, ground)
		if seen.is_empty():
			continue
		var at: Vector3 = seen[0]["at"]
		if not cam.is_position_behind(at) and Rect2(Vector2.ZERO, size).has_point(cam.unproject_position(at)):
			discovered[door["key"]] = true
	_pockets_found = discovered.size()


func _all_found(doors: Array[Dictionary]) -> bool:
	if discovered.size() < doors.size():
		return false
	for door in doors:
		if not discovered.has(door["key"]):
			return false
	return true


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


func _row_icon() -> String:
	return objective_icon if objective_icon != "" else Objectives.glyph(objective_id)


func _glyph(fallback: String) -> String:
	return Objectives.glyph(objective_id) if objective_id not in ["", "find_activity", CLAMP_ROW] else fallback


func _clamp_crew() -> Node3D:
	var gate = game.flow.get("gate")
	if objective_id != CLAMP_ROW or gate == null or not gate.has_method("clamp_crew") or game.player == null:
		return null
	return gate.clamp_crew(game.player.shown_position())


func _yard_crew() -> Node3D:
	var gate = game.flow.get("gate")
	if gate == null or not gate.has_method("yard_crew") or game.player == null:
		return null
	return gate.yard_crew(game.player.shown_position())


static func view_rect(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("toasts", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


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
		var shift := 0.0
		if tag != "":
			var place := tag_place(box, tag, room, taken, keep_clear)
			under = place.get("under", false)
			shift = place.get("shift", 0.0)
			tag = tag if not place.is_empty() else ""
		if tag == "" and not _free(mark_rect(box, ""), room, taken):
			if group["seen"]:
				away.append_array(group["targets"])
			continue
		taken.append(mark_rect(box, tag, under, shift))
		out.append({"box": box, "color": group["color"], "tag": tag, "under": under, "shift": shift})
	var view := view_rect(size)
	var slid_now := {}
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
		var tip := _on_edge(view, centre, dir)
		var span := lerpf(MAX_SIZE, MIN_SIZE, near)
		var offset := arrow_slide(view, tip, dir, span, sign_rects, float(_slide.get(target["at"], 0.0)))
		slid_now[target["at"]] = offset
		tip += _edge_tangent(view, tip) * offset
		out.append({"at": tip, "dir": dir, "size": span,
			"color": marker_color(target), "icon": target["icon"]})
	_slide = slid_now
	return out


static func _edge_tangent(view: Rect2, tip: Vector2) -> Vector2:
	var on_side := absf(tip.x - view.position.x) < 0.5 or absf(tip.x - view.end.x) < 0.5
	return Vector2.DOWN if on_side else Vector2.RIGHT


static func arrow_slide(view: Rect2, tip: Vector2, dir: Vector2, span: float, signs: Array[Rect2], held: float) -> float:
	if signs.is_empty():
		return 0.0
	var tangent := _edge_tangent(view, tip)
	var low := (view.position - tip).dot(tangent)
	var high := (view.end - tip).dot(tangent)
	var clear := func(offset: float, room: float) -> bool:
		var footprint := edge_footprint(tip + tangent * offset, dir, span).grow(room)
		return not signs.any(func(sign: Rect2): return sign.intersects(footprint))
	if held == 0.0:
		if clear.call(0.0, 0.0):
			return 0.0
	elif held >= low and held <= high and clear.call(held, 0.0):
		return 0.0 if clear.call(0.0, ARROW_HOLD) else held
	var first := -1.0 if held < 0.0 else 1.0
	for room in [ARROW_HOLD, 0.0]:
		for step in range(1, int(ARROW_SLIDE_MAX) + 1):
			for way in [first, -first]:
				var offset: float = way * step
				if offset >= low and offset <= high and clear.call(offset, room):
					return offset
	return clampf(held, low, high)


static func edge_footprint(tip: Vector2, dir: Vector2, span: float) -> Rect2:
	var icon := tip - dir * span * ICON_BACK
	var fin := Vector2(-dir.y, dir.x) * span * 0.8
	var root := tip - dir * span
	var bounds := Rect2(icon - Vector2.ONE * span * 0.5, Vector2.ONE * span)
	return bounds.expand(tip).expand(root + fin).expand(root - fin).grow(1.0)


func in_sight(cam: Camera3D, at: Vector3) -> bool:
	if not cam.is_inside_tree():
		return true
	var from := cam.global_position
	var query := PhysicsRayQueryParameters3D.create(from, at, Hitscan.WORLD)
	var hit: Dictionary = cam.get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit["position"].distance_to(at) <= SIGHT_SLACK_M


func avoid_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	for node in get_tree().get_nodes_in_group(FlourishPlayer.AVOID_GROUP):
		if node is Control and node.is_visible_in_tree():
			out.append(node.get_global_rect().grow(AVOID_GROW))
	return out


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


static func mark_view(size: Vector2) -> Rect2:
	var top := ScreenRegions.rect("top", size).end.y + BAND_CLEARANCE
	var bottom := ScreenRegions.rect("bottom", size).position.y - BAND_CLEARANCE
	var inset := size.x * SIDE_INSET
	return Rect2(inset, top, size.x - 2.0 * inset, bottom - top)


func drawn_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for marker in _shown:
		if marker.has("box"):
			out.append(mark_rect(marker["box"], marker["tag"], marker["under"], marker["shift"]))
	return out


func tag_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for marker in _shown:
		if marker.has("box") and String(marker["tag"]) != "":
			out.append(tag_rect(marker["box"], marker["tag"], marker["under"], marker["shift"]))
	return out


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	for marker in _shown:
		if marker.get("tag", "") != "":
			out.append(marker["tag"])
	return out


static func tag_place(box: Rect2, tag: String, room: Rect2, taken: Array[Rect2], clear: Array[Rect2]) -> Dictionary:
	for under in [false, true]:
		var chip := tag_rect(box, tag, under)
		var shifts: Array[float] = [0.0]
		for other in clear:
			shifts.append(other.position.x - chip.end.x - TAG_CLEAR)
			shifts.append(other.end.x - chip.position.x + TAG_CLEAR)
		shifts.sort_custom(func(a: float, b: float): return absf(a) < absf(b))
		for shift in shifts:
			if absf(shift) > chip.size.x * TAG_SLIDE:
				break
			if tag_free(box, tag, under, room, taken, clear, shift):
				return {"under": under, "shift": shift}
	return {}


static func tag_free(box: Rect2, tag: String, under: bool, room: Rect2, taken: Array[Rect2], clear: Array[Rect2], shift := 0.0) -> bool:
	var chip := tag_rect(box, tag, under, shift)
	return _free(mark_rect(box, tag, under, shift), room, taken) and not clear.any(func(other: Rect2): return other.intersects(chip))


static func _free(rect: Rect2, room: Rect2, taken: Array[Rect2]) -> bool:
	return room.encloses(rect) and not taken.any(func(other: Rect2): return other.intersects(rect))


static func _slid(box: Rect2, room: Rect2) -> Rect2:
	var grown := mark_rect(box, "")
	var move := Vector2(maxf(room.position.x - grown.position.x, 0.0) + minf(room.end.x - grown.end.x, 0.0),
		maxf(room.position.y - grown.position.y, 0.0) + minf(room.end.y - grown.end.y, 0.0))
	if absf(move.x) >= box.size.x * 0.5 or absf(move.y) >= box.size.y * 0.5:
		return box
	return Rect2(box.position + move, box.size)


static func mark_rect(box: Rect2, tag: String, under := false, shift := 0.0) -> Rect2:
	var out := box.grow(maxf(box.size.x, box.size.y) * 0.5 * MARK_PULSE + MARK_STROKE)
	return out.merge(tag_rect(box, tag, under, shift)) if tag != "" else out


static func tag_rect(box: Rect2, tag: String, under := false, shift := 0.0) -> Rect2:
	var chip := Vector2(UiDraw.width(tag, TAG_FONT), UiFonts.bold().get_height(TAG_FONT)) + TAG_PAD * 2.0
	var off := maxf(box.size.x, box.size.y) * 0.5 * MARK_PULSE + MARK_STROKE + TAG_GAP
	var top := box.end.y + off if under else box.position.y - off - chip.y
	return Rect2(Vector2(box.get_center().x - chip.x * 0.5 + shift, top), chip)


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
	var breathing := false
	for marker in now:
		if marker.has("box"):
			breathing = true
			break
	if breathing or now != _shown:
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
		var icon_at := tip - dir * s * ICON_BACK
		draw_texture_rect(Icons.texture(marker["icon"]), Rect2(icon_at - Vector2(s, s) * 0.5, Vector2(s, s)), false, Icons.tint(marker["icon"], color))


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
	var chip := tag_rect(rest, tag, under, float(marker.get("shift", 0.0)))
	var stem_x := clampf(rest.get_center().x, chip.position.x + 8.0, chip.end.x - 8.0)
	var stem := Vector2(stem_x, chip.position.y if under else chip.end.y)
	var point := -1.0 if under else 1.0
	draw_colored_polygon(PackedVector2Array([stem + Vector2(-6.0, -point), stem + Vector2(6.0, -point), stem + Vector2(0.0, (TAG_GAP + 2.0) * point)]), Color(Palette.CHARCOAL, 0.92))
	draw_rect(chip, Color(Palette.CHARCOAL, 0.92))
	draw_rect(chip, color, false, 2.0)
	UiDraw.text(self, chip.position.x + TAG_PAD.x, chip.get_center().y, tag, TAG_FONT, color)
