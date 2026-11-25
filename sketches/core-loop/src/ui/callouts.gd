extends HBoxContainer

const EventKinds := preload("res://src/core/event_kinds.gd")
const UiTokens := preload("res://src/ui/ui_tokens.gd")
const Icons := preload("res://src/ui/icons.gd")
const KeycapView := preload("res://src/ui/keycap_view.gd")
const UiFonts := preload("res://src/ui/ui_fonts.gd")
const Keycap := preload("res://src/ui/keycap.gd")


const SHOW_SECONDS := 2.5
const FADE_IN := 0.2
const FADE_OUT := 0.4
const NOTES_AFTER := 60.0
const ICON := 28.0
const PARTS := {
	"callout_scrap": {"before": ["res_mass"], "after": ["res_heft"]},
	"callout_warden": {"before": ["obj_warden"], "after": []},
	"callout_gates": {"before": ["obj_gate"], "after": []},
	"callout_notes": {"before": [], "after": []},
}
const KEY_PATTERN := "\\{(key_[a-z0-9]+)\\}"

var game
var profile
var queue: Array[String] = []
var showing := ""
var suppressed := false
var _shown_text := ""
var _tween: Tween


func setup(game_ref, profile_ref) -> void:
	game = game_ref
	profile = profile_ref
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 8)
	modulate.a = 0.0
	game.events.scrap_collected.connect(func(_amount: int, _at: Vector3, _total: int): offer("callout_scrap"))
	game.events.warden_engaged.connect(func(_stage: int): offer("callout_warden"))
	game.events.beacon_unsealed.connect(func(_stage: int): offer("callout_gates"))


func offer(id: String) -> void:
	if profile.seen(id) or id in queue or id == showing or not game.flow.in_play():
		return
	queue.append(id)


func _process(_delta: float) -> void:
	if game == null:
		return
	var playing: bool = game.flow.in_play()
	visible = playing and not suppressed
	if playing and game.run.run_time >= NOTES_AFTER:
		offer("callout_notes")
	if showing == "" and playing and not queue.is_empty():
		_show(queue.pop_front())


func _show(id: String) -> void:
	showing = id
	profile.mark_seen(id)
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var row: Dictionary = EventKinds.UI_ROWS[id]
	var color: Color = row["color"]
	var parts: Dictionary = PARTS[id]
	for icon in parts["before"]:
		add_child(_part(icon, color))
	var wording: String = row["hud"]
	var keys := RegEx.create_from_string(KEY_PATTERN)
	var at := 0
	for m in keys.search_all(wording):
		_add_words(wording.substr(at, m.get_start() - at), color)
		add_child(_part(m.get_string(1), color))
		at = m.get_end()
	_add_words(wording.substr(at), color)
	_shown_text = plain(wording)
	for icon in parts["after"]:
		add_child(_part(icon, color))
	if _tween != null:
		_tween.kill()
	modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 1.0, FADE_IN)
	_tween.tween_interval(SHOW_SECONDS - FADE_IN - FADE_OUT)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_OUT)
	_tween.tween_callback(func(): showing = "")
	_chime(id)


func _chime(id: String) -> void:
	var presentation = game.get("presentation")
	var audio = presentation.get("audio") if presentation != null else null
	if audio != null and audio.has_method("play"):
		audio.play(id, 0.0, 1.0, "UI")


func text() -> String:
	return _shown_text if showing != "" else ""


static func plain(wording: String) -> String:
	var keys := RegEx.create_from_string(KEY_PATTERN)
	var out := wording
	for m in keys.search_all(wording):
		out = out.replace(m.get_string(0), Keycap.label(m.get_string(1)))
	return out


func _add_words(words: String, color: Color) -> void:
	if words.strip_edges() == "":
		return
	var label := Label.new()
	label.text = words.strip_edges()
	label.add_theme_font_override("font", UiFonts.bold())
	label.add_theme_font_size_override("font_size", UiTokens.BODY)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)


static func _part(icon: String, color: Color) -> Control:
	if icon.begins_with("key_"):
		return KeycapView.new(icon, color, ICON)
	var rect := TextureRect.new()
	rect.texture = Icons.texture(icon)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(ICON, ICON)
	rect.modulate = Icons.tint(icon, color)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
