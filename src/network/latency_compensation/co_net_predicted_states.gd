extends Component
class_name CoNetPredictedStates
const label = "conetpredictedstates"

var buffer: RingBuffer = RingBuffer.new(4) #:RingBuffer[NetTickData]
