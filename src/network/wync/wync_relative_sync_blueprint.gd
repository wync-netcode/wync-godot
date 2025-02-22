class_name WyncDeltaBlueprint

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
