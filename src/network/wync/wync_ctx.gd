class_name WyncCtx

const RELIABLE = true
const UNRELIABLE = false

## extrapolation service ??

# We can detect a local_tick is duplicated by checking is the same as te previous,
# Then we can honor the config wheter to allow duplication or not for each prop
var xtrap_is_local_tick_duplicated = false
var xtrap_prev_local_tick: Variant = null # Optional<int>
var xtrap_local_tick: Variant = null # Optional<int>


## user network info feed

var current_tick_nete_latency_ms: int

# other config

var physic_ticks_per_second: int = 60

## SUPERSEEDED?
## client only
## it's described in ticks between receiving updates from the server
## So, 3 would mean it's 1 update every 4 ticks. 0 means updates every tick.
var server_tick_rate: float = 0
var server_tick_rate_sliding_window: RingBuffer
var server_tick_rate_sliding_window_size: int = 10
var tick_last_packet_received_from_server: int = 0

## client only
## it's described in ticks between receiving updates from the server
## So, 3 would mean it's 1 update every 4 ticks. 0 means updates every tick.
var low_priority_entity_update_rate: float = 0
var low_priority_entity_update_rate_sliding_window: RingBuffer
var low_priority_entity_update_rate_sliding_window_size: int = 10
var low_priority_entity_tick_last_update: int = 0
const ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS = 699
var PROP_ID_PROB = -1

## outgoing packets =============================

const OK_BUT_COULD_NOT_FIT_ALL_PACKETS = 1

## can be used to limit the production of packets
var out_packets_size_limit: int 
var out_packets_size_remaining_chars: int 
var out_reliable_packets: Array[WyncPacketOut]
var out_unreliable_packets: Array[WyncPacketOut]

## Extra structures =============================

var co_ticks: CoTicks = CoTicks.new()
var co_predict_data: CoPredictionData = CoPredictionData.new()

## Server & Client ==============================

const SERVER_PEER_ID = 0
const ENTITY_ID_GLOBAL_EVENTS = 700
# NOTE: Rename to PRED_INPUT_BUFFER_SIZE
const INPUT_BUFFER_SIZE = 60 * 12
var max_amount_cache_events = 2 # it could be useful to have a different value for server cache
var max_peers = 24
var max_channels = 12
var max_tick_history = 60 # 1 second at 60 fps
var max_prop_relative_sync_history_ticks = 20 # set to 1 to see if it's working alright 
var max_delta_prop_predicted_ticks = 60 # 1000ms ping at 60fps 2000ms ping at 30fps

# how many ticks in the past to keep state cache for a regular prop
var REGULAR_PROP_CACHED_STATE_AMOUNT = 10

# Map<entity_id: int, unused_bool: bool>
var tracked_entities: Dictionary


const MAX_PROPS = 4096 # 2**16

# Array<prop_id: int, WyncEntityProp>
var props: Array[WyncEntityProp]

var prop_id_cursor: int

# SizedBufferList[int]
# Set[int]
var active_prop_ids: Array[int]


# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary

# User defined types, so that they can know what data types to sync
# Map<entity_id: int, entity_type_id: int>
var entity_is_of_type: Dictionary

# TODO: Separate generated events from CACHED events
# Map<event_id: uint, WyncEvent>
var events: Dictionary

var event_id_counter: int

# 24 clients, 12 channels, unlimited event ids
# Array[24 clients]< Array[12 channels] < Dictionary <int, unused_bool> > >
# events can be Dictionary (non-repeating set) or Array (allows duplicates)
# Array[Array[Array[int]]]
var peer_has_channel_has_events: Array[Array]


# event caching
# --------------------------------------------------------------------------------

# FIFOMap <event_data_hash: int, event_id: int>
var events_hash_to_id: FIFOMap = FIFOMap.new()

# Set <event_id: int>
#var events_sent: FIFOMap = FIFOMap.new()
# peers_events_sent: Array< peer_id: int, RingSet <event_id> >
var to_peers_i_sent_events: Array[FIFOMap]


# premature optimization?
# this solves deterministicly knowing where an event came from
# > What about just storing this metadata in the event wrapper?
# var entities_that_published_global_events_this_tick: Array[int]

# Array<delta_blueprint_id: int, Blueprint>
var delta_blueprints: Array[WyncDeltaBlueprint]

# how far in the past we can go
# Updated every frame, should correspond to current_tick - max_history_ticks
var delta_base_state_tick: int = -1


## Server only ==============================

# peer[0] = -1: it's reserved for the server
# List<client_id: int, any_data: int> # NOTE: Should be Ring
var peers: Array[int]

# Map<client_id: int, prop_id: Array[int]>
var client_owns_prop: Dictionary

# Stores client metadata
# Array<client_id: int, WyncClientInfo>
var client_has_info: Array

# used to know two things:
# 1. If a player has received info about this prop before
# 2. What was the Last tick we sent prop data (relative sync event) to a client
#    (Counts for both fullsnapshot and _delta events_)
#
# ctx.client_has_relative_prop_has_last_tick can only be modified on these events:
# 1. (On server) The server sends a fullsnapshot aka 'base state'
# 2. (On server) The client notifies the server about it (WYNC_PKT_DELTA_PROP_ACK)
# 3. (On client) When we receive a fullsnapshot
# 4. (On client) When we confidently apply a delta event forward
#
# Array[12] < client_id: int, Map<prop_id: int, tick: int> >
var client_has_relative_prop_has_last_tick: Array[Dictionary]
# each 10 frames and on prop creation. check for initialization
# each 1 frame. use it to send needed state

# TODO: use it to prevent applying _undo delta events_ of a range too broad that uses old values from the ring
# maybe it can be a single int that works for all predicted props
# var relative_prop_has_last_tick_predicted: Array[Dictionary]

# relative synchronization
# --------------------------------------------------------------------------------

#var peers_entities_to_sync
#var peers_props_to_sync

# TODO: DEPRECATE this data structure
# Array<client_id: int, ordered_set<event_id> >
var peers_events_to_sync: Array[Dictionary]


## Client only ==============================

## last tick received from the server
var last_tick_received: int

# Map<entity_id: int, sim_fun_id>
var entity_has_integrate_fun: Dictionary

# Array<prop_id: int>
var props_to_predict: Array[int]

var is_client: bool = false
var my_peer_id: int = -1
var my_nete_peer_id: int = -1

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

# This size should be the maximum amount of 'tick_offset' for prediction
var tick_action_history_size: int = 20

# did action already ran on tick?
# Ring < predicted_tick: int, Set <action_id: String> >
# RingBuffer < tick: int, Dictionary <action_id: String, unused_bool: bool> >
# RingBuffer [ Dictionary ]
var tick_action_history: RingBuffer = RingBuffer.new(tick_action_history_size)


# prediction
# --------------------------------------------------------------------------------

var currently_on_predicted_tick: bool = false
var current_predicted_tick: int = 0 # only for debugging

# tick markers for the prev prediction cycle
var first_tick_predicted: int = 1
var last_tick_predicted: int = 0
# markers for the current prediction cycle
var pred_intented_first_tick: int = 0

## how many ticks before 'last_tick_received' to predict to compensate for throttling
var max_prediction_tick_threeshold: int = 0

# throttling
# --------------------------------------------------------------------------------

class PeerEntityPair:
	var peer_id: int = -1
	var entity_id: int = -1

# Sync priorities:
# * VIP
# * Spawning
# * Despawning
# * Queue

# TODO
# Map <client_id: int, List[entity_id: int]>
#var vip_props: Map

# * Only add/remove _entity ids_ when a packet is confirmed sent (WYNC_EXTRACT_WRITE)
# * Confirmed list of entities the client sees
# Array <client_id: int, Set[entity_id: int]>
var clients_sees_entities: Array[Dictionary]
# Tener la garantía de que todo lo que está aquí se puede spawnear
# * Every frame we check.. 
# Array <client_id: int, Set[entity_id: int]>
var clients_sees_new_entities: Array[Dictionary]
# Array <client_id: int, Set[entity_id: int]>
var clients_no_longer_sees_entities: Array[Dictionary]

# Note: One may want to update this spawn data as the entity evolves over time
# Note: Spawn data should be small metadata just to setup an entity,
#       For big data use _delta props_
# Map <entity_id: int, data: Variant>
var entity_spawn_data: Dictionary

class PendingEntityToSpawn:
	var already_spawned: bool
	var entity_id: int
	var entity_type_id: int
	var spawn_data: Variant

## User facing var
## Client only
## List<PendingEntityToSpawn>
var out_pending_entities_to_spawn: Array[PendingEntityToSpawn]

# Internal list
# Map <entity_id: int, Tripla[prop_start: int, prop_end: int, curr: int]
var pending_entity_to_spawn_props: Dictionary

## Despawned entities
## List<entity_id: int>
var despawned_entity_ids: Array[int]

## User facing var
## Client only
## List<entity_id: int>
var out_pending_entities_to_despawn: Array[int]


## Queues

# * Only refill the queue once it's emptied
# * Queue entities for eventual synchronization
# Array <client_id: int, FIFORing[entity_id: int]>
var queue_clients_entities_to_sync: Array[FIFORing]

# Here, add what entities where synced last frame and to which client_id
# Array <client_id: int, Set[entity_id: int]>
var entities_synced_last_time: Array[Dictionary]

# * Recomputed each tick we gather out packets
# * TODO: Use FIFORing and preallocate all instances (pooling)
# FIFORing < PeerEntityPair[peer: int, entity: int] > [100]
var queue_entity_pairs_to_sync: Array[PeerEntityPair]

# dummy props
# --------------------------------------------------------------------------------

class DummyProp:
	var last_tick: int
	var data_size: int
	var data: Variant

# Map <prop_id: int, DummyProp*>
var dummy_props: Dictionary

## Stat
var stat_lost_dummy_props: int = 0

const MAX_DUMMY_PROP_TICKS_ALIVE: int = 100 # 1000

# debugging
# --------------------------------------------------------------------------------

# : Array <packet_id:int, Array <prop_id:int, amount: int> >
# : Array[Array[int]]
var debug_packets_received: Array[Array]

# mean of how much data is being transmitted each tick
var debug_data_per_tick_sliding_window_size: int = 10
var debug_data_per_tick_sliding_window: RingBuffer
var debug_data_per_tick_total_mean: float = 0
var debug_data_per_tick_sliding_window_mean: float = 0
var debug_data_per_tick_current: float = 0
var debug_ticks_sent: int = 0


# TODO: Move to WyncUtils
func _init() -> void:
	props.resize(MAX_PROPS)
	prop_id_cursor = 0
	active_prop_ids = []

	peer_has_channel_has_events.resize(max_peers)
	client_has_relative_prop_has_last_tick.resize(max_peers) # NOTE: index 0 not used

	queue_clients_entities_to_sync.resize(max_peers)
	queue_entity_pairs_to_sync.resize(100)

	clients_sees_entities.resize(max_peers)
	clients_sees_new_entities.resize(max_peers)
	clients_no_longer_sees_entities.resize(max_peers)
	entities_synced_last_time.resize(max_peers)

	for peer_i in range(max_peers):
		peer_has_channel_has_events[peer_i] = []
		peer_has_channel_has_events[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			peer_has_channel_has_events[peer_i][channel_i] = []
		client_has_relative_prop_has_last_tick[peer_i] = {}

		#if peer_i != WyncCtx.SERVER_PEER_ID:
		queue_clients_entities_to_sync[peer_i] = FIFORing.new()
		queue_clients_entities_to_sync[peer_i].init(100)
		clients_sees_entities[peer_i] = {}
		clients_sees_new_entities[peer_i] = {}
		clients_no_longer_sees_entities[peer_i] = {}
		entities_synced_last_time[peer_i] = {}
	
	for i in range(tick_action_history_size):
		tick_action_history.insert_at(i, {} as Dictionary)
	
	client_has_info.resize(max_peers)

	debug_packets_received.resize(WyncPacket.WYNC_PKT_AMOUNT)
	for i in range(WyncPacket.WYNC_PKT_AMOUNT):
		debug_packets_received[i] = [] as Array[int]
		debug_packets_received[i].resize(20) # amount of props, also 0 is reserved for 'total'

	debug_data_per_tick_sliding_window = RingBuffer.new(debug_data_per_tick_sliding_window_size)

	server_tick_rate_sliding_window = RingBuffer.new(server_tick_rate_sliding_window_size)

	low_priority_entity_update_rate_sliding_window = RingBuffer.new(low_priority_entity_update_rate_sliding_window_size)

	dummy_props = {}
		
