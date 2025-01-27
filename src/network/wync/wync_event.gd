class_name WyncEvent

# NOTE: Do not confuse with WyncPktEventData.EventData
# TODO: define data types somewhere + merge with WyncEntityProp

var event_type_id: int
var arg_count: int
var arg_data_type: Array[int] 
var arg_data: Array[Variant]
