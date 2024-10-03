extends Component
class_name CoSingleSelfPredictedActors
const label = "cosingleselfpredictedactors"

#class SelfPredictSnapshot:
	#var position: Vector2
	#var 

class TickData:
	var tick: int
	var timestamp: int ## ms
	var actor_snapshot: Dictionary ## Dictionary[actor_id: int, Snapshot]
	var actor_input: Dictionary ## Dictionary[actor_id: int, CoInput]

#var predicted_snapshots: RingBuffer = RingBuffer.new(10) # RingBuffer[TickData]
#var snapshots: RingBuffer = RingBuffer.new(BUFFER_SIZE) # RingBuffer[TickData]
const BUFFER_SIZE = 10
#var predicted_snapshots: Array[TickData]
var last_tick_confirmed: int = 0
var last_tick_predicted: int = 0
var ticks_to_predict: int = 0

# Dictionary<actor_id, Entity>
var actors: Dictionary

# Array[Dictionary[actor_id, Snapshot]]
# tick_snapshots: Array[TickData]: [
# 	(TickData) {
#     tick: int
#     timestamp: int
#     actor_snapshots: Dictionary[int, Snapshot]: {
#       id: (Snapshot) {
#         position: Vector2
#       },
#     }
#   },
# ]
var tick_snapshots: Array


func _init() -> void:
	tick_snapshots.resize(BUFFER_SIZE)


func snapshots_set_tick(tick: int, data) -> void:
	tick_snapshots[tick % BUFFER_SIZE] = data


func snapshots_get_tick(tick: int) -> TickData:
	var data = tick_snapshots[tick % BUFFER_SIZE]
	if data is TickData && data.tick == tick:
		return data
	return null
