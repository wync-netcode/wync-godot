class_name WyncPacket

enum {
	WYNC_PKT_JOIN_REQ,
	WYNC_PKT_JOIN_RES,
	WYNC_PKT_EVENT_DATA,
	WYNC_PKT_INPUTS,
	WYNC_PKT_PROP_SNAP,
	WYNC_PKT_RES_CLIENT_INFO,
	WYNC_PKT_CLOCK,
	WYNC_PKT_AMOUNT,
}

var packet_type_id: int # : WYNC_PKT
var size: int # unused here in gdscript
var data: Variant
