extends Node

const AbilityState := preload("res://src/core/ability_state.gd")
const Palette := preload("res://src/core/palette.gd")

# First-meet tips (HELP-REFRESH, alpha-status WHATS-LEFT row 8): the field rules no key prompt
# carries, said once on a profile at the moment the player first meets them, as a toast.
#   grip       the ball carves a wall at the fast tier (state.carving)
#   jam        a field's pulse jams the special and line slots (abilities.jams)
#   cast       the bar holds a slot with a cast time, or one starts casting (abilities.casting)
#   radio      the pilot radio's dial first draws in play
#   stake      the ball comes within STAKE_REACH of a relay's stake post
#   companion  SPIL-9's halo gauge fills (combat.companion_assist_full)
#   active     the F slot first racks an active (behind --actives)
# A fight keeps its word budget (ui_word_budget_test): a tip met while a Warden is engaged waits
# in `pending` and is told when the fight lets go, and one still on screen when a fight starts is
# taken down.
# Each emits events.prompt_shown("tip_<id>") as the toast shows, so scripts/first-timer.mjs reads
# it as a teach, and files itself in the profile's seen list so it never repeats. Words come
# from the game's own: the Warden's slots are numbers, the dial's keys are . , /.

const TIPS := {
	"grip": "Wall grip: stay at top speed and walls hold you.",
	"jam": "Jammed: slots 2 and 3 shut. A fast ball slips the pulse.",
	"cast": "Cast time: a hit or a second press drops it unspent.",
	"radio": "Radio: . next station, , back, / skip the track.",
	"stake": "Relay stake: hold E at the mast to raise the fight and the parts.",
	"companion": "SPIL-9 is full: your next ram calls it in.",
	"active": "F fires your active.",
}
const STAKE_REACH := 30.0
const SEEN_PREFIX := "tip_"

var game
var profile
var hud
var pending := {}
var _jams := 0
var _wired := false


func setup(game_ref, profile_ref, hud_ref) -> void:
	game = game_ref
	profile = profile_ref
	hud = hud_ref
	process_mode = Node.PROCESS_MODE_PAUSABLE


func seen(id: String) -> bool:
	return profile.seen(SEEN_PREFIX + id)


# Shows the tip for `id` once on this profile: a toast, then prompt_shown for the audit.
func tell(id: String) -> bool:
	if seen(id) or not TIPS.has(id):
		return false
	profile.mark_seen(SEEN_PREFIX + id)
	hud.toast(TIPS[id], Palette.SAND, "diamond", 3)
	game.events.prompt_shown.emit("tip_" + id)
	return true


func _physics_process(_delta: float) -> void:
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
	if abilities.casting != AbilityState.UNSTARTED or has_cast_slot(abilities):
		meet("cast")
	if not seen("radio"):
		var deck = game.get("radio_deck")
		if deck != null and deck.dial != null and deck.dial.is_visible_in_tree():
			meet("radio")
	if not seen("stake") and stake_near(player.ball_position()):
		meet("stake")
	var combat = game.get("combat")
	if combat != null and not seen("active") and combat.get("actives") != null and combat.actives.active_id != "":
		meet("active")
	if game.flow.engaged():
		for id in TIPS:
			hud.drop_toast(TIPS[id])
	else:
		for id in pending.keys():
			tell(id)
		pending.clear()


# A pilot whose bar holds a slot with a cast time hears of it from the drop, before the first
# cast lands in a fight (where the tip would have to wait).
static func has_cast_slot(abilities) -> bool:
	for slot in [AbilityState.WEAPON, AbilityState.SPECIAL, AbilityState.LINE]:
		if abilities.cast_of(slot) > 0.0:
			return true
	return false


# A verb met now: told at once, or held until the fight is over.
func meet(id: String) -> void:
	if seen(id):
		return
	if game.flow.engaged():
		pending[id] = true
		return
	tell(id)


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
