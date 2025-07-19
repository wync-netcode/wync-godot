class_name WyncMisc


## denominator must be a power of 2
static func fast_modulus(numerator: int, denominator: int) -> int:
	## NOTE: DEBUG flag only: assert(denominator is power of 2)
	return numerator & (denominator - 1)


static func lerp_any(left: Variant, right: Variant, weight: float):
	return lerp(left, right, weight)


static func duplicate_any(any): #-> Optional<any>
	if any is Object:
		if any.has_method("duplicate") && any is not Node:
			return any.duplicate()
		elif any.has_method("copy"):
			return any.copy()
		elif any.has_method("make_duplicate"):
			return any.make_duplicate()
	elif typeof(any) in [
		TYPE_ARRAY,
		TYPE_DICTIONARY
	]:
		return any.duplicate(true)
	elif typeof(any) in [
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_RECT2,
		TYPE_RECT2I,
		TYPE_VECTOR3,
		TYPE_VECTOR3I,
		TYPE_TRANSFORM2D,
		TYPE_VECTOR4,
		TYPE_VECTOR4I,
		TYPE_PLANE,
		TYPE_QUATERNION,
		TYPE_AABB,
		TYPE_BASIS,
		TYPE_TRANSFORM3D,
		TYPE_PROJECTION,
		TYPE_COLOR,
		TYPE_STRING_NAME
	]:
		return any
	return null
