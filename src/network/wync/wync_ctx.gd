class_name WyncCtx


## Server & Client ==============================

const ENTITY_ID_GLOBAL_EVENTS = 777
var max_peers = 24
var max_channels = 12

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
# var global_events_channel: Array[Array]

# 24 clients, 12 channels, unlimited event ids
# Array[24 clients]< Array[12 channels] < Dictionary <int, unused_bool> > >
# events can be Dictionary (non-repeating set) or Array (allows duplicates)
# Array[Array[Array[int]]]
var peer_has_channel_has_events: Array[Array]

# premature optimization?
# this solves deterministicly knowing where an event came from
# > What about just storing this metadata in the event wrapper?
# var entities_that_published_global_events_this_tick: Array[int]


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

# This size should be the maximum amount of 'tick_offset' for prediction
var tick_action_history_size: int = 20

# did action already ran on tick?
# Ring < predicted_tick: int, Set <action_id: String> >
# RingBuffer < tick: int, Dictionary <action_id: String, unused_bool: bool> >
# RingBuffer [ Dictionary ]
var tick_action_history: RingBuffer = RingBuffer.new(tick_action_history_size)


# TODO: Move to WyncUtils
func _init() -> void:
	peer_has_channel_has_events.resize(max_peers)
	for peer_i in range(max_peers):
		peer_has_channel_has_events[peer_i] = []
		peer_has_channel_has_events[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			peer_has_channel_has_events[peer_i][channel_i] = []
	
	for i in range(tick_action_history_size):
		tick_action_history.insert_at(i, {} as Dictionary)
