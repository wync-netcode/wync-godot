extends RayCast2D
class_name DebugRay

const live_time_ms = 200
@onready var born_time_ms = Time.get_ticks_msec()


func _ready() -> void:
	enabled = false
	self.z_index = 2


func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() > born_time_ms + live_time_ms:
		self.queue_free()


static func show_debug_ray(caller: Node, from: Vector2, to: Vector2) -> void:
	var ray = DebugRay.new()
	caller.add_child(ray)
	ray.global_position = from
	ray.target_position = to
