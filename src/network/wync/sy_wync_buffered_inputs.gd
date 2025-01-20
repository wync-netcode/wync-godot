extends System
class_name SyWyncBufferedInputs
const label: StringName = StringName("SyWyncBufferedInputs")

## * Buffers the inputs per tick
## Rules for saving a tick
## * Si ya existe no lo reemplaces
## * Solo puedes guardar ticks que sean mayores al último guardado?

func _ready():
	components = [
		CoActorInput.label,
		CoFlagNetSelfPredict.label,
		CoNetBufferedInputs.label,
		CoFlagWyncEntityTracked.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_curr = co_ticks.server_ticks
	var tick_pred = co_predict_data.target_tick
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	if not wync_ctx.connected:
		return

	for entity: Entity in entities:

		var co_actor = entity.get_component(CoActor.label) as CoActor
		var owned_prop_id = wync_get_owned_prop_input(wync_ctx, co_actor.id)
		if owned_prop_id == -1:
			continue
		#Log.out(self, "Input prop id is %s" % owned_prop_id)
		
		var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
		wync_tick_set_input(co_predict_data, wync_ctx, owned_prop_id, tick_curr, co_actor_input.copy())
		
		# =================================================
		# (2) TODO: Send inputs to server


# @returns int: prop_id; -1 if nothing was found
func wync_get_owned_prop_input(wync_ctx: WyncCtx, game_entity_id: int) -> int:
	
	if not WyncUtils.is_entity_tracked(wync_ctx, game_entity_id):
		return -1
	
	var input_prop_id = WyncUtils.entity_get_prop_id(wync_ctx, game_entity_id, "input")
	if input_prop_id < 0:
		return -1
	
	# checking ownership
	
	if not (wync_ctx.client_owns_prop[wync_ctx.my_client_id] as Array).has(input_prop_id):
		return -1
	
	return input_prop_id
	

func wync_tick_set_input(
	co_predict_data: CoSingleNetPredictionData,
	wync_ctx: WyncCtx,
	input_prop_id: int,
	tick_curr: int,
	input #: any
	) -> void:
	
	var tick_pred = co_predict_data.target_tick
	
	# save tick relationship
	
	co_predict_data.set_tick_predicted(tick_pred, tick_curr)
	# Compensate for UP smooth tick_offset transition
	# check if previous input is missing -> then duplicate
	if not co_predict_data.get_tick_predicted(tick_pred-1):
		co_predict_data.set_tick_predicted(tick_pred-1, tick_curr)
	
	# save input to actual prop
	
	var input_prop = wync_ctx.props[input_prop_id] as WyncEntityProp
	if input_prop == null:
		return
	
	input_prop.confirmed_states.insert_at(tick_curr, input)
