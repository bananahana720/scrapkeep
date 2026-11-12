extends Node

const FxLibrary := preload("res://src/presentation/fx_library.gd")
const Palette := preload("res://src/core/palette.gd")
const Density := preload("res://src/presentation/density.gd")
const Roster := preload("res://src/combat/roster.gd")
const EnemyMotion := preload("res://src/presentation/enemy_motion.gd")
const BossPosture := preload("res://src/combat/boss_posture.gd")
const SpecialCues := preload("res://src/combat/special_cues.gd")
const ScreenRegions := preload("res://src/ui/screen_regions.gd")
const FlashGuard := preload("res://src/presentation/flash_guard.gd")

# What the machines throw off: how a pack arrives, how a body winds up, takes a hit,
# staggers and dies, how the four specials tell you what they are about to do, and how
# Brindle, the Waking and the Mind change phase and fall. Fleet crews are steam and brass
# (they leak, hiss and spark); ancients are their seam light (it crawls, fizzes and
# gutters out) and cast shell. Comic words (KLANG, SHIFT OVER) stamp on the big moments.
#
# Readability (FEEL-READABILITY 1.1): nothing here is committed geometry. The telegraph
# owns the read and draws above all of this; these effects sit on or over the body, never
# across the footprint. Body effects are P5 and steam and motes P7, so the density
# governor thins them. A special's tell is the exception: it is a read, so it is never
# thinned and always gets its word. One pack's arrival effects start on the frame its
# arrival rings do, so they share the rings' timing and the 0.2 s gap rule between packs.
#
# Timing contract with audio: a special fires its tell through SpecialCues.tell(), which
# emits the body's special_tell(moment) once; audio.gd (the sound) and special_rig.gd (the
# clip) answer the same emit, so the picture and the sound come off one frame. SpecialCues
# names the sound ids.

const FAMILY := {Roster.FLEET: "fleet", Roster.REACTOR: "ancient", Roster.SWARM: "ancient", Roster.MIND: "ancient"}
# Spec id -> particle count, per family and moment. "windup" and "stagger" are persistent
# emitters that follow the body; the rest fire once.
const MOMENTS := {
	"fleet": {
		"arrive": {"steam_puff": 6, "brass_spark": 8},
		"arriving": {"steam_jet": 10},
		"windup": {"steam_jet": 10},
		"release": {"steam_puff": 4},
		"hit": {"brass_spark": 5},
		"heavy": {"brass_spark": 14, "steam_puff": 4},
		"chunk": {"plate_chunks": 12, "brass_spark": 16, "steam_puff": 6},
		"death": {"steam_puff": 5, "brass_spark": 10},
		"stagger": {"steam_jet": 10},
	},
	"ancient": {
		"arrive": {"seam_motes": 12, "arc_fizz": 6},
		"arriving": {"arc_crawl": 8},
		"windup": {"arc_crawl": 10},
		"release": {"arc_fizz": 8},
		"hit": {"arc_fizz": 5},
		"heavy": {"arc_fizz": 12, "shell_shards": 6},
		"chunk": {"shell_shards": 14, "arc_fizz": 14, "seam_motes": 10},
		"death": {"seam_motes": 10, "arc_fizz": 10},
		"stagger": {"arc_crawl": 10},
	},
}
const WORDS := {"fleet_heavy": "KLANG", "ancient_heavy": "KRZZT", "stagger": "KRNK", "elite": "CLOCKED OUT"}
# Every glyph the uppercase words draw (WORDS, SPECIALS, BOSSES, the fall words and the panel pops).
const WARM_GLYPHS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?.,'+-%"
const WORD_TINT := {"fleet": Palette.BRASS, "ancient": Palette.ANCIENT}

# The four kill-first specials (ENEMY-PRIORITY.md 4, 4a; SOUND-BIBLE specials). Each
# moment lists its effects, an optional tint for "row" specs and an optional word; the
# sound each moment plays is SpecialCues.sound(special, moment).
const SPECIALS := {
	"foreman": {"family": "fleet", "presence": {"steam_jet": 3},
		"spawn": {"steam_puff": 8, "brass_spark": 8},
		"tell": {"steam_puff": 10, "phase_ring": 40}, "tell_tint": Palette.BRASS, "tell_word": "HOOONK",
		"break": {"steam_puff": 10, "brass_spark": 16}, "break_word": "SHIFT OVER"},
	"dispatcher": {"family": "fleet", "presence": {},
		"spawn": {"brass_spark": 8, "phase_ring": 24}, "spawn_tint": Palette.AMBER,
		"tell": {"steam_puff": 8, "phase_ring": 24}, "tell_tint": Palette.AMBER, "tell_word": "NEXT",
		"break": {"brass_spark": 16, "steam_puff": 4}, "break_word": "OUT OF ORDER"},
	"splitter": {"family": "fleet", "presence": {"fuse_sputter": 6},
		"spawn": {"brass_spark": 8},
		"tell": {"brass_spark": 16, "phase_ring": 30}, "tell_tint": Palette.SAND, "tell_word": "1+1+1",
		"break_split": {"brass_spark": 10, "steam_puff": 6}, "break_split_word": "UNION RULES",
		"break_clean": {"brass_spark": 16, "steam_puff": 3}, "break_clean_word": "CLEAN"},
	"linker": {"family": "fleet", "presence": {},
		"spawn": {"brass_spark": 8},
		"tell": {"brass_spark": 10}, "tell_word": "TWANG", "cable": true,
		"break": {"brass_spark": 16, "plate_chunks": 6}, "break_word": "CLANG"},
}

# The bosses: a phase change and the fall. The fall is played straight first (a run of
# blasts across the body, then one ring), and the wink word lands one beat after it.
const BOSSES := {
	"brindle": {"family": "fleet", "tint": Palette.BRASS, "reach": 8.0,
		"phase": {"phase_ring": 64, "steam_puff": 10, "brass_spark": 16, "plate_chunks": 12}, "phase_word": "",
		"eject_word": "EJECT"},
	"waking": {"family": "ancient", "tint": Palette.ANCIENT, "reach": 5.0,
		"phase": {"phase_ring": 64, "arc_fizz": 14, "shell_shards": 14, "seam_motes": 12}, "phase_word": "KRAKK",
		"fall_word": "BACK TO SLEEP"},
	"mind": {"family": "ancient", "tint": Palette.ANCIENT, "reach": 5.0,
		"phase": {"phase_ring": 64, "arc_fizz": 14, "shell_shards": 14, "seam_motes": 12}, "phase_word": "RECALIBRATING",
		"fall_word": "SIGNAL LOST"},
}
const FALL_BLASTS := 5
const FALL_GAP := 0.22
# One beat at the 129 BPM fight tempo: the wink waits this long after the last blast.
const WINK_DELAY := 60.0 / 129.0

const WORD_POOL := 4
const WORD_LIFE := 0.9
const WORD_SLAM := 0.06
const WORD_GAP := 0.4
const WORD_HEIGHT := 3.2
# No word holds wider on screen than this share of the view's HEIGHT (its slam, the first
# WORD_SLAM seconds, may pass it, up to 1.6 times). Words are sized in metres, so one stamped
# beside the camera (a panel pickup's pop sits at the ball) was a wall of letters over the HUD.
# The room is a share of the height, as the player's own words are sized (player_fx.gd
# WORD_SCREEN), so letters stand as tall on an ultrawide screen as on 16:9: 0.9 of the height is
# 0.51 of a 16:9 view's width and 0.38 of a 21:9 view's. Every machine word shares this room
# (hits, tells, a boss's phase and fall words), not only the pickup's pop.
const WORD_FIT := 0.9
const HIT_GAP := 0.12
const HITS_PER_TENTH := 8
const DAZE_SPIN := 4.0
const SAMPLE_SECONDS := 0.1

var ctx
var root: Node3D
# spec id or moment -> count fired, for the tests and the notes.
var spawned := {}
# [clock, moment, who, at]: the last LOG_KEEP moments, for tests and captures.
var moments: Array = []
const LOG_KEEP := 64
var reduced_motion := false

var _fx := {}
var _fx_next := {}
var _busy := {}
# Follows: {emitter, node, lift, until (or INF), spin}
var _follows: Array = []
var _windups := {}
var _dazes := {}
var _arrivals := {}
var _chunks := {}
var _last_hit := {}
var _hits_window := 0
var _hits_clock := 0.0
var _words: Array = []
var _word_next := 0
var _last_word := -INF
var _cables: Array = []
var _cable_mesh: ImmediateMesh
var _cable_rng := RandomNumberGenerator.new()
var _queue: Array = []
var _clock := 0.0
var _sample := 0.0
var _boss_at := Vector3.ZERO
var director_ref = null


func setup(ctx_ref) -> void:
	ctx = ctx_ref
	name = "MachineFx"
	_cable_rng.seed = 0x1C4
	root = Node3D.new()
	root.name = "MachineEffects"
	ctx.root.add_child(root)
	for id in FxLibrary.SPECS:
		if FxLibrary.SPECS[id].get("owner", "vfx") != "machine":
			continue
		var pool: Array = []
		for i in int(FxLibrary.SPECS[id]["pool"]):
			var p := FxLibrary.build(id)
			p.name = "%s_%d" % [p.name, i]
			root.add_child(p)
			pool.append(p)
		_fx[id] = pool
		_fx_next[id] = 0
	for i in WORD_POOL:
		_words.append(_make_word())
	var view := MeshInstance3D.new()
	view.name = "CableArcs"
	_cable_mesh = ImmediateMesh.new()
	view.mesh = _cable_mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	view.material_override = mat
	root.add_child(view)
	var events = ctx.events
	SignalWire.listen(events, "enemy_spawned", _on_spawned)
	SignalWire.listen(events, "enemy_struck", _on_struck)
	SignalWire.listen(events, "posture_changed", _on_posture)
	SignalWire.listen(events, "boss_phase_changed", _on_boss_phase)
	SignalWire.listen(events, "boss_defeated", _on_boss_defeated)
	SignalWire.listen(events, "stage_entered", func(_stage: int, _retry: bool): clear())
	SignalWire.listen(events, "stage_content_cleared", func(_reason: String): clear())


static func family_of(faction: String) -> String:
	return FAMILY.get(faction, "fleet")


static func family_of_kind(kind: String) -> String:
	return family_of(String(Roster.row(kind).get("faction", Roster.FLEET)))


# The special a body is ("" for none) and the sound a special's moment plays: one row,
# SpecialCues, keys audio and these effects.
static func special_of(enemy: Node) -> String:
	return SpecialCues.special_of(enemy)


static func special_sound(special: String, moment: String) -> String:
	return SpecialCues.sound(special, moment)


func clear() -> void:
	for id in _fx:
		for p: GPUParticles3D in _fx[id]:
			p.emitting = false
	_busy.clear()
	_follows.clear()
	_windups.clear()
	_dazes.clear()
	_arrivals.clear()
	_chunks.clear()
	_last_hit.clear()
	_cables.clear()
	_queue.clear()
	for w in _words:
		w["node"].visible = false
		w["t"] = INF
	if _cable_mesh != null:
		_cable_mesh.clear_surfaces()


# --- Firing ----------------------------------------------------------------------------

# Fires a set of one-shot specs ({id: count}) at one place; a "row" spec takes `tint`. `cls` is the priority class:
# "P1" is never thinned (a special's tell), "P5" and "P7" follow the governor.
func fire(effects: Dictionary, at: Vector3, tint := Color.TRANSPARENT, cls := "P5") -> int:
	if root == null or not root.is_inside_tree():
		return 0
	var fired := 0
	for id in effects:
		var count := _thin(int(effects[id]), _class_of(id, cls))
		if count <= 0 or not _fx.has(id) or FxLibrary.SPECS[id]["attach"] != "world":
			continue
		var pool: Array = _fx[id]
		var p: GPUParticles3D = pool[_fx_next[id]]
		_fx_next[id] = (_fx_next[id] + 1) % pool.size()
		# A moment's tint colours only its "row" specs (rings); steam stays steam.
		FxLibrary.fire(p, id, "enemy_struck", count, at, tint if FxLibrary.SPECS[id]["colour"] == "row" else Color.TRANSPARENT)
		spawned[id] = spawned.get(id, 0) + 1
		fired += 1
	return fired


# Steam and motes are ambient (P7) inside any moment; sparks, shards and rings keep the
# moment's class.
static func _class_of(id: String, cls: String) -> String:
	if cls == "P1":
		return cls
	return "P7" if id in ["steam_puff", "steam_jet", "seam_motes"] else cls


func _thin(count: int, cls: String) -> int:
	if not cls in Density.GOVERNED_CLASSES:
		return count
	var band: Dictionary = Density.live().band()
	var keep := float(band["alpha"]) / 0.9
	if cls == "P7":
		keep *= keep
	return int(round(count * keep))


# A persistent emitter that follows `node` (lifted `lift` metres) until stop_follow or
# `seconds` run out; null when the pool is busy (the effect is candy, so it just skips).
func follow(id: String, node: Node3D, count: int, lift: float, seconds := INF, tint := Color.TRANSPARENT, spin := 0.0) -> GPUParticles3D:
	if not _fx.has(id) or not is_instance_valid(node) or count <= 0:
		return null
	for p: GPUParticles3D in _fx[id]:
		if _busy.has(p):
			continue
		_busy[p] = true
		p.amount_ratio = clampf(float(count) / float(p.amount), 0.0, 1.0)
		p.global_transform = Transform3D(Basis.IDENTITY, node.global_position + Vector3.UP * lift)
		p.set_instance_shader_parameter("tint", tint if tint.a > 0.0 else FxLibrary.colour(id, "enemy_struck"))
		FxLibrary.set_heat(p, FxLibrary.look(id))
		p.emitting = true
		_follows.append({"emitter": p, "node": node, "lift": lift, "until": _clock + seconds, "spin": spin})
		spawned[id] = spawned.get(id, 0) + 1
		return p
	return null


func stop_follow(p: GPUParticles3D) -> void:
	if p == null:
		return
	p.emitting = false
	_busy.erase(p)
	_follows = _follows.filter(func(f: Dictionary): return f["emitter"] != p)


func _note(moment: String, who: String, at: Vector3) -> void:
	moments.append([_clock, moment, who, at])
	if moments.size() > LOG_KEEP:
		moments.pop_front()
	spawned[moment] = spawned.get(moment, 0) + 1


# --- Words -----------------------------------------------------------------------------

func _make_word() -> Dictionary:
	var label := word_label()
	label.visible = false
	root.add_child(label)
	return {"node": label, "t": INF, "life": WORD_LIFE, "at": Vector3.ZERO, "scale": 1.0}


static func word_label() -> Label3D:
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 112
	label.pixel_size = 0.01
	label.outline_size = 30
	label.outline_modulate = Palette.CHARCOAL
	label.uppercase = true
	label.double_sided = true
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label.render_priority = 20
	label.outline_render_priority = 19
	label.name = "Word"
	return label


# A word label showing `glyphs`, for BakeWarm, which shows every glyph a word can draw: the first word of a run (KLANG
# on a heavy hit) otherwise rasterizes its glyphs at this size and outline in the frame's deferred
# Label3D update (stage 1 f3822, 44 ms of a 106-121 ms frame on the cloud box).
static func warm_views(glyphs: String) -> Array[Node3D]:
	var label := word_label()
	label.text = glyphs
	return [label]


# Stamps a drawn sound word over `at`: three frames of overshoot, a hold, then it slides
# off on a diagonal (TONE-BIBLE UI motion). `force` words are reads or set pieces and
# ignore the gap and the density skip; the rest are candy.
func word(text: String, at: Vector3, tint: Color, force := false, life := WORD_LIFE, size := 1.0) -> bool:
	if root == null or not root.is_inside_tree() or text == "":
		return false
	if not force and (_clock - _last_word < WORD_GAP or Density.live().value >= 0.7):
		return false
	_last_word = _clock
	var slot: Dictionary = _words[_word_next]
	_word_next = (_word_next + 1) % _words.size()
	var label: Label3D = slot["node"]
	label.text = text
	label.modulate = tint
	label.visible = true
	slot["t"] = 0.0
	slot["life"] = life
	slot["at"] = at
	slot["scale"] = size
	var font: Font = label.font if label.font != null else ThemeDB.fallback_font
	slot["width_px"] = font.get_string_size(text.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, label.font_size).x + label.outline_size
	_draw_word(slot)
	_note("word", text, at)
	return true


func _draw_word(slot: Dictionary) -> void:
	var label: Label3D = slot["node"]
	var t: float = slot["t"]
	var life: float = slot["life"]
	var size: float = slot["scale"]
	var at: Vector3 = slot["at"]
	size = _fit(slot, at, size)
	if not reduced_motion and t < WORD_SLAM:
		size *= lerpf(1.6, 1.0, t / WORD_SLAM)
	at = _below_top(slot, at, size)
	var leave := clampf((t - (life - 0.25)) / 0.25, 0.0, 1.0)
	if leave > 0.0:
		var side := Vector3.RIGHT
		var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
		if cam != null:
			side = cam.global_basis.x
		if not reduced_motion:
			at += (side + Vector3.UP) * leave * 1.2
	label.global_position = at
	label.scale = Vector3.ONE * size
	# Reduce flashes dims the coloured face, never the ink outline, so the word still reads.
	label.modulate.a = FlashGuard.info(1.0 - leave)
	label.outline_modulate.a = 1.0 - leave


# `at`, lowered along the view's up so the word's top stays under the HUD's top band. A tall body's
# break word (SHIFT OVER on the foreman, OUT OF ORDER on the dispatcher) stood over the objective
# plate with its letters cut off by the screen's top edge (the death reel, 10 Nov 2026).
func _below_top(slot: Dictionary, at: Vector3, size: float) -> Vector3:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null or cam.is_position_behind(at):
		return at
	var label: Label3D = slot["node"]
	var screen := cam.unproject_position(at)
	var px_per_m := cam.unproject_position(at + cam.global_basis.y).distance_to(screen)
	var half := label.font_size * label.pixel_size * size * px_per_m * 0.5
	var top := get_viewport().get_visible_rect().size.y * ScreenRegions.BANDS["top"].y
	var over := top - (screen.y - half)
	if over <= 0.0 or px_per_m <= 0.0:
		return at
	return at - cam.global_basis.y * (over / px_per_m)


# `size`, held down so the word at `at` is no wider on screen than WORD_FIT of the view's height.
func _fit(slot: Dictionary, at: Vector3, size: float) -> float:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var width_m: float = float(slot.get("width_px", 0.0)) * (slot["node"] as Label3D).pixel_size * size
	if cam == null or width_m <= 0.0 or cam.is_position_behind(at):
		return size
	var px_per_m := cam.unproject_position(at + cam.global_basis.x).distance_to(cam.unproject_position(at))
	var room := get_viewport().get_visible_rect().size.y * WORD_FIT
	return size if width_m * px_per_m <= room else size * room / (width_m * px_per_m)


# --- Bodies: arrival, wind-up, hits, stagger, death -----------------------------------

func _on_spawned(enemy: Node3D, kind: String) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var family := family_of(String(enemy.get("faction"))) if enemy.get("faction") != null else family_of_kind(kind)
	var at := enemy.global_position
	var special := special_of(enemy)
	if special != "":
		SpecialCues.attach(enemy)
		special_moment(special, "spawn", enemy)
		var presence: Dictionary = SPECIALS[special]["presence"]
		for id in presence:
			follow(id, enemy, int(presence[id]), _lift(enemy) + 0.6)
	else:
		fire(MOMENTS[family]["arrive"], at)
		_note("arrive", family, at)
	if enemy.has_signal("attack_phase"):
		enemy.attack_phase.connect(_on_phase.bind(enemy, family))
	if enemy.has_signal("special_tell"):
		enemy.connect("special_tell", _on_special_tell.bind(enemy))
	if enemy.has_signal("died"):
		enemy.died.connect(_on_died.bind(enemy, kind, family))
	enemy.tree_exiting.connect(_forget.bind(enemy))


func _forget(enemy: Node3D) -> void:
	for f in _follows.duplicate():
		if f["node"] == enemy:
			stop_follow(f["emitter"])
	var id := enemy.get_instance_id()
	_windups.erase(id)
	_dazes.erase(id)
	_last_hit.erase(id)
	_chunks.erase(id)


static func _lift(enemy: Node3D) -> float:
	var h = enemy.get("half_height")
	return float(h) if h != null else 1.2


# A wind-up hisses (Fleet: a steam jet off the body that builds) or crawls (ancients:
# seam light orbiting the body) until it strikes, when it lets go in one puff.
func _on_phase(facts: Dictionary, enemy: Node3D, family: String) -> void:
	if not is_instance_valid(enemy):
		return
	var id := enemy.get_instance_id()
	var phase := String(facts.get("phase", ""))
	if phase == "windup":
		if _windups.has(id):
			return
		var spec: Dictionary = MOMENTS[family]["windup"]
		var key: String = spec.keys()[0]
		var p := follow(key, enemy, int(spec[key]), _lift(enemy) + 0.4)
		if p != null:
			p.amount_ratio *= 0.3
			_windups[id] = {"emitter": p, "enemy": enemy, "full": int(spec[key])}
			_note("windup", family, enemy.global_position)
		return
	if _windups.has(id):
		stop_follow(_windups[id]["emitter"])
		_windups.erase(id)
	if phase == "strike" and enemy.is_inside_tree():
		fire(MOMENTS[family]["release"], enemy.global_position + Vector3.UP * _lift(enemy))
		_note("release", family, enemy.global_position)


func _on_struck(enemy: Node3D, kind: String, force: float) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or kind == "synergy":
		return
	var id := enemy.get_instance_id()
	if _clock - float(_last_hit.get(id, -INF)) < HIT_GAP:
		return
	if _clock - _hits_clock >= 0.1:
		_hits_clock = _clock
		_hits_window = 0
	if _hits_window >= HITS_PER_TENTH:
		return
	_hits_window += 1
	_last_hit[id] = _clock
	var family := family_of(String(enemy.get("faction"))) if enemy.get("faction") != null else "fleet"
	var at := enemy.global_position + Vector3.UP * _lift(enemy)
	var heavy := force >= 30.0
	fire(MOMENTS[family]["heavy" if heavy else "hit"], at)
	if heavy:
		word(WORDS[family + "_heavy"], at + Vector3.UP * WORD_HEIGHT * 0.6, WORD_TINT[family])


func _on_died(at: Vector3, _scrap: int, enemy: Node3D, kind: String, family: String) -> void:
	var special := special_of(enemy)
	if special != "":
		special_moment(special, SpecialCues.break_moment(enemy), enemy, at)
		return
	var lifted := at + Vector3.UP * 0.8
	fire(MOMENTS[family]["death"], lifted)
	_note("death", family, at)
	var elite := kind == "miniboss" or String(enemy.get_meta("elite_affix", "")) != ""
	if elite:
		fire(MOMENTS[family]["chunk"], lifted, Color.TRANSPARENT, "P1")
		word(WORDS["elite"], at + Vector3.UP * WORD_HEIGHT, WORD_TINT[family], true)


# A posture body (a Warden or a boss's): the stagger vents for its whole window under a
# daze halo; each chunk it loses bursts off it; a boss's chunk is its phase change.
func _on_posture(enemy: Node3D, _posture: float, staggered: bool) -> void:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return
	var id := enemy.get_instance_id()
	var source = enemy.get("family") if enemy.get("family") != null else enemy.get("faction")
	var family := family_of(String(source)) if source != null else "ancient"
	var at := enemy.global_position + Vector3.UP * _lift(enemy)
	# Brindle's pieces change phase through boss_phase_changed; their chunks add nothing.
	var brindle := String(enemy.get("kind")).begins_with("brindle")
	if _boss_of(enemy) != "":
		_boss_at = enemy.global_position
	if enemy.has_method("chunks_left"):
		var left := int(enemy.chunks_left())
		var before := int(_chunks.get(id, BossPosture.CHUNKS))
		_chunks[id] = left
		if left < before and not brindle:
			var boss := _boss_of(enemy)
			if boss != "":
				boss_phase(boss, enemy.global_position)
			else:
				fire(MOMENTS[family]["chunk"], at)
				_note("chunk", family, at)
	if staggered and not _dazes.has(id):
		var spec: Dictionary = MOMENTS[family]["stagger"]
		var key: String = spec.keys()[0]
		var seconds := BossPosture.STAGGER_SECONDS
		var vent := follow(key, enemy, int(spec[key]), _lift(enemy), seconds)
		var halo := follow("daze_halo", enemy, 6, _lift(enemy) * 2.0 + 1.0, seconds, Color.TRANSPARENT, DAZE_SPIN)
		_dazes[id] = {"until": _clock + seconds, "emitters": [vent, halo]}
		word(WORDS["stagger"], at + Vector3.UP * WORD_HEIGHT, WORD_TINT[family], true)
		_note("stagger", family, at)
	elif not staggered and _dazes.has(id):
		for p in _dazes[id]["emitters"]:
			stop_follow(p)
		_dazes.erase(id)


# A pack unit's stagger (counter.gd stun_left): a daze halo while it lasts. Sampled at
# 10 Hz from the enemy group, since the counter publishes no fact for it.
func _sample_stuns() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var stun = enemy.get("stun_left")
		if stun == null or float(stun) <= 0.0:
			continue
		var id: int = enemy.get_instance_id()
		if _dazes.has(id):
			continue
		var halo := follow("daze_halo", enemy, 6, _lift(enemy) * 2.0 + 0.6, float(stun), Color.TRANSPARENT, DAZE_SPIN)
		if halo != null:
			_dazes[id] = {"until": _clock + float(stun), "emitters": [halo]}
			_note("daze", String(enemy.get("kind")), enemy.global_position)


# --- Pack arrivals ---------------------------------------------------------------------

# The director's arrival list (world.gd draws a ring for each): each new arrival vents
# from the ground (Fleet) or wells up in seam light (ancients) for its whole second, so a
# pack's arrivals all start together, on the frame their rings do.
func _sample_arrivals() -> void:
	var director = _director()
	if director == null or ctx.get("calm"):
		return
	var seen := {}
	for a in director.get("arrivals"):
		var at2: Vector2 = a["at"]
		var key := "%s:%.2f:%.2f" % [a["kind"], at2.x, at2.y]
		seen[key] = true
		if _arrivals.has(key):
			continue
		var kind: String = _kind_name(a["kind"])
		var family := family_of_kind(kind)
		var ground := Vector3(at2.x, 0.0, at2.y)
		if ctx.terrain != null and ctx.terrain.has_method("drop_point"):
			ground = ctx.terrain.drop_point(at2.x, at2.y, 0.0)
		var spec: Dictionary = MOMENTS[family]["arriving"]
		var id: String = spec.keys()[0]
		var anchor := Node3D.new()
		root.add_child(anchor)
		anchor.global_position = ground
		var p := follow(id, anchor, int(spec[id]), 0.2, float(a.get("left", 1.0)))
		_arrivals[key] = {"anchor": anchor, "emitter": p}
		_note("arriving", family, ground)
	for key in _arrivals.keys():
		if not seen.has(key):
			stop_follow(_arrivals[key]["emitter"])
			_arrivals[key]["anchor"].queue_free()
			_arrivals.erase(key)


func _director():
	if director_ref != null:
		return director_ref
	var presentation := get_parent()
	var game = presentation.get_parent() if presentation != null else null
	var world = game.get("world") if game != null else null
	return world.get("director") if world != null else null


static func _kind_name(kind) -> String:
	if kind is String:
		return kind
	var names = load("res://src/world/director.gd").KIND_NAMES
	return String(names[kind]) if int(kind) >= 0 and int(kind) < names.size() else "chaser"


# --- Specials --------------------------------------------------------------------------

func _on_special_tell(moment: String, enemy: Node3D) -> void:
	var special := special_of(enemy)
	if special != "":
		special_moment(special, moment, enemy)


# One special's moment: "spawn", "tell", "break", "break_split" or "break_clean". A tell
# is a read (P1): never thinned, always worded. Returns the sound id the moment plays.
func special_moment(special: String, moment: String, enemy: Node3D, at := Vector3.INF) -> String:
	var row: Dictionary = SPECIALS.get(special, {})
	if row.is_empty() or not row.has(moment):
		return ""
	if at == Vector3.INF:
		at = enemy.global_position if is_instance_valid(enemy) and enemy.is_inside_tree() else Vector3.ZERO
	var top := at + Vector3.UP * (_lift(enemy) if is_instance_valid(enemy) else 1.2)
	var tint: Color = row.get(moment + "_tint", WORD_TINT[row["family"]])
	var cls := "P1" if moment == "tell" or moment.begins_with("break") else "P5"
	fire(row[moment], top, tint, cls)
	if moment == "tell" and row.get("cable", false) and is_instance_valid(enemy) and enemy.has_method("cable_ends"):
		var ends: Array = enemy.cable_ends()
		if ends.size() == 2:
			_cables.append({"from": ends[0], "to": ends[1], "life": 0.5, "full": 0.5})
			fire({"brass_spark": 8}, ends[1], Color.TRANSPARENT, "P1")
	var text := String(row.get(moment + "_word", ""))
	if text != "":
		word(text, top + Vector3.UP * WORD_HEIGHT, tint if moment == "tell" else WORD_TINT[row["family"]], true)
	_note(special + "_" + moment, special, at)
	return special_sound(special, moment)


func _draw_cables(delta: float) -> void:
	_cable_mesh.clear_surfaces()
	var kept: Array = []
	for c in _cables:
		c["life"] -= delta
		if c["life"] > 0.0:
			kept.append(c)
	_cables = kept
	if _cables.is_empty():
		return
	_cable_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for c in _cables:
		var from: Vector3 = c["from"]
		var to: Vector3 = c["to"]
		var color := Color(Palette.SAND, clampf(c["life"] / c["full"], 0.0, 1.0))
		var span := to - from
		var jitter := minf(0.6, span.length() * 0.06)
		var previous := from
		for i in range(1, 9):
			var point := from + span * (i / 8.0)
			if i < 8:
				point += Vector3(_cable_rng.randf_range(-1, 1), _cable_rng.randf_range(-1, 1), _cable_rng.randf_range(-1, 1)) * jitter
			_cable_mesh.surface_set_color(color)
			_cable_mesh.surface_add_vertex(previous)
			_cable_mesh.surface_set_color(color)
			_cable_mesh.surface_add_vertex(point)
			previous = point
	_cable_mesh.surface_end()


# --- Bosses ----------------------------------------------------------------------------

# Which boss owns a posture body: its fleet is a boss script ("" for a park Warden).
static func _boss_of(enemy: Node) -> String:
	var holder = enemy.get("fleet")
	if holder == null or not holder is Object or holder.get_script() == null:
		return ""
	return _boss_from_script(holder.get_script())


static func _boss_from_script(script: Script) -> String:
	var path := script.resource_path.get_file() if script != null else ""
	while path == "" and script != null and script.get_base_script() != null:
		script = script.get_base_script()
		path = script.resource_path.get_file()
	match path:
		"boss.gd":
			return "brindle"
		"waking.gd":
			return "waking"
		"mind.gd":
			return "mind"
	return ""


func _active_boss() -> String:
	var boss = ctx.get("boss")
	if boss == null or not is_instance_valid(boss) or boss.get_script() == null:
		return ""
	return _boss_from_script(boss.get_script())


func _brindle_at() -> Vector3:
	var boss = ctx.get("boss")
	for piece in ["scooter", "ship"]:
		var node = boss.get(piece) if boss != null else null
		if node is Node3D and is_instance_valid(node) and node.is_inside_tree() and (piece == "ship" or node.visible):
			return node.global_position
	return _boss_at


func _on_boss_phase(phase: int, phase_name := "") -> void:
	if _active_boss() != "brindle" or phase <= 1:
		return
	var at := _brindle_at()
	if phase_name == "chase":
		fire(MOMENTS["fleet"]["chunk"], at + Vector3.UP * 2.0, Color.TRANSPARENT, "P1")
		word(BOSSES["brindle"]["eject_word"], at + Vector3.UP * (WORD_HEIGHT + 3.0), Palette.BRASS, true, 1.1, 1.4)
		_note("boss_eject", "brindle", at)
		return
	boss_phase("brindle", at)


# A boss changes phase: a ring out to its reach, its family's chunk of armour or shell,
# and the phase word, big, for a boss that has one.
func boss_phase(boss: String, at: Vector3) -> void:
	var row: Dictionary = BOSSES.get(boss, {})
	if row.is_empty():
		return
	_boss_at = at
	var lift: Vector3 = Vector3.UP * (float(row["reach"]) * 0.4)
	fire(row["phase"], at + lift, row["tint"], "P1")
	# Brindle's turn is read from his plates and the glance, not a word over him (flourish_rows.gd brindle_phase_2).
	if String(row["phase_word"]) != "":
		word(String(row["phase_word"]), at + lift + Vector3.UP * (WORD_HEIGHT + 2.0), row["tint"], true, 1.1, 1.6)
	_note("boss_phase", boss, at)


func _on_boss_defeated() -> void:
	var boss := _active_boss()
	if boss == "":
		return
	var at := _brindle_at() if boss == "brindle" else _boss_at
	var stub = ctx.get("boss")
	var warden = stub.get("warden") if stub != null and boss != "brindle" else null
	if warden is Node3D and is_instance_valid(warden) and warden.is_inside_tree():
		at = warden.global_position
	boss_fall(boss, at)


# The fall, played straight then winked: FALL_BLASTS blasts walk across the body
# FALL_GAP apart, a last ring goes out, and one beat later the fall word stamps.
func boss_fall(boss: String, at: Vector3) -> void:
	var row: Dictionary = BOSSES.get(boss, {})
	if row.is_empty():
		return
	var family: String = row["family"]
	var reach: float = row["reach"]
	for i in FALL_BLASTS:
		var angle := TAU * float(i) / FALL_BLASTS + 0.7
		var spot := at + Vector3(cos(angle) * reach * 0.5, reach * (0.3 + 0.1 * i), sin(angle) * reach * 0.5)
		_queue.append({"at": _clock + FALL_GAP * i, "effects": MOMENTS[family]["chunk"], "where": spot, "tint": row["tint"]})
	var finale := FALL_GAP * FALL_BLASTS
	_queue.append({"at": _clock + finale, "effects": row["phase"], "where": at + Vector3.UP * reach * 0.4, "tint": row["tint"]})
	# Brindle's rout says its one word through flourish_rows.gd; his fall stays a sight and a sound.
	if row.has("fall_word"):
		_queue.append({"at": _clock + finale + WINK_DELAY, "word": String(row["fall_word"]), "where": at + Vector3.UP * (reach + WORD_HEIGHT), "tint": row["tint"]})
	_note("boss_fall", boss, at)


func _run_queue() -> void:
	if _queue.is_empty():
		return
	var later: Array = []
	for item in _queue:
		if _clock < float(item["at"]):
			later.append(item)
			continue
		if item.has("effects"):
			fire(item["effects"], item["where"], item["tint"], "P1")
		if item.has("word"):
			word(item["word"], item["where"], item["tint"], true, 1.6, 1.8)
	_queue = later


# --- Frame -----------------------------------------------------------------------------

func _process(delta: float) -> void:
	if root == null:
		return
	_clock += delta
	reduced_motion = EnemyMotion.motion_scale <= 0.0
	_sample -= delta
	if _sample <= 0.0:
		_sample = SAMPLE_SECONDS
		_sample_stuns()
		_sample_arrivals()
	var kept: Array = []
	for f in _follows:
		var node = f["node"]
		var p: GPUParticles3D = f["emitter"]
		if not is_instance_valid(node) or not node.is_inside_tree() or _clock >= float(f["until"]):
			p.emitting = false
			_busy.erase(p)
			continue
		var spin := 0.0 if reduced_motion else float(f["spin"]) * _clock
		p.global_transform = Transform3D(Basis(Vector3.UP, spin), node.global_position + Vector3.UP * float(f["lift"]))
		kept.append(f)
	_follows = kept
	for id in _windups.keys():
		var w: Dictionary = _windups[id]
		if not is_instance_valid(w["enemy"]):
			_windups.erase(id)
			continue
		var facts: Dictionary = w["enemy"].attack_facts() if w["enemy"].has_method("attack_facts") else {}
		var progress := clampf(float(facts.get("progress", 0.0)), 0.0, 1.0)
		var p: GPUParticles3D = w["emitter"]
		p.amount_ratio = clampf(float(w["full"]) * lerpf(0.3, 1.0, progress) / float(p.amount), 0.0, 1.0)
	for id in _dazes.keys():
		if _clock >= float(_dazes[id]["until"]):
			_dazes.erase(id)
	_run_queue()
	for slot in _words:
		if slot["t"] >= slot["life"]:
			if slot["node"].visible:
				slot["node"].visible = false
			continue
		slot["t"] += delta
		_draw_word(slot)
	_draw_cables(delta)


# Live emitters, for the bench and the notes: [one-shot pools restarted, follows alive].
func alive_follows() -> int:
	return _follows.size()
