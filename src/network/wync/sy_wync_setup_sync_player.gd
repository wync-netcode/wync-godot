class_name SyWyncSetupSyncPlayer
extends System
const label: StringName = StringName("SyWyncSetupSyncPlayer")


# This function aims to setup synchronization info for entities

func _ready():
	components = [
		CoActor.label,
		CoCollider.label,
		CoActorInput.label,
		CoActorRegisteredFlag.label, -CoFlagWyncEntityTracked.label,
		]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	
	var single_world = ECS.get_singleton_component(self, CoSingleWorld.label) as CoSingleWorld
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_collider = entity.get_component(CoCollider.label) as CharacterBody2D
	var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
	
	# NOTE: Register just the ball for now
	
	WyncUtils.track_entity(wync_ctx, co_actor.id)
	var pos_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func(): return co_collider.global_position,
		func(pos: Vector2): co_collider.global_position = pos,
	)
	var vel_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"velocity",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func(): return co_collider.velocity,
		func(vel: Vector2): co_collider.velocity = vel,
	)
	var input_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"input",
		WyncEntityProp.DATA_TYPE.INPUT,
		func(): return co_actor_input.copy(),
		func(input: CoActorInput): input.copy_to_instance(co_actor_input),
	)
	
	# setup extrapolation
	
	if is_client(single_world):
		var sim_fun_id = WyncUtils.register_function(wync_ctx, SyBallMovement.simulate_movement)
		if sim_fun_id < 0:
			Log.err(self, "Couldn't register sim fun")
		else:
			WyncUtils.entity_set_sim_fun(wync_ctx, co_actor.id, sim_fun_id)
		
		var int_fun_id = WyncUtils.register_function(wync_ctx, co_collider.force_update_transform)
		if int_fun_id < 0:
			Log.err(self, "Couldn't register integrate fun")
		else:
			WyncUtils.entity_set_integration_fun(wync_ctx, co_actor.id, int_fun_id)
			
		WyncUtils.prop_set_predict(wync_ctx, pos_prop_id)
		WyncUtils.prop_set_predict(wync_ctx, vel_prop_id)
	
	# is server
	else:
		
		var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
		if not single_server:
			print("E: Couldn't find singleton EnSingleServer")
			return
		var co_io_packets = single_server.get_component(CoIOPackets.label) as CoIOPackets
		var co_server = single_server.get_component(CoServer.label) as CoServer
		
		# FIXME
		"""
		var client_id = 0
		WyncUtils.prop_set_client_owner(wync_ctx, input_prop_id, client_id)
		var pkt_client_owns = WyncPacketClientOwnsProp.new()
		pkt_client_owns.entity_id = co_actor.id
		pkt_client_owns.prop_id = input_prop_id
		
		# submit packets to deliver

		for peer: CoServer.ServerPeer in co_server.peers:
			if peer.peer_id != client_id:
				continue
			var pkt = NetPacket.new()
			pkt.to_peer = peer.peer_id
			pkt.data = pkt_client_owns.duplicate()
			co_io_packets.out_packets.append(pkt)"""

		
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out(self, "wync: Registered entity %s with id %s" % [entity, co_actor.id])
	

func is_client(single_world: CoSingleWorld) -> bool:
	return single_world.world_id != 0
