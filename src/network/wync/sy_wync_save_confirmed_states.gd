extends System
class_name SyWyncSaveConfirmedStates
const label: StringName = StringName("SyWyncSaveConfirmedStates")

# TODO: This preferable would be in process


func _ready():
	components = [CoClient.label, CoPeerRegisteredFlag.label]
	super()
	

func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err(self, "Couldn't find singleton EnSingleClient")
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets

	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		Log.err(self, "Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktPropSnap
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
		#Log.out(self, "consume | co_io.in_packets.size() %s" % (co_io.in_packets.size()+1))
		
		for snap: WyncPktPropSnap.EntitySnap in data.snaps:
			
			if not WyncUtils.is_entity_tracked(wync_ctx, snap.entity_id):
				continue
			
			for prop: WyncPktPropSnap.PropSnap in snap.props:
				
				if prop.prop_id > wync_ctx.props.size()-1:
					continue
				var local_prop = wync_ctx.props[prop.prop_id] as WyncEntityProp
				if not local_prop:
					continue
				
				var tick_data = NetTickData.new()
				tick_data.tick = data.tick
				tick_data.timestamp = curr_time
				tick_data.data = prop.prop_value
				local_prop.confirmed_states.push(tick_data)
				local_prop.dirty = true
