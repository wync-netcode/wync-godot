class_name NetPacketInputs

class NetTickDataDecorator:
	var tick: int
	var data # : any
	
	func duplicate() -> NetTickDataDecorator:
		var newi = NetTickDataDecorator.new()
		newi.tick = tick
		if data is Object:
			if data.has_method("copy"):
				newi.data = data.copy()
			elif data.has_method("duplicate"):
				newi.data = data.duplicate()
		return newi

var prop_id: int = -1 # inputs to which prop
var amount: int = 0
var inputs: Array[NetTickDataDecorator]


func duplicate() -> NetPacketInputs:
	var newi = NetPacketInputs.new()
	newi.prop_id = prop_id
	newi.amount = amount
	newi.inputs = []
	for input in self.inputs:
		newi.inputs.append(input.duplicate())
	return newi
