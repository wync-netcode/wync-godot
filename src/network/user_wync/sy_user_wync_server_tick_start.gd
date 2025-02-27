class_name SyUserWyncServerTickStart
extends System
const label: StringName = StringName("SyUserWyncServerTickStart")

## Runs wync flow functions (tick start, tick end, etc)


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	# tick start
	WyncFlow.wync_server_tick_start(ctx)
	
	# for now, share all entities with all clients
	
	if Engine.get_physics_frames() % 10 == 0:

		var en_single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
		var co_actors = en_single_actors.get_component(CoSingleActors.label) as CoSingleActors

		for peer_id in range(1, ctx.peers.size()):
			for actor_id in range(co_actors.actors.size()):
				if co_actors.actors[actor_id] == null:
					continue

				# deleteme debug
				if actor_id == 3:
					continue

				WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, actor_id)
				WyncThrottle.wync_add_local_existing_entity(ctx, peer_id, actor_id)

