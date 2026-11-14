extends RefCounted

# The ball meets the park's dressing (thread "Make collisions feel physical", 13 Nov 2026). A park
# prop has no body (park_props.gd: nothing there collides or moves a run), so without this the ball
# rolled through barrels, drums and scrub as if they were not there. Now a ball that runs into a
# prop at KICK_SPEED or more moves it, presentation only, by the prop's build:
#   fly    a light prop (FLY_HEIGHT_M or lower) is thrown ahead of the ball, tumbles, bounces and
#          comes to rest on its side where it lands
#   shove  a heavier one slides a little along the push and rocks on its base
#   bend   a plant or a soft thing (tags "plant", "soft") bends away and springs back
# Heroes and tall props stand: they are landmarks. Each prop's drawn copies (its LOD batches, its
# litter batch) take the same transform, so the near and middle views agree; the far merge keeps
# the old spot, beyond PROP_RANGES[1]. The run never reads any of this: the ball keeps its speed.
#
# index() reads the stage's batches once; step() runs the moves and returns the kicks this frame,
# [{at, mode, speed, tags}] for sound and dust.

const KICK_SPEED := 4.0
const FLY_HEIGHT_M := 1.8
const GRAVITY := 26.0
const CELL_M := 6.0
const LIVE_CAP := 24
# A fly throw: the share of the ball's speed it takes, the lift, the bounce and the rest it ends in.
const FLY_CARRY := 0.75
const FLY_LIFT := 3.0
const FLY_LIFT_PER_SPEED := 0.22
const FLY_BOUNCE := 0.3
const FLY_SKID := 0.55
const FLY_REST_SPEED := 1.2
const FLY_MAX_S := 3.0
# A shove: how far it slides per m/s of the ball, and the rock it settles from.
const SHOVE_PER_SPEED := 0.07
const SHOVE_MAX_M := 1.4
const SHOVE_S := 1.1
const BEND_S := 0.9

var _props: Array = []
var _grid := {}
var _live := {}
var _rng := RandomNumberGenerator.new()
var indexed := false
var kicks := 0


func clear() -> void:
	_props.clear()
	_grid.clear()
	_live.clear()
	indexed = false


func live_count() -> int:
	return _live.size()


static func mode_of(inst: Dictionary) -> String:
	var tags: Array = inst.get("tags", [])
	if "plant" in tags or "soft" in tags:
		return "bend"
	return "fly" if float(inst["height"]) <= FLY_HEIGHT_M else "shove"


# A prop's drawn transform, as park_props.gd _transform places it.
static func place_of(inst: Dictionary) -> Transform3D:
	return Transform3D((inst["basis"] as Basis).scaled_local(Vector3.ONE * float(inst["scale"])), inst["pos"])


static func _key(at: Vector3) -> Vector3i:
	return Vector3i(roundi(at.x * 100.0), roundi(at.y * 100.0), roundi(at.z * 100.0))


static func _cell(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / CELL_M), floori(z / CELL_M))


# instances: the stage's instance list; eligible: Callable(inst) -> bool; views: the stage's batches, each carrying
# meta "dress_members" (park_props.gd _batch: instance i of the batch is members[i]).
func index(instances: Array, eligible: Callable, views: Array) -> void:
	clear()
	var by_key := {}
	for inst: Dictionary in instances:
		if not eligible.call(inst):
			continue
		var id := _props.size()
		_props.append({"inst": inst, "slots": [], "base": place_of(inst), "mode": mode_of(inst), "tags": inst.get("tags", []),
			"height": float(inst["height"]), "reach": clampf(float(inst["height"]) * 0.4, 0.35, 1.0)})
		by_key[_key(inst["pos"])] = id
	for view in views:
		if not view is MultiMeshInstance3D or not view.has_meta("dress_members") or view.multimesh == null:
			continue
		var members: Array = view.get_meta("dress_members")
		for i in members.size():
			var id = by_key.get(_key(members[i]["pos"]))
			if id != null:
				_props[id]["slots"].append([view.multimesh, i])
	for id in _props.size():
		if _props[id]["slots"].is_empty():
			continue
		var at: Vector3 = _props[id]["base"].origin
		var cell := _cell(at.x, at.z)
		if not _grid.has(cell):
			_grid[cell] = []
		_grid[cell].append(id)
	_rng.seed = hash(instances.size())
	indexed = true


# One frame: starts the kicks the ball makes at `ball_at` moving `velocity` (radius `radius`), runs
# every live move on `height` (x, z) -> ground y, and returns this frame's kicks.
func step(delta: float, ball_at: Vector3, velocity: Vector3, radius: float, height: Callable) -> Array:
	var out := []
	var flat := Vector3(velocity.x, 0.0, velocity.z)
	var speed := flat.length()
	if speed >= KICK_SPEED and _live.size() < LIVE_CAP:
		var home := _cell(ball_at.x, ball_at.z)
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for id: int in _grid.get(home + Vector2i(dx, dz), []):
					if _live.has(id) or _live.size() >= LIVE_CAP:
						continue
					var prop: Dictionary = _props[id]
					var at: Vector3 = prop["base"].origin
					var gap := Vector2(ball_at.x - at.x, ball_at.z - at.z).length()
					if gap > radius + float(prop["reach"]) or ball_at.y - radius > at.y + float(prop["height"]):
						continue
					_start(id, flat, speed)
					kicks += 1
					out.append({"at": at + Vector3.UP * minf(float(prop["height"]) * 0.5, 1.0), "mode": prop["mode"], "speed": speed, "tags": prop["tags"]})
	for id in _live.keys():
		if _run(id, delta, height):
			_live.erase(id)
	return out


func _start(id: int, flat: Vector3, speed: float) -> void:
	var prop: Dictionary = _props[id]
	var push := flat / speed
	var axis := Vector3.UP.cross(push).normalized()
	var move := {"t": 0.0, "push": push, "axis": axis, "speed": speed, "from": prop["base"]}
	match String(prop["mode"]):
		"fly":
			var side := _rng.randf_range(-0.35, 0.35)
			move["v"] = (push + axis * side) * speed * FLY_CARRY + Vector3.UP * (FLY_LIFT + FLY_LIFT_PER_SPEED * speed)
			move["p"] = prop["base"].origin
			move["angle"] = 0.0
			move["spin"] = _rng.randf_range(7.0, 13.0) * (1.0 if _rng.randf() < 0.75 else -1.0)
		"shove":
			move["slide"] = minf(speed * SHOVE_PER_SPEED, SHOVE_MAX_M)
			move["rock"] = deg_to_rad(clampf(speed * 1.2, 6.0, 20.0))
		"bend":
			move["rock"] = deg_to_rad(clampf(speed * 2.5, 15.0, 55.0))
	_live[id] = move


# Advances one move; true once it has come to rest (its last transform is the prop's new base).
func _run(id: int, delta: float, height: Callable) -> bool:
	var prop: Dictionary = _props[id]
	var move: Dictionary = _live[id]
	move["t"] = float(move["t"]) + delta
	var t: float = move["t"]
	var from: Transform3D = move["from"]
	var axis: Vector3 = move["axis"]
	var xf := from
	var done := false
	match String(prop["mode"]):
		"fly":
			var v: Vector3 = move["v"]
			var p: Vector3 = move["p"]
			v.y -= GRAVITY * delta
			p += v * delta
			var ground: float = height.call(p.x, p.z)
			var lie := minf(float(prop["reach"]), float(prop["height"]) * 0.3)
			if p.y <= ground + lie * 0.5 and v.y < 0.0:
				p.y = ground + lie * 0.5
				v = Vector3(v.x * FLY_SKID, -v.y * FLY_BOUNCE, v.z * FLY_SKID)
				move["spin"] = float(move["spin"]) * FLY_SKID
				if v.length() < FLY_REST_SPEED:
					done = true
			move["angle"] = float(move["angle"]) + float(move["spin"]) * delta
			if done or t >= FLY_MAX_S:
				# At rest it lies on its side, turned the way its tumble left it.
				var side := PI * 0.5 * (1.0 if fposmod(float(move["angle"]), TAU) < PI else -1.0)
				xf = Transform3D(Basis(axis, side) * from.basis, Vector3(p.x, ground + lie, p.z))
				done = true
			else:
				xf = Transform3D(Basis(axis, float(move["angle"])) * from.basis, p)
			move["v"] = v
			move["p"] = p
		"shove":
			var ease := 1.0 - pow(1.0 - minf(t / 0.3, 1.0), 3.0)
			var at := from.origin + (move["push"] as Vector3) * float(move["slide"]) * ease
			at.y = height.call(at.x, at.z) + (from.origin.y - height.call(from.origin.x, from.origin.z))
			var rock := float(move["rock"]) * exp(-t * 4.0) * sin(t * 18.0)
			xf = Transform3D(Basis(axis, rock) * from.basis, at)
			done = t >= SHOVE_S
			if done:
				xf = Transform3D(from.basis, at)
		"bend":
			var bend := float(move["rock"]) * exp(-t * 5.0) * cos(t * 12.0)
			xf = Transform3D(Basis(axis, bend) * from.basis, from.origin)
			done = t >= BEND_S
			if done:
				xf = from
	_place(id, xf)
	if done:
		_settle(id, xf)
	return done


func _place(id: int, xf: Transform3D) -> void:
	for slot: Array in _props[id]["slots"]:
		(slot[0] as MultiMesh).set_instance_transform(int(slot[1]), xf)


# A prop at rest stays where it came to rest and can be kicked again from there.
func _settle(id: int, xf: Transform3D) -> void:
	var prop: Dictionary = _props[id]
	var old: Vector3 = prop["base"].origin
	prop["base"] = xf
	var was := _cell(old.x, old.z)
	var now := _cell(xf.origin.x, xf.origin.z)
	if was != now:
		(_grid[was] as Array).erase(id)
		if not _grid.has(now):
			_grid[now] = []
		_grid[now].append(id)


# The current transform of every indexed prop, for tests.
func base_of(id: int) -> Transform3D:
	return _props[id]["base"]


func count() -> int:
	return _props.size()
