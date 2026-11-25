# smoke: timeout=300s (the real title, every camp station opened and closed)
extends SceneTree

const Game := preload("res://src/game.gd")
const Intent := preload("res://src/movement/intent.gd")
const Companion := preload("res://src/core/companion.gd")
const Keycap := preload("res://src/ui/keycap.gd")
const Push := preload("res://tests/workshop/push.gd")
const T := preload("res://tests/support/t.gd")

# Every station the hub prompts with a key (the pet pen has a zone but no key).
const KEYED := ["achieve", "camp_ring", "camp_skee", "camp_trial", "dispatch", "gate", "jukebox", "lockers", "logbook", "moss", "radio", "sandbox_call_box",
	"scrapbook", "settings"]

# Rule: from the real title, the main menu's Camp button enters the walk, and every station the hub reports opens its
# page or starts its activity on its own key and gives the walk back; the list comes from the hub (zone_ids), so a
# station added without an opener fails here. Esc then leaves to the main menu.

var _t := T.new("camp_stations_smoke_test")
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


func _put_in(id: String) -> void:
	var centre: Vector3 = _hub.zone_position(id)
	var toward: Vector3 = _hub.root.global_position - centre
	toward.y = 0.0
	var at: Vector3 = centre + toward.normalized() * 1.5
	at.y = 1.3
	_game.player.reset_to(at)
	_game.player.body().global_position = at
	await _physics(4)


# Anything a station may start besides a page: the skee game, the time trial and the ring's stocktake.
func _activity() -> String:
	var skee = _hub.root.get_node_or_null("CampSkee")
	var trial = _hub.root.get_node_or_null("CampTrial")
	if skee != null and skee.phase != skee.Phase.IDLE:
		return "skee"
	if trial != null and trial.run.state != trial.State.IDLE:
		return "trial"
	var ring = _hub.root.get_node_or_null("CampRing")
	if ring != null and ring.running():
		return "ring"
	return ""


func _end_activity(kind: String) -> void:
	if kind == "skee":
		_hub.root.get_node("CampSkee").end_game(true)
	elif kind == "trial":
		_hub.root.get_node("CampTrial").abort()
	elif kind == "ring":
		_hub.root.get_node("CampRing").stop()
	await _frames(2)


func _enter_by_button() -> void:
	var button: Button = _screens.button_for("camp")
	_t.check("the main menu offers Camp", button != null and button.is_visible_in_tree(), str(button))
	button.pressed.emit()
	await _frames(3)


func _run() -> void:
	while _game.flow == null:
		await process_frame
	await _frames(5)
	_game.ctx.calm = true
	_game.player.source = Intent.Scripted.new()
	_screens = _game.screens
	_hub = _game.camp_hub
	var flow = _game.flow
	_t.eq("the game starts on the title", flow.state_name(), "title")
	_game.ctx.profile.set_companion(Companion.with_piece({}, "escape_vent"))

	await _enter_by_button()
	_t.check("the Camp button enters the walk", _screens.walk_live() and _hub.walking and _hub.built, "")
	_t.eq("the flow stays on the title", flow.state_name(), "title")

	var ids: Array = _hub.zone_ids()
	_t.check("the hub reports its stations", ids.size() >= 10, str(ids))
	ids.sort()
	if ids.has("gate"):
		ids.erase("gate")
		ids.append("gate")  # Launch ends the walk, so it goes last.
	var keyed: Array = []
	for id in ids:
		var zone: Dictionary = _hub._zones[id]
		var key_id: String = zone["key"]
		if key_id == "":
			continue
		keyed.append(id)
		var keycode: int = OS.find_keycode_from_string(Keycap.label(key_id))
		await _put_in(id)
		_t.check("%s: the ball is in the zone" % id, _hub.inside(id), str(_hub.inside_ids()))
		_t.check("%s: the prompt shows" % id, _hub.prompts_shown() and _hub.card_for(id) != null, str(_hub.prompt_words()))
		var state_before: String = flow.state_name()
		_game._screen_key(keycode)
		await _frames(3)
		var activity := _activity()
		var left: bool = flow.state_name() != state_before
		var paged: bool = not _screens.walk_live()
		_t.check("%s: its key opens a page or starts an activity" % id, left or paged or activity != "",
			"state %s, page %s, activity '%s'" % [flow.state_name(), paged, activity])
		if left:
			_t.check("%s: Launch starts the run on stage 1" % id, flow.in_stage() and _game.run.stage == 1, flow.state_name())
			_t.check("%s: the walk has ended" % id, not _screens.walking() and not _hub.walking, "")
			flow.show_title()
			await _frames(3)
			await _enter_by_button()
		elif activity != "":
			await _end_activity(activity)
		elif paged:
			Push.key(root, KEY_ESCAPE)
			await _frames(3)
			var panel = _game.get_node("Workshop").companion_panel
			if panel.is_open():  # Moss's bench closes from its own Back, not Esc.
				panel.close()
				await _frames(3)
		_t.check("%s: closing returns to the walk" % id, _screens.walk_live() and _hub.walking and _activity() == "",
			"walking %s, live %s" % [_screens.walking(), _screens.walk_live()])
	# The exact keyed set, so a station dropped by a missing socket (camp_hub._station) fails here too.
	keyed.sort()
	var expected := KEYED.duplicate()
	expected.sort()
	_t.eq("every keyed station was pressed", keyed, expected)
	_t.check("the pet pen zone is there", ids.has("pet"), str(ids))

	Push.key(root, KEY_ESCAPE)
	await _frames(3)
	_t.check("Esc leaves the walk to the main menu", not _screens.walking() and not _hub.walking and flow.state_name() == "title"
		and _screens._actions.visible and _screens.button_for("camp").is_visible_in_tree(), "")
	quit(_t.verdict())
