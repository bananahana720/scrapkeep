extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Palette := preload("res://src/core/palette.gd")

# First-meet tips (HELP-REFRESH, alpha-status WHATS-LEFT row 8): the field rules no key prompt
# carries, said once on a profile as a toast at the first calm moment after the player first
# meets them: held while a fight is live and while another toast or tip holds the screen.
#   grip       the ball carves a wall at the fast tier (state.carving)
#   jam        a field's pulse jams the special and line slots (abilities.jams)
#   cast       the bar holds a slot with a cast time, or one starts casting (abilities.casting)
#   radio      the pilot radio's dial first draws in play
#   stake      the ball comes within STAKE_REACH of a relay's stake post
#   companion  SPIL-9's halo gauge fills (combat.companion_assist_full)
#   active     the F slot first racks an active (actives are off unless the tuning turns them on)
#   dunk       an air slam first stores a dunk charge (player.dunk.stored_count rises)
# Radio and active (WAIT_FOR_PICK) wait while stage 1's start-pick card is up or the launch take
# that reveals it still plays (both a player's only): the drop already carries the card, so neither
# is met, and one already waiting leaves the queue, until the pick is taken (w22 first-timer red
# team watch 5). Their verbs stay met, so they queue again on the next calm frame.
# In a run's opening every tip waits for its turn (opening.gd): the title and Moss go first.
# The HUD shows one toast at a time and a newer one replaces it, so a met tip joins `pending`
# and goes up only when the toast slot is empty and no other tip is up: one tip per toast
# lifetime. A tip met now goes ahead of the cast tip a slot only promises (has_cast_slot).
# A tip counts as told only after its toast has been on screen for MIN_SHOWN: then it emits
# events.prompt_shown("tip_<id>"), which scripts/first-timer.mjs reads as a teach, and files
# itself in the profile's seen list so it never repeats. A tip whose toast leaves sooner (another
# toast replaced it, or a fight took it down) goes back to the front of `pending`.
# A fight keeps its word budget (ui_word_budget_test): while fight_live() no tip goes up and a
# tip still on screen is taken down. Words come from the game's own: the Warden's slots are
# numbers, and no tip types a key: a toast is a plain Label that cannot draw a keycap, so a tip that needs
# a key points at the mark that draws it (the mast's prompt, the bar slot, the notes) and keys can be rebound.
# A new run (events.run_started) clears the queue and takes down the tip on screen: each was
# met in the old run's moment (its pilot's cast slot, a stake post, a rack, a halo), so it waits
# to be met again rather than show out of context; nothing untold is marked seen.

const TIPS := {
	"grip": "Stay fast against a wall and it holds you.",
	"jam": "A pulse shuts picks 2 and 3. A fast, airborne or hooked ball slips it.",
	"cast": "A pick with a cast time spends nothing if a knock or a second press stops it.",
	"radio": "The radio changes station and skips takes. Its keys are in the notes.",
	"stake": "Hold at the relay mast for a bigger fight and more part rolls.",
	"companion": "SPIL-9 is full. Your next ram calls it in.",
	"active": "Press the active's key on the bar to fire it.",
	"dunk": "An air slam stores its hit. Reel into a hooked body to cash it in.",
}
const WAIT_FOR_PICK := ["radio", "active"]
const STAKE_REACH := 30.0
const SEEN_PREFIX := "tip_"
# Seconds a tip's toast must stay on screen before it counts as told (the fade in is 0.12 s).
const MIN_SHOWN := 0.4

var game
var profile
var hud
# Met tips waiting for the toast slot, in the order they go up.
var pending: Array[String] = []
# The tip whose toast is up (or held behind the stage card); "" when none.
var showing := ""
var _later := {}
var _shown_for := 0.0
var _told := false
var _jams := 0
var _dunks := 0
var _wired := false


func setup(game_ref, profile_ref, hud_ref) -> void:
	game = game_ref
	profile = profile_ref
	hud = hud_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE
	if game != null and game.get("events") != null:
		game.events.run_started.connect(_on_run_started)


func seen(id: String) -> bool:
	return profile.seen(SEEN_PREFIX + id)


func _physics_process(delta: float) -> void:
	if game == null or game.flow == null or not game.flow.in_play():
		return
	_wire()
	var player = game.player
	var state = player.state
	if state.carving:
		meet("grip")
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
	if not seen("radio") and not picking:
		var deck = game.get("radio_deck")
		if deck != null and deck.dial != null and deck.dial.is_visible_in_tree():
			meet("radio")
	if not seen("stake") and stake_near(player.shown_position()):
		meet("stake")
	var combat = game.get("combat")
	if combat != null and not picking and not seen("active") and combat.get("actives") != null and combat.actives.enabled() \
			and combat.actives.active_id != "":
		meet("active")
	if abilities.casting != AbilityState.UNSTARTED:
		meet("cast")
	elif has_cast_slot(abilities):
		meet("cast", true)
	if fight_live(game.flow):
		_withdraw()
		return
	_step_showing(delta)
	if showing == "" and not pending.is_empty() and hud.toast_texts().is_empty() and not game.opening.waits("tip"):
		_put_up(pending.pop_front())


# A fight holds the screen while this stage's Warden is engaged and not yet broken (flow
# unseals on the break) or while flow is in Brindle's arena (BOSS until the boss falls).
static func fight_live(flow) -> bool:
	return (flow.engaged() and flow.sealed) or flow.state_name() == "boss"


static func start_card_up(game_ref) -> bool:
	var card = game_ref.flow.get("start_card")
	var take = game_ref.get("launch_take")
	return (card != null and card.showing()) or (take != null and take.busy())


# A pilot whose bar holds a slot with a cast time hears of it from the drop, before the first
# cast lands in a fight (where the tip would have to wait).
static func has_cast_slot(abilities) -> bool:
	for slot in [AbilityState.WEAPON, AbilityState.SPECIAL, AbilityState.LINE]:
		if abilities.cast_of(slot) > 0.0:
			return true
	return false


# A verb met now joins the queue ahead of any tip only promised (`later`, the cast slot on the
# bar); a promised tip whose verb is then met moves up.
func meet(id: String, later := false) -> void:
	if seen(id) or id == showing or not TIPS.has(id):
		return
	if pending.has(id):
		if later or not _later.has(id):
			return
		pending.erase(id)
	_later.erase(id)
	if later:
		_later[id] = true
		pending.append(id)
		return
	var at := pending.size()
	for i in pending.size():
		if _later.has(pending[i]):
			at = i
			break
	pending.insert(at, id)


func _on_run_started(_class_id: String) -> void:
	pending.clear()
	_later.clear()
	if showing != "":
		hud.drop_toast(TIPS[showing])
	showing = ""
	_told = false
	_shown_for = 0.0


func _put_up(id: String) -> void:
	_later.erase(id)
	if seen(id):
		return
	showing = id
	_shown_for = 0.0
	_told = false
	hud.toast(TIPS[id], Palette.SAND, "diamond", 3)


# Counts the showing tip's time on screen; past MIN_SHOWN it is told. Once its toast is gone the
# slot frees, and a tip gone before it was told waits again at the front of the queue.
func _step_showing(delta: float) -> void:
	if showing == "":
		return
	var words: String = TIPS[showing]
	if hud.toast_on_screen() == words:
		_shown_for += delta
		if not _told and _shown_for >= MIN_SHOWN:
			_told = true
			profile.mark_seen(SEEN_PREFIX + showing)
			game.events.prompt_shown.emit("tip_" + showing)
		return
	if hud.toast_texts().has(words):
		return
	_release()


# A fight starts: the showing tip comes down, and waits again unless it was already told.
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


# The companion's signal lives on combat, which can come up after the HUD: join it once.
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
