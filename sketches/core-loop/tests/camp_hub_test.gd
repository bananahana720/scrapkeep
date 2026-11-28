extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const CampHub := preload("res://src/world/camp_hub.gd")
const CampLayout := preload("res://src/world/camp_layout.gd")
const Push := preload("res://tests/support/push.gd")
const CampSkee := preload("res://src/world/camp_skee.gd")
const CampTrial := preload("res://src/world/camp_trial.gd")
const CampSandbox := preload("res://src/world/camp_sandbox.gd")
const MetRecord := preload("res://src/core/met_record.gd")
const T := preload("res://tests/support/t.gd")

# The walkable camp (camp_hub.gd) on the real title:
#   - K enters the walk: the hub is built from the camp GLBs, the ball is unfrozen at the spawn, the title picture is
#     hidden and the flow stays on the title;
#   - outside a zone a station key does nothing (S and A are also the roll's keys);
#   - each station's zone shows a prompt card; its key opens the station's page; closing the page returns to the walk;
#   - the pet hops and chirps when the ball rolls into its pen;
#   - a scripted roll from the spawn moves more than 20 m and stays on the plaza;
#   - K leaves to the title with the ball frozen and the hub hidden;
#   - Space in the gate's zone launches the last-flown pilot straight into stage 1 (no pilot select).

const STATIONS := [
	{"id": "lockers", "key": KEY_C, "label": "Customize"},
	{"id": "moss", "key": KEY_M, "label": "Companion"},
	{"id": "jukebox", "key": KEY_J, "label": "Jukebox"},
	{"id": "settings", "key": KEY_S, "label": "Settings"},
	{"id": "radio", "key": KEY_R, "label": "Radio"},
	{"id": "achieve", "key": KEY_A, "label": "Trophy wall"},
]

var _t := T.new("camp_hub_test")
var _game
var _hub
var _screens


func _initialize() -> void:
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _physics(n: int) -> void:
	for i in n:
		await physics_frame


# The ball set down inside a station's zone, 2 m toward the plaza from its centre so it clears the piece's solid.
func _put_in(id: String) -> void:
	var centre: Vector3 = _hub.zone_position(id)
	var toward: Vector3 = _hub.root.global_position - centre
	toward.y = 0.0
	var at: Vector3 = centre + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	await _physics(4)


func _open(id: String) -> bool:
	match id:
		"lockers":
			return _screens.camp_page().customize.visible
		"moss":
			return _game.get_node("Workshop").companion_panel.is_open()
		"jukebox":
			return _screens.jukebox_open()
		"settings":
			return _screens.settings_open()
		"radio":
			return _screens.radio_open()
		"achieve":
			return _screens.achievements_open()
	return false


func _close(id: String) -> void:
	match id:
		"lockers":
			_screens.camp_page().customize.close()
		"moss":
			_game.get_node("Workshop").companion_panel.close()
		"jukebox":
			_game._screen_key(KEY_J)
		"settings":
			_screens.toggle_settings()
		"radio":
			_game._screen_key(KEY_R)
		"achieve":
			_screens.toggle_achievements()
	await _frames(2)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	var source := Intent.Scripted.new()
	_game.player.source = source
	_screens = _game.screens
	_hub = _game.camp_hub
	var flow = _game.flow
	var player = _game.player
	_t.eq("the game starts on the title", flow.state_name(), "title")
	_t.check("the hub is not built before the first walk", not _hub.built, "")
	_t.check("the title ball is frozen", player.frozen(), "")
	# A run marks kinds as met before the camp is ever opened (the listener is wired at setup, once).
	_t.check("nothing is met before any spawn", not MetRecord.met_of(_game, CampSandbox.kinds()).has("chaser"), str(MetRecord.met_of(_game, CampSandbox.kinds())))
	# Spawners add a body to the tree before announcing it; so do these stand-ins.
	var ghost := Node3D.new()
	_game.add_child(ghost)
	_game.events.enemy_spawned.emit(ghost, "chaser")
	_t.check("an enemy_spawned before any camp visit marks it met", MetRecord.met_of(_game, CampSandbox.kinds()).has("chaser") and not _hub.built, str(MetRecord.met_of(_game, CampSandbox.kinds())))
	MetRecord.watch(_game)
	var called := Node3D.new()
	called.set_meta("sandbox_slot", 0)
	_game.add_child(called)
	_game.events.enemy_spawned.emit(called, "lobber")
	_t.check("watch is idempotent and a sandbox call marks nothing", not MetRecord.met_of(_game, CampSandbox.kinds()).has("lobber"), str(MetRecord.met_of(_game, CampSandbox.kinds())))
	ghost.free()
	called.free()

	var environments := _count_environments(_game)
	# K enters the walk.
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("K builds the hub", _hub.built and _hub.root != null, "")
	_t.check("the walk is on and the camp is open", _screens.walking() and _screens.camp_open() and _hub.walking, "")
	var line_card: Node = _hub.get_node_or_null("CampLineLayer/CampLine")
	_t.check("a dry line card shows on entering the walk", line_card != null and line_card.get_child_count() > 0
		and line_card.get_child(0).text.length() > 10 and line_card.mouse_filter == Control.MOUSE_FILTER_IGNORE, str(line_card))
	_t.eq("the flow stays on the title", flow.state_name(), "title")
	_t.check("the run is not in play", not flow.in_play(), "")
	_t.check("the ball is unfrozen", not player.frozen(), "")
	_t.check("the ball wakes near the spawn", player.ball_position().distance_to(_hub.spawn_position()) < 6.0,
		str(player.ball_position()))
	_t.check("the hub stands clear of every stage", _hub.root.global_position.length() > 2000.0, str(_hub.root.global_position))
	var title_stage = _game.presentation.title_stage
	_t.check("the title picture stands down", not title_stage._layer.visible and not title_stage.active, "")
	_t.check("the walk page is a strip, not the veil", _screens._camp.visible and not _screens._veil.visible and not _screens._actions.visible, "")
	_t.check("the hub root shows", _hub.root.visible, "")
	_t.eq("the hub adds no WorldEnvironment", _count_environments(_game), environments)
	var pieces := ["camp_plaza", "camp_launch_gate", "camp_lockers", "camp_moss_stall", "camp_trophy_wall", "camp_settings_console",
		"camp_skee_lane", "camp_pet_pen", "camp_pet", "camp_trial_track", "camp_trial_arch", "camp_sandbox_yard", "camp_call_box",
		"camp_shortcut", "camp_lamp_post", "camp_fence", "moss_jukebox", "moss_hover_barge", "cottonwood"]
	var missing := []
	for id in pieces:
		if _hub.piece(id) == null:
			missing.append(id)
	_t.check("every kit piece is placed", missing.is_empty(), str(missing))
	_t.check("each solid piece has a world collider", _hub.piece("camp_plaza").get_node("Collider").get_child_count() > 0
		and _hub.piece("camp_lockers").get_node("Collider").get_child_count() > 0, "")
	_t.check("the lights stay inside the cap", _hub.light_count > 0 and _hub.light_count <= CampHub.MAX_LIGHTS, str(_hub.light_count))
	# The pen's toys stand their lowest drawn point on the plaza's top (camp_hub.gd _seat; clip audit, 30 Oct: a fixed
	# 0.3 m floated the wrench and sank the tire in the plaza's lip).
	for toy: String in ["camp_toy_ball", "camp_toy_wrench", "camp_toy_tire"]:
		var holder: Node3D = _hub.piece(toy)
		var foot := INF
		for view: MeshInstance3D in holder.find_children("*", "MeshInstance3D", true, false):
			foot = minf(foot, (holder.transform * view.transform * view.mesh.get_aabb()).position.y)
		var top: float = _hub.plaza_top(Vector2(holder.position.x, holder.position.z))
		_t.near("%s stands on the plaza's top" % toy, foot, top, 0.01)
	_t.check("the settings console has a socket", _hub.has_socket("camp_settings_console", "interact"), "")
	# Every socket a camp feature reads: socket() answers IDENTITY for a missing one, which puts the
	# station or sensor at the world origin, about 4 km from the camp, without an error.
	var wanted := {"camp_skee_lane": ["interact", "score", "start", "return_exit"],
		"camp_trial_track": ["start"], "camp_trial_arch": ["timer", "light_bronze", "light_silver", "light_gold"],
		"camp_sandbox_yard": ["entry", "enemy_spawn_0"], "camp_call_box": ["interact"]}
	for cup in CampSkee.CUPS:
		wanted["camp_skee_lane"].append(cup)
	for i in CampTrial.CHECKPOINTS:
		wanted["camp_trial_track"].append("checkpoint_%d" % i)
	for i in 32:
		wanted["camp_trial_track"].append("ghost_%02d" % i)
	for i in CampSandbox.CAP:
		wanted["camp_sandbox_yard"].append("enemy_spawn_%d" % i)
	for stem in wanted:
		_t.check("camp piece %s is placed" % stem, _hub.piece(stem) != null)
		for socket_name in wanted[stem]:
			_t.check("camp piece %s has socket %s" % [stem, socket_name], _hub.has_socket(stem, socket_name))

	# Station keys do nothing outside a zone.
	_t.check("S outside a zone is not a station key", not _game._screen_key(KEY_S) and not _screens.settings_open(), "")
	_t.check("Space outside the gate is the jump", not _game._screen_key(KEY_SPACE) and flow.state_name() == "title", "")

	# Every station.
	var profile = _game.ctx.profile
	profile.set_companion(Companion.with_piece({}, "escape_vent"))
	for row in STATIONS:
		var id: String = row["id"]
		await _put_in(id)
		_t.check("%s: the ball is in the zone" % id, _hub.inside(id), str(_hub.inside_ids()))
		_t.check("%s: the prompt shows" % id, _hub.prompts_shown() and _hub.card_for(id) != null
			and _hub.card_for(id).text == row["label"], str(_hub.prompt_words()))
		var before: Vector3 = player.ball_position()
		_game._screen_key(row["key"])
		await _frames(2)
		_t.check("%s: its key opens the page" % id, _open(id), "")
		_t.check("%s: the walk is held under the page" % id, _screens.walking() and not _screens.walk_live()
			and not _hub.prompts_shown(), "")
		_t.eq("%s: the flow stays on the title" % id, flow.state_name(), "title")
		await _close(id)
		_t.check("%s: closing returns to the walk" % id, _screens.walk_live() and _hub.walking and not _open(id)
			and not _screens._actions.visible, "")
		_t.check("%s: the ball stays where it was" % id, player.ball_position().distance_to(before) < 4.0,
			"%s -> %s" % [before, player.ball_position()])
	# A card's click presses the same key.
	await _put_in("settings")
	_hub.card_for("settings").pressed.emit()
	await _frames(2)
	_t.check("a card's click opens its page", _screens.settings_open(), "")
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Escape on a page returns to the walk, not the title", not _screens.settings_open() and _screens.walk_live(), "")
	# Pad A presses the station the ball is in.
	_t.eq("pad A in a zone is that station's key", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_S)
	_game._screen_key(_game.pad_screen_key(_pad(JOY_BUTTON_A)))
	await _frames(2)
	_t.check("pad A opens the settings console page", _screens.settings_open(), "")
	Push.pad(root, JOY_BUTTON_B)
	await _frames(2)
	_t.check("pad B on a page returns to the walk", not _screens.settings_open() and _screens.walk_live(), "")
	await _put_in("achieve")
	_t.eq("pad A in the trophy wall's zone is A", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_A)
	_game._screen_key(KEY_A)
	await _frames(2)
	_t.check("A opens the trophy wall over the walk", _screens.achievements_open() and _screens.walking(), "")
	_t.eq("the trophy wall's Back shows Esc over the walk", _screens.button_for("back").key, "key_esc")
	_screens.button_for("back").pressed.emit()
	await _frames(2)
	_t.check("the trophy wall's Back returns to the walk", not _screens.achievements_open() and _screens.walk_live(), "")
	if _screens.achievements_open():
		_screens.toggle_achievements()
		await _frames(2)

	# The pet.
	await _put_in("settings")
	var pet_before: int = _hub.pet_reactions
	var pet: Node3D = _hub.piece("camp_pet")
	var pet_at: Vector3 = pet.position
	var chirps: int = _chirps()
	await _put_in("pet")
	_t.check("the ball is in the pen", _hub.inside("pet"), str(_hub.inside_ids()))
	await _frames(40)
	_t.eq("the pet reacts once", _hub.pet_reactions, pet_before + 1)
	_t.check("the pet moved toward the ball", pet.position.distance_to(pet_at) > 0.1 or absf(pet.rotation.y) > 0.01, "")
	_t.check("the pet chirped", _chirps() > chirps, "")
	_t.check("the pen has no prompt", not _hub.prompts_shown(), str(_hub.prompt_words()))

	# The feature stations the hub attaches: skee lane, time trial, sandbox call box and the scrapbook.
	var skee = _hub.root.get_node("CampSkee")
	var trial = _hub.root.get_node("CampTrial")
	var sandbox = _hub.root.get_node("CampSandbox")
	await _put_in("camp_skee")
	_t.check("skee: the prompt shows", _hub.card_for("camp_skee") != null and _hub.card_for("camp_skee").text.begins_with("Skee"), str(_hub.prompt_words()))
	_game._screen_key(KEY_E)
	await _frames(2)
	_t.check("skee: E starts the game", skee.phase != skee.Phase.IDLE and _screens.walk_live(), str(skee.phase))
	skee.end_game(true)
	await _put_in("camp_trial")
	_t.check("trial: the prompt shows", _hub.card_for("camp_trial") != null and _hub.card_for("camp_trial").text.begins_with("Time trial"), str(_hub.prompt_words()))
	_game._screen_key(KEY_E)
	await _frames(2)
	_t.check("trial: E arms the clock", trial.run.state == trial.State.ARMED, str(trial.run.state))
	trial.abort()
	_hub.set_clock("Lap  0:01.00")
	_t.check("the walk HUD shows a lap line, top centre", _hub.clock_text() == "Lap  0:01.00" and _hub._clock.get_global_rect().get_center().x > 400.0, "")
	_hub.set_clock("")
	await _put_in("sandbox_call_box")
	_t.check("sandbox: the call box prompt shows", _hub.card_for("sandbox_call_box") != null, str(_hub.prompt_words()))
	_game._screen_key(KEY_E)
	await _frames(2)
	_t.check("sandbox: E opens the enemy picker over the walk", sandbox.page_open and _screens.walking() and not _screens.walk_live(), "")
	_t.check("sandbox: the picker sits on screen", _on_screen(_screens.walk_page()), str(_screens.walk_page().get_global_rect()))
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("sandbox: Escape returns to the walk", not sandbox.page_open and _screens.walk_live(), "")
	await _put_in("scrapbook")
	_t.check("scrapbook: the prompt shows", _hub.card_for("scrapbook") != null and _hub.card_for("scrapbook").text == "Scrapbook", str(_hub.prompt_words()))
	_game._screen_key(KEY_B)
	await _frames(2)
	_t.check("scrapbook: B opens the book over the walk", _screens.walk_page() != null and _screens.walk_page().visible and not _screens.walk_live(), "")
	_t.check("scrapbook: the book sits on screen", _on_screen(_screens.walk_page()), str(_screens.walk_page().get_global_rect()))
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("scrapbook: Escape returns to the walk", _screens.walk_page() == null and _screens.walk_live(), "")
	_t.check("every feature added its station", _hub.zone_ids().has("camp_skee") and _hub.zone_ids().has("camp_trial")
		and _hub.zone_ids().has("sandbox_call_box") and _hub.zone_ids().has("scrapbook"), str(_hub.zone_ids()))

	# No two prompted zones that overlap share a key, so a key never means two stations at once.
	var clashes := []
	var ids: Array = _hub.zone_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			var za: Dictionary = _hub._zones[ids[i]]
			var zb: Dictionary = _hub._zones[ids[j]]
			if za["key"] == "" or zb["key"] == "":
				continue
			var reach: float = za["area"].get_child(0).shape.radius + zb["area"].get_child(0).shape.radius
			if za["key"] == zb["key"] and _hub.zone_position(ids[i]).distance_to(_hub.zone_position(ids[j])) < reach:
				clashes.append([ids[i], ids[j]])
	_t.check("no overlapping stations share a key", clashes.is_empty(), str(clashes))

	# The plug-in API: a feature's station and its page, opened over the walk and closed back to it.
	var feature := {"pressed": 0, "closed": 0}
	var page := PanelContainer.new()
	page.name = "FeaturePage"
	_hub.add_station("feature_test", _hub.zone_position("settings") + Vector3(20.0, 0.0, 0.0), "Feature", "key_f", 2.5,
		func():
			feature["pressed"] += 1
			_screens.open_walk_page(page, func(): feature["closed"] += 1))
	await _put_in("feature_test")
	_t.check("a feature's station shows its prompt", _hub.card_for("feature_test") != null and _hub.card_for("feature_test").text == "Feature", "")
	_game._screen_key(KEY_F)
	await _frames(2)
	_t.check("its key opens its page over the walk", feature["pressed"] == 1 and page.visible and _screens.walking()
		and not _screens.walk_live(), "")
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("Escape closes the page, runs on_close and returns to the walk", not page.visible and feature["closed"] == 1
		and _screens.walk_live() and _hub.walking, "")
	_t.check("socket() reads a placed piece's socket", _hub.socket("camp_launch_gate", "launch_trigger").origin.distance_to(
		_hub.zone_position("gate")) < 0.01, "")

	# No title hotkey leaks through a page opened over the walk, and pad B boosts instead of leaving.
	var leak_pages := [
		{"id": "lockers", "key": KEY_C}, {"id": "moss", "key": KEY_M}, {"id": "jukebox", "key": KEY_J},
		{"id": "settings", "key": KEY_S}, {"id": "radio", "key": KEY_R}, {"id": "achieve", "key": KEY_A},
		{"id": "sandbox_call_box", "key": KEY_E}, {"id": "scrapbook", "key": KEY_B},
	]
	for row in leak_pages:
		var id: String = row["id"]
		await _put_in(id)
		_game._screen_key(row["key"])
		await _frames(2)
		var opened: bool = not _screens.walk_live()
		_t.check("%s: a page is open for the leak check" % id, opened, "")
		var before: Array = _stack()
		for key in [KEY_SPACE, KEY_ENTER, KEY_A, KEY_S, KEY_H, KEY_C]:
			_game._screen_key(key)
			await _frames(1)
		_t.eq("%s: the flow stays on the title under hotkeys" % id, flow.state_name(), "title")
		_t.check("%s: the same page stays open and nothing stacks" % id, _stack() == before and _screens.walking()
			and not _screens.walk_live(), "%s vs %s" % [_stack(), before])
		_t.eq("%s: pad A opens nothing under a page" % id, _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_NONE)
		if id == "sandbox_call_box" or id == "scrapbook":
			Push.key(root, KEY_ESCAPE)
			await _frames(2)
		else:
			await _close(id)
		_t.check("%s: the leak check ends back on the live walk" % id, _screens.walk_live(), "")
	await _put_in("settings")
	Push.pad(root, JOY_BUTTON_B)
	await _frames(2)
	_t.check("pad B in the live walk boosts and does not leave", _screens.walking() and _screens.walk_live() and _hub.walking, "")
	Push.pad(root, JOY_BUTTON_START)
	await _frames(2)
	_t.check("pad Start leaves the walk", not _screens.walking() and not _hub.walking and flow.state_name() == "title", "")
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("the walk is back after the pad check", _screens.walk_live(), "")

	# A scripted roll from the spawn.
	_game.player.reset_to(_hub.spawn_position())
	_game.player.body().global_position = _hub.spawn_position()
	await _physics(10)
	var start: Vector3 = player.ball_position()
	source.hold = {"move": Vector2(0.0, 1.0)}
	var lowest := start.y
	for i in 270:
		await physics_frame
		lowest = minf(lowest, player.ball_position().y)
	source.hold = {}
	var moved: float = player.ball_position().distance_to(start)
	_t.check("a 3 s roll moves the ball more than 20 m", moved > 20.0, "%.1f m" % moved)
	_t.check("the ball does not fall below the plaza", lowest > _hub.root.global_position.y - 1.0, "%.2f" % lowest)

	# K leaves.
	_game.player.reset_to(_hub.spawn_position())
	await _physics(3)
	_game._screen_key(KEY_K)
	await _frames(2)
	_t.check("K leaves the walk", not _screens.walking() and not _hub.walking and not _screens.camp_open(), "")
	_t.check("the ball is frozen again", player.frozen(), "")
	_t.check("the hub hides", not _hub.root.visible, "")
	_t.check("the title picture comes back", title_stage._layer.visible and title_stage.active, "")
	_t.check("the title's buttons come back", _screens._actions.visible and _screens._veil.visible, "")
	_t.check("the ball is back on the first stage", player.ball_position().distance_to(_game.ctx.terrain.spawn_point(1)) < 3.0,
		str(player.ball_position()))
	_t.check("no zone is left inside", _hub.inside_ids().is_empty(), "")

	# Re-entering reuses the hub; Space at the gate launches the gate's pilot straight into stage 1 (launch_take.gd).
	var root_before = _hub.root
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("a second walk reuses the hub", _hub.root == root_before and _screens.walking(), "")
	await _put_in("gate")
	var gate_pilot = _game.gate_pilot()
	_t.check("the gate prompt names the pilot it launches", _hub.card_for("gate") != null
		and _hub.card_for("gate").text == "Launch as %s" % gate_pilot.display_name, _hub.card_for("gate").text if _hub.card_for("gate") != null else "")
	_game._screen_key(KEY_SPACE)
	await _frames(3)
	_t.check("Space at the gate starts the run on stage 1, no pilot select", flow.in_stage() and _game.run.stage == 1, flow.state_name())
	_t.eq("the gate's pilot flies", _game.run.class_def.id, gate_pilot.id)
	_t.check("the walk has ended", not _screens.walking() and not _hub.walking and not _hub.root.visible, "")
	_t.check("the ball is live over the dam", not player.frozen()
		and player.ball_position().distance_to(_game.ctx.terrain.spawn_point(1)) < 30.0, str(player.ball_position()))
	_t.check("the title picture stays down", not title_stage._layer.visible, "")
	flow.show_title()
	await _frames(2)
	_t.check("the title after Launch is the plain title", not _screens.camp_open() and _screens._actions.visible, "")
	quit(_t.verdict())


# A page that is tall enough to read and lies inside the window.
func _on_screen(page: Control) -> bool:
	var rect: Rect2 = page.get_global_rect()
	var slide: float = _screens._content.position.y  # the page is still sliding in
	return rect.size.y > 200.0 and rect.position.y - slide >= 0.0 and rect.end.y - slide <= page.get_viewport().get_visible_rect().size.y + 1.0


func _pad(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


# What is open over the walk: every page and the walk page, for the leak checks.
func _stack() -> Array:
	var customize: bool = _screens.camp_page().customize.visible
	return [_screens.settings_open(), _screens.achievements_open(), _screens.help_open(), _screens.jukebox_open(),
		_screens.radio_open(), customize, _game.get_node("Workshop").companion_panel.is_open(), _screens.walk_page()]


func _chirps() -> int:
	var audio = _game.presentation.get("audio")
	return audio.chirp_log.size() if audio != null else 0


func _count_environments(node: Node) -> int:
	var n := 1 if node is WorldEnvironment else 0
	for child in node.get_children():
		n += _count_environments(child)
	return n
