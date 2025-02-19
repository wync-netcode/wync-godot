class_name FIFORingAny

var max_size: int = 0
var size: int
var tail: int
var head: int
var ring: Array[Variant]


func _init(p_max_size: int = 0) -> void:
	tail = 0
	head = 0
	size = 0
	resize(p_max_size)


func resize(new_size: int):
	max_size = new_size
	ring.resize(new_size)


## @returns int. 0 -> ok, 1 -> error
func push_head(item: Variant) -> int:
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


## Similar to push_head but doesn't insert, so it reuses whatever it's already present in that slot
## @returns int. 0 -> ok, 1 -> error
func extend_head() -> int:
	if size >= max_size:
		return 1
	elif size == 0:
		head = 0
		tail = 0
	else:
		head += 1
		if head >= max_size:
			head = 0
	size += 1
	return OK


## @returns Optional<Variant>. popped item
func pop_tail() -> Variant:
	if size <= 0:
		return -1
	
	var item = ring[tail]
	
	if size > 1:
		tail += 1
		if tail >= max_size:
			tail = 0
	
	size -= 1
	return item


## @returns Optional<Variant>
func get_head() -> Variant:
	return ring[head]


## @returns Optional<Variant>
func get_tail() -> Variant:
	return ring[tail]
