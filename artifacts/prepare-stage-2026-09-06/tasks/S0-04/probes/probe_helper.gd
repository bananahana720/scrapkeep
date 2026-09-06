extends RefCounted


class Frame extends RefCounted:
	var held: Dictionary[String, bool] = {}


func make() -> Frame:
	var frame: Frame = Frame.new()
	frame.held["cast"] = true
	return frame
