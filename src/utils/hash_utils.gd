class_name HashUtils


## When native @GlobalScope.hash hashes Objects it doesn't have into
## account most of it's data (See Variant.cpp). So to reduce colisions we
## convert Objects to Dictionaries first before hashing
static func hash_any(any) -> int:
	if any is Object:
		return hash(object_to_dictionary(any))
	return hash(any)


static func object_to_dictionary(object: Object) -> Dictionary:
	return JsonClassConverter.class_to_json(object)


static func calculate_object_data_size(object: Object) -> int:
	return JsonClassConverter.class_to_json_string(object).length()
