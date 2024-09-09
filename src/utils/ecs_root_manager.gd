#
# singleton script
#
extends Node
class_name ECSRootManager

var _current_root: ECSRoot = null
var _entities_node: Node = null


func get_root() -> ECSRoot:
	return _current_root


func update_root(root: ECSRoot):
	assert(root as ECSRoot)
	_current_root = root as ECSRoot
	_entities_node = root.get_node("Entities")


func add_entity_node(entity: Entity):
	_entities_node.add_child(entity)
