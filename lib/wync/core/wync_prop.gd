class_name WyncProp


## --------------------------------------------------------
## State buffer
## --------------------------------------------------------

class StateBuffer:

	var just_received_new_state: bool

	# Unified
	# states           <state_id, state>
	# statebff.state_id_to_tick <state_id, tick>
	# statebff.tick_to_state_id <tick, state_id>
	# statebff.state_id_to_local_tick <state_id, local_tick>
	
	# RingBuffer<int, Variant>
	var saved_states: RingBuffer = null
	# RingBuffer<int, int>
	var state_id_to_tick: RingBuffer = null
	# RingBuffer<int, int>
	var tick_to_state_id: RingBuffer = null
	# RingBuffer<int, int> (only for lerping)
	var state_id_to_local_tick: RingBuffer = null
	
	## Note. On predicted entities only the latest value is valid
	## Last-In-First-Out (LIFO)
	## LIFO Queue <arrival_order: int, server_tick: int>
	var last_ticks_received: RingBuffer = null


## --------------------------------------------------------
## Extrapolation / Prediction
## --------------------------------------------------------

class Xtrap:
	var pred_curr: WyncCtx.NetTickData = null
	var pred_prev: WyncCtx.NetTickData = null


## --------------------------------------------------------
## Lerping
## --------------------------------------------------------

class Lerp:

	# For lerping and 'subtick timewarp', don't use for checking prop data type on
	# any other prop
	var lerp_user_data_type: int 
	
	var interpolated_state #: char[4]; can hold 4 bytes
	
	var lerp_ready: bool
	var lerp_use_confirmed_state: bool
	
	# Precalculate which ticks we're gonna be interpolating between
	# Q: Why store specific tick range instead of using current one
	# A: To support varying update rates per prop
	# Q: Why store state copy?
	# A: To allow the state buffer to fill and be replaced
	
	var lerp_left_local_tick: int
	var lerp_right_local_tick: int
	
	var lerp_left_canon_tick: int
	var lerp_right_canon_tick: int
	
	var lerp_left_state: Variant = null
	var lerp_right_state: Variant = null


## --------------------------------------------------------
## Relative Synchronization
## --------------------------------------------------------
## Auxiliar props don't get this struct

class Rela:
	
	# What blueprint does this prop obeys? This dictates relative sync events
	var delta_blueprint_id: int = -1
	
	# if relative_sync_enabled: points to auxiliar prop
	# if is_auxiliar_prop: points to delta prop
	var auxiliar_delta_events_prop_id: int = -1
	
	# A place to insert current delta events
	var current_delta_events: Array[int]
	
	# A place to insert current undo delta events
	var current_undo_delta_events: Array[int]

	## --------------------------------------------------------
	## Undo events: Only for Prediction and Timewarp
	## --------------------------------------------------------

	# Rela Aux: here we store undo event_ids
	# Ring <tick: id, data: Array[int]>
	var confirmed_states_undo: RingBuffer = null
	
	# Rela Aux: what tick corresponds to any saved state
	var confirmed_states_undo_tick: RingBuffer = null


## --------------------------------------------------------
## Event consumed module
## --------------------------------------------------------

class Consumed:
	## * Note: Currently, if there are duplicated events on a single tick,
	##   only once instance will be executed
	## * Stores the consumed events for the last N ticks
	## * Used mainly for the server to consume late client events
	## Ring <tick: id, event_ids: Array[int]>
	var events_consumed_at_tick: RingBuffer = null
	var events_consumed_at_tick_tick: RingBuffer = null


# Future: Create pseudo-ECS for prop components

var name_id: String ## char[64]
var prop_type: WyncCtx.PROP_TYPE

var lerp_enabled: bool
var xtrap_enabled: bool
var relative_sync_enabled: bool
var consumed_events_enabled: bool
var timewarp_enabled: bool # (server-side) will keep state history

var is_auxiliar_prop: bool
# if relative_sync_enabled: points to auxiliar prop
# if is_auxiliar_prop: points to delta prop
var auxiliar_delta_events_prop_id: int = -1

var statebff: WyncProp.StateBuffer = null
var co_lerp: WyncProp.Lerp = null
var co_xtrap: WyncProp.Xtrap = null
var co_rela: WyncProp.Rela = null
var co_consumed: WyncProp.Consumed = null
