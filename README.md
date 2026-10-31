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
| **01 · Harbor Gardens 起航花园** | 大广场与码头出发，宽路加两次低风险短跳，学习跳距。 |
| **02 · Windmill Court 风车庭院** | 连续大岛面、两座风车与两根旋转扫杆；虚线圈标出危险范围，草地边缘提供宽松绕行。 |
| **03 · Canopy Paths 林冠双路** | 下层宽路绕行；上层窄木桥更短、更快。上层下面有真实可落脚的恢复平台，两路在同一检查点前汇合。 |
| **04 · Ferry Harbor 渡台港口** | 吊机、码头、两块横向移动渡台与中间等待岛；观察运动、稳定起跳。 |
| **05 · Ridge Ascent 山脊攀升** | 岩脊与桥墩承托的逐级升高路径，从海面回望已走过的区域，接近灯塔。 |
| **06 · Lighthouse Run 灯塔冲刺** | 复用扫杆、阶梯与红/绿节奏门；最后在宽阔灯塔广场上冲线并结算。 |

- **5 个顺序检查点**。必须沿路线依次保存，才会计入有效完赛；失败不必重跑整张地图。
- 安全地面为青绿和浅石色；活动危险物为橙红；检查点和终点为金色。箭头、旗帜和建筑地标共同引路。
- 路径之间的空隙是真实跨越，岛面与休息区则连续可走；没有隐形墙强迫唯一解。
- 个人最佳保存在 `user://record_lighthouse_v1.cfg`，与旧版短赛道纪录隔离。

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
scripts/hud.gd       简洁 HUD、六区进度、全图图例、暂停与完赛卡片
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
```

`traverse.gd` 从真正起点出发，仅发送正常移动/跳跃输入，观察几何与运动时机；不传送、不改移动速度、不关闭危险物。`focused.gd` 的独立设置位置只用于边界状态验证，不作为真实通关证据。

### 最新验证记录（2026-10-31）

- Godot 4.7.2 导入：无脚本错误。
- 控制器：**12 / 12**；状态/恢复/障碍/全图集成：**54 / 54**。
- 主路正常输入通关：**62.167 秒、400.1 米、26 跳、0 失败、5 个检查点**。
- 上层捷径正常输入通关：**57.350 秒、382.5 米、29 跳、0 失败、5 个检查点**。
- 这些是熟悉几何的自动输入回归成绩，不是首玩用户时长预测，也不是实际设备帧率测试。扫杆测试路线选择真实宽肩绕行；独立集成测试确认三根扫杆仍会命中并复位玩家，终点节奏门则在通关中等待绿灯。

原生视口录制：

```sh
godot --path . --fixed-fps 60 --script res://tests/traverse.gd -- --capture-dir=/absolute/output/folder
```

预览使用原生游戏渲染帧，按模拟时间组织，不代表目标设备的实测帧率。仓库不包含引擎、导出包、缓存或录制文件。
