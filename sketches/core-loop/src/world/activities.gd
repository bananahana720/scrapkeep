extends Node3D

const ActivityView := preload("res://src/world/activity_view.gd")
const Companion := preload("res://src/core/companion.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const Cards := preload("res://src/world/director_cards.gd")
const HoldRelay := preload("res://src/world/hold_relay.gd")
const RelayStake := preload("res://src/world/relay_stake.gd")
const Interact := preload("res://src/world/interact.gd")
const ItemGen := preload("res://src/build/item_gen.gd")
const OddsReadout := preload("res://src/ui/odds_readout.gd")
const Palette := preload("res://src/core/palette.gd")
const BakeLook := preload("res://src/presentation/bake_look.gd")
const Parts := preload("res://src/build/parts.gd")
const ParkGraph := preload("res://src/world/park/park_graph.gd")
const PocketFog := preload("res://src/world/events/pocket_fog.gd")
const TradePockets := preload("res://src/world/trade_pockets.gd")
const StakeDevices := preload("res://src/world/stake_devices.gd")
const PocketDraw := preload("res://src/world/pockets/pocket_draw.gd")
const PocketLibrary := preload("res://src/world/pockets/pocket_library.gd")
const Secrets := preload("res://src/core/secrets.gd")
const AmbushAltar := preload("res://src/world/ambush_altar.gd")
const CrackedCache := preload("res://src/world/cracked_cache.gd")
const FindKit := preload("res://src/world/find_kit.gd")
const ModelKit := preload("res://src/world/model_kit.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const WorldFx := preload("res://src/presentation/world_fx/world_fx.gd")
const WorldFxAnchor := preload("res://src/presentation/world_fx/world_fx_anchor.gd")
const StageModifier := preload("res://src/world/events/stage_modifier.gd")
const SurgeCourse := preload("res://src/world/surge_course.gd")
const EventDirector := preload("res://src/world/event_director.gd")

# A surge course's ring was rolled into (its row id): the world opens the park's sluice row on it.
signal sluice_opened(row_id: String)
# The course was won or lost: the world ends the sluice row early.
signal sluice_closed(row_id: String)

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
#           goes to a ram at RAM_MIN_PER_CRUISE x cruise or a slam of at least that strength) or "brute_dead".
# pay:      `scrap` (180, so three activities lift the ball two heft classes), taken with one
#           part from `rarities` or an authored `named` part id, as a pickup at `where`: the altar, the pedestal or the
#           place the brute fell, or the relay's mast. A roll with no part pays the scrap when the activity finishes. part_gained carries `source`, which is not in
#           EventKinds.CEREMONY_SOURCES, so no ceremony pauses the game for it. The first activity finished
#           in a stage entry also adds the next companion piece (Companion.DROP_ORDER) to the run, unequipped.
const PAY_RARITIES := ["common", "rare"]
const PAY_SCRAP := 180
# A pocket interior's cover block and entrance bollard (pocket_kit.glb), the block built 4 by 3 by 4 m.
const POCKET_KIT := "res://assets/models/world_one/pocket_kit.glb"
const POCKET_PARTS := ["PocketBlock", "PocketPost"]
const POCKET_BLOCK := Vector3(4.0, 3.0, 4.0)
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
		# The on-line pocket's common roll (PARK.md 2.12; ruling bu, 2026-11-09: a camp pays from the pool,
		# where it always paid Hot Rivets). A park row may still author a named part.
		"pay": {"scrap": PAY_SCRAP, "rarities": ["common"], "source": "activity_camp", "where": "camp"},
	},
	"ambush_altar": {
		"starts": "ring", "ring": 8.0, "pack": ["chaser", "chaser", "lobber"], "finishes": "pack_dead",
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_ambush", "where": "altar"},
	},
	"cracked_cache": {
		"starts": "none", "ring": 5.0, "finishes": "wall_broken", "face": Vector2(0.0, -1.0),
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_cache", "where": "pedestal"},
		# A bump under the ram's bar answers with the roll's refused cue (ruling p), so the face reads as
		# "faster", not as solid: from `floor` x cruise up to the bar, in these worlds, once a face every
		# `gap_s` of play. Under the floor (a ball resting on or easing into the face) it stays quiet.
		"refused": {"worlds": [1], "floor": 0.4, "gap_s": 3.0},
	},
	# Hold the Relay in a park (W13 SR10): a stake post `post_out` metres outside the ring, past the
	# miniboss zone, on the side facing the stage's drop-in, takes 0 to 4 stacks before the ball rolls into the ring; the
	# ring then charges by hold_relay.gd's rule. The relay's pack credit (`waves` buys of `pack`)
	# and its miniboss count are both times 1 + k, and it pays 1 + k part rolls. Packs come every
	# `wave_s` while it charges and never two inside `pack_gap_s`; what the relay stands at once,
	# minibosses included, stays inside the attacker budget (relay_budget). Minibosses come from
	# `miniboss_at` in steps of `miniboss_step` of the charge. A loss frees the stake after
	# `retry_s`.
	"hold_the_relay": {
		"starts": "ring", "ring": HoldRelay.RULE["radius"], "finishes": "relay", "pack": ["chaser", "chaser", "lobber"],
		"waves": 3, "wave_s": 6.0, "pack_gap_s": 0.5, "miniboss_at": 0.35, "miniboss_step": 0.12,
		"post_out": 26.0, "retry_s": 12.0, "budget": {"start": 6, "per_class": 1, "per_world": 2, "cap": 12},
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_relay", "where": "relay"},
	},
	# The surge course in a park (surge_course.gd): rolling into the ring by the head of the activity row's `route`
	# opens the sluice (the park's sluice_surge event row, triggered on this row), and when the gate lands the water
	# chases the ball down the route's grind rows through the gates. A ring with no sluice heard opens anyway after
	# `fallback_s`. Taking every gate before the front pays one part into the ball's path; a loss re-arms after
	# `retry_s`. The front only ever pushes the ball on (EventDirector.never_brake) and never hurts it.
	"surge_run": {
		"starts": "ring", "ring": 7.0, "finishes": "surge", "fallback_s": 10.0, "retry_s": 12.0,
		"pay": {"scrap": PAY_SCRAP, "rarities": PAY_RARITIES, "source": "activity_surge", "where": "ball"},
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
# The ball touching the face: its centre one radius (Tuning.RADIUS 1.0) and a little more off it.
const WALL_CONTACT := 1.2
const SLAM_REACH := 7.0
# `slammed` carries the ball's own strength for the landing (player.slam_strength), not a speed.
# A slam breaks the wall at SLAM_MIN_PER_CRUISE times the strength of a flat landing at cruise speed,
# a landing at cruise. It stays at full cruise, over the ram's bar: slam_strength floors at 0.4, so a bar
# at 0.85 x cruise (strength 0.397) would let any flat landing break the wall.
const SLAM_MIN_PER_CRUISE := 1.0
# A ram breaks the wall at RAM_MIN_PER_CRUISE times cruise into the face. A held stick climbs toward
# cruise and never quite reaches it on a run-up (12.6-13.8 m/s over 10-22 m, 14.0 only after 30 m),
# so with the bar at cruise itself only the speed bank's roll start or a burst broke the wall: a player
# already rolling at full speed bumped the face (cautious red team, 26 Oct). A nudge stays under it.
const RAM_MIN_PER_CRUISE := 0.85
const PEDESTAL_BACK := 4.0
const CACHE_LANE_OFFSET := 6.0
# The first-win room's log line on the back wall, on a dark crew board of its own: the fired wall
# glows sand (CACHE_FIRED_GLOW), so text straight on it washes out. The board sits above the ball's
# eye line, clear of the centre prompts and the beacon's beam, and its wrap keeps it inside the
# board at Label3D's 0.005 m per pixel.
const ROOM_LOG_HEIGHT := 4.5
const ROOM_LOG_WIDTH_PX := 1240.0
const ROOM_BOARD_SIZE := Vector2(7.0, 1.5)
# The room's tell from outside, for a sharp eye only: a crew chalk tally on the cracked face and one
# work glove hung on a nail beside it (the crew were the Mind's hands, worlds.gd). An ordinary cracked
# cache has neither. Both sit on the face, not the ground: Terrain3D's drawn floor can stand above the
# collider by more than a glove's height, which buried a glove laid on the ground.
const ROOM_TALLY_AT := Vector3(3.6, 1.3, 0.52)
const ROOM_TALLY_STROKE := Vector2(0.14, 1.1)
const ROOM_GLOVE_AT := Vector3(2.3, 2.3, 0.5)
const ROOM_GLOVE_SCALE := 1.6
# The back wall's own glow once the wall is fired. No light: a per-site OmniLight3D freed on
# a stage change made Godot 4.7.2 Forward+ segfault on the next boss entry (GPU only), as the
# wave 9 cage light did.
const CACHE_FIRED_GLOW := {"energy": 0.8}
# A field find's tells: seep streaks on the cracked face (x, y, width in metres) and the radio aerial.
const FIND_SEEP_STREAKS := [Vector3(-2.6, 0.4, 0.5), Vector3(-1.9, 0.1, 0.3), Vector3(2.2, 0.6, 0.4)]
const FIND_AERIAL_M := 3.2
# The timed door's punch clock plate, square, on the cracked face.
const DOOR_CLOCK_M := 1.6
# One wet material for every seep streak.
static var _find_wet: StandardMaterial3D

# How near the ball must be to a site it has started for the site to be the one at hand, and how
# far it must roll before a site that was at hand lets go (at_hand).
const AT_HAND_M := 80.0
const LET_GO_M := 100.0

var ctx
var sites: Array = []
var _piece_paid := false
var _pending_stage := false
var _elite_arrivals := 0
var _graph
var _graph_map := ""
var _draw_layout := {}
var _draw_map := ""
# The SI3 row this stage's draw applied, {} for none; the stage card shows the same row.
var stage_modifier := {}
var _mark_pools := {}
# A park map's stage-entry data (SWAP-HITCH): the baked graph, the trade-pocket candidates and,
# for a map played past stage 1, the pocket-draw layout. All three read only the graph and the
# map's authored rows, so a worker builds them for the next stage's map while this one plays,
# from a copy taken on the main thread, and hands them back as plain data. Map id -> {"task",
# "out"} while the worker runs, then {"pool", "layout"}; the graph goes to shared_graph.
var _prep := {}
# One read graph per path for the game's readers (activities, audio's parameter sampler). Main
# thread only: a search writes the graph's own heap, so a worker reads a private graph and hands
# it in through _adopt_graph. Here, not in park_graph.gd, whose source the baked graphs hash.
static var _shared_graphs := {}
# The main-thread time of the last stage_entered handler, for stage_entry_budget_test.
var last_entry_usec := 0
# That handler's parts, each "part ms" (clear, then a site id per _build), so the test can name what a slow entry built.
var last_entry_steps := PackedStringArray()
# The next stage's sites, built during a launch's flight under a hidden, disabled holder (the flume entry's longest
# part, 37 ms of 105 on the 4080): {"stage", "holder", "plan", "built", "grounds"}, {} when none. The entry takes each
# one whose plan entry it would build again, and ground under it reads the same, and builds the rest as before.
var _ahead := {}
# Where _build_site puts a site: this node, or the ahead holder while it builds.
var _site_parent: Node = null
# The flight plans this many ticks after the launch, and builds from the tick after: the launch frame stays the kick's.
const AHEAD_PLAN_TICKS := 2
# The main-thread time of the flight's plan, for tests.
var last_ahead_plan_usec := 0
# The flight's builds, each "id ms", as last_entry_steps.
var last_ahead_steps := PackedStringArray()
# How many sites the entry took from the ahead build, for tests.
var last_entry_adopted := 0
# The holders whose sites this stage adopted.
var _holders: Array = []
# The trade interior's block material, built once instead of a checker texture a block;
# dress_props reads its two colours and replaces it, so every block can share it.
static var _interior_block: StandardMaterial3D
static var _wall: PhysicsMaterial
# True on the Game's own instance (setup ran), whose _exit_tree is the Game's teardown. A
# contraption's cache helper (contraptions.gd) leaves with its stage root on a stage exit, and
# releasing the shared caches there dropped the next stage's plans before its retry (SWAP-HITCH-3).
var _owns_shared := false

const POCKET_HEAL_SHARE := 0.15
const POCKET_FOG_SIZE := Vector3(32, 8, 32)
const POCKET_SAFE_M := 4.0
const POCKET_DAMAGE_PER_S := 8.0
const MARK_SPACING_M := 80.0
const MARK_POOL_SIZE := 16
# A charging relay reports its progress when it has moved this far (event_director's step).
const RELAY_PROGRESS_STEP := 0.01
# The head-gate crew's lines on the ring's word, in the crew-log voice (design-v3/TONE-BIBLE.md: deadpan words, no
# jokes about the rider; the siren and the water carry the noise). Their post stands beside the ring (props flume_c01).
const SURGE_WORDS := {
	"open": "Head gate: wheel turning. Stay ahead of the water.",
	"won": "Head gate log: wheel shut. One ball through, flume dry.",
	"lost": "Head gate: winding the wheel back.",
}


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
	# The physics frame of this face's last refused cue (RULES cracked_cache refused).
	var refused_frame := -1
	var round := 0
	var round_elements: Array = []
	var round_credits := 0.0
	var round_payments := 0
	var round_rewards: Array = []
	var awaiting_round := false
	var wave := 0
	var spawn_positions: Array = []
	var phase_view: Node3D
	var drawn := false
	var interior := {}
	var interior_collision_ready := false
	var trade := {}
	var trade_devices: Array = []
	var footprint := POCKET_FOG_SIZE
	var relay
	var stake_post: Node3D
	var relay_credit := 0.0
	var relay_wave_s := 0.0
	var relay_gap_s := 0.0
	var relay_wave_left := 0
	var relay_shown := -1.0
	var relay_cooldown := 0.0
	var minibosses_sent := 0
	var minibosses: Array = []
	var course
	var surge_row := ""
	var surge_live := false
	var surge_wait := 0.0
	var surge_shown := -1.0

	func _exit_tree() -> void:
		for enemy in pack + minibosses:
			if is_instance_valid(enemy):
				enemy.queue_free()


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	_owns_shared = true
	name = "Activities"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String):
		clear()
		_drop_ahead())
	ctx.events.launched.connect(_on_launched)
	ctx.events.slammed.connect(func(at: Vector3, strength: float, _flatness: float): _slammed(at, strength))
	ctx.events.world_fact.connect(_on_world_fact)
	# The trade devices' plate finish neutralises its texture pixel by pixel on first use (about
	# 55 ms, SWAP-HITCH-2); Palette caches it, so it is made here rather than on a stage entry.
	Palette.look_texture("rusted-salvaged-plate-worn", true)
	# The polish bake's shade ramp is drawn pixel by pixel too, on the first enemy spawn's frame.
	BakeLook.ramp()
	_prepare_stage(1)


func _exit_tree() -> void:
	for id in _prep:
		_settle(id)
	if not _owns_shared:
		return
	# No static keeps a map, mesh, shape or material once the Game is freed.
	load("res://src/world/director.gd").release_parks()
	load("res://src/world/events/natural.gd").release_plans()
	load("res://src/presentation/set_dressing.gd").release_shared()
	load("res://src/presentation/park_props.gd").release_shared()
	_interior_block = null
	_wall = null


# Waits once on a map's entry-data worker and takes its results. worker_layout records that the
# worker computed the layout, so a test can tell it from one _enter_stage computes later.
func _settle(id: String) -> void:
	if not _prep.has(id) or not _prep[id].has("task"):
		return
	WorkerThreadPool.wait_for_task_completion(_prep[id].task)
	var done: Dictionary = _prep[id].out
	_adopt_graph(graph_path(id), done.graph)
	_prep[id] = {"pool": done.pool, "layout": done.layout, "worker_layout": not done.layout.is_empty()}


# Starts the worker for a stage's map when the terrain has that stage (a test double may not).
func _prepare_stage(stage_number: int) -> void:
	var terrain = ctx.terrain
	if terrain == null or not "maps" in terrain or not terrain.has_method("map_for"):
		return
	if stage_number >= 1 and stage_number <= terrain.maps.size():
		_prepare_map(terrain.map_for(stage_number))


static func graph_path(map_id: String) -> String:
	return "res://assets/park/%s/graph.bin" % map_id


# The game's copy of a baked graph, read once per path (about 50 ms a map) and shared by every
# reader, which treats it as read-only. ParkGraph.read still gives a private copy.
static func shared_graph(path: String):
	if not _shared_graphs.has(path):
		_shared_graphs[path] = ParkGraph.read(path) if FileAccess.file_exists(path) else null
	return _shared_graphs[path]


# A graph a worker read for this path becomes the shared one, unless one is already shared.
static func _adopt_graph(path: String, graph) -> void:
	if graph != null and _shared_graphs.get(path) == null:
		_shared_graphs[path] = graph


# Starts the worker for a park map's entry data, the pocket-draw layout included (every stage
# draws, the dam too). The worker reads its own graph and a deep copy of the rows, so no live
# object is shared with it.
func _prepare_map(map) -> void:
	if map == null or not "park" in map or map.park.is_empty():
		return
	var id := String(map.park.map)
	if _prep.has(id):
		return
	var rows := {"park": map.park.duplicate(true), "activity_sites": map.activity_sites.duplicate(true), "play_rect": map.play_rect}
	var out := {}
	var path := graph_path(id)
	_prep[id] = {"task": WorkerThreadPool.add_task(func(): out.merge(prepare_data(path, rows, true)), false, "activities prep " + id), "out": out}
	# The director's read of the same map (its rows and corridor reader) goes on a worker too.
	load("res://src/world/director.gd").prepare_park(id)


# The pure part of a park map's stage entry, safe on a worker: no node, no tree, no shared graph.
static func prepare_data(path: String, map, layout: bool) -> Dictionary:
	var graph = ParkGraph.read(path) if FileAccess.file_exists(path) else null
	if graph == null:
		return {"graph": null, "pool": PackedInt32Array(), "layout": {}}
	# The zone member lists fill on their first read, the entry tick's rib cache spots (7 ms on the
	# cloud at the flume, scrapkeep#494), so the worker fills them while the graph is still its own.
	if graph.zone_count() > 0:
		graph.zone_nodes(0)
	return {"graph": graph, "pool": TradePockets.candidates(graph, map), "layout": PocketDraw.prepare(graph, map) if layout else {}}


# This map's entry data, waiting on its worker when one is still running (a stage reached before
# its worker finished), or computed here when none was started (a direct use in a test).
func _entry_data(map) -> Dictionary:
	var id := String(map.park.map)
	_settle(id)
	var graph = shared_graph(graph_path(id))
	if not _prep.has(id):
		_prep[id] = {"pool": TradePockets.candidates(graph, map) if graph != null else PackedInt32Array(), "layout": {}}
	return _prep[id]


func _on_stage_entered(_stage: int, retry: bool) -> void:
	var started := Time.get_ticks_usec()
	last_entry_steps = PackedStringArray()
	_enter_stage(retry)
	last_entry_usec = Time.get_ticks_usec() - started


func _enter_stage(retry: bool) -> void:
	var cleared := Time.get_ticks_usec()
	clear()
	last_entry_steps.append("clear %.1f" % ((Time.get_ticks_usec() - cleared) / 1000.0))
	_elite_arrivals = 0
	stage_modifier = {}
	last_entry_adopted = 0
	_site_parent = null
	# A retry does not re-arm the piece, so dying cannot farm one.
	if not retry:
		_piece_paid = false
	var map = ctx.terrain.map()
	var entry_data := _use_map(map)
	# The next stage's worker starts now, so it has this whole stage to finish.
	if "stage" in ctx.terrain:
		_prepare_stage(int(ctx.terrain.stage) + 1)
	if not "activity_sites" in map:
		_drop_ahead()
		StageModifier.set_air({})
		return
	var plan := _plan(map, entry_data)
	stage_modifier = plan.modifier
	var ahead := {}
	if not retry and int(_ahead.get("stage", 0)) == ctx.run.stage and not _ahead.plan.is_empty():
		ahead = _ahead
		_ahead = {}
	else:
		_drop_ahead()
	for i in plan.sites.size():
		var entry: Dictionary = plan.sites[i]
		var site: Site = _adopt(ahead, i, entry)
		if site == null:
			site = _build_entry(entry, stage_modifier)
		else:
			_arm(site)
			last_entry_adopted += 1
		sites.append(site)
	if not ahead.is_empty():
		_uncover(ahead)
	StageModifier.set_air(stage_modifier)
	_pending_stage = true


# The map's graph and its worker's entry data become this stage's.
func _use_map(map) -> Dictionary:
	_graph = null
	_graph_map = ""
	_mark_pools.clear()
	if "park" in map and not map.park.is_empty():
		_graph_map = String(map.park.map)
		var entry_data := _entry_data(map)
		_graph = shared_graph(graph_path(_graph_map))
		return entry_data
	return {}


# Every site a stage entry builds, in build order, with what the build does after it, and the stage's modifier.
# The draws write the run's caches (trade offers, pocket draws) as they always have; nothing here makes a node.
func _plan(map, entry_data: Dictionary) -> Dictionary:
	var out := []
	var modifier := {}
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
		out.append({"kind": "row", "id": id, "at": spec["at"], "spec": built_spec})
	if _graph_map != "":
		var tuning = ctx.get("tuning")
		var sitting: bool = tuning != null and tuning.has_method("sitting") and tuning.sitting()
		for room_spec in Secrets.room_sites(_graph_map, ctx.get("profile"), sitting):
			out.append({"kind": "room", "id": "cracked_cache", "at": room_spec["at"], "spec": room_spec, "secret": String(room_spec["secret"])})
		# The run's own seed picks the spots, so the next run moves them and a replay keeps them.
		for find_spec in Secrets.find_sites(_graph_map, hash([ctx.rng.seed, ctx.run.run_seed, "field_finds"])):
			out.append({"kind": "find", "id": "cracked_cache", "at": find_spec["at"], "spec": find_spec, "find": String(find_spec["find"])})
		# A fast Brindle rout last run: the timed door stands open this run (secrets.gd DOOR).
		for door_spec in Secrets.door_sites(_graph_map, ctx.get("profile")):
			out.append({"kind": "door", "id": "cracked_cache", "at": door_spec["at"], "spec": door_spec})
	if _graph != null:
		var pool: PackedInt32Array = entry_data.pool
		var trade_spec := TradePockets.stage_site(_graph, map, ctx.run, ctx.rng.seed, pool)
		if not trade_spec.is_empty():
			out.append({"kind": "trade", "id": trade_spec.id, "at": trade_spec.at, "spec": trade_spec})
		if _draw_map != _graph_map:
			_draw_layout = {}
			_draw_map = _graph_map
		if _draw_layout.is_empty():
			if entry_data.layout.is_empty():
				entry_data.layout = PocketDraw.prepare(_graph, map)
			_draw_layout = entry_data.layout
		modifier = StageModifier.for_stage(ctx.run, ctx.terrain, ctx.run.stage)
		for drawn_spec in PocketDraw.stage_sites(_graph, map, ctx.run, ctx.rng.seed, trade_spec, _draw_layout, modifier):
			if not ctx.calm or RULES[drawn_spec.id].finishes == "wall_broken":
				out.append({"kind": "drawn", "id": drawn_spec.id, "at": drawn_spec.at, "spec": drawn_spec})
	return {"sites": out, "modifier": modifier}


# What a site kind's marker calls it ("Arena", "Pickup course"), "" for a kind whose cue has no word.
static func called(id: String) -> String:
	return String(RULES.get(id, {}).get("cue", {}).get("word", ""))


# One planned site, built and dressed as its kind asks. Interact does not know it yet (_arm).
func _build_entry(entry: Dictionary, modifier: Dictionary) -> Site:
	var site := _build(entry.id, entry.at, entry.spec)
	match String(entry.kind):
		"room":
			_hang_room_log(site, entry.secret)
		"find":
			var dressed := Time.get_ticks_usec()
			_dress_find(site, entry.find)
			last_entry_steps.append("find %s %.1f" % [entry.find, (Time.get_ticks_usec() - dressed) / 1000.0])
		"door":
			_dress_door(site)
		"drawn":
			site.view.set_sight(float(modifier.get("sight_scale", 1.0)))
			StageModifier.mark_far(modifier, site)
	return site


# An ahead site's devices and stake post join Interact as the entry takes it (an entry's own build registers them).
func _arm(site: Site) -> void:
	var interact: Node = ctx.root.get_node("Interact")
	for device in site.trade_devices:
		interact.register(device)
	if site.stake_post != null:
		interact.register(site.stake_post)


# ---- Built during the launch's flight ----

# A launch toward the next park stage (not a world's last, whose launch goes to its boss) starts that stage's sites,
# where stages are built on workers (a played game, a frame-capture bot run). Bots and tests build at entry as before.
func _on_launched(_velocity: Vector3) -> void:
	_drop_ahead()
	if ctx.terrain == null or not ctx.terrain.has_method("_worker_builds") or not ctx.terrain._worker_builds():
		return
	var flow = ctx.get("flow")
	if flow == null or not flow.state_name() in ["gates", "launch"]:
		return
	var stage: int = ctx.run.stage + 1
	if ctx.stages.is_world_last(ctx.run.stage) or not "maps" in ctx.terrain or stage > ctx.terrain.maps.size() \
			or not ctx.terrain.is_ready(stage):
		return
	var map = ctx.terrain.map_for(stage)
	if not "park" in map or map.park.is_empty() or not "activity_sites" in map:
		return
	var holder := Node3D.new()
	holder.name = "AheadSites_%d" % stage
	holder.visible = false
	# Disabled: nothing under it processes, and its bodies stay out of the space until the entry takes them.
	holder.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(holder)
	_ahead = {"stage": stage, "holder": holder, "plan": {}, "built": [], "grounds": [], "run": _run_key(), "wait": AHEAD_PLAN_TICKS}


# The flight's plan, AHEAD_PLAN_TICKS after the launch: the launch's own frame (the kick) carries nothing of it.
func _plan_ahead() -> void:
	var stage: int = _ahead.stage
	var map = ctx.terrain.map_for(stage)
	var started := Time.get_ticks_usec()
	last_ahead_steps = PackedStringArray()
	# The run's caches as the entry will find them: run_state.enter_stage refuses the offers left unanswered.
	var memory: Dictionary = ctx.run.trade_memory
	var draws: Dictionary = ctx.run.pocket_draw_cache
	ctx.run.trade_memory = memory.duplicate(true)
	ctx.run.pocket_draw_cache = draws.duplicate(true)
	for offer in ctx.run.trade_memory.seen:
		if int(offer.stage) == stage - 1 and not ctx.run.trade_memory.decisions.has(str(stage - 1)):
			TradePockets.decide(ctx.run.trade_memory, offer, false)
	_as_stage(stage, map, func(): _ahead.plan = _plan(map, _entry_data(map)))
	ctx.run.trade_memory = memory
	ctx.run.pocket_draw_cache = draws
	last_ahead_plan_usec = Time.get_ticks_usec() - started
	if _ahead.plan.is_empty():
		_drop_ahead()


# What a site's build reads of the run besides its plan: device prices and pocket rewards (parts, health, class).
func _run_key() -> int:
	return hash([ctx.run.parts, ctx.run.max_hp, ctx.run.class_id(), ctx.run.heft_class()])


# One ahead site a physics tick, while the flight lasts.
func _step_ahead() -> void:
	var i: int = _ahead.built.size()
	var entry: Dictionary = _ahead.plan.sites[i]
	var map = ctx.terrain.map_for(int(_ahead.stage))
	var steps := last_entry_steps
	var started := Time.get_ticks_usec()
	_site_parent = _ahead.holder
	_as_stage(int(_ahead.stage), map, func():
		_ahead.built.append(_build_entry(entry, _ahead.plan.modifier))
		_ahead.grounds.append(ctx.terrain.height(float(entry.at.x), float(entry.at.y))))
	_site_parent = null
	last_entry_steps = steps
	last_ahead_steps.append("%s %.1f" % [entry.id, (Time.get_ticks_usec() - started) / 1000.0])
	# A build that failed appends nothing: the entry builds the rest.
	if _ahead.built.size() <= i:
		_ahead.plan.sites.resize(i)


# Runs fn as though the stage were already `stage`: the run's and the terrain's stage, the terrain's overlays as the
# stage starts them, and this stage's graph and draw layout; all put back after.
func _as_stage(stage: int, map, fn: Callable) -> void:
	var saved := [ctx.run.stage, ctx.terrain.stage, ctx.terrain.overlays.duplicate(), _graph, _graph_map, _draw_layout, _draw_map, _mark_pools]
	ctx.run.stage = stage
	ctx.terrain.stage = stage
	ctx.terrain.overlays.clear()
	if "start_overlays" in map:
		ctx.terrain.overlays.append_array(map.start_overlays)
	_mark_pools = {}
	_graph_map = String(map.park.map)
	# The worker's graph first: shared_graph alone would read the map's graph again on this tick (about 50 ms).
	_settle(_graph_map)
	_graph = shared_graph(graph_path(_graph_map))
	fn.call()
	ctx.run.stage = saved[0]
	ctx.terrain.stage = saved[1]
	ctx.terrain.overlays.assign(saved[2])
	_graph = saved[3]
	_graph_map = saved[4]
	_draw_layout = saved[5]
	_draw_map = saved[6]
	_mark_pools = saved[7]


# The ahead site for plan entry i when the flight built it from the same entry over the same ground. It stays under
# its holder (moving it would take every node out of the tree and back); null to build it here.
func _adopt(ahead: Dictionary, i: int, entry: Dictionary) -> Site:
	if ahead.is_empty() or i >= ahead.built.size() or i >= ahead.plan.sites.size() or ahead.run != _run_key():
		return null
	var planned: Dictionary = ahead.plan.sites[i]
	if not _same_entry(planned, entry) or (String(entry.kind) == "drawn" and hash(ahead.plan.modifier) != hash(stage_modifier)):
		return null
	if absf(float(ahead.grounds[i]) - ctx.terrain.height(float(entry.at.x), float(entry.at.y))) > 0.01:
		return null
	var site: Site = ahead.built[i]
	ahead.built[i] = null
	return site


static func _same_entry(a: Dictionary, b: Dictionary) -> bool:
	return a.kind == b.kind and a.id == b.id and a.at == b.at and hash(a.spec) == hash(b.spec) \
		and a.get("secret", "") == b.get("secret", "") and a.get("find", "") == b.get("find", "")


# The entry took what it could: the rest go, and the holder shows and runs, so its sites' bodies join the space now.
# It stays this stage's, freed with its sites by clear().
func _uncover(ahead: Dictionary) -> void:
	var taken := sites.filter(func(site): return is_instance_valid(site) and site.get_parent() == ahead.holder)
	if taken.is_empty():
		_free_holder(ahead)
		return
	# Every other child goes, a failed build's part-made site too.
	for child in ahead.holder.get_children():
		if not child in taken:
			ahead.holder.remove_child(child)
			child.queue_free()
	ahead.holder.visible = true
	ahead.holder.process_mode = Node.PROCESS_MODE_INHERIT
	_holders.append(ahead.holder)


func _drop_ahead() -> void:
	if not _ahead.is_empty():
		_free_holder(_ahead)
	_ahead = {}


func _free_holder(ahead: Dictionary) -> void:
	if is_instance_valid(ahead.holder):
		ahead.holder.queue_free()


func clear() -> void:
	for site in sites:
		if is_instance_valid(site):
			for device in site.trade_devices:
				ctx.root.get_node("Interact").unregister(device)
			if site.stake_post != null:
				ctx.root.get_node("Interact").unregister(site.stake_post)
			for enemy in site.minibosses:
				if is_instance_valid(enemy):
					enemy.queue_free()
			for hazard in site.hazards:
				hazard.stop()
			for enemy in site.pack:
				if is_instance_valid(enemy):
					enemy.queue_free()
			site.queue_free()
	sites.clear()
	for holder in _holders:
		if is_instance_valid(holder):
			holder.queue_free()
	_holders.clear()
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
	var started := Time.get_ticks_usec()
	var site := _build_site(id, at, spec)
	last_entry_steps.append("%s %.1f" % [id, (Time.get_ticks_usec() - started) / 1000.0])
	return site


func _build_site(id: String, at: Vector2, spec: Dictionary) -> Site:
	var s := Site.new()
	s.id = id
	s.rule = RULES[id]
	s.interior = spec.get("interior", {})
	s.drawn = spec.get("drawn", false)
	s.trade = spec.get("trade", {})
	var spec_pay: Dictionary = spec.get("pay", {})
	if id in ["enemy_camp", "hold_the_relay", "ambush_altar"] or not spec_pay.is_empty() or spec.has("face") or s.rule.has("bundle") or not s.interior.is_empty():
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
	elif id in ["hold_the_relay", "ambush_altar"] and not spec.get("pack", []).is_empty():
		s.rule["pack"] = spec.pack.duplicate()
	# PARK.md 2.12: the park row authors the pay ladder (rarities, or a named part that wins when the
	# table offers it). Scrap, source and where stay the rule's own, so the heft pace never moves.
	for key in ["rarities", "named"]:
		if spec_pay.has(key):
			s.rule["pay"][key] = spec_pay[key]
	# A field find faces out of its dead end (secrets.gd FINDS spots); a park row may set its own face.
	if spec.has("face"):
		s.rule["face"] = spec["face"]
	# A card 2 extra (PARK.md 2.12) is a second site beside the stage's own of its kind: it rolls apart (_luck_id).
	if spec.get("extra", "") == "card_2":
		s.set_meta("extra", String(spec.get("row", id)))
	s.name = "Activity_" + id
	(_site_parent if _site_parent != null else self).add_child(s)
	s.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
	if s.drawn:
		s.rotation.y = -spec.get("turn", 0) * PI * 0.5
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
		"hold_the_relay":
			_build_relay(s)
		"surge_run":
			_build_surge(s, spec)
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
		if _site_parent == null:
			ctx.root.get_node("Interact").register(device)
		s.trade_devices.append(device)
		words.append(device.words())
	var door: Array = s.interior.entrances[0].at
	var label := Label3D.new()
	label.name = "TradePrices"
	label.position = Vector3(door[0], 3.4, door[1] + 1.0)
	label.text = "%s\n%s\nHold E at a device" % [TradePockets.door_words(s.trade, s.interior.tell.word), "\n".join(words)]
	label.font_size = 36
	label.outline_size = 8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	s.add_child(label)


func _watch_trade(s: Site, ball: Vector3) -> void:
	if not s.started and _planar(ball, s.global_position) <= s.footprint.z * 0.5 + 16.0:
		s.started = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
	if not s.done and s.trade_devices.any(func(device): return device.spent):
		s.done = true
		TradePockets.see(ctx.run.trade_memory, s.trade)
		TradePockets.decide(ctx.run.trade_memory, s.trade, true)
		ctx.events.trade_taken.emit(s.id, s.global_position)


func _build_interior(s: Site) -> void:
	var root := Node3D.new()
	root.name = "Interior_" + String(s.interior.id)
	s.add_child(root)
	# Each block and bollard wears the pocket kit's model (tools/blender/world_one/pocket_kit.py), scaled from
	# its nominal size; a block's model sits under an unscaled holder so its collider (added on entry)
	# keeps the authored size. A missing kit keeps the striped boxes.
	for block in s.interior.terrain:
		var size := Vector3(block.size[0], block.size[1], block.size[2])
		var at := Vector3(block.at[0], size.y * 0.5, block.at[1])
		var holder := Node3D.new()
		holder.position = at
		root.add_child(holder)
		var view := ModelKit.part(POCKET_KIT, POCKET_PARTS, "PocketBlock", holder)
		if view != null:
			view.scale = size / POCKET_BLOCK
			continue
		holder.free()
		if _interior_block == null:
			_interior_block = Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
		_mesh_box(root, size, at, _interior_block)
	for entrance in s.interior.entrances:
		for side in [-1.0, 1.0]:
			var post_at := Vector3(entrance.at[0] + side * entrance.width * 0.5, 1.0, entrance.at[1])
			var post := ModelKit.part(POCKET_KIT, POCKET_PARTS, "PocketPost", root)
			if post != null:
				post.position = post_at
				post.material_override = _solid(EventKinds.activity_color(s.view.id))
			else:
				_mesh_box(root, Vector3(0.3, 2.0, 0.3), post_at, _solid(EventKinds.activity_color(s.view.id)))
	# The interior builds after the site's own dressing pass, so it dresses its own blocks (2026-10-14).
	load("res://src/presentation/spillway_scenery.gd").dress_props(root)


# Interior blocks and the cache's walls are plain vertical box faces. On the default wall
# material the ball's friction (0.9) held a glancing 20 m/s strike to a third of its speed: a dead
# stop (PARK-PIPEVAULT, stage-5 pipe vault). A frictionless wall slides a glancing hit along it. Its
# small bounce (0.3, on top of the ball's) lifts a 22 degree strike above the half-speed dead-stop
# line (bounce 0 left it at 36%) while a head-on hit still rebounds under 40% of its speed.
func _wall_material() -> PhysicsMaterial:
	if _wall == null:
		_wall = PhysicsMaterial.new()
		_wall.friction = 0.0
		_wall.bounce = 0.3
	return _wall


func _activate_interior_collision(s: Site) -> void:
	var root := s.get_node("Interior_" + String(s.interior.id))
	for i in s.interior.terrain.size():
		var block: Dictionary = s.interior.terrain[i]
		var body := StaticBody3D.new()
		body.physics_material_override = _wall_material()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(block.size[0], block.size[1], block.size[2])
		shape.shape = box
		body.add_child(shape)
		root.get_child(i).add_child(body)
	s.interior_collision_ready = true


func _build_altar(s: Site) -> void:
	s.cap = AmbushAltar.dress(s)
	if s.cap != null:
		return
	_mesh_cylinder(s, 0.45, 3.2, Vector3.UP * 1.6, _solid(Palette.VERDIGRIS))
	s.cap = _mesh_box(s, Vector3(1.4, 0.6, 1.4), Vector3.UP * 3.5, _solid(Palette.BRASS))
	_mesh_box(s, Vector3(1.42, 0.12, 1.42), Vector3.UP * 3.22, _solid(Palette.SAND))


func _build_cache(s: Site) -> void:
	if not s.drawn:
		var face: Vector2 = s.rule["face"]
		s.rotation.y = atan2(face.x, face.y)
		s.global_position += s.global_basis.z * CACHE_LANE_OFFSET
		s.global_position.y = ctx.terrain.height(s.global_position.x, s.global_position.z)
	var local := Vector3(0.0, 0.0, -PEDESTAL_BACK)
	s.pedestal = s.to_global(local)
	s.pedestal.y = ctx.terrain.height(s.pedestal.x, s.pedestal.z)
	s.fired_glow = StandardMaterial3D.new()
	s.fired_glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	s.fired_glow.albedo_color = Color.BLACK
	s.fired_glow.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	if not _model_cache(s):
		_greybox_cache(s)


# The pocket wears the cracked cache's model over colliders of its own, as built: the shell without
# its roof, stretched to this pocket's sink and depth (its inner back face on the back collider's),
# the fracture panel on the wall's body and the model's pedestal. False, with nothing built, when the
# model is missing.
func _model_cache(s: Site) -> bool:
	var shell := CrackedCache.model_part("CacheShell", s)
	if shell == null:
		return false
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	var rise := tall / (CrackedCache.HEIGHT + CrackedCache.SINK)
	var deep := WALL_DEPTH / (CrackedCache.HALF_D * 2.0 + 0.5)
	var front := CrackedCache.HALF_D + 0.5
	shell.transform = Transform3D(Basis.from_scale(Vector3(1.0, rise, deep)),
		Vector3(0.0, WALL_HEIGHT - CrackedCache.HEIGHT * rise, -front * deep)) * shell.transform
	shell.material_overlay = s.fired_glow
	s.wall = _wall_body(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0))
	var panel := CrackedCache.model_part("CacheWall", s.wall)
	panel.transform = Transform3D(Basis.from_scale(Vector3(1.0, rise, 1.0)) * panel.basis, Vector3.ZERO)
	for side in [-1.0, 1.0]:
		_wall_body(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5))
	_wall_body(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5))
	CrackedCache.model_part("CachePedestal", s).position = s.to_local(s.pedestal)
	return true


func _greybox_cache(s: Site) -> void:
	var concrete := Palette.striped(Palette.VERDIGRIS, Palette.CHARCOAL)
	var tall := WALL_HEIGHT + WALL_SINK
	var mid := tall * 0.5 - WALL_SINK
	s.wall = _mesh_box(s, Vector3(WALL_HALF_W * 2.0, tall, 1.0), Vector3(0.0, mid, 0.0),
		Palette.striped(Palette.SANDSTONE, Palette.VERDIGRIS), true)
	for k in 3:
		var crack := _mesh_box(s.wall, Vector3(WALL_HALF_W * 1.3, 0.2, 1.1), Vector3(0.0, -1.2 + k * 1.6, 0.0),
			_solid(Palette.CHARCOAL))
		crack.rotation.z = 0.5 - k * 0.45
	for side in [-1.0, 1.0]:
		_mesh_box(s, Vector3(1.0, tall, WALL_DEPTH), Vector3(side * (WALL_HALF_W + 0.5), mid, -WALL_DEPTH * 0.5), concrete, true)
	var back := _mesh_box(s, Vector3(WALL_HALF_W * 2.0 + 2.0, tall, 1.0), Vector3(0.0, mid, -WALL_DEPTH - 0.5), concrete, true)
	_mesh_cylinder(s, 0.8, 0.6, s.to_local(s.pedestal) + Vector3.UP * 0.3, _solid(Palette.CHARCOAL))
	# Finish only: the same workshop materials the Spillway props wear; colliders stay as built.
	load("res://src/presentation/spillway_scenery.gd").dress_props(s, s.view)
	# The dressed finish shader carries no emission, so the glow is this site's own additive
	# overlay on its back wall (the model's: its shell), dark until the wall is fired.
	(back.get_child(1) as GeometryInstance3D).material_overlay = s.fired_glow


# A field find (secrets.gd FINDS): the crew board inside, and its family's tell on the face. Its
# codex row is declared here, so the logbook knows it before the first find.
func _dress_find(s: Site, find_id: String) -> void:
	var f: Dictionary = Secrets.FINDS[find_id]
	_hang_board(s, "Find_" + find_id, String(f["name"]), String(f["log"]))
	s.set_meta("find", find_id)
	# A secret shows no beacon column, glyph, ring or word: its tell is what gives it away.
	s.view.finish()
	if ctx.get("codex") != null:
		ctx.codex.declare(f["codex"])
	if f["kind"] == "radio":
		_radio_tell(s)
	else:
		_seep_tell(s)


# The crack's tell: a dark wet streak down the cracked face under a slow glint, and a drip heard
# from Secrets.DRIP_HEAR_M. Both go with the face when it breaks.
func _seep_tell(s: Site) -> void:
	if _find_wet == null:
		_find_wet = _solid(Palette.CHARCOAL.lerp(Palette.VERDIGRIS, 0.35))
	var wet := _find_wet
	for k in FIND_SEEP_STREAKS.size():
		var streak: Vector3 = FIND_SEEP_STREAKS[k]
		var mark: Node3D = FindKit.part("FindSeep", s.wall)
		if mark != null:
			mark.position = Vector3(streak.x, streak.y, 0.52)
			mark.scale = Vector3(streak.z, WALL_HEIGHT * 0.8, 1.0)
		else:
			mark = _mesh_box(s.wall, Vector3(streak.z, WALL_HEIGHT * 0.8, 0.04), Vector3(streak.x, streak.y, 0.52), wet)
		mark.name = "FindSeep%d" % k
	var glint: Node3D = WorldFxAnchor.make("secret")
	glint.name = "FindGlint"
	glint.position = Vector3(0.0, WALL_HEIGHT * 0.6, 1.2)
	s.wall.add_child(glint)
	s.wall.add_child(_find_sound("find_drip", Secrets.DRIP_HEAR_M))


# The timed door: the foreman's board inside and a brass punch clock on the face, stopped short of
# the whistle. It keeps its beacon, since it was earned; its codex row is declared here.
func _dress_door(s: Site) -> void:
	_hang_board(s, "Door_clock", String(Secrets.DOOR["name"]), String(Secrets.DOOR["log"]))
	s.set_meta("door", true)
	if ctx.get("codex") != null:
		ctx.codex.declare(Secrets.DOOR["codex"])
	var clock := Node3D.new()
	clock.name = "DoorClock"
	clock.position = Vector3(0.0, 1.3, 0.52)
	s.wall.add_child(clock)
	_mesh_box(clock, Vector3(DOOR_CLOCK_M, DOOR_CLOCK_M, 0.1), Vector3.ZERO, _solid(Palette.BRASS))
	_mesh_box(clock, Vector3(DOOR_CLOCK_M - 0.3, DOOR_CLOCK_M - 0.3, 0.06), Vector3(0.0, 0.0, 0.06), _solid(Palette.LEDGER))
	var ink := _solid(Palette.CHARCOAL)
	# Hands at five to twelve: the hour hand straight up, the minute hand a little short of it.
	var hour := _mesh_box(clock, Vector3(0.1, DOOR_CLOCK_M * 0.3, 0.04), Vector3(0.0, DOOR_CLOCK_M * 0.15, 0.1), ink)
	hour.name = "HourHand"
	var minute := Node3D.new()
	minute.position = Vector3(0.0, 0.0, 0.12)
	minute.rotation.z = deg_to_rad(30.0)
	clock.add_child(minute)
	_mesh_box(minute, Vector3(0.07, DOOR_CLOCK_M * 0.42, 0.04), Vector3(0.0, DOOR_CLOCK_M * 0.21, 0.0), ink)


# The radio's tell: a short whip aerial over the roof line and the tune through the wall, heard from
# Secrets.RADIO_HEAR_M. The aerial stays; the sound goes with the face.
func _radio_tell(s: Site) -> void:
	# The model's aerial is clamped to the side wall's top; the plain one stood inside the pocket's rim.
	var aerial: Node3D = FindKit.part("FindAerial", s)
	if aerial != null:
		aerial.position = Vector3(WALL_HALF_W + 0.5, WALL_HEIGHT, -1.0)
	else:
		aerial = _mesh_box(s, Vector3(0.12, FIND_AERIAL_M, 0.12), Vector3(WALL_HALF_W - 1.0, WALL_HEIGHT + FIND_AERIAL_M * 0.5, -1.0),
			_solid(Palette.BRASS))
	aerial.name = "FindAerial"
	s.wall.add_child(_find_sound("find_radio", Secrets.RADIO_HEAR_M))


func _find_sound(id: String, reach: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = "FindTell"
	p.stream = SfxBank.loop_stream(id)
	p.bus = "SFX"
	p.volume_db = SfxBank.trim_db(id)
	p.unit_size = reach * 0.25
	p.max_distance = reach
	p.position = Vector3(0.0, 2.0, 0.6)
	p.autoplay = true
	return p


# A first-win room's crew-log line (secrets.gd ROOMS), on a crew board fixed inside its back wall, so it
# reads only once the cracked face is down and the ball is in the room; and its two quiet tells outside.
func _hang_room_log(s: Site, room_id: String) -> void:
	var room: Dictionary = Secrets.ROOMS[room_id]
	_hang_board(s, "Secret_" + room_id, String(room["name"]), String(room["log"]))
	s.set_meta("room", room_id)
	_chalk_tally(s.wall)
	_hang_glove(s)


func _hang_board(s: Site, site_name: String, title: String, text: String) -> void:
	s.name = site_name
	var board_z := -WALL_DEPTH + 0.06
	# The model's frame and plate stand on the back wall: their back face on its origin, the plate's
	# face where the plain plate's was. The plate is painted one flat dark under the log line.
	var frame: Node3D = FindKit.part("FindBoardFrame", s)
	var board: Node3D = FindKit.part("FindBoard", s)
	if frame != null and board != null:
		frame.position = Vector3(0.0, ROOM_LOG_HEIGHT, board_z - 0.04)
		board.position = frame.position
		(board as MeshInstance3D).material_override = _solid(Palette.CHARCOAL)
	else:
		frame = _mesh_box(s, Vector3(ROOM_BOARD_SIZE.x + 0.3, ROOM_BOARD_SIZE.y + 0.3, 0.08),
			Vector3(0.0, ROOM_LOG_HEIGHT, board_z), _solid(Palette.BRASS))
		board = _mesh_box(s, Vector3(ROOM_BOARD_SIZE.x, ROOM_BOARD_SIZE.y, 0.08),
			Vector3(0.0, ROOM_LOG_HEIGHT, board_z + 0.04), _solid(Palette.CHARCOAL))
	frame.name = "RoomBoardFrame"
	board.name = "RoomBoard"
	var label := Label3D.new()
	label.name = "RoomLog"
	label.text = "%s\n%s" % [title.to_upper(), text]
	label.position = Vector3(0.0, ROOM_LOG_HEIGHT, board_z + 0.1)
	label.font_size = 40
	label.outline_size = 4
	label.outline_modulate = Palette.CHARCOAL
	label.width = ROOM_LOG_WIDTH_PX
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Palette.LEDGER
	label.render_priority = 2
	label.outline_render_priority = 1
	s.add_child(label)


# Four strokes and the bar through them, chalked on the cracked face: the crew's count of a shift
# that came back. It goes with the face when the wall breaks.
func _chalk_tally(wall: Node3D) -> void:
	var chalk := _solid(Palette.LEDGER)
	var tally := Node3D.new()
	tally.name = "RoomTally"
	tally.position = ROOM_TALLY_AT
	wall.add_child(tally)
	for k in 4:
		var stroke := _mesh_box(tally, Vector3(ROOM_TALLY_STROKE.x, ROOM_TALLY_STROKE.y, 0.02),
			Vector3(-0.39 + k * 0.26, 0.0, 0.0), chalk)
		stroke.rotation.z = 0.06 * (k % 2 * 2 - 1)
	var bar := _mesh_box(tally, Vector3(ROOM_TALLY_STROKE.x, ROOM_TALLY_STROKE.y * 1.25, 0.02), Vector3(0.0, 0.0, 0.01), chalk)
	bar.rotation.z = -1.05


# One work glove, fingers down on a nail in the cracked face, as the crew hang them at a shift's end: a
# chunky leather palm, four rounded fingers, a thumb and a canvas cuff. It goes with the face.
func _hang_glove(s: Site) -> void:
	var glove := Node3D.new()
	glove.name = "RoomGlove"
	glove.position = ROOM_GLOVE_AT + Vector3(0.0, 0.0, 0.1 * ROOM_GLOVE_SCALE + 0.02)
	# Hung fingers down, then slanted a little across the face.
	glove.basis = (Basis(Vector3.BACK, 0.22) * Basis(Vector3.RIGHT, -PI * 0.5)).scaled(Vector3.ONE * ROOM_GLOVE_SCALE)
	s.wall.add_child(glove)
	var leather := _solid(Palette.COPPER)
	_mesh_box(glove, Vector3(0.62, 0.2, 0.66), Vector3.ZERO, leather)
	for k in 4:
		var finger := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.08
		cap.height = 0.5 - absf(k - 1.5) * 0.08
		finger.mesh = cap
		finger.material_override = leather
		finger.rotation = Vector3(PI * 0.5, (k - 1.5) * 0.12, 0.0)
		finger.position = Vector3(-0.23 + k * 0.155, -0.02, -0.33 - cap.height * 0.4)
		glove.add_child(finger)
	var thumb := MeshInstance3D.new()
	var thumb_cap := CapsuleMesh.new()
	thumb_cap.radius = 0.09
	thumb_cap.height = 0.4
	thumb.mesh = thumb_cap
	thumb.material_override = leather
	thumb.rotation = Vector3(PI * 0.5, 1.0, 0.0)
	thumb.position = Vector3(-0.42, -0.02, -0.02)
	glove.add_child(thumb)
	_mesh_box(glove, Vector3(0.7, 0.24, 0.26), Vector3(0.0, 0.01, 0.42), _solid(Palette.LEDGER))
	_mesh_box(glove, Vector3(0.05, 0.45, 0.05), Vector3(0.0, 0.0, 0.5), _solid(Palette.CHARCOAL))


# A site's parts repeat from site to site and stage to stage, so their flat materials and meshes are
# made once and shared by key (each new one built its shader or arrays on the stage entry frame).
# Nothing writes to a shared one.
static var _parts := {}


static func _solid(color: Color) -> StandardMaterial3D:
	var key := "solid:" + color.to_html()
	if not _parts.has(key):
		_parts[key] = Palette.solid(color)
	return _parts[key]


func _mesh_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, solid := false) -> Node3D:
	var mesh := MeshInstance3D.new()
	var key := "box:%s" % size
	if not _parts.has(key):
		var bm := BoxMesh.new()
		bm.size = size
		_parts[key] = bm
	mesh.mesh = _parts[key]
	mesh.material_override = mat
	if not solid:
		mesh.position = at
		parent.add_child(mesh)
		return mesh
	var body := _wall_body(parent, size, at)
	body.add_child(mesh)
	return body


# A bare wall collider: the box shape is its first child, any drawn face comes after.
func _wall_body(parent: Node3D, size: Vector3, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.physics_material_override = _wall_material()
	body.add_child(shape)
	body.position = at
	parent.add_child(body)
	return body


func _mesh_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var key := "cylinder:%s:%s" % [radius, height]
	if not _parts.has(key):
		var cm := CylinderMesh.new()
		cm.top_radius = radius
		cm.bottom_radius = radius
		cm.height = height
		_parts[key] = cm
	mesh.mesh = _parts[key]
	mesh.material_override = mat
	mesh.position = at
	parent.add_child(mesh)


func _physics_process(delta: float) -> void:
	if not _ahead.is_empty():
		if _ahead.wait > 0:
			_ahead.wait -= 1
			if _ahead.wait == 0:
				_plan_ahead()
		elif _ahead.built.size() < _ahead.plan.sites.size():
			_step_ahead()
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
				"relay":
					_watch_relay(s, delta, ball)
				"surge":
					_watch_surge(s, delta, ball)
				"pack_dead":
					_watch_ambush(s, ball)
				"wall_broken":
					_watch_wall(s, ball)
			_advance_hazards(s, delta, ball)
		_watch_pickup(s, ball)


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# The side site the ball is at, or null: one it has started and has neither finished nor lost,
# while the ball is within AT_HAND_M of it. A surge's water carries the ball down its course, so a
# live surge is at hand wherever the ball is; a bounty is its hauler, once the ball has met it. A
# trade spot is started by standing near it and nothing else, so it is never at hand: its own
# label and offer say what it is. The site that was at hand (`held`) stays so until it is finished
# or the ball is LET_GO_M from it, so the goal never flickers at the edge of a site's reach or
# between two sites. A site is on offer at the site until then (LEGIBILITY.md, "An activity is on
# offer"), and the objective plate names only the one at hand (ui/hud.gd objective_reading).
func at_hand(ball: Vector3, held: Site = null) -> Site:
	if is_instance_valid(held) and _hand_metres(held, ball) <= LET_GO_M:
		return held
	var best: Site = null
	var best_m := AT_HAND_M
	for s in sites:
		var m := _hand_metres(s, ball)
		if m <= best_m:
			best = s
			best_m = m
	return best


# The metres from the ball to a site that can be at hand, INF for one that cannot.
func _hand_metres(s: Site, ball: Vector3) -> float:
	if not is_instance_valid(s) or s.done or s.failed or not s.started or s.has_meta("find") or s.rule.finishes == "trade":
		return INF
	if s.id == "hauler_bounty":
		return _planar(ball, s.brute.global_position) if is_instance_valid(s.brute) and s.brute.bounty_met else INF
	return 0.0 if s.surge_live else _planar(ball, s.global_position)


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
			var size := Vector3(box.size[0], box.size[1], box.size[2])
			if s.drawn:
				centre = s.to_global(Vector3(box.at[0], 0, box.at[1]))
				size = (s.global_basis * size).abs()
				hazard.top_level = true
				hazard.global_transform = Transform3D.IDENTITY
			hazard.setup(centre, size, POCKET_SAFE_M, POCKET_DAMAGE_PER_S, ctx.rng.seed)
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
		# The site's own tune (an arena's), read by id; audio decides whether it has one.
		if presentation.audio.has_method("activity_cue"):
			presentation.audio.activity_cue(s.id, phase)
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
		if ctx.calm or not ctx.can_spawn():
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


# ---- The relay ----

func _build_relay(s: Site) -> void:
	var at := Vector2(s.global_position.x, s.global_position.z)
	s.relay = HoldRelay.new({"relay": at, "ring": at}, s.global_position.y)
	var post := RelayStake.new()
	post.relay = s.relay
	s.add_child(post)
	var spawn: Vector3 = ctx.terrain.spawn_point(ctx.run.stage)
	var toward := Vector2(spawn.x, spawn.z) - at
	toward = toward.normalized() if toward.length() > 0.01 else Vector2(0.0, -1.0)
	var post_at := at + toward * (float(s.rule["ring"]) + float(s.rule["post_out"]))
	post.global_position = ctx.terrain.drop_point(post_at.x, post_at.y, 0.0)
	post.setup(ctx, ctx.root.get_node("Interact"), {"id": "relay_stake_%d_%s" % [ctx.run.stage, s.name]})
	if _site_parent == null:
		ctx.root.get_node("Interact").register(post)
	s.stake_post = post
	s.view.word.text = s.relay.stake_line()


func relay_pack_cost(s: Site) -> float:
	return Cards.cost(s.rule["pack"])


func relay_miniboss_count(s: Site) -> int:
	return int(round(s.relay.miniboss_credit(1.0)))


# The attacker budget the relay stands inside: a start, one more per heft class past the first
# and two per world past the first, capped.
func relay_budget(s: Site) -> int:
	var b: Dictionary = s.rule["budget"]
	var world: int = ctx.stages.world_of(ctx.run.stage)
	return mini(int(b["cap"]), int(b["start"]) + int(b["per_class"]) * maxi(0, ctx.run.heft_class() - 1) + int(b["per_world"]) * maxi(0, world - 1))


func relay_standing(s: Site) -> int:
	return _alive(s.pack) + _alive(s.minibosses)


func _watch_relay(s: Site, delta: float, ball: Vector3) -> void:
	var relay = s.relay
	if not s.started:
		s.view.word.text = relay.stake_line()
		s.relay_cooldown -= delta
		if s.relay_cooldown > 0.0:
			return
		if not ctx.can_spawn():
			return
		if _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > HoldRelay.REACH_UP:
			return
		s.started = true
		relay.begin()
		s.relay_credit = relay.pack_credit(relay_pack_cost(s) * int(s.rule["waves"]))
		s.relay_wave_s = 0.0
		s.relay_gap_s = 0.0
		s.relay_wave_left = 0
		s.minibosses_sent = 0
		s.relay_shown = -1.0
		ctx.events.event_started.emit(s.id)
	var outcome: String = relay.step(delta, ball, ctx.player.state.velocity)
	if relay.progress() - s.relay_shown >= RELAY_PROGRESS_STEP or (relay.progress() >= 1.0 and s.relay_shown < 1.0):
		s.relay_shown = relay.progress()
		ctx.events.event_progress.emit(s.id, s.relay_shown)
	s.view.word.text = relay.status()
	s.pack = s.pack.filter(func(enemy): return is_instance_valid(enemy) and not (enemy.has_method("is_dead") and enemy.is_dead()))
	s.relay_wave_s -= delta
	s.relay_gap_s -= delta
	var cost := relay_pack_cost(s)
	var room := relay_budget(s) - relay_standing(s)
	var due: int = mini(relay_miniboss_count(s), int(floor((relay.progress() - float(s.rule["miniboss_at"])) / float(s.rule["miniboss_step"]))) + 1)
	# A wave is one pack per stack plus one, each pack_gap_s after the last, every wave_s.
	if s.relay_wave_s <= 0.0 and s.relay_wave_left == 0 and s.relay_credit >= cost - 0.0001:
		s.relay_wave_left = relay.stakes + 1
		s.relay_wave_s = float(s.rule["wave_s"])
	if s.relay_gap_s <= 0.0:
		if s.minibosses_sent < due and room >= 1:
			_relay_miniboss(s)
		elif s.relay_wave_left > 0 and s.relay_credit >= cost - 0.0001 and room >= s.rule["pack"].size():
			_relay_pack(s, ball)
			s.relay_credit -= cost
			s.relay_wave_left -= 1
	if outcome == "won":
		s.stake_post.spent = true
		ctx.events.event_ended.emit(s.id, "won")
		ctx.events.relay_stake_paid.emit(int(relay.stakes))
		_finish(s, s.global_position + Vector3(0.0, 0.0, 6.0))
	elif outcome == "lost":
		ctx.events.event_ended.emit(s.id, "lost")
		s.started = false
		s.relay_cooldown = float(s.rule["retry_s"])


func _build_surge(s: Site, spec: Dictionary) -> void:
	var map = ctx.terrain.map()
	if not "park" in map or map.park.is_empty() or String(spec.get("route", "")) == "":
		return
	var course := SurgeCourse.new()
	s.add_child(course)
	var ring := Vector2(s.global_position.x, s.global_position.z)
	course.setup({"ring": ring, "route": spec.route}, ctx.tuning.f("cruise"), map.park, Callable(ctx.terrain, "height"))
	if course.model.route.points.size() < 2:
		course.queue_free()
		return
	s.course = course
	s.surge_row = String(spec.get("row", s.id))


# The sluice's gate landed on the bar (the park row's land fact): every course still waiting goes live.
func _on_world_fact(kind: String, _at: Vector3) -> void:
	if kind != "sluice_landed":
		return
	for s in sites:
		if is_instance_valid(s) and s.course != null and s.started and not s.surge_live and not s.done:
			_surge_begin(s)


func _surge_begin(s: Site) -> void:
	s.surge_live = true
	s.surge_shown = -1.0
	s.course.settle()
	s.course.model.begin()
	ctx.events.event_started.emit(s.id)


func _watch_surge(s: Site, delta: float, ball: Vector3) -> void:
	if s.course == null:
		return
	var model = s.course.model
	if not s.started:
		s.relay_cooldown -= delta
		if s.relay_cooldown > 0.0 or _planar(ball, s.global_position) > float(s.rule["ring"]) or absf(ball.y - s.global_position.y) > RING_HEIGHT:
			return
		s.started = true
		s.surge_wait = float(s.rule["fallback_s"])
		s.view.word.text = SURGE_WORDS.open
		sluice_opened.emit(s.surge_row)
		return
	if not s.surge_live:
		s.surge_wait -= delta
		if s.surge_wait <= 0.0:
			_surge_begin(s)
		return
	var velocity: Vector3 = ctx.player.state.velocity
	var outcome: String = model.step(delta, ball, velocity)
	ctx.player.add_external_accel(EventDirector.never_brake(model.push(ball, velocity), velocity))
	s.course.show_live(outcome == "", fmod(model.elapsed * 2.0, 1.0))
	s.view.word.text = model.status()
	if model.progress() - s.surge_shown >= RELAY_PROGRESS_STEP:
		s.surge_shown = model.progress()
		ctx.events.event_progress.emit(s.id, s.surge_shown)
	if outcome == "won":
		s.surge_live = false
		ctx.events.event_ended.emit(s.id, "won")
		sluice_closed.emit(s.surge_row)
		_finish(s, ball)
		s.view.word.text = SURGE_WORDS.won
		# The course pays into the ball's path: the pickup sits where the ball is, so it is taken on the next frame.
		s.inside_pickup = false
	elif outcome == "lost":
		s.surge_live = false
		s.started = false
		s.relay_cooldown = float(s.rule["retry_s"])
		s.course.show_live(false, 0.0)
		s.view.word.text = SURGE_WORDS.lost
		ctx.events.event_ended.emit(s.id, "lost")
		sluice_closed.emit(s.surge_row)


func _relay_pack(s: Site, ball: Vector3) -> void:
	var kinds: Array = s.rule["pack"]
	var entry: Vector3 = ball - s.global_position
	var first := atan2(entry.z, entry.x) + PI + PACK_TURN
	for i in kinds.size():
		var a := first + TAU * float(i) / kinds.size()
		var spot := s.global_position + Vector3(cos(a), 0.0, sin(a)) * float(s.rule["ring"])
		var enemy = ctx.spawner.spawn_enemy(kinds[i], ctx.terrain.drop_point(spot.x, spot.z, SPAWN_CLEARANCE))
		if enemy != null:
			s.pack.append(enemy)
	s.relay_gap_s = float(s.rule["pack_gap_s"])


# Each miniboss lands in the relay's miniboss zone, seeded per relay and per arrival, so a
# stage retry puts them where they were.
func _relay_miniboss(s: Site) -> void:
	var zone: Array = s.relay.miniboss_zone()
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, "%s_miniboss_%d" % [s.id, s.minibosses_sent])
	var angle := rng.randf() * TAU
	var dist := rng.randf_range(zone[1].x, zone[1].y)
	var at: Vector2 = (zone[0] as Vector2) + Vector2(cos(angle), sin(angle)) * dist
	var enemy = ctx.spawner.spawn_enemy("miniboss", ctx.terrain.drop_point(at.x, at.y, BRUTE_DROP))
	s.minibosses_sent += 1
	if enemy != null:
		s.minibosses.append(enemy)
	s.relay_gap_s = float(s.rule["pack_gap_s"])


# ---- The cache ----

func _watch_wall(s: Site, ball: Vector3) -> void:
	var v: Vector3 = ctx.player.state.velocity
	var toward := -(v.x * s.global_basis.z.x + v.z * s.global_basis.z.z)
	var local := s.to_local(ball)
	var ahead := local.z - 0.5
	if ahead < -1.0 or ahead > WALL_REACH + maxf(0.0, toward) / 30.0 or absf(local.x) > WALL_HALF_W + 1.0 or local.y > WALL_HEIGHT + 2.0:
		return
	var bar: float = ctx.tuning.f("cruise") * RAM_MIN_PER_CRUISE
	if toward >= bar:
		_break_wall(s)
	elif ahead <= WALL_CONTACT and local.y < WALL_HEIGHT:
		_refuse_ram(s, toward)


# A bump under the bar: the roll's refused cue, once a face per gap, in the worlds the rule names.
func _refuse_ram(s: Site, toward: float) -> void:
	var cue: Dictionary = s.rule.get("refused", {})
	if cue.is_empty() or toward < ctx.tuning.f("cruise") * float(cue["floor"]):
		return
	if not int(ctx.stages.world_of(ctx.run.stage)) in cue["worlds"]:
		return
	var frame := Engine.get_physics_frames()
	if s.refused_frame >= 0 and frame - s.refused_frame < int(float(cue["gap_s"]) * Engine.physics_ticks_per_second):
		return
	s.refused_frame = frame
	ctx.events.verb_failed.emit("roll", "under_bar", ctx.player.ball_position())


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
	if s.has_meta("find"):
		_found(s)
	elif s.has_meta("door") and ctx.get("codex") != null:
		ctx.codex.mark_discovered(String(Secrets.DOOR["codex"]["id"]), s.pedestal)
	_finish(s, s.pedestal)


# A field find opened: the OOH burst at the room, and its codex row (the first time, the logbook's
# own burst and the find tune; synergy_discovered carries it to audio.gd).
func _found(s: Site) -> void:
	var f: Dictionary = Secrets.FINDS[String(s.get_meta("find"))]
	var tell: Node = s.wall.get_node_or_null("FindTell")
	if tell != null:
		tell.queue_free()
	WorldFx.fire("secret_found", s.pedestal + Vector3.UP)
	if ctx.get("codex") != null:
		ctx.codex.mark_discovered(String(f["codex"]["id"]), s.pedestal)


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
		elif s.relay != null:
			s.pickup_parts = _roll_many(s.id, table["rarities"], s.relay.rewards())
			s.pickup_part = String(s.pickup_parts[0]) if not s.pickup_parts.is_empty() else ""
		else:
			s.pickup_part = _roll(_luck_id(s), table["rarities"])
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


# A field find, a first-win room, the timed door, a card 2 extra, a sealed room or a drawn pocket rolls on its own
# stream, so it never pays the part the stage's ordinary site of its kind pays; every other site keeps its id, and so
# its rolls.
func _luck_id(s: Site) -> String:
	if s.has_meta("find"):
		return "%s:%s" % [s.id, s.get_meta("find")]
	if s.has_meta("room"):
		return "%s:%s" % [s.id, s.get_meta("room")]
	if s.has_meta("door"):
		return "%s:timed_door" % s.id
	# A card 2 extra and a room a valve or cracked wall seals (contraptions.gd) stand beside the stage's own
	# cracked cache; on its stream they paid the same part.
	if s.has_meta("extra"):
		return "%s:%s" % [s.id, s.get_meta("extra")]
	if s.has_meta("sealed"):
		return "%s:%s" % [s.id, s.get_meta("sealed")]
	# A drawn pocket rolls apart from the stage's authored site of its kind, or the two paid the same part:
	# a drawn vault and the stage's own cache did on 23 of 40 dam runs and 24 of 40 flume runs (2026-11-09).
	if s.drawn:
		return "%s:%s" % [s.id, s.interior.id]
	return s.id


func _roll(id: String, rarities: Array) -> String:
	var picks := _roll_many(id, rarities, 1)
	return String(picks[0]) if not picks.is_empty() else ""


func _roll_many(id: String, rarities: Array, count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = Interact.luck_seed(ctx.rng.seed, ctx.run.run_id, ctx.run.stage, id)
	return Parts.roll(rng, rarities, ctx.run.class_id(), ctx.run.parts, count)


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
		if s.rule.has("bundle") or not s.pickup_parts.is_empty():
			for part in s.pickup_parts:
				ctx.run.add_part(part, String(s.rule.pay.source))
		else:
			ctx.run.add_part(s.pickup_part, String(s.rule["pay"]["source"]))
		_pay_scrap(s, at)
		if s.rule.has("bundle"):
			_cue(s, "pay")
		return
	s.inside_pickup = now
