extends Control

const EventKinds := preload("res://src/core/event_kinds.gd")
const Augments := preload("res://src/movement/augments.gd")
const Icons := preload("res://src/ui/icons.gd")
const Keycap := preload("res://src/ui/keycap.gd")

# Contextual key glyphs: a keycap beside the ball or the grapple target, shown only
# while its action is available right now, and retired for good once the action has
# succeeded RETIRE_AFTER times on this profile (ui_profile.gd). The Tab field notes keep
# the full key list for anyone who wants it back.

const RETIRE_AFTER := 3
const KEY_H := 24.0
# action: the key it asks for, the ability icon beside it, and what it sits next to.
const ACTIONS := {
	"mount": {"key": "key_e", "icon": "ab_sable_mount", "anchor": "ball"},
	"grapple": {"key": "key_rmb", "icon": "ab_sable_move", "anchor": "aim"},
	"slingshot": {"key": "key_space", "icon": "ab_sable_vault", "anchor": "ball"},
}
const BALL_OFFSET := Vector2(52.0, -34.0)
const AIM_OFFSET := Vector2(34.0, 24.0)

var game
var profile
var available := {}


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.events.grapple_fired.connect(func(_anchor: Vector3): record_use("grapple"))
	game.events.mounted.connect(func(_at: Vector3, _banked: float): record_use("mount"))
	game.events.dismounted.connect(func(velocity: Vector3):
		if velocity.length() > 0.1:
			record_use("slingshot"))


func record_use(action: String) -> void:
	if game.flow.in_play():
		profile.add_use(action)


func retired(action: String) -> bool:
	return profile.uses(action) >= RETIRE_AFTER


# The actions whose glyph shows for this availability, in ACTIONS order.
func shown(avail: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for action in ACTIONS:
		if avail.get(action, false) and not retired(action):
			out.append(action)
	return out


func drawn_words() -> PackedStringArray:
	var out := PackedStringArray()
	if not visible:
		return out
	for action in shown(available):
		out.append_array(Keycap.words(ACTIONS[action]["key"]))
	return out


func _physics_process(_delta: float) -> void:
	if game == null:
		return
	available = {}
	if not game.flow.in_play():
		return
	var kit = game.player.kit
	available["slingshot"] = kit.mounted
	available["grapple"] = kit.on(Augments.GRAPPLE) and not kit.hooked and not kit.mounted \
		and kit.aim.get("state", Augments.AIM_NONE) != Augments.AIM_NONE
	# E is interact first (LOOP-REDESIGN section 9): the pylon glyph shows only when E
	# would mount, never beside an interactable's own keycap.
	var claim: Callable = game.player.interact_claim
	available["mount"] = kit.on(Augments.PYLON) and not kit.mounted and kit.mount_block <= 0.0 and game.player.face_in_reach() \
		and (game.player.mobility_started() or not (claim.is_valid() and claim.call(true)))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if game == null or not game.flow.in_play():
		return
	var cam: Camera3D = game.camera.cam
	var color: Color = EventKinds.UI_ROWS["key_glyph"]["color"]
	for action in shown(available):
		var spec: Dictionary = ACTIONS[action]
		var world: Vector3 = game.player.shown_position() if spec["anchor"] == "ball" else game.player.kit.aim.get("point", Vector3.INF)
		if world == Vector3.INF or cam.is_position_behind(world):
			continue
		var offset: Vector2 = BALL_OFFSET if spec["anchor"] == "ball" else AIM_OFFSET
		var at := cam.unproject_position(world) + offset
		var cap := Keycap.draw(self, at, spec["key"], color, KEY_H)
		var icon := Rect2(Vector2(cap.end.x + 5.0, at.y - KEY_H * 0.45), Vector2(KEY_H * 0.9, KEY_H * 0.9))
		draw_texture_rect(Icons.texture(spec["icon"]), icon, false, Icons.tint(spec["icon"], color))
