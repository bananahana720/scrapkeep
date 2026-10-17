extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const CampHub := preload("res://src/world/camp_hub.gd")
const CampLayout := preload("res://src/world/camp_layout.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# The walkable camp (camp_hub.gd) on the real title:
#   - K enters the walk: the hub is built from the camp GLBs, the ball is unfrozen at the spawn, the title picture is
#     hidden and the flow stays on the title;
#   - outside a zone a station key does nothing (S and A are also the roll's keys);
#   - each station's zone shows a prompt card; its key opens the station's page; closing the page returns to the walk;
#   - the pet hops and chirps when the ball rolls into its pen;
#   - a scripted roll from the spawn moves more than 20 m and stays on the plaza;
#   - K leaves to the title with the ball frozen and the hub hidden;
#   - Space in the gate's zone leaves the walk for class select.

const STATIONS := [
	{"id": "lockers", "key": KEY_C, "label": "Customize"},
	{"id": "moss", "key": KEY_M, "label": "Companion"},
	{"id": "jukebox", "key": KEY_J, "label": "Jukebox"},
	{"id": "settings", "key": KEY_S, "label": "Settings"},
	{"id": "radio", "key": KEY_R, "label": "Mixtapes"},
	{"id": "achieve", "key": KEY_A, "label": "Achievements"},
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
			_game._screen_key(KEY_A)
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

	var environments := _count_environments(_game)
	# K enters the walk.
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("K builds the hub", _hub.built and _hub.root != null, "")
	_t.check("the walk is on and the camp is open", _screens.walking() and _screens.camp_open() and _hub.walking, "")
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
	_t.check("the settings console has a socket", _hub.has_socket("camp_settings_console", "interact"), "")

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
	# A second Esc with no page leaves.
	await _put_in("achieve")
	_t.eq("pad A in the trophy wall's zone is A", _game.pad_screen_key(_pad(JOY_BUTTON_A)), KEY_A)

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
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("sandbox: Escape returns to the walk", not sandbox.page_open and _screens.walk_live(), "")
	await _put_in("scrapbook")
	_t.check("scrapbook: the prompt shows", _hub.card_for("scrapbook") != null and _hub.card_for("scrapbook").text == "Scrapbook", str(_hub.prompt_words()))
	_game._screen_key(KEY_B)
	await _frames(2)
	_t.check("scrapbook: B opens the book over the walk", _screens.walk_page() != null and _screens.walk_page().visible and not _screens.walk_live(), "")
	Push.key(root, KEY_ESCAPE)
	await _frames(2)
	_t.check("scrapbook: Escape returns to the walk", _screens.walk_page() == null and _screens.walk_live(), "")
	_t.check("every feature added its station", _hub.zone_ids().has("camp_skee") and _hub.zone_ids().has("camp_trial")
		and _hub.zone_ids().has("sandbox_call_box") and _hub.zone_ids().has("scrapbook"), str(_hub.zone_ids()))

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

	# Re-entering reuses the hub; Space at the gate goes to class select.
	var root_before = _hub.root
	_game._screen_key(KEY_K)
	await _frames(3)
	_t.check("a second walk reuses the hub", _hub.root == root_before and _screens.walking(), "")
	await _put_in("gate")
	_t.check("the gate prompt reads Launch", _hub.card_for("gate") != null and _hub.card_for("gate").text == "Launch", "")
	_game._screen_key(KEY_SPACE)
	await _frames(3)
	_t.eq("Space at the gate reaches class select", flow.state_name(), "class_select")
	_t.check("the walk has ended", not _screens.walking() and not _hub.walking and not _hub.root.visible, "")
	_t.check("the ball is frozen for class select", player.frozen(), "")
	_t.check("class select shows its title picture", title_stage._layer.visible, "")
	flow.show_title()
	await _frames(2)
	_t.check("the title after Launch is the plain title", not _screens.camp_open() and _screens._actions.visible, "")
	quit(_t.verdict())


func _pad(button: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event


func _chirps() -> int:
	var audio = _game.presentation.get("audio")
	return audio.chirp_log.size() if audio != null else 0


func _count_environments(node: Node) -> int:
	var n := 1 if node is WorldEnvironment else 0
	for child in node.get_children():
		n += _count_environments(child)
	return n
