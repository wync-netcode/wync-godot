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
	wync_buffer_inputs(single_wync.ctx)
	
	
static func wync_buffer_inputs(ctx: WyncCtx):
	
	if not ctx.connected:
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in ctx.client_owns_prop[ctx.my_peer_id]:
		
		# Log.out(node_self, "client owns prop %s" % prop_id)
		if not WyncUtils.prop_exists(ctx, prop_id):
			Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var input_prop = ctx.props[prop_id] as WyncEntityProp
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

		input_prop.confirmed_states.insert_at(ctx.co_predict_data.target_tick, new_state)
