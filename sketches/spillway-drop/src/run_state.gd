extends RefCounted

const Buffs := preload("res://src/buffs.gd")

# One object owns the whole run: phase, health, scrap, buffs and the clock. Every
# system reads its numbers from here instead of keeping a private copy that has
# to stay in sync.
enum { RUNNING, CHARGING, CHARGED, CLEARED, DEAD }

const PHASE_NAMES := ["running", "charging", "charged", "clear", "scrapped"]
const TIER_SECONDS := 45.0
const REGEN_DELAY := 5.0
const REGEN_RATE := 7.0
const HULL_BUFF_HP := 20.0

signal buffs_changed
signal phase_changed(phase: int)

var phase := RUNNING
var max_hp := 100.0
var hp := 100.0
var scrap := 0
var buffs := {}
var stage_time := 0.0
var since_damage := 99.0
var caches_opened := 0
var secret_found := false


func tier() -> int:
	return int(stage_time / TIER_SECONDS)


func alive() -> bool:
	return phase != DEAD and phase != CLEARED


func stacks(id: String) -> int:
	return buffs.get(id, 0)


func advance(delta: float) -> void:
	if not alive():
		return
	stage_time += delta
	since_damage += delta
	if since_damage > REGEN_DELAY and hp < max_hp:
		hp = minf(max_hp, hp + REGEN_RATE * delta)


func damage(amount: float) -> void:
	if not alive():
		return
	hp = maxf(0.0, hp - amount)
	since_damage = 0.0
	if hp <= 0.0:
		set_phase(DEAD)


func add_scrap(amount: int) -> void:
	scrap += amount


func spend(cost: int) -> bool:
	if scrap < cost:
		return false
	scrap -= cost
	return true


func take_buff(id: String) -> void:
	buffs[id] = stacks(id) + 1
	if id == "hull":
		max_hp += HULL_BUFF_HP
		hp += HULL_BUFF_HP
	buffs_changed.emit()


func set_phase(next: int) -> void:
	if phase == next:
		return
	phase = next
	phase_changed.emit(next)


func buff_summary() -> String:
	if buffs.is_empty():
		return "no buffs"
	var parts: Array[String] = []
	for id in Buffs.SPECS.map(func(s): return s["id"]):
		var n: int = stacks(id)
		if n > 0:
			parts.append("%s x%d" % [Buffs.label(id), n])
	return "  ·  ".join(parts)
