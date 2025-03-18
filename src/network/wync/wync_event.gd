class_name WyncEvent


var data: EventData
var data_hash: int # used to avoid sending duplicates


func _init() -> void:
	data = EventData.new()


# NOTE: Do not confuse with WyncPktEventData.EventData
# TODO: define data types somewhere + merge with WyncEntityProp

class EventData:
	var event_type_id: int
	var event_data: Variant
	# var event_size?: int # first compare size before comparing data

	func duplicate() -> EventData:
		var newi = EventData.new()
		newi.event_type_id = event_type_id
		newi.event_data = WyncUtils.duplicate_any(event_data)
		return newi
