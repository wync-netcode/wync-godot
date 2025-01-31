class_name WyncCtx


## Server & Client ==============================

const ENTITY_ID_GLOBAL_EVENTS = 777
const MAX_GLOBAL_EVENT_CHANNELS = 1

# Map<entity_id: int, unused_bool: bool>
var tracked_entities: Dictionary

# Array<prop_id: int, WyncEntityProp>
var props: Array[WyncEntityProp]

# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary

# TODO: Separate generated events from CACHED events
# Map<event_id: uint, WyncEvent>
var events: Dictionary

# Set[event_id]
var events_to_sync_this_tick: Dictionary

# Array<channel_id: int, Array<event_id>>
# Array[Array[int]]
# global_events_channel_in_order
var global_events_channel: Array[Array] 

# this solves deterministicly knowing where an event came from
# > What about just storing this metadata in the event wrapper?
var entities_that_published_global_events_this_tick: Array[int]


## Server only ==============================

# peer[0] = -1: it's reserved for the server
# Array<client_id: int> # NOTE: Should be Ring
var peers: Array[int]

# Map<client_id: int, prop_id: Array[int]>
var client_owns_prop: Dictionary


## Client only ==============================

# Map<entity_id: int, sim_fun_id>
var entity_has_integrate_fun: Dictionary

# Array<prop_id: int>
var props_to_predict: Array[int]

var my_peer_id: int = -1

# Array<sim_fun_id: int, Callable>
# stores:
# (1) simulation functions: simulate physics
# (2) integrate functions: syncs entity transform with physic server 
var simulation_functions: Array[Callable]

# DEPRECATED
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
