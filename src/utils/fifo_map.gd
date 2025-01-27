class_name FIFOMap

var max_size: int = 0
var map: Dictionary
var ring: FIFORing = FIFORing.new()


func init(p_max_size = 0):
	max_size = p_max_size
	ring.resize(p_max_size)
	pass


## Add a new item 
## Automatically removes previous items if full (FIFO)
## NOTE: unused function
"""
func push_head(item: Variant):
	
	# if not enough room -> pop
	if ring.size >= max_size:
		var item_hash = ring.pop_tail()
		map.erase(item_hash)
	
	# insert new data: calculate hash and register on list
	var item_hash = HashUtils.hash_any(item)
	ring.push_head(item_hash)
	map[item_hash] = item"""


func push_head_hash_and_item(item_hash: int, item: Variant):
	
	# if not enough room -> pop
	
	if ring.size >= max_size:
		var cached_item_hash = ring.pop_tail()
		print(self, "EVENT Remove %s" % cached_item_hash)
		map.erase(cached_item_hash)
		pass
	
	# insert new data: calculate hash and register on list
	ring.push_head(item_hash)
	map[item_hash] = item
	print(self, "EVENT Add %s" % hash)


func has_item_hash(item_hash: int) -> bool:
	return map.has(item_hash)


func get_item_by_hash(item_hash: int) -> Variant:
	return map.get(item_hash, null)
