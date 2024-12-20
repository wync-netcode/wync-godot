class_name SyWyncSetupBallSync
extends System
const label: StringName = StringName("SyWyncSetupBallSync")


# NOTE: Register just the ball for now

func _ready():
	components = [CoActor.label, CoBall.label, CoActorRegisteredFlag.label, -CoFlagWyncEntityTracked.label]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_collider = entity.get_component(CoCollider.label) as CharacterBody2D
	
	# NOTE: Register just the ball for now
	
	WyncUtils.track_entity(wync_ctx, co_actor.id)
	WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func(): return co_collider.global_position,
		func(pos: Vector2): co_collider.global_position = pos,
	)
	
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out(self, "wync: Registered entity %s with id %s" % [entity, co_actor.id])
