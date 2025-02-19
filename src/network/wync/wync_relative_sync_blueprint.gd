class_name WyncDeltaBlueprint

# Another idea to store Callables:
# List <handler_id: int>
# See WyncCtx for where handlers (Callables) are stored
# Blueprint instances should be scarse, so there won't be any significant repetition

# * Stores Callables
# * Allows to check if a given event_type_id is supported
# Map <event_type_id: int, handler: Callable>
var event_handlers: Dictionary
