extends Component
class_name CoClient
static var label = ECS.add_component()

enum STATE {
	DISCONNECTED,
	CONNECTED
}

var state: STATE = STATE.DISCONNECTED
var identifier: int = -1
var server_peer: int = -1  # key to actual peer

var last_synced_server_tick: int = 0
var last_synced_server_tick_timestamp: int = 0
