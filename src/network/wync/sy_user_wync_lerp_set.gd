extends System
class_name SyUserWyncLerpSet
const label: StringName = StringName("SyUserWyncLerpSet")


## This system manually sets the interpolated position / rotation to the visual
## component

func _ready():
	components = [
		CoActor.label,
		CoActorRenderer.label,
		CoFlagWyncEntityTracked.label
	]
	super()
	

func on_process(entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# interpolate entities

	for entity: Entity in entities:

		var co_actor = entity.get_component(CoActor.label) as CoActor
		var co_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer

		# is prop interpolable (aka numeric, Vector2)

		if not WyncUtils.is_entity_tracked(wync_ctx, co_actor.id):
			continue
			
		var prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "position")
		if (prop != null
			&& prop.interpolated_state != null
			&& co_renderer is Node2D):
			co_renderer.global_position = prop.interpolated_state
			
			# simple
			DebugPlayerTrail.spawn(self, co_renderer.global_position, 0.5, 0, true)

			# long trail
			#DebugPlayerTrail.spawn(self, co_renderer.global_position, wync_ctx.co_ticks.lerp_delta_accumulator_ms / 1000.0, 1, false, -10)
				
		
		# 1. aim is currently interpolated by Wync
		# 2. apply this value to the visual Ball
		prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "aim")
		if (prop != null
			&& prop.interpolated_state != null
			&& co_renderer is Node2D):
			co_renderer.rotation = prop.interpolated_state
		
