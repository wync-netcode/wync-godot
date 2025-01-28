class_name SyWyncSetupSyncBlockGrid
extends System
const label: StringName = StringName("SyWyncSetupSyncBlockGrid")


# This function aims to setup synchronization info for entities

func _ready():
	components = [
		CoActor.label,
		CoBlockGrid.label,
		CoActorRegisteredFlag.label,
		-CoFlagWyncEntityTracked.label
	]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	
	# TODO: Move this elsewhere
	# Setup random blocks on server
	if !WyncUtils.is_client(wync_ctx):
		co_block_grid.generate_random_blocks()
	
	WyncUtils.track_entity(wync_ctx, co_actor.id)
	var _pos_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"blocks",
		WyncEntityProp.DATA_TYPE.ANY,
		func() -> CoBlockGrid: return co_block_grid.make_duplicate(),
		func(block_grid: CoBlockGrid): co_block_grid.set_from_instance(block_grid),
	)
	
	# TODO: setup prediction
	
	if !WyncUtils.is_client(wync_ctx):
		pass
	
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out(self, "wync: Registered entity %s with id %s" % [entity, co_actor.id])
