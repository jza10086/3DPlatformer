# CUBE · Skyline Sprint

一个 **Godot 4.7.2** 的 3D 平台跑酷小原型：纯白、无脸、无贴图的 Cube，在浮空赛道上完成一次计时挑战。

灵感仅来自派对游戏中「短赛道 + 清晰障碍 + 失败迅速重来」的节奏；地图、几何、美术、界面和音效均为本项目原创，不包含《揍击派对》的素材。

## 运行

1. 用 Godot 4.7.2 打开 `project.godot`。
2. 按 **F6/F5** 运行 `scenes/main.tscn` / 项目。
3. 移动后计时开始。无需插件、下载素材或额外依赖。

```sh
godot --path .
```

使用 Compatibility 渲染器，桌面键盘操作；当前是 **单人可玩原型**，没有多人、联网或完整派对模式。

## 操作

| 按键 | 动作 |
| --- | --- |
| WASD / 方向键 | 相机相对移动 |
| Space | 跳跃；按住更高，松开缩短跳跃 |
| Backspace | 返回最近检查点（记一次失败） |
| R | 完整重开计时赛道 |
| Esc | 暂停 / 继续（计时和障碍一起暂停） |
| Enter | 完赛后再来一局 |
| M | 音效开关 |

暂停/完赛卡片的主按钮也可以点击。

## 赛道

- **01 · HOP**：错位、逐步升高的基础跳台。
- **02 · DRIFT**：两块横移平台；站稳后会随平台移动。
- **03 · RHYTHM**：跳过旋转横杆，在绿灯时穿过节奏门，再冲过终点。
- 两个检查点；掉落、碰撞危险物后快速复位。完赛时间停止，个人最佳保存在本机 `user://record.cfg`。

起跳条、箭头与分段颜色提示前进方向。镜头采用抬高的跟随视角，提前显示落点；移动不依赖鼠标。角色保留普通立方体轮廓，只有很轻的倾斜和落地回弹。

## 小而集中的结构

```text
scenes/main.tscn      入口
scripts/main.gd      比赛状态、跟随镜头、输入、程序化短音效
scripts/player.gd    Cube 移动、跳跃、土狼时间和跳跃缓冲
scripts/course.gd    原创几何赛道、平台、危险物与检查点
scripts/hud.gd       简洁 HUD、暂停和完赛卡片
```

移动速度 7 m/s，跳速 9 m/s，重力 24 m/s²；土狼时间 0.12 秒，跳跃缓冲 0.14 秒。移动平台使用 `AnimatableBody3D`，玩家使用 `CharacterBody3D.move_and_slide()`。

## 验证

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/controller.gd
godot --headless --path . --script res://tests/focused.gd
godot --headless --path . --script res://tests/traverse.gd
```

`traverse.gd` 通过正常移动/跳跃输入从起点跑到终点，读取赛道几何来决定输入，不传送角色、不改速度、不关闭危险物。`focused.gd` 的独立场景设置仅用于检查边界状态，不作为真实通关证据。

可选原生渲染捕获：

```sh
godot --path . --script res://tests/traverse.gd -- --capture-dir=/absolute/output/folder
```

录制是从原生视口采样、按模拟时间组织的预览，不代表目标设备的实测帧率。提交中不包含引擎、导出包、缓存、截图或 GIF。

### 参考

- [Godot · CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html)
- [Godot · AnimatableBody3D](https://docs.godotengine.org/en/stable/classes/class_animatablebody3d.html)
- [Pummel Party 官方商店介绍](https://store.steampowered.com/app/880940/Pummel_Party/)
