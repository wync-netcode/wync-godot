extends Component
class_name CoServer
const label = "coserver"

## Keeps track of client peers

enum STATE {
	STOPPED,
	STARTED
}

class ServerPeer:
	var identifier: int
	var peer_id: int # key to actual peer

var state: STATE = STATE.STARTED
var peers: Array[ServerPeer]
var peer_count: int = 0

# TODO: Define update rate
