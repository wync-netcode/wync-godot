class_name SyWyncLatestValue
extends System
const label: StringName = StringName("SyWyncLatestValue")

## sets props state to last confirmed received state
## NOTE: optimize which to reset, by knowing which were modified/new state gotten
## NOTE: reset only when new data is available

func _ready():
	components = [
		CoActor.label,
		CoActorRegisteredFlag.label,
		CoFlagWyncEntityTracked.label
	]
	super()


func on_process(entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# Reset all extrapolated entities to last confirmed tick
	# Don't affect predicted entities?
	# TODO: store props in HashMap instead of Array
	
	var prop_id_list: Array[int] = []
	for prop_id: int in wync_ctx.props.size():
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if !prop.dirty:
			continue
		prop.dirty = false
		prop_id_list.append(prop_id)
		
	reset_all_state_to_confirmed_tick_relative(wync_ctx, prop_id_list, 0)
	
	# call integration function to sync new transforms with physics server
	
	integrate_state(wync_ctx, entities)


static func reset_all_state_to_confirmed_tick(wync_ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue 
		prop = prop as WyncEntityProp
		
		var last_confirmed = prop.confirmed_states.get_at(tick)
		if last_confirmed == null:
			continue
		
		prop.setter.call(last_confirmed.data)


static func reset_all_state_to_confirmed_tick_relative(wync_ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue 
		prop = prop as WyncEntityProp
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick) as int
		var last_confirmed = prop.confirmed_states.get_at(last_confirmed_tick)
		if last_confirmed == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(wync_ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		prop.setter.call(last_confirmed)


static func integrate_state(wync_ctx: WyncCtx, entities: Array):
	
	# iterate all entities
	# check if they have a prop that was affected?
	# run entity integration function

	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		
		if not wync_ctx.entity_has_props.has(co_actor.id):
			continue
				
		var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
		if int_fun is Callable:
			int_fun.call()
