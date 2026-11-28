extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const Synth := preload("res://src/presentation/synth.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const Audio := preload("res://src/presentation/audio.gd")
const GameEvents := preload("res://src/core/game_events.gd")

class FakeCtx:
	extends RefCounted
	var events: Node

# The AU2 bank (design-v3/AUDIO-V3.md section 8's AU2 row): every new recipe bakes
# non-silent, stays under the soft-clip ceiling and holds its role's length. crater_hold
# loops seamlessly (both ends fade to near-silence, so back-to-back holds tile with no
# click), and every pitched cue is in audio.gd's KEYED_SOUNDS and actually moves with a
# Warden key lift when played. Buffers, not ears.

# Every new AU2 id, with the longest length its role should hold to. Stingers and juice
# cues are capped at 1.2 s (AUDIO-V3.md section 5 rule 5's chain-tier bound); the bell
# and the hiss carry the tails their own recipes name (2 s, 1.2 s).
const STINGER_CAP := 1.2
# The ally hum rings on the Mind's own chime voice (2.6 s natural decay, _mind_quote's
# own instrument), so it is a background hum's length, not a stinger's.
const HUM_CAP := 2.5
const CUES := {
	# 2026-10-12 WEIGHT-1: core_slam preserves the shared slam body without a pilot voice.
	"core_slam": 1.2,
	# 2026-10-11 WEIGHT-1: authored impact cues replace three borrowed voices.
	"ultimate_land": 1.6, "kest_demo_knock": 0.6, "rivet_skid_plate": 0.5,
	"bet_roll": STINGER_CAP, "bet_clunk": STINGER_CAP, "bet_crack": STINGER_CAP, "bet_refusal": STINGER_CAP,
	"sunken_bell": 2.5, "ally_hum_sable": HUM_CAP, "ally_hum_rivet": HUM_CAP, "ally_hum_kest": HUM_CAP,
	"ally_wake": STINGER_CAP, "fight_arm_stamp": STINGER_CAP,
	"near_miss_whip_sable": STINGER_CAP, "near_miss_whip_rivet": STINGER_CAP, "near_miss_whip_kest": STINGER_CAP,
	"kill_chain_tier": STINGER_CAP, "drop_landing": STINGER_CAP, "door_tick": STINGER_CAP,
	"return_launch_arpeggio": STINGER_CAP, "lift_hiss": 1.5, "crater_hold": 1.5,
}
# Every pitched AU2 id: it must carry KEYED_SOUNDS, so a Warden lift transposes it.
const KEYED := ["core_slam", "ultimate_land", "kest_demo_knock", "rivet_skid_plate", "bet_clunk", "bet_crack", "bet_refusal", "sunken_bell", "ally_hum_sable", "ally_hum_rivet",
	"ally_hum_kest", "ally_wake", "fight_arm_stamp", "near_miss_whip_sable", "near_miss_whip_rivet",
	"near_miss_whip_kest", "drop_landing", "return_launch_arpeggio", "crater_hold"]
# The one AU2 id known to be engine-managed (music_engine.gd calls samples_at with an
# explicit shift), so it never needs KEYED_SOUNDS: door_tick, bet_roll (percussion) and
# lift_hiss (noise only) are the deliberate exceptions, and so is kill_chain_tier since its tiers
# became percussion (SOUND-BIBLE rule 7).
const UNKEYED := ["bet_roll", "door_tick", "lift_hiss", "kill_chain_tier"]

var _failures := 0


func _initialize() -> void:
	_baked()
	_keyed_list()
	_keyed_playback()
	_crater_loop()
	print("audio_v3_bank_test: %s" % ("PASS" if _failures == 0 else "FAIL (%d)" % _failures))
	quit(0 if _failures == 0 else 1)


func _baked() -> void:
	var bad: Array = []
	var no_recipe: Array = []
	for id in CUES:
		var buf := SfxBank.samples(id)
		var peak := 0.0
		for s in buf:
			peak = maxf(peak, absf(s))
		var seconds := buf.size() / float(SfxBank.RATE)
		var cap: float = CUES[id]
		if peak <= 0.1 or peak >= 0.95 or seconds < 0.02 or seconds > cap:
			bad.append("%s (peak %.2f, %.2fs, cap %.2fs)" % [id, peak, seconds, cap])
		if not SfxBank.has_recipe(id):
			no_recipe.append(id)
	_check("baked", bad.is_empty(), "%d AU2 ids baked, non-silent, under 0.95 peak, within role length; failing %s" % [CUES.size(), bad])
	_check("recipes", no_recipe.is_empty(), "every AU2 id has its own recipe, not the fallback blip; missing %s" % [no_recipe])
	_check("scope", CUES.size() == KEYED.size() + UNKEYED.size(),
		"every AU2 id is accounted for as keyed or a named exception (%d keyed, %d exceptions, %d total)"
			% [KEYED.size(), UNKEYED.size(), CUES.size()])


func _keyed_list() -> void:
	var missing: Array = []
	for id in KEYED:
		if not id in Audio.KEYED_SOUNDS:
			missing.append(id)
	_check("keyed list", missing.is_empty(), "every pitched AU2 cue is in audio.gd KEYED_SOUNDS; missing %s" % [missing])


# A pitched AU2 cue actually moves with the key: audio.gd's play() multiplies playback
# pitch by Harmony.ratio(engine.key) whenever the sound is in KEYED_SOUNDS.
func _keyed_playback() -> void:
	var events := GameEvents.new()
	var ctx := FakeCtx.new()
	ctx.events = events
	var audio := Audio.new()
	audio.setup(ctx)
	audio.bake_now()
	audio.engine.key = 1
	audio.play("threat", 0.0, 1.0, "SFX", "bet_clunk")
	var cue: Array = audio.cue_log[audio.cue_log.size() - 1]
	var expect := Harmony.ratio(1)
	_check("lift moves a keyed AU2 cue", cue[1] == "bet_clunk" and cue[2] == "now" and absf(float(cue[4]) - expect) < 0.0001,
		"bet_clunk at key +1 plays at pitch %.4f (expected %.4f); logged %s" % [cue[4], expect, cue])
	audio.free()
	events.free()


func _crater_loop() -> void:
	var n := int(Harmony.RATE * 2.0)
	var buf := SfxBank.new().hold("crater", n)
	var head := 0.0
	var tail := 0.0
	for i in 32:
		head = maxf(head, absf(buf[i]))
		tail = maxf(tail, absf(buf[n - 1 - i]))
	_check("crater_hold loops seamlessly", head < 0.05 and tail < 0.05,
		"both ends fade to near-silence, over 25 dB under the 0.9 peak (head %.4f, tail %.4f), so consecutive holds tile with no click" % [head, tail])
	var peak := 0.0
	for s in buf:
		peak = maxf(peak, absf(s))
	_check("crater_hold non-silent", peak > 0.3 and peak < 0.95, "peak %.2f" % peak)


func _check(label: String, ok: bool, detail: String) -> void:
	if not ok:
		_failures += 1
	print("[%s] %s -> %s" % [label, detail, "PASS" if ok else "FAIL"])
