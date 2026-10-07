extends SceneTree

const Game := preload("res://src/game.gd")
const Harness := preload("res://tests/doubles/module_harness.gd")
const BossModel := preload("res://src/boss/boss_model.gd")
const Requisition := preload("res://src/boss/requisition.gd")
const WakingDress := preload("res://src/boss/waking_dress.gd")
const MindDress := preload("res://src/boss/mind_dress.gd")
const MindHand := preload("res://src/combat/mind_hand.gd")
const T := preload("res://tests/support/t.gd")

# Keep the imported scenes cached through real arena retries and repeated hand spawns.
# Compare both the split cue tracks and the original libraries, including loop flags.
# Headless evidence only: this checks resource ownership, not rendered animation quality.
const MODELS := [Requisition.MODEL, Requisition.SCOOTER_MODEL,
	WakingDress.BASE, WakingDress.KIT, MindDress.BASE, MindDress.KIT, MindHand.MODEL]

var _t := T.new("boss_clip_isolation_test")
var _game
var _packed: Array[PackedScene] = []
var _sources := {}
var _originals := {}


func _initialize() -> void:
	for path in MODELS:
		var packed := load(path) as PackedScene
		if not _t.check("imported boss model exists", packed != null, path):
			quit(_t.verdict())
			return
		_packed.append(packed)
		var probe := packed.instantiate()
		var player := BossModel.player_of(probe)
		_sources[path] = player.get_animation_library("")
		_originals[path] = _signature(player)
		probe.free()
	_game = Game.new()
	_game.test_mode = true
	root.add_child(_game)
	_run()


func _run() -> void:
	while _game.flow == null:
		await physics_frame
	await physics_frame
	_game.ctx.calm = true
	Harness.boot(_game)
	_brindle()
	_waking()
	_mind()
	_hand()
	for path in MODELS:
		var library: AnimationLibrary = _sources[path]
		_same("imported %s stays unchanged" % path.get_file(), _library_signature(library), _originals[path])
	_game.free()
	quit(_t.verdict())


func _brindle() -> void:
	Harness.enter_world(_game, 1)
	var boss = _game.boss
	_owned("Brindle fortress", boss.ship._anim, Requisition.MODEL)
	var hull := _signature(boss.ship._anim)
	boss.jump_to_phase(4)
	_owned("Brindle scooter", boss._scooter_anim, Requisition.SCOOTER_MODEL)
	var scooter := _signature(boss._scooter_anim)
	_game.flow._retry_arena()
	_same("Brindle retry keeps fortress tracks", _signature(boss.ship._anim), hull)
	boss.jump_to_phase(4)
	_same("Brindle retry keeps scooter tracks", _signature(boss._scooter_anim), scooter)
	boss.exit_arena()


func _waking() -> void:
	Harness.enter_world(_game, 2)
	var mod = Harness.module(_game, 2)
	var dress = mod._dress
	_owned("Waking base", dress._base_anim, WakingDress.BASE)
	_owned("Waking kit", dress._kit_anim, WakingDress.KIT)
	var base := _signature(dress._base_anim)
	var kit := _signature(dress._kit_anim)
	var core := _signature(dress._core_anim)
	var core_tracks: int = dress._core_anim.get_animation("core_open").get_track_count()
	_t.check("first Waking core has tracks", core_tracks > 0, "tracks %d" % core_tracks)
	_game.flow._retry_arena()
	dress = mod._dress
	_t.eq("Waking retry keeps core_open tracks", dress._core_anim.get_animation("core_open").get_track_count(), core_tracks)
	_same("Waking retry keeps all base, kit and core tracks",
		[_signature(dress._base_anim), _signature(dress._kit_anim), _signature(dress._core_anim)], [base, kit, core])
	mod.exit_arena()


func _mind() -> void:
	Harness.enter_world(_game, 3)
	var mod = Harness.module(_game, 3)
	var dress = mod._dress
	_owned("Mind base", dress._base_anim, MindDress.BASE)
	_owned("Mind kit", dress._kit_anim, MindDress.KIT)
	var first := [_signature(dress._base_anim), _signature(dress._kit_anim),
		_signature(dress._lens_anim), _signature(dress._pulse_anim)]
	var lens_tracks: int = dress._lens_anim.get_animation("stagger_open").get_track_count()
	var warn_tracks: int = dress._pulse_anim.get_animation("pulse_warn").get_track_count()
	var pulse_tracks: int = dress._pulse_anim.get_animation("pulse").get_track_count()
	_t.check("first Mind lens and pulse cues have tracks", lens_tracks > 0 and warn_tracks > 0 and pulse_tracks > 0,
		"tracks %s" % [[lens_tracks, warn_tracks, pulse_tracks]])
	_game.flow._retry_arena()
	dress = mod._dress
	_t.eq("Mind retry keeps stagger_open tracks", dress._lens_anim.get_animation("stagger_open").get_track_count(), lens_tracks)
	_t.eq("Mind retry keeps pulse_warn tracks", dress._pulse_anim.get_animation("pulse_warn").get_track_count(), warn_tracks)
	_t.eq("Mind retry keeps pulse tracks", dress._pulse_anim.get_animation("pulse").get_track_count(), pulse_tracks)
	_same("Mind retry keeps all base, kit, lens and pulse tracks",
		[_signature(dress._base_anim), _signature(dress._kit_anim),
		_signature(dress._lens_anim), _signature(dress._pulse_anim)], first)
	mod.exit_arena()


func _hand() -> void:
	_game.ctx.spawner = _game.combat
	var first = _game.combat.spawn_enemy("mind_hand", Vector3(100, 20, 100))
	first.set_physics_process(false)
	_owned("Mind hand", first._anim, MindHand.MODEL)
	var clips := _signature(first._anim)
	var second = _game.combat.spawn_enemy("mind_hand", Vector3(110, 20, 100))
	second.set_physics_process(false)
	_same("second Mind hand keeps all tracks", _signature(second._anim), clips)
	_t.check("Mind hands own distinct libraries and clips",
		first._anim.get_animation_library("") != second._anim.get_animation_library("")
		and first._anim.get_animation("still_track") != second._anim.get_animation("still_track"))
	first.free()
	second.free()


func _owned(label: String, player: AnimationPlayer, path: String) -> void:
	var library := player.get_animation_library("")
	var source: AnimationLibrary = _sources[path]
	var private_clips := true
	for clip in library.get_animation_list():
		private_clips = private_clips and library.get_animation(clip) != source.get_animation(clip)
	_t.check("%s owns its library and clips" % label, library != source and private_clips)


func _signature(player: AnimationPlayer) -> Dictionary:
	return _library_signature(player.get_animation_library(""))


func _same(label: String, got, want) -> void:
	_t.check(label, got == want, "clip signatures %s" % ("match" if got == want else "differ"))


func _library_signature(library: AnimationLibrary) -> Dictionary:
	var signature := {}
	for clip in library.get_animation_list():
		var animation := library.get_animation(clip)
		var tracks: Array = []
		for track in animation.get_track_count():
			tracks.append([animation.track_get_path(track), animation.track_get_type(track)])
		signature[clip] = [animation.length, animation.loop_mode, tracks]
	return signature
