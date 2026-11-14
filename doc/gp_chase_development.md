# M04 极速追逐　A　依赖 G02、G03

来源：2026-11-07 架构审查及其最后实施记录。整理日期：2026-11-14。下列待办保留原状态；实施前核对本包源码与工作区，不以历史检查代替本次验收。

[共享 G01–G03 任务](../../../protocols/godot_party_default_protocol/doc/godot_party_default_protocol_development.md) · [包说明](gp_chase_guide.md)


包：`gp_chase`，原清单称灯塔群岛。定位：[scripts/main.gd](../scripts/main.gd) 的 `_setup_inputs()`、`_course_forward()`、`_build_sounds()`、`_play_sound()`；`scripts/player.gd`。

实施记录（2026-11-07）：M04 四项已落地，五个固定音效为 Cue 资源；相机编辑值、顺序存档/重试、四个平台运动、总览切换、输入改键/屏蔽及唯一完成/退出已做定向运行检查。1920×1080 画面已查看；未重跑正常输入全路线通关，原型历史通关记录不作为本次验收。

验证：跳跃/检查点/重试、四个平台运动、总览切换、菜单输入屏蔽、通关与退出。

## 人工验收待办

保留自 2026-11-05 场景审查，后续记录未明确关闭的人工事项：全程通关待人工验收。
