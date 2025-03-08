class_name Log

enum {
	TAG_DEBUG1,
	TAG_DEBUG2,
	TAG_DEBUG3,
	TAG_CLOCK,
	TAG_LATENCY,
	TAG_PRED_TICK,
	TAG_NETE_CONNECT,
	TAG_INPUT_BUFFER,
	TAG_INPUT_RECEIVE,
	TAG_WYNC_CONNECT,
	TAG_LATEST_VALUE,
	TAG_LERP,
	TAG_WYNC_PEER_SETUP,
	TAG_EVENT_DATA,
	TAG_PROP_SETUP,
	TAG_DELTA_EVENT,
	TAG_XTRAP,
	TAG_GAME_EVENT,
	TAG_TIMEWARP,
	TAG_SUBTICK_EVENT,
	TAG_THROTTLE,
	TAG_SYNC_QUEUE,
	# append up
	TAG_COUNT,
}

const tag_names: Dictionary = {
	TAG_DEBUG1: "Debug1",
	TAG_DEBUG2: "Debug2",
	TAG_DEBUG3: "Debug3",
	TAG_CLOCK: "Clock",
	TAG_LATENCY: "Latency",
	TAG_PRED_TICK: "Pred-tick",
	TAG_NETE_CONNECT: "Nete-connect",
	TAG_INPUT_BUFFER: "Input-buffer",
	TAG_INPUT_RECEIVE: "Input-receive",
	TAG_WYNC_CONNECT: "Wync-connect",
	TAG_LATEST_VALUE: "Latest-value",
	TAG_LERP: "Lerp",
	TAG_WYNC_PEER_SETUP: "Wync-peer-setup",
	TAG_EVENT_DATA: "Event-data",
	TAG_PROP_SETUP: "Prop-setup",
	TAG_DELTA_EVENT: "Delta-Event",
	TAG_XTRAP: "Xtrap",
	TAG_GAME_EVENT: "Game-Event",
	TAG_TIMEWARP: "Timewarp",
	TAG_SUBTICK_EVENT: "Subtick-Event",
	TAG_THROTTLE: "Throttle",
	TAG_SYNC_QUEUE: "SYNC_QUEUE",
}


# workaround for variant arguments for now
# https://github.com/godotengine/godot-proposals/issues/1034

static func outc(ctx: WyncCtx, msg: String,
arg1 = null, arg2 = null, arg3 = null, arg4 = null,
arg5 = null, arg6 = null, arg7 = null, arg8 = null):

	var tags: Array[int] = []
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if argument is int:
			tags.push_back(argument)

	var tag_text = ""
	if tags.size():
		tag_text = " : "
		for tag: int in tags:
			if tag >= 0 && tag < TAG_COUNT:
				tag_text += "%s " % [tag_names[tag]]
			else:
				tag_text += "%s " % str(tag)

	var prefix = "cli_%s| " % [ctx.my_peer_id] if ctx.is_client else "serve| "
	var color = "yellow" if ctx.is_client else "magenta"
	var function_name = get_function_name(1)
	print_rich("[color=%s]%s%s | %s%s" % [color, prefix, msg, function_name, tag_text])


static func errc(ctx: WyncCtx, msg: String,
arg1 = null, arg2 = null, arg3 = null, arg4 = null,
arg5 = null, arg6 = null, arg7 = null, arg8 = null):

	var tags: Array[int] = []
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if argument is int:
			tags.push_back(argument)

	var tag_text = ""
	if tags.size():
		tag_text = " : "
		for tag: int in tags:
			if tag >= 0 && tag < TAG_COUNT:
				tag_text += "%s " % [tag_names[tag]]
			else:
				tag_text += "%s " % str(tag)

	var prefix = "cli_%s| " % [ctx.my_peer_id] if ctx.is_client else "serve| "
	var function_name = get_function_name(1)
	printerr("%s%s | %s%s" % [prefix, msg, function_name, tag_text])


static func out(msg: String,
arg1 = null, arg2 = null, arg3 = null, arg4 = null,
arg5 = null, arg6 = null, arg7 = null, arg8 = null):

	var tags: Array[int] = []
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if argument is int:
			tags.push_back(argument)

	var tag_text = ""
	if tags.size():
		tag_text = " : "
		for tag: int in tags:
			if tag >= 0 && tag < TAG_COUNT:
				tag_text += "%s " % [tag_names[tag]]
			else:
				tag_text += "%s " % str(tag)

	var function_name = get_function_name(1)
	print("%s | %s%s" % [msg, function_name, tag_text])


static func err(msg: String,
arg1 = null, arg2 = null, arg3 = null, arg4 = null,
arg5 = null, arg6 = null, arg7 = null, arg8 = null):

	var tags: Array[int] = []
	for argument in [arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8]:
		if argument is int:
			tags.push_back(argument)

	var tag_text = ""
	if tags.size():
		tag_text = " : "
		for tag: int in tags:
			if tag >= 0 && tag < TAG_COUNT:
				tag_text += "%s " % [tag_names[tag]]
			else:
				tag_text += "%s " % str(tag)

	var function_name = get_function_name(1)
	printerr("%s | %s%s" % [msg, function_name, tag_text])


static func get_function_name(levels_up: int) -> String:
	var stack = get_stack() as Array
	var level = levels_up +1
	if level >= stack.size():
		return ""
	return stack[level]["function"]


## @argument caller: Null | Node | Object
static func obj_out(caller, msg: String):
	var name = ""
	var script_name = ""
	var script = null

	if caller is Object:
		script = caller.get_script()

	if script != null:
		script_name = script.get_global_name()
		if script_name.length():
			name = script.get_global_name()

	if caller is Node:
		if script_name != caller.name:
			if name.length():
				name += ":"
			name += caller.name
	
	print("%s | %s" % [name, msg])


## @argument caller: Null | Node | Object
static func obj_err(caller, msg: String):
	var name = ""
	var script_name = ""
	var script = null

	if caller is Object:
		script = caller.get_script()

	if script != null:
		script_name = script.get_global_name()
		if script_name.length():
			name = script.get_global_name()

	if caller is Node:
		if script_name != caller.name:
			if name.length():
				name += ":"
			name += caller.name
	
	printerr("%s | %s" % [name, msg])
