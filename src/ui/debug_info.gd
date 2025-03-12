extends Label
class_name DynamicDebugInfo

enum INFO {
	INFO_FPS,
	INFO_GENERAL,
	INFO_CLIENT_PACKET_LOG,
	INFO_SERVER_PACKET_LOG,
	INFO_PROPS_SERVER,
	INFO_PROPS_CLIENT,
}
@export var info_to_show: INFO = INFO.INFO_GENERAL
@export var enabled: bool = true
@onready var lblMain: Label = self

var initialized := false
var loopback_ctx: Loopback.Context = null
var server_wctx: WyncCtx = null
var client_wctx: WyncCtx = null


func _ready() -> void:
	if not enabled:
		self.queue_free()


func initialize(loopback_ctx: Loopback.Context, server_wctx: WyncCtx, client_wctx: WyncCtx):
	self.loopback_ctx = loopback_ctx
	self.server_wctx = server_wctx
	self.client_wctx = client_wctx
	self.initialized = true


func _physics_process(_delta: float) -> void:
	if not initialized:
		return
	if WyncUtils.fast_modulus(Engine.get_physics_frames(), 2) != 0:
		return
	match info_to_show:
		INFO.INFO_FPS:
			lblMain.text = str(Performance.get_monitor(Performance.TIME_FPS))
		INFO.INFO_GENERAL:
			lblMain.text = get_info_general()
		INFO.INFO_CLIENT_PACKET_LOG:
			lblMain.text = get_info_packets_received_text(client_wctx)
		INFO.INFO_SERVER_PACKET_LOG:
			lblMain.text = get_info_packets_received_text(server_wctx)
		INFO.INFO_PROPS_SERVER:
			lblMain.text = get_info_prop_identifiers(server_wctx)
		INFO.INFO_PROPS_CLIENT:
			lblMain.text = get_info_prop_identifiers(client_wctx)


func get_info_general() -> String:
	var text = \
	"""PhysicsFPS: %s
	ScreenFPS: %s
	Latency: %s jit(%sms) loss(%s%%)
	Latency_stable: %s
	tick_offset: %s
	ticks_predi: %s
	lerp_ms: %s
	delta_base_tick: %s
	  server_tick: %s
	(cl)rver_tick: %s (d %s)
	(cl)target : %s
	client_tick: %s
	server_rate_out: %s/t
	client_rate_out: %s/t
	(cl)server_tick_rate %.2f (%.2f tps)
	(cl)prob_prop_rate %.2f
	(cl)dummy_props %s (lost %s)
	""" % \
	[
		Engine.physics_ticks_per_second,
		Performance.get_monitor(Performance.TIME_FPS),
		string_exact_length(str(loopback_ctx.latency), 3),
		string_exact_length(str(loopback_ctx.jitter), 3),
		string_exact_length(str(loopback_ctx.packet_loss_percentage), 3),
		client_wctx.co_predict_data.latency_stable,
		client_wctx.co_predict_data.tick_offset,
		(client_wctx.last_tick_predicted -client_wctx.first_tick_predicted),
		client_wctx.co_predict_data.lerp_ms,
		server_wctx.delta_base_state_tick,
		server_wctx.co_ticks.ticks,
		client_wctx.co_ticks.server_ticks,
		client_wctx.co_ticks.server_ticks -server_wctx.co_ticks.ticks, 
		client_wctx.co_predict_data.target_tick,
		client_wctx.co_ticks.ticks,
		server_wctx.debug_data_per_tick_sliding_window_mean,
		client_wctx.debug_data_per_tick_sliding_window_mean,
		client_wctx.server_tick_rate,
		((1.0 / (client_wctx.server_tick_rate + 1)) * Engine.physics_ticks_per_second),
		client_wctx.low_priority_entity_update_rate,
		client_wctx.dummy_props.size(), client_wctx.stat_lost_dummy_props
	]
	return text


static func get_info_packets_received_text(ctx: WyncCtx) -> String:
	var name_length = 10
	var number_length = 4

	var prop_amount = 20
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
