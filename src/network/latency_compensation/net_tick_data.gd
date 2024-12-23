class_name NetTickData

var tick: int
var timestamp: float # TODO rename to timestamp_arrived
var data#: Any


func copy() -> NetTickData:
	var new_instance = NetTickData.new()
	new_instance.tick = tick
	new_instance.timestamp = timestamp
	new_instance.data = data
	if data is Object && data.has_method("copy"):
		new_instance.data = data.copy()
	return new_instance
