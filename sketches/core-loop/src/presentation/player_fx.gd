extends Node

const Palette := preload("res://src/core/palette.gd")
const Parts := preload("res://src/build/parts.gd")
const SpeedTier := preload("res://src/movement/speed_tier.gd")
const Density := preload("res://src/presentation/density.gd")
const FxLibrary := preload("res://src/presentation/fx_library.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")
const DamageNumbers := preload("res://src/presentation/damage_numbers.gd")
const Threat := preload("res://src/combat/threat_grammar.gd")
const Redline := preload("res://src/combat/redline.gd")
const ChargeHalo := preload("res://src/presentation/charge_halo.gd")
const Pattern := preload("res://src/combat/pattern.gd")
const ImpactFrame := preload("res://src/presentation/impact_frame.gd")
const PauseGuard := preload("res://src/presentation/pause_guard.gd")
const Particles := preload("res://src/presentation/player_fx_particles.gd")


const SOFT_CAP_MPS := 60.0
const SOFT_CAP_OFF_MPS := 54.0
const HEAT_RISE_S := 0.15
const HEAT_FALL_S := 0.4
const CARVE_NORMAL_Y := 0.82
const MOTES := 12
const MOTE_RADIUS := 1.65
const ELEMENT_COLORS := {"frost": Palette.ICE, "arc": Palette.ARC, "kinetic": Palette.SAND}
const HEAT_SHARE := 0.85
const INK := Palette.INK_DEEP

const RENDER_PRIORITY := -4

const MIGHT_TIERS := ["small", "rising", "grown", "mighty"]

const WORDS := {
	"smash": {"text": "KLANG", "size": 0.9},
	"slam": {"text": "WHUMP", "size": 0.9},
	"landing": {"text": "KRUNCH", "size": 0.7},
	"launch": {"text": "FWOOSH", "size": 0.8},
	"rocket": {"text": "KA-BOOM", "size": 1.0},
	"vault": {"text": "BOING", "size": 0.7},
	"ignite": {"text": "VRAAAM", "size": 0.85},
	"heft_up": {"text": "KACHUNK", "size": 1.0},
	"fused": {"text": "FUSED", "size": 1.0},
	"ultimate": {"text": "KRA-KOOM", "size": 1.3},
	"paid": {"text": "SHORT", "size": 0.9},
	"wham": {"text": "WHAM", "size": 1.0},
	"strike": {"text": "STRIKE", "size": 1.1},
	"beat": {"text": "BWAP", "size": 0.64},
	"redline": {"text": "KA-BLAM", "size": 1.2},
}
const ONBEAT_GROW := 1.4
const READ_SIZE := 0.8
const STACK_LOW := 1.8
const STACK_TOP := 3.8
const STACK_HALF := 1.8
const WORD_FONT_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
const WORD_SCREEN := 0.075
const WORD_SAFE := Vector2(0.78, 0.7)
const LAUNCH_KINDS := ["ram", "slam"]
const CONTACT_KINDS := ["ram", "slam", "stomp"]
const STRIKE_PINS := 3
const STRIKE_WINDOW_S := 0.6

const PILOT_WORDS := {
	"pylon_engineer": {"launch": "ZWOOSH"},
	"runner_gunner": {"smash": "PING"},
	"demolitions_caster": {"slam": "BOOM", "rocket": "BOOM"},
	"tarn": {"smash": "GRRAK", "slam": "KRASH"},
	"tally": {"smash": "KA-CHUNK"},
	"remembered_cannon": {"launch": "KA-THOOM", "smash": "THOOM"},
}
const WORD_POOL := 4
const WORDS_ALIVE := 2
const WORD_GAP_S := 0.35
const WORD_REPEAT_S := 1.2
const BEAT_REPEAT_S := 4.0
const WORD_WARNING_GAP := 24.0
const FOE_REACH_M := 25.0
const FOE_MIN_PX := 24.0
const SPOT_BESIDE := 0.32
const SPOT_DROP := 0.22
const MARKS_GROUP := "foe_marks"
const KEEP_GROUP := "word_keep_clear"
const ROOM_GROUP := "word_room"
static var rect_tests := 0


static func reset_for_tests() -> void:
	rect_tests = 0
const WORD_LIFE := 0.6
const WORD_STAMP_S := 0.1
const WORD_EXIT_S := 0.2
const SMASH_WORD_MPS := [22.0, 12.0]
const SMASH_FRAME_MPS := [32.0, 18.0]
const FRAME_GAP_S := 0.6
const NEAR_EPSILON := 0.01

const FLECKS := 96
const EMBERS := 64
const CARVE := 64
const COLUMN := 48
const COLUMN_POOL := 2
const BOON := 40
const BOON_POOL := 3

var ctx
var player
var camera
var vfx
var root: Node3D
var _word_root: Node3D
var reduced_motion := false
var spawned := {}

var might := 0.0
var pose := {}
var overdrive := false
var heat := 0.0
var _evolutions := 0
var _clock := 0.0
var _warn_frame := -1
var _warn_rects: Array[Rect2] = []
var _fight_frame := -1
var _fight_cache: Array[Rect2] = []
var _fight_kind: Array[String] = []
var _rng := RandomNumberGenerator.new()
var _font: Font
var _words: Array = []
var _last_word := -1.0e9
var _word_seen := {}
var _side := 1.0
var _aura: MultiMeshInstance3D
var _mote_colors: Array = []
var _mote_flare := 0.0
var _mote_arrive := {}
var _rim: MeshInstance3D
var _rim_mat: ShaderMaterial
var _flecks: GPUParticles3D
var _embers: GPUParticles3D
var _carve: GPUParticles3D
var _columns: Array = []
var _column_next := 0
var _boons: Array = []
var _boon_next := 0
var _last_boon := -1.0e9
var _frame: Control
var _last_frame := -1.0e9
var _kill_times: Array = []
const MIGHT_REFRESH_S := 0.25
var _might_wait := 0.0
var _pin_times: Array = []


var _dunk_glow: MeshInstance3D


func setup(ctx_ref, vfx_ref = null) -> void:
	ctx = ctx_ref
	vfx = vfx_ref
	name = "PlayerFx"
	add_to_group(ROOM_GROUP)
	player = ctx.player
	camera = ctx.camera
	_rng.seed = 1717
	root = Node3D.new()
	root.name = "PlayerFxRoot"
	ctx.root.add_child(root)
	_word_root = Node3D.new()
	_word_root.name = "Words"
	root.add_child(_word_root)
	var pause_guard := PauseGuard.new()
	pause_guard.root = _word_root
	add_child(pause_guard)
	_font = word_font()
	for i in WORD_POOL:
		_words.append(_make_word())
	_build_aura()
	_build_dunk_glow()
	_build_rim()
	_build_rivet_fire()
	_flecks = _emitter(Particles.flecks_material(), Particles.box(Vector3(0.12, 0.12, 0.55)), FLECKS, 0.35, "add", false)
	_flecks.name = "OverdriveFlecks"
	_embers = _emitter(Particles.embers_material(), Particles.ball(0.16), EMBERS, 0.9, "add", false)
	_embers.name = "OverdriveEmbers"
	_carve = _emitter(Particles.carve_material(), Particles.box(Vector3(0.05, 0.05, 0.4)), CARVE, 0.28, "add", false)
	_carve.name = "CarveSparks"
	for i in COLUMN_POOL:
		var c := _emitter(Particles.column_material(), Particles.box(Vector3(0.07, 0.6, 0.07)), COLUMN, 0.8, "add", true)
		c.name = "PowerColumn_%d" % i
		_columns.append(c)
	for i in BOON_POOL:
		var b := _emitter(Particles.boon_material(), Particles.box(Vector3.ONE * 0.16), BOON, 0.3, "add", true)
		b.name = "BoonSparks_%d" % i
		_boons.append(b)
	var layer := CanvasLayer.new()
	layer.name = "ImpactFrameLayer"
	layer.layer = 3
	add_child(layer)
	_frame = ImpactFrame.new()
	_frame.rect_source = func() -> Array[Rect2]:
		return warning_rects(get_tree(), camera.cam if camera != null else null, 0.0)
	layer.add_child(_frame)
	_wire()


const DUNK_RADIUS := 1.06
const DUNK_ARC := deg_to_rad(140.0)
const DUNK_TUBE := 0.08
const DUNK_INK := 0.0
const DUNK_PIPS := 3
const DUNK_PIP_RADIUS := 0.11
const DUNK_EMISSION := 1.1
const DUNK_PIP_EMISSION := 1.5
const DUNK_BASE := 0.35
const DUNK_HOLD_SPEED := 1.5

var _dunk_coil: StandardMaterial3D
var _dunk_pips: Array[StandardMaterial3D] = []
var _dunk_pip_lit: Array[bool] = []
var _dunk_yaw := 0.0


func _build_dunk_glow() -> void:
	_dunk_coil = _dunk_emissive()
	_dunk_glow = MeshInstance3D.new()
	_dunk_glow.name = "DunkGlow"
	_dunk_glow.set_meta("no_ink", true)
	_dunk_glow.mesh = _dunk_arc_mesh(_dunk_coil, DUNK_TUBE)
	_dunk_glow.top_level = true
	_dunk_glow.visible = false
	_dunk_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_dunk_glow)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = DUNK_PIP_RADIUS
	pip_mesh.height = DUNK_PIP_RADIUS * 2.0
	pip_mesh.radial_segments = 10
	pip_mesh.rings = 5
	for i in DUNK_PIPS:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.set_meta("no_ink", true)
		pip.mesh = pip_mesh
		var mat := _dunk_emissive()
		pip.material_override = mat
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.position = _dunk_arc_point(_dunk_pip_angle(i), DUNK_RADIUS + DUNK_TUBE * 0.5) + Vector3.UP * (DUNK_TUBE + DUNK_PIP_RADIUS * 0.4)
		_dunk_glow.add_child(pip)
		_dunk_pips.append(mat)
		_dunk_pip_lit.append(false)


func _dunk_emissive() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.set_meta("no_ink", true)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.roughness = 0.4
	mat.render_priority = RENDER_PRIORITY
	return mat


static func _dunk_pip_angle(i: int) -> float:
	return DUNK_ARC * ((float(i) + 0.5) / float(DUNK_PIPS) - 0.5)


static func _dunk_arc_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)


static func _dunk_arc_mesh(material: Material, tube: float) -> ArrayMesh:
	const SEGMENTS := 24
	const SIDES := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in SEGMENTS:
		for k in SIDES:
			var quad: Array[Vector3] = []
			var normals: Array[Vector3] = []
			for corner in [[s, k], [s, k + 1], [s + 1, k + 1], [s + 1, k]]:
				var a: float = DUNK_ARC * (float(corner[0]) / SEGMENTS - 0.5)
				var b: float = TAU * float(corner[1]) / SIDES
				var centre := _dunk_arc_point(a, DUNK_RADIUS)
				var out := _dunk_arc_point(a, 1.0) * cos(b) + Vector3.UP * sin(b)
				quad.append(centre + out * tube)
				normals.append(out)
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_normal(normals[j])
				st.add_vertex(quad[j])
	st.set_material(material)
	return st.commit()


func dunk_glow_shown() -> bool:
	return _dunk_glow != null and _dunk_glow.visible


func dunk_pips_lit() -> int:
	return _dunk_pip_lit.count(true) if dunk_glow_shown() else 0


func dunk_glow_color() -> Color:
	if _dunk_coil == null:
		return Color.BLACK
	var c: Color = _dunk_coil.emission
	return Color(c.r, c.g, c.b)


func _draw_dunk_glow() -> void:
	var dunk = player.get("dunk")
	if _dunk_glow == null or dunk == null or not dunk.held():
		if _dunk_glow != null:
			_dunk_glow.visible = false
		return
	var record: Dictionary = dunk.charge
	var share := clampf(dunk.left() / dunk.WINDOW, 0.0, 1.0)
	var pulse := 0.5 + 0.5 * sin(_clock * TAU * FlashGuard.rate(1.0 + 1.5 * (1.0 - share)))
	var colour: Color = record["color"]
	_dunk_coil.albedo_color = Color(colour.r, colour.g, colour.b, 0.78)
	_dunk_coil.emission = colour
	_dunk_coil.emission_energy_multiplier = FlashGuard.spike(DUNK_EMISSION, DUNK_EMISSION * (1.0 + 0.6 * pulse))
	var lit := ceili(share * DUNK_PIPS)
	for i in _dunk_pips.size():
		var burning := i < lit
		_dunk_pip_lit[i] = burning
		_dunk_pips[i].albedo_color = Color(colour.r, colour.g, colour.b, 0.88) if burning else Color(INK.r, INK.g, INK.b, 0.35)
		_dunk_pips[i].emission = colour if burning else Color.BLACK
		_dunk_pips[i].emission_energy_multiplier = DUNK_PIP_EMISSION if burning else 0.0
	var v: Vector3 = _velocity()
	if Vector2(v.x, v.z).length() >= DUNK_HOLD_SPEED:
		_dunk_yaw = atan2(-v.x, -v.z)
	_dunk_glow.global_transform = Transform3D(Basis(Vector3.UP, _dunk_yaw), player.shown_position())
	_dunk_glow.visible = true


static func might_from(heft_class: int, parts: int, synergies: int, evolutions: int, picks := 0) -> float:
	return clampf(0.3 * clampf((heft_class - 1) / 4.0, 0.0, 1.0) + 0.3 * minf(parts, 8) / 8.0
		+ 0.2 * minf(picks, 4) / 4.0 + 0.1 * minf(synergies, 4) / 4.0 + 0.1 * minf(evolutions, 3) / 3.0, 0.0, 1.0)


static func might_tier(value: float) -> int:
	return clampi(int(value * 4.0), 0, 3)


func refresh_might() -> void:
	var run = ctx.run
	var heft_class: int = run.heft_class() if run != null and run.has_method("heft_class") else 1
	var parts: Array = run.parts if run != null else []
	var synergies: int = vfx.ring_count() if vfx != null else 0
	var picks := 0
	if player.get("tree") != null and player.tree.has_method("path"):
		picks = player.tree.path().size()
	might = might_from(heft_class, parts.size(), synergies, _evolutions, picks)
	if vfx != null and "might" in vfx:
		vfx.might = might
		vfx.heat = HEAT_SHARE * heat_k(might)
	_mote_colors.clear()
	for id in parts:
		if _mote_colors.size() >= MOTES:
			break
		_mote_colors.append(part_color(String(id)))


static func part_color(part_id: String) -> Color:
	var row := Parts.row(part_id)
	var element := String(row.get("element", "kinetic"))
	var color: Color = ELEMENT_COLORS.get(element, Palette.SAND)
	if String(row.get("rarity", "")) in ["rare", "relic"]:
		color = color.lerp(Color.WHITE, 0.25)
	return color


static func heat_k(value: float) -> float:
	return clampf((value - 0.1) / 0.6, 0.0, 1.0)


func heat_tint(color: Color) -> Color:
	return color.lerp(ImpactFrame.HEAT_COLOR, HEAT_SHARE * heat_k(might))


func dominant_color() -> Color:
	var counts := {}
	var best := Palette.SAND
	var most := 0
	for c in _mote_colors:
		counts[c] = counts.get(c, 0) + 1
		if counts[c] > most:
			most = counts[c]
			best = c
	return best


func _wire() -> void:
	var events = ctx.events
	events.run_started.connect(func(_class_id: String):
		_evolutions = 0
		_mote_arrive.clear()
		refresh_might())
	events.part_gained.connect(func(id: String, _source: String):
		_mote_arrive[min(ctx.run.parts.size() - 1, MOTES - 1) if ctx.run != null else 0] = 0.0
		refresh_might())
	events.heft_class_changed.connect(_on_heft_up)
	SignalWire.listen(events, "heft_class_dropped", func(_c: int, _h: float): refresh_might())
	SignalWire.listen(events, "synergy_discovered", func(_id: String, _cat: String, _first: bool): refresh_might.call_deferred())
	SignalWire.listen(events, "evolution_fired", _on_evolution)
	events.enemy_struck.connect(_on_struck)
	events.harpoon_smashed.connect(_on_smashed)
	events.slammed.connect(_on_slammed)
	events.landed.connect(func(impact: float):
		if impact >= 24.0:
			word("landing", _beside_ball()))
	events.launched.connect(func(_v: Vector3): word("launch", _beside_ball()))
	SignalWire.listen(events, "rocket_jumped", func(at: Vector3, _speed: float): word("rocket", at + Vector3.UP * 1.8))
	SignalWire.listen(events, "vault_kicked", func(at: Vector3, _speed: float): word("vault", at + Vector3.UP * 1.6))
	SignalWire.listen(events, "ultimate_landed", func(_id: String, at: Vector3, hits: int, _dmg: float):
		if hits > 0:
			word("ultimate", at + Vector3.UP * 2.0)
			impact_frame(at, 1.0))
	events.enemy_killed.connect(_on_killed)
	SignalWire.listen(events, "enemy_pinned", _on_pinned)
	events.stage_entered.connect(func(_stage: int, _retry: bool): clear())
	_wire_weapon()
	_wire_redline()
	events.world_fact.connect(func(kind: String, at: Vector3):
		if kind == "call_met":
			impact_frame(at, 1.0))


func _pilot_id() -> String:
	return String(player.class_def.id) if player.class_def != null else ""


func _on_heft_up(heft_class: int, _heft: float) -> void:
	var before := might
	refresh_might()
	if might > before and heft_class > 1:
		column(Palette.BRASS)
		word("heft_up", _beside_ball())


func _on_evolution(part_id: String) -> void:
	_evolutions += 1
	refresh_might()
	column(part_color(part_id).lerp(Palette.BRASS, 0.4))
	word("fused", _beside_ball())


func _on_struck(enemy: Node3D, kind: String, _force: float) -> void:
	_mote_flare = 1.0
	if kind in LAUNCH_KINDS and _tier() >= SpeedTier.BLAZING and is_instance_valid(enemy) and enemy.is_inside_tree():
		word("wham", enemy.global_position + Vector3.UP * 1.8, Color.TRANSPARENT, enemy)
		impact_frame(enemy.global_position, clampf(0.6 + 0.4 * might, 0.0, 1.0))
	elif kind in CONTACT_KINDS and might_tier(might) >= 2 and is_instance_valid(enemy) and enemy.is_inside_tree():
		impact_frame(enemy.global_position, 0.4 + 0.4 * might)
	if _mote_colors.is_empty() or might < 0.25 or _clock - _last_boon < 0.06:
		return
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	_boon(enemy.global_position + Vector3.UP * 0.7)


func _boon(at: Vector3) -> void:
	if Density.live().band()["max"] > 0.7:
		return
	_last_boon = _clock
	var p: GPUParticles3D = _boons[_boon_next]
	_boon_next = (_boon_next + 1) % _boons.size()
	var pm := p.process_material as ParticleProcessMaterial
	FxLibrary.fire(p, "", "", boon_count(might), at, Particles.glow(heat_tint(dominant_color()), 1.1 + 0.7 * heat_k(might)))
	spawned["boon"] = spawned.get("boon", 0) + 1


func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.5:
		return
	word("slam", at + Vector3.UP * 1.6)
	if might >= 0.25 and not _mote_colors.is_empty():
		_boon(at + Vector3.UP * 0.4)
	if might_tier(might) >= 2:
		impact_frame(at, clampf(0.5 + 0.5 * might, 0.0, 1.0))


static func boon_count(value: float) -> int:
	return int(round(BOON * clampf(value, 0.0, 1.0)))


func _on_smashed(enemy: Node3D, at: Vector3, speed: float) -> void:
	if speed >= lerpf(SMASH_WORD_MPS[0], SMASH_WORD_MPS[1], might):
		word("smash", at + Vector3.UP * 1.8, Color.TRANSPARENT, enemy)
	if speed >= lerpf(SMASH_FRAME_MPS[0], SMASH_FRAME_MPS[1], might):
		impact_frame(at, clampf(0.6 + might * 0.4, 0.0, 1.0))


func _on_pinned(victim: Node3D, _damage: float) -> void:
	_pin_times.append(_clock)
	while not _pin_times.is_empty() and _clock - float(_pin_times[0]) > STRIKE_WINDOW_S:
		_pin_times.pop_front()
	if _pin_times.size() == STRIKE_PINS and is_instance_valid(victim) and victim.is_inside_tree():
		word("strike", victim.global_position + Vector3.UP * 2.0, Palette.BRASS, victim)
		impact_frame(victim.global_position, 0.8)


func on_beat_hit(enemy: Node3D, kind: String) -> void:
	_on_beat_word.call_deferred(enemy, kind, _clock)


# Untyped: Godot rejects a freed instance for a typed parameter before is_instance_valid() runs.
func _on_beat_word(enemy, _kind: String, at_clock: float) -> void:
	spawned["on_beat"] = spawned.get("on_beat", 0) + 1
	for w in _words:
		if w["t"] < 1.0 and float(w.get("born", -1.0)) >= at_clock and w["id"] != "read":
			var grown: Array[Rect2] = []
			if camera != null and camera.cam != null:
				grown.append(_word_rect(camera.cam, w["at"], float(w["away"]) > 0.0, float(w["width_px"]),
					float(w["size"]) * ONBEAT_GROW, w["node"].pixel_size))
			var around := _fight_rects().duplicate()
			around.append_array(_keep_rects())
			if grown.is_empty() or word_spot(grown, around) == 0:
				w["size"] = float(w["size"]) * ONBEAT_GROW
			return
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	if word("beat", _beside_ball(), Color.TRANSPARENT, enemy):
		_words_by_id("beat")["size"] *= ONBEAT_GROW


func _words_by_id(id: String) -> Dictionary:
	for w in _words:
		if w.get("id", "") == id and w["t"] < 1.0:
			return w
	return {}


func _on_killed(_kind: String, at: Vector3, _scrap: int) -> void:
	if _pilot_id() != "tally":
		return
	_kill_times.append(_clock)
	while not _kill_times.is_empty() and _clock - float(_kill_times[0]) > 0.25:
		_kill_times.pop_front()
	if _kill_times.size() == 2:
		word("paid", at + Vector3.UP * 1.8, Palette.AMBER)


func clear() -> void:
	for w in _words:
		w["t"] = 1.0
		w["node"].visible = false
	overdrive = false
	heat = 0.0
	_kill_times.clear()
	_pin_times.clear()
	if _frame != null:
		_frame.hide_now()
	if _halo != null:
		_halo.stop()
	_halo_spent = false
	for i in FLASHES:
		_end_flash(i)
	if _flashes != null and is_instance_valid(_flashes):
		_flashes.visible = false
	for i in CASINGS:
		_end_casing(i)
	if _casings != null and is_instance_valid(_casings):
		_casings.visible = false


func _make_word() -> Dictionary:
	var label := word_label(_font)
	label.visible = false
	_word_root.add_child(label)
	return {"node": label, "t": 1.0, "id": "", "tilt": 0.0, "size": 1.0, "at": Vector3.ZERO}


static func word_label(font: Font = null) -> Label3D:
	var label := Label3D.new()
	label.name = "SoundWord"
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.double_sided = true
	label.shaded = false
	label.font_size = 96
	label.outline_size = 30
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.outline_modulate = INK
	label.pixel_size = 0.01
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.no_depth_test = true
	label.render_priority = RENDER_PRIORITY
	label.outline_render_priority = RENDER_PRIORITY - 1
	if font != null:
		label.font = font
	return label


static func word_font() -> Font:
	return load(WORD_FONT_PATH) if ResourceLoader.exists(WORD_FONT_PATH) else null


func word_text(id: String) -> String:
	var own: Dictionary = PILOT_WORDS.get(_pilot_id(), {})
	return String(own.get(id, WORDS[id]["text"]))


func words_alive() -> int:
	var n := 0
	for w in _words:
		if w["t"] < 1.0 and w["id"] != "read":
			n += 1
	return n


func candy_room() -> bool:
	var n := words_alive()
	if not is_instance_valid(_machine) and is_inside_tree():
		for other in get_tree().get_nodes_in_group(MARKS_GROUP):
			if other != self and other.has_method("candy_alive"):
				_machine = other
				break
	if is_instance_valid(_machine):
		n += _machine.candy_alive()
	return n < WORDS_ALIVE


func spot_free(r: Rect2) -> bool:
	for k in _keep_rects():
		rect_tests += 1
		if k.intersects(r):
			return false
	return true


var _machine = null
var _keep_frame := -1


func keep_clear_changed() -> void:
	_keep_frame = -1
var _keep_cache: Array[Rect2] = []


func _keep_rects() -> Array[Rect2]:
	var frame := Engine.get_process_frames()
	if frame == _keep_frame:
		return _keep_cache
	_keep_frame = frame
	_keep_cache = []
	if not is_inside_tree():
		return _keep_cache
	for node in get_tree().get_nodes_in_group(KEEP_GROUP):
		if not node.has_method("keep_clear_rects"):
			continue
		for r in node.keep_clear_rects():
			if r.has_area():
				_keep_cache.append(r.grow(WORD_WARNING_GAP))
	return _keep_cache


# Untyped: Godot rejects a freed instance for a typed parameter before validity checks run.
func word(id: String, at: Vector3, color := Color.TRANSPARENT, foe = null) -> bool:
	if not WORDS.has(id) or root == null or not root.is_inside_tree():
		return false
	var repeat := BEAT_REPEAT_S if id == "beat" else WORD_REPEAT_S
	if _clock - _last_word < WORD_GAP_S or _clock - float(_word_seen.get(id, -1.0e9)) < repeat:
		return false
	if not candy_room() or Density.live().band()["max"] > 0.7:
		return false
	var slot := _free_slot()
	var label: Label3D = slot["node"]
	var text := word_text(id)
	var width_px := _text_px(label, text)
	var size := float(WORDS[id]["size"]) * (1.0 + 0.8 * might)
	var placed := clear_of_lane(at)
	var right_of_ball := true
	if camera != null and camera.cam != null:
		var cam: Camera3D = camera.cam
		var side: Vector3 = cam.global_basis.x
		var rel: Vector3 = placed - player.shown_position()
		right_of_ball = rel.dot(side) >= 0.0
		var grow := ONBEAT_GROW if id == "beat" else 1.0
		var spots: Array = [[placed, right_of_ball], [placed - side * 2.0 * rel.dot(side), not right_of_ball]]
		var avoid := _fight_rects().duplicate()
		var kinds := _fight_kind.duplicate()
		for r in _keep_rects():
			avoid.append(r)
			kinds.append("keep")
		var bodies := foe_rects(foe, cam)
		if not bodies.is_empty():
			var whole := bodies[0]
			for r in bodies:
				avoid.append(r.grow(WORD_WARNING_GAP))
				kinds.append("foe")
				whole = whole.merge(r)
			var stack := stack_rect(foe, cam) if _marked(foe) else Rect2()
			if stack.has_area():
				avoid.append(stack.grow(WORD_WARNING_GAP))
				kinds.append("marks")
				whole = whole.merge(stack)
			var tall := size * grow * WORD_SCREEN * cam.get_viewport().get_visible_rect().size.y
			var p := cam.unproject_position(placed)
			var depth := -(cam.global_transform.affine_inverse() * placed).z
			spots.append([cam.project_position(Vector2(p.x, whole.position.y - WORD_WARNING_GAP - tall * 0.6 - 1.0), maxf(depth, cam.near + 0.1)), right_of_ball])
		var ball: Vector3 = player.shown_position()
		var half := _half_height(cam, ball)
		var first_side := 1.0 if right_of_ball else -1.0
		for drop in [0.0, SPOT_DROP, -SPOT_DROP, 2.0 * SPOT_DROP, -2.0 * SPOT_DROP]:
			for sgn in [first_side, -first_side]:
				var near := clear_of_lane(ball + side * half * SPOT_BESIDE * sgn - cam.global_basis.y * half * drop)
				spots.append([near, sgn > 0.0])
		var pick := _pick_spot(cam, spots, width_px, size * grow, label.pixel_size, avoid)
		if pick < 0:
			spawned["word_held"] = spawned.get("word_held", 0) + 1
			var why := _held_by(cam, spots[0], width_px, size * grow, label.pixel_size, avoid, kinds)
			spawned["held_" + why] = spawned.get("held_" + why, 0) + 1
			return false
		placed = spots[pick][0]
		right_of_ball = spots[pick][1]
	_last_word = _clock
	_word_seen[id] = _clock
	_stamp_word(slot, id, text, placed, right_of_ball, width_px, size, color if color.a > 0.0 else heat_tint(_word_color(id)))
	return true


func read_word(text: String, foe: Node3D, color: Color) -> bool:
	if text == "" or root == null or not root.is_inside_tree() or camera == null or camera.cam == null:
		return false
	var cam: Camera3D = camera.cam
	var body := foe_rect(foe, cam)
	if not body.has_area():
		return false
	var slot := _free_slot()
	if slot["t"] < 1.0:
		return false
	var label: Label3D = slot["node"]
	var width_px := _text_px(label, text)
	var tall := READ_SIZE * WORD_SCREEN * cam.get_viewport().get_visible_rect().size.y
	var wide := width_px * label.pixel_size * tall / 0.7
	var gap := WORD_WARNING_GAP + 1.0
	var depth := maxf(-(cam.global_transform.affine_inverse() * foe.global_position).z, cam.near + 0.1)
	var stack := stack_rect(foe, cam)
	var whole := body.merge(stack) if stack.has_area() else body
	var spots: Array = []
	for s in [[Vector2(body.end.x + gap, body.get_center().y), true], [Vector2(body.position.x - gap, body.get_center().y), false],
			[Vector2(whole.get_center().x - wide * 0.5, whole.position.y - gap - tall * 0.6), true]]:
		spots.append([cam.project_position(s[0], depth), s[1]])
	var avoid := _warnings().duplicate()
	avoid.append_array(_keep_rects())
	avoid.append(body.grow(WORD_WARNING_GAP))
	if stack.has_area():
		avoid.append(stack.grow(WORD_WARNING_GAP))
	var pick := _pick_spot(cam, spots, width_px, READ_SIZE, label.pixel_size, avoid)
	if pick < 0:
		spawned["word_held"] = spawned.get("word_held", 0) + 1
		return false
	_stamp_word(slot, "read", text, spots[pick][0], spots[pick][1], width_px, READ_SIZE, color)
	return true


static func stack_rect(foe: Node3D, cam: Camera3D) -> Rect2:
	var low := foe.global_position + Vector3.UP * STACK_LOW
	var high := foe.global_position + Vector3.UP * STACK_TOP
	if cam.is_position_behind(low) or cam.is_position_behind(high):
		return Rect2()
	var side := cam.global_basis.x * STACK_HALF
	var span := Rect2(cam.unproject_position(low), Vector2.ZERO)
	for p in [low - side, low + side, high - side, high + side]:
		span = span.expand(cam.unproject_position(p))
	return span


func _marked(foe) -> bool:
	if foe == null or not is_instance_valid(foe) or get_tree() == null:
		return false
	for owner_node in get_tree().get_nodes_in_group(MARKS_GROUP):
		if owner_node.marked(foe):
			return true
	return false


func _free_slot() -> Dictionary:
	for w in _words:
		if w["t"] >= 1.0:
			return w
	return _words[0]


static func _text_px(label: Label3D, text: String) -> float:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x


static func _pick_spot(cam: Camera3D, spots: Array, width_px: float, size: float, pixel_size: float, avoid: Array[Rect2]) -> int:
	var view := cam.get_viewport().get_visible_rect().size
	var safe := Rect2(view * 0.5 * (Vector2.ONE - WORD_SAFE), view * WORD_SAFE)
	var rects: Array[Rect2] = []
	for s in spots:
		var r := _word_rect(cam, s[0], s[1], width_px, size, pixel_size)
		rects.append(r if safe.encloses(r) else Rect2())
	return word_spot(rects, avoid)


func _stamp_word(slot: Dictionary, id: String, text: String, at: Vector3, right: bool, width_px: float, size: float, tint: Color) -> void:
	var label: Label3D = slot["node"]
	label.text = text
	label.modulate = tint
	slot["away"] = 1.0 if right else -1.0
	slot["width_px"] = width_px
	slot["t"] = 0.0
	slot["id"] = id
	slot["at"] = at
	slot["tilt"] = _rng.randf_range(-0.2, 0.2)
	slot["size"] = size
	slot["born"] = _clock
	label.visible = true
	_draw_word(slot)
	spawned["word_" + id] = spawned.get("word_" + id, 0) + 1


func _warnings() -> Array[Rect2]:
	var frame := Engine.get_process_frames()
	if frame != _warn_frame:
		_warn_frame = frame
		_warn_rects = warning_rects(get_tree(), camera.cam if camera != null else null, WORD_WARNING_GAP)
	return _warn_rects


func _fight_rects() -> Array[Rect2]:
	var frame := Engine.get_process_frames()
	if frame == _fight_frame:
		return _fight_cache
	_fight_frame = frame
	spawned["fight_refresh"] = spawned.get("fight_refresh", 0) + 1
	_fight_cache = _warnings().duplicate()
	_fight_kind = []
	_fight_kind.resize(_fight_cache.size())
	_fight_kind.fill("warning")
	var cam: Camera3D = camera.cam if camera != null else null
	if cam == null:
		return _fight_cache
	var view := cam.get_viewport().get_visible_rect()
	var focal := view.size.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
	var forward := -cam.global_transform.basis.z
	for node in get_tree().get_nodes_in_group("enemy"):
		if not (node is Node3D) or not node.is_visible_in_tree():
			continue
		var depth: float = (node.global_position - cam.global_position).dot(forward)
		if depth < -FOE_REACH_M:
			continue
		if depth > cam.near:
			var reach: float = FOE_REACH_M * focal / depth
			if not view.grow(reach).has_point(cam.unproject_position(node.global_position)):
				continue
		var bodies := foe_rects(node, cam)
		if bodies.is_empty():
			continue
		var whole := bodies[0]
		for r in bodies:
			whole = whole.merge(r)
		var marks := stack_rect(node, cam) if _marked(node) else Rect2()
		if maxf(whole.size.x, whole.size.y) < FOE_MIN_PX and not marks.has_area():
			continue
		for r in bodies:
			_add_avoid(r, "foe")
		if marks.has_area():
			_add_avoid(marks, "marks")
	for layer in get_tree().get_nodes_in_group(DamageNumbers.GROUP):
		for r in layer.path_rects():
			_add_avoid(r, "number")
	return _fight_cache


func _add_avoid(r: Rect2, kind: String) -> void:
	_fight_cache.append(r.grow(WORD_WARNING_GAP))
	_fight_kind.append(kind)


static func _held_by(cam: Camera3D, spot: Array, width_px: float, size: float, pixel_size: float, avoid: Array[Rect2], kinds: Array) -> String:
	var view := cam.get_viewport().get_visible_rect().size
	var safe := Rect2(view * 0.5 * (Vector2.ONE - WORD_SAFE), view * WORD_SAFE)
	var r := _word_rect(cam, spot[0], spot[1], width_px, size, pixel_size)
	if not safe.encloses(r):
		return "safe"
	for i in avoid.size():
		if avoid[i].intersects(r):
			return kinds[i]
	return "other"


static func word_spot(spots: Array[Rect2], avoid: Array[Rect2]) -> int:
	for i in spots.size():
		if not spots[i].has_area():
			continue
		var clear := true
		for r in avoid:
			rect_tests += 1
			if r.intersects(spots[i]):
				clear = false
				break
		if clear:
			return i
	return -1


static func foe_rects(foe, cam: Camera3D) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if foe == null or not is_instance_valid(foe) or not foe.is_inside_tree() or cam == null:
		return out
	if foe.has_method("screen_bound_boxes"):
		for pair in foe.screen_bound_boxes():
			var r := _view_rect(_box_points(pair[0], pair[1], cam), cam)
			if r.has_area():
				out.append(r)
		if not out.is_empty():
			return out
	var merged := [AABB(), false]
	_merge_meshes(foe, merged)
	if merged[1]:
		var r := _view_rect(_box_points(Transform3D.IDENTITY, merged[0], cam), cam)
		if r.has_area():
			out.append(r)
	return out


static func foe_rect(foe, cam: Camera3D) -> Rect2:
	var rects := foe_rects(foe, cam)
	if rects.is_empty():
		return Rect2()
	var out := rects[0]
	for r in rects:
		out = out.merge(r)
	return out


static func _word_rect(cam: Camera3D, at: Vector3, right: bool, width_px: float, size: float, pixel_size: float) -> Rect2:
	if cam.is_position_behind(at):
		return Rect2()
	var view_h := cam.get_viewport().get_visible_rect().size.y
	var tall := size * WORD_SCREEN * view_h
	var wide := width_px * pixel_size * tall / 0.7
	var p := cam.unproject_position(at)
	return Rect2(Vector2(p.x if right else p.x - wide, p.y - tall * 0.6), Vector2(wide, tall * 1.2))


func _word_color(id: String) -> Color:
	match id:
		"ignite":
			return ImpactFrame.HEAT_COLOR
		"heft_up", "fused":
			return Palette.BRASS
	return player.class_color().lerp(Color.WHITE, FlashGuard.whiten(0.2))


func _beside_ball() -> Vector3:
	_side = -_side
	var ball: Vector3 = player.shown_position()
	if camera == null or camera.cam == null:
		return ball + Vector3.UP * 2.3 + Vector3.RIGHT * 1.6 * _side
	var cam: Camera3D = camera.cam
	var half := _half_height(cam, ball)
	return ball + cam.global_basis.y * half * 0.3 + cam.global_basis.x * half * 0.22 * _side


static func _half_height(cam: Camera3D, at: Vector3) -> float:
	var depth := maxf(0.5, -(cam.global_transform.affine_inverse() * at).z)
	return depth * tan(deg_to_rad(cam.fov) * 0.5)


static func _in_safe_area(cam: Camera3D, at: Vector3, margin := Vector2.ZERO) -> Vector3:
	if cam.is_position_behind(at):
		return at
	var view := cam.get_viewport().get_visible_rect().size
	var p := cam.unproject_position(at)
	var centre := view * 0.5
	var reach := (view * 0.5 * WORD_SAFE - margin).max(Vector2.ZERO)
	var clamped := Vector2(clampf(p.x, centre.x - reach.x, centre.x + reach.x), clampf(p.y, centre.y - reach.y, centre.y + reach.y))
	if clamped.is_equal_approx(p):
		return at
	var depth := -(cam.global_transform.affine_inverse() * at).z
	return cam.project_position(clamped, depth)


const LANE_M := 2.5
const LANE_AHEAD_M := 30.0


func clear_of_lane(at: Vector3) -> Vector3:
	var v: Vector3 = _velocity()
	v.y = 0.0
	if v.length() < 1.0:
		return at
	var dir := v.normalized()
	var ball: Vector3 = player.shown_position()
	var rel := at - ball
	var ahead := rel.dot(dir)
	if ahead <= 0.0 or ahead > LANE_AHEAD_M:
		return at
	var lateral := rel - dir * ahead
	lateral.y = 0.0
	if lateral.length() >= LANE_M:
		return at
	var side := dir.cross(Vector3.UP).normalized()
	if lateral.length() > 0.01:
		side = lateral.normalized()
	return at + side * (LANE_M - lateral.length() + 0.3)


func _draw_word(slot: Dictionary) -> void:
	var label: Label3D = slot["node"]
	var t: float = slot["t"] * WORD_LIFE
	var size: float = slot["size"]
	var scale := 1.0
	var slide := 0.0
	var alpha := 1.0
	if not reduced_motion:
		if t < WORD_STAMP_S * 0.5:
			scale = lerpf(1.7, 0.9, t / (WORD_STAMP_S * 0.5))
		elif t < WORD_STAMP_S:
			scale = lerpf(0.9, 1.0, (t - WORD_STAMP_S * 0.5) / (WORD_STAMP_S * 0.5))
	var exit_from := WORD_LIFE - WORD_EXIT_S
	if t > exit_from:
		var u := (t - exit_from) / WORD_EXIT_S
		alpha = 1.0 - u
		slide = 0.0 if reduced_motion else u * u * 1.4
	var basis := Basis.IDENTITY
	var at: Vector3 = slot["at"]
	var metres := size
	if camera != null and camera.cam != null:
		var cam: Camera3D = camera.cam
		basis = cam.global_basis
		var half := _half_height(cam, at)
		metres = size * WORD_SCREEN * half * 2.0
		var width_m: float = float(slot.get("width_px", 0.0)) * label.pixel_size * metres / 0.7
		at += basis.x * float(slot.get("away", 1.0)) * width_m * 0.5
		var px_per_m := cam.get_viewport().get_visible_rect().size.y / (2.0 * half)
		at = _in_safe_area(cam, at, Vector2(width_m * 0.5, metres * 0.6) * px_per_m)
		at += (basis.x + basis.y) * slide * half * 0.25
	basis = basis * Basis(Vector3.BACK, slot["tilt"])
	label.global_transform = Transform3D(basis.scaled(Vector3.ONE * metres * scale / 0.7), at)
	label.modulate.a = FlashGuard.info(alpha)
	label.outline_modulate = Color(INK.r, INK.g, INK.b, alpha)


func impact_frame(at: Vector3, strength: float) -> bool:
	if reduced_motion or _frame == null or _clock - _last_frame < FRAME_GAP_S:
		return false
	if camera == null or camera.cam == null or camera.cam.is_position_behind(at):
		return false
	_last_frame = _clock
	_frame.fire(camera.cam.unproject_position(at), strength, _rng.randi(), heat_k(might))
	spawned["impact_frame"] = spawned.get("impact_frame", 0) + 1
	return true


static func warning_rects(tree: SceneTree, cam: Camera3D, margin: float, use_bounds := true) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if tree == null or cam == null:
		return out
	for node in tree.get_nodes_in_group(Threat.GROUP):
		if not (node is Node3D) or not node.is_visible_in_tree():
			continue
		var span := [Vector2(INF, INF), Vector2(-INF, -INF)]
		var cached := AABB()
		if use_bounds and node.has_method("screen_bound_box"):
			cached = node.screen_bound_box()
		if cached.size != Vector3.ZERO:
			_project_box(cached, cam, span)
		else:
			var merged := [AABB(), false]
			_merge_meshes(node, merged)
			if merged[1]:
				_project_box(merged[0], cam, span)
		if span[0].x <= span[1].x:
			out.append(Rect2(span[0], span[1] - span[0]).grow(margin))
	return out


static func _merge_meshes(node: Node, merged: Array) -> void:
	for child in node.get_children():
		if child is Node3D and not child.visible:
			continue
		if child is VisualInstance3D:
			var box: AABB = child.get_aabb()
			if box.size != Vector3.ZERO:
				var world: AABB = child.global_transform * box
				merged[0] = world.merge(merged[0]) if merged[1] else world
				merged[1] = true
		_merge_meshes(child, merged)


static func _project_box(box: AABB, cam: Camera3D, span: Array) -> void:
	for p in _box_points(Transform3D.IDENTITY, box, cam):
		_grow_span(span, p)


static func _box_points(xf: Transform3D, box: AABB, cam: Camera3D) -> PackedVector2Array:
	var points := PackedVector2Array()
	var forward := -cam.global_transform.basis.z
	var origin := cam.global_transform.origin
	var plane := cam.near + NEAR_EPSILON
	var corners: Array[Vector3] = []
	var depths: Array[float] = []
	var in_front := 0
	for c in 8:
		var corner: Vector3 = xf * (box.position + box.size * Vector3(c & 1, (c >> 1) & 1, (c >> 2) & 1))
		corners.append(corner)
		depths.append((corner - origin).dot(forward))
		if depths[c] > plane:
			in_front += 1
			points.append(cam.unproject_position(corner))
	if in_front == 0 or in_front == 8:
		return points
	for c in 8:
		for bit in [1, 2, 4]:
			var other: int = c | bit
			if other == c or (depths[c] > plane) == (depths[other] > plane):
				continue
			var t: float = (plane - depths[c]) / (depths[other] - depths[c])
			points.append(cam.unproject_position(corners[c].lerp(corners[other], t)))
	return points


static func _view_rect(points: PackedVector2Array, cam: Camera3D) -> Rect2:
	if points.is_empty():
		return Rect2()
	var view := cam.get_viewport().get_visible_rect()
	var hull := Geometry2D.convex_hull(points)
	if hull.size() < 4:
		var bounds := Rect2(points[0], Vector2.ZERO)
		for q in points:
			bounds = bounds.expand(q)
		return bounds.intersection(view)
	var frame := PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), view.end, Vector2(view.position.x, view.end.y)])
	var out := Rect2()
	var first := true
	for poly in Geometry2D.intersect_polygons(hull, frame):
		for q in poly:
			out = Rect2(q, Vector2.ZERO) if first else out.expand(q)
			first = false
	return out


static func _grow_span(span: Array, at: Vector2) -> void:
	span[0] = span[0].min(at)
	span[1] = span[1].max(at)


func _build_aura() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = MOTES
	mm.visible_instance_count = 0
	_aura = MultiMeshInstance3D.new()
	_aura.name = "MightAura"
	_aura.multimesh = mm
	_aura.top_level = true
	_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_aura)


func motes_shown() -> int:
	return _aura.multimesh.visible_instance_count if _aura != null else 0


func _draw_aura(delta: float) -> void:
	var mm := _aura.multimesh
	var n := _mote_colors.size()
	mm.visible_instance_count = n
	if n == 0:
		return
	_mote_flare = maxf(0.0, _mote_flare - delta * 6.0)
	var centre: Vector3 = player.shown_position()
	_aura.global_transform = Transform3D.IDENTITY
	var v: Vector3 = _velocity()
	var speed := v.length()
	var stretch := 1.0 + (clampf(speed / 30.0, 0.0, 1.0) * 3.0 if might_tier(might) >= 2 else 0.0)
	var along := v / speed if speed > 0.5 else Vector3.FORWARD
	var tilt := Basis(Vector3.RIGHT, 0.45)
	for i in n:
		var arrive: float = _mote_arrive.get(i, 1.0)
		if arrive < 1.0:
			arrive = minf(1.0, arrive + delta * 2.0)
			_mote_arrive[i] = arrive
		var angle := _clock * (1.6 + 0.8 * might) + TAU * float(i) / float(n)
		var ring := tilt * Vector3(cos(angle), 0.0, sin(angle)) * MOTE_RADIUS * (1.0 + 0.15 * might)
		var at := centre + ring + Vector3.UP * (1.0 - ease(arrive, 0.4)) * 4.0
		var size := (0.8 + 0.5 * might) * (1.0 + 0.9 * _mote_flare)
		var basis := Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT)
		basis = basis.scaled(Vector3(size, size, size * stretch))
		mm.set_instance_transform(i, Transform3D(basis, at))
		var c: Color = heat_tint(_mote_colors[i])
		mm.set_instance_color(i, c.lerp(Color.WHITE, FlashGuard.whiten(0.6 * _mote_flare)))


const _RIM_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;
uniform vec4 rim : source_color = vec4(1.0, 0.62, 0.24, 1.0);
uniform vec4 pilot : source_color = vec4(1.0);
uniform float heat = 0.0;
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	vec3 hot = mix(rim.rgb, vec3(1.0, 0.97, 0.9), f * f);
	ALBEDO = mix(hot, pilot.rgb, 0.25 * (1.0 - f)) * (f * 2.2 + 0.08) * heat;
}
"""


func _build_rim() -> void:
	var shader := Shader.new()
	shader.code = _RIM_SHADER
	_rim_mat = ShaderMaterial.new()
	_rim_mat.shader = shader
	_rim_mat.render_priority = RENDER_PRIORITY
	var mesh := SphereMesh.new()
	mesh.radius = 1.08
	mesh.height = 2.16
	mesh.radial_segments = 24
	mesh.rings = 12
	_rim = MeshInstance3D.new()
	_rim.name = "OverdriveRim"
	_rim.mesh = mesh
	_rim.material_override = _rim_mat
	_rim.top_level = true
	_rim.visible = false
	_rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_rim)


func overdrive_step(speed: float, delta: float) -> bool:
	var ignited := false
	if not overdrive and speed >= SOFT_CAP_MPS:
		overdrive = true
		ignited = true
	elif overdrive and speed < SOFT_CAP_OFF_MPS:
		overdrive = false
	var target := 1.0 if overdrive else 0.0
	var seconds := HEAT_RISE_S if target > heat else HEAT_FALL_S
	heat = move_toward(heat, target, delta / seconds)
	return ignited


func _draw_overdrive(delta: float) -> void:
	var v: Vector3 = _velocity()
	var speed := v.length()
	if overdrive_step(speed, delta):
		spawned["ignite"] = spawned.get("ignite", 0) + 1
		var back: Vector3 = player.shown_position() - v.normalized() * 1.5
		word("ignite", _beside_ball())
		impact_frame(player.shown_position(), 0.6)
		if vfx != null:
			vfx.glyph("overdrive", back, 0.8, 4.0, 0.3, v, "ring", ImpactFrame.HEAT_COLOR)
	var on := heat > 0.01
	var shell := shell_heat() if _shell_band > 0 else 0.0
	var lit := maxf(heat, shell)
	_rim.visible = lit > 0.01
	var ball: Vector3 = player.shown_position()
	if lit > 0.01:
		_rim.global_position = ball
		var red = player.get("redline")
		var shell_wins: bool = shell > 0.0 and (heat < shell or red.hot())
		var rim: Color = shell_color(red) if shell_wins else OVERDRIVE_RIM
		var kettle := 0.0
		if red != null:
			kettle = (1.0 if red.kettle_live() else 0.0) if FlashGuard.on else red.kettle_pulse()
		_rim_mat.set_shader_parameter("heat", FlashGuard.spike(lit, lerpf(lit, 1.0, kettle)))
		_rim_mat.set_shader_parameter("rim", rim.lerp(Palette.HAZARD, kettle))
	if on:
		_rim_mat.set_shader_parameter("pilot", player.class_color())
		if speed > 1.0:
			var basis := Basis.looking_at(-v / speed, Vector3.UP if absf(v.y / speed) < 0.95 else Vector3.RIGHT)
			_flecks.global_transform = Transform3D(basis, ball - v / speed * 0.9)
			_embers.global_transform = Transform3D(basis, ball - v / speed * 0.6)
		_flecks.amount_ratio = clampf(heat * (0.6 + 0.4 * might), 0.0, 1.0)
		_embers.amount_ratio = clampf(heat * (0.5 + 0.5 * might), 0.0, 1.0)
	if _flecks.emitting != on:
		FxLibrary.set_heat(_flecks)
		FxLibrary.set_heat(_embers)
		_flecks.emitting = on
		_embers.emitting = on


const OVERDRIVE_RIM := Color(1.0, 0.62, 0.24)
const SHELL_COLORS := [Color(0.45, 1.0, 0.75), Color(1.0, 0.72, 0.25), Color(1.0, 0.98, 0.92)]
const SHELL_RIM := 0.7
const BLAST_RING := Color(1.0, 0.97, 0.9)
var _shell_band := 0


func shell_heat() -> float:
	var redline = player.get("redline")
	return SHELL_RIM * redline.warmth() if redline != null else 0.0


static func shell_color(redline) -> Color:
	if redline.redline():
		return SHELL_COLORS[2]
	return SHELL_COLORS[0].lerp(SHELL_COLORS[1], redline.hot_share())


func _wire_redline() -> void:
	var redline = player.get("redline")
	if redline == null:
		return
	redline.detonated.connect(_on_redline_blast)
	redline.cooked_off.connect(_on_redline_blast)
	redline.changed.connect(func(_value: float, band: int): _shell_band = band)


func _on_redline_blast(at: Vector3, _force: float) -> void:
	spawned["redline_blast"] = spawned.get("redline_blast", 0) + 1
	word("redline", at + Vector3.UP * 2.0)
	impact_frame(at, 1.0)
	if vfx != null:
		vfx.glyph("redline_blast", at + Vector3.UP * 0.3, 1.0, Redline.BLAST_RADIUS, 0.35, Vector3.UP, "ring", BLAST_RING)


func _velocity() -> Vector3:
	return pose.get("velocity", player.state.velocity)


func _normal() -> Vector3:
	return pose.get("normal", player.state.contact_normal)


func _tier() -> int:
	return SpeedTier.of(_velocity().length(), 14.0) if pose.has("velocity") else player.speed_tier()


func carving() -> bool:
	var grounded: bool = pose.get("grounded", player.state.grounded)
	return grounded and _normal().y < CARVE_NORMAL_Y and _tier() >= SpeedTier.FAST


func _draw_carve() -> void:
	var v: Vector3 = _velocity()
	var speed := v.length()
	var on := carving() and speed > 0.01
	if on:
		var back: Vector3 = -v / speed
		var normal := _normal()
		var up: Vector3 = normal
		if absf(back.dot(up)) > 0.95:
			up = Vector3.UP
		_carve.global_transform = Transform3D(Basis.looking_at(back, up), player.shown_position() - normal * 0.95)
		var steep := clampf((CARVE_NORMAL_Y - normal.y) / CARVE_NORMAL_Y, 0.0, 1.0)
		var fast := clampf(speed / 30.0, 0.0, 1.0)
		_carve.amount_ratio = clampf((0.35 + 0.65 * steep) * (0.7 + 0.3 * might) * fast, 0.1, 1.0)
	if _carve.emitting != on:
		FxLibrary.set_heat(_carve)
		_carve.emitting = on
		if on:
			spawned["carve"] = spawned.get("carve", 0) + 1


func column(tint: Color, at := Vector3.INF) -> void:
	var p: GPUParticles3D = _columns[_column_next]
	_column_next = (_column_next + 1) % _columns.size()
	var base: Vector3 = player.shown_position() - Vector3.UP * 0.8 if at == Vector3.INF else at
	p.global_transform = Transform3D(Basis.IDENTITY, base)
	p.set_instance_shader_parameter(FxLibrary.TINT, Particles.glow(heat_tint(tint), 1.15))
	p.amount_ratio = clampf(0.5 + 0.5 * might, 0.0, 1.0)
	FxLibrary.set_heat(p)
	p.restart()
	p.emitting = true
	spawned["column"] = spawned.get("column", 0) + 1


func _emitter(pm: ParticleProcessMaterial, shape: PrimitiveMesh, amount: int, life: float, blend: String, one_shot: bool) -> GPUParticles3D:
	var size = shape.size if shape is BoxMesh else shape.height
	var look := "streak" if size is Vector3 and maxf(size.y, size.z) > size.x * 2.0 else "glow"
	var mesh := FxLibrary.look_mesh(look, size, blend)
	mesh.material = FxLibrary.look_material(look, blend)
	if look == "glow":
		pm.angle_min = 0.0
		pm.angle_max = 360.0
	var p := GPUParticles3D.new()
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.set_meta("fx_look", look)
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = false
	p.emitting = false
	p.use_fixed_seed = true
	p.seed = FxLibrary.SEED
	p.visibility_aabb = AABB(Vector3(-10, -6, -10), Vector3(20, 14, 20))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.set_instance_shader_parameter(FxLibrary.TINT, Color.WHITE)
	root.add_child(p)
	return p


static func ceiling() -> int:
	return FLECKS + EMBERS + CARVE + COLUMN * COLUMN_POOL + BOON * BOON_POOL


const RIVET := "runner_gunner"
const FLASHES := 2
const FLASH_SIZE := 0.22
const FLASH_LIFE := 0.05
const FLASH_CORE := Color(1.0, 0.97, 0.9)
const CASINGS := 8
const CASING_LIFE := 0.35
const CASING_SPEED := 2.5
const CASING_TURNS := 20.0
const CASING_GRAVITY := 9.8
const CASING_EVERY := 2
const RIVET_DRAWS := 2
const DRUM_GAP := Vector3(0.24, -0.04, 0.47)
const SIDE_M := 1.26
const HALO_AHEAD_M := 1.34
const MARKER_SEEK_S := 0.5

const _FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec4 core : source_color = vec4(1.0);
uniform vec4 rim : source_color = vec4(1.0);
varying float v_glow;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
	v_glow = INSTANCE_CUSTOM.r;
}
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	// A four-point star, |x|^0.5 + |y|^0.5 = 1, negative inside; over its screen gradient it is pixels.
	float f = sqrt(abs(p.x)) + sqrt(abs(p.y)) - 1.0;
	float px = f / max(fwidth(f), 0.00001);
	if (px > 0.0) {
		discard;
	}
	float edge = smoothstep(-2.0, -1.0, px);
	ALBEDO = mix(core.rgb * (1.4 - 0.6 * length(p)), rim.rgb, edge) * v_glow;
}
"""

var _halo: Node3D
var _halo_spent := false
var _markers := {}
var _marker_wait := {}
var _rivet_shots := 0
var _flashes: MultiMeshInstance3D
var _flash_age: Array[float] = []
var _flash_pos: Array[Vector3] = []
var _casings: MultiMeshInstance3D
var _casing_age: Array[float] = []
var _casing_next := 0
var _casing_at: Array[Vector3] = []
var _casing_v: Array[Vector3] = []
var _casing_axis: Array[Vector3] = []
var _casing_basis: Array[Basis] = []


func halo() -> Node3D:
	return _halo


func weapon_cadence() -> Dictionary:
	var combat = ctx.get("spawner") if ctx != null else null
	var driver = combat.get("weapon_driver") if combat != null else null
	if driver == null or not driver.has_method("state_snapshot"):
		return {}
	return driver.state_snapshot()


static func halo_pilot(cadence: Dictionary) -> bool:
	return String(cadence.get("trigger", "")) == Pattern.TRIGGER_TAP_CHARGE


func charge_level(cadence: Dictionary) -> float:
	var level := clampf(float(cadence.get("charge", 0.0)), 0.0, 1.0) if cadence.get("charging", false) == true else 0.0
	var abilities = player.get("abilities")
	if abilities != null and abilities.has_method("slots"):
		for record in abilities.slots():
			level = maxf(level, clampf(float(record.get("gauge", 0.0)), 0.0, 1.0))
	return level


func _wire_weapon() -> void:
	var events = ctx.events
	SignalWire.listen(events, "shot_fired", _on_weapon_shot)
	SignalWire.listen(events, "gauge_charging", func(_id: String): _halo_spent = false)
	SignalWire.listen(events, "gauge_released", _on_gauge_released)
	SignalWire.listen(events, "gauge_cancelled", func(_id: String, _reason: String):
		if _halo != null and _halo.charging():
			_halo_spent = true
			_halo.cancel())
	SignalWire.listen(events, "run_started", func(_class_id: String): _rivet_shots = 0)


func _on_weapon_shot(weapon: String, from: Vector3, to: Vector3) -> void:
	var cadence := weapon_cadence()
	if weapon != String(cadence.get("weapon", "")):
		return
	var dir := to - from
	if halo_pilot(cadence):
		_ensure_halo()
		_halo_spent = true
		if float(cadence.get("recover", 0.0)) > 0.0:
			_halo.release(dir)
		else:
			_halo.tap()
			_tap_arc(dir)
	elif _pilot_id() == RIVET:
		_rivet_shot(from, dir)


func _on_gauge_released(_id: String, fraction: float) -> void:
	if _halo == null or not halo_pilot(weapon_cadence()):
		return
	_halo_spent = true
	if fraction <= ChargeHalo.TAP_FLOOR:
		_halo.tap()
		_tap_arc(_halo.forward())
	else:
		_halo.release(_halo.forward())


func _tap_arc(dir: Vector3) -> void:
	spawned["sable_tap"] = spawned.get("sable_tap", 0) + 1
	if vfx != null:
		vfx.glyph("shot_fired", _halo.tip(), ChargeHalo.ARC_LENGTH, ChargeHalo.ARC_LENGTH, ChargeHalo.ARC_LIFE, dir, "arc", Palette.ARC)


func _ensure_halo() -> void:
	if _halo == null:
		_halo = ChargeHalo.new()
		root.add_child(_halo)
	var left := _marker("Emitter_L")
	var right := _marker("Emitter_R")
	var ring: Node3D = left.get_parent() as Node3D if left != null and right != null else null
	if ring != null:
		if _halo.mounted_on() != ring:
			_halo.mount(ring, Transform3D(Basis.IDENTITY, (left.position + right.position) * 0.5))
		return
	if _halo.mounted_on() != _halo:
		_halo.mount(null, Transform3D.IDENTITY)
	var ahead := _ahead()
	_halo.place(Transform3D(Basis.looking_at(ahead, Vector3.UP), player.shown_position() + ahead * HALO_AHEAD_M))


func _ahead() -> Vector3:
	var ahead := Vector3.ZERO
	if camera != null and camera.cam != null:
		ahead = -camera.cam.global_basis.z
	if Vector2(ahead.x, ahead.z).length_squared() < 0.0001:
		ahead = _velocity()
	ahead.y = 0.0
	return ahead.normalized() if ahead.length_squared() > 0.0001 else Vector3.FORWARD


func _marker(id: String) -> Node3D:
	var node = _markers.get(id)
	if node != null and is_instance_valid(node) and node.is_inside_tree():
		return node
	_markers.erase(id)
	if _clock < float(_marker_wait.get(id, -1.0)):
		return null
	_marker_wait[id] = _clock + MARKER_SEEK_S
	var mount: Node = player.pod_mount() if player.has_method("pod_mount") else null
	var found: Node3D = mount.find_child(id, true, false) as Node3D if mount != null else null
	if found != null:
		_markers[id] = found
		_marker_wait.erase(id)
	return found


func _draw_weapon_fx(delta: float) -> void:
	var cadence := weapon_cadence()
	if halo_pilot(cadence):
		var level := charge_level(cadence)
		if level <= 0.0:
			_halo_spent = false
		var live := level > 0.0 and not _halo_spent
		if live or _halo != null:
			_ensure_halo()
		if live:
			_halo.charge(level)
		elif _halo != null and _halo.charging():
			_halo.cancel()
	elif _halo != null and _halo.charging():
		_halo.cancel()
	if _halo != null:
		_halo.reduced_motion = reduced_motion
		_halo.step(delta)
	_step_flashes(delta)
	_step_casings(delta)


func _rivet_shot(from: Vector3, dir: Vector3) -> void:
	var side := _rivet_shots % 2
	var on_side := floori(_rivet_shots / 2.0)
	_rivet_shots += 1
	var marker := _marker("LaserMuzzle_L" if side == 0 else "LaserMuzzle_R")
	var outboard := -1.0 if side == 0 else 1.0
	var at: Vector3
	var frame: Basis
	if marker != null and marker.get_parent() is Node3D:
		at = marker.global_position
		frame = (marker.get_parent() as Node3D).global_basis.orthonormalized()
	else:
		var ahead := dir.normalized() if dir.length_squared() > 0.0001 else _ahead()
		frame = Basis.looking_at(ahead, Vector3.UP if absf(ahead.y) < 0.95 else Vector3.RIGHT)
		at = from + frame.x * outboard * SIDE_M
	_flash(side, at)
	if on_side % CASING_EVERY == 0 and not reduced_motion:
		_eject(at + frame * Vector3(DRUM_GAP.x * outboard, DRUM_GAP.y, DRUM_GAP.z), frame, outboard)


func _flash(slot: int, at: Vector3) -> void:
	_flash_age[slot] = 0.0
	_flash_pos[slot] = at
	_flashes.multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ONE * FLASH_SIZE), at))
	_flashes.multimesh.set_instance_custom_data(slot, Color(FlashGuard.alpha(1.0), 0, 0, 0))
	_flashes.visible = true
	spawned["rivet_flash"] = spawned.get("rivet_flash", 0) + 1


func _end_flash(slot: int) -> void:
	if _flashes == null:
		return
	_flash_age[slot] = -1.0
	_flashes.multimesh.set_instance_transform(slot, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))
	_flashes.multimesh.set_instance_custom_data(slot, Color(0, 0, 0, 0))


func _step_flashes(delta: float) -> void:
	var alive := false
	for i in FLASHES:
		if _flash_age[i] < 0.0:
			continue
		_flash_age[i] += delta
		if _flash_age[i] >= FLASH_LIFE:
			_end_flash(i)
			continue
		alive = true
		_flashes.multimesh.set_instance_custom_data(i, Color(FlashGuard.alpha(1.0 - 0.5 * _flash_age[i] / FLASH_LIFE), 0, 0, 0))
	_flashes.visible = alive


func _eject(at: Vector3, frame: Basis, outboard: float) -> void:
	var i := _casing_next
	_casing_next = (_casing_next + 1) % CASINGS
	_casing_age[i] = 0.0
	_casing_at[i] = at
	_casing_v[i] = frame * (Vector3(outboard, 1.0, 0.0).normalized() * CASING_SPEED) + _velocity()
	_casing_axis[i] = (frame * Vector3(0.3 * outboard, 0.2, 1.0)).normalized()
	_casing_basis[i] = frame * Basis(Vector3.RIGHT, PI * 0.5)
	_draw_casing(i)
	_casings.visible = true
	spawned["rivet_casing"] = spawned.get("rivet_casing", 0) + 1


func _end_casing(i: int) -> void:
	if _casings == null:
		return
	_casing_age[i] = -1.0
	_casings.multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ZERO), Vector3.ZERO))


func _draw_casing(i: int) -> void:
	var turn := Basis(_casing_axis[i], TAU * CASING_TURNS * _casing_age[i])
	_casings.multimesh.set_instance_transform(i, Transform3D(turn * _casing_basis[i], _casing_at[i]))


func _step_casings(delta: float) -> void:
	var alive := false
	for i in CASINGS:
		if _casing_age[i] < 0.0:
			continue
		_casing_age[i] += delta
		if _casing_age[i] >= CASING_LIFE:
			_end_casing(i)
			continue
		alive = true
		_casing_v[i] += Vector3.DOWN * CASING_GRAVITY * delta
		_casing_at[i] += _casing_v[i] * delta
		_draw_casing(i)
	_casings.visible = alive


func flashes_alive() -> int:
	return _flash_age.filter(func(a: float) -> bool: return a >= 0.0).size()


func casings_alive() -> int:
	return _casing_age.filter(func(a: float) -> bool: return a >= 0.0).size()


# Godot headless Dummy renderer keeps no readback.
func flash_at(slot: int) -> Vector3:
	return _flash_pos[slot]


func _build_rivet_fire() -> void:
	var card := QuadMesh.new()
	card.size = Vector2.ONE
	card.custom_aabb = AABB(Vector3.ONE * -0.75, Vector3.ONE * 1.5)
	var shader := Shader.new()
	shader.code = _FLASH_SHADER
	var flash_mat := ShaderMaterial.new()
	flash_mat.shader = shader
	flash_mat.set_shader_parameter("core", FLASH_CORE)
	flash_mat.set_shader_parameter("rim", Palette.COPPER)
	flash_mat.render_priority = RENDER_PRIORITY
	_flashes = _pool_view("MuzzleFlashes", card, flash_mat, FLASHES, true)
	_flash_age.resize(FLASHES)
	_flash_pos.resize(FLASHES)
	for i in FLASHES:
		_end_flash(i)
	var casing := CylinderMesh.new()
	casing.top_radius = 0.006
	casing.bottom_radius = 0.006
	casing.height = 0.03
	casing.radial_segments = 8
	casing.rings = 0
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Palette.BRASS.lerp(Palette.STEEL, 0.45)
	metal.roughness = 0.5
	metal.metallic = 0.35
	metal.render_priority = RENDER_PRIORITY
	_casings = _pool_view("SpentCasings", casing, metal, CASINGS, false)
	for list in [_casing_age, _casing_at, _casing_v, _casing_axis, _casing_basis]:
		list.resize(CASINGS)
	for i in CASINGS:
		_end_casing(i)


func _pool_view(id: String, mesh: Mesh, mat: Material, count: int, custom: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = custom
	mm.mesh = mesh
	mm.instance_count = count
	var view := MultiMeshInstance3D.new()
	view.name = id
	view.multimesh = mm
	view.material_override = mat
	view.top_level = true
	view.visible = false
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(view)
	return view


func _process(delta: float) -> void:
	if player == null or root == null:
		return
	_clock += delta
	_might_wait -= delta
	if _might_wait <= 0.0:
		_might_wait = MIGHT_REFRESH_S
		refresh_might()
	for w in _words:
		if w["t"] >= 1.0:
			continue
		w["t"] = minf(1.0, w["t"] + delta / WORD_LIFE)
		if w["t"] >= 1.0:
			w["node"].visible = false
		else:
			_draw_word(w)
	_draw_aura(delta)
	_draw_dunk_glow()
	_draw_overdrive(delta)
	_draw_carve()
	_draw_weapon_fx(delta)
