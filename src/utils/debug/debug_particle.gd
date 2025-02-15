extends Node2D
class_name DebugParticle

@export var color: Color = Color.WHITE
static var SCENE_DEBUG_PARTICLE: PackedScene = preload("res://src/utils/debug/debug_particle.tscn")


func _ready() -> void:
	$CPUParticles2D.color = self.color
	$CPUParticles2D.restart()
	$CPUParticles2D.emitting = true
	($CPUParticles2D.finished as Signal).connect(self.queue_free)


static func spawn(parent: Node, global_pos: Vector2, arg_color: Color):
	var newi = SCENE_DEBUG_PARTICLE.instantiate()
	newi.color = arg_color
	newi.global_position = global_pos
	parent.add_child(newi)
