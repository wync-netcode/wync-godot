class_name Log


## @argument caller: Null | Node | Object
static func out(caller, msg: String):
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
static func err(caller, msg: String):
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
