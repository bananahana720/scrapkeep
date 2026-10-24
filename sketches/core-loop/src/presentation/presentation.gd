extends Node

const Audio := preload("res://src/presentation/audio.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const StatusMarks := preload("res://src/presentation/status_marks.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CompanionBody := preload("res://src/presentation/companion_body.gd")
const TitleStage := preload("res://src/presentation/title_stage.gd")
const WardenRing := preload("res://src/presentation/warden_ring.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const AmbientLife := preload("res://src/presentation/ambient_life.gd")
const Parts := preload("res://src/build/parts.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")

# Writer C's module: how every committed fact looks, feels and sounds. It reads the
# GameEvents bus, the event_kinds table and the spine's camera and ball hooks, and
# never decides an outcome (TADR-008).
#
#   audio.gd       the director: which cue, now or on the beat; the mixer and keys
#   music_engine   the band: 172 BPM drum-and-bass in D Dorian, layered by pressure
#   sfx_bank       one synthesized sound per event_kinds sound id
#   synth          the instrument rack both of them play
#   harmony        tempo, key and scales, the one musical source
#   juice          squash and stretch, camera punches and kicks, hit-stop, the pylon, and
#                  how hits, kills, pickups, dodges and hits taken land (v3 W11)
#   line_view      the harpoon line in the world: cable, lock brackets, barb and collar
#   status_marks   what an enemy's state shows on its body that no table row draws elsewhere:
#                  the star over a wind-up a hit broke
#   vfx            trails, speed lines, flashes, rings, sparkles, bursts and the edge flash
#   machine_fx     what enemies and bosses throw off: arrival, wind-up, hits, stagger,
#                  deaths, the four specials' tells, boss phases and falls, comic words
#   player_fx      sound words, overdrive, carve sparks, the might aura and impact frames
#   streak         the pickup streak and the kill chain audio climbs and juice draws
#   rows           event_kinds rows, with fallbacks for demo-spec kinds not yet landed
#   codex_style    category colours, icons and the discovery banner
#   hero_assets    the V3 models dressed over the greybox shell, chunks and gates
#   warden_ring    a posture Warden's health as four arcs on the ground round its foot
#   reward_ceremony  how a part find is presented, from a rarity tick to the crate (v3 W13)
#   panel_fx       a grey panel pickup: the word at the ball, the ratchet and the run's phrase

var ctx
var audio
var juice
var vfx
var machine_fx
var player_fx
var line_view
var status_marks
var armour_marks
var banner
var hero_assets
var ceremony
var panel_fx
var set_dressing: Node3D
var park_props: Node3D
var ambient_life: Node3D
var title_stage: Node
var ui_hidden := false
# Presentation shows the discovery banner itself. Set false if the HUD shows its own.
var auto_banner := true
var _dismiss_wired := {}
var _windup_states := {}
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
	machine_fx = MachineFx.new()
	add_child(machine_fx)
	machine_fx.setup(ctx)
	player_fx = PlayerFx.new()
	add_child(player_fx)
	player_fx.setup(ctx, vfx)
	audio.hit_on_beat.connect(player_fx.on_beat_hit)
	line_view = LineView.new()
	add_child(line_view)
	if ctx.camera != null and ctx.camera.cam != null:
		line_view.setup(ctx.player, ctx.camera.cam, ctx.events)
	juice.audio = audio
	juice.vfx = vfx
	status_marks = StatusMarks.new()
	add_child(status_marks)
	status_marks.setup(ctx, vfx)
	armour_marks = ArmourMarks.new()
	add_child(armour_marks)
	armour_marks.setup(ctx)
	hero_assets = HeroAssets.new()
	add_child(hero_assets)
	hero_assets.setup(ctx)
	var companion_body := CompanionBody.new()
	add_child(companion_body)
	companion_body.setup(ctx)
	title_stage = TitleStage.new()
	add_child(title_stage)
	title_stage.setup(ctx)
	var layer := CanvasLayer.new()
	layer.name = "CodexBannerLayer"
	layer.layer = 40
	add_child(layer)
	banner = CodexBanner.new()
	layer.add_child(banner)
	var codex = ctx.get("codex")
	if ctx.tuning != null and ctx.tuning.option(Tuning.DISCOVERY_KEY) == "cards" and codex != null:
		banner.cards = true
		banner.storage_dir = codex.storage_dir
	ceremony = RewardCeremony.new()
	add_child(ceremony)
	ceremony.setup(ctx, audio, juice, vfx)
	panel_fx = PanelFx.new()
	add_child(panel_fx)
	panel_fx.setup(ctx, audio, machine_fx)
	wire_optional()
	GraphicsPreset.register_dressing_host(self)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		_ring_warden.call_deferred(enemy)
		_read_windups(enemy)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_script() == WardenScript or (node.get("role") == "hull" and node.get("boss") != null):
		_ring_warden.call_deferred(node)
	if node.has_signal("attack_phase"):
		_read_windups.call_deferred(node)


var _boils_wired := false


func _read_windups(enemy) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if not enemy.has_signal("attack_phase") or not enemy.has_method("attack_facts"):
		return
	var listener := _on_windup_phase.bind(enemy)
	if not enemy.is_connected("attack_phase", listener):
		enemy.connect("attack_phase", listener)
		_on_windup_phase(enemy.attack_facts(), enemy)
	if enemy.has_signal("pressure_cue") and not enemy.is_connected("pressure_cue", _on_pressure_cue):
		enemy.connect("pressure_cue", _on_pressure_cue)


# Pack pressure cues (combat/pack_pressure.gd, world 1 experiments): a flanker's whistle and a silt boil's
# rumble, each sounding before its committed telegraph, with a chevron over the caller.
func _on_pressure_cue(cue: String, at: Vector3, seconds_until: float) -> void:
	vfx.glyph("enemy_spawned", at + Vector3.UP * 2.5, 1.0, 1.0, seconds_until, Vector3.ZERO,
		"chevron", EventKinds.role_color("hazard"), "P1")
	audio.play("threat_projectile", 0.0, 1.0, "SFX", cue)


func _on_windup_phase(facts: Dictionary, enemy: Node) -> void:
	if facts.get("phase", "") != "windup":
		return
	_show_windup(enemy, facts)


func _show_windup(enemy: Node, facts: Dictionary) -> void:
	var cue := WindupRows.row(String(enemy.get("kind")), enemy, String(facts.row))
	if cue.is_empty() or cue.phase == "none":
		return
	var remaining: float = cue.lead_seconds * (1.0 - clampf(float(facts.get("progress", 0.0)), 0.0, 1.0))
	if remaining <= 0.0:
		return
	vfx.glyph("enemy_spawned", facts.at, 1.0, 1.0, remaining, Vector3.ZERO,
		cue.shape, EventKinds.role_color(cue.color_role), "P1")
	if cue.sound != EventKinds.NONE:
		audio.play("threat_projectile", 0.0, 1.0, "SFX", cue.sound)


func _physics_process(_delta: float) -> void:
	if ctx == null or not ctx.flow.in_play():
		_windup_states.clear()
		return
	if not _boils_wired and ctx.spawner != null and ctx.spawner.get("boils") != null:
		_boils_wired = true
		ctx.spawner.boils.rumbled.connect(func(at: Vector3, seconds_until: float): _on_pressure_cue("boil_rumble", at, seconds_until))
	var active := {}
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.get("kind") not in ["warden", "swarm_remnant"] or not enemy.has_method("is_dead") or enemy.is_dead():
			continue
		for facts in WindupRows.state_facts(enemy):
			var key := "%d:%s" % [enemy.get_instance_id(), facts.row]
			active[key] = true
			if not _windup_states.has(key):
				_show_windup(enemy, facts)
	_windup_states = active


# One ring per posture Warden, a child of it so it is freed with it; a plating Warden has none.
func _ring_warden(warden: Node) -> void:
	if not is_instance_valid(warden) or not warden.is_inside_tree():
		return
	if warden.get_script() != WardenScript and not (warden.get("role") == "hull" and warden.get("boss") != null):
		return
	if warden.fight() != "posture" or warden.has_node("WardenRing"):
		return
	var ring := WardenRing.new()
	warden.add_child(ring)
	ring.bind(warden)


# Connects the demo-spec signals the bus has now. Safe to call again after the spine
# (or a test) adds more.
func wire_optional() -> void:
	audio.wire_optional()
	juice.wire_optional()
	vfx.wire_optional()
	var events = ctx.events
	if not events.is_connected("enemy_spawned", _on_enemy_windups):
		events.connect("enemy_spawned", _on_enemy_windups)
	if events.has_signal("synergy_discovered") and not events.is_connected("synergy_discovered", _on_synergy):
		events.connect("synergy_discovered", _on_synergy)
	if events.has_signal("part_gained") and not events.is_connected("part_gained", _on_part):
		events.connect("part_gained", _on_part)
	# The banner never outlives the moment: a flow change, arena entry, death or the
	# run's end clears it at once.
	for signal_name in ["stage_content_cleared", "player_died", "run_ended"]:
		if events.has_signal(signal_name) and not _dismiss_wired.has(signal_name):
			_dismiss_wired[signal_name] = true
			var argc := _argc(events, signal_name)
			events.connect(signal_name, _dismiss_banner.unbind(argc) if argc > 0 else _dismiss_banner)
	if not events.is_connected("flow_changed", _on_flow_changed):
		events.connect("flow_changed", _on_flow_changed)


func _on_enemy_windups(enemy: Node3D, _kind: String) -> void:
	_read_windups(enemy)


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
	# A repeat draws nothing in either mode: cards mode drops it on the seen record,
	# banner mode has no record, so it stops here.
	if not auto_banner or (not first_time and not banner.cards):
		return
	var entry := _codex_entry(id)
	var title: String = entry.get("name", id.capitalize())
	banner.show_discovery(title, category, String(entry.get("text", "")), "New synergy" if first_time else "Synergy", id, "synergy_discovered")


# In cards mode a first-found part is queued as a banner card behind the shared find gate; a
# repeat is dropped there and draws nothing.
func _on_part(part_id: String, _source: String) -> void:
	if not auto_banner or not banner.cards:
		return
	var row := Parts.row(part_id)
	var title: String = row.get("name", part_id.capitalize())
	banner.show_discovery(title, "part", String(row.get("text", "")), "Found", "part:" + part_id, "part_gained")


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


# Capture switch: hides the game's screen-space UI, the Moss bubble and the world prompts (Labels
# parented to world anchors, outside every CanvasLayer) and stops them redrawing themselves.
# One way; look_harness.gd flips it before a frame, the game is not played after.
func hide_ui() -> void:
	ui_hidden = true
	var scope: Node = ctx.root if ctx != null and ctx.root != null else self
	for node in scope.find_children("*", "CanvasLayer", true, false):
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scope.find_children("*", "Control", true, false):
		node.visible = false
		node.process_mode = Node.PROCESS_MODE_DISABLED
	for node in scope.find_children("*", "Label3D", true, false):
		node.visible = false


func _sync_dressing() -> void:
	if is_instance_valid(set_dressing):
		set_dressing.free()
	set_dressing = null
	# Park prop dressing is on for every park whatever the set-dressing preset flag says (it ranges itself down).
	if is_instance_valid(park_props):
		park_props.free()
	park_props = ParkProps.new()
	add_child(park_props)
	park_props.setup(ctx)
	if is_instance_valid(ambient_life):
		ambient_life.free()
	ambient_life = null
	var spec: Dictionary = GraphicsPreset.PRESETS[GraphicsPreset.current]
	if spec.get("set_dressing", false):
		ambient_life = AmbientLife.new()
		add_child(ambient_life)
		ambient_life.setup(ctx)
	if spec.get("set_dressing", false) or spec.get("air_motes", false) or spec.get("air_streaks", false):
		set_dressing = SetDressing.new()
		add_child(set_dressing)
		set_dressing.setup(ctx)
