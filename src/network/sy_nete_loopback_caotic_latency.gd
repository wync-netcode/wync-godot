extends System
class_name SyNeteLoopbackCaoticLatency
const label: StringName = StringName("SyNeteLoopbackCaoticLatency")


func on_process_entity(_entity: Entity, _data, _delta: float):

	# components

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	if Engine.get_physics_frames() % (Engine.physics_ticks_per_second/2) == 0:
		co_loopback._latency_mean += 1
		if co_loopback._latency_mean > 600:
			co_loopback._latency_mean = 0
