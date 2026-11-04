extends Control
## Compact edge-mounted overlays: the island, not a dashboard, owns the frame.
signal restart_requested
signal resume_requested

var elapsed := 0.0
var best := 0.0
var checkpoint := 0
var checkpoint_total := 0
var chapter := 0
var save_pulse := 0.0
var falls := 0
var running := false
var finished := false
var paused := false
var muted := false
var map_view := false
var map_markers: Array[Vector2] = []
var map_saves: Array[Vector2] = []
var finish_marker := Vector2(-1,-1)
var notice := ""
var notice_detail := ""
var notice_is_save := false
var notice_alpha := 0.0
var _font: Font
var _bold: FontVariation
const WHITE := Color("f7f7ef")
const INK := Color("24394f")
const MINT := Color("51e1c2")
const GOLD := Color("ffd17a")
const SUBTLE := Color("bad1dc")
const CHAPTERS := ["HARBOR GARDENS", "WINDMILL COURT", "CANOPY PATHS", "FERRY HARBOR", "RIDGE ASCENT", "LIGHTHOUSE RUN"]

const DefaultText: Translation = preload("res://games/minigame/godot_party_default_lighthouse_isles/i18n/zh_Hans.po")
var i18n: RefCounted

func hud_text(key: StringName, values: Dictionary) -> String:
	return DefaultText.get_message(key).format(values) if i18n == null else i18n.text(key,values)

func _ready() -> void:
	%Resume.pressed.connect(func() -> void:
		if finished:
			restart_requested.emit()
		elif paused:
			resume_requested.emit())

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_font = ThemeDB.fallback_font
	_bold = FontVariation.new()
	_bold.base_font = _font
	_bold.variation_embolden = 0.7

func time_text(value: float) -> String:
	var centis := int(value*100.0)
	return "%02d:%02d.%02d" % [centis/6000, (centis/100)%60, centis%100]

func _panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	draw_style_box(style,rect)

func _text(at: Vector2, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	draw_string(_bold if bold else _font,at,content,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px,color)

func _center(y: float, content: String, size_px: int, color: Color = WHITE, bold: bool = false) -> void:
	var font: Font = _bold if bold else _font
	_text(Vector2(640-font.get_string_size(content,HORIZONTAL_ALIGNMENT_LEFT,-1,size_px).x/2,y),content,size_px,color,bold)

func refresh() -> void:
	%Times.visible = not map_view
	%Saves.visible = not map_view
	%MapLegend.visible = map_view
	%Stage.text = "THE COMPLETE JOURNEY" if map_view else hud_text(&"hud.chapter", {"number":"%02d" % (chapter+1), "chapter":CHAPTERS[clampi(chapter,0,CHAPTERS.size()-1)]})
	%ChapterBar.value = chapter + 1
	%Clock.text = hud_text(&"hud.clock", {"time":time_text(elapsed)})
	%Best.text = hud_text(&"hud.best", {"time":time_text(best) if best > 0 else "—"})
	%SaveCount.text = hud_text(&"hud.saves", {"current":checkpoint,"total":checkpoint_total})
	%SaveHint.text = "Falls return to this saved point" if checkpoint > 0 else "Reach a glowing beacon to save"
	%SaveBar.max_value = checkpoint_total
	%SaveBar.value = checkpoint
	%Controls.get_node("Guide").text = "TAB / ESC   Return to the journey · Timer paused" if map_view else "WASD / ARROWS  Move    SPACE  Jump    TAB  Map    BACKSPACE  Retry    R  Restart    ESC  Pause    M  Sound"
	%Prompt.visible = not (running or finished or paused or map_view)
	%Notice.visible = notice_alpha > 0 and not (finished or paused or map_view)
	%Notice.modulate.a = notice_alpha
	%NoticeText.text = notice + ("\n" + notice_detail if not notice_detail.is_empty() else "")
	%Pause.visible = (paused or finished) and not map_view
	%Muted.visible = muted
	if %Pause.visible:
		%PauseTitle.text = "ISLAND JOURNEY COMPLETE" if finished else "TAKE A BREATHER"
		%PauseBody.text = hud_text(&"hud.result", {"time":time_text(elapsed), "falls":falls, "total":checkpoint_total}) if finished else "Your timer and the islands are paused.\nTab views the full map. Backspace retries this section."
		%Resume.text = "RUN AGAIN  /  ENTER" if finished else "KEEP GOING  /  ESC"
	queue_redraw()

func _draw() -> void:
	if not map_view:
		return
	draw_set_transform(Vector2.ZERO,0,size/Vector2(1280,800))
	for i in map_saves.size():
		var p := map_saves[i]
		if p.x<12 or p.x>1268 or p.y<12 or p.y>788: continue
		draw_circle(p,7,INK)
		draw_circle(p,5,MINT if i<checkpoint else GOLD)
	for i in map_markers.size():
		var p := map_markers[i]
		if p.x<12 or p.x>1268 or p.y<12 or p.y>788: continue
		draw_circle(p+Vector2(0,2),13,Color(0.06,0.12,0.17,0.4))
		draw_circle(p,12,MINT if i<=chapter else WHITE)
		_text(p+Vector2(-4,5),str(i+1),14,INK,true)
	if finish_marker.x>=0:
		_panel(Rect2(finish_marker.x-36,finish_marker.y-11,72,22),GOLD,7)
		_text(finish_marker+Vector2(-25,4),"FINISH",11,INK,true)
