extends System
class_name SyStateLoggerClient
const label: StringName = StringName("SyStateLoggerClient")
"""

const ACTOR_TO_LOG_ID = 0

func _ready():
	components = [CoActor.label, CoCollider.label, CoActorInput.label]
	super()
	

func on_process_entity(entity, _data, _delta: float):
	
	var co_state_log = GlobalSingletons.singleton.get_component(CoStateLog.label) as CoStateLog
	if not co_state_log:
		Log.err("E: Couldn't find singleton CoStateLog")
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
	
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_pred = co_predict_data.target_tick
	
	co_state_log.client_state[tick_pred] = state
	
	# compare the two
	
	var tick_show = co_predict_data.last_tick_confirmed
	#if co_ticks.ticks % 60 == 0:
	if tick_show > 0 && co_state_log.client_state.has(tick_show):
		Log.out("(%d) server: %s client %s diff %s" % [tick_show, co_state_log.server_state[tick_show].input, co_state_log.client_state[tick_show].input, co_state_log.server_state[tick_show].input - co_state_log.client_state[tick_show].input])
		Log.out("(%d) server: %s client %s" % [tick_show, co_state_log.server_state[tick_show].vel, co_state_log.client_state[tick_show].vel])
		Log.out("(%d) server: %s client %s" % [tick_show, co_state_log.server_state[tick_show].pos, co_state_log.client_state[tick_show].pos])
"""
