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

# The player-side effects vfx.gd does not draw (PLAYER-FX.md). Everything here answers a
# committed fact or the ball's own motion and never decides an outcome (TADR-008).
#
#   might      0 to 1 from heft class, parts, synergies and fusions: how grown the build
#              is. Every layer below reads it, so a grown pilot looks mightier than a
#              small one (Andrew, 17 Oct: action-RPG growth, Hades boon stacking).
#   aura       one mote per part orbits the ball in its element's colour; motes flare on
#              each hit and stretch into streamers once the build is grown
#   boon       a hit throws a second spark burst in the build's dominant element colour
#   words      comic sound words (KLANG, WHUMP) stamped beside big moments, never ahead of
#              the ball (TONE-BIBLE pillar 2), never on a hostile warning or the foe they
#              name, nor any foe in view, the marks stacked over it or the rising damage
#              numbers (beside the ball, else its other side, else above the foe's marks,
#              else unsaid); an ordinary hit says only BWAP when it lands on the beat (PF-26)
#   overdrive  past SOFT_CAP_MPS the ball burns: white-hot rim, flame flecks and a
#              hanging ember trail, so "my contact hurts now" reads at a glance
#   carve      grinding sparks while the ball rides banked ground at speed
#   column     a rising brass column for a heft class up or a fusion
#   frame      a 3-frame ink focus-line impact frame on the biggest hits; edge band only,
#              so the centre stays clear, and it skips every wedge and wash piece that
#              would cross a hostile warning's screen rect (enemy warnings draw on top)
# Colour carries the meaning: the pilot's colour is "you did this", brass is growth,
# the heat ramp is overdrive, element colours are the build.

# Andrew's ruling (17 Oct 07:17Z): speed past 60 m/s becomes hit damage and a blazing
# trail. The gameplay is wave 17 machine work; this layer reads the ball's speed itself.
const SOFT_CAP_MPS := 60.0
const SOFT_CAP_OFF_MPS := 54.0
const HEAT_RISE_S := 0.15
const HEAT_FALL_S := 0.4
# Banked ground: the contact normal's up share below this is a carve.
const CARVE_NORMAL_Y := 0.82
const MOTES := 12
const MOTE_RADIUS := 1.65
const ELEMENT_COLORS := {"frost": Palette.ANCIENT, "arc": Palette.ARC, "kinetic": Palette.SAND}
const HEAT_COLOR := Color(1.0, 0.5, 0.12)
# How much of a colour the heat takes at full heat_k: saturated orange, never white, so the
# heat reads as colour and not as brightness.
const HEAT_SHARE := 0.85
const INK := Color(0.07, 0.07, 0.08)

# Below every threat mark (threat_grammar PRIORITY 40, under-lines 39): enemy warnings
# always draw on top of player effects (Andrew, 17 Oct 16:36Z).
const RENDER_PRIORITY := -4

const MIGHT_TIERS := ["small", "rising", "grown", "mighty"]

# Sound words. size is metres of cap height at might 0; a word grows to 1.5x at might 1.
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
	"paid": {"text": "PAID", "size": 0.9},
	"wham": {"text": "WHAM", "size": 1.0},
	"strike": {"text": "STRIKE", "size": 1.1},
	"beat": {"text": "BWAP", "size": 0.64},
	"redline": {"text": "KA-BLAM", "size": 1.2},
}
# An on-beat hit's word is this much bigger (Andrew, Q10 "Sound only"): the hit's own word
# when it has one, else BWAP over the on-beat clap.
const ONBEAT_GROW := 1.4
# A read word's size (read_word: DENT, ZZAP!), on the same screen-share scale; it is the foe's,
# so the build's might never grows it.
const READ_SIZE := 0.8
# Where a foe's marks stack over its feet (stack_rect): the interrupted star at 2.4 m, the class
# icon at 3.1 m and machine_fx's stagger word at 3.2 m, with room for that word's height (about
# 1.1 m) and half its width.
const STACK_LOW := 1.8
const STACK_TOP := 3.8
const STACK_HALF := 1.8
const WORD_FONT_PATH := "res://assets/fonts/NotoSans-Bold.ttf"
# Word size is screen height share: "size" 1.0 is WORD_SCREEN of the screen's height,
# whatever the distance, so a word near the camera never swallows the ball.
const WORD_SCREEN := 0.075
# Words stay inside this share of the screen from its centre (the HUD lives outside it).
const WORD_SAFE := Vector2(0.78, 0.7)
# Ram launches and bowling racks, lined up with the Knockback thread (17 Oct): a ram at
# blazing speed throws 23 to 34 m/s; a killed body bowling on fires enemy_pinned per pin.
const LAUNCH_KINDS := ["ram", "slam"]
const CONTACT_KINDS := ["ram", "slam", "stomp"]
const STRIKE_PINS := 3
const STRIKE_WINDOW_S := 0.6

# Each pilot's own voice on the shared moments (TONE-BIBLE, the cast).
const PILOT_WORDS := {
	"pylon_engineer": {"launch": "ZWOOSH"},
	"runner_gunner": {"smash": "PING"},
	"demolitions_caster": {"slam": "BOOM", "rocket": "BOOM"},
	"tarn": {"smash": "GRRAK", "slam": "KRASH"},
	"tally": {"smash": "KA-CHING"},
	"remembered_cannon": {"launch": "KA-THOOM", "smash": "THOOM"},
}
const WORD_POOL := 4
const WORDS_ALIVE := 2
const WORD_GAP_S := 0.35
const WORD_REPEAT_S := 1.2
# BWAP rides an ordinary hit that lands on the beat, the commonest hit in a fight, so it
# repeats far less often than a big moment's word (PF-26: the w37 film's readers said the
# hit words cover the fight).
const BEAT_REPEAT_S := 4.0
# A word keeps this far, in px, off any hostile warning, any foe in view with its marks, and any
# rising damage number.
# 24 covers the word's ink outline and its tilt at the ends, which _word_rect leaves out.
const WORD_WARNING_GAP := 24.0
# A foe's origin is at most this far (m) from any part of its drawn body (Brindle's hull is 14 m long and
# his cranes stand 7.5 m up), so a foe whose origin is farther than this behind the camera plane or off
# the screen's edge has none of its body in view and its meshes are not walked.
const FOE_REACH_M := 25.0
# A foe whose column is under this many px on its longer side is not avoided: it is no larger than the
# gap a word already keeps (WORD_WARNING_GAP), so it cannot hide a word, and a far crowd stays cheap.
const FOE_MIN_PX := 24.0
# The owners of a foe's marks (status_marks.gd, machine_fx.gd) join this group and answer marked(foe).
# Beside-the-ball spots, as shares of the view's half-height at the ball: out to either side, and then
# down, so the search stays near the ball and low in the view, away from a foe's marks above it.
const SPOT_BESIDE := 0.32
const SPOT_DROP := 0.22
const MARKS_GROUP := "foe_marks"
# Whatever draws something a word must not cover joins KEEP_GROUP and answers keep_clear_rects()
# (viewport pixels): the HUD, the flourish player, the screens, a reward gate. player_fx reads the
# group and never names a member. Every stamper of candy words asks this node (ROOM_GROUP) through
# spot_free() and candy_room(), so one module owns what a word keeps off.
const KEEP_GROUP := "word_keep_clear"
const ROOM_GROUP := "word_room"
# Rect-versus-rect tests made by word placement (a count for the notes and the cost check).
static var rect_tests := 0


static func reset_for_tests() -> void:
	rect_tests = 0
const WORD_LIFE := 0.6
const WORD_STAMP_S := 0.1
const WORD_EXIT_S := 0.2
# Smash speed that earns KLANG and the impact frame: lower as the build grows.
const SMASH_WORD_MPS := [22.0, 12.0]
const SMASH_FRAME_MPS := [32.0, 18.0]
# An impact frame holds for rendered frames, not seconds: 3 frames is 50 ms at 60 fps.
const FRAME_FRAMES := 3
const FRAME_GAP_S := 0.6
# A warning's box is clipped this far (m) past the camera's near plane, so every crossing
# point is in front of the lens and projects.
const NEAR_EPSILON := 0.01

# GPU particle ceilings: pool x max, pinned by player_fx_test.
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
# The words' own parent: only they hide while the tree is paused, not the aura, coil or sparks.
var _word_root: Node3D
var reduced_motion := false
# Facts drawn, by layer, for the tests and the notes.
var spawned := {}

var might := 0.0
# Staged captures only (tools/player_fx_capture.gd): "velocity", "normal" and "grounded"
# stand in for the ball's state, so a frozen ball can be posed blazing or carving.
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
# Might is recounted this often too, so a growth path with no fact of its own (a tree pick,
# start mass, a restored snapshot) still shows.
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
	_flecks = _emitter(_flecks_material(), _box(Vector3(0.12, 0.12, 0.55)), FLECKS, 0.35, "add", false)
	_flecks.name = "OverdriveFlecks"
	_embers = _emitter(_embers_material(), _ball(0.16), EMBERS, 0.9, "add", false)
	_embers.name = "OverdriveEmbers"
	_carve = _emitter(_carve_material(), _box(Vector3(0.05, 0.05, 0.4)), CARVE, 0.28, "add", false)
	_carve.name = "CarveSparks"
	for i in COLUMN_POOL:
		var c := _emitter(_column_material(), _box(Vector3(0.07, 0.6, 0.07)), COLUMN, 0.8, "add", true)
		c.name = "PowerColumn_%d" % i
		_columns.append(c)
	for i in BOON_POOL:
		var b := _emitter(_boon_material(), _box(Vector3.ONE * 0.16), BOON, 0.3, "add", true)
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


# --- Dunk charge --------------------------------------------------------------------------
# While the ball holds a dunk charge (dunk.gd), a coil glows on the collar's rear arc in the
# pilot's class colour from the charge record, never mint for all (DECISIONS pilot call d;
# ROADMAP Effects row: a coil collar glow with a ring or pip shape, no chevron). The arc rides
# level at the fairlead's radius, behind the line of travel so the chase camera sees it, and
# holds its last bearing when the ball is near rest. DUNK_PIPS studs on top of it burn in the
# class colour and go dark one by one as the window runs down, and the coil pulses faster near
# the end. The sound reads the same record (audio.gd), and the coil clears on spend and on expiry
# because both clear the record.
# Sized for play distance (3060 still, #521: the ball is about 60 px tall there, so a 0.07 m
# tube was 2 px and pips 3 and 1 looked the same): the tube is about 5 px, a dark ink rim
# (an inverted hull) parts it from the cage, and it is emissive in the full class colour, so it
# blooms under Forward+ glow instead of washing toward white.
const DUNK_RADIUS := 1.06
const DUNK_ARC := deg_to_rad(140.0)
const DUNK_TUBE := 0.16
const DUNK_INK := 0.045
const DUNK_PIPS := 3
const DUNK_PIP_RADIUS := 0.21
# Emission past about 1.5 clips every channel and burns the class colour to white; a dark
# base keeps the hue at the top of the pulse.
const DUNK_EMISSION := 1.1
const DUNK_PIP_EMISSION := 1.5
const DUNK_BASE := 0.35
# Below this planar speed the arc keeps its bearing, so it never spins at rest.
const DUNK_HOLD_SPEED := 1.5

var _dunk_coil: StandardMaterial3D
var _dunk_pips: Array[StandardMaterial3D] = []
var _dunk_pip_lit: Array[bool] = []
var _dunk_yaw := 0.0


func _build_dunk_glow() -> void:
	_dunk_coil = _dunk_emissive()
	_dunk_glow = MeshInstance3D.new()
	_dunk_glow.name = "DunkGlow"
	_dunk_glow.mesh = _dunk_arc_mesh(_dunk_coil, DUNK_TUBE)
	_dunk_glow.top_level = true
	_dunk_glow.visible = false
	_dunk_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(_dunk_glow)
	var rim := MeshInstance3D.new()
	rim.name = "Ink"
	rim.mesh = _dunk_arc_mesh(_dunk_ink(), DUNK_TUBE + DUNK_INK)
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dunk_glow.add_child(rim)
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = DUNK_PIP_RADIUS
	pip_mesh.height = DUNK_PIP_RADIUS * 2.0
	pip_mesh.radial_segments = 10
	pip_mesh.rings = 5
	var pip_ink := SphereMesh.new()
	pip_ink.radius = DUNK_PIP_RADIUS + DUNK_INK
	pip_ink.height = pip_ink.radius * 2.0
	pip_ink.radial_segments = 10
	pip_ink.rings = 5
	pip_ink.material = _dunk_ink()
	for i in DUNK_PIPS:
		var pip := MeshInstance3D.new()
		pip.name = "Pip%d" % i
		pip.mesh = pip_mesh
		var mat := _dunk_emissive()
		pip.material_override = mat
		pip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Studs riding on top of the coil, so they stand clear of the cage behind them.
		pip.position = _dunk_arc_point(_dunk_pip_angle(i), DUNK_RADIUS + DUNK_TUBE * 0.5) + Vector3.UP * (DUNK_TUBE + DUNK_PIP_RADIUS * 0.4)
		var ink := MeshInstance3D.new()
		ink.name = "Ink"
		ink.mesh = pip_ink
		ink.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pip.add_child(ink)
		_dunk_glow.add_child(pip)
		_dunk_pips.append(mat)
		_dunk_pip_lit.append(false)


func _dunk_emissive() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.roughness = 0.4
	mat.render_priority = RENDER_PRIORITY
	return mat


# The ink rim: the back faces of a slightly fatter shell, so only its outline shows.
func _dunk_ink() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_FRONT
	mat.albedo_color = INK
	mat.render_priority = RENDER_PRIORITY
	return mat


# The pips sit evenly inside the arc.
static func _dunk_pip_angle(i: int) -> float:
	return DUNK_ARC * ((float(i) + 0.5) / float(DUNK_PIPS) - 0.5)


# A point on the level arc at `angle` from its middle, which faces +Z (the rear).
static func _dunk_arc_point(angle: float, radius: float) -> Vector3:
	return Vector3(sin(angle) * radius, 0.0, cos(angle) * radius)


# A tube of radius `tube` swept along the rear arc (outward normals), built once.
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


# How many of the pips burn: all of them at the store, none at the window's end.
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
	_dunk_coil.albedo_color = colour * Color(DUNK_BASE, DUNK_BASE, DUNK_BASE)
	_dunk_coil.emission = colour
	_dunk_coil.emission_energy_multiplier = FlashGuard.spike(DUNK_EMISSION, DUNK_EMISSION * (1.0 + 0.6 * pulse))
	# A spent pip goes to ink, so 3 against 1 is a count of lit studs, not of shapes.
	var lit := ceili(share * DUNK_PIPS)
	for i in _dunk_pips.size():
		var burning := i < lit
		_dunk_pip_lit[i] = burning
		_dunk_pips[i].albedo_color = colour * Color(DUNK_BASE, DUNK_BASE, DUNK_BASE) if burning else INK
		_dunk_pips[i].emission = colour if burning else Color.BLACK
		_dunk_pips[i].emission_energy_multiplier = DUNK_PIP_EMISSION if burning else 0.0
	var v: Vector3 = _velocity()
	if Vector2(v.x, v.z).length() >= DUNK_HOLD_SPEED:
		_dunk_yaw = atan2(-v.x, -v.z)
	_dunk_glow.global_transform = Transform3D(Basis(Vector3.UP, _dunk_yaw), player.shown_position())
	_dunk_glow.visible = true


# --- Might -------------------------------------------------------------------------------

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


# Colour heat (Andrew, "Presence, centre clear", 17 Oct 17:28Z): a grown build's colours
# run hotter, toward the heat ramp, instead of its bursts growing past their size. Heat
# starts at might 0.1 and is full from 0.7, so a "grown" build already runs mostly hot.
static func heat_k(value: float) -> float:
	return clampf((value - 0.1) / 0.6, 0.0, 1.0)


func heat_tint(color: Color) -> Color:
	return color.lerp(HEAT_COLOR, HEAT_SHARE * heat_k(might))


# The colour most of the build's parts share: the colour a boon spark takes.
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
	_wire_redline()
	# Called Shot (build/called_shot.gd): a met break holds the frame (its pad thump is juice.gd's).
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
		# Grown builds earn the edge ink on every contact hit, not only the biggest.
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
	# A hotter build burns a brighter core: same size, more light.
	FxLibrary.fire(p, "", "", boon_count(might), at, _glow(heat_tint(dominant_color()), 1.1 + 0.7 * heat_k(might)))
	spawned["boon"] = spawned.get("boon", 0) + 1


# A slam: WHUMP when it is a real one; a grown build also throws hot sparks out of the
# crater and, from "grown", earns the impact frame. No column here: the centre stays clear
# (Andrew, "Presence, centre clear"). The ring of the slam's real reach stays vfx.gd's,
# true to who it hit.
func _on_slammed(at: Vector3, strength: float, _flatness: float) -> void:
	if strength < 0.5:
		return
	word("slam", at + Vector3.UP * 1.6)
	if might >= 0.25 and not _mote_colors.is_empty():
		_boon(at + Vector3.UP * 0.4)
	if might_tier(might) >= 2:
		impact_frame(at, clampf(0.5 + 0.5 * might, 0.0, 1.0))


# Andrew's "Clearly mightier" (17 Oct 16:36Z), read as "Presence, centre clear": the boon
# burst grows in count and heat, never in size or reach, on top of vfx.gd's fixed sparks.
static func boon_count(value: float) -> int:
	return int(round(BOON * clampf(value, 0.0, 1.0)))


func _on_smashed(enemy: Node3D, at: Vector3, speed: float) -> void:
	if speed >= lerpf(SMASH_WORD_MPS[0], SMASH_WORD_MPS[1], might):
		word("smash", at + Vector3.UP * 1.8, Color.TRANSPARENT, enemy)
	if speed >= lerpf(SMASH_FRAME_MPS[0], SMASH_FRAME_MPS[1], might):
		impact_frame(at, clampf(0.6 + might * 0.4, 0.0, 1.0))


# A body bowled into a rack: the third pin inside the window stamps STRIKE.
func _on_pinned(victim: Node3D, _damage: float) -> void:
	_pin_times.append(_clock)
	while not _pin_times.is_empty() and _clock - float(_pin_times[0]) > STRIKE_WINDOW_S:
		_pin_times.pop_front()
	if _pin_times.size() == STRIKE_PINS and is_instance_valid(victim) and victim.is_inside_tree():
		word("strike", victim.global_position + Vector3.UP * 2.0, Palette.BRASS, victim)
		impact_frame(victim.global_position, 0.8)


# audio.gd's hit_on_beat. Deferred, so a word the same hit earns (WHAM, KLANG) stamps first
# and grows instead of being refused by the gap.
func on_beat_hit(enemy: Node3D, kind: String) -> void:
	_on_beat_word.call_deferred(enemy, kind, _clock)


# `enemy` is untyped on purpose: the foe can be freed before this deferred call runs, and Godot
# refuses a freed instance for a typed parameter ("Cannot convert argument 1 from Object to
# Object") before the validity check below can run.
func _on_beat_word(enemy, _kind: String, at_clock: float) -> void:
	spawned["on_beat"] = spawned.get("on_beat", 0) + 1
	for w in _words:
		if w["t"] < 1.0 and float(w.get("born", -1.0)) >= at_clock and w["id"] != "read":
			# The hit's own word grows (a read word is the foe's, never the beat's), unless the bigger word would reach the fight.
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
	# Beside the ball, not over the foe: an ordinary hit's word never covers what is being hit.
	if word("beat", _beside_ball(), Color.TRANSPARENT, enemy):
		_words_by_id("beat")["size"] *= ONBEAT_GROW


func _words_by_id(id: String) -> Dictionary:
	for w in _words:
		if w.get("id", "") == id and w["t"] < 1.0:
			return w
	return {}


# Tally stamps PAID when two or more go down together.
func _on_killed(_kind: String, at: Vector3, _scrap: int) -> void:
	if _pilot_id() != "tally":
		return
	_kill_times.append(_clock)
	while not _kill_times.is_empty() and _clock - float(_kill_times[0]) > 0.25:
		_kill_times.pop_front()
	if _kill_times.size() == 2:
		word("paid", at + Vector3.UP * 1.8, Palette.LEDGER)


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


# --- Sound words -------------------------------------------------------------------------

func _make_word() -> Dictionary:
	var label := word_label(_font)
	label.visible = false
	_word_root.add_child(label)
	return {"node": label, "t": 1.0, "id": "", "tilt": 0.0, "size": 1.0, "at": Vector3.ZERO}


# A pooled word's label, as every word wears it (BakeWarm stands one per read word at stage entry).
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
	# Words sit beside the ball, never in its lane, so a hill may not swallow them; the
	# threat marks still draw after them.
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


# The sound words showing; a read word (read_word) stands outside their budget.
func words_alive() -> int:
	var n := 0
	for w in _words:
		if w["t"] < 1.0 and w["id"] != "read":
			n += 1
	return n


# Whether another candy sound word may show: the budget WORDS_ALIVE counts this module's words and
# the ones machine_fx has up (its candy_alive()), so the two stampers share it. Reads and tells
# stand outside it.
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


# Whether a word covering `r` (viewport pixels) would stand clear of everything that joined KEEP_GROUP.
# The one test the other stampers ask; it holds no foe or warning, which a machine word is stamped on
# by design.
func spot_free(r: Rect2) -> bool:
	for k in _keep_rects():
		rect_tests += 1
		if k.intersects(r):
			return false
	return true


var _machine = null
var _keep_frame := -1


# A member's rects changed (a card, caption, stamp or inset started or ended): read the list again.
func keep_clear_changed() -> void:
	_keep_frame = -1
var _keep_cache: Array[Rect2] = []


# KEEP_GROUP's rects, grown by WORD_WARNING_GAP, read once a frame.
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


# Stamps a sound word at `at`, pushed off the line ahead of the ball. Refused inside the
# gap since the last word, inside a word's own repeat window, with two alive, or in the
# densest band, where only the reads may speak.
# `foe` is untyped: a freed foe cannot pass a typed parameter (see _on_beat_word).
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
	# The word grows away from the ball, so a long one never covers it, and never lands on a
	# hostile warning, on any foe in view, on the marks stacked over a foe or on a rising damage
	# number: it takes the ball's other side, or the space just above the foe's marks, or stays
	# unsaid (PF-26).
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
			# The named foe's own body and, while it shows a mark, the marks over it. A foe outside the
			# "enemy" group (a plant, a test box) is covered here too.
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
			# A pixel past the gap: placed flush on the grown body's edge, float rounding put it on the foe one run in four.
			spots.append([cam.project_position(Vector2(p.x, whole.position.y - WORD_WARNING_GAP - tall * 0.6 - 1.0), maxf(depth, cam.near + 0.1)), right_of_ball])
		# Then a short fixed search beside the ball, so a fight that covers the asked spot still leaves
		# somewhere to stand: at the ball's height on its two sides, then below it, then above it, then two
		# drops below and above (a caption or a close-up panel beside the ball covers the near ones). The side the
		# word was asked on goes first. Each spot is pushed out of the lane ahead of the ball like the
		# asked one, and the word runs away from the ball (TONE-BIBLE pillar 2).
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


# A read word (DENT, ZZAP!): an armour class answering its first hit (armour_marks.gd). A read
# teaches, so it speaks past the sound words' budget (the gap, the repeat window, the densest
# band; it takes only a free slot and leaves the gap alone), but it keeps their placement: screen-share size, the safe area, the warning
# gap, render priority, and the foe's body kept clear. It stands beside the foe it names at
# mid-body, either side, else above the column of marks stacked on it; false when every spot is
# covered, every slot is showing or the foe is out of view, so the caller asks again next hit.
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
	# A pixel past the gap, as word() does: flush on the grown body's edge, rounding can touch it.
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


# The screen rect of the marks that stack over a foe and are not part of its body: the
# interrupted star, the class icon and the stagger word, STACK_LOW to STACK_TOP over its feet and
# STACK_HALF either side (the stagger word is the widest). Empty when it is behind the camera.
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


# Whether `foe` is showing a mark now (the interrupted star, the stagger word), asked of the owners
# of those marks: each joins MARKS_GROUP and answers marked(foe). The class icon is a mesh under
# the foe, so its body rect already holds it.
func _marked(foe) -> bool:
	if foe == null or not is_instance_valid(foe) or get_tree() == null:
		return false
	for owner_node in get_tree().get_nodes_in_group(MARKS_GROUP):
		if owner_node.marked(foe):
			return true
	return false


# A pooled word that is not showing, else the first of the pool.
func _free_slot() -> Dictionary:
	for w in _words:
		if w["t"] >= 1.0:
			return w
	return _words[0]


static func _text_px(label: Label3D, text: String) -> float:
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x


# Which of `spots` ([at, runs right]) a word takes: the first whose rect stands inside the safe
# area and covers none of `avoid`, else -1. Inside the safe area already, so the draw's pull never
# drags it back onto what it avoided.
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


# The hostile warnings' screen rects, grown by WORD_WARNING_GAP, read once a frame: a ram
# through a pack asks for a word per foe.
func _warnings() -> Array[Rect2]:
	var frame := Engine.get_process_frames()
	if frame != _warn_frame:
		_warn_frame = frame
		_warn_rects = warning_rects(get_tree(), camera.cam if camera != null else null, WORD_WARNING_GAP)
	return _warn_rects


# Everything a word keeps off, each rect grown by WORD_WARNING_GAP and tagged with a kind (_fight_kind,
# so a held word can say why): the hostile warnings ("warning"), each foe on screen ("foe"), the
# marks over a foe while it shows one ("marks", asked of the owners through MARKS_GROUP), and the
# paths of the damage numbers rising now ("number"). A damage number stays where the hit landed
# while its foe moves, so the numbers are read from the HUD layer, not guessed from the foe. A foe
# answers for its own silhouette when it has screen_bound_boxes() (Brindle's hull piece: the ship's
# oriented boxes); else its meshes are walked. Every foe rect is cut to the viewport (_view_rect), so
# a box that passes beside or behind the camera adds nothing instead of a screen-sized rect.
# Which foes count: a cheap origin test rejects a foe more than FOE_REACH_M behind the camera plane
# or farther off the screen's edge than that reach projects to, the box clip decides what is on
# screen, and a foe whose body is under FOE_MIN_PX on its longer side (with no mark) is skipped, as
# it is a dot no word can hide behind.
# Cost: read once per drawn frame, and only when a word asks (a stamped word, a held word, an
# on-beat grow). A refresh does one mesh walk or one box projection per part per foe that passes the
# origin test. spawned["fight_refresh"] counts refreshes.
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


# Why the asked spot (the first) of a held word was refused: "safe" when it stands outside the safe
# area, else the kind of the first avoided rect it touches ("warning", "foe", "marks", "number").
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


# Which spot a word takes: the first of `spots` (its own, the ball's other side, above the
# foe) that covers none of `avoid`, or -1 when every one does.
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


# The screen rects of `foe`'s drawn body, each cut to the viewport: one per box when the foe reports
# its own screen_bound_boxes() (Brindle's ship: oriented boxes in its own frame, [Transform3D, AABB]
# pairs), else one for its visible meshes. Empty without any of it on screen.
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


# The one rect that holds every rect of foe_rects (the named foe's body, a test's reading).
static func foe_rect(foe, cam: Camera3D) -> Rect2:
	var rects := foe_rects(foe, cam)
	if rects.is_empty():
		return Rect2()
	var out := rects[0]
	for r in rects:
		out = out.merge(r)
	return out


# The screen rect a word of `width_px` at `size` covers when its near end sits at `at` and it
# runs away from the ball (_draw_word's sizing, before the safe-area pull and the stamp's
# overshoot).
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
			return HEAT_COLOR
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


# Half the view's height in metres at `at`'s depth.
static func _half_height(cam: Camera3D, at: Vector3) -> float:
	var depth := maxf(0.5, -(cam.global_transform.affine_inverse() * at).z)
	return depth * tan(deg_to_rad(cam.fov) * 0.5)


# Pulls a point inside the safe share of the screen, at the same depth.
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


# A word never sits in the lane ahead of the ball: anything within LANE_M of the line the
# ball travels, in front of it, is pushed sideways out of the lane.
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
		# Ink-stamp in with overshoot, hold, then slide off on a diagonal (TONE-BIBLE UI motion).
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
		# The word's near end sits at the anchor and the word runs away from the ball; the
		# whole word, not its anchor, stays inside the safe area.
		var width_m: float = float(slot.get("width_px", 0.0)) * label.pixel_size * metres / 0.7
		at += basis.x * float(slot.get("away", 1.0)) * width_m * 0.5
		var px_per_m := cam.get_viewport().get_visible_rect().size.y / (2.0 * half)
		at = _in_safe_area(cam, at, Vector2(width_m * 0.5, metres * 0.6) * px_per_m)
		at += (basis.x + basis.y) * slide * half * 0.25
	basis = basis * Basis(Vector3.BACK, slot["tilt"])
	# The label's font is 96 px at 0.01 m a pixel, so ~0.7 m of cap height at scale 1.
	label.global_transform = Transform3D(basis.scaled(Vector3.ONE * metres * scale / 0.7), at)
	# Reduce flashes dims the coloured face, never the ink outline, so the word still reads.
	label.modulate.a = FlashGuard.info(alpha)
	label.outline_modulate = Color(INK.r, INK.g, INK.b, alpha)


# --- Impact frame ------------------------------------------------------------------------

func impact_frame(at: Vector3, strength: float) -> bool:
	if reduced_motion or _frame == null or _clock - _last_frame < FRAME_GAP_S:
		return false
	if camera == null or camera.cam == null or camera.cam.is_position_behind(at):
		return false
	_last_frame = _clock
	_frame.fire(camera.cam.unproject_position(at), strength, _rng.randi(), heat_k(might))
	spawned["impact_frame"] = spawned.get("impact_frame", 0) + 1
	return true


# The screen rect of every hostile warning, grown by `margin` px: the warning's world box,
# clipped at the camera's near plane and projected through `cam` (see _project_box); a warning
# with every corner behind is skipped. The box is the node's own screen_bound_box() when it
# has one and it is not empty: Telegraph and Hazard cut one at commit from their committed
# geometry (WarningBound), conservative over everything their painter draws at any progress,
# so a refresh projects 8 corners per warning and a telegraph walks no meshes; a hostile hazard
# stepped since its last read walks its own painter's meshes once on the read (lighting L7,
# #297). A node
# without one, or whose box is empty (a mark carried off its commit, a finished hazard), falls
# back to the mesh walk: its visual meshes' world boxes merged into one (see _merge_meshes).
# `use_bounds` false forces the walk, for the bench and the tests. Reusable by any 2D layer
# that must not cover warnings. The nodes come from Threat.GROUP, which every hostile mark
# joins (Telegraph._build for combat telegraphs, Hazard._ready for boss and world-event
# hazards) and no neutral or owned mark does (a Silo amber ring, a Warden lift).
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


# Grows `merged` ([box, any]) by the world box of every visible mesh under `node`. One box
# per warning means 8 projections instead of 8 per mesh. The merged box holds every mesh's
# box, so its screen rect is conservative: with the near-plane clip in _project_box it covers
# the whole on-screen footprint of every mesh, and a warning stays protected.
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


# Grows span (low, high) by the screen footprint of `box`: the 8 corners in front of the
# camera, and where each of the 12 edges crosses a plane just beyond the near plane. A box
# that crosses the near plane reaches the screen edge nearest the camera (the bottom, where
# the frame's band draws), and the crossing points are what put that part in the rect. A
# box with every corner behind adds nothing.
static func _project_box(box: AABB, cam: Camera3D, span: Array) -> void:
	for p in _box_points(Transform3D.IDENTITY, box, cam):
		_grow_span(span, p)


# The screen points a box stands for: its 8 corners (put through `xf` first, so a box in a body's own
# frame stays tight when the body turns) in front of the camera, and where each of its 12 edges
# crosses the near plane. Empty when no corner is in front.
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
	# Edges only cross the plane when some corners are in front and some are not; a box wholly
	# in front (the common case) or wholly behind has no crossing to add.
	if in_front == 0 or in_front == 8:
		return points
	# The edges join corners that differ in one bit.
	for c in 8:
		for bit in [1, 2, 4]:
			var other: int = c | bit
			if other == c or (depths[c] > plane) == (depths[other] > plane):
				continue
			var t: float = (plane - depths[c]) / (depths[other] - depths[c])
			points.append(cam.unproject_position(corners[c].lerp(corners[other], t)))
	return points


# The part of the viewport a set of screen points covers: their convex hull (the box's true
# footprint, as the box is convex) cut to the viewport, then its bounding rect. A box that passes
# beside or behind the camera has crossing points far off screen, so its bounding rect alone would
# cover the whole screen with nothing of the box on it; the hull cut leaves nothing, or only the
# part that is there. Empty when none of it is on screen.
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


# Manga focus lines: ink wedges pointing at the hit from the screen edge, only in the outer
# BAND of the screen, so the hit, the ball and every telegraph inside stay readable. The
# frame also yields at the edge: a pixel inside a live telegraph's screen rect, grown by
# YIELD_MARGIN_PX, is discarded by the frame's shader, because enemy warnings always draw on
# top of player effects (Andrew, 17 Oct 16:36Z; RENDER_PRIORITY above). The frame is a 2D
# layer that no 3D render priority can sort under, so it steps out of the way on the GPU:
# the CPU draws every wedge and wash quad and uploads only the rects.
class ImpactFrame:
	extends Control

	const LINES := 56
	# Lines live only in this share of the screen's short side, measured in from the edge.
	const BAND := 0.2
	# A wedge's half-width in px runs 5 to 16 at full strength (before the strength scale).
	const WEDGE_WIDTH_MIN := 5.0
	const WEDGE_WIDTH_MAX := 16.0
	# The room left around a warning is the widest wedge half-width, so no wedge edge sits
	# closer to a warning than the wedge is wide.
	const YIELD_MARGIN_PX := WEDGE_WIDTH_MAX
	# The shader's rect array. More live warnings than this and the frame cannot promise to
	# stay off all of them, so it draws nothing for that refresh (overflow_hides).
	const MAX_RECTS := 64
	# The rects arrive in the Control's local px: the Control is full-rect at the origin of a
	# CanvasLayer with an identity transform, and Camera3D.unproject_position answers in the
	# viewport's own px, the same space get_viewport_rect() sizes the Control in, so the
	# canvas_items content scale applies to both alike. The varying carries the local VERTEX,
	# not FRAGCOORD, so the window's y origin and scale do not matter.
	const YIELD_SHADER := """
shader_type canvas_item;
uniform vec4 rects[64];
uniform int rect_count = 0;
uniform float margin = 0.0;
varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	for (int i = 0; i < rect_count; i++) {
		vec4 r = rects[i];
		if (local.x > r.x - margin && local.x < r.x + r.z + margin && local.y > r.y - margin && local.y < r.y + r.w + margin) {
			discard;
		}
	}
}
"""
	var _focus := Vector2.ZERO
	var _strength := 0.0
	var _heat := 0.0
	var _left := 0
	var _seed := 0
	# Answers with the live warning rects, ungrown (PlayerFx.warning_rects on the game camera
	# with margin 0; the shader grows them); set by the owner: a bare warning_rects() call
	# from in here is a parse error ("not found in base self"), so the outer class hands the
	# function in.
	var rect_source := Callable()
	var _rects: Array[Rect2] = []
	var _uniform_rects := PackedVector4Array()
	var _material: ShaderMaterial
	# Pieces drawn by the last draw, for tests; a refresh past MAX_RECTS draws none.
	var drawn := 0
	var overflow_hides := 0
	var _overflowed := false
	# What a live frame costs, for the stress capture and the tests, in microseconds summed and
	# worst. A rect call is one refresh (the source and the uniform upload), made on every
	# live frame; a shape call is one build and draw of the pieces, made once per fire. A
	# frame that is not alive never refreshes or draws, so these stay put
	# (impact_frame_cost_test).
	var rect_calls := 0
	var rect_usec := 0
	var rect_usec_max := 0
	var shape_calls := 0
	var shape_usec := 0
	var shape_usec_max := 0
	# The viewport size the pieces were drawn for.
	var _drawn_size := Vector2.ZERO

	func _ready() -> void:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		visible = false
		_ensure_material()

	# Built once per frame, here or on the first rects, so a frame never in a tree can be fed.
	func _ensure_material() -> void:
		if _material != null:
			return
		var shader := Shader.new()
		shader.code = YIELD_SHADER
		_uniform_rects.resize(MAX_RECTS)
		_material = ShaderMaterial.new()
		_material.shader = shader
		_material.set_shader_parameter("margin", YIELD_MARGIN_PX)
		_material.set_shader_parameter("rect_count", 0)
		_material.set_shader_parameter("rects", _uniform_rects)
		material = _material

	func fire(focus: Vector2, strength: float, seed_value: int, heat_value := 0.0) -> void:
		_focus = focus
		_strength = strength
		_heat = heat_value
		_left = FRAME_FRAMES
		_seed = seed_value
		position = Vector2.ZERO
		size = get_viewport_rect().size
		visible = true
		_refresh_rects()
		queue_redraw()

	func hide_now() -> void:
		_left = 0
		visible = false

	func active() -> bool:
		return _left > 0

	func _process(_delta: float) -> void:
		if _left <= 0:
			return
		_left -= 1
		if _left <= 0:
			visible = false
		else:
			# Warnings and the camera move while the frame lives, so the rects are sent again.
			# The pieces depend only on what fire() set and the viewport size, so the canvas
			# keeps its draw commands; a resized viewport redraws (checked per frame).
			_refresh_rects()
			if get_viewport_rect().size != _drawn_size:
				size = get_viewport_rect().size
				queue_redraw()

	func _refresh_rects() -> void:
		var began := Time.get_ticks_usec()
		apply_rects(rect_source.call() if rect_source.is_valid() and is_inside_tree() else ([] as Array[Rect2]))
		var cost := Time.get_ticks_usec() - began
		rect_calls += 1
		rect_usec += cost
		rect_usec_max = maxi(rect_usec_max, cost)

	# Takes the warning rects: keeps them and writes them to the shader. More than MAX_RECTS
	# cannot be written whole, so the frame hides itself while they overflow, and draws
	# again (a redraw, since an overflowed fire drew nothing) once they fit.
	func apply_rects(found: Array) -> void:
		_ensure_material()
		var was_overflowed := _overflowed
		_overflowed = found.size() > MAX_RECTS
		if _overflowed:
			overflow_hides += 1
			_rects = []
			_material.set_shader_parameter("rect_count", 0)
			visible = false
			return
		if _left > 0:
			visible = true
			if was_overflowed:
				queue_redraw()
		_rects.assign(found)
		for k in found.size():
			var r: Rect2 = found[k]
			_uniform_rects[k] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
		_material.set_shader_parameter("rects", _uniform_rects)
		_material.set_shader_parameter("rect_count", found.size())

	# The shader's test in GDScript, for the tests: whether a local px point is discarded by
	# the first `count` rects grown by `margin`. A point exactly on the grown edge stays.
	static func _yields(point: Vector2, rects: Array, count: int, margin: float) -> bool:
		for k in mini(count, rects.size()):
			var r: Rect2 = rects[k]
			if point.x > r.position.x - margin and point.x < r.end.x + margin and point.y > r.position.y - margin and point.y < r.end.y + margin:
				return true
		return false

	func _draw() -> void:
		drawn = 0
		if _overflowed:
			return
		var began := Time.get_ticks_usec()
		_drawn_size = get_viewport_rect().size
		for shape in _shapes(_drawn_size):
			drawn += 1
			if shape.has("colors"):
				draw_polygon(shape["poly"], shape["colors"])
			else:
				draw_colored_polygon(shape["poly"], shape["color"])
		var cost := Time.get_ticks_usec() - began
		shape_calls += 1
		shape_usec += cost
		shape_usec_max = maxi(shape_usec_max, cost)

	# Every piece the frame is made of, in draw order: {poly, colors} for the wash and
	# {poly, color} for a wedge.
	func _shapes(rect: Vector2) -> Array:
		var out := []
		var band := minf(rect.x, rect.y) * BAND
		var focus := _focus.clamp(Vector2.ZERO, rect)
		var rng := RandomNumberGenerator.new()
		rng.seed = _seed
		if _heat > 0.0:
			_wash_shapes(out, rect, band)
		for i in int(LINES * _strength):
			var angle := TAU * (float(i) + rng.randf() * 0.8) / float(LINES * _strength)
			var dir := Vector2(cos(angle), sin(angle))
			# Where the ray from the focus leaves the screen.
			var exit := INF
			if dir.x > 0.001:
				exit = minf(exit, (rect.x - focus.x) / dir.x)
			elif dir.x < -0.001:
				exit = minf(exit, -focus.x / dir.x)
			if dir.y > 0.001:
				exit = minf(exit, (rect.y - focus.y) / dir.y)
			elif dir.y < -0.001:
				exit = minf(exit, -focus.y / dir.y)
			if exit == INF or exit < 1.0:
				continue
			var inner := maxf(0.0, exit - band * rng.randf_range(0.5, 1.0))
			var width := rng.randf_range(WEDGE_WIDTH_MIN, WEDGE_WIDTH_MAX) * (0.6 + 0.4 * _strength)
			var side := Vector2(-dir.y, dir.x) * width
			var tip := focus + dir * inner
			var outer := focus + dir * (exit + width * 2.0)
			# Every third line of a hot build burns heat orange; a cold build keeps a few white.
			var accent := i % (3 if _heat > 0.0 else 7) == 0
			var ink := INK
			ink.a = 0.75 + 0.2 * _heat
			if accent:
				ink = Color(1, 1, 1, 0.5).lerp(Color(HEAT_COLOR.r, HEAT_COLOR.g, HEAT_COLOR.b, 0.9), _heat)
				ink.a = FlashGuard.alpha(ink.a)
			out.append({"poly": PackedVector2Array([tip, outer + side, outer - side]), "color": ink})
		return out

	# A hot build's edge wash: the screen edge dips dark, glows heat orange halfway in and
	# fades to nothing before the middle, so the build's heat and weight read on every grown
	# hit and the centre stays clear.
	func _wash_shapes(out: Array, rect: Vector2, band: float) -> void:
		var dark := Color(INK.r, INK.g, INK.b, 0.8 * _heat)
		var hot := Color(HEAT_COLOR.r, HEAT_COLOR.g, HEAT_COLOR.b, FlashGuard.alpha(0.4 * _heat))
		var clear := Color(hot.r, hot.g, hot.b, 0.0)
		_ring_shapes(out, rect, 0.0, band * 0.6, dark, hot)
		_ring_shapes(out, rect, band * 0.6, band, hot, clear)

	# A screen-edge ring from `outer` to `inner` pixels in, shaded from one colour to the other.
	# Each side is one trapezoid keeping the side's four vertex colours.
	func _ring_shapes(out: Array, rect: Vector2, outer: float, inner: float, from: Color, to: Color) -> void:
		var o := [Vector2(outer, outer), Vector2(rect.x - outer, outer), rect - Vector2(outer, outer), Vector2(outer, rect.y - outer)]
		var i := [Vector2(inner, inner), Vector2(rect.x - inner, inner), rect - Vector2(inner, inner), Vector2(inner, rect.y - inner)]
		var colors := PackedColorArray([from, from, to, to])
		for k in 4:
			var n := (k + 1) % 4
			out.append({"poly": PackedVector2Array([o[k], o[n], i[n], i[k]]), "colors": colors})


# --- Aura --------------------------------------------------------------------------------

func _build_aura() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.11
	mesh.height = 0.22
	mesh.radial_segments = 4
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
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
	# Grown builds trail their motes as streamers along the ball's motion.
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
		# A new part drops in from above and settles into the ring.
		var at := centre + ring + Vector3.UP * (1.0 - ease(arrive, 0.4)) * 4.0
		var size := (0.8 + 0.5 * might) * (1.0 + 0.9 * _mote_flare)
		var basis := Basis.looking_at(along, Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT)
		basis = basis.scaled(Vector3(size, size, size * stretch))
		mm.set_instance_transform(i, Transform3D(basis, at))
		var c: Color = heat_tint(_mote_colors[i])
		mm.set_instance_color(i, c.lerp(Color.WHITE, FlashGuard.whiten(0.6 * _mote_flare)))


# --- Overdrive ---------------------------------------------------------------------------

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


# One step of the overdrive switch: on at SOFT_CAP_MPS, off under SOFT_CAP_OFF_MPS, so a
# speed on the line never flickers it. Returns true on the frame it ignites.
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
			vfx.glyph("overdrive", back, 0.8, 4.0, 0.3, v, "ring", HEAT_COLOR)
	var on := heat > 0.01
	# Heat on the shell (redline.gd) lights the same rim before overdrive does: mint at a quarter,
	# amber when hot, white at redline. Overdrive's own heat wins when it is the brighter.
	var shell := shell_heat() if _shell_band > 0 else 0.0
	var lit := maxf(heat, shell)
	_rim.visible = lit > 0.01
	var ball: Vector3 = player.shown_position()
	if lit > 0.01:
		_rim.global_position = ball
		# A hot shell keeps its own colour over overdrive's: the risk reads first.
		var red = player.get("redline")
		var shell_wins: bool = shell > 0.0 and (heat < shell or red.hot())
		var rim: Color = shell_color(red) if shell_wins else OVERDRIVE_RIM
		# The kettle's twin: over the last Redline.KETTLE_S of the fuse the rim beats to full heat
		# in the hazard colour, in step with the whistle (redline.gd kettle_pulse).
		# The beat runs 4 to 10 Hz, so Reduce flashes holds it steady, as FlashGuard.blink does.
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


# --- Heat on the shell ------------------------------------------------------------------
# The shell's heat (redline.gd) carries itself in colour, motion, sound and the pad, never a bar
# (ruling cx): the rim warms mint, amber, white; a blast stamps its word and draws its true ring;
# the pad (juice.gd heat_* rumble rows) buzzes while the shell waits at redline and thumps on the blast.
const OVERDRIVE_RIM := Color(1.0, 0.62, 0.24)
const SHELL_COLORS := [Color(0.45, 1.0, 0.75), Color(1.0, 0.72, 0.25), Color(1.0, 0.98, 0.92)]
# The rim's brightness at full heat, under overdrive's 1.0 so the soft cap still reads above it.
const SHELL_RIM := 0.7
const BLAST_RING := Color(1.0, 0.97, 0.9)
var _shell_band := 0


# 0 to SHELL_RIM, how bright the rim burns for the shell's heat; 0 when the flag is not on.
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


# --- Carve sparks ------------------------------------------------------------------------

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
	# A carve needs a heading: a ball at rest on a steep face (the pose's speed tier can lag a stop) has none.
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


# --- Column ------------------------------------------------------------------------------

func column(tint: Color, at := Vector3.INF) -> void:
	var p: GPUParticles3D = _columns[_column_next]
	_column_next = (_column_next + 1) % _columns.size()
	var base: Vector3 = player.shown_position() - Vector3.UP * 0.8 if at == Vector3.INF else at
	p.global_transform = Transform3D(Basis.IDENTITY, base)
	p.set_instance_shader_parameter("tint", _glow(heat_tint(tint), 1.15))
	p.amount_ratio = clampf(0.5 + 0.5 * might, 0.0, 1.0)
	FxLibrary.set_heat(p)
	p.restart()
	p.emitting = true
	spawned["column"] = spawned.get("column", 0) + 1


# --- Emitters ----------------------------------------------------------------------------

# The shape gives the look (FxLibrary._LOOKS): a long box is a streak along its motion, a ball
# or a cube a soft glow.
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
	p.set_instance_shader_parameter("tint", Color.WHITE)
	root.add_child(p)
	return p


static func _glow(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, 1.0)


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _ball(d: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = d * 0.5
	s.height = d
	s.radial_segments = 6
	s.rings = 3
	return s


static func _ramp(stops: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(stops.map(func(s): return s[0]))
	g.colors = PackedColorArray(stops.map(func(s): return s[1]))
	var tex := GradientTexture1D.new()
	tex.gradient = g
	return tex


static func _fade(end: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 1.0))
	c.add_point(Vector2(1.0, end))
	var tex := CurveTexture.new()
	tex.curve = c
	return tex


static func _flecks_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 16.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 11.0
	pm.gravity = Vector3(0, 3.0, 0)
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.7
	pm.scale_min = 0.7
	pm.scale_max = 1.4
	pm.scale_curve = _fade(0.2)
	pm.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.75, 1.0)], [0.25, Color(1.0, 0.6, 0.18, 1.0)],
		[0.65, Color(0.85, 0.24, 0.08, 0.85)], [1.0, Color(0.2, 0.08, 0.06, 0.0)]])
	return pm


static func _embers_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, -1)
	pm.spread = 40.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 1.5
	pm.gravity = Vector3(0, 1.4, 0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.9
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pm.scale_curve = _fade(0.0)
	pm.color_ramp = _ramp([[0.0, Color(1.0, 0.7, 0.3, 1.0)], [0.5, Color(0.9, 0.35, 0.12, 0.9)], [1.0, Color(0.35, 0.1, 0.06, 0.0)]])
	return pm


static func _carve_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0.35, -1)
	pm.spread = 22.0
	pm.initial_velocity_min = 7.0
	pm.initial_velocity_max = 14.0
	pm.gravity = Vector3(0, -22.0, 0)
	pm.particle_flag_align_y = true
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = _fade(0.1)
	pm.color_ramp = _ramp([[0.0, Color(1.0, 0.95, 0.7, 1.0)], [0.35, Color(1.0, 0.72, 0.25, 1.0)], [1.0, Color(0.8, 0.3, 0.1, 0.0)]])
	return pm


static func _column_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 6.0
	pm.initial_velocity_min = 6.0
	pm.initial_velocity_max = 11.0
	pm.radial_velocity_min = -1.6
	pm.radial_velocity_max = -1.0
	pm.gravity = Vector3(0, -2.0, 0)
	pm.particle_flag_align_y = true
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3.UP
	pm.emission_ring_radius = 1.6
	pm.emission_ring_inner_radius = 1.3
	pm.emission_ring_height = 0.0
	pm.scale_curve = _fade(0.0)
	pm.alpha_curve = _fade(0.0)
	return pm


static func _boon_material() -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0
	pm.initial_velocity_max = 9.0
	pm.gravity = Vector3(0, -6.0, 0)
	pm.angular_velocity_min = -540.0
	pm.angular_velocity_max = 540.0
	pm.scale_curve = _fade(0.0)
	pm.alpha_curve = _fade(0.0)
	return pm


# The most particles this layer can hold alive at once, for the notes.
static func ceiling() -> int:
	return FLECKS + EMBERS + CARVE + COLUMN * COLUMN_POOL + BOON * BOON_POOL


# --- Frame -------------------------------------------------------------------------------

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


# Hides the word layer while the tree is paused, as flourish_player hides its own: a word stamped
# before a pause would otherwise stay frozen over the menu.
class PauseGuard extends Node:
	var root: Node3D

	func _init() -> void:
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(_delta: float) -> void:
		if root != null and is_instance_valid(root):
			root.visible = not get_tree().paused
