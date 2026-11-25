extends RefCounted

const Palette := preload("res://src/core/palette.gd")


const DEFAULT_LIMIT := 4
const DEFAULT_RAIL_MIN_S := 3.0
const KIND_TIMER := "timer"
const KIND_COUNT := "count"
const EPSILON := 0.000001
const DEFAULT_TONE := Palette.SAND

static var default_rail_min_s := DEFAULT_RAIL_MIN_S

signal buff_changed
signal buff_expired(id: String)

var _entries := {}
var _seq := 0
var _events: Node = null


static func reset_for_tests() -> void:
	default_rail_min_s = DEFAULT_RAIL_MIN_S


func bind_events(events: Node) -> void:
	if _events == events:
		return
	if _events != null and is_instance_valid(_events):
		_disconnect_if(_events, "run_started", _on_run_started)
		_disconnect_if(_events, "stage_entered", _on_stage_entered)
		_disconnect_if(_events, "stage_content_cleared", _on_stage_content_cleared)
		_disconnect_if(_events, "player_died", _on_player_died)
		_disconnect_if(_events, "run_ended", _on_run_ended)
	_events = events
	if _events != null and is_instance_valid(_events):
		_connect_if(_events, "run_started", _on_run_started)
		_connect_if(_events, "stage_entered", _on_stage_entered)
		_connect_if(_events, "stage_content_cleared", _on_stage_content_cleared)
		_connect_if(_events, "player_died", _on_player_died)
		_connect_if(_events, "run_ended", _on_run_ended)


func post(id: String, spec: Dictionary) -> void:
	if id.strip_edges().is_empty():
		return
	var before := _visible_snapshot()
	var existing: Dictionary = _entries.get(id, {})
	var duration_s := maxf(0.0, float(spec.get("duration_s", existing.get("duration_s", 0.0))))
	var raw_kind := String(spec.get("kind", existing.get("kind", "")))
	var kind := raw_kind if (raw_kind == KIND_TIMER or raw_kind == KIND_COUNT) else (KIND_TIMER if duration_s > 0.0 else KIND_COUNT)
	if kind == KIND_TIMER and duration_s <= EPSILON:
		if _entries.erase(id) and _visible_snapshot() != before:
			buff_changed.emit()
		return
	var max_stacks := maxi(0, int(spec.get("max_stacks", existing.get("max_stacks", 0))))
	var default_stacks := 1 if kind == KIND_COUNT else 0
	var stacks := maxi(0, int(spec.get("stacks", existing.get("stacks", default_stacks))))
	if max_stacks > 0:
		stacks = mini(stacks, max_stacks)
	if kind == KIND_COUNT and stacks <= 0:
		if _entries.erase(id) and _visible_snapshot() != before:
			buff_changed.emit()
		return
	var left_s := 0.0
	if duration_s > EPSILON:
		left_s = clampf(float(spec.get("left_s", duration_s)), 0.0, duration_s)
		if left_s <= EPSILON:
			if _entries.erase(id) and _visible_snapshot() != before:
				buff_changed.emit()
			return
	var icon := String(spec.get("icon", existing.get("icon", "")))
	var raw_tone = spec.get("tone", existing.get("tone", DEFAULT_TONE))
	var tone: Color = raw_tone if raw_tone is Color else DEFAULT_TONE
	var rail_min_s := maxf(0.0, float(spec.get("rail_min_s", existing.get("rail_min_s", default_rail_min_s))))
	var order: int = int(existing.get("order", 0))
	if existing.is_empty():
		_seq += 1
		order = _seq
	var entry := {
		"id": id,
		"icon": icon,
		"tone": tone,
		"kind": kind,
		"left_s": left_s,
		"duration_s": duration_s,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"rail_min_s": rail_min_s,
		"order": order,
	}
	var becomes_visible := _is_rail_visible(entry) and (existing.is_empty() or not _is_rail_visible(existing))
	if becomes_visible:
		_evict_if_full(id, DEFAULT_LIMIT)
	_entries[id] = entry
	if _visible_snapshot() != before:
		buff_changed.emit()


func clear_id(id: String) -> void:
	if not _entries.has(id):
		return
	var before := _visible_snapshot()
	_entries.erase(id)
	if _visible_snapshot() != before:
		buff_changed.emit()


func clear() -> void:
	if _entries.is_empty():
		return
	var before := _visible_snapshot()
	_entries.clear()
	_seq = 0
	if _visible_snapshot() != before:
		buff_changed.emit()


func step(delta: float) -> void:
	if delta <= 0.0 or _entries.is_empty():
		return
	var before := _visible_snapshot()
	var expired: Array[Dictionary] = []
	for id in _entries:
		var e: Dictionary = _entries[id]
		if float(e["duration_s"]) <= EPSILON:
			continue
		e["left_s"] = maxf(0.0, float(e["left_s"]) - delta)
		if float(e["left_s"]) <= EPSILON:
			expired.append(e)
	if not expired.is_empty():
		expired.sort_custom(_sort_oldest_first)
		for e in expired:
			_entries.erase(e["id"])
		for e in expired:
			buff_expired.emit(String(e["id"]))
	if _visible_snapshot() != before:
		buff_changed.emit()


func active_rows(limit := DEFAULT_LIMIT) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if limit <= 0 or _entries.is_empty():
		return out
	var visible: Array[Dictionary] = []
	for id in _entries:
		var e: Dictionary = _entries[id]
		if _is_rail_visible(e):
			visible.append(e)
	while visible.size() > limit:
		var victim_idx := _shortest_remaining_index(visible)
		visible.remove_at(victim_idx)
	visible.sort_custom(_sort_oldest_first)
	for e in visible:
		out.append(_to_row(e))
	return out


func _is_rail_visible(e: Dictionary) -> bool:
	var duration_s := float(e["duration_s"])
	if String(e["kind"]) == KIND_COUNT and duration_s <= EPSILON:
		return int(e["stacks"]) > 0
	return duration_s >= float(e["rail_min_s"]) and float(e["left_s"]) > EPSILON


func _evict_if_full(incoming_id: String, cap: int) -> void:
	if cap <= 0:
		return
	var visible: Array[Dictionary] = []
	for id in _entries:
		if id == incoming_id:
			continue
		var e: Dictionary = _entries[id]
		if _is_rail_visible(e):
			visible.append(e)
	while visible.size() >= cap:
		var victim_idx := _shortest_remaining_index(visible)
		var victim: Dictionary = visible[victim_idx]
		_entries.erase(victim["id"])
		visible.remove_at(victim_idx)


func _shortest_remaining_index(list: Array[Dictionary]) -> int:
	var best := 0
	for i in range(1, list.size()):
		if _evict_before(list[i], list[best]):
			best = i
	return best


static func _evict_before(a: Dictionary, b: Dictionary) -> bool:
	var a_left := float(a["left_s"]) if float(a["duration_s"]) > EPSILON else INF
	var b_left := float(b["left_s"]) if float(b["duration_s"]) > EPSILON else INF
	if not is_equal_approx(a_left, b_left):
		return a_left < b_left
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return String(a["id"]) < String(b["id"])


static func _sort_oldest_first(a: Dictionary, b: Dictionary) -> bool:
	if int(a["order"]) != int(b["order"]):
		return int(a["order"]) < int(b["order"])
	return String(a["id"]) < String(b["id"])


static func _to_row(e: Dictionary) -> Dictionary:
	var duration_s := float(e["duration_s"])
	var left_s := float(e["left_s"])
	var stacks := int(e["stacks"])
	var max_stacks := int(e["max_stacks"])
	var kind := String(e["kind"])
	var frac := 1.0
	if duration_s > EPSILON:
		frac = clampf(left_s / duration_s, 0.0, 1.0)
	elif max_stacks > 0:
		frac = clampf(float(stacks) / float(max_stacks), 0.0, 1.0)
	return {
		"id": String(e["id"]),
		"icon": String(e["icon"]),
		"tone": e["tone"] as Color,
		"kind": kind,
		"left_s": left_s,
		"duration_s": duration_s,
		"frac": frac,
		"stacks": stacks,
		"max_stacks": max_stacks,
		"show_digit": kind == KIND_COUNT or stacks > 1,
	}


func _visible_snapshot() -> Array[Dictionary]:
	return active_rows(DEFAULT_LIMIT)


func _connect_if(obj: Node, sig: String, fn: Callable) -> void:
	if obj.has_signal(sig) and not obj.is_connected(sig, fn):
		obj.connect(sig, fn)


func _disconnect_if(obj: Node, sig: String, fn: Callable) -> void:
	if obj.has_signal(sig) and obj.is_connected(sig, fn):
		obj.disconnect(sig, fn)


func _on_run_started(_class_id: String) -> void:
	clear()


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	clear()


func _on_stage_content_cleared(_reason: String) -> void:
	clear()


func _on_player_died() -> void:
	clear()


func _on_run_ended(_won: bool) -> void:
	clear()
