class_name WyncPktDespawn

var entity_amount: int
var entity_ids: Array[int]


func _init(size) -> void:
	entity_amount = size
	entity_ids.resize(size)


func duplicate() -> WyncPktDespawn:
	var i = WyncPktDespawn.new(entity_amount)
	i.entity_amount = entity_amount
	i.entity_ids = entity_ids.duplicate(true)
	return i
