extends RefCounted

# Single melodic lane lease (Sound V4, verified by SoundArbiter.tla).
# Owns June's active set-director answer booking and decides when warnings, callers,
# pilot quotes, pack changes, or directed sections preempt it.

const YIELD_SECTIONS := ["open", "drop", "break"]

var answer_id := ""
var answer_at := -1
var epoch := 0


func book(id: String, at: int) -> int:
	answer_id = id
	answer_at = at
	return epoch


func release() -> String:
	var dropped := answer_id
	answer_id = ""
	answer_at = -1
	epoch += 1
	return dropped


func bump_epoch() -> int:
	epoch += 1
	return epoch


func should_preempt(state: Dictionary) -> bool:
	var id := String(state.get("answer_id", answer_id))
	if id == "":
		return false
	var at := int(state.get("answer_at", answer_at))
	var bar_samples := int(state.get("bar_samples", 0))
	var clock_samples := int(state.get("clock_samples", 0))
	if bar_samples > 0 and clock_samples >= at + bar_samples:
		answer_id = ""
		answer_at = -1
		return false
	if not bool(state.get("allowed", true)) or bool(state.get("warning", false)) or bool(state.get("busy", false)):
		return true
	var mode := String(state.get("ace_mode", ""))
	var sec := String(state.get("ace_section", ""))
	var pending := String(state.get("pending_section", ""))
	return mode == "piece" or sec in YIELD_SECTIONS or pending in YIELD_SECTIONS
