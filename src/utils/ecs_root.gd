#
# Use this node to mark a node as ECSRoot to store entities
# This node must have a child node named "Entities"
#
extends Node
class_name ECSRoot


func _ready():
	# register as root
	ECSRootManagerSingleton.update_root(self)
