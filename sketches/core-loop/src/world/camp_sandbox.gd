extends Node

const Palette := preload("res://src/core/palette.gd")
const Roster := preload("res://src/combat/roster.gd")
const Fleet := preload("res://src/combat/fleet.gd")
const Combat := preload("res://src/combat/combat.gd")
const Sight := preload("res://src/combat/sight.gd")
const Swarm := preload("res://src/combat/swarm.gd")
const Projectile := preload("res://src/combat/projectile.gd")
const Chaser := preload("res://src/combat/chaser.gd")
const Lobber := preload("res://src/combat/lobber.gd")
const Miniboss := preload("res://src/combat/miniboss.gd")
const Worlds := preload("res://src/core/worlds.gd")
const PICKER := "res://src/ui/camp_enemy_picker.gd"

# The camp's any-enemy sandbox: the call box at the practice yard calls one enemy of any kind
# the pilot has met onto a grate, up to CAP at once, and the enemies fight the ball for real.
# Nothing here is a run. It never calls the spawner's spawn_enemy (which wires a kill into the
# run, a hit into the run's health and a fleet pack into the director); it builds the enemy the
# way the spawner does and wires the three things it needs itself:
#
# - the ground: the yard's own flat floor (YardGround), not the stage terrain under the camp;
# - the ball's hits: a small hull of this sandbox's own (HULL), never run.damage, so no
#   player_hit or player_died goes out and no scrap spills. At 0 the ball is put back at the
#   yard's entry with the hull full again, no penalty;
# - the lobber's shell, which combat would otherwise wire to the run.
#
# A kill is not recorded (no run kills, no enemy_killed), so the run log, achievements and
# the saved stats never see the yard. The enemy_spawned fact is published, so the enemy's
# presentation (wind-up glyphs, status marks, audio) works; the picker's met-marking listens
# to that fact too, and a called enemy is by definition already met.
# Not spawnable: the stage Warden and the vault (they read the stage and the beacon), and every
# boss (a boss is a module that owns an arena, not an enemy to drop on a grate).
# Everything despawns when the ball leaves the yard, when the walk ends, or on "Clear yard".

const CAP := 4
const HULL := 100.0
const SAND := 0.12
const YARD_RADIUS := 24.0
const FALL_DEPTH := 40.0
const SPAWN_CLEARANCE := 2.4
const KEY := "key_e"
const STATION_RADIUS := 3.5
const EXCLUDED := ["warden", "vault"]
const BASE_KINDS := ["chaser", "lobber", "miniboss"]

# Where a kind turns up, in the crew log's voice. A kind not listed here is described from
# its roster row (where_met).
const WHERE := {
	"chaser": "Spillway Works, stage one. It will find you first.",
	"lobber": "Spillway Works, stage one. Posts its mail from a distance.",
	"miniboss": "Spillway Works, once a stage, on a bad day.",
	"reactor_relic": "Spillway Works, with the reactor family. Bring a Geiger counter or a good excuse.",
	"swarm_remnant": "The Dig, in the swarm family's stage. The crew log counts them by the dozen.",
	"mind_hand": "The Highdraft, with the Mind's family. It reads the log, then reads you.",
}

signal changed

var hub
var game
var ctx
var combat
var ground := YardGround.new()
var live: Array[Node3D] = []
var hull := HULL
var wrecks := 0
# How many times the yard has been emptied by clear() (the call box's "Clear yard", leaving the yard, the walk
# ending), which is not a kill: the ring ends a count on it (camp_ring.gd).
var clears := 0
var walking := false
var inside := false
var page_open := false
# Tests set this to stand in for the saved list of met kinds; null reads the save.
var met_override = null

var _shells: Array[Node3D] = []
var _slots := {}
var _yard_centre := Vector3.ZERO
var _entry := Vector3.ZERO
var _page: Control
var _layer: CanvasLayer
var _frozen_here := false
var _via_screens := false


# The camp hub calls this once after it is built.
static func attach(camp_hub) -> void:
	var sandbox := new()
	sandbox.name = "CampSandbox"
	camp_hub.root.add_child(sandbox)
	sandbox.bind(camp_hub)


func bind(camp_hub) -> void:
	hub = camp_hub
	game = hub.game
	ctx = game.ctx
	combat = ctx.spawner
	ground.floor_y = hub.socket("camp_sandbox_yard", "enemy_spawn_0").origin.y - 0.5
	_entry = hub.socket("camp_sandbox_yard", "entry").origin
	var yard: Node3D = hub.piece("camp_sandbox_yard")
	_yard_centre = yard.global_position if yard != null else Vector3(_entry.x, 0.0, _entry.z - 21.5)
	hub.walk_entered.connect(_on_walk_entered)
	hub.walk_left.connect(_on_walk_left)
	walking = hub.get("walking") == true
	var box: Transform3D = hub.socket("camp_call_box", "interact")
	hub.add_station("sandbox_call_box", box.origin, "Call box", KEY, STATION_RADIUS, open_picker)
	_picker().watch(game)


func _picker():
	return load(PICKER)


# --- Which kinds, in what words --------------------------------------------------------------

# The enemy kinds the box can call, in picker order: the first roster's three, then the rest
# of the roster as declared, each only when its behaviour exists.
static func kinds() -> Array:
	var out: Array = []
	for kind in BASE_KINDS:
		out.append(kind)
	for kind in Roster.ROWS:
		if kind not in out and spawnable(kind):
			out.append(kind)
	return out


static func spawnable(kind: String) -> bool:
	if kind in EXCLUDED or not Roster.has(kind):
		return false
	return kind in BASE_KINDS or Fleet.SCRIPTS.has(kind) or (Roster.row(kind).has("script") and Roster.built(kind))


static func name_of(kind: String) -> String:
	return Roster.name_of(kind)


static func line_of(kind: String) -> String:
	var job := Roster.job_of(kind)
	var line := String(Roster.row(kind).get("line", ""))
	return line if job == "" else "%s %s" % [job, line]


static func where_met(kind: String) -> String:
	if WHERE.has(kind):
		return WHERE[kind]
	var row := Roster.row(kind)
	var world := int(row.get("world", 0))
	if world >= 1 and world <= Worlds.ROWS.size():
		return "%s. The reports on it are short." % Worlds.ROWS[world - 1]["name"]
	if kind in Roster.COUNTERS:
		return "Spillway Works, in reinforcement packs, once the stage clock has run a while."
	return "Not on the manifest."


# --- Spawning --------------------------------------------------------------------------------

# Why a kind cannot be called right now: "", or in_run, away, unknown, locked or full.
func refusal(kind: String) -> String:
	if game.flow.in_play():
		return "in_run"
	_update_inside()
	if not walking or not inside:
		return "away"
	if not spawnable(kind):
		return "unknown"
	if not kind in _met():
		return "locked"
	if live_count() >= CAP:
		return "full"
	return ""


func live_count() -> int:
	_prune()
	return live.size()


# Calls one enemy of a kind onto a free grate. Null when refused (see refusal).
func spawn(kind: String) -> Node3D:
	if refusal(kind) != "":
		return null
	var slot := 0
	while _slots.has(slot):
		slot += 1
	var enemy := stand(kind, hub.socket("camp_sandbox_yard", "enemy_spawn_%d" % slot).origin)
	_slots[slot] = enemy
	return enemy


# Stands one enemy of a kind on the yard's floor at `at`, at `health` times its health, wired to this yard's hull.
# The call box's own limits (met kinds, the cap, the grates) are spawn()'s; the ring's counts come in here
# (camp_ring.gd). More health is health only: what the machine's tools do stays at stage one's numbers.
func stand(kind: String, at: Vector3, health := 1.0) -> Node3D:
	var enemy := _make(kind)
	ctx.root.add_child(enemy)
	enemy.global_position = ground.drop_point(at.x, at.z, SPAWN_CLEARANCE)
	var target = Sight.new(ctx.player, combat, enemy, kind)
	var spec := _spec_for(kind)
	if health != 1.0:
		spec["stage_threat"] = 1.0
	enemy.setup(target, ground, ctx.root, _is_live, health, spec)
	enemy.hit_player.connect(_on_hit.bind(kind))
	if enemy.has_signal("fired"):
		enemy.fired.connect(_on_fired.bind(enemy))
	enemy.died.connect(func(_where: Vector3, _scrap: int): _forget(enemy))
	# A yard machine: the picker's met-marking skips anything that carries this.
	enemy.set_meta("sandbox_slot", true)
	live.append(enemy)
	ctx.events.enemy_spawned.emit(enemy, kind)
	changed.emit()
	return enemy


# The hull is whole again.
func mend() -> void:
	hull = HULL
	changed.emit()


func _make(kind: String) -> Node3D:
	match kind:
		"chaser":
			return Chaser.new()
		"lobber":
			return Lobber.new()
		"miniboss":
			return Miniboss.new()
	return combat.fleet.make(kind)


# The spec the spawner would build (fleet.dress and the spawner's own), at stage one's numbers
# and without the director's tier scales.
func _spec_for(kind: String) -> Dictionary:
	var plating := float(combat.warden_spec(1)["plating"])
	var spec := {"rest_scale": 1.0}
	if kind == "miniboss":
		spec["plating"] = float(roundi(Combat.MINIBOSS_PLATING_SCALE * plating))
	if combat.fleet.makes(kind):
		spec["kind"] = kind
		spec["holds"] = combat.fleet.holds
		spec["fleet"] = combat.fleet
		if Fleet.PLATING_SCALE.has(kind):
			spec["plating"] = float(roundi(Fleet.PLATING_SCALE[kind] * plating))
		if kind == "swarm_remnant":
			# A lone drone with a formation of its own: the yard's cap counts bodies.
			spec["swarm"] = Swarm.new(combat.fleet)
	return spec


func _is_live() -> bool:
	return walking and inside and not page_open


# True while the yard's machines fight: on the walk, the ball inside the fence and the call box's page shut.
func fighting() -> bool:
	return _is_live()


# Sends every called enemy home.
func clear() -> void:
	for enemy in live:
		_free(enemy)
	for shell in _shells:
		_free(shell)
	live.clear()
	_shells.clear()
	_slots.clear()
	clears += 1
	if combat != null and combat.fleet != null and combat.fleet.holds != null:
		combat.fleet.holds.clear()
	changed.emit()


func _free(node: Node) -> void:
	if not is_instance_valid(node):
		return
	node.remove_from_group("enemy")
	node.remove_from_group("enemy_shot")
	if node.has_method("set_physics_process"):
		node.set_physics_process(false)
	node.queue_free()


func _forget(enemy: Node3D) -> void:
	var at := live.find(enemy)
	if at >= 0:
		live.remove_at(at)
	for slot in _slots.keys():
		if _slots[slot] == enemy:
			_slots.erase(slot)
	changed.emit()


func _prune() -> void:
	for enemy in live.duplicate():
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or (enemy.has_method("is_dead") and enemy.is_dead()):
			_forget(enemy)
	_shells = _shells.filter(func(shell): return is_instance_valid(shell) and not shell.is_queued_for_deletion())


# The lobber's shell, wired the way combat does it but to this hull.
func _on_fired(origin: Vector3, landing: Vector3, flight: float, lobber: Node3D) -> void:
	var shell := Projectile.new()
	ctx.root.add_child(shell)
	shell.setup(ctx.player, ground, ctx.root, _is_live, origin, landing, flight, lobber)
	shell.hit_player.connect(_on_hit.bind("lobber"))
	shell.returned_landed.connect(combat._on_shell_returned)
	shell.exploded.connect(func(at: Vector3, blast: float, _hit: bool): combat.effects.ring(at, blast, Palette.HAZARD))
	_shells.append(shell)


# --- The ball in the yard ---------------------------------------------------------------------

# An enemy's committed hit. The hull takes it and the ball takes the shove; the run does not.
func _on_hit(amount: float, shove: Vector3, _source: String) -> void:
	if not _is_live():
		return
	hurt(amount)
	ctx.player.crowd_control("knock", shove / get_physics_process_delta_time())


func hurt(amount: float) -> void:
	if amount <= 0.0 or hull <= 0.0:
		return
	hull = maxf(0.0, hull - amount)
	if hull <= 0.0:
		wreck()
	changed.emit()


# The ball is wrecked: back at the entry with a full hull. Nothing is charged.
func wreck() -> void:
	wrecks += 1
	hull = HULL
	if combat != null and combat.fleet != null and combat.fleet.holds != null:
		combat.fleet.holds.clear()
	hub.ball.reset_to(_entry + Vector3.UP * 0.5)
	changed.emit()


func _physics_process(_delta: float) -> void:
	if not walking:
		return
	var was := inside
	_update_inside()
	if was and not inside:
		clear()
		hull = HULL
	if inside and hub.ball.ball_position().y < ground.floor_y - FALL_DEPTH:
		wreck()
	_prune()


func _update_inside() -> void:
	var ball: Vector3 = hub.ball.ball_position()
	inside = Vector2(ball.x - _yard_centre.x, ball.z - _yard_centre.z).length() <= YARD_RADIUS


func _on_walk_entered() -> void:
	walking = true
	hull = HULL
	_update_inside()


func _on_walk_left() -> void:
	walking = false
	inside = false
	_close_page()
	clear()
	hull = HULL


# --- The picker page ---------------------------------------------------------------------------

func _met() -> Array:
	return met_override if met_override != null else _picker().met_of(game)


# The call box was used. Opens the picker through the walk's page entry point when screens
# has one (open_walk_page(page, on_close)), else on a layer of its own.
func open_picker() -> void:
	if page_open or not walking:
		return
	_page = _picker().new()
	_page.kind_chosen.connect(_on_chosen)
	_page.clear_chosen.connect(func():
		clear()
		_refresh())
	_page.closed.connect(_on_page_closed)
	_refresh()
	_via_screens = game.screens != null and game.screens.has_method("open_walk_page")
	if _via_screens:
		game.screens.open_walk_page(_page, _close_page)
		if _page.get_parent() == null:
			# The walk is not live (another page is up): nothing opened.
			_page.free()
			_page = null
			return
		page_open = true
	else:
		page_open = true
		_layer = CanvasLayer.new()
		_layer.layer = 40
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		centre.add_child(_page)
		_layer.add_child(centre)
		game.add_child(_layer)
		ctx.player.set_frozen(true)
		_frozen_here = true
	_page.focus_first()


func _on_page_closed() -> void:
	if _via_screens and game.screens.walk_page() == _page:
		game.screens.close_walk_page()
	else:
		_close_page()


func _on_chosen(kind: String) -> void:
	spawn(kind)
	_refresh()


func _refresh() -> void:
	if is_instance_valid(_page):
		_page.refresh(_met(), live_count(), CAP)


func _close_page() -> void:
	page_open = false
	if _frozen_here:
		ctx.player.set_frozen(false)
		_frozen_here = false
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	if is_instance_valid(_page):
		_page.queue_free()
	_page = null


# The yard's floor as the enemies and their telegraphs read it: flat, at the grate's height.
class YardGround extends RefCounted:
	var floor_y := 0.0

	func height_at(_point: Vector3) -> float:
		return floor_y

	func height(_x: float, _z: float) -> float:
		return floor_y

	func drop_point(x: float, z: float, clearance := 1.8) -> Vector3:
		return Vector3(x, floor_y + clearance, z)
