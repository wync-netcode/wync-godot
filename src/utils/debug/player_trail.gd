extends CollisionShape2D
class_name DebugPlayerTrail

var max_alive_secs: float = 0
var time_alive_secs: float = 0
var use_draw_loop: bool = false

func _physics_process(_delta: float) -> void:
	time_alive_secs += _delta
	if time_alive_secs >= max_alive_secs:
		self.queue_free()


func _process(delta: float) -> void:
	if use_draw_loop:
		self.queue_free()


static func spawn(parent: Node, global_pos: Vector2, hue: float = 0, max_alive_secs: float = 0, use_draw_loop: bool = false, p_z_index: int = 0):
	var inst = DebugPlayerTrail.new()
	inst.max_alive_secs = max_alive_secs
	inst.use_draw_loop = use_draw_loop
	
	inst.shape = RectangleShape2D.new()
	inst.shape.size = Vector2(26, 26)
	inst.global_position = global_pos
	inst.debug_color.h = hue
	inst.debug_color.a = 0
	inst.z_index = p_z_index
	
	parent.add_child(inst)
