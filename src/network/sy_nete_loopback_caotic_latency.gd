extends System
class_name SyNeteLoopbackCaoticLatency
const label: StringName = StringName("SyNeteLoopbackCaoticLatency")


func on_process_entity(_entity: Entity, _data, _delta: float):

	# components

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	#Loopback.system_caotic_latency(co_loopback.ctx)
