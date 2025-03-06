extends System
class_name SyUserWyncSpawnActors
const label: StringName = StringName("SyUserWyncSpawnActors")

## This services poll _wync spawn events_
## It spawns _game actors_ and registers them to wync


func on_process(_entities, _data, _delta: float):
	var co_io = null # : CoIOPackets*
	
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if single_client:
		var co_client = single_client.get_component(CoClient.label) as CoClient
		if co_client.state != CoClient.STATE.CONNECTED:
			return
		co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
		if single_server:
			co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		Log.err("Couldn't find co_io_packets", Log.TAG_WYNC_CONNECT)

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	if ctx.out_pending_entities_to_spawn.size() <= 0:
		return

	for i in range(ctx.out_pending_entities_to_spawn.size()):

		var entity_to_spawn: WyncCtx.PendingEntityToSpawn = ctx.out_pending_entities_to_spawn[i]

		match entity_to_spawn.entity_type_id:

			GameInfo.ENTITY_TYPE_PROJECTILE:
				var spawn_data = entity_to_spawn.spawn_data as GameInfo.EntityProjectileSpawnData
				var entity = SyShootWeapon.launch_projectile(spawn_data.weapon_id, -1, self, Vector2.ZERO, 0)
				var err = SyActorRegister.register_actor(self, entity, entity_to_spawn.entity_id)
				assert(err == OK)
				UserWyncUtils.setup_entity_type(self, entity, GameInfo.ENTITY_TYPE_PROJECTILE)
				WyncUtils.finish_spawning_entity(ctx, entity_to_spawn.entity_id, i)

	# wync cleanup
	WyncFlow.wync_system_spawned_props_cleanup(ctx)
