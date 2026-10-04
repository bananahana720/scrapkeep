extends Node3D

const Interactables := preload("res://src/world/interactables.gd")
const Palette := preload("res://src/core/palette.gd")

# The world rescues (DESIGN-V3, pilots): a caged pilot on a map, freed by the player. The
# map says where (StageMap.rescue_sites: id, at, quest), the cage is an ally-family device
# in the interact system's hold consent, and finishing it emits rescue_completed(quest) on
# the bus; achievements.gd earns the pilot's row from that fact. A quest is rescued once
# per run: a stage entry, so a retry, rebuilds an unfinished cage and keeps a freed one
# open. A new run clears the record.

const BREAK_SECONDS := 2.0
const RING_RADIUS := 4.0

var ctx
var system
var cages: Array = []
var _done := {}


# One cage. Hold E (the ally family's hold) to start the lock breaking; it gives way after
# BREAK_SECONDS whether or not E stays held, with the ring filling as the gauge.
class Cage extends "res://src/world/device.gd":
	var quest := ""
	var owner_site
	var progress := 0.0
	var breaking := false
	var _bars: Node3D

	func _init() -> void:
		family = "ally"

	func build() -> void:
		quest = String(spec.get("quest", ""))
		var steel := Palette.solid(Palette.CHARCOAL)
		var accent := Palette.solid(Interactables.color(family), 1.2)
		ground_ring(RING_RADIUS, Interactables.color(family))
		_bars = Node3D.new()
		add_child(_bars)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				box(Vector3(0.3, 3.2, 0.3), Vector3(sx * 1.4, 1.6, sz * 1.4), steel, false, _bars)
		for s in [-1.0, 1.0]:
			box(Vector3(3.1, 0.25, 0.25), Vector3(0.0, 3.2, s * 1.4), steel, false, _bars)
			box(Vector3(0.25, 0.25, 3.1), Vector3(s * 1.4, 3.2, 0.0), steel, false, _bars)
			box(Vector3(0.12, 3.0, 0.12), Vector3(s * 0.5, 1.6, 1.4), steel, false, _bars)
		box(Vector3(0.7, 0.5, 0.2), Vector3(0.0, 1.4, 1.5), accent, false, _bars)
		box(Vector3(0.8, 1.2, 0.8), Vector3(0.0, 0.6, 0.0), accent)
		if owner_site != null and owner_site.is_done(quest):
			_bars.visible = false
			spent = true

	func ready_now() -> bool:
		return not spent and not breaking

	func gauge() -> float:
		return progress / BREAK_SECONDS if breaking else -1.0

	func terms() -> String:
		return "free the runner"

	func fire() -> bool:
		if spent or breaking:
			return false
		breaking = true
		progress = 0.0
		return false

	func tick(delta: float) -> void:
		if not breaking:
			return
		progress += delta
		if progress < BREAK_SECONDS:
			return
		breaking = false
		spent = true
		_bars.visible = false
		system.fired(self)
		owner_site.complete(quest)


func setup(ctx_ref, interact_ref) -> void:
	ctx = ctx_ref
	system = interact_ref
	name = "RescueSites"
	ctx.events.stage_entered.connect(_on_stage_entered)
	ctx.events.stage_content_cleared.connect(func(_reason: String): clear())
	ctx.events.run_started.connect(func(_class_id: String): _done.clear())


func _on_stage_entered(_stage: int, _retry: bool) -> void:
	clear()
	var map = ctx.terrain.map()
	if not "rescue_sites" in map:
		return
	for spec in map.rescue_sites:
		var cage := Cage.new()
		cage.owner_site = self
		add_child(cage)
		var at: Vector2 = spec["at"]
		cage.global_position = ctx.terrain.drop_point(at.x, at.y, 0.0)
		var face: Vector2 = spec.get("face", Vector2(0.0, 1.0))
		cage.rotation.y = atan2(face.x, face.y)
		cage.setup(ctx, system, spec)
		system.register(cage)
		cages.append(cage)


func clear() -> void:
	for cage in cages:
		if is_instance_valid(cage):
			system.unregister(cage)
			cage.queue_free()
	cages.clear()


func is_done(quest: String) -> bool:
	return bool(_done.get(quest, false))


func cage(quest: String):
	for c in cages:
		if c.quest == quest:
			return c
	return null


# The one place a rescue finishes: once per quest per run.
func complete(quest: String) -> void:
	if is_done(quest):
		return
	_done[quest] = true
	ctx.events.rescue_completed.emit(quest)
