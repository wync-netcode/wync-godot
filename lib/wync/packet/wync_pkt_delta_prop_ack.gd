class_name WyncPktDeltaPropAck

## * Client -> Server
## * The client notifies the server what was the last update (tick) received
##   for all relative props that he knows about.
## * Send this aprox every 3 seconds

var prop_amount: int
var delta_prop_ids: Array[int]
var last_tick_received: Array[int]


func duplicate() -> WyncPktDeltaPropAck:
	var i = WyncPktDeltaPropAck.new()
	i.prop_amount = prop_amount
	i.delta_prop_ids = delta_prop_ids.duplicate(true)
	i.last_tick_received = last_tick_received.duplicate(true)
	return i
