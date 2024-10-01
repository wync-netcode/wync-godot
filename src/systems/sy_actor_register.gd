extends System
class_name SyActorRegister


func _ready():
	components = "%s,!%s" % [CoActor.label, CoActorRegisteredFlag.label]
	super()

	
func on_process_entity(entity : Entity, _delta: float):
	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors
	var co_actor = entity.get_component(CoActor.label) as CoActor

	print("D: Trying to register %s:%s" % [entity, entity.name])
	
	# register actors that aren't registered

	var cursor = co_actors.cursor
	for i in range(co_actors.max_actors):
		cursor = (co_actors.cursor + i) % co_actors.max_actors

		if co_actors.actors[cursor] == null:
			co_actors.actor_count += 1
			co_actors.actors[cursor] = entity
			co_actor.id = cursor
			var flag = CoActorRegisteredFlag.new()
			ECS.entity_add_component_node(entity, flag)
			print("D: Registered Actor %s:%s with id %s" % [entity, entity.name, cursor])
			break

	co_actors.cursor = cursor
