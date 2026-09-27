extends Node

const Audio := preload("res://src/presentation/audio.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")

# Writer C's module: how every committed fact looks, feels and sounds. It reads the
# GameEvents bus, the event_kinds table and the spine's camera and ball hooks, and
# never decides an outcome (TADR-008).
#
#   audio.gd       the director: which cue, now or on the beat; the mixer and keys
#   music_engine   the band: 172 BPM drum-and-bass in D Dorian, layered by pressure
#   sfx_bank       one synthesized sound per event_kinds sound id
#   synth          the instrument rack both of them play
#   harmony        tempo, key and scales, the one musical source
#   juice          squash and stretch, camera punches and kicks, hit-stop, the pylon
#   vfx            trails, speed lines, flashes, rings and sparkles
#   rows           event_kinds rows, with fallbacks for demo-spec kinds not yet landed
#   codex_style    category colours, icons and the discovery banner

var ctx
var audio
var juice
var vfx
var banner
# Presentation shows the discovery banner itself. Set false if the HUD shows its own.
var auto_banner := true
var _dismiss_wired := {}
# Screens a queued discovery never plays over.
const BANNER_SCREENS := ["title", "class_select", "summary", "dead", "victory"]


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "Presentation"
	audio = Audio.new()
	add_child(audio)
	audio.setup(ctx)
	juice = Juice.new()
	add_child(juice)
	juice.setup(ctx)
	vfx = Vfx.new()
	add_child(vfx)
	vfx.setup(ctx)
	var layer := CanvasLayer.new()
	layer.name = "CodexBannerLayer"
	layer.layer = 40
	add_child(layer)
	banner = CodexBanner.new()
	layer.add_child(banner)
	wire_optional()


# Connects the demo-spec signals the bus has now. Safe to call again after the spine
# (or a test) adds more.
func wire_optional() -> void:
	audio.wire_optional()
	juice.wire_optional()
	vfx.wire_optional()
	var events = ctx.events
	if events.has_signal("synergy_discovered") and not events.is_connected("synergy_discovered", _on_synergy):
		events.connect("synergy_discovered", _on_synergy)
	# The banner never outlives the moment: a flow change, arena entry, death or the
	# run's end clears it at once.
	for signal_name in ["stage_content_cleared", "player_died", "run_ended"]:
		if events.has_signal(signal_name) and not _dismiss_wired.has(signal_name):
			_dismiss_wired[signal_name] = true
			var argc := _argc(events, signal_name)
			events.connect(signal_name, _dismiss_banner.unbind(argc) if argc > 0 else _dismiss_banner)
	if not events.is_connected("flow_changed", _on_flow_changed):
		events.connect("flow_changed", _on_flow_changed)


func _dismiss_banner() -> void:
	banner.dismiss(true)


# Any flow change clears the banner; a queued discovery survives an in-play change
# (beacon, gates, launch) but never a screen (title, class select, death, summary).
func _on_flow_changed(state: String) -> void:
	banner.dismiss(state in BANNER_SCREENS)
	if not state in BANNER_SCREENS:
		banner._next()


static func _argc(events: Object, signal_name: String) -> int:
	for info in events.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


# Category colours, icons, the banner script and sizes, for the codex page and HUD.
func codex_style() -> Dictionary:
	return CodexStyle.style()


func _on_synergy(id: String, category: String, first_time: bool) -> void:
	if not auto_banner:
		return
	var entry := _codex_entry(id)
	var title: String = entry.get("name", id.capitalize())
	banner.show_discovery(title, category, String(entry.get("text", "")), "New synergy" if first_time else "Synergy")


# The registry entry for an id, if the spine's codex offers one.
func _codex_entry(id: String) -> Dictionary:
	var codex = ctx.get("codex")
	if codex == null:
		return {}
	if codex.has_method("entries"):
		for entry in codex.entries():
			if entry.get("id", "") == id:
				return entry
	if codex.has_method("name_of"):
		return {"name": codex.name_of(id)}
	return {}
