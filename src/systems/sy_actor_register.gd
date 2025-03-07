extends System
class_name SyActorRegister
const label: StringName = StringName("SyActorRegister")


func _ready():
	components = [CoActor.label, -CoActorRegisteredFlag.label]
	super()

	
func on_process_entity(entity : Entity, _data, _delta: float):
	register_actor(self, entity)


static func register_actor(node_ctx: Node, entity: Entity, entity_id: int = -1) -> int:

	var single_actors = ECS.get_singleton_entity(node_ctx, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return 1
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors
	var co_actor = entity.get_component(CoActor.label) as CoActor

	print("D: Trying to register %s:%s" % [entity, entity.name])
	
	# register actors that aren't registered

	if entity_id == -1:
		entity_id = actors_find_available_id(co_actors)
		if entity_id == -1:
			Log.err("A Couldn't register actor %s" % [entity])
			return 2
	else:
		if ((entity_id >= co_actors.max_actors)
		|| (co_actors.actors[entity_id] != null)):
			Log.err("B Couldn't register actor %s" % [entity])
			return 3
	
	# register

	co_actors.actor_count += 1
	co_actors.actors[entity_id] = entity
	co_actor.id = entity_id
	var flag = CoActorRegisteredFlag.new()
	ECS.entity_add_component_node(entity, flag)

	print("D: Registered Actor %s:%s with id %s" % [entity, entity.name, entity_id])

	return OK


static func actors_find_available_id(co_actors: CoSingleActors) -> int:
	var cursor = co_actors.cursor
	for i in range(co_actors.max_actors):
		cursor = (co_actors.cursor + i) % co_actors.max_actors

		if co_actors.actors[cursor] == null:
			co_actors.cursor = cursor
			return cursor

	co_actors.cursor = cursor
	return -1


static func remove_actor(node_ctx: Node, actor_id: int):
	var single_actors = ECS.get_singleton_entity(node_ctx, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	if actor_id >= co_actors.max_actors:
		return

	var entity = co_actors.actors[actor_id]
	if entity == null:
		return

	co_actors.actors[actor_id] = null
	co_actors.actor_count -= 1
