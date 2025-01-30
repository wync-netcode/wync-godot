class_name WyncEvent

# NOTE: Do not confuse with WyncPktEventData.EventData
# TODO: define data types somewhere + merge with WyncEntityProp

class EventData:
	var event_type_id: int
	var arg_count: int
	var arg_data_type: Array[int] 
	var arg_data: Array[Variant]

# data
var data: EventData

# metadata
var prop_id: int = -1


func _init() -> void:
	data = EventData.new()
