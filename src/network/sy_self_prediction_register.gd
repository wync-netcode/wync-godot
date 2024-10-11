class_name SySelfPredictionRegister
extends System
const label: StringName = StringName("SySelfPredictionRegister")

## Registers actors that will be predicted
## This could be done in other ways, however,
## that touches the realm of _entity management_ from _state synchronization_


func _ready():
	components = [CoActor.label, CoActorRegisteredFlag.label, CoSelfPredicted.label, -CoSelfPredictedRegistered.label]
	super()


func on_process(entities: Array[Entity], _data, _delta: float):
	
	var co_single_self_predicted_actors = ECS.get_singleton_component(self, CoSingleSelfPredictedActors.label) as CoSingleSelfPredictedActors

	for entity in entities:
		var co_actor = entity.get_component(CoActor.label) as CoActor

		co_single_self_predicted_actors.actors[co_actor.id] = Entity
		co_single_self_predicted_actors.actor_snapshots[co_actor.id] = []

		var flag = CoSelfPredictedRegistered.new()
		ECS.entity_add_component_node(entity, flag)
