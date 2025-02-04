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
	
	for prop: WyncEntityProp in wync_ctx.props:
		
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
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		prop.setter.call(last_confirmed.data)
	
	# call integration function to sync new transforms with physics server
	
	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		
		if not wync_ctx.entity_has_props.has(co_actor.id):
			continue
				
		var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
		if int_fun is Callable:
			int_fun.call()
