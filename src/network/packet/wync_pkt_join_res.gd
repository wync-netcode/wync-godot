class_name WyncPktJoinRes

var approved: bool


func duplicate() -> WyncPktJoinRes:
	var i = WyncPktJoinRes.new()
	i.approved = approved
	return i
