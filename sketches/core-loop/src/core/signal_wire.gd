class_name SignalWire
extends RefCounted


static func arg_count(obj: Object, signal_name: String) -> int:
	for info in obj.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


static func listen(events: Object, signal_name: String, callable: Callable) -> void:
	if events.has_signal(signal_name) and not events.is_connected(signal_name, callable):
		events.connect(signal_name, callable)


static func listen_until_exit(owner: Node, bus: Signal, callback: Callable) -> void:
	if bus.is_connected(callback):
		return
	bus.connect(callback)
	owner.tree_exiting.connect(func():
		if not bus.is_null() and is_instance_valid(bus.get_object()) and bus.is_connected(callback):
			bus.disconnect(callback), CONNECT_ONE_SHOT)
