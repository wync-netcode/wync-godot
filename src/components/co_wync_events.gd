extends Component
class_name CoWyncEvents
static var label = ECS.add_component()

# We're using this Component for player subtick precision shooting events

# the last tick we polled for events, used to ensure only one event is sent per
# tick (otherwise we could generate multiples events each draw frame)
var last_tick_polled: int 

var prop_id: int = -1
var events: Array[int]
