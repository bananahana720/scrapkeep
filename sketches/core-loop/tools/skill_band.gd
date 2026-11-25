extends RefCounted

const BANDS := {
	"expert": {"reaction_first": 0.25, "reaction_last": 0.25, "read_first": 1.0, "read_last": 1.0,
		"window_first": 0.85, "window_last": 0.85, "learn_attempts": 1, "kit": "full"},
	"learner": {"reaction_first": 0.45, "reaction_last": 0.30, "read_first": 0.65, "read_last": 0.92,
		"window_first": 0.25, "window_last": 0.45, "learn_attempts": 5, "kit": "base"},
	"novice": {"reaction_first": 0.70, "reaction_last": 0.70, "read_first": 0.35, "read_last": 0.35,
		"window_first": 0.15, "window_last": 0.15, "learn_attempts": 1, "kit": "basic"},
}

const BASE_VERBS := ["special", "line_cast", "plant", "harpoon", "weak_points", "ultimate"]

var name := "expert"
var attempt := 1
var reaction_s := 0.25
var read_chance := 1.0
var window_share := 0.85
var kit := "full"

var _seed := 1
var _rng := RandomNumberGenerator.new()
var _read := {}

static var quiet := false
static var last_refusal := ""


static func make(band_name: String, attempt_number: int, seed_value: int):
	var key := band_name
	if not BANDS.has(key):
		var message := "skill_band: unknown band '%s'; use expert, learner or novice" % band_name
		last_refusal = message
		if not quiet:
			push_error(message)
		key = "expert"
	var row: Dictionary = BANDS[key]
	var band = new()
	band.name = key
	band.attempt = maxi(attempt_number, 1)
	var span := maxi(int(row["learn_attempts"]) - 1, 1)
	var t := clampf(float(band.attempt - 1) / float(span), 0.0, 1.0)
	band.reaction_s = lerpf(float(row["reaction_first"]), float(row["reaction_last"]), t)
	band.read_chance = lerpf(float(row["read_first"]), float(row["read_last"]), t)
	band.window_share = lerpf(float(row["window_first"]), float(row["window_last"]), t)
	band.kit = String(row["kit"])
	band._seed = seed_value
	band._rng.seed = hash(["band", key, band.attempt, seed_value])
	return band


static func roll_window(seed_value: int, index: int, share: float) -> bool:
	if share <= 0.0:
		return false
	if share >= 1.0:
		return true
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["window", seed_value, index])
	return rng.randf() < share


func hits_window(index: int) -> bool:
	return roll_window(_seed, index, window_share)


func reads(key: int) -> bool:
	if read_chance >= 1.0:
		return true
	if not _read.has(key):
		_read[key] = _rng.randf() < read_chance
	return _read[key]


func forget(live: Dictionary) -> void:
	if _read.size() > 64:
		for key in _read.keys():
			if not live.has(key):
				_read.erase(key)


func allows(verb: String) -> bool:
	if kit == "full":
		return true
	if kit == "base":
		return verb in BASE_VERBS
	return false


func timed_ultimate() -> bool:
	return kit == "full"


func timed_sheet() -> bool:
	return kit == "full"


func describe() -> Dictionary:
	return {"name": name, "attempt": attempt, "reaction_s": snappedf(reaction_s, 0.001),
		"read_chance": snappedf(read_chance, 0.001), "window_share": snappedf(window_share, 0.001), "kit": kit}
