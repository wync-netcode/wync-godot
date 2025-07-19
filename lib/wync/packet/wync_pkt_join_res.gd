class_name WyncPktJoinRes

var approved: bool = false
var wync_client_id: int = -1


func duplicate() -> WyncPktJoinRes:
	var i = WyncPktJoinRes.new()
	i.approved = approved
	i.wync_client_id = wync_client_id
	return i
