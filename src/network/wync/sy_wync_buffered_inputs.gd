extends System
class_name SyWyncBufferedInputs
const label: StringName = StringName("SyWyncBufferedInputs")

## Polling and buffering of:
## * INPUT props that the client owns
## * EVENT props that the client owns
## * Client authoritative global events

## Old description:
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
	

func on_process(_entities, _data, _delta: float, p_node_root: Node = null):

	var node_root = self if p_node_root == null else p_node_root

	var single_wync = ECS.get_singleton_component(node_root, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_ticks = wync_ctx.co_ticks
	var co_predict_data = ECS.get_singleton_component(node_root, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_curr = co_ticks.server_ticks

	if not wync_ctx.connected:
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in wync_ctx.client_owns_prop[wync_ctx.my_peer_id]:
		
		# Log.out(node_self, "client owns prop %s" % prop_id)
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		if not input_prop:
			Log.err("not input_prop %s" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		if input_prop.data_type not in [
			WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			Log.err("prop %s is not INPUT or EVENT" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
	
		# Log.out(node_self, "gonna call getter for prop %s" % prop_id)
		var new_state = input_prop.getter.call()
		if new_state == null:
			Log.out("new_state == null :%s" % [new_state], Log.TAG_INPUT_BUFFER)
			continue
		
		# Log.out(node_self, "Saving event state :%s" % [new_state])
		# TODO: Should always run once per tick regardless of props
		wync_tick_set_input(co_predict_data, wync_ctx, prop_id, tick_curr, new_state)
	

static func wync_tick_set_input(
	co_predict_data: CoSingleNetPredictionData,
	wync_ctx: WyncCtx,
	input_prop_id: int,
	tick_curr: int,
	input #: any
	) -> void:
	
	var tick_pred = co_predict_data.target_tick
	
	# save tick relationship
	
	co_predict_data.set_tick_predicted(tick_pred, tick_curr)
	#Log.out(self, "debug1 | set_tick_predicted tick_pred(%s) tick_curr(%s)" % [tick_pred, tick_curr])
	
	# NOTE, are we assuming our max step skip is 2?
	# Compensate for UP smooth tick_offset transition
	# check if previous input is missing -> then duplicate
	if not co_predict_data.get_tick_predicted(tick_pred-1):
		co_predict_data.set_tick_predicted(tick_pred-1, tick_curr)
		#Log.out(self, "debug1 | duplicated tick_pred(%s to %s) tick_curr(%s)" % [tick_pred, tick_pred-1, tick_curr])
	
	# save input to actual prop
	
	var input_prop = wync_ctx.props[input_prop_id] as WyncEntityProp
	if input_prop == null:
		return
	
	input_prop.confirmed_states.insert_at(tick_curr, input)
