class_name GameInfo

enum {
	EVENT_NONE,

	# delta events
	EVENT_DELTA_BLOCK_REPLACE,

	# player events
	EVENT_PLAYER_SHOOT,
	EVENT_PLAYER_BLOCK_BREAK,
	EVENT_PLAYER_BLOCK_PLACE,
	EVENT_PLAYER_BLOCK_BREAK_DELTA,
	EVENT_PLAYER_BLOCK_PLACE_DELTA,
	EVENT_PLAYER_BLOCK_SET_FIRE,

	# ???
	EVENT_CHAT_MESSAGE,
}

## The user has it's own packet types, he must use a magic number to distinguish 
## his packets from Wync's packets

enum {
	NETE_PKT_ANY,
	NETE_PKT_AMOUNT,
	NETE_PKT_WYNC_PKT = 888
}
