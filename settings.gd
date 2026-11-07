extends RefCounted
## Local bindings shared by formal input and F6 defaults. Reading does not persist them.
static func schema() -> Dictionary:
	var fields: Dictionary = {
		"lighthouse_isles_move_left": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_A, "physical": true}, {"kind": "key", "code": KEY_LEFT, "physical": true}],
			"title": "向左", "action": "lighthouse_isles_move_left", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_move_right": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_D, "physical": true}, {"kind": "key", "code": KEY_RIGHT, "physical": true}],
			"title": "向右", "action": "lighthouse_isles_move_right", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_move_forward": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_W, "physical": true}, {"kind": "key", "code": KEY_UP, "physical": true}],
			"title": "向前", "action": "lighthouse_isles_move_forward", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_move_back": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_S, "physical": true}, {"kind": "key", "code": KEY_DOWN, "physical": true}],
			"title": "向后", "action": "lighthouse_isles_move_back", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_jump": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_SPACE, "physical": true}],
			"title": "跳跃", "action": "lighthouse_isles_jump", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_restart": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_R, "physical": true}],
			"title": "重新开始", "action": "lighthouse_isles_restart", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_retry_checkpoint": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_BACKSPACE, "physical": true}],
			"title": "返回检查点", "action": "lighthouse_isles_retry_checkpoint", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_accept": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_ENTER, "physical": true}],
			"title": "确认", "action": "lighthouse_isles_accept", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_mute": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_M, "physical": true}],
			"title": "声音开关", "action": "lighthouse_isles_mute", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false},
		"lighthouse_isles_overview": {"type": "array", "control": "binding", "default": [{"kind": "key", "code": KEY_TAB, "physical": true}],
			"title": "地图总览", "action": "lighthouse_isles_overview", "audience": "local", "apply": "immediate", "items": {"type": "object", "format": "binding"}, "max_items": 2, "combinations": false}
	}
	var layout: Array[Dictionary] = []
	for key: String in fields:
		layout.append({"field": key})
	return {"schema_format": 3, "settings_version": 1, "fields": fields, "layout": layout}
