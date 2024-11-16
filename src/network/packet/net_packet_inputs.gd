class_name NetPacketInputs

var actor_id: int
var amount: int
var inputs: Array[CoActorInput]


func duplicate() -> NetPacketInputs:
	var newi = NetPacketInputs.new()
	newi.amount = amount
	newi.inputs = []
	for input in self.inputs:
		newi.inputs.append(input.copy())
	return newi
