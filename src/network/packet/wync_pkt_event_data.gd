class_name WyncPktEventData

# NOTE: EventData is different from WyncEvent in that this one is sent
# over the network, so it has an extra property: event_id: int
class EventData:
	var event_id: int
	var event_type_id: int
	var event_data: Variant
	
	func duplicate() -> EventData:
		var newi = EventData.new()
		newi.event_id = event_id
		newi.event_type_id = event_type_id
		newi.event_data = WyncUtils.duplicate_any(event_data)
		return newi


var events: Array[EventData]


func duplicate() -> WyncPktEventData:
	var newi = WyncPktEventData.new()
	newi.events = [] as Array[EventData]
	for event in self.events:
		newi.events.append(event.duplicate())
	return newi
