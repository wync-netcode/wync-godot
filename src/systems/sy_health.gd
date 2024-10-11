extends System
class_name SyHealth
const label: StringName = StringName("SyHealth")


func _ready():
	components = [CoHealth.label]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	var health = entity.get_component(CoHealth.label) as CoHealth

	if health.damage_events.size() > 0:
		for event: CoHealthDamageEvent in health.damage_events:
			health.health = max(0, health.health - event.damage)
			print("Damage event %s %s " % [event.damage, health.health])

			# handle death

			if health.health <= 0:
				print("Entity %s has died" % [entity])
				break

		health.damage_events.clear()
