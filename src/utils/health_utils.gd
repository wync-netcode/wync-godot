class_name HealthUtils


static func generate_health_damage_event(entity: Entity, damage: int, player_id: int):
	if not entity.has_component(CoHealth.label):
		return
	var health = entity.get_component(CoHealth.label) as CoHealth
	var event = CoHealthDamageEvent.new()
	event.damage = damage
	event.player_id = player_id
	health.damage_events.append(event)
