extends Node2D

@export var color: Color = Color.WHITE

func _ready() -> void:
	$CPUParticles2D.color = self.color
	$CPUParticles2D.restart()
	$CPUParticles2D.emitting = true
	($CPUParticles2D.finished as Signal).connect(self.queue_free)
