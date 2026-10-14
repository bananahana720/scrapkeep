extends Node3D

const ActivityView := preload("res://src/world/activity_view.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Interact := preload("res://src/world/interact.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const PocketFog := preload("res://src/world/events/pocket_fog.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const PocketLibrary := preload("res://src/world/pockets/pocket_library.gd")

# The standing activities (LEGIBILITY sections 7 and 9, wave R3): optional things on a map that
# stand lit from the stage's first frame, finish on an action the player already knows and pay
# one part at the spot. No timer, no prompt, no key. The map says where (StageMap.activity_sites),
# EventKinds.ACTIVITY_ROWS says how a site looks and sounds, RULES says how it starts, what
# finishes it and what it pays. A site whose id has no rule is not built (surge_run has no site
# on the Reach). A stage entry, so a retry and a new run too, builds every site unfinished; a
# finished site stays finished until the next stage entry.
#
# starts:   "ring" (the ball inside `ring` metres), "none" (nothing starts it) or
#           "near_or_hit" (the ball inside `wake` metres, or the brute is hit).
# finishes: "pack_dead" (every enemy the ring spawned is dead), "wall_broken" (the cache's wall
#           goes to a ram at cruise or a slam of at least that strength) or "brute_dead".
# pay:      `scrap` (180, so three activities lift the ball two heft classes), taken with one
#           part from `rarities` or an authored `named` part id, as a pickup at `where`: the altar, the pedestal or the
#           place the brute fell. A roll with no part pays the scrap when the activity finishes. part_gained carries `source`, which is not in
#           EventKinds.CEREMONY_SOURCES, so no ceremony pauses the game for it. The first activity finished
#           in a stage entry also adds the next companion piece (Companion.DROP_ORDER) to the run, unequipped.
const PAY_RARITIES := ["common", "rare"]
const PAY_SCRAP := 180
const RULES := {
	"trade_risk": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "trade_risk", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"trade_safe": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "trade_safe", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"curse": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "curse", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"sacrifice": {"starts": "none", "ring": 6.0, "finishes": "trade", "pay": {"scrap": 0, "rarities": [], "source": "sacrifice", "where": "device"}, "cue": {"view": "cracked_cache"}},
	"movement_course": {
		"starts": "ring", "ring": 8.0, "finishes": "course", "bundle": ["course", "chest"],
		"cue": {"view": "surge_run", "word": "Course", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["common"], "tier": 1, "parts": 1, "source": "pocket_course", "where": "stand"},
	},
	"arena": {
		"starts": "ring", "ring": 8.0, "finishes": "arena", "pack": ["chaser", "chaser", "lobber"], "bundle": ["spawners", "hazard", "heal", "chest"],
		"cue": {"view": "enemy_camp", "word": "Arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_arena", "where": "stand"},
	},
	"elite_arena": {
		"starts": "ring", "ring": 8.0, "finishes": "elite", "pack": ["chaser", "lobber", "miniboss"], "bundle": ["elite", "spawners", "hazard", "heal", "chest"],
		"cue": {"view": "hauler_bounty", "word": "Elite arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 3, "parts": 2, "source": "pocket_elite", "where": "stand"},
	},
	"objective_limit": {
		"starts": "ring", "ring": 8.0, "finishes": "timed_pickup", "limit_ticks": 600, "bundle": ["timed_pickup", "chest"],
		"cue": {"view": "cracked_cache", "word": "Pickup course", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 4, "parts": 3, "source": "pocket_objective", "where": "stand"},
	},
	"round_arena": {
		"starts": "ring", "ring": 8.0, "finishes": "rounds", "rounds": 3, "base": 12.0, "step": 6.0, "difficulty_cap": 3.0, "enemy_credit": 6.0,
		"elements": ["chaser", "lobber", "plated_brute"], "bundle": ["spawners", "hazard", "safe_zone", "heal", "round_chests"],
		"cue": {"view": "enemy_camp", "word": "Round arena", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_round", "where": "safe_zone"},
	},
	"ambush": {
		"starts": "ring", "ring": 8.0, "finishes": "waves", "waves": [["chaser"], ["chaser", "lobber", "chaser"], ["chaser", "lobber", "chaser", "lobber", "chaser"]],
		"bundle": ["spawners", "hazard", "heal", "chest"],
		"cue": {"view": "ambush_altar", "word": "Ambush", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_ambush", "where": "stand"},
	},
	"scattered_marks": {
		"starts": "none", "ring": 8.0, "finishes": "marks", "bundle": ["marks", "chest"],
		"cue": {"view": "cracked_cache", "word": "Scattered marks", "telegraph": "event_announced", "clear": "event_ended", "pay": "reward_chosen"},
		"pay": {"scrap": PAY_SCRAP, "rarities": ["rare"], "tier": 2, "parts": 1, "source": "pocket_marks", "where": "stand"},
	},
	"enemy_camp": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "chaser"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "named": "hot_rivets", "rarities": PAY_RARITIES, "source": "activity_camp", "where": "camp"},
	},
	"ambush_altar": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "lobber"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_ambush", "where": "altar"},
	},
	"cracked_cache": {
		"starts": "none", "ring": 5.0, "finishes": "wall_broken", "face": Vector2(0.0, -1.0),
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_cache", "where": "pedestal"},
	},
	"hauler_bounty": {
		"starts": "near_or_hit", "ring": 4.0, "wake": 30.0, "leash": 40.0, "return_speed": 9.0, "kind": "plated_brute",
		"finishes": "brute_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_bounty", "where": "fall"},
	},
}

const PICKUP_REACH := 1.7
const PICKUP_HEIGHT := 3.0
const RING_HEIGHT := 8.0
const BRUTE_DROP := 2.4
const SPAWN_CLEARANCE := 2.4
const PACK_TURN := PI / 6.0

# The cache's pocket: the cracked face, two side walls, a back wall and the pedestal, in the
# site's frame with +z out through the face.
const WALL_HALF_W := 6.0
const WALL_DEPTH := 8.0
const WALL_HEIGHT := 6.0
const WALL_SINK := 3.0
const WALL_REACH := 3.0
const SLAM_REACH := 7.0
# `slammed` carries the ball's own strength for the landing (player.slam_strength), not a speed.
# A slam breaks the wall at SLAM_MIN_PER_CRUISE times the strength of a flat landing at cruise speed,
# so a landing as fast as the ram that breaks it breaks it too and a slower one does not.
const SLAM_MIN_PER_CRUISE := 1.0
const PEDESTAL_BACK := 4.0
const CACHE_LANE_OFFSET := 6.0
# The back wall's own glow once the wall is fired. No light: a per-site OmniLight3D freed on
# a stage change made Godot 4.7.2 Forward+ segfault on the next boss entry (GPU only), as the
# wave 9 cage light did.
const CACHE_FIRED_GLOW := {"energy": 0.8}

var ctx
var sites: Array = []
var _piece_paid := false
var _pending_stage := false
var _elite_arrivals := 0
var _graph
var _graph_map := ""
var _draw_layout := {}
var _draw_map := ""
var _mark_pools := {}

const POCKET_HEAL_SHARE := 0.15
const POCKET_FOG_SIZE := Vector3(32, 8, 32)
const POCKET_SAFE_M := 4.0
const POCKET_DAMAGE_PER_S := 8.0
const MARK_SPACING_M := 80.0
const MARK_POOL_SIZE := 16


# One standing activity: its rule, its look, its state and, once it has finished, its pay.
class Site extends Node3D:
	var id := ""
	var rule := {}
	var view
	var done := false
	var started := false
	var pack: Array = []
	var brute
	var wall: Node3D
	var pedestal := Vector3.ZERO
	var pickup: Node3D
	var pickup_part := ""
	var pickup_parts: Array = []
	var reward_parts: Array = []
	var cap: Node3D
	var pickup_taken := false
	var inside_pickup := true
	var fired_glow: StandardMaterial3D
	var hazards: Array = []
	var fog
	var graph
	var targets: Array = []
	var target_views: Array = []
	var taken := {}
	var marks_taken := 0
	var next_target := 0
	var ticks := 0
	var failed := false
	var heal_paid := false
	var tier_label: Label3D
	var difficulty := 1.0
	var round := 0
	var round_elements: Array = []
	var round_credits := 0.0
	var round_payments := 0
	var round_rewards: Array = []
	var awaiting_round := false
	var wave := 0
	var spawn_positions: Array = []
	var phase_view: Node3D
	var interior := {}
	var interior_collision_ready := false
	var trade := {}
	var trade_devices: Array = []
	var footprint := POCKET_FOG_SIZE

	func _exit_tree() -> void:
		for enemy in pack:
			if is_instance_valid(enemy):
				enemy.queue_free()


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Activities"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())
	ctx.events.slammed.connect(func(at: Vector3, strength: float, _flatness: float): _slammed(at, strength))


func _on_stage_entered(_stage: int, retry: bool) -> void:
	clear()
	_elite_arrivals = 0
	# A retry does not re-arm the piece, so dying cannot farm one.
	if not retry:
		_piece_paid = false
	var map = ctx.terrain.map()
	_graph = null
	_graph_map = ""
	_mark_pools.clear()
	if "park" in map and not map.park.is_empty():
		_graph_map = String(map.park.map)
		_graph = ParkGraph.read("res://assets/park/%s/graph.bin" % _graph_map)
	if not "activity_sites" in map:
		return
	for spec in map.activity_sites:
		var id := String(spec["id"])
		if not RULES.has(id):
			continue
		# Calm mode spawns nothing, so the ambush and the bounty could never be paid there.
		if ctx.calm and String(RULES[id]["finishes"]) != "wall_broken":
			continue
		var map_id := _graph_map if _graph_map != "" else String(ctx.stages.of(ctx.terrain.stage).get("map", ""))
		var entry := PocketLibrary.for_site(map_id, String(spec.get("row", id)))
		var built_spec: Dictionary = spec
		if not entry.is_empty() and entry.activity == id:
			built_spec = spec.merged(PocketLibrary.site_spec(entry), true)
			if not spec.get("pack", []).is_empty():
				built_spec.pack = spec.pack.duplicate()
				built_spec.tell = spec.get("tell", {}).duplicate(true)
		sites.append(_build(id, spec["at"], built_spec))
	if _graph != null:
		var pool := TradePockets.candidates(_graph, map)
		var trade_spec := TradePockets.stage_site(_graph, map, ctx.run, ctx.rng.seed, pool)
		if not trade_spec.is_empty():
			sites.append(_build(trade_spec.id, trade_spec.at, trade_spec))
		if _draw_map != _graph_map:
			_draw_layout.clear()
			_draw_map = _graph_map
		if _draw_layout.is_empty() and ctx.run.stage > 1:
			_draw_layout = PocketDraw.prepare(_graph, map)
		for drawn_spec in PocketDraw.stage_sites(_graph, map, ctx.run, ctx.rng.seed, trade_spec, _draw_layout):
			if not ctx.calm or RULES[drawn_spec.id].finishes == "wall_broken":
				sites.append(_build(drawn_spec.id, drawn_spec.at, drawn_spec))
	_pending_stage = true


func clear() -> void:
	for site in sites:
		if is_instance_valid(site):
			for device in site.trade_devices:
				ctx.root.get_node("Interact").unregister(device)
			for hazard in site.hazards:
				hazard.stop()
			for enemy in site.pack:
				if is_instance_valid(enemy):
					enemy.queue_free()
			site.queue_free()
	sites.clear()
	_pending_stage = false


func site(id: String) -> Site:
	for s in sites:
		if s.id == id:
			return s
	return null


# Enemies the activities keep standing that the director's cap does not count.
func standing() -> int:
	var n := 0
	for s in sites:
		if s.brute != null and is_instance_valid(s.brute) and not s.brute.is_dead():
			n += 1
	return n


func _build(id: String, at: Vector2, spec := {}) -> Site:
	var s := Site.new()
	s.id = id
	s.rule = RULES[id]
	s.interior = spec.get("interior", {})
	s.trade = spec.get("trade", {})
	var spec_pay: Dictionary = spec.get("pay", {})
	if id == "enemy_camp" or not spec_pay.is_empty() or s.rule.has("bundle") or not s.interior.is_empty():
		s.rule = s.rule.duplicate(true)
	if not s.interior.is_empty():
		s.footprint = spec.footprint
		s.difficulty = clampf(float(spec.get("difficulty", 1.0)), 1.0, float(s.rule.get("difficulty_cap", 3.0)))
		s.rule["ring"] = spec.ring
		if not spec.pack.is_empty():
			s.rule["pack"] = spec.pack.duplicate()
			if id == "ambush":
				s.rule["waves"] = [spec.pack.slice(0, 1), spec.pack.slice(0, ceili(spec.pack.size() * 0.5)), spec.pack.duplicate()]
		if s.rule.has("cue") and not spec.get("tell", {}).is_empty():
			s.rule.cue.word = spec.tell.word
	if id == "enemy_camp":
		s.rule["pack"] = spec.get("pack", s.rule["pack"])
	# PARK.md 2.12: the park row authors the pay ladder (rarities, or a named part that wins when the
	# table offers it). Scrap, source and where stay the rule's own, so the heft pace never moves.
	for key in ["rarities", "named"]:
		if spec_pay.has(key):
			s.rule["pay"][key] = spec_pay[key]
	s.name = "Activity_" + id
	add_child(s)
	s.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
	s.view = ActivityView.new()
	s.add_child(s.view)
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	var tell_audio = presentation.audio if presentation != null and not s.interior.is_empty() else null
	s.view.build(String(s.rule.cue.view) if s.rule.has("cue") else id, float(s.rule["ring"]), spec.get("tell", {}), tell_audio)
	if s.rule.has("bundle"):
		_build_pocket(s, spec)
	elif id == "enemy_camp" and (spec.has("site") or not s.interior.is_empty()):
		_build_hazard(s)
	match id:
		"ambush_altar":
			_build_altar(s)
		"cracked_cache":
			_build_cache(s)
	if not s.interior.is_empty():
		_build_interior(s)
	if s.rule.finishes == "trade":
		_build_trade(s)
	return s


func _build_trade(s: Site) -> void:
	var words := []
	for i in TradePockets.devices(s.trade).size():
		var spec: Dictionary = TradePockets.devices(s.trade)[i].duplicate()
		spec["id"] = "trade_%d_%s_%d" % [ctx.run.stage, s.trade.interior_id, i]
		var device := StakeDevices.new()
		s.add_child(device)
		device.position = Vector3(-4.0 if i == 0 else 4.0, 0.0, 0.0)
		device.setup(ctx, ctx.root.get_node("Interact"), spec)
		ctx.root.get_node("Interact").register(device)
		s.trade_devices.append(device)
		words.append(device.words())
	var door: Array = s.interior.entrances[0].at
	var label := Label3D.new()
	label.name = "TradePrices"
	label.position = Vector3(door[0], 3.4, door[1] + 1.0)
	label.text = "%s (%s)\n%s\nHold E at a device" % [s.interior.tell.word, s.trade.family, "\n".join(words)]
	label.font_size = 36
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	s.add_child(label)
	s.view.word.text = "%s: %s" % [s.interior.tell.word, " / ".join(words)]


func _watch_trade(s: Site, ball: Vector3) -> void:
	if not s.started and _planar(ball, s.global_position) <= s.footprint.z * 0.5 + 16.0:
		s.started = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
	if not s.done and s.trade_devices.any(func(device): return device.spent):
		s.done = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
		TradePockets.decide(ctx.run.trade_memory, s.trade, true)


func _build_interior(s: Site) -> void:
	var root := Node3D.new()
	root.name = "Interior_" + String(s.interior.id)
	s.add_child(root)
	for block in s.interior.terrain:
		var size := Vector3(block.size[0], block.size[1], block.size[2])
		var at := Vector3(block.at[0], size.y * 0.5, block.at[1])
		_mesh_box(root, size, at, Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL))
	for entrance in s.interior.entrances:
		for side in [-1.0, 1.0]:
			_mesh_box(root, Vector3(0.3, 2.0, 0.3), Vector3(entrance.at[0] + side * entrance.width * 0.5, 1.0, entrance.at[1]), Palette.solid(EventKinds.activity_color(s.view.id)))
	# The interior builds after the site's own dressing pass, so it dresses its own blocks (2026-10-14).
	load("res://src/presentation/spillway_scenery.gd").dress_props(root)


func _activate_interior_collision(s: Site) -> void:
	var root := s.get_node("Interior_" + String(s.interior.id))
	for i in s.interior.terrain.size():
		var block: Dictionary = s.interior.terrain[i]
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(block.size[0], block.size[1], block.size[2])
		shape.shape = box
		body.add_child(shape)
		root.get_child(i).add_child(body)
	s.interior_collision_ready = true


func _build_altar(s: Site) -> void:
	_mesh_cylinder(s, 0.45, 3.2, Vector3.UP * 1.6, Palette.solid(Palette.VERDIGRIS))
	s.cap = _mesh_box(s, Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, Palette.solid(Palette.BRASS))
	_mesh_box(s, Vector3(1.42, 0.12, 1.42), Vector3.UP * 3.22, Palette.solid(Palette.SAND))


func _build_cache(s: Site) -> void:
	var face: Vector2 = s.rule["face"]
	s.rotation.y = atan2(face.x, face.y)
	s.global_position += s.global_basis.z * CACHE_LANE_OFFSET
	s.global_position.y = ctx.terrain.height(s.global_position.x, s.global_position.z)
	var concrete := Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	s.wall = _mesh_box(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0),
		Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := _mesh_box(s.wall, Vector3(WALL_HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0),
			Palette.solid(Palette.CHARCOAL))
		crack.rotation.z = 0.5 - k * 0.45
	for side in [-1.0, 1.0]:
		_mesh_box(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5), concrete, true)
	var back := _mesh_box(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5), concrete, true)
	var local := Vector3(0.0, 0.0, -PEDESTAL_BACK)
	s.pedestal = s.to_global(local)
	s.pedestal.y = ctx.terrain.height(s.pedestal.x, s.pedestal.z)
	_mesh_cylinder(s, 0.8, 0.6, s.to_local(s.pedestal) + Vector3.UP * 0.3, Palette.solid(Palette.CHARCOAL))
	# Finish only: the same workshop materials the Spillway props wear; colliders stay as built.
	load("res://src/presentation/spillway_scenery.gd").dress_props(s, s.view)
	# The dressed finish shader carries no emission, so the glow is this site's own additive
	# overlay on its back wall, dark until the wall is fired.
	s.fired_glow = StandardMaterial3D.new()
	s.fired_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.fired_glow.albedo_color = Color.BLACK
	s.fired_glow.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	(back.get_child(1) as GeometryInstance3D).material_overlay = s.fired_glow


func _mesh_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid := false) -> Node3D:
	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mesh.mesh = bm
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.add_child(mesh)
	body.position = at
	parent.add_child(body)
	return body


func _mesh_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mesh.mesh = cm
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)


func _physics_process(delta: float) -> void:
	if ctx == null or not ctx.flow.in_stage():
		return
	if _pending_stage and ctx.spawner != null and not ctx.calm:
		_pending_stage = false
		for s in sites:
			if s.id == "hauler_bounty":
				_spawn_bounty(s)
	var ball: Vector3 = ctx.player.ball_position()
	for s in sites:
		if not is_instance_valid(s):
			continue
		if not s.interior.is_empty() and not s.interior_collision_ready:
			var local: Vector3 = s.to_local(ball)
			if absf(local.x) <= s.footprint.x * 0.5 and absf(local.z) <= s.footprint.z * 0.5 \
					and local.y >= 0.0 and local.y <= s.footprint.y:
				_activate_interior_collision(s)
		s.view.near(ball)
		if s.rule.finishes == "trade":
			_watch_trade(s, ball)
			continue
		if s.rule.has("bundle"):
			step_pocket(s, delta, ball)
			_watch_pickup(s, ball)
			continue
		if not s.done:
			match String(s.rule["finishes"]):
				"pack_dead":
					_watch_ambush(s, ball)
				"wall_broken":
					_watch_wall(s, ball)
			_advance_hazards(s, delta, ball)
		_watch_pickup(s, ball)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _build_pocket(s: Site, spec: Dictionary) -> void:
	s.graph = spec.get("graph", _graph)
	s.difficulty = clampf(float(spec.get("difficulty", 1.0)), 1.0, float(s.rule.get("difficulty_cap", 3.0)))
	s.tier_label = s.view.word
	_show_reward(s)
	if "hazard" in s.rule.bundle:
		_build_hazard(s)
	match s.id:
		"movement_course":
			for offset in [12.0, 24.0, 36.0]:
				s.targets.append(ctx.terrain.drop_point(s.global_position.x + offset, s.global_position.z, 0.0))
		"objective_limit":
			s.targets.append(ctx.terrain.drop_point(s.global_position.x + 24.0, s.global_position.z, 0.0))
		"scattered_marks":
			if s.graph != null:
				var graph_id: int = s.graph.get_instance_id()
				if not _mark_pools.has(graph_id):
					_mark_pools[graph_id] = mark_candidates(s.graph)
				var pool: Array = _mark_pools[graph_id]
				for n in draw_marks(s.graph, ctx.rng.seed, pool):
					s.targets.append(s.graph.position(n))
			if s.targets.size() < 3:
				s.failed = true
	for target in s.targets:
		var marker := ActivityView.gem(String(s.rule.cue.view))
		s.add_child(marker)
		marker.global_position = target
		s.target_views.append(marker)


func _show_reward(s: Site) -> void:
	var suffix := "round_%d" % maxi(1, s.round) if s.id == "round_arena" else "clear"
	s.reward_parts = _reward_parts(s, suffix)
	var shown := stand_odds(s)
	s.tier_label.text = "%s — Tier %d (%s)" % [s.rule.cue.word, shown.tier, shown.reward_text]
	s.tier_label.modulate = ItemGen.RARITY[shown.reward_rarity].color


func step_pocket(s: Site, delta: float, ball: Vector3) -> void:
	_watch_round_pickups(s, ball)
	if s.done or s.failed:
		return
	if s.id == "scattered_marks":
		for i in s.targets.size():
			if not s.taken.has(i) and _touches(ball, s.targets[i]):
				s.taken[i] = true
				s.marks_taken += 1
				s.target_views[i].visible = false
				_cue(s, "telegraph")
		if s.marks_taken == s.targets.size() and s.marks_taken >= 3:
			_finish(s, s.global_position)
		return
	if not s.started:
		if _planar(ball, s.global_position) > float(s.rule.ring) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		if s.id in ["arena", "elite_arena", "round_arena", "ambush"] and (ctx.calm or ctx.spawner == null):
			return
		if s.id == "elite_arena" and _elite_arrivals >= 3:
			return
		s.started = true
		_cue(s, "telegraph")
		match s.id:
			"arena", "elite_arena":
				_spawn_pocket_pack(s, s.rule.pack)
				if s.pack.is_empty():
					s.started = false
					return
				_begin_hazards(s, 1)
				if s.id == "elite_arena":
					_elite_arrivals += 1
					s.brute = s.pack.back()
					s.brute.died.connect(func(_at, _scrap): _elite_clear(s))
			"round_arena":
				_begin_round(s)
			"ambush":
				_begin_hazards(s, 1)
				_next_wave(s)
	_advance_hazards(s, delta, ball)
	match String(s.rule.finishes):
		"course":
			if s.next_target < s.targets.size() and _touches(ball, s.targets[s.next_target]):
				s.target_views[s.next_target].visible = false
				s.next_target += 1
			if s.next_target == s.targets.size():
				_finish(s, s.global_position)
		"timed_pickup":
			s.ticks += 1
			if s.ticks > int(s.rule.limit_ticks):
				s.failed = true
				s.view.finish()
				for marker in s.target_views:
					marker.visible = false
			elif _touches(ball, s.targets[0]):
				s.target_views[0].visible = false
				_finish(s, s.global_position)
		"arena":
			if _alive(s.pack) == 0:
				_finish(s, s.global_position)
		"elite":
			if is_instance_valid(s.brute) and s.brute.is_dead():
				_elite_clear(s)
		"waves":
			if _alive(s.pack) == 0:
				if s.wave == s.rule.waves.size():
					_finish(s, s.global_position)
				else:
					_next_wave(s)
		"rounds":
			if s.awaiting_round:
				if s.fog.active:
					s.awaiting_round = false
					var kinds := []
					for i in maxi(s.round_elements.size(), floori(s.round_credits / float(s.rule.enemy_credit))):
						kinds.append(s.round_elements[i % s.round_elements.size()])
					if not s.interior.is_empty():
						kinds.clear()
						for i in maxi(s.rule.pack.size(), floori(s.round_credits / float(s.rule.enemy_credit))):
							kinds.append(s.rule.pack[i % s.rule.pack.size()])
					_spawn_pocket_pack(s, kinds)
			elif _alive(s.pack) == 0:
				_pay_round(s)
				if s.round == int(s.rule.rounds):
					_finish(s, s.global_position)
				else:
					_begin_round(s)


func _touches(ball: Vector3, at: Vector3) -> bool:
	return _planar(ball, at) <= PICKUP_REACH and absf(ball.y - at.y) <= PICKUP_HEIGHT


func _build_hazard(s: Site) -> void:
	if not s.interior.is_empty():
		for box in s.interior.hazards:
			var hazard := PocketFog.new()
			s.add_child(hazard)
			var centre := s.global_position + Vector3(box.at[0], 0, box.at[1])
			hazard.setup(centre, Vector3(box.size[0], box.size[1], box.size[2]), POCKET_SAFE_M, POCKET_DAMAGE_PER_S, ctx.rng.seed)
			s.hazards.append(hazard)
		if not s.hazards.is_empty():
			s.fog = s.hazards[0]
		return
	s.fog = PocketFog.new()
	s.add_child(s.fog)
	s.fog.setup(s.global_position, s.footprint, POCKET_SAFE_M, POCKET_DAMAGE_PER_S, ctx.rng.seed)
	s.hazards.append(s.fog)


func _begin_hazards(s: Site, round_number: int) -> void:
	for hazard in s.hazards:
		hazard.begin(round_number)


func _advance_hazards(s: Site, delta: float, ball: Vector3) -> void:
	for hazard in s.hazards:
		for fact in hazard.advance(delta, ball):
			if fact.kind == "world":
				ctx.events.world_fact.emit(fact.fact, fact.at)
		var damage: float = hazard.damage_at(ball) * delta
		if damage > 0.0:
			ctx.run.damage(damage, "pocket_veil")


func _cue(s: Site, phase: String) -> void:
	var kind := String(s.rule.cue[phase])
	var row := EventKinds.row(kind)
	var presentation: Node = ctx.root.get_node_or_null("Presentation")
	if presentation != null:
		presentation.audio.play(kind)
	if is_instance_valid(s.phase_view):
		s.phase_view.queue_free()
	s.phase_view = ActivityView._glyph(String(row.shape), row.color)
	s.add_child(s.phase_view)
	s.phase_view.position = Vector3.UP * 2.0
	if s.view.word != null:
		s.view.word.modulate = row.color


func _pocket_roll(s: Site, suffix: String, count := 1) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, s.id + suffix)
	return Parts.roll(rng, pay_table(s).rarities, ctx.run.class_id(), ctx.run.parts, count)


func _reward_parts(s: Site, suffix: String) -> Array:
	var table := pay_table(s)
	if table.named != "":
		return [table.named]
	return _pocket_roll(s, suffix, int(s.rule.pay.parts))


func _heal(s: Site) -> void:
	if s.heal_paid or not "heal" in s.rule.get("bundle", []):
		return
	ctx.run.heal(ctx.run.max_hp * POCKET_HEAL_SHARE)
	s.heal_paid = true


func _elite_clear(s: Site) -> void:
	if not is_instance_valid(s) or s.done:
		return
	for enemy in s.pack:
		if is_instance_valid(enemy) and enemy != s.brute:
			enemy.queue_free()
	s.pack.clear()
	_finish(s, s.global_position)


func _spawn_pocket_pack(s: Site, kinds: Array) -> void:
	s.pack.clear()
	var positions := pocket_positions(s, kinds.size())
	if positions.size() != kinds.size():
		s.failed = true
		for hazard in s.hazards:
			hazard.stop()
		return
	for i in kinds.size():
		var spot: Vector3 = positions[i]
		var enemy = ctx.spawner.spawn_enemy(String(kinds[i]), ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
			s.spawn_positions.append(enemy.global_position)


func pocket_positions(s: Site, count: int) -> Array:
	if not s.interior.is_empty():
		return _library_positions(s, count)
	var result := []
	for i in count:
		var angle := PACK_TURN + TAU * float(i) / count
		var point := s.global_position + Vector3(cos(angle), 0, sin(angle)) * float(s.rule.ring)
		if s.id == "ambush" and s.interior.is_empty():
			if s.graph == null:
				return []
			var candidates: PackedInt32Array = s.graph.disc_nodes(Vector2(point.x, point.z), float(s.rule.ring))
			var eligible := PackedInt32Array()
			for n in candidates:
				if s.graph.flags(n) & ParkGraph.DOOR_OK != 0 and s.graph.flags(n) & ParkGraph.LINE == 0:
					eligible.append(n)
			var node: int = s.graph.nearest_in(eligible, point)
			if node < 0:
				return []
			point = s.graph.position(node)
		result.append(point)
	return result


func _library_positions(s: Site, count: int) -> Array:
	var entry := Vector2(s.interior.entry_spot[0], s.interior.entry_spot[1])
	var rear := entry.angle() + PI
	var radius := maxf(float(s.rule.ring), minf(s.footprint.x, s.footprint.z) * 0.35)
	var result := []
	for i in count:
		var angle := rear - PI * 0.25 + PI * 0.5 * (float(i) + 0.5) / count
		result.append(s.to_global(Vector3(cos(angle), 0, sin(angle)) * radius))
	return result


func _next_wave(s: Site) -> void:
	var kinds: Array = s.rule.waves[s.wave]
	s.wave += 1
	_spawn_pocket_pack(s, kinds)


func _begin_round(s: Site) -> void:
	s.round += 1
	s.round_elements.append(s.rule.elements[s.round - 1])
	s.round_credits = (float(s.rule.base) + float(s.rule.step) * (s.round - 1)) * s.difficulty
	s.awaiting_round = true
	_begin_hazards(s, s.round)
	_show_reward(s)


func _pay_round(s: Site) -> void:
	for hazard in s.hazards:
		hazard.stop()
	s.heal_paid = false
	_heal(s)
	var picks: Array = s.reward_parts.duplicate()
	var pickup := ActivityView.gem(String(s.rule.cue.view))
	s.add_child(pickup)
	pickup.global_position = s.fog.committed.safe_at
	s.round_rewards.append({"pickup": pickup, "parts": picks, "inside": _touches(ctx.player.ball_position(), pickup.global_position)})
	s.round_payments += 1
	_cue(s, "clear")


func _watch_round_pickups(s: Site, ball: Vector3) -> void:
	for reward in s.round_rewards.duplicate():
		var now := _touches(ball, reward.pickup.global_position)
		if now and not reward.inside:
			for part in reward.parts:
				ctx.run.add_part(part, String(s.rule.pay.source))
			_pay_scrap(s, reward.pickup.global_position)
			reward.pickup.queue_free()
			s.round_rewards.erase(reward)
			_cue(s, "pay")
		else:
			reward.inside = now


static func mark_far_m(graph) -> float:
	var farthest := 0.0
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.DOOR_OK != 0 and is_finite(graph.d_spawn_node(n)):
			farthest = maxf(farthest, graph.d_spawn_node(n))
	return farthest * 0.5


static func mark_candidates(graph) -> Array:
	var far := mark_far_m(graph)
	var nodes := []
	for n in graph.node_count():
		if graph.flags(n) & ParkGraph.DOOR_OK != 0 and is_finite(graph.d_spawn_node(n)) and is_finite(graph.d_landmark_node(n)) and graph.d_spawn_node(n) >= far:
			nodes.append(n)
	nodes.sort_custom(func(a, b): return graph.d_spawn_node(a) < graph.d_spawn_node(b))
	var pool := []
	if nodes.is_empty():
		return pool
	var anchor := PackedInt32Array([nodes[0]])
	var from_anchor: PackedByteArray = graph.reach(anchor)
	var to_anchor: PackedFloat32Array = graph.search(anchor, true)
	# All marks must be mutually reachable, including directed ride/drop edges.
	# The entry drop need not be reachable again after the ball leaves it.
	nodes = nodes.filter(func(n): return from_anchor[n] != 0 and is_finite(to_anchor[n]))
	for i in mini(MARK_POOL_SIZE, nodes.size()):
		pool.append(nodes[roundi(float(i) * (nodes.size() - 1) / (MARK_POOL_SIZE - 1))])
	return pool


static func draw_marks(graph, seed_value: int, pool: Array = []) -> Array:
	if pool.is_empty():
		pool = mark_candidates(graph)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var count := rng.randi_range(3, 4)
	var candidates := pool.duplicate()
	for i in range(candidates.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = swap
	var marks := []
	for n in candidates:
		# Difference in shortest spawn distances is a lower bound on path separation;
		# unlike Euclidean spacing, it preserves the park's authored path measure.
		if marks.all(func(other): return absf(graph.d_spawn_node(n) - graph.d_spawn_node(other)) >= MARK_SPACING_M):
			marks.append(n)
			if marks.size() == count:
				return marks
	return marks


# ---- The ambush ----

func _watch_ambush(s: Site, ball: Vector3) -> void:
	if not s.started:
		if ctx.calm or ctx.spawner == null or not ctx.spawner.has_method("spawn_enemy"):
			return
		if _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		_spawn_pack(s)
		return
	if _alive(s.pack) == 0:
		_finish(s, s.global_position)


func _spawn_pack(s: Site) -> void:
	if not s.interior.is_empty():
		_spawn_pocket_pack(s, s.rule.pack)
		s.started = not s.pack.is_empty()
		if s.started:
			_begin_hazards(s, 1)
		return
	var kinds: Array = s.rule["pack"]
	s.pack.clear()
	# The ring's first spot lies 30 degrees past the point opposite the ball's entry, so none of the
	# three stands within 4 m of the ball's straight line through the ring.
	var entry: Vector3 = ctx.player.ball_position() - s.global_position
	var first := atan2(entry.z, entry.x) + PI + PACK_TURN
	for i in kinds.size():
		var a := first + TAU * float(i) / kinds.size()
		var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
		var enemy = ctx.spawner.spawn_enemy(kinds[i], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
	s.started = not s.pack.is_empty()
	if s.started and s.fog != null:
		s.fog.begin(1)


static func _alive(pack: Array) -> int:
	var n := 0
	for enemy in pack:
		if is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()):
			n += 1
	return n


# ---- The cache ----

func _watch_wall(s: Site, ball: Vector3) -> void:
	var v: Vector3 = ctx.player.state.velocity
	var toward := -(v.x * s.global_basis.z.x + v.z * s.global_basis.z.z)
	var local := s.to_local(ball)
	var ahead := local.z - 0.5
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > WALL_HALF_W + 1.0 or local.y > WALL_HEIGHT + 2.0:
		return
	if toward >= ctx.tuning.f("cruise"):
		_break_wall(s)


func _slammed(at: Vector3, strength: float) -> void:
	if strength < ctx.player.slam_strength(ctx.tuning.f("cruise")) * SLAM_MIN_PER_CRUISE:
		return
	for s in sites:
		if s.wall == null or s.done:
			continue
		var local: Vector3 = s.to_local(at)
		if local.z > 0.5 and local.z < 0.5 + SLAM_REACH and absf(local.x) <= WALL_HALF_W + 1.0:
			_break_wall(s)


func _break_wall(s: Site) -> void:
	if s.done:
		return
	s.wall.position += Vector3.DOWN * 400.0
	s.wall.visible = false
	if s.fired_glow != null:
		s.fired_glow.emission_enabled = true
		s.fired_glow.emission = Palette.SAND
		s.fired_glow.emission_energy_multiplier = CACHE_FIRED_GLOW.energy
	ctx.events.world_fact.emit("wall_crumbled", s.global_position)
	_finish(s, s.pedestal)


# ---- The bounty ----

func _spawn_bounty(s: Site) -> void:
	var at: Vector3 = ctx.terrain.drop_point(s.global_position.x, s.global_position.z, BRUTE_DROP)
	var brute = ctx.spawner.spawn_enemy(String(s.rule["kind"]), at)
	if brute == null or not brute.has_method("carry_bounty"):
		return
	brute.carry_bounty(s.global_position, EventKinds.activity_color(s.id))
	brute.bounty_wake = float(s.rule["wake"])
	brute.bounty_leash = float(s.rule["leash"])
	brute.bounty_return_speed = float(s.rule["return_speed"])
	brute.died.connect(func(where: Vector3, _scrap: int): _bounty_died(s, where))
	s.brute = brute
	s.started = true


func _bounty_died(s: Site, where: Vector3) -> void:
	if not is_instance_valid(s) or s.done:
		return
	_finish(s, Vector3(where.x, ctx.terrain.height(where.x, where.z), where.z))


# ---- The pay ----

# What the stand pays from, read by the pay below and by the readout before commit: `named` is
# the authored part when the table offers it ("" otherwise), `rarities` the table the roll
# draws from, or the named part's own tier. A named part the table does not offer
# (not in ctx.stages.part_in_play) rolls like any other pay.
func pay_table(s: Site) -> Dictionary:
	var pay: Dictionary = s.rule["pay"]
	if pay.has("named"):
		var named := String(pay["named"])
		if (Parts.rows().has(named) or Parts.is_burden(named)) and ctx.stages.part_in_play(named):
			return {"named": named, "rarities": [Parts.rarity_of(named)]}
	return {"named": "", "rarities": ItemGen.resolve_rarities(pay.get("rarities", ["common"]))}


# What a stand shows before the ball commits (SG13): the rarities its pay can hold, each with
# its weight from ItemGen.TIER_WEIGHTS, and the readout line for them. A named part is a sure
# thing, so it shows its own tier at 100%.
func stand_odds(s: Site) -> Dictionary:
	var table := pay_table(s)
	var odds: Array = ItemGen.odds(table["rarities"]) if table["named"] != "" \
			else OddsReadout.odds_for(table["rarities"], ctx.run.class_id())
	var result := {"named": table["named"], "rarities": table["rarities"], "odds": odds, "text": OddsReadout.text(odds)}
	if s.rule.has("bundle"):
		var picks: Array = s.reward_parts
		var rung := 0
		var descriptions := []
		var rarity := "common"
		for part in picks:
			var part_rarity := Parts.rarity_of(part)
			if int(ItemGen.RARITY[part_rarity].rung) >= rung:
				rung = int(ItemGen.RARITY[part_rarity].rung)
				rarity = part_rarity
			if not part_rarity in descriptions:
				descriptions.append(part_rarity)
		result["tier"] = picks.size() + rung
		result["parts"] = picks.size()
		result["reward_rarity"] = rarity
		result["reward_text"] = Parts.display_name(String(table.named)) if table.named != "" else "%d %s parts" % [picks.size(), "/".join(descriptions)]
	return result

func _finish(s: Site, at: Vector3) -> void:
	if s.done:
		return
	s.done = true
	for hazard in s.hazards:
		hazard.stop()
	if s.rule.has("bundle"):
		_heal(s)
		if s.id != "round_arena":
			_cue(s, "clear")
	s.view.finish()
	if s.tier_label != null:
		s.tier_label.visible = false
	if s.cap != null:
		s.cap.visible = false
	if s.id == "round_arena":
		_pay_piece()
		ctx.events.activity_done.emit(s.id, at)
		return
	var table := pay_table(s)
	if table["named"] != "":
		s.pickup_part = table["named"]
		if s.rule.has("bundle"):
			s.pickup_parts = [s.pickup_part]
	else:
		if s.rule.has("bundle"):
			s.pickup_parts = s.reward_parts.duplicate()
			s.pickup_part = String(s.pickup_parts[0]) if not s.pickup_parts.is_empty() else ""
		else:
			s.pickup_part = _roll(s.id, table["rarities"])
	if s.pickup_part != "":
		s.pickup = ActivityView.gem(String(s.rule.cue.view) if s.rule.has("bundle") else s.id)
		s.add_child(s.pickup)
		s.pickup.global_position = at
		s.inside_pickup = _planar(ctx.player.ball_position(), at) <= PICKUP_REACH
	else:
		_pay_scrap(s, at)
	_pay_piece()
	ctx.events.activity_done.emit(s.id, at)


func _pay_piece() -> void:
	if _piece_paid:
		return
	var id := Companion.next_drop(ctx.run.companion)
	if id == "":
		return
	ctx.run.companion = Companion.with_piece(ctx.run.companion, id)
	_piece_paid = true


# The rule's scrap, through the run's own add_scrap so it grows the ball and publishes a class up.
# The same amount lands in the cog wallet (CG2, one cog per scrap unit as on kills), so the
# activity still pays what it paid when scrap was the money.
func _pay_scrap(s: Site, at: Vector3) -> void:
	var amount := int(s.rule["pay"].get("scrap", 0))
	if amount > 0:
		ctx.run.add_scrap(amount, at)
		ctx.run.add_cogs(amount)


func _roll(id: String, rarities: Array) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, id)
	var picks: Array = Parts.roll(rng, rarities, ctx.run.class_id(), ctx.run.parts, 1)
	return String(picks[0]) if not picks.is_empty() else ""


# A pickup takes the ball that rolls onto it, not one already standing there when it appeared.
func _watch_pickup(s: Site, ball: Vector3) -> void:
	if s.pickup == null or s.pickup_taken:
		return
	var at: Vector3 = s.pickup.global_position
	var now := _planar(ball, at) <= PICKUP_REACH and absf(ball.y - at.y) < PICKUP_HEIGHT
	if now and not s.inside_pickup:
		s.pickup_taken = true
		s.pickup.queue_free()
		s.pickup = null
		if s.rule.has("bundle"):
			for part in s.pickup_parts:
				ctx.run.add_part(part, String(s.rule.pay.source))
		else:
			ctx.run.add_part(s.pickup_part, String(s.rule["pay"]["source"]))
		_pay_scrap(s, at)
		if s.rule.has("bundle"):
			_cue(s, "pay")
		return
	s.inside_pickup = now
