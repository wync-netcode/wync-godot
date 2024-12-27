class_name RingBuffer

var buffer: Array = []
var size: int
var head_pointer: int = 0


## Initializes ring buffer of specified size
func _init(ar_size: int) -> void:
	size = ar_size
	buffer.resize(size)


## Returns the item in position relative to head
## e.g. get(0) will return head, but get(-1) will return the item before head
func get_relative(position: int = 0): # -> Any
	return buffer[(head_pointer + position) % size]
	

## Adds item to the head overwritting the tail if necessary
## func push(item: Any)
func push(item) -> void:
	head_pointer = (head_pointer + 1) % size
	buffer[head_pointer] = item


## @argument i (int): position in the ring
## @argument item (any)
func insert_at(i: int, item):
	buffer[i % size] = item
	

## @returns: Optional<any>
func get_at(i: int):# -> any
	return buffer[i % size]


func clear() -> void:
	head_pointer = 0
	buffer.clear()
