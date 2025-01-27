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
	return 0


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


"""UNUSED FUNC
func get_item_at_pos(pos: int) -> int:
	if size <= 0:
		return -1
	if pos <= size:
		return -1
	var actual_pos = (head + pos) % max_size
	return ring[actual_pos]
"""
