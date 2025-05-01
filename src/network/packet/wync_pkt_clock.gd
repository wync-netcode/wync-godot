class_name WyncPktClock

var tick: int
var time: int # answer time
var time_og: int # request time


func duplicate() -> WyncPktClock:
	var newi = WyncPktClock.new()
	newi.tick = tick
	newi.time = time
	newi.time_og = time_og
	return newi
