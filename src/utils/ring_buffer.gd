class_name RingBuffer

var buffer: Array = []
var size: int
var head_pointer: int = 0


## Initializes ring buffer of specified size
## @argument arg_size: int must a power of two
func _init(ar_size: int, default_value: Variant) -> void:
	size = ar_size
	buffer.resize(size)

	# fill
	for i: int in range(size):
		if typeof(default_value) == TYPE_ARRAY:
			buffer[i] = (default_value as Array).duplicate(true)
		elif typeof(default_value) == TYPE_DICTIONARY:
			buffer[i] = (default_value as Dictionary).duplicate(true)
		else:
			buffer[i] = default_value


## Returns the item in position relative to head
## e.g. get(0) will return head, but get(-1) will return the item before head
func get_relative(position: int = 0): # -> Any
	return buffer[WyncMisc.fast_modulus(head_pointer + position, size)]
	

## Adds item to the head overwritting the tail if necessary
## func push(item: Any)
## @returns int: position for new element
func push(item) -> int:
	if size == 0: return -1
	head_pointer = WyncMisc.fast_modulus(head_pointer + 1, size)
	buffer[head_pointer] = item
	return head_pointer


## @argument i (int): position in the ring
## @argument item (any)
func insert_at(i: int, item) -> void:
	if size == 0: return
	buffer[WyncMisc.fast_modulus(i, size)] = item
	# Note: Maybe implement an insert_at_absolute
	

## @returns: Optional<any>
func get_at(i: int):# -> any
	if size == 0: return null
	return buffer[WyncMisc.fast_modulus(i, size)]


## @returns: Optional<any>
func get_absolute(i: int):# -> any
	if size == 0: return null
	return buffer[i]


func clear() -> void:
	head_pointer = 0
	buffer.clear()
	buffer.resize(size)


## sorts it and repositions head to latest
func sort() -> void:
	head_pointer = size -1
	if typeof(buffer[0]) != TYPE_INT:
		return
	buffer.sort()
