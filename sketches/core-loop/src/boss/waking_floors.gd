extends RefCounted

const Rules := preload("res://src/boss/boss_rules.gd")
const Posture := preload("res://src/combat/boss_posture.gd")

# The Waking's floors as a pure rule on the posture contract: one floor per phase stacked
# above a pit, and each shattered chunk drops one floor, highest first, so the fight
# sinks a tier per phase. The last chunk is defeat and drops nothing. Nothing here
# touches the tree or the terrain; a map lays overlays() onto its ground and can delegate
# its overlay_height to this object.
#
# The caller feeds the Warden's chunks: chunks_shattered(n) with the count broken so far,
# or on_posture(chunks_left) with warden.chunks_left(), as posture_changed carries it.
# Floors never rise: a count lower than one already seen is ignored and counted in
# ignored. A rebuild is a new object.
#
# Floors are numbered from the top: floor 1 is the highest and falls to chunk 1, floor
# floor_count() is the lowest and falls to the last phase's chunk. Floor k carries phase
# k's name.
#
# Overlay record fields:
#   id      "waking_floor_k"
#   height  floor k's height above the ground, a delta a map adds to ground
#   live    false once the floor has dropped

const ID_PREFIX := "waking_floor_"
# Height between tiers, and from the pit to the lowest floor.
const SPACING := 4.0
# Three-phase anthem pacing (Base / +10 BPM / +20 BPM): Spoil -> Seam -> Bedrock & Pit finale.
const ANTHEM_BPM_DELTA := [0, 10, 20]

var names: Array
var chunks: int
var shattered := 0
var ignored := 0


func _init(phase_names: Array = Rules.PHASE_NAMES, chunk_count: int = Posture.CHUNKS) -> void:
	names = phase_names.duplicate()
	chunks = chunk_count


func floor_count() -> int:
	return names.size()


func floor_id(k: int) -> String:
	return "%s%d" % [ID_PREFIX, k]


func floor_height(k: int) -> float:
	return float(floor_count() - k + 1) * SPACING


func live(k: int) -> bool:
	return k >= 1 and k <= floor_count() and k > shattered


func live_floors() -> Array[int]:
	var out: Array[int] = []
	for k in range(1, floor_count() + 1):
		if live(k):
			out.append(k)
	return out


func overlays() -> Array:
	var out := []
	for k in range(1, floor_count() + 1):
		out.append({"id": floor_id(k), "height": floor_height(k), "live": live(k)})
	return out


func overlay_height(id: String, ground: float) -> float:
	if not id.begins_with(ID_PREFIX):
		return -INF
	var tail := id.substr(ID_PREFIX.length())
	if not tail.is_valid_int():
		return -INF
	var k := tail.to_int()
	return ground + floor_height(k) if live(k) else -INF


# Returns false when n is lower than a count already seen, and the floors stay put.
func chunks_shattered(n: int) -> bool:
	if n < shattered:
		ignored += 1
		return false
	shattered = mini(n, chunks)
	return true


func on_posture(chunks_left: int) -> bool:
	return chunks_shattered(chunks - chunks_left)


# The highest live floor, or 0 for the pit.
func current_floor() -> int:
	var open := live_floors()
	return open[0] if not open.is_empty() else 0


func defeated() -> bool:
	return shattered >= chunks


# 3-phase anthem index (1..3): Spoil=1 (Base), Seam=2 (+10 BPM), Bedrock & Pit share 3 (+20 BPM).
func music_phase() -> int:
	return clampi(shattered + 1, 1, Rules.PHASE_NAMES.size())


func phase_name() -> String:
	var k := current_floor()
	if k > 0 and k <= names.size():
		return String(names[k - 1])
	return "Pit"


func anthem_bpm_delta() -> int:
	return ANTHEM_BPM_DELTA[music_phase() - 1]


func objective() -> String:
	if defeated():
		return "The Waking is down"
	var k := current_floor()
	if k == 0:
		return "In the pit: shatter the last chunk"
	return "%s floor: shatter a chunk to drop it" % names[k - 1]
