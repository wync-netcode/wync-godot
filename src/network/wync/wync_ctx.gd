class_name WyncCtx

# Array<entity_id: int>
var tracked_entities: Array

# Array<prop_id: int, WyncEntityProp>
var props: Array

# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary


"""
static var instance: WyncCtx = null
static func get_singleton() -> WyncCtx:
	if instance == null:
		instance = WyncCtx.new()
	return instance
"""
