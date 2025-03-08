extends Label

enum INFO {
	INFO_GENERAL,
	INFO_CLIENT_PACKET_LOG,
	INFO_SERVER_PACKET_LOG,
	INFO_PROPS,
}
@export var info_to_show: INFO = INFO.INFO_GENERAL

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS
@onready var lblMain: Label = self
# TODO: Use a service
@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback
@onready var co_wync_ctx_server: CoSingleWyncContext = %"CoSingleWyncContext-Server"
@onready var co_wync_ctx_client: CoSingleWyncContext = %"CoSingleWyncContext-Client"


func _process(_delta):
	
	match info_to_show:
		INFO.INFO_GENERAL:
			lblMain.text = get_info_general()
		INFO.INFO_CLIENT_PACKET_LOG:
			lblMain.text = get_info_packets_received_text(co_wync_ctx_client.ctx)
		INFO.INFO_SERVER_PACKET_LOG:
			lblMain.text = get_info_packets_received_text(co_wync_ctx_server.ctx)
		INFO.INFO_PROPS:
			lblMain.text = get_info_prop_identifiers(co_wync_ctx_server.ctx)


func get_info_general() -> String:
	var text = \
	"""PhysicsFPS: %s
	ScreenFPS: %s
	Latency: %s
	Latency_stable: %s
	tick_offset: %s
	lerp_ms: %s
	delta_base_tick: %s
	server_tick: %s
	(cl)target : %s
	server_data_per_tick_sliding: %s/t
	(cl)server_tick_rate %.2f (%.2f tps)
	(cl)prob_prop_rate %.2f
	(cl)dummy_props %s
	""" % \
	[
		Engine.physics_ticks_per_second,
		Performance.get_monitor(Performance.TIME_FPS),
		co_loopback.ctx.latency,
		co_wync_ctx_client.ctx.co_predict_data.latency_stable,
		co_wync_ctx_client.ctx.co_predict_data.tick_offset,
		co_wync_ctx_client.ctx.co_predict_data.lerp_ms,
		co_wync_ctx_server.ctx.delta_base_state_tick,
		co_wync_ctx_server.ctx.co_ticks.ticks,
		co_wync_ctx_client.ctx.co_predict_data.target_tick,
		co_wync_ctx_server.ctx.debug_data_per_tick_sliding_window_mean,
		co_wync_ctx_client.ctx.server_tick_rate,
		((1.0 / (co_wync_ctx_client.ctx.server_tick_rate + 1)) * Engine.physics_ticks_per_second),
		co_wync_ctx_client.ctx.low_priority_entity_update_rate,
		co_wync_ctx_client.ctx.dummy_props.size()
	]
	return text


static func get_info_packets_received_text(ctx: WyncCtx) -> String:
	var name_length = 10
	var number_length = 4

	var prop_amount = 19
	var text = ""
	var prefix = "client_%s" % [ctx.my_peer_id] if WyncUtils.is_client(ctx) else "server"

	text += prefix + " Received \n"
	text += string_exact_length("", name_length) + " "
	text += string_exact_length("Tot", number_length)
	for j in range(prop_amount -1):
		text += string_exact_length(str(j), number_length)

	for packet_type_id in range(WyncPacket.WYNC_PKT_AMOUNT):
		text += "\n"
		text += string_exact_length(WyncPacket.PKT_NAMES[packet_type_id], name_length) + " "

		var history = ctx.debug_packets_received[packet_type_id] as Array[int]
		for j in range(prop_amount):
			text += str(history[j]).rpad(number_length)

	return text


static func get_info_prop_identifiers(ctx: WyncCtx) -> String:
	var text = ""

	for entity_id in ctx.tracked_entities.keys():

		for i in ctx.entity_has_props[entity_id]:
			var prop := WyncUtils.get_prop(ctx, i)
			if prop == null:
				continue
			text += "%s %s %s\n" % [
				string_exact_length(str(entity_id), 3),
				string_exact_length(str(i), 3),
				prop.name_id,
			]

	return text


static func string_exact_length(stri: String, length: int) -> String:
	if stri.length() > length:
		#return stri.substr(0, length)
		return stri.substr(stri.length() - length, length)
	elif stri.length() < length:
		return stri.rpad(length)
	return stri
