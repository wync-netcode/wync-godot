class_name WyncPktEventData

"""
events: Array[EventData] [
	{
		event_id: int,
		arg_count: int,
		arg_data_type: Array[int] [
			INT,
			VECTOR2
		],
		arg_data: Array[any] [
			110,
			(12, 13)
		]
	}
]
"""

# NOTE: EventData is different from WyncEvent in that this one is sent
# over the network, so it has an extra property: event_id: int
class EventData:
	var event_id: int
	var event_type_id: int
	var arg_count: int
	var arg_data_type: Array[int]
	var arg_data: Array # : Array[any]
	
	func duplicate() -> EventData:
		var newi = EventData.new()
		newi.event_id = event_id
		newi.event_type_id = event_type_id
		newi.arg_count = arg_count
		newi.arg_data_type = arg_data_type.duplicate(true)
		# WARNING: Only godot types will be duplicated
		newi.arg_data = arg_data.duplicate(true)
		return newi

var events: Array[EventData]


func duplicate() -> WyncPktEventData:
	var newi = WyncPktEventData.new()
	newi.events = [] as Array[EventData]
	for event in events:
		newi.events.append(event.duplicate())
	return newi
