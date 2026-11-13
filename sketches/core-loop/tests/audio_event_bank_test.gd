extends SceneTree

const Harmony := preload("res://src/presentation/harmony.gd")
const SfxBank := preload("res://src/presentation/sfx_bank.gd")
const T := preload("res://tests/support/t.gd")

# INTEGRATION section 7, item 2: the 51 event-set WAVs (49, and feedback_set.py's shot and deflect) are registered under their cue
# keys. Every registered key resolves to a file that exists and decodes, the tiered cues
# map to the tier and rarity arguments the callers already send, and a registered file
# is what the bank bakes.

var t := T.new("audio_event_bank_test")


func _initialize() -> void:
	var cues: Array = SfxBank.EVENT_CUES
	t.eq("51 event cues are registered", cues.size(), 51)
	var dir := DirAccess.get_files_at(SfxBank.EVENT_DIR)
	var on_disk: Array = Array(dir).filter(func(name: String): return name.ends_with(".wav")).map(func(name: String): return name.get_basename())
	on_disk.sort()
	var registered := cues.duplicate()
	registered.sort()
	t.eq("the registered keys are exactly the files in the event folder", registered, on_disk)
	var empty := 0
	for id in cues:
		var path := SfxBank.event_path(id)
		if not (FileAccess.file_exists(path) or ResourceLoader.exists(path)):
			t.check("%s resolves to a file" % id, false, path)
			continue
		var raw := SfxBank.file_samples(id)
		if raw.is_empty():
			empty += 1
			t.check("%s decodes as 16-bit mono PCM" % id, false, path)
			continue
		var peak := 0.0
		for v in raw:
			peak = maxf(peak, absf(v))
		# The linear resample from 48 kHz shaves a little off bright peaks; the bank re-normalizes.
		t.check("%s decodes near its -1 dBFS peak" % id, peak > 0.7 and peak < 0.95, "peak %.3f, %d samples" % [peak, raw.size()])
		t.check("%s is a bank cue" % id, SfxBank.has_recipe(id))
		var baked := SfxBank.samples(id)
		var baked_peak := 0.0
		for v in baked:
			baked_peak = maxf(baked_peak, absf(v))
		t.check("%s bakes to the file, not a recipe" % id, baked.size() == raw.size() and absf(baked_peak - 0.9) < 0.01, "%d samples, peak %.3f" % [baked.size(), baked_peak])
	t.eq("no registered file fails to decode", empty, 0)
	t.check("the 48 kHz files land at the bank rate", absf(float(SfxBank.file_samples("land_thud").size()) - 13440.0 * Harmony.RATE / 48000.0) <= 1.0)
	_tiers()
	quit(t.verdict())


func _tiers() -> void:
	for base in SfxBank.TIER_CUES:
		for file in SfxBank.TIER_CUES[base]:
			t.check("%s is a registered tier of %s" % [file, base], file in SfxBank.EVENT_CUES and SfxBank.base_key(file) == base)
			t.eq("%s keeps the trim of %s" % [file, base], SfxBank.trim_db(file), SfxBank.trim_db(base))
	# Scrap pickups and kill chains: the rung in the pitch picks the tier, five of them.
	for base in ["scrap_tick", "kill_chain_tier"]:
		for rung in 5:
			var got := SfxBank.resolve(base, Harmony.ratio(Harmony.pentatonic_step(rung)))
			t.eq("%s rung %d plays tier %d" % [base, rung, rung + 1], got["id"], "%s_%d" % [base, rung + 1])
			t.eq("%s rung %d plays the stepped file as it is" % [base, rung], got["pitch"], 1.0)
		var beyond := SfxBank.resolve(base, Harmony.ratio(Harmony.pentatonic_step(9)))
		t.eq("%s past the ladder holds at tier 5" % base, beyond["id"], "%s_5" % base)
	# Rarity: the rung each rarity rings (common 0, rare 4, relic 5, evolved 7).
	var rarity := {0: "rarity_bell_common", 4: "rarity_bell_rare", 5: "rarity_bell_epic", 7: "rarity_bell_epic"}
	for rung in rarity:
		t.eq("rarity rung %d rings %s" % [rung, rarity[rung]], SfxBank.resolve("rarity_bell", Harmony.ratio(Harmony.pentatonic_step(rung)))["id"], rarity[rung])
	# A missing tier file plays the base recipe on the caller's rung, pitch kept.
	var rung3 := Harmony.ratio(Harmony.pentatonic_step(2))
	SfxBank._file_present["scrap_tick_3"] = false
	var fallback := SfxBank.resolve("scrap_tick", rung3)
	SfxBank._file_present.erase("scrap_tick_3")
	t.check("a missing tier file keeps the rung's pitch on the base recipe", fallback["id"] == "scrap_tick" and fallback["pitch"] == rung3)
	var plain := SfxBank.resolve("hurt", 1.25)
	t.check("an untiered key passes through", plain["id"] == "hurt" and plain["pitch"] == 1.25)
