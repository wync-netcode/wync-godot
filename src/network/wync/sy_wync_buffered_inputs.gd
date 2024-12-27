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
	
	# TODO: get actual client id
	var client_id = 0

	# TODO: Save actual ticks

	if not wync_ctx.client_owns_prop.has(client_id):
		return
	"""
	for prop_id in wync_ctx.client_owns_prop[client_id]:
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			continue
		var prop = wync_ctx.props[prop_id] as WyncEntityProp
		if prop.data_type != WyncEntityProp.DATA_TYPE.INPUT:
			continue
		
		# feed inputs to prop
	
	for entity_id_key in wync_ctx.entity_has_props.keys():
		var prop_ids_array = wync_ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		var entity_snap = WyncPktPropSnap.EntitySnap.new()
		entity_snap.entity_id = entity_id_key
		
		for prop_id in prop_ids_array:
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
	"""
	for entity: Entity in entities:

		var co_actor = entity.get_component(CoActor.label) as CoActor
		if not WyncUtils.is_entity_tracked(wync_ctx, co_actor.id):
			continue
		
		var input_prop_id = WyncUtils.entity_get_prop_id(wync_ctx, co_actor.id, "input")
		if input_prop_id < 0:
			continue
		
		if not (wync_ctx.client_owns_prop[client_id] as Array).has(input_prop_id):
			continue
		
		var input_prop = wync_ctx.props[input_prop_id]
		if input_prop == null:
			continue
		
		Log.out(self, "Input prop is %s" % input_prop)
		
		continue
		var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
		var co_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# save inputs

		var curr_input = co_actor_input.copy()
		curr_input.tick = tick_curr
		co_buffered_inputs.set_tick(tick_curr, curr_input)
		
		# save tick relationship
		
		co_buffered_inputs.set_tick_predicted(tick_pred, tick_curr)
		
		# Compensate for UP smooth tick_offset transition
		# check if previous input is missing -> then duplicate
		
		if not co_buffered_inputs.get_tick_predicted(tick_pred-1):
			co_buffered_inputs.set_tick_predicted(tick_pred-1, tick_curr)
