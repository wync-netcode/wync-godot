class_name SyActorEvents
extends System
const label: StringName = StringName("SyActorEvents")


func _ready():
	components = [
		CoActor.label,
		CoWyncEvents.label
	]
	super()


func on_process(entities: Array, _data, _delta: float):
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	
	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
		
		for event_id in co_wync_events.events:
			
			# print events for now
			Log.out(self, "Entity %d did event %s" % [co_actor.id, event_id])
