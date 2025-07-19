class_name NetTickData

var server_tick: int
var arrived_at_tick: int ## local tick
var data#: Any


func copy() -> NetTickData:
	var new_instance = NetTickData.new()
	new_instance.server_tick = server_tick
	new_instance.arrived_at_tick = arrived_at_tick
	new_instance.data = data
	if data is Object && data.has_method("copy"):
		new_instance.data = data.copy()
	return new_instance
