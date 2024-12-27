class_name WyncCtx


## Server & Client ==============================

# Array<entity_id: int>
var tracked_entities: Array[int]

# Array<prop_id: int, WyncEntityProp>
var props: Array[WyncEntityProp]

# Map<entity_id: int, Array<prop_id>>
var entity_has_props: Dictionary

# Map<entity_id: int, sim_fun_id>
var entity_has_integrate_fun: Dictionary

# Array<prop_id: int>
var props_to_predict: Array[int]


## Server only ==============================

# Array<clients_id: int> # NOTE: Should be Ring
var clients: Array[int]

# Map<client_id: int, prop_id: int>
var client_owns_prop: Dictionary


## Client only ==============================

var my_client_id: int

# Array<sim_fun_id: int, Callable>
# stores:
# (1) simulation functions: simulate physics
# (2) integrate functions: syncs entity transform with physic server 
var simulation_functions: Array[Callable]

# Map<entity_id: int, sim_fun_id>
var entity_has_simulation_fun: Dictionary

# Meta state / Managment
var connected: bool = false
