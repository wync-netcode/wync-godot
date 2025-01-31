extends System
class_name SyWyncBufferedInputs
const label: StringName = StringName("SyWyncBufferedInputs")

## * Buffers the inputs per tick
## Rules for saving a tick
## * Si ya existe no lo reemplaces
## * Solo puedes guardar ticks que sean mayores al último guardado?

## TODO: Handle special cases for events: non-repeat on tick (set data struct)

func _ready():
	components = [
		CoActorInput.label,
		CoFlagNetSelfPredict.label,
		CoNetBufferedInputs.label,
		CoFlagWyncEntityTracked.label]
	super()
	

func on_process(_entities, _data, _delta: float, node_root: Node = null):
	
	var node_self = self if node_root == null else node_root
	var co_ticks = ECS.get_singleton_component(node_self, CoTicks.label) as CoTicks
	var co_predict_data = ECS.get_singleton_component(node_self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_curr = co_ticks.server_ticks
	
	var single_wync = ECS.get_singleton_component(node_self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	if not wync_ctx.connected:
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in wync_ctx.client_owns_prop[wync_ctx.my_peer_id]:
		
		# Log.out(node_self, "client owns prop %s" % prop_id)
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err(node_self, "prop %s doesn't exists" % prop_id)
			continue
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		if not input_prop:
			Log.err(node_self, "not input_prop %s" % prop_id)
			continue
		if input_prop.data_type not in [
			WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			Log.err(node_self, "prop %s is not INPUT or EVENT" % prop_id)
			continue
	
		# Log.out(node_self, "gonna call getter for prop %s" % prop_id)
		var new_state = input_prop.getter.call()
		if new_state == null:
			Log.out(node_self, "new_state == null :%s" % [new_state])
			continue
		
		# Log.out(node_self, "Saving event state :%s" % [new_state])
		wync_tick_set_input(co_predict_data, wync_ctx, prop_id, tick_curr, new_state)
	

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
