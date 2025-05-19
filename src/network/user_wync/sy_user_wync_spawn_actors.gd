extends System
class_name SyUserWyncSpawnActors
const label: StringName = StringName("SyUserWyncSpawnActors")

## This services poll _wync spawn events_
## It spawns _game actors_ and registers them to wync


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	if ctx.out_pending_entities_to_despawn.size() > 0:
		despawn_actors(ctx)
	if ctx.out_pending_entities_to_spawn.size() > 0:
		spawn_actors(ctx)


func spawn_actors(ctx: WyncCtx):

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


func despawn_actors(ctx: WyncCtx):

	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	for entity_id: int in ctx.out_pending_entities_to_despawn:

		# try to find the entity
		if entity_id >= co_actors.max_actors:
			continue

		var entity = co_actors.actors[entity_id]
		if entity == null:
			continue

		# free it

		ECS.remove_entity(entity)
		SyActorRegister.remove_actor(self, entity_id)

	WyncFlow.wync_clear_entities_pending_to_despawn(ctx)
