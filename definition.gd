## Lightweight catalog data. Do not load gameplay scenes or scripts here.
extends RefCounted

static func party_definition() -> Dictionary:
	return {"player_counts": [1], "controls": {"lighthouse_isles_move_left": "向左", "lighthouse_isles_move_right": "向右", "lighthouse_isles_move_forward": "向前", "lighthouse_isles_move_back": "向后", "lighthouse_isles_jump": "跳跃", "lighthouse_isles_restart": "重新开始", "lighthouse_isles_retry_checkpoint": "返回检查点", "lighthouse_isles_accept": "确认", "lighthouse_isles_mute": "声音开关", "lighthouse_isles_overview": "地图总览"}}
