
#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: System
#
#	Helper Class for a Developer to add a System process
#	to the ECS Framework.
#
#
@icon("res://addons/gs_ecs/icons/gear.png")

extends Node

class_name System


@export var COMPONENTS = ""
@export var ENABLED = true

var components: Array[int] = []
var enabled = false


## Labels identify systems in ECS
## All subclasses should implement a label constant
func get_label() -> StringName:
	assert(self.label is StringName)
	return self.label


# virtual calls

func on_init():
	Logger.trace("[system] on_init")
	
	
func on_ready():
	Logger.trace("[system] on_ready")
	
	
func on_before_add():
	Logger.trace("[system] on_before_add")
	
	
func on_after_add():
	Logger.trace("[system] on_after_added")
	
	
func on_before_remove():
	Logger.trace("[system] on_before_remove")
	
	
func on_after_remove():
	Logger.trace("[system] on_after_remove")
	
	
func on_process(entities, data, delta):
	for entity in entities:
		on_process_entity(entity, data, delta)
	
	
func on_process_entity(entity, data, delta):
	Logger.trace("[system] on_process_entity")
	pass
	
	
func _ready():
	
	Logger.trace("[system] _ready")
	
	if COMPONENTS:	components = COMPONENTS
	if ENABLED:		enabled = ENABLED
	
	var world = ECS.find_world_up(self)
	if world:
		ECS.add_system(world, self, components)
		on_ready()

	
func _init():
	Logger.trace("[system] _init")
	on_init()
