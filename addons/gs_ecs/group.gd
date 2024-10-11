
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

# group of systems to process
var systems: Array[StringName]


func _ready():

	_find_systems(self, systems, 0)

	print("D[GROUP]: Found the following systems:")
	for sys in systems:
		print("D[GROUP]: (%s)" % sys)

	ECS.add_group(self, systems)


func _find_systems(node: Node, list: Array[StringName], depth: int):
	for child in node.get_children():
		if child is System:
			list.append(child.get_label())
		if child.get_child_count() && depth < maximun_depth_system_lookup:
			_find_systems(child, list, depth+1)
	
