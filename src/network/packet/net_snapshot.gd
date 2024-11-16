class_name NetSnapshot

var tick: int
var entity_ids: Array[int]
var positions: Array[Vector2]
var velocities: Array[Vector2]


func duplicate() -> NetSnapshot:
	var snap = NetSnapshot.new()
	snap.tick = tick
	snap.entity_ids = entity_ids.duplicate(true)
	snap.positions = positions.duplicate(true)
	snap.velocities = velocities.duplicate(true)
	return snap
