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
