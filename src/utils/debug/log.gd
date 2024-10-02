class_name Log


static func out(caller: Node, msg: String):
	var script = caller.get_script()

	if script && script.get_global_name().length() && script.get_global_name() != caller.name:
		print("%s:%s | %s" % [caller.name, script.get_global_name(), msg])
	else:
		print("%s | %s" % [caller.name, msg])


static func err(caller: Node, msg: String):
	var script = caller.get_script()

	if script && script.get_global_name().length():
		printerr("%s:%s | %s" % [caller.name, script.get_global_name(), msg])
	else:
		printerr("%s | %s" % [caller.name, script.get_global_name(), msg])
