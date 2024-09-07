class_name SyVelocity
extends System

func _ready():
	components = "covelocity,cocollider"
	super()
	
func on_process_entity(entity : Entity, delta: float):
	var _component = entity.get_component("covelocity") as CoVelocity
	var _collider = entity.get_component("cocollider") as CoCollider
	print(_collider)
	assert((entity as Node) is Node2D)
	entity.position += _component.direction * _component.speed * delta
	print(entity.position)
