class_name WyncWrapperStructs


class WyncDeltaBlueprint:

	# Another idea to store Callables:
	# List <handler_id: int>
	# See WyncCtx for where handlers (Callables) are stored
	# Blueprint instances should be scarse, so there won't be any significant repetition
	
	# * Stores Callables
	# * Allows to check if a given event_type_id is supported
	# Map <event_type_id: int, handler: Callable>
	var event_handlers: Dictionary
	
	# Callable interface
	# 'first time' is another name for 'requires_undo'
	# 'wync_ctx' will only be set if 'requires_undo' is
	# (state: Variant, event: WyncEvent.EventData, requires_undo: bool, ctx: WyncCtx*) -> [err, undo_event_id]:


# ------------------------------
# Wrapper

const WRAPPER_MAX_USER_TYPES = 256


class WyncWrapperCtx:
	# Array<prop_id: int, Callable>
	var prop_user_ctx: Array[Variant]
	var prop_getter: Array[Callable]
	var prop_setter: Array[Callable] # Maybe use a b-tree set?

	# Array[256] <user_type_id: int, lerp_function_id: int>
	var lerp_type_to_lerp_function: Array[int]
	# DynArr[0] <order_id: int, Callable[a: Variant, b: Variant, c: float]>
	var lerp_function: Array[Callable]

	# Array<delta_blueprint_id: int, Blueprint>
	var delta_blueprints: Array[WyncWrapperStructs.WyncDeltaBlueprint]
