extends Node

const Audio := preload("res://src/presentation/audio.gd")
const Juice := preload("res://src/presentation/juice.gd")
const Vfx := preload("res://src/presentation/vfx.gd")
const MachineFx := preload("res://src/presentation/machine_fx.gd")
const PlayerFx := preload("res://src/presentation/player_fx.gd")
const CodexStyle := preload("res://src/presentation/codex_style.gd")
const CodexBanner := preload("res://src/presentation/codex_banner.gd")
const LineView := preload("res://src/presentation/line_view.gd")
const GrappleRig := preload("res://src/presentation/grapple_rig.gd")
const StatusMarks := preload("res://src/presentation/status_marks.gd")
const ArmourMarks := preload("res://src/presentation/armour_marks.gd")
const HeroAssets := preload("res://src/presentation/hero_assets.gd")
const CompanionBody := preload("res://src/presentation/companion_body.gd")
const TitleStage := preload("res://src/presentation/title_stage.gd")
const WardenRing := preload("res://src/presentation/warden_ring.gd")
const WardenScript := preload("res://src/combat/warden.gd")
const RewardCeremony := preload("res://src/presentation/reward_ceremony.gd")
const FlourishPlayer := preload("res://src/presentation/flourish_player.gd")
const SpillwayStory := preload("res://src/presentation/spillway_story.gd")
const FlourishCues := preload("res://src/presentation/flourish_cues.gd")
const Tuning := preload("res://src/movement/tuning.gd")
const GraphicsPreset := preload("res://src/presentation/graphics_preset.gd")
const SetDressing := preload("res://src/presentation/set_dressing.gd")
const ParkProps := preload("res://src/presentation/park_props.gd")
const AmbientLife := preload("res://src/presentation/ambient_life.gd")
const WorkMachines := preload("res://src/presentation/work_machines.gd")
const SiteMarkers := preload("res://src/presentation/site_markers.gd")
const ConduitCable := preload("res://src/presentation/conduit_cable.gd")
const Parts := preload("res://src/build/parts.gd")
const WindupRows := preload("res://src/presentation/windup_rows.gd")
const EventKinds := preload("res://src/core/event_kinds.gd")
const PanelFx := preload("res://src/presentation/panel_fx.gd")
const W50AssetHooks := preload("res://src/presentation/w50_asset_hooks.gd")


var ctx
var audio
var juice
var vfx
var machine_fx
var player_fx
var line_view
var grapple_rig
var status_marks
var armour_marks
var banner
var hero_assets
var ceremony
var panel_fx
var flourish
var spillway_story
var flourish_cues
var set_dressing: Node3D
var park_props: Node3D
var ambient_life: Node3D
var work_machines: Node3D
var site_markers: Node3D
var conduit_cable: Node3D
var w50_assets: Node3D
var title_stage: Node
var ui_hidden := false
var auto_banner := true
var _dismiss_wired := {}
var _impulse_wired := {}
var _windup_states := {}
const BANNER_SCREENS := ["title", "class_select", "summary", "dead", "victory"]
const SET_KEY := "set:"
const PILOT_IMPULSE_EVENTS := ["player_hit", "shot_fired", "boss_defeated"]


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
	machine_fx.kill_mark = vfx.kill_mark
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
	armour_marks.setup(ctx, player_fx)
	hero_assets = HeroAssets.new()
	add_child(hero_assets)
	hero_assets.setup(ctx)
	grapple_rig = GrappleRig.new()
	add_child(grapple_rig)
	grapple_rig.setup(ctx, hero_assets, line_view)
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
	banner.came_up.connect(_on_banner_up)
	var codex = ctx.get("codex")
	if ctx.tuning != null and ctx.tuning.option(Tuning.DISCOVERY_KEY) == "cards" and codex != null:
		banner.cards = true
		banner.storage_dir = codex.storage_dir
	ceremony = RewardCeremony.new()
	add_child(ceremony)
	ceremony.setup(ctx, audio, juice, vfx)
	panel_fx = PanelFx.new()
	add_child(panel_fx)
	panel_fx.setup(ctx, audio)
	flourish = FlourishPlayer.new()
	add_child(flourish)
	flourish.setup(ctx)
	spillway_story = SpillwayStory.new()
	add_child(spillway_story)
	spillway_story.setup(ctx, flourish)
	flourish_cues = FlourishCues.new()
	add_child(flourish_cues)
	flourish_cues.setup(ctx, flourish)
	site_markers = SiteMarkers.new()
	add_child(site_markers)
	site_markers.setup(ctx)
	conduit_cable = ConduitCable.new()
	add_child(conduit_cable)
	conduit_cable.setup(ctx, site_markers)
	w50_assets = W50AssetHooks.new()
	add_child(w50_assets)
	w50_assets.setup(ctx)
	wire_optional()
	GraphicsPreset.register_dressing_host(self)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		_ring_warden.call_deferred(enemy)
		_read_windups(enemy)


func reading() -> bool:
	return flourish != null and flourish.reading()


func close_up() -> bool:
	return flourish != null and flourish.close_up()


func names_boss() -> bool:
	return flourish_cues != null and flourish_cues.names_boss()


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node.get_script() == WardenScript or (node.get("role") == "hull" and node.get("boss") != null):
		_ring_warden.call_deferred(node)
	if node.has_signal("attack_phase"):
		_read_windups.call_deferred(node)


var _boils_wired := false
var _boil_marker := {}
var _boil_marker_at := Vector3.ZERO


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


func _on_pressure_cue(cue: String, at: Vector3, seconds_until: float) -> Dictionary:
	var marker: Dictionary = vfx.glyph("enemy_spawned", at + Vector3.UP * 2.5, 1.0, 1.0, seconds_until, Vector3.ZERO,
		"chevron", EventKinds.role_color("hazard"), "P1")
	audio.play("threat_projectile", 0.0, 1.0, "SFX", cue)
	return marker


func _on_boil_rumbled(at: Vector3, seconds_until: float) -> void:
	_boil_marker = _on_pressure_cue("boil_rumble", at, seconds_until)
	_boil_marker_at = at + Vector3.UP * 2.5


func _on_boil_quelled(_at: Vector3) -> void:
	vfx.end_glyph(_boil_marker, _boil_marker_at)
	_boil_marker = {}
	audio.stop("boil_rumble")


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
		ctx.spawner.boils.rumbled.connect(_on_boil_rumbled)
		ctx.spawner.boils.quelled.connect(_on_boil_quelled)
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
	var build = ctx.get("build")
	if build != null and build.has_signal("set_completed") and not build.set_completed.is_connected(_on_set_completed):
		build.set_completed.connect(_on_set_completed)
	for signal_name in ["stage_content_cleared", "player_died", "run_ended"]:
		if events.has_signal(signal_name) and not _dismiss_wired.has(signal_name):
			_dismiss_wired[signal_name] = true
			var argc := SignalWire.arg_count(events, signal_name)
			events.connect(signal_name, _dismiss_banner.unbind(argc) if argc > 0 else _dismiss_banner)
	if not events.is_connected("flow_changed", _on_flow_changed):
		events.connect("flow_changed", _on_flow_changed)
	for signal_name in PILOT_IMPULSE_EVENTS:
		if events.has_signal(signal_name) and not _impulse_wired.has(signal_name):
			_impulse_wired[signal_name] = true
			var argc := SignalWire.arg_count(events, signal_name)
			var impulse: Callable = hero_assets.pilot_impulse.bind(signal_name)
			events.connect(signal_name, impulse.unbind(argc) if argc > 0 else impulse)


func _on_enemy_windups(enemy: Node3D, _kind: String) -> void:
	_read_windups(enemy)


func _dismiss_banner() -> void:
	banner.dismiss(true)


func _on_flow_changed(state: String) -> void:
	banner.dismiss(state in BANNER_SCREENS)
	if not state in BANNER_SCREENS:
		banner._next()


func codex_style() -> Dictionary:
	return CodexStyle.style()


func _on_synergy(id: String, category: String, first_time: bool) -> void:
	if not auto_banner or (not first_time and not banner.cards):
		return
	var entry := _codex_entry(id)
	var title: String = entry.get("name", id.capitalize())
	banner.show_discovery(title, category, String(entry.get("text", "")), "New synergy" if first_time else "Synergy", id, "synergy_discovered")


func _on_part(part_id: String, _source: String) -> void:
	if not auto_banner or not banner.cards:
		return
	var words := part_card(part_id)
	banner.show_discovery(words["title"], "part", words["detail"], "Found", RewardCeremony.FIND_CARD + part_id, "part_gained")


static func part_card(part_id: String) -> Dictionary:
	var row := Parts.row(part_id)
	return {"title": String(row.get("name", Parts.display_name(part_id))),
		"detail": String(row.get("text", Parts.token(part_id).get("verb", "")))}


func _on_set_completed(set_id: String, title: String, text: String, color: Color) -> void:
	if auto_banner:
		banner.show_discovery(title, "build", text, "Set complete", SET_KEY + set_id, "synergy_discovered", color, true)


func _on_banner_up(key: String) -> void:
	var build = ctx.get("build")
	if key.begins_with(SET_KEY) and build != null:
		audio.set_complete(build.set_element(key.trim_prefix(SET_KEY)))


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
	if is_instance_valid(park_props):
		park_props.free()
	park_props = ParkProps.new()
	add_child(park_props)
	park_props.setup(ctx)
	park_props.prop_kicked.connect(juice.on_prop_kicked)
	if not is_instance_valid(work_machines):
		work_machines = WorkMachines.new()
		add_child(work_machines)
		work_machines.setup(ctx)
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
