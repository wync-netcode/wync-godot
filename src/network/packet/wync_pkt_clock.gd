class_name WyncPktClock

var tick: int
var time: int
var latency: int


func duplicate() -> WyncPktClock:
	var newi = WyncPktClock.new()
	newi.tick = tick
	newi.time = time
	newi.latency = latency
	return newi
