class_name ECSUtils

const MAX_CYCLES_SEARCH_UP = 4

## @returns: Optional[Entity]
static func get_entity_from_component(component: Component) -> Entity:
	if component == null:
		return null

	var _parent = component
	for i in range(MAX_CYCLES_SEARCH_UP):
		_parent = _parent.get_parent() as Node
		if _parent == null:
			break
		if _parent is Entity:
			return _parent
	
	return null
