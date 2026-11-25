extends RefCounted


const STRIKE_KILLS := 3
const STRIKE_WINDOW := 1.2
const SPARE_WINDOW := 2.0
const TURKEY_STRIKES := 3
const TURKEY_WINDOW := 4.0

const ENTRIES := [
	{"id": "strike", "category": "build", "name": "Strike", "hint": "Knocked machines", "clue": "+ three down from one knock",
		"text": "A knocked machine took three down in one chain."},
	{"id": "spare", "category": "build", "name": "Spare", "hint": "A bounce", "clue": "+ the one that bounced you",
		"text": "You bounced off a heavy one, then took it down."},
	{"id": "turkey", "category": "build", "name": "Turkey", "hint": "Strike", "clue": "+ two more inside 4 s",
		"text": "Three strikes inside four seconds."},
	{"id": "too_heavy_for_you", "category": "build", "name": "Too heavy for you", "hint": "Moss's locked hook",
		"clue": "+ come back heavier", "text": "Moss sells the top shelf once your heft reaches the next tier."},
]

var clock := 0.0
var _pinned := {}
var _pin_kills: Array[float] = []
var _bounced := {}
var _strikes: Array[float] = []
var _found: Array = []


func reset() -> void:
	_pinned = {}
	_pin_kills.clear()
	_bounced = {}
	_strikes.clear()
	_found.clear()


func note_pin(victim: Node3D) -> void:
	if is_instance_valid(victim):
		_pinned[victim.get_instance_id()] = {"node": victim, "t": clock, "at": victim.global_position}


func note_rebound(enemy: Node3D) -> void:
	if is_instance_valid(enemy):
		_bounced[enemy.get_instance_id()] = {"node": enemy, "t": clock, "at": enemy.global_position}


func step(delta: float) -> Array:
	clock += delta
	_found = []
	for key in _pinned.keys():
		var row: Dictionary = _pinned[key]
		if clock - row["t"] > STRIKE_WINDOW:
			_pinned.erase(key)
		elif _down(row):
			_pinned.erase(key)
			_pin_kills.append(clock)
			while not _pin_kills.is_empty() and clock - _pin_kills[0] > STRIKE_WINDOW:
				_pin_kills.pop_front()
			if _pin_kills.size() >= STRIKE_KILLS:
				_pin_kills.clear()
				_strike(row["at"])
	for key in _bounced.keys():
		var row: Dictionary = _bounced[key]
		if clock - row["t"] > SPARE_WINDOW:
			_bounced.erase(key)
		elif _down(row):
			_bounced.erase(key)
			_found.append(["spare", row["at"]])
	return _found


func _strike(at: Vector3) -> void:
	_found.append(["strike", at])
	_strikes.append(clock)
	while not _strikes.is_empty() and clock - _strikes[0] > TURKEY_WINDOW:
		_strikes.pop_front()
	if _strikes.size() >= TURKEY_STRIKES:
		_strikes.clear()
		_found.append(["turkey", at])


static func _down(row: Dictionary) -> bool:
	var node = row["node"]
	if not is_instance_valid(node):
		return true
	if node.has_method("is_dead") and node.is_dead():
		return true
	row["at"] = node.global_position
	return false
