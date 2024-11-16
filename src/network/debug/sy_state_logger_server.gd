extends System
class_name SyStateLoggerServer
const label: StringName = StringName("SyStateLoggerServer")

const ACTOR_TO_LOG_ID = 0
@export var is_server: bool = false

func _ready():
	components = [CoActor.label, CoCollider.label, CoActorInput.label]
	super()
	

func on_process_entity(entity, _data, _delta: float):
	
	var co_state_log = GlobalSingletons.singleton.get_component(CoStateLog.label) as CoStateLog
	if not co_state_log:
		Log.err(self, "E: Couldn't find singleton CoStateLog")
		return
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	# get entity to log from
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_collider = entity.get_component(CoCollider.label) as CoCollider as Node as CharacterBody2D
	var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
	
	if co_actor.id != ACTOR_TO_LOG_ID:
		return
	
	# construct state timestamp
	
	var tick = co_ticks.ticks
	var state = CoStateLog.State.new()
	state.tick = tick
	state.pos = co_collider.global_position
	state.vel = co_collider.velocity
	state.input = co_actor_input.movement_dir.x
	
	# log there
	
	co_state_log.server_state[state.tick] = state
