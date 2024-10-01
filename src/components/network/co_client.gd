extends Component
class_name CoClient
const label = "coclient"

enum STATE {
	DISCONNECTED,
	CONNECTED
}

var state: STATE = STATE.DISCONNECTED
var identifier: int = -1
var server_peer: int = -1  # key to actual peer
