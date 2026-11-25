extends SceneTree

const Game := preload("res://src/game.gd")
const BotDriver := preload("res://tools/bot_driver.gd")
const SimClock := preload("res://src/core/sim_clock.gd")
const RunLog := preload("res://src/core/run_log.gd")
const Augments := preload("res://src/movement/augments.gd")
const ParkSchema := preload("res://src/world/park/park_schema.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const FloorRule := preload("res://src/combat/floor_rule.gd")
const CinderHeat := preload("res://src/world/cinder_heat.gd")
const ParkRecipes := preload("res://src/world/park/park_recipes.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const CINDER_SOURCE := CinderHeat.SOURCE
const CINDER_BURN := CinderHeat.BURN_FACT


const TABLE := "slice"
const ROUTES := "res://tools/traversal_lines.json"
const PILOTS := ["sable", "rivet", "kest"]
const DEFAULT_SEEDS := [1, 2, 3, 4, 5, 6, 7, 8]
const DEFAULT_OUT := "res://../../artifacts/local/traversal"
const WORLD_AIMS := [Augments.AIM_REACH, Augments.AIM_ASSIST]
const PROBE_SECONDS := 0.1
const PROBE_SPOKES := 12
const PROBE_PITCHES := [0.0, 0.4, 0.8]
const RIDE_FACTS := ["ride_grapple_line", "ride_chute", "ride_skylight", "ride_glide_drop", "wall_crumbled", "thermal_ride"]
const KICKER_LAUNCH := "kicker_launch"

const PARK := "park"
const PARK_PILOTS := {"sable": "pylon_engineer", "rivet": "runner_gunner", "kest": "demolitions_caster",
	"tarn": "tarn", "tally": "tally", "cannon": "remembered_cannon"}
const FLOOR := "floor"
const FLOOR_CLASS := "rivet"
const FLOOR_HANDS := ["move", "brake_held"]
const PARK_DEFS := "res://src/core/park_defs.gd"
const PARK_LINES := "res://assets/park/%s/lines.json"
const PARK_OUT := "res://../../artifacts/local/traversal/park"
const FIXTURE_STAGE := 0
const FIXTURE_MAP := "park_test"
const FIXTURE_SWAP := ["\"map\": \"park_dam\"", "\"map\": \"park_test\""]
const GRAPH_FILE := "res://assets/park/%s/graph.bin"
const WAYMARK_PASSED := 12.0
const DROP_EVENT := 4.0
const PARK_RIDE_FACTS := ["ride_chute", "ride_grapple_line", "ride_bowl", "ride_drop", "ride_ledge",
	"kicker_launch", "ride_glide_drop", "thermal_ride", "ride_hop"]
const RIDE_EXTRAS := ["crater_ride", "lift_fired"]
const VERB_SIGNALS := {"jumped": "jump", "boosted": "boost", "dashed": "dash", "slammed": "slam", "special_used": "special",
	"vault_kicked": "vault", "sprint_started": "sprint", "rocket_jumped": "rocket_jump", "blink_used": "blink",
	"mounted": "mount", "shield_vaulted": "shield_vault"}

const BAND_REACHED := "%d of %d seeds"
const BAND_TIME := [60.0, 120.0]
const BAND_TIME_WORST := 150.0
const BAND_SEGMENT := [12.0, 45.0]
const BAND_FLOW := 0.70
const BAND_FLOW_WORST := 0.60
const BAND_AIRBORNE := [0.12, 0.45]
const BAND_AIRBORNE_HIGH := [0.25, 0.60]
const BAND_AIRBORNE_HIGH_STAGES := [5, 6]
const BAND_TIER3 := 3.0
const BAND_QUIET := 20.0
const BAND_ANCHOR := 40.0
const BAND_VERBS := 3
const BAND_LENGTH := [1.3, 2.0]
const BAND_FLOOR := 2.0
const STALLED_PATH_M := 1.0

static var graph_notes := 0
static var _park_defs_source := ""
static var _graphs := {}


class Sampler:
	extends RefCounted

	var game
	var traversal: RunLog.Traversal
	var engaged := false
	var time_to_warden = null
	var max_anchor_gap := 0.0
	var _path := 0.0
	var _last_anchor := 0.0
	var _last_anchor_ball := Vector3.INF
	var _last_anchor_time := 0.0
	var _gap_from := Vector3.INF
	var _gap_to := Vector3.INF
	var _gap_t := [0.0, 0.0]
	var _last_ball := Vector3.INF
	var _clock := -1.0
	var _rides: Array[String] = []
	var _was_grounded := true
	var _furthest_z := -INF
	var _uphill := 0.0
	var tracing := false
	var trace: Array = []
	var record_glide := false
	var park := false
	var waymarks: Array = []
	var graph = null
	var graph_note := ""
	var dead_stop_at: Array = []
	var _mark_times: Array = []
	var _verbs: Array[String] = []
	var _last_event := 0.0
	var _quiet_max := 0.0
	var _drop_top := -INF
	var _start := Vector3.INF
	var _start_time := 0.0
	var _straight := 0.0
	var _graph_start = null
	var cruise := 0.0
	var _floor_ticks := 0
	var _grounded_ticks := 0
	var _cinder_burns := 0
	var _cinder_hp := 0.0
	var contacts = null

	func _init(game_ref) -> void:
		game = game_ref
		cruise = game.player.tuning.f("cruise")
		traversal = RunLog.Traversal.new(Engine.physics_ticks_per_second, cruise)
		game.events.warden_engaged.connect(_on_engaged)
		game.events.world_fact.connect(_on_fact)
		game.events.line_state_changed.connect(_on_line)
		game.events.player_hit.connect(func(amount: float, source: String):
			if source == CINDER_SOURCE and _counting():
				_cinder_hp += amount)
		for signal_name in VERB_SIGNALS:
			if game.events.has_signal(signal_name):
				var verb: String = VERB_SIGNALS[signal_name]
				game.events.connect(signal_name, func(_a = null, _b = null, _c = null): _on_verb(verb))

	func setup_park(marks: Array, graph_ref) -> void:
		park = true
		waymarks = marks
		graph = graph_ref
		_mark_times = []
		_mark_times.resize(marks.size())
		if graph == null:
			graph_note = "no stage graph: progress_m is null"

	func _counting() -> bool:
		return not engaged and game.flow.in_stage()

	func _on_fact(kind: String, _at: Vector3) -> void:
		if not _counting():
			return
		if kind == CINDER_BURN:
			_cinder_burns += 1
		if kind in RIDE_FACTS and not kind in _rides:
			_rides.append(kind)
		if park:
			if kind in PARK_RIDE_FACTS:
				_event()
			if kind in PARK_RIDE_FACTS or kind in RIDE_FACTS or kind in RIDE_EXTRAS or kind.begins_with("ride_"):
				_verb(kind)
		elif kind in RIDE_FACTS or kind in RIDE_EXTRAS or kind.begins_with("ride_"):
			_event()
			_verb(kind)

	func _on_line(state: String, _target, _at: Vector3, _cause: String) -> void:
		if not _counting():
			return
		if state.begins_with("latched"):
			_event()
			_verb("bite")
		elif state == "smash_lands":
			_verb("smash")

	func _on_verb(verb: String) -> void:
		if _counting():
			_verb(verb)

	func _verb(name: String) -> void:
		if not name in _verbs:
			_verbs.append(name)

	func _ride_facts() -> Array:
		if park:
			return _verbs.filter(func(v): return v in PARK_RIDE_FACTS)
		return _verbs.filter(func(v): return v in RIDE_FACTS or v in RIDE_EXTRAS or v.begins_with("ride_") or v == KICKER_LAUNCH)

	func _event() -> void:
		var now: float = game.run.stage_time
		_quiet_max = maxf(_quiet_max, now - _last_event)
		_last_event = now

	func _on_engaged(_stage: int) -> void:
		if engaged:
			return
		engaged = true
		time_to_warden = snappedf(game.run.stage_time, 0.01)
		_close_gap()
		_close_quiet()
		var last := waymarks.size() - 1
		if park and last > 0 and _mark_times[last] == null:
			_mark_times[last] = game.run.stage_time

	func sample() -> void:
		if engaged or not game.flow.in_stage() or game.run.stage_time <= _clock:
			return
		_clock = game.run.stage_time
		var player = game.player
		var ball: Vector3 = player.ball_position()
		if _start == Vector3.INF:
			_begin(ball)
			_last_anchor_ball = ball
			_last_anchor_time = game.run.stage_time
		if _last_ball != Vector3.INF:
			_path += ball.distance_to(_last_ball)
		_last_ball = ball
		_furthest_z = maxf(_furthest_z, ball.z)
		_uphill = maxf(_uphill, _furthest_z - ball.z)
		var grounded: bool = player.state.grounded
		if grounded:
			_grounded_ticks += 1
			if FloorRule.on_floor(player.state):
				_floor_ticks += 1
		if _was_grounded and not grounded and game.ctx.terrain.map().near_kicker_lip(Vector2(ball.x, ball.z)):
			if not KICKER_LAUNCH in _rides:
				_rides.append(KICKER_LAUNCH)
			_event()
			_verb(KICKER_LAUNCH)
		_was_grounded = grounded
		if record_glide and player.kit.gliding:
			_verb("glide")
		if _anchored(ball):
			_note_gap(ball)
			_last_anchor = _path
			_last_anchor_ball = ball
			_last_anchor_time = game.run.stage_time
		_watch_drop(ball)
		_watch_marks(ball)
		var intent = player.intent
		var stops := traversal.dead_stops
		traversal.step(player.speed_tier(), player.planar_velocity().length(), intent.brake_held, RunLog.Traversal.is_exempt(player), not grounded)
		if traversal.dead_stops > stops:
			dead_stop_at.append({"time": snappedf(game.run.stage_time, 0.01), "at": [snappedf(ball.x, 0.1), snappedf(ball.z, 0.1)]})
		if contacts != null:
			contacts.observe(game, ball, traversal.dead_stops > stops)
		if tracing:
			_record_tick(player, ball, grounded)

	func _begin(ball: Vector3) -> void:
		_start = ball
		_start_time = game.run.stage_time
		_last_event = _start_time
		_drop_top = ball.y
		var stage: int = game.run.stage
		var engage: Vector3 = game.ctx.terrain.beacon_point(stage)
		_straight = Vector2(ball.x, ball.z).distance_to(Vector2(engage.x, engage.z))
		if park and not _mark_times.is_empty():
			_mark_times[0] = _start_time
		if graph != null:
			var d: float = graph.d_landmark(ball)
			_graph_start = d if is_finite(d) else null

	func _watch_drop(ball: Vector3) -> void:
		_drop_top = maxf(_drop_top, ball.y)
		if _drop_top - ball.y >= DROP_EVENT:
			_event()
			_drop_top = ball.y

	func _watch_marks(ball: Vector3) -> void:
		if not park:
			return
		for i in range(1, waymarks.size()):
			if _mark_times[i] != null:
				continue
			if Vector2(ball.x, ball.z).distance_to(waymarks[i]["at"]) <= WAYMARK_PASSED:
				_mark_times[i] = game.run.stage_time
			break

	func _close_quiet() -> void:
		var now: float = game.run.stage_time
		_quiet_max = maxf(_quiet_max, now - _last_event)

	func _record_tick(player, ball: Vector3, grounded: bool) -> void:
		var contacts: Array = []
		for body in player._rigid.get_colliding_bodies():
			contacts.append(_contact_path(body))
		contacts.sort()
		var velocity: Vector3 = player.state.velocity
		var aim_origin: Vector3 = game.ctx.aim_origin()
		var aim_forward: Vector3 = game.ctx.aim_forward()
		trace.append({
			"tick": traversal.ticks, "time": snappedf(game.run.stage_time, 0.001),
			"at": [snappedf(ball.x, 0.01), snappedf(ball.y, 0.01), snappedf(ball.z, 0.01)],
			"velocity": [snappedf(velocity.x, 0.01), snappedf(velocity.y, 0.01), snappedf(velocity.z, 0.01)],
			"planar_speed": snappedf(player.planar_velocity().length(), 0.01), "tier": player.speed_tier(),
			"grounded": grounded, "contacts": contacts, "dead_stops": traversal.dead_stops,
			"frozen": player.frozen(), "mounted": player.kit.mounted, "state": game.flow.state_name(),
			"camera_rng": str(game.camera._shake_rng.state),
			"camera_pitch_bias": game.camera._pitch_bias, "camera_spring_length": game.camera.arm.spring_length,
			"aim_origin": [aim_origin.x, aim_origin.y, aim_origin.z],
			"aim_forward": [aim_forward.x, aim_forward.y, aim_forward.z],
		})

	func _contact_path(body: Node) -> String:
		var names: Array[String] = []
		var node := body
		while node != null:
			var label := String(node.name)
			names.push_front("%s[%d]" % [node.get_class(), node.get_index()] if label.begins_with("@") else label)
			node = node.get_parent()
		return "/" + "/".join(names)

	func _anchored(ball: Vector3) -> bool:
		var reach: float = game.player.grapple_range()
		var aim: Dictionary = game.player.kit.aim
		if int(aim.get("state", Augments.AIM_NONE)) in WORLD_AIMS and ball.distance_to(aim["point"]) <= reach:
			return true
		if traversal.ticks % maxi(1, int(round(PROBE_SECONDS * Engine.physics_ticks_per_second))) != 0:
			return false
		var space = game.get_world_3d().direct_space_state
		for pitch in PROBE_PITCHES:
			for i in PROBE_SPOKES:
				var yaw := TAU * float(i) / float(PROBE_SPOKES)
				var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
				var hit: Dictionary = Augments.grapple_target(space, ball, dir, ball, reach, 0.0, Augments.WORLD_MASK, false)
				if int(hit.get("state", Augments.AIM_NONE)) in WORLD_AIMS and ball.distance_to(hit["point"]) <= reach:
					return true
		return false

	func _close_gap() -> void:
		_note_gap(_last_ball)

	func _note_gap(ball: Vector3) -> void:
		var gap := _path - _last_anchor
		if gap > max_anchor_gap and _last_anchor_ball != Vector3.INF and ball != Vector3.INF:
			_gap_from = _last_anchor_ball
			_gap_to = ball
			_gap_t = [snappedf(_last_anchor_time, 0.01), snappedf(game.run.stage_time, 0.01)]
		max_anchor_gap = maxf(max_anchor_gap, gap)

	func _segments() -> Array:
		var out: Array = []
		for i in range(1, _mark_times.size()):
			var a = _mark_times[i - 1]
			var b = _mark_times[i]
			out.append(snappedf(float(b) - float(a), 0.01) if a != null and b != null else null)
		return out

	func _progress():
		if graph == null or _graph_start == null or _last_ball == Vector3.INF:
			return null
		var seconds: float = (time_to_warden if time_to_warden != null else game.run.stage_time) - _start_time
		if seconds <= 0.0:
			return null
		var d: float = graph.d_landmark(_last_ball)
		if not is_finite(d):
			return null
		return snappedf((float(_graph_start) - d) / seconds, 0.01)

	func _xz(p: Vector3) -> Variant:
		return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)] if p != Vector3.INF else null

	func result(seed_number: int, outcome: String) -> Dictionary:
		if not engaged:
			_close_gap()
			_close_quiet()
		var share = traversal.flow_share()
		var airborne = traversal.airborne_share()
		var segments := _segments()
		var longest = null
		for s in segments:
			if s != null:
				longest = s if longest == null else maxf(float(longest), float(s))
		return {
			"seed": seed_number,
			"flow_share": snappedf(float(share), 0.0001) if share != null else 0.0,
			"dead_stops": traversal.dead_stops,
			"max_anchor_gap_m": snappedf(max_anchor_gap, 0.1),
			"max_anchor_gap_from": _xz(_gap_from),
			"max_anchor_gap_to": _xz(_gap_to),
			"max_anchor_gap_t": _gap_t.duplicate(),
			"time_to_warden_s": time_to_warden,
			"reached_warden": engaged,
			"path_length_m": snappedf(_path, 0.1),
			"rides": _rides.duplicate(),
			"uphill_m": snappedf(_uphill, 0.1),
			"outcome": outcome,
			"ticks": traversal.ticks,
			"airborne_share": snappedf(float(airborne), 0.0001) if airborne != null else 0.0,
			"peak_speed_mps": snappedf(traversal.peak_speed, 0.01),
			"tier3_s": snappedf(traversal.blazing_seconds(), 0.01),
			"segments_s": segments,
			"segment_s": longest,
			"quiet_max_s": snappedf(_quiet_max, 0.01),
			"distinct_verbs": _verbs.size(),
			"distinct_ride_facts": _ride_facts().size(),
			"verbs": _verbs.duplicate(),
			"blazing_mps": snappedf(SpeedTier.MULTIPLES[SpeedTier.BLAZING] * cruise, 0.01),
			"length_ratio": snappedf(_path / _straight, 0.01) if _straight > 0.0 else null,
			"dead_stop_at": dead_stop_at.duplicate(true),
			"progress_m": _progress(),
			"floor_share": snappedf(float(_floor_ticks) / float(traversal.ticks), 0.0001) if traversal.ticks > 0 else 0.0,
			"carve_share": snappedf(1.0 - float(_floor_ticks) / float(_grounded_ticks), 0.0001) if _grounded_ticks > 0 else 0.0,
			"cinder_burns": _cinder_burns,
			"cinder_hp": snappedf(_cinder_hp, 0.01),
		}


class AnchorContacts:
	extends RefCounted

	const NEAR_M := 1.5
	const Y_SLACK_M := 1.5
	const BOUNCE_MIN_MPS := 1.0
	const SURFACE_LIMIT_M := 2.0
	const CELL_M := 8.0

	var park_id := ""
	var seed_number := 0
	var lane := {}
	var park_rows: Array = []
	var boxes: Array = []
	var events: Array = []
	var fields := 0
	var _body_boxes := {}
	var _grid := {}
	var closest_surface := {"dist": INF, "row": ""}
	var closest_corner := {"dist": INF, "row": ""}
	var _ticks := 0
	var _tries := 0
	var touch_ticks := 0
	var _prev_v := Vector3.INF
	var _prev_touch := {}

	func _init(park_name: String, seed_value: int, lane_mask: Dictionary, rows: Array) -> void:
		park_id = park_name
		seed_number = seed_value
		lane = lane_mask
		park_rows = rows

	static func box_record(xf: Transform3D, size: Vector3, info: Dictionary) -> Dictionary:
		var half := size * 0.5
		var corners: Array = []
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var p := xf * Vector3(sx * half.x, 0.0, sz * half.z)
				corners.append(Vector2(p.x, p.z))
		var out := info.duplicate()
		out["xf"] = xf
		out["half"] = half
		out["corners"] = corners
		out["y0"] = xf.origin.y - half.y
		out["y1"] = xf.origin.y + half.y
		return out

	static func hull_outline(points: PackedVector3Array) -> Dictionary:
		var flat: Array = []
		var lo := INF
		var hi := -INF
		for p in points:
			flat.append(Vector2(p.x, p.z))
			lo = minf(lo, p.y)
			hi = maxf(hi, p.y)
		flat.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
		var uniq: Array = []
		for v: Vector2 in flat:
			if uniq.is_empty() or not (uniq[-1] as Vector2).is_equal_approx(v):
				uniq.append(v)
		if uniq.size() < 3:
			return {"poly": uniq, "y0": lo, "y1": hi}
		var chain: Array = []
		for pass_index in 2:
			var start := chain.size()
			for v: Vector2 in (uniq if pass_index == 0 else _reversed(uniq)):
				while chain.size() >= start + 2 and ((chain[-1] - chain[-2]) as Vector2).cross(v - chain[-2]) <= 0.0:
					chain.pop_back()
				chain.append(v)
			chain.pop_back()
		return {"poly": chain, "y0": lo, "y1": hi}

	static func _reversed(list: Array) -> Array:
		var out := list.duplicate()
		out.reverse()
		return out

	static func hull_record(xf: Transform3D, outline: Dictionary, info: Dictionary) -> Dictionary:
		var poly: Array = []
		for v: Vector2 in outline["poly"]:
			var p := xf * Vector3(v.x, 0.0, v.y)
			poly.append(Vector2(p.x, p.z))
		if poly.size() >= 3 and xf.basis.determinant() < 0.0:
			poly.reverse()
		var out := info.duplicate()
		out["xf"] = xf
		out["poly"] = poly
		out["corners"] = poly
		out["y0"] = (xf * Vector3(0.0, float(outline["y0"]), 0.0)).y
		out["y1"] = (xf * Vector3(0.0, float(outline["y1"]), 0.0)).y
		return out

	static func surface_of(at: Vector3, b: Dictionary) -> Dictionary:
		if b.has("poly"):
			return _prism_surface(at, b)
		var local: Vector3 = (b["xf"] as Transform3D).affine_inverse() * at
		var half: Vector3 = b["half"]
		var near := Vector3(clampf(local.x, -half.x, half.x), clampf(local.y, -half.y, half.y), clampf(local.z, -half.z, half.z))
		var d := local.distance_to(near)
		return {"dist": d, "normal": ((b["xf"] as Transform3D).basis * (local - near)).normalized() if d > 0.0 else Vector3.UP}

	static func _prism_surface(at: Vector3, b: Dictionary) -> Dictionary:
		var poly: Array = b["poly"]
		var flat := Vector2(at.x, at.z)
		var inside := poly.size() >= 3
		var best := INF
		var nearest := flat
		for i in poly.size():
			var a: Vector2 = poly[i]
			var c: Vector2 = poly[(i + 1) % poly.size()]
			if inside and (c - a).cross(flat - a) < 0.0:
				inside = false
			var edge := c - a
			var len2 := edge.length_squared()
			var t := clampf((flat - a).dot(edge) / len2, 0.0, 1.0) if len2 > 0.0 else 0.0
			var q := a + edge * t
			var dq := flat.distance_squared_to(q)
			if dq < best:
				best = dq
				nearest = q
		var dxz := 0.0 if inside or poly.is_empty() else sqrt(best)
		var y0 := float(b["y0"])
		var y1 := float(b["y1"])
		var dy := (at.y - y0) if at.y < y0 else ((at.y - y1) if at.y > y1 else 0.0)
		var d := Vector2(dxz, dy).length()
		if d <= 0.0:
			return {"dist": 0.0, "normal": Vector3.UP}
		var away := flat - nearest if dxz > 0.0 else Vector2.ZERO
		return {"dist": d, "normal": Vector3(away.x, dy, away.y).normalized()}

	static func fit_info(row: Dictionary, kit: bool) -> Dictionary:
		var info := {"row": String(row.get("id", "")), "key": String(row.get("recipe", "")), "size_y": float(row["size"][1]), "fitted": false, "over_limit": false}
		if not kit or ParkRecipes.anchor_fit_boxes(row).is_empty():
			return info
		var recipe := String(row.get("recipe", ""))
		info["key"] = ParkRecipes.anchor_paths(recipe)[ParkRecipes.anchor_variant(row)].get_file().get_basename()
		for entry: Dictionary in ParkRecipes.anchor_fit_table().get("fits", {}).get(info["key"], []):
			if is_equal_approx(float(entry["size"]), float(info["size_y"])):
				info["fitted"] = true
				info["over_limit"] = bool(entry.get("over_limit", false))
		return info

	static func collect(root: Node, rows: Array) -> Array:
		var by_id := {}
		for row: Dictionary in rows:
			by_id[String(row.get("id", ""))] = row
		var out: Array = []
		var outlines := {}
		for node: Node in root.find_children("Park_*", "Node3D", true, false):
			if not node.has_meta("anchor_posts") or not by_id.has(String(node.name).substr(5)):
				continue
			var body := node.get_node_or_null("Collider")
			if body == null:
				continue
			var info := fit_info(by_id[String(node.name).substr(5)], bool(node.get_meta("anchor_kit", false)))
			info["body"] = body.get_instance_id()
			for shape: Dictionary in ParkRecipes.collider_shapes(body):
				if shape.shape is BoxShape3D:
					out.append(box_record(shape.global_transform, (shape.shape as BoxShape3D).size, info))
				elif shape.shape is ConvexPolygonShape3D:
					var hull := shape.shape as ConvexPolygonShape3D
					if not outlines.has(hull):
						outlines[hull] = hull_outline(hull.points)
					out.append(hull_record(shape.global_transform, outlines[hull], info))
		return out

	static func corner_distance(at: Vector3, list: Array) -> Dictionary:
		var best := INF
		var which := -1
		var flat := Vector2(at.x, at.z)
		for i in list.size():
			var b: Dictionary = list[i]
			if not b["fitted"] or at.y < float(b["y0"]) - Y_SLACK_M or at.y > float(b["y1"]) + Y_SLACK_M:
				continue
			for c: Vector2 in b["corners"]:
				var d := flat.distance_to(c)
				if d < best:
					best = d
					which = i
		return {"dist": best, "box": which}

	static func nearest_surface(at: Vector3, list: Array, indices = null) -> Dictionary:
		var best := INF
		var which := -1
		var normal := Vector3.UP
		for n in (list.size() if indices == null else indices.size()):
			var i: int = n if indices == null else indices[n]
			var hit := surface_of(at, list[i])
			if float(hit["dist"]) < best:
				best = hit["dist"]
				which = i
				normal = hit["normal"]
		return {"dist": best, "box": which, "normal": normal}

	static func on_lane(mask: Dictionary, x: float, z: float) -> bool:
		if mask.is_empty():
			return false
		var side: int = mask["side"]
		var step: float = mask["step"]
		var half: float = mask["half"]
		var i := clampi(roundi((x + half) / step), 0, side - 1)
		var j := clampi(roundi((z + half) / step), 0, side - 1)
		return (mask["cells"] as PackedByteArray)[j * side + i] != 0

	static func cell_of(x: float, z: float) -> Vector2i:
		return Vector2i(floori(x / CELL_M), floori(z / CELL_M))

	static func build_grid(list: Array) -> Dictionary:
		var grid := {}
		for i in list.size():
			var b: Dictionary = list[i]
			if not b["fitted"]:
				continue
			var lo := Vector2(INF, INF)
			var hi := Vector2(-INF, -INF)
			for c: Vector2 in b["corners"]:
				lo = lo.min(c)
				hi = hi.max(c)
			var a := cell_of(lo.x, lo.y)
			var z := cell_of(hi.x, hi.y)
			for cx in range(a.x, z.x + 1):
				for cz in range(a.y, z.y + 1):
					var key := Vector2i(cx, cz)
					if not grid.has(key):
						grid[key] = []
					grid[key].append(i)
		return grid

	static func approach(at: Vector3, list: Array, grid: Dictionary) -> Dictionary:
		var out := {"surface": {"dist": INF, "row": ""}, "corner": {"dist": INF, "row": ""}}
		var home := cell_of(at.x, at.z)
		var flat := Vector2(at.x, at.z)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var indices = grid.get(Vector2i(home.x + dx, home.y + dz))
				if indices == null:
					continue
				for i: int in indices:
					var b: Dictionary = list[i]
					var d := float(surface_of(at, b)["dist"])
					if d < float(out["surface"]["dist"]):
						out["surface"] = {"dist": d, "row": b["row"]}
					var y := clampf(at.y, float(b["y0"]), float(b["y1"]))
					for c: Vector2 in b["corners"]:
						var dc := Vector3(flat.distance_to(c), at.y - y, 0.0).length()
						if dc < float(out["corner"]["dist"]):
							out["corner"] = {"dist": dc, "row": b["row"]}
		for k in out:
			if float(out[k]["dist"]) >= CELL_M:
				out[k] = {"dist": INF, "row": ""}
		return out

	func over_limit_rows() -> Array:
		var seen := {}
		var out: Array = []
		for b: Dictionary in boxes:
			if b["over_limit"] and not seen.has(b["row"]):
				seen[b["row"]] = true
				out.append({"row": b["row"], "key": b["key"], "size_y": b["size_y"]})
		out.sort_custom(func(a, c): return String(a["row"]) < String(c["row"]))
		return out

	func _collect(game) -> void:
		boxes = collect(game, park_rows)
		_grid = build_grid(boxes)
		_body_boxes = {}
		for i in boxes.size():
			var id: int = boxes[i]["body"]
			if not _body_boxes.has(id):
				_body_boxes[id] = []
				fields += 1
			_body_boxes[id].append(i)

	func observe(game, ball: Vector3, stopped: bool) -> void:
		_ticks += 1
		if boxes.is_empty():
			if _ticks % 90 == 1 and _tries < 8:
				_tries += 1
				_collect(game)
			if boxes.is_empty():
				return
		var near := approach(ball, boxes, _grid)
		if float(near["surface"]["dist"]) < float(closest_surface["dist"]):
			closest_surface = near["surface"]
		if float(near["corner"]["dist"]) < float(closest_corner["dist"]):
			closest_corner = near["corner"]
		var rigid = game.player._rigid
		var v: Vector3 = rigid.linear_velocity
		var touch := {}
		for body in rigid.get_colliding_bodies():
			if _body_boxes.has(body.get_instance_id()):
				touch[body.get_instance_id()] = true
		touch_ticks += 1 if not touch.is_empty() else 0
		if _prev_v != Vector3.INF:
			var ids: Array = touch.keys()
			for id in _prev_touch:
				if not touch.has(id):
					ids.append(id)
			ids.sort_custom(func(a, b): return _body_boxes[a][0] < _body_boxes[b][0])
			for id in ids:
				var hit := nearest_surface(ball, boxes, _body_boxes[id])
				if hit["dist"] > SURFACE_LIMIT_M:
					continue
				if _prev_v.dot(hit["normal"]) < -BOUNCE_MIN_MPS and v.dot(hit["normal"]) > 0.0:
					_record("bounce", game, ball, hit)
		_prev_v = v
		_prev_touch = touch
		if stopped:
			_record("stop", game, ball, nearest_surface(ball, boxes))

	func _record(kind: String, game, ball: Vector3, hit: Dictionary) -> void:
		events.append(describe(kind, park_id, seed_number, snappedf(game.run.stage_time, 0.01), ball, boxes, hit, lane))

	static func describe(kind: String, park_name: String, seed_value: int, time: float, ball: Vector3, list: Array, hit: Dictionary, mask: Dictionary) -> Dictionary:
		var corner := corner_distance(ball, list)
		var near: Dictionary = list[hit["box"]] if int(hit["box"]) >= 0 else {}
		var cb: Dictionary = list[corner["box"]] if int(corner["box"]) >= 0 else {}
		return {
			"park": park_name, "seed": seed_value, "kind": kind, "time": time,
			"at": [snappedf(ball.x, 0.01), snappedf(ball.y, 0.01), snappedf(ball.z, 0.01)],
			"row": near.get("row", ""), "key": near.get("key", ""), "size_y": near.get("size_y"), "fitted": near.get("fitted", false),
			"over_limit": near.get("over_limit", false), "surface_dist_m": snappedf(float(hit["dist"]), 0.01) if is_finite(float(hit["dist"])) else null,
			"corner_dist_m": snappedf(float(corner["dist"]), 0.01) if is_finite(float(corner["dist"])) else null,
			"corner_row": cb.get("row", ""), "corner_key": cb.get("key", ""), "corner_size_y": cb.get("size_y"),
			"corner_over_limit": cb.get("over_limit", false),
			"on_ride_line": on_lane(mask, ball.x, ball.z),
		}

	func report() -> Dictionary:
		var fitted := 0
		for b in boxes:
			fitted += 1 if b["fitted"] else 0
		return {"seed": seed_number, "fields": fields, "boxes": boxes.size(), "fitted_boxes": fitted, "touch_ticks": touch_ticks, "events": events.duplicate(true),
			"closest_surface_m": snappedf(float(closest_surface["dist"]), 0.01) if is_finite(float(closest_surface["dist"])) else null, "closest_surface_row": closest_surface["row"],
			"closest_corner_m": snappedf(float(closest_corner["dist"]), 0.01) if is_finite(float(closest_corner["dist"])) else null, "closest_corner_row": closest_corner["row"],
			"over_limit_rows": over_limit_rows()}

	static func summarise(rows: Array, over_rows: Array = []) -> Dictionary:
		var near_corner := 0
		var corner_on_line := 0
		var on_line := 0
		var limit := {}
		var by_row := {}
		var listed := {}
		for r: Dictionary in over_rows:
			listed["%s size %s %s" % [r["row"], r["size_y"], r["key"]]] = 0
		for e: Dictionary in rows:
			var corner = e.get("corner_dist_m")
			var is_near: bool = corner != null and float(corner) <= NEAR_M
			if is_near:
				near_corner += 1
				var label := "%s size %s" % [e["corner_row"], e["corner_size_y"]]
				by_row[label] = int(by_row.get(label, 0)) + 1
				if e["on_ride_line"]:
					corner_on_line += 1
			if e["on_ride_line"]:
				on_line += 1
			var surface = e.get("surface_dist_m")
			if e.get("over_limit", false) and surface != null and float(surface) <= NEAR_M:
				var label := "%s size %s %s%s" % [e["row"], e["size_y"], e["key"], " (on ride line)" if e["on_ride_line"] else ""]
				limit[label] = int(limit.get(label, 0)) + 1
				var listed_label := "%s size %s %s" % [e["row"], e["size_y"], e["key"]]
				if listed.has(listed_label):
					listed[listed_label] = int(listed[listed_label]) + 1
		return {"events": rows.size(), "near_corner": near_corner, "near_corner_on_ride_line": corner_on_line,
			"near_corner_by_row": by_row, "events_on_ride_line": on_line, "over_limit_events": limit, "over_limit_rows": listed}


static func park_ride_facts(verbs: Array) -> Array:
	return verbs.filter(func(v): return v in PARK_RIDE_FACTS)


static func document(pilot: String, table: String, commit: String, runs: Array, bar: Dictionary) -> Dictionary:
	var shares: Array = []
	var worst := {}
	var dead := 0
	var gap := 0.0
	var reached := 0
	var lengths: Array = []
	var uphills: Array = []
	var ride_counts: Array = []
	for run in runs:
		shares.append(float(run["flow_share"]))
		lengths.append(float(run.get("path_length_m", 0.0)))
		uphills.append(float(run.get("uphill_m", 0.0)))
		ride_counts.append(float((run.get("rides", []) as Array).size()))
		if worst.is_empty() or float(run["flow_share"]) < float(worst["flow_share"]):
			worst = {"seed": run["seed"], "flow_share": run["flow_share"]}
		dead += int(run["dead_stops"])
		gap = maxf(gap, float(run["max_anchor_gap_m"]))
		if run["reached_warden"]:
			reached += 1
	return {
		"pilot": pilot, "table": table, "commit": commit, "bar": bar, "runs": runs,
		"median_flow_share": snappedf(median(shares), 0.0001), "worst_seed": worst,
		"dead_stops_total": dead, "max_anchor_gap_m": gap, "reached_warden": reached,
		"median_path_length_m": snappedf(median(lengths), 0.1), "median_uphill_m": snappedf(median(uphills), 0.1),
		"median_rides": median(ride_counts),
	}


static func park_document(pilot: String, map_id: String, stage: int, commit: String, runs: Array, bar: Dictionary, floor_ref: Dictionary) -> Dictionary:
	for run in runs:
		if run.get("verbs") is Array:
			run["distinct_ride_facts"] = park_ride_facts(run["verbs"]).size()
	var doc := document(pilot, PARK, commit, runs, bar)
	doc["map"] = map_id
	doc["stage"] = stage
	var medians := {}
	for key in ["time_to_warden_s", "flow_share", "airborne_share", "peak_speed_mps", "tier3_s", "segment_s", "quiet_max_s",
			"distinct_verbs", "distinct_ride_facts", "max_anchor_gap_m", "length_ratio", "progress_m", "path_length_m", "dead_stops", "blazing_mps",
			"floor_share", "carve_share", "cinder_burns", "cinder_hp"]:
		var values := _values(runs, key)
		medians[key] = snappedf(median(values), 0.0001) if not values.is_empty() else null
	var segment_medians: Array = []
	var count := 0
	for run in runs:
		count = maxi(count, (run.get("segments_s", []) as Array).size())
	for i in count:
		var values: Array = []
		for run in runs:
			var segs: Array = run.get("segments_s", [])
			if i < segs.size() and segs[i] != null:
				values.append(float(segs[i]))
		segment_medians.append(snappedf(median(values), 0.01) if not values.is_empty() else null)
	medians["segments_s"] = segment_medians
	doc["medians"] = medians

	var bands: Array = []
	var reached := 0
	for run in runs:
		if run.get("reached_warden", false):
			reached += 1
	bands.append(_band("reached_warden", BAND_REACHED % [runs.size(), runs.size()], reached, null, not runs.is_empty() and reached == runs.size()))
	var times := _values(runs, "time_to_warden_s")
	var time_worst = _worst(times, true) if times.size() == runs.size() else null
	bands.append(_band("time_to_warden_s", "median %s to %s s; no seed over %s s" % [BAND_TIME[0], BAND_TIME[1], BAND_TIME_WORST],
		medians["time_to_warden_s"], time_worst,
		_and(_within(medians["time_to_warden_s"], BAND_TIME), null if times.is_empty() else (time_worst != null and float(time_worst) <= BAND_TIME_WORST))))
	var segments_inside = null
	if not segment_medians.is_empty():
		segments_inside = true
		for m in segment_medians:
			if m == null or float(m) < BAND_SEGMENT[0] or float(m) > BAND_SEGMENT[1]:
				segments_inside = false
	bands.append(_band("segment_s", "each segment's median %s to %s s" % [BAND_SEGMENT[0], BAND_SEGMENT[1]], segment_medians, medians["segment_s"], segments_inside))
	var flows := _values(runs, "flow_share")
	var flow_worst = _worst(flows, false)
	bands.append(_band("flow_share", "median at least %s; no seed under %s" % [BAND_FLOW, BAND_FLOW_WORST], medians["flow_share"], flow_worst,
		_and(_at_least(medians["flow_share"], BAND_FLOW), _at_least(flow_worst, BAND_FLOW_WORST))))
	var air := airborne_band(bar, stage)
	bands.append(_band("airborne_share", "%s to %s" % [air[0], air[1]], medians["airborne_share"], null, _within(medians["airborne_share"], air)))
	var dead := _values(runs, "dead_stops")
	var dead_worst = _worst(dead, true)
	var stalled := runs.filter(func(r): return float(r.get("path_length_m", 0.0)) < STALLED_PATH_M).size()
	var dead_inside = null
	if not dead.is_empty() and stalled == 0:
		dead_inside = float(dead_worst) == 0.0
	elif not dead.is_empty() and float(dead_worst) > 0.0:
		dead_inside = false
	bands.append(_band("dead_stops", "0 on every seed" if stalled == 0 else "0 on every seed; no data: %d seed(s) never rolled" % stalled,
		medians["dead_stops"], dead_worst, dead_inside))
	var peaks := _values(runs, "peak_speed_mps")
	var peak_worst = _worst(peaks, false)
	var blazings := _values(runs, "blazing_mps")
	var blazing = _worst(blazings, true) if not blazings.is_empty() else null
	var peak_label := "at least the blazing tier on every seed (no tuned cruise recorded)" if blazing == null \
		else "at least %s m/s (the blazing tier) on every seed" % blazing
	bands.append(_band("peak_speed_mps", peak_label, medians["peak_speed_mps"], peak_worst,
		null if blazing == null else _at_least(peak_worst, float(blazing))))
	bands.append(_band("tier3_s", "median at least %s s at the blazing tier" % BAND_TIER3, medians["tier3_s"], null, _at_least(medians["tier3_s"], BAND_TIER3)))
	bands.append(_band("quiet_max_s", "at most %s s" % BAND_QUIET, medians["quiet_max_s"], _worst(_values(runs, "quiet_max_s"), true), _at_most(medians["quiet_max_s"], BAND_QUIET)))
	bands.append(_band("max_anchor_gap_m", "at most %s m" % BAND_ANCHOR, medians["max_anchor_gap_m"], _worst(_values(runs, "max_anchor_gap_m"), true), _at_most(medians["max_anchor_gap_m"], BAND_ANCHOR)))
	bands.append(_band("distinct_verbs", "at least %d different ride facts" % BAND_VERBS, medians["distinct_ride_facts"],
		_worst(_values(runs, "distinct_ride_facts"), false), _at_least(medians["distinct_ride_facts"], BAND_VERBS)))
	bands.append(_band("length_ratio", "%s to %s" % [BAND_LENGTH[0], BAND_LENGTH[1]], medians["length_ratio"], null, _within(medians["length_ratio"], BAND_LENGTH)))
	if pilot == FLOOR:
		var ref = floor_ref.get("median_time_to_warden_s")
		var limit = BAND_FLOOR * float(ref) if ref != null else null
		var inside = null
		if limit != null and medians["time_to_warden_s"] != null:
			inside = reached == runs.size() and float(medians["time_to_warden_s"]) <= float(limit) and dead_worst != null and float(dead_worst) == 0.0
		bands.append(_band("floor", "reaches the Warden in at most %s times %s's median time, 0 dead stops" % [BAND_FLOOR, floor_ref.get("pilot", "the pilot line")],
			medians["time_to_warden_s"], limit, inside))
	doc["bands"] = bands
	return doc


static func airborne_band(bar: Dictionary, stage: int) -> Array:
	var given = bar.get("airborne_share")
	if given is Array and (given as Array).size() == 2:
		return [float(given[0]), float(given[1])]
	return BAND_AIRBORNE_HIGH if stage in BAND_AIRBORNE_HIGH_STAGES else BAND_AIRBORNE


static func _band(measure: String, band: String, value, worst, inside) -> Dictionary:
	return {"measure": measure, "band": band, "median": value, "worst": worst, "inside": inside}


static func _values(runs: Array, key: String) -> Array:
	var out: Array = []
	for run in runs:
		var v = run.get(key)
		if v != null and (v is float or v is int):
			out.append(float(v))
	return out


static func _worst(values: Array, high: bool):
	if values.is_empty():
		return null
	return values.max() if high else values.min()


static func _within(value, band: Array):
	return null if value == null else float(value) >= float(band[0]) and float(value) <= float(band[1])


static func _at_least(value, floor_value: float):
	return null if value == null else float(value) >= floor_value


static func _at_most(value, cap: float):
	return null if value == null else float(value) <= cap


static func _and(a, b):
	if a == null or b == null:
		return null if a != false and b != false else false
	return a and b


static func median(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var mid := sorted.size() / 2
	if sorted.size() % 2 == 1:
		return float(sorted[mid])
	return (float(sorted[mid - 1]) + float(sorted[mid])) / 2.0


static func write_document(path: String, doc: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(doc, "  "))
	file.close()
	return true


static func load_routes() -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	return parsed if parsed is Dictionary else {}


static func route_of(routes: Dictionary, pilot: String) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for pair in routes.get("pilots", {}).get(pilot, {}).get("waypoints", []):
		points.append(Vector2(float(pair[0]), float(pair[1])))
	return points


static func load_lines(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func place_of(park: Dictionary, id: String) -> Vector2:
	if id == ParkSchema.DROP_IN:
		return _pair(park.get("spawn", {}).get("at"))
	if id == ParkSchema.LANDMARK:
		return _pair(park.get("landmark", {}).get("beacon"))
	for table in ["park_rows", "activity_rows"]:
		for row in park.get(table, []):
			if row is Dictionary and row.get("id") == id:
				return _pair(row.get("at"))
	return Vector2.INF


static func _pair(value) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	return Vector2.INF


static func line_of(lines: Dictionary, key: String, park: Dictionary) -> Dictionary:
	var line: Dictionary = lines.get("floor", {}) if key == FLOOR else lines.get("pilots", {}).get(key, {})
	var route: Array[Vector2] = []
	var marks: Array = []
	for point in line.get("waypoints", []):
		var at := Vector2.INF
		if point is String:
			at = place_of(park, point)
			if at != Vector2.INF:
				marks.append({"id": point, "at": at})
			if point == ParkSchema.DROP_IN:
				continue
		else:
			at = _pair(point)
		if at != Vector2.INF:
			route.append(at)
	return {"route": route, "waymarks": marks, "bar": line.get("bar", {})}


static func floor_hands(hold: Dictionary, press: Dictionary) -> Dictionary:
	var kept := {}
	for key in hold:
		if key in FLOOR_HANDS:
			kept[key] = hold[key]
	return {"hold": kept, "press": {}}


static func use_fixture() -> bool:
	var script: GDScript = load(PARK_DEFS)
	if _park_defs_source == "":
		_park_defs_source = script.source_code
	var swapped := _park_defs_source.replace(FIXTURE_SWAP[0], FIXTURE_SWAP[1])
	if swapped == _park_defs_source:
		return false
	script.source_code = swapped
	if script.reload() != OK:
		return false
	var defs: Array = script.get_script_constant_map().get("DEFS", [])
	return not defs.is_empty() and defs[0].get("map") == FIXTURE_MAP


static func restore_park_defs() -> void:
	if _park_defs_source == "":
		return
	var script: GDScript = load(PARK_DEFS)
	script.source_code = _park_defs_source
	script.reload()


static func map_of(stage: int) -> String:
	if stage == FIXTURE_STAGE:
		return FIXTURE_MAP
	var script: GDScript = load(PARK_DEFS)
	var defs: Array = script.get_script_constant_map().get("DEFS", [])
	return String(defs[clampi(stage, 1, defs.size()) - 1].get("map", "")) if not defs.is_empty() else ""


static func open_graph(map_id: String):
	return open_graph_file(GRAPH_FILE % map_id, map_id)


static func open_graph_file(file: String, map_id: String):
	if _graphs.has(file):
		return _graphs[file]
	var graph = ParkGraph.read(file) if FileAccess.file_exists(file) else null
	if graph != null and (graph.d_land as PackedFloat32Array).size() != graph.node_count():
		graph = null
	if graph != null:
		_graphs[file] = graph
	if graph == null and graph_notes == 0:
		graph_notes += 1
		print("traversal_line: %s has no readable stage graph at %s; progress_m reads null" % [map_id, file])
	return graph


var _settings := {}
var _seeds: Array[int] = []
var _pilot := ""
var _routes := {}
var _index := -1
var _game
var _driver
var _sampler: Sampler
var _runs: Array = []
var _inconclusive: Array = []
var _counter_serial := 0
var _scrap_serial := 0
var _park := false
var _stage := 1
var _map_id := ""
var _lines := {}
var _line := {}
var _class_key := ""
var _floor := false


func _initialize() -> void:
	SimClock.ticks = true
	node_added.connect(_on_node_added)
	_settings = _parse(OS.get_cmdline_user_args())
	_pilot = String(_settings.get("pilot", ""))
	_park = String(_settings.get("table", TABLE)) == PARK
	if contacts_on(_settings) and not _park and not _settings.has("child"):
		print("traversal_line: warning: --anchor-contacts reads the park table's anchor fields; this table is not the park, so the flag is ignored")
	if _park:
		if not _setup_park():
			quit(2)
			return
	elif not _pilot in PILOTS:
		printerr("traversal_line: usage: -- --pilot=sable|rivet|kest [--seeds=1,2,3] [--out=<dir>] [--commit=<sha>] [--trace]"
			+ " | --table=park --stage=<0-6> --pilot=<sable|rivet|kest|tarn|tally|cannon> [--floor] [--lines=<file>] [--ref=<pilot>]")
		quit(2)
		return
	var seeds: Array = DEFAULT_SEEDS
	if _settings.has("seeds"):
		seeds = []
		for part in String(_settings["seeds"]).split(",", false):
			seeds.append(int(part))
	for value in seeds:
		_seeds.append(int(value))
	if _seeds.is_empty() or (_settings.has("ticks") and int(_settings["ticks"]) <= 0) or float(_settings.get("child-timeout", "120")) <= 0.0:
		printerr("traversal_line: seeds must be nonempty and ticks and child-timeout positive")
		quit(2)
		return
	for hand in hands_of(_settings):
		if not hand in BotDriver.HAND_NAMES:
			printerr("traversal_line: --hands=%s names no hand (%s)" % [hand, ",".join(BotDriver.HAND_NAMES)])
			quit(2)
			return
	if _settings.has("floor") and not hands_of(_settings).is_empty():
		printerr("traversal_line: --floor cannot take --hands (the floor line strips the hands' presses)")
		quit(2)
		return
	_routes = load_routes()
	if _settings.has("child"):
		if _seeds.size() != 1:
			printerr("traversal_line: a child must run exactly one seed")
			quit(2)
			return
		_start_seed()
	else:
		_run_children()


func _run_children() -> void:
	var out := ProjectSettings.globalize_path(_out_dir())
	if not out.is_absolute_path():
		out = OS.get_environment("PWD").path_join(out)
	var forwarded := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--seeds=") and not arg.begins_with("--out="):
			forwarded.append(arg)
	for i in _seeds.size():
		var child_out := out.path_join("children/%d-seed-%d" % [i + 1, _seeds[i]])
		DirAccess.make_dir_recursive_absolute(child_out)
		var path := child_out.path_join(summary_name(_pilot, hands_of(_settings)))
		var name := "%s-seed-%d-trace.json" % [trace_stem(_pilot, hands_of(_settings)), _seeds[i]]
		var child_trace := child_out.path_join(name)
		var trace_path := out.path_join(name)
		for stale in [path, child_trace, trace_path]:
			if FileAccess.file_exists(stale):
				DirAccess.remove_absolute(stale)
		var previous := {}
		for kind in ["DATA", "CONFIG", "CACHE"]:
			var key: String = "XDG_%s_HOME" % kind
			previous[key] = {"present": OS.has_environment(key), "value": OS.get_environment(key)}
			OS.set_environment(key, child_out.path_join("state/" + kind.to_lower()))
		var args := PackedStringArray(["--signal=KILL", "%ss" % _settings.get("child-timeout", "120"),
			OS.get_executable_path(), "--headless", "--fixed-fps", "90", "--path",
			ProjectSettings.globalize_path("res://"), "--script", "res://tools/traversal_line.gd", "--"])
		args.append_array(forwarded)
		args.append("--child")
		args.append("--seeds=%d" % _seeds[i])
		args.append("--out=" + child_out)
		var output := []
		var code := OS.execute("timeout", args, output, true)
		for key in previous:
			if previous[key]["present"]:
				OS.set_environment(key, previous[key]["value"])
			else:
				OS.unset_environment(key)
		var log := "".join(output)
		var file := FileAccess.open(child_out.path_join("child.log"), FileAccess.WRITE)
		if file != null:
			file.store_string(log)
		print(log.strip_edges())
		var doc = JSON.parse_string(FileAccess.get_file_as_string(path)) if code == 0 and FileAccess.file_exists(path) else null
		var rows: Array = doc.get("runs", []) if doc is Dictionary else []
		var rejected := code != 0 or rows.size() != 1 or int(rows[0].get("seed", -1)) != _seeds[i] or log.contains("SCRIPT ERROR")
		if not rejected and _settings.has("trace"):
			rejected = not FileAccess.file_exists(child_trace)
			if not rejected:
				rejected = DirAccess.copy_absolute(child_trace, trace_path) != OK
		if rejected:
			for unusable in [child_trace, trace_path]:
				if FileAccess.file_exists(unusable):
					DirAccess.remove_absolute(unusable)
			_inconclusive.append({"seed": _seeds[i], "status": "INCONCLUSIVE", "exit_code": code, "out": child_out})
			printerr("traversal_line: seed %d INCONCLUSIVE (child exit %d, %d rows); see %s" % [_seeds[i], code, rows.size(), child_out])
			continue
		for key in ["seed", "ticks", "dead_stops", "distinct_verbs", "distinct_ride_facts"]:
			rows[0][key] = int(rows[0][key])
		_runs.append(rows[0])
		_line["bar"] = doc.get("bar", {})
	_finish()


func _setup_park() -> bool:
	_floor = _settings.has("floor")
	_class_key = _pilot if _pilot != "" else (FLOOR_CLASS if _floor else "")
	if not PARK_PILOTS.has(_class_key):
		printerr("traversal_line: usage: -- --table=park --stage=<0-6> --pilot=sable|rivet|kest|tarn|tally|cannon [--floor] [--seeds=...] [--out=<dir>] [--lines=<file>] [--ref=<pilot>]")
		return false
	_pilot = FLOOR if _floor else _class_key
	_stage = int(_settings.get("stage", "1"))
	if _stage < FIXTURE_STAGE or _stage > 6:
		printerr("traversal_line: --stage=%d is not 0 (the park_test fixture) or a park table row 1 to 6" % _stage)
		return false
	if _stage == FIXTURE_STAGE and not use_fixture():
		printerr("traversal_line: could not ride park_test as the park table's stage 1 (park_defs.gd stage 1 map is no longer park_dam)")
		return false
	_map_id = map_of(_stage)
	var lines_path := String(_settings.get("lines", PARK_LINES % _map_id))
	_lines = load_lines(lines_path)
	if _lines.is_empty():
		printerr("traversal_line: no line file at %s" % lines_path)
		return false
	_line["bar"] = _lines.get("pilots", {}).get(_pilot, {}).get("bar", {})
	print("traversal_line: park %s (stage %d%s), %s line from %s" % [_map_id, _stage, ", the fixture as stage 1" if _stage == FIXTURE_STAGE else "",
		_pilot, lines_path])
	return true


func _game_stage() -> int:
	return 1 if _stage == FIXTURE_STAGE else _stage


static func contacts_on(settings: Dictionary) -> bool:
	return settings.has("anchor-contacts") and not String(settings["anchor-contacts"]) in ["0", "false", ""]


static func _parse(args: PackedStringArray) -> Dictionary:
	var out := {}
	for arg in args:
		if arg.begins_with("--") and "=" in arg:
			out[arg.substr(2, arg.find("=") - 2)] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("--"):
			out[arg.substr(2)] = "1"
	return out


static func summary_name(pilot: String, hands: Array) -> String:
	return "%s.json" % pilot if hands.is_empty() else "%s.hands.json" % pilot


static func trace_stem(pilot: String, hands: Array) -> String:
	return pilot if hands.is_empty() else "%s.hands" % pilot


static func hands_of(settings: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for part in String(settings.get("hands", "")).split(",", false):
		out.append(part)
	return out


func _start_seed() -> void:
	_index = 0
	seed(_seeds[_index])
	_game = Game.new()
	_game.name = "Game"
	_game.test_mode = true
	_game.table = PARK if _park else TABLE
	root.add_child(_game)
	_driver = null


func _physics_process(delta: float) -> bool:
	if _game == null or _game.flow == null:
		return false
	if _driver == null:
		_game.presentation.audio.bake_now()
		_driver = BotDriver.new(_game, "traversal", _seeds[_index])
		_driver.hands = hands_of(_settings)
		if _park:
			if not _start_park_driver():
				return false
		else:
			_driver.class_index = PILOTS.find(_pilot)
			_driver.route = route_of(_routes, _pilot)
			_driver.start()
			_sampler = Sampler.new(_game)
		_sampler.tracing = _settings.has("trace")
		_sampler.record_glide = "glide" in _driver.hands
		return false
	var over: bool = _driver.tick(delta)
	if not over and _settings.has("ticks") and _driver.ticks >= int(_settings["ticks"]):
		_driver._end("ticks_done")
		over = true
	if _floor:
		var hands := floor_hands(_driver.source.hold, _driver.source.press)
		_driver.source.hold = hands["hold"]
		_driver.source.press = hands["press"]
	_sampler.sample()
	if not over and not _sampler.engaged:
		return false
	var run := _sampler.result(_seeds[_index], "engaged" if _sampler.engaged else _driver.outcome)
	if _sampler.contacts != null:
		run["anchor_contacts"] = _sampler.contacts.report()
	_runs.append(run)
	if _sampler.tracing:
		var trace_path := _out_dir().path_join("%s-seed-%d-trace.json" % [trace_stem(_pilot, hands_of(_settings)), _seeds[_index]])
		write_document(trace_path, {"pilot": _pilot, "seed": _seeds[_index], "ticks": _sampler.trace})
	print("traversal_line: %s seed %d -> %s, flow share %.3f, dead stops %d, anchor gap %.1f m, to Warden %s s, path %.1f m, rides %s, uphill %.1f m"
		% [_pilot, run["seed"], run["outcome"], run["flow_share"], run["dead_stops"], run["max_anchor_gap_m"], run["time_to_warden_s"],
			run["path_length_m"], run["rides"], run["uphill_m"]])
	if _park:
		print("traversal_line: %s seed %d park: airborne %.3f, peak %.1f m/s (blazing %s), tier 3 %.1f s, segments %s s (longest %s), quiet max %.1f s, verbs %d %s (ride facts %d), length ratio %s, progress %s, floor %.3f, carve %.3f, cinder burns %d (%.1f hp), dead stops at %s"
			% [_pilot, run["seed"], run["airborne_share"], run["peak_speed_mps"], run["blazing_mps"], run["tier3_s"], run["segments_s"], run["segment_s"],
				run["quiet_max_s"], run["distinct_verbs"], run["verbs"], run["distinct_ride_facts"], run["length_ratio"], run["progress_m"], run["floor_share"], run["carve_share"], run["cinder_burns"], run["cinder_hp"], run["dead_stop_at"]])
	_game.free()
	_game = null
	_finish()
	return false


static func replay_side(node: Node, key: String, ordinal: int, seed_number: int) -> void:
	node.set_meta(key, 1.0 if (ordinal + seed_number) % 2 == 0 else -1.0)


func _on_node_added(node: Node) -> void:
	if _game == null or _game.build == null:
		return
	if "_strafe" in node:
		replay_side(node, "bot_strafe", _counter_serial, _seeds[_index])
		_counter_serial += 1
	if node.get_parent() == _game.build.scrap:
		replay_side(node, "bot_side", _scrap_serial, _seeds[_index])
		_scrap_serial += 1


func _start_park_driver() -> bool:
	var stage := _game_stage()
	var map = _game.ctx.terrain.map_for(stage)
	var park = map.get("park")
	if not park is Dictionary or (park as Dictionary).is_empty():
		printerr("traversal_line: stage %d has no park file loaded (map %s); its waymarks cannot resolve" % [_stage, map.get("title")])
		_game.free()
		_game = null
		quit(2)
		return false
	_line = line_of(_lines, _pilot, park)
	_driver.class_index = BotDriver.class_index_for(_seeds[_index], PARK_PILOTS[_class_key])
	_driver.route = _line["route"]
	_driver.start()
	if stage != 1:
		_game.flow.enter_stage(stage, Vector3.ZERO, false)
	_sampler = Sampler.new(_game)
	_sampler.setup_park(_line["waymarks"], open_graph(_map_id))
	if contacts_on(_settings):
		_sampler.contacts = AnchorContacts.new(_map_id, _seeds[_index], ParkMap.lane_mask_for(map.path, park), ParkRecipes.placed_rows(park))
	return true


func _out_dir() -> String:
	if _settings.has("out"):
		return String(_settings["out"])
	if _park:
		return ProjectSettings.globalize_path(PARK_OUT).path_join(_map_id)
	return ProjectSettings.globalize_path(DEFAULT_OUT)


func _finish() -> void:
	var out := _out_dir()
	var path := out.path_join(summary_name(_pilot, hands_of(_settings)))
	var doc := {}
	var contacts_doc := {}
	if contacts_on(_settings) and _park and not _settings.has("child"):
		contacts_doc = _take_contacts()
	if _park:
		doc = park_document(_pilot, _map_id, _stage, _commit(), _runs, _line.get("bar", {}), _floor_ref(out))
		doc["class"] = PARK_PILOTS[_class_key]
		doc["graph"] = "present" if open_graph(_map_id) != null else "missing: progress_m is null"
	else:
		var bar: Dictionary = _routes.get("pilots", {}).get(_pilot, {}).get("bar", {})
		doc = document(_pilot, TABLE, _commit(), _runs, bar)
	if not hands_of(_settings).is_empty():
		doc["hands"] = hands_of(_settings)
	if not _inconclusive.is_empty():
		doc["status"] = "INCONCLUSIVE"
		doc["inconclusive"] = _inconclusive
		for band in doc.get("bands", []):
			band["inside"] = null
	var written := write_document(path, doc)
	if not contacts_doc.is_empty():
		written = write_document(out.path_join("anchor_contacts.json" if hands_of(_settings).is_empty() else "anchor_contacts.hands.json"), contacts_doc) and written
	if _park:
		for band in doc["bands"]:
			var verdict := "no data" if band["inside"] == null else ("inside" if band["inside"] else "OUTSIDE")
			print("traversal_line: %s band %s (%s): median %s, worst %s -> %s" % [_pilot, band["measure"], band["band"], band["median"], band["worst"], verdict])
	var hands_note := "" if hands_of(_settings).is_empty() else " hands=" + ",".join(hands_of(_settings))
	print("traversal_line: %s%s median flow share %.3f, worst seed %s, written %s to %s"
		% [_pilot, hands_note, doc["median_flow_share"], doc["worst_seed"], written, path])
	if _park and _stage == FIXTURE_STAGE:
		restore_park_defs()
	quit((0 if _inconclusive.is_empty() else 3) if written else 1)


func _take_contacts() -> Dictionary:
	var per_seed: Array = []
	var events: Array = []
	var over_rows := {}
	for run in _runs:
		if run.has("anchor_contacts"):
			var one: Dictionary = run["anchor_contacts"]
			run.erase("anchor_contacts")
			per_seed.append({"seed": int(one["seed"]), "fields": int(one["fields"]), "boxes": int(one["boxes"]), "fitted_boxes": int(one["fitted_boxes"]), "touch_ticks": int(one["touch_ticks"]), "events": (one["events"] as Array).size(),
				"closest_surface_m": one["closest_surface_m"], "closest_surface_row": one["closest_surface_row"], "closest_corner_m": one["closest_corner_m"], "closest_corner_row": one["closest_corner_row"]})
			for r: Dictionary in one["over_limit_rows"]:
				over_rows[r["row"]] = r
			for e: Dictionary in one["events"]:
				e["seed"] = int(e["seed"])
				events.append(e)
	var summary := AnchorContacts.summarise(events, over_rows.values())
	var closest := closest_of(per_seed)
	summary["closest_approach"] = closest
	var note := "" if hands_of(_settings).is_empty() else " hands=" + ",".join(hands_of(_settings))
	print("traversal_line: anchor-contacts %s %s%s: %d events (%d stops, %d bounces), %d of them within %.1f m of a fitted corner, %d of those near-corner events on a ride line (the gated number), %d events of any distance on a ride line, over_limit rows (events within %.1f m of the face) %s, closest approach to a fitted surface %s, to a fitted corner %s, fitted boxes per seed %s, anchor touch ticks per seed %s"
		% [_map_id, _pilot, note, events.size(),
			events.filter(func(e): return e["kind"] == "stop").size(), events.filter(func(e): return e["kind"] == "bounce").size(),
			summary["near_corner"], AnchorContacts.NEAR_M, summary["near_corner_on_ride_line"], summary["events_on_ride_line"], AnchorContacts.NEAR_M, summary["over_limit_rows"],
			approach_text(closest["surface_m"], closest["surface_row"], closest["seed"]), approach_text(closest["corner_m"], closest["corner_row"], closest["corner_seed"]),
			per_seed.map(func(r): return r["fitted_boxes"]), per_seed.map(func(r): return r["touch_ticks"])])
	return {"park": _map_id, "stage": _stage, "pilot": _pilot, "hands": hands_of(_settings), "commit": _commit(),
		"definitions": {"near_m": AnchorContacts.NEAR_M, "ride_line": "ParkMap.lane_mask_for cell of the nearest 8 m lattice node (scatter.gd rule)",
			"corner": "fitted box vertical-edge corner (a hull band: a vertex of its XZ polygon), XZ, ball height within box span +/- %.1f m" % AnchorContacts.Y_SLACK_M,
			"bounce": "contact with an anchor body and normal velocity from below -%.1f m/s to above 0" % AnchorContacts.BOUNCE_MIN_MPS,
			"closest_approach": "ball centre to a fitted box surface, and to a fitted corner's vertical edge (3D), over every counted tick; null when never within %.1f m" % AnchorContacts.CELL_M,
			"over_limit_rows": "every placed row whose variant at its height has over_limit in anchor_fit.json, with the events whose nearest box is that row's and within %.1f m of its surface; 0 when none" % AnchorContacts.NEAR_M},
		"per_seed": per_seed, "summary": summary, "events": events}


static func closest_of(per_seed: Array) -> Dictionary:
	var out := {"surface_m": null, "surface_row": "", "seed": null, "corner_m": null, "corner_row": "", "corner_seed": null}
	for row: Dictionary in per_seed:
		if row["closest_surface_m"] != null and (out["surface_m"] == null or float(row["closest_surface_m"]) < float(out["surface_m"])):
			out["surface_m"] = row["closest_surface_m"]
			out["surface_row"] = row["closest_surface_row"]
			out["seed"] = row["seed"]
		if row["closest_corner_m"] != null and (out["corner_m"] == null or float(row["closest_corner_m"]) < float(out["corner_m"])):
			out["corner_m"] = row["closest_corner_m"]
			out["corner_row"] = row["closest_corner_row"]
			out["corner_seed"] = row["seed"]
	return out


static func approach_text(metres, row: String, seed_number) -> String:
	return "none within %.0f m" % AnchorContacts.CELL_M if metres == null else "%.2f m (%s, seed %d)" % [float(metres), row, int(seed_number)]


func _floor_ref(out: String) -> Dictionary:
	if not _floor:
		return {}
	var ref := String(_settings.get("ref", FLOOR_CLASS))
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(out.path_join("%s.json" % ref))) if FileAccess.file_exists(out.path_join("%s.json" % ref)) else null
	var time = parsed.get("medians", {}).get("time_to_warden_s") if parsed is Dictionary else null
	return {"pilot": ref, "median_time_to_warden_s": time}


func _commit() -> String:
	if _settings.has("commit"):
		return String(_settings["commit"])
	var output: Array = []
	var code := OS.execute("git", ["-C", ProjectSettings.globalize_path("res://"), "rev-parse", "HEAD"], output)
	return String(output[0]).strip_edges() if code == 0 and output.size() > 0 else "unknown"
