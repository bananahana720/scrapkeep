extends Node

const EventKinds := preload("res://src/core/event_kinds.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Beacon := preload("res://src/core/beacon.gd")
const Worlds := preload("res://src/core/worlds.gd")
const Secrets := preload("res://src/core/secrets.gd")
const Companion := preload("res://src/core/companion.gd")
const RunState := preload("res://src/core/run_state.gd")
const RunStore := preload("res://src/core/run_store.gd")
const RunTier := preload("res://src/core/run_tier.gd")
const DeathCause := preload("res://src/core/death_cause.gd")
const DeathTips := preload("res://src/core/death_tips.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")
const StartPickCard := preload("res://src/ui/start_pick_card.gd")
const VictoryLap := preload("res://src/world/victory_lap.gd")
const SlagBowl := preload("res://src/boss/arena.gd")

# The run as one state machine: title, class select, then per stage roam, beacon,
# gates and launch, and a summary after stage 3. Death is its own state with a
# one-key way out. Modules read state; only flow changes it, and every change is
# published as flow_changed so music and HUD follow the same beat.

enum { TITLE, CLASS_SELECT, STAGE, BEACON, GATES, LAUNCH, SUMMARY, DEAD, BOSS, VICTORY, LAP }

const NAMES := ["title", "class_select", "stage", "beacon", "gates", "launch", "summary", "dead", "boss", "victory", "lap"]
# The beat between Brindle's defeat and the summary: the ball keeps rolling.
const VICTORY_SECONDS := 2.5
# How long the ball flies after the launch before the next stage takes it; the
# velocity at that moment is what the next stage receives.
const LAUNCH_FLIGHT := 0.6
# The next stage is entered from above, so a launch lands rather than appears.
const ENTRY_LIFT := 14.0
# Stage 1 has no launch behind it; it drops you in rolling at this share of cruise.
const FIRST_DROP_SPEED := 0.8
const RESCUE_DEPTH := 14.0
# A map that declares net_deck_height() catches a fall below it: the ball is set on the
# deck, NET_DECK_SLACK metres past it counts as fallen, and the horizontal speed keeps
# NET_DAMP of itself.
const NET_DECK_SLACK := 2.0
const NET_DAMP := 0.5

var ctx
var start_card
# Where the start card sits: its top edge outside a briefing, and how far down the view its
# free height is shared above it in a briefing (0.5 is the middle; lower keeps it clear of Moss's bubble).
const START_CARD_TOP := 160.0
const BRIEFING_CENTRE := 0.6
var beacon
var state := TITLE
var classes: Array[Resource] = []
# Tests shorten the beacon; anything below zero means use the stage's own seconds.
var beacon_seconds_override := -1.0
# The Warden seals every stage in play. ctx.calm leaves stages unsealed so momentum
# tests measure the seams alone; force_warden seals them anyway for the gate tests.
var force_warden := false
var sealed := false
var warden: Node3D = null
# The park Warden's gate and the yard's arena lock (world/stage_locks.gd), when the world has one.
var gate = null
# Seam for wave 4: the boss flow sets boss_active when it enters its "boss" state and
# boss_plating to the hull's plating. The store-less death screen then offers T, which replays
# stage 3 from the start the run kept.
var boss_active := false
var boss_plating := 120.0
# True from arena entry until the run leaves the fight, so a death there retries the
# arena, not stage 3.
var in_arena := false
# RUN OVER's cause line for this run's death (death_cause.gd), "" before one; and the source of
# the last hit taken, which player_hit publishes just before a killing hit's player_died.
var death_cause := ""
# RUN OVER's "next shift" line for the same death (death_tips.gd), "" when there is none.
var death_tip := ""
# The fight in hand as the build met it: {"who", "punch", "plating"}, read when the Warden engages or
# the boss arena opens. Scrap is armour (run_state.gd), so the killing hit lands on a stripped ball
# whose punch is bare whatever it arrived with; the tip's gap rule reads the arrival, not the death.
var _arrival := {}
var _last_hit_source := ""
var _victory_left := 0.0
# The boss's flourishes (flourish_cues.gd) size the victory window: plan() returns {hold, veil},
# the seconds added to VICTORY_SECONDS and how long the victory card waits over the world.
var victory_plan := Callable()
var victory_veil := 0.0
var _victory_hold := 0.0
# warden_engaged fires once per stage attempt: on the first sealed ring entry or the
# first strike on the Warden, whichever comes first (the music's cue to bring its theme in).
var _engaged := false
# warden_sighted fires once per stage attempt, before warden_engaged, when the ball first comes
# within SIGHT_SHARE times the beacon ring's radius of the sealed Warden (flat distance); an
# engagement that comes first skips it. Intro lines and reveal cards play here, never in the fight.
var _sighted := false
const SIGHT_SHARE := 3.5
# Where this stage's Warden stands; it is immobile, so a warden kill reported far from
# here belongs to some other warden and does not unseal this beacon.
var _warden_at := Vector3.ZERO
# While sealed the shown charge stops short of full, so 1.0 is published only by the
# unseal itself and a module that opens gates on 1.0 cannot run ahead of the kill.
const SEALED_CAP := 0.99
const WARDEN_MATCH := 6.0
var _warned := {}

# Test seam: a boss row per world standing in for Worlds.boss_of.
var boss_row_override := {}
# The scene's own boss module script (game.gd sets it up as ctx.boss), the modules flow
# built for other rows' scripts keyed by path, and the scene module while ctx.boss names
# another.
const SCENE_BOSS := "res://src/boss/boss.gd"
var _row_modules := {}
# Boss module scripts read ahead on a loader thread while the world's last stage is in its beacon,
# gates or launch: path -> null while loading, the Script once loaded, false when it failed. The
# stage exit compiled mind.gd (89 ms on the cloud) and the arena's dress loaded and painted in the
# same frame, the 4080's 254 to 274 ms boss-entry freeze (scrapkeep#241).
var _boss_reads := {}
# By boss script path: whether its warm_arena still has work, the arena's main-thread steps ahead of
# the entry (a step a physics tick until it returns true; false for a script without one).
var _boss_warms := {}
var _home_boss: Node = null
var _world := 0
var _launched := false
var _flight := 0.0
# The launch take (launch_take.gd) rides this launch: it closes during the flight and cuts to the next place under it.
var _seam_take := false
var _last_percent := -1

# Run saves (RS3): game hands flow a RunStore in play. Every zone entrance is written to it,
# a death ends the run (there is no free retry; the earned save, a part, is the only second
# chance and run_state spends it before player_died). A flow with no store (the tests and bots
# that do not opt in) keeps the dead screen and unlimited stage retries.
var store = null
# The cause the last store write was refused with ("" when it saved); the run plays on.
var store_error := ""
# What the title offers (RS6), from saved_run(): a run to continue, or the named cause a
# saved file could not be used ("" when there is simply none).
var continue_ready := false
var saved_run_cause := ""
var saved_run_why := ""
const INVALID_RUN_SENTENCE := "The saved run does not fit this version of the game, so it cannot be continued."
var run_won := false
# The victory lap after the Mind (src/world/victory_lap.gd). Tests that read the old fly-over ending turn it off.
var victory_lap := true
var lap: Node3D = null
var lap_stats := {}
# The entrance doc last written, kept so the earned save's spend rewrites the entrance, never the arena.
var _entrance := {}


func setup(ctx_ref, beacon_ref) -> void:
	ctx = ctx_ref
	beacon = beacon_ref
	classes = ClassDef.all()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	start_card = StartPickCard.new()
	layer.add_child(start_card)
	start_card.pick_requested.connect(take_start_pick)
	start_card.reroll_requested.connect(reroll_start_pick)
	start_card.tier_requested.connect(func(value: int): if not _start_card_covered(): choose_run_tier(value))
	start_card.covered = _start_card_covered
	ctx.events.player_hit.connect(func(_amount: float, source: String): _last_hit_source = source)
	ctx.events.player_died.connect(_on_player_died)
	ctx.run.death_saved.connect(func(_hp: float): _on_death_saved())
	ctx.events.reward_chosen.connect(_on_reward_chosen)
	ctx.events.launched.connect(_on_launched)
	ctx.events.enemy_killed.connect(_on_enemy_killed)
	ctx.events.enemy_struck.connect(_on_enemy_struck)
	ctx.events.boss_defeated.connect(_on_boss_defeated)
	# A stage's piece pays with its activity; it reaches the profile then, so a restart or a quit
	# before the next stage entry cannot lose it.
	ctx.events.activity_done.connect(func(_id: String, _at: Vector3): _persist_companion())


func state_name() -> String:
	return NAMES[state]


# Whether this stage attempt's Warden has been engaged (the ring or a strike).
func engaged() -> bool:
	return _engaged


func in_play() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH or state == BOSS or state == LAP


# The stretch between a stage's Warden falling and the next landing: the gates stand open or the
# ball is in flight. Work held for a quiet moment (a park stage built ahead) runs only then.
func calm() -> bool:
	return state == GATES or state == LAUNCH


# Stage content (director, flood, events, scrap, fabricators, vaults, stage enemies)
# runs only while this is true; it is false in the arena and after the win.
func in_stage() -> bool:
	return state == STAGE or state == BEACON or state == GATES or state == LAUNCH


# The boss module for the current world runs the arena; without one, or on a stage table
# that names no boss, the run ends on the summary after the last stage.
func _boss_module() -> Node:
	if ctx.stages.BOSS == "":
		return null
	return _module_for(ctx.stages.world_of(ctx.run.stage))


# The module a world's boss row names. A row with the scene's own script (or none, as a
# test's stand-in row) is answered by the scene's module, ctx.boss as game.gd or a test
# set it up. Any other script is loaded and set up here once, kept beside flow and shared
# by every row that names it.
func _module_for(world: int) -> Node:
	var path := String(boss_row(world).get("script", SCENE_BOSS))
	if path == SCENE_BOSS:
		return _scene_boss()
	if not _row_modules.has(path):
		_row_modules[path] = _load_module(path)
	return _row_modules[path]


func _scene_boss() -> Node:
	var boss: Node = _home_boss if is_instance_valid(_home_boss) else (ctx.boss if "boss" in ctx else null)
	return boss if boss != null and boss.has_method("enter_arena") else null


# Teardown: a boss script still on its loader thread is collected, and a read-ahead script settles
# what its prepare_arena started (a quit before the boss entry aborted Godot, exit 134, scrapkeep#322).
# Brindle's arena read ahead is held outside the tree; it goes with the flow.
func _exit_tree() -> void:
	for path in _boss_reads:
		var script = _boss_reads[path]
		if script == null and ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			script = ResourceLoader.load_threaded_get(path)
		if script is Script and script.get_script_method_list().any(func(m): return m.name == "settle_arena"):
			script.call("settle_arena")
	SlagBowl.drop_ahead()


func _load_module(path: String) -> Node:
	if not ResourceLoader.exists(path):
		warn_once("boss_script_" + path, "flow: boss script %s does not exist" % path)
		return null
	var script = _boss_reads.get(path)
	if not script is Script:
		script = ResourceLoader.load_threaded_get(path) if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_INVALID_RESOURCE else null
	if not script is Script:
		script = load(path)
	var module: Node = script.new()
	add_child(module)
	module.setup(ctx)
	return module


# On the world's last stage, reads its boss module's script on a loader thread, then lets the
# script prepare its arena (a static prepare_arena) before the stage exit makes the module.
# The scene's own module (Brindle) only warms its Slag Bowl.
func _read_boss_ahead() -> void:
	if ctx.stages.BOSS == "" or not ctx.stages.is_world_last(ctx.run.stage):
		return
	var row: Dictionary = boss_row(ctx.stages.world_of(ctx.run.stage))
	var path := String(row.get("script", SCENE_BOSS))
	if not bool(row.get("built", false)) or _row_modules.has(path):
		return
	if path == SCENE_BOSS:
		# The scene's own module is loaded already; only its Slag Bowl warms ahead.
		if _scene_boss() != null:
			SlagBowl.warm_ahead()
		return
	if not _boss_reads.has(path):
		_boss_reads[path] = null
		if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
			_boss_reads[path] = false
		return
	if _boss_reads[path] != null:
		if _boss_reads[path] is Script:
			if not _boss_warms.has(path):
				_boss_warms[path] = _boss_reads[path].get_script_method_list().any(func(m): return m.name == "warm_arena")
			if _boss_warms[path] and _boss_reads[path].call("warm_arena"):
				_boss_warms[path] = false
		return
	var status := ResourceLoader.load_threaded_get_status(path)
	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	var script = ResourceLoader.load_threaded_get(path) if status == ResourceLoader.THREAD_LOAD_LOADED else null
	_boss_reads[path] = script if script is Script else false
	if script is Script and script.get_script_method_list().any(func(m): return m.name == "prepare_arena"):
		script.call("prepare_arena")


# The boss row that runs at the end of a world. Tests set boss_row_override[world] to stand
# in for a row; the screens and the HUD read this same row.
func boss_row(world: int) -> Dictionary:
	return boss_row_override.get(world, Worlds.boss_of(world))


# The run was won over the boss of its table's final world: the summary opens on the ending
# page. A table that names no boss counts only when its last world is the last of Worlds.ROWS.
func won_final() -> bool:
	return run_won and _final_world_cleared()


func _final_world_cleared() -> bool:
	var world: int = ctx.stages.world_of(ctx.run.stage)
	var boss_table: bool = ctx.stages.BOSS != "" or world == int(Worlds.ROWS.back()["id"])
	return ctx.stages.is_run_last(ctx.run.stage) and bool(boss_row(world).get("built", false)) and boss_table


# The run ends at Meteor Crater only after the Mind: the final world's boss row plays the Mind's music.
func _ending_due() -> bool:
	return _final_world_cleared() and String(boss_row(ctx.stages.world_of(ctx.run.stage)).get("music", "")) == "mind"

# The boss that ends a world, or null when that world has none to run: its row is not
# built, or the scene has no module. A one-world table that names no boss ends with the
# summary as before.
func _world_boss(world: int) -> Node:
	if ctx.stages.BOSS == "":
		return null
	var row: Dictionary = boss_row(world)
	if not bool(row.get("built", false)):
		warn_once("boss_unbuilt_%d" % world, "flow: world %d's boss is not built; skipping to the next world" % world)
		return null
	var module := _module_for(world)
	if module == null and ctx.stages.worlds().size() > 1:
		warn_once("boss_module_%d" % world, "flow: no boss module in the scene for world %d; skipping to the next world" % world)
	return module


# The stage that leads into this world's boss arena: the current world's last stage. A death
# in world one's arena replays stage 3, not the run's last stage.
func final_stage() -> int:
	return ctx.stages.last_of(ctx.stages.world_of(ctx.run.stage))


func stage() -> int:
	return ctx.run.stage


func stage_def() -> Dictionary:
	return ctx.stages.of(ctx.run.stage)


func show_title() -> void:
	_drop_lap()
	ctx.player.set_frozen(true)
	state = TITLE
	ctx.events.flow_changed.emit(NAMES[TITLE])


func open_class_select() -> void:
	if not in_play():
		ctx.player.set_frozen(true)
		_set_state(CLASS_SELECT)


# Space or Enter on the title, or on the summary, goes to class select.
func press_start() -> void:
	if state == TITLE or state == SUMMARY:
		_set_state(CLASS_SELECT)


func choose_class(index: int) -> void:
	if state != CLASS_SELECT or index < 0 or index >= classes.size():
		return
	_begin_run(classes[index])


# The camp's launch gate: a run with the given pilot straight from the title, with no pilot select between
# (game.launch_from_gate; launch_take.gd hides the cut into the dam).
func launch_from_title(chosen: Resource) -> bool:
	if state != TITLE or chosen == null:
		return false
	_begin_run(chosen)
	return true


# The death screen's second key: a fresh run with the same class, straight in.
func new_run() -> void:
	if ctx.run.class_def == null:
		_set_state(CLASS_SELECT)
		return
	_begin_run(ctx.run.class_def)


# The run's briefing (workshop.gd): in a played game the kit pick comes first, then this card on
# the same paused screen, so the pick is made before the ball rolls and is never open in play.
# The workshop holds the pause while the card shows; this function only says when it shows.
func show_start_card() -> void:
	# Under the launch take's panel the card stays hidden; game shows it when the panel has gone.
	var take = ctx.root.get("launch_take")
	var host = ctx.root.get_node_or_null("Workshop")
	var interactive: bool = not ctx.root.bot_driven and not (take != null and take.busy())
	var briefing: bool = host != null and host.armed
	start_card.set_interactive(interactive)
	start_card.set_briefing(briefing)
	start_card.show_picks(ctx.run, ctx.profile)
	var view := get_viewport().get_visible_rect().size
	start_card.position = Vector2((view.x - start_card.size.x) * 0.5,
		maxf(START_CARD_TOP, (view.y - start_card.size.y) * BRIEFING_CENTRE) if briefing else START_CARD_TOP)
	# The kit pick has the screen first; the workshop calls back here when it closes.
	if not interactive or not in_stage() or (host != null and host.kit_pick_due()):
		start_card.hide_card()
	if host != null:
		host.sync_start_card_pointer()
		host.sync_briefing()


# A screen open over the card (the pause menu or the hotwire offer) owns the keys and the clicks:
# the card takes nothing under it and a tier button pressed under it changes nothing. The briefing
# holds both shut; a test game's card, shown without the hold, can still be covered.
func _start_card_covered() -> bool:
	var game = ctx.root
	var menu = game.get_node_or_null("PauseMenu")
	var offer = game.hud.hotwire_screen if game.get("hud") != null else null
	return (menu != null and menu.is_open()) or (offer != null and offer.is_open())


func take_start_pick(index: int) -> bool:
	var taken: bool = in_stage() and not _start_card_covered() and ctx.run.take_start_pick(index)
	show_start_card()
	return taken


func reroll_start_pick() -> bool:
	var rerolled: bool = in_stage() and not _start_card_covered() and ctx.run.reroll_start_pick()
	show_start_card()
	return rerolled


# Only before stage 1's Warden breaks: GATES and LAUNCH come after it (or after a vanished or skipped Warden),
# so a rung taken there would count a win for a dam played below it.
func choose_run_tier(value: int, check_unlock := true) -> bool:
	if not (state == STAGE or state == BEACON) or not ctx.run.select_run_tier(value, ctx.profile, check_unlock):
		return false
	if ctx.build != null:
		ctx.build.recompute()
	if store != null and not _entrance.is_empty():
		if value == 0:
			_entrance.erase("run_tier")
			_entrance.erase("event_core_grants")
		else:
			_entrance["run_tier"] = value
			_entrance["event_core_grants"] = int(_entrance.get("event_core_grants", 0))
		_save(_entrance)
	show_start_card()
	return true


func _begin_run(chosen: Resource) -> void:
	in_arena = false
	boss_active = false
	lap_stats = {}
	_world = 0
	death_cause = ""
	death_tip = ""
	_arrival = {}
	_last_hit_source = ""
	if ctx.run_log != null:
		ctx.run_log.abandon_open_run()
	if ctx.profile != null and ctx.profile.settle_previous_run_tallies() and ctx.profile.can_save and not ctx.profile.save():
		warn_once("profile_tally_save", "flow: earlier run tallies not saved: %s" % ctx.profile.last_error)
	run_won = false
	# The gate launches this pilot next time (game.gate_pilot); saved with the profile's next save.
	if ctx.profile != null:
		ctx.profile.set_last_pilot(chosen.id)
	# A new run, never a Continue: the timed door opens for exactly the run after a fast rout.
	Secrets.roll_door(ctx.profile)
	_save_profile("profile_door_save")
	# A fixed route names the run seed (not the run id, which the tally ledger keys on), so the
	# streams that read the run (pockets, stage modifiers, panels) repeat with the route. Read
	# every run, so turning the slider back to 0 gives the next run its own seed again.
	ctx.run.route_seed = int(ctx.tuning.base("route_seed")) if ctx.tuning != null else 0
	ctx.run.begin(chosen)
	_seed_companion()
	ctx.events.run_started.emit(chosen.id)
	if store != null and not store.keep_prev():
		warn_once("run_prev_backup", "flow: could not keep the old run: %s" % store.last_error)
	var heading: Vector3 = ctx.terrain.entry_heading(1)
	enter_stage(1, heading * ctx.tuning.f("cruise") * FIRST_DROP_SPEED, false)
	show_start_card()


# The saved run the title can offer, or {} with saved_run_cause naming why not: "" for no
# run or an ended one, the store's refusal (newer_schema, quarantine_failed), "unreadable" for
# a file moved aside as .bad, or "invalid_run" for a document this build cannot apply.
# saved_run_why has the detail; continue_refusal() has the player's sentence.
# Every stage table shares user://run.json. A run saved past this table's end (a park run opened
# under the one-stage slice dev table) is refused rather than clamped onto the last map, where
# clearing it would win a run that was never played; the file stays for the table that wrote it.
func _stage_fit_error(doc: Dictionary) -> String:
	if ctx == null or ctx.stages == null:
		return ""
	var stage := int(doc["stage"])
	var count: int = ctx.stages.DEFS.size()
	if stage > count:
		return "stage %d is past this table's %d stages" % [stage, count]
	return ""


func saved_run() -> Dictionary:
	continue_ready = false
	saved_run_cause = ""
	saved_run_why = ""
	if store == null:
		return {}
	var doc: Dictionary = store.load()
	if doc.is_empty():
		if store.refusal == RunStore.REFUSED_CHANGED or (store.refusal == "" and store.last_error != ""):
			saved_run_cause = "unreadable"
		elif store.refusal != RunStore.REFUSED_ENDED:
			saved_run_cause = store.refusal
		saved_run_why = store.last_error
		return {}
	var why := RunState.validate_entrance_doc(doc)
	if why == "" and ClassDef.by_id(String(doc["class_id"])) == null:
		why = "unknown pilot %s" % doc["class_id"]
	if why == "":
		why = _stage_fit_error(doc)
	if why != "":
		saved_run_cause = "invalid_run"
		saved_run_why = why
		return {}
	continue_ready = true
	return doc


# Why the last saved_run() offered no Continue, as one line for the title; "" when Continue
# is offered or there is no run on disk.
func continue_refusal() -> String:
	if continue_ready or store == null:
		return ""
	if saved_run_cause == "invalid_run":
		return INVALID_RUN_SENTENCE
	return store.refusal_sentence()


# Continue (RS6): the saved run from its last zone entrance, free. The world's spent
# retries come back as saved and none is spent; the tree picks are put back on the live
# tree. False when there is nothing valid to continue.
func resume_run() -> bool:
	if in_play():
		return false
	var doc := saved_run()
	if doc.is_empty():
		return false
	var chosen: Resource = ClassDef.by_id(String(doc["class_id"]))
	in_arena = false
	boss_active = false
	run_won = false
	_world = 0
	if ctx.run_log != null:
		ctx.run_log.abandon_open_run()
	ctx.run.begin(chosen)
	ctx.events.run_started.emit(chosen.id)
	ctx.run.from_entrance_doc(doc)
	_keep_found_pieces()
	# The run document's settled ids and the profile's become one set again.
	if ctx.progress != null:
		ctx.progress.reconcile_settled()
	_apply_tree_picks()
	var p: Array = doc["entry_velocity"]
	enter_stage(ctx.run.stage, Vector3(p[0], p[1], p[2]), false)
	show_start_card()
	return true


func _tree():
	return ctx.player.get("tree") if ctx.player != null else null


# Puts the loaded picks on the live tree through tree.pick, so the kit and combat hear
# tree_picked as they did the first time. The depth cap and world-one flag follow world.gd's
# _open_pick for the stage resumed at. A pick owed at the save is offered again.
func _apply_tree_picks() -> void:
	var tree = _tree()
	if tree == null:
		return
	var world: int = ctx.stages.world_of(ctx.run.stage)
	tree.max_depth = UpgradeTree.depth_cap(world) if ctx.tuning.world_one() else UpgradeTree.DEPTHS
	tree.world_one = ctx.tuning.world_one() and world == 1
	var saved: Array[String] = ctx.run.tree_picks.duplicate()
	var allowed: int = ctx.run.tree_allowed
	# A saved late skip goes back first, so the replay and the owed pick see the forced sibling (SG8).
	tree.restore_late_skip(ctx.run.tree_late_skipped)
	tree.allowed = saved.size()
	for id in saved:
		if not tree.pick(id):
			warn_once("resume_pick", "flow: saved tree pick %s does not fit the tree; later picks dropped" % id)
			break
	if allowed > tree.picks.size():
		tree.allowed = allowed - 1
		tree.open_checkpoint()
	else:
		tree.allowed = maxi(allowed, tree.picks.size())


# The earned save fired: the entrance on disk carries the spent flag, so a quit and Continue
# cannot hand the save back.
func _on_death_saved() -> void:
	if store == null or _entrance.is_empty():
		return
	_entrance["death_save_spent"] = true
	_save(_entrance)


# Pieces found carry across runs: a run that starts with no companion takes the profile's.
func _seed_companion() -> void:
	if ctx.profile != null and ctx.run.companion.is_empty():
		ctx.run.companion = profile_companion()


# The profile's companion with pieces this build no longer has dropped (Companion.sanitize): the
# profile only checks it is a dictionary, and a cut piece would stop the companion growing.
func profile_companion() -> Dictionary:
	var fixed: Array = Companion.sanitize(ctx.profile.companion())
	if fixed[1] != "":
		warn_once("profile_companion", "flow: %s" % fixed[1])
	return fixed[0]


# A Continue rolls the run back to its last zone entrance, whose companion can predate a piece
# the profile already holds: the piece stays found, and no persist writes the older companion
# over the profile.
func _keep_found_pieces() -> void:
	if ctx.profile == null:
		return
	for id in profile_companion().get("owned", []):
		if not ctx.run.companion.get("owned", []).has(id):
			ctx.run.companion = Companion.with_piece(ctx.run.companion, String(id))


# Writes the run's companion to the profile when it has one and the profile's differs.
func _persist_companion() -> void:
	_keep_found_pieces()
	# Compared with the profile's companion as this build reads it: a piece this build does not
	# know (a newer build's save) is not a reason to write, so it is never dropped from the file
	# unless the run actually changed the companion.
	if ctx.profile == null or ctx.run.companion.is_empty() or profile_companion() == ctx.run.companion:
		return
	ctx.profile.set_companion(ctx.run.companion)
	if ctx.profile.can_save and not ctx.profile.save():
		warn_once("profile_companion_save", "flow: companion not saved to the profile: %s" % ctx.profile.last_error)


func _save_profile(warn_id: String) -> void:
	if ctx.profile != null and ctx.profile.can_save and not ctx.profile.save():
		warn_once(warn_id, "flow: profile not saved: %s" % ctx.profile.last_error)


func _save(doc: Dictionary) -> void:
	_persist_companion()
	store_error = store.save(doc)
	if store_error != "":
		warn_once("run_save_" + store_error, "flow: run not saved (%s): %s" % [store_error, store.last_error])


# carried is the velocity the ball arrives with: its horizontal speed is kept exactly
# and turned onto the stage's entry heading, its vertical part is kept as it was.
func enter_stage(index: int, carried: Vector3, retry: bool) -> void:
	ctx.run.enter_stage(index)
	var world: int = ctx.stages.world_of(index)
	ctx.run.world = world
	if not retry and world != _world:
		_world = world
		ctx.events.world_entered.emit(world)
	_launched = false
	_flight = 0.0
	_last_percent = -1
	# The checkpoint is taken before stage_entered, so nothing a module grants inside
	# its handler is folded into the stage start. The entry pose is filled in after,
	# because world may swap the geometry inside that handler. The entrance doc is read at
	# the same moment as the checkpoint and gets the same pose.
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	var doc: Dictionary = ctx.run.to_entrance_doc(_tree()) if store != null else {}
	seed_stage_stream(index)
	ctx.events.stage_entered.emit(index, retry)
	var heading: Vector3 = ctx.terrain.entry_heading(index)
	var flat := Vector2(carried.x, carried.z).length()
	var velocity := heading * flat + Vector3.UP * carried.y
	var at: Vector3 = ctx.terrain.spawn_point(index) + Vector3.UP * ENTRY_LIFT
	_place_ball(at, velocity, heading)
	_place_beacon()
	ctx.run.set_snapshot_entry(at, velocity, ctx.camera.yaw)
	if store != null:
		doc["entry_position"] = [at.x, at.y, at.z]
		doc["entry_velocity"] = [velocity.x, velocity.y, velocity.z]
		doc["camera_yaw"] = ctx.camera.yaw
		_entrance = doc
		_save(doc)
	_set_state(STAGE)


# The run's shared stream starts each stage from (session seed, run seed, stage), so a stage's
# layout, event plan and offers are the same on a retry, after quit and Continue, and however the
# stage before it was played; the next run in a session does not continue this one's stream.
# Only the state moves: ctx.rng.seed stays the session (or --route-seed) value that device luck
# and the activity sites read.
func seed_stage_stream(index: int, place: String = "stage") -> void:
	if ctx.rng != null and ctx.run != null:
		# Through a seeded generator: a raw 32-bit hash as the state would make the first draws tiny.
		var mixed := RandomNumberGenerator.new()
		mixed.seed = hash([ctx.rng.seed, run_key(), index, place])
		ctx.rng.state = mixed.state


# The run's part of the stage stream, loot, scrap, offers and the shelf. A headless test that
# names no run seed of its own keeps one stage route whatever the clock-made run id is (the
# streams that read run_seed directly, such as pockets, stage modifiers, panels and device luck,
# still follow it); a run seed set on purpose (bots, QA tools), a fixed route (--route-seed names
# run_seed) and every real run draw their own stages.
func run_key() -> int:
	if ctx.run == null:
		return 0
	if ctx.run.run_seed_override == null and ctx.run.route_seed <= 0 and ctx.root != null and bool(ctx.root.get("test_mode")):
		return 0
	return ctx.run.run_seed


# Back to the stage-start checkpoint: run state, ball position and entry speed. It is
# one synchronous call, so it lands well inside a second.
func retry_stage() -> void:
	if not ctx.run.has_snapshot() or state == TITLE or state == CLASS_SELECT or state == SUMMARY or state == VICTORY or state == LAP:
		return
	if in_arena:
		_retry_arena()
		return
	ctx.run.restore()
	_launched = false
	_flight = 0.0
	_last_percent = -1
	seed_stage_stream(ctx.run.stage)
	ctx.events.stage_entered.emit(ctx.run.stage, true)
	var velocity: Vector3 = ctx.run.snapshot_value("entry_velocity")
	_place_ball(ctx.run.snapshot_value("entry_position"), velocity, velocity)
	ctx.camera.yaw = ctx.run.snapshot_value("camera_yaw")
	_place_beacon()
	_set_state(STAGE)
	show_start_card()


# Replays a stage from the first start the run kept for it, as the boss death screen's
# T does for stage 3. One synchronous call, like a retry.
func replay_stage(index: int) -> bool:
	if not ctx.run.use_stage_start(index):
		return false
	boss_active = false
	in_arena = false
	retry_stage()
	return true


# After stage 3's launch the run enters the arena instead of the summary. The boss
# module places the ball; flow then keeps the arena-entry checkpoint (the stage-3-end
# snapshot), which holding R in play restores (storeless flows only; the death screen has no R).
func enter_boss(carried: Vector3) -> void:
	var boss := _boss_module()
	# Combat's arena ground and the music read ctx.boss, so it names the module whose
	# arena this is; the scene's own module is kept to answer its rows again later.
	if "boss" in ctx and ctx.boss != boss:
		if not is_instance_valid(_home_boss):
			_home_boss = ctx.boss
		ctx.boss = boss
	in_arena = true
	ctx.run.snapshot(Vector3.ZERO, Vector3.ZERO, ctx.camera.yaw)
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena")
	ctx.player.set_frozen(false)
	seed_stage_stream(ctx.run.stage, "arena")
	boss.enter_arena(carried)
	_arrival = _met(_boss_called(), boss_plating_now())
	ctx.run.set_snapshot_entry(ctx.player.ball_position(), ctx.player.state.velocity, ctx.camera.yaw)


# The retry's reason is its own, so anything that keeps per-attempt memory (the codex,
# the music) can tell a fresh arena from a retried one.
func _retry_arena() -> void:
	# The module the fight began with (enter_boss names it ctx.boss); without one the fight
	# cannot be rebuilt, so the run moves on the way a world with no boss does.
	var boss := _boss_module()
	if boss == null and "boss" in ctx and is_instance_valid(ctx.boss) and ctx.boss.has_method("enter_arena"):
		boss = ctx.boss
	ctx.run.restore()
	ctx.player.set_frozen(false)
	if boss == null:
		warn_once("arena_retry", "flow: no boss module to retry the arena against; moving on")
		in_arena = false
		boss_active = false
		_advance_from(ctx.run.stage)
		return
	_set_state(BOSS)
	ctx.events.stage_content_cleared.emit("arena_retry")
	seed_stage_stream(ctx.run.stage, "arena")
	boss.enter_arena(ctx.run.snapshot_value("entry_velocity"))
	_arrival = _met(_boss_called(), boss_plating_now())


# The boss's live read of the fight (CONTRACTS, Flow seams): the plating that stands in
# the way right now and the objective for the current phase. A boss module without
# them falls back to the entry plating and the standing arena objective.
func boss_plating_now() -> float:
	var boss := _boss_module()
	if boss != null and boss.has_method("live_plating"):
		return float(boss.live_plating())
	return boss_plating


func _boss_objective() -> String:
	var boss := _boss_module()
	if boss != null and boss.has_method("objective_text"):
		var text := String(boss.objective_text())
		if text != "":
			return text
	return EventKinds.objective("boss_arena_entered", {"punch": int(punch_now()), "plating": int(boss_plating_now())})


# The arena's own fall rescue. The boss module (E) owns the arena, so it names the
# floor and the landing spot; without them flow uses the arena-entry checkpoint.
# Like the stage rescue it costs nothing and keeps the horizontal speed.
const ARENA_FALL := 40.0


func _rescue_in_arena(ball: Vector3) -> void:
	if not ball.is_finite():
		_rescue_lost_ball()
		return
	var boss := _boss_module()
	var floor_y: float = boss.floor_y() if boss != null and boss.has_method("floor_y") and boss.has_method("rescue_point") else NAN
	var landing: Vector3
	# A module whose arena is gone answers -INF; that is "cannot say", not "no floor", or the
	# ball would fall for good with nothing to catch it.
	if is_finite(floor_y):
		if ball.y >= floor_y:
			return
		landing = boss.rescue_point()
		if not landing.is_finite():
			landing = ctx.run.snapshot_value("entry_position")
	else:
		var entry: Vector3 = ctx.run.snapshot_value("entry_position")
		if ball.y >= entry.y - ARENA_FALL:
			return
		warn_once("arena_rescue", "flow: boss module has no floor_y()/rescue_point(); rescuing to the arena entry")
		landing = entry
	var v: Vector3 = ctx.player.state.velocity
	ctx.player.reset_to(landing, Vector3(v.x, 0.0, v.z))


# The treasure burst for a first discovery in a run: scrap at the spot, which feeds
# heft, so exploring feeds growth (DEMO-SPEC), and the same amount in cogs, one per scrap
# unit as kills and activities pay. The codex calls it once per entry per run.
const BURST_PER_STAGE := 20


func discovery_burst(at: Vector3) -> void:
	ctx.run.add_scrap(BURST_PER_STAGE * ctx.run.stage, at)
	ctx.run.add_cogs(BURST_PER_STAGE * ctx.run.stage)
	ctx.events.cogs_collected.emit(BURST_PER_STAGE * ctx.run.stage, ctx.run.cogs)


func can_replay_final_stage() -> bool:
	return boss_active and ctx.run.has_stage_start(final_stage())


# The live fight's arrival numbers for the death tip: the engaged Warden's or the boss's; empty off one.
func _fight_gap() -> Dictionary:
	if state == BOSS or (state in [STAGE, BEACON] and sealed and _engaged and is_instance_valid(warden)):
		return _arrival
	return {}


func _met(who: String, plating: float) -> Dictionary:
	return {"who": who, "punch": build_punch(), "plating": plating}


# The world's boss as a sentence names it: "Admiral Brindle", "the Waking".
func _boss_called() -> String:
	var called := String(boss_row(ctx.stages.world_of(ctx.run.stage)).get("name", "the boss"))
	return "the " + called.substr(4) if called.begins_with("The ") else called


# The punch the build carries whatever the ball was doing when it was read: punch_now(), or a ram
# at base cruise when that is more, so a ball knocked to a stop does not read as a weak build.
func build_punch() -> float:
	var punch := punch_now()
	if ctx.spawner != null and ctx.spawner.has_method("punch_of") and ctx.spawner.has_method("panel_punch"):
		punch = maxf(punch, ctx.spawner.punch_of("ram", ctx.player.tuning.tier_cruise()) + ctx.spawner.panel_punch("ram", "ram_or_contact"))
	return punch


func _place_ball(at: Vector3, velocity: Vector3, heading: Vector3) -> void:
	ctx.player.set_frozen(false)
	ctx.player.reset_to(at, velocity)
	# The camera is snapped now so the first drawn frame already looks down the run.
	ctx.camera.snap(heading)


func _place_beacon() -> void:
	var def := stage_def()
	var seconds: float = beacon_seconds_override if beacon_seconds_override >= 0.0 else def["beacon_seconds"]
	var radius: float = def["beacon_radius"]
	if ctx.stages == preload("res://src/core/park_defs.gd"):
		const ParkMap := preload("res://src/world/park/park_map.gd")
		var map = ctx.terrain.map()
		if map is ParkMap and map.ok:
			radius = map.reach_m
	beacon.place(ctx.terrain.beacon_point(ctx.run.stage), seconds, radius)
	if is_instance_valid(warden):
		warden.queue_free()
	_engaged = false
	_arrival = {}
	_sighted = false
	sealed = (not ctx.calm) or force_warden
	warden = _spawn_warden() if sealed else null
	_warden_at = warden.global_position if warden != null else Vector3.ZERO
	# No Warden to break (a spawner without the kind): the stage stays on the
	# presence path rather than locking the exit.
	if warden == null:
		sealed = false


func _spawn_warden() -> Node3D:
	if not ctx.can_spawn():
		return null
	var spawned = ctx.spawner.spawn_enemy("warden", ctx.terrain.beacon_point(ctx.run.stage))
	return spawned if spawned is Node3D else null


# Spawner reads, each with the fallback the contract names for a spawner without it.
# A fallback that fires says so once, so a missing seam shows up in the log.
func warden_integrity() -> float:
	if not is_instance_valid(warden):
		return 1.0
	if not ctx.spawner.has_method("integrity_of"):
		warn_once("integrity_of", "flow: spawner has no integrity_of(); the Warden charge reads 0")
		return 1.0
	return ctx.spawner.integrity_of(warden)


func punch_now() -> float:
	if ctx.spawner == null or not ctx.spawner.has_method("punch_now"):
		warn_once("punch_now", "flow: spawner has no punch_now(); punch reads 0")
		return 0.0
	return ctx.spawner.punch_now()


func warden_plating() -> float:
	if is_instance_valid(warden) and ctx.spawner.has_method("plating_of"):
		return ctx.spawner.plating_of(warden)
	if is_instance_valid(warden):
		warn_once("plating_of", "flow: spawner has no plating_of(); showing the stage's warden_plating")
	return stage_def()["warden_plating"]


func warn_once(key: String, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


func physics_step(delta: float) -> void:
	if state == VICTORY:
		_victory_left -= delta
		if _victory_left <= 0.0:
			_advance_from(ctx.run.stage)
		return
	if state == LAP:
		if not is_instance_valid(lap) or lap.step(delta):
			_close_lap()
		return
	if not in_play():
		return
	ctx.run.advance(delta)
	if state == BEACON or state == GATES or state == LAUNCH:
		_read_boss_ahead()
	var ball: Vector3 = ctx.player.ball_position()
	match state:
		STAGE, BEACON:
			if sealed and not is_instance_valid(warden):
				_warden_vanished()
				return
			var done: bool = beacon.advance(delta, ball, sealed)
			if sealed:
				var charge: float = 1.0 - warden_integrity()
				beacon.show_progress(beacon.duration * minf(SEALED_CAP, charge))
				if beacon.phase != Beacon.IDLE:
					_engage()
				else:
					_read_sighting(ball)
			if state == STAGE and beacon.phase != Beacon.IDLE:
				_set_state(BEACON)
			var percent := int(beacon.fraction() * 100.0)
			if percent != _last_percent and not done:
				_last_percent = percent
				ctx.events.beacon_charge_changed.emit(beacon.fraction())
			if done:
				_set_state(GATES)
				ctx.events.beacon_charge_changed.emit(1.0)
		LAUNCH:
			if _launched:
				_flight += delta
				if _flight >= LAUNCH_FLIGHT and not _seam_take:
					_finish_stage()
		BOSS:
			# The arena is the boss module's geometry, not the world's terrain.
			_rescue_in_arena(ball)
			return
	_rescue_if_fallen(ball)


func _finish_stage() -> void:
	var cleared: int = ctx.run.stage
	ctx.events.stage_cleared.emit(cleared)
	if ctx.stages.is_world_last(cleared) and _world_boss(ctx.stages.world_of(cleared)) != null:
		enter_boss(ctx.player.state.velocity)
		return
	_advance_from(cleared)


# The next stage after a cleared one, which is the next world's first when the cleared
# stage closed a world; the run ends won after the last world.
func _advance_from(cleared: int) -> void:
	if ctx.stages.is_run_last(cleared):
		_end_run_won()
		return
	enter_stage(cleared + 1, ctx.player.state.velocity, false)


func _on_boss_defeated() -> void:
	if state != BOSS:
		return
	boss_active = false
	in_arena = false
	_victory_left = VICTORY_SECONDS
	_victory_hold = 0.0
	victory_veil = 0.0
	if victory_plan.is_valid():
		var plan: Dictionary = victory_plan.call()
		_victory_hold = maxf(0.0, float(plan.get("hold", 0.0)))
		_victory_left += _victory_hold
		victory_veil = maxf(0.0, float(plan.get("veil", 0.0)))
	# A fast rout opens the timed door for the next run (secrets.gd DOOR).
	var boss := String(Worlds.row(ctx.stages.world_of(ctx.run.stage)).get("boss", ""))
	if Secrets.note_rout(ctx.profile, boss, ctx.run.run_time):
		_save_profile("profile_door_save")
	_set_state(VICTORY)


# A skipped flourish gives back the hold it was paying for, and the card shows at once.
func cut_victory(seconds: float) -> void:
	if state != VICTORY:
		return
	var back := clampf(seconds, 0.0, _victory_hold)
	_victory_hold -= back
	_victory_left = maxf(0.0, _victory_left - back)
	victory_veil = 0.0


func _end_run_won() -> void:
	if victory_lap and _ending_due() and _begin_ending():
		return
	_end_run(true)
	# run_ended's synchronous listeners finish the profile, achievements and log first.
	if won_final() and _ending_due():
		_roll_ending()


func _roll_ending() -> void:
	var screens = _screens()
	if screens != null and screens.has_method("start_ending_sequence"):
		screens.start_ending_sequence()


func _screens():
	return ctx.root.get("screens") if ctx.root != null else null


# The Q16 ending (Andrew, 2026-10-17: "60 s free roll"): the crew's fly-over, then the victory lap in Meteor Crater,
# then the credits over the bowl. The win is recorded here, exactly as _end_run records it, so a quit at any point of
# the ending keeps it and leaves no Continue. The arena and every fight group go now, so nothing that can hurt the
# ball reaches the crater, and the bowl is placed now so a bowl that cannot place falls back to the old ending before
# anything is promised. Flow holds the victory state, with the ball frozen, until the fly-over hands over (start_lap).
func _begin_ending() -> bool:
	var boss := _boss_module()
	if boss != null and boss.has_method("exit_arena"):
		boss.exit_arena()
	boss_active = false
	in_arena = false
	ctx.events.stage_content_cleared.emit("lap")
	lap = VictoryLap.new()
	ctx.root.add_child(lap)
	if not lap.build(ctx):
		warn_once("victory_lap", "flow: the crater did not place; the run ends without the victory lap")
		_drop_lap()
		return false
	lap_stats = {}
	_victory_left = INF
	_record_end(true)
	ctx.events.run_ended.emit(true)
	var screens = _screens()
	if screens != null and screens.has_method("start_ending_prelude"):
		screens.start_ending_prelude()
	else:
		start_lap()
	return true


# The fly-over has finished or been skipped: the ball drops over the crater's rim and the lap's clock starts.
func start_lap() -> void:
	if state != VICTORY or not is_instance_valid(lap):
		return
	var hud = ctx.root.get("hud") if ctx.root != null else null
	if hud != null and hud.has_method("clear_toasts"):
		hud.clear_toasts()
	lap.begin(ctx.player.state.velocity)
	_set_state(LAP)


# The lap's clock ran out: the summary waits beneath and the credits roll over the bowl.
func _close_lap() -> void:
	if is_instance_valid(lap):
		lap_stats = lap.stats()
	ctx.player.set_frozen(true)
	_set_state(SUMMARY)
	_roll_ending()


func _drop_lap() -> void:
	if is_instance_valid(lap):
		lap.get_parent().remove_child(lap)
		lap.queue_free()
	lap = null


# The run is over for good, won or lost: the saved run becomes a tombstone so no Continue
# can bring it back.
func _end_run(won: bool) -> void:
	_record_end(won)
	_set_state(SUMMARY)
	ctx.events.run_ended.emit(won)


func _record_end(won: bool) -> void:
	ctx.run.over = true
	run_won = won
	# A won run on the HARD ladder's best rung so far opens the next one (run_tier.gd BEST_STAT). Every win
	# ends here, the victory lap's (_begin_ending) included.
	if won and RunTier.note_win(ctx.profile, ctx.run.run_tier):
		_save_profile("profile_ladder_save")
	ctx.player.set_frozen(true)
	_entrance = {}
	_persist_companion()
	# A save this build never owned (store refused it: newer_schema) is not ours to delete.
	if store != null and store.refusal == "" and not store.clear():
		store_error = "clear_failed"
		push_warning("flow: run save not cleared: %s" % store.last_error)


func _on_reward_chosen(_part_id: String) -> void:
	if state == GATES:
		_set_state(LAUNCH)


# World may launch from inside its own reward_chosen handler, before flow has heard
# reward_chosen, so a launch during GATES counts as the gate being taken too.
func _on_launched(_velocity: Vector3) -> void:
	if state == GATES or state == LAUNCH:
		_set_state(LAUNCH)
		_launched = true
		_flight = 0.0
		_seam_take = _play_seam_take()


# A played game's stage launch runs under the comic swipe: the panel closes while the ball flies, the cut to the next
# place waits for the flight's end behind the full cover, and the reveal opens once its ground is drawn. Bots, tests and
# headless runs cut at once as before. Returns true when the take plays.
func _play_seam_take() -> bool:
	var root = ctx.root
	if root == null or not root.has_method("play_launch_take") or ctx.stages.is_run_last(ctx.run.stage):
		return false
	return root.play_launch_take(_cut_under_cover, _flight_over, _next_drawn)


func _flight_over() -> bool:
	return _flight >= LAUNCH_FLIGHT or not (state == LAUNCH and _launched)


# A run that ended or restarted in the flight leaves the cover with nothing to cut to.
func _cut_under_cover() -> void:
	_seam_take = false
	if state == LAUNCH and _launched:
		_finish_stage()


func _next_drawn() -> bool:
	return not in_play() or ctx.terrain.is_ready(ctx.run.stage)


# Breaking the Warden opens the gates wherever the ball is: the stage's MUST is done
# and nothing asks you to roll back to the ring.
func _on_enemy_killed(kind: String, at: Vector3, _scrap_value: int) -> void:
	if kind != "warden" or not sealed or not (state == STAGE or state == BEACON):
		return
	if not _is_this_warden(at):
		return
	_unseal()


# The kill is this stage's Warden when the spawner reads it as broken, or, for a
# spawner that cannot say, when it died where this Warden stands.
func _is_this_warden(at: Vector3) -> bool:
	if is_instance_valid(warden) and ctx.spawner.has_method("integrity_of"):
		return ctx.spawner.integrity_of(warden) <= 0.0
	return at.distance_to(_warden_at) <= WARDEN_MATCH


# A Warden that left the tree with no kill recorded is a seam fault, not the player's:
# the stage opens the same way a break does, and the run log keeps a note of it.
func _warden_vanished() -> void:
	warn_once("warden_vanished", "flow: the Warden left without a recorded kill; unsealing stage %d" % ctx.run.stage)
	ctx.run.note_anomaly("warden_vanished")
	_unseal()


func _unseal() -> void:
	sealed = false
	warden = null
	beacon.open()
	ctx.events.beacon_unsealed.emit(ctx.run.stage)
	_set_state(GATES)
	ctx.events.beacon_charge_changed.emit(1.0)


func _on_enemy_struck(enemy: Node3D, _kind: String, _force: float) -> void:
	if sealed and enemy == warden:
		_engage()


func _read_sighting(ball: Vector3) -> void:
	if _sighted or _engaged:
		return
	var flat := Vector2(ball.x - _warden_at.x, ball.z - _warden_at.z)
	if flat.length() <= beacon.radius * SIGHT_SHARE:
		_sighted = true
		ctx.events.warden_sighted.emit(ctx.run.stage)


func _engage() -> void:
	if _engaged:
		return
	_engaged = true
	_arrival = _met("the Warden", warden_plating()) if is_instance_valid(warden) else {}
	_sighted = true
	if ctx.run.run_tier_open():
		ctx.run.close_run_tier()
		show_start_card()
	ctx.events.warden_engaged.emit(ctx.run.stage)


# The attack combat filed for this tick's hit from the same source (combat.gd last_player_hit).
func _landed_attack() -> String:
	var last = ctx.spawner.get("last_player_hit") if ctx.spawner != null else null
	if not (last is Dictionary) or int(last.get("frame", -1)) != Engine.get_physics_frames() or String(last.get("source", "")) != _last_hit_source:
		return ""
	return String(last.get("attack", ""))


func _on_player_died() -> void:
	if not in_play() or state == LAP:
		return
	death_cause = DeathCause.line(_last_hit_source, _landed_attack(), DeathCause.phase_note(_boss_module()) if state == BOSS else "")
	death_tip = DeathTips.line(_last_hit_source, _landed_attack(), _fight_gap())
	ctx.player.set_frozen(true)
	if store != null:
		_end_run(false)
		return
	_set_state(DEAD)


# A fall through the geometry is the map's fault, not the player's, so the rescue
# costs nothing and keeps the horizontal speed. A map with a net deck catches the fall
# on the deck at damped speed instead, before the ground rule is asked.
func _rescue_if_fallen(ball: Vector3) -> void:
	if not ball.is_finite():
		_rescue_lost_ball()
		return
	var v: Vector3 = ctx.player.state.velocity
	var map = ctx.terrain.map()
	if map.has_method("net_deck_height"):
		var deck: float = map.net_deck_height()
		if ball.y < deck - NET_DECK_SLACK:
			var radius: float = preload("res://src/movement/tuning.gd").RADIUS
			ctx.player.reset_to(Vector3(ball.x, deck + radius, ball.z), Vector3(v.x, 0.0, v.z) * NET_DAMP)
			return
	# Measured from the floor, not height(): an overlay is a sheet, not a fill, so a ball under
	# one (the flume's trestle ramp) rolls on the floor beneath it and has not fallen.
	if ctx.terrain.contains(ball) and ball.y > ctx.terrain.floor_height(ball.x, ball.z) - RESCUE_DEPTH:
		return
	ctx.player.reset_to(ctx.terrain.rescue_point(ball), Vector3(v.x, 0.0, v.z))


# A ball whose position went non-finite fails every bounds test (contains() and clampf() both
# carry NaN through), so it goes back to the stage's entry checkpoint at rest.
func _rescue_lost_ball() -> void:
	var at = ctx.run.snapshot_value("entry_position") if ctx.run != null else null
	if not (at is Vector3) or not (at as Vector3).is_finite():
		at = ctx.terrain.spawn_point(ctx.run.stage) if ctx.terrain != null and ctx.run != null else Vector3.ZERO
	warn_once("ball_not_finite", "flow: the ball's position is not finite; returned to the stage entry")
	ctx.player.reset_to(at, Vector3.ZERO)


func objective_text() -> String:
	var ball: Vector3 = ctx.player.ball_position()
	var to_beacon: float = Vector2(ball.x - beacon.global_position.x, ball.z - beacon.global_position.z).length()
	var percent := int(beacon.fraction() * 100.0)
	var fight := {
		"distance": int(to_beacon),
		"percent": percent,
		"punch": int(punch_now()),
		"plating": int(warden_plating()),
		"hint": stage_def()["warden_hint"],
	}
	match state:
		STAGE, BEACON:
			if sealed:
				var held: String = gate.objective() if gate != null else ""
				if held != "":
					return held
				return EventKinds.objective("stage_entered" if state == STAGE else "beacon_charge_changed", fight)
			var text := EventKinds.objective("beacon_unsealed", fight)
			if not beacon.in_ring(ball):
				text += "  The ring is %d m away." % int(maxf(0.0, to_beacon - beacon.radius))
			return text
		GATES:
			return EventKinds.objective("reward_offered")
		LAUNCH:
			return EventKinds.objective("launched" if _launched else "reward_chosen")
		BOSS:
			return _boss_objective()
	return ""


func _set_state(next: int) -> void:
	if start_card != null and (next not in [STAGE, BEACON] or ctx.run.stage != 1):
		start_card.hide_card()
	if state == next:
		return
	if next != LAP:
		_drop_lap()
	state = next
	ctx.events.flow_changed.emit(NAMES[next])
