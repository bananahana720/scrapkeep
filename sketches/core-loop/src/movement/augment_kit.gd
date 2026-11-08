extends RefCounted

const Augments := preload("res://src/movement/augments.gd")
const AbilityState := preload("res://src/core/ability_state.gd")
const UpgradeTree := preload("res://src/core/upgrade_tree.gd")

# Which augments are fitted, and the live state of the ones that have any. A class fits
# only its movement ability's kit (its row's `augments`) plus the shared smash; a kit with
# no class is the engineer's. The ability state holds every slot's charges and gauge, and
# the tree the run's upgrade picks, whose knobs the movement rules read.
var enabled := {}
var movement_id := ""
var smash_id := ""
# The smash row's landing flavour: arc, skid or demo.
var smash_flavour := ""
var abilities = AbilityState.new()
var tree = UpgradeTree.new()
# Set by combat while Kest's dust cloak is up.
var cloaked := false

var hooked := false
var anchor := Vector3.ZERO
var anchor_normal := Vector3.ZERO
var rope := 0.0
var aim := Augments.no_aim()

# The harpoon's line record, on top of the grapple's fields above (one rope, in
# Augments._grapple). on_body says the line is bitten into anchor_body, an enemy, and
# anchor then follows it at anchor_offset; a freed body reads as null, so the flag is
# its own. smash_left is the seconds a committed haul may still run and smash_floor the speed
# it never drops below. winching is Ctrl held on a world line. line_end says how the line last
# ended: "let_go" for the player's own release, "landed" for a smash, else the cause that cut
# it. lock_body is the soft-lock's sticky pick; rewind_left the seconds the hook is spent
# after a line smash.
var on_body := false
var anchor_body: Node3D = null
var anchor_offset := Vector3.ZERO
var line_state := Augments.LINE_IDLE
var winching := false
# The body a right-mouse reel last hauled toward, and how long that reel still counts: the
# ball's contact lets the line go before its strike resolves, so the dunk (combat._dunk_bonus)
# reads this short grace instead of the live line. Survives drop_line on purpose.
var reel_body: Node3D = null
var reel_left := 0.0
var line_end := ""
var smash_left := 0.0
var smash_floor := 0.0
var line_closing := 0.0
var lock_body: Node3D = null
# The grip the standing body line took at its bite: pole, reel or flail (grip.gd); "" on a world line.
var grip := ""
# Seconds the standing pole line has been ridden (augments.gd _ride_pole).
var pole_time := 0.0
var rewind_left := 0.0

var gliding := false

var slamming := false
var slam_fall := 0.0
var slam_velocity := Vector3.ZERO
var slam_landed := 0.0
var slam_flat := 0.0
# True while Ctrl is held from a press that began on the ground (or before a reset).
var brake_from_ground := false

var plant_time := 0.0
var plant_total := 0.0
var plant_at := Vector3.ZERO
var plant_normal := Vector3.UP
var plant_exit := Vector3.ZERO
var plant_jump := false
var plant_boost := false

var mounted := false
var mount_point := Vector3.ZERO
var mount_face := Vector3.ZERO
var mount_normal := Vector3.ZERO
var mount_block := 0.0
var mount_planted := false
# The speed the ball arrived with when it planted: combat reads it as turret charge.
var mount_banked := 0.0
var dismount_fired := false
var dismount_velocity := Vector3.ZERO
var slingshot = AbilityState.Gauge.new(Augments.SLINGSHOT_CHARGE)
# The slingshot's aim cone while mounted: {dir, speed, fill}.
var slingshot_aim := {}

# Sable's vault: face key -> seconds it stays locked, the last face kicked, and the aim
# cone's record while a kick is available ({} when none is).
var vault_faces := {}
var last_vault_face := ""
var vault_aim := {}

# Mass-S: whether the run's picks grant the mass launch verb under --world-one-builds, its
# q, and the seconds until the one shared bonus grant is available again. player_ball sets
# the first two each tick; nothing here touches steering, friction or the collider.
var mass_on := false
var mass_q := 0.0
var mass_gap := 0.0

var sprinting := false
var sprint_left := 0.0

# Facts the static rules leave for the ball to publish: [signal name, [args]].
var facts: Array = []


func _init() -> void:
	fit(Augments.DEFAULT_MOVEMENT, "")


func fit(movement: String, smash: String) -> void:
	movement_id = movement
	smash_id = smash
	smash_flavour = AbilityState.ABILITIES.get(smash, {}).get("flavour", "")
	var keys: Array = AbilityState.ABILITIES.get(movement, {}).get("augments", []) + Augments.SHARED
	keys = keys + [Augments.GRAPPLE]
	for spec in Augments.SPECS:
		set_on(spec["key"], spec["key"] in keys)


func knob(name: String):
	return tree.knob(name)


func on(key: String) -> bool:
	return enabled.get(key, false)


func set_on(key: String, value: bool) -> void:
	enabled[key] = value
	if not value:
		_stop(key)


func toggle(key: String) -> bool:
	set_on(key, not on(key))
	return enabled[key]


func tick_timers(delta: float) -> void:
	mount_block = maxf(0.0, mount_block - delta)
	reel_left = maxf(0.0, reel_left - delta)
	if reel_left <= 0.0:
		reel_body = null
	rewind_left = maxf(0.0, rewind_left - delta)
	mass_gap = maxf(0.0, mass_gap - delta)
	for key in vault_faces.keys():
		vault_faces[key] -= delta
		if vault_faces[key] <= 0.0:
			vault_faces.erase(key)


# The stomp and rebound refresh gives Sable back the last face it kicked.
func refresh_vault() -> void:
	vault_faces.erase(last_vault_face)


# A mode switch or respawn must never leave the ball pinned somewhere it no longer is.
func release_holds() -> void:
	plant_time = 0.0
	mounted = false
	mount_planted = false
	dismount_fired = false
	slingshot.cancel()


# The line ends and the ball keeps whatever velocity it has. `end` is recorded for the
# ball to publish, and only for a line that stood.
func drop_line(end := "let_go") -> void:
	if hooked:
		line_end = end
	hooked = false
	on_body = false
	anchor_body = null
	grip = ""
	pole_time = 0.0
	line_state = Augments.LINE_IDLE
	winching = false
	smash_left = 0.0
	smash_floor = 0.0
	line_closing = 0.0


func clear_runtime() -> void:
	for spec in Augments.SPECS:
		_stop(spec["key"])
	release_holds()
	slam_landed = 0.0
	# A brake still held across a reset or retry counts as held from the ground.
	brake_from_ground = true
	mount_block = 0.0
	mount_banked = 0.0
	vault_faces.clear()
	reel_body = null
	reel_left = 0.0
	mass_gap = 0.0
	last_vault_face = ""
	vault_aim = {}
	slingshot_aim = {}
	lock_body = null
	rewind_left = 0.0
	facts.clear()


func _stop(key: String) -> void:
	match key:
		Augments.GRAPPLE:
			drop_line("reset")
			aim = Augments.no_aim()
		Augments.GLIDE:
			gliding = false
		Augments.SLAM:
			slamming = false
			slam_fall = 0.0
			plant_time = 0.0
		Augments.PYLON:
			mounted = false
			slingshot.cancel()
		Augments.SPRINT:
			sprinting = false
			sprint_left = 0.0
			abilities.slot(AbilityState.MOVEMENT).active = false
		Augments.VAULT:
			vault_aim = {}
