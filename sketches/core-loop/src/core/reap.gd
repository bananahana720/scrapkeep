extends Node

# A clear's leftovers are deleted a few a frame instead of all in the frame that let them go:
# activities.clear() runs on every stage change, a lap and the arena entry, where the flume's
# sites were about half of its 12-20 ms of delete queue on the entry frame on the cloud. free_later() hides and disables the node and
# takes it and everything under it out of their groups at once, so it stops processing, its
# bodies leave the space and no group query finds it; taking it out of the tree here would cost
# the same exit notifications the delete did. A hidden, disabled node still hears any signal it
# is connected to, so only nodes that answer nothing belong here (not enemies). One Reap node
# under the tree's root deletes them oldest first within a budget a frame, from the next frame
# on, and whatever is left when the tree goes.

const BUDGET_USEC := 2000

var _queue := []
static var _current: Node


static func free_later(node: Node) -> void:
	if not is_instance_valid(node) or node.is_queued_for_deletion():
		return
	if not node.is_inside_tree():
		node.queue_free()
		return
	if node is Node3D or node is CanvasItem:
		node.visible = false
	node.process_mode = Node.PROCESS_MODE_DISABLED
	_leave_groups(node)
	if not is_instance_valid(_current):
		_current = new()
		_current.name = "Reap"
		_current.process_mode = Node.PROCESS_MODE_ALWAYS
		node.get_tree().root.add_child.call_deferred(_current)
	_current._queue.append([node, Engine.get_process_frames()])


static func _leave_groups(node: Node) -> void:
	for group in node.get_groups():
		if not String(group).begins_with("_"):
			node.remove_from_group(group)
	for child in node.get_children():
		_leave_groups(child)


func pending() -> int:
	return _queue.size()


func _process(_delta: float) -> void:
	var deadline := Time.get_ticks_usec() + BUDGET_USEC
	var now := Engine.get_process_frames()
	# The frame that let a node go has paid for the clear already; its leftovers start on the next.
	while not _queue.is_empty() and _queue[0][1] < now and Time.get_ticks_usec() < deadline:
		_delete(_queue.pop_front()[0])


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for held in _queue:
			_delete(held[0])
		_queue.clear()


# A queued node can go first with its parent (a site's pack), so it is checked before it is typed.
static func _delete(held) -> void:
	if is_instance_valid(held) and not held.is_queued_for_deletion():
		(held as Node).free()
