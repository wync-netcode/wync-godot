extends Node
class_name MathUtils

"""
// Case 1: When AA is a power of 2
int is_power_of_two_factor(int A, int B) {
	return (B & (A - 1)) == 0;
}

// Case 2: When AA is not a power of 2
int is_factor(int A, int B) {
	if (A == 0) return 0; // Division by zero not allowed

	// Reduce B by multiples of A
	while (B >= A) {
		B -= A;
	}
	
	// If remainder is 0, A is a factor
	return B == 0;
}
"""

## Inclusive
static func is_between_int(value: int, left: int, right: int):
	return value >= left && value <= right
