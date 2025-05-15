class_name WyncPktSpawn

var entity_amount: int
var entity_ids: Array
var entity_type_ids: Array


func _init(size) -> void:
	entity_amount = size
	entity_ids.resize(size)
	entity_type_ids.resize(size)


func duplicate() -> WyncPktSpawn:
	var i = WyncPktSpawn.new(entity_amount)
	i.entity_amount = entity_amount
	i.entity_ids = entity_ids.duplicate(true)
	i.entity_type_ids = entity_type_ids.duplicate(true)
	return i
