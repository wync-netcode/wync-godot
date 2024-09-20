
#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: Group
#
#	Helper Class for the Developer to create a
#	collection of Systems to Run during the
#	game.
#
#	Remarks:
#
#		A Group is a way to place Systems together. This is useful
#		when you want to control what happens to a number of entities
#		without having to control each individual component on
#		the entity.
#
#	How To Use:
#
#		Place this Class, or Sub Class it onto a Parent Node. Any
#		Child Node should be a type of System.
#
@icon("res://addons/gs_ecs/icons/share2.png")

extends Node

class_name Group

@export var maximun_depth_system_lookup: int = 5


func _ready():

	var _systems: Array[String] = []

	_find_systems(self, _systems, 0)


	print("D[GROUP]: Found the following systems:")
	for system in _systems:
		print("D[GROUP]: (%s)" % system)

	ECS.add_group(self, _systems)
	
		#var lowered_name = ""
		#lowered_name = _system.name
		#_systems.append( str( _system.name ).to_lower() )


func _find_systems(node: Node, list: Array[String], depth: int):
	for child in node.get_children():
		if child is System:
			var system_name = str(child.name).to_lower()
			list.append(system_name)
		if child.get_child_count() && depth < maximun_depth_system_lookup:
			_find_systems(child, list, depth+1)
	
