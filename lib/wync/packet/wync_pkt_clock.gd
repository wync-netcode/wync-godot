class_name WyncPktClock

var tick: int # answerer's tick
var time: int # answerer's time
var tick_og: int # requester's tick
var time_og: int # requester's time


func duplicate() -> WyncPktClock:
	var newi = WyncPktClock.new()
	newi.tick = tick
	newi.time = time
	newi.tick_og = tick_og
	newi.time_og = time_og
	return newi
