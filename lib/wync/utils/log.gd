class_name Log


static func outc(ctx: WyncCtx, msg: String):
	var prefix = "cli_%s" % [ctx.common.my_peer_id] if ctx.common.is_client else "serve"
	prefix += " %s| " % [ctx.common.ticks]
	var color = "yellow" if ctx.common.is_client else "magenta"
	var function_name = get_function_name(1)
	print_rich("[color=%s]IN %s%s | %s" % [color, prefix, msg, function_name])


static func warc(ctx: WyncCtx, msg: String):
	var prefix = "cli_%s" % [ctx.common.my_peer_id] if ctx.common.is_client else "serve"
	prefix += " %s| " % [ctx.common.ticks]
	var color = "orange" if ctx.common.is_client else "pink"
	var function_name = get_function_name(1)
	print_rich("[color=%s]WA %s%s | %s" % [color, prefix, msg, function_name])


static func errc(ctx: WyncCtx, msg: String):
	var prefix = "cli_%s" % [ctx.common.my_peer_id] if ctx.common.is_client else "serve"
	prefix += " %s| " % [ctx.common.ticks]
	var function_name = get_function_name(1)
	printerr("ER %s%s | %s" % [prefix, msg, function_name])


static func out(msg: String):
	print("I %s | %s" % [msg, get_function_name(1)])


static func war(msg: String):
	print("W %s | %s" % [msg, get_function_name(1)])


static func err(msg: String):
	printerr("E %s | %s" % [msg, get_function_name(1)])


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
