class_name SyActorEvents
extends System
const label: StringName = StringName("SyActorEvents")
"""

## TIMEWARP IMPLEMENTATION REFERENCE

# server only function
static func handle_event_player_shoot(node_ctx: Node, event: WyncEvent.EventData, peer_id: int):
	
	pass

	#var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	#var ctx = single_wync.ctx as WyncCtx
	#var co_ticks = ctx.co_ticks
	
	## NOTE: peer_id shouldn't be 0 (the server's)
	#var client_info = ctx.client_has_info[peer_id] as WyncClientInfo
	
	#var lerp_ms: int = client_info.lerp_ms
	#var data = event.event_data as GameInfo.EventPlayerShoot
	#var tick_left: int = data.last_tick_rendered_left
	#var lerp_delta: float = data.lerp_delta
	
	## TODO: Lerp delta is not in this format
	#if lerp_delta < 0 || lerp_delta > 1000:
		#Log.errc(ctx, "TIMEWARP | lerp_delta is outside [0, 1] (%s)" % [lerp_delta], Log.TAG_TIMEWARP)
		#return

	## NOTE: We can provide some modes of security, this helps against cheaters:
	## * (1) Low. No limit, current implementation
	## * (2) Middle. Allow ticks in the range of the _prob prop rate_
	## * (1) High. Only allow ranges of 1 tick (the small range defined by the client's: latency + lerp_ms + last_packet_sent)
	#if ((tick_left <= co_ticks.ticks - ctx.max_tick_history) ||
		#(tick_left > co_ticks.ticks)
		#):
		#Log.errc(ctx, "timewarp | tick_left out of range (%s)" % [tick_left], Log.TAG_TIMEWARP)
		#return

	
	#Log.outc(ctx, "Client shoots at tick_left %d | lerp_delta %s | lerp_ms %s | tick_diff %s" % [ tick_left, lerp_delta, lerp_ms, co_ticks.ticks - tick_left ], Log.TAG_TIMEWARP)
	

	## ------------------------------------------------------------
	## time warp: reset all timewarpable props to a previous state, whilst saving their current state

	#var space := node_ctx.get_viewport().world_2d.space
	
	## 1. save current state
	## TODO: update saved state _only_ for selected props
	
	#WyncStateSend.extract_data_to_tick(ctx, co_ticks, co_ticks.ticks)
	
	#var prop_ids_to_timewarp: Array[int] = []
	#for prop_id: int in ctx.active_prop_ids:
		#var prop = WyncTrack.get_prop(ctx, prop_id)
		#if prop_id != 4: # ????
			#continue 
		#if prop == null:
			#continue
		#if not prop.timewarpable:
			#continue

		#prop_ids_to_timewarp.append(prop_id)

	## 2. set previous state
	
	#SyWyncLerp.confirmed_states_set_to_tick_interpolated(ctx, prop_ids_to_timewarp, tick_left, lerp_delta, co_ticks)

	## show debug trail
		
	#for prop_id: int in prop_ids_to_timewarp:
		#var prop = WyncTrack.get_prop(ctx, prop_id)
		#if prop == null:
			#continue
		#DebugPlayerTrail.spawn(node_ctx, prop.interpolated_state, 0.3, 2.5)
	
	## integrate physics

	#Log.outc(ctx, "entities to integrate state are %s" % [ctx.tracked_entities.keys()], Log.TAG_TIMEWARP)
	#WyncStateSet.integrate_state(ctx, ctx.tracked_entities.keys())
	#RapierPhysicsServer2D.space_step(space, 0)
	#RapierPhysicsServer2D.space_flush_queries(space)

	## 3. do my physics checks

	#var world_id = ECS.find_world_up(node_ctx).get_instance_id()
	#var sy_shoot_weapon_entities = ECS.get_system_entities(world_id, SyShootWeapon.label)
	#for entity in sy_shoot_weapon_entities:
		#Log.outc(ctx, "event,shoot | will process SyShootWeapon on entity %s" % [entity], Log.TAG_TIMEWARP)
		#SyShootWeapon.simulate_shoot_weapon(node_ctx, entity)
	
	## 4. restore original state

	#SyWyncLerp.confirmed_states_set_to_tick(ctx, prop_ids_to_timewarp, co_ticks.ticks, co_ticks)

	## integrate physics

	#WyncStateSet.integrate_state(ctx, ctx.tracked_entities.keys())
	#RapierPhysicsServer2D.space_step(space, 0)
	#RapierPhysicsServer2D.space_flush_queries(space)
"""
