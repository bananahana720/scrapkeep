extends Node

const AbilitySlots := preload("res://src/ui/ability_slots.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const Palette := preload("res://src/core/palette.gd")
const Tuning := preload("res://src/movement/tuning.gd")


const TIPS := {
	"grip": "Stay fast against a wall and it holds you.",
	"jam": "A pulse shuts picks 2 and 3. A fast, airborne or hooked ball slips it.",
	"cast": "A pick with a cast time spends nothing if a knock or a second press stops it.",
	"radio": "Turn the radio or skip a take with the keys on its dial.",
	"stake": "Hold at the relay mast for a bigger fight and more part rolls.",
	"companion": "SPIL-9 is full. Your next ram calls it in.",
	"active": "Your active waits on the bar. Press the key under it to fire.",
	"ultimate": "Your ultimate is full. Press the key under it on the bar.",
	"dunk": "Slam in the air, then reel into what you hooked to land the slam on it.",
}
const WAIT_FOR_PICK := ["radio", "active"]
const STAKE_REACH := 30.0
const SEEN_PREFIX := "tip_"
const MIN_SHOWN := 0.4
const OPENING := 20.0

var game
var profile
var hud
var pending: Array[String] = []
var showing := ""
var _shown_for := 0.0
var _told := false
var _jams := 0
var _dunks := 0
var _wired := false
var _run_time := 0.0
var _opening_tips := 0
var _cleared := false
var _fought := false
var _walled := false
var _was_carving := false


func setup(game_ref, profile_ref, hud_ref) -> void:
	game = game_ref
	profile = profile_ref
	hud = hud_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if game != null and game.get("events") != null:
		game.events.run_started.connect(_on_run_started)
		game.events.carved.connect(_on_carved)
		game.events.stage_cleared.connect(func(_stage: int): _cleared = true)
		game.events.player_hit.connect(func(_amount: float, _source: String): _fought = true)
		game.events.enemy_killed.connect(func(_kind: String, _at: Vector3, _scrap: int): _fought = true)


func seen(id: String) -> bool:
	return profile.seen(SEEN_PREFIX + id)


func _physics_process(delta: float) -> void:
	if game == null or game.flow == null or not game.flow.in_play():
		return
	_wire()
	_run_time += delta
	var player = game.player
	_track_wall(player.state)
	var abilities = player.abilities
	if abilities.jams > _jams:
		meet("jam")
	_jams = abilities.jams
	var dunk = player.get("dunk")
	if dunk != null:
		if dunk.stored_count > _dunks:
			meet("dunk")
		_dunks = dunk.stored_count
	var picking := start_card_up(game)
	if picking:
		for id in WAIT_FOR_PICK:
			pending.erase(id)
	if not seen("radio") and not picking and _cleared:
		var deck = game.get("radio_deck")
		if deck != null and deck.dial != null and deck.dial.is_visible_in_tree():
			meet("radio")
	if not seen("stake") and stake_near(player.shown_position()):
		meet("stake")
	var combat = game.get("combat")
	if combat != null and not picking and _fought and not seen("active") and combat.get("actives") != null \
			and combat.actives.enabled() and combat.actives.active_id != "":
		meet("active")
	if abilities.casting != AbilityState.UNSTARTED:
		meet("cast")
	if fight_live(game.flow) or game.flow.calm():
		_withdraw()
		return
	if not seen("ultimate") and AbilitySlots.ultimate_of(game)["state"] == AbilityState.READY:
		meet("ultimate")
	_step_showing(delta)
	if showing == "" and not pending.is_empty() and hud.toast_texts().is_empty() and not game.opening.waits("tip") \
			and not opening_full():
		_put_up(pending.pop_front())


static func fight_live(flow) -> bool:
	return (flow.engaged() and flow.sealed) or flow.state_name() == "boss"


static func start_card_up(game_ref) -> bool:
	var card = game_ref.flow.get("start_card")
	var take = game_ref.get("launch_take")
	return (card != null and card.showing()) or (take != null and take.busy())


func _track_wall(state) -> void:
	if state.carving and not _was_carving:
		_walled = false
	if state.carving and state.contact_normal.y <= Tuning.MAX_SLOPE_DOT:
		_walled = true
	_was_carving = state.carving


func _on_carved(_at: Vector3, _seconds: float, _speed: float) -> void:
	if _walled:
		meet("grip")
	_walled = false


func opening_full() -> bool:
	return _run_time < OPENING and _opening_tips >= 1


func meet(id: String) -> void:
	if seen(id) or id == showing or not TIPS.has(id) or pending.has(id):
		return
	pending.append(id)


func _on_run_started(_class_id: String) -> void:
	pending.clear()
	_run_time = 0.0
	_opening_tips = 0
	_cleared = false
	_fought = false
	if showing != "":
		hud.drop_toast(TIPS[showing])
	showing = ""
	_told = false
	_shown_for = 0.0


func _put_up(id: String) -> void:
	if seen(id):
		return
	showing = id
	if id == "radio":
		var deck = game.get("radio_deck")
		if deck != null and deck.dial != null:
			deck.dial.teach()
	_shown_for = 0.0
	_told = false
	hud.toast(TIPS[id], Palette.SAND, "diamond", 3)


func _step_showing(delta: float) -> void:
	if showing == "":
		return
	var words: String = TIPS[showing]
	if hud.toast_on_screen() == words:
		_shown_for += delta
		if not _told and _shown_for >= MIN_SHOWN:
			_told = true
			profile.mark_seen(SEEN_PREFIX + showing)
			if _run_time < OPENING:
				_opening_tips += 1
			game.events.prompt_shown.emit("tip_" + showing)
		return
	if hud.toast_texts().has(words):
		return
	_release()


func _withdraw() -> void:
	if showing == "":
		return
	hud.drop_toast(TIPS[showing])
	_release()


func _release() -> void:
	if not _told:
		pending.push_front(showing)
	showing = ""
	_told = false
	_shown_for = 0.0


func _wire() -> void:
	if _wired:
		return
	var combat = game.get("combat")
	if combat == null:
		return
	_wired = true
	combat.companion_assist_full.connect(func(): meet("companion"))


func stake_near(ball: Vector3) -> bool:
	var interact = game.ctx.root.get_node_or_null("Interact") if game.ctx != null and game.ctx.root != null else null
	if interact == null:
		return false
	for device in interact.devices:
		if is_instance_valid(device) and device.has_method("terms") and "relay" in device and device.relay != null \
				and device.reach_point().distance_to(ball) <= STAKE_REACH:
			return true
	return false
