class_name SyWyncSetupSyncRocket
extends System
const label: StringName = StringName("SyWyncSetupSyncRocket")


# This function aims to setup synchronization info for entities

func _ready():
	components = [
		CoActor.label,
		CoProjectileData.label,
		CoActorRegisteredFlag.label,
		-CoFlagWyncEntityTracked.label]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
		
	var pro_data = entity.get_component(CoProjectileData.label) as CoProjectileData
	if not pro_data.alive:
		return
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var wync_entity_id = co_actor.id

	# setup existing entity
	
	UserWyncUtils.setup_entity_type(self, entity, GameInfo.ENTITY_TYPE_PROJECTILE)
	WyncThrottle.wync_everyone_now_can_see_entity(wync_ctx, wync_entity_id)
	var spawn_data = GameInfo.EntityProjectileSpawnData.new()
	spawn_data.weapon_id = pro_data.weapon_id
	WyncThrottle.wync_entity_set_spawn_data(wync_ctx, wync_entity_id, spawn_data, 0)

	# TODO: Server: On client connect setup these _map present_ entities
	#WyncThrottle.wync_add_local_existing_entity(wync_ctx, wync_ctx.my_peer_id, co_actor.id)
	
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out("wync: Registered entity %s with id %s" % [entity, co_actor.id], Log.TAG_PROP_SETUP)
