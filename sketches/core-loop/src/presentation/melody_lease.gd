extends RefCounted

# Single melodic lane lease (Sound V4, verified by SoundArbiter.tla).
# Tracks who owns the foreground melodic lane (June's answer vs callers, quotes, warnings,
# and directed sections) and stamps DJ trims with a monotonic epoch so stale trims cancel.

const YIELD_SECTIONS := ["open", "drop", "break"]

var owner := "none"
var epoch := 0
var answer_id := ""
var answer_at := -1
var trim_epoch := -1


func bump_epoch() -> int:
	epoch += 1
	return epoch


func can_book_june(allowed: bool, warning: bool, busy: bool) -> bool:
	return allowed and not warning and not busy


func book_june(id: String, at: int) -> int:
	owner = "june"
	answer_id = id
	answer_at = at
	trim_epoch = epoch
	return epoch


func should_preempt(clock_samples: int, bar_samples: int, allowed: bool, warning: bool, busy: bool, ace_mode: String, ace_section: String, pending_section: String) -> bool:
	if answer_id == "":
		return false
	if bar_samples > 0 and clock_samples >= answer_at + bar_samples:
		answer_id = ""
		answer_at = -1
		owner = "none"
		return false
	if not allowed or warning or busy:
		return true
	return ace_mode == "piece" or ace_section in YIELD_SECTIONS or pending_section in YIELD_SECTIONS


func release() -> String:
	var dropped := answer_id
	answer_id = ""
	answer_at = -1
	owner = "none"
	epoch += 1
	return dropped


func trim_valid(action_epoch: int) -> bool:
	return action_epoch < 0 or action_epoch == epoch


func reset() -> void:
	owner = "none"
	answer_id = ""
	answer_at = -1
	trim_epoch = -1
	epoch += 1
