
#
#	Copyright 2018-2023, SpockerDotNet LLC.
#	https://gitlab.com/godot-stuff/gs-ecs/-/blob/master/LICENSE.md
#
#	Class: World
#
#	Helper Class for the Developer to create a
#	collection of Entity / Systems.
#
#	Remarks:
#
#		A world allows to separate diffent game simulations.
#
#	How To Use:
#
#		Place this Class, or Sub Class it onto a Parent Node. Any
#		Child Node should be a type of System.
#		- World
#			- WhatEver
#				- PathTo
#					- Entities
#					- Systems
#
@icon("res://addons/gs_ecs/icons/share2.png")

extends Node

class_name World


func _ready():
	ECS.add_world(self)


func add_entity_node(entity: Entity):
	self.add_child(entity)
