class_name NetTickData

var tick: int
var timestamp: float
var data#: Any


func copy() -> NetTickData:
	var new_instance = NetTickData.new()
	new_instance.tick = tick
	new_instance.timestamp = timestamp
	new_instance.data = data.copy()
	# TODO: Proper data duplication
	# if (data as Node).has_method(""
	return new_instance
