extends SceneTree

const Director := preload("res://src/world/event_director.gd")
const ParkMap := preload("res://src/world/park/park_map.gd")
const T := preload("res://tests/support/t.gd")
const KINDS := ["flood_fill", "drain", "cave_in", "collapse", "impact", "flash_flood", "lightning"]
const FORMS := ["flood_rising", "flood_rising", "cave_in_crumble", "cave_in_crumble", "impact_incoming", "flood_rising", "lightning_charge"]
const FAR := Vector3(100, 1, 100)

class Player:
	extends RefCounted
	var state := {"velocity": Vector3(17, -2, 9), "grounded": true}
	func set_velocity_now(v: Vector3, _cause := "") -> void:
		state.velocity = v

class Run:
	extends RefCounted
	var mass := 20
	func lose_scrap(amount: int, _at: Vector3, _cause: String) -> int:
		var lost := mini(amount, mass)
		mass -= lost
		return lost

class Context:
	extends RefCounted
	var player := Player.new()
	var run := Run.new()
	var root: Node3D

class Terrain:
	extends RefCounted
	var maps: Array = []
	var stage := 1
	var flood = null
	var overlays: Array[String] = []
	func map():
		return maps[stage - 1]
	func height(x: float, z: float) -> float:
		var h := 0.0
		for id in overlays:
			h = maxf(h, map().overlay_height(id, x, z, 0.0))
		return h

class World:
	extends Node3D
	var ctx := Context.new()
	var terrain := Terrain.new()
	var events
	var flood = null
	var terrain_view = null

var t := T.new("park_natural_test")


func _initialize() -> void:
	_run.call_deferred()


func _row(kind: String, form: String) -> Dictionary:
	var water := kind in ["flood_fill", "drain", "flash_flood"]
	var effect := {"depth_m": 9.0, "fill_s": 2.0, "material": "water"} if water else {"swap": "rubble_ramp", "strike_m": 6.0, "damage": 8.0}
	if kind == "lightning":
		effect.erase("swap")
	return {"id": kind, "kind": kind, "family": "natural", "site": "site",
		"trigger": {"on": "clock_tier", "value": 1}, "weight": 1.0,
		"telegraph": {"lead_s": 5.0, "form": form, "on_bar": false},
		"live_s": 8.0, "effect": effect, "route_change": {"closes": [], "opens": []},
		"hold_clear_m": 1.0, "cooldown_s": 10.0, "once": true,
		"music_cue": {"telegraph": "riser_natural", "land": "drop_natural"}}


func _fixture(row: Dictionary) -> Array:
	var w := World.new()
	root.add_child(w)
	w.ctx.root = w
	var map := ParkMap.new()
	map.park = {"map": "fixture", "park_rows": [{"id": "site", "at": [0, 0], "y": 0,
		"size": [20, 2, 10], "yaw_deg": 30}], "event_rows": [row], "weather_rows": [],
		"routes": [{"id": "main", "from": "drop_in", "to": "landmark"}]}
	w.terrain.maps = [map]
	w.events = Director.new(823, {}, map, 14.0, Callable(w.terrain, "height"))
	var script: Script = load("res://src/world/events/natural.gd")
	var handler = script.new()
	w.add_child(handler)
	handler.setup(w)
	w.events.register_family("natural", Callable(handler, "handle"))
	return [w, handler]


func _run() -> void:
	if not t.check("natural family exists", FileAccess.file_exists("res://src/world/events/natural.gd")):
		quit(t.verdict())
		return
	for k in KINDS.size():
		var kind: String = KINDS[k]
		var row := _row(kind, FORMS[k])
		var fixture := _fixture(row)
		var w = fixture[0]
		var handler = fixture[1]
		var facts := []
		for i in 52:
			facts.append_array(w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}))
		t.eq(kind + " one telegraph", facts.filter(func(f): return f.kind == "announced").size(), 1)
		t.eq(kind + " one landing", facts.filter(func(f): return f.kind == "started").size(), 1)
		var state: Dictionary = handler.active.get(kind, {})
		t.check(kind + " persistent warning and feedback", state.has("mark") and is_instance_valid(state.get("mark")))
		if kind in ["flood_fill", "drain", "flash_flood"]:
			for i in 25:
				w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true})
			var depth: float = float(state.get("depth_m", -INF))
			t.near(kind + " committed water depth", depth, 0.0 if kind == "drain" else 1.2)
			t.check(kind + " uses Flood rendering", state.get("water") != null)
			if state.get("water") != null:
				t.near(kind + " rendered surface agrees", state.water.surface_y(), depth)
				t.eq(kind + " water never brakes", state.water.external_accel(Vector3.ZERO, Vector3(17, 0, 9)), Vector3.ZERO)
		elif kind != "lightning":
			t.check(kind + " uses live terrain overlay", w.terrain.overlays.has("rubble_ramp_after") and w.terrain.height(0, 0) > 0.0, str(w.terrain.overlays))
			t.check(kind + " prebuilt collider lands", state.get("overlay") != null and state.overlay.visible)
		if kind in ["impact", "lightning"]:
			var before: Vector3 = w.ctx.player.state.velocity
			w.events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1, "grounded": true})
			t.eq(kind + " costs scrap armour", w.ctx.run.mass, 12)
			t.eq(kind + " never slows planar velocity", Vector2(w.ctx.player.state.velocity.x, w.ctx.player.state.velocity.z), Vector2(before.x, before.z))
			w.events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1, "grounded": true})
			t.eq(kind + " one hit per landing", w.ctx.run.mass, 12)
			# A separate event with no armour must lift vertically instead.
			var empty := _fixture(row)
			empty[0].ctx.run.mass = 0
			for i in 53:
				empty[0].events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1})
			empty[0].events.advance(0.1, Vector3(0, 1, 0), before, {"clock_tier": 1})
			t.check(kind + " lifts without armour", empty[0].ctx.player.state.velocity.y > before.y)
			t.eq(kind + " lift keeps planar speed", Vector2(empty[0].ctx.player.state.velocity.x, empty[0].ctx.player.state.velocity.z), Vector2(before.x, before.z))
			empty[1].release()
			empty[0].free()
		for i in 90:
			facts.append_array(w.events.advance(0.1, FAR, Vector3.ZERO, {"clock_tier": 1, "grounded": true}))
		t.eq(kind + " one end", facts.filter(func(f): return f.kind == "ended").size(), 1)
		t.check(kind + " end removes effects", handler.active.is_empty() and w.terrain.overlays.is_empty())
		handler.release()
		w.free()
	t.check("all seven kinds tested", t.checks >= 50, str(t.checks))
	quit(t.verdict())
