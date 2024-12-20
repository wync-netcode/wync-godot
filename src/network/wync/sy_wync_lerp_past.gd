extends System
class_name SyWyncLerpPast
const label: StringName = StringName("SyWyncLerpPast")

## This interpolation implementation applies:
## * Asumes there is no jitter
## * Uses packet arrival time as it's timestamp
## Drawbacks:
## * There will be visual glitches because of jitter

# TODO: Lots of unoptimizations


func _ready():
	components = [CoActor.label, CoActorRenderer.label, CoNetConfirmedStates.label, -CoNetPredictedStates.label, CoFlagWyncEntityTracked.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second
	
	# define target time to render
	var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) # NOTE: This will be important later
	var frame = (1000.0 / physics_fps)
	var target_time = curr_time - co_predict_data.lerp_ms

	# interpolate positions for entities

	for entity: Entity in entities:

		var co_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer
		var co_actor = entity.get_component(CoActor.label) as CoActor

		# else fall back to using confirmed state

		var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
		var ring = co_net_confirmed_states.buffer
			
		# check if this entity has a "position" prop
		
		if not WyncUtils.is_entity_tracked(wync_ctx, co_actor.id):
			continue
		
		var prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "position")
		if not prop:
			continue
		
		# find two snapshots

		var snaps = WyncUtils.find_closest_two_snapshots_from_prop(target_time, prop)

		if not snaps.size():
			Log.out(self, "lerppast NOTFOUND left: %s | target: %s | right: %s | curr: %s" % [0, target_time, 0, curr_time])
			continue
		
		var snap_left = snaps[0] as NetTickData
		var snap_right = snaps[1] as NetTickData

		# Log.out(self, "%s new_pos: %s | left: %s | target: %s | right: %s | curr: %s" % [snap_left.tick == snap_right.tick, new_pos, snap_left.timestamp, target_time, snap_right.timestamp, curr_time])

		# interpolate between the two

		var left_timestamp = snap_left.timestamp
		var right_timestamp = snap_right.timestamp
		
		if abs(left_timestamp - right_timestamp) < 0.000001:
			co_renderer.global_position = snap_right.data
		else:
			var left_pos = snap_left.data as Vector2
			var right_pos = snap_right.data as Vector2
			var factor = clampf(
				(float(target_time) - left_timestamp) / (right_timestamp - left_timestamp),
				0, 1)
			var new_pos = left_pos.lerp(right_pos, factor)
			co_renderer.global_position = new_pos
			
			Log.out(self, "leftardiff %s | left: %s | target: %s | right: %s | factor %s" % [target_time - left_timestamp, left_timestamp, target_time, right_timestamp, factor])
