extends System
class_name SyNetClockClient
const label: StringName = StringName("SyNetClockClient")

## Receives the clock sync packet, to be able to translate timestamps from
## the remote clock to the local clock


func _ready():
	components = [CoNetConfirmedStates.label, CoActor.label, CoActorRegisteredFlag.label]
	super()
	

func on_process(_entities, _data, _delta: float):
	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err("Couldn't find singleton EnSingleClient", Log.TAG_CLOCK)
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets
	if co_io.in_packets.size() == 0:
		return

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktClock
		if not data:
			continue

		#WyncFlow.wync_handle_pkt_clock(wync_ctx, data)
		#print_additional_clock_debug_info(wync_ctx)
			
		# consume
		co_io.in_packets.remove_at(k)


func print_additional_clock_debug_info(ctx: WyncCtx):

	var server_ticks = %"CoSingleWyncContext-Server".ctx.co_ticks.ticks -1
	
	Log.out("server_ticks_aprox %s, real %s, d %s" % [
		ctx.co_ticks.server_ticks,
		server_ticks,
		server_ticks - ctx.co_ticks.server_ticks,
	], Log.TAG_CLOCK)
