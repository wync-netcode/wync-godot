class_name WyncPktClientSetLerpMS

var lerp_ms: int


func duplicate() -> WyncPktClientSetLerpMS:
	var i = WyncPktClientSetLerpMS.new()
	i.lerp_ms = lerp_ms
	return i
