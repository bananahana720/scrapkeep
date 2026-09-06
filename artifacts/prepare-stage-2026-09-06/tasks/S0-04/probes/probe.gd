extends SceneTree

const Helper: GDScript = preload("probe_helper.gd")


class Counter extends Node:
	var physics_calls: int = 0
	var process_calls: int = 0
	var focus_out: int = 0
	var in_physics_at_timeout: int = -1

	func _physics_process(_delta: float) -> void:
		physics_calls += 1

	func _process(_delta: float) -> void:
		process_calls += 1

	func _notification(what: int) -> void:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			focus_out += 1

	func _on_timeout() -> void:
		in_physics_at_timeout = 1 if Engine.is_in_physics_frame() else 0


var pausable: Counter = Counter.new()
var always: Counter = Counter.new()
var initialized: bool = false


func _initialize() -> void:
	initialized = true
	print("PROBE _initialize called; root valid=%s" % [root != null])
	root.add_child(pausable)
	always.process_mode = Node.PROCESS_MODE_ALWAYS
	root.add_child(always)
	print("PROBE inside_tree=%s" % [pausable.is_inside_tree()])
	print("PROBE user_args=%s" % [OS.get_cmdline_user_args()])
	print("PROBE ticks_per_second=%d" % [Engine.physics_ticks_per_second])
	print("PROBE version=%s" % [Engine.get_version_info()])
	var helper: Helper = Helper.new()
	var frame: Helper.Frame = helper.make()
	print("PROBE typed dict held=%s" % [frame.held])
	print("PROBE focus constant=%d" % [NOTIFICATION_APPLICATION_FOCUS_OUT])
	run()


func run() -> void:
	await physics_frame
	var calls0: int = pausable.physics_calls
	print("PROBE at first physics_frame: physics_calls=%d process_calls=%d" % [calls0, pausable.process_calls])
	for i: int in 10:
		await physics_frame
	print("PROBE after 10 awaits: physics_calls delta=%d process_calls=%d" % [pausable.physics_calls - calls0, pausable.process_calls])
	var timer: SceneTreeTimer = create_timer(0.05)
	timer.timeout.connect(pausable._on_timeout)
	var waited: int = 0
	while pausable.in_physics_at_timeout < 0 and waited < 600:
		await physics_frame
		waited += 1
	print("PROBE timer fired after %d frames; in_physics=%d" % [waited, pausable.in_physics_at_timeout])
	paused = true
	var frozen: int = pausable.physics_calls
	var always0: int = always.process_calls
	var ap0: int = always.physics_calls
	var frames: int = 0
	for i: int in 10:
		await physics_frame
		frames += 1
	print("PROBE paused: signal frames=%d pausable delta=%d always process delta=%d always physics delta=%d" % [frames, pausable.physics_calls - frozen, always.process_calls - always0, always.physics_calls - ap0])
	paused = false
	root.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	print("PROBE focus_out via propagate=%d" % [pausable.focus_out])
	pausable.propagate_notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	print("PROBE focus_out via self propagate=%d" % [pausable.focus_out])
	await physics_frame
	print("PROBE quitting with 3")
	quit(3)
