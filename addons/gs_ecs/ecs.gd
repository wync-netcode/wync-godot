#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: ECS
#		Framework for Managing a simple Entity Component System
#		with Godot.
#
#	Remarks:
#
#	Installation:
#		Add this Script as an Autoload singleton to your Project.
#

extends Node

# Map<world_id: int, Map<entity_id: int, entity: Entity>>
var world_entities = {}  

## Map<world_id: int, Map<entity_name: string, entity: Entity>>
var world_singleton_entities = {}

# entities with a component
# Map<comp_id: string, map<entity_id: int, comp: Comp>>
var component_entities = {}  

# a system processes entities with certain components
# Map<world_id: int, map<system_name: string, system: System>>
var world_systems = {}

# the components filtered in a system
# Map<system_name: string, comp_names: Array<string>>
var system_components = {}  

# the entities in a given system
# Map<world_id: int, map<system_name: string, entities: Array<Entity>>
var world_system_entities = {}

# a group represents a collection of systems
# Map<group_name: string, group: Group>
var groups = {}

# systems in a group
# Map<group_name: string, systems: Array<System>>
var group_systems = {}

# a list of entities to remove after group processing is complete
var entity_remove_queue = []

# Map<world_id: int, world: World>
var worlds = {}


# Map<world_id: int, bool>
var is_dirty = {}
var do_clean = {}

const version = "4.2-R1"

# Group: Public Methods

# register a component
func add_component(component):
	Logger.trace("[ECS] add_component")

	var _name = str(component.name).to_lower()
	if has_component(_name):
		Logger.warn("- component %s was already registered -- skipping" % [_name])
		return
				
	component_entities[_name] = {}
	Logger.debug("- new component %s was registered" % [_name])


# register an entity
func add_entity(world: World, entity: Entity, singleton: bool = false):
	Logger.trace("[ECS] add_entity")

	var _id = entity.get_instance_id()
	var _world_id = world.get_instance_id()
	var _name = entity.name

	is_dirty[_world_id] = true

	if not has_world(_world_id):
		add_world(world)

	# warn if trying to use same instance_id and exit
	if has_entity(_world_id, _id):
		Logger.warn("- entity %s already exists, skipping")
		return

	# turn off normal godot processing

	entity.set_process(false)
	entity.set_physics_process(false)
	entity.set_process_input(false)

	# call on_before_add if available
	if entity.has_method("on_before_add"):
		entity.on_before_add()

	# add the entity node reference using its instance_id as key

	world_entities[_world_id][_id] = entity
	if singleton:
		print("Registering entity singleton %s:%s" % [entity, _name])
		world_singleton_entities[_world_id][_name] = entity

	Logger.debug("- entity %s:%s has been registered" % [entity, _name])

	# call on_after_add if available
	if entity.has_method("on_after_add"):
		entity.on_after_add()


# register a system
#func add_system(system, components = []):
func add_system(world: World, system, components = []):
	Logger.trace("[ECS] add_system")

	var _sys_id = str(system.name).to_lower()
	var _world_id = world.get_instance_id()

	is_dirty[_world_id] = true

	if has_system(_world_id, _sys_id):
		Logger.warn("- system %s already exists, skipping" % [_sys_id])
		return

	if not has_world(_world_id):
		Logger.warn("- world %s:%s not registered " % [world, world.name])
		add_world(world)
		Logger.debug("- world was registered")

	# call on_before_add if available
	if system.has_method("on_before_add"):
		system.on_before_add()

	# add the system and create an empty list of component names
	system_components[_sys_id] = []
	world_systems[_world_id][_sys_id] = system
	world_system_entities[_world_id][_sys_id] = []

	# add the components to the system
	for _component in components:
		system_components[_sys_id].append(_component.to_lower().strip_edges())

	Logger.debug("- system %s has been registered" % [_sys_id])

	# call on_after_add if available
	if system.has_method("on_after_add"):
		system.on_after_add()


# register a group
func add_group(group, systems = []):
	Logger.trace("[ECS] add_group")
	#is_dirty = true  # TODO support worlds

	var _id = group.name.to_lower()

	if has_group(_id):
		Logger.warn("- group %s already exists, skipping" % [_id])
		return

	groups[_id] = group
	group_systems[_id] = []

	for system in systems:
		group_systems[_id].append(system.to_lower().strip_edges())

	Logger.debug("- group %s has been registered" % [_id])


# register a world
func add_world(world: World):
	Logger.trace("[ECS] add_world")

	var _id = world.get_instance_id()

	# warn if trying to use same instance_id and exit
	if has_world(_id):
		Logger.warn("- world %s already exists, skipping")
		return

	# add the entity node reference using its instance_id as key
	worlds[_id] = world
	world_systems[_id] = {}
	world_system_entities[_id] = {}
	world_entities[_id] = {}
	world_singleton_entities[_id] = {}
	is_dirty[_id] = true
	do_clean[_id] = false

	Logger.debug("- world %s:%s has been registered" % [world, world.name])


# remove everything from the framework
func clean(world: World):
	Logger.trace("[ECS] clean")
	do_clean[world.get_instance_id()] = true
	

# add an entity to a component
func entity_add_component(entity, component):
	Logger.trace("[ECS] entity_add_component")

	var world = find_world_up(entity)
	if not world:
		Logger.warn("- world for entity %s:%s not found " % [entity, entity.name])
		return
	var _entity_id = entity.get_instance_id()
	var _world_id = world.get_instance_id()

	is_dirty[_world_id] = true

	if not has_entity(_world_id, _entity_id):
		Logger.warn("- entity %s:%s not registered " % [entity, entity.name])
		add_entity(_world_id, entity)
		Logger.debug("- entity was registered")

	var _id = str( component.name ).to_lower()

	# add new component
	if not has_component(_id):
		add_component(component)

	# add entity to the component
	component_entities[_id][_entity_id] = component
	Logger.debug("- registered %s component for entity %s:%s " % [_id, entity, entity.name])

	return


# returns a component for an entity
func entity_get_component(entity_id, component_name):
	Logger.trace("[ECS] entity_get_component")
	if (component_entities.has(component_name)):
		return component_entities[component_name][entity_id]


# returns true if the entity has the component
func entity_has_component(entity_id, component_name):
	Logger.trace("[ECS] entity_has_component")
	if component_entities.has(component_name):
		if component_entities[component_name].has(entity_id):
			return true
	return false



func entity_remove_component(entity, component_name):
	Logger.trace("[ECS] entity_remove_component")

	var world = find_world_up(entity)
	if not world:
		Logger.warn("- world for entity %s:%s not found " % [entity, entity.name])
		return
	var _world_id = world.get_instance_id()
	var _entity_id = entity.get_instance_id()

	is_dirty[_world_id] = true

	if not has_entity(_world_id, _entity_id):
		Logger.warn("- entity %s:%s not registered " % [entity, entity.name])
		return

	var _id = component_name.to_lower()

	if not has_component(_id):
		Logger.warn("- component %s not registered " % [_id])
		return

	# remove entity
	component_entities[_id].erase(_entity_id)
	Logger.debug("- removed component %s for entity %s:%s" % [_id, entity, entity.name])

	return


# returns entity singleton
func get_singleton(caller: Node, entity_name: String) -> Entity:
	var world = find_world_up(caller)
	if not world:
		Logger.warn("- world for node %s:%s not found " % [caller, caller.name])
		return null

	var world_id = world.get_instance_id()
	if not world_singleton_entities[world_id].has(entity_name):
		return null

	return world_singleton_entities[world_id][entity_name]


# return component from the framework
func get_component(component_name):
	Logger.trace("[ECS] get_component")
	return component_entities[component_name]


# return all components
func get_all_components():
	Logger.trace("[ECS] get_all_components")
	return component_entities


# returns true if component already exists in the framework
func has_component(component_name):
	Logger.trace("[ECS] has_component")
	return component_entities.has(component_name)


# returns true if entity already exists
func has_entity(world_id, entity_id):
	Logger.trace("[ECS] has_entity")

	if world_entities[world_id].has(entity_id):
		return true

	return false

# returns true if the system already exists
func has_system(world_id, system_name):
	Logger.trace("[ECS] has_system")
	if world_systems[world_id].has(system_name):
		return true

	return false


# returns true if the system already exists
func has_group(group_name):
	Logger.trace("[ECS] has_group")
	if groups.has(group_name):
		return true

	return false


# returns true if entity already exists
func has_world(world_id: int):
	Logger.trace("[ECS] has_world")
	if worlds.has(world_id):
		return true

	return false


# tries to find a World node up the tree
func find_world_up(node: Node) -> World:
	var _parent = node
	
	while true:
		if _parent == null:
			break
		
		if _parent is World:
			return _parent

		_parent = _parent.get_parent()

	return null


# rebuild system entities
func rebuild(world_id):
	Logger.trace("[ECS] rebuild")

	world_system_entities[world_id].clear()
	for _system in world_systems[world_id]:
		if world_systems[world_id][_system].enabled:
			_add_system_entities(world_id, _system)

	is_dirty[world_id] = false


# remove component from the framework
func remove_component(entity, component_name):
	Logger.trace("[ECS] remove_component")

	var world = find_world_up(entity)
	if not world:
		Logger.warn("- world for entity %s:%s not found " % [entity, entity.name])
		return
	var _key = component_name.to_lower()
	var _world_id = world.get_instance_id()

	is_dirty[_world_id] = true

	if has_component(_key):

		var _id = entity.get_instance_id()
		component_entities[_key].erase(_id)

		Logger.debug("- %s component was removed for entity %s:%s" % [_key, entity, entity.name])

	else:

		Logger.warn("Entity %s:%s does not exist" % [entity, entity.name])

	return


# queue an entity for removal
func remove_entity(entity):
	Logger.trace("[ECS] remove_entity")

	var world = find_world_up(entity)
	if not world:
		Logger.warn("- world for entity %s:%s not found " % [entity, entity.name])
		return
	var _world_id = world.get_instance_id()
	is_dirty[_world_id] = true

	if (entity.has_method("get_instance_id")):
		entity_remove_queue.append(entity.get_instance_id())


# remove a system
func remove_system(world: World, system_name):
	
	Logger.trace("[ECS] remove_system")

	var _id = system_name.to_lower()
	var _world_id = world.get_instance_id()
	var _system = world_systems[_world_id][system_name]

	if not has_system(_world_id, _id):
		Logger.warn("- system %s is not registered, skipping" % [_id])
		return

	is_dirty[_world_id] = true

	# call on_before_remove if available
	if _system.has_method("on_before_remove"):
		_system.on_before_remove()

	# remove the system and create an empty list of component names
	world_systems[_world_id].erase(_id)
	system_components.erase(_id)

	# call on_after_remove if available
	if _system.has_method("on_after_remove"):
		_system.on_after_remove()

	Logger.debug("- system %s has been removed" % [_id])


# update the systems, specified by group name (or not)
func update(world: World, group = null, delta = null):
	Logger.fine("[ECS] update")

	var world_id = world.get_instance_id()

	# rebuild if dirty
	if is_dirty[world_id]:
		Logger.debug("- system is dirty, rebuilding indexes")
		rebuild(world_id)

	var _delta = delta

	# if no delta is passed, use the current delta
	if _delta == null:
		_delta = get_process_delta_time()

	# if no group passed, do all systems
	if group == null:
		for _system in world_systems[world_id].values():
			if _system != null:
				if _system.enabled:
					#print("%s %s %s %s" % [world.name, _system.name])
					_system.on_process(world_system_entities[world_id][str(_system.name).to_lower()], _delta)

	# FIXME
	# process each system in this group group
	#if (group && group_systems.has(group)):
	#	for _system_name in group_systems[group]:
	#		if systems.has(_system_name):
	#			var _system = systems[_system_name]
	#			if _system != null:
	#				if _system.enabled:
	#					_system.on_process(world_system_entities[world_id][_system.name.to_lower()], _delta)

	# clean up entities queued for removal
	if entity_remove_queue.size() > 0:	
		is_dirty[world_id] = true
		for _entity_id in entity_remove_queue:
			if world_entities[world_id].has(_entity_id):
				# when the entity has not yet been freed then
				if world_entities[world_id][_entity_id] != null:
					world_entities[world_id][_entity_id].queue_free()
				world_entities[world_id].erase(_entity_id)

	# and clear the queue
	entity_remove_queue.clear()
	
	# full cleaning requested?
	if (do_clean[world_id]):
		
		world_entities[world_id].clear()
		component_entities.clear()
		world_systems[world_id].clear()
		system_components.clear()
		world_system_entities[world_id].clear()
		groups.clear()
		group_systems.clear()
		entity_remove_queue.clear()
		do_clean[world_id] = false

	return


func _add_system_entities(world_id, system_name):
	Logger.trace("[ECS] _add_system_entities")

	var _entities = []

	for entity_id in world_entities[world_id]:

		if world_entities[world_id][entity_id] == null:
			continue
			
		if not world_entities[world_id][entity_id].enabled:
			continue

		var has_all_components = true
		for component in system_components[system_name]:

			if component.substr(0,1) == "!":
				var _component_id = component.substr(1,999)
				if (has_component(_component_id)):
					if component_entities[_component_id].has(entity_id):
						has_all_components = false
						break
					break
				break

			if not component_entities.has(component):
				has_all_components = false
				break

			if not component_entities[component].has(entity_id):
				has_all_components = false
				break

		if has_all_components:
			_entities.append(world_entities[world_id][entity_id])


	#system_entities[system_name] = _entities
	world_system_entities[world_id][system_name] = _entities


# do some cleanup
func _exit_tree():
	Logger.trace("[ECS] _exit_tree")
	for world in worlds.values():
		clean(world)


func _init() -> void:
	print(" ")
	print("godot-stuff ECS")
	print("https://gitlab.com/godot-stuff/gs-ecs")
	print("Copyright 2018-2023, SpockerDotNet LLC")
	print("Version " + version)
	print(" ")
