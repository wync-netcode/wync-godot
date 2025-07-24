class_name WyncCtx

const SERVER_TICK_OFFSET_COLLECTION_SIZE := 4


var ticks: int

class CoTicks: ## Clock?
	#var ticks: int

	# for "debug_tick_offset" just set ctx.co_ticks.ticks to any value
	var debug_time_offset_ms: int

	var server_ticks: int

	## Strategy for getting a stable server_tick_offset value:
	## We have a list of of common values and their count
	## value | percentage
	## -199  | 212
	## -201  | 98
	## -202  | 13
	## Then we just pick the most common one, if we encounter
	## a new value just replace the one with less count. Also, there shouldn't
	## be fight between two adyacent values (e.g. -199 & -200) because the
	## code for picking a value prevents fluctuation of one unit

	## Strategy for more accurate stable latency calculation.
	## TODO: Since the main use of this stable latency is to convert this time
	## into the equivalente ticks, then better to constantly update stable 
	## latency and use the previous strategy to slowly update the tick number.
	## Trying to have the tick be always bigger (ceil).
	## TLDR: stabilize tick amount instead of latency.
	
	## List<Tuple<int, int>>
	## Array[Array[Variant]]
	var server_tick_offset_collection: Array[Array]
	var server_tick_offset: int

	# TODO: Move this elsewhere
	# used to (1) lerp and (2) time warp
	var lerp_delta_accumulator_ms: float
	var last_tick_rendered_left: int
	var minimum_lerp_fraction_accumulated_ms: float


class CoPredictionData:

	# periodical vars
	
	## to get target_time add this to curr_time -> curr_time + tick_offset * fixed_step
	var tick_offset: int = 0
	var tick_offset_prev: int = 0
	var tick_offset_desired: int = 0
	var target_tick: int = 0 # co_ticks.ticks + tick_offset
	## fixed timestamp for current tick
	## It's the point of reference for other ticks
	var current_tick_timestamp: float = 0
	
	# For calculating clock_offset_mean
	# TODO: Move this to co_ticks
	
	var clock_offset_sliding_window: RingBuffer = null
	var clock_offset_sliding_window_size: int = 16
	var clock_offset_mean: float
	
	# Interpolation data
	# TODO: Move this elsewhere
	
	var lerp_ms: int = 50
	var lerp_latency_ms: int = 0


class NetTickData:

	var server_tick: int
	var arrived_at_tick: int ## local tick
	var data#: Any

	func copy() -> NetTickData:
		var new_instance = NetTickData.new()
		new_instance.server_tick = server_tick
		new_instance.arrived_at_tick = arrived_at_tick
		new_instance.data = data
		if data is Object && data.has_method("copy"):
			new_instance.data = data.copy()
		return new_instance


## user network info feed

const LATENCY_BUFFER_SIZE: int = 20 ## 20 size, 2 polls per second -> 10 seconds worth
class PeerLatencyInfo:
	var latency_raw_latest_ms: int ## Recently polled latency
	var latency_stable_ms: int ## Stabilized latency
	var latency_mean_ms: int
	var latency_std_dev_ms: int
	var latency_buffer: Array[int]
	var latency_buffer_head: int
	var debug_latency_mean_ms: float

class WyncClientInfo:
	var lerp_ms: int

	func _init() -> void:
		lerp_ms = 200

## throttling

class PeerEntityPair:
	var peer_id: int = -1
	var entity_id: int = -1

class PeerPropPair:
	var peer_id: int = -1
	var prop_id: int = -1


class EntitySpawnEvent:
	var spawn: bool  ## wheter to spawn or to dispawn
	var already_spawned: bool
	var entity_id: int
	var entity_type_id: int
	var spawn_data: Variant


class DummyProp:
	var last_tick: int
	var data_size: int
	var data: Variant


# NOTE: Do not confuse with WyncPktEventData.EventData
# TODO: define data types somewhere + merge with WyncProp

class WyncEventEventData:
	var event_type_id: int
	var event_data: Variant
	# var event_size?: int # first compare size before comparing data

	func duplicate() -> WyncEventEventData:
		var newi = WyncEventEventData.new()
		newi.event_type_id = event_type_id
		newi.event_data = WyncMisc.duplicate_any(event_data)
		return newi


class WyncEvent:

	var data: WyncEventEventData
	var data_hash: int # used to avoid sending duplicates

	func _init() -> void:
		data = WyncEventEventData.new()


## --------------------------------------------------------
## Wrapper
## --------------------------------------------------------
## Only populated if in C/C++; other languages require
## a separate wrapper.


var wrapper: WyncWrapperStructs.WyncWrapperCtx

var co_ticks: CoTicks = CoTicks.new()
var co_predict_data: CoPredictionData = CoPredictionData.new()


## --------------------------------------------------------
## Extrapolation / Prediction
## --------------------------------------------------------

## last tick received from the server
var last_tick_received: int

# Array<prop_id: int>
# Note: Could be replace by a simple flag in WyncProp
var props_to_predict: Array[int]

var currently_on_predicted_tick: bool = false
var current_predicted_tick: int = 0 # only for debugging

# tick markers for the prev prediction cycle
var first_tick_predicted: int = 1
var last_tick_predicted: int = 0
# markers for the current prediction cycle
var pred_intented_first_tick: int = 0

# user facing variable, tells the user which entities are safe to predict this tick
var global_entity_ids_to_predict: Array[int] = []

## how many ticks before 'last_tick_received' to predict to compensate for throttling
## * Limited by REGULAR_PROP_CACHED_STATE_AMOUNT
## TODO: rename
var max_prediction_tick_threeshold: int = 0

# to know if we should extrapolate from the beggining (last received tick) or continue (this implies not getting packets)
# TODO: rename

var last_tick_received_at_tick: int
var last_tick_received_at_tick_prev: int


var entity_last_predicted_tick: Dictionary[int, int] = {}
var entity_last_received_tick: Dictionary[int, int] = {}
var predicted_entity_ids: Array[int] = []


## --------------------------------------------------------
## Single time predicted Action
## --------------------------------------------------------
## E.g. shooting sound

# This size should be the maximum amount of 'tick_offset' for prediction
var tick_action_history_size: int = 32

# did action already ran on tick?
# Ring < predicted_tick: int, Set <action_id: String> >
# RingBuffer < tick: int, Dictionary <action_id: String, unused_bool: bool> >
# RingBuffer [ Dictionary ]
var tick_action_history: RingBuffer = RingBuffer.new(tick_action_history_size, {})




## --------------------------------------------------------
## General Settings
## --------------------------------------------------------

var physic_ticks_per_second: int = 60

## --------------------------------------------------------
## Server Settings
## --------------------------------------------------------


## --------------------------------------------------------
## Client Settings
## --------------------------------------------------------

# MAYBEDO: use ms as magnitud
var max_lerp_factor_symmetric: float


## --------------------------------------------------------
## Statistics / Metrics
## --------------------------------------------------------


# : Array <packet_id:int, Array <prop_id:int, amount: int> >
# : Array[Array[int]]
var debug_packets_received: Array[Array]

# mean of how much data is being transmitted each tick
var debug_data_per_tick_sliding_window_size: int = 8
var debug_data_per_tick_sliding_window: RingBuffer
var debug_data_per_tick_total_mean: float = 0
var debug_data_per_tick_sliding_window_mean: float = 0
var debug_data_per_tick_current: float = 0
var debug_ticks_sent: int = 0

var debug_lerp_prev_curr_time: float
var debug_lerp_prev_target: float


## (client only)
## it's described in ticks between receiving updates from the server
## So, 3 would mean it's 1 update every 4 ticks. 0 means updates every tick.
var server_tick_rate: float = 0
var server_tick_rate_sliding_window: RingBuffer
const SERVER_TICK_RATE_SLIDING_WINDOW_SIZE: int = 8
var tick_last_packet_received_from_server: int = 0


## (client only)
## it's described in ticks between receiving updates from the server
## So, 3 would mean it's 1 update every 4 ticks. 0 means updates every tick.
var low_priority_entity_update_rate: float = 0
var low_priority_entity_update_rate_sliding_window: RingBuffer
var low_priority_entity_update_rate_sliding_window_size: int = 8
var low_priority_entity_tick_last_update: int = 0
const ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS = 699
var PROP_ID_PROB = -1


## --------------------------------------------------------
## Outgoing packets
## --------------------------------------------------------

const RELIABLE = true
const UNRELIABLE = false
const OK_BUT_COULD_NOT_FIT_ALL_PACKETS = 1

## can be used to limit the production of packets
var out_packets_size_limit: int 
var out_packets_size_remaining_chars: int 
var out_reliable_packets: Array[WyncPacketOut]
var out_unreliable_packets: Array[WyncPacketOut]

## temporary snapshot cache for later packet size optimization
## Array < client_id: int, DynArr < WyncPacket > >
var clients_cached_reliable_snapshots: Array[Array] = []
var clients_cached_unreliable_snapshots: Array[Array] = []


## --------------------------------------------------------
## Peer Management
## --------------------------------------------------------

const SERVER_PEER_ID = 0

var max_peers = 4

# peer[0] = -1: it's reserved for the server
# List<wync_peer_id: int, nete_peer_id: int> # NOTE: Should be Ring
var peers: Array[int]

# Array[12] <peer_id: int, PeerLatencyInfo>
var peer_latency_info: Array[PeerLatencyInfo]

# Note: Might want to merge with PeerLatencyInfo
# Stores client metadata
# Array<client_id: int, WyncClientInfo>
var client_has_info: Array

var is_client: bool = false

## --------------------------------------------------------
## Client Only??
## --------------------------------------------------------

var my_peer_id: int = -1
var my_nete_peer_id: int = -1
var connected: bool = false
var _prev_connected: bool = false



## --------------------------------------------------------
## Inputs / Events
## --------------------------------------------------------

const ENTITY_ID_GLOBAL_EVENTS = 700
# NOTE: Rename to PRED_INPUT_BUFFER_SIZE
const INPUT_BUFFER_SIZE = 2 ** 10 ## 1024
const INPUT_AMOUNT_TO_SEND = 20   # TODO: Make configurable
var max_amount_cache_events = 1000 # it could be useful to have a different value for server cache

var max_channels = 12
var max_prop_relative_sync_history_ticks = 20 # set to 1 to see if it's working alright 
var max_age_user_events_for_consumption = 120 # almost two seconds TODO: separate variables per client/server


## --------------------------------------------------------
## Timewarp
## --------------------------------------------------------

var max_tick_history_timewarp = 2**7 # must be a power of two, 64 ~= 1 second at 60 tps


## --------------------------------------------------------
## State tracking
## --------------------------------------------------------

const MAX_PROPS = 4096 # default to 2**16 (65536)

# how many ticks in the past to keep state cache for a regular prop
var REGULAR_PROP_CACHED_STATE_AMOUNT = 8

# Map<wync_entity_id: int, unused_bool: bool>
var tracked_entities: Dictionary[int, bool]

var prop_id_cursor: int

# Array<prop_id: int, WyncProp>
var props: Array[WyncProp]

# SizedBufferList[int]
# Set[int]
var active_prop_ids: Array[int]

# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary

# User defined types, so that they can know what data types to sync
# Map<entity_id: int, entity_type_id: int>
# TODO: Rename to make clear this is user data
var entity_is_of_type: Dictionary

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
# each 10 frames and on prop creation. check for initialization, TODO: Where?
# each 1 frame. use it to send needed state


## (client only)
## Dummy Props: Used to hold state for a prop not yet present;
## If too much time passes it will be discarded

# Map <prop_id: int, DummyProp*>
var dummy_props: Dictionary

## Stat
var stat_lost_dummy_props: int = 0

const MAX_DUMMY_PROP_TICKS_ALIVE: int = 100 # 1000


## --------------------------------------------------------
## Events
## --------------------------------------------------------

# TODO: Separate generated events from CACHED events
# Map<event_id: uint, WyncEvent>
var events: Dictionary[int, WyncCtx.WyncEvent]

var event_id_counter: int

# 24 clients, 12 channels, unlimited event ids
# Array[24 clients]< Array[12 channels] < Dictionary <int, unused_bool> > >
# events can be Dictionary (non-repeating set) or Array (allows duplicates)
# Array[Array[Array[int]]]
var peer_has_channel_has_events: Array[Array]

## TODO: Rename all the table-like containers
## Array< peer_id: int, Array< channel: int, prop_id: prop_id > >
var prop_id_by_peer_by_channel: Array[Array]


## --------------------------------------------------------
## Event caching
## --------------------------------------------------------

# FIFOMap <event_data_hash: int, event_id: int>
var events_hash_to_id: FIFOMap = FIFOMap.new()

# Set <event_id: int>
#var events_sent: FIFOMap = FIFOMap.new()
# peers_events_sent: Array< peer_id: int, RingSet <event_id> >
var to_peers_i_sent_events: Array[FIFOMap]

# how far in the past we can go
# Updated every frame, should correspond to current_tick - max_history_ticks
var delta_base_state_tick: int = -1


## --------------------------------------------------------
## Client Authority
## --------------------------------------------------------

# Map<client_id: int, prop_id: Array[int]>
# TODO: change to array
var client_owns_prop: Dictionary

var client_ownership_updated: bool


## --------------------------------------------------------
## Relative synchronization
## --------------------------------------------------------

# Array<client_id: int, ordered_set<event_id> >
var peers_events_to_sync: Array[Dictionary]



## --------------------------------------------------------
## Prop ID caching - Server
## --------------------------------------------------------

var was_any_prop_added_deleted: bool
var filtered_clients_input_and_event_prop_ids: Array[int] = []
var filtered_delta_prop_ids: Array[int] = [] # client & server
var filtered_regular_extractable_prop_ids: Array[int] = []
var filtered_regular_timewarpable_prop_ids: Array[int] = [] # either interpolable or not
var filtered_regular_timewarpable_interpolable_prop_ids: Array[int] = [] # to easily do subtick timewarp


## --------------------------------------------------------
## Prop ID caching - Client
## --------------------------------------------------------

var type_input_event__owned_prop_ids: Array[int] = []
var type_input_event__predicted_owned_prop_ids: Array[int] = []
var type_event__predicted_prop_ids: Array[int] = []
var type_event__predicted_auxiliar_prop_ids: Array[int] = []
var type_state__delta_prop_ids: Array[int] = []
var type_state__predicted_delta_prop_ids: Array[int] = []
var type_state__predicted_regular_prop_ids: Array[int] = []
var type_state__interpolated_regular_prop_ids: Array[int] = []
## props that just received new state
var type_state__newstate_prop_ids: Array[int] = [] 


## --------------------------------------------------------
## Spawning / Despawning
## --------------------------------------------------------
## I.e. When entities get added or removed

# Q: One may want to update this spawn data as the entity evolves over time
# A: No, Spawn data should be small metadata just to setup an entity,
#    big data use _delta props_
# Map <entity_id: int, data: Variant>
var entity_spawn_data: Dictionary

## User facing variable
## Client only
## FIFO<SpawnEvent>
var out_queue_spawn_events: FIFORingAny # Maybe a dynamic FIFORing would be better?

## User must call get_next_entity
## Cleared each tick
var next_entity_to_spawn: EntitySpawnEvent

# Internal list
# Map <entity_id: int, Tripla[prop_start: int, prop_end: int, curr: int]
var pending_entity_to_spawn_props: Dictionary

## Despawned entities
## List<entity_id: int>
var despawned_entity_ids: Array[int]


## --------------------------------------------------------
## Throttling / Relative synchronization
## --------------------------------------------------------

# TODO: Update
# Sync priorities:
# * Spawning
# * Despawning
# * Queue


# * Only add/remove _entity ids_ when a packet is confirmed sent (WYNC_EXTRACT_WRITE)
# * Confirmed list of entities the client sees
# Array <client_id: int, Set[entity_id: int]>
var clients_sees_entities: Array[Dictionary]

# Guarantee that all entities here can be spawned...
# * Every frame we check.. 
# Array <client_id: int, Set[entity_id: int]>
var clients_sees_new_entities: Array[Dictionary]

# Array <client_id: int, Set[entity_id: int]>
var clients_no_longer_sees_entities: Array[Dictionary]

## Queues
## vvv

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

# * Used to reduce state extraction to only the props requested
# Simple dynamic array list
var rela_prop_ids_for_full_snapshot: Array[int]
var pending_rela_props_to_sync_to_peer: Array[PeerPropPair]

## setup new connected peer
## Array <order: int, nete_peer_id: int>
var out_peer_pending_to_setup: Array[int]


# TODO: Move to WyncTrack
func _init() -> void:

	CoTicksUtils.init_co_ticks(co_ticks)
	CoTicksUtils.init_co_prediction_data(co_predict_data)

	props.resize(MAX_PROPS)
	prop_id_cursor = 0
	active_prop_ids = []

	peer_has_channel_has_events.resize(max_peers)
	prop_id_by_peer_by_channel.resize(max_peers)
	client_has_relative_prop_has_last_tick.resize(max_peers) # NOTE: index 0 not used
	out_queue_spawn_events = FIFORingAny.new(1024)

	queue_clients_entities_to_sync.resize(max_peers)
	queue_entity_pairs_to_sync.resize(100)

	clients_sees_entities.resize(max_peers)
	clients_sees_new_entities.resize(max_peers)
	clients_no_longer_sees_entities.resize(max_peers)
	entities_synced_last_time.resize(max_peers)

	clients_cached_unreliable_snapshots.resize(max_peers)
	clients_cached_reliable_snapshots.resize(max_peers)

	peer_latency_info.resize(max_peers)

	for peer_i in range(max_peers):
		peer_has_channel_has_events[peer_i] = []
		peer_has_channel_has_events[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			peer_has_channel_has_events[peer_i][channel_i] = []
		client_has_relative_prop_has_last_tick[peer_i] = {}

		prop_id_by_peer_by_channel[peer_i] = []
		prop_id_by_peer_by_channel[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			prop_id_by_peer_by_channel[peer_i][channel_i] = -1

		#if peer_i != WyncCtx.SERVER_PEER_ID:
		queue_clients_entities_to_sync[peer_i] = FIFORing.new()
		queue_clients_entities_to_sync[peer_i].init(128) # TODO: Make this user defined
		clients_sees_entities[peer_i] = {}
		clients_sees_new_entities[peer_i] = {}
		clients_no_longer_sees_entities[peer_i] = {}
		entities_synced_last_time[peer_i] = {}

		var latency_info = WyncCtx.PeerLatencyInfo.new()
		latency_info.latency_buffer.resize(WyncCtx.LATENCY_BUFFER_SIZE)
		peer_latency_info[peer_i] = latency_info

		clients_cached_reliable_snapshots[peer_i] = [] as Array[WyncPktSnap.SnapProp]
		clients_cached_unreliable_snapshots[peer_i] = [] as Array[WyncPktSnap.SnapProp]
	
	for i in range(tick_action_history_size):
		tick_action_history.insert_at(i, {} as Dictionary)
	
	client_has_info.resize(max_peers)

	debug_packets_received.resize(WyncPacket.WYNC_PKT_AMOUNT)
	for i in range(WyncPacket.WYNC_PKT_AMOUNT):
		debug_packets_received[i] = [] as Array[int]
		debug_packets_received[i].resize(20) # amount of props, also 0 is reserved for 'total'

	debug_data_per_tick_sliding_window = RingBuffer.new(debug_data_per_tick_sliding_window_size, 0)

	server_tick_rate_sliding_window = RingBuffer.new(SERVER_TICK_RATE_SLIDING_WINDOW_SIZE, 0)

	low_priority_entity_update_rate_sliding_window = RingBuffer.new(low_priority_entity_update_rate_sliding_window_size, 0)

	dummy_props = {}

	max_lerp_factor_symmetric = 1.0

	## TODO: Move wrapper initialization elsewhere

	WyncWrapper.wrapper_initialize(self)
