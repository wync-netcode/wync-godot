extends Component
class_name CoNetBufferedInputs
static var label = ECS.add_component()

const BUFFER_SIZE = 60 * 12  ## 1.2 seconds worth of inputs
const AMOUNT_TO_SEND = 10

var buffer_inputs: Array[CoActorInput]  ## Array[tick_id: int, input: Input]
var buffer_head: int = 0


func _init() -> void:
	buffer_inputs.resize(BUFFER_SIZE)
	buffer_predicted_tick.resize(BUFFER_SIZE)
	buffer_predicted_tick_prev.resize(BUFFER_SIZE)


func set_tick(tick: int, data) -> void:
	buffer_head = tick % BUFFER_SIZE
	buffer_inputs[buffer_head] = data


func get_tick(tick: int) -> CoActorInput:
	var data = buffer_inputs[tick % BUFFER_SIZE]
	if data is CoActorInput && data.tick == tick:
		return data
	return null


# TODO: BETTER NAMES OR BETTER STRUCTURE

var buffer_predicted_tick: Array[int]  ## Array[tick_predicted: int, tick_local: int]
var buffer_predicted_tick_prev: Array[int]  ## Array[tick_predicted: int, tick_local: int]
var buffer_head_predicted_tick: int = 0


func set_tick_predicted(pred_tick: int, local_tick: int) -> void:
	buffer_head_predicted_tick = pred_tick % BUFFER_SIZE
	buffer_predicted_tick[buffer_head_predicted_tick] = local_tick
	buffer_predicted_tick_prev[buffer_head_predicted_tick] = pred_tick


func get_tick_predicted(pred_tick: int):# -> Optional<int>:
	var key = pred_tick % BUFFER_SIZE
	var data = buffer_predicted_tick[key]
	if pred_tick == buffer_predicted_tick_prev[key]:
		return data
	return null
