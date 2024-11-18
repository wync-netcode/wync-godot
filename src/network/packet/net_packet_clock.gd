class_name NetPacketClock

var tick: int
var time: int
var latency: int


func duplicate() -> NetPacketClock:
	var newi = NetPacketClock.new()
	newi.tick = tick
	newi.time = time
	newi.latency = latency
	return newi
