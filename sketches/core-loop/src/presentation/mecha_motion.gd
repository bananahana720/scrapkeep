extends RefCounted

# Code moves the mecha; clips move only pilot bones (design-v3/PILOT-CLIPS.md section 5).
# One instance per fitted shell, owned by hero_assets.gd. It drives:
#   - the cockpit controls: a cast throws its slot 2 or 3 control at the clip's contact time,
#     a shot squeezes the yoke trigger, a movement verb kicks both pedals, and the ultimate
#     hauls the lap bar back from ultimate_started to its landing or cancel;
#   - the Cannon's lattice fold for Fire Mission (Core scale);
#   - each pilot's machinery rows from its pose table (src/presentation/clips/<pilot>.json,
#     key "machinery"): one row per node, {node, fact, motion, start}, where fact is one of
#     FACTS and motion one of MOTIONS (the vocabulary below).
# All motion is time-stepped here (step), never tweens, so a test can sample it frame by frame.
# It never creates a node, a light or a material_override (ROSTER-LOOK.md section 8). A node
# the shell lacks prints "SKIP control <name>" once and the rest goes on.

# Control throws (section 5 table, starting values).
const LEVER_DEG := 35.0
const CRANK_DEG := 180.0
const PLUNGER_M := 0.06
const THROW_S := 0.08
const RETURN_S := 0.25
const TRIGGER_DEG := 12.0
const TRIGGER_S := 0.06
const TRIGGER_INTERVAL := 0.12
const PEDAL_DEG := 20.0
const PEDAL_S := 0.06
# Back is a negative pitch about the pod's left-right axis.
const LAP_DEG := -25.0
# The Cannon's Fire Mission fold (pilots/cannon.md section 5): in on ultimate_started, sprung
# back in 0.12 s on the landing or cancel. A base row, not an extra.
const CANNON_CLASS := "remembered_cannon"
const CANNON_FOLD := 0.85
const CANNON_FOLD_S := 0.08
const CANNON_SPRING_S := 0.12
# ROSTER-LOOK section 0.5's shared landing fold is an extra on the veto list: off.
const LANDING_FOLD := false
const LANDING_FOLD_SCALE := 0.92
const LANDING_FOLD_S := 0.25
const CAST_CLIPS := ["cast_special", "cast_line"]
# The slot 2 and 3 controls per class (section 5's table; the shells' BANK names), used when
# the pose table names no contact control.
const CAST_CONTROLS := {
	"pylon_engineer": {"cast_special": "GaugeLever", "cast_line": "SpoolBrake"},
	"runner_gunner": {"cast_special": "Lever", "cast_line": "WinchLever"},
	"demolitions_caster": {"cast_special": "FusePlunger", "cast_line": "ChargeKey"},
	"tarn": {"cast_special": "ClampLever", "cast_line": "DrumLever"},
	"tally": {"cast_special": "CardTab.1", "cast_line": "CardTab.2"},
	"remembered_cannon": {"cast_special": "PlateCrank", "cast_line": "CableClamp"},
}
# How a bank control moves (tools/blender/shell_base.py BANK_KINDS): a crank turns half a turn,
# a plunger, key, tab or button presses down, anything else is a lever.
const CONTROL_KINDS := {"PlateCrank": "crank", "Crank": "crank", "FusePlunger": "plunger", "Plunger": "plunger",
	"ChargeKey": "key", "CardTab.0": "tab", "CardTab.1": "tab", "CardTab.2": "tab"}
const PRESS_KINDS := ["plunger", "key", "tab", "button"]

# The machinery vocabulary (P-UNITS.md "PE common rules"; section 0.4 item 12).
# fact -> what hero_assets passes in step()'s facts:
#   meter_fill       0..1, the ultimate meter
#   selected_slot    the selected slot name; start.slot (2, 3 or a name) picks the match
#   slot_ready       {slot: bool}; start.slot picks
#   pressure         the last pressure_changed value; start.max scales it (default 1)
#   gliding, cloaked bool, the kit's
#   line_load        0..1, 1 while a line skill load waits
#   set_piece_phase  the set piece phase; 1 inside start.phases (default windup and flight)
#   heft_class       1..5, read as 0..1
#   shot_fired       a pulse per shot (pulse())
#   aim              a world direction; only motion "aim" reads it
const FACTS := ["meter_fill", "selected_slot", "slot_ready", "pressure", "gliding", "cloaked", "line_load",
	"set_piece_phase", "heft_class", "shot_fired", "aim"]
# motion -> what the fact's 0..1 value does to the node, from its rest transform (start keys):
#   turn   rotate start.deg about start.axis (x, y or z; default x), eased at start.rate (12)
#   slide  move start.m along start.axis (default y), eased
#   grow   scale toward start.scale, eased
#   show   visible above 0.5
#   spin   turn at start.deg_s times the value about start.axis
#   throw  on a rising edge (or a pulse): out by start.deg (or start.m) in start.throw_s (0.08),
#          back in start.return_s (0.25)
#   aim    yaw toward the aim direction at start.rate
#   param  set_instance_shader_parameter(start.param, value * start.scale): no override
const MOTIONS := ["turn", "slide", "grow", "show", "spin", "throw", "aim", "param"]
const SLOT_NAMES := {1: "weapon", 2: "special", 3: "line"}
const AXIS_INDEX := {"x": 0, "y": 1, "z": 2}
const EASE_RATE := 12.0

# Whether a SKIP line is also printed. The smoke harness counts any output line holding the
# SKIP token as a skipped test, so a test that plants a missing node turns this off and reads
# skip_lines instead. Static, because rows are read (and lines made) in _init.
static var echo := true


static func reset_for_tests() -> void:
	echo = true

var class_id := ""
var skip_lines: Array = []
var _pod: Node3D
var _core: Node3D
var _rows: Array = []
var _nodes := {}
var _rest := {}
# Active pulses by channel key "<node id>:<rot|pos|scale>:<axis>".
var _pulses := {}
var _clock := 0.0
var _last_shot := -INF
var _edges := {}
var _row_last := {}


func _init(pod: Node3D, core: Node3D, pilot_class: String, machinery: Array = []) -> void:
	_pod = pod
	_core = core
	class_id = pilot_class
	for row in machinery:
		if row is Dictionary:
			_add_row(row)


func needs_facts() -> bool:
	return not _rows.is_empty()


# The cast clip's control throw: starts after `contact_seconds` (the pose table's contact frame).
func cast(_clip: String, control: String, contact_seconds: float) -> void:
	var node := _node("Control." + control)
	if node == null:
		return
	var kind: String = CONTROL_KINDS.get(control, "lever")
	if kind in PRESS_KINDS:
		_start(node, "pos", 1, -PLUNGER_M, THROW_S, RETURN_S, contact_seconds)
	elif kind == "crank":
		_start(node, "rot", 0, CRANK_DEG, THROW_S, RETURN_S, contact_seconds)
	else:
		_start(node, "rot", 0, LEVER_DEG, THROW_S, RETURN_S, contact_seconds)


static func cast_control(pilot_class: String, clip: String) -> String:
	return String(CAST_CONTROLS.get(pilot_class, {}).get(clip, ""))


# The weapon's yoke trigger: at most once per TRIGGER_INTERVAL. Returns whether it squeezed.
func shot() -> bool:
	if _clock - _last_shot < TRIGGER_INTERVAL - 1e-6:
		return false
	_last_shot = _clock
	pulse("shot_fired")
	var node := _node("Control.Trigger")
	if node != null:
		_start(node, "rot", 0, TRIGGER_DEG, TRIGGER_S, TRIGGER_S, 0.0)
	return true


# The movement verb on the pedals.
func kick() -> void:
	for pedal in ["Control.Pedal.L", "Control.Pedal.R"]:
		var node := _node(pedal)
		if node != null:
			_start(node, "rot", 0, PEDAL_DEG, PEDAL_S, RETURN_S, 0.0)


func ultimate_started() -> void:
	var lap := _node("Control.LapBar")
	if lap != null:
		_start(lap, "rot", 0, LAP_DEG, THROW_S, RETURN_S, 0.0, true)
	if class_id == CANNON_CLASS and _core_valid():
		_start(_core, "scale", -1, CANNON_FOLD - 1.0, CANNON_FOLD_S, CANNON_SPRING_S, 0.0, true)


func ultimate_ended() -> void:
	var lap := _node("Control.LapBar")
	if lap != null:
		_release(lap, "rot", 0)
	if class_id == CANNON_CLASS and _core_valid():
		_release(_core, "scale", -1)


# The shared landing fold (an extra, LANDING_FOLD off).
func landed() -> void:
	if LANDING_FOLD and _core_valid() and class_id != CANNON_CLASS:
		_start(_core, "scale", -1, LANDING_FOLD_SCALE - 1.0, 0.0, LANDING_FOLD_S, 0.0)


# A fact that arrives as an event (shot_fired): the next step fires its throw rows once.
func pulse(fact: String) -> void:
	_edges[fact] = true


func step(delta: float, facts: Dictionary = {}) -> void:
	if not is_instance_valid(_pod):
		return
	_clock += delta
	for index in _rows.size():
		_step_row(index, delta, facts)
	_edges.clear()
	for key in _pulses.keys():
		var p: Dictionary = _pulses[key]
		if not is_instance_valid(p.node):
			_pulses.erase(key)
			continue
		p.t += delta
		var value := _pulse_value(p)
		_apply(p.node, p.channel, p.axis, value)
		if p.done:
			_pulses.erase(key)


# --- controls --------------------------------------------------------------------------

func _start(node: Node3D, channel: String, axis: int, amount: float, throw_s: float, return_s: float,
		delay: float, held := false) -> void:
	_remember(node)
	var key := "%d:%s:%d" % [node.get_instance_id(), channel, axis]
	_pulses[key] = {"node": node, "channel": channel, "axis": axis, "amount": amount, "throw": throw_s,
		"ret": return_s, "delay": delay, "held": held, "t": 0.0, "done": false}


func _release(node: Node3D, channel: String, axis: int) -> void:
	var key := "%d:%s:%d" % [node.get_instance_id(), channel, axis]
	if not _pulses.has(key):
		return
	var p: Dictionary = _pulses[key]
	var now := _pulse_value(p)
	p.amount = now
	p.delay = 0.0
	p.throw = 0.0
	p.held = false
	p.t = 0.0


func _pulse_value(p: Dictionary) -> float:
	var t: float = p.t - p.delay
	if t <= 0.0 and p.throw > 0.0:
		return 0.0
	if p.throw > 0.0 and t < p.throw:
		return p.amount * t / p.throw
	if p.held:
		return p.amount
	var r: float = t - p.throw
	if p.ret > 0.0 and r < p.ret - 1e-6:
		return p.amount * (1.0 - r / p.ret)
	p.done = true
	return 0.0


func _apply(node: Node3D, channel: String, axis: int, value: float) -> void:
	var rest: Dictionary = _rest[node.get_instance_id()]
	match channel:
		"rot":
			var degrees: Vector3 = rest.rot
			degrees[axis] += value
			node.rotation_degrees = degrees
		"pos":
			var at: Vector3 = rest.pos
			at[axis] += value
			node.position = at
		"scale":
			node.scale = rest.scale * (1.0 + value)


func _remember(node: Node3D) -> void:
	var id := node.get_instance_id()
	if not _rest.has(id):
		_rest[id] = {"rot": node.rotation_degrees, "pos": node.position, "scale": node.scale}


func _core_valid() -> bool:
	return _core != null and is_instance_valid(_core)


# Shell paths win over name search. The loader splits and renames Core/Pod, so their
# declared names also resolve through the references passed at construction.
func _node(node_name: String) -> Node3D:
	if _nodes.has(node_name):
		var cached = _nodes[node_name]
		return cached if cached != null and is_instance_valid(cached) else null
	var found: Node3D = null
	if is_instance_valid(_pod):
		for candidate in [node_name, node_name.replace(".", "_")]:
			if candidate == "Core" and _core_valid():
				found = _core
			elif candidate == "Pod":
				found = _pod
			elif candidate.begins_with("Core/") and _core_valid():
				found = _core.get_node_or_null(candidate.trim_prefix("Core/")) as Node3D
			elif candidate.begins_with("Pod/"):
				found = _pod.get_node_or_null(candidate.trim_prefix("Pod/")) as Node3D
			else:
				var shell_root := _pod.get_parent()
				if shell_root != null:
					found = shell_root.get_node_or_null(candidate) as Node3D
				if found == null:
					found = _pod.get_node_or_null(candidate) as Node3D
				if found == null and _core_valid():
					found = _core.get_node_or_null(candidate) as Node3D
			if found != null:
				break
		if found == null:
			var scopes: Array = [_pod]
			if _core_valid():
				scopes.append(_core)
			if _pod.get_parent() != null:
				for sibling in _pod.get_parent().get_children():
					if sibling != _pod and not sibling in scopes:
						scopes.append(sibling)
			var name_only := node_name.get_file()
			for scope in scopes:
				for candidate in [name_only, name_only.replace(".", "_")]:
					found = scope if String(scope.name) == candidate and scope is Node3D else scope.find_child(candidate, true, false) as Node3D
					if found != null:
						break
				if found != null:
					break
	if found == null:
		_skip("SKIP control " + node_name.trim_prefix("Control."))
	_nodes[node_name] = found
	return found


func _skip(line: String) -> void:
	if line in skip_lines:
		return
	skip_lines.append(line)
	if echo:
		print(line)


# --- machinery rows ---------------------------------------------------------------------

func _add_row(row: Dictionary) -> void:
	var fact := String(row.get("fact", ""))
	var motion := String(row.get("motion", ""))
	var node_name := String(row.get("node", ""))
	if not fact in FACTS or not motion in MOTIONS:
		_skip("SKIP machinery %s: fact '%s' or motion '%s' outside the vocabulary" % [node_name, fact, motion])
		return
	var node := _node(node_name)
	if node == null:
		return
	_remember(node)
	_rows.append({"node": node, "fact": fact, "motion": motion, "start": row.get("start", {})})


func _slot_name(slot) -> String:
	if slot is int or slot is float:
		return String(SLOT_NAMES.get(int(slot), ""))
	return String(slot)


func _fact_value(row: Dictionary, facts: Dictionary) -> float:
	var start: Dictionary = row.start
	match row.fact:
		"meter_fill", "line_load":
			return clampf(float(facts.get(row.fact, 0.0)), 0.0, 1.0)
		"selected_slot":
			return 1.0 if String(facts.get("selected_slot", "")) == _slot_name(start.get("slot", 2)) else 0.0
		"slot_ready":
			return 1.0 if bool(facts.get("slot_ready", {}).get(_slot_name(start.get("slot", 2)), false)) else 0.0
		"pressure":
			return clampf(float(facts.get("pressure", 0.0)) / maxf(float(start.get("max", 1.0)), 0.0001), 0.0, 1.0)
		"gliding", "cloaked":
			return 1.0 if facts.get(row.fact, false) == true else 0.0
		"set_piece_phase":
			return 1.0 if String(facts.get("set_piece_phase", "idle")) in Array(start.get("phases", ["windup", "flight"])) else 0.0
		"heft_class":
			return clampf((float(facts.get("heft_class", 1)) - 1.0) / 4.0, 0.0, 1.0)
		"shot_fired":
			return 1.0 if _edges.get("shot_fired", false) else 0.0
	return 1.0


func _step_row(index: int, delta: float, facts: Dictionary) -> void:
	var row: Dictionary = _rows[index]
	var node: Node3D = row.node
	if not is_instance_valid(node):
		return
	var start: Dictionary = row.start
	var value := _fact_value(row, facts)
	var rest: Dictionary = _rest[node.get_instance_id()]
	var ease := 1.0 - exp(-float(start.get("rate", EASE_RATE)) * delta)
	var axis: int = AXIS_INDEX.get(String(start.get("axis", "y" if row.motion == "slide" else "x")), 0)
	match row.motion:
		"turn":
			var degrees := node.rotation_degrees
			degrees[axis] = lerpf(degrees[axis], rest.rot[axis] + value * float(start.get("deg", 0.0)), ease)
			node.rotation_degrees = degrees
		"slide":
			var at := node.position
			at[axis] = lerpf(at[axis], rest.pos[axis] + value * float(start.get("m", 0.0)), ease)
			node.position = at
		"grow":
			node.scale = node.scale.lerp(rest.scale * lerpf(1.0, float(start.get("scale", 1.0)), value), ease)
		"show":
			node.visible = value >= 0.5
		"spin":
			var degrees := node.rotation_degrees
			degrees[axis] = wrapf(degrees[axis] + value * float(start.get("deg_s", 0.0)) * delta, -180.0, 180.0)
			node.rotation_degrees = degrees
		"throw":
			var last := float(_row_last.get(index, 0.0))
			if value >= 0.5 and last < 0.5:
				var throw_s := float(start.get("throw_s", THROW_S))
				var return_s := float(start.get("return_s", RETURN_S))
				if start.has("m"):
					_start(node, "pos", AXIS_INDEX.get(String(start.get("axis", "y")), 1), float(start.m), throw_s, return_s, 0.0)
				else:
					_start(node, "rot", axis, float(start.get("deg", LEVER_DEG)), throw_s, return_s, 0.0)
		"aim":
			var aim: Vector3 = facts.get("aim", Vector3.ZERO)
			if Vector2(aim.x, aim.z).length_squared() > 0.0001:
				var want := atan2(-aim.x, -aim.z)
				if _pod.is_inside_tree():
					want -= _pod.global_rotation.y
				node.rotation.y = lerp_angle(node.rotation.y, want, ease)
		"param":
			var geometry := node as GeometryInstance3D
			if geometry != null:
				geometry.set_instance_shader_parameter(StringName(start.get("param", "fill")), value * float(start.get("scale", 1.0)))
	_row_last[index] = value
