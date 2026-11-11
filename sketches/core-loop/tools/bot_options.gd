extends RefCounted

const BotDriver := preload("res://tools/bot_driver.gd")
const ParkTerrain := preload("res://src/world/park/park_terrain.gd")

const FAST_FLAGS := ["bot-no-mix", "bot-no-visuals", "bot-no-pilot-tracks"]
const UNREAD_VISUALS := [
	"res://src/presentation/warden_ring.gd",
	"res://src/presentation/set_dressing.gd", "res://src/presentation/vfx.gd"
]

var settings: Dictionary
var pilot_tracks_skipped := 0


func _init(options: Dictionary = {}, tree: SceneTree = null) -> void:
	settings = options
	configure(settings)
	if tree != null:
		tree.node_added.connect(_on_node_added)
	# A park stage's render regions are drawn only; a headless bot run builds the collider alone.
	ParkTerrain.draw_regions = not _enabled("bot-no-visuals")


static func configure(settings: Dictionary) -> void:
	if settings.get("gate", "0") == "1":
		for key in FAST_FLAGS:
			if not settings.has(key):
				settings[key] = "1"


# --relay-stake=<0..4> (SR10): the stake the skipper puts on the park relay before it rolls in.
# 0 (and an absent flag) leaves the bot untouched. Returns -1 for anything outside 0..4.
static func relay_stake(settings: Dictionary) -> int:
	if not settings.has("relay-stake"):
		return 0
	var text := String(settings["relay-stake"])
	if not text.is_valid_int():
		return -1
	var k := int(text)
	return k if k >= 0 and k <= 4 else -1


# --explore-by=<s> (pacing lab): the stage second the completionist leaves its optional rolling for
# the Warden, in place of BotDriver.ENGAGE_BY. Each activity keeps its ACTIVITY_SECONDS, so a site the bot
# cannot finish costs what it costs by default, not more. 0 when absent, -1 when not a number above ENGAGE_BY.
static func explore_by(settings: Dictionary) -> float:
	if not settings.has("explore-by"):
		return 0.0
	var text := String(settings["explore-by"])
	if not text.is_valid_float() or float(text) <= BotDriver.ENGAGE_BY:
		return -1.0
	return float(text)


func apply_audio(audio: Node) -> void:
	if _enabled("bot-no-mix"):
		audio.engine.bot_skip_samples = true


func _enabled(key: String) -> bool:
	return settings.get(key, "0") == "1" and DisplayServer.get_name() == "headless"


func _on_node_added(node: Node) -> void:
	if _enabled("bot-no-pilot-tracks") and node is AnimationPlayer:
		_disable_pilot_tracks(node)
		_disable_pilot_tracks.call_deferred(node)
	if _enabled("bot-no-visuals"):
		var script = node.get_script()
		if script != null and script.resource_path in UNREAD_VISUALS:
			node.set_process(false)
			node.set_process.call_deferred(false)


func _disable_pilot_tracks(animator: AnimationPlayer) -> void:
	if not is_instance_valid(animator):
		return
	var parent := animator.get_parent()
	while parent != null and parent.name != "AnimatedPilot":
		parent = parent.get_parent()
	if parent == null:
		return
	for id in animator.get_animation_list():
		var animation := animator.get_animation(id)
		for track in animation.get_track_count():
			if animation.track_get_type(track) in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D, Animation.TYPE_BLEND_SHAPE] and animation.track_is_enabled(track):
				pilot_tracks_skipped += 1
				animation.track_set_enabled(track, false)
