class_name SyPlayerInput
extends System

func _ready():
	components = "coplayerinput,coactorinput"
	super()
	
func on_process_entity(entity : Entity, _delta: float):
	var input = entity.get_component("coactorinput") as CoActorInput

	input.movement_dir = Vector2(
		int(Input.is_action_pressed("p1_right")) - int(Input.is_action_pressed("p1_left")),
		int(Input.is_action_pressed("p1_down")) - int(Input.is_action_pressed("p1_up")),
	)
	input.shoot = Input.is_action_pressed("p1_mouse1")
	input.reload = Input.is_action_pressed("p1_reload")
	input.open_store = Input.is_action_pressed("p1_interact")
	input.aim = (entity as Node as Node2D).get_global_mouse_position()
	# print(input.shoot, input.reload, input.open_store, input.movement_dir, input.aim)
