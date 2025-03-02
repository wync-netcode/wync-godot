class_name FIFORing

var max_size: int = 0
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
	max_size = new_size
	ring.resize(new_size)


## @returns int. 0 -> ok, 1 -> error
func push_head(item: int) -> int:
	if size >= max_size:
		return 1
	elif size == 0:
		head = 0
		tail = 0
	else:
		head += 1
		if head >= max_size:
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
		if tail >= max_size:
			tail = 0
	
	size -= 1
	return item


## TODO: maybe check for size?
## @returns Optional<Variant>
func get_head() -> int:
	return ring[head]


## @returns Optional<Variant>
func get_tail() -> int:
	return ring[tail]


## @returns Optional<Variant>
func get_relative_to_head(pos: int) -> int:
	return ring[(head + pos) % max_size]


## @returns Optional<Variant>
func get_relative_to_tail(pos: int) -> int:
	return ring[(tail + pos) % max_size]

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
		for i in range(tail, max_size):
			if ring[i] == item:
				return true
		for i in range(0, head +1):
			if ring[i] == item:
				return true
	
	return false
