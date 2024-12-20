class_name WyncPacketPropSnap

## Ideal packet structure
## tick;[entity_id:[prop_id:prop_value,prop_id:prop_value]]

## NOTE: Build an optimized packet format exclusive for positional data

class PropSnap:
	var prop_id: int
	var prop_value#: (int, float, vector2)

class EntitySnap:
	var entity_id: int
	var props: Array[PropSnap]

var tick: int
var snaps: Array[EntitySnap]


func duplicate() -> WyncPacketPropSnap:
	var i = WyncPacketPropSnap.new()
	i.tick = tick
	
	for snap: EntitySnap in snaps:
		var new_snap = EntitySnap.new()
		new_snap.entity_id = snap.entity_id
		i.snaps.append(new_snap)
		
		for prop in snap.props:
			var new_prop = PropSnap.new()
			new_prop.prop_id = prop.prop_id
			new_prop.prop_value = prop.prop_value
			new_snap.props.append(new_prop)
			
	return i
