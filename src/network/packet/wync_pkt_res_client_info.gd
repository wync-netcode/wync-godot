class_name WyncPktResClientInfo

var peer_id: int
var entity_id: int # to validate the entity id exists, unused?
var prop_id: int


func duplicate() -> WyncPktResClientInfo:
	var i = WyncPktResClientInfo.new()
	i.peer_id = peer_id
	i.entity_id = entity_id
	i.prop_id = prop_id
	return i
