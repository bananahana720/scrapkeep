extends SceneTree

const Ace := preload("res://src/presentation/ace_sequencer.gd")
const T := preload("res://tests/support/t.gd")

# The momentum smoothing (a beat up, two bars down) belongs to voices already sounding. A
# join's new voices keep the 10 ms join, so a parameter-driven section change never dips the
# drums or the lead, in level mode or boss mode, and the armour strip and the Warden release
# keep their STOP_RAMP. Runs on a real picked take, so it needs the local Oggs; without them
# it says so on a SKIP control line and the receipt counts it.

const MANIFEST := "res://assets/music_ace/roam_spillway/manifest.json"
const TOLERANCE := 0.02

var t := T.new("audio_momentum_join_test")


func _initialize() -> void:
	if not _stems_present():
		print("SKIP control momentum join: the roam_spillway Oggs are not in this checkout (gitignored), so the join and release ramps were not rendered")
		quit(t.verdict())
		return
	_level_join()
	_boss_join()
	_release("armour", {"threat": 0.0, "speed": 1.0, "chain": 1.0, "armour": 0.1}, false)
	_release("warden break", {"threat": 0.0, "speed": 1.0, "chain": 1.0, "armour": 1.0}, true)
	quit(t.verdict())


func _stems_present() -> bool:
	if not FileAccess.file_exists(MANIFEST):
		return false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for cid in manifest["clips"]:
		for file in manifest["clips"][cid]["files"].values():
			if not FileAccess.file_exists("res://assets/music_ace/roam_spillway/%s" % file):
				return false
	return true


func _to(seq: Ace, until: int) -> void:
	while seq.clock < until:
		seq.render(mini(256, until - seq.clock))


func _target(seq: Ace, stem: String) -> float:
	for v in seq.voices:
		if v.stem == stem:
			return v.target
	return -1.0


func _level(feed: Dictionary) -> Ace:
	var seq := Ace.new(MANIFEST)
	seq.parameter_enabled = true
	seq.parameters = feed.duplicate()
	seq.start_level(0)
	_to(seq, seq.grid_bar * 3)
	return seq


# Level mode: threat rises, calm gives way to travel. At the edge the new drums and lead
# are at their join gain, not partway up a beat ramp.
func _level_join() -> void:
	var seq := _level({"threat": 0.0, "speed": 1.0, "chain": 0.0, "armour": 1.0})
	t.eq("level starts in calm", seq.section, "calm")
	seq.commit_parameters(seq.clock, {"threat": 0.9, "speed": 1.0, "chain": 1.0, "armour": 1.0}, false, false, "")
	var limit: int = seq.clock + seq.grid_bar * 4
	while seq.section != "travel" and seq.clock < limit:
		seq.render(64)
	t.eq("level threat changes the section", seq.section, "travel")
	_to(seq, seq.clock + 2048)
	_gains_at_join("level", seq)


func _gains_at_join(label: String, seq: Ace) -> void:
	for stem in ["drums", "other"]:
		var found := false
		for v in seq.voices:
			if v.stem == stem and not seq.fading.has(v):
				found = true
				t.check("%s new %s are at join gain once the join ends" % [label, stem], absf(v.gain - v.target) <= TOLERANCE and v.target > 0.0, "gain %.3f target %.3f" % [v.gain, v.target])
		t.check("%s has new %s voices" % [label, stem], found)


# Boss mode: a Warden state change joins its section while a parameter commit lands inside
# the join. The commit must leave the entering voices on their own join.
func _boss_join() -> void:
	var seq := Ace.new(MANIFEST)
	seq.parameter_enabled = true
	seq.parameters = {"threat": 0.7, "speed": 0.0, "chain": 0.0, "armour": 1.0}
	seq.start_boss(0)
	t.eq("boss mode", seq.mode, "warden")
	# The pivot hands over to the build: wait for that join to begin, the pivot still sounding.
	var limit: int = seq.grid_bar * 12
	while not (seq.pending.get("section", "") == "build" and seq.pending.get("begun", false)) and seq.clock < limit:
		seq.render(16)
	t.check("the build join has begun", seq.pending.get("section", "") == "build" and seq.pending.get("begun", false) and seq.section == "pivot")
	# The commit lands inside the join and moves the lead's chain factor.
	seq.commit_parameters(seq.clock + 1, {"threat": 0.7, "speed": 0.0, "chain": 1.0, "armour": 1.0}, false, false, "")
	while seq.section != "build" and seq.clock < limit:
		seq.render(16)
	t.eq("boss reaches build", seq.section, "build")
	_to(seq, seq.clock + 2048)
	_gains_at_join("boss", seq)


# The armour strip and the Warden-broken release take the lead out over STOP_RAMP.
func _release(label: String, feed: Dictionary, released: bool) -> void:
	var seq := _level({"threat": 0.0, "speed": 1.0, "chain": 1.0, "armour": 1.0})
	t.check("%s starts with the lead up" % label, _target(seq, "other") > 0.9)
	seq.commit_parameters(seq.clock, feed, released, false, "")
	var at: int = seq.clock
	_to(seq, at + Ace.STOP_RAMP + 64)
	var lead := -1.0
	for v in seq.voices:
		if v.stem == "other":
			lead = v.gain
	t.eq("%s strips the lead within STOP_RAMP" % label, lead, 0.0)
