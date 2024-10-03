extends Component
class_name CoNetBufferedInputs
const label = "conetbufferedinputs"

const BUFFER_SIZE = 10
var buffer_inputs: Array[CoActorInput]  ## Array[tick_id: int, input: Input]
var buffer_head: int = 0


func _init() -> void:
	buffer_inputs.resize(BUFFER_SIZE)


func set_tick(tick: int, data) -> void:
	buffer_inputs[tick % BUFFER_SIZE] = data


func get_tick(tick: int) -> CoActorInput:
	var data = buffer_inputs[tick % BUFFER_SIZE]
	if data is CoActorInput && data.tick == tick:
		return data
	return null
