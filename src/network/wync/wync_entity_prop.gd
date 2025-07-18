class_name WyncEntityProp

enum PROP_TYPE {
	STATE,
	INPUT, # can store Variant
	EVENT, # aka Array[int]
}

# A note about syncing strings:
# If you want to sync strings it's recommended to config the prop
# So that updates are only sent on value change.

var name_id: String
var prop_type: PROP_TYPE
var user_data_type: int # DO not use for checking prop data type, this is only for 'lerping' and 'subtick timewarp'

# Optional properties:
# TODO: Move these elsewhere

var just_received_new_state: bool # new state was received from the server
var interpolated: bool
var interpolated_state # : any

# (server-side) the server will keep a history of state
var timewarpable: bool


# Unified
# states           <state_id, state>
# state_id_to_tick <state_id, tick>
# tick_to_state_id <tick, state_id>
# state_id_to_local_tick <state_id, local_tick>

# RingBuffer<int, Variant>
var saved_states: RingBuffer = null
# RingBuffer<int, int>
var state_id_to_tick: RingBuffer = null
# RingBuffer<int, int>
var tick_to_state_id: RingBuffer = null
# RingBuffer<int, int> (only for lerping)
var state_id_to_local_tick: RingBuffer = null


# get state from tick
# @argument int: tick
# @returns Variant: state

# Warning: Use only if you know what you're doing
static func saved_state_get(
	prop: WyncEntityProp, tick: int) -> Variant:

	var state_id = prop.tick_to_state_id.get_at(tick)
	if state_id == -1 || prop.state_id_to_tick.get_absolute(state_id) != tick:
		return null

	return prop.saved_states.get_absolute(state_id)


static func saved_state_get_throughout(
	prop: WyncEntityProp, tick: int) -> Variant:

	#return saved_state_get_quick(prop, tick)

	# look up tick
	for i in range(prop.saved_states.size):
		#var state_id = WyncTrack.fast_modulus(
			#prop.state_id_to_tick.head_pointer -i, prop.state_id_to_tick.size)
		var state_id = i
		var saved_tick = prop.state_id_to_tick.get_absolute(state_id) 
		if saved_tick == tick:
		#if prop.state_id_to_tick.get_relative(-i) == tick:
		#if prop.state_id_to_tick.get_absolute(i) == tick:
			return prop.saved_states.get_absolute(state_id)

	return null


static func saved_state_insert (
	_ctx: WyncCtx, prop: WyncEntityProp, tick: int, state: Variant):
	
	var err = prop.saved_states.push(state)
	if err == -1: return
	var state_id = prop.saved_states.head_pointer
	prop.state_id_to_tick.insert_at(state_id, tick)
	prop.tick_to_state_id.insert_at(tick, state_id)


static func server_tick_arrived_at_local_tick (prop: WyncEntityProp, server_tick: int) -> int:

	for i in range(prop.saved_states.size):
		var state_id = i
		var saved_tick = prop.state_id_to_tick.get_absolute(state_id) 
		if saved_tick == server_tick:
			return prop.state_id_to_local_tick.get_absolute(state_id)

	return -1


## On predicted entities, only the latest value is valid
## Last-In-First-Out (LIFO)
## LIFO Queue <arrival_order: int, server_tick: int>
var last_ticks_received: RingBuffer = null

## Corresponds to the position in confirmed_states where
## we last stored a predicted state
## Guaranteed to find state between last_tick_received(0) and last_cached_predicted_tick
var last_cached_predicted_tick: int = -1

## store predicted state
var pred_curr: NetTickData = null
var pred_prev: NetTickData = null

# UNUSED
# Precalculate which ticks we're gonna be interpolating between
# int: keys to 'confirmed_state'
var lerp_use_confirmed_state: bool
var lerp_left_local_tick: int # used to calculate timing
var lerp_right_local_tick: int

# Q: Why store specific tick range instead of using current one
# A: To support varying update rates per prop
var lerp_left_confirmed_state_tick: int
var lerp_right_confirmed_state_tick: int

# Q: Why store state copy?
# A: To allow the buffer to fill and be replaced
var lerp_left_state: Variant
var lerp_right_state: Variant

## Whether when we skip ticks we want to duplicated it
## (useful for _input events_, e.g movement, shooting. Do not confuse with INPUT props)
## Only applies to EVENT props
var allow_duplication_on_tick_skip: bool = true

# Related to relative syncronization
# --------------------------------------------------

var relative_syncable: bool = false
var is_auxiliar_prop: bool = false

# What blueprint does this prop obeys? This dictates relative sync events
var delta_blueprint_id: int = -1

# if relative_syncable point to auxiliar prop
# if is_auxiliar_prop point to delta prop
var auxiliar_delta_events_prop_id: int = -1

# A place to insert current delta events
var current_delta_events: Array[int]

# A place to insert current undo delta events
var current_undo_delta_events: Array[int]

# Exclusive to auxiliar props, here we store undo event_ids
# Ring <tick: id, data: Array[int]>
var confirmed_states_undo: RingBuffer = null

## what tick corresponds to any saved state
var confirmed_states_undo_tick: RingBuffer = null

# Related to Throttling
# --------------------------------------------------

#var reliable := true

# Event consumed module
# --------------------------------------------------

## * Note: Currently, if there are duplicated events on a single tick,
##   only once instance will be executed
## * Stores the consumed events for the last N ticks
## * Used mainly for the server to consume late client events
## Ring <tick: id, event_ids: Array[int]>
var module_events_consumed: bool = false
var events_consumed_at_tick: RingBuffer = null
var events_consumed_at_tick_tick: RingBuffer = null
