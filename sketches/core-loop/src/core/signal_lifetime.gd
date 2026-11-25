extends RefCounted

static func listen(owner: Node, bus: Signal, callback: Callable) -> void:
	if bus.is_connected(callback):
		return
	bus.connect(callback)
	owner.tree_exiting.connect(func():
		if not bus.is_null() and is_instance_valid(bus.get_object()) and bus.is_connected(callback):
			bus.disconnect(callback), CONNECT_ONE_SHOT)
