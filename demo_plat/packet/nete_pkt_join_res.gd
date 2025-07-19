class_name NetePktJoinRes

var approved: bool = false
var identifier: int = -1


func duplicate() -> NetePktJoinRes:
	var i = NetePktJoinRes.new()
	i.approved = approved
	i.identifier = identifier
	return i
