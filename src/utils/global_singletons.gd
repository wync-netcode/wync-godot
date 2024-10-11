extends Node
class_name GlobalSingletons

static var singleton: GlobalSingletons = GlobalSingletons.new()
var entities: Dictionary = {}
var components: Dictionary = {}


func _ready():
	GlobalSingletons.singleton = self
	
	for child in get_children():
		if child is Entity:
			var label = str(child.name).to_lower()
			print("Registering singleton: ", label)
			entities[label] = child
		elif child is Component:
			var label = child.label
			print("Registering singleton: ", child.name)
			components[label] = child
			

func get_entity(query_name: String) -> Entity:
	return entities.get(query_name)

			
func get_component(query_label: int) -> Component:
	return components.get(query_label)
