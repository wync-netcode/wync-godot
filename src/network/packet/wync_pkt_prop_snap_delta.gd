class_name WyncPktPropSnapDelta

## This Packet ONLY contains the event_id's for the delta changes,
## The actual event_data must be synced just like any other event_data
## See SyWyncSendEventData
"""
{
	props: Array[PropSnap]: [
		[0]: PropSnap: {
			prop_id: int,
			delta_event_tick: Array[int],
			delta_event_id: Array[int],
		}
	]
}
"""


class PropSnap:
	var prop_id: int
	var delta_event_tick_list: Array[int]
	var delta_event_id_list: Array[Array] #: Array[Array[int]]

var snaps: Array[PropSnap] = []


func duplicate() -> WyncPktPropSnapDelta:
	var i = WyncPktPropSnapDelta.new()
	
	for snap: PropSnap in snaps:
		var new_snap = PropSnap.new()
		new_snap.prop_id = snap.prop_id
		new_snap.delta_event_tick_list = snap.delta_event_tick_list.duplicate(true)
		new_snap.delta_event_id_list = snap.delta_event_id_list.duplicate(true)

		i.snaps.append(new_snap)
			
	return i
