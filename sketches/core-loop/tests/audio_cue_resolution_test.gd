extends SceneTree

const GameEvents := preload("res://src/core/game_events.gd")
const ClassDef := preload("res://src/core/class_def.gd")
const Roster := preload("res://src/combat/roster.gd")
const Audio := preload("res://src/presentation/audio.gd")
const Rows := preload("res://src/presentation/rows.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const VoiceSynth := preload("res://src/presentation/voice_synth.gd")
const Shop := preload("res://src/build/shop.gd")
const Workshop := preload("res://src/ui/workshop.gd")
const AbilityBar := preload("res://src/ui/ability_bar.gd")
const AbilitySlots := preload("res://src/ui/ability_slots.gd")

# v2 W9, the ear: the running game plays W5's baked cues, resolved from the event, class
# and roster rows (SOUND-STORY sections 2, 3, 7 and 8; DESIGN-V2 section 11 ruling 3).
#   - Each class hears its own motif on the gauge release, the HUD's ready swell and a
#     break-free, from the class row's motif; the band takes the motif, not the class id.
#   - The Mind quotes the player's own class, once per adaptation.
#   - Each hold kind sounds its own loop.
#   - The shop bell rings on a purchase; the reroll is the bench clank.
#   - Ancients never growl like the Fleet; each faction's pack arrives on its own cue.
#   - Moss's lines babble, non-silent, cached per line and key.
# The cue log, not speakers.

const RELEASE := {"sable": "sable_arpeggio", "rivet": "rivet_hihat_roll", "kest": "kest_low_thump",
	"tarn": "tarn_latch_tear", "tally": "tally_balance_due", "cannon": "cannon_recall"}
const HOLDS := {"mag_pit": "hold_pit", "anchor_tether": "hold_tether", "air_net": "hold_net", "bola_wrap": "hold_bola",
	"gyro_drift": "hold_riser"}
const ARRIVALS := {"fleet": "fleet_motif", "reactor": "reactor_tick", "swarm": "swarm_lock", "mind": "mind_kest"}

class FakeCtx:
	extends RefCounted
	var events: Node
	var player = null
	var run = null
	var flow = null
	var spawner = null
	var calm = false

class FakeFlow:
	extends RefCounted
	func in_play() -> bool:
		return true

class FakeRun:
	extends RefCounted
	var run_time := 0.0

class FakePresentation:
	extends RefCounted
	var audio

class FakeGame:
	extends Node
	var events
	var flow
	var run
	var presentation

class FakeHud:
	extends Control
	var game

var _failures := 0
var _events
var _audio
var _game: FakeGame


func _initialize() -> void:
	_events = GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = _events
	_audio = Audio.new()
	_audio.setup(ctx)
	_audio.bake_now()
	_game = FakeGame.new()
	_game.events = _events
	_game.flow = FakeFlow.new()
	_game.run = FakeRun.new()
	_game.presentation = FakePresentation.new()
	_game.presentation.audio = _audio
	root.add_child(_game)

	_class_cues()
	_holds()
	_shop()
	_arrivals()
	_babble()

	print("audio_cue_resolution_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	_game.free()
	_audio.free()
	_events.free()
	quit(0 if _failures == 0 else 1)


func _class_cues() -> void:
	var heard: Array = []
	var ok := true
	for def in ClassDef.all():
		var motif: String = def.motif
		# 2026-10-05 (alpha wave 16 cannon-look): every pilot has its own motif; no stand-in skip
		_events.run_started.emit(def.id)
		var band: String = _audio.engine.class_motif
		_events.gauge_released.emit(def.special_id, 1.0)
		var release := _last("gauge_released")
		var ready := _ready_swell()
		_events.hold_broken.emit("mag_pit", "jump")
		var broke := _last("hold_broken")
		_events.mind_adapted.emit("boost", "ab_boost")
		var quote := _last("mind_adapted")
		var telegraph: bool = _audio.play("threat", 0.0, 1.0, "SFX", "mind_" + motif)
		var candidates: Array = Rows.releases(motif)
		var mine: bool = band == motif and release == [RELEASE[motif], "now"] and ready == [motif + "_ready", "now"] \
			and broke == [motif + "_break", "now"] and quote == ["mind_" + motif, "now"] and not telegraph \
			and candidates == [RELEASE[motif]]
		ok = ok and mine
		heard.append("%s: band %s, release %s, ready %s, break %s, mind %s, telegraph quote again %s, release candidates %s"
			% [def.display_name, band, release, ready, broke, quote, telegraph, candidates])
	_check("each class hears its own motif", ok, "; ".join(heard))


# The HUD's ready swell, from the ability bar's own call site: a slot's cooldown ends.
func _ready_swell() -> Array:
	var hud := FakeHud.new()
	hud.game = _game
	var bar := AbilityBar.new()
	hud.add_child(bar)
	bar.update_slots([AbilitySlots.slot("overdrive_blast", "ab_rivet_special", "key_f", 0.4, 0, 1, "cooling")], Color.WHITE, "ring")
	bar.update_slots([AbilitySlots.slot("overdrive_blast", "ab_rivet_special", "key_f", 0.0, 1, 1, "ready")], Color.WHITE, "ring")
	hud.free()
	return _last("ability_ready")


func _holds() -> void:
	var ok := true
	var heard: Array = []
	for kind in HOLDS:
		_events.hold_started.emit(kind, Vector3.ZERO)
		var cue := _last("hold_started")
		ok = ok and cue == [HOLDS[kind], "now"]
		heard.append("%s -> %s" % [kind, cue])
	_check("each hold kind hears its own hold", ok, ", ".join(heard))


func _shop() -> void:
	var ws := Workshop.new()
	ws.game = _game
	ws._cue("shop_bought")
	var bought := _last("shop_bought")
	ws._cue("shop_rerolled")
	var rerolled := _last("shop_rerolled")
	ws.free()
	_check("the shop bell plays", bought == ["shop_bell", "now"] and rerolled == ["bench_clank", "now"],
		"a purchase rings %s; a reroll is %s" % [bought, rerolled])


func _arrivals() -> void:
	_events.run_started.emit("demolitions_caster")
	var growls: Array = []
	for kind in Roster.ANCIENTS + ["warden"]:
		var before: int = _audio.cue_log_total
		_events.enemy_spawned.emit(null, kind)
		for cue in _audio.cues_since(before):
			growls.append("%s: %s" % [kind, cue[1]])
	_events.enemy_spawned.emit(null, "chaser")
	var fleet := _last("enemy_spawned")
	var ok := growls.is_empty() and fleet == ["enemy_arrive", "now"]
	var heard: Array = []
	for faction in ARRIVALS:
		_events.pack_arrived.emit(faction, Vector3.ZERO, [])
		var cue := _last("pack_arrived")
		ok = ok and cue[0] == ARRIVALS[faction]
		heard.append("%s -> %s" % [faction, cue[0]])
	_check("ancients arrive in their own voice", ok,
		"ancient spawns made %s; a Fleet chaser growls %s; packs: %s" % [growls, fleet, ", ".join(heard)])


func _babble() -> void:
	var line: String = Shop.LINES["moss.ask.1"]
	var samples := VoiceSynth.babble(line, 1)
	var peak := 0.0
	for s in samples:
		peak = maxf(peak, absf(s))
	var seconds := samples.size() / float(SfxBank.RATE)
	var ws := Workshop.new()
	ws.game = _game
	ws._babble("moss_beat", line, Workshop.babble_beat({"beat": 0, "text": line}))
	var spoken := _last("moss_beat")
	var cached: int = _audio._babble.size()
	ws._babble("moss_beat", line, 1)
	var again: int = _audio._babble.size()
	_audio.engine.key = 1
	ws._babble("moss_beat", line, 1)
	var keyed: int = _audio._babble.size()
	_audio.engine.key = 0
	ws.free()
	var beats := [Workshop.babble_beat({"beat": 0}), Workshop.babble_beat({"beat": 5}), Workshop.babble_beat({"beat": 6, "restart": true}),
		Workshop.babble_beat({"beat": -1, "relent": true})]
	_check("Moss babbles", peak > 0.1 and seconds > 1.0 and spoken == ["babble", "now"] and again == cached and keyed == cached + 1
		and beats == [1, 6, VoiceSynth.BABBLE_LEVEL, VoiceSynth.BABBLE_RELENT],
		"'%s' babbles %.2f s at peak %.2f; the workshop speaks it as %s; baked lines %d, %d on a repeat, %d in Eb; beats ask, send-off, restart, relent -> %s"
			% [line, seconds, peak, spoken, cached, again, keyed, beats])


# The last cue logged for a kind, as [sound, decision].
func _last(kind: String) -> Array:
	for i in range(_audio.cue_log.size() - 1, -1, -1):
		var cue: Array = _audio.cue_log[i]
		if cue[0] == kind:
			return [cue[1], cue[2]]
	return ["", "none"]


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
