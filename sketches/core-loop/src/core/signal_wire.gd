class_name SignalWire
extends RefCounted

# Signal plumbing shared by the presentation and HUD listeners: how many arguments a
# signal carries, and a connect that is safe to repeat.


# The argument count a signal declares, or 0 when the object has no such signal.
static func arg_count(obj: Object, signal_name: String) -> int:
	for info in obj.get_signal_list():
		if info["name"] == signal_name:
			return (info["args"] as Array).size()
	return 0


# Connects once, and only when the object has the signal.
static func listen(events: Object, signal_name: String, callable: Callable) -> void:
	if events.has_signal(signal_name) and not events.is_connected(signal_name, callable):
		events.connect(signal_name, callable)
