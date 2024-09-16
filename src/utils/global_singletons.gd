extends Node
class_name GlobalSingletons

static var singleton: GlobalSingletons = GlobalSingletons.new()
var entities: Dictionary = {}
var components: Dictionary = {}


func _ready():
	GlobalSingletons.singleton = self
	
	for child in get_children():
		if child is Entity:
			print("Registering singleton: ", child.name)
			entities[child.name] = child
		elif child is Component:
			print("Registering singleton: ", child.name)
			components[child.name] = child
			

func get_entity(query_name: String) -> Entity:
	return entities.get(query_name)

			
func get_component(query_name: String) -> Component:
	return components.get(query_name)
