class_name ECSUtils

## @returns: Optional[Entity]
static func get_entity_from_component(component: Component) -> Entity:
	if not component:
		return null
	var _parent = component.get_parent() as Node
	if not _parent:
		return null
	return _parent.get_parent() as Entity
