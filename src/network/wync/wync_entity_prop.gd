class_name WyncEntityProp
"""
enum SYNC_STRAT {
	LATEST_VALUE,
	INTERPOLATED,
	PREDICTED # aka extrapolation / self-prediction
}"""

enum DATA_TYPE {
	INT,
	FLOAT,
	VECTOR2,
	INPUT, # can store Variant
	ANY,
	EVENT,
	STRING
}

static var INTERPOLABLE_DATA_TYPES: Array[DATA_TYPE] = [
	DATA_TYPE.FLOAT,
	DATA_TYPE.VECTOR2,
]

var name_id: String
var data_type: DATA_TYPE
var user_ctx_pointer: Variant #: VariantPointer
var getter: Callable #: func(user_ctx: Variant) -> Variant
var setter: Callable #: func(user_ctx: Variant, new_state: Variant) -> void
var state_pointer: Variant #: VariantPointer # for relative sync props

# Optional properties:
# TODO: Move these elsewhere

var just_received_new_state: bool # new state was received from the server
var interpolated: bool
var interpolated_state # : any

# (server-side) the server will keep a history of state
var timewarpable: bool

# TODO: Make this value configurable on WyncCtx
# Ring <tick: id, data: Variant>
var confirmed_states: RingBuffer = null

## On predicted entities, only the latest value is valid
## Last-In-First-Out (LIFO)
## LIFO Queue <arrival_order: int, server_tick: int>
var last_ticks_received: RingBuffer = null

## Corresponds to the position in confirmed_states where
## we last stored a predicted state
## Guaranteed to find state between last_tick_received(0) and last_cached_predicted_tick
var last_cached_predicted_tick: int = -1

## this server tick was received at this tick (used for lerping)
## LIFO Queue <server_tick: int, local_tick: int>
var arrived_at_tick: RingBuffer = null

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

# Related to Throttling
# --------------------------------------------------

var reliable := true
