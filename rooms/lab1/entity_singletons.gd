extends Node
class_name EntitySingletons

static var singleton: EntitySingletons = EntitySingletons.new()
var entities: Dictionary = {}

func _ready():
	EntitySingletons.singleton = self
	
	for child in get_children():
		if child is Entity:
			print("Registering singleton: ", child.name)
			entities[child.name] = child
			
func get_entity(entity_name: String) -> Entity:
	return entities.get(entity_name)
