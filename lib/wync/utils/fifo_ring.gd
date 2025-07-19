class_name FIFORing

var capacity: int = 0
var size: int
var tail: int
var head: int
var ring: Array[int]


func init(p_max_size: int = 0):
	tail = 0
	head = 0
	size = 0
	resize(p_max_size)


func resize(new_size: int):
	capacity = new_size
	ring.resize(new_size)


## @returns int. 0 -> ok, 1 -> error
func push_head(item: int) -> int:
	if size >= capacity:
		return 1
	elif size == 0:
		head = 0
		tail = 0
	else:
		head += 1
		if head >= capacity:
			head = 0
	ring[head] = item
	size += 1
	return OK


## NOTE: should return a struct Tuple[Error, Value]
## @returns int. popped item
func pop_tail() -> int:
	if size <= 0:
		return -1
	
	var item = ring[tail]
	
	if size > 1:
		tail += 1
		if tail >= capacity:
			tail = 0
	
	size -= 1
	return item


func remove_item(item_to_remove: int) -> int:
	if size <= 0:
		return 1

	var ring_i = tail
	for i in range(size):

		var item = ring[ring_i]

		if item == item_to_remove:
			var item_head = ring[head]
			ring[ring_i] = item_head
			if size > 1:
				head -= 1
				if head < 0:
					head = capacity -1
			size -= 1
			return OK

		ring_i += 1
		if ring_i >= capacity:
			ring_i = 0

	return 2


## TODO: maybe check for size?
## @returns Optional<Variant>
func get_head() -> int:
	return ring[head]


## @returns Optional<Variant>
func get_tail() -> int:
	return ring[tail]


## @returns Optional<Variant>
#func get_relative_to_head(pos: int) -> int:
	#return ring[WyncTrack.fast_modulus(head + pos, capacity)]


## @returns Optional<Variant>
func get_relative_to_tail(pos: int) -> int:
	return ring[WyncMisc.fast_modulus(tail + pos, capacity)]

func clear() -> void:
	tail = 0
	head = 0
	size = 0


func has_item(item: int) -> bool:
	if size == 0:
		return false
	if tail < head:
		for i in range(tail, head +1):
			if ring[i] == item:
				return true
	if tail > head:
		for i in range(tail, capacity):
			if ring[i] == item:
				return true
		for i in range(0, head +1):
			if ring[i] == item:
				return true
	
	return false
