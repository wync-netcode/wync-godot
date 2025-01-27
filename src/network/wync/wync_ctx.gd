class_name WyncCtx


## Server & Client ==============================

# Array<entity_id: int>
var tracked_entities: Array[int]

# Array<prop_id: int, WyncEntityProp>
var props: Array[WyncEntityProp]

# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary

# TODO: Separate generated events from CACHED events
# Map<event_id: uint, WyncEvent>
var events: Dictionary

# Set[event_id]
var events_to_sync_this_tick: Dictionary


## Server only ==============================

# Array<clients_id: int> # NOTE: Should be Ring
var clients: Array[int]

# Map<client_id: int, prop_id: Array[int]>
var client_owns_prop: Dictionary


## Client only ==============================

# Map<entity_id: int, sim_fun_id>
var entity_has_integrate_fun: Dictionary

# Array<prop_id: int>
var props_to_predict: Array[int]

var my_client_id: int

# Array<sim_fun_id: int, Callable>
# stores:
# (1) simulation functions: simulate physics
# (2) integrate functions: syncs entity transform with physic server 
var simulation_functions: Array[Callable]

# Map<entity_id: int, sim_fun_id>
var entity_has_simulation_fun: Dictionary

# Meta state / Managment
var connected: bool = false

# NOTE: Rename to PRED_INPUT_BUFFER_SIZE
const INPUT_BUFFER_SIZE = 60 * 12

var event_id_counter: int

const MAX_AMOUNT_CACHE_EVENTS = 2

# FIFOMap <event_data_hash: int, event_id: int>
var events_hash_to_id: FIFOMap = FIFOMap.new()

# Set <event_id: int>
var events_sent: FIFOMap = FIFOMap.new()
