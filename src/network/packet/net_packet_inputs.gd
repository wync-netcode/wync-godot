class_name NetPacketInputs

var prop_id: int = -1 # inputs to which prop
var amount: int = 0
var inputs: Array[CoActorInput]


func duplicate() -> NetPacketInputs:
	var newi = NetPacketInputs.new()
	newi.prop_id = prop_id
	newi.amount = amount
	newi.inputs = []
	for input in self.inputs:
		newi.inputs.append(input.copy())
	return newi
