class_name WyncPktSnap


## NOTE: Build an optimized packet format exclusive for positional data

class SnapProp:
	var prop_id: int
	var state_size: int
	var state#: Variant: Vector2, Quaternion, float, struct

	func duplicate () -> SnapProp:
		var i = SnapProp.new()
		i.prop_id = self.prop_id
		i.state_size = self.state_size
		i.state = self.state
		return i


var tick: int
var snaps: Array[SnapProp]


func duplicate() -> WyncPktSnap:
	var i = WyncPktSnap.new()
	i.tick = self.tick
		
	for prop in self.snaps:
		var new_prop = SnapProp.new()
		new_prop.prop_id = prop.prop_id
		new_prop.state_size = prop.state_size
		new_prop.state = prop.state
		i.snaps.append(prop)
			
	return i

"""
Preliminar packet structure (three packet types?)
ExtractedInputs {
	var size: int, # sizeof(int) * amount
	var prop_id: int,
	var tick_head: int,
	var amount: int
	var inputs: Array[int] (amount)
}
ExtractedEventsData {
	var size: int,
	var event_amount: int,
	var event_buffer: Array[EventData],
}
ExtractedEventsData__Event {
	var event_id: int,
	var event_type_id: int,
	var arg_count: int,
	var arg_data_type: Array[int],
	var arg_buffer: Array[Variant],
}
ExtractedState {
	var size: int, # = prop_id + state_size
	var tick: int,
	var prop_id: int,
	var state_size: int,
	var state: Variant,
}
"""

"""
Packets to send
OutInputs {
	amount: int,
	inputs [
		{
			var prop_id: int
			var tick_head: int
			var amount: int
			var inputs: Array[int] (amount)
		}
	]
}
"""
