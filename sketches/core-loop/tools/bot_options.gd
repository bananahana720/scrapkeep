extends RefCounted

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
