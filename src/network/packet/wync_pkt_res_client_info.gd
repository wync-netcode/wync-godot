class_name WyncPacketResClientInfo

var entity_id: int # to validate the entity id exists
var prop_id: int


func duplicate() -> WyncPacketResClientInfo:
	var i = WyncPacketResClientInfo.new()
	i.entity_id = entity_id
	i.prop_id = prop_id
	return i
