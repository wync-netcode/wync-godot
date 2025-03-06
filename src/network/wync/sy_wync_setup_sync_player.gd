class_name SyWyncSetupSyncPlayer
extends System
const label: StringName = StringName("SyWyncSetupSyncPlayer")


# This function aims to setup synchronization info for entities

func _ready():
	components = [
		CoActor.label,
		CoCollider.label,
		CoActorInput.label,
		CoWyncEvents.label,
		CoActorRegisteredFlag.label,
		-CoFlagWyncEntityTracked.label,
		]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	UserWyncUtils.setup_entity_type(self, entity, GameInfo.ENTITY_TYPE_PLAYER)
		
	var co_actor = entity.get_component(CoActor.label) as CoActor
	Log.out("wync: Registered entity %s with id %s" % [entity, co_actor.id], Log.TAG_PROP_SETUP)
