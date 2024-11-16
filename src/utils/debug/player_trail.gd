extends CollisionShape2D
class_name DebugPlayerTrail


func _physics_process(_delta: float) -> void:
	self.queue_free()


static func spawn(parent: Node, global_pos: Vector2, hue: float = 0):
	var inst = DebugPlayerTrail.new()
	inst.shape = RectangleShape2D.new()
	inst.shape.size = Vector2(26, 26)
	inst.global_position = global_pos
	inst.debug_color.h = hue
	inst.debug_color.a = 0
	
	parent.add_child(inst)
