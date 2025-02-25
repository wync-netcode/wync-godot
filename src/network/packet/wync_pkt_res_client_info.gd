class_name WyncPktResClientInfo

var entity_id: int # to validate the entity id exists
var prop_id: int


func duplicate() -> WyncPktResClientInfo:
	var i = WyncPktResClientInfo.new()
	i.entity_id = entity_id
	i.prop_id = prop_id
	return i
