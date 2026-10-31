# CUBE · Lighthouse Isles

**灯塔群岛**：用纯白、无脸、无贴图的小方块，穿过一张完整的海岛跑酷地图。基于 **Godot 4.7.2**，单人、键盘、原生 3D；不是多人派对游戏，也没有布娃娃或抓取系统。

这次不是给旧直线浮台增加几关：路线围绕中央灯塔形成一个上升回环，包含有岩体承托的花园、庭院、码头、上下分岔、山脊与明确的终点。主路实测行程约 400 米，起点至终点升高 16 米。**Tab 可以随时查看整张实景地图，查看期间计时与游戏暂停。**

## 运行

1. 用 Godot 4.7.2 打开 `project.godot`。
2. 按 **F5** 运行项目（或 F6 运行 `scenes/main.tscn`）。
3. 移动后计时开始。无需外部素材、插件或下载依赖。

```sh
godot --path .
```

使用 Compatibility 渲染器。地图、几何、美术、UI 与合成短音效都是本项目原创；没有复制参考游戏的关卡布局或资产。

## 操作

| 按键 | 动作 |
| --- | --- |
| WASD / 方向键 | 相机相对移动 |
| Space | 跳跃；按住更高，松开缩短跳跃 |
| Tab | 全图实景俯瞰 / 返回；期间暂停 |
| Backspace | 返回最近检查点，记一次失败 |
| R | 完整重开计时与赛道 |
| Esc | 暂停 / 继续；全图中返回原状态 |
| Enter | 完赛后再来一局 |
| M | 音效开关 |

镜头在地面移动时平滑跟随路线转弯，跳跃与静止时保持方向，避免落地目标在空中突然旋转。暂停/完赛卡片的主按钮也可点击。

## 一张完整地图，六种节奏

| 区域 | 旅程内容 |
| --- | --- |
| **01 · Harbor Gardens 起航花园** | 大广场与码头出发，两道实体跳栏、短跳逐步教学。 |
| **02 · Windmill Court 风车庭院** | 两根旋转扫杆 → 安全存档 → 横移接驳平台；虚线圈标出危险范围。 |
| **03 · Canopy Paths 林冠双路** | 下层宽路与垂直升降平台；上层 2.2–2.8m 窄桥捷径。失足可落入恢复层，两路在同一存档前汇合。 |
| **04 · Ferry Harbor 渡台港口** | 两块横向移动渡台，中间等待岛新增中途存档；失败只重试当前半段。 |
| **05 · Ridge Ascent 山脊攀升** | 两条反向旋转的真实滚筒路、两条 2.4m 窄梁与中途存档；需要抵消侧向带动、保持平衡。 |
| **06 · Lighthouse Run 灯塔冲刺** | 扫杆 → 2.6m 窄桥 → 门前存档 → 红/绿节奏门；最后在灯塔广场冲线。 |

- **9 个顺序中途检查点**。必须沿路线依次保存，才会计入有效完赛；失败不必重跑整张地图。
- 安全地面为青绿和浅石色；活动危险物为橙红；检查点和终点为金色。箭头、旗帜和建筑地标共同引路。
- 路径之间的空隙是真实跨越，岛面与休息区则连续可走；没有隐形墙强迫唯一解。
- 个人最佳保存在 `user://record_lighthouse_obstacles_v2.cfg`，与旧版短赛道纪录隔离。

## 新增的可玩道路与中途存档

- **2 条滚筒路**：圆柱体碰撞面，转向相反，表面角速度会真实带动站在上面的 Cube 向侧面偏移；需要朝反方向微调或抓准跳跃。条纹显示转动方向，**不是只让模型自转**。
- **4 块移动平台**：风车区横移接驳、林冠垂直升降，以及渡港的两块横向渡台。静止站稳会跟随平台移动。
- **窄桥与窄梁**：上层捷径、山脊和灯塔前路径都缩窄了真实碰撞宽度，不只是画一条细路面。
- **2 道实体跳栏**：低栏会挡住普通行走，跳跃可越过，不会碰一下就强制死亡。
- **9 处中途存档**：在原有五处基础上，增加风车出口、渡港中间岛、滚筒山脊中段、终点节奏门前四处。金色灯柱与浮动编号清晰可见，激活后转青绿，HUD 提示已保存；Backspace 或掉落返回这里。

滚筒使用 Godot 官方支持的 `StaticBody3D.constant_angular_velocity` 表面速度，配合完全对应的圆柱碰撞与条纹转速；不修改玩家基础速度、重力或跳跃规则。[Godot StaticBody3D 文档](https://docs.godotengine.org/en/stable/classes/class_staticbody3d.html)

## 设计参考：学结构，不复制素材

参考了真实案例后再设计地图，具体对应关系详见 [设计说明](docs/map-design.md)。

- **Fall Guys · The Whirlygig**：Mediatonic 设计师说明了旋转扫杆、台阶、巨型风扇的递进，以及机关产生风险捷径的可能。这里借鉴「先认识机关，再组合复用」，不移植弹射或布娃娃。[PlayStation 官方设计师文章](https://blog.playstation.com/?p=333768)
- **Fall Guys · Treetop Tumble**：官方介绍多层、分支路线。这里落实为「下层宽主路 / 上层窄捷径 / 失误恢复层」。[Fall Guys 官方介绍](https://www.fallguys.com/news/fall-guys-season-5-blog?lang=en-US)
- **Human Fall Flat · Castle**：官方商店的城堡画面中，桥梁、门楼、岩体和高塔构成可辨识的完整环境；官方也说明关卡存在多条路线。这里借鉴环境连续性、强地标和探索感，**不是复制其抓取解谜玩法**。[官方商店与截图](https://store.steampowered.com/app/477160/Human_Fall_Flat/)

## 项目结构

```text
scenes/main.tscn      入口
scripts/main.gd      比赛状态、镜头、全图视角、输入、程序化短音效
scripts/player.gd    不变的 Cube 移动、跳跃、土狼时间与跳跃缓冲
scripts/course.gd    完整原创地图、建筑、地貌、分路与障碍
scripts/hud.gd       简洁 HUD、六区进度、九处存档、全图图例、暂停与完赛卡片
tests/               控制器、状态集成与正常输入通关测试
docs/map-design.md   案例到地图的设计依据
```

移动速度 **7 m/s**，跳速 **9 m/s**，重力 **24 m/s²**；土狼时间 **0.12 秒**，跳跃缓冲 **0.14 秒**。移动平台采用 `AnimatableBody3D`，玩家采用 `CharacterBody3D.move_and_slide()`。

## 验证

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --fixed-fps 60 --script res://tests/controller.gd
godot --headless --path . --fixed-fps 60 --script res://tests/focused.gd
godot --headless --path . --fixed-fps 60 --script res://tests/traverse.gd
godot --headless --path . --fixed-fps 60 --script res://tests/traverse.gd -- --route=upper
godot --headless --path . --fixed-fps 60 --script res://tests/traverse.gd -- --demo-respawn
```

`traverse.gd` 从真正起点出发，仅发送正常移动/跳跃输入，观察几何与运动时机；不传送、不改移动速度、不关闭危险物。`focused.gd` 的独立设置位置只用于边界状态验证，不作为真实通关证据。

### 最新验证记录（2026-10-31 · 障碍与中途存档版）

- Godot 4.7.2 导入：无脚本错误；控制器 **12 / 12**，物理/存档/恢复/UI 集成 **114 / 114**。
- 主路正常输入通关：**62.167 秒、400.8 米、29 跳、0 失败、9 存档**；实际接触全部 4 移动台、两滚筒，跳过两道矮栏。
- 上层窄路通关：**57.350 秒、383.1 米、31 跳、0 失败、9 存档**。
- 两滚筒实测接触角速度 **+0.72 / −0.85 rad/s**，静止 0.4 秒分别被带动 **+0.588 / −0.694 米**；正常输入能够纠正方向并通过。
- `--demo-respawn` 只用方向键真实走落海面，自动观察第 5 存档复位，再正常输入跑完；不调用角色传送。原生预览使用这条演示路线，**故意包含一次失败**。
- 熟悉几何的测试输入成绩不是首玩时长预测，也不是实际设备帧率测试。宽肩路线仍可绕开扫杆，但独立集成测试确认全部扫杆正常触发失败；窄桥、滚筒和移动平台则有真实接触覆盖检查。

原生视口录制：

```sh
godot --path . --fixed-fps 60 --script res://tests/traverse.gd -- --capture-dir=/absolute/output/folder
```

预览使用原生游戏渲染帧，按模拟时间组织，不代表目标设备的实测帧率。仓库不包含引擎、导出包、缓存或录制文件。
