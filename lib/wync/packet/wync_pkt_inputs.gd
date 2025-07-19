class_name WyncPktInputs

class NetTickDataDecorator:
	var tick: int
	var data # : any
	
	func duplicate() -> NetTickDataDecorator:
		var newi = NetTickDataDecorator.new()
		newi.tick = tick
		newi.data = WyncMisc.duplicate_any(data)
		return newi

var prop_id: int = -1 # inputs to which prop
var amount: int = 0
var inputs: Array[NetTickDataDecorator]


func duplicate() -> WyncPktInputs:
	var newi = WyncPktInputs.new()
	newi.prop_id = prop_id
	newi.amount = amount
	newi.inputs = [] as Array[NetTickDataDecorator]
	for input: NetTickDataDecorator in self.inputs:
		newi.inputs.append(input.duplicate())
	return newi

"""
# TODO: Use a different packet for event_ids
class_name WyncPktEvents

var prop_id: int
var tick_head: int
var amount: int
var inputs: Array[int]


func duplicate() -> WyncPktInputs:
	var newi = WyncPktInputs.new()
	newi.prop_id = self.prop_id
	newi.tick_head = self.tick_head
	newi.amount = self.amount
	newi.inputs = self.inputs.duplicate(true)
	return newi
"""
