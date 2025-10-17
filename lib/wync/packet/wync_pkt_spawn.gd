class_name WyncPktSpawn

var entity_amount: int
var entity_ids: Array[int]
var entity_type_ids: Array[int]

var entity_prop_id_start: Array[int] # authoritative prop id range
var entity_prop_id_end: Array[int]

var entity_spawn_data_sizes: Array[int] # C buffer info
var entity_spawn_data: Array[Variant]


func _init(size) -> void:
	resize(size)


func resize(size):
	entity_amount = size
	entity_ids.resize(size)
	entity_type_ids.resize(size)
	entity_prop_id_start.resize(size)
	entity_prop_id_end.resize(size)
	entity_spawn_data_sizes.resize(size)
	entity_spawn_data.resize(size)


func duplicate() -> WyncPktSpawn:
	var i = WyncPktSpawn.new(entity_amount)
	i.entity_amount = entity_amount
	i.entity_ids = entity_ids.duplicate(true)
	i.entity_type_ids = entity_type_ids.duplicate(true)
	i.entity_prop_id_start = entity_prop_id_start.duplicate(true)
	i.entity_prop_id_end = entity_prop_id_end.duplicate(true)
	i.entity_spawn_data_sizes = entity_spawn_data_sizes.duplicate(true)
	for j in range(entity_amount):
		i.entity_spawn_data.append(entity_spawn_data[j])
	return i
