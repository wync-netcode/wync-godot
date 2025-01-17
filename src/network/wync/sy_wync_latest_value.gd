class_name SyWyncLatestValue
extends System
const label: StringName = StringName("SyWyncLatestValue")

## Extrapolates the position

func _ready():
	components = [
		CoActor.label,
		CoActorRegisteredFlag.label,
		CoFlagWyncEntityTracked.label
	]
	super()


func on_process(entities, _data, delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return
	
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var target_tick = co_predict_data.target_tick
	var last_confirmed_tick = 0
	
	# Don't affect unwanted entities
	# reset all extrapolated entities to last confirmed tick
		
	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		
		if not wync_ctx.entity_has_props.has(co_actor.id):
			continue
		
		for prop_id: int in wync_ctx.entity_has_props[co_actor.id]:
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			if prop == null:
				continue
			if !prop.dirty:
				continue
			prop.dirty = false
			# TODO: This also affects predicted props
			
			var last_confirmed = prop.confirmed_states.get_relative(0) as NetTickData
			
			if last_confirmed == null:
				continue
			if last_confirmed.data == null:
				continue
			
			prop.setter.call(last_confirmed.data)
			
			last_confirmed_tick = max(last_confirmed_tick, last_confirmed.tick)
		
		# call integration function to sync new transforms with physics server
				
		var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
		if int_fun is Callable:
			int_fun.call()
